// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';

import '../utils/logger.dart';

/// Сервис отчётности о сбоях — Sentry (Dart SDK)
/// Отправляет ошибки и crash-отчёты, Breadcrumb для отладки
class CrashReportingService {
  static CrashReportingService? _instance;
  static CrashReportingService get instance => _instance ??= CrashReportingService._();

  CrashReportingService._();

  bool _isInitialized = false;

  /// Инициализация Sentry
  Future<void> initialize({String? dsn}) async {
    if (_isInitialized) return;

    final sentryDsn = dsn ?? const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    if (sentryDsn.isEmpty) {
      logger.i('📊 Sentry DSN not configured — crash reporting disabled');
      return;
    }

    try {
      await Sentry.init(
        (options) {
          options.dsn = sentryDsn;
          options.tracesSampleRate = kDebugMode ? 0.0 : 1.0;
          options.profilesSampleRate = kDebugMode ? 0.0 : 1.0;
          options.environment = kDebugMode ? 'development' : 'production';
          options.release = const String.fromEnvironment('APP_VERSION', defaultValue: '1.1.0');
          options.attachStacktrace = true;
          options.sendDefaultPii = false; // GDPR: не отправлять PII по умолчанию
          options.maxBreadcrumbs = 100;
        },
      );
      _isInitialized = true;
      logger.i('📊 Sentry crash reporting initialized');
    } catch (e) {
      logger.e('📊 Sentry initialization failed: $e');
    }
  }

  /// Отправить ошибку в Sentry
  Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    String? hint,
  }) async {
    if (!_isInitialized) return;
    try {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        hint: hint != null ? Hint.withMap({'hint': hint}) : null,
      );
    } catch (e) {
      logger.e('📊 Sentry report error failed: $e');
    }
  }

  /// Добавить breadcrumb для отладки
  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    if (!_isInitialized) return;
    try {
      Sentry.addBreadcrumb(Breadcrumb(
        message: message,
        category: category ?? 'app',
        data: data,
        level: SentryLevel.info,
      ));
    } catch (_) {
      // Breadcrumb failures are non-critical
    }
  }

  /// Установить тег пользователя для привязки ошибок
  Future<void> setUser(String userId, {String? username}) async {
    if (!_isInitialized) return;
    try {
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(
          id: userId,
          username: username,
        ));
      });
    } catch (_) {}
  }

  /// Очистить пользователя при выходе
  Future<void> clearUser() async {
    if (!_isInitialized) return;
    try {
      Sentry.configureScope((scope) {
        scope.setUser(null);
      });
    } catch (_) {}
  }

  /// Отправить сообщение (info level)
  Future<void> captureMessage(String message, {SentryLevel level = SentryLevel.info}) async {
    if (!_isInitialized) return;
    try {
      await Sentry.captureMessage(message, level: level);
    } catch (_) {}
  }
}
