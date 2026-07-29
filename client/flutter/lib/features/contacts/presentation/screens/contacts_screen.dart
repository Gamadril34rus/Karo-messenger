import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../bloc/contacts_bloc.dart';
import '../../data/contact_item.dart';

/// Экран контактов — список, поиск, добавление, удаление, синхронизация
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ContactsBloc>().add(ContactsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Контакты'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => HapticService.light()),
          IconButton(icon: const Icon(Icons.person_add), onPressed: _showAddContact),
          PopupMenuButton(
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'sync', child: Text('Синхронизировать')),
              const PopupMenuItem(value: 'invite', child: Text('Пригласить друга')),
              const PopupMenuItem(value: 'qr', child: Text('QR-код')),
            ],
            onSelected: (v) {
              HapticService.light();
              if (v == 'sync') context.read<ContactsBloc>().add(ContactsSyncRequested());
              if (v == 'qr') _showQrCode();
            },
          ),
        ],
      ),
      body: BlocBuilder<ContactsBloc, ContactsState>(
        builder: (context, state) {
          if (state is ContactsLoading) return const Center(child: CircularProgressIndicator());
          if (state is ContactsError) return Center(
            child: CharoCard(
              gradientColors: [context.colors.error.withOpacity(0.08), context.colors.outlineVariant],
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, size: 48, color: context.colors.error),
                const SizedBox(height: 16),
                Text(state.message, style: context.typography.bodyLarge),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    HapticService.light();
                    context.read<ContactsBloc>().add(ContactsLoadRequested());
                  },
                  child: const Text('Повторить'),
                ),
              ]),
            ),
          );
          final contacts = state is ContactsLoaded ? state.contacts : <ContactItem>[];
          if (contacts.isEmpty) return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline, size: 64, color: context.colors.onSurface.withOpacity(0.15)),
              const SizedBox(height: 16),
              Text('Нет контактов', style: context.typography.titleLarge?.copyWith(
                color: context.colors.onSurface.withOpacity(0.4),
              )),
              const SizedBox(height: 8),
              Text('Синхронизируйте телефонную книгу', style: context.typography.bodyMedium?.copyWith(
                color: context.colors.onSurface.withOpacity(0.3),
              )),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  HapticService.medium();
                  context.read<ContactsBloc>().add(ContactsSyncRequested());
                },
                child: const Text('Синхронизировать'),
              ),
            ]),
          );
          final online = contacts.where((c) => c.isOnline).toList();
          final offline = contacts.where((c) => !c.isOnline).toList();
          return ListView(
            children: [
              if (online.isNotEmpty)
                CharoSection(
                  title: 'В сети — ${online.length}',
                  children: [
                    for (final c in online) _ContactTile(contact: c),
                  ],
                ),
              if (offline.isNotEmpty)
                CharoSection(
                  title: 'Остальные — ${offline.length}',
                  children: [
                    for (final c in offline) _ContactTile(contact: c),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  void _showAddContact() {
    final controller = TextEditingController();
    HapticService.light();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить контакт'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Имя пользователя или телефон'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ContactsBloc>().add(ContactAdded(identifier: controller.text.trim()));
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _showQrCode() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ваш QR-код'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Icon(Icons.qr_code_2, size: 160)),
            ),
            const SizedBox(height: 16),
            Text('Покажите этот код другу', style: context.typography.bodyMedium),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ContactItem contact;
  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(contact.userId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmDelete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(Icons.person_remove, color: Colors.white),
      ),
      child: CharoTile(
        icon: Icons.person,
        iconColor: contact.isOnline ? context.colors.success : context.colors.onSurface.withOpacity(0.5),
        title: contact.displayName,
        subtitle: '@${contact.username}',
        onTap: () {
          HapticService.light();
          _showContactSheet(context, contact);
        },
        onLongPress: () => _showContactSheet(context, contact),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить контакт'),
        content: Text('Удалить ${contact.displayName} из списка контактов?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showContactSheet(BuildContext context, ContactItem contact) {
    HapticService.medium();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            CharoAvatar(
              radius: 36,
              imageUrl: contact.avatarUrl,
              fallbackText: contact.displayName,
              isOnline: contact.isOnline,
              showRing: contact.isOnline,
            ),
            const SizedBox(height: 12),
            Text(contact.displayName, style: context.typography.titleLarge),
            Text('@${contact.username}', style: context.typography.bodyMedium?.copyWith(
              color: context.colors.onSurface.withOpacity(0.5),
            )),
            const SizedBox(height: 20),
            CharoSection(
              title: 'Действия',
              children: [
                CharoTile(icon: Icons.chat, title: 'Написать', onTap: () {
                  HapticService.light();
                  Navigator.pop(ctx);
                  context.go('/chat/${contact.userId}');
                }),
                CharoTile(icon: Icons.call, title: 'Позвонить', onTap: () {
                  HapticService.light();
                  Navigator.pop(ctx);
                  context.go('/call/${contact.userId}', extra: {
                    'recipientName': contact.displayName,
                    'recipientAvatarUrl': contact.avatarUrl ?? '',
                    'isVideo': false,
                    'isOutgoing': true,
                  });
                }),
                CharoTile(icon: Icons.videocam, title: 'Видеозвонок', onTap: () {
                  HapticService.light();
                  Navigator.pop(ctx);
                  context.go('/call/${contact.userId}', extra: {
                    'recipientName': contact.displayName,
                    'recipientAvatarUrl': contact.avatarUrl ?? '',
                    'isVideo': true,
                    'isOutgoing': true,
                  });
                }),
                CharoTile(icon: Icons.block, title: 'Заблокировать', isDestructive: true, onTap: () {
                  HapticService.light();
                  Navigator.pop(ctx);
                  _confirmBlock(context);
                }),
                CharoTile(icon: Icons.person_remove, title: 'Удалить контакт', isDestructive: true, onTap: () {
                  HapticService.light();
                  Navigator.pop(ctx);
                  context.read<ContactsBloc>().add(ContactDeleted(userId: contact.userId));
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmBlock(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заблокировать'),
        content: Text('Заблокировать ${contact.displayName}? Пользователь не сможет отправлять вам сообщения.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ContactsBloc>().add(ContactDeleted(userId: contact.userId));
            },
            child: const Text('Заблокировать'),
          ),
        ],
      ),
    );
  }
}
