// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:io';

import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../utils/logger.dart';

/// ─── Push Notification Service ───────────────────────────────────
/// FCM (Android/Web) + APNS (iOS) push-уведомления.
/// При получении токена — автоматически отправляет на сервер.

class PushNotificationService {
  static PushNotificationService? _instance;
  static PushNotificationService get instance => _instance ??= PushNotificationService._();

  PushNotificationService._();

  String? _fcmToken;
  String? _apnsToken;
  bool _initialized = false;

  /// Текущий FCM токен
  String? get fcmToken => _fcmToken;

  /// Текущий APNS токен
  String? get apnsToken => _apnsToken;

  /// Инициализация push-уведомлений
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Firebase инициализация — требует google-services.json / plist
      // Для запуска:
      // 1. Добавить google-services.json в android/app/
      // 2. Добавить GoogleService-Info.plist в ios/Runner/
      // 3. Раскомментировать код ниже

      logger.i('🔔 PushNotificationService initialized (token pending Firebase config)');

      // --- Реальный код для Firebase (раскомментировать при настройке) ---
      //
      // await Firebase.initializeApp();
      // final messaging = FirebaseMessaging.instance;
      //
      // if (Platform.isIOS) {
      //   await messaging.requestPermission(alert: true, badge: true, sound: true);
      //   _apnsToken = await messaging.getAPNSToken();
      // }
      //
      // _fcmToken = await messaging.getToken();
      // logger.i('🔔 FCM token: ${_fcmToken?.substring(0, 20)}...');
      //
      // if (_fcmToken != null) {
      //   await sendTokenToServer(_fcmToken!);
      // }
      //
      // messaging.onTokenRefresh.listen((token) {
      //   _fcmToken = token;
      //   logger.i('🔔 FCM token refreshed');
      //   sendTokenToServer(token);
      // });
      //
      // FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      // FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      //
      // final initialMessage = await messaging.getInitialMessage();
      // if (initialMessage != null) {
      //   _handleMessageOpenedApp(initialMessage);
      // }

      _initialized = true;
    } catch (e) {
      logger.e('🔔 PushNotificationService init failed: $e');
    }
  }

  /// Отправить FCM токен на сервер POST /api/v1/auth/devices/register
  Future<void> sendTokenToServer(String token) async {
    try {
      final apiClient = GetIt.instance<ApiClient>();
      final platform = Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'web';

      await apiClient.post('/api/v1/auth/devices/register', data: {
        'platform': platform,
        'push_token': token,
        'device_type': 'smartphone',
      });

      logger.i('🔔 Push token registered on server: $platform');
    } catch (e) {
      logger.e('🔔 Failed to register push token: $e');
    }
  }

  /// Обработка уведомления в foreground
  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String? ?? 'message';

    logger.i('🔔 Foreground push: type=$type, chatId=${data['chatId']}');

    // Локальное уведомление через flutter_local_notifications
    // (вызывает NotificationService.showNotification)
  }

  /// Обработка клика по уведомлению (app opened from background)
  void _handleMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    final chatId = data['chatId'] as String?;

    logger.i('🔔 Push opened: chatId=$chatId');

    // Навигация: GoRouter → /chat/:chatId
  }

  /// Подписка на тему (для broadcast уведомлений)
  Future<void> subscribeToTopic(String topic) async {
    // FirebaseMessaging.instance.subscribeToTopic(topic);
    logger.i('🔔 Subscribed to topic: $topic');
  }

  /// Отписка от темы
  Future<void> unsubscribeFromTopic(String topic) async {
    // FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    logger.i('🔔 Unsubscribed from topic: $topic');
  }
}

/// Placeholder для RemoteMessage — заменяется на firebase_messaging
class RemoteMessage {
  final Map<String, dynamic> data;
  RemoteMessage({this.data = const {}});
}
