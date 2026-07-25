import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// HapticService — сервис тактильной отдачи (haptic feedback)
///
/// Использует HapticFeedback из Flutter для:
/// - light: мягкий тап (нажатие кнопки, выбор чата)
/// - medium: средний удар (отправка сообщения, переключение)
/// - heavy: сильный удар (удаление, важное действие)
/// - error: вибрация ошибки (не удалось отправить, сбой)
/// - notification: вибрация уведомления (новое сообщение, звонок)
class HapticService {
  static final HapticService instance = HapticService._internal();
  HapticService._internal();

  bool _enabled = true;

  /// Включение/выключение haptic feedback
  bool get isEnabled => _enabled;

  void setEnabled(bool enabled) {
    _enabled = enabled;
    logger.d('📳 Haptic feedback ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Мягкий тап — нажатие кнопки, выбор чата, переключение таба
  Future<void> light() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Средний удар — отправка сообщения, ответ на звонок, toggle
  Future<void> medium() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Сильный удар — удаление сообщения, выход из чата, важное действие
  Future<void> heavy() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// Вибрация ошибки — не удалось отправить, E2EE ошибка, сбой сети
  Future<void> error() async {
    if (!_enabled) return;
    await HapticFeedback.vibrate();
  }

  /// Вибрация уведомления — новое сообщение, входящий звонок
  Future<void> notification() async {
    if (!_enabled) return;
    await HapticFeedback.notification();
  }

  /// Selection click — прокрутка, выбор элемента из списка
  Future<void> selectionClick() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Контекстные методы — привязка к конкретным действиям

  Future<void> onSendMessage() async => medium();
  Future<void> onReceiveMessage() async => notification();
  Future<void> onIncomingCall() async => heavy();
  Future<void> onCallAnswered() async => medium();
  Future<void> onCallEnded() async => light();
  Future<void> onReactionAdded() async => light();
  Future<void> onDeleteMessage() async => heavy();
  Future<void> onErrorOccurred() async => error();
  Future<void> onTabSwitch() async => selectionClick();
  Future<void> onChatOpened() async => light();
  Future<void> onVoiceRecordStart() async => medium();
  Future<void> onVoiceRecordStop() async => heavy();
  Future<void> onStickerSent() async => light();
  Future<void> onSwipeAction() async => selectionClick();

  // Static convenience methods for quick usage in widgets
  static Future<void> selection() async => instance.selectionClick();
  static Future<void> lightImpact() async => instance.light();
  static Future<void> mediumImpact() async => instance.medium();
  static Future<void> heavyImpact() async => instance.heavy();
}
