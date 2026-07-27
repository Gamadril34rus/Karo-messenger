/// Модель сообщения AI-ассистента
class AiMessage {
  final String id;
  final String role; // user, assistant
  final String content;
  final DateTime createdAt;

  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });
}
