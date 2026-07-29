import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/services/offline_sync_service.dart';

void main() {
  group('OfflineQueueItem', () {
    test('creates with default values', () {
      final item = OfflineQueueItem(
        id: 'test',
        chatId: 'chat',
        type: 'text',
        content: {'text': 'hi'},
      );

      expect(item.id, 'test');
      expect(item.status, 'pending');
      expect(item.retryCount, 0);
      expect(item.createdAt, isNotNull);
    });

    test('accepts custom createdAt', () {
      final date = DateTime(2024, 1, 1);
      final item = OfflineQueueItem(
        id: 'test',
        chatId: 'chat',
        type: 'text',
        content: {},
        createdAt: date,
      );

      expect(item.createdAt, date);
    });

    test('accepts custom retryCount and status', () {
      final item = OfflineQueueItem(
        id: 'test',
        chatId: 'chat',
        type: 'text',
        content: {},
        retryCount: 3,
        status: 'failed',
      );

      expect(item.retryCount, 3);
      expect(item.status, 'failed');
    });

    test('accepts replyTo and tempId', () {
      final item = OfflineQueueItem(
        id: 'test',
        chatId: 'chat',
        type: 'text',
        content: {},
        replyTo: 'msg-1',
        tempId: 'temp-1',
      );

      expect(item.replyTo, 'msg-1');
      expect(item.tempId, 'temp-1');
    });
  });

  group('OfflineSyncStatus', () {
    test('creates with required fields', () {
      const status = OfflineSyncStatus(
        isOnline: true,
        pendingCount: 3,
        failedCount: 1,
        isSyncing: false,
      );

      expect(status.isOnline, isTrue);
      expect(status.pendingCount, 3);
      expect(status.failedCount, 1);
      expect(status.isSyncing, isFalse);
      expect(status.sendingItem, isNull);
    });

    test('accepts sendingItem', () {
      final item = OfflineQueueItem(
        id: 'test',
        chatId: 'chat',
        type: 'text',
        content: {},
      );

      final status = OfflineSyncStatus(
        isOnline: true,
        pendingCount: 0,
        failedCount: 0,
        isSyncing: true,
        sendingItem: item,
      );

      expect(status.sendingItem, isNotNull);
      expect(status.sendingItem!.id, 'test');
    });
  });

  group('OfflineSyncService', () {
    test('initial state is online with no pending items', () {
      final service = OfflineSyncService.instance;
      expect(service.isOnline, isTrue);
      expect(service.pendingCount, equals(0));
      expect(service.failedCount, equals(0));
    });

    test('setOnline changes state', () {
      final service = OfflineSyncService.instance;
      service.setOnline(false);
      expect(service.isOnline, isFalse);
      service.setOnline(true);
      expect(service.isOnline, isTrue);
    });

    test('enqueue adds item to queue when offline', () {
      final service = OfflineSyncService.instance;
      service.setOnline(false);

      final item = OfflineQueueItem(
        id: 'test-enqueue',
        chatId: 'chat-1',
        type: 'text',
        content: {'text': 'Hello'},
      );

      service.enqueue(item);
      expect(service.pendingCount, equals(1));

      // Clean up
      service.setOnline(true);
    });

    test('markDelivered removes item from queue', () {
      final service = OfflineSyncService.instance;
      service.setOnline(false);

      final item = OfflineQueueItem(
        id: 'test-deliver',
        chatId: 'chat-1',
        type: 'text',
        content: {'text': 'Hello'},
        tempId: 'temp-deliver',
      );

      service.enqueue(item);
      expect(service.pendingCount, equals(1));

      service.markDelivered('temp-deliver');
      expect(service.pendingCount, equals(0));

      // Clean up
      service.setOnline(true);
    });

    test('multiple enqueue adds multiple items', () {
      final service = OfflineSyncService.instance;
      service.setOnline(false);

      for (int i = 0; i < 5; i++) {
        service.enqueue(OfflineQueueItem(
          id: 'test-multi-$i',
          chatId: 'chat-1',
          type: 'text',
          content: {'text': 'Message $i'},
        ));
      }

      expect(service.pendingCount, equals(5));

      // Clean up
      service.setOnline(true);
    });
  });
}
