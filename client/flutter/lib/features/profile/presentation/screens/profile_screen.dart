import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/profile_bloc.dart';

/// Экран профиля пользователя — аватарка, имя, настройки видимости
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
            ? [IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditProfile(context))]
            : [
                IconButton(icon: const Icon(Icons.call), onPressed: () => _initCall(false)),
                IconButton(icon: const Icon(Icons.videocam), onPressed: () => _initCall(true)),
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
            return Center(child: Text(state.message));
          }
          final profile = state is ProfileLoaded ? state : null;
          if (profile == null) return const SizedBox.shrink();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Аватарка
                GestureDetector(
                  onTap: isMe ? _changeAvatar : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 64,
                        backgroundColor: context.colors.primary.withOpacity(0.1),
                        backgroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? Text(
                                (profile.displayName ?? '?')[0].toUpperCase(),
                                style: context.typography.displayLarge?.copyWith(
                                  color: context.colors.primary,
                                ),
                              )
                            : null,
                      ),
                      if (isMe)
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.colors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Имя
                Text(
                  profile.displayName ?? 'Без имени',
                  style: context.typography.headlineMedium,
                ),
                const SizedBox(height: 4),

                // Никнейм
                Text(
                  '@${profile.username}',
                  style: context.typography.bodyLarge?.copyWith(
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(height: 4),

                // Статус онлайн
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: profile.isOnline ? context.colors.success : context.colors.onSurface.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      profile.isOnline ? 'в сети' : 'был(а) ${_formatLastSeen(profile.lastSeen)}',
                      style: context.typography.bodySmall?.copyWith(
                        color: profile.isOnline ? context.colors.success : context.colors.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Био
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.outlineVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(profile.bio!, style: context.typography.bodyLarge),
                  ),
                  const SizedBox(height: 24),
                ],

                // Информация
                if (profile.phone != null)
                  _InfoTile(icon: Icons.phone, label: 'Телефон', value: profile.phone!, visible: profile.phoneVisible),
                if (profile.email != null)
                  _InfoTile(icon: Icons.email, label: 'Email', value: profile.email!, visible: true),
                _InfoTile(icon: Icons.alternate_email, label: 'Никнейм', value: '@${profile.username}', visible: true),

                const SizedBox(height: 32),

                // Кнопки для чужого профиля
                if (!isMe) ...[
                  FilledButton.icon(
                    onPressed: () => _openChat(profile.userId),
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text('Написать'),
                    style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _initCall(false),
                    icon: const Icon(Icons.call),
                    label: const Text('Позвонить'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _initCall(true),
                    icon: const Icon(Icons.videocam),
                    label: const Text('Видеозвонок'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  ),
                ],

                // Настройки для своего профиля
                if (isMe) ...[
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Настройки'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Конфиденциальность'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/privacy'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.devices_outlined),
                    title: const Text('Устройства'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {/* Список устройств */},
                  ),
                ],
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Камера'), onTap: () { Navigator.pop(ctx); context.read<ProfileBloc>().add(ProfileAvatarChanged(source: 'camera')); }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Галерея'), onTap: () { Navigator.pop(ctx); context.read<ProfileBloc>().add(ProfileAvatarChanged(source: 'gallery')); }),
            ListTile(leading: const Icon(Icons.auto_awesome), title: const Text('Сгенерировать с AI'), onTap: () { Navigator.pop(ctx); context.read<ProfileBloc>().add(ProfileAvatarChanged(source: 'ai')); }),
            ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Удалить', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(ctx); context.read<ProfileBloc>().add(ProfileAvatarChanged(source: 'remove')); }),
          ],
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    final nameController = TextEditingController();
    final bioController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать профиль'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Имя')),
            const SizedBox(height: 12),
            TextField(controller: bioController, decoration: const InputDecoration(labelText: 'О себе'), maxLength: 256, maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProfileBloc>().add(ProfileUpdated(
                displayName: nameController.text.trim(),
                bio: bioController.text.trim(),
              ));
            },
            child: const Text('Сохранить'),
          ),
        ],
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool visible;

  const _InfoTile({required this.icon, required this.label, required this.value, required this.visible});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.colors.onSurface.withOpacity(0.6)),
      title: Text(label, style: context.typography.bodySmall),
      subtitle: Text(visible ? value : 'Скрыто', style: context.typography.bodyLarge),
      trailing: visible ? null : Icon(Icons.lock_outline, size: 16, color: context.colors.onSurface.withOpacity(0.4)),
    );
  }
}
