// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../haptic/haptic_service.dart';
import '../utils/logger.dart';

/// NotificationService — сервис звуков и push-уведомлений (Charo sounds)
///
/// Звуки ЧАРО (по мотивам Charo):
/// - charo_message.wav — входящее сообщение ("Uh-oh!")
/// - charo_send.wav — отправленное сообщение
/// - charo_call.wav — входящий звонок (loop)
/// - charo_online.wav — контакт появился онлайн
/// - charo_system.wav — системное уведомление
///
/// Push-уведомления:
/// - flutter_local_notifications для локальных уведомлений
/// - Баннер + звук + вибрация для входящих сообщений
/// - Full-screen intent для входящих звонков
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final AudioPlayer _player = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  bool _soundEnabled = true;
  bool _pushEnabled = true;
  bool _initialized = false;

  final _soundStateController = StreamController<bool>.broadcast();
  Stream<bool> get soundStateStream => _soundStateController.stream;

  bool get isSoundEnabled => _soundEnabled;
  bool get isPushEnabled => _pushEnabled;

  // ─── Инициализация ──────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    final storedSound = await _secureStorage.read(key: 'sound_enabled');
    _soundEnabled = storedSound != 'false';

    final storedPush = await _secureStorage.read(key: 'push_enabled');
    _pushEnabled = storedPush != 'false';

    // Initialize flutter_local_notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings();
    const macosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
      macOS: macosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request Android notification permission (Android 13+)
    await _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

    _initialized = true;
    logger.i('🔔 NotificationService initialized (sound=${_soundEnabled}, push=${_pushEnabled})');
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _secureStorage.write(key: 'sound_enabled', value: enabled.toString());
    _soundStateController.add(enabled);
    logger.d('🔔 Sound ${enabled ? 'enabled' : 'disabled'}');
  }

  Future<void> setPushEnabled(bool enabled) async {
    _pushEnabled = enabled;
    await _secureStorage.write(key: 'push_enabled', value: enabled.toString());
    logger.d('🔔 Push ${enabled ? 'enabled' : 'disabled'}');
  }

  // ─── Push Notifications ──────────────────────────────────────────

  /// Show notification for incoming message
  Future<void> showMessageNotification({
    required String chatId,
    required String senderName,
    required String messageText,
    String? avatarUrl,
  }) async {
    if (!_pushEnabled) return;

    final androidDetails = AndroidNotificationDetails(
      'charo_messages',
      'ЧАРО — Сообщения',
      channelDescription: 'Входящие сообщения в ЧАРО',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('charo_message'),
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(messageText),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'charo_message.wav',
      categoryIdentifier: 'charo_message',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use chatId hash as notification ID to update existing notifications
    final notificationId = chatId.hashCode & 0x7FFFFFFF;

    await _notificationsPlugin.show(
      notificationId,
      senderName,
      messageText,
      notificationDetails,
      payload: 'chat:$chatId',
    );
  }

  /// Show notification for incoming call (high priority, full-screen intent)
  Future<void> showCallNotification({
    required String callId,
    required String callerName,
    bool isVideo = false,
  }) async {
    if (!_pushEnabled) return;

    final androidDetails = AndroidNotificationDetails(
      'charo_calls',
      'ЧАРО — Звонки',
      channelDescription: 'Входящие звонки в ЧАРО',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('charo_call'),
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      autoCancel: false,
      ongoing: true,
      styleInformation: BigTextStyleInformation(
        isVideo ? 'Видеозвонок от $callerName' : 'Голосовой звонок от $callerName',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'charo_call.wav',
      categoryIdentifier: 'charo_call',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = callId.hashCode & 0x7FFFFFFF;

    await _notificationsPlugin.show(
      notificationId,
      callerName,
      isVideo ? 'Видеозвонок' : 'Голосовой звонок',
      notificationDetails,
      payload: 'call:$callId',
    );
  }

  /// Cancel call notification (when call is answered/ended)
  Future<void> cancelCallNotification(String callId) async {
    final notificationId = callId.hashCode & 0x7FFFFFFF;
    await _notificationsPlugin.cancel(notificationId);
  }

  /// Cancel message notification for a chat (when chat is opened)
  Future<void> cancelMessageNotification(String chatId) async {
    final notificationId = chatId.hashCode & 0x7FFFFFFF;
    await _notificationsPlugin.cancel(notificationId);
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    logger.i('🔔 Notification tapped: $payload');

    // Route to appropriate screen based on payload
    // 'chat:chatId' → open chat detail
    // 'call:callId' → open active call
    // This is handled by the app's navigation system
  }

  // ─── Звуки Charo ──────────────────────────────────────────────────

  Future<void> playMessageSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/charo_message.wav'));
      logger.d('🔔 Charo message sound played');
    } catch (e) {
      logger.e('Failed to play message sound: $e');
    }
  }

  Future<void> playSendSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/charo_send.wav'));
      logger.d('🔔 Charo send sound played');
    } catch (e) {
      logger.e('Failed to play send sound: $e');
    }
  }

  Future<void> playCallSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.setVolume(1.0);
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/charo_call.wav'));
      logger.d('🔔 Charo call sound playing (loop)');
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
      await _player.play(AssetSource('sounds/charo_online.wav'));
      logger.d('🔔 Charo online sound played');
    } catch (e) {
      logger.e('Failed to play online sound: $e');
    }
  }

  Future<void> playSystemSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/charo_system.wav'));
      logger.d('🔔 Charo system sound played');
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
