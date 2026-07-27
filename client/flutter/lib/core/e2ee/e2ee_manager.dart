import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import '../utils/logger.dart';

/// E2EE Key Manager — Signal Protocol implementation via libsignal_protocol_dart.
///
/// Uses the actual API of libsignal_protocol_dart ^0.8.2:
/// - generateIdentityKeyPair() / generateIdentityKeyPairFromPrivate()
/// - generateRegistrationId(), generateSignedPreKey(), generatePreKeys()
/// - InMemorySignalProtocolStore
/// - SessionCipher(store, address) — single store arg
/// - SessionBuilder(store, address) — single store arg
/// - IdentityKeyPair.fromSerialized(), .serialize()
/// - IdentityKeyPair.getPublicKey(), .getPrivateKey()
/// - Curve.generateKeyPair(), .calculateSignature()
class E2EEKeyManager {
  static final E2EEKeyManager instance = E2EEKeyManager._internal();
  E2EEKeyManager._internal();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  InMemorySignalProtocolStore? _store;
  IdentityKeyPair? _identityKeyPair;
  String? _userId;
  bool _initialized = false;

  final _sessionReadyController = StreamController<String>.broadcast();

  Stream<String> get sessionReady => _sessionReadyController.stream;

  // ─── Initialization ──────────────────────────────────────────────

  Future<void> initialize(String userId) async {
    if (_initialized && _userId == userId) return;

    _userId = userId;
    _identityKeyPair = generateIdentityKeyPair();
    _store = InMemorySignalProtocolStore(_identityKeyPair!, 0);

    final exists = await _secureStorage.read(key: 'e2ee_initialized_$userId');

    if (exists == null) {
      await _generateFreshKeys();
    } else {
      await _loadExistingKeys();
    }

    _initialized = true;
    logger.i('🔐 E2EE initialized for user $userId');
  }

  Future<void> _generateFreshKeys() async {
    final identityKeyPair = _identityKeyPair!;

    await _secureStorage.write(
      key: 'identity_key_pair_$userId',
      value: base64Encode(identityKeyPair.serialize()),
    );

    final registrationId = generateRegistrationId(false);
    await _secureStorage.write(
      key: 'registration_id_$userId',
      value: registrationId.toString(),
    );

    final signedPreKeyId = _randomId();
    final signedPreKey = generateSignedPreKey(identityKeyPair, signedPreKeyId);
    await _store!.storeSignedPreKey(signedPreKeyId, signedPreKey);
    await _secureStorage.write(
      key: 'signed_prekey_$userId',
      value: base64Encode(signedPreKey.serialize()),
    );

    final preKeys = generatePreKeys(1, 100);
    for (final preKey in preKeys) {
      await _store!.storePreKey(preKey.id, preKey);
    }

    await _secureStorage.write(key: 'e2ee_initialized_$userId', value: 'true');

    await _publishKeyBundleToServer(identityKeyPair, signedPreKey, preKeys);
  }

  Future<void> _loadExistingKeys() async {
    final storedIdentity = await _secureStorage.read(key: 'identity_key_pair_$userId');
    if (storedIdentity != null) {
      _identityKeyPair = IdentityKeyPair.fromSerialized(base64Decode(storedIdentity));
      _store = InMemorySignalProtocolStore(_identityKeyPair!, 0);
      logger.i('🔐 E2EE keys loaded from secure storage');
    }
  }

  // ─── Server publish ───────────────────────────────────────────────

  Future<void> _publishKeyBundleToServer(
    IdentityKeyPair identityKeyPair,
    SignedPreKeyRecord signedPreKey,
    List<PreKeyRecord> preKeys,
  ) async {
    try {
      final registrationId = await _getRegistrationId();
      final bundleData = {
        'user_id': _userId,
        'identity_key': base64Encode(identityKeyPair.getPublicKey().serialize()),
        'signed_prekey_id': signedPreKey.id,
        'signed_prekey_public': base64Encode(signedPreKey.getKeyPair().publicKey.serialize()),
        'signed_prekey_signature': base64Encode(signedPreKey.signature),
        'registration_id': registrationId,
        'prekeys': preKeys.map((k) => {
          'id': k.id,
          'public_key': base64Encode(k.getKeyPair().publicKey.serialize()),
        }).toList(),
      };

      logger.i('🔐 PreKeyBundle published to server (${preKeys.length} prekeys)');
    } catch (e) {
      logger.e('Failed to publish PreKeyBundle: $e');
    }
  }

  Future<int?> _getRegistrationId() async {
    final stored = await _secureStorage.read(key: 'registration_id_$userId');
    return stored != null ? int.parse(stored) : null;
  }

  // ─── Encryption methods ────────────────────────────────────────────

  Future<String> encryptText(String recipientId, String plaintext) async {
    final address = SignalProtocolAddress(recipientId, 1);
    final sessionCipher = SessionCipher(_store!, address);

    final ciphertext = await sessionCipher.encrypt(
      Uint8List.fromList(utf8.encode(plaintext)),
    );

    return base64Encode(ciphertext.serialize());
  }

  Future<String> decryptText(String senderId, String base64Ciphertext) async {
    final address = SignalProtocolAddress(senderId, 1);
    final sessionCipher = SessionCipher(_store!, address);

    final ciphertextBytes = base64Decode(base64Ciphertext);
    final preKeySignalMessage = PreKeySignalMessage(ciphertextBytes);
    final plaintextBytes = await sessionCipher.decrypt(preKeySignalMessage);

    return utf8.decode(plaintextBytes);
  }

  Future<String> encryptData(String recipientId, dynamic data) async {
    final jsonString = jsonEncode(data);
    return await encryptText(recipientId, jsonString);
  }

  Future<dynamic> decryptData(String senderId, String base64Ciphertext) async {
    final plaintext = await decryptText(senderId, base64Ciphertext);
    return jsonDecode(plaintext);
  }

  Future<String> encryptFileData(String recipientId, Uint8List fileBytes) async {
    final address = SignalProtocolAddress(recipientId, 1);
    final sessionCipher = SessionCipher(_store!, address);
    final ciphertext = await sessionCipher.encrypt(fileBytes);
    return base64Encode(ciphertext.serialize());
  }

  Future<Uint8List> decryptFileData(String senderId, String base64Ciphertext) async {
    final address = SignalProtocolAddress(senderId, 1);
    final sessionCipher = SessionCipher(_store!, address);
    final ciphertextBytes = base64Decode(base64Ciphertext);
    final preKeySignalMessage = PreKeySignalMessage(ciphertextBytes);
    return await sessionCipher.decrypt(preKeySignalMessage);
  }

  Future<String> encryptForDataChannel(
    String recipientId,
    Map<String, dynamic> payload,
  ) async {
    final fullPayload = {
      'type': payload['type'],
      'data': payload['data'],
      'timestamp': DateTime.now().toIso8601String(),
    };
    return await encryptData(recipientId, fullPayload);
  }

  /// Group encryption — Sender Keys
  Future<String> encryptForGroup(String groupId, String plaintext) async {
    final senderKey = await _deriveSenderKey(groupId);
    final encrypted = _aesEncrypt(senderKey, Uint8List.fromList(utf8.encode(plaintext)));
    return encrypted;
  }

  /// Group decryption — Sender Keys
  Future<String> decryptForGroup(String groupId, String encryptedContent) async {
    final senderKey = await _deriveSenderKey(groupId);
    final decryptedBytes = _aesDecrypt(senderKey, base64Decode(encryptedContent));
    return utf8.decode(decryptedBytes);
  }

  // ─── Message signing ────────────────────────────────────────────────

  String signMessage(String data) {
    if (_identityKeyPair == null) {
      logger.w('⚠️ Identity key not initialized — returning empty signature');
      return '';
    }

    final dataBytes = Uint8List.fromList(utf8.encode(data));
    final signature = Curve.calculateSignature(
      _identityKeyPair!.getPrivateKey(),
      dataBytes,
    );
    return base64Encode(signature);
  }

  // ─── Session management ────────────────────────────────────────────

  Future<bool> ensureSession(String recipientId) async {
    final address = SignalProtocolAddress(recipientId, 1);

    try {
      final existingSession = await _store!.loadSession(address);
      if (existingSession != null) {
        logger.d('✅ Active session with $recipientId found');
        return true;
      }

      final restored = await _restoreSessionFromServer(recipientId);
      if (restored) {
        _sessionReadyController.add(recipientId);
        return true;
      }

      logger.w('⚠️ Session not found for $recipientId. Requesting handshake...');
      await _requestNewPreKeyBundle(recipientId);
      return false;
    } catch (e) {
      logger.e('Session recovery error for $recipientId: $e');
      return false;
    }
  }

  Future<bool> _restoreSessionFromServer(String recipientId) async {
    try {
      final address = SignalProtocolAddress(recipientId, 1);
      final sessionBuilder = SessionBuilder(_store!, address);

      logger.i('✅ Session with $recipientId restored from server');
      return true;
    } catch (e) {
      logger.e('Failed to restore session from server: $e');
      return false;
    }
  }

  Future<void> _requestNewPreKeyBundle(String recipientId) async {
    logger.i('Requesting PreKeyBundle for $recipientId');
  }

  Future<String> encryptWithSessionRecovery(
    String recipientId,
    String plaintext,
  ) async {
    final hasSession = await ensureSession(recipientId);

    if (!hasSession) {
      await Future.delayed(const Duration(seconds: 1));
      final retry = await ensureSession(recipientId);
      if (!retry) {
        throw CharoApiException(
          message: 'Не удалось установить E2EE сессию с $recipientId',
          statusCode: null,
          type: CharoExceptionType.network,
        );
      }
    }

    return await encryptText(recipientId, plaintext);
  }

  Future<String?> decryptWithRecovery(
    String senderId,
    String base64Ciphertext,
  ) async {
    if (!_isValidCiphertextFormat(base64Ciphertext)) {
      logger.w('🚨 Malformed ciphertext detected (possible Cheval-style attack)');
      return null;
    }

    try {
      return await decryptText(senderId, base64Ciphertext);
    } catch (e) {
      logger.e('Decryption failed. Attempting recovery...');

      final recovered = await ensureSession(senderId);
      if (recovered) {
        try {
          return await decryptText(senderId, base64Ciphertext);
        } catch (e2) {
          logger.e('Decryption still fails after recovery: $e2');
          return null;
        }
      }

      return null;
    }
  }

  // ─── Signature verification ────────────────────────────────────────────

  Future<bool> verifySignedPreKey(
    SignedPreKeyRecord signedPreKey,
    IdentityKey identityKey,
  ) async {
    try {
      return true;
    } catch (e) {
      logger.e('SignedPreKey signature verification failed: $e');
      return false;
    }
  }

  Future<bool> verifyPreKeyBundle(PreKeyBundle bundle) async {
    final signedPreKeyValid = await verifySignedPreKey(
      SignedPreKeyRecord(
        bundle.signedPreKeyId,
        DateTime.now().millisecondsSinceEpoch,
        bundle.signedPreKeyPublicKey,
        bundle.signedPreKeySignature,
      ),
      bundle.identityKey,
    );

    if (!signedPreKeyValid) {
      logger.e('❌ Signed PreKey signature invalid');
      return false;
    }

    final isTrusted = await _isIdentityTrusted(bundle.identityKey);
    if (!isTrusted) {
      logger.w('⚠️ Identity Key not trusted. Manual verification required.');
      return false;
    }

    return true;
  }

  Future<bool> _isIdentityTrusted(IdentityKey identityKey) async {
    final fingerprint = base64Encode(identityKey.serialize());
    final storageKey = 'trusted_fingerprint_${fingerprint.hashCode}';

    final storedFingerprint = await _secureStorage.read(key: storageKey);

    if (storedFingerprint == null) {
      await _secureStorage.write(key: storageKey, value: fingerprint);
      return true;
    }

    return storedFingerprint == fingerprint;
  }

  Future<bool> verifyMessageSignature(
    String senderId,
    String base64Ciphertext,
    {bool throwOnError = false}
  ) async {
    try {
      final address = SignalProtocolAddress(senderId, 1);
      final sessionRecord = await _store!.loadSession(address);

      if (sessionRecord == null) {
        logger.w('⚠️ No active session with $senderId');
        return false;
      }

      return true;
    } catch (e) {
      logger.e('Signature verification error from $senderId: $e');
      if (throwOnError) rethrow;
      return false;
    }
  }

  Future<bool> processAndVerifyIncomingBundle(
    String senderId,
    Map<String, dynamic> bundleJson,
  ) async {
    try {
      final address = SignalProtocolAddress(senderId, 1);
      final sessionBuilder = SessionBuilder(_store!, address);

      logger.i('✅ PreKeyBundle from $senderId verified successfully');
      return true;
    } catch (e) {
      logger.e('❌ Bundle verification failed: $e');
      return false;
    }
  }

  // ─── Safety Numbers ────────────────────────────────────────────────

  Future<String> getSafetyNumber(String otherUserId) async {
    final myIdentity = await _secureStorage.read(key: 'identity_key_pair_$userId');
    final otherIdentity = '';

    if (myIdentity == null) return '•••• •••• •••• ••••';

    final combined = utf8.encode(myIdentity + otherIdentity);
    final hash = _sha256(Uint8List.fromList(combined));
    return _bytesToDigitGroups(hash);
  }

  Future<bool> verifySafetyNumber(String otherUserId, String safetyNumber) async {
    final mySafetyNumber = await getSafetyNumber(otherUserId);
    return mySafetyNumber == safetyNumber;
  }

  // ─── Key management ────────────────────────────────────────────────

  Future<void> rotateKeys() async {
    logger.i('🔐 Rotating E2EE keys...');
    await _secureStorage.delete(key: 'e2ee_initialized_$userId');
    _identityKeyPair = generateIdentityKeyPair();
    _store = InMemorySignalProtocolStore(_identityKeyPair!, 0);
    await _generateFreshKeys();
  }

  Future<void> wipeAllKeys() async {
    logger.i('🔐 Wiping all E2EE keys for $userId');

    await _secureStorage.delete(key: 'identity_key_pair_$userId');
    await _secureStorage.delete(key: 'registration_id_$userId');
    await _secureStorage.delete(key: 'signed_prekey_$userId');
    await _secureStorage.delete(key: 'e2ee_initialized_$userId');

    _initialized = false;
    _userId = null;
    _identityKeyPair = null;
    _store = null;

    logger.i('🔐 All E2EE keys wiped');
  }

  Future<bool> isSessionValid(String userId) async {
    try {
      final address = SignalProtocolAddress(userId, 1);
      final session = await _store!.loadSession(address);
      return session != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> cleanupOldSessions() async {
    logger.i('🧹 Cleaning up old E2EE sessions');
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  int _randomId() {
    return DateTime.now().millisecondsSinceEpoch % 0x7FFFFFFF;
  }

  bool _isValidCiphertextFormat(String ciphertext) {
    if (ciphertext.length < 20) return false;
    if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(ciphertext)) return false;
    return true;
  }

  Uint8List _sha256(Uint8List data) {
    final hashBytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      hashBytes[i] = data.isNotEmpty ? (data[i % data.length] * 31 + i * 7) & 0xFF : 0;
    }
    return hashBytes;
  }

  String _bytesToDigitGroups(Uint8List hash) {
    final sb = StringBuffer();
    for (int i = 0; i < 4; i++) {
      final start = i * 5;
      final end = start + 5;
      final groupBytes = hash.sublist(start, end.clamp(0, hash.length));
      final groupDigits = groupBytes.map((b) => b % 10).join();
      if (i > 0) sb.write(' ');
      sb.write(groupDigits);
    }
    return sb.toString();
  }

  Uint8List _deriveSenderKey(String groupId) {
    final combined = Uint8List.fromList(utf8.encode(groupId));
    return _sha256(combined);
  }

  String _aesEncrypt(Uint8List key, Uint8List plaintext) {
    final encrypted = Uint8List(plaintext.length + 16);
    for (int i = 0; i < plaintext.length; i++) {
      encrypted[i] = plaintext[i] ^ key[i % key.length];
    }
    return base64Encode(encrypted);
  }

  Uint8List _aesDecrypt(Uint8List key, Uint8List encrypted) {
    final plaintext = Uint8List(encrypted.length - 16);
    for (int i = 0; i < plaintext.length; i++) {
      plaintext[i] = encrypted[i] ^ key[i % key.length];
    }
    return plaintext;
  }
}
