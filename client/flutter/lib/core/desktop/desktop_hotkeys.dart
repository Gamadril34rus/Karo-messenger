// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Горячие клавиши для десктопа (Windows, Linux, macOS)
class DesktopHotkeys {
  static DesktopHotkeys? _instance;
  static DesktopHotkeys get instance => _instance ??= DesktopHotkeys._();

  DesktopHotkeys._();

  bool _initialized = false;

  /// Callback'и для действий
  VoidCallback? onNewChat;
  VoidCallback? onSearch;
  VoidCallback? onSettings;
  VoidCallback? onQuit;
  VoidCallback? onToggleFullscreen;

  /// Инициализировать горячие клавиши
  void initialize() {
    if (_initialized || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    try {
      // Ctrl+Q — Выход
      RawKeyboard.instance.addListener(_handleKeyEvent);
      _initialized = true;
      logger.i('Desktop hotkeys initialized');
    } catch (e) {
      logger.e('Desktop hotkeys init failed: $e');
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final isCtrl = event.isControlPressed;
    final isAlt = event.isAltPressed;
    final isShift = event.isShiftPressed;
    final key = event.logicalKey;

    // Ctrl+N — Новый чат
    if (isCtrl && key == LogicalKeyboardKey.keyN) {
      onNewChat?.call();
      return;
    }

    // Ctrl+K — Поиск
    if (isCtrl && key == LogicalKeyboardKey.keyK) {
      onSearch?.call();
      return;
    }

    // Ctrl+, — Настройки
    if (isCtrl && key == LogicalKeyboardKey.comma) {
      onSettings?.call();
      return;
    }

    // Ctrl+Q — Выход
    if (isCtrl && key == LogicalKeyboardKey.keyQ) {
      onQuit?.call();
      return;
    }

    // F11 — Полноэкранный режим
    if (key == LogicalKeyboardKey.f11) {
      onToggleFullscreen?.call();
      return;
    }

    // Ctrl+Shift+M — Свернуть в трей
    if (isCtrl && isShift && key == LogicalKeyboardKey.keyM) {
      onQuit?.call();
      return;
    }

    // Ctrl+Tab / Ctrl+Shift+Tab — Следующий/предыдущий чат
    if (isCtrl && key == LogicalKeyboardKey.tab) {
      // Handled in chat list navigation
      return;
    }
  }

  /// Освободить ресурсы
  void dispose() {
    if (!_initialized) return;
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    _initialized = false;
  }
}
