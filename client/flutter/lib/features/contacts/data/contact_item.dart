// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
/// Модель контакта
class ContactItem {
  final String userId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final bool isOnline;

  const ContactItem({
    required this.userId,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.isOnline = false,
  });
}
