import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:charo_messenger/core/network/api_client.dart';
import 'package:charo_messenger/core/storage/secure_storage.dart';
import 'package:charo_messenger/core/network/ws_client.dart';

/// Mock implementations for testing
class _MockApiClient extends ApiClient {
  bool loginCalled = false;
  bool verifyCalled = false;
  bool registerCalled = false;
  bool logoutCalled = false;
  bool deleteAccountCalled = false;
  bool refreshCalled = false;
  bool oauthCalled = false;
  bool recoverCalled = false;
  bool twoFaVerifyCalled = false;
  bool getMeCalled = false;

  Map<String, dynamic>? verifyResponse;
  Map<String, dynamic>? registerResponse;
  Map<String, dynamic>? getMeResponse;
  Map<String, dynamic>? deleteAccountResponse;
  Map<String, dynamic>? recoverResponse;
  Map<String, dynamic>? twoFaVerifyResponse;
  Map<String, dynamic>? refreshResponse;

  _MockApiClient() : super(baseUrl: 'http://test');

  @override
  Future<ApiResponse> post(String path, {Map<String, dynamic>? data}) async {
    if (path == '/api/v1/auth/login') {
      loginCalled = true;
      return ApiResponse(body: '{}');
    }
    if (path == '/api/v1/auth/verify') {
      verifyCalled = true;
      if (verifyResponse != null) {
        return ApiResponse(body: verifyResponse!);
      }
      return ApiResponse(body: {
        'access_token': 'test-access-token',
        'refresh_token': 'test-refresh-token',
        'user': {'id': 'user-1', 'username': 'testuser', 'display_name': 'Test User', 'avatar_url': null},
      });
    }
    if (path == '/api/v1/auth/register') {
      registerCalled = true;
      return ApiResponse(body: registerResponse ?? {});
    }
    if (path == '/api/v1/auth/logout') {
      logoutCalled = true;
      return ApiResponse(body: {});
    }
    if (path == '/api/v1/auth/account') {
      deleteAccountCalled = true;
      return ApiResponse(body: deleteAccountResponse ?? {
        'account_id': 'acc-1',
        'recovery_code': 'rc-12345678',
      });
    }
    if (path == '/api/v1/auth/refresh') {
      refreshCalled = true;
      return ApiResponse(body: refreshResponse ?? {
        'access_token': 'new-access-token',
        'refresh_token': 'new-refresh-token',
      });
    }
    if (path == '/api/v1/auth/2fa/verify') {
      twoFaVerifyCalled = true;
      return ApiResponse(body: twoFaVerifyResponse ?? {
        'access_token': '2fa-access-token',
        'refresh_token': '2fa-refresh-token',
        'user': {'id': 'user-1', 'username': 'testuser', 'display_name': 'Test User', 'avatar_url': null},
      });
    }
    if (path == '/api/v1/auth/recover') {
      recoverCalled = true;
      return ApiResponse(body: recoverResponse ?? {
        'access_token': 'recovered-access-token',
        'refresh_token': 'recovered-refresh-token',
      });
    }
    return ApiResponse(body: {});
  }

  @override
  Future<ApiResponse> get(String path) async {
    if (path == '/api/v1/users/me') {
      getMeCalled = true;
      return ApiResponse(body: getMeResponse ?? {
        'id': 'user-1',
        'username': 'testuser',
        'display_name': 'Test User',
        'avatar_url': null,
      });
    }
    if (path.startsWith('/api/v1/auth/oauth/')) {
      oauthCalled = true;
      return ApiResponse(body: {'state': 'oauth-state-123'});
    }
    return ApiResponse(body: {});
  }

  @override
  Future<ApiResponse> delete(String path, {Map<String, dynamic>? data}) async {
    if (path == '/api/v1/auth/account') {
      deleteAccountCalled = true;
      return ApiResponse(body: deleteAccountResponse ?? {
        'account_id': 'acc-1',
        'recovery_code': 'rc-12345678',
      });
    }
    return ApiResponse(body: {});
  }
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
    late _MockApiClient mockApiClient;
    late _MockSecureStorage mockSecureStorage;
    late _MockWsClient mockWsClient;

    setUp(() {
      mockApiClient = _MockApiClient();
      mockSecureStorage = _MockSecureStorage();
      mockWsClient = _MockWsClient();
      authBloc = AuthBloc(
        apiClient: mockApiClient,
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
      // No access token stored
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
      expect(mockApiClient.loginCalled, isTrue);
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
      expect(mockApiClient.verifyCalled, isTrue);
    });

    test('AuthOtpSubmitted with 2FA required yields Auth2faRequired', () async {
      mockApiClient.verifyResponse = {
        'requires_2fa': true,
        'temp_token': 'temp-token-123',
      };

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
      expect(mockApiClient.registerCalled, isTrue);
    });

    test('AuthLogoutRequested yields AuthUnauthenticated', () async {
      authBloc.add(AuthLogoutRequested());
      await expectLater(
        authBloc.stream,
        [isA<AuthUnauthenticated>()],
      );
      expect(mockApiClient.logoutCalled, isTrue);
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
      expect(mockApiClient.deleteAccountCalled, isTrue);
    });
  });
}
