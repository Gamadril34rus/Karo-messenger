import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

/// Настройки конфиденциальности — детальный контроль каждого аспекта
class SettingsPrivacyScreen extends StatefulWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  State<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends State<SettingsPrivacyScreen> {
  // Текущие настройки (заглушки, в реальности — из BLoC)
  String _profileVisibility = 'everyone';
  String _lastSeenVisibility = 'everyone';
  String _avatarVisibility = 'everyone';
  String _phoneVisibility = 'contacts';
  String _whoCanMessage = 'everyone';
  String _whoCanAddToGroups = 'contacts';
  String _whoCanCall = 'everyone';
  bool _readReceipts = true;
  bool _typingIndicator = true;
  bool _blockedUsersExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Конфиденциальность')),
      body: ListView(
        children: [
          // ─── Видимость профиля ────────────────────────────────
          _SectionHeader(title: 'Кто видит мою информацию'),
          _PrivacySelector(
            title: 'Профиль',
            subtitle: 'Имя, био, аватарка',
            value: _profileVisibility,
            onChanged: (v) => setState(() => _profileVisibility = v),
          ),
          _PrivacySelector(
            title: 'Был(а) в сети',
            subtitle: 'Время последнего посещения',
            value: _lastSeenVisibility,
            onChanged: (v) => setState(() => _lastSeenVisibility = v),
          ),
          _PrivacySelector(
            title: 'Аватарка',
            subtitle: 'Ваша фотография профиля',
            value: _avatarVisibility,
            onChanged: (v) => setState(() => _avatarVisibility = v),
          ),
          _PrivacySelector(
            title: 'Номер телефона',
            subtitle: 'Ваш номер в профиле',
            value: _phoneVisibility,
            onChanged: (v) => setState(() => _phoneVisibility = v),
          ),

          const Divider(height: 1),

          // ─── Кто может со мной связаться ──────────────────────
          _SectionHeader(title: 'Кто может со мной связаться'),
          _PrivacySelector(
            title: 'Кто может писать',
            subtitle: 'Личные сообщения',
            value: _whoCanMessage,
            onChanged: (v) => setState(() => _whoCanMessage = v),
          ),
          _PrivacySelector(
            title: 'Кто может добавлять в группы',
            subtitle: 'Приглашения в группы и каналы',
            value: _whoCanAddToGroups,
            onChanged: (v) => setState(() => _whoCanAddToGroups = v),
          ),
          _PrivacySelector(
            title: 'Кто может звонить',
            subtitle: 'Голосовые и видеозвонки',
            value: _whoCanCall,
            onChanged: (v) => setState(() => _whoCanCall = v),
          ),

          const Divider(height: 1),

          // ─── Индикаторы ───────────────────────────────────────
          _SectionHeader(title: 'Индикаторы'),
          SwitchListTile(
            title: const Text('Галочки прочтения'),
            subtitle: const Text('Показывать, когда вы прочитали сообщение'),
            value: _readReceipts,
            onChanged: (v) => setState(() => _readReceipts = v),
          ),
          SwitchListTile(
            title: const Text('Набор текста'),
            subtitle: const Text('Показывать, когда вы печатаете'),
            value: _typingIndicator,
            onChanged: (v) => setState(() => _typingIndicator = v),
          ),

          const Divider(height: 1),

          // ─── Заблокированные ──────────────────────────────────
          _SectionHeader(title: 'Заблокированные пользователи'),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text('Заблокированные'),
            subtitle: Text('0 пользователей'),
            trailing: const Icon(Icons.chevron_right),
    onLongPress: () => _showPrivacyAction(context, 'blocked'),
          ),

          const Divider(height: 1),

          // ─── Безопасность ─────────────────────────────────────
          _SectionHeader(title: 'Безопасность'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Блокировка приложения'),
            subtitle: const Text('PIN-код, биометрия, графический ключ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAppLockSettings,
          ),
          ListTile(
            leading: const Icon(Icons.devices_outlined),
            title: const Text('Активные сессии'),
            subtitle: const Text('Управление устройствами'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showActiveSessions,
          ),
          ListTile(
            leading: const Icon(Icons.enhanced_encryption),
            title: const Text('Секретные чаты'),
            subtitle: const Text('E2E-шифрование по протоколу Signal'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showSecretChatsInfo,
          ),

          const Divider(height: 1),

          // ─── Исчезающие сообщения ──────────────────────────────
          _SectionHeader(title: 'Исчезающие сообщения'),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Таймер по умолчанию'),
            subtitle: const Text('Выкл'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showDisappearingTimerPicker,
          ),

          const Divider(height: 1),

          // ─── Удаление аккаунта ─────────────────────────────────
          _SectionHeader(title: 'Удаление аккаунта'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'При удалении аккаунта все ваши данные, включая сообщения, '
              'медиа и контакты, будут безвозвратно удалены. Это действие '
              'необратимо и соответствует требованиям Play Market и App Store.',
              style: context.typography.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _showDeleteDialog(context),
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('Удалить аккаунт', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Удалить аккаунт?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Это действие необратимо. Все ваши данные будут удалены:\n\n'
              '• Все сообщения у всех участников чатов\n'
              '• Все медиа-файлы\n'
              '• Контакты и настройки\n'
              '• Ключи шифрования\n'
              '• Данные из резервных копий (в течение 30 дней)\n\n'
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
                context.read<AuthBloc>().add(const AuthDeleteAccountRequested(confirmation: 'DELETE'))
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

// ─── Селектор приватности ──────────────────────────────────────────

class _PrivacySelector extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final ValueChanged<String> onChanged;

  const _PrivacySelector({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: _buildChip(context),
      onTap: () => _showPicker(context),
    );
  }

  Widget _buildChip(BuildContext context) {
    final label = AppConstants.privacyLevels
        .firstWhere((l) => l['key'] == value)['label']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: context.typography.labelMedium?.copyWith(
          color: context.colors.primary,
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            ),
            ...AppConstants.privacyLevels.map((level) => ListTile(
                  title: Text(level['label']!),
                  trailing: value == level['key']
                      ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () {
                    onChanged(level['key']!);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title, style: context.typography.labelMedium?.copyWith(
        color: context.colors.primary,
      )),
    );
  }
}
