import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_detail_screen.dart';
import '../../features/calls/presentation/screens/calls_screen.dart';
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
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../features/nearby/presentation/screens/nearby_screen.dart';

/// Навигация ЧАРО — GoRouter с вложенными маршрутами
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // Проверка авторизации выполняется через AuthBloc в main.dart
      return null;
    },
    routes: [
      // ── Авторизация ────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) => const OtpVerificationScreen(),
      ),

      // ── Основная навигация (Shell) ─────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/chats',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChatListScreen(),
            ),
          ),
          GoRoute(
            path: '/calls',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CallsScreen(),
            ),
          ),
          GoRoute(
            path: '/stories',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StoriesScreen(),
            ),
          ),
          GoRoute(
            path: '/contacts',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ContactsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsMainScreen(),
            ),
          ),
        ],
      ),

      // ── Чат ────────────────────────────────────────────────────
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final chatId = state.pathParameters['id']!;
          return ChatDetailScreen(chatId: chatId);
        },
      ),

      // ── Профиль ────────────────────────────────────────────────
      GoRoute(
        path: '/profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return ProfileScreen(userId: userId);
        },
      ),

      // ── Настройки (подэкраны) ──────────────────────────────────
      GoRoute(
        path: '/settings/privacy',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsPrivacyScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsNotificationsScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsAppearanceScreen(),
      ),
      GoRoute(
        path: '/settings/network',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsNetworkScreen(),
      ),
      GoRoute(
        path: '/settings/storage',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsStorageScreen(),
      ),
      GoRoute(
        path: '/settings/language',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsLanguageScreen(),
      ),
      GoRoute(
        path: '/settings/energy',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsEnergyScreen(),
      ),
      GoRoute(
        path: '/settings/media-quality',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsMediaQualityScreen(),
      ),
      GoRoute(
        path: '/settings/about',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsAboutScreen(),
      ),

      // ── AI-ассистент ───────────────────────────────────────────
      GoRoute(
        path: '/ai',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AiAssistantScreen(),
      ),

      // ── Кто рядом ──────────────────────────────────────────────
      GoRoute(
        path: '/nearby',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NearbyScreen(),
      ),
    ],
  );
}

/// Главный каркас приложения с нижней навигацией
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

/// Нижняя навигация с 5 табами
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

    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) {
        final routes = ['/chats', '/calls', '/stories', '/contacts', '/settings'];
        context.go(routes[i]);
      },
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
    );
  }
}
