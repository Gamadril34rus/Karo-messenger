import '../network/api_client.dart';
import '../utils/logger.dart';

/// ─── Block List Service ─────────────────────────────────────────
/// Блокировка пользователей: добавить/удалить из чёрного списка.
/// Проверка: заблокирован ли пользователь.

class BlockListService {
  final ApiClient _apiClient;

  BlockListService({required ApiClient apiClient}) : _apiClient = apiClient;

  final Set<String> _blockedUsers = {};

  /// Заблокировать пользователя
  Future<void> blockUser(String userId) async {
    await _apiClient.post('/api/v1/contacts/block', data: {'userId': userId});
    _blockedUsers.add(userId);
    logger.i('🚫 User blocked: $userId');
  }

  /// Разблокировать пользователя
  Future<void> unblockUser(String userId) async {
    await _apiClient.delete('/api/v1/contacts/block/$userId');
    _blockedUsers.remove(userId);
    logger.i('🚫 User unblocked: $userId');
  }

  /// Проверить, заблокирован ли пользователь
  bool isBlocked(String userId) => _blockedUsers.contains(userId);

  /// Загрузить список заблокированных
  Future<void> loadBlockList() async {
    try {
      final response = await _apiClient.get('/api/v1/contacts/blocked');
      final list = (response.asList).cast<Map<String, dynamic>>();
      _blockedUsers.clear();
      for (final item in list) {
        final userId = item['contact_user_id'] as String? ?? item['userId'] as String? ?? '';
        if (userId.isNotEmpty) _blockedUsers.add(userId);
      }
      logger.i('🚫 Block list loaded: ${_blockedUsers.length} users');
    } catch (e) {
      logger.e('🚫 Failed to load block list: $e');
    }
  }

  /// Получить все заблокированные ID
  Set<String> get blockedUserIds => Set.from(_blockedUsers);
}
