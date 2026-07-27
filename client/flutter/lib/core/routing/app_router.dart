import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/account_recovery_screen.dart';
import '../../features/auth/presentation/screens/two_fa_verification_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_detail_screen.dart';
import '../../features/calls/presentation/screens/calls_screen.dart';
import '../../features/calls/presentation/screens/active_call_screen.dart';
import '../../features/stories/presentation/screens/stories_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/settings_main_screen.dart';
import '../../features/settings/presentation/screens/settings_privacy_screen.dart';
import '../../features/settings/presentation/screens/settings_notifications_screen.dart';
import '../../features/settings/presentation/screens/settings_appearance_screen.dart';
import '../../features/settings/presentation/screens/settings_network_screen.dart';
import '../../features/settings/presentation/screens/settings_storage_screen.dart';
import '../../features/settings/presentation/screens/settings_language_screen.dart';
import '../../features/settings/presentation/screens/settings_energy_screen.dart';
import '../../features/settings/presentation/screens/settings_media_quality_screen.dart';
import '../../features/settings/presentation/screens/settings_about_screen.dart';
import '../../features/settings/presentation/screens/data_export_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../features/nearby/presentation/screens/nearby_screen.dart';
import '../../core/haptic/haptic_service.dart';

/// Навигация ЧАРО — GoRouter с вложенными маршрутами
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) => null,
    routes: [
      // ── Auth ────────────────────────────────────────────────
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/verify', builder: (context, state) => const OtpVerificationScreen()),
      GoRoute(
        path: '/2fa',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return TwoFaVerificationScreen();
        },
      ),
      GoRoute(
        path: '/auth/recover',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AccountRecoveryScreen(
            accountId: extra['accountId'] as String? ?? '',
            recoveryCode: extra['recoveryCode'] as String? ?? '',
          );
        },
      ),

      // ── Main shell with premium bottom nav ──────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/chats', pageBuilder: (context, state) => const NoTransitionPage(child: ChatListScreen())),
          GoRoute(path: '/calls', pageBuilder: (context, state) => const NoTransitionPage(child: CallsScreen())),
          GoRoute(path: '/stories', pageBuilder: (context, state) => const NoTransitionPage(child: StoriesScreen())),
          GoRoute(path: '/contacts', pageBuilder: (context, state) => const NoTransitionPage(child: ContactsScreen())),
          GoRoute(path: '/settings', pageBuilder: (context, state) => const NoTransitionPage(child: SettingsMainScreen())),
        ],
      ),

      // ── Chat detail ─────────────────────────────────────────
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ChatDetailScreen(chatId: state.pathParameters['id']!),
      ),

      // ── Profile ─────────────────────────────────────────────
      GoRoute(path: '/profile', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const ProfileScreen()),
      GoRoute(
        path: '/profile/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ProfileScreen(userId: state.pathParameters['id']),
      ),

      // ── Settings sub-screens ────────────────────────────────
      GoRoute(path: '/settings/privacy', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const SettingsPrivacyScreen()),
      GoRoute(path: '/settings/notifications', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const SettingsNotificationsScreen()),
      GoRoute(path: '/settings/appearance', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const SettingsAppearanceScreen()),
      GoRoute(path: '/settings/network', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const SettingsNetworkScreen()),
      GoRoute(path: '/settings/storage', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const SettingsStorageScreen()),
      GoRoute(path: '/settings/language', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const SettingsLanguageScreen()),
      GoRoute(path: '/settings/energy', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const SettingsEnergyScreen()),
      GoRoute(path: '/settings/media-quality', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const SettingsMediaQualityScreen()),
      GoRoute(path: '/settings/about', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const SettingsAboutScreen()),
      GoRoute(path: '/settings/data-export', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const DataExportScreen()),
      GoRoute(path: '/ai', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const AiAssistantScreen()),
      GoRoute(path: '/nearby', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const NearbyScreen()),

      // ── Active Call ────────────────────────────────────────────
      GoRoute(
        path: '/call/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final callId = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ActiveCallScreen(
            callId: callId,
            recipientName: extra['recipientName'] as String? ?? 'Неизвестный',
            recipientAvatarUrl: extra['recipientAvatarUrl'] as String? ?? '',
            isVideo: extra['isVideo'] as bool? ?? false,
            isOutgoing: extra['isOutgoing'] as bool? ?? true,
          );
        },
      ),
    ],
  );
}

/// Главный каркас приложения с премиальной нижней навигацией
class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const CharoBottomNav(),
    );
  }
}

/// Премиальная нижняя навигация — Material 3 NavigationBar с haptic feedback
class CharoBottomNav extends StatelessWidget {
  const CharoBottomNav({super.key});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/chats')) return 0;
    if (location.startsWith('/calls')) return 1;
    if (location.startsWith('/stories')) return 2;
    if (location.startsWith('/contacts')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          // Haptic feedback on tab switch
          HapticService.selection();
          final routes = ['/chats', '/calls', '/stories', '/contacts', '/settings'];
          context.go(routes[i]);
        },
        height: 64,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Чаты',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'Звонки',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Истории',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Контакты',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}
