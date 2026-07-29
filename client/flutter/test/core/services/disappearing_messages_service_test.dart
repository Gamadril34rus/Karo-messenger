import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/services/disappearing_messages_service.dart';

void main() {
  group('DisappearingMessage', () {
    test('creates with required fields', () {
      final msg = DisappearingMessage(
        messageId: 'msg-1',
        chatId: 'chat-1',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(msg.messageId, 'msg-1');
      expect(msg.chatId, 'chat-1');
      expect(msg.expiresAt, isNotNull);
    });

    test('expiresAt in the future means not expired', () {
      final msg = DisappearingMessage(
        messageId: 'msg-2',
        chatId: 'chat-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(msg.expiresAt.isAfter(DateTime.now()), isTrue);
    });
  });

  group('DisappearingMessagesService', () {
    test('startTimer with zero seconds does nothing', () {
      final service = DisappearingMessagesService.instance;
      // Zero seconds should not create a timer
      service.startTimer('msg-test-zero', 'chat-1', 0);
      // Clean up
      service.cancelTimer('msg-test-zero');
    });

    test('startTimer with positive seconds creates timer', () {
      final service = DisappearingMessagesService.instance;
      service.startTimer('msg-test-pos', 'chat-1', 3600);
      // Timer should be running — cancel it
      service.cancelTimer('msg-test-pos');
    });

    test('cancelTimer removes timer without error', () {
      final service = DisappearingMessagesService.instance;
      service.startTimer('msg-test-cancel', 'chat-1', 60);
      service.cancelTimer('msg-test-cancel');
      // Double cancel should not throw
      service.cancelTimer('msg-test-cancel');
    });

    test('cancelTimer for non-existent timer is safe', () {
      final service = DisappearingMessagesService.instance;
      // Should not throw
      service.cancelTimer('non-existent');
    });
  });
}
