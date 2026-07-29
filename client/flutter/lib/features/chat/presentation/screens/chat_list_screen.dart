import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/responsive_layout.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../bloc/chat_list/chat_bloc.dart';
import '../../data/chat_item.dart';
import '../screens/chat_detail_screen.dart';

/// Список чатов — главный экран мессенджера с премиальным UI
/// На десктопе: Master-Detail layout (список + деталь рядом)
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String? _selectedChatId; // For desktop master-detail

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
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return MasterDetailLayout(
      masterPanel: _buildChatListScaffold(),
      detailPanel: _selectedChatId != null
          ? ChatDetailScreen(chatId: _selectedChatId!)
          : const _EmptyChatState(),
      hasSelection: _selectedChatId != null,
      emptyState: const _EmptyChatState(),
    );
  }

  Widget _buildChatListScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Поиск чатов...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                        context.read<ChatListBloc>().add(ChatListLoadRequested());
                      });
                    },
                  ),
                ),
                style: context.typography.bodyLarge,
                onChanged: (q) => context.read<ChatListBloc>().add(ChatListSearchRequested(query: q)),
              )
            : Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('ЧАРО', style: context.typography.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  )),
                ],
              ),
        actions: _isSearching
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.go('/search'),
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
                      onPressed: () => context.read<ChatListBloc>().add(ChatListLoadRequested()),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is ChatListLoaded && state.chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.chat_bubble_outline, size: 40, color: context.colors.primary.withOpacity(0.3)),
                  ),
                  const SizedBox(height: 16),
                  Text('Нет чатов', style: context.typography.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
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
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                // Show pinned separator
                if (index == 0 && chat.isPinned) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            Icon(Icons.push_pin, size: 14, color: context.colors.primary),
                            const SizedBox(width: 6),
                            Text('Закреплённые', style: context.typography.labelMedium?.copyWith(
                              color: context.colors.primary,
                            )),
                          ],
                        ),
                      ),
                      _PremiumChatTile(chat: chat),
                    ],
                  );
                }
                return _PremiumChatTile(chat: chat);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChatSheet(context),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  void _selectChat(String chatId) {
    setState(() => _selectedChatId = chatId);
  }

  void _showNewChatSheet(BuildContext context) {
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
              Text('Новое сообщение', style: context.typography.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 16),
              CharoTile(
                icon: Icons.person_add_outlined,
                iconColor: context.colors.primary,
                title: 'Новый чат',
                onTap: () { Navigator.pop(ctx); context.go('/contacts'); },
              ),
              CharoTile(
                icon: Icons.group_add_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Новая группа',
                onTap: () { Navigator.pop(ctx); _showCreateGroupDialog(context); },
              ),
              CharoTile(
                icon: Icons.campaign_outlined,
                iconColor: const Color(0xFF3B82F6),
                title: 'Новый канал',
                onTap: () { Navigator.pop(ctx); _showCreateChannelDialog(context); },
              ),
              CharoTile(
                icon: Icons.enhanced_encryption,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Секретный чат',
                onTap: () { Navigator.pop(ctx); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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


/// Premium chat tile with avatar, online indicator, unread badge, and actions
class _PremiumChatTile extends StatelessWidget {
  final ChatItem chat;

  const _PremiumChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final isDesktop = ResponsiveLayout.isDesktop(context);
            if (isDesktop) {
              // Desktop: select chat in master-detail
              _selectChat(chat.id);
            } else {
              // Mobile: navigate to detail
              context.go('/chat/${chat.id}');
            }
          },
          onLongPress: () => _showChatActions(context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Avatar with online indicator
                CharoAvatar(
                  radius: 28,
                  imageUrl: chat.avatarUrl,
                  fallbackText: chat.title ?? '?',
                  isOnline: chat.isOnline,
                  showRing: chat.isPinned,
                  ringWidth: 2,
                  ringColors: [
                    context.colors.primary,
                    context.colors.secondary,
                  ],
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.title ?? 'Чат',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.titleMedium?.copyWith(
                                fontWeight: chat.unreadCount > 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          // Icons: muted, pinned
                          if (chat.isMuted)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.notifications_off_outlined, size: 14, color: context.colors.onSurface.withOpacity(0.4)),
                            ),
                          if (chat.isPinned)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.push_pin, size: 14, color: context.colors.primary.withOpacity(0.6)),
                            ),
                          // Time
                          Text(
                            _formatTime(chat.lastMessageAt),
                            style: context.typography.bodySmall?.copyWith(
                              color: chat.unreadCount > 0
                                  ? context.colors.primary
                                  : context.colors.onSurface.withOpacity(0.5),
                              fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Subtitle row
                      Row(
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
                          // Unread badge
                          if (chat.unreadCount > 0)
                            CharoBadge(count: chat.unreadCount),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChatActions(BuildContext context) {
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
              CharoTile(
                icon: chat.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                iconColor: context.colors.primary,
                title: chat.isPinned ? 'Открепить' : 'Закрепить',
                onTap: () { Navigator.pop(ctx); },
              ),
              CharoTile(
                icon: chat.isMuted ? Icons.notifications_outlined : Icons.notifications_off_outlined,
                iconColor: const Color(0xFFF59E0B),
                title: chat.isMuted ? 'Включить уведомления' : 'Отключить уведомления',
                onTap: () { Navigator.pop(ctx); },
              ),
              CharoTile(
                icon: Icons.archive_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'Архивировать',
                onTap: () { Navigator.pop(ctx); },
              ),
              CharoTile(
                icon: Icons.delete_outline,
                iconColor: Colors.red,
                title: 'Удалить',
                isDestructive: true,
                onTap: () { Navigator.pop(ctx); },
              ),
            ],
          ),
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

/// Пустое состояние — показывается на десктопе, когда чат не выбран
class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Выберите чат',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
