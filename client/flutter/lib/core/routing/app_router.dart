// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
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
import '../../features/calls/presentation/screens/incoming_call_screen.dart';
import '../../features/chat/presentation/screens/create_chat_screen.dart';
import '../../features/chat/presentation/screens/forward_message_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
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
import '../../features/settings/presentation/screens/settings_legal_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../features/nearby/presentation/screens/nearby_screen.dart';
import '../../features/chat/presentation/screens/sticker_import_screen.dart';
import '../../features/chat/presentation/screens/group_management_screen.dart';
import '../../features/chat/presentation/screens/chat_members_screen.dart';
import '../../features/chat/presentation/screens/contact_picker_screen.dart';
import '../../features/chat/presentation/screens/chat_wallpaper_screen.dart';
import '../../features/stories/presentation/screens/story_create_screen.dart';
import '../../features/settings/presentation/screens/block_list_screen.dart';
import '../../features/search/presentation/screens/global_search_screen.dart';
import '../../core/services/media_viewer_service.dart';
import '../../core/services/responsive_layout.dart';
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
      GoRoute(path: '/settings/privacy-policy', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const PrivacyPolicyScreen()),
      GoRoute(path: '/settings/terms', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const TermsOfServiceScreen()),
      GoRoute(path: '/sticker-import', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const StickerImportScreen()),

      // ── Group Management ────────────────────────────────────────
      GoRoute(
        path: '/group-management/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return GroupManagementScreen(
            chatId: state.pathParameters['id']!,
            chatTitle: extra['chatTitle'] as String? ?? 'Группа',
            avatarUrl: extra['avatarUrl'] as String?,
          );
        },
      ),

      // ── Chat Members ──────────────────────────────────────────────
      GoRoute(
        path: '/chat-members/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatMembersScreen(
            chatId: state.pathParameters['id']!,
            chatTitle: extra['chatTitle'] as String? ?? 'Чат',
          );
        },
      ),

      // ── Contact Picker ────────────────────────────────────────────
      GoRoute(
        path: '/contact-picker/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ContactPickerScreen(
            chatId: state.pathParameters['id']!,
            multiSelect: extra['multiSelect'] as bool? ?? true,
            title: extra['title'] as String? ?? 'Добавить участников',
          );
        },
      ),

      // ── Chat Wallpaper ────────────────────────────────────────────
      GoRoute(
        path: '/chat-wallpaper/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return ChatWallpaperScreen(
            chatId: state.pathParameters['id']!,
          );
        },
      ),

      // ── Story Create ──────────────────────────────────────────────
      GoRoute(
        path: '/story-create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return StoryCreateScreen(
            storyType: extra['storyType'] as String? ?? 'image',
          );
        },
      ),

      // ── Block List ───────────────────────────────────────────────
      GoRoute(
        path: '/block-list',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BlockListScreen(),
      ),

      // ── Media Viewer ─────────────────────────────────────────────
      GoRoute(
        path: '/media-viewer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MediaViewerScreen(
            mediaItems: (extra['items'] as List<MediaItem>?) ?? [],
            initialIndex: extra['initialIndex'] as int? ?? 0,
            chatTitle: extra['chatTitle'] as String? ?? '',
          );
        },
      ),

      // ── Global Search ────────────────────────────────────────────
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GlobalSearchScreen(),
      ),

      // ── Create Chat ──────────────────────────────────────────────
      GoRoute(
        path: '/create-chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreateChatScreen(
            chatType: extra['chatType'] as String? ?? 'private',
          );
        },
      ),

      // ── Forward Message ──────────────────────────────────────────
      GoRoute(
        path: '/forward',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ForwardMessageScreen(
            messageId: extra['messageId'] as String? ?? '',
            messagePreview: extra['messagePreview'] as String?,
          );
        },
      ),

      // ── Profile Edit ─────────────────────────────────────────────
      GoRoute(
        path: '/profile-edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileEditScreen(),
      ),
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

      // ── Incoming Call ────────────────────────────────────────────
      GoRoute(
        path: '/incoming-call/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final callId = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return IncomingCallScreen(
            callId: callId,
            callerId: extra['callerId'] as String? ?? '',
            callerName: extra['callerName'] as String? ?? 'Неизвестный',
            callerAvatarUrl: extra['callerAvatarUrl'] as String?,
            isVideo: extra['isVideo'] as bool? ?? false,
          );
        },
      ),
    ],
  );
}

/// Главный каркас приложения с премиальной нижней навигацией
/// На десктопе — адаптивный layout без bottom nav
class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (isDesktop) {
      // Desktop: side navigation rail instead of bottom nav
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex(context),
              onDestinationSelected: (i) {
                HapticService.selection();
                final routes = ['/chats', '/calls', '/stories', '/contacts', '/settings'];
                context.go(routes[i]);
              },
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 18),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: Text('Чаты'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.call_outlined),
                  selectedIcon: Icon(Icons.call),
                  label: Text('Звонки'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome),
                  label: Text('Истории'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Контакты'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Настройки'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // Mobile: bottom navigation bar
    return Scaffold(
      body: child,
      bottomNavigationBar: const CharoBottomNav(),
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/chats')) return 0;
    if (location.startsWith('/calls')) return 1;
    if (location.startsWith('/stories')) return 2;
    if (location.startsWith('/contacts')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
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
