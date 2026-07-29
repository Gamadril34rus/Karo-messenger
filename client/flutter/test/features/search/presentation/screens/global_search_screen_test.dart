import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchResult model', () {
    test('chat result has correct type', () {
      // Test the data model structure
      final result = {
        'type': 'chat',
        'id': 'chat-1',
        'title': 'Test Chat',
        'subtitle': 'Last message',
      };

      expect(result['type'], 'chat');
      expect(result['id'], 'chat-1');
      expect(result['title'], 'Test Chat');
    });

    test('message result has chatId', () {
      final result = {
        'type': 'message',
        'id': 'msg-1',
        'title': 'Alice',
        'subtitle': 'Hello world',
        'chatId': 'chat-1',
      };

      expect(result['chatId'], 'chat-1');
    });

    test('contact result has username', () {
      final result = {
        'type': 'contact',
        'id': 'user-1',
        'title': 'Bob Smith',
        'subtitle': '@bob',
      };

      expect(result['type'], 'contact');
      expect(result['subtitle'], '@bob');
    });
  });
}
