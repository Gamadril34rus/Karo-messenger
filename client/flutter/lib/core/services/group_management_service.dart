// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import '../domain/charo_repository.dart';
import '../../features/chat/data/chat_item.dart';
import '../utils/logger.dart';

/// ─── Group Management Service ────────────────────────────────────
/// Управление группами: создание, изменение названия/аватара,
/// управление участниками и ролями.
/// Все вызовы проходят через CharoRepository.

class GroupManagementService {
  final CharoRepository _repository;

  GroupManagementService({required CharoRepository repository}) : _repository = repository;

  /// Создать группу
  Future<ChatItem> createGroup({
    required String title,
    required List<String> memberIds,
    String? avatarUrl,
  }) async {
    final chat = await _repository.createChat('group', title, memberIds);
    logger.i('👥 Group created: ${chat.id}');
    return chat;
  }

  /// Создать канал
  Future<ChatItem> createChannel({
    required String title,
    String? description,
    String? avatarUrl,
  }) async {
    final chat = await _repository.createChat('channel', title, null);
    logger.i('👥 Channel created: ${chat.id}');
    return chat;
  }

  /// Обновить название/аватар группы
  Future<void> updateGroupInfo({
    required String chatId,
    String? title,
    String? avatarUrl,
    String? description,
  }) async {
    await _repository.updateGroupInfo(chatId, title: title, avatarUrl: avatarUrl);
    logger.i('👥 Group info updated: $chatId');
  }

  /// Добавить участника
  Future<void> addMember({
    required String chatId,
    required String userId,
    String role = 'MEMBER',
  }) async {
    await _repository.addChatMembers(chatId, [userId]);
    logger.i('👥 Member added: $userId to $chatId');
  }

  /// Удалить участника
  Future<void> removeMember({
    required String chatId,
    required String userId,
  }) async {
    await _repository.removeMember(chatId, userId);
    logger.i('👥 Member removed: $userId from $chatId');
  }

  /// Изменить роль участника
  Future<void> updateMemberRole({
    required String chatId,
    required String userId,
    required String role,
  }) async {
    await _repository.updateMemberRole(chatId, userId, role);
    logger.i('👥 Member role updated: $userId → $role');
  }

  /// Покинуть группу
  Future<void> leaveGroup(String chatId) async {
    await _repository.leaveGroup(chatId);
    logger.i('👥 Left group: $chatId');
  }

  /// Удалить группу (только OWNER)
  Future<void> deleteGroup(String chatId) async {
    await _repository.deleteGroup(chatId);
    logger.i('👥 Group deleted: $chatId');
  }
}

// Re-export ChatItem for backward compatibility — already imported above
