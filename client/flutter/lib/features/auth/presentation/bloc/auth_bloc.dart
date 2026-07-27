import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/e2ee/e2ee_manager.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/network/ws_client.dart';
import '../../../../core/audio/notification_service.dart';
import '../../../../core/utils/logger.dart';

// ─── События ──────────────────────────────────────────────────────

sealed class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Проверка текущей авторизации при запуске
final class AuthCheckRequested extends AuthEvent {}

/// Запрос входа (телефон/email)
final class AuthLoginRequested extends AuthEvent {
  final String identifier;
  final String method; // 'phone' | 'email'

  AuthLoginRequested({required this.identifier, required this.method});

  @override
  List<Object?> get props => [identifier, method];
}

/// Верификация OTP-кода
final class AuthOtpSubmitted extends AuthEvent {
  final String identifier;
  final String code;
  final String method;

  AuthOtpSubmitted({
    required this.identifier,
    required this.code,
    required this.method,
  });

  @override
  List<Object?> get props => [identifier, code, method];
}

/// Запрос регистрации
final class AuthRegisterRequested extends AuthEvent {
  final String username;
  final String displayName;
  final String? phone;
  final String? email;
  final bool consentGiven;
  final bool ageConfirmed;
  final bool termsAccepted;

  AuthRegisterRequested({
    required this.username,
    required this.displayName,
    this.phone,
    this.email,
    required this.consentGiven,
    required this.ageConfirmed,
    required this.termsAccepted,
  });

  @override
  List<Object?> get props => [username, displayName, phone, email, consentGiven, ageConfirmed, termsAccepted];
}

/// OAuth авторизация
final class AuthOAuthRequested extends AuthEvent {
  final String provider; // 'google' | 'apple' | 'vk'

  AuthOAuthRequested({required this.provider});

  @override
  List<Object?> get props => [provider];
}

/// Включение 2FA
final class Auth2faEnabled extends AuthEvent {
  final String code;

  Auth2faEnabled({required this.code});

  @override
  List<Object?> get props => [code];
}

/// Верификация 2FA при входе (после OTP или пароля)
final class Auth2faVerifyRequested extends AuthEvent {
  final String tempToken;
  final String code;

  Auth2faVerifyRequested({required this.tempToken, required this.code});

  @override
  List<Object?> get props => [tempToken, code];
}

/// Выход
final class AuthLogoutRequested extends AuthEvent {}

/// Удаление аккаунта
final class AuthDeleteAccountRequested extends AuthEvent {
  final String confirmation; // Пользователь должен ввести "DELETE"

  AuthDeleteAccountRequested({required this.confirmation});

  @override
  List<Object?> get props => [confirmation];
}

/// Обновление токена
final class AuthRefreshRequested extends AuthEvent {}

/// Восстановление удалённого аккаунта (30-дневный grace period)
final class AuthAccountRecoveryRequested extends AuthEvent {
  final String accountId;
  final String recoveryCode;

  AuthAccountRecoveryRequested({required this.accountId, required this.recoveryCode});

  @override
  List<Object?> get props => [accountId, recoveryCode];
}

// ─── Состояния ────────────────────────────────────────────────────

sealed class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Начальное состояние
final class AuthInitial extends AuthState {}

/// Загрузка
final class AuthLoading extends AuthState {}

/// Пользователь авторизован
final class AuthAuthenticated extends AuthState {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  AuthAuthenticated({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [userId, username, displayName, avatarUrl];
}

/// Пользователь не авторизован
final class AuthUnauthenticated extends AuthState {}

/// OTP отправлен — ожидаем ввод кода
final class AuthOtpSent extends AuthState {
  final String identifier;
  final String method;
  final int expiresIn; // секунды

  AuthOtpSent({
    required this.identifier,
    required this.method,
    this.expiresIn = 120,
  });

  @override
  List<Object?> get props => [identifier, method, expiresIn];
}

/// Ошибка
final class AuthError extends AuthState {
  final String message;

  AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Аккаунт удалён — ожидание подтверждения удаления (recovery code returned)
final class AuthAccountDeleted extends AuthState {
  final String accountId;
  final String recoveryCode;

  AuthAccountDeleted({required this.accountId, required this.recoveryCode});

  @override
  List<Object?> get props => [accountId, recoveryCode];
}

/// Аккаунт восстановлен (30-дневный grace period)
final class AuthAccountRecovered extends AuthState {}

/// 2FA требуется — ожидаем ввод TOTP-кода
final class Auth2faRequired extends AuthState {
  final String tempToken;
  final String identifier;

  Auth2faRequired({required this.tempToken, required this.identifier});

  @override
  List<Object?> get props => [tempToken, identifier];
}

// ─── BLoC ─────────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient _apiClient;
  final SecureStorageHelper _secureStorage;
  final WsClient _wsClient;

  AuthBloc({
    required ApiClient apiClient,
    required SecureStorageHelper secureStorage,
    required WsClient wsClient,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage,
        _wsClient = wsClient,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthOtpSubmitted>(_onOtpSubmitted);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthOAuthRequested>(_onOAuthRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthDeleteAccountRequested>(_onDeleteAccountRequested);
    on<AuthRefreshRequested>(_onRefreshRequested);
    on<AuthAccountRecoveryRequested>(_onAccountRecoveryRequested);
    on<Auth2faVerifyRequested>(_on2faVerifyRequested);
  }

  // ─── Проверка авторизации ──────────────────────────────────────
  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final token = await _secureStorage.getAccessToken();
      if (token == null) {
        emit(AuthUnauthenticated());
        return;
      }

      // Проверяем валидность токена
      final response = await _apiClient.get('/api/v1/users/me');
      final userData = response.asMap;

      // Подключаем WebSocket
      await _wsClient.connect();

      // Инициализация E2EE
      await E2EEKeyManager.instance.initialize(userData['id'] as String);

      // Инициализация звуков уведомлений
      await NotificationService.instance.initialize();

      emit(AuthAuthenticated(
        userId: userData['id'] as String,
        username: userData['username'] as String,
        displayName: userData['display_name'] as String?,
        avatarUrl: userData['avatar_url'] as String?,
      ));
    } catch (e) {
      logger.w('Auth check failed: $e');
      // Пробуем обновить токен
      try {
        await _refreshTokens();
        add(AuthCheckRequested());
      } catch (_) {
        emit(AuthUnauthenticated());
      }
    }
  }

  // ─── Вход ──────────────────────────────────────────────────────
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _apiClient.post('/api/v1/auth/login', data: {
        'identifier': event.identifier,
        'method': event.method,
      });

      emit(AuthOtpSent(
        identifier: event.identifier,
        method: event.method,
      ));
    } on CharoApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: 'Неизвестная ошибка: $e'));
    }
  }

  // ─── Верификация OTP ───────────────────────────────────────────
  Future<void> _onOtpSubmitted(
    AuthOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _apiClient.post('/api/v1/auth/verify', data: {
        'identifier': event.identifier,
        'code': event.code,
        'method': event.method,
      });

      final data = response.asMap;

      // Check if 2FA is required
      if (data['requires_2fa'] == true) {
        emit(Auth2faRequired(
          tempToken: data['temp_token'] as String? ?? '',
          identifier: event.identifier,
        ));
        return;
      }

      await _saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      // Подключаем WebSocket
      await _wsClient.connect();

      // Инициализация E2EE
      final userId = data['user']['id'] as String;
      await E2EEKeyManager.instance.initialize(userId);
      await _secureStorage.setUserId(userId);

      // Инициализация звуков уведомлений
      await NotificationService.instance.initialize();

      emit(AuthAuthenticated(
        userId: userId,
        username: data['user']['username'] as String,
        displayName: data['user']['display_name'] as String?,
        avatarUrl: data['user']['avatar_url'] as String?,
      ));
    } on CharoApiException catch (e) {
      emit(AuthError(message: e.message));
    }
  }

  // ─── Регистрация ───────────────────────────────────────────────
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _apiClient.post('/api/v1/auth/register', data: {
        'username': event.username,
        'display_name': event.displayName,
        if (event.phone != null) 'phone': event.phone,
        if (event.email != null) 'email': event.email,
        'consent_given': event.consentGiven,
        'age_confirmed': event.ageConfirmed,
        'terms_accepted': event.termsAccepted,
      });

      // После регистрации отправляем OTP
      if (event.phone != null) {
        emit(AuthOtpSent(identifier: event.phone!, method: 'phone'));
      } else if (event.email != null) {
        emit(AuthOtpSent(identifier: event.email!, method: 'email'));
      }
    } on CharoApiException catch (e) {
      emit(AuthError(message: e.message));
    }
  }

  // ─── OAuth ─────────────────────────────────────────────────────
  Future<void> _onOAuthRequested(
    AuthOAuthRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // Redirect to OAuth provider via deep link / browser
      final response = await _apiClient.get(
        '/api/v1/auth/oauth/${event.provider}',
      );

      // The server returns a redirect URL to the OAuth provider
      // In a real mobile app: open URL in browser/WebView with deep link callback
      // On web: redirect directly via window.location
      final redirectData = response.asMap;

      // Store OAuth state for callback verification
      await _secureStorage.setOAuthState(
        provider: event.provider,
        state: redirectData['state'] as String? ?? '',
      );

      // The BLoC fetches the redirect URL — UI layer handles the actual redirect
      logger.i('OAuth ${event.provider}: redirect URL received — UI handles redirect');

      // Don't emit a state change — the UI will handle the redirect
      // and call AuthCheckRequested after OAuth callback
    } on CharoApiException catch (e) {
      emit(AuthError(message: e.message));
    }
  }

  // ─── Выход ─────────────────────────────────────────────────────
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _apiClient.post('/api/v1/auth/logout');
    } catch (_) {}

    await _wsClient.disconnect();
    await E2EEKeyManager.instance.wipeAllKeys();
    await _secureStorage.clearAll();
    emit(AuthUnauthenticated());
  }

  // ─── Удаление аккаунта ─────────────────────────────────────────
  Future<void> _onDeleteAccountRequested(
    AuthDeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (event.confirmation != 'DELETE') {
      emit(AuthError(message: 'Введите DELETE для подтверждения'));
      return;
    }

    emit(AuthLoading());
    try {
      final response = await _apiClient.delete('/api/v1/auth/account', data: {
        'confirmation': event.confirmation,
      });

      final data = response.asMap;
      final accountId = data['account_id'] as String? ?? '';
      final recoveryCode = data['recovery_code'] as String? ?? '';

      await _wsClient.disconnect();
      await _secureStorage.clearAll();
      emit(AuthAccountDeleted(accountId: accountId, recoveryCode: recoveryCode));
    } on CharoApiException catch (e) {
      emit(AuthError(message: e.message));
    }
  }

  // ─── Восстановление аккаунта ───────────────────────────────────
  Future<void> _onAccountRecoveryRequested(
    AuthAccountRecoveryRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _apiClient.post('/api/v1/auth/recover', data: {
        'account_id': event.accountId,
        'verification_code': event.recoveryCode,
      });

      final data = response.asMap;
      await _saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      // After recovery, fetch user profile separately
      final userResponse = await _apiClient.get('/api/v1/users/me');
      final userData = userResponse.asMap;
      final userId = userData['id'] as String;
      await _secureStorage.setUserId(userId);
      await _wsClient.connect();
      await E2EEKeyManager.instance.initialize(userId);
      await NotificationService.instance.initialize();

      emit(AuthAuthenticated(
        userId: userId,
        username: userData['username'] as String,
        displayName: userData['display_name'] as String?,
        avatarUrl: userData['avatar_url'] as String?,
      ));
    } on CharoApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: 'Неизвестная ошибка: $e'));
    }
  }

  // ─── Обновление токена ─────────────────────────────────────────
  Future<void> _onRefreshRequested(
    AuthRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _refreshTokens();
      add(AuthCheckRequested());
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  // ─── Верификация 2FA ────────────────────────────────────────────
  Future<void> _on2faVerifyRequested(
    Auth2faVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _apiClient.post('/api/v1/auth/2fa/verify', data: {
        'temp_token': event.tempToken,
        'code': event.code,
      });

      final data = response.asMap;
      await _saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      // Подключаем WebSocket
      await _wsClient.connect();

      // Инициализация E2EE
      final userId = data['user']['id'] as String;
      await E2EEKeyManager.instance.initialize(userId);
      await _secureStorage.setUserId(userId);

      // Инициализация звуков уведомлений
      await NotificationService.instance.initialize();

      emit(AuthAuthenticated(
        userId: userId,
        username: data['user']['username'] as String,
        displayName: data['user']['display_name'] as String?,
        avatarUrl: data['user']['avatar_url'] as String?,
      ));
    } on CharoApiException catch (e) {
      emit(AuthError(message: e.message));
    }
  }

  // ─── Вспомогательные методы ────────────────────────────────────
  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.setAccessToken(accessToken);
    await _secureStorage.setRefreshToken(refreshToken);
  }

  Future<void> _refreshTokens() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) throw Exception('No refresh token');

    final response = await _apiClient.post(
      '/api/v1/auth/refresh',
      data: {'refresh_token': refreshToken},
    );

    final data = response.asMap;
    await _saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }
}
