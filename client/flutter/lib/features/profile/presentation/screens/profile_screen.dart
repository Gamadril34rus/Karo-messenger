import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../bloc/profile_bloc.dart';

/// Экран профиля — премиальный вид с gradient header, shimmer avatar,
/// grouped sections, и плавными анимациями.
class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      context.read<ProfileBloc>().add(ProfileLoadRequested(userId: widget.userId!));
    } else {
      context.read<ProfileBloc>().add(ProfileMeRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'Мой профиль' : 'Профиль'),
        actions: isMe
            ? [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.go('/profile-edit'))]
            : [
                IconButton(icon: const Icon(Icons.call_outlined), onPressed: () => _initCall(false)),
                IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () => _initCall(true)),
                PopupMenuButton(itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'mute', child: Text('Отключить уведомления')),
                  const PopupMenuItem(value: 'secret', child: Text('Секретный чат')),
                  const PopupMenuItem(value: 'block', child: Text('Заблокировать')),
                ],
                onSelected: (v) => _onMenuAction(v as String)),
              ],
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ProfileError) {
            return Center(
              child: CharoCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: context.colors.error),
                    const SizedBox(height: 16),
                    Text(state.message, style: context.typography.bodyLarge),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        if (widget.userId != null) {
                          context.read<ProfileBloc>().add(ProfileLoadRequested(userId: widget.userId!));
                        } else {
                          context.read<ProfileBloc>().add(ProfileMeRequested());
                        }
                      },
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          final profile = state is ProfileLoaded ? state : null;
          if (profile == null) return const SizedBox.shrink();

          return SingleChildScrollView(
            child: Column(
              children: [
                // ── Premium gradient header with avatar ───────────
                CharoHeaderCard(
                  height: 200,
                  radius: 24,
                  child: Center(
                    child: CharoAvatar(
                      radius: 56,
                      imageUrl: profile.avatarUrl,
                      fallbackText: profile.displayName ?? '?',
                      isOnline: profile.isOnline,
                      showRing: isMe,
                      showEditBadge: isMe,
                      onEditTap: _changeAvatar,
                    ),
                  ),
                ),

                // ── Name, username, status ────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    children: [
                      Text(
                        profile.displayName ?? 'Без имени',
                        style: context.typography.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${profile.username}',
                        style: context.typography.bodyLarge?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Online status with animated dot
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: AppConstants.animationDurationMedium,
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: profile.isOnline
                                  ? context.colors.success
                                  : context.colors.onSurface.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            profile.isOnline
                                ? 'в сети'
                                : 'был(а) ${_formatLastSeen(profile.lastSeen)}',
                            style: context.typography.bodyMedium?.copyWith(
                              color: profile.isOnline
                                  ? context.colors.success
                                  : context.colors.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Bio card ──────────────────────────────────────
                if (profile.bio != null && profile.bio!.isNotEmpty)
                  CharoCard(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(16),
                    child: Text(profile.bio!, style: context.typography.bodyLarge),
                  ),

                const SizedBox(height: 12),

                // ── Contact info section ──────────────────────────
                CharoSection(
                  title: 'Информация',
                  children: [
                    if (profile.phone != null)
                      CharoTile(
                        icon: Icons.phone_outlined,
                        iconColor: Colors.blue,
                        title: profile.phone!,
                        subtitle: profile.phoneVisible ? 'Телефон' : 'Скрыто',
                        trailing: profile.phoneVisible
                            ? null
                            : Icon(Icons.lock_outline, size: 16, color: context.colors.onSurface.withOpacity(0.4)),
                      ),
                    if (profile.email != null)
                      CharoTile(
                        icon: Icons.email_outlined,
                        iconColor: Colors.red,
                        title: profile.email!,
                        subtitle: 'Email',
                      ),
                    CharoTile(
                      icon: Icons.alternate_email,
                      iconColor: context.colors.primary,
                      title: '@${profile.username}',
                      subtitle: 'Никнейм',
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Actions for other user's profile ──────────────
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        FilledButton.icon(
                          onPressed: () => _openChat(profile.userId),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Написать'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _initCall(false),
                                icon: const Icon(Icons.call_outlined),
                                label: const Text('Позвонить'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _initCall(true),
                                icon: const Icon(Icons.videocam_outlined),
                                label: const Text('Видео'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // ── My profile: settings section ──────────────────
                if (isMe)
                  CharoSection(
                    title: 'Настройки аккаунта',
                    children: [
                      CharoTile(
                        icon: Icons.settings_outlined,
                        title: 'Настройки',
                        subtitle: 'Все параметры приложения',
                        onTap: () => context.go('/settings'),
                      ),
                      CharoTile(
                        icon: Icons.lock_outline,
                        title: 'Конфиденциальность',
                        subtitle: 'Кто видит профиль, кто может писать',
                        onTap: () => context.go('/settings/privacy'),
                      ),
                      CharoTile(
                        icon: Icons.devices_outlined,
                        title: 'Устройства',
                        subtitle: 'Активные сессии',
                        onTap: () => context.go('/settings/privacy'),
                      ),
                      CharoTile(
                        icon: Icons.enhanced_encryption,
                        title: 'Секретные чаты',
                        subtitle: 'E2E-шифрование Signal Protocol',
                        onTap: () => context.go('/settings/privacy'),
                      ),
                    ],
                  ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  void _changeAvatar() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Изменить аватарку', style: context.typography.titleLarge),
              const SizedBox(height: 16),
              CharoTile(
                icon: Icons.camera_alt_outlined,
                iconColor: Colors.blue,
                title: 'Камера',
                onTap: () { Navigator.pop(ctx); context.read<ProfileBloc>().add(ProfileAvatarChanged(source: 'camera')); },
              ),
              CharoTile(
                icon: Icons.photo_library_outlined,
                iconColor: Colors.green,
                title: 'Галерея',
                onTap: () { Navigator.pop(ctx); context.read<ProfileBloc>().add(ProfileAvatarChanged(source: 'gallery')); },
              ),
              CharoTile(
                icon: Icons.auto_awesome_outlined,
                iconColor: context.colors.secondary,
                title: 'Сгенерировать с AI',
                subtitle: 'Уникальный аватар на основе вашего стиля',
                onTap: () { Navigator.pop(ctx); context.read<ProfileBloc>().add(ProfileAvatarChanged(source: 'ai')); },
              ),
              CharoTile(
                icon: Icons.delete_outline,
                iconColor: Colors.red,
                title: 'Удалить',
                isDestructive: true,
                onTap: () { Navigator.pop(ctx); context.read<ProfileBloc>().add(ProfileAvatarChanged(source: 'remove')); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    final nameController = TextEditingController();
    final bioController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Редактировать профиль', style: context.typography.headlineMedium),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bioController,
                  decoration: const InputDecoration(
                    labelText: 'О себе',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                  maxLength: 256,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.read<ProfileBloc>().add(ProfileUpdated(
                            displayName: nameController.text.trim(),
                            bio: bioController.text.trim(),
                          ));
                        },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openChat(String userId) {
    context.go('/chat/$userId');
  }

  void _initCall(bool isVideo) {
    context.read<ProfileBloc>().add(ProfileCallInitiated(isVideo: isVideo));
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'mute':
        context.read<ProfileBloc>().add(ProfileMuteToggled());
        break;
      case 'secret':
        context.read<ProfileBloc>().add(ProfileSecretChatRequested());
        break;
      case 'block':
        _showBlockDialog();
        break;
    }
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Заблокировать?'),
        content: const Text('Пользователь не сможет писать вам и видеть ваш профиль.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProfileBloc>().add(ProfileBlocked());
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Заблокировать'),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'давно';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 5) return 'недавно';
    if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
    if (diff.inDays < 1) return '${diff.inHours} ч. назад';
    return '${lastSeen.day}.${lastSeen.month}';
  }
}
