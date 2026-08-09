// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
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
  Future<void> _light() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Средний удар — отправка сообщения, ответ на звонок, toggle
  Future<void> _medium() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Сильный удар — удаление сообщения, выход из чата, важное действие
  Future<void> _heavy() async {
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
    await HapticFeedback.mediumImpact();
  }

  /// Selection click — прокрутка, выбор элемента из списка
  Future<void> selectionClick() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Контекстные методы — привязка к конкретным действиям

  Future<void> onSendMessage() async => _medium();
  Future<void> onReceiveMessage() async => notification();
  Future<void> onIncomingCall() async => _heavy();
  Future<void> onCallAnswered() async => _medium();
  Future<void> onCallEnded() async => _light();
  Future<void> onReactionAdded() async => _light();
  Future<void> onDeleteMessage() async => _heavy();
  Future<void> onErrorOccurred() async => error();
  Future<void> onTabSwitch() async => selectionClick();
  Future<void> onChatOpened() async => _light();
  Future<void> onVoiceRecordStart() async => _medium();
  Future<void> onVoiceRecordStop() async => _heavy();
  Future<void> onStickerSent() async => _light();
  Future<void> onSwipeAction() async => selectionClick();

  // Public convenience accessors
  Future<void> light() async => _light();
  Future<void> medium() async => _medium();
  Future<void> heavy() async => _heavy();
}
