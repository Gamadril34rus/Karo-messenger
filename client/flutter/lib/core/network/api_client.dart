// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import '../utils/logger.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/anti_block_interceptor.dart';

/// HTTP-клиент ЧАРО на базе Dio
///
/// Особенности:
/// - Автоматическая ротация зеркальных доменов при блокировках
/// - JWT-авторизация с автообновлением токена
/// - Retry при временных ошибках
/// - Централизованная обработка ошибок
class ApiClient {
  late final Dio _dio;
  final SecureStorageHelper _secureStorage;

  ApiClient(this._secureStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-App-Version': AppConstants.appVersion,
          'X-Platform': _platformHeader,
        },
      ),
    );

    // Порядок интерцепторов важен!
    _dio.interceptors.addAll([
      AuthInterceptor(_secureStorage, _dio),
      AntiBlockInterceptor(),
      ErrorInterceptor(),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => logger.d(o),
      ),
    ]);
  }

  String get _platformHeader {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
      default:
        return 'flutter';
    }
  }

  // ─── GET ───────────────────────────────────────────────────────
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return ApiResponse.fromDio(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ─── POST ──────────────────────────────────────────────────────
  Future<ApiResponse> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return ApiResponse.fromDio(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ─── PATCH ─────────────────────────────────────────────────────
  Future<ApiResponse> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse.fromDio(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ─── DELETE ────────────────────────────────────────────────────
  Future<ApiResponse> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse.fromDio(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ─── Upload (multipart) ────────────────────────────────────────
  Future<ApiResponse> upload(
    String path, {
    required FormData formData,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
      return ApiResponse.fromDio(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ─── Обработка ошибок ──────────────────────────────────────────
  CharoApiException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return CharoApiException(
          message: 'Превышено время ожидания. Проверьте подключение к интернету.',
          statusCode: e.response?.statusCode,
          type: CharoExceptionType.timeout,
        );
      case DioExceptionType.connectionError:
        return CharoApiException(
          message: 'Нет подключения к серверу. Попробуйте включить прокси.',
          statusCode: e.response?.statusCode,
          type: CharoExceptionType.network,
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] as String? ??
            'Произошла ошибка сервера';
        return CharoApiException(
          message: message,
          statusCode: statusCode,
          type: _statusCodeToType(statusCode),
        );
      case DioExceptionType.cancel:
        return CharoApiException(
          message: 'Запрос отменён',
          type: CharoExceptionType.cancelled,
        );
      default:
        return CharoApiException(
          message: 'Неизвестная ошибка',
          statusCode: e.response?.statusCode,
          type: CharoExceptionType.unknown,
        );
    }
  }

  CharoExceptionType _statusCodeToType(int? statusCode) {
    if (statusCode == null) return CharoExceptionType.unknown;
    switch (statusCode) {
      case 400:
        return CharoExceptionType.badRequest;
      case 401:
        return CharoExceptionType.unauthorized;
      case 403:
        return CharoExceptionType.forbidden;
      case 404:
        return CharoExceptionType.notFound;
      case 429:
        return CharoExceptionType.rateLimit;
      default:
        if (statusCode >= 500) return CharoExceptionType.serverError;
        return CharoExceptionType.unknown;
    }
  }
}

/// Обёртка ответа API
class ApiResponse {
  final dynamic data;
  final int? statusCode;
  final Map<String, dynamic>? headers;

  ApiResponse({
    required this.data,
    this.statusCode,
    this.headers,
  });

  factory ApiResponse.fromDio(Response response) {
    return ApiResponse(
      data: response.data,
      statusCode: response.statusCode,
      headers: response.headers.map,
    );
  }

  T as<T>() => data as T;
  Map<String, dynamic> get asMap => data as Map<String, dynamic>;
  List<dynamic> get asList => data as List<dynamic>;
}

/// Исключение API
class CharoApiException implements Exception {
  final String message;
  final int? statusCode;
  final CharoExceptionType type;

  CharoApiException({
    required this.message,
    this.statusCode,
    required this.type,
  });

  @override
  String toString() => 'CharoApiException($statusCode, $type): $message';
}

enum CharoExceptionType {
  timeout,
  network,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  rateLimit,
  serverError,
  cancelled,
  unknown,
}
