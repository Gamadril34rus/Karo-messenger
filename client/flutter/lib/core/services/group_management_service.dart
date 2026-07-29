import '../network/api_client.dart';
import '../utils/logger.dart';

/// ─── Group Management Service ────────────────────────────────────
/// Управление группами: создание, изменение названия/аватара,
/// управление участниками и ролями.

class GroupManagementService {
  final ApiClient _apiClient;

  GroupManagementService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Создать группу
  Future<GroupInfo> createGroup({
    required String title,
    required List<String> memberIds,
    String? avatarUrl,
  }) async {
    final response = await _apiClient.post('/api/v1/chats', data: {
      'type': 'group',
      'title': title,
      'member_ids': memberIds,
      'avatar_url': avatarUrl,
    });
    return GroupInfo.fromJson(response.asMap);
  }

  /// Создать канал
  Future<GroupInfo> createChannel({
    required String title,
    String? description,
    String? avatarUrl,
  }) async {
    final response = await _apiClient.post('/api/v1/chats', data: {
      'type': 'channel',
      'title': title,
      'description': description,
      'avatar_url': avatarUrl,
    });
    return GroupInfo.fromJson(response.asMap);
  }

  /// Обновить название/аватар группы
  Future<void> updateGroupInfo({
    required String chatId,
    String? title,
    String? avatarUrl,
    String? description,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    if (description != null) data['description'] = description;

    await _apiClient.patch('/api/v1/chats/$chatId', data: data);
    logger.i('👥 Group info updated: $chatId');
  }

  /// Добавить участника
  Future<void> addMember({
    required String chatId,
    required String userId,
    String role = 'MEMBER',
  }) async {
    await _apiClient.post('/api/v1/chats/$chatId/members', data: {
      'userId': userId,
      'role': role,
    });
    logger.i('👥 Member added: $userId to $chatId');
  }

  /// Удалить участника
  Future<void> removeMember({
    required String chatId,
    required String userId,
  }) async {
    await _apiClient.delete('/api/v1/chats/$chatId/members/$userId');
    logger.i('👥 Member removed: $userId from $chatId');
  }

  /// Изменить роль участника
  Future<void> updateMemberRole({
    required String chatId,
    required String userId,
    required String role,
  }) async {
    await _apiClient.patch('/api/v1/chats/$chatId/members/$userId', data: {
      'role': role,
    });
    logger.i('👥 Member role updated: $userId → $role');
  }

  /// Покинуть группу
  Future<void> leaveGroup(String chatId) async {
    await _apiClient.delete('/api/v1/chats/$chatId/members/me');
    logger.i('👥 Left group: $chatId');
  }

  /// Удалить группу (только OWNER)
  Future<void> deleteGroup(String chatId) async {
    await _apiClient.delete('/api/v1/chats/$chatId');
    logger.i('👥 Group deleted: $chatId');
  }
}

class GroupInfo {
  final String id;
  final String title;
  final String type;
  final String? avatarUrl;
  final String? description;
  final List<GroupMember> members;
  final int memberCount;

  const GroupInfo({
    required this.id,
    required this.title,
    required this.type,
    this.avatarUrl,
    this.description,
    this.members = const [],
    this.memberCount = 0,
  });

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'group',
      avatarUrl: json['avatar_url'] as String?,
      description: json['description'] as String?,
      members: (json['members'] as List?)?.map((m) => GroupMember.fromJson(m as Map<String, dynamic>)).toList() ?? [],
      memberCount: json['member_count'] as int? ?? 0,
    );
  }
}

class GroupMember {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String role; // OWNER, ADMIN, MEMBER

  const GroupMember({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.role = 'MEMBER',
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['displayName'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'MEMBER',
    );
  }
}
