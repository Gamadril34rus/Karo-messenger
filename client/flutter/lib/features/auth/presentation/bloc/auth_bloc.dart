import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/network/ws_client.dart';
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

  AuthRegisterRequested({
    required this.username,
    required this.displayName,
    this.phone,
    this.email,
  });

  @override
  List<Object?> get props => [username, displayName, phone, email];
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

/// Аккаунт удалён
final class AuthAccountDeleted extends AuthState {}

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
      await _saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      // Подключаем WebSocket
      await _wsClient.connect();

      emit(AuthAuthenticated(
        userId: data['user']['id'] as String,
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
      await _apiClient.delete('/api/v1/auth/account', data: {
        'confirmation': event.confirmation,
      });

      await _wsClient.disconnect();
      await _secureStorage.clearAll();
      emit(AuthAccountDeleted());
    } on CharoApiException catch (e) {
      emit(AuthError(message: e.message));
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
