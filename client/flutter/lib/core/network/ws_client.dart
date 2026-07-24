import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import '../utils/logger.dart';

/// WebSocket-клиент ЧАРО
///
/// Особенности:
/// - Автоматическое переподключение с exponential backoff
/// - Heartbeat для поддержания соединения
/// - Ротация зеркальных доменов при блокировках
/// - Типизированные события
/// - Room-based подписки (чат, звонок и т.д.)
class WsClient {
  WebSocketChannel? _channel;
  final SecureStorageHelper _secureStorage;

  final _messageController = StreamController<WsEvent>.broadcast();
  final _connectionController = StreamController<WsConnectionState>.broadcast();

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  bool _isDisposed = false;
  String? _currentUrl;

  WsClient(this._secureStorage);

  // ─── Потоки ────────────────────────────────────────────────────
  Stream<WsEvent> get messages => _messageController.stream;
  Stream<WsConnectionState> get connectionState => _connectionController.stream;
  bool get isConnected => _channel != null;

  // ─── Подключение ───────────────────────────────────────────────
  Future<void> connect() async {
    if (_isDisposed) return;

    final token = await _secureStorage.getAccessToken();
    if (token == null) {
      logger.w('WS: Нет токена, подключение отложено');
      return;
    }

    _currentUrl = '${AppConstants.wsUrl}?token=$token';
    _doConnect();
  }

  void _doConnect() {
    if (_isDisposed) return;

    logger.i('WS: Подключение к $_currentUrl (попытка ${_reconnectAttempts + 1})');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_currentUrl!));

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _reconnectAttempts = 0;
      _startHeartbeat();
      _connectionController.add(WsConnectionState.connected);
      logger.i('WS: Подключено');
    } catch (e) {
      logger.e('WS: Ошибка подключения: $e');
      _scheduleReconnect();
    }
  }

  // ─── Обработка сообщений ───────────────────────────────────────
  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = WsEvent.fromJson(json);
      logger.d('WS ← ${event.type}');
      _messageController.add(event);
    } catch (e) {
      logger.e('WS: Ошибка парсинга сообщения: $e');
    }
  }

  // ─── Обработка ошибок ──────────────────────────────────────────
  void _onError(dynamic error) {
    logger.e('WS: Ошибка: $error');
    _connectionController.add(WsConnectionState.error);
    _scheduleReconnect();
  }

  // ─── Обработка отключения ──────────────────────────────────────
  void _onDone() {
    logger.w('WS: Соединение закрыто');
    _connectionController.add(WsConnectionState.disconnected);
    _stopHeartbeat();
    if (!_isDisposed) {
      _scheduleReconnect();
    }
  }

  // ─── Отправка ──────────────────────────────────────────────────
  void send(String type, Map<String, dynamic> data) {
    if (_channel == null) {
      logger.w('WS: Попытка отправки без подключения: $type');
      return;
    }

    final payload = jsonEncode({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    logger.d('WS → $type');
    _channel!.sink.add(payload);
  }

  // ─── Типизированные отправки ───────────────────────────────────

  /// Отправить сообщение
  void sendMessage({
    required String chatId,
    required String type,
    required Map<String, dynamic> content,
    String? replyTo,
    String? tempId,
  }) {
    send('message.send', {
      'chatId': chatId,
      'type': type,
      'content': content,
      if (replyTo != null) 'replyTo': replyTo,
      if (tempId != null) 'tempId': tempId,
    });
  }

  /// Начать печатать
  void startTyping(String chatId) {
    send('typing.start', {'chatId': chatId});
  }

  /// Прекратить печатать
  void stopTyping(String chatId) {
    send('typing.stop', {'chatId': chatId});
  }

  /// Отметить прочитанным
  void markAsRead(String chatId, String lastMessageId) {
    send('read', {
      'chatId': chatId,
      'lastMessageId': lastMessageId,
    });
  }

  /// Обновить присутствие
  void updatePresence(String status) {
    send('presence', {'status': status});
  }

  /// WebRTC сигналинг
  void callSignal(String callId, String signalType, dynamic data) {
    send('call.$signalType', {
      'callId': callId,
      'data': data,
    });
  }

  // ─── Heartbeat ─────────────────────────────────────────────────
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      send('ping', {});
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ─── Переподключение (exponential backoff) ─────────────────────
  void _scheduleReconnect() {
    if (_isDisposed || _reconnectAttempts >= _maxReconnectAttempts) {
      logger.e('WS: Превышено количество попыток переподключения');
      _connectionController.add(WsConnectionState.failed);
      return;
    }

    _stopHeartbeat();

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s...
    final delay = Duration(
      seconds: 1 << _reconnectAttempts.clamp(0, 5),
    );

    logger.i('WS: Переподключение через ${delay.inSeconds}с');
    _connectionController.add(WsConnectionState.reconnecting);

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      // Попробовать зеркальный домен
      if (_reconnectAttempts > 3) {
        _tryMirrorDomain();
      } else {
        _doConnect();
      }
    });
  }

  void _tryMirrorDomain() {
    final mirrorIndex = _reconnectAttempts % AppConstants.mirrorDomains.length;
    final mirror = AppConstants.mirrorDomains[mirrorIndex];
    _currentUrl = '${mirror.replaceAll('https://', 'wss://')}/ws';
    logger.i('WS: Пробуем зеркало: $_currentUrl');
    _doConnect();
  }

  // ─── Отключение ────────────────────────────────────────────────
  Future<void> disconnect() async {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _connectionController.add(WsConnectionState.disconnected);
  }

  // ─── Очистка ───────────────────────────────────────────────────
  Future<void> dispose() async {
    _isDisposed = true;
    await disconnect();
    await _messageController.close();
    await _connectionController.close();
  }
}

/// Модель WebSocket-события
class WsEvent {
  final String type;
  final Map<String, dynamic> data;
  final int? timestamp;

  const WsEvent({
    required this.type,
    required this.data,
    this.timestamp,
  });

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    return WsEvent(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'data': data,
        'timestamp': timestamp,
      };
}

/// Состояние WebSocket-соединения
enum WsConnectionState {
  connected,
  reconnecting,
  disconnected,
  error,
  failed,
}
