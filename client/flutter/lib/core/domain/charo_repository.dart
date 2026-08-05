// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import '../../features/chat/data/chat_item.dart';
import '../../features/chat/data/message_item.dart';
import '../../features/contacts/data/contact_item.dart';
import '../../features/calls/data/call_item.dart';
import '../../features/stories/data/story_item.dart';
import '../../features/nearby/data/nearby_user.dart';
import '../../features/ai_assistant/data/ai_message.dart';
import '../network/api_client.dart';

/// CharoRepository — абстрактный интерфейс для всех операций с сервером.
///
/// BLoC-и работают только через этот интерфейс и не знают
/// о конкретной реализации (Fastify, Supabase, Firebase и т.д.).
///
/// Замена сервера = создание новой реализации CharoRepository
/// + переключение DI в main.dart.
abstract class CharoRepository {
  // ─── Auth ──────────────────────────────────────────────────────

  Future<AuthResult> login(String identifier, String method);

  Future<AuthResult> verifyOtp(String identifier, String code, String method);

  Future<AuthResult> register({
    required String username,
    required String displayName,
    String? phone,
    String? email,
    required bool consentGiven,
    required bool ageConfirmed,
    required bool termsAccepted,
  });

  Future<void> logout();

  Future<AccountDeletionResult> deleteAccount(String confirmation);

  Future<AccountRecoveryResult> recoverAccount(String accountId, String recoveryCode);

  Future<AuthResult> verify2fa(String tempToken, String code);

  Future<AuthResult> refreshTokens();

  // ─── Chats ─────────────────────────────────────────────────────

  Future<List<ChatItem>> getChats({bool includeArchived = false});

  Future<ChatItem> createChat(String type, String? title, List<String>? memberIds);

  Future<void> pinChat(String chatId, bool pinned);

  Future<void> muteChat(String chatId, bool muted);

  Future<void> archiveChat(String chatId, bool archived);

  Future<void> deleteChat(String chatId);

  // ─── Messages ──────────────────────────────────────────────────

  Future<List<MessageItem>> getMessages(String chatId, {int limit = 50, String? afterId});

  Future<MessageItem> sendMessage(String chatId, String type, dynamic content);

  Future<MessageItem> editMessage(String messageId, dynamic content);

  Future<void> deleteMessage(String messageId);

  Future<void> reactToMessage(String messageId, String emoji);

  // ─── Contacts ──────────────────────────────────────────────────

  Future<List<ContactItem>> getContacts();

  Future<void> addContact(String identifier);

  Future<void> deleteContact(String userId);

  Future<void> syncContacts(List<String> phones);

  Future<void> blockUser(String userId);

  Future<void> unblockUser(String userId);

  // ─── Calls ────────────────────────────────────────────────────

  Future<List<CallItem>> getCallsHistory();

  // ─── Stories ───────────────────────────────────────────────────

  Future<List<StoryItem>> getStories();

  Future<void> publishStory(String type, {String? mediaUrl, String? textContent, String? backgroundColor});

  Future<void> viewStory(String storyId);

  Future<void> deleteStory(String storyId);

  // ─── Profile ───────────────────────────────────────────────────

  Future<ProfileResult> getMyProfile();

  Future<ProfileResult> getUserProfile(String userId);

  Future<void> updateProfile({String? displayName, String? bio});

  Future<String?> changeAvatar(String source);

  // ─── Settings ──────────────────────────────────────────────────

  Future<SettingsResult> getSettings();

  Future<void> updatePrivacy(Map<String, dynamic> data);

  Future<void> updateNotifications(Map<String, dynamic> data);

  Future<void> updateAppearance(Map<String, dynamic> data);

  // ─── Search ────────────────────────────────────────────────────

  Future<SearchResult> search(String query);

  // ─── Nearby ────────────────────────────────────────────────────

  Future<List<NearbyUser>> getNearbyUsers(double lat, double lng, {int radius = 1000});

  // ─── AI ────────────────────────────────────────────────────────

  Future<AiChatResult> sendAiMessage(String message, {String? conversationId});

  Future<String> summarizeChat(String chatId);

  // ─── Data Export ───────────────────────────────────────────────

  Future<Map<String, dynamic>> exportData();

  // ─── Chat Advanced ─────────────────────────────────────────────

  Future<List<ChatMemberResult>> getChatMembers(String chatId);

  Future<void> addChatMembers(String chatId, List<String> userIds);

  Future<void> leaveGroup(String chatId);

  Future<void> deleteGroup(String chatId);

  Future<void> updateGroupInfo(String chatId, {String? title, String? avatarUrl});

  Future<void> updateMemberRole(String chatId, String userId, String role);

  Future<void> removeMember(String chatId, String userId);

  Future<Map<String, dynamic>> exportChat(String chatId);

  Future<void> clearChatHistory(String chatId);

  Future<List<MessageItem>> searchMessagesInChat(String chatId, String query);

  // ─── OAuth ─────────────────────────────────────────────────────

  Future<OAuthResult> getOAuthUrl(String provider);

  // ─── Search Users ──────────────────────────────────────────────

  Future<List<UserSearchResult>> searchUsers(String query);

  // ─── AI Advanced ───────────────────────────────────────────────

  Future<List<AiConversationResult>> getAiConversations();

  Future<String> createAiConversation();

  Future<void> generateAiSticker(String prompt);

  // ─── Network / Storage Settings ────────────────────────────────

  Future<void> updateNetwork(Map<String, dynamic> data);

  Future<void> updateStorage(Map<String, dynamic> data);

  // ─── Block List ────────────────────────────────────────────────

  Future<List<BlockedUserResult>> getBlockedUsers();

  // ─── Sessions ──────────────────────────────────────────────────

  Future<List<SessionResult>> getSessions();

  Future<void> deleteSession(String sessionId);

  Future<void> deleteAllSessions();
}

// ─── Result Models ──────────────────────────────────────────────────

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final bool requires2fa;
  final String? tempToken;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.requires2fa = false,
    this.tempToken,
  });
}

class AccountDeletionResult {
  final String accountId;
  final String recoveryCode;

  const AccountDeletionResult({required this.accountId, required this.recoveryCode});
}

class AccountRecoveryResult {
  final String accessToken;
  final String refreshToken;
  final String userId;

  const AccountRecoveryResult({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });
}

class ProfileResult {
  final String userId;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final String? phone;
  final String? email;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool phoneVisible;
  final bool isBlocked;

  const ProfileResult({
    required this.userId,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.phone,
    this.email,
    this.isOnline = false,
    this.lastSeen,
    this.phoneVisible = true,
    this.isBlocked = false,
  });
}

class SettingsResult {
  final Map<String, dynamic> privacy;
  final Map<String, dynamic> notifications;
  final String language;

  const SettingsResult({
    this.privacy = const {},
    this.notifications = const {},
    this.language = 'ru',
  });
}

class SearchResult {
  final List<ChatItem> chats;
  final List<MessageItem> messages;
  final List<ContactItem> contacts;

  const SearchResult({this.chats = const [], this.messages = const [], this.contacts = const []});
}

class AiChatResult {
  final String conversationId;
  final String content;

  const AiChatResult({required this.conversationId, required this.content});
}

class ChatMemberResult {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String role;
  final bool isOnline;

  const ChatMemberResult({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.role = 'MEMBER',
    this.isOnline = false,
  });
}

class OAuthResult {
  final String redirectUrl;
  final String state;

  const OAuthResult({required this.redirectUrl, required this.state});
}

class UserSearchResult {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  const UserSearchResult({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });
}

class AiConversationResult {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;

  const AiConversationResult({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });
}

class BlockedUserResult {
  final String userId;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final DateTime blockedAt;

  const BlockedUserResult({
    required this.userId,
    this.displayName,
    this.username,
    this.avatarUrl,
    required this.blockedAt,
  });
}

class SessionResult {
  final String id;
  final String deviceName;
  final String? ip;
  final String? location;
  final DateTime lastActive;
  final bool isCurrent;

  const SessionResult({
    required this.id,
    required this.deviceName,
    this.ip,
    this.location,
    required this.lastActive,
    this.isCurrent = false,
  });
}
