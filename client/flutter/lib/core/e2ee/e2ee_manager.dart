// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';
import 'dart:typed_data';
import '../network/api_client.dart';
import '../utils/logger.dart';

/// E2EE Key Manager — stub implementation.
/// Full Signal Protocol implementation pending API migration for libsignal_protocol_dart.
class E2EEKeyManager {
  static final E2EEKeyManager instance = E2EEKeyManager._internal();
  E2EEKeyManager._internal();

  String? _userId;

  Future<void> initialize(String userId, [ApiClient? apiClient]) async {
    _userId = userId;
    logger.i('E2EE: Initialized for user $userId (stub)');
  }

  Future<Map<String, dynamic>> generatePreKeyBundle() async {
    return {'userId': _userId, 'registrationId': 0, 'identityKey': '', 'signedPreKey': {}, 'preKeys': []};
  }

  Future<void> processPreKeyBundle(String remoteUserId, Map<String, dynamic> bundle) async {
    logger.i('E2EE: Processed pre-key bundle from $remoteUserId (stub)');
  }

  Future<Uint8List> encryptMessage(String remoteUserId, String plaintext) async {
    logger.w('E2EE: Encryption is stub — returning plaintext bytes');
    return Uint8List.fromList(plaintext.codeUnits);
  }

  Future<String> decryptMessage(String remoteUserId, Uint8List ciphertext) async {
    logger.w('E2EE: Decryption is stub — returning ciphertext as string');
    return String.fromCharCodes(ciphertext);
  }

  Future<String> encryptForGroup(String groupId, String plaintext) async {
    logger.w('E2EE: Group encryption is stub');
    return plaintext;
  }

  Future<String> decryptForGroup(String groupId, String ciphertext) async {
    logger.w('E2EE: Group decryption is stub');
    return ciphertext;
  }

  Future<String> encryptGroupMessage(String groupId, String plaintext) async => encryptForGroup(groupId, plaintext);
  Future<String> decryptGroupMessage(String groupId, String ciphertext) async => decryptForGroup(groupId, ciphertext);

  Future<void> rotateSignedPreKey() async {
    logger.i('E2EE: Signed pre-key rotation (stub)');
  }

  Future<void> wipeAllKeys() async {
    _userId = null;
    logger.i('E2EE: All keys wiped (stub)');
  }

  Future<void> reset() async => wipeAllKeys();

  /// Установить API-клиент (stub — noop)
  void setApiClient(ApiClient apiClient) {
    logger.i('E2EE: API client set (stub)');
  }

  /// Расшифровать с ключом восстановления (stub — возвращает как есть)
  Future<String> decryptWithRecovery(String remoteUserId, String ciphertext) async {
    logger.w('E2EE: decryptWithRecovery is stub — returning ciphertext');
    return ciphertext;
  }
}
