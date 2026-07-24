import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../haptic/haptic_service.dart';
import '../utils/logger.dart';

/// NotificationService — сервис звуков уведомлений (ICQ sounds)
///
/// Звуки ЧАРО (по мотивам ICQ):
/// - icq_message.wav — входящее сообщение ("Uh-oh!")
/// - icq_send.wav — отправленное сообщение
/// - icq_call.wav — входящий звонок (loop)
/// - icq_online.wav — контакт появился онлайн
/// - icq_system.wav — системное уведомление
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final AudioPlayer _player = AudioPlayer();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  bool _soundEnabled = true;
  bool _initialized = false;

  final _soundStateController = StreamController<bool>.broadcast();
  Stream<bool> get soundStateStream => _soundStateController.stream;

  bool get isSoundEnabled => _soundEnabled;

  // ─── Инициализация ──────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    final stored = await _secureStorage.read(key: 'sound_enabled');
    _soundEnabled = stored != 'false';
    _initialized = true;

    logger.i('🔔 NotificationService initialized (sound=${_soundEnabled})');
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _secureStorage.write(key: 'sound_enabled', value: enabled.toString());
    _soundStateController.add(enabled);
    logger.d('🔔 Sound ${enabled ? 'enabled' : 'disabled'}');
  }

  // ─── Звуки ICQ ──────────────────────────────────────────────────

  Future<void> playMessageSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/icq_message.wav'));
      logger.d('🔔 ICQ message sound played');
    } catch (e) {
      logger.e('Failed to play message sound: $e');
    }
  }

  Future<void> playSendSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/icq_send.wav'));
      logger.d('🔔 ICQ send sound played');
    } catch (e) {
      logger.e('Failed to play send sound: $e');
    }
  }

  Future<void> playCallSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.setVolume(1.0);
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/icq_call.wav'));
      logger.d('🔔 ICQ call sound playing (loop)');
    } catch (e) {
      logger.e('Failed to play call sound: $e');
    }
  }

  Future<void> stopCallSound() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      logger.d('🔔 Call sound stopped');
    } catch (e) {
      logger.e('Failed to stop call sound: $e');
    }
  }

  Future<void> playOnlineSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/icq_online.wav'));
      logger.d('🔔 ICQ online sound played');
    } catch (e) {
      logger.e('Failed to play online sound: $e');
    }
  }

  Future<void> playSystemSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/icq_system.wav'));
      logger.d('🔔 ICQ system sound played');
    } catch (e) {
      logger.e('Failed to play system sound: $e');
    }
  }

  // ─── Vibration (через HapticService) ────────────────────────────

  Future<void> vibrateOnMessage() async {
    if (!_soundEnabled) return;
    await HapticService.instance.onReceiveMessage();
  }

  Future<void> vibrateOnCall() async {
    if (!_soundEnabled) return;
    await HapticService.instance.onIncomingCall();
  }

  // ─── Cleanup ─────────────────────────────────────────────────────

  void dispose() {
    _player.dispose();
    _soundStateController.close();
  }
}
