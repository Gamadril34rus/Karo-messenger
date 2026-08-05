// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Глобальные константы ЧАРО
class AppConstants {
  AppConstants._();

  // ─── Приложение ───────────────────────────────────────────────
  static const String appName = 'ЧАРО';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // ─── API ──────────────────────────────────────────────────────
  static const String apiBaseUrl = 'https://api.charo.chat';
  static const String wsUrl = 'wss://ws.charo.chat';
  static const String cdnUrl = 'https://cdn.charo.chat';

  // Зеркальные домены для анти-блокировок
  static const List<String> mirrorDomains = [
    'https://api.charo.chat',
    'https://api1.charo.chat',
    'https://api2.charo.chat',
    'https://charo-api.cloudflare.com',
    'https://charo-api.bypass.workers.dev',
  ];

  // DNS-over-HTTPS
  static const List<String> dohServers = [
    'https://cloudflare-dns.com/dns-query',
    'https://dns.google/dns-query',
    'https://dns.quad9.net/dns-query',
  ];

  // ─── Ограничения ──────────────────────────────────────────────
  static const int maxMessageLength = 4096;
  static const int maxFileSize = 2 * 1024 * 1024 * 1024; // 2 GB
  static const int maxGroupMembers = 200000;
  static const int maxChannelSubscribers = 10000000;
  static const int maxCallParticipants = 1000;
  static const int maxVideoCallParticipants = 32;
  static const int maxStoriesPerDay = 100;
  static const int maxStickersInPack = 120;
  static const int maxBioLength = 256;
  static const int maxUsernameLength = 64;
  static const int maxGroupNameLength = 255;
  static const int maxDescriptionLength = 2048;

  // ─── Таймеры исчезающих сообщений (секунды) ───────────────────
  static const List<int> disappearingTimers = [
    5,       // 5 секунд
    30,      // 30 секунд
    60,      // 1 минута
    300,     // 5 минут
    600,     // 10 минут
    1800,    // 30 минут
    3600,    // 1 час
    21600,   // 6 часов
    43200,   // 12 часов
    86400,   // 1 день
    604800,  // 7 дней
  ];

  // ─── Качество медиа ───────────────────────────────────────────
  static const Map<String, Map<String, dynamic>> mediaQuality = {
    'original': {
      'label': 'Оригинал',
      'photoMaxDim': null,
      'photoQuality': 100,
      'videoBitrate': null,
    },
    'high': {
      'label': 'Высокое',
      'photoMaxDim': 2560,
      'photoQuality': 90,
      'videoBitrate': 2500000,
    },
    'medium': {
      'label': 'Среднее',
      'photoMaxDim': 1280,
      'photoQuality': 80,
      'videoBitrate': 1500000,
    },
    'low': {
      'label': 'Эконом',
      'photoMaxDim': 640,
      'photoQuality': 60,
      'videoBitrate': 800000,
    },
  };

  // ─── Языки (все языки России + основные мировые) ──────────────
  static const Map<String, String> supportedLanguages = {
    // Официальные языки России
    'ru': 'Русский',
    'tt': 'Татарча',
    'ba': 'Башҡортса',
    'ce': 'Нохчийн',
    'cv': 'Чӑвашла',
    'hy': 'Հայերեն',
    'sah': 'Саха тыла',
    'bxr': 'Буряад',
    'os': 'Ирон',
    'mhr': 'Марий',
    'udm': 'Удмурт',
    'kom': 'Коми',
    'kum': 'Къумукъ',
    'av': 'Авар',
    'lez': 'Лезги',
    'tab': 'Табасаран',
    'kbd': 'Адыгэбзэ',
    'ady': 'Адыгабзэ',
    'krc': 'Къарачай-Малкъар',
    'myv': 'Эрзянь',
    'mdf': 'Мокшень',
    'tyv': 'Тыва дыл',
    'alt': 'Алтай тил',
    'hak': 'Хакас',
    'eve': 'Эвэды',
    'chm': 'Мари',
    'koi': 'Перем коми',
    'sr_Cyrl': 'Српски',
    'kk': 'Қазақша',
    'be': 'Беларуская',
    'uk': 'Українська',

    // Мировые языки
    'en': 'English',
    'de': 'Deutsch',
    'fr': 'Français',
    'es': 'Español',
    'pt': 'Português',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
    'ar': 'العربية',
    'hi': 'हिन्दी',
    'tr': 'Türkçe',
  };

  static List<Locale> supportedLocales = supportedLanguages.keys
      .map((code) => Locale(code))
      .toList();

  static const localizationDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  // ─── Темы ─────────────────────────────────────────────────────
  static const List<Map<String, String>> themeOptions = [
    {'key': 'system', 'label': 'Системная'},
    {'key': 'light', 'label': 'Светлая'},
    {'key': 'dark', 'label': 'Тёмная'},
    {'key': 'amoled', 'label': 'AMOLED'},
  ];

  // ─── Размер текста ────────────────────────────────────────────
  static const double textScaleMin = 0.8;
  static const double textScaleMax = 1.8;
  static const double textScaleDefault = 1.0;

  // ─── Настройки приватности ────────────────────────────────────
  static const List<Map<String, String>> privacyLevels = [
    {'key': 'everyone', 'label': 'Все'},
    {'key': 'contacts', 'label': 'Только контакты'},
    {'key': 'nobody', 'label': 'Никто'},
  ];

  // ─── Анимации ─────────────────────────────────────────────────
  static const Duration animationDurationShort = Duration(milliseconds: 150);
  static const Duration animationDurationMedium = Duration(milliseconds: 300);
  static const Duration animationDurationLong = Duration(milliseconds: 500);

  // ─── Хранилище ────────────────────────────────────────────────
  static const int cacheMaxSizeMB = 512;
  static const int autoDownloadWifiMaxMB = 50;
  static const int autoDownloadMobileMaxMB = 10;
}
