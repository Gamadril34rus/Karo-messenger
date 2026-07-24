import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../main.dart';

/// Главный экран настроек — все разделы
class SettingsMainScreen extends StatelessWidget {
  const SettingsMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          _ProfileHeader(onTap: () => context.go('/profile')),
          const Divider(height: 1),

          _Section(title: 'Аккаунт и приватность'),
          _Nav(icon: Icons.lock_outline, title: 'Конфиденциальность', subtitle: 'Кто видит профиль, кто может писать', route: '/settings/privacy'),
          _Nav(icon: Icons.notifications_outlined, title: 'Уведомления', subtitle: 'Звуки, вибрация, режимы', route: '/settings/notifications'),
          _Nav(icon: Icons.devices_outlined, title: 'Устройства', subtitle: 'Активные сессии', route: '/settings/privacy'),
          _Nav(icon: Icons.security_outlined, title: 'Двухфакторная аутентификация', subtitle: 'Защита аккаунта', route: '/settings/privacy'),

          const Divider(height: 1),
          _Section(title: 'Внешний вид'),
          _Nav(icon: Icons.palette_outlined, title: 'Оформление', subtitle: 'Тема, цвет акцента, фон чатов', route: '/settings/appearance'),
          _Nav(icon: Icons.text_fields, title: 'Размер текста', subtitle: 'Крошечный — огромный', route: '/settings/appearance'),
          _Nav(icon: Icons.language, title: 'Язык', subtitle: 'Русский', route: '/settings/language'),

          const Divider(height: 1),
          _Section(title: 'Чаты'),
          _Nav(icon: Icons.chat_bubble_outline, title: 'Настройки чатов', subtitle: 'Архив, папки, поведение', route: '/settings/storage'),
          _Nav(icon: Icons.emoji_emotions_outlined, title: 'Стикеры и эмодзи', subtitle: 'Управление паками, импорт', route: '/chats'),

          const Divider(height: 1),
          _Section(title: 'Медиа и хранилище'),
          _Nav(icon: Icons.photo_size_select_large_outlined, title: 'Качество медиа', subtitle: 'Фото, видео, голос при отправке', route: '/settings/media-quality'),
          _Nav(icon: Icons.storage_outlined, title: 'Хранилище', subtitle: 'Кэш, автоскачивание, лимиты', route: '/settings/storage'),

          const Divider(height: 1),
          _Section(title: 'Сеть и доступность'),
          _Nav(icon: Icons.wifi_outlined, title: 'Сеть и прокси', subtitle: 'Прокси, VPN, DNS, приоритет Wi-Fi', route: '/settings/network'),
          _Nav(icon: Icons.battery_alert_outlined, title: 'Энергопотребление', subtitle: 'Режим экономии, фоновые процессы', route: '/settings/energy'),
          _Nav(icon: Icons.visibility_outlined, title: 'Доступность', subtitle: 'Статус, автоответчик', route: '/settings/notifications'),

          const Divider(height: 1),
          _Section(title: 'AI-ассистент'),
          _Nav(icon: Icons.smart_toy_outlined, title: 'Настройки AI', subtitle: 'Модель, голос, поведение', route: '/ai'),

          const Divider(height: 1),
          _Section(title: 'О приложении'),
          _Nav(icon: Icons.info_outline, title: 'О Ауре', subtitle: 'Версия ${AppConstants.appVersion}', route: '/settings/about'),

          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _showDeleteAccountDialog(context),
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('Удалить аккаунт', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Удалить аккаунт?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Это действие необратимо. Все ваши данные, сообщения и медиа будут безвозвратно удалены.'),
        const SizedBox(height: 16),
        const Text('Введите DELETE для подтверждения:'),
        const SizedBox(height: 8),
        TextField(controller: controller, decoration: const InputDecoration(hintText: 'DELETE')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(onPressed: () {
          if (controller.text == 'DELETE') {
            Navigator.pop(ctx);
            sl<AuthBloc>().add(const AuthDeleteAccountRequested(confirmation: 'DELETE'));
          }
        }, style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Удалить навсегда')),
      ],
    ));
  }
}

class _Nav extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  const _Nav({required this.icon, required this.title, required this.subtitle, required this.route});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.colors.onSurface.withOpacity(0.7)),
      title: Text(title, style: context.typography.bodyLarge),
      subtitle: Text(subtitle, style: context.typography.bodySmall),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.go(route),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileHeader({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        CircleAvatar(radius: 32, backgroundColor: context.colors.primary.withOpacity(0.1),
          child: Icon(Icons.person, color: context.colors.primary, size: 32)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Пользователь', style: context.typography.titleLarge),
          const SizedBox(height: 2),
          Text('@username', style: context.typography.bodyMedium?.copyWith(color: context.colors.onSurface.withOpacity(0.6))),
        ])),
        const Icon(Icons.chevron_right),
      ])),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(title, style: context.typography.labelMedium?.copyWith(color: context.colors.primary)));
}
