// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:convert';

/// MLS Message — сообщение протокола MLS (Messaging Layer Security)
///
/// Типы MLS-сообщений:
/// - proposal: предложение добавить/удалить участника, обновить ключи
/// - commit: подтверждение предложенных изменений (с updatePath)
/// - application: зашифрованное содержимое (текст, медиа и т.д.)
class MlsMessage {
  final String groupId;
  final int epoch;
  final MlsMessageType type;
  final String encryptedContent;
  final String signature;
  final String? senderId;
  final DateTime? timestamp;

  MlsMessage({
    required this.groupId,
    required this.epoch,
    required this.type,
    required this.encryptedContent,
    required this.signature,
    this.senderId,
    this.timestamp,
  });

  factory MlsMessage.fromJson(Map<String, dynamic> json) {
    return MlsMessage(
      groupId: json['group_id'] as String? ?? json['groupId'] as String? ?? '',
      epoch: json['epoch'] as int? ?? 0,
      type: MlsMessageType.fromString(
        json['type'] as String? ?? 'application',
      ),
      encryptedContent: json['encrypted_content'] as String? ?? json['encryptedContent'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? json['senderId'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'epoch': epoch,
      'type': type.value,
      'encrypted_content': encryptedContent,
      'signature': signature,
      if (senderId != null) 'sender_id': senderId,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }

  String serialize() => jsonEncode(toJson());

  factory MlsMessage.deserialize(String serialized) {
    return MlsMessage.fromJson(jsonDecode(serialized) as Map<String, dynamic>);
  }

  @override
  String toString() => 'MlsMessage($groupId, epoch=$epoch, type=${type.value})';
}

/// Типы MLS-сообщений
enum MlsMessageType {
  proposal('proposal'),
  commit('commit'),
  application('application');

  final String value;

  const MlsMessageType(this.value);

  static MlsMessageType fromString(String value) {
    switch (value) {
      case 'proposal':
        return MlsMessageType.proposal;
      case 'commit':
        return MlsMessageType.commit;
      case 'application':
        return MlsMessageType.application;
      default:
        return MlsMessageType.application;
    }
  }
}
