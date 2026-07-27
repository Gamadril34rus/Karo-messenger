import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;

import 'mls_message.dart';
import 'ratchet_tree.dart';

/// MLS Commit — подтверждение предложенных изменений в группе
///
/// Commit создаётся после накопления proposal-сообщений.
/// Он содержит:
/// - Список принятых proposals
/// - UpdatePath для обновления дерева ключей
/// - ConfirmationTag — HMAC для верификации
class MlsCommit {
  final String groupId;
  final int epoch;
  final List<MlsProposal> proposals;
  final UpdatePath? updatePath;
  final String confirmationTag;
  final String? senderId;
  final DateTime createdAt;

  MlsCommit({
    required this.groupId,
    required this.epoch,
    required this.proposals,
    this.updatePath,
    required this.confirmationTag,
    this.senderId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Статический фабричный метод — создание Commit из proposals
  static MlsCommit create({
    required String groupId,
    required int currentEpoch,
    required List<MlsProposal> proposals,
    required RatchetTree tree,
    required String senderId,
  }) {
    // 1. Фильтруем валидные proposals
    final validProposals = proposals.where((p) => p.isValid).toList();

    // 2. Генерируем UpdatePath (обновление ключей в дереве)
    final updatePath = tree.generateUpdatePath(senderId);

    // 3. Вычисляем ConfirmationTag (HMAC над transitive hash)
    final confirmationTag = _computeConfirmationTag(
      groupId: groupId,
      epoch: currentEpoch + 1,
      proposals: validProposals,
      updatePath: updatePath,
    );

    return MlsCommit(
      groupId: groupId,
      epoch: currentEpoch + 1,
      proposals: validProposals,
      updatePath: updatePath,
      confirmationTag: confirmationTag,
      senderId: senderId,
    );
  }

  /// Применение Commit — верификация и обновление состояния группы
  MlsCommitResult apply({
    required RatchetTree tree,
    required int currentEpoch,
    required String confirmationKey,
  }) {
    // 1. Верификация epoch (commit.epoch == currentEpoch + 1)
    if (epoch != currentEpoch + 1) {
      return MlsCommitResult(
        success: false,
        error: 'Epoch mismatch: expected ${currentEpoch + 1}, got $epoch',
      );
    }

    // 2. Верификация ConfirmationTag
    final expectedTag = _computeConfirmationTag(
      groupId: groupId,
      epoch: epoch,
      proposals: proposals,
      updatePath: updatePath,
    );

    if (confirmationTag != expectedTag) {
      return MlsCommitResult(
        success: false,
        error: 'Confirmation tag mismatch — possible forged commit',
      );
    }

    // 3. Применение proposals к дереву
    for (final proposal in proposals) {
      switch (proposal.type) {
        case MlsProposalType.add:
          tree.addLeaf(proposal.targetUserId!);
          break;
        case MlsProposalType.remove:
          tree.removeLeaf(proposal.targetUserId!);
          break;
        case MlsProposalType.update:
          tree.updateLeaf(senderId!);
          break;
        case MlsProposalType.externalInit:
          // External init не требует модификации дерева на данном этапе
          break;
      }
    }

    // 4. Применение UpdatePath к дереву
    if (updatePath != null) {
      final applyResult = tree.applyUpdatePath(updatePath!);
      if (!applyResult) {
        return MlsCommitResult(
          success: false,
          error: 'Failed to apply update path to ratchet tree',
        );
      }
    }

    // 5. Увеличение epoch
    return MlsCommitResult(
      success: true,
      newEpoch: epoch,
    );
  }

  /// Вычисление ConfirmationTag — HMAC-SHA256 via PointyCastle
  static String _computeConfirmationTag({
    required String groupId,
    required int epoch,
    required List<MlsProposal> proposals,
    required UpdatePath? updatePath,
  }) {
    // ConfirmationTag = HMAC-SHA256(confirmation_key, transitive_hash)
    // transitive_hash = SHA-256(epoch || proposals || updatePath)
    final proposalsData = proposals.map((p) => p.toJson()).toList().toString();
    final updatePathData = updatePath?.toJson().toString() ?? '';
    final transitiveInput = '$groupId|$epoch|$proposalsData|$updatePathData';

    // HMAC-SHA256 via PointyCastle
    final inputBytes = Uint8List.fromList(utf8.encode(transitiveInput));

    // Use groupId-derived key as HMAC key (in full MLS: confirmation_key from GroupContext)
    final keyBytes = Uint8List.fromList(utf8.encode('charo_confirm:$groupId'));

    final hmac = pc.HMac(pc.SHA256Digest(), 64);
    hmac.init(pc.KeyParameter(keyBytes));
    final tagBytes = Uint8List(32);
    hmac.update(inputBytes, 0, inputBytes.length);
    hmac.doFinal(tagBytes, 0);

    return base64Encode(tagBytes);
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'epoch': epoch,
      'proposals': proposals.map((p) => p.toJson()).toList(),
      if (updatePath != null) 'update_path': updatePath!.toJson(),
      'confirmation_tag': confirmationTag,
      if (senderId != null) 'sender_id': senderId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MlsCommit.fromJson(Map<String, dynamic> json) {
    return MlsCommit(
      groupId: json['group_id'] as String? ?? json['groupId'] as String? ?? '',
      epoch: json['epoch'] as int? ?? 0,
      proposals: (json['proposals'] as List<dynamic>? ?? [])
          .map((p) => MlsProposal.fromJson(p as Map<String, dynamic>))
          .toList(),
      updatePath: json['update_path'] != null
          ? UpdatePath.fromJson(json['update_path'] as Map<String, dynamic>)
          : null,
      confirmationTag: json['confirmation_tag'] as String? ?? json['confirmationTag'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? json['senderId'] as String?,
    );
  }
}

/// MLS Proposal — предложение изменения в группе
class MlsProposal {
  final MlsProposalType type;
  final String? senderId;
  final String? targetUserId;
  final String? reference;
  final bool isValid;

  MlsProposal({
    required this.type,
    this.senderId,
    this.targetUserId,
    this.reference,
    this.isValid = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      if (senderId != null) 'sender_id': senderId,
      if (targetUserId != null) 'target_user_id': targetUserId,
      if (reference != null) 'reference': reference,
      'is_valid': isValid,
    };
  }

  factory MlsProposal.fromJson(Map<String, dynamic> json) {
    return MlsProposal(
      type: MlsProposalType.fromString(json['type'] as String? ?? 'add'),
      senderId: json['sender_id'] as String? ?? json['senderId'] as String?,
      targetUserId: json['target_user_id'] as String? ?? json['targetUserId'] as String?,
      reference: json['reference'] as String?,
      isValid: json['is_valid'] as bool? ?? true,
    );
  }
}

/// Типы MLS proposals
enum MlsProposalType {
  add('add'),
  remove('remove'),
  update('update'),
  externalInit('external_init');

  final String value;

  const MlsProposalType(this.value);

  static MlsProposalType fromString(String value) {
    switch (value) {
      case 'add':
        return MlsProposalType.add;
      case 'remove':
        return MlsProposalType.remove;
      case 'update':
        return MlsProposalType.update;
      case 'external_init':
        return MlsProposalType.externalInit;
      default:
        return MlsProposalType.add;
    }
  }
}

/// Результат применения Commit
class MlsCommitResult {
  final bool success;
  final int? newEpoch;
  final String? error;

  MlsCommitResult({
    required this.success,
    this.newEpoch,
    this.error,
  });
}
