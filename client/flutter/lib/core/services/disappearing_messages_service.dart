import 'dart:async';

import '../storage/local_db.dart';
import '../utils/logger.dart';

/// ─── Disappearing Messages Service ──────────────────────────────
/// Клиентская логика автоудаления сообщений по таймеру.
/// Запускает таймер для каждого сообщения с disappearing-настройкой.
/// При истечении — удаляет из локальной БД и помечает на сервере.

class DisappearingMessagesService {
  static DisappearingMessagesService? _instance;
  static DisappearingMessagesService get instance => _instance ??= DisappearingMessagesService._();

  DisappearingMessagesService._();

  final Map<String, Timer> _timers = {};
  AppDatabase? _localDb;

  /// Инициализация с локальной БД
  void initialize(AppDatabase localDb) {
    _localDb = localDb;
  }

  /// Запустить таймер исчезновения для сообщения
  void startTimer(String messageId, String chatId, int seconds) {
    // Отменить существующий таймер если есть
    cancelTimer(messageId);

    if (seconds <= 0) return;

    final timer = Timer(Duration(seconds: seconds), () async {
      logger.i('⏱ Disappearing message expired: $messageId');
      await _deleteMessage(messageId, chatId);
      _timers.remove(messageId);
    });

    _timers[messageId] = timer;
    logger.i('⏱ Disappearing timer set: ${seconds}s for message $messageId');
  }

  /// Отменить таймер для сообщения
  void cancelTimer(String messageId) {
    _timers[messageId]?.cancel();
    _timers.remove(messageId);
  }

  /// Удалить сообщение при истечении таймера
  Future<void> _deleteMessage(String messageId, String chatId) async {
    // Удалить из локальной БД
    if (_localDb != null) {
      try {
        await (_localDb!.delete(_localDb!.localMessages)
              ..where((t) => t.id.equals(messageId)))
            .go();
        logger.i('⏱ Disappearing message deleted from local DB: $messageId');
      } catch (e) {
        logger.e('⏱ Failed to delete disappearing message from local DB: $e');
      }
    }

    // Пометить на сервере (через WS)
    // В реальном коде: wsClient.send('message.delete', {'messageId': messageId, 'disappearing': true});
  }

  /// Восстановить таймеры при загрузке чата
  /// (если приложение было закрыто — нужно проверить оставшееся время)
  void restoreTimers(List<DisappearingMessage> messages) {
    for (final msg in messages) {
      final remaining = msg.expiresAt.difference(DateTime.now());
      if (remaining.isNegative) {
        // Уже истекло — удалить немедленно
        _deleteMessage(msg.messageId, msg.chatId);
      } else {
        startTimer(msg.messageId, msg.chatId, remaining.inSeconds);
      }
    }
  }

  /// Очистить все таймеры
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

class DisappearingMessage {
  final String messageId;
  final String chatId;
  final DateTime expiresAt;

  const DisappearingMessage({
    required this.messageId,
    required this.chatId,
    required this.expiresAt,
  });
}
