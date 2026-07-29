import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:charo_messenger/features/settings/presentation/bloc/settings_bloc.dart';

void main() {
  group('SettingsBloc', () {
    late SettingsBloc settingsBloc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsBloc = SettingsBloc();
    });

    tearDown(() {
      settingsBloc.close();
    });

    test('initial state has correct defaults', () {
      expect(settingsBloc.state.themeMode, 'system');
      expect(settingsBloc.state.language, 'system');
      expect(settingsBloc.state.textScale, 1.0);
      expect(settingsBloc.state.profileVisibility, 'everyone');
      expect(settingsBloc.state.lastSeenVisibility, 'everyone');
      expect(settingsBloc.state.whoCanMessage, 'everyone');
      expect(settingsBloc.state.whoCanAddToGroups, 'contacts');
      expect(settingsBloc.state.readReceipts, true);
      expect(settingsBloc.state.pushEnabled, true);
      expect(settingsBloc.state.soundEnabled, true);
      expect(settingsBloc.state.proxyEnabled, false);
      expect(settingsBloc.state.proxyAddress, '');
      expect(settingsBloc.state.photoQuality, 'high');
      expect(settingsBloc.state.videoQuality, 'high');
    });

    test('SettingsThemeChanged updates themeMode', () async {
      settingsBloc.add(SettingsThemeChanged(themeMode: 'dark'));
      await expectLater(
        settingsBloc.stream,
        emits(isA<SettingsState>().having((s) => s.themeMode, 'themeMode', 'dark')),
      );
    });

    test('SettingsLanguageChanged updates language', () async {
      settingsBloc.add(SettingsLanguageChanged(language: 'ru'));
      await expectLater(
        settingsBloc.stream,
        emits(isA<SettingsState>().having((s) => s.language, 'language', 'ru')),
      );
    });

    test('SettingsTextScaleChanged updates textScale', () async {
      settingsBloc.add(SettingsTextScaleChanged(textScale: 1.5));
      await expectLater(
        settingsBloc.stream,
        emits(isA<SettingsState>().having((s) => s.textScale, 'textScale', 1.5)),
      );
    });

    test('SettingsPrivacyChanged updates privacy fields', () async {
      settingsBloc.add(SettingsPrivacyChanged(
        profileVisibility: 'contacts',
        lastSeenVisibility: 'nobody',
        readReceipts: false,
      ));
      await expectLater(
        settingsBloc.stream,
        emits(isA<SettingsState>()
            .having((s) => s.profileVisibility, 'profileVisibility', 'contacts')
            .having((s) => s.lastSeenVisibility, 'lastSeenVisibility', 'nobody')
            .having((s) => s.readReceipts, 'readReceipts', false)),
      );
    });

    test('SettingsNotificationChanged updates notification fields', () async {
      settingsBloc.add(SettingsNotificationChanged(
        pushEnabled: false,
        soundEnabled: false,
      ));
      await expectLater(
        settingsBloc.stream,
        emits(isA<SettingsState>()
            .having((s) => s.pushEnabled, 'pushEnabled', false)
            .having((s) => s.soundEnabled, 'soundEnabled', false)),
      );
    });

    test('SettingsNetworkChanged updates network fields', () async {
      settingsBloc.add(SettingsNetworkChanged(
        proxyEnabled: true,
        proxyAddress: 'socks5://proxy:1080',
      ));
      await expectLater(
        settingsBloc.stream,
        emits(isA<SettingsState>()
            .having((s) => s.proxyEnabled, 'proxyEnabled', true)
            .having((s) => s.proxyAddress, 'proxyAddress', 'socks5://proxy:1080')),
      );
    });

    test('SettingsMediaQualityChanged updates quality fields', () async {
      settingsBloc.add(SettingsMediaQualityChanged(
        photoQuality: 'low',
        videoQuality: 'medium',
      ));
      await expectLater(
        settingsBloc.stream,
        emits(isA<SettingsState>()
            .having((s) => s.photoQuality, 'photoQuality', 'low')
            .having((s) => s.videoQuality, 'videoQuality', 'medium')),
      );
    });

    test('SettingsLoadRequested loads from SharedPreferences cache', () async {
      SharedPreferences.setMockInitialValues({
        'settings_theme': 'dark',
        'settings_language': 'de',
        'settings_textScale': 1.3,
        'settings_profileVisibility': 'contacts',
        'settings_pushEnabled': false,
      });

      final bloc = SettingsBloc();
      bloc.add(SettingsLoadRequested());

      // Wait for the async load to complete
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.themeMode, 'dark');
      expect(bloc.state.language, 'de');
      expect(bloc.state.textScale, 1.3);
      expect(bloc.state.profileVisibility, 'contacts');
      expect(bloc.state.pushEnabled, false);

      bloc.close();
    });

    test('SettingsState copyWith preserves unchanged fields', () {
      const state = SettingsState(
        themeMode: 'dark',
        language: 'ru',
        textScale: 1.2,
      );
      final updated = state.copyWith(language: 'en');
      expect(updated.themeMode, 'dark');
      expect(updated.language, 'en');
      expect(updated.textScale, 1.2);
    });

    test('SettingsState equality works correctly', () {
      const state1 = SettingsState(themeMode: 'dark', language: 'ru');
      const state2 = SettingsState(themeMode: 'dark', language: 'ru');
      const state3 = SettingsState(themeMode: 'light', language: 'ru');
      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });
}
