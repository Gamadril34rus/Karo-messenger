// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:dio/dio.dart';
import '../../utils/logger.dart';

/// Централизованная обработка ошибок API
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Логируем ошибку
    logger.e(
      'API Error: ${err.requestOptions.method} ${err.requestOptions.path}',
      error: err.message,
    );

    // Формируем понятное сообщение
    String userMessage;
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        userMessage = 'Превышено время ожидания';
        break;
      case DioExceptionType.connectionError:
        userMessage = 'Нет подключения к серверу';
        break;
      case DioExceptionType.badResponse:
        userMessage = _extractErrorMessage(err.response);
        break;
      default:
        userMessage = 'Произошла неизвестная ошибка';
    }

    handler.next(DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: userMessage,
    ));
  }

  String _extractErrorMessage(Response? response) {
    if (response?.data is Map) {
      return (response!.data as Map)['message'] as String? ??
          'Ошибка сервера (${response.statusCode})';
    }
    return 'Ошибка сервера (${response?.statusCode})';
  }
}
