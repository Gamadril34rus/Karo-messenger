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
  final bool isArchived;
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
    this.isArchived = false,
    this.isOnline = false,
  });

  ChatItem copyWith({
    String? title,
    String? avatarUrl,
    String? lastMessage,
    String? lastMessageSender,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isMuted,
    bool? isPinned,
    bool? isArchived,
    bool? isOnline,
  }) {
    return ChatItem(
      id: id,
      type: type,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
