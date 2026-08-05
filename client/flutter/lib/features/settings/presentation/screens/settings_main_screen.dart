// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Главный экран настроек — премиальный вид с grouped sections,
/// CharoCard группами, gradient header, и premium tiles.
class SettingsMainScreen extends StatelessWidget {
  const SettingsMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAccountDeleted) {
          _showRecoveryCodeDialog(context, state.accountId, state.recoveryCode);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: context.colors.error),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Настройки')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ── Profile header card ───────────────────────────────
            CharoCard(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(16),
              radius: 20,
              gradientColors: [
                context.colors.primary.withOpacity(0.08),
                context.colors.secondary.withOpacity(0.05),
                context.colors.outlineVariant,
              ],
              child: InkWell(
                onTap: () => context.go('/profile'),
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    CharoAvatar(
                      radius: 32,
                      fallbackText: 'П',
                      showRing: true,
                      ringWidth: 2,
                      ringColors: [context.colors.primary, context.colors.secondary],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Пользователь', style: context.typography.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                          const SizedBox(height: 2),
                          Text('@username', style: context.typography.bodyMedium?.copyWith(
                            color: context.colors.onSurface.withOpacity(0.6),
                          )),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.colors.outline,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.chevron_right, size: 20, color: context.colors.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            ),

            // ── Account & privacy ─────────────────────────────────
            CharoSection(
              title: 'Аккаунт и приватность',
              children: [
                CharoTile(
                  icon: Icons.lock_outline,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Конфиденциальность',
                  subtitle: 'Кто видит профиль, кто может писать',
                  onTap: () => context.go('/settings/privacy'),
                ),
                CharoTile(
                  icon: Icons.notifications_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Уведомления',
                  subtitle: 'Звуки, вибрация, тихие часы',
                  onTap: () => context.go('/settings/notifications'),
                ),
                CharoTile(
                  icon: Icons.devices_outlined,
                  iconColor: const Color(0xFF06B6D4),
                  title: 'Устройства',
                  subtitle: 'Активные сессии',
                  onTap: () => context.go('/settings/privacy'),
                ),
                CharoTile(
                  icon: Icons.security_outlined,
                  iconColor: const Color(0xFF10B981),
                  title: 'Двухфакторная аутентификация',
                  subtitle: 'Защита аккаунта',
                  onTap: () => context.go('/settings/privacy'),
                ),
              ],
            ),

            // ── Appearance ─────────────────────────────────────────
            CharoSection(
              title: 'Внешний вид',
              children: [
                CharoTile(
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFFEC4899),
                  title: 'Оформление',
                  subtitle: 'Тема, цвет акцента, фон чатов',
                  onTap: () => context.go('/settings/appearance'),
                ),
                CharoTile(
                  icon: Icons.text_fields,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Размер текста',
                  subtitle: 'Крошечный — огромный',
                  onTap: () => context.go('/settings/appearance'),
                ),
                CharoTile(
                  icon: Icons.language,
                  iconColor: const Color(0xFF2563EB),
                  title: 'Язык',
                  subtitle: 'Русский',
                  onTap: () => context.go('/settings/language'),
                ),
              ],
            ),

            // ── Chats ──────────────────────────────────────────────
            CharoSection(
              title: 'Чаты',
              children: [
                CharoTile(
                  icon: Icons.chat_bubble_outline,
                  iconColor: const Color(0xFF2563EB),
                  title: 'Настройки чатов',
                  subtitle: 'Архив, папки, поведение',
                  onTap: () => context.go('/settings/storage'),
                ),
                CharoTile(
                  icon: Icons.emoji_emotions_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Стикеры и эмодзи',
                  subtitle: 'Управление паками, импорт',
                  onTap: () => context.go('/chats'),
                ),
              ],
            ),

            // ── Media & storage ────────────────────────────────────
            CharoSection(
              title: 'Медиа и хранилище',
              children: [
                CharoTile(
                  icon: Icons.photo_size_select_large_outlined,
                  iconColor: const Color(0xFFEF4444),
                  title: 'Качество медиа',
                  subtitle: 'Фото, видео, голос при отправке',
                  onTap: () => context.go('/settings/media-quality'),
                ),
                CharoTile(
                  icon: Icons.storage_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Хранилище',
                  subtitle: 'Кэш, автоскачивание, лимиты',
                  onTap: () => context.go('/settings/storage'),
                ),
              ],
            ),

            // ── Network ────────────────────────────────────────────
            CharoSection(
              title: 'Сеть и доступность',
              children: [
                CharoTile(
                  icon: Icons.wifi_outlined,
                  iconColor: const Color(0xFF10B981),
                  title: 'Сеть и прокси',
                  subtitle: 'Прокси, VPN, DNS, приоритет Wi-Fi',
                  onTap: () => context.go('/settings/network'),
                ),
                CharoTile(
                  icon: Icons.battery_charging_full,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Энергопотребление',
                  subtitle: 'Режим экономии, фоновые процессы',
                  onTap: () => context.go('/settings/energy'),
                ),
                CharoTile(
                  icon: Icons.visibility_outlined,
                  iconColor: const Color(0xFF06B6D4),
                  title: 'Доступность',
                  subtitle: 'Статус, автоответчик',
                  onTap: () => context.go('/settings/notifications'),
                ),
              ],
            ),

            // ── AI assistant ───────────────────────────────────────
            CharoSection(
              title: 'AI-ассистент',
              children: [
                CharoTile(
                  icon: Icons.smart_toy_outlined,
                  iconColor: context.colors.primary,
                  title: 'Настройки AI',
                  subtitle: 'Модель, голос, поведение',
                  onTap: () => context.go('/ai'),
                ),
              ],
            ),

            // ── About ──────────────────────────────────────────────
            CharoSection(
              title: 'О ЧАРО',
              children: [
                CharoTile(
                  icon: Icons.info_outline,
                  iconColor: context.colors.primary,
                  title: 'О ЧАРО',
                  subtitle: 'Версия ${AppConstants.appVersion}',
                  onTap: () => context.go('/settings/about'),
                ),
              ],
            ),

            // ── Delete account ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: OutlinedButton.icon(
                onPressed: () => _showDeleteAccountDialog(context),
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('Удалить аккаунт', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Удалить аккаунт?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Это действие можно отменить в течение 30 дней с помощью '
              'кода восстановления.\n\n'
              'Что будет удалено:\n'
              '• Все сообщения\n'
              '• Все медиа-файлы\n'
              '• Контакты и настройки\n'
              '• Ключи шифрования\n\n'
              'Введите DELETE для подтверждения:',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'DELETE'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (controller.text == 'DELETE') {
                Navigator.pop(ctx);
                context.read<AuthBloc>().add(const AuthDeleteAccountRequested(confirmation: 'DELETE'));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить навсегда'),
          ),
        ],
      ),
    );
  }

  void _showRecoveryCodeDialog(BuildContext context, String accountId, String recoveryCode) {
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
              '• Код действителен 30 дней\n'
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
