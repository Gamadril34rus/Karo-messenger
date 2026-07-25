import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Настройки конфиденциальности — премиальный grouped layout
class SettingsPrivacyScreen extends StatefulWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  State<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends State<SettingsPrivacyScreen> {
  String _profileVisibility = 'everyone';
  String _lastSeenVisibility = 'everyone';
  String _avatarVisibility = 'everyone';
  String _phoneVisibility = 'contacts';
  String _whoCanMessage = 'everyone';
  String _whoCanAddToGroups = 'contacts';
  String _whoCanCall = 'everyone';
  bool _readReceipts = true;
  bool _typingIndicator = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Конфиденциальность')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ─── Who sees my info ────────────────────────────────
          CharoSection(
            title: 'Кто видит мою информацию',
            children: [
              CharoTile(
                icon: Icons.person_outline,
                iconColor: const Color(0xFF2563EB),
                title: 'Профиль',
                subtitle: 'Имя, био, аватарка — ${_privacyLabel(_profileVisibility)}',
                trailing: _PrivacyChip(value: _profileVisibility),
                onTap: () => _showPrivacyPicker('Профиль', _profileVisibility, (v) => setState(() => _profileVisibility = v)),
              ),
              CharoTile(
                icon: Icons.access_time,
                iconColor: const Color(0xFFF59E0B),
                title: 'Был(а) в сети',
                subtitle: 'Время последнего посещения — ${_privacyLabel(_lastSeenVisibility)}',
                trailing: _PrivacyChip(value: _lastSeenVisibility),
                onTap: () => _showPrivacyPicker('Был(а) в сети', _lastSeenVisibility, (v) => setState(() => _lastSeenVisibility = v)),
              ),
              CharoTile(
                icon: Icons.image_outlined,
                iconColor: const Color(0xFFEC4899),
                title: 'Аватарка',
                subtitle: 'Ваша фотография — ${_privacyLabel(_avatarVisibility)}',
                trailing: _PrivacyChip(value: _avatarVisibility),
                onTap: () => _showPrivacyPicker('Аватарка', _avatarVisibility, (v) => setState(() => _avatarVisibility = v)),
              ),
              CharoTile(
                icon: Icons.phone_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Номер телефона',
                subtitle: 'Ваш номер в профиле — ${_privacyLabel(_phoneVisibility)}',
                trailing: _PrivacyChip(value: _phoneVisibility),
                onTap: () => _showPrivacyPicker('Номер телефона', _phoneVisibility, (v) => setState(() => _phoneVisibility = v)),
              ),
            ],
          ),

          // ─── Who can contact me ──────────────────────────────
          CharoSection(
            title: 'Кто может со мной связаться',
            children: [
              CharoTile(
                icon: Icons.chat_bubble_outline,
                iconColor: const Color(0xFF3B82F6),
                title: 'Кто может писать',
                subtitle: 'Личные сообщения — ${_privacyLabel(_whoCanMessage)}',
                trailing: _PrivacyChip(value: _whoCanMessage),
                onTap: () => _showPrivacyPicker('Кто может писать', _whoCanMessage, (v) => setState(() => _whoCanMessage = v)),
              ),
              CharoTile(
                icon: Icons.group_outlined,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Кто может добавлять в группы',
                subtitle: 'Приглашения в группы — ${_privacyLabel(_whoCanAddToGroups)}',
                trailing: _PrivacyChip(value: _whoCanAddToGroups),
                onTap: () => _showPrivacyPicker('Добавление в группы', _whoCanAddToGroups, (v) => setState(() => _whoCanAddToGroups = v)),
              ),
              CharoTile(
                icon: Icons.call_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'Кто может звонить',
                subtitle: 'Голосовые и видеозвонки — ${_privacyLabel(_whoCanCall)}',
                trailing: _PrivacyChip(value: _whoCanCall),
                onTap: () => _showPrivacyPicker('Кто может звонить', _whoCanCall, (v) => setState(() => _whoCanCall = v)),
              ),
            ],
          ),

          // ─── Indicators ───────────────────────────────────────
          CharoSection(
            title: 'Индикаторы',
            children: [
              CharoSwitchTile(
                icon: Icons.done_all,
                iconColor: context.colors.primary,
                title: 'Галочки прочтения',
                subtitle: 'Показывать, когда вы прочитали сообщение',
                value: _readReceipts,
                onChanged: (v) => setState(() => _readReceipts = v),
              ),
              CharoSwitchTile(
                icon: Icons.keyboard_outlined,
                iconColor: const Color(0xFFF59E0B),
                title: 'Набор текста',
                subtitle: 'Показывать, когда вы печатаете',
                value: _typingIndicator,
                onChanged: (v) => setState(() => _typingIndicator = v),
              ),
            ],
          ),

          // ─── Blocked ──────────────────────────────────────────
          CharoSection(
            title: 'Заблокированные',
            children: [
              CharoTile(
                icon: Icons.block_outlined,
                iconColor: Colors.red,
                title: 'Заблокированные',
                subtitle: '0 пользователей',
                onTap: () {},
              ),
            ],
          ),

          // ─── Security ────────────────────────────────────────
          CharoSection(
            title: 'Безопасность',
            children: [
              CharoTile(
                icon: Icons.lock_outline,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Блокировка приложения',
                subtitle: 'PIN-код, биометрия, графический ключ',
                onTap: _showAppLockSettings,
              ),
              CharoTile(
                icon: Icons.devices_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'Активные сессии',
                subtitle: 'Управление устройствами',
                onTap: _showActiveSessions,
              ),
              CharoTile(
                icon: Icons.enhanced_encryption,
                iconColor: const Color(0xFF10B981),
                title: 'Секретные чаты',
                subtitle: 'E2E-шифрование по протоколу Signal',
                onTap: _showSecretChatsInfo,
              ),
            ],
          ),

          // ─── Disappearing messages ────────────────────────────
          CharoSection(
            title: 'Исчезающие сообщения',
            children: [
              CharoTile(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xF59E0B),
                title: 'Таймер по умолчанию',
                subtitle: 'Выкл',
                onTap: _showDisappearingTimerPicker,
              ),
            ],
          ),

          // ─── Delete account ──────────────────────────────────
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: CharoCard(
              padding: const EdgeInsets.all(16),
              borderWidth: 1.5,
              borderColor: Colors.red.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning_amber_outlined, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text('Удаление аккаунта', style: context.typography.titleMedium?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    )),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'При удалении аккаунта все ваши данные, включая сообщения, '
                    'медиа и контакты, будут безвозвратно удалены. Это действие '
                    'необратимо.',
                    style: context.typography.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showDeleteDialog(context),
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text('Удалить аккаунт', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _privacyLabel(String key) {
    return AppConstants.privacyLevels.firstWhere((l) => l['key'] == key)['label']!;
  }

  void _showPrivacyPicker(String title, String currentValue, ValueChanged<String> onChanged) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ...AppConstants.privacyLevels.map((level) => CharoTile(
                title: level['label']!,
                trailing: currentValue == level['key']
                    ? Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary)
                    : Icon(Icons.circle_outlined, size: 20, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3)),
                onTap: () {
                  onChanged(level['key']!);
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppLockSettings() {}
  void _showActiveSessions() {}
  void _showSecretChatsInfo() {}
  void _showDisappearingTimerPicker() {}

  void _showDeleteDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.red, size: 28),
          SizedBox(width: 12),
          Text('Удалить аккаунт?'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Это действие необратимо. Все ваши данные будут удалены:\n\n'
              '• Все сообщения у всех участников чатов\n'
              '• Все медиа-файлы\n'
              '• Контакты и настройки\n'
              '• Ключи шифрования\n\n'
              'Введите DELETE для подтверждения:',
            ),
            const SizedBox(height: 8),
            TextField(controller: controller, decoration: const InputDecoration(hintText: 'DELETE')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (controller.text == 'DELETE') {
                Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить навсегда'),
          ),
        ],
      ),
    );
  }
}

/// Small privacy chip indicator
class _PrivacyChip extends StatelessWidget {
  final String value;
  const _PrivacyChip({required this.value});

  @override
  Widget build(BuildContext context) {
    final label = AppConstants.privacyLevels.firstWhere((l) => l['key'] == value)['label']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: context.typography.labelMedium?.copyWith(
        color: context.colors.primary,
        fontWeight: FontWeight.w600,
      )),
    );
  }
}
