// ─── Desktop Support ────────────────────────────────────────────────
// ЧАРО Messenger — Windows, Linux, macOS
//
// Инициализация десктопа происходит в main.dart:
//   if (DesktopPlatform.isDesktop) {
//     await DesktopInitializer.instance.initialize();
//     DesktopHotkeys.instance.initialize();
//   }

export 'desktop_initializer.dart';
export 'desktop_hotkeys.dart';
export 'desktop_title_bar.dart';
export 'desktop_platform.dart';
