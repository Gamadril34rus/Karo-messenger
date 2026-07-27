/// Модель истории (story)
class StoryItem {
  final String userId;
  final String? userName;
  final String? avatarUrl;
  final String type; // image, video, text
  final String? textContent;
  final int count;
  final bool isViewed;

  const StoryItem({
    required this.userId,
    this.userName,
    this.avatarUrl,
    this.type = 'image',
    this.textContent,
    this.count = 1,
    this.isViewed = false,
  });
}
