// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/errors/app_error.dart';
import '../../core/utils/logger.dart';

/// ErrorBoundary — глобальный UI-обработчик ошибок
///
/// Обёртка вокруг widget subtree, которая:
/// - Перехватывает ошибки при построении widget tree
/// - Показывает user-friendly сообщение вместо crash
/// - Предлагает Retry для retryable ошибок
/// - Логирует ошибку для отладки
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? fallbackMessage;
  final Widget? customFallback;
  final void Function(AppError error)? onError;

  const ErrorBoundary({
    required this.child,
    this.fallbackMessage,
    this.customFallback,
    this.onError,
    super.key,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  AppError? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.customFallback ?? _buildDefaultFallback(context, _error!);
    }

    return _ErrorBoundaryWrapper(
      onError: _handleError,
      child: widget.child,
    );
  }

  void _handleError(AppError error) {
    logger.e('🚨 ErrorBoundary caught: ${error.toLog()}');

    if (widget.onError != null) {
      widget.onError!(error);
    }

    setState(() {
      _error = error;
    });
  }

  void _retry() {
    setState(() {
      _error = null;
    });
  }

  Widget _buildDefaultFallback(BuildContext context, AppError error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForErrorType(error.type),
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              widget.fallbackMessage ?? error.userMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            if (error.code != null)
              Text(
                'Код ошибки: ${error.code}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (error.isRetryable)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Попробовать снова'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForErrorType(ErrorType type) {
    switch (type) {
      case ErrorType.e2ee: return Icons.lock_outline;
      case ErrorType.network: return Icons.wifi_off;
      case ErrorType.mls: return Icons.group_off;
      case ErrorType.webrtc: return Icons.videocam_off;
      case ErrorType.validation: return Icons.error_outline;
      case ErrorType.auth: return Icons.key_off;
      case ErrorType.storage: return Icons.storage_outlined;
      case ErrorType.media: return Icons.perm_media_outlined;
      case ErrorType.unknown: return Icons.bug_report_outlined;
    }
  }
}

/// Wrapper widget, перехватывающий Flutter errors в subtree
class _ErrorBoundaryWrapper extends StatelessWidget {
  final Widget child;
  final void Function(AppError error) onError;

  const _ErrorBoundaryWrapper({
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBoundaryHandler(
      onError: onError,
      child: child,
    );
  }
}

/// ErrorBoundaryHandler — перехватывает ошибки через FlutterError.onError
class ErrorBoundaryHandler extends StatefulWidget {
  final Widget child;
  final void Function(AppError error) onError;

  const ErrorBoundaryHandler({
    required this.child,
    required this.onError,
    super.key,
  });

  @override
  State<ErrorBoundaryHandler> createState() => _ErrorBoundaryHandlerState();
}

class _ErrorBoundaryHandlerState extends State<ErrorBoundaryHandler> {
  FlutterErrorHandler? _previousErrorHandler;

  @override
  void initState() {
    super.initState();
    // Сохраняем предыдущий обработчик
    _previousErrorHandler = FlutterError.onError;
    // Устанавливаем наш обработчик
    FlutterError.onError = _handleFlutterError;
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    // Сначала вызываем предыдущий обработчик (логирование консоли)
    _previousErrorHandler?.call(details);

    final error = AppError.fromUnknown(
      details.exception,
      details.stack,
    );
    widget.onError(error);
  }

  @override
  void dispose() {
    // Восстанавливаем предыдущий обработчик
    FlutterError.onError = _previousErrorHandler ?? FlutterError.dumpErrorToConsole;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// GlobalErrorHandler для всего приложения
///
/// Устанавливается в main.dart:
/// ```dart
/// GlobalErrorHandler.initialize();
/// ```
class GlobalErrorHandler {
  static bool _initialized = false;
  static FlutterErrorHandler? _originalFlutterErrorHandler;
  static PlatformErrorCallback? _originalPlatformErrorHandler;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Сохраняем оригинальные обработчики
    _originalFlutterErrorHandler = FlutterError.onError;
    _originalPlatformErrorHandler = PlatformDispatcher.instance.onError;

    // Перехват всех Flutter framework errors
    FlutterError.onError = (details) {
      _originalFlutterErrorHandler?.call(details);
      final error = AppError.fromUnknown(details.exception, details.stack);
      logger.e('🚨 Global error: ${error.toLog()}');
    };

    // Перехват всех uncaught async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      final appError = AppError.fromUnknown(error, stack);
      logger.e('🚨 Uncaught async error: ${appError.toLog()}');
      return true; // Handled
    };
  }

  /// Восстановление оригинальных обработчиков (для тестов)
  static void reset() {
    FlutterError.onError = _originalFlutterErrorHandler;
    PlatformDispatcher.instance.onError = _originalPlatformErrorHandler;
    _initialized = false;
  }
}
