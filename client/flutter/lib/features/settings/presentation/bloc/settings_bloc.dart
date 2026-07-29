import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/logger.dart';

/// Settings BLoC — управление всеми настройками приложения
/// Синхронизация с сервером + локальный кэш
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final ApiClient? _apiClient;

  SettingsBloc({ApiClient? apiClient})
      : _apiClient = apiClient,
        super(const SettingsState()) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<SettingsThemeChanged>(_onThemeChanged);
    on<SettingsLanguageChanged>(_onLanguageChanged);
    on<SettingsTextScaleChanged>(_onTextScaleChanged);
    on<SettingsPrivacyChanged>(_onPrivacyChanged);
    on<SettingsNotificationChanged>(_onNotificationChanged);
    on<SettingsNetworkChanged>(_onNetworkChanged);
    on<SettingsMediaQualityChanged>(_onMediaQualityChanged);
  }

  Future<void> _onLoadRequested(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    // Load from local cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = SettingsState(
        themeMode: prefs.getString('settings_theme') ?? 'system',
        language: prefs.getString('settings_language') ?? 'system',
        textScale: prefs.getDouble('settings_textScale') ?? 1.0,
        profileVisibility: prefs.getString('settings_profileVisibility') ?? 'everyone',
        lastSeenVisibility: prefs.getString('settings_lastSeenVisibility') ?? 'everyone',
        whoCanMessage: prefs.getString('settings_whoCanMessage') ?? 'everyone',
        whoCanAddToGroups: prefs.getString('settings_whoCanAddToGroups') ?? 'contacts',
        readReceipts: prefs.getBool('settings_readReceipts') ?? true,
        pushEnabled: prefs.getBool('settings_pushEnabled') ?? true,
        soundEnabled: prefs.getBool('settings_soundEnabled') ?? true,
        proxyEnabled: prefs.getBool('settings_proxyEnabled') ?? false,
        proxyAddress: prefs.getString('settings_proxyAddress') ?? '',
        photoQuality: prefs.getString('settings_photoQuality') ?? 'high',
        videoQuality: prefs.getString('settings_videoQuality') ?? 'high',
      );
      emit(cached);
    } catch (e) {
      logger.w('Settings local cache load failed: $e');
    }

    // Then load from server
    if (_apiClient != null) {
      try {
        final response = await _apiClient!.get('/api/v1/settings');
        final data = response.asMap;
        final privacy = data['privacy'] as Map<String, dynamic>? ?? {};
        final notifications = data['notifications'] as Map<String, dynamic>? ?? {};

        emit(state.copyWith(
          profileVisibility: _mapPrivacyLevel(privacy['profileVisibility'] as String?),
          lastSeenVisibility: _mapPrivacyLevel(privacy['lastSeenVisibility'] as String?),
          whoCanMessage: _mapPrivacyLevel(privacy['whoCanMessage'] as String?),
          whoCanAddToGroups: _mapPrivacyLevel(privacy['whoCanAddToGroups'] as String?),
          readReceipts: privacy['readReceipts'] as bool? ?? state.readReceipts,
          pushEnabled: notifications['pushEnabled'] as bool? ?? notifications['push_enabled'] as bool? ?? state.pushEnabled,
          soundEnabled: notifications['soundEnabled'] as bool? ?? notifications['sound_enabled'] as bool? ?? state.soundEnabled,
          language: data['language'] as String? ?? state.language,
        ));
        await _persistState(state);
      } catch (e) {
        logger.w('Settings server load failed: $e');
      }
    }
  }

  void _onThemeChanged(SettingsThemeChanged event, Emitter<SettingsState> emit) {
    emit(state.copyWith(themeMode: event.themeMode));
    _persistKey('settings_theme', event.themeMode);
  }

  void _onLanguageChanged(SettingsLanguageChanged event, Emitter<SettingsState> emit) {
    emit(state.copyWith(language: event.language));
    _persistKey('settings_language', event.language);
    _saveToServer('appearance', {'language': event.language});
  }

  void _onTextScaleChanged(SettingsTextScaleChanged event, Emitter<SettingsState> emit) {
    emit(state.copyWith(textScale: event.textScale));
    _persistDouble('settings_textScale', event.textScale);
  }

  void _onPrivacyChanged(SettingsPrivacyChanged event, Emitter<SettingsState> emit) {
    emit(state.copyWith(
      profileVisibility: event.profileVisibility ?? state.profileVisibility,
      lastSeenVisibility: event.lastSeenVisibility ?? state.lastSeenVisibility,
      whoCanMessage: event.whoCanMessage ?? state.whoCanMessage,
      whoCanAddToGroups: event.whoCanAddToGroups ?? state.whoCanAddToGroups,
      readReceipts: event.readReceipts ?? state.readReceipts,
    ));
    _persistState(state);
    _saveToServer('privacy', {
      if (event.profileVisibility != null) 'profileVisibility': event.profileVisibility!.toUpperCase(),
      if (event.lastSeenVisibility != null) 'lastSeenVisibility': event.lastSeenVisibility!.toUpperCase(),
      if (event.whoCanMessage != null) 'whoCanMessage': event.whoCanMessage!.toUpperCase(),
      if (event.whoCanAddToGroups != null) 'whoCanAddToGroups': event.whoCanAddToGroups!.toUpperCase(),
      if (event.readReceipts != null) 'readReceipts': event.readReceipts,
    });
  }

  void _onNotificationChanged(SettingsNotificationChanged event, Emitter<SettingsState> emit) {
    emit(state.copyWith(
      pushEnabled: event.pushEnabled ?? state.pushEnabled,
      soundEnabled: event.soundEnabled ?? state.soundEnabled,
    ));
    _persistState(state);
    _saveToServer('notifications', {
      if (event.pushEnabled != null) 'pushEnabled': event.pushEnabled,
      if (event.soundEnabled != null) 'soundEnabled': event.soundEnabled,
    });
  }

  void _onNetworkChanged(SettingsNetworkChanged event, Emitter<SettingsState> emit) {
    emit(state.copyWith(
      proxyEnabled: event.proxyEnabled ?? state.proxyEnabled,
      proxyAddress: event.proxyAddress ?? state.proxyAddress,
    ));
    _persistState(state);
    _saveToServer('network', {
      if (event.proxyEnabled != null) 'proxyEnabled': event.proxyEnabled,
      if (event.proxyAddress != null) 'proxyAddress': event.proxyAddress,
    });
  }

  void _onMediaQualityChanged(SettingsMediaQualityChanged event, Emitter<SettingsState> emit) {
    emit(state.copyWith(
      photoQuality: event.photoQuality ?? state.photoQuality,
      videoQuality: event.videoQuality ?? state.videoQuality,
    ));
    _persistState(state);
    _saveToServer('storage', {
      if (event.photoQuality != null) 'photoQuality': event.photoQuality,
      if (event.videoQuality != null) 'videoQuality': event.videoQuality,
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  String _mapPrivacyLevel(String? value) {
    if (value == null) return 'everyone';
    final lower = value.toLowerCase();
    if (lower == 'nobody' || lower == 'contacts' || lower == 'everyone') return lower;
    return 'everyone';
  }

  Future<void> _persistState(SettingsState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('settings_theme', state.themeMode);
      await prefs.setString('settings_language', state.language);
      await prefs.setDouble('settings_textScale', state.textScale);
      await prefs.setString('settings_profileVisibility', state.profileVisibility);
      await prefs.setString('settings_lastSeenVisibility', state.lastSeenVisibility);
      await prefs.setString('settings_whoCanMessage', state.whoCanMessage);
      await prefs.setString('settings_whoCanAddToGroups', state.whoCanAddToGroups);
      await prefs.setBool('settings_readReceipts', state.readReceipts);
      await prefs.setBool('settings_pushEnabled', state.pushEnabled);
      await prefs.setBool('settings_soundEnabled', state.soundEnabled);
      await prefs.setBool('settings_proxyEnabled', state.proxyEnabled);
      await prefs.setString('settings_proxyAddress', state.proxyAddress);
      await prefs.setString('settings_photoQuality', state.photoQuality);
      await prefs.setString('settings_videoQuality', state.videoQuality);
    } catch (e) {
      logger.w('Settings persist failed: $e');
    }
  }

  Future<void> _persistKey(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  Future<void> _persistDouble(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (_) {}
  }

  Future<void> _saveToServer(String section, Map<String, dynamic> data) async {
    if (_apiClient == null) return;
    try {
      await _apiClient!.patch('/api/v1/settings/$section', data: data);
    } catch (e) {
      logger.w('Settings server save failed ($section): $e');
    }
  }
}

// ─── Events ────────────────────────────────────────────────────────

sealed class SettingsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

final class SettingsLoadRequested extends SettingsEvent {}

final class SettingsThemeChanged extends SettingsEvent {
  final String themeMode;
  SettingsThemeChanged({required this.themeMode});
  @override
  List<Object?> get props => [themeMode];
}

final class SettingsLanguageChanged extends SettingsEvent {
  final String language;
  SettingsLanguageChanged({required this.language});
  @override
  List<Object?> get props => [language];
}

final class SettingsTextScaleChanged extends SettingsEvent {
  final double textScale;
  SettingsTextScaleChanged({required this.textScale});
  @override
  List<Object?> get props => [textScale];
}

final class SettingsPrivacyChanged extends SettingsEvent {
  final String? profileVisibility;
  final String? lastSeenVisibility;
  final String? whoCanMessage;
  final String? whoCanAddToGroups;
  final bool? readReceipts;

  SettingsPrivacyChanged({
    this.profileVisibility,
    this.lastSeenVisibility,
    this.whoCanMessage,
    this.whoCanAddToGroups,
    this.readReceipts,
  });

  @override
  List<Object?> get props => [
        profileVisibility,
        lastSeenVisibility,
        whoCanMessage,
        whoCanAddToGroups,
        readReceipts,
      ];
}

final class SettingsNotificationChanged extends SettingsEvent {
  final bool? pushEnabled;
  final bool? soundEnabled;
  SettingsNotificationChanged({this.pushEnabled, this.soundEnabled});
  @override
  List<Object?> get props => [pushEnabled, soundEnabled];
}

final class SettingsNetworkChanged extends SettingsEvent {
  final bool? proxyEnabled;
  final String? proxyAddress;
  SettingsNetworkChanged({this.proxyEnabled, this.proxyAddress});
  @override
  List<Object?> get props => [proxyEnabled, proxyAddress];
}

final class SettingsMediaQualityChanged extends SettingsEvent {
  final String? photoQuality;
  final String? videoQuality;
  SettingsMediaQualityChanged({this.photoQuality, this.videoQuality});
  @override
  List<Object?> get props => [photoQuality, videoQuality];
}

// ─── State ─────────────────────────────────────────────────────────

class SettingsState extends Equatable {
  final String themeMode;
  final String language;
  final double textScale;
  final String profileVisibility;
  final String lastSeenVisibility;
  final String whoCanMessage;
  final String whoCanAddToGroups;
  final bool readReceipts;
  final bool pushEnabled;
  final bool soundEnabled;
  final bool proxyEnabled;
  final String proxyAddress;
  final String photoQuality;
  final String videoQuality;

  const SettingsState({
    this.themeMode = 'system',
    this.language = 'system',
    this.textScale = 1.0,
    this.profileVisibility = 'everyone',
    this.lastSeenVisibility = 'everyone',
    this.whoCanMessage = 'everyone',
    this.whoCanAddToGroups = 'contacts',
    this.readReceipts = true,
    this.pushEnabled = true,
    this.soundEnabled = true,
    this.proxyEnabled = false,
    this.proxyAddress = '',
    this.photoQuality = 'high',
    this.videoQuality = 'high',
  });

  SettingsState copyWith({
    String? themeMode,
    String? language,
    double? textScale,
    String? profileVisibility,
    String? lastSeenVisibility,
    String? whoCanMessage,
    String? whoCanAddToGroups,
    bool? readReceipts,
    bool? pushEnabled,
    bool? soundEnabled,
    bool? proxyEnabled,
    String? proxyAddress,
    String? photoQuality,
    String? videoQuality,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      textScale: textScale ?? this.textScale,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      lastSeenVisibility: lastSeenVisibility ?? this.lastSeenVisibility,
      whoCanMessage: whoCanMessage ?? this.whoCanMessage,
      whoCanAddToGroups: whoCanAddToGroups ?? this.whoCanAddToGroups,
      readReceipts: readReceipts ?? this.readReceipts,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      proxyEnabled: proxyEnabled ?? this.proxyEnabled,
      proxyAddress: proxyAddress ?? this.proxyAddress,
      photoQuality: photoQuality ?? this.photoQuality,
      videoQuality: videoQuality ?? this.videoQuality,
    );
  }

  @override
  List<Object?> get props => [
        themeMode, language, textScale,
        profileVisibility, lastSeenVisibility,
        whoCanMessage, whoCanAddToGroups, readReceipts,
        pushEnabled, soundEnabled,
        proxyEnabled, proxyAddress,
        photoQuality, videoQuality,
      ];
}
