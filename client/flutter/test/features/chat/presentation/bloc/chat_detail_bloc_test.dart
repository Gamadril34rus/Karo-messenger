import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/features/chat/presentation/bloc/chat_detail/chat_bloc.dart';
import 'package:charo_messenger/features/chat/data/message_item.dart';

void main() {
  group('ChatDetailEvent', () {
    test('ChatDetailLoadRequested has correct props', () {
      final event = ChatDetailLoadRequested(chatId: 'chat-1');
      expect(event.props, ['chat-1']);
    });

    test('ChatDetailMessageSent has correct props', () {
      final event = ChatDetailMessageSent(
        chatId: 'chat-1',
        type: 'text',
        content: 'Hello',
      );
      expect(event.props, ['chat-1', 'text', 'Hello', null]);
    });

    test('ChatDetailTypingStarted has correct props', () {
      final event = ChatDetailTypingStarted(chatId: 'chat-1');
      expect(event.props, ['chat-1']);
    });

    test('ChatDetailTypingStopped has correct props', () {
      final event = ChatDetailTypingStopped(chatId: 'chat-1');
      expect(event.props, ['chat-1']);
    });

    test('ChatDetailReactionSent has correct props', () {
      final event = ChatDetailReactionSent(
        chatId: 'chat-1',
        messageId: 'msg-1',
        emoji: '❤️',
      );
      expect(event.props, ['chat-1', 'msg-1', '❤️']);
    });

    test('ChatDetailDisappearingSet has correct props', () {
      final event = ChatDetailDisappearingSet(
        chatId: 'chat-1',
        seconds: 3600,
      );
      expect(event.props, ['chat-1', 3600]);
    });

    test('ChatDetailReplySet has correct props', () {
      final event = ChatDetailReplySet(messageId: 'msg-1');
      expect(event.props, ['msg-1']);
    });

    test('ChatDetailEditSet has correct props', () {
      final event = ChatDetailEditSet(messageId: 'msg-1');
      expect(event.props, ['msg-1']);
    });

    test('ChatDetailMessageDeleted has correct props', () {
      final event = ChatDetailMessageDeleted(messageId: 'msg-1');
      expect(event.props, ['msg-1']);
    });

    test('ChatDetailSearchRequested has correct props', () {
      final event = ChatDetailSearchRequested(chatId: 'chat-1', query: 'hello');
      expect(event.props, ['chat-1', 'hello']);
    });
  });

  group('ChatDetailState', () {
    test('ChatDetailInitial has empty props', () {
      final state = ChatDetailInitial();
      expect(state.props, []);
    });

    test('ChatDetailLoading has empty props', () {
      final state = ChatDetailLoading();
      expect(state.props, []);
    });

    test('ChatDetailError has message in props', () {
      final state = ChatDetailError(message: 'Test error');
      expect(state.props, ['Test error']);
    });

    test('ChatDetailLoaded copyWith works correctly', () {
      final state = ChatDetailLoaded(
        chatId: 'chat-1',
        chatTitle: 'Test Chat',
        isOnline: true,
        messages: [],
      );

      final updated = state.copyWith(chatTitle: 'Updated Chat');
      expect(updated.chatId, 'chat-1');
      expect(updated.chatTitle, 'Updated Chat');
      expect(updated.isOnline, isTrue);
    });

    test('ChatDetailLoaded copyWith clearTyping works', () {
      final state = ChatDetailLoaded(
        chatId: 'chat-1',
        typingUserId: 'user-1',
      );

      final updated = state.copyWith(clearTyping: true);
      expect(updated.typingUserId, isNull);
    });

    test('ChatDetailLoaded copyWith clearReply works', () {
      final state = ChatDetailLoaded(
        chatId: 'chat-1',
        replyToId: 'msg-1',
      );

      final updated = state.copyWith(clearReply: true);
      expect(updated.replyToId, isNull);
    });

    test('ChatDetailLoaded copyWith clearEditing works', () {
      final state = ChatDetailLoaded(
        chatId: 'chat-1',
        editingId: 'msg-1',
      );

      final updated = state.copyWith(clearEditing: true);
      expect(updated.editingId, isNull);
    });

    test('ChatDetailLoaded with disappearingTimer', () {
      final state = ChatDetailLoaded(
        chatId: 'chat-1',
        disappearingTimer: 3600,
      );

      expect(state.disappearingTimer, 3600);
    });
  });

  group('MessageItem', () {
    test('creates with required fields', () {
      final item = MessageItem(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        isMe: true,
        type: 'text',
        text: 'Hello',
        sentAt: DateTime.now(),
      );

      expect(item.id, 'msg-1');
      expect(item.isMe, isTrue);
      expect(item.type, 'text');
      expect(item.text, 'Hello');
      expect(item.isDeleted, isFalse);
      expect(item.isEdited, isFalse);
      expect(item.reactions, isEmpty);
    });
  });
}
