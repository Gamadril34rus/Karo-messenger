import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/charo_repository.dart';
import '../../../../core/e2ee/e2ee_manager.dart';
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
  final String provider; // 'google' | 'apple'

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
  final CharoRepository _repository;
  final SecureStorageHelper _secureStorage;
  final WsClient _wsClient;

  AuthBloc({
    required CharoRepository repository,
    required SecureStorageHelper secureStorage,
    required WsClient wsClient,
  })  : _repository = repository,
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

      // Проверяем валидность токена через профиль
      final profile = await _repository.getMyProfile();

      // Подключаем WebSocket
      await _wsClient.connect();

      // Инициализация E2EE
      await E2EEKeyManager.instance.initialize(profile.userId);

      // Инициализация звуков уведомлений
      await NotificationService.instance.initialize();

      emit(AuthAuthenticated(
        userId: profile.userId,
        username: profile.username,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
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
      await _repository.login(event.identifier, event.method);

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
      final result = await _repository.verifyOtp(
        event.identifier, event.code, event.method,
      );

      // Check if 2FA is required
      if (result.requires2fa) {
        emit(Auth2faRequired(
          tempToken: result.tempToken ?? '',
          identifier: event.identifier,
        ));
        return;
      }

      await _saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );

      // Подключаем WebSocket
      await _wsClient.connect();

      // Инициализация E2EE
      await E2EEKeyManager.instance.initialize(result.userId);
      await _secureStorage.setUserId(result.userId);

      // Инициализация звуков уведомлений
      await NotificationService.instance.initialize();

      emit(AuthAuthenticated(
        userId: result.userId,
        username: result.username,
        displayName: result.displayName,
        avatarUrl: result.avatarUrl,
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
      await _repository.register(
        username: event.username,
        displayName: event.displayName,
        phone: event.phone,
        email: event.email,
        consentGiven: event.consentGiven,
        ageConfirmed: event.ageConfirmed,
        termsAccepted: event.termsAccepted,
      );

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
      final oauthResult = await _repository.getOAuthUrl(event.provider);

      // Store OAuth state for callback verification
      await _secureStorage.setOAuthState(
        provider: event.provider,
        state: oauthResult.state,
      );

      // The BLoC fetches the redirect URL — UI layer handles the actual redirect
      logger.i('OAuth ${event.provider}: redirect URL received — UI handles redirect');
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
      await _repository.logout();
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
      final result = await _repository.deleteAccount(event.confirmation);

      await _wsClient.disconnect();
      await _secureStorage.clearAll();
      emit(AuthAccountDeleted(accountId: result.accountId, recoveryCode: result.recoveryCode));
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
      final result = await _repository.recoverAccount(
        event.accountId, event.recoveryCode,
      );

      await _saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );

      // After recovery, fetch user profile
      final profile = await _repository.getMyProfile();
      await _secureStorage.setUserId(profile.userId);
      await _wsClient.connect();
      await E2EEKeyManager.instance.initialize(profile.userId);
      await NotificationService.instance.initialize();

      emit(AuthAuthenticated(
        userId: profile.userId,
        username: profile.username,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
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
      final result = await _repository.verify2fa(
        event.tempToken, event.code,
      );

      await _saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );

      // Подключаем WebSocket
      await _wsClient.connect();

      // Инициализация E2EE
      await E2EEKeyManager.instance.initialize(result.userId);
      await _secureStorage.setUserId(result.userId);

      // Инициализация звуков уведомлений
      await NotificationService.instance.initialize();

      emit(AuthAuthenticated(
        userId: result.userId,
        username: result.username,
        displayName: result.displayName,
        avatarUrl: result.avatarUrl,
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

    final result = await _repository.refreshTokens();
    await _saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
  }
}

/// Обратная совместимость — CharoApiException из ApiClient
/// (бросается через repository при ошибках HTTP)
class CharoApiException implements Exception {
  final String message;
  final int? statusCode;

  const CharoApiException({required this.message, this.statusCode});

  @override
  String toString() => 'CharoApiException: $message';
}
