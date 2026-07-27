/// Модель чата для списка
class ChatItem {
  final String id;
  final String type;
  final String? title;
  final String? avatarUrl;
  final String? lastMessage;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;
  final bool isOnline;

  const ChatItem({
    required this.id,
    this.type = 'private',
    this.title,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageSender,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
    this.isOnline = false,
  });
}
