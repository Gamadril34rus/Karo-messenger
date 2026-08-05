// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
/// Централизованная обработка ошибок ЧАРО
///
/// AppError — единый тип ошибки для всего приложения.
/// Категоризирует ошибки по типу и предоставляет удобные методы для UI.
///
/// ВНИМАНИЕ: CharoApiException и CharoExceptionType определены
/// в api_client.dart — здесь только импорт для удобства.

import '../network/api_client.dart';

// Re-export для удобства — реальные определения в api_client.dart
// CharoApiException, CharoExceptionType доступны через api_client.dart

enum ErrorType {
  e2ee('e2ee', 'Ошибка шифрования'),
  network('network', 'Ошибка сети'),
  mls('mls', 'Ошибка MLS'),
  webrtc('webrtc', 'Ошибка звонка'),
  validation('validation', 'Ошибка проверки'),
  auth('auth', 'Ошибка авторизации'),
  storage('storage', 'Ошибка хранения'),
  media('media', 'Ошибка медиа'),
  unknown('unknown', 'Неизвестная ошибка');

  final String code;
  final String defaultMessage;

  const ErrorType(this.code, this.defaultMessage);
}

class AppError implements Exception {
  final String message;
  final ErrorType type;
  final int? code;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  AppError({
    required this.message,
    required this.type,
    this.code,
    this.originalError,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AppError.fromApiException(CharoApiException exception) {
    final type = _mapApiExceptionType(exception.type);
    return AppError(
      message: exception.message,
      type: type,
      code: exception.statusCode,
      originalError: exception,
    );
  }

  factory AppError.fromMlsException(CharoMlsException exception) {
    return AppError(
      message: exception.message,
      type: ErrorType.mls,
      originalError: exception,
    );
  }

  factory AppError.fromE2eeError(String message, dynamic originalError) {
    return AppError(
      message: message,
      type: ErrorType.e2ee,
      originalError: originalError,
    );
  }

  factory AppError.fromWebRtcError(String message, dynamic originalError) {
    return AppError(
      message: message,
      type: ErrorType.webrtc,
      originalError: originalError,
    );
  }

  factory AppError.validationError(String message) {
    return AppError(message: message, type: ErrorType.validation);
  }

  factory AppError.fromUnknown(dynamic error, StackTrace? stackTrace) {
    return AppError(
      message: error.toString(),
      type: ErrorType.unknown,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  String get userMessage {
    switch (type) {
      case ErrorType.e2ee:
        return 'Ошибка шифрования: $message. Попробуйте снова или проверьте Safety Numbers.';
      case ErrorType.network:
        return 'Нет подключения к серверу. Проверьте интернет или включите прокси.';
      case ErrorType.mls:
        return 'Ошибка группового шифрования: $message.';
      case ErrorType.webrtc:
        return 'Ошибка звонка: $message. Попробуйте перезвонить.';
      case ErrorType.validation:
        return message;
      case ErrorType.auth:
        return 'Ошибка авторизации. Проверьте логин и пароль.';
      case ErrorType.storage:
        return 'Ошибка хранения данных. Попробуйте очистить кэш.';
      case ErrorType.media:
        return 'Ошибка медиа: $message.';
      case ErrorType.unknown:
        return 'Произошла неизвестная ошибка. Попробуйте снова.';
    }
  }

  String get shortMessage {
    switch (type) {
      case ErrorType.e2ee: return 'Ошибка шифрования';
      case ErrorType.network: return 'Нет подключения';
      case ErrorType.mls: return 'Ошибка MLS';
      case ErrorType.webrtc: return 'Ошибка звонка';
      case ErrorType.validation: return message;
      case ErrorType.auth: return 'Ошибка авторизации';
      case ErrorType.storage: return 'Ошибка хранения';
      case ErrorType.media: return 'Ошибка медиа';
      case ErrorType.unknown: return 'Ошибка';
    }
  }

  bool get isRetryable {
    switch (type) {
      case ErrorType.network:
      case ErrorType.webrtc:
      case ErrorType.e2ee:
      case ErrorType.unknown:
        return true;
      case ErrorType.validation:
      case ErrorType.mls:
      case ErrorType.auth:
      case ErrorType.storage:
      case ErrorType.media:
        return false;
    }
  }

  bool get requiresUserAction {
    switch (type) {
      case ErrorType.auth:
      case ErrorType.validation:
      case ErrorType.e2ee:
        return true;
      default:
        return false;
    }
  }

  @override
  String toString() => 'AppError(${type.code}${code != null ? ', $code' : ''}): $message';

  Map<String, dynamic> toLog() {
    return {
      'type': type.code,
      'message': message,
      'code': code,
      'timestamp': timestamp.toIso8601String(),
      if (originalError != null) 'original_error': originalError.toString(),
      if (stackTrace != null) 'stack_trace': stackTrace.toString(),
    };
  }

  static ErrorType _mapApiExceptionType(CharoExceptionType apiType) {
    switch (apiType) {
      case CharoExceptionType.network:
      case CharoExceptionType.timeout:
        return ErrorType.network;
      case CharoExceptionType.unauthorized:
      case CharoExceptionType.forbidden:
        return ErrorType.auth;
      case CharoExceptionType.badRequest:
        return ErrorType.validation;
      case CharoExceptionType.notFound:
        return ErrorType.network;
      case CharoExceptionType.rateLimit:
        return ErrorType.network;
      case CharoExceptionType.serverError:
        return ErrorType.network;
      case CharoExceptionType.cancelled:
        return ErrorType.unknown;
      case CharoExceptionType.unknown:
        return ErrorType.unknown;
    }
  }
}

/// CharoMlsException — MLS-специфичная ошибка
class CharoMlsException implements Exception {
  final String message;
  CharoMlsException(this.message);

  @override
  String toString() => 'CharoMlsException: $message';
}
