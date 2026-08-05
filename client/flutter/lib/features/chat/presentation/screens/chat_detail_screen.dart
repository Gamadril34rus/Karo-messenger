// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/reactions_service.dart';
import '../../../../core/services/media_viewer_service.dart';
import '../../../../core/services/voice_message_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../../core/services/file_upload_service.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../bloc/chat_detail/chat_bloc.dart';
import '../../../../shared/widgets/message_bubble.dart';
import '../../data/message_item.dart';

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
  bool _isRecordingVoice = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

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
    _recordingTimer?.cancel();
    if (_isRecordingVoice) {
      VoiceMessageService.instance.cancelRecording();
    }
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
            icon: const Icon(Icons.people_outline),
            onPressed: () {
              final state = context.read<ChatDetailBloc>().state;
              final chatTitle = state is ChatDetailLoaded ? state.chatTitle : 'Чат';
              context.go('/chat-members/${widget.chatId}', extra: {'chatTitle': chatTitle});
            },
          ),
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
          // ─── Offline / Sync indicator ────────────────────────────
          StreamBuilder<OfflineSyncStatus>(
            stream: OfflineSyncService.instance.statusStream,
            initialData: const OfflineSyncStatus(isOnline: true, pendingCount: 0, failedCount: 0, isSyncing: false),
            builder: (context, snapshot) {
              final status = snapshot.data!;
              if (!status.isOnline) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: Colors.orange.shade700,
                  child: Text(
                    'Нет подключения • ${status.pendingCount} в очереди',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                );
              }
              if (status.isSyncing) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.blue.shade600,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 8),
                      Text('Синхронизация...', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // ─── Typing indicator ────────────────────────────────────
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

          // ─── Messages ────────────────────────────────────────────
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
                          width: 80, height: 80,
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

          // ─── Premium input bar ──────────────────────────────────
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
      onTap: () => _onMessageTap(msg),
      onLongPress: () => _showMessageActions(context, msg),
      onReplyTap: () => _replyToMessage(msg),
    );
  }

  /// Нажатие на сообщение — открыть медиа, если фото/видео
  void _onMessageTap(MessageItem msg) {
    if (msg.type == 'image' || msg.type == 'video') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            mediaItems: [
              MediaItem(
                id: msg.id,
                type: msg.type == 'video' ? MediaType.video : MediaType.image,
                url: msg.mediaUrl,
                thumbnailUrl: msg.mediaThumbnail,
              ),
            ],
          ),
        ),
      );
    }
  }

  // ─── Input Bar ──────────────────────────────────────────────────

  Widget _buildInputBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: _isRecordingVoice ? _buildVoiceRecordingBar() : _buildTextInputBar(context),
        ),
      ),
    );
  }

  Widget _buildTextInputBar(BuildContext context) {
    return Row(
      children: [
        // Attach button
        IconButton(
          icon: Icon(Icons.attach_file, color: context.colors.primary),
          onPressed: _showAttachSheet,
        ),
        // Text input
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.outlineVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.emoji_emotions_outlined, color: context.colors.onSurface.withOpacity(0.5)),
                  onPressed: _showEmojiSheet,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _inputFocusNode,
                    onChanged: _onTextChanged,
                    decoration: InputDecoration(
                      hintText: 'Сообщение...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Voice / Send button
        BlocBuilder<ChatDetailBloc, ChatDetailState>(
          builder: (context, state) {
            final hasText = _messageController.text.trim().isNotEmpty;
            if (hasText) {
              return IconButton.filled(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              );
            }
            return IconButton(
              icon: const Icon(Icons.mic),
              onPressed: _startVoiceRecording,
            );
          },
        ),
      ],
    );
  }

  Widget _buildVoiceRecordingBar() {
    return Row(
      children: [
        // Cancel
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: _cancelVoiceRecording,
        ),
        const SizedBox(width: 8),
        // Recording indicator
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_recordingDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${_recordingDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 16),
        // Waveform animation during recording
        Expanded(
          child: _RecordingWaveform(),
        ),
        const SizedBox(width: 8),
        // Send
        IconButton.filled(
          icon: const Icon(Icons.send),
          onPressed: _sendVoiceRecording,
        ),
      ],
    );
  }

  // ─── Voice Recording ────────────────────────────────────────────

  Future<void> _startVoiceRecording() async {
    final path = await VoiceMessageService.instance.startRecording();
    if (path != null) {
      setState(() {
        _isRecordingVoice = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _recordingDuration = VoiceMessageService.instance.currentDuration;
        });
      });
    }
  }

  Future<void> _sendVoiceRecording() async {
    _recordingTimer?.cancel();
    final result = await VoiceMessageService.instance.stopRecording();
    setState(() => _isRecordingVoice = false);

    if (result != null) {
      // Upload voice file first
      final upload = await FileUploadService.instance.uploadFile(
        filePath: result.filePath,
        chatId: widget.chatId,
        mimeType: 'audio/m4a',
      );

      if (upload != null) {
        context.read<ChatDetailBloc>().add(ChatDetailMessageSent(
          chatId: widget.chatId,
          type: 'voice',
          content: jsonEncode({
            'url': upload.url,
            'duration': result.duration.inSeconds,
            'waveform': result.waveformData,
            'file_size': result.fileSize,
          }),
        ));
      } else {
        // Fallback: send without upload (local path)
        context.read<ChatDetailBloc>().add(ChatDetailMessageSent(
          chatId: widget.chatId,
          type: 'voice',
          content: jsonEncode({
            'url': result.filePath,
            'duration': result.duration.inSeconds,
            'waveform': result.waveformData,
            'file_size': result.fileSize,
          }),
        ));
      }
    }
  }

  void _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await VoiceMessageService.instance.cancelRecording();
    setState(() => _isRecordingVoice = false);
  }

  // ─── Attach / Emoji / Actions ──────────────────────────────────

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
              // ─── Quick Reactions ────────────────────────────────
              ReactionsPicker(
                onReactionSelected: (emoji) {
                  Navigator.pop(ctx);
                  context.read<ChatDetailBloc>().add(ChatDetailReactionSent(
                    chatId: widget.chatId,
                    messageId: msg.id,
                    emoji: emoji,
                  ));
                },
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // ─── Action buttons ─────────────────────────────────
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
    context.go('/forward', extra: {
      'messageId': msg.id,
      'messagePreview': msg.text ?? 'Медиа',
    });
  }

  void _copyMessage(MessageItem msg) {
    final text = msg.text ?? '';
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Скопировано'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _editMessage(MessageItem msg) {
    _messageController.text = msg.text ?? '';
    _inputFocusNode.requestFocus();
    context.read<ChatDetailBloc>().add(ChatDetailEditSet(messageId: msg.id));
    // When user sends edited message, the BLoC will check if editingId is set
    // and send message.update instead of message.send
  }

  void _deleteMessage(MessageItem msg) {
    context.read<ChatDetailBloc>().add(ChatDetailMessageDeleted(messageId: msg.id));
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      final upload = await FileUploadService.instance.uploadFile(
        filePath: result.files.single.path!,
        chatId: widget.chatId,
      );
      if (upload != null) {
        context.read<ChatDetailBloc>().add(ChatDetailMessageSent(
          chatId: widget.chatId,
          type: 'image',
          content: jsonEncode({'url': upload.url, 'thumbnail_url': upload.thumbnailUrl, 'file_name': upload.fileName, 'file_size': upload.fileSize}),
        ));
      }
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      final upload = await FileUploadService.instance.uploadFile(
        filePath: result.files.single.path!,
        chatId: widget.chatId,
      );
      if (upload != null) {
        context.read<ChatDetailBloc>().add(ChatDetailMessageSent(
          chatId: widget.chatId,
          type: 'video',
          content: jsonEncode({'url': upload.url, 'thumbnail_url': upload.thumbnailUrl, 'file_name': upload.fileName, 'file_size': upload.fileSize}),
        ));
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      final upload = await FileUploadService.instance.uploadFile(
        filePath: result.files.single.path!,
        chatId: widget.chatId,
      );
      if (upload != null) {
        context.read<ChatDetailBloc>().add(ChatDetailMessageSent(
          chatId: widget.chatId,
          type: 'file',
          content: jsonEncode({'url': upload.url, 'file_name': upload.fileName, 'file_size': upload.fileSize}),
        ));
      }
    }
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
      case 'wallpaper': context.go('/chat-wallpaper/${widget.chatId}'); break;
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

/// Animated waveform bars during voice recording
class _RecordingWaveform extends StatefulWidget {
  const _RecordingWaveform();

  @override
  State<_RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<_RecordingWaveform> {
  final List<double> _barHeights = List.generate(24, (_) => 0.3);

  @override
  void initState() {
    super.initState();
    _animateBars();
  }

  void _animateBars() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _barHeights.length; i++) {
          _barHeights[i] = 0.15 + (DateTime.now().millisecondsSinceEpoch * (i + 1) % 100) / 100 * 0.75;
        }
      });
      _animateBars();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: context.colors.outlineVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _barHeights.map((h) {
          return Container(
            width: 3,
            height: (h * 20).clamp(4.0, 20.0),
            decoration: BoxDecoration(
              color: context.colors.primary.withOpacity(0.6),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }).toList(),
      ),
    );
  }
}
