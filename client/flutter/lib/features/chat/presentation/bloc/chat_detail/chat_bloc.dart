import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/e2ee/e2ee_manager.dart';
import '../../../../../core/errors/app_error.dart';
import '../../../../../core/haptic/haptic_service.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/ws_client.dart';
import '../../../../../core/storage/local_db.dart';
import '../../../../../core/utils/logger.dart';
import '../../screens/chat_detail_screen.dart';

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
  final ApiClient _apiClient;
  final WsClient _wsClient;
  final AppDatabase _localDb;
  final E2EEKeyManager _e2ee;
  final HapticService _haptic;

  ChatDetailBloc({
    required ApiClient apiClient,
    required WsClient wsClient,
    required AppDatabase localDb,
    E2EEKeyManager? e2ee,
    HapticService? haptic,
  })  : _apiClient = apiClient,
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

    _wsClient.messages.listen(_onWsEvent);
  }

  Future<void> _onLoadRequested(ChatDetailLoadRequested event, Emitter<ChatDetailState> emit) async {
    emit(ChatDetailLoading());
    try {
      final response = await _apiClient.get('/api/v1/chats/${event.chatId}');
      final chatData = response.asMap;

      final messagesResponse = await _apiClient.get(
        '/api/v1/chats/${event.chatId}/messages',
        queryParameters: {'limit': 50},
      );

      final messages = (messagesResponse.asList).map<MessageItem>(_parseMessage).toList();

      emit(ChatDetailLoaded(
        chatId: event.chatId,
        chatTitle: chatData['title'] as String? ?? 'Чат',
        isOnline: chatData['is_online'] as bool? ?? false,
        memberCount: chatData['member_count'] as int?,
        messages: messages,
      ));
    } on CharoApiException catch (e) {
      emit(ChatDetailError(message: e.message));
    } catch (e) {
      logger.e('ChatDetail load error: $e');
      emit(ChatDetailError(message: 'Не удалось загрузить чат'));
    }
  }

  Future<void> _onLoadMore(ChatDetailLoadMoreRequested event, Emitter<ChatDetailState> emit) async {
    final current = state;
    if (current is! ChatDetailLoaded || !current.hasMore) return;

    try {
      final oldestMsg = current.messages.firstOrNull;
      final before = oldestMsg?.sentAt.toIso8601String();

      final response = await _apiClient.get(
        '/api/v1/chats/${event.chatId}/messages',
        queryParameters: {'before': before, 'limit': 50},
      );

      final olderMessages = (response.asList).map<MessageItem>(_parseMessage).toList();

      emit(current.copyWith(
        messages: [...olderMessages, ...current.messages],
        hasMore: olderMessages.length >= 50,
      ));
    } catch (e) {
      logger.e('Load more error: $e');
    }
  }

  Future<void> _onMessageSent(ChatDetailMessageSent event, Emitter<ChatDetailState> emit) async {
    final current = state;
    if (current is! ChatDetailLoaded) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Оптимистичное обновление — сразу показываем сообщение
    final optimisticMsg = MessageItem(
      id: tempId,
      chatId: event.chatId,
      senderId: 'me',
      isMe: true,
      type: event.type,
      text: event.content,
      status: MessageStatus.sending,
      sentAt: DateTime.now(),
      replyToText: current.replyToId != null ? 'Сообщение' : null,
    );

    emit(current.copyWith(
      messages: [...current.messages, optimisticMsg],
      clearReply: true,
    ));

    // Haptic feedback при отправке
    await _haptic.onSendMessage();

    // E2EE шифрование текстового сообщения
    String? encryptedContent = event.content;
    bool isE2ee = false;

    if (event.type == 'text' && event.content != null) {
      try {
        // Определение recipientId (для 1:1 чата — другой участник)
        final otherMemberId = current.messages
            .where((m) => !m.isMe)
            .firstOrNull?.senderId;

        if (otherMemberId != null) {
          final hasSession = await _e2ee.ensureSession(otherMemberId);
          if (hasSession) {
            encryptedContent = await _e2ee.encryptWithSessionRecovery(
              otherMemberId,
              event.content!,
            );
            isE2ee = true;
            logger.d('🔐 Message encrypted with E2EE for $otherMemberId');
          }
        }
      } catch (e) {
        logger.e('E2EE encryption failed — sending plaintext: $e');
        encryptedContent = event.content;
      }
    }

    // Отправляем через WebSocket (с E2EE-шифрованием при наличии сессии)
    _wsClient.sendMessage(
      chatId: event.chatId,
      type: event.type,
      content: isE2ee
          ? {'e2ee_text': encryptedContent, 'is_encrypted': true}
          : {'text': event.content},
      tempId: tempId,
      replyTo: current.replyToId,
    );
  }

  void _onMessageDeleted(ChatDetailMessageDeleted event, Emitter<ChatDetailState> emit) {
    final current = state;
    if (current is! ChatDetailLoaded) return;

    _wsClient.send('message.delete', {'messageId': event.messageId});

    final updated = current.messages.map((m) =>
        m.id == event.messageId ? MessageItem(
          id: m.id, chatId: m.chatId, senderId: m.senderId,
          senderName: m.senderName, isMe: m.isMe, type: m.type,
          isDeleted: true, sentAt: m.sentAt,
        ) : m).toList();
    emit(current.copyWith(messages: updated));
  }

  void _onTypingStarted(ChatDetailTypingStarted event, Emitter<ChatDetailState> emit) {
    _wsClient.startTyping(event.chatId);
  }

  void _onTypingStopped(ChatDetailTypingStopped event, Emitter<ChatDetailState> emit) {
    _wsClient.stopTyping(event.chatId);
  }

  void _onReplySet(ChatDetailReplySet event, Emitter<ChatDetailState> emit) {
    final current = state;
    if (current is! ChatDetailLoaded) return;
    emit(current.copyWith(replyToId: event.messageId));
  }

  void _onEditSet(ChatDetailEditSet event, Emitter<ChatDetailState> emit) {
    final current = state;
    if (current is! ChatDetailLoaded) return;
    emit(current.copyWith(editingId: event.messageId));
  }

  Future<void> _onForwardRequested(ChatDetailForwardRequested event, Emitter<ChatDetailState> emit) async {
    _wsClient.send('message.forward', {'messageId': event.messageId});
  }

  Future<void> _onMediaPicked(ChatDetailMediaPicked event, Emitter<ChatDetailState> emit) async {
    final current = state;
    if (current is! ChatDetailLoaded) return;

    _wsClient.sendMessage(
      chatId: event.chatId,
      type: event.type,
      content: {'action': 'pick_${event.type}'},
    );
  }

  Future<void> _onVoiceRecorded(ChatDetailVoiceRecorded event, Emitter<ChatDetailState> emit) async {
    _wsClient.sendMessage(chatId: event.chatId, type: 'voice', content: {'action': 'record'});
  }

  Future<void> _onLocationSent(ChatDetailLocationSent event, Emitter<ChatDetailState> emit) async {
    _wsClient.sendMessage(chatId: event.chatId, type: 'location', content: {'action': 'send_location'});
  }

  Future<void> _onContactSent(ChatDetailContactSent event, Emitter<ChatDetailState> emit) async {
    _wsClient.sendMessage(chatId: event.chatId, type: 'contact', content: {'action': 'send_contact'});
  }

  Future<void> _onPollCreated(ChatDetailPollCreated event, Emitter<ChatDetailState> emit) async {
    _wsClient.sendMessage(chatId: event.chatId, type: 'poll', content: {'action': 'create_poll'});
  }

  Future<void> _onGifSent(ChatDetailGifSent event, Emitter<ChatDetailState> emit) async {
    _wsClient.sendMessage(chatId: event.chatId, type: 'gif', content: {'action': 'search_gif'});
  }

  void _onCallInitiated(ChatDetailCallInitiated event, Emitter<ChatDetailState> emit) {
    _wsClient.send('call.initiate', {
      'chatId': event.chatId,
      'type': event.isVideo ? 'video' : 'voice',
    });
  }

  Future<void> _onMuteToggled(ChatDetailMuteToggled event, Emitter<ChatDetailState> emit) async {
    await _apiClient.patch('/api/v1/chats/${event.chatId}', data: {'is_muted': true});
  }

  Future<void> _onDisappearingSet(ChatDetailDisappearingSet event, Emitter<ChatDetailState> emit) async {
    await _apiClient.patch('/api/v1/chats/${event.chatId}', data: {'disappear_timer': event.seconds});
    final current = state;
    if (current is ChatDetailLoaded) {
      emit(current.copyWith(disappearingTimer: event.seconds));
    }
  }

  Future<void> _onExportRequested(ChatDetailExportRequested event, Emitter<ChatDetailState> emit) async {
    await _apiClient.get('/api/v1/chats/${event.chatId}/export');
  }

  Future<void> _onHistoryCleared(ChatDetailHistoryCleared event, Emitter<ChatDetailState> emit) async {
    await _apiClient.delete('/api/v1/chats/${event.chatId}/messages');
    final current = state;
    if (current is ChatDetailLoaded) {
      emit(current.copyWith(messages: []));
    }
  }

  Future<void> _onSearchRequested(ChatDetailSearchRequested event, Emitter<ChatDetailState> emit) async {
    final current = state;
    if (current is! ChatDetailLoaded) return;
    if (event.query.isEmpty) return;

    final response = await _apiClient.get(
      '/api/v1/chats/${event.chatId}/search',
      queryParameters: {'q': event.query},
    );
    final results = (response.asList).map<MessageItem>(_parseMessage).toList();
    emit(current.copyWith(messages: results));
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
              return; // Расшифровка происходит async — добавление через add()
            }
          }
        }

        if (msg.chatId == current.chatId && !current.messages.any((m) => m.id == msg.id)) {
          add(ChatDetailLoadRequested(chatId: current.chatId));
          _wsClient.markAsRead(current.chatId, msg.id);
          _haptic.onReceiveMessage();
        }
        break;
      case 'message.status':
        final updated = current.messages.map((m) {
          if (m.id == event.data['messageId']) {
            final statusStr = event.data['status'] as String? ?? 'sent';
            return MessageItem(
              id: m.id, chatId: m.chatId, senderId: m.senderId,
              senderName: m.senderName, isMe: m.isMe, type: m.type,
              text: m.text, mediaUrl: m.mediaUrl,
              isEdited: m.isEdited, isDeleted: m.isDeleted,
              status: _parseStatus(statusStr),
              sentAt: m.sentAt, readAt: statusStr == 'read' ? DateTime.now() : m.readAt,
              reactions: m.reactions,
            );
          }
          return m;
        }).toList();
        emit(current.copyWith(messages: updated));
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
}
