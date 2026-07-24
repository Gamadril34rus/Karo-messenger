import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/chat_list/chat_bloc.dart';

/// Список чатов — главный экран мессенджера
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    context.read<ChatListBloc>().add(ChatListLoadRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск чатов...',
                  border: InputBorder.none,
                ),
                onChanged: (q) => context.read<ChatListBloc>().add(ChatListSearchRequested(query: q)),
              )
            : const Text('ЧАРО'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  context.read<ChatListBloc>().add(ChatListLoadRequested());
                }
              });
            },
          ),
        ],
      ),
      body: BlocBuilder<ChatListBloc, ChatListState>(
        builder: (context, state) {
          if (state is ChatListLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ChatListError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: context.colors.error),
                  const SizedBox(height: 16),
                  Text(state.message, style: context.typography.bodyLarge),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.read<ChatListBloc>().add(ChatListLoadRequested()),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          if (state is ChatListLoaded && state.chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: context.colors.onSurface.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('Нет чатов', style: context.typography.titleLarge),
                  const SizedBox(height: 8),
                  Text('Начните общение!', style: context.typography.bodyMedium?.copyWith(
                    color: context.colors.onSurface.withOpacity(0.6),
                  )),
                ],
              ),
            );
          }
          final chats = state is ChatListLoaded ? state.chats : <ChatItem>[];
          return RefreshIndicator(
            onRefresh: () async {
              context.read<ChatListBloc>().add(ChatListLoadRequested());
            },
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) => _ChatTile(chat: chats[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChatSheet(context),
        child: const Icon(Icons.edit),
      ),
    );
  }

  void _showNewChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Новый чат'),
              onTap: () { Navigator.pop(ctx); context.go('/contacts'); },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Новая группа'),
              onTap: () { Navigator.pop(ctx); _showCreateGroupDialog(context); },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('Новый канал'),
              onTap: () { Navigator.pop(ctx); _showCreateChannelDialog(context); },
            ),
            ListTile(
              leading: const Icon(Icons.enhanced_encryption),
              title: const Text('Секретный чат'),
              onTap: () { Navigator.pop(ctx); /* Секретный чат создается из профиля контакта */ },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая группа'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Название группы'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChatListBloc>().add(ChatListCreateRequested(
                type: 'group',
                title: nameController.text.trim(),
              ));
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showCreateChannelDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый канал'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Название канала'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChatListBloc>().add(ChatListCreateRequested(
                type: 'channel',
                title: nameController.text.trim(),
              ));
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}

/// Модель чата для списка
class ChatItem {
  final String id;
  final String type;
  final String? title;
  final String? avatarUrl;
  final String? lastMessage;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;

  const ChatItem({
    required this.id,
    this.type = 'private',
    this.title,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageSender,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
  });
}

/// Плитка чата в списке
class _ChatTile extends StatelessWidget {
  final ChatItem chat;

  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: context.colors.primary.withOpacity(0.1),
        backgroundImage: chat.avatarUrl != null ? NetworkImage(chat.avatarUrl!) : null,
        child: chat.avatarUrl == null
            ? Text(
                (chat.title ?? '?')[0].toUpperCase(),
                style: context.typography.titleLarge?.copyWith(color: context.colors.primary),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.title ?? 'Чат',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.titleMedium?.copyWith(
                fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (chat.isMuted)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.notifications_off, size: 16, color: context.colors.onSurface.withOpacity(0.4)),
            ),
          if (chat.isPinned)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin, size: 16, color: context.colors.onSurface.withOpacity(0.4)),
            ),
          Text(
            _formatTime(chat.lastMessageAt),
            style: context.typography.bodySmall?.copyWith(
              color: chat.unreadCount > 0
                  ? context.colors.primary
                  : context.colors.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              chat.lastMessage ?? 'Нет сообщений',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.bodyMedium?.copyWith(
                color: context.colors.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                style: context.typography.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      onTap: () => context.go('/chat/${chat.id}'),
      onLongPress: () => _showChatActions(context, chat),
    );
  }

  void _showChatActions(BuildContext context, ChatItem chat) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(chat.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(chat.isPinned ? 'Открепить' : 'Закрепить'),
              onTap: () { Navigator.pop(ctx); },
            ),
            ListTile(
              leading: Icon(chat.isMuted ? Icons.notifications : Icons.notifications_off_outlined),
              title: Text(chat.isMuted ? 'Включить уведомления' : 'Отключить уведомления'),
              onTap: () { Navigator.pop(ctx); },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Архивировать'),
              onTap: () { Navigator.pop(ctx); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Вчера';
    if (diff.inDays < 7) {
      const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      return days[dt.weekday - 1];
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }
}
