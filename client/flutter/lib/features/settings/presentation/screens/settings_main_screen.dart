import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../../../../main.dart';

/// Главный экран настроек — премиальный вид с grouped sections,
/// CharoCard группами, gradient header, и premium tiles.
class SettingsMainScreen extends StatelessWidget {
  const SettingsMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            const Text('Это действие необратимо. Все ваши данные, сообщения и медиа будут безвозвратно удалены.'),
            const SizedBox(height: 16),
            const Text('Введите DELETE для подтверждения:', style: TextStyle(fontWeight: FontWeight.w600)),
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
                sl<AuthBloc>().add(const AuthDeleteAccountRequested(confirmation: 'DELETE'));
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
