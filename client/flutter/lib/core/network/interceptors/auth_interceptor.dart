// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:dio/dio.dart';
import '../../storage/secure_storage.dart';
import '../../utils/logger.dart';

/// Интерцептор авторизации — автоматически добавляет JWT в заголовки
class AuthInterceptor extends Interceptor {
  final SecureStorageHelper _secureStorage;
  final Dio _dio;

  AuthInterceptor(this._secureStorage, this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Пропускаем запросы авторизации
    if (_isAuthRoute(options.path)) {
      handler.next(options);
      return;
    }

    final token = await _secureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Если 401 — пробуем обновить токен
    if (err.response?.statusCode == 401) {
      logger.w('Auth: 401 received, attempting token refresh...');

      try {
        final newToken = await _refreshToken();
        if (newToken != null) {
          // Повторяем запрос с новым токеном
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final response = await _dio.fetch(err.requestOptions);
          handler.resolve(response);
          return;
        }
      } catch (e) {
        logger.e('Auth: token refresh failed: $e');
      }
    }

    handler.next(err);
  }

  bool _isAuthRoute(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/verify') ||
        path.contains('/auth/refresh');
  }

  Future<String?> _refreshToken() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await _dio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Authorization': ''}),
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String;

      await _secureStorage.setAccessToken(newAccessToken);
      await _secureStorage.setRefreshToken(newRefreshToken);

      logger.i('Auth: token refreshed successfully');
      return newAccessToken;
    } catch (e) {
      logger.e('Auth: refresh failed: $e');
      return null;
    }
  }
}
