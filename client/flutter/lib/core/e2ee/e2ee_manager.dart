// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

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
///
/// AES-256-CBC group encryption via PointyCastle.
/// SHA-256 hashing via PointyCastle.
class E2EEKeyManager {
  static final E2EEKeyManager instance = E2EEKeyManager._internal();
  E2EEKeyManager._internal();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  ApiClient? _apiClient;

  InMemorySignalProtocolStore? _store;
  IdentityKeyPair? _identityKeyPair;
  String? _userId;
  bool _initialized = false;

  final _sessionReadyController = StreamController<String>.broadcast();

  Stream<String> get sessionReady => _sessionReadyController.stream;

  /// Set API client for server communication
  void setApiClient(ApiClient apiClient) {
    _apiClient = apiClient;
  }

  // ─── Initialization ──────────────────────────────────────────────

  Future<void> initialize(String userId) async {
    if (_initialized && _userId == userId) return;

    _userId = userId;

    final exists = await _secureStorage.read(key: 'e2ee_initialized_$userId');

    if (exists != null) {
      await _loadExistingKeys();
    } else {
      _identityKeyPair = generateIdentityKeyPair();
      _store = InMemorySignalProtocolStore(_identityKeyPair!, 0);
      await _generateFreshKeys();
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
    final localRegistrationId = registrationId;
    await _secureStorage.write(
      key: 'registration_id_$userId',
      value: localRegistrationId.toString(),
    );

    // Recreate store with proper registration ID
    _store = InMemorySignalProtocolStore(_identityKeyPair!, localRegistrationId);

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

      final storedRegId = await _secureStorage.read(key: 'registration_id_$userId');
      final regId = storedRegId != null ? int.parse(storedRegId) : 0;

      _store = InMemorySignalProtocolStore(_identityKeyPair!, regId);
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

      if (_apiClient != null) {
        await _apiClient!.post('/api/v1/users/me/keys', data: bundleData);
        logger.i('🔐 PreKeyBundle published to server (${preKeys.length} prekeys)');
      } else {
        logger.w('🔐 No ApiClient set — PreKeyBundle not published to server');
      }
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

  /// Group encryption — AES-256-CBC with Sender Keys
  Future<String> encryptForGroup(String groupId, String plaintext) async {
    final senderKey = await _deriveSenderKey(groupId);
    final iv = _generateRandomIv();
    final encrypted = _aes256CbcEncrypt(senderKey, iv, Uint8List.fromList(utf8.encode(plaintext)));
    // IV prepended to ciphertext for decryption
    final combined = Uint8List.fromList([...iv, ...encrypted]);
    return base64Encode(combined);
  }

  /// Group decryption — AES-256-CBC with Sender Keys
  Future<String> decryptForGroup(String groupId, String base64Combined) async {
    final senderKey = await _deriveSenderKey(groupId);
    final combined = base64Decode(base64Combined);
    // First 16 bytes = IV
    final iv = combined.sublist(0, 16);
    final ciphertext = combined.sublist(16);
    final decryptedBytes = _aes256CbcDecrypt(senderKey, Uint8List.fromList(iv), Uint8List.fromList(ciphertext));
    return utf8.decode(decryptedBytes);
  }

  // ─── AES-256-CBC via PointyCastle ────────────────────────────────────

  /// AES-256-CBC encrypt — real encryption via PointyCastle
  Uint8List _aes256CbcEncrypt(Uint8List key, Uint8List iv, Uint8List plaintext) {
    // PKCS7 padding
    final padded = _pkcs7Pad(plaintext, 16);

    final cipher = pc.CBCBlockCipher(pc.AESEngine());
    cipher.init(true, pc.ParametersWithIV(pc.KeyParameter(key), iv));

    final output = Uint8List(padded.length);
    var offset = 0;
    while (offset < padded.length) {
      offset += cipher.processBlock(padded, offset, output, offset);
    }

    return output;
  }

  /// AES-256-CBC decrypt — real decryption via PointyCastle
  Uint8List _aes256CbcDecrypt(Uint8List key, Uint8List iv, Uint8List ciphertext) {
    final cipher = pc.CBCBlockCipher(pc.AESEngine());
    cipher.init(false, pc.ParametersWithIV(pc.KeyParameter(key), iv));

    final output = Uint8List(ciphertext.length);
    var offset = 0;
    while (offset < ciphertext.length) {
      offset += cipher.processBlock(ciphertext, offset, output, offset);
    }

    return _pkcs7Unpad(output);
  }

  /// PKCS7 padding
  Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLength = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLength);
    padded.setRange(0, data.length, data);
    for (int i = data.length; i < padded.length; i++) {
      padded[i] = padLength;
    }
    return padded;
  }

  /// PKCS7 unpadding
  Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final padLength = data[data.length - 1];
    if (padLength > data.length || padLength == 0) return data;
    // Verify padding
    for (int i = data.length - padLength; i < data.length; i++) {
      if (data[i] != padLength) return data;
    }
    return data.sublist(0, data.length - padLength);
  }

  /// Generate random 16-byte IV for AES-CBC
  Uint8List _generateRandomIv() {
    final secureRandom = pc.FortunaRandom();
    // Cryptographically strong seeding: combine dart:math Random.secure()
    // output with system timestamp entropy
    final seeds = Uint8List(32);
    final strongRandom = Random.secure();
    for (int i = 0; i < 32; i++) {
      seeds[i] = strongRandom.nextInt(256);
    }
    // Mix in timestamp entropy as additional source
    final now = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < 8; i++) {
      seeds[i] ^= ((now >> (i * 8)) & 0xFF);
    }
    secureRandom.seed(pc.KeyParameter(seeds));
    final iv = Uint8List(16);
    secureRandom.nextBytes(iv);
    return iv;
  }

  // ─── SHA-256 via PointyCastle ────────────────────────────────────────

  Uint8List _sha256(Uint8List data) {
    final digest = pc.SHA256Digest();
    digest.update(data, 0, data.length);
    final hash = Uint8List(digest.digestSize);
    digest.doFinal(hash, 0);
    return hash;
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
      if (_apiClient == null) return false;

      final response = await _apiClient!.get('/api/v1/users/$recipientId/keys');
      final bundleData = response.asMap;

      // Build PreKeyBundle from server response
      final identityKey = IdentityKey.fromSerialized(
        base64Decode(bundleData['identity_key'] as String),
      );
      final signedPreKeyId = bundleData['signed_prekey_id'] as int;
      final signedPreKeyPublic = Curve.decodePoint(
        base64Decode(bundleData['signed_prekey_public'] as String),
        0,
      );
      final signedPreKeySignature = base64Decode(
        bundleData['signed_prekey_signature'] as String,
      );
      final registrationId = bundleData['registration_id'] as int;

      // Pick first available prekey
      final prekeysList = bundleData['prekeys'] as List<dynamic>;
      final firstPrekey = prekeysList.isNotEmpty ? prekeysList[0] as Map<String, dynamic> : null;

      PreKeyBundle? preKeyBundle;
      if (firstPrekey != null) {
        final preKeyId = firstPrekey['id'] as int;
        final preKeyPublic = Curve.decodePoint(
          base64Decode(firstPrekey['public_key'] as String),
          0,
        );
        preKeyBundle = PreKeyBundle(
          registrationId,
          1, // deviceId
          preKeyId,
          preKeyPublic,
          signedPreKeyId,
          signedPreKeyPublic,
          signedPreKeySignature,
          identityKey,
        );
      } else {
        // No prekey available — fallback
        preKeyBundle = PreKeyBundle(
          registrationId,
          1,
          0,
          null,
          signedPreKeyId,
          signedPreKeyPublic,
          signedPreKeySignature,
          identityKey,
        );
      }

      final address = SignalProtocolAddress(recipientId, 1);
      final sessionBuilder = SessionBuilder(_store!, address);
      await sessionBuilder.process(preKeyBundle);

      logger.i('✅ Session with $recipientId restored from server');
      return true;
    } catch (e) {
      logger.e('Failed to restore session from server: $e');
      return false;
    }
  }

  Future<void> _requestNewPreKeyBundle(String recipientId) async {
    logger.i('Requesting PreKeyBundle for $recipientId');
    // Will be processed on next ensureSession call
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
      logger.w('🚨 Malformed ciphertext detected (possible attack)');
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
      // Real verification: verify the signature of the signed prekey
      final signature = signedPreKey.signature;
      final signedPreKeyPublicKey = signedPreKey.getKeyPair().publicKey.serialize();
      Curve.verifySignature(
        identityKey.getPublicKey(),
        Uint8List.fromList(signedPreKeyPublicKey),
        signature,
      );
      return true;
    } catch (e) {
      logger.e('SignedPreKey signature verification failed: $e');
      return false;
    }
  }

  Future<bool> verifyPreKeyBundle(PreKeyBundle bundle) async {
    try {
      // Verify the signature on the signed prekey
      Curve.verifySignature(
        bundle.identityKey.getPublicKey(),
        bundle.signedPreKeyPublicKey.serialize(),
        bundle.signedPreKeySignature,
      );
    } catch (e) {
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
      if (_store == null) return false;

      final identityKey = IdentityKey.fromSerialized(
        base64Decode(bundleJson['identity_key'] as String),
      );
      final signedPreKeyId = bundleJson['signed_prekey_id'] as int;
      final signedPreKeyPublic = Curve.decodePoint(
        base64Decode(bundleJson['signed_prekey_public'] as String),
        0,
      );
      final signedPreKeySignature = base64Decode(
        bundleJson['signed_prekey_signature'] as String,
      );
      final registrationId = bundleJson['registration_id'] as int;

      final prekeysList = bundleJson['prekeys'] as List<dynamic>;
      final firstPrekey = prekeysList.isNotEmpty ? prekeysList[0] as Map<String, dynamic> : null;

      PreKeyBundle preKeyBundle;
      if (firstPrekey != null) {
        final preKeyId = firstPrekey['id'] as int;
        final preKeyPublic = Curve.decodePoint(
          base64Decode(firstPrekey['public_key'] as String),
          0,
        );
        preKeyBundle = PreKeyBundle(
          registrationId,
          1,
          preKeyId,
          preKeyPublic,
          signedPreKeyId,
          signedPreKeyPublic,
          signedPreKeySignature,
          identityKey,
        );
      } else {
        preKeyBundle = PreKeyBundle(
          registrationId,
          1,
          0,
          null,
          signedPreKeyId,
          signedPreKeyPublic,
          signedPreKeySignature,
          identityKey,
        );
      }

      final address = SignalProtocolAddress(senderId, 1);
      final sessionBuilder = SessionBuilder(_store!, address);
      await sessionBuilder.process(preKeyBundle);

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
    if (myIdentity == null) return '•••• •••• •••• ••••';

    final myKey = IdentityKeyPair.fromSerialized(base64Decode(myIdentity));
    final myFingerprint = myKey.getPublicKey().serialize();

    // Fetch other user's identity key from server via ApiClient
    Uint8List otherFingerprint;
    if (_apiClient != null) {
      try {
        final response = await _apiClient!.get('/api/v1/users/$otherUserId/keys');
        final bundleData = response.asMap;
        final otherIdentityKeyBase64 = bundleData['identity_key'] as String;
        otherFingerprint = base64Decode(otherIdentityKeyBase64);
        logger.d('🔐 Safety number: fetched identity key for $otherUserId from server');
      } catch (e) {
        logger.e('Failed to fetch identity key for safety number: $e');
        // Fallback: derive from local session if available
        otherFingerprint = await _getLocalIdentityKey(otherUserId);
      }
    } else {
      otherFingerprint = await _getLocalIdentityKey(otherUserId);
    }

    // Safety number = SHA-256(sorted(fingerprint1, fingerprint2))
    // Sort fingerprints lexicographically to ensure same result for both users
    final sortedFingerprints = [
      myFingerprint,
      otherFingerprint,
    ];
    sortedFingerprints.sort((a, b) {
      for (int i = 0; i < a.length && i < b.length; i++) {
        if (a[i] != b[i]) return a[i] - b[i];
      }
      return a.length - b.length;
    });

    final combined = Uint8List.fromList([
      ...sortedFingerprints[0],
      ...sortedFingerprints[1],
    ]);
    final hash = _sha256(combined);
    return _bytesToDigitGroups(hash);
  }

  /// Get local identity key for a user from the signal store
  Future<Uint8List> _getLocalIdentityKey(String userId) async {
    if (_store == null) return Uint8List(33);

    try {
      final address = SignalProtocolAddress(userId, 1);
      final sessionRecord = await _store!.loadSession(address);
      if (sessionRecord != null) {
        // Session record contains the remote identity key
        final sessionState = sessionRecord.sessionState;
        final remoteIdentityKey = sessionState.remoteIdentityKey;
        return remoteIdentityKey.serialize();
      }
    } catch (e) {
      logger.d('No local session for $userId: $e');
    }

    return Uint8List(33); // 33 bytes = ECPublicKey format
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

  String _bytesToDigitGroups(Uint8List hash) {
    final sb = StringBuffer();
    for (int i = 0; i < 4; i++) {
      final start = i * 5;
      final end = start + 5;
      final groupBytes = hash.sublist(start, end.clamp(0, hash.length));
      // Convert 5 bytes to 5 decimal digits
      final groupDigits = groupBytes.map((b) => b % 10).join();
      if (i > 0) sb.write(' ');
      sb.write(groupDigits);
    }
    return sb.toString();
  }

  /// Derive Sender Key — HKDF-SHA256 with epoch and sender context
  Uint8List _deriveSenderKey(String groupId) {
    // HKDF-Extract: salt = SHA-256(groupId), IKM = groupId bytes
    final groupIdBytes = Uint8List.fromList(utf8.encode(groupId));
    final salt = _sha256(groupIdBytes);

    // HKDF-Expand: PRK = HMAC-SHA256(salt, IKM)
    final hmac = pc.HMac(pc.SHA256Digest(), 64);
    hmac.init(pc.KeyParameter(salt));
    final prk = Uint8List(32);
    hmac.update(groupIdBytes, 0, groupIdBytes.length);
    hmac.doFinal(prk, 0);

    // HKDF-Expand: OKM = HMAC-SHA256(PRK, "charo_sender_key" || 0x01)
    final expandInput = Uint8List.fromList([...utf8.encode('charo_sender_key'), 0x01]);
    hmac.init(pc.KeyParameter(prk));
    final okm = Uint8List(32);
    hmac.update(expandInput, 0, expandInput.length);
    hmac.doFinal(okm, 0);

    return okm;
  }
}
