import 'dart:io';
import 'package:flutter/foundation.dart';

/// Утилиты для определения платформы и адаптации UI
class DesktopPlatform {
  DesktopPlatform._();

  /// Текущая платформа
  static String get currentPlatform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }

  /// Это десктоп?
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Это мобильный?
  static bool get isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Это веб?
  static bool get isWeb => kIsWeb;

  /// Это macOS?
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Это Windows?
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Это Linux?
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// Рекомендуемый размер окна для текущей платформы
  static double get defaultWidth {
    if (isDesktop) return 1280;
    return double.infinity;
  }

  static double get defaultHeight {
    if (isDesktop) return 800;
    return double.infinity;
  }

  static double get minWidth => isDesktop ? 800 : 0;
  static double get minHeight => isDesktop ? 600 : 0;

  /// Рекомендуемый отступ для контента (safe area на мобилке, 0 на десктопе)
  static double get contentPadding => isDesktop ? 0 : 16;

  /// Максимальная ширина чата (десктоп — ограничена, мобилка — на весь экран)
  static double get chatMaxWidth => isDesktop ? 900 : double.infinity;

  /// Показывать sidebar (десктоп: всегда, мобилка: только в landscape или планшет)
  static bool get showSidebar => isDesktop;

  /// Расположение навигации
  static NavigationMode get navigationMode {
    if (isDesktop) return NavigationMode.rail;
    if (isMobile) return NavigationMode.bottom;
    return NavigationMode.bottom;
  }

  /// Формат имени платформы для логов
  static String get platformLabel {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    return 'Unknown';
  }
}

/// Режим навигации
enum NavigationMode {
  /// Нижняя навигация (мобильный)
  bottom,

  /// Боковая панель-рейл (десктоп)
  rail,

  /// Drawer (планшет)
  drawer,
}
