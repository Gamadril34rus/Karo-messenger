// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import '../utils/logger.dart';

/// Инициализация десктопного окружения (Windows, Linux, macOS)
/// Настраивает окно, системный трей, горячие клавиши
class DesktopInitializer with TrayListener, WindowListener {
  static DesktopInitializer? _instance;
  static DesktopInitializer get instance => _instance ??= DesktopInitializer._();

  DesktopInitializer._();

  bool _initialized = false;
  bool get isDesktop => !isMobile && !isWeb;
  bool get isMobile => Platform.isAndroid || Platform.isIOS;
  bool get isWeb => identical(0, 0.0); // always false in dart:io

  /// Инициализировать десктопное окружение
  Future<void> initialize() async {
    if (_initialized || !isDesktop) return;

    try {
      // ─── Менеджер окон ───────────────────────────────────────────
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      windowManager.addListener(this);

      // ─── Системный трей ──────────────────────────────────────────
      await trayManager.ensureInitialized();
      trayManager.addListener(this);

      await _updateTray();

      _initialized = true;
      logger.i('Desktop environment initialized (${Platform.operatingSystem})');
    } catch (e) {
      logger.e('Desktop initialization failed: $e');
    }
  }

  /// Обновить меню системного трея
  Future<void> _updateTray() async {
    if (!isDesktop) return;

    final menu = Menu(items: [
      MenuItem(key: 'show', label: 'Открыть ЧАРО'),
      MenuItem.separator(),
      MenuItem(key: 'new_chat', label: 'Новый чат    Ctrl+N'),
      MenuItem(key: 'search', label: 'Поиск         Ctrl+K'),
      MenuItem.separator(),
      MenuItem(key: 'settings', label: 'Настройки'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Выход         Ctrl+Q'),
    ]);

    if (Platform.isWindows) {
      await trayManager.setIcon(
        'assets/icons/app_icon.ico',
      );
    } else if (Platform.isLinux) {
      await trayManager.setIcon(
        'assets/icons/app_icon.png',
      );
    } else if (Platform.isMacOS) {
      await trayManager.setIcon(
        'assets/icons/app_icon.png',
      );
    }

    await trayManager.setContextMenu(menu);
    await trayManager.setToolTip('ЧАРО Мессенджер');
  }

  /// Показать окно из трея
  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Скрыть окно в трей
  Future<void> hideToTray() async {
    await windowManager.hide();
  }

  /// Освободить ресурсы
  Future<void> dispose() async {
    if (!_initialized) return;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    await trayManager.destroy();
    _initialized = false;
  }

  // ─── TrayListener ────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() => showWindow();

  @override
  void onTrayIconRightMouseDown() {}

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        showWindow();
      case 'new_chat':
        showWindow();
        // Навигация через глобальный ключ — handled in main
      case 'search':
        showWindow();
      case 'settings':
        showWindow();
      case 'quit':
        _quit();
    }
  }

  // ─── WindowListener ──────────────────────────────────────────────

  @override
  void onWindowClose() {
    // Сворачиваем в трей вместо закрытия
    hideToTray();
  }

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowResized() {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowEvent(String eventName) {}

  Future<void> _quit() async {
    await dispose();
    exit(0);
  }
}
