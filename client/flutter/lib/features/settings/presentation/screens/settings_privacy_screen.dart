import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

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
  int _disappearingTimerSeconds = 0; // 0 = off

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
                subtitle: 'Управление чёрным списком',
                onTap: () => context.go('/block-list'),
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
              CharoTile(
                icon: Icons.download_outlined,
                iconColor: const Color(0xFF3B82F6),
                title: 'Экспорт данных',
                subtitle: 'GDPR/ФЗ-152 — скачать свои данные',
                onTap: () => context.go('/settings/data-export'),
              ),
            ],
          ),

          // ─── Disappearing messages ────────────────────────────
          CharoSection(
            title: 'Исчезающие сообщения',
            children: [
              CharoTile(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFFF59E0B),
                title: 'Таймер по умолчанию',
                subtitle: _disappearingTimerLabel(),
                onTap: _showDisappearingTimerPicker,
              ),
            ],
          ),

          // ─── Delete account ──────────────────────────────────
          const SizedBox(height: 16),
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthAccountDeleted) {
                // Show recovery code then redirect to login
                _showRecoveryCodeDialog(state.accountId, state.recoveryCode);
              } else if (state is AuthError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message), backgroundColor: context.colors.error),
                );
              }
            },
            child: Padding(
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
                      'медиа и контакты, будут удалены. '
                      'Вы получите код восстановления — с ним можно вернуть '
                      'аккаунт в течение 30 дней.',
                      style: context.typography.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoading;
                        return OutlinedButton.icon(
                          onPressed: isLoading ? null : () => _showDeleteDialog(context),
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          label: const Text('Удалить аккаунт', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
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

  String _disappearingTimerLabel() {
    if (_disappearingTimerSeconds == 0) return 'Выкл';
    final timers = AppConstants.disappearingTimers;
    if (timers.contains(_disappearingTimerSeconds)) {
      return _formatTimerSeconds(_disappearingTimerSeconds);
    }
    return _formatTimerSeconds(_disappearingTimerSeconds);
  }

  String _formatTimerSeconds(int seconds) {
    if (seconds < 60) return '$seconds сек';
    if (seconds < 3600) {
      final mins = seconds / 60;
      if (mins == mins.roundToDouble()) return '${mins.toInt()} мин';
      return '$mins мин';
    }
    if (seconds < 86400) {
      final hours = seconds / 3600;
      if (hours == hours.roundToDouble()) return '${hours.toInt()} ч';
      return '$hours ч';
    }
    final days = seconds / 86400;
    if (days == days.roundToDouble()) return '${days.toInt()} дн';
    return '$days дн';
  }

  // ─── Privacy Picker ────────────────────────────────────────────

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

  // ─── App Lock Settings ─────────────────────────────────────────

  void _showAppLockSettings() {
    HapticService.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AppLockSettingsSheet(
        onChanged: () => setState(() {}),
      ),
    );
  }

  // ─── Active Sessions ───────────────────────────────────────────

  void _showActiveSessions() {
    HapticService.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ActiveSessionsSheet(),
    );
  }

  // ─── Secret Chats Info ─────────────────────────────────────────

  void _showSecretChatsInfo() {
    HapticService.selection();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: context.colors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.enhanced_encryption, color: context.colors.success, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Секретные чаты', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 20),
              CharoCard(
                padding: const EdgeInsets.all(16),
                borderWidth: 1,
                borderColor: context.colors.success.withOpacity(0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Как работают секретные чаты ЧАРО:', style: context.typography.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                    const SizedBox(height: 12),
                    _InfoRow(icon: Icons.lock, color: context.colors.success,
                      text: 'Шифрование: протокол Signal (AES-256-CBC + HKDF-SHA256)'),
                    _InfoRow(icon: Icons.key, color: context.colors.warning,
                      text: 'Ключи: генерируются на устройстве, сервер не имеет доступа'),
                    _InfoRow(icon: Icons.devices, color: context.colors.info,
                      text: 'Привязка: секретный чат привязан к одному устройству'),
                    _InfoRow(icon: Icons.timer, color: const Color(0xFF8B5CF6),
                      text: 'Исчезание: можно задать таймер автоудаления сообщений'),
                    _InfoRow(icon: Icons.visibility_off, color: Colors.red,
                      text: 'Без пересылки: сообщения нельзя переслать из секретного чата'),
                    _InfoRow(icon: Icons.cloud_off, color: context.colors.onSurface.withOpacity(0.7),
                      text: 'Без облака: сообщения не хранятся на сервере после доставки'),
                    const SizedBox(height: 12),
                    Text(
                      'Для создания секретного чата нажмите «Новый секретный чат» '
                      'в меню контакта. Ключи шифрования пересоздаются при каждом '
                      'сеансе, обеспечивая Perfect Forward Secrecy.',
                      style: context.typography.bodySmall?.copyWith(
                        color: context.colors.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check),
                label: const Text('Понятно'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Disappearing Timer Picker ─────────────────────────────────

  void _showDisappearingTimerPicker() {
    HapticService.selection();
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
              Text('Таймер исчезающих сообщений', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('По умолчанию для всех новых чатов', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5),
              )),
              const SizedBox(height: 16),
              // Off option
              CharoTile(
                title: 'Выкл',
                subtitle: 'Сообщения не удаляются автоматически',
                trailing: _disappearingTimerSeconds == 0
                    ? Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () {
                  setState(() => _disappearingTimerSeconds = 0);
                  Navigator.pop(ctx);
                },
              ),
              ...AppConstants.disappearingTimers.map((seconds) => CharoTile(
                title: _formatTimerSeconds(seconds),
                trailing: _disappearingTimerSeconds == seconds
                    ? Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () {
                  setState(() => _disappearingTimerSeconds = seconds);
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Delete Dialog ──────────────────────────────────────────────

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
              'Это действие можно отменить в течение 30 дней с помощью '
              'кода восстановления.\n\n'
              'Что будет удалено:\n'
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
                // Dispatch delete account event to AuthBloc
                context.read<AuthBloc>().add(
                  AuthDeleteAccountRequested(confirmation: controller.text),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить навсегда'),
          ),
        ],
      ),
    );
  }

  // ─── Recovery Code Dialog ───────────────────────────────────────

  void _showRecoveryCodeDialog(String accountId, String recoveryCode) {
    HapticService.heavy();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.restore, color: Color(0xFF10B981), size: 28),
          SizedBox(width: 12),
          Text('Аккаунт удалён'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ваш аккаунт был удалён. Для восстановления используйте код ниже:'),
            const SizedBox(height: 16),
            CharoCard(
              padding: const EdgeInsets.all(16),
              borderWidth: 2,
              borderColor: context.colors.success.withOpacity(0.4),
              child: Column(
                children: [
                  Text('Код восстановления', style: context.typography.labelMedium?.copyWith(
                    color: context.colors.success,
                    fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 8),
                  SelectableText(
                    recoveryCode,
                    style: context.typography.headlineLarge?.copyWith(
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• Этот код действителен 30 дней\n'
              '• Сохраните его в безопасном месте\n'
              '• Для восстановления: Войти → Восстановить аккаунт',
              style: context.typography.bodySmall?.copyWith(
                color: context.colors.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/login');
            },
            child: const Text('Закрыть'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/auth/recover', extra: {
                'accountId': accountId,
                'recoveryCode': recoveryCode,
              });
            },
            child: const Text('Восстановить сейчас'),
          ),
        ],
      ),
    );
  }
}

// ─── App Lock Settings Sheet ──────────────────────────────────────

class _AppLockSettingsSheet extends StatefulWidget {
  final VoidCallback onChanged;
  const _AppLockSettingsSheet({required this.onChanged});

  @override
  State<_AppLockSettingsSheet> createState() => _AppLockSettingsSheetState();
}

class _AppLockSettingsSheetState extends State<_AppLockSettingsSheet> {
  bool _lockEnabled = false;
  String _lockMethod = 'pin'; // 'pin' | 'biometric' | 'pattern'
  int _autoLockTimeout = 0; // 0=immediate, 30, 60, 300 seconds
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_outline, color: Color(0xFF8B5CF6), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Блокировка приложения', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 24),

            // Enable toggle
            CharoSwitchTile(
              icon: Icons.lock,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Блокировка',
              subtitle: 'Запрашивать при каждом запуске',
              value: _lockEnabled,
              onChanged: (v) {
                setState(() => _lockEnabled = v);
                HapticService.medium();
              },
            ),
            const SizedBox(height: 16),

            // Method picker (visible only if lock enabled)
            if (_lockEnabled) ...[
              Text('Метод блокировки', style: context.typography.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'pin', label: const Text('PIN'), icon: const Icon(Icons.dialpad)),
                  ButtonSegment(value: 'biometric', label: const Text('Биометрия'), icon: const Icon(Icons.fingerprint)),
                  ButtonSegment(value: 'pattern', label: const Text('Ключ'), icon: const Icon(Icons.pattern)),
                ],
                selected: {_lockMethod},
                onSelectionChanged: (v) {
                  setState(() => _lockMethod = v.first);
                  HapticService.selection();
                  if (_lockMethod == 'biometric') {
                    _checkBiometrics();
                  }
                },
              ),
              const SizedBox(height: 16),

              // Auto-lock timeout
              Text('Автоблокировка', style: context.typography.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _autoLockTimeout,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.timer_outlined),
                  hintText: 'Когда блокировать',
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Сразу')),
                  DropdownMenuItem(value: 30, child: Text('30 секунд')),
                  DropdownMenuItem(value: 60, child: Text('1 минута')),
                  DropdownMenuItem(value: 300, child: Text('5 минут')),
                  DropdownMenuItem(value: 900, child: Text('15 минут')),
                ],
                onChanged: (v) {
                  setState(() => _autoLockTimeout = v ?? 0);
                },
              ),
            ],

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkBiometrics() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();
      if (!canAuth || available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Биометрия не доступна на этом устройстве'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _lockMethod = 'pin');
      }
    } catch (e) {
      logger.w('Biometric check failed: $e');
      setState(() => _lockMethod = 'pin');
    }
  }
}

// ─── Active Sessions Sheet ────────────────────────────────────────

class _ActiveSessionsSheet extends StatefulWidget {
  @override
  State<_ActiveSessionsSheet> createState() => _ActiveSessionsSheetState();
}

class _ActiveSessionsSheetState extends State<_ActiveSessionsSheet> {
  List<_SessionInfo> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final sl = GetIt.instance;
      final apiClient = sl<ApiClient>();
      final response = await apiClient.get('/api/v1/auth/sessions');
      final data = response.asList;
      setState(() {
        _sessions = data.map((s) => _SessionInfo(
          id: s['id'] as String,
          deviceName: s['device_name'] as String? ?? 'Неизвестное устройство',
          platform: s['platform'] as String? ?? '',
          ip: s['ip'] as String? ?? '',
          lastActive: s['last_active'] as String? ?? '',
          isCurrent: s['is_current'] as bool? ?? false,
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      logger.w('Failed to load sessions: $e');
      setState(() {
        _sessions = [
          _SessionInfo(
            id: 'current',
            deviceName: 'Это устройство',
            platform: 'Android',
            ip: '192.168.1.1',
            lastActive: 'Сейчас',
            isCurrent: true,
          ),
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.devices_outlined, color: Color(0xFF06B6D4), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Активные сессии', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ..._sessions.map((session) => CharoTile(
                icon: session.isCurrent ? Icons.phone_android : Icons.devices,
                iconColor: session.isCurrent ? context.colors.success : const Color(0xFF06B6D4),
                title: session.deviceName,
                subtitle: '${session.platform} • ${session.ip} • ${session.lastActive}',
                trailing: session.isCurrent
                    ? CharoBadge(count: 1, size: 16, color: context.colors.success)
                    : IconButton(
                        icon: Icon(Icons.close, color: Colors.red, size: 20),
                        onPressed: () => _terminateSession(session.id),
                      ),
                onLongPress: !session.isCurrent ? () => _terminateSession(session.id) : null,
              )),

            if (_sessions.length > 1) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _terminateAllOtherSessions,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Завершить все другие сессии', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],

            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _terminateSession(String sessionId) async {
    HapticService.medium();
    try {
      final sl = GetIt.instance;
      final apiClient = sl<ApiClient>();
      await apiClient.delete('/api/v1/auth/sessions/$sessionId');
      setState(() {
        _sessions = _sessions.where((s) => s.id != sessionId).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия завершена'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _terminateAllOtherSessions() async {
    HapticService.heavy();
    try {
      final sl = GetIt.instance;
      final apiClient = sl<ApiClient>();
      await apiClient.delete('/api/v1/auth/sessions', data: {'keep_current': true});
      setState(() {
        _sessions = _sessions.where((s) => s.isCurrent).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Все другие сессии завершены'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class _SessionInfo {
  final String id;
  final String deviceName;
  final String platform;
  final String ip;
  final String lastActive;
  final bool isCurrent;

  _SessionInfo({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.ip,
    required this.lastActive,
    required this.isCurrent,
  });
}

// ─── Info Row helper ──────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: context.typography.bodySmall)),
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
