// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import '../domain/charo_repository.dart';
import '../utils/logger.dart';

/// ─── Block List Service ─────────────────────────────────────────
/// Блокировка пользователей: добавить/удалить из чёрного списка.
/// Проверка: заблокирован ли пользователь.

class BlockListService {
  final CharoRepository _repository;

  BlockListService({required CharoRepository repository}) : _repository = repository;

  final Set<String> _blockedUsers = {};

  /// Заблокировать пользователя
  Future<void> blockUser(String userId) async {
    await _repository.blockUser(userId);
    _blockedUsers.add(userId);
    logger.i('🚫 User blocked: $userId');
  }

  /// Разблокировать пользователя
  Future<void> unblockUser(String userId) async {
    await _repository.unblockUser(userId);
    _blockedUsers.remove(userId);
    logger.i('🚫 User unblocked: $userId');
  }

  /// Проверить, заблокирован ли пользователь
  bool isBlocked(String userId) => _blockedUsers.contains(userId);

  /// Загрузить список заблокированных
  Future<void> loadBlockList() async {
    try {
      final blockedUsers = await _repository.getBlockedUsers();
      _blockedUsers.clear();
      for (final user in blockedUsers) {
        if (user.userId.isNotEmpty) _blockedUsers.add(user.userId);
      }
      logger.i('🚫 Block list loaded: ${_blockedUsers.length} users');
    } catch (e) {
      logger.e('🚫 Failed to load block list: $e');
    }
  }

  /// Получить все заблокированные ID
  Set<String> get blockedUserIds => Set.from(_blockedUsers);
}
