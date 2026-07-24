import 'dart:async';

import '../../../core/e2ee/e2ee_manager.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/utils/logger.dart';
import 'data_channel_service.dart';

/// SecureDataChannel — E2EE-обёртка над DataChannelService
///
/// Все сообщения через DataChannel шифруются E2EE перед отправкой
/// и расшифровываются при получении.
class SecureDataChannel {
  final DataChannelService _dataChannel;
  final E2EEKeyManager _e2ee;

  final _secureMessageController = StreamController<SecureDataChannelMessage>.broadcast();

  Stream<SecureDataChannelMessage> get onSecureMessage => _secureMessageController.stream;

  bool _disposed = false;

  SecureDataChannel({
    required DataChannelService dataChannel,
    E2EEKeyManager? e2ee,
  }) : _dataChannel = dataChannel,
       _e2ee = e2ee ?? E2EEKeyManager.instance {
    _setupSecureListener();
  }

  void _setupSecureListener() {
    _dataChannel.onMessage.listen((message) async {
      if (_disposed) return;

      if (message.data.containsKey('e2ee_payload')) {
        await _decryptAndForward(message);
      } else {
        // Открытые сообщения (metadata — typing) не шифруются
        if (message.type == DataChannelMessageType.metadata) {
          _secureMessageController.add(SecureDataChannelMessage(
            type: message.type,
            chatId: message.chatId,
            senderId: message.senderId,
            data: message.data,
            isEncrypted: false,
            timestamp: message.timestamp,
          ));
        }
      }
    });
  }

  Future<void> _decryptAndForward(DataChannelMessage message) async {
    final e2eePayload = message.data['e2ee_payload'] as String;
    final senderId = message.senderId;

    try {
      final decryptedData = await _e2ee.decryptWithRecovery(senderId, e2eePayload);
      if (decryptedData == null) {
        logger.w('🚨 E2EE decryption failed for DataChannel message from $senderId');
        return;
      }

      final secureMessage = SecureDataChannelMessage(
        type: message.type,
        chatId: message.chatId,
        senderId: senderId,
        data: decryptedData is Map<String, dynamic> ? decryptedData : {'text': decryptedData},
        isEncrypted: true,
        timestamp: message.timestamp,
      );

      _secureMessageController.add(secureMessage);
      logger.d('🔐 SecureDataChannel: decrypted message from $senderId');
    } catch (e) {
      logger.e('🚨 SecureDataChannel decryption error: $e');
      final error = AppError.fromE2eeError('DataChannel decryption failed', e);
      logger.e('🚨 ${error.toLog()}');
    }
  }

  bool sendSecureMessage({
    required String recipientId,
    required DataChannelMessageType type,
    required String chatId,
    required Map<String, dynamic> data,
    String senderId = '',
  }) async {
    final encryptedPayload = await _e2ee.encryptForDataChannel(recipientId, {
      'type': type.value,
      'data': data,
    });

    final message = DataChannelMessage(
      type: type,
      chatId: chatId,
      senderId: senderId,
      data: {
        'e2ee_payload': encryptedPayload,
      },
      timestamp: DateTime.now(),
    );

    final sent = _dataChannel.sendMessage(message);
    if (sent) {
      logger.d('🔐 SecureDataChannel: encrypted message sent to $recipientId');
    }
    return sent;
  }

  bool sendSecureReaction({
    required String recipientId,
    required String chatId,
    required String messageId,
    required String emoji,
    String senderId = '',
  }) async {
    return await sendSecureMessage(
      recipientId: recipientId,
      type: DataChannelMessageType.reaction,
      chatId: chatId,
      data: {'message_id': messageId, 'emoji': emoji},
      senderId: senderId,
    );
  }

  bool sendSecureChat({
    required String recipientId,
    required String chatId,
    required String text,
    String senderId = '',
  }) async {
    return await sendSecureMessage(
      recipientId: recipientId,
      type: DataChannelMessageType.chat,
      chatId: chatId,
      data: {'text': text},
      senderId: senderId,
    );
  }

  bool sendSecureFileChunk({
    required String recipientId,
    required String chatId,
    required String fileId,
    required int chunkIndex,
    required String chunkData,
    required int totalChunks,
    String senderId = '',
  }) async {
    return await sendSecureMessage(
      recipientId: recipientId,
      type: DataChannelMessageType.fileChunk,
      chatId: chatId,
      data: {
        'file_id': fileId,
        'chunk_index': chunkIndex,
        'chunk_data': chunkData,
        'total_chunks': totalChunks,
      },
      senderId: senderId,
    );
  }

  bool sendMetadata({
    required String chatId,
    required String action,
    Map<String, dynamic>? payload,
    String senderId = '',
  }) {
    return _dataChannel.sendMetadata(
      chatId: chatId,
      action: action,
      payload: payload,
      senderId: senderId,
    );
  }

  void dispose() {
    _disposed = true;
    _secureMessageController.close();
  }
}

/// SecureDataChannelMessage — расшифрованное сообщение DataChannel
class SecureDataChannelMessage {
  final DataChannelMessageType type;
  final String chatId;
  final String senderId;
  final Map<String, dynamic> data;
  final bool isEncrypted;
  final DateTime timestamp;

  SecureDataChannelMessage({
    required this.type,
    required this.chatId,
    required this.senderId,
    required this.data,
    required this.isEncrypted,
    required this.timestamp,
  });

  @override
  String toString() => 'SecureDC(${type.value}, encrypted=$isEncrypted, from=$senderId)';
}
