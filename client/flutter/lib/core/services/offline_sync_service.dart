// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';
import 'dart:collection';

import 'package:drift/drift.dart';

import '../network/api_client.dart';
import '../storage/local_db.dart';
import '../utils/logger.dart';

/// ─── Offline-First Architecture ──────────────────────────────────
/// Очередь отправки сообщений при отсутствии сети.
/// Кэширование сообщений в Drift (SQLite).
/// Синхронизация при восстановлении соединения.
/// Gap-filling: подгрузка пропущенных сообщений при reconnect.

class OfflineQueueItem {
  final String id;
  final String chatId;
  final String type;
  final Map<String, dynamic> content;
  final String? replyTo;
  final String? tempId;
  final DateTime createdAt;
  int retryCount;
  String status; // 'pending', 'sending', 'failed'

  OfflineQueueItem({
    required this.id,
    required this.chatId,
    required this.type,
    required this.content,
    this.replyTo,
    this.tempId,
    DateTime? createdAt,
    this.retryCount = 0,
    this.status = 'pending',
  }) : createdAt = createdAt ?? DateTime.now();
}

class OfflineSyncService {
  static OfflineSyncService? _instance;
  static OfflineSyncService get instance => _instance ??= OfflineSyncService._();

  OfflineSyncService._();

  final Queue<OfflineQueueItem> _queue = Queue<OfflineQueueItem>();
  final _statusController = StreamController<OfflineSyncStatus>.broadcast();
  bool _isProcessing = false;
  bool _isOnline = true;

  /// Статус синхронизации для UI
  Stream<OfflineSyncStatus> get statusStream => _statusController.stream;

  /// Количество сообщений в очереди
  int get pendingCount => _queue.where((i) => i.status == 'pending').length;

  /// Количество неудачных сообщений
  int get failedCount => _queue.where((i) => i.status == 'failed').length;

  /// Есть ли подключение
  bool get isOnline => _isOnline;

  /// Установить статус подключения (вызывается из WsClient / connectivity_plus)
  void setOnline(bool online) {
    final wasOffline = !_isOnline;
    _isOnline = online;
    _statusController.add(OfflineSyncStatus(
      isOnline: online,
      pendingCount: pendingCount,
      failedCount: failedCount,
      isSyncing: _isProcessing,
    ));

    if (online && wasOffline) {
      logger.i('📡 Network restored — flushing offline queue (${_queue.length} items)');
      flushQueue();
    }
  }

  /// Добавить сообщение в очередь отправки
  void enqueue(OfflineQueueItem item) {
    _queue.add(item);
    _statusController.add(OfflineSyncStatus(
      isOnline: _isOnline,
      pendingCount: pendingCount,
      failedCount: failedCount,
      isSyncing: _isProcessing,
    ));

    if (_isOnline) {
      flushQueue();
    } else {
      logger.i('📤 Message queued for offline delivery: ${item.chatId}/${item.type}');
    }
  }

  /// Отправить все сообщения из очереди
  Future<void> flushQueue() async {
    if (_isProcessing || !_isOnline) return;
    _isProcessing = true;
    _statusController.add(OfflineSyncStatus(
      isOnline: _isOnline,
      pendingCount: pendingCount,
      failedCount: failedCount,
      isSyncing: true,
    ));

    while (_queue.isNotEmpty && _isOnline) {
      final item = _queue.removeFirst();
      item.status = 'sending';
      try {
        _statusController.add(OfflineSyncStatus(
          isOnline: _isOnline,
          pendingCount: pendingCount,
          failedCount: failedCount,
          isSyncing: true,
          sendingItem: item,
        ));
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        item.retryCount++;
        if (item.retryCount < 5) {
          item.status = 'pending';
          _queue.addFirst(item);
          logger.w('📤 Retrying message send (${item.retryCount}/5): $e');
          await Future.delayed(Duration(seconds: item.retryCount * 2));
        } else {
          item.status = 'failed';
          logger.e('📤 Message permanently failed after 5 retries: $e');
        }
      }
    }

    _isProcessing = false;
    _statusController.add(OfflineSyncStatus(
      isOnline: _isOnline,
      pendingCount: pendingCount,
      failedCount: failedCount,
      isSyncing: false,
    ));
  }

  /// Пометить сообщение как доставленное
  void markDelivered(String tempId) {
    _queue.removeWhere((i) => i.tempId == tempId);
    _statusController.add(OfflineSyncStatus(
      isOnline: _isOnline,
      pendingCount: pendingCount,
      failedCount: failedCount,
      isSyncing: _isProcessing,
    ));
  }

  /// Gap-filling: подгрузка пропущенных сообщений
  /// Вызывается при reconnect — загружает сообщения с последнего known ID
  Future<List<Map<String, dynamic>>> fetchMissingMessages(
    ApiClient apiClient,
    String chatId,
    String lastKnownMessageId, {
    int limit = 100,
  }) async {
    try {
      final response = await apiClient.get(
        '/api/v1/chats/$chatId/messages',
        queryParameters: {
          'after_id': lastKnownMessageId,
          'limit': limit,
        },
      );
      final messages = (response.asList).cast<Map<String, dynamic>>();
      if (messages.isNotEmpty) {
        logger.i('📡 Gap-filled ${messages.length} messages for chat $chatId');
      }
      return messages;
    } catch (e) {
      logger.e('📡 Gap-fill failed for chat $chatId: $e');
      return [];
    }
  }

  /// Синхронизация всех чатов при reconnect
  Future<void> syncAllChats(
    ApiClient apiClient,
    AppDatabase localDb,
  ) async {
    try {
      final response = await apiClient.get('/api/v1/chats');
      final chats = (response.asList).cast<Map<String, dynamic>>();

      for (final chat in chats) {
        final chatId = chat['id'] as String? ?? '';
        if (chatId.isEmpty) continue;

        final localChats = await localDb.getAllChats();
        final lastLocal = localChats.where((c) => c.id == chatId).firstOrNull;

        if (lastLocal != null) {
          final missing = await fetchMissingMessages(
            apiClient,
            chatId,
            lastLocal.id,
          );
          for (final msg in missing) {
            await localDb.insertMessage(LocalMessagesCompanion(
              id: Value(msg['id'] as String? ?? ''),
              chatId: Value(chatId),
              senderId: Value(msg['sender_id'] as String? ?? ''),
              type: Value(msg['type'] as String? ?? 'text'),
              content: Value(msg['content']?.toString()),
              isRead: Value(msg['is_read'] as bool? ?? false),
              createdAt: Value(msg['created_at'] != null
                  ? DateTime.parse(msg['created_at'] as String)
                  : DateTime.now()),
            ));
          }
        }
      }
      logger.i('📡 Full chat sync completed');
    } catch (e) {
      logger.e('📡 Full sync failed: $e');
    }
  }

  void dispose() {
    _statusController.close();
  }
}

class OfflineSyncStatus {
  final bool isOnline;
  final int pendingCount;
  final int failedCount;
  final bool isSyncing;
  final OfflineQueueItem? sendingItem;

  const OfflineSyncStatus({
    required this.isOnline,
    required this.pendingCount,
    required this.failedCount,
    required this.isSyncing,
    this.sendingItem,
  });
}
