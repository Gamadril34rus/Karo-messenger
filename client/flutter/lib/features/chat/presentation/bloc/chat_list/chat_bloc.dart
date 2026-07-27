import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/ws_client.dart';
import '../../../../../core/storage/local_db.dart';
import '../../../../../core/utils/logger.dart';
import '../../screens/chat_list_screen.dart';

// ─── Events ────────────────────────────────────────────────────────

sealed class ChatListEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

final class ChatListLoadRequested extends ChatListEvent {}

final class ChatListSearchRequested extends ChatListEvent {
  final String query;
  ChatListSearchRequested({required this.query});
  @override
  List<Object?> get props => [query];
}

final class ChatListCreateRequested extends ChatListEvent {
  final String type;
  final String? title;
  ChatListCreateRequested({required this.type, this.title});
  @override
  List<Object?> get props => [type, title];
}

final class ChatListChatUpdated extends ChatListEvent {
  final ChatItem chat;
  ChatListChatUpdated({required this.chat});
  @override
  List<Object?> get props => [chat];
}

final class ChatListChatDeleted extends ChatListEvent {
  final String chatId;
  ChatListChatDeleted({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

// ─── States ────────────────────────────────────────────────────────

sealed class ChatListState extends Equatable {
  @override
  List<Object?> get props => [];
}

final class ChatListInitial extends ChatListState {}

final class ChatListLoading extends ChatListState {}

final class ChatListLoaded extends ChatListState {
  final List<ChatItem> chats;
  final String? searchQuery;
  ChatListLoaded({required this.chats, this.searchQuery});
  @override
  List<Object?> get props => [chats, searchQuery];
}

final class ChatListError extends ChatListState {
  final String message;
  ChatListError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ──────────────────────────────────────────────────────────

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  final ApiClient _apiClient;
  final WsClient _wsClient;
  final AppDatabase _localDb;

  ChatListBloc({
    required ApiClient apiClient,
    required WsClient wsClient,
    required AppDatabase localDb,
  })  : _apiClient = apiClient,
        _wsClient = wsClient,
        _localDb = localDb,
        super(ChatListInitial()) {
    on<ChatListLoadRequested>(_onLoadRequested);
    on<ChatListSearchRequested>(_onSearchRequested);
    on<ChatListCreateRequested>(_onCreateRequested);
    on<ChatListChatUpdated>(_onChatUpdated);
    on<ChatListChatDeleted>(_onChatDeleted);

    // Подписка на WebSocket-события
    _wsClient.messages.listen(_onWsEvent);
  }

  Future<void> _onLoadRequested(
    ChatListLoadRequested event,
    Emitter<ChatListState> emit,
  ) async {
    emit(ChatListLoading());
    try {
      // Сначала пытаемся загрузить из локального кэша
      final localChats = await _localDb.getAllChats();

      if (localChats.isNotEmpty) {
        emit(ChatListLoaded(
          chats: localChats.map(_localChatToItem).toList(),
        ));
      }

      // Затем загружаем с сервера
      final response = await _apiClient.get('/api/v1/chats');
      final serverChats = (response.asList)
          .map<ChatItem>((json) => ChatItem(
                id: json['id'] as String,
                type: json['type'] as String? ?? 'private',
                title: json['title'] as String?,
                avatarUrl: json['avatar_url'] as String?,
                lastMessage: json['last_message'] as String?,
                lastMessageSender: json['last_message_sender'] as String?,
                lastMessageAt: json['last_message_at'] != null
                    ? DateTime.parse(json['last_message_at'] as String)
                    : null,
                unreadCount: json['unread_count'] as int? ?? 0,
                isMuted: json['is_muted'] as bool? ?? false,
                isPinned: json['is_pinned'] as bool? ?? false,
                isOnline: json['is_online'] as bool? ?? false,
              ))
          .toList();

      // Кэшируем в локальную БД
      for (final chat in serverChats) {
        await _localDb.insertChat(_chatItemToCompanion(chat));
      }

      emit(ChatListLoaded(chats: serverChats));
    } on CharoApiException catch (e) {
      // Если сервер недоступен — показываем кэш
      final localChats = await _localDb.getAllChats();
      if (localChats.isNotEmpty) {
        emit(ChatListLoaded(
          chats: localChats.map(_localChatToItem).toList(),
        ));
      } else {
        emit(ChatListError(message: e.message));
      }
    } catch (e) {
      logger.e('ChatList load error: $e');
      emit(ChatListError(message: 'Не удалось загрузить чаты'));
    }
  }

  Future<void> _onSearchRequested(
    ChatListSearchRequested event,
    Emitter<ChatListState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatListLoaded) return;

    if (event.query.isEmpty) {
      add(ChatListLoadRequested());
      return;
    }

    try {
      final response = await _apiClient.get(
        '/api/v1/chats',
        queryParameters: {'q': event.query},
      );
      final filtered = (response.asList)
          .map<ChatItem>((json) => ChatItem(
                id: json['id'] as String,
                type: json['type'] as String? ?? 'private',
                title: json['title'] as String?,
                avatarUrl: json['avatar_url'] as String?,
                lastMessage: json['last_message'] as String?,
                unreadCount: json['unread_count'] as int? ?? 0,
              ))
          .toList();

      emit(ChatListLoaded(chats: filtered, searchQuery: event.query));
    } catch (e) {
      // Локальный поиск по кэшу
      final localChats = await _localDb.getAllChats();
      final filtered = localChats
          .where((c) =>
              (c.title?.toLowerCase().contains(event.query.toLowerCase()) ?? false))
          .map(_localChatToItem)
          .toList();
      emit(ChatListLoaded(chats: filtered, searchQuery: event.query));
    }
  }

  Future<void> _onCreateRequested(
    ChatListCreateRequested event,
    Emitter<ChatListState> emit,
  ) async {
    try {
      final response = await _apiClient.post('/api/v1/chats', data: {
        'type': event.type,
        'title': event.title,
      });
      final chatData = response.asMap;
      final newChat = ChatItem(
        id: chatData['id'] as String,
        type: event.type,
        title: event.title,
      );

      final currentState = state;
      if (currentState is ChatListLoaded) {
        emit(ChatListLoaded(chats: [newChat, ...currentState.chats]));
      }
    } on CharoApiException catch (e) {
      logger.e('Create chat error: ${e.message}');
    }
  }

  void _onChatUpdated(ChatListChatUpdated event, Emitter<ChatListState> emit) {
    final currentState = state;
    if (currentState is! ChatListLoaded) return;

    final chats = currentState.chats.map((c) =>
        c.id == event.chat.id ? event.chat : c).toList();
    chats.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return (b.lastMessageAt ?? DateTime(1970))
          .compareTo(a.lastMessageAt ?? DateTime(1970));
    });

    emit(ChatListLoaded(chats: chats, searchQuery: currentState.searchQuery));
  }

  void _onChatDeleted(ChatListChatDeleted event, Emitter<ChatListState> emit) {
    final currentState = state;
    if (currentState is! ChatListLoaded) return;
    emit(ChatListLoaded(
      chats: currentState.chats.where((c) => c.id != event.chatId).toList(),
      searchQuery: currentState.searchQuery,
    ));
  }

  void _onWsEvent(WsEvent event) {
    switch (event.type) {
      case 'message.new':
        final chatId = event.data['chatId'] as String?;
        if (chatId == null) return;
        // Обновляем чат в списке — поднимаем наверх
        final currentState = state;
        if (currentState is ChatListLoaded) {
          final chatIndex = currentState.chats.indexWhere((c) => c.id == chatId);
          if (chatIndex >= 0) {
            final chat = currentState.chats[chatIndex];
            final content = event.data['content'];
            final updated = ChatItem(
              id: chat.id,
              type: chat.type,
              title: chat.title,
              avatarUrl: chat.avatarUrl,
              lastMessage: content is String ? content : 'Медиа',
              lastMessageAt: DateTime.now(),
              unreadCount: chat.unreadCount + 1,
              isMuted: chat.isMuted,
              isPinned: chat.isPinned,
            );
            add(ChatListChatUpdated(chat: updated));
          }
        }
        break;
      case 'chat.updated':
        final chatId = event.data['chatId'] as String?;
        if (chatId != null) {
          add(ChatListLoadRequested());
        }
        break;
    }
  }

  // Маппинг локального чата -> ChatItem
  ChatItem _localChatToItem(dynamic c) {
    return ChatItem(
      id: c.id,
      type: c.type,
      title: c.title,
      avatarUrl: c.avatarUrl,
      lastMessage: c.lastMessage,
      lastMessageAt: c.lastMessageAt,
      unreadCount: c.unreadCount,
      isMuted: c.isMuted,
      isPinned: c.isPinned,
    );
  }

  // Маппинг ChatItem -> Drift companion
  dynamic _chatItemToCompanion(ChatItem chat) {
    // Возвращаем Map для Drift insert — полная реализация при генерации кода
    return {
      'id': chat.id,
      'type': chat.type,
      'title': chat.title,
      'avatarUrl': chat.avatarUrl,
      'lastMessage': chat.lastMessage,
      'lastMessageAt': chat.lastMessageAt?.toIso8601String(),
      'unreadCount': chat.unreadCount,
      'isMuted': chat.isMuted,
      'isPinned': chat.isPinned,
      'updatedAt': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
