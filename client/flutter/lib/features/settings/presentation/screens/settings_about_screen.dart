import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

/// Экран «О приложении» — версия, ссылки, лицензия
class SettingsAboutScreen extends StatelessWidget {
  const SettingsAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: ListView(children: [
        const SizedBox(height: 32),
        Center(child: Container(width: 80, height: 80, decoration: BoxDecoration(
          color: context.colors.primary, borderRadius: BorderRadius.circular(24),
        ), child: const Icon(Icons.auto_awesome, color: Colors.white, size: 48))),
        const SizedBox(height: 16),
        Center(child: Text('ЧАРО', style: context.typography.headlineLarge)),
        Center(child: Text('Версия ${AppConstants.appVersion} (${AppConstants.appBuildNumber})', style: context.typography.bodyMedium?.copyWith(color: context.colors.onSurface.withOpacity(0.5)))),
        const SizedBox(height: 32),
        ListTile(leading: const Icon(Icons.copyright), title: const Text('Лицензия'), subtitle: const Text('AGPL-3.0'), trailing: const Icon(Icons.chevron_right), onTap: () => _showLicense(context)),
        ListTile(leading: const Icon(Icons.code), title: const Text('Исходный код'), subtitle: const Text('github.com/charo-messenger/charo'), trailing: const Icon(Icons.open_in_new), onTap: () {}),
        ListTile(leading: const Icon(Icons.security), title: const Text('Политика конфиденциальности'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
        ListTile(leading: const Icon(Icons.description), title: const Text('Пользовательское соглашение'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
        const Divider(),
        ListTile(leading: const Icon(Icons.bug_report), title: const Text('Сообщить об ошибке'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
        ListTile(leading: const Icon(Icons.rate_review), title: const Text('Оставить отзыв'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
        const Divider(),
        ListTile(leading: const Icon(Icons.telegram), title: const Text('Telegram-канал'), subtitle: const Text('@charo_messenger'), trailing: const Icon(Icons.open_in_new), onTap: () {}),
        ListTile(leading: const Icon(Icons.language), title: const Text('Веб-сайт'), subtitle: const Text('charo.chat'), trailing: const Icon(Icons.open_in_new), onTap: () {}),
        const Divider(),
        Padding(padding: const EdgeInsets.all(24), child: Text(
          'ЧАРО — мессенджер нового поколения.\nБыстрый. Приватный. Мощный. Красивый. Твой.\n\n© 2024–2026',
          style: context.typography.bodySmall?.copyWith(color: context.colors.onSurface.withOpacity(0.4)),
          textAlign: TextAlign.center,
        )),
      ]),
    );
  }

  void _showLicense(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('AGPL-3.0'),
      content: const SingleChildScrollView(child: Text(
        'ЧАРО распространяется под лицензией GNU Affero General Public License v3.0.\n\n'
        'Это означает, что:\n'
        '• Вы можете свободно использовать, изучать и модифицировать приложение\n'
        '• Любые модификации должны распространяться под той же лицензией\n'
        '• Если вы запускаете модифицированную версию как сетевой сервис, '
        'вы обязаны предоставить исходный код пользователям\n\n'
        'Это гарантирует, что ЧАРО останется открытой навсегда.',
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно'))],
    ));
  }
}
