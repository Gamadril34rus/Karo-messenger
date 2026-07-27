import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// CharoLocalizationsDelegate — динамическая загрузка JSON-файлов локализации.
///
/// Загружает strings_<locale>.json из assets/i18n/ или lib/i18n/.
/// Поддерживает 35+ языков России и основные мировые.
/// Falls back на русский если locale не найден.
class CharoLocalizations {
  final Locale locale;
  final Map<String, String> _strings;

  CharoLocalizations(this.locale, this._strings);

  /// Get a localized string by key
  String get(String key) => _strings[key] ?? key;

  /// Shorthand operator
  String operator [](String key) => get(key);

  /// Static delegate instance
  static const LocalizationsDelegate<CharoLocalizations> delegate =
      _CharoLocalizationsDelegate();

  /// Get current localizations from context
  static CharoLocalizations of(BuildContext context) {
    return Localizations.of<CharoLocalizations>(context, CharoLocalizations)!;
  }
}

class _CharoLocalizationsDelegate
    extends LocalizationsDelegate<CharoLocalizations> {
  const _CharoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Support all locales that have a JSON file
    return true; // We'll try to load any locale
  }

  @override
  Future<CharoLocalizations> load(Locale locale) async {
    // Try to load JSON for exact locale
    final strings = await _loadLocaleStrings(locale.languageCode);
    return CharoLocalizations(locale, strings);
  }

  @override
  bool shouldReload(_CharoLocalizationsDelegate old) => false;

  Future<Map<String, String>> _loadLocaleStrings(String code) async {
    // Try full locale code first
    final paths = [
      'lib/i18n/strings_$code.json',
      'assets/i18n/strings_$code.json',
    ];

    for (final path in paths) {
      try {
        final jsonStr = await rootBundle.loadString(path);
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return json.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        continue;
      }
    }

    // Fallback to Russian
    try {
      final jsonStr = await rootBundle.loadString('lib/i18n/strings_ru.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return json.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      // Ultimate fallback: return empty map (strings.dart used as static)
      return {};
    }
  }
}
