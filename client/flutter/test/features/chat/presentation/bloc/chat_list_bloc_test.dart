import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:charo_messenger/core/network/api_client.dart';
import 'package:charo_messenger/core/network/ws_client.dart';
import 'package:charo_messenger/core/storage/local_db.dart';
import 'package:charo_messenger/features/chat/presentation/bloc/chat_list/chat_bloc.dart';
import 'package:charo_messenger/features/chat/data/chat_item.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockWsClient extends Mock implements WsClient {}
class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  group('ChatListBloc', () {
    late MockApiClient mockApiClient;
    late MockWsClient mockWsClient;
    late MockAppDatabase mockLocalDb;

    setUp(() {
      mockApiClient = MockApiClient();
      mockWsClient = MockWsClient();
      mockLocalDb = MockAppDatabase();
    });

    test('initial state is ChatListInitial', () {
      final bloc = ChatListBloc(
        apiClient: mockApiClient,
        wsClient: mockWsClient,
        localDb: mockLocalDb,
      );
      expect(bloc.state, equals(ChatListInitial()));
      bloc.close();
    });

    test('ChatListPinToggled event has chatId in props', () {
      final event = ChatListPinToggled(chatId: 'test-chat-id');
      expect(event.props, contains('test-chat-id'));
    });

    test('ChatListMuteToggled event has chatId in props', () {
      final event = ChatListMuteToggled(chatId: 'test-chat-id');
      expect(event.props, contains('test-chat-id'));
    });

    test('ChatListArchiveToggled event has chatId in props', () {
      final event = ChatListArchiveToggled(chatId: 'test-chat-id');
      expect(event.props, contains('test-chat-id'));
    });

    test('ChatListLoadRequested includes includeArchived in props', () {
      final event = ChatListLoadRequested(includeArchived: true);
      expect(event.props, contains(true));
    });

    test('ChatItem has isArchived field', () {
      final chat = ChatItem(
        id: 'test-id',
        isArchived: true,
        isPinned: true,
        isMuted: true,
      );
      expect(chat.isArchived, isTrue);
      expect(chat.isPinned, isTrue);
      expect(chat.isMuted, isTrue);
    });

    test('ChatItem copyWith works', () {
      final chat = ChatItem(id: 'test-id');
      final copied = chat.copyWith(isArchived: true, isPinned: true, title: 'Test');
      expect(copied.isArchived, isTrue);
      expect(copied.isPinned, isTrue);
      expect(copied.title, 'Test');
      expect(copied.id, 'test-id');
    });

    test('ChatListLoaded state has showArchived field', () {
      final state = ChatListLoaded(chats: [], showArchived: true);
      expect(state.showArchived, isTrue);
    });
  });
}
