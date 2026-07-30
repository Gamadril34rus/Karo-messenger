import '../domain/charo_repository.dart';
import '../network/api_client.dart';
import '../utils/logger.dart';

/// ─── Email Verification Service ─────────────────────────────────
/// Отправка email с кодом подтверждения.
/// Верификация кода на сервере.
/// Использует ApiClient напрямую для специфичных endpoints,
/// которые ещё не добавлены в CharoRepository.

class EmailVerificationService {
  final ApiClient _apiClient;

  EmailVerificationService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Отправить код подтверждения на email
  Future<bool> sendVerificationCode(String email) async {
    try {
      await _apiClient.post('/api/v1/auth/verify-email', data: {
        'email': email,
      });
      logger.i('📧 Verification code sent to: $email');
      return true;
    } catch (e) {
      logger.e('📧 Failed to send verification code: $e');
      return false;
    }
  }

  /// Подтвердить email кодом
  Future<bool> verifyCode(String email, String code) async {
    try {
      await _apiClient.post('/api/v1/auth/verify-email/confirm', data: {
        'email': email,
        'code': code,
      });
      logger.i('📧 Email verified: $email');
      return true;
    } catch (e) {
      logger.e('📧 Email verification failed: $e');
      return false;
    }
  }
}
