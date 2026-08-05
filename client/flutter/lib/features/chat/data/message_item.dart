// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import '../../../shared/widgets/message_bubble.dart';

/// Модель сообщения для чата
class MessageItem {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final bool isMe;
  final String type;
  final String? text;
  final String? mediaUrl;
  final String? mediaThumbnail;
  final String? replyToText;
  final String? replyToSender;
  final bool isEdited;
  final bool isDeleted;
  final MessageStatus status;
  final DateTime sentAt;
  final DateTime? readAt;
  final List<Reaction> reactions;

  const MessageItem({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    required this.isMe,
    required this.type,
    this.text,
    this.mediaUrl,
    this.mediaThumbnail,
    this.replyToText,
    this.replyToSender,
    this.isEdited = false,
    this.isDeleted = false,
    this.status = MessageStatus.sent,
    required this.sentAt,
    this.readAt,
    this.reactions = const [],
  });
}
