import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../bloc/chat_detail/chat_bloc.dart';
import '../../../../shared/widgets/message_bubble.dart';

/// Экран конкретного чата — премиальный UI, сообщения, ввод, медиа
class ChatDetailScreen extends StatefulWidget {
  final String chatId;

  const ChatDetailScreen({super.key, required this.chatId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    context.read<ChatDetailBloc>().add(ChatDetailLoadRequested(chatId: widget.chatId));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 200) {
      context.read<ChatDetailBloc>().add(ChatDetailLoadMoreRequested(chatId: widget.chatId));
    }
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      context.read<ChatDetailBloc>().add(ChatDetailTypingStarted(chatId: widget.chatId));
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        context.read<ChatDetailBloc>().add(ChatDetailTypingStopped(chatId: widget.chatId));
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    context.read<ChatDetailBloc>().add(ChatDetailMessageSent(
          chatId: widget.chatId,
          type: 'text',
          content: text,
        ));

    _messageController.clear();
    _isTyping = false;
    _typingTimer?.cancel();
    context.read<ChatDetailBloc>().add(ChatDetailTypingStopped(chatId: widget.chatId));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppConstants.animationDurationMedium,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/chats'),
        ),
        title: _buildAppBarTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () => _initCall(isVideo: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () => _initCall(isVideo: true),
          ),
          PopupMenuButton(itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'search', child: Text('Поиск')),
            const PopupMenuItem(value: 'mute', child: Text('Отключить уведомления')),
            const PopupMenuItem(value: 'disappearing', child: Text('Исчезающие сообщения')),
            const PopupMenuItem(value: 'wallpaper', child: Text('Фон чата')),
            const PopupMenuItem(value: 'export', child: Text('Экспорт чата')),
            const PopupMenuItem(value: 'clear', child: Text('Очистить историю')),
          ],
          onSelected: (value) => _onMenuAction(value as String)),
        ],
      ),
      body: Column(
        children: [
          // Typing indicator
          BlocBuilder<ChatDetailBloc, ChatDetailState>(
            builder: (context, state) {
              if (state is ChatDetailLoaded && state.typingUserId != null) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withOpacity(0.06),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.primary),
                      ),
                      const SizedBox(width: 8),
                      Text('печатает...', style: context.typography.bodySmall?.copyWith(
                        color: context.colors.primary,
                        fontStyle: FontStyle.italic,
                      )),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Messages
          Expanded(
            child: BlocBuilder<ChatDetailBloc, ChatDetailState>(
              builder: (context, state) {
                if (state is ChatDetailLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ChatDetailError) {
                  return Center(
                    child: CharoCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: context.colors.error),
                          const SizedBox(height: 16),
                          Text(state.message),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => context.read<ChatDetailBloc>()
                                .add(ChatDetailLoadRequested(chatId: widget.chatId)),
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final messages = state is ChatDetailLoaded ? state.messages : <MessageItem>[];
                if (messages.isEmpty) {
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
                        Text('Начните общение!', style: context.typography.bodyLarge?.copyWith(
                          color: context.colors.onSurface.withOpacity(0.5),
                        )),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _buildMessage(context, messages[index]),
                );
              },
            ),
          ),

          // Premium input bar
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    return BlocBuilder<ChatDetailBloc, ChatDetailState>(
      builder: (context, state) {
        final chatTitle = state is ChatDetailLoaded ? state.chatTitle : 'Чат';
        final isOnline = state is ChatDetailLoaded ? state.isOnline : false;
        final memberCount = state is ChatDetailLoaded ? state.memberCount : null;
        return GestureDetector(
          onTap: () => context.go('/profile'),
          child: Row(
            children: [
              CharoAvatar(
                radius: 18,
                isOnline: isOnline,
                showRing: false,
                fallbackText: chatTitle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chatTitle, style: context.typography.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                    Text(
                      isOnline
                          ? 'в сети'
                          : memberCount != null
                              ? '$memberCount участников'
                              : 'был(а) недавно',
                      style: context.typography.bodySmall?.copyWith(
                        color: isOnline ? context.colors.success : context.colors.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessage(BuildContext context, MessageItem msg) {
    return MessageBubble(
      messageId: msg.id,
      senderName: msg.isMe ? null : msg.senderName,
      isMe: msg.isMe,
      type: msg.type,
      text: msg.text,
      mediaUrl: msg.mediaUrl,
      mediaThumbnail: msg.mediaThumbnail,
      replyToText: msg.replyToText,
      replyToSender: msg.replyToSender,
      isEdited: msg.isEdited,
      isDeleted: msg.isDeleted,
      status: msg.status,
      sentAt: msg.sentAt,
      readAt: msg.readAt,
      reactions: msg.reactions,
      onLongPress: () => _showMessageActions(context, msg),
      onReplyTap: () {},
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attach button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.attach_file, size: 20, color: context.colors.onSurface.withOpacity(0.7)),
                onPressed: _showAttachSheet,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 6),

            // Text field with rounded background
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _inputFocusNode,
                  onChanged: _onTextChanged,
                  decoration: const InputDecoration(
                    hintText: 'Сообщение...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Emoji button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.emoji_emotions_outlined, size: 20, color: context.colors.onSurface.withOpacity(0.7)),
                onPressed: _showEmojiSheet,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 4),

            // Send/mic button — animated swap
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;
                return AnimatedSwitcher(
                  duration: AppConstants.animationDurationShort,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: hasText
                      ? Container(
                          key: const ValueKey('send'),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: _sendMessage,
                            padding: EdgeInsets.zero,
                          ),
                        )
                      : Container(
                          key: const ValueKey('mic'),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.colors.outlineVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.mic, size: 20, color: context.colors.onSurface.withOpacity(0.7)),
                            onPressed: _startVoiceRecording,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachSheet() {
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
              Text('Прикрепить', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(icon: Icons.photo_outlined, label: 'Фото', color: Colors.blue, onTap: () { Navigator.pop(ctx); _pickImage(); }),
                  _AttachOption(icon: Icons.videocam_outlined, label: 'Видео', color: Colors.red, onTap: () { Navigator.pop(ctx); _pickVideo(); }),
                  _AttachOption(icon: Icons.insert_drive_file_outlined, label: 'Файл', color: Colors.purple, onTap: () { Navigator.pop(ctx); _pickFile(); }),
                  _AttachOption(icon: Icons.headphones_outlined, label: 'Голос', color: Colors.orange, onTap: () { Navigator.pop(ctx); _startVoiceRecording(); }),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(icon: Icons.location_on_outlined, label: 'Место', color: Colors.green, onTap: () { Navigator.pop(ctx); _sendLocation(); }),
                  _AttachOption(icon: Icons.contact_page_outlined, label: 'Контакт', color: Colors.cyan, onTap: () { Navigator.pop(ctx); _sendContact(); }),
                  _AttachOption(icon: Icons.poll_outlined, label: 'Опрос', color: Colors.teal, onTap: () { Navigator.pop(ctx); _createPoll(); }),
                  _AttachOption(icon: Icons.gif_box_outlined, label: 'GIF', color: Colors.pink, onTap: () { Navigator.pop(ctx); _searchGif(); }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmojiSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: 280,
        child: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8, mainAxisSpacing: 4, crossAxisSpacing: 4),
          itemCount: 64,
          itemBuilder: (context, index) {
            const emojis = ['😀','😂','😍','🥰','😎','🤔','😢','😡','👍','👎','❤️','🔥','🎉','✨','💯','🙏',
              '🤣','😘','😊','🥺','😤','🤗','😏','🤭','👋','✌️','🤞','💪','🫶','👀','💀','🤡',
              '🤜💥','😭','🥳','😈','👻','🎃','💀','☠️','🤖','👽','💩','🐱','🐶','🦊','🐼','🐨',
              '🌈','⭐','🌙','☀️','🌊','🎵','🎶','🎸','🎮','⚽','🏀','🎯','🏆','🥇','🎖️','🏅'];
            if (index >= emojis.length) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () {
                _messageController.text += emojis[index];
                Navigator.pop(ctx);
                _inputFocusNode.requestFocus();
              },
              child: Center(child: Text(emojis[index], style: const TextStyle(fontSize: 24))),
            );
          },
        ),
      ),
    );
  }

  void _showMessageActions(BuildContext context, MessageItem msg) {
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
              CharoTile(icon: Icons.reply_outlined, iconColor: context.colors.primary, title: 'Ответить',
                  onTap: () { Navigator.pop(ctx); _replyToMessage(msg); }),
              CharoTile(icon: Icons.forward_outlined, iconColor: const Color(0xFF10B981), title: 'Переслать',
                  onTap: () { Navigator.pop(ctx); _forwardMessage(msg); }),
              CharoTile(icon: Icons.copy_outlined, iconColor: const Color(0xFF3B82F6), title: 'Копировать',
                  onTap: () { Navigator.pop(ctx); _copyMessage(msg); }),
              if (msg.isMe)
                CharoTile(icon: Icons.edit_outlined, iconColor: const Color(0xFFF59E0B), title: 'Редактировать',
                    onTap: () { Navigator.pop(ctx); _editMessage(msg); }),
              CharoTile(icon: Icons.push_pin_outlined, iconColor: context.colors.primary, title: 'Закрепить',
                  onTap: () { Navigator.pop(ctx); }),
              CharoTile(icon: Icons.delete_outline, iconColor: Colors.red, title: 'Удалить', isDestructive: true,
                  onTap: () { Navigator.pop(ctx); _deleteMessage(msg); }),
            ],
          ),
        ),
      ),
    );
  }

  void _replyToMessage(MessageItem msg) {
    _messageController.text = '';
    _inputFocusNode.requestFocus();
    context.read<ChatDetailBloc>().add(ChatDetailReplySet(messageId: msg.id));
  }

  void _forwardMessage(MessageItem msg) {
    context.read<ChatDetailBloc>().add(ChatDetailForwardRequested(messageId: msg.id));
  }

  void _copyMessage(MessageItem msg) {
    if (msg.text != null) {
      // Clipboard.setData(ClipboardData(text: msg.text!));
    }
  }

  void _editMessage(MessageItem msg) {
    _messageController.text = msg.text ?? '';
    _inputFocusNode.requestFocus();
    context.read<ChatDetailBloc>().add(ChatDetailEditSet(messageId: msg.id));
  }

  void _deleteMessage(MessageItem msg) {
    context.read<ChatDetailBloc>().add(ChatDetailMessageDeleted(messageId: msg.id));
  }

  void _pickImage() {
    context.read<ChatDetailBloc>().add(ChatDetailMediaPicked(chatId: widget.chatId, type: 'image'));
  }
  void _pickVideo() {
    context.read<ChatDetailBloc>().add(ChatDetailMediaPicked(chatId: widget.chatId, type: 'video'));
  }
  void _pickFile() {
    context.read<ChatDetailBloc>().add(ChatDetailMediaPicked(chatId: widget.chatId, type: 'file'));
  }
  void _startVoiceRecording() {
    context.read<ChatDetailBloc>().add(ChatDetailVoiceRecorded(chatId: widget.chatId));
  }
  void _sendLocation() {
    context.read<ChatDetailBloc>().add(ChatDetailLocationSent(chatId: widget.chatId));
  }
  void _sendContact() {
    context.read<ChatDetailBloc>().add(ChatDetailContactSent(chatId: widget.chatId));
  }
  void _createPoll() {
    context.read<ChatDetailBloc>().add(ChatDetailPollCreated(chatId: widget.chatId));
  }
  void _searchGif() {
    context.read<ChatDetailBloc>().add(ChatDetailGifSent(chatId: widget.chatId));
  }
  void _initCall({required bool isVideo}) {
    context.read<ChatDetailBloc>().add(ChatDetailCallInitiated(chatId: widget.chatId, isVideo: isVideo));
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'search': _showSearchInChat(); break;
      case 'mute': context.read<ChatDetailBloc>().add(ChatDetailMuteToggled(chatId: widget.chatId)); break;
      case 'disappearing': _showDisappearingTimerPicker(); break;
      case 'wallpaper': break;
      case 'export': context.read<ChatDetailBloc>().add(ChatDetailExportRequested(chatId: widget.chatId)); break;
      case 'clear': context.read<ChatDetailBloc>().add(ChatDetailHistoryCleared(chatId: widget.chatId)); break;
    }
  }

  void _showSearchInChat() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Поиск в чате'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Поиск...'),
          onChanged: (q) => context.read<ChatDetailBloc>().add(
            ChatDetailSearchRequested(chatId: widget.chatId, query: q),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  void _showDisappearingTimerPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.all(16),
              child: Text('Исчезающие сообщения', style: context.typography.titleLarge)),
            ListTile(title: const Text('Выкл'), onTap: () {
              Navigator.pop(ctx);
              context.read<ChatDetailBloc>().add(ChatDetailDisappearingSet(chatId: widget.chatId, seconds: 0));
            }),
            for (final timer in AppConstants.disappearingTimers)
              ListTile(
                title: Text(_formatTimer(timer)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<ChatDetailBloc>().add(ChatDetailDisappearingSet(chatId: widget.chatId, seconds: timer));
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimer(int seconds) {
    if (seconds < 60) return '$seconds сек';
    if (seconds < 3600) return '${seconds ~/ 60} мин';
    if (seconds < 86400) return '${seconds ~/ 3600} ч';
    return '${seconds ~/ 86400} дн';
  }
}

/// Модель сообщения для UI
class MessageItem {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final bool isMe;
  final String type;
  final String? text;
  final String? mediaUrl;
  final String? mediaThumbnail;
  final String? replyToText;
  final String? replyToSender;
  final bool isEdited;
  final bool isDeleted;
  final MessageStatus status;
  final DateTime sentAt;
  final DateTime? readAt;
  final List<Reaction> reactions;

  const MessageItem({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    required this.isMe,
    required this.type,
    this.text,
    this.mediaUrl,
    this.mediaThumbnail,
    this.replyToText,
    this.replyToSender,
    this.isEdited = false,
    this.isDeleted = false,
    this.status = MessageStatus.sent,
    required this.sentAt,
    this.readAt,
    this.reactions = const [],
  });
}

/// Premium attach option with rounded container
class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: context.typography.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
