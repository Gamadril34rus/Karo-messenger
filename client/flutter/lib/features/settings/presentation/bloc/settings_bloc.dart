import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Settings BLoC — управление всеми настройками приложения
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(const SettingsState()) {
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
    // Загрузка из локального хранилища (Hive/SharedPreferences)
    emit(const SettingsState());
  }

  void _onThemeChanged(
    SettingsThemeChanged event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(themeMode: event.themeMode));
  }

  void _onLanguageChanged(
    SettingsLanguageChanged event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(language: event.language));
  }

  void _onTextScaleChanged(
    SettingsTextScaleChanged event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(textScale: event.textScale));
  }

  void _onPrivacyChanged(
    SettingsPrivacyChanged event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(
      profileVisibility: event.profileVisibility ?? state.profileVisibility,
      lastSeenVisibility: event.lastSeenVisibility ?? state.lastSeenVisibility,
      whoCanMessage: event.whoCanMessage ?? state.whoCanMessage,
      whoCanAddToGroups: event.whoCanAddToGroups ?? state.whoCanAddToGroups,
      readReceipts: event.readReceipts ?? state.readReceipts,
    ));
  }

  void _onNotificationChanged(
    SettingsNotificationChanged event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(
      pushEnabled: event.pushEnabled ?? state.pushEnabled,
      soundEnabled: event.soundEnabled ?? state.soundEnabled,
    ));
  }

  void _onNetworkChanged(
    SettingsNetworkChanged event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(
      proxyEnabled: event.proxyEnabled ?? state.proxyEnabled,
      proxyAddress: event.proxyAddress ?? state.proxyAddress,
    ));
  }

  void _onMediaQualityChanged(
    SettingsMediaQualityChanged event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(
      photoQuality: event.photoQuality ?? state.photoQuality,
      videoQuality: event.videoQuality ?? state.videoQuality,
    ));
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
