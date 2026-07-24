import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/chat_detail/chat_bloc.dart';
import '../../../../shared/widgets/message_bubble.dart';

/// Экран конкретного чата — сообщения, ввод, медиа
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

    // Прокрутка вниз
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
          // Индикатор набора текста собеседником
          BlocBuilder<ChatDetailBloc, ChatDetailState>(
            builder: (context, state) {
              if (state is ChatDetailLoaded && state.typingUserId != null) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: context.colors.outlineVariant,
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

          // Список сообщений
          Expanded(
            child: BlocBuilder<ChatDetailBloc, ChatDetailState>(
              builder: (context, state) {
                if (state is ChatDetailLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ChatDetailError) {
                  return Center(child: Column(
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
                  ));
                }
                final messages = state is ChatDetailLoaded ? state.messages : <MessageItem>[];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: context.colors.onSurface.withOpacity(0.2)),
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

          // Поле ввода
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(chatTitle, style: context.typography.titleMedium),
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
      onReplyTap: () {
        // Прокрутка к сообщению, на которое ответили
      },
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.outline, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Кнопка вложений
            IconButton(
              icon: Icon(Icons.attach_file, color: context.colors.onSurface.withOpacity(0.7)),
              onPressed: _showAttachSheet,
            ),

            // Текстовое поле
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                onChanged: _onTextChanged,
                decoration: const InputDecoration(
                  hintText: 'Сообщение...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.newline,
              ),
            ),

            // Кнопка эмодзи
            IconButton(
              icon: Icon(Icons.emoji_emotions_outlined, color: context.colors.onSurface.withOpacity(0.7)),
              onPressed: _showEmojiSheet,
            ),

            // Кнопка отправки / голосового
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;
                return AnimatedSwitcher(
                  duration: AppConstants.animationDurationShort,
                  child: hasText
                      ? IconButton(
                          key: const ValueKey('send'),
                          icon: Icon(Icons.send, color: context.colors.primary),
                          onPressed: _sendMessage,
                        )
                      : IconButton(
                          key: const ValueKey('mic'),
                          icon: Icon(Icons.mic, color: context.colors.onSurface.withOpacity(0.7)),
                          onPressed: _startVoiceRecording,
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
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Прикрепить', style: context.typography.titleLarge),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(icon: Icons.photo, label: 'Фото', color: Colors.blue, onTap: () { Navigator.pop(ctx); _pickImage(); }),
                  _AttachOption(icon: Icons.videocam, label: 'Видео', color: Colors.red, onTap: () { Navigator.pop(ctx); _pickVideo(); }),
                  _AttachOption(icon: Icons.insert_drive_file, label: 'Файл', color: Colors.purple, onTap: () { Navigator.pop(ctx); _pickFile(); }),
                  _AttachOption(icon: Icons.headphones, label: 'Голос', color: Colors.orange, onTap: () { Navigator.pop(ctx); _startVoiceRecording(); }),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(icon: Icons.location_on, label: 'Место', color: Colors.green, onTap: () { Navigator.pop(ctx); _sendLocation(); }),
                  _AttachOption(icon: Icons.contact_page, label: 'Контакт', color: Colors.cyan, onTap: () { Navigator.pop(ctx); _sendContact(); }),
                  _AttachOption(icon: Icons.poll, label: 'Опрос', color: Colors.teal, onTap: () { Navigator.pop(ctx); _createPoll(); }),
                  _AttachOption(icon: Icons.gif_box, label: 'GIF', color: Colors.pink, onTap: () { Navigator.pop(ctx); _searchGif(); }),
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.reply), title: const Text('Ответить'), onTap: () { Navigator.pop(ctx); _replyToMessage(msg); }),
            ListTile(leading: const Icon(Icons.forward), title: const Text('Переслать'), onTap: () { Navigator.pop(ctx); _forwardMessage(msg); }),
            ListTile(leading: const Icon(Icons.copy), title: const Text('Копировать'), onTap: () { Navigator.pop(ctx); _copyMessage(msg); }),
            if (msg.isMe) ...[
              ListTile(leading: const Icon(Icons.edit), title: const Text('Редактировать'), onTap: () { Navigator.pop(ctx); _editMessage(msg); }),
            ],
            ListTile(leading: const Icon(Icons.push_pin_outlined), title: const Text('Закрепить'), onTap: () { Navigator.pop(ctx); }),
            ListTile(leading: Icon(Icons.delete, color: context.colors.error), title: Text('Удалить', style: TextStyle(color: context.colors.error)), onTap: () { Navigator.pop(ctx); _deleteMessage(msg); }),
          ],
        ),
      ),
    );
  }

  void _replyToMessage(MessageItem msg) {
    // Вставляем упоминание ответа в поле ввода
    _messageController.text = '';
    _inputFocusNode.requestFocus();
    context.read<ChatDetailBloc>().add(ChatDetailReplySet(messageId: msg.id));
  }

  void _forwardMessage(MessageItem msg) {
    // Показываем список чатов для пересылки
    context.read<ChatDetailBloc>().add(ChatDetailForwardRequested(messageId: msg.id));
  }

  void _copyMessage(MessageItem msg) {
    // Копируем текст сообщения в буфер обмена
    if (msg.text != null) {
      // В реальном приложении: Clipboard.setData(ClipboardData(text: msg.text!));
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
      case 'search':
        _showSearchInChat();
        break;
      case 'mute':
        context.read<ChatDetailBloc>().add(ChatDetailMuteToggled(chatId: widget.chatId));
        break;
      case 'disappearing':
        _showDisappearingTimerPicker();
        break;
      case 'wallpaper':
        // Навигация на выбор фона
        break;
      case 'export':
        context.read<ChatDetailBloc>().add(ChatDetailExportRequested(chatId: widget.chatId));
        break;
      case 'clear':
        context.read<ChatDetailBloc>().add(ChatDetailHistoryCleared(chatId: widget.chatId));
        break;
    }
  }

  void _showSearchInChat() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.all(16), child: Text('Исчезающие сообщения', style: context.typography.titleLarge)),
            ListTile(title: const Text('Выкл'), onTap: () { Navigator.pop(ctx); context.read<ChatDetailBloc>().add(ChatDetailDisappearingSet(chatId: widget.chatId, seconds: 0)); }),
            for (final timer in AppConstants.disappearingTimers)
              ListTile(
                title: Text(_formatTimer(timer)),
                onTap: () { Navigator.pop(ctx); context.read<ChatDetailBloc>().add(ChatDetailDisappearingSet(chatId: widget.chatId, seconds: timer)); },
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
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: context.typography.bodySmall),
        ],
      ),
    );
  }
}
