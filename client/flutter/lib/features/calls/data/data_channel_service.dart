// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/utils/logger.dart';

/// DataChannelService — сервис для WebRTC DataChannel
///
/// DataChannel в звонках ЧАРО используется для:
/// - Реакции (emoji мгновенно, без задержки)
/// - Chat messages (текст параллельно с видео/аудио)
/// - File chunks (передача файлов прямо в звонке)
/// - Metadata (typing indicators, read receipts)
///
/// Настройки DataChannel:
/// - ordered: true (гарантия порядка)
/// - maxRetransmits: 3 (ограниченная повторная отправка)
/// - Protocol: 'charo-chat-v1'
class DataChannelService {
  RTCDataChannel? _dataChannel;
  RTCPeerConnection? _peerConnection;

  final _messageController = StreamController<DataChannelMessage>.broadcast();
  final _stateController = StreamController<DataChannelState>.broadcast();

  Stream<DataChannelMessage> get onMessage => _messageController.stream;
  Stream<DataChannelState> get stateStream => _stateController.stream;
  DataChannelState get currentState => _mapChannelState(_dataChannel?.state);

  bool _disposed = false;

  DataChannelService();

  /// Создание DataChannel (для инициатора звонка)
  void createDataChannel(RTCPeerConnection peerConnection) {
    _peerConnection = peerConnection;

    final config = RTCDataChannelInit()
      ..ordered = true
      ..maxRetransmits = 3
      ..protocol = 'charo-chat-v1';

    _dataChannel = peerConnection.createDataChannel('charo-chat', config);
    _setupDataChannelHandlers();

    logger.i('📡 DataChannel "charo-chat" created (ordered=true, maxRetransmits=3)');
  }

  /// Подключение к существующему DataChannel (для отвечающего)
  void connectToDataChannel(RTCDataChannel dataChannel) {
    _dataChannel = dataChannel;
    _setupDataChannelHandlers();
    logger.i('📡 DataChannel "charo-chat" connected');
  }

  void _setupDataChannelHandlers() {
    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      if (_disposed) return;

      final dcMessage = DataChannelMessage.deserialize(message.text);
      _messageController.add(dcMessage);

      logger.d('📡 DataChannel received: ${dcMessage.type} from ${dcMessage.senderId}');
    };

    _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
      if (_disposed) return;

      final mappedState = _mapChannelState(state);
      _stateController.add(mappedState);

      logger.d('📡 DataChannel state: ${mappedState.value}');
    };
  }

  /// Отправка сообщения через DataChannel
  bool sendMessage(DataChannelMessage message) {
    if (_dataChannel == null || currentState != DataChannelState.open) {
      logger.w('📡 DataChannel not open — cannot send');
      return false;
    }

    final serialized = message.serialize();

    if (serialized.length > 65535) {
      // DataChannel max message size — разбить на chunks
      logger.w('📡 Message too large (${serialized.length} bytes) — splitting');
      return _sendChunkedMessage(message);
    }

    _dataChannel!.send(RTCDataChannelMessage(serialized));
    logger.d('📡 DataChannel sent: ${message.type}');
    return true;
  }

  /// Отправка реакции через DataChannel (мгновенная)
  bool sendReaction({
    required String chatId,
    required String messageId,
    required String emoji,
    String senderId = '',
  }) {
    return sendMessage(DataChannelMessage(
      type: DataChannelMessageType.reaction,
      chatId: chatId,
      senderId: senderId,
      data: {
        'message_id': messageId,
        'emoji': emoji,
      },
      timestamp: DateTime.now(),
    ));
  }

  /// Отправка chat message через DataChannel
  bool sendChatMessage({
    required String chatId,
    required String text,
    String senderId = '',
  }) {
    return sendMessage(DataChannelMessage(
      type: DataChannelMessageType.chat,
      chatId: chatId,
      senderId: senderId,
      data: {
        'text': text,
      },
      timestamp: DateTime.now(),
    ));
  }

  /// Отправка file chunk через DataChannel
  bool sendFileChunk({
    required String chatId,
    required String fileId,
    required int chunkIndex,
    required String chunkData,
    required int totalChunks,
    String senderId = '',
  }) {
    return sendMessage(DataChannelMessage(
      type: DataChannelMessageType.fileChunk,
      chatId: chatId,
      senderId: senderId,
      data: {
        'file_id': fileId,
        'chunk_index': chunkIndex,
        'chunk_data': chunkData,
        'total_chunks': totalChunks,
      },
      timestamp: DateTime.now(),
    ));
  }

  /// Отправка metadata через DataChannel
  bool sendMetadata({
    required String chatId,
    required String action,
    Map<String, dynamic>? payload,
    String senderId = '',
  }) {
    return sendMessage(DataChannelMessage(
      type: DataChannelMessageType.metadata,
      chatId: chatId,
      senderId: senderId,
      data: {
        'action': action,
        ...(payload ?? {}),
      },
      timestamp: DateTime.now(),
    ));
  }

  bool _sendChunkedMessage(DataChannelMessage message) {
    final serialized = message.serialize();
    final chunkSize = 16384; // 16KB chunks
    final totalChunks = (serialized.length / chunkSize).ceil();

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = start + chunkSize;
      final chunk = serialized.substring(start, end.clamp(0, serialized.length));

      final chunkMessage = DataChannelMessage(
        type: DataChannelMessageType.fileChunk,
        chatId: message.chatId,
        senderId: message.senderId,
        data: {
          'message_type': message.type.value,
          'chunk_index': i,
          'chunk_data': chunk,
          'total_chunks': totalChunks,
        },
        timestamp: DateTime.now(),
      );

      if (!sendMessage(chunkMessage)) return false;
    }

    return true;
  }

  DataChannelState _mapChannelState(RTCDataChannelState? state) {
    switch (state) {
      case RTCDataChannelState.RTCDataChannelOpen:
        return DataChannelState.open;
      case RTCDataChannelState.RTCDataChannelClosing:
        return DataChannelState.closing;
      case RTCDataChannelState.RTCDataChannelClosed:
        return DataChannelState.closed;
      case RTCDataChannelState.RTCDataChannelConnecting:
        return DataChannelState.connecting;
      default:
        return DataChannelState.closed;
    }
  }

  void dispose() {
    _disposed = true;
    _dataChannel?.close();
    _messageController.close();
    _stateController.close();
  }
}

/// DataChannelMessage — модель сообщения DataChannel
class DataChannelMessage {
  final DataChannelMessageType type;
  final String chatId;
  final String senderId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  DataChannelMessage({
    required this.type,
    required this.chatId,
    required this.senderId,
    required this.data,
    required this.timestamp,
  });

  String serialize() {
    return jsonEncode(toJson());
  }

  factory DataChannelMessage.deserialize(String serialized) {
    final json = jsonDecode(serialized) as Map<String, dynamic>;
    return DataChannelMessage.fromJson(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'chat_id': chatId,
      'sender_id': senderId,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DataChannelMessage.fromJson(Map<String, dynamic> json) {
    return DataChannelMessage(
      type: DataChannelMessageType.fromString(json['type'] as String? ?? 'chat'),
      chatId: json['chat_id'] as String? ?? json['chatId'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? json['senderId'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

/// DataChannelMessageType — типы сообщений DataChannel
enum DataChannelMessageType {
  reaction('reaction'),      // Emoji-реакция
  chat('chat'),              // Текстовое сообщение
  fileChunk('file_chunk'),   // Часть файла
  metadata('metadata');      // Typing, read receipts и т.д.

  final String value;

  const DataChannelMessageType(this.value);

  static DataChannelMessageType fromString(String value) {
    switch (value) {
      case 'reaction':
        return DataChannelMessageType.reaction;
      case 'chat':
        return DataChannelMessageType.chat;
      case 'file_chunk':
        return DataChannelMessageType.fileChunk;
      case 'metadata':
        return DataChannelMessageType.metadata;
      default:
        return DataChannelMessageType.chat;
    }
  }
}

/// DataChannelState — состояние DataChannel
enum DataChannelState {
  connecting('connecting'),
  open('open'),
  closing('closing'),
  closed('closed');

  final String value;

  const DataChannelState(this.value);
}
