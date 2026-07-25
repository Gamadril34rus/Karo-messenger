import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Экран «О ЧАРО» — премиальный вид с gradient header, grouped sections
class SettingsAboutScreen extends StatelessWidget {
  const SettingsAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('О ЧАРО')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Logo header ───────────────────────────────────────
          CharoHeaderCard(
            height: 200,
            radius: 24,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: context.colors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 12),
                Text('ЧАРО', style: context.typography.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                )),
                const SizedBox(height: 4),
                Text(
                  'Версия ${AppConstants.appVersion} (${AppConstants.appBuildNumber})',
                  style: context.typography.bodyMedium?.copyWith(
                    color: context.colors.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Legal ────────────────────────────────────────────
          CharoSection(
            title: 'Правовая информация',
            children: [
              CharoTile(
                icon: Icons.copyright_outlined,
                iconColor: context.colors.primary,
                title: 'Лицензия',
                subtitle: 'AGPL-3.0',
                onTap: () => _showLicense(context),
              ),
              CharoTile(
                icon: Icons.code_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Исходный код',
                subtitle: 'github.com/charo-messenger/charo',
                trailing: Icon(Icons.open_in_new, size: 18, color: context.colors.onSurface.withOpacity(0.4)),
                onTap: () {},
              ),
              CharoTile(
                icon: Icons.security_outlined,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Политика конфиденциальности',
                onTap: () {},
              ),
              CharoTile(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF3B82F6),
                title: 'Пользовательское соглашение',
                onTap: () {},
              ),
            ],
          ),

          // ── Feedback ──────────────────────────────────────────
          CharoSection(
            title: 'Обратная связь',
            children: [
              CharoTile(
                icon: Icons.bug_report_outlined,
                iconColor: Colors.red,
                title: 'Сообщить об ошибке',
                onTap: () {},
              ),
              CharoTile(
                icon: Icons.rate_review_outlined,
                iconColor: const Color(0xFFF59E0B),
                title: 'Оставить отзыв',
                onTap: () {},
              ),
            ],
          ),

          // ── Social ────────────────────────────────────────────
          CharoSection(
            title: 'Связаться с нами',
            children: [
              CharoTile(
                icon: Icons.telegram_outlined,
                iconColor: const Color(0xFF2563EB),
                title: 'Telegram-канал',
                subtitle: '@charo_messenger',
                trailing: Icon(Icons.open_in_new, size: 18, color: context.colors.onSurface.withOpacity(0.4)),
                onTap: () {},
              ),
              CharoTile(
                icon: Icons.language_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Веб-сайт',
                subtitle: 'charo.chat',
                trailing: Icon(Icons.open_in_new, size: 18, color: context.colors.onSurface.withOpacity(0.4)),
                onTap: () {},
              ),
            ],
          ),

          // ── Bottom quote ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'ЧАРО — мессенджер нового поколения.\n'
              'Быстрый. Приватный. Мощный. Красивый. Твой.\n\n'
              '© 2024–2026',
              style: context.typography.bodySmall?.copyWith(
                color: context.colors.onSurface.withOpacity(0.4),
                textAlign: TextAlign.center,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showLicense(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      ),
    );
  }
}
