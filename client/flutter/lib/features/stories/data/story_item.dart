// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
/// Модель истории (story)
class StoryItem {
  final String userId;
  final String? userName;
  final String? avatarUrl;
  final String type; // image, video, text
  final String? textContent;
  final int count;
  final bool isViewed;

  /// Individual story items for viewer (when expanded from grouped)
  final List<StoryContentItem> items;

  const StoryItem({
    required this.userId,
    this.userName,
    this.avatarUrl,
    this.type = 'image',
    this.textContent,
    this.count = 1,
    this.isViewed = false,
    this.items = const [],
  });

  StoryItem copyWith({
    String? userId,
    String? userName,
    String? avatarUrl,
    String? type,
    String? textContent,
    int? count,
    bool? isViewed,
    List<StoryContentItem>? items,
  }) {
    return StoryItem(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      type: type ?? this.type,
      textContent: textContent ?? this.textContent,
      count: count ?? this.count,
      isViewed: isViewed ?? this.isViewed,
      items: items ?? this.items,
    );
  }
}

/// Отдельная история (элемент внутри группы)
class StoryContentItem {
  final String id;
  final String type; // image, video, text
  final String? mediaUrl;
  final String? textContent;
  final String? backgroundColor;
  final DateTime? createdAt;
  final bool isViewed;
  final int viewCount;

  const StoryContentItem({
    required this.id,
    this.type = 'image',
    this.mediaUrl,
    this.textContent,
    this.backgroundColor,
    this.createdAt,
    this.isViewed = false,
    this.viewCount = 0,
  });
}
