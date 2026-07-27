import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';

/// Безопасное хранилище для токенов и ключей
class SecureStorageHelper {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ─── Access Token ───────────────────────────────────────────────
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (e) {
      logger.e('SecureStorage: failed to read access token: $e');
      return null;
    }
  }

  Future<void> setAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  // ─── Refresh Token ──────────────────────────────────────────────
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      logger.e('SecureStorage: failed to read refresh token: $e');
      return null;
    }
  }

  Future<void> setRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  // ─── User ID ────────────────────────────────────────────────────
  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  Future<void> setUserId(String id) async {
    await _storage.write(key: _userIdKey, value: id);
  }

  // ─── OAuth State ────────────────────────────────────────────────

  Future<void> setOAuthState({required String provider, required String state}) async {
    await _storage.write(key: 'oauth_state_$provider', value: state);
  }

  Future<String?> getOAuthState(String provider) async {
    return await _storage.read(key: 'oauth_state_$provider');
  }

  Future<void> clearOAuthState(String provider) async {
    await _storage.delete(key: 'oauth_state_$provider');
  }

  // ─── Clear All ──────────────────────────────────────────────────
  Future<void> clearAll() async {
    await _storage.deleteAll();
    logger.i('SecureStorage: all data cleared');
  }
}
