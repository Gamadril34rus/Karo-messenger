// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';

import '../network/ws_client.dart';
import '../storage/local_db.dart';
import '../utils/logger.dart';

/// ─── Presence Service ────────────────────────────────────────────
/// Отслеживание онлайн-статуса и «был(а) в сети».
/// Слушает WS presence events и обновляет локальный кэш.

class PresenceService {
  static PresenceService? _instance;
  static PresenceService get instance => _instance ??= PresenceService._();

  PresenceService._();

  final Map<String, UserPresence> _presenceCache = {};
  final _presenceController = StreamController<Map<String, UserPresence>>.broadcast();
  StreamSubscription? _wsSubscription;

  /// Стрим изменений присутствия
  Stream<Map<String, UserPresence>> get presenceStream => _presenceController.stream;

  /// Получить статус пользователя
  UserPresence? getPresence(String userId) => _presenceCache[userId];

  /// Подписка на WS events
  void initialize(WsClient wsClient) {
    _wsSubscription?.cancel();
    _wsSubscription = wsClient.messages.listen((event) {
      if (event.type == 'presence') {
        _handlePresenceEvent(event.data);
      }
    });
    logger.i('👁 PresenceService initialized');
  }

  void _handlePresenceEvent(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    final userId = data['userId'] as String? ?? '';
    final status = data['status'] as String? ?? 'offline';
    final lastSeen = data['last_seen'] as String?;

    if (userId.isEmpty) return;

    _presenceCache[userId] = UserPresence(
      userId: userId,
      status: status,
      lastSeen: lastSeen != null ? DateTime.tryParse(lastSeen) : null,
    );

    _presenceController.add(Map.from(_presenceCache));
  }

  /// Форматирование «был(а) в сети»
  static String formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'давно';

    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 5) return 'недавно';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';

    return '${lastSeen.day}.${lastSeen.month.toString().padLeft(2, '0')}.${lastSeen.year}';
  }

  void dispose() {
    _wsSubscription?.cancel();
    _presenceController.close();
  }
}

class UserPresence {
  final String userId;
  final String status; // 'online', 'offline', 'away', 'dnd'
  final DateTime? lastSeen;

  const UserPresence({
    required this.userId,
    required this.status,
    this.lastSeen,
  });

  bool get isOnline => status == 'online' || status == 'away';
}
