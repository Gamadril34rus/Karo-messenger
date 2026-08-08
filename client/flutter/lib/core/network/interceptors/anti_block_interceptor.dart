// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:dio/dio.dart';
import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// Интерцептор анти-блокировок
///
/// При получении ошибки соединения автоматически
/// переключается на зеркальные домены
class AntiBlockInterceptor extends Interceptor {
  int _currentMirrorIndex = 0;
  DateTime? _lastMirrorSwitch;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Если ошибка связана с недоступностью сервера
    if (_isConnectionError(err)) {
      logger.w('AntiBlock: connection error detected, trying mirror...');

      if (_shouldSwitchMirror()) {
        _switchToNextMirror();
        _retryWithMirror(err, handler);
        return;
      }
    }

    handler.next(err);
  }

  bool _isConnectionError(DioException err) {
    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        (err.response?.statusCode == 403 &&
            err.response?.data?['code'] == 'BLOCKED');
  }

  bool _shouldSwitchMirror() {
    if (_lastMirrorSwitch == null) return true;
    // Не переключаемся чаще, чем раз в 30 секунд
    return DateTime.now().difference(_lastMirrorSwitch!).inSeconds > 30;
  }

  void _switchToNextMirror() {
    _currentMirrorIndex =
        (_currentMirrorIndex + 1) % AppConstants.mirrorDomains.length;
    _lastMirrorSwitch = DateTime.now();
    logger.i(
        'AntiBlock: switched to mirror ${AppConstants.mirrorDomains[_currentMirrorIndex]}');
  }

  void _retryWithMirror(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    final mirror = AppConstants.mirrorDomains[_currentMirrorIndex];
    final newUrl = '$mirror${err.requestOptions.path}';

    final options = Options(
      method: err.requestOptions.method,
      headers: err.requestOptions.headers,
    );

    err.requestOptions.extra['mirror_retry'] = true;

    try {
      final dio = Dio();
      dio.fetch(err.requestOptions.copyWith(
        baseUrl: mirror,
        path: err.requestOptions.path,
      )).then((response) {
        handler.resolve(response);
      }).catchError((e) {
        handler.next(err);
      });
    } catch (e) {
      handler.next(err);
    }
  }
}
