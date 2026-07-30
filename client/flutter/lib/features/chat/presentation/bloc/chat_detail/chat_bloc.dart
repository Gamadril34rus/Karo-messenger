import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/domain/charo_repository.dart';
import '../../../../../core/e2ee/e2ee_manager.dart';
import '../../../../../core/haptic/haptic_service.dart';
import '../../../../../core/network/ws_client.dart';
import '../../../../../core/storage/local_db.dart';
import '../../../../../core/storage/local_db.g.dart';
import '../../../../../core/utils/logger.dart';
import '../../../data/message_item.dart';

// ─── Events ────────────────────────────────────────────────────────

sealed class ChatDetailEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

final class ChatDetailLoadRequested extends ChatDetailEvent {
  final String chatId;
  ChatDetailLoadRequested({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailLoadMoreRequested extends ChatDetailEvent {
  final String chatId;
  ChatDetailLoadMoreRequested({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailMessageSent extends ChatDetailEvent {
  final String chatId;
  final String type;
  final String? content;
  final String? replyToId;
  ChatDetailMessageSent({required this.chatId, required this.type, this.content, this.replyToId});
  @override
  List<Object?> get props => [chatId, type, content, replyToId];
}

final class ChatDetailMessageDeleted extends ChatDetailEvent {
  final String messageId;
  ChatDetailMessageDeleted({required this.messageId});
  @override
  List<Object?> get props => [messageId];
}

final class ChatDetailTypingStarted extends ChatDetailEvent {
  final String chatId;
  ChatDetailTypingStarted({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailTypingStopped extends ChatDetailEvent {
  final String chatId;
  ChatDetailTypingStopped({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailReplySet extends ChatDetailEvent {
  final String messageId;
  ChatDetailReplySet({required this.messageId});
  @override
  List<Object?> get props => [messageId];
}

final class ChatDetailEditSet extends ChatDetailEvent {
  final String messageId;
  ChatDetailEditSet({required this.messageId});
  @override
  List<Object?> get props => [messageId];
}

final class ChatDetailForwardRequested extends ChatDetailEvent {
  final String messageId;
  ChatDetailForwardRequested({required this.messageId});
  @override
  List<Object?> get props => [messageId];
}

final class ChatDetailMediaPicked extends ChatDetailEvent {
  final String chatId;
  final String type;
  ChatDetailMediaPicked({required this.chatId, required this.type});
  @override
  List<Object?> get props => [chatId, type];
}

final class ChatDetailVoiceRecorded extends ChatDetailEvent {
  final String chatId;
  ChatDetailVoiceRecorded({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailLocationSent extends ChatDetailEvent {
  final String chatId;
  ChatDetailLocationSent({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailContactSent extends ChatDetailEvent {
  final String chatId;
  ChatDetailContactSent({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailPollCreated extends ChatDetailEvent {
  final String chatId;
  ChatDetailPollCreated({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailGifSent extends ChatDetailEvent {
  final String chatId;
  ChatDetailGifSent({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailCallInitiated extends ChatDetailEvent {
  final String chatId;
  final bool isVideo;
  ChatDetailCallInitiated({required this.chatId, required this.isVideo});
  @override
  List<Object?> get props => [chatId, isVideo];
}

final class ChatDetailMuteToggled extends ChatDetailEvent {
  final String chatId;
  ChatDetailMuteToggled({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailDisappearingSet extends ChatDetailEvent {
  final String chatId;
  final int seconds;
  ChatDetailDisappearingSet({required this.chatId, required this.seconds});
  @override
  List<Object?> get props => [chatId, seconds];
}

final class ChatDetailExportRequested extends ChatDetailEvent {
  final String chatId;
  ChatDetailExportRequested({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailHistoryCleared extends ChatDetailEvent {
  final String chatId;
  ChatDetailHistoryCleared({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatDetailSearchRequested extends ChatDetailEvent {
  final String chatId;
  final String query;
  ChatDetailSearchRequested({required this.chatId, required this.query});
  @override
  List<Object?> get props => [chatId, query];
}

final class ChatDetailReactionSent extends ChatDetailEvent {
  final String chatId;
  final String messageId;
  final String emoji;
  ChatDetailReactionSent({required this.chatId, required this.messageId, required this.emoji});
  @override
  List<Object?> get props => [chatId, messageId, emoji];
}

// ─── States ────────────────────────────────────────────────────────

sealed class ChatDetailState extends Equatable {
  @override
  List<Object?> get props => [];
}

final class ChatDetailInitial extends ChatDetailState {}

final class ChatDetailLoading extends ChatDetailState {}

final class ChatDetailLoaded extends ChatDetailState {
  final String chatId;
  final String chatTitle;
  final bool isOnline;
  final int? memberCount;
  final List<MessageItem> messages;
  final String? typingUserId;
  final String? replyToId;
  final String? editingId;
  final bool hasMore;
  final int? disappearingTimer;

  ChatDetailLoaded({
    required this.chatId,
    this.chatTitle = 'Чат',
    this.isOnline = false,
    this.memberCount,
    this.messages = const [],
    this.typingUserId,
    this.replyToId,
    this.editingId,
    this.hasMore = true,
    this.disappearingTimer,
  });

  ChatDetailLoaded copyWith({
    String? chatTitle,
    bool? isOnline,
    int? memberCount,
    List<MessageItem>? messages,
    String? typingUserId,
    String? replyToId,
    String? editingId,
    bool? hasMore,
    int? disappearingTimer,
    bool clearReply = false,
    bool clearEditing = false,
    bool clearTyping = false,
  }) {
    return ChatDetailLoaded(
      chatId: chatId,
      chatTitle: chatTitle ?? this.chatTitle,
      isOnline: isOnline ?? this.isOnline,
      memberCount: memberCount ?? this.memberCount,
      messages: messages ?? this.messages,
      typingUserId: clearTyping ? null : (typingUserId ?? this.typingUserId),
      replyToId: clearReply ? null : (replyToId ?? this.replyToId),
      editingId: clearEditing ? null : (editingId ?? this.editingId),
      hasMore: hasMore ?? this.hasMore,
      disappearingTimer: disappearingTimer ?? this.disappearingTimer,
    );
  }

  @override
  List<Object?> get props => [chatId, chatTitle, isOnline, memberCount, messages, typingUserId, replyToId, editingId, hasMore, disappearingTimer];
}

final class ChatDetailError extends ChatDetailState {
  final String message;
  ChatDetailError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ──────────────────────────────────────────────────────────

class ChatDetailBloc extends Bloc<ChatDetailEvent, ChatDetailState> {
  final CharoRepository _repository;
  final WsClient _wsClient;
  final AppDatabase _localDb;
  final E2EEKeyManager _e2ee;
  final HapticService _haptic;

  ChatDetailBloc({
    required CharoRepository repository,
    required WsClient wsClient,
    required AppDatabase localDb,
    E2EEKeyManager? e2ee,
    HapticService? haptic,
  })  : _repository = repository,
        _wsClient = wsClient,
        _localDb = localDb,
        _e2ee = e2ee ?? E2EEKeyManager.instance,
        _haptic = haptic ?? HapticService.instance,
        super(ChatDetailInitial()) {
    on<ChatDetailLoadRequested>(_onLoadRequested);
    on<ChatDetailLoadMoreRequested>(_onLoadMore);
    on<ChatDetailMessageSent>(_onMessageSent);
    on<ChatDetailMessageDeleted>(_onMessageDeleted);
    on<ChatDetailTypingStarted>(_onTypingStarted);
    on<ChatDetailTypingStopped>(_onTypingStopped);
    on<ChatDetailReplySet>(_onReplySet);
    on<ChatDetailEditSet>(_onEditSet);
    on<ChatDetailForwardRequested>(_onForwardRequested);
    on<ChatDetailMediaPicked>(_onMediaPicked);
    on<ChatDetailVoiceRecorded>(_onVoiceRecorded);
    on<ChatDetailLocationSent>(_onLocationSent);
    on<ChatDetailContactSent>(_onContactSent);
    on<ChatDetailPollCreated>(_onPollCreated);
    on<ChatDetailGifSent>(_onGifSent);
    on<ChatDetailCallInitiated>(_onCallInitiated);
    on<ChatDetailMuteToggled>(_onMuteToggled);
    on<ChatDetailDisappearingSet>(_onDisappearingSet);
    on<ChatDetailExportRequested>(_onExportRequested);
    on<ChatDetailHistoryCleared>(_onHistoryCleared);
    on<ChatDetailSearchRequested>(_onSearchRequested);
    on<ChatDetailReactionSent>(_onReactionSent);

    _wsClient.messages.listen(_onWsEvent);
  }

  Future<void> _onLoadRequested(ChatDetailLoadRequested event, Emitter<ChatDetailState> emit) async {
    emit(ChatDetailLoading());
    try {
      // Сначала пытаемся загрузить из локального кэша
      final localMessages = await _localDb.getMessages(event.chatId);
      final localChat = await _getLocalChat(event.chatId);

      if (localMessages.isNotEmpty && localChat != null) {
        emit(ChatDetailLoaded(
          chatId: event.chatId,
          chatTitle: localChat.title ?? 'Чат',
          isOnline: localChat.isMuted,
          messages: localMessages.map(_localMessageToItem).toList(),
        ));
      }

      // Затем загружаем с сервера через repository
      final serverMessages = await _repository.getMessages(event.chatId);

      // Кэшируем в локальную БД
      await _cacheMessages(event.chatId, serverMessages);

      emit(ChatDetailLoaded(
        chatId: event.chatId,
        chatTitle: localChat?.title ?? 'Чат',
        messages: serverMessages,
      ));
    } on CharoApiException catch (e) {
      emit(ChatDetailError(message: e.message));
    }
  }

  Future<void> _onLoadMore(ChatDetailLoadMoreRequested event, Emitter<ChatDetailState> emit) async {
    final current = state;
    if (current is! ChatDetailLoaded) return;

    try {
      final lastId = current.messages.isNotEmpty ? current.messages.last.id : null;
      final moreMessages = await _repository.getMessages(event.chatId, afterId: lastId);

      if (moreMessages.isEmpty) {
        emit(current.copyWith(hasMore: false));
        return;
      }

      await _cacheMessages(event.chatId, moreMessages);
      emit(current.copyWith(messages: [...current.messages, ...moreMessages]));
    } catch (e) {
      logger.e('Load more error: $e');
    }
  }

  void _onMessageSent(ChatDetailMessageSent event, Emitter<ChatDetailState> emit) {
    final current = state;
    if (current is! ChatDetailLoaded) return;

    // Если редактирование — отправляем через WS message.update
    if (current.editingId != null) {
      _wsClient.send('message.update', {
        'messageId': current.editingId,
        'content': event.content,
      });
      emit(current.copyWith(clearEditing: true));
      return;
    }

    // Обычная отправка через repository (WS message.send)
    _repository.sendMessage(event.chatId, event.type, event.content);

    // Оптимистичное обновление
    final optimistic = MessageItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: event.chatId,
      senderId: 'me',
      isMe: true,
      type: event.type,
      text: event.content,
      status: MessageStatus.sending,
      sentAt: DateTime.now(),
    );

    final updatedMessages = [...current.messages, optimistic];
    emit(current.copyWith(messages: updatedMessages, clearReply: true));
  }

  Future<void> _onMessageDeleted(ChatDetailMessageDeleted event, Emitter<ChatDetailState> emit) async {
    try {
      await _repository.deleteMessage(event.messageId);
      final current = state;
      if (current is ChatDetailLoaded) {
        emit(current.copyWith(messages: current.messages.where((m) => m.id != event.messageId).toList()));
      }
    } on CharoApiException catch (e) {
      logger.e('Delete message error: ${e.message}');
    }
  }

  void _onTypingStarted(ChatDetailTypingStarted event, Emitter<ChatDetailState> emit) {
    _wsClient.send('typing.start', {'chatId': event.chatId});
  }

  void _onTypingStopped(ChatDetailTypingStopped event, Emitter<ChatDetailState> emit) {
    _wsClient.send('typing.stop', {'chatId': event.chatId});
  }

  void _onReplySet(ChatDetailReplySet event, Emitter<ChatDetailState> emit) {
    final current = state;
    if (current is ChatDetailLoaded) {
      emit(current.copyWith(replyToId: event.messageId));
    }
  }

  void _onEditSet(ChatDetailEditSet event, Emitter<ChatDetailState> emit) {
    final current = state;
    if (current is ChatDetailLoaded) {
      emit(current.copyWith(editingId: event.messageId));
    }
  }

  void _onForwardRequested(ChatDetailForwardRequested event, Emitter<ChatDetailState> emit) {
    _wsClient.send('message.forward', {'messageId': event.messageId});
  }

  void _onMediaPicked(ChatDetailMediaPicked event, Emitter<ChatDetailState> emit) {
    _repository.sendMessage(event.chatId, event.type, {'action': 'upload_media'});
  }

  void _onVoiceRecorded(ChatDetailVoiceRecorded event, Emitter<ChatDetailState> emit) {
    _repository.sendMessage(event.chatId, 'voice', {'action': 'upload_voice'});
  }

  void _onLocationSent(ChatDetailLocationSent event, Emitter<ChatDetailState> emit) {
    _repository.sendMessage(event.chatId, 'location', {'action': 'send_location'});
  }

  void _onContactSent(ChatDetailContactSent event, Emitter<ChatDetailState> emit) {
    _repository.sendMessage(event.chatId, 'contact', {'action': 'send_contact'});
  }

  void _onPollCreated(ChatDetailPollCreated event, Emitter<ChatDetailState> emit) {
    _repository.sendMessage(event.chatId, 'poll', {'action': 'create_poll'});
  }

  void _onGifSent(ChatDetailGifSent event, Emitter<ChatDetailState> emit) {
    _repository.sendMessage(event.chatId, 'gif', {'action': 'search_gif'});
  }

  void _onCallInitiated(ChatDetailCallInitiated event, Emitter<ChatDetailState> emit) {
    _wsClient.send('call.initiate', {
      'chatId': event.chatId,
      'type': event.isVideo ? 'video' : 'voice',
    });
  }

  Future<void> _onMuteToggled(ChatDetailMuteToggled event, Emitter<ChatDetailState> emit) async {
    await _repository.muteChat(event.chatId, true);
  }

  Future<void> _onDisappearingSet(ChatDetailDisappearingSet event, Emitter<ChatDetailState> emit) async {
    // Update chat via WS — server handles the timer
    _wsClient.send('chat.update', {
      'chatId': event.chatId,
      'disappearTimer': event.seconds,
    });
    final current = state;
    if (current is ChatDetailLoaded) {
      emit(current.copyWith(disappearingTimer: event.seconds));
    }
  }

  Future<void> _onExportRequested(ChatDetailExportRequested event, Emitter<ChatDetailState> emit) async {
    await _repository.exportChat(event.chatId);
  }

  Future<void> _onHistoryCleared(ChatDetailHistoryCleared event, Emitter<ChatDetailState> emit) async {
    await _repository.clearChatHistory(event.chatId);
    final current = state;
    if (current is ChatDetailLoaded) {
      emit(current.copyWith(messages: []));
    }
  }

  Future<void> _onSearchRequested(ChatDetailSearchRequested event, Emitter<ChatDetailState> emit) async {
    final current = state;
    if (current is! ChatDetailLoaded) return;
    if (event.query.isEmpty) return;

    final results = await _repository.searchMessagesInChat(event.chatId, event.query);
    emit(current.copyWith(messages: results));
  }

  void _onReactionSent(ChatDetailReactionSent event, Emitter<ChatDetailState> emit) {
    final current = state;
    if (current is! ChatDetailLoaded) return;

    // Отправить реакцию на сервер через WS
    _wsClient.send('message.react', {
      'chatId': event.chatId,
      'messageId': event.messageId,
      'emoji': event.emoji,
    });

    // Оптимистичное обновление — добавляем реакцию локально
    final updated = current.messages.map((m) {
      if (m.id == event.messageId) {
        final existing = m.reactions.where((r) => r.emoji == event.emoji).firstOrNull;
        final updatedReactions = existing != null
            ? m.reactions.map((r) => r.emoji == event.emoji
                ? Reaction(emoji: r.emoji, count: r.count + 1, isSelected: true)
                : r).toList()
            : [...m.reactions, Reaction(emoji: event.emoji, count: 1, isSelected: true)];
        return MessageItem(
          id: m.id, chatId: m.chatId, senderId: m.senderId,
          senderName: m.senderName, isMe: m.isMe, type: m.type,
          text: m.text, mediaUrl: m.mediaUrl, mediaThumbnail: m.mediaThumbnail,
          replyToText: m.replyToText, replyToSender: m.replyToSender,
          isEdited: m.isEdited, isDeleted: m.isDeleted,
          status: m.status, sentAt: m.sentAt, readAt: m.readAt,
          reactions: updatedReactions,
        );
      }
      return m;
    }).toList();
    emit(current.copyWith(messages: updated));
  }

  void _onWsEvent(WsEvent event) {
    final current = state;
    if (current is! ChatDetailLoaded) return;

    switch (event.type) {
      case 'message.new':
        final msg = _parseMessage(event.data);

        // E2EE расшифровка incoming сообщения
        if (event.data is Map<String, dynamic>) {
          final data = event.data as Map<String, dynamic>;
          final isEncrypted = data['content']?['is_encrypted'] as bool? ?? false;
          if (isEncrypted && msg.senderId != 'me') {
            final e2eePayload = data['content']?['e2ee_text'] as String?;
            if (e2eePayload != null) {
              _decryptIncomingMessage(msg, e2eePayload);
              return;
            }
          }
        }

        if (msg.chatId == current.chatId && !current.messages.any((m) => m.id == msg.id)) {
          add(ChatDetailLoadRequested(chatId: current.chatId));
          _wsClient.markAsRead(current.chatId, msg.id);
          _haptic.onReceiveMessage();
        }
        break;
      case 'typing':
        final chatId = event.data['chatId'] as String?;
        final userId = event.data['userId'] as String?;
        if (chatId == current.chatId) {
          emit(current.copyWith(typingUserId: userId, clearTyping: userId == null));
        }
        break;
      case 'message.updated':
        add(ChatDetailLoadRequested(chatId: current.chatId));
        break;
      case 'message.disappeared':
        final messageIds = (event.data['messageIds'] as List?)?.cast<String>() ?? [];
        if (messageIds.isNotEmpty) {
          final updated = current.messages.where((m) => !messageIds.contains(m.id)).toList();
          emit(current.copyWith(messages: updated));
        }
        break;
      case 'message.status':
        final statusMessageId = event.data['messageId'] as String?;
        final statusStr = event.data['status'] as String? ?? 'sent';
        if (statusMessageId != null) {
          final updated = current.messages.map((m) {
            if (m.id == statusMessageId) {
              return MessageItem(
                id: m.id, chatId: m.chatId, senderId: m.senderId,
                senderName: m.senderName, isMe: m.isMe, type: m.type,
                text: m.text, mediaUrl: m.mediaUrl, mediaThumbnail: m.mediaThumbnail,
                replyToText: m.replyToText, replyToSender: m.replyToSender,
                isEdited: m.isEdited, isDeleted: m.isDeleted,
                status: _parseStatus(statusStr),
                sentAt: m.sentAt, readAt: statusStr == 'read' ? DateTime.now() : m.readAt,
                reactions: m.reactions,
              );
            }
            return m;
          }).toList();
          emit(current.copyWith(messages: updated));
        }
        break;
    }
  }

  MessageItem _parseMessage(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    return MessageItem(
      id: map['id'] as String? ?? '',
      chatId: map['chat_id'] as String? ?? map['chatId'] as String? ?? '',
      senderId: map['sender_id'] as String? ?? map['senderId'] as String? ?? '',
      senderName: map['sender']?['display_name'] as String?,
      isMe: map['is_me'] as bool? ?? false,
      type: map['type'] as String? ?? 'text',
      text: map['content']?['text'] as String? ?? map['content'] as String?,
      mediaUrl: map['content']?['url'] as String?,
      isEdited: map['is_edited'] as bool? ?? false,
      isDeleted: map['is_deleted'] as bool? ?? false,
      status: _parseStatus(map['status'] as String?),
      sentAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      readAt: map['read_at'] != null ? DateTime.parse(map['read_at'] as String) : null,
    );
  }

  MessageStatus _parseStatus(String? status) {
    switch (status) {
      case 'sent': return MessageStatus.sent;
      case 'delivered': return MessageStatus.delivered;
      case 'read': return MessageStatus.read;
      default: return MessageStatus.sending;
    }
  }

  /// E2EE расшифровка входящего сообщения
  Future<void> _decryptIncomingMessage(MessageItem msg, String e2eePayload) async {
    try {
      final plaintext = await _e2ee.decryptWithRecovery(msg.senderId, e2eePayload);
      if (plaintext == null) {
        logger.w('🚨 E2EE decryption failed for message from ${msg.senderId}');
        return;
      }

      final decryptedMsg = MessageItem(
        id: msg.id,
        chatId: msg.chatId,
        senderId: msg.senderId,
        senderName: msg.senderName,
        isMe: false,
        type: msg.type,
        text: plaintext,
        status: msg.status,
        sentAt: msg.sentAt,
        readAt: msg.readAt,
        reactions: msg.reactions,
      );

      final current = state;
      if (current is ChatDetailLoaded && decryptedMsg.chatId == current.chatId) {
        if (!current.messages.any((m) => m.id == decryptedMsg.id)) {
          add(ChatDetailLoadRequested(chatId: current.chatId));
          _wsClient.markAsRead(current.chatId, decryptedMsg.id);
          await _haptic.onReceiveMessage();
        }
      }
    } catch (e) {
      logger.e('🚨 E2EE decryption error: $e');
    }
  }

  // ─── Local DB helpers ──────────────────────────────────────────

  Future<void> _cacheMessages(String chatId, List<MessageItem> messages) async {
    try {
      final companions = messages.map((m) => LocalMessagesCompanion.insert(
        id: m.id,
        chatId: chatId,
        senderId: m.senderId,
        type: m.type,
        content: Value(m.text),
        isEdited: Value(m.isEdited),
        isRead: Value(m.isDeleted ? false : m.status == MessageStatus.read),
        status: Value(m.status.name),
        createdAt: m.sentAt,
      )).toList();
      await _localDb.insertMessages(companions);
    } catch (e) {
      logger.e('Cache messages error: $e');
    }
  }

  Future<LocalChat?> _getLocalChat(String chatId) async {
    try {
      final chats = await _localDb.getAllChats();
      return chats.where((c) => c.id == chatId).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  MessageItem _localMessageToItem(LocalMessage m) {
    return MessageItem(
      id: m.id,
      chatId: m.chatId,
      senderId: m.senderId,
      isMe: m.senderId == 'me',
      type: m.type,
      text: m.content,
      isEdited: m.isEdited,
      isDeleted: false,
      status: _parseStatus(m.status),
      sentAt: m.createdAt,
    );
  }
}
