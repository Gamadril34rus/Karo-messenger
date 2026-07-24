import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/contacts_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Экран контактов — список, поиск, синхронизация
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
      appBar: AppBar(title: const Text('Контакты'), actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: () => showSearch(context: context, delegate: _ContactsSearchDelegate())),
        IconButton(icon: const Icon(Icons.person_add), onPressed: _showAddContact),
        PopupMenuButton(itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'sync', child: Text('Синхронизировать')),
          const PopupMenuItem(value: 'invite', child: Text('Пригласить друга')),
          const PopupMenuItem(value: 'qr', child: Text('QR-код')),
        ], onSelected: (v) {
          if (v == 'sync') context.read<ContactsBloc>().add(ContactsSyncRequested());
          if (v == 'qr') _showQrCode();
        }),
      ]),
      body: BlocBuilder<ContactsBloc, ContactsState>(
        builder: (context, state) {
          if (state is ContactsLoading) return const Center(child: CircularProgressIndicator());
          if (state is ContactsError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(state.message),
            FilledButton(onPressed: () => context.read<ContactsBloc>().add(ContactsLoadRequested()), child: const Text('Повторить')),
          ]));
          final contacts = state is ContactsLoaded ? state.contacts : <ContactItem>[];
          if (contacts.isEmpty) return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline, size: 64, color: context.colors.onSurface.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text('Нет контактов', style: context.typography.titleLarge?.copyWith(color: context.colors.onSurface.withOpacity(0.5))),
              const SizedBox(height: 8),
              Text('Синхронизируйте телефонную книгу', style: context.typography.bodyMedium?.copyWith(color: context.colors.onSurface.withOpacity(0.4))),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => context.read<ContactsBloc>().add(ContactsSyncRequested()), child: const Text('Синхронизировать')),
            ]),
          );
          final online = contacts.where((c) => c.isOnline).toList();
          final offline = contacts.where((c) => !c.isOnline).toList();
          return ListView(children: [
            if (online.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('В сети — ${online.length}', style: context.typography.labelMedium?.copyWith(color: context.colors.primary))),
              for (final c in online) _ContactTile(contact: c),
            ],
            if (offline.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('Остальные — ${offline.length}', style: context.typography.labelMedium?.copyWith(color: context.colors.onSurface.withOpacity(0.5)))),
              for (final c in offline) _ContactTile(contact: c),
            ],
          ]);
        },
      ),
    );
  }

  void _showAddContact() {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Добавить контакт'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Имя пользователя или телефон'), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(onPressed: () { Navigator.pop(ctx); context.read<ContactsBloc>().add(ContactAdded(identifier: controller.text.trim())); }, child: const Text('Добавить')),
      ],
    ));
  }

  void _showQrCode() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Ваш QR-код'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 200, height: 200, color: context.colors.outlineVariant, child: const Center(child: Icon(Icons.qr_code_2, size: 160))),
        const SizedBox(height: 16),
        Text('Покажите этот код другу', style: context.typography.bodyMedium),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
    ));
  }
}

class _ContactTile extends StatelessWidget {
  final ContactItem contact;
  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(children: [
        CircleAvatar(radius: 28, backgroundColor: context.colors.primary.withOpacity(0.1),
          backgroundImage: contact.avatarUrl != null ? NetworkImage(contact.avatarUrl!) : null,
          child: contact.avatarUrl == null ? Text(contact.displayName[0].toUpperCase(), style: TextStyle(color: context.colors.primary)) : null,
        ),
        if (contact.isOnline) Positioned(right: 2, bottom: 2, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: context.colors.success, shape: BoxShape.circle, border: Border.all(color: context.colors.surface, width: 2)))),
      ]),
      title: Text(contact.displayName, style: context.typography.titleMedium),
      subtitle: Text('@${contact.username}', style: context.typography.bodySmall),
      onTap: () {/* Открыть чат или профиль */},
      onLongPress: () => showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.chat), title: const Text('Написать'), onTap: () => Navigator.pop(ctx)),
        ListTile(leading: const Icon(Icons.call), title: const Text('Позвонить'), onTap: () => Navigator.pop(ctx)),
        ListTile(leading: const Icon(Icons.videocam), title: const Text('Видеозвонок'), onTap: () => Navigator.pop(ctx)),
        ListTile(leading: const Icon(Icons.block, color: Colors.red), title: const Text('Заблокировать', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(ctx)),
      ]))),
    );
  }
}

class _ContactsSearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => const Center(child: Text('Результаты'));
  @override
  Widget buildSuggestions(BuildContext context) => const Center(child: Text('Поиск контактов...'));
}

class ContactItem {
  final String userId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final bool isOnline;
  const ContactItem({required this.userId, required this.displayName, required this.username, this.avatarUrl, this.isOnline = false});
}
