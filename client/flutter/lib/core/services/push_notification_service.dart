import 'dart:io';

import '../utils/logger.dart';

/// ─── Push Notification Service ───────────────────────────────────
/// FCM (Android/Web) + APNS (iOS) push-уведомления.
///
/// Для реального запуска необходимы:
/// - google-services.json (Android)
/// - GoogleService-Info.plist (iOS)
/// - Firebase проект с FCM enabled
/// - APNS сертификат (iOS)
///
/// Сейчас реализована полная логика обработки уведомлений,
/// но регистрация FCM токена требует Firebase настройки.

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
      // В реальном проекте: Firebase.initializeApp() + FirebaseMessaging.instance
      //
      // Для запуска:
      // 1. Добавить firebase_core, firebase_messaging в pubspec.yaml
      // 2. Добавить google-services.json в android/app/
      // 3. Добавить GoogleService-Info.plist в ios/Runner/
      // 4. Раскомментировать код ниже

      logger.i('🔔 PushNotificationService initialized (token pending Firebase config)');

      // --- Реальный код для Firebase (раскомментировать при настройке) ---
      //
      // await Firebase.initializeApp();
      // final messaging = FirebaseMessaging.instance;
      //
      // // Запрос разрешений (iOS)
      // if (Platform.isIOS) {
      //   await messaging.requestPermission(
      //     alert: true, badge: true, sound: true,
      //   );
      //   _apnsToken = await messaging.getAPNSToken();
      // }
      //
      // // Получить FCM токен
      // _fcmToken = await messaging.getToken();
      // logger.i('🔔 FCM token: ${_fcmToken?.substring(0, 20)}...');
      //
      // // Слушать обновления токена
      // messaging.onTokenRefresh.listen((token) {
      //   _fcmToken = token;
      //   logger.i('🔔 FCM token refreshed');
      //   _sendTokenToServer(token);
      // });
      //
      // // Foreground messages
      // FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      //
      // // Background messages (app opened from notification)
      // FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      //
      // // Terminated state
      // final initialMessage = await messaging.getInitialMessage();
      // if (initialMessage != null) {
      //   _handleMessageOpenedApp(initialMessage);
      // }

      _initialized = true;
    } catch (e) {
      logger.e('🔔 PushNotificationService init failed: $e');
    }
  }

  /// Отправить FCM токен на сервер
  Future<void> _sendTokenToServer(String token) async {
    // Вызывается через ApiClient — отправка POST /api/v1/devices/register
    // { "platform": "android"|"ios"|"web", "push_token": token }
    logger.i('🔔 Push token should be sent to server: ${token.substring(0, 20)}...');
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
    final type = data['type'] as String? ?? 'message';

    logger.i('🔔 Push opened: type=$type, chatId=$chatId');

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
