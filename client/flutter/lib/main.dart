import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/network/ws_client.dart';
import 'core/storage/secure_storage.dart';
import 'core/storage/local_db.dart';
import 'core/e2ee/e2ee_manager.dart';
import 'core/audio/notification_service.dart';
import 'core/utils/logger.dart';
import 'i18n/localizations_delegate.dart';

import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/chat/presentation/bloc/chat_list/chat_bloc.dart';
import 'features/chat/presentation/bloc/chat_detail/chat_bloc.dart';
import 'features/contacts/presentation/bloc/contacts_bloc.dart';
import 'features/calls/presentation/bloc/calls_bloc.dart';
import 'features/stories/presentation/bloc/stories_bloc.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import 'features/nearby/presentation/bloc/nearby_bloc.dart';

final sl = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Строгая ориентация для мобильных
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Строка состояния
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Инициализация хранилищ
  await Hive.initFlutter();
  final secureStorage = SecureStorageHelper();
  final localDb = AppDatabase();

  // Регистрация зависимостей
  await _setupDependencies(secureStorage, localDb);

  logger.i('🚀 ЧАРО v${AppConstants.appVersion} запущен');

  runApp(const AppCharoApp());
}

Future<void> _setupDependencies(
  SecureStorageHelper secureStorage,
  AppDatabase localDb,
) async {
  // Core
  sl.registerLazySingleton<SecureStorageHelper>(() => secureStorage);
  sl.registerLazySingleton<AppDatabase>(() => localDb);

  // Network
  final apiClient = ApiClient(sl());
  sl.registerLazySingleton<ApiClient>(() => apiClient);
  sl.registerLazySingleton<WsClient>(() => WsClient(sl()));

  // E2EE — connect to ApiClient for server key publishing
  E2EEKeyManager.instance.setApiClient(apiClient);

  // BLoCs
  sl.registerFactory(() => AuthBloc(
        apiClient: sl(),
        secureStorage: sl(),
        wsClient: sl(),
      ));
  sl.registerFactory(() => ChatListBloc(
        apiClient: sl(),
        wsClient: sl(),
        localDb: sl(),
      ));
  sl.registerFactory(() => ChatDetailBloc(
        apiClient: sl(),
        wsClient: sl(),
        localDb: sl(),
      ));
  sl.registerFactory(() => ContactsBloc(apiClient: sl()));
  sl.registerFactory(() => CallsBloc(apiClient: sl(), wsClient: sl()));
  sl.registerFactory(() => StoriesBloc(apiClient: sl()));
  sl.registerFactory(() => ProfileBloc(apiClient: sl(), secureStorage: sl(), wsClient: sl()));
  sl.registerFactory(() => SettingsBloc());
  sl.registerFactory(() => AiAssistantBloc(apiClient: sl()));
  sl.registerFactory(() => NearbyBloc(apiClient: sl()));
}

class AppCharoApp extends StatelessWidget {
  const AppCharoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AuthBloc>()..add(AuthCheckRequested())),
        BlocProvider(create: (_) => sl<SettingsBloc>()..add(SettingsLoadRequested())),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return MaterialApp.router(
            title: 'ЧАРО',
            debugShowCheckedModeBanner: false,

            // Тема
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _resolveThemeMode(settingsState.themeMode),

            // Локализация
            locale: _resolveLocale(settingsState.language),
            supportedLocales: AppConstants.supportedLocales,
            localizationsDelegates: [
              ...AppConstants.localizationDelegates,
              CharoLocalizations.delegate,
            ],

            // Навигация
            routerConfig: AppRouter.router,

            // Производительность
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    settingsState.textScale,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }

  ThemeMode _resolveThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'amoled':
        return ThemeMode.dark; // AMOLED обрабатывается в AppTheme
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Locale _resolveLocale(String language) {
    if (language == 'system') {
      return WidgetsBinding.instance.platformDispatcher.locale;
    }
    return Locale(language);
  }
}
