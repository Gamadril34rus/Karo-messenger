import 'dart:async';
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
import 'core/domain/charo_repository.dart';
import 'core/data/charo_api_repository.dart';
import 'core/e2ee/e2ee_manager.dart';
import 'core/audio/notification_service.dart';
import 'core/utils/logger.dart';
import 'i18n/localizations_delegate.dart';

import 'core/services/offline_sync_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/voice_message_service.dart';
import 'core/services/disappearing_messages_service.dart';
import 'core/services/presence_service.dart';
import 'core/services/block_list_service.dart';
import 'core/services/group_management_service.dart';
import 'core/services/email_verification_service.dart';
import 'core/services/crash_reporting_service.dart';

import 'features/calls/presentation/screens/incoming_call_screen.dart';

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

  // Repository — абстрактный слой для замены сервера
  sl.registerLazySingleton<CharoRepository>(() => CharoApiRepository(
    apiClient: sl(), wsClient: sl(),
  ));

  // E2EE — connect to ApiClient for server key publishing
  E2EEKeyManager.instance.setApiClient(apiClient);

  // ─── Сервисы ──────────────────────────────────────────────────────

  // Offline-First: синхронизация очереди и gap-filling
  sl.registerLazySingleton<OfflineSyncService>(() => OfflineSyncService.instance);

  // Push-уведомления (FCM/APNS)
  sl.registerLazySingleton<PushNotificationService>(() => PushNotificationService.instance);

  // Голосовые сообщения (запись через record package)
  sl.registerLazySingleton<VoiceMessageService>(() => VoiceMessageService.instance);

  // Исчезающие сообщения (клиентские таймеры)
  sl.registerLazySingleton<DisappearingMessagesService>(() => DisappearingMessagesService.instance);

  // Присутствие (online/offline, «был(а) в сети»)
  sl.registerLazySingleton<PresenceService>(() => PresenceService.instance);

  // Чёрный список
  sl.registerLazySingleton<BlockListService>(() => BlockListService(repository: sl()));

  // Управление группами
  sl.registerLazySingleton<GroupManagementService>(() => GroupManagementService(repository: sl()));

  // Верификация email
  sl.registerLazySingleton<EmailVerificationService>(() => EmailVerificationService(apiClient: sl()));

  // Crash reporting (Sentry)
  sl.registerLazySingleton<CrashReportingService>(() => CrashReportingService.instance);

  // ─── Инициализация сервисов ──────────────────────────────────────

  // Disappearing messages — привязка к локальной БД
  sl<DisappearingMessagesService>().initialize(localDb);

  // Presence — подписка на WS events
  sl<PresenceService>().initialize(sl<WsClient>());

  // Push-уведомления — инициализация
  await sl<PushNotificationService>().initialize();

  // Crash reporting — Sentry
  await sl<CrashReportingService>().initialize();

  // ─── Bridge: WsClient → OfflineSyncService ────────────────────────
  // При восстановлении WS-соединения — помечаем онлайн и flush queue
  sl<WsClient>().connectionState.listen((wsState) {
    final offlineSync = sl<OfflineSyncService>();
    if (wsState == WsConnectionState.connected) {
      offlineSync.setOnline(true);
      // Gap-fill sync при reconnect
      offlineSync.syncAllChats(sl<ApiClient>(), sl<AppDatabase>());
    } else if (wsState == WsConnectionState.disconnected ||
               wsState == WsConnectionState.error ||
               wsState == WsConnectionState.failed) {
      offlineSync.setOnline(false);
    }
  });

  // ─── Bridge: WsClient → Incoming Call ─────────────────────────────
  // При получении call.incoming — показываем экран входящего звонка
  sl<WsClient>().messages.listen((event) {
    if (event.type == 'call.incoming') {
      final callId = event.data['callId'] as String? ?? '';
      final callerId = event.data['callerId'] as String? ?? '';
      final callType = event.data['type'] as String? ?? 'voice';
      // Navigate to incoming call screen via global navigator
      final navigatorKey = AppRouter.router.configuration.navigatorKey;
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              callId: callId,
              callerId: callerId,
              callerName: event.data['callerName'] as String? ?? 'Неизвестный',
              callerAvatarUrl: event.data['callerAvatarUrl'] as String?,
              isVideo: callType == 'video',
            ),
          ),
        );
      }
    }
  });

  // ─── BLoCs ────────────────────────────────────────────────────────
  // Все BLoC-и работают через CharoRepository — замена сервера
  // требует только новой реализации CharoRepository
  sl.registerFactory(() => AuthBloc(
        repository: sl(),
        secureStorage: sl(),
        wsClient: sl(),
      ));
  sl.registerFactory(() => ChatListBloc(
        repository: sl(),
        wsClient: sl(),
        localDb: sl(),
      ));
  sl.registerFactory(() => ChatDetailBloc(
        repository: sl(),
        wsClient: sl(),
        localDb: sl(),
      ));
  sl.registerFactory(() => ContactsBloc(repository: sl(), localDb: sl()));
  sl.registerFactory(() => CallsBloc(repository: sl(), wsClient: sl()));
  sl.registerFactory(() => StoriesBloc(repository: sl()));
  sl.registerFactory(() => ProfileBloc(repository: sl(), wsClient: sl()));
  sl.registerFactory(() => SettingsBloc(repository: sl()));
  sl.registerFactory(() => AiAssistantBloc(repository: sl()));
  sl.registerFactory(() => NearbyBloc(repository: sl()));
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
