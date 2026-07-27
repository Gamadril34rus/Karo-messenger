import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Пузырь сообщения — сердце мессенджера.
///
/// Отображает:
/// - Текст, медиа, стикеры, голосовые, кружки и т.д.
/// - Галочки отправки/доставки/прочтения
/// - Время отправки и прочтения
/// - Реакции
/// - Ответ на другое сообщение
/// - Статус редактирования
class MessageBubble extends StatelessWidget {
  final String messageId;
  final String? senderName;
  final String? senderAvatarUrl;
  final bool isMe;
  final String type; // text, image, video, voice, video_note, file, sticker, gif, etc.
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
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onReplyTap;

  const MessageBubble({
    super.key,
    required this.messageId,
    this.senderName,
    this.senderAvatarUrl,
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
    this.onTap,
    this.onLongPress,
    this.onAvatarTap,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isDeleted) return _buildDeletedMessage(context);

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 48 : 12,
        right: isMe ? 12 : 48,
        top: 2,
        bottom: 2,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Имя отправителя (для групп)
              if (senderName != null && !isMe) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 2),
                  child: GestureDetector(
                    onTap: onAvatarTap,
                    child: Text(
                      senderName!,
                      style: context.typography.labelMedium?.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ),
              ],

              // Пузырь
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Container(
                  padding: _bubblePadding,
                  decoration: BoxDecoration(
                    color: _bubbleColor(context),
                    borderRadius: _bubbleRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Ответ на сообщение
                      if (replyToText != null) _buildReply(context),

                      // Контент
                      _buildContent(context),

                      // Мета-информация (время, галочки)
                      _buildMeta(context),
                    ],
                  ),
                ),
              ),

              // Реакции
              if (reactions.isNotEmpty) _buildReactions(context),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Цвет пузыря ────────────────────────────────────────────────
  Color _bubbleColor(BuildContext context) {
    if (isMe) {
      return context.colors.primary.withOpacity(0.12);
    }
    return context.colors.outlineVariant;
  }

  // ─── Радиус пузыря ──────────────────────────────────────────────
  BorderRadius get _bubbleRadius {
    return BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );
  }

  // ─── Padding пузыря ─────────────────────────────────────────────
  EdgeInsets get _bubblePadding {
    if (type == 'sticker') return EdgeInsets.zero;
    if (type == 'video_note') return const EdgeInsets.all(4);
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  // ─── Контент по типу ────────────────────────────────────────────
  Widget _buildContent(BuildContext context) {
    switch (type) {
      case 'text':
        return Text(
          text ?? '',
          style: context.typography.bodyLarge?.copyWith(
            height: 1.45,
          ),
        );

      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _MediaPlaceholder(
            width: double.infinity,
            height: 200,
            child: mediaUrl != null
                ? Image.network(mediaUrl!, fit: BoxFit.cover)
                : const Icon(Icons.image, size: 48),
          ),
        );

      case 'video':
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _MediaPlaceholder(
            width: double.infinity,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (mediaThumbnail != null)
                  Image.network(mediaThumbnail!, fit: BoxFit.cover),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.play_arrow, color: Colors.white),
                ),
              ],
            ),
          ),
        );

      case 'voice':
        return _VoiceMessage(
          duration: const Duration(seconds: 12), // Длина голосового сообщения
          isMe: isMe,
        );

      case 'video_note':
        // Кружок — круглое видеосообщение
        return Container(
          width: 180,
          height: 180,
          decoration: const BoxDecoration(
            color: Colors.black12,
            shape: BoxShape.circle,
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.play_circle_fill, size: 48, color: Colors.white70),
            ],
          ),
        );

      case 'sticker':
        return Image.network(
          mediaUrl ?? '',
          width: 160,
          height: 160,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.emoji_emblems, size: 64),
        );

      case 'gif':
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _MediaPlaceholder(
            width: double.infinity,
            height: 180,
            child: mediaUrl != null
                ? Image.network(mediaUrl!, fit: BoxFit.cover)
                : const Icon(Icons.gif, size: 48),
          ),
        );

      case 'file':
        return _FileMessage(fileName: text ?? 'Файл');

      case 'location':
        return Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: context.colors.outlineVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(child: Icon(Icons.map, size: 48)),
        );

      default:
        return Text(
          text ?? '[Неподдерживаемый тип]',
          style: context.typography.bodyMedium,
        );
    }
  }

  // ─── Мета: время + галочки ──────────────────────────────────────
  Widget _buildMeta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Время отправки
          Text(
            _formatTime(sentAt),
            style: context.typography.bodySmall?.copyWith(
              fontSize: 11,
            ),
          ),

          // Время прочтения (для своих сообщений)
          if (isMe && readAt != null) ...[
            const SizedBox(width: 4),
            Text(
              _formatTime(readAt!),
              style: context.typography.bodySmall?.copyWith(
                fontSize: 10,
              ),
            ),
          ],

          // Отредактировано
          if (isEdited) ...[
            const SizedBox(width: 4),
            Text(
              'ред.',
              style: context.typography.bodySmall?.copyWith(
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Галочки (только для своих сообщений)
          if (isMe) ...[
            const SizedBox(width: 4),
            _StatusIcon(status: status),
          ],
        ],
      ),
    );
  }

  // ─── Ответ ──────────────────────────────────────────────────────
  Widget _buildReply(BuildContext context) {
    return GestureDetector(
      onTap: onReplyTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.colors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: context.colors.primary,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              replyToSender ?? '',
              style: context.typography.labelMedium?.copyWith(
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              replyToText ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Реакции ────────────────────────────────────────────────────
  Widget _buildReactions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: reactions.map((r) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.colors.outlineVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.emoji, style: const TextStyle(fontSize: 14)),
                if (r.count > 1) ...[
                  const SizedBox(width: 2),
                  Text(
                    '${r.count}',
                    style: context.typography.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Удалённое сообщение ─────────────────────────────────────────
  Widget _buildDeletedMessage(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 48 : 12,
        right: isMe ? 12 : 48,
        top: 2,
        bottom: 2,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.outlineVariant.withOpacity(0.5),
            borderRadius: _bubbleRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 14, color: context.colors.onSurface.withOpacity(0.4)),
              const SizedBox(width: 6),
              Text(
                'Сообщение удалено',
                style: context.typography.bodyMedium?.copyWith(
                  color: context.colors.onSurface.withOpacity(0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Галочки статуса ──────────────────────────────────────────────

/// Иконка статуса сообщения (✓ / ✓✓ / ✓✓ синие)
class _StatusIcon extends StatelessWidget {
  final MessageStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time, size: 14, color: context.colors.onSurface.withOpacity(0.4));
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: context.colors.onSurface.withOpacity(0.4));
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: context.colors.onSurface.withOpacity(0.4));
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: context.colors.primary);
    }
  }
}

// ─── Голосовое сообщение ──────────────────────────────────────────

class _VoiceMessage extends StatelessWidget {
  final Duration duration;
  final bool isMe;

  const _VoiceMessage({required this.duration, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {/* Play/pause toggle */},
          icon: const Icon(Icons.play_arrow),
          iconSize: 28,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              // Волна (placeholder)
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: context.colors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(duration),
          style: context.typography.bodySmall,
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── Файл ─────────────────────────────────────────────────────────

class _FileMessage extends StatelessWidget {
  final String fileName;

  const _FileMessage({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.insert_drive_file, color: context.colors.primary),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Нажмите для скачивания',
                style: context.typography.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Placeholder для медиа ────────────────────────────────────────

class _MediaPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const _MediaPlaceholder({
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: context.colors.outlineVariant,
      child: child,
    );
  }
}

// ─── Модели ───────────────────────────────────────────────────────

enum MessageStatus { sending, sent, delivered, read }

class Reaction {
  final String emoji;
  final int count;
  final bool isSelected;

  const Reaction({
    required this.emoji,
    required this.count,
    this.isSelected = false,
  });
}
