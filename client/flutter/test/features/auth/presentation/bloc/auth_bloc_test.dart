import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:charo_messenger/core/domain/charo_repository.dart';
import 'package:charo_messenger/core/storage/secure_storage.dart';
import 'package:charo_messenger/core/network/ws_client.dart';

/// Mock CharoRepository for testing
class _MockRepository implements CharoRepository {
  bool loginCalled = false;
  bool verifyCalled = false;
  bool registerCalled = false;
  bool logoutCalled = false;
  bool deleteAccountCalled = false;
  bool refreshCalled = false;
  bool oauthCalled = false;
  bool recoverCalled = false;
  bool twoFaVerifyCalled = false;
  bool getMyProfileCalled = false;

  AuthResult? verifyResult;
  AuthResult? registerResult;
  ProfileResult? getMyProfileResult;
  AccountDeletionResult? deleteAccountResult;
  AccountRecoveryResult? recoverResult;
  AuthResult? twoFaVerifyResult;
  AuthResult? refreshResult;
  OAuthResult? oauthResult;

  @override
  Future<AuthResult> login(String identifier, String method) async {
    loginCalled = true;
    return const AuthResult(accessToken: '', refreshToken: '', userId: '', username: '');
  }

  @override
  Future<AuthResult> verifyOtp(String identifier, String code, String method) async {
    verifyCalled = true;
    return verifyResult ?? const AuthResult(
      accessToken: 'test-access-token',
      refreshToken: 'test-refresh-token',
      userId: 'user-1',
      username: 'testuser',
      displayName: 'Test User',
    );
  }

  @override
  Future<AuthResult> register({required String username, required String displayName, String? phone, String? email, required bool consentGiven, required bool ageConfirmed, required bool termsAccepted}) async {
    registerCalled = true;
    return registerResult ?? const AuthResult(accessToken: '', refreshToken: '', userId: '', username: 'testuser');
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<AccountDeletionResult> deleteAccount(String confirmation) async {
    deleteAccountCalled = true;
    return deleteAccountResult ?? const AccountDeletionResult(accountId: 'acc-1', recoveryCode: 'rc-12345678');
  }

  @override
  Future<AccountRecoveryResult> recoverAccount(String accountId, String recoveryCode) async {
    recoverCalled = true;
    return recoverResult ?? const AccountRecoveryResult(accessToken: 'recovered-access', refreshToken: 'recovered-refresh', userId: 'user-1');
  }

  @override
  Future<AuthResult> verify2fa(String tempToken, String code) async {
    twoFaVerifyCalled = true;
    return twoFaVerifyResult ?? const AuthResult(
      accessToken: '2fa-access-token',
      refreshToken: '2fa-refresh-token',
      userId: 'user-1',
      username: 'testuser',
      displayName: 'Test User',
    );
  }

  @override
  Future<AuthResult> refreshTokens() async {
    refreshCalled = true;
    return refreshResult ?? const AuthResult(accessToken: 'new-access', refreshToken: 'new-refresh', userId: '', username: '');
  }

  @override
  Future<ProfileResult> getMyProfile() async {
    getMyProfileCalled = true;
    return getMyProfileResult ?? const ProfileResult(userId: 'user-1', username: 'testuser', displayName: 'Test User');
  }

  @override
  Future<OAuthResult> getOAuthUrl(String provider) async {
    oauthCalled = true;
    return oauthResult ?? const OAuthResult(redirectUrl: 'https://oauth.example.com', state: 'oauth-state-123');
  }

  // Stub methods not used in auth tests
  @override Future<List<ChatItem>> getChats({bool includeArchived = false}) async => [];
  @override Future<ChatItem> createChat(String type, String? title, List<String>? memberIds) async => ChatItem(id: 'c1', type: 'private');
  @override Future<void> pinChat(String chatId, bool pinned) async {}
  @override Future<void> muteChat(String chatId, bool muted) async {}
  @override Future<void> archiveChat(String chatId, bool archived) async {}
  @override Future<void> deleteChat(String chatId) async {}
  @override Future<List<MessageItem>> getMessages(String chatId, {int limit = 50, String? afterId}) async => [];
  @override Future<MessageItem> sendMessage(String chatId, String type, dynamic content) async => MessageItem(id: 'm1', chatId: chatId, senderId: '', type: 'text', content: '', createdAt: DateTime.now());
  @override Future<MessageItem> editMessage(String messageId, dynamic content) async => MessageItem(id: messageId, chatId: '', senderId: '', type: 'text', content: '', createdAt: DateTime.now());
  @override Future<void> deleteMessage(String messageId) async {}
  @override Future<void> reactToMessage(String messageId, String emoji) async {}
  @override Future<List<ContactItem>> getContacts() async => [];
  @override Future<void> addContact(String identifier) async {}
  @override Future<void> deleteContact(String userId) async {}
  @override Future<void> syncContacts(List<String> phones) async {}
  @override Future<void> blockUser(String userId) async {}
  @override Future<void> unblockUser(String userId) async {}
  @override Future<List<CallItem>> getCallsHistory() async => [];
  @override Future<List<StoryItem>> getStories() async => [];
  @override Future<void> publishStory(String type, {String? mediaUrl, String? textContent, String? backgroundColor}) async {}
  @override Future<void> viewStory(String storyId) async {}
  @override Future<void> deleteStory(String storyId) async {}
  @override Future<ProfileResult> getUserProfile(String userId) async => const ProfileResult(userId: 'u1', username: 'user');
  @override Future<void> updateProfile({String? displayName, String? bio}) async {}
  @override Future<String?> changeAvatar(String source) async => null;
  @override Future<SettingsResult> getSettings() async => const SettingsResult();
  @override Future<void> updatePrivacy(Map<String, dynamic> data) async {}
  @override Future<void> updateNotifications(Map<String, dynamic> data) async {}
  @override Future<void> updateAppearance(Map<String, dynamic> data) async {}
  @override Future<SearchResult> search(String query) async => const SearchResult();
  @override Future<List<NearbyUser>> getNearbyUsers(double lat, double lng, {int radius = 1000}) async => [];
  @override Future<AiChatResult> sendAiMessage(String message, {String? conversationId}) async => const AiChatResult(conversationId: '', content: '');
  @override Future<String> summarizeChat(String chatId) async => '';
  @override Future<Map<String, dynamic>> exportData() async => {};
  @override Future<List<ChatMemberResult>> getChatMembers(String chatId) async => [];
  @override Future<void> addChatMembers(String chatId, List<String> userIds) async {}
  @override Future<void> leaveGroup(String chatId) async {}
  @override Future<void> deleteGroup(String chatId) async {}
  @override Future<void> updateGroupInfo(String chatId, {String? title, String? avatarUrl}) async {}
  @override Future<void> updateMemberRole(String chatId, String userId, String role) async {}
  @override Future<void> removeMember(String chatId, String userId) async {}
  @override Future<Map<String, dynamic>> exportChat(String chatId) async => {};
  @override Future<void> clearChatHistory(String chatId) async {}
  @override Future<List<MessageItem>> searchMessagesInChat(String chatId, String query) async => [];
  @override Future<List<UserSearchResult>> searchUsers(String query) async => [];
  @override Future<List<AiConversationResult>> getAiConversations() async => [];
  @override Future<String> createAiConversation() async => '';
  @override Future<void> generateAiSticker(String prompt) async {}
  @override Future<void> updateNetwork(Map<String, dynamic> data) async {}
  @override Future<void> updateStorage(Map<String, dynamic> data) async {}
  @override Future<List<BlockedUserResult>> getBlockedUsers() async => [];
  @override Future<List<SessionResult>> getSessions() async => [];
  @override Future<void> deleteSession(String sessionId) async {}
  @override Future<void> deleteAllSessions() async {}
}

class _MockSecureStorage extends SecureStorageHelper {
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _oauthState;
  bool _cleared = false;

  _MockSecureStorage();

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<void> setAccessToken(String token) async => _accessToken = token;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> setRefreshToken(String token) async => _refreshToken = token;

  @override
  Future<void> setUserId(String id) async => _userId = id;

  @override
  Future<void> setOAuthState({required String provider, required String state}) async => _oauthState = state;

  @override
  Future<void> clearAll() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _oauthState = null;
    _cleared = true;
  }
}

class _MockWsClient extends WsClient {
  bool _connected = false;

  _MockWsClient() : super(baseUrl: 'ws://test');

  @override
  Future<void> connect() async => _connected = true;

  @override
  Future<void> disconnect() async => _connected = false;

  bool get isConnected => _connected;
}

void main() {
  group('AuthBloc', () {
    late AuthBloc authBloc;
    late _MockRepository mockRepository;
    late _MockSecureStorage mockSecureStorage;
    late _MockWsClient mockWsClient;

    setUp(() {
      mockRepository = _MockRepository();
      mockSecureStorage = _MockSecureStorage();
      mockWsClient = _MockWsClient();
      authBloc = AuthBloc(
        repository: mockRepository,
        secureStorage: mockSecureStorage,
        wsClient: mockWsClient,
      );
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state is AuthInitial', () {
      expect(authBloc.state, isA<AuthInitial>());
    });

    test('AuthCheckRequested with no token yields AuthUnauthenticated', () async {
      authBloc.add(AuthCheckRequested());
      await expectLater(
        authBloc.stream,
        emitsInOrder([isA<AuthLoading>(), isA<AuthUnauthenticated>()]),
      );
    });

    test('AuthLoginRequested yields AuthOtpSent', () async {
      authBloc.add(AuthLoginRequested(identifier: '+79991234567', method: 'phone'));
      await expectLater(
        authBloc.stream,
        emitsInOrder([isA<AuthLoading>(), isA<AuthOtpSent>()]),
      );
      expect(mockRepository.loginCalled, isTrue);
    });

    test('AuthOtpSubmitted yields AuthAuthenticated', () async {
      authBloc.add(AuthOtpSubmitted(
        identifier: '+79991234567',
        code: '123456',
        method: 'phone',
      ));
      await expectLater(
        authBloc.stream,
        emitsInOrder([isA<AuthLoading>(), isA<AuthAuthenticated>()]),
      );
      expect(mockRepository.verifyCalled, isTrue);
    });

    test('AuthOtpSubmitted with 2FA required yields Auth2faRequired', () async {
      mockRepository.verifyResult = const AuthResult(
        accessToken: '', refreshToken: '', userId: '', username: '',
        requires2fa: true, tempToken: 'temp-token-123',
      );

      authBloc.add(AuthOtpSubmitted(
        identifier: '+79991234567',
        code: '123456',
        method: 'phone',
      ));
      await expectLater(
        authBloc.stream,
        emitsInOrder([isA<AuthLoading>(), isA<Auth2faRequired>()]),
      );
    });

    test('AuthRegisterRequested yields AuthOtpSent', () async {
      authBloc.add(AuthRegisterRequested(
        username: 'testuser',
        displayName: 'Test User',
        phone: '+79991234567',
        consentGiven: true,
        ageConfirmed: true,
        termsAccepted: true,
      ));
      await expectLater(
        authBloc.stream,
        emitsInOrder([isA<AuthLoading>(), isA<AuthOtpSent>()]),
      );
      expect(mockRepository.registerCalled, isTrue);
    });

    test('AuthLogoutRequested yields AuthUnauthenticated', () async {
      authBloc.add(AuthLogoutRequested());
      await expectLater(
        authBloc.stream,
        [isA<AuthUnauthenticated>()],
      );
      expect(mockRepository.logoutCalled, isTrue);
    });

    test('AuthDeleteAccountRequested with wrong confirmation yields AuthError', () async {
      authBloc.add(AuthDeleteAccountRequested(confirmation: 'WRONG'));
      await expectLater(
        authBloc.stream,
        [isA<AuthError>()],
      );
    });

    test('AuthDeleteAccountRequested with DELETE confirmation yields AuthAccountDeleted', () async {
      authBloc.add(AuthDeleteAccountRequested(confirmation: 'DELETE'));
      await expectLater(
        authBloc.stream,
        emitsInOrder([isA<AuthLoading>(), isA<AuthAccountDeleted>()]),
      );
      expect(mockRepository.deleteAccountCalled, isTrue);
    });
  });
}
