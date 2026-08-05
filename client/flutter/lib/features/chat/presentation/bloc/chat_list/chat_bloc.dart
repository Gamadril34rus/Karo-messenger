// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:drift/drift.dart' show Value;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/domain/charo_repository.dart';
import '../../../../../core/network/ws_client.dart';
import '../../../../../core/storage/local_db.dart';
import '../../../../../core/storage/local_db.g.dart';
import '../../../../../core/utils/logger.dart';
import '../../../data/chat_item.dart';

// ─── Events ────────────────────────────────────────────────────────

sealed class ChatListEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

final class ChatListLoadRequested extends ChatListEvent {
  final bool includeArchived;
  ChatListLoadRequested({this.includeArchived = false});
  @override
  List<Object?> get props => [includeArchived];
}

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

final class ChatListPinToggled extends ChatListEvent {
  final String chatId;
  ChatListPinToggled({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatListMuteToggled extends ChatListEvent {
  final String chatId;
  ChatListMuteToggled({required this.chatId});
  @override
  List<Object?> get props => [chatId];
}

final class ChatListArchiveToggled extends ChatListEvent {
  final String chatId;
  ChatListArchiveToggled({required this.chatId});
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
  final bool showArchived;
  ChatListLoaded({required this.chats, this.searchQuery, this.showArchived = false});
  @override
  List<Object?> get props => [chats, searchQuery, showArchived];
}

final class ChatListError extends ChatListState {
  final String message;
  ChatListError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ──────────────────────────────────────────────────────────

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  final CharoRepository _repository;
  final WsClient _wsClient;
  final AppDatabase _localDb;

  ChatListBloc({
    required CharoRepository repository,
    required WsClient wsClient,
    required AppDatabase localDb,
  })  : _repository = repository,
        _wsClient = wsClient,
        _localDb = localDb,
        super(ChatListInitial()) {
    on<ChatListLoadRequested>(_onLoadRequested);
    on<ChatListSearchRequested>(_onSearchRequested);
    on<ChatListCreateRequested>(_onCreateRequested);
    on<ChatListChatUpdated>(_onChatUpdated);
    on<ChatListChatDeleted>(_onChatDeleted);
    on<ChatListPinToggled>(_onPinToggled);
    on<ChatListMuteToggled>(_onMuteToggled);
    on<ChatListArchiveToggled>(_onArchiveToggled);

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
          showArchived: event.includeArchived,
        ));
      }

      // Затем загружаем с сервера через repository
      final serverChats = await _repository.getChats(includeArchived: event.includeArchived);

      // Кэшируем в локальную БД
      for (final chat in serverChats) {
        await _localDb.insertChat(_chatItemToCompanion(chat));
      }

      emit(ChatListLoaded(chats: serverChats, showArchived: event.includeArchived));
    } on CharoApiException catch (e) {
      // Если сервер недоступен — показываем кэш
      final localChats = await _localDb.getAllChats();
      if (localChats.isNotEmpty) {
        emit(ChatListLoaded(
          chats: localChats.map(_localChatToItem).toList(),
          showArchived: event.includeArchived,
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
      final result = await _repository.search(event.query);
      // Из результатов поиска чаты — показываем в списке
      emit(ChatListLoaded(chats: result.chats, searchQuery: event.query, showArchived: currentState.showArchived));
    } catch (e) {
      // Локальный поиск по кэшу
      final localChats = await _localDb.getAllChats();
      final filtered = localChats
          .where((c) =>
              (c.title?.toLowerCase().contains(event.query.toLowerCase()) ?? false))
          .map(_localChatToItem)
          .toList();
      emit(ChatListLoaded(chats: filtered, searchQuery: event.query, showArchived: currentState.showArchived));
    }
  }

  Future<void> _onCreateRequested(
    ChatListCreateRequested event,
    Emitter<ChatListState> emit,
  ) async {
    try {
      final newChat = await _repository.createChat(event.type, event.title, null);

      final currentState = state;
      if (currentState is ChatListLoaded) {
        emit(ChatListLoaded(chats: [newChat, ...currentState.chats], showArchived: currentState.showArchived));
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

    emit(ChatListLoaded(chats: chats, searchQuery: currentState.searchQuery, showArchived: currentState.showArchived));
  }

  void _onChatDeleted(ChatListChatDeleted event, Emitter<ChatListState> emit) {
    final currentState = state;
    if (currentState is! ChatListLoaded) return;
    emit(ChatListLoaded(
      chats: currentState.chats.where((c) => c.id != event.chatId).toList(),
      searchQuery: currentState.searchQuery,
      showArchived: currentState.showArchived,
    ));
  }

  Future<void> _onPinToggled(ChatListPinToggled event, Emitter<ChatListState> emit) async {
    final currentState = state;
    if (currentState is! ChatListLoaded) return;

    final chat = currentState.chats.firstWhere((c) => c.id == event.chatId);
    try {
      await _repository.pinChat(event.chatId, !chat.isPinned);
      final updated = chat.copyWith(isPinned: !chat.isPinned);
      add(ChatListChatUpdated(chat: updated));
    } on CharoApiException catch (e) {
      logger.e('Pin toggle error: ${e.message}');
    }
  }

  Future<void> _onMuteToggled(ChatListMuteToggled event, Emitter<ChatListState> emit) async {
    final currentState = state;
    if (currentState is! ChatListLoaded) return;

    final chat = currentState.chats.firstWhere((c) => c.id == event.chatId);
    try {
      await _repository.muteChat(event.chatId, !chat.isMuted);
      final updated = chat.copyWith(isMuted: !chat.isMuted);
      add(ChatListChatUpdated(chat: updated));
    } on CharoApiException catch (e) {
      logger.e('Mute toggle error: ${e.message}');
    }
  }

  Future<void> _onArchiveToggled(ChatListArchiveToggled event, Emitter<ChatListState> emit) async {
    final currentState = state;
    if (currentState is! ChatListLoaded) return;

    final chat = currentState.chats.firstWhere((c) => c.id == event.chatId);
    try {
      await _repository.archiveChat(event.chatId, !chat.isArchived);
      final updated = chat.copyWith(isArchived: !chat.isArchived);
      if (updated.isArchived) {
        // Remove from list when archived
        add(ChatListChatDeleted(chatId: event.chatId));
      } else {
        add(ChatListChatUpdated(chat: updated));
      }
    } on CharoApiException catch (e) {
      logger.e('Archive toggle error: ${e.message}');
    }
  }

  void _onWsEvent(WsEvent event) {
    switch (event.type) {
      case 'message.new':
        final chatId = event.data['chatId'] as String?;
        if (chatId == null) return;
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
              isArchived: chat.isArchived,
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

  // Маппинг LocalChat (Drift data class) -> ChatItem
  ChatItem _localChatToItem(LocalChat c) {
    return ChatItem(
      id: c.id,
      type: c.type,
      title: c.title,
      avatarUrl: c.avatarUrl,
      lastMessage: c.lastMessage,
      lastMessageSender: c.lastMessageSender,
      lastMessageAt: c.lastMessageAt,
      unreadCount: c.unreadCount,
      isMuted: c.isMuted,
      isPinned: c.isPinned,
      isArchived: c.isArchived,
    );
  }

  // Маппинг ChatItem -> LocalChatsCompanion (Drift companion)
  LocalChatsCompanion _chatItemToCompanion(ChatItem chat) {
    return LocalChatsCompanion.insert(
      id: chat.id,
      type: Value(chat.type),
      title: Value(chat.title),
      avatarUrl: Value(chat.avatarUrl),
      lastMessage: Value(chat.lastMessage),
      lastMessageSender: Value(chat.lastMessageSender),
      lastMessageAt: Value(chat.lastMessageAt),
      unreadCount: Value(chat.unreadCount),
      isMuted: Value(chat.isMuted),
      isPinned: Value(chat.isPinned),
      isArchived: Value(chat.isArchived),
      updatedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }
}
