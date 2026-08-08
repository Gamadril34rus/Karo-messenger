// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import '../domain/charo_repository.dart';
import '../network/api_client.dart';
import '../network/ws_client.dart';
import '../../features/chat/data/chat_item.dart';
import '../../features/chat/data/message_item.dart';
import '../../features/contacts/data/contact_item.dart';
import '../../features/calls/data/call_item.dart';
import '../../features/stories/data/story_item.dart';
import '../../features/nearby/data/nearby_user.dart';
import '../utils/logger.dart';

/// CharoApiRepository — реализация CharoRepository для текущего Fastify-сервера.
///
/// Содержит маппинг JSON → Dart-модели. При замене сервера нужно создать
/// только новую реализацию CharoRepository (например, CharoSupabaseRepository),
/// а все BLoC-и останутся без изменений.
class CharoApiRepository implements CharoRepository {
  final ApiClient _apiClient;
  final WsClient _wsClient;

  CharoApiRepository({required ApiClient apiClient, required WsClient wsClient})
      : _apiClient = apiClient,
        _wsClient = wsClient;

  // ─── Auth ──────────────────────────────────────────────────────

  @override
  Future<AuthResult> login(String identifier, String method) async {
    await _apiClient.post('/api/v1/auth/login', data: {
      'identifier': identifier,
      'method': method,
    });
    // Server sends OTP — no tokens yet
    return AuthResult(
      accessToken: '',
      refreshToken: '',
      userId: '',
      username: '',
    );
  }

  @override
  Future<AuthResult> verifyOtp(String identifier, String code, String method) async {
    final response = await _apiClient.post('/api/v1/auth/verify', data: {
      'identifier': identifier,
      'code': code,
      'method': method,
    });
    final data = response.asMap;

    if (data['requires_2fa'] == true) {
      return AuthResult(
        accessToken: '',
        refreshToken: '',
        userId: '',
        username: '',
        requires2fa: true,
        tempToken: data['temp_token'] as String? ?? '',
      );
    }

    return AuthResult(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      userId: data['user']['id'] as String,
      username: data['user']['username'] as String,
      displayName: data['user']['display_name'] as String?,
      avatarUrl: data['user']['avatar_url'] as String?,
    );
  }

  @override
  Future<AuthResult> register({
    required String username,
    required String displayName,
    String? phone,
    String? email,
    required bool consentGiven,
    required bool ageConfirmed,
    required bool termsAccepted,
  }) async {
    await _apiClient.post('/api/v1/auth/register', data: {
      'username': username,
      'display_name': displayName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      'consent_given': consentGiven,
      'age_confirmed': ageConfirmed,
      'terms_accepted': termsAccepted,
    });
    return AuthResult(accessToken: '', refreshToken: '', userId: '', username: username);
  }

  @override
  Future<void> logout() async {
    try { await _apiClient.post('/api/v1/auth/logout'); } catch (_) {}
  }

  @override
  Future<AccountDeletionResult> deleteAccount(String confirmation) async {
    final response = await _apiClient.delete('/api/v1/auth/account', data: {
      'confirmation': confirmation,
    });
    final data = response.asMap;
    return AccountDeletionResult(
      accountId: data['account_id'] as String? ?? '',
      recoveryCode: data['recovery_code'] as String? ?? '',
    );
  }

  @override
  Future<AccountRecoveryResult> recoverAccount(String accountId, String recoveryCode) async {
    final response = await _apiClient.post('/api/v1/auth/recover', data: {
      'account_id': accountId,
      'verification_code': recoveryCode,
    });
    final data = response.asMap;
    return AccountRecoveryResult(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      userId: data['user']?['id'] as String? ?? '',
    );
  }

  @override
  Future<AuthResult> verify2fa(String tempToken, String code) async {
    final response = await _apiClient.post('/api/v1/auth/2fa/verify', data: {
      'temp_token': tempToken,
      'code': code,
    });
    final data = response.asMap;
    return AuthResult(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      userId: data['user']['id'] as String,
      username: data['user']['username'] as String,
      displayName: data['user']['display_name'] as String?,
      avatarUrl: data['user']['avatar_url'] as String?,
    );
  }

  @override
  Future<AuthResult> refreshTokens() async {
    final response = await _apiClient.post('/api/v1/auth/refresh');
    final data = response.asMap;
    return AuthResult(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      userId: '',
      username: '',
    );
  }

  // ─── Chats ─────────────────────────────────────────────────────

  @override
  Future<List<ChatItem>> getChats({bool includeArchived = false}) async {
    final response = await _apiClient.get('/api/v1/chats',
        queryParameters: {'include_archived': includeArchived.toString()});
    final data = response.asMap;
    final chatList = (data['data'] as List<dynamic>?) ?? [];
    return chatList.map(_mapChatItem).toList();
  }

  ChatItem _mapChatItem(dynamic json) {
    final j = json as Map<String, dynamic>;
    return ChatItem(
      id: j['id'] as String? ?? '',
      title: j['title'] as String?,
      avatarUrl: j['avatar_url'] as String?,
      lastMessage: j['last_message'] as String?,
      lastMessageAt: j['last_message_at'] != null
          ? DateTime.tryParse(j['last_message_at'].toString())
          : null,
      unreadCount: j['unread_count'] as int? ?? 0,
      isOnline: j['is_online'] as bool? ?? false,
      isPinned: j['is_pinned'] as bool? ?? false,
      isMuted: j['is_muted'] as bool? ?? false,
      isArchived: j['is_archived'] as bool? ?? false,
    );
  }

  @override
  Future<ChatItem> createChat(String type, String? title, List<String>? memberIds) async {
    final response = await _apiClient.post('/api/v1/chats', data: {
      'type': type,
      if (title != null) 'title': title,
      if (memberIds != null) 'memberIds': memberIds,
    });
    return _mapChatItem(response.asMap);
  }

  @override
  Future<void> pinChat(String chatId, bool pinned) async {
    await _apiClient.patch('/api/v1/chats/$chatId/pin', data: {'pinned': pinned});
  }

  @override
  Future<void> muteChat(String chatId, bool muted) async {
    await _apiClient.patch('/api/v1/chats/$chatId/mute', data: {'muted': muted});
  }

  @override
  Future<void> archiveChat(String chatId, bool archived) async {
    await _apiClient.patch('/api/v1/chats/$chatId/archive', data: {'archived': archived});
  }

  @override
  Future<void> deleteChat(String chatId) async {
    await _apiClient.delete('/api/v1/chats/$chatId');
  }

  // ─── Messages ──────────────────────────────────────────────────

  @override
  Future<List<MessageItem>> getMessages(String chatId, {int limit = 50, String? afterId}) async {
    final response = await _apiClient.get('/api/v1/chats/$chatId/messages',
        queryParameters: {'limit': limit.toString(), if (afterId != null) 'after_id': afterId});
    return (response.asList).map(_mapMessageItem).toList();
  }

  MessageItem _mapMessageItem(dynamic json) {
    final j = json as Map<String, dynamic>;
    return MessageItem(
      id: j['id'] as String? ?? '',
      chatId: j['chatId'] as String? ?? j['chat_id'] as String? ?? '',
      senderId: j['senderId'] as String? ?? j['sender_id'] as String? ?? '',
      type: j['type'] as String? ?? 'text',
      content: j['content']?.toString(),
      isEdited: j['isEdited'] as bool? ?? j['is_edited'] as bool? ?? false,
      isRead: j['isRead'] as bool? ?? false,
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  Future<MessageItem> sendMessage(String chatId, String type, dynamic content) async {
    _wsClient.send('message.send', {
      'chatId': chatId,
      'type': type,
      'content': content,
    });
    return MessageItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: chatId,
      senderId: '',
      type: type,
      content: content?.toString(),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<MessageItem> editMessage(String messageId, dynamic content) async {
    final response = await _apiClient.patch('/api/v1/messages/$messageId', data: {
      'content': content,
    });
    return _mapMessageItem(response.asMap);
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await _apiClient.delete('/api/v1/messages/$messageId');
  }

  @override
  Future<void> reactToMessage(String messageId, String emoji) async {
    await _apiClient.post('/api/v1/messages/$messageId/react', data: {'emoji': emoji});
  }

  // ─── Contacts ──────────────────────────────────────────────────

  @override
  Future<List<ContactItem>> getContacts() async {
    final response = await _apiClient.get('/api/v1/contacts');
    return (response.asList).map((json) {
      final j = json as Map<String, dynamic>;
      return ContactItem(
        userId: j['contact_user_id'] as String? ?? j['user_id'] as String? ?? '',
        displayName: j['display_name'] as String? ?? j['contact_user']?['display_name'] as String? ?? 'Без имени',
        username: j['contact_user']?['username'] as String? ?? '',
        avatarUrl: j['contact_user']?['avatar_url'] as String?,
        isOnline: j['contact_user']?['is_online'] as bool? ?? false,
      );
    }).toList();
  }

  @override
  Future<void> addContact(String identifier) async {
    await _apiClient.post('/api/v1/contacts', data: {'identifier': identifier});
  }

  @override
  Future<void> deleteContact(String userId) async {
    await _apiClient.delete('/api/v1/contacts/$userId');
  }

  @override
  Future<void> syncContacts(List<String> phones) async {
    await _apiClient.post('/api/v1/contacts/sync', data: {'phones': phones});
  }

  @override
  Future<void> blockUser(String userId) async {
    await _apiClient.post('/api/v1/contacts/block', data: {'userId': userId});
  }

  @override
  Future<void> unblockUser(String userId) async {
    await _apiClient.delete('/api/v1/contacts/block/$userId');
  }

  // ─── Calls ────────────────────────────────────────────────────

  @override
  Future<List<CallItem>> getCallsHistory() async {
    final response = await _apiClient.get('/api/v1/calls/history');
    final data = response.asMap;
    final callsList = (data['data'] as List<dynamic>?) ?? [];
    return callsList.map((json) {
      final j = json as Map<String, dynamic>;
      return CallItem(
        id: j['id'] as String,
        name: j['caller']?['display_name'] as String?,
        avatarUrl: j['caller']?['avatar_url'] as String?,
        type: j['type'] as String? ?? 'voice',
        direction: j['direction'] as String? ?? 'outgoing',
        status: j['status'] as String? ?? 'ended',
        time: j['started_at'] != null ? DateTime.parse(j['started_at'] as String) : DateTime.now(),
        duration: j['duration_sec'] as int?,
      );
    }).toList();
  }

  // ─── Stories ───────────────────────────────────────────────────

  @override
  Future<List<StoryItem>> getStories() async {
    final response = await _apiClient.get('/api/v1/stories');
    final data = response.asMap;
    final storiesList = (data['data'] as List<dynamic>?) ?? [];
    return storiesList.map((json) {
      final j = json as Map<String, dynamic>;
      final storyItems = (j['stories'] as List<dynamic>?) ?? [];
      final items = storyItems.map<StoryContentItem>((s) {
        final sm = s as Map<String, dynamic>;
        return StoryContentItem(
          id: sm['id'] as String? ?? '',
          type: _mapStoryType(sm['type'] as String?),
          mediaUrl: sm['mediaUrl'] as String? ?? sm['media_url'] as String?,
          textContent: sm['content'] as String?,
          backgroundColor: sm['backgroundColor'] as String? ?? sm['background_color'] as String?,
          createdAt: sm['createdAt'] != null ? DateTime.tryParse(sm['createdAt'].toString()) : null,
          isViewed: (sm['views'] as List?)?.isNotEmpty ?? false,
          viewCount: (sm['views'] as List?)?.length ?? 0,
        );
      }).toList();

      return StoryItem(
        userId: j['userId'] as String? ?? j['user_id'] as String? ?? '',
        userName: j['userName'] as String? ?? j['user']?['display_name'] as String?,
        avatarUrl: j['avatarUrl'] as String? ?? j['user']?['avatar_url'] as String?,
        type: items.isNotEmpty ? items.first.type : 'image',
        count: items.length,
        isViewed: items.every((i) => i.isViewed),
        items: items,
      );
    }).toList();
  }

  String _mapStoryType(String? type) {
    if (type == null) return 'image';
    final lower = type.toLowerCase();
    if (lower == 'video') return 'video';
    if (lower == 'text') return 'text';
    return 'image';
  }

  @override
  Future<void> publishStory(String type, {String? mediaUrl, String? textContent, String? backgroundColor}) async {
    final data = <String, dynamic>{'type': type.toUpperCase()};
    if (type == 'text') {
      data['content'] = textContent ?? '';
      data['background_color'] = backgroundColor ?? '#6366F1';
    } else if (mediaUrl != null) {
      data['media_url'] = mediaUrl;
    }
    await _apiClient.post('/api/v1/stories', data: data);
  }

  @override
  Future<void> viewStory(String storyId) async {
    await _apiClient.get('/api/v1/stories/$storyId/views');
  }

  @override
  Future<void> deleteStory(String storyId) async {
    await _apiClient.delete('/api/v1/stories/$storyId');
  }

  // ─── Profile ───────────────────────────────────────────────────

  @override
  Future<ProfileResult> getMyProfile() async {
    final response = await _apiClient.get('/api/v1/users/me');
    return _mapProfileResult(response.asMap);
  }

  @override
  Future<ProfileResult> getUserProfile(String userId) async {
    final response = await _apiClient.get('/api/v1/users/$userId');
    return _mapProfileResult(response.asMap);
  }

  ProfileResult _mapProfileResult(Map<String, dynamic> data) {
    return ProfileResult(
      userId: data['id'] as String,
      username: data['username'] as String,
      displayName: data['display_name'] as String?,
      bio: data['bio'] as String?,
      avatarUrl: data['avatar_url'] as String?,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      isOnline: data['is_online'] as bool? ?? false,
      lastSeen: data['last_seen'] != null ? DateTime.tryParse(data['last_seen'].toString()) : null,
      phoneVisible: data['phone_visible'] as bool? ?? true,
    );
  }

  @override
  Future<void> updateProfile({String? displayName, String? bio}) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (bio != null) data['bio'] = bio;
    await _apiClient.patch('/api/v1/users/me', data: data);
  }

  @override
  Future<String?> changeAvatar(String source) async {
    if (source == 'remove') {
      await _apiClient.patch('/api/v1/users/me', data: {'avatar_url': null});
      return null;
    }
    if (source == 'ai') {
      final response = await _apiClient.post('/api/v1/ai/generate-avatar', data: {'prompt': 'avatar'});
      return response.asMap['url'] as String?;
    }
    final response = await _apiClient.patch('/api/v1/users/me/avatar', data: {'source': source});
    return response.asMap['avatar_url'] as String?;
  }

  // ─── Settings ──────────────────────────────────────────────────

  @override
  Future<SettingsResult> getSettings() async {
    final response = await _apiClient.get('/api/v1/settings');
    final data = response.asMap;
    return SettingsResult(
      privacy: data['privacy'] as Map<String, dynamic>? ?? {},
      notifications: data['notifications'] as Map<String, dynamic>? ?? {},
      language: data['language'] as String? ?? 'ru',
    );
  }

  @override
  Future<void> updatePrivacy(Map<String, dynamic> data) async {
    await _apiClient.patch('/api/v1/settings/privacy', data: data);
  }

  @override
  Future<void> updateNotifications(Map<String, dynamic> data) async {
    await _apiClient.patch('/api/v1/settings/notifications', data: data);
  }

  @override
  Future<void> updateAppearance(Map<String, dynamic> data) async {
    await _apiClient.patch('/api/v1/settings/appearance', data: data);
  }

  // ─── Search ────────────────────────────────────────────────────

  @override
  Future<SearchResult> search(String query) async {
    final response = await _apiClient.get('/api/v1/search', queryParameters: {'q': query});
    final data = response.asMap;
    return SearchResult(
      chats: ((data['chats'] as List<dynamic>?) ?? []).map(_mapChatItem).toList(),
      messages: ((data['messages'] as List<dynamic>?) ?? []).map(_mapMessageItem).toList(),
      contacts: ((data['contacts'] as List<dynamic>?) ?? []).map((json) {
        final j = json as Map<String, dynamic>;
        return ContactItem(
          userId: j['id'] as String? ?? '',
          displayName: j['display_name'] as String? ?? 'Без имени',
          username: j['username'] as String? ?? '',
          avatarUrl: j['avatar_url'] as String?,
        );
      }).toList(),
    );
  }

  // ─── Nearby ────────────────────────────────────────────────────

  @override
  Future<List<NearbyUser>> getNearbyUsers(double lat, double lng, {int radius = 1000}) async {
    final response = await _apiClient.get('/api/v1/nearby',
        queryParameters: {'lat': lat.toString(), 'lng': lng.toString(), 'radius': radius.toString()});
    final data = response.asMap;
    final usersList = (data['data'] as List<dynamic>?) ?? [];
    return usersList.map((json) {
      final j = json as Map<String, dynamic>;
      return NearbyUser(
        userId: j['user_id'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        distance: j['distance'] as String? ?? '? м',
        status: j['status'] as String?,
      );
    }).toList();
  }

  // ─── AI ────────────────────────────────────────────────────────

  @override
  Future<AiChatResult> sendAiMessage(String message, {String? conversationId}) async {
    final response = await _apiClient.post('/api/v1/ai/chat', data: {
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
    });
    final data = response.asMap;
    return AiChatResult(
      conversationId: data['conversation_id'] as String? ?? '',
      content: data['content'] as String? ?? '',
    );
  }

  @override
  Future<String> summarizeChat(String chatId) async {
    final response = await _apiClient.post('/api/v1/ai/summarize', data: {'chat_id': chatId});
    return response.asMap['summary'] as String? ?? 'Саммаризация недоступна';
  }

  // ─── Data Export ───────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> exportData() async {
    final response = await _apiClient.get('/api/v1/auth/export-data');
    return response.asMap;
  }

  // ─── Chat Advanced ─────────────────────────────────────────────

  @override
  Future<List<ChatMemberResult>> getChatMembers(String chatId) async {
    final response = await _apiClient.get('/api/v1/chats/$chatId');
    final data = response.asMap;
    final membersList = (data['members'] as List<dynamic>?) ?? [];
    return membersList.map((json) {
      final j = json as Map<String, dynamic>;
      final user = j['user'] as Map<String, dynamic>? ?? j;
      return ChatMemberResult(
        userId: (user['id'] ?? j['userId'] ?? '') as String,
        username: (user['username'] ?? '') as String,
        displayName: user['display_name'] as String? ?? user['displayName'] as String?,
        avatarUrl: user['avatar_url'] as String? ?? user['avatarUrl'] as String?,
        role: (j['role'] ?? 'MEMBER') as String,
        isOnline: (user['is_online'] ?? user['isOnline'] ?? false) as bool,
      );
    }).toList();
  }

  @override
  Future<void> addChatMembers(String chatId, List<String> userIds) async {
    for (final userId in userIds) {
      await _apiClient.post('/api/v1/chats/$chatId/members', data: {'userId': userId});
    }
  }

  @override
  Future<void> leaveGroup(String chatId) async {
    await _apiClient.post('/api/v1/chats/$chatId/leave');
  }

  @override
  Future<void> deleteGroup(String chatId) async {
    await _apiClient.delete('/api/v1/chats/$chatId');
  }

  @override
  Future<void> updateGroupInfo(String chatId, {String? title, String? avatarUrl}) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    await _apiClient.patch('/api/v1/chats/$chatId', data: data);
  }

  @override
  Future<void> updateMemberRole(String chatId, String userId, String role) async {
    await _apiClient.patch('/api/v1/chats/$chatId/members/$userId', data: {'role': role});
  }

  @override
  Future<void> removeMember(String chatId, String userId) async {
    await _apiClient.delete('/api/v1/chats/$chatId/members/$userId');
  }

  @override
  Future<Map<String, dynamic>> exportChat(String chatId) async {
    final response = await _apiClient.get('/api/v1/chats/$chatId/export');
    return response.asMap;
  }

  @override
  Future<void> clearChatHistory(String chatId) async {
    await _apiClient.delete('/api/v1/chats/$chatId/messages');
  }

  @override
  Future<List<MessageItem>> searchMessagesInChat(String chatId, String query) async {
    final response = await _apiClient.get(
      '/api/v1/chats/$chatId/search',
      queryParameters: {'q': query},
    );
    return (response.asList).map(_mapMessageItem).toList();
  }

  // ─── OAuth ─────────────────────────────────────────────────────

  @override
  Future<OAuthResult> getOAuthUrl(String provider) async {
    final response = await _apiClient.get('/api/v1/auth/oauth/$provider');
    final data = response.asMap;
    return OAuthResult(
      redirectUrl: data['redirect_url'] as String? ?? data['url'] as String? ?? '',
      state: data['state'] as String? ?? '',
    );
  }

  // ─── Search Users ──────────────────────────────────────────────

  @override
  Future<List<UserSearchResult>> searchUsers(String query) async {
    final response = await _apiClient.get(
      '/api/v1/users/search',
      queryParameters: {'q': query},
    );
    final data = response.asMap;
    final usersList = (data['data'] as List<dynamic>?) ?? [];
    return usersList.map((json) {
      final j = json as Map<String, dynamic>;
      return UserSearchResult(
        userId: j['id'] as String? ?? '',
        username: j['username'] as String? ?? '',
        displayName: j['display_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
      );
    }).toList();
  }

  // ─── AI Advanced ───────────────────────────────────────────────

  @override
  Future<List<AiConversationResult>> getAiConversations() async {
    final response = await _apiClient.get('/api/v1/ai/conversations');
    return (response.asList).map((json) {
      final j = json as Map<String, dynamic>;
      return AiConversationResult(
        id: j['id'] as String? ?? '',
        role: j['role'] as String? ?? 'assistant',
        content: j['content'] as String? ?? '',
        createdAt: j['created_at'] != null
            ? DateTime.parse(j['created_at'] as String)
            : DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<String> createAiConversation() async {
    final response = await _apiClient.post('/api/v1/ai/conversations');
    return response.asMap['id'] as String? ?? '';
  }

  @override
  Future<void> generateAiSticker(String prompt) async {
    await _apiClient.post('/api/v1/ai/sticker', data: {'prompt': prompt});
  }

  // ─── Network / Storage Settings ────────────────────────────────

  @override
  Future<void> updateNetwork(Map<String, dynamic> data) async {
    await _apiClient.patch('/api/v1/settings/network', data: data);
  }

  @override
  Future<void> updateStorage(Map<String, dynamic> data) async {
    await _apiClient.patch('/api/v1/settings/storage', data: data);
  }

  // ─── Block List ────────────────────────────────────────────────

  @override
  Future<List<BlockedUserResult>> getBlockedUsers() async {
    final response = await _apiClient.get('/api/v1/contacts/blocked');
    final data = response.asMap;
    final blockedList = (data['data'] as List<dynamic>?) ?? [];
    return blockedList.map((json) {
      final j = json as Map<String, dynamic>;
      final user = j['blocked_user'] as Map<String, dynamic>? ?? j['user'] as Map<String, dynamic>? ?? j;
      return BlockedUserResult(
        userId: user['id'] as String? ?? j['user_id'] as String? ?? '',
        displayName: user['display_name'] as String?,
        username: user['username'] as String?,
        avatarUrl: user['avatar_url'] as String?,
        blockedAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
    }).toList();
  }

  // ─── Sessions ──────────────────────────────────────────────────

  @override
  Future<List<SessionResult>> getSessions() async {
    final response = await _apiClient.get('/api/v1/auth/sessions');
    final data = response.asMap;
    final sessionsList = (data['data'] as List<dynamic>?) ?? [];
    return sessionsList.map((json) {
      final j = json as Map<String, dynamic>;
      return SessionResult(
        id: j['id'] as String? ?? '',
        deviceName: j['device_name'] as String? ?? j['deviceName'] as String? ?? 'Неизвестное устройство',
        ip: j['ip'] as String?,
        location: j['location'] as String?,
        lastActive: j['last_active'] != null
            ? DateTime.tryParse(j['last_active'].toString()) ?? DateTime.now()
            : DateTime.now(),
        isCurrent: j['is_current'] as bool? ?? false,
      );
    }).toList();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _apiClient.delete('/api/v1/auth/sessions/$sessionId');
  }

  @override
  Future<void> deleteAllSessions() async {
    await _apiClient.delete('/api/v1/auth/sessions', data: {'keep_current': true});
  }
}
