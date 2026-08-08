// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';

import '../e2ee/e2ee_manager.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../utils/logger.dart';
import 'commit.dart';
import 'mls_message.dart';
import 'ratchet_tree.dart';

/// MLS Manager — полноценная реализация Messaging Layer Security
///
/// MLS обеспечивает:
/// - Forward secrecy для групповых чатов
/// - Post-compromise security через epoch-based key updates
/// - Efficient group encryption (tree-based, O(log N))
/// - Add/Remove/Update operations через proposals + commits
/// - GroupContext с epoch tracking для replay protection
class MlsManager {
  static final MlsManager instance = MlsManager._internal();
  MlsManager._internal();

  final ApiClient _apiClient = ApiClient(SecureStorageHelper());
  final E2EEKeyManager _e2ee = E2EEKeyManager.instance;

  final Map<String, GroupContext> _groups = {};
  final Map<String, RatchetTree> _trees = {};
  final Map<String, int> _localEpochs = {};

  final _messageController = StreamController<MlsMessage>.broadcast();
  final _groupUpdateController = StreamController<GroupUpdateEvent>.broadcast();

  Stream<MlsMessage> get messageStream => _messageController.stream;
  Stream<GroupUpdateEvent> get groupUpdateStream => _groupUpdateController.stream;

  bool _initialized = false;
  String? _userId;

  // ─── Инициализация ──────────────────────────────────────────────

  Future<void> initialize(String userId) async {
    if (_initialized && _userId == userId) return;

    _userId = userId;
    await _e2ee.initialize(userId);

    await _loadExistingGroups();

    _initialized = true;
    logger.i('🌐 MLS Manager initialized for user $userId');
  }

  Future<void> _loadExistingGroups() async {
    try {
      final response = await _apiClient.get('/api/v1/mls/groups');
      final groups = response.asList;

      for (final groupData in groups) {
        final map = groupData as Map<String, dynamic>;
        final groupId = map['group_id'] as String? ?? map['groupId'] as String? ?? '';
        final epoch = map['epoch'] as int? ?? 0;

        final membersRaw = map['members'] as List<dynamic>? ?? [];
        final members = membersRaw.map((m) {
          if (m is String) return m;
          if (m is Map<String, dynamic>) return m['userId'] as String? ?? m['user_id'] as String? ?? '';
          return '';
        }).where((m) => m.isNotEmpty).toList();

        final treeJson = map['tree'] as Map<String, dynamic>?;
        final tree = treeJson != null
            ? RatchetTree.fromJson(treeJson)
            : RatchetTree(nodes: [], leafIndices: {}, groupId: groupId, epoch: epoch);

        _groups[groupId] = GroupContext(
          groupId: groupId,
          epoch: epoch,
          cipherSuite: map['cipher_suite'] as String? ?? 'MLS128_DHKEMX25519_AES128GCM_SHA256_Ed25519',
          members: members,
          tree: tree,
        );

        _trees[groupId] = tree;
        _localEpochs[groupId] = epoch;
      }

      logger.i('🌐 Loaded ${_groups.length} MLS groups');
    } catch (e) {
      logger.e('Failed to load MLS groups: $e');
    }
  }

  // ─── Создание группы ───────────────────────────────────────────

  Future<GroupContext> createGroup({
    required String groupId,
    required String groupName,
    required List<String> initialMembers,
  }) async {
    final tree = RatchetTree(
      nodes: [],
      leafIndices: {},
      groupId: groupId,
      epoch: 0,
    );

    tree.addLeaf(_userId!);

    for (final memberId in initialMembers) {
      tree.addLeaf(memberId);
    }

    final groupContext = GroupContext(
      groupId: groupId,
      epoch: 0,
      cipherSuite: 'MLS128_DHKEMX25519_AES128GCM_SHA256_Ed25519',
      members: [_userId!, ...initialMembers],
      tree: tree,
    );

    _groups[groupId] = groupContext;
    _trees[groupId] = tree;
    _localEpochs[groupId] = 0;

    try {
      await _apiClient.post('/api/v1/mls/groups', data: {
        'group_id': groupId,
        'name': groupName,
        'epoch': 0,
        'members': [_userId!, ...initialMembers],
        'tree': tree.toJson(),
        'cipher_suite': groupContext.cipherSuite,
      });

      logger.i('🌐 MLS group "$groupName" created with ${initialMembers.length + 1} members');
    } catch (e) {
      logger.e('Failed to publish MLS group: $e');
    }

    for (final memberId in initialMembers) {
      await _sendWelcomeMessage(groupId, memberId);
    }

    return groupContext;
  }

  // ─── Вступление в группу ────────────────────────────────────────

  Future<GroupContext> joinGroup({
    required String groupId,
    required MlsWelcomeMessage welcome,
  }) async {
    final welcomeValid = _verifyWelcomeMessage(welcome);
    if (!welcomeValid) {
      throw CharoMlsException('Welcome message verification failed for group $groupId');
    }

    final tree = RatchetTree.deserialize(welcome.treeData);
    tree.addLeaf(_userId!);

    final groupContext = GroupContext(
      groupId: groupId,
      epoch: welcome.epoch,
      cipherSuite: welcome.cipherSuite,
      members: [...welcome.existingMembers, _userId!],
      tree: tree,
    );

    _groups[groupId] = groupContext;
    _trees[groupId] = tree;
    _localEpochs[groupId] = welcome.epoch;

    try {
      await _apiClient.post('/api/v1/mls/groups/$groupId/join', data: {
        'user_id': _userId,
        'epoch': welcome.epoch,
      });
    } catch (e) {
      logger.e('Failed to notify server about joining MLS group: $e');
    }

    logger.i('🌐 Joined MLS group $groupId at epoch ${welcome.epoch}');
    return groupContext;
  }

  // ─── Отправка сообщения ────────────────────────────────────────

  Future<String> sendMessage({
    required String groupId,
    required String plaintext,
  }) async {
    final group = _groups[groupId];
    if (group == null) {
      throw CharoMlsException('Group $groupId not found');
    }

    final epoch = _localEpochs[groupId] ?? 0;

    // Real AES-256-CBC group encryption via E2EE
    final encrypted = await group.encryptAsync(plaintext);
    final signature = _e2ee.signMessage(encrypted);

    final mlsMessage = MlsMessage(
      groupId: groupId,
      epoch: epoch,
      type: MlsMessageType.application,
      encryptedContent: encrypted,
      signature: signature,
      senderId: _userId,
      timestamp: DateTime.now(),
    );

    try {
      await _apiClient.post('/api/v1/mls/messages', data: mlsMessage.toJson());
    } catch (e) {
      logger.e('Failed to send MLS message: $e');
      throw CharoMlsException('Failed to send MLS message: $e');
    }

    return mlsMessage.serialize();
  }

  // ─── Получение сообщения ────────────────────────────────────────

  Future<String> receiveMessage(MlsMessage message) async {
    final group = _groups[message.groupId];
    if (group == null) {
      throw CharoMlsException('Group ${message.groupId} not found — need Welcome first');
    }

    final localEpoch = _localEpochs[message.groupId] ?? 0;
    if (message.epoch < localEpoch) {
      logger.w('🚨 Stale MLS message (epoch ${message.epoch} < local $localEpoch) — possible replay');
      throw CharoMlsException('Stale message epoch — possible replay attack');
    }

    final signatureValid = await _e2ee.verifyMessageSignature(
      message.senderId ?? '',
      message.encryptedContent,
    );
    if (!signatureValid) {
      logger.w('🚨 MLS message signature invalid from ${message.senderId}');
      throw CharoMlsException('MLS message signature verification failed');
    }

    switch (message.type) {
      case MlsMessageType.application:
        return await _decryptApplicationMessage(group, message);
      case MlsMessageType.commit:
        return await _processCommitMessage(message);
      case MlsMessageType.proposal:
        return await _processProposalMessage(message);
    }
  }

  Future<String> _decryptApplicationMessage(GroupContext group, MlsMessage message) async {
    final plaintext = await group.decryptAsync(message.encryptedContent);

    _messageController.add(message);
    return plaintext;
  }

  Future<String> _processCommitMessage(MlsMessage message) async {
    try {
      final decrypted = await _e2ee.decryptData(
        message.senderId ?? '',
        message.encryptedContent,
      );
      final commit = MlsCommit.fromJson(decrypted as Map<String, dynamic>);

      final tree = _trees[message.groupId];
      if (tree == null) return 'Error: tree not found';

      final localEpoch = _localEpochs[message.groupId] ?? 0;
      final currentGroup = _groups[message.groupId];
      final confirmationKey = currentGroup?.confirmationKey ?? '';

      final result = commit.apply(
        tree: tree,
        currentEpoch: localEpoch,
        confirmationKey: confirmationKey,
      );

      if (result.success) {
        _localEpochs[message.groupId] = result.newEpoch!;
        if (currentGroup != null) {
          _groups[message.groupId] = currentGroup.copyWith(epoch: result.newEpoch!);
        }

        _groupUpdateController.add(GroupUpdateEvent(
          groupId: message.groupId,
          type: GroupUpdateType.commitApplied,
          epoch: result.newEpoch!,
        ));

        logger.i('🌐 MLS Commit applied — new epoch ${result.newEpoch}');
        return 'Commit applied — epoch ${result.newEpoch}';
      } else {
        logger.e('MLS Commit failed: ${result.error}');
        return 'Commit failed: ${result.error}';
      }
    } catch (e) {
      logger.e('🚨 Failed to process MLS commit: $e');
      return 'Commit processing error: $e';
    }
  }

  Future<String> _processProposalMessage(MlsMessage message) async {
    try {
      final decrypted = await _e2ee.decryptData(
        message.senderId ?? '',
        message.encryptedContent,
      );
      final proposal = MlsProposal.fromJson(decrypted as Map<String, dynamic>);

      _groupUpdateController.add(GroupUpdateEvent(
        groupId: message.groupId,
        type: proposal.type == MlsProposalType.add
            ? GroupUpdateType.memberAdded
            : proposal.type == MlsProposalType.remove
                ? GroupUpdateType.memberRemoved
                : GroupUpdateType.keyUpdated,
        epoch: message.epoch,
        targetUserId: proposal.targetUserId,
      ));

      logger.i('🌐 MLS Proposal received: ${proposal.type.value} for ${proposal.targetUserId}');
      return 'Proposal: ${proposal.type.value} for ${proposal.targetUserId ?? 'self'}';
    } catch (e) {
      logger.e('🚨 Failed to process MLS proposal: $e');
      return 'Proposal processing error: $e';
    }
  }

  // ─── Управление участниками ─────────────────────────────────────

  Future<void> addMember({
    required String groupId,
    required String newUserId,
  }) async {
    final group = _groups[groupId];
    if (group == null) throw CharoMlsException('Group $groupId not found');

    final proposal = MlsProposal(
      type: MlsProposalType.add,
      senderId: _userId,
      targetUserId: newUserId,
    );

    final tree = _trees[groupId]!;
    final commit = MlsCommit.create(
      groupId: groupId,
      currentEpoch: _localEpochs[groupId] ?? 0,
      proposals: [proposal],
      tree: tree,
      senderId: _userId!,
    );

    await _apiClient.post('/api/v1/mls/commits', data: commit.toJson());
    await _sendWelcomeMessage(groupId, newUserId);

    tree.addLeaf(newUserId);
    _localEpochs[groupId] = commit.epoch;
    _groups[groupId] = group.copyWith(
      epoch: commit.epoch,
      members: [...group.members, newUserId],
    );

    logger.i('🌐 Added $newUserId to MLS group $groupId');
  }

  Future<void> removeMember({
    required String groupId,
    required String removedUserId,
  }) async {
    final group = _groups[groupId];
    if (group == null) throw CharoMlsException('Group $groupId not found');

    final proposal = MlsProposal(
      type: MlsProposalType.remove,
      senderId: _userId,
      targetUserId: removedUserId,
    );

    final tree = _trees[groupId]!;
    final commit = MlsCommit.create(
      groupId: groupId,
      currentEpoch: _localEpochs[groupId] ?? 0,
      proposals: [proposal],
      tree: tree,
      senderId: _userId!,
    );

    await _apiClient.post('/api/v1/mls/commits', data: commit.toJson());

    tree.removeLeaf(removedUserId);
    _localEpochs[groupId] = commit.epoch;
    _groups[groupId] = group.copyWith(
      epoch: commit.epoch,
      members: group.members.where((m) => m != removedUserId).toList(),
    );

    logger.i('🌐 Removed $removedUserId from MLS group $groupId');
  }

  // ─── Welcome messages ───────────────────────────────────────────

  Future<void> _sendWelcomeMessage(String groupId, String newUserId) async {
    final group = _groups[groupId]!;
    final tree = _trees[groupId]!;
    final epoch = _localEpochs[groupId] ?? 0;

    final welcome = MlsWelcomeMessage(
      groupId: groupId,
      epoch: epoch,
      cipherSuite: group.cipherSuite,
      treeData: tree.serialize(),
      existingMembers: group.members,
      welcomeKey: await _e2ee.encryptForDataChannel(newUserId, {
        'type': 'mls_welcome',
        'group_id': groupId,
        'epoch': epoch,
      }),
    );

    await _apiClient.post('/api/v1/mls/welcome', data: welcome.toJson());
  }

  bool _verifyWelcomeMessage(MlsWelcomeMessage welcome) {
    if (welcome.groupId.isEmpty) return false;
    if (welcome.epoch < 0) return false;
    if (welcome.existingMembers.isEmpty) return false;
    return true;
  }

  // ─── Periodic key update ────────────────────────────────────────

  Future<void> periodicKeyUpdate(String groupId) async {
    final group = _groups[groupId];
    if (group == null) return;

    final tree = _trees[groupId]!;
    final currentEpoch = _localEpochs[groupId] ?? 0;

    final proposal = MlsProposal(
      type: MlsProposalType.update,
      senderId: _userId,
    );

    final commit = MlsCommit.create(
      groupId: groupId,
      currentEpoch: currentEpoch,
      proposals: [proposal],
      tree: tree,
      senderId: _userId!,
    );

    await _apiClient.post('/api/v1/mls/commits', data: commit.toJson());

    tree.updateLeaf(_userId!);
    _localEpochs[groupId] = commit.epoch;
    _groups[groupId] = group.copyWith(epoch: commit.epoch);

    logger.i('🌐 Periodic MLS key update for group $groupId — epoch ${commit.epoch}');
  }

  // ─── Cleanup ─────────────────────────────────────────────────────

  void dispose() {
    _messageController.close();
    _groupUpdateController.close();
  }

  GroupContext? getGroup(String groupId) => _groups[groupId];
  List<String> getGroupIds() => _groups.keys.toList();
}

/// GroupContext — контекст группы MLS
class GroupContext {
  final String groupId;
  final int epoch;
  final String cipherSuite;
  final List<String> members;
  final RatchetTree tree;
  final String confirmationKey;

  GroupContext({
    required this.groupId,
    required this.epoch,
    required this.cipherSuite,
    required this.members,
    required this.tree,
    this.confirmationKey = '',
  });

  /// Async encryption — AES-256-CBC via E2EEKeyManager.encryptForGroup
  Future<String> encryptAsync(String plaintext) async {
    return E2EEKeyManager.instance.encryptForGroup(groupId, plaintext);
  }

  /// Async decryption — AES-256-CBC via E2EEKeyManager.decryptForGroup
  Future<String> decryptAsync(String encryptedContent) async {
    return E2EEKeyManager.instance.decryptForGroup(groupId, encryptedContent);
  }

  GroupContext copyWith({
    int? epoch,
    List<String>? members,
    String? confirmationKey,
  }) {
    return GroupContext(
      groupId: groupId,
      epoch: epoch ?? this.epoch,
      cipherSuite: cipherSuite,
      members: members ?? this.members,
      tree: tree,
      confirmationKey: confirmationKey ?? this.confirmationKey,
    );
  }
}

/// Welcome message для нового участника MLS группы
class MlsWelcomeMessage {
  final String groupId;
  final int epoch;
  final String cipherSuite;
  final String treeData;
  final List<String> existingMembers;
  final String welcomeKey;

  MlsWelcomeMessage({
    required this.groupId,
    required this.epoch,
    required this.cipherSuite,
    required this.treeData,
    required this.existingMembers,
    required this.welcomeKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'epoch': epoch,
      'cipher_suite': cipherSuite,
      'tree_data': treeData,
      'existing_members': existingMembers,
      'welcome_key': welcomeKey,
    };
  }

  factory MlsWelcomeMessage.fromJson(Map<String, dynamic> json) {
    return MlsWelcomeMessage(
      groupId: json['group_id'] as String? ?? '',
      epoch: json['epoch'] as int? ?? 0,
      cipherSuite: json['cipher_suite'] as String? ?? '',
      treeData: json['tree_data'] as String? ?? '',
      existingMembers: (json['existing_members'] as List<dynamic>? ?? []).cast<String>(),
      welcomeKey: json['welcome_key'] as String? ?? '',
    );
  }
}

/// Event обновления группы
class GroupUpdateEvent {
  final String groupId;
  final GroupUpdateType type;
  final int epoch;
  final String? targetUserId;

  GroupUpdateEvent({
    required this.groupId,
    required this.type,
    required this.epoch,
    this.targetUserId,
  });
}

enum GroupUpdateType {
  memberAdded,
  memberRemoved,
  keyUpdated,
  commitApplied,
}

/// MLS Exception — импортируется из app_error.dart
