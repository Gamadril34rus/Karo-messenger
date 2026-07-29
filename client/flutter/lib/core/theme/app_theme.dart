import 'package:flutter/material.dart';

/// Тема ЧАРО — минималистичная, динамичная, изящная.
///
/// Принципы:
/// - Чистая геометрия без лишних теней
/// - Акцентный цвет как инструмент фокуса
/// - Плавные переходы и анимации
/// - Идеальная читаемость на любом фоне
class AppTheme {
  AppTheme._();

  // ─── Цвета ────────────────────────────────────────────────────

  static const Color primaryLight = Color(0xFF2563EB);  // Charo Blue
  static const Color primaryDark = Color(0xFF60A5FA);
  static const Color accentLight = Color(0xFF8B5CF6);   // Violet accent
  static const Color accentDark = Color(0xFFA78BFA);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ─── Светлая тема ─────────────────────────────────────────────

  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: primaryLight,
      secondary: accentLight,
      surface: const Color(0xFFFAFAFA),
      onSurface: const Color(0xFF1A1A2E),
      error: error,
      outline: const Color(0xFFE2E8F0),
      outlineVariant: const Color(0xFFF1F5F9),
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  // ─── Тёмная тема ──────────────────────────────────────────────

  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: primaryDark,
      secondary: accentDark,
      surface: const Color(0xFF0F172A),
      onSurface: const Color(0xFFE2E8F0),
      error: const Color(0xFFF87171),
      outline: const Color(0xFF334155),
      outlineVariant: const Color(0xFF1E293B),
      surfaceContainerHighest: const Color(0xFF1E293B),
      surfaceContainerHigh: const Color(0xFF263548),
      surfaceContainer: const Color(0xFF192033),
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  // ─── AMOLED тема ──────────────────────────────────────────────

  static ThemeData amoled() {
    final colorScheme = ColorScheme.dark(
      primary: primaryDark,
      secondary: accentDark,
      surface: Colors.black,
      onSurface: const Color(0xFFE2E8F0),
      error: const Color(0xFFF87171),
      outline: const Color(0xFF1E293B),
      outlineVariant: const Color(0xFF0F172A),
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  // ─── Общий билдер ─────────────────────────────────────────────

  static ThemeData _buildTheme(ColorScheme colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      brightness: brightness,

      // ── Типографика ────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.5,
          color: colors.onSurface,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.25,
          letterSpacing: -0.3,
          color: colors.onSurface,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: colors.onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: colors.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: colors.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: colors.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: colors.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.45,
          color: colors.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: colors.onSurface.withOpacity(0.6),
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 0.1,
          color: colors.onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.3,
          letterSpacing: 0.5,
          color: colors.onSurface.withOpacity(0.6),
        ),
      ),

      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: isDark ? 0.5 : 0,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
      ),

      // ── Карточки ────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.outlineVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── Чипы ────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: colors.outlineVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // ── Диалоги ─────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ── BottomSheet ─────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ── FloatingActionButton ────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── Ввод ────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.outlineVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        hintStyle: TextStyle(
          color: colors.onSurface.withOpacity(0.4),
        ),
      ),

      // ── Разделители ─────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: colors.outline,
        thickness: 0.5,
        space: 0,
      ),

      // ── Снэкбары ────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ── Анимации ────────────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _CharoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: _CharoPageTransitionsBuilder(),
          TargetPlatform.linux: _CharoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Кастомный переход страниц — плавный слайд с fade
class _CharoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _CharoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final tween = Tween(begin: const Offset(0.05, 0), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic));
    final fadeTween = Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOut));

    return SlideTransition(
      position: animation.drive(tween),
      child: FadeTransition(
        opacity: animation.drive(fadeTween),
        child: child,
      ),
    );
  }
}

/// Расширения для удобной работы с темой
extension CharoColors on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get typography => Theme.of(this).textTheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // ─── Custom semantic colors (not in ColorScheme) ──────────────
  Color get success => isDarkMode ? const Color(0xFF34D399) : AppTheme.success;
  Color get warning => isDarkMode ? const Color(0xFFFBBF24) : AppTheme.warning;
  Color get info => isDarkMode ? const Color(0xFF60A5FA) : AppTheme.info;
  Color get accentLight => isDarkMode ? AppTheme.accentDark : AppTheme.accentLight;
}
