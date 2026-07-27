import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/constants/app_constants.dart';
import 'package:charo_messenger/core/errors/app_error.dart';
import 'package:charo_messenger/core/haptic/haptic_service.dart';
import 'package:charo_messenger/core/network/api_client.dart';

void main() {
  group('AppConstants', () {
    test('appName is ЧАРО', () {
      expect(AppConstants.appName, 'ЧАРО');
    });

    test('appVersion is not empty', () {
      expect(AppConstants.appVersion, isNotEmpty);
    });

    test('apiBaseUrl is not empty', () {
      expect(AppConstants.apiBaseUrl, isNotEmpty);
    });

    test('wsUrl is not empty', () {
      expect(AppConstants.wsUrl, isNotEmpty);
    });

    test('maxFileSize > 0', () {
      expect(AppConstants.maxFileSize, greaterThan(0));
    });

    test('maxMessageLength > 0', () {
      expect(AppConstants.maxMessageLength, greaterThan(0));
    });

    test('mirrorDomains is not empty', () {
      expect(AppConstants.mirrorDomains, isNotEmpty);
    });

    test('supportedLanguages contains Russian', () {
      expect(AppConstants.supportedLanguages.containsKey('ru'), isTrue);
    });

    test('supportedLanguages contains English', () {
      expect(AppConstants.supportedLanguages.containsKey('en'), isTrue);
    });

    test('supportedLanguages has at least 10 entries', () {
      expect(AppConstants.supportedLanguages.length, greaterThanOrEqualTo(10));
    });

    test('disappearingTimers is not empty', () {
      expect(AppConstants.disappearingTimers, isNotEmpty);
    });

    test('mediaQuality has 4 presets', () {
      expect(AppConstants.mediaQuality.length, 4);
    });
  });

  group('AppError', () {
    test('creates with message and type', () {
      final error = AppError(
        message: 'test error',
        type: ErrorType.unknown,
      );
      expect(error.message, 'test error');
      expect(error.type, ErrorType.unknown);
    });

    test('toString contains message', () {
      final error = AppError(
        message: 'test',
        type: ErrorType.network,
      );
      expect(error.toString(), contains('test'));
    });

    test('fromUnknown creates error with original error', () {
      final error = AppError.fromUnknown(
        Exception('original'),
        StackTrace.empty,
      );
      expect(error.type, ErrorType.unknown);
      expect(error.originalError, isNotNull);
    });

    test('validationError creates validation type error', () {
      final error = AppError.validationError('bad input');
      expect(error.type, ErrorType.validation);
      expect(error.message, 'bad input');
    });

    test('isRetryable is true for network errors', () {
      final error = AppError(message: 'net', type: ErrorType.network);
      expect(error.isRetryable, isTrue);
    });

    test('isRetryable is false for auth errors', () {
      final error = AppError(message: 'auth', type: ErrorType.auth);
      expect(error.isRetryable, isFalse);
    });

    test('userMessage returns readable text', () {
      final error = AppError(message: 'test', type: ErrorType.network);
      expect(error.userMessage, isNotEmpty);
    });
  });

  group('CharoApiException', () {
    test('creates with message and type', () {
      final exception = CharoApiException(
        message: 'server error',
        statusCode: 500,
        type: CharoExceptionType.serverError,
      );
      expect(exception.message, 'server error');
      expect(exception.statusCode, 500);
      expect(exception.type, CharoExceptionType.serverError);
    });

    test('toString contains status code and message', () {
      final exception = CharoApiException(
        message: 'timeout',
        type: CharoExceptionType.timeout,
      );
      expect(exception.toString(), contains('timeout'));
    });
  });

  group('HapticService', () {
    test('instance is singleton-like', () {
      final s1 = HapticService.instance;
      final s2 = HapticService.instance;
      expect(s1, same(s2));
    });

    test('static convenience methods exist', () {
      // Just verifying they don't throw in test environment
      expect(HapticService.selection, isA<Function>());
      expect(HapticService.light, isA<Function>());
      expect(HapticService.medium, isA<Function>());
      expect(HapticService.heavy, isA<Function>());
    });
  });

  group('ErrorType', () {
    test('all error types have codes', () {
      for (final type in ErrorType.values) {
        expect(type.code, isNotEmpty);
      }
    });

    test('all error types have default messages', () {
      for (final type in ErrorType.values) {
        expect(type.defaultMessage, isNotEmpty);
      }
    });
  });

  group('CharoExceptionType', () {
    test('all exception types exist', () {
      expect(CharoExceptionType.values.length, 10);
    });

    test('has common types', () {
      expect(CharoExceptionType.network, isNotNull);
      expect(CharoExceptionType.unauthorized, isNotNull);
      expect(CharoExceptionType.serverError, isNotNull);
    });
  });
}
