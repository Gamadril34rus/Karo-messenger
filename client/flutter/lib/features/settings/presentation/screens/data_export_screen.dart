import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';

/// Экран экспорта данных пользователя — GDPR Art.20, ФЗ-152 Art.14, CCPA
///
/// Пользователь может скачать все свои данные в формате JSON:
/// профиль, контакты, чаты, сообщения, настройки приватности, согласия
class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  bool _isExporting = false;
  Map<String, dynamic>? _exportData;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Экспорт данных')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header icon
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.download_outlined, color: Color(0xFF3B82F6), size: 40),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Экспорт ваших данных',
            style: context.typography.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Вы имеете право получить копию всех ваших персональных данных, '
            'которые ЧАРО хранит о вас. Это ваше право по:\n'
            '• ФЗ-152 Ст.14 (Россия)\n'
            '• GDPR Art.20 (EU)\n'
            '• CCPA §1798.100 (Калифорния)',
            style: context.typography.bodyMedium?.copyWith(
              color: context.colors.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Export button
          if (_exportData == null && _errorMessage == null)
            FilledButton.icon(
              onPressed: _isExporting ? null : _startExport,
              icon: _isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download),
              label: Text(_isExporting ? 'Экспортирование...' : 'Скачать мои данные'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
              ),
            ),

          // Error display
          if (_errorMessage != null)
            CharoCard(
              borderWidth: 1.5,
              borderColor: context.colors.error.withOpacity(0.4),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: context.colors.error, size: 32),
                  const SizedBox(height: 8),
                  Text(_errorMessage!, style: context.typography.bodyMedium?.copyWith(color: context.colors.error)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _startExport,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Попробовать ещё раз'),
                  ),
                ],
              ),
            ),

          // Exported data preview
          if (_exportData != null)
            _buildExportResult(context),
        ],
      ),
    );
  }

  Widget _buildExportResult(BuildContext context) {
    final exportDate = _exportData!['export_date'] as String? ?? '';
    final user = _exportData!['user'] as Map<String, dynamic>? ?? {};
    final contactsCount = (_exportData!['contacts'] as List?)?.length ?? 0;
    final chatsCount = (_exportData!['chats'] as List?)?.length ?? 0;
    final messagesCount = (_exportData!['own_messages'] as List?)?.length ?? 0;
    final consentsCount = (_exportData!['consent_records'] as List?)?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success indicator
        CharoCard(
          borderWidth: 2,
          borderColor: context.colors.success.withOpacity(0.4),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.check_circle, color: context.colors.success, size: 40),
              const SizedBox(height: 8),
              Text('Данные экспортированы', style: context.typography.titleMedium?.copyWith(
                color: context.colors.success,
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 4),
              Text('Дата экспорта: ${exportDate}', style: context.typography.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Data summary
        CharoSection(
          title: 'Содержимое экспорта',
          children: [
            CharoTile(
              icon: Icons.person_outline,
              iconColor: context.colors.primary,
              title: 'Профиль',
              subtitle: '${user['username'] ?? ''} — ${user['display_name'] ?? ''}',
              trailing: Text('1', style: context.typography.labelLarge),
            ),
            CharoTile(
              icon: Icons.people_outline,
              iconColor: const Color(0xFF10B981),
              title: 'Контакты',
              subtitle: 'Список всех контактов',
              trailing: Text('$contactsCount', style: context.typography.labelLarge),
            ),
            CharoTile(
              icon: Icons.chat_bubble_outline,
              iconColor: const Color(0xFF3B82F6),
              title: 'Чаты',
              subtitle: 'Чаты и группы, где вы участвуете',
              trailing: Text('$chatsCount', style: context.typography.labelLarge),
            ),
            CharoTile(
              icon: Icons.message_outlined,
              iconColor: const Color(0xFFF59E0B),
              title: 'Сообщения',
              subtitle: 'Только ваши сообщения (E2EE-содержимое не доступно серверу)',
              trailing: Text('$messagesCount', style: context.typography.labelLarge),
            ),
            CharoTile(
              icon: Icons.lock_outline,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Настройки приватности',
              subtitle: 'Ваши настройки видимости и доступа',
              trailing: Text('1', style: context.typography.labelLarge),
            ),
            CharoTile(
              icon: Icons.check_circle_outline,
              iconColor: context.colors.success,
              title: 'Записи согласий',
              subtitle: 'ФЗ-152 Art.9, GDPR Art.7 — история согласий',
              trailing: Text('$consentsCount', style: context.typography.labelLarge),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // E2EE notice
        CharoCard(
          borderWidth: 1,
          borderColor: context.colors.warning.withOpacity(0.3),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.enhanced_encryption, color: context.colors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'E2EE-шифрованное содержимое сообщений не может быть экспортировано '
                  'с сервера — ключи шифрования хранятся только на ваших устройствах. '
                  'Для полного экспорта сообщений используйте локальный экспорт в чате.',
                  style: context.typography.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Actions
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _downloadToFile,
                icon: const Icon(Icons.download),
                label: const Text('Сохранить файл'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareData,
                icon: const Icon(Icons.share),
                label: const Text('Поделиться'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _startExport,
          icon: const Icon(Icons.refresh),
          label: const Text('Экспортировать ещё раз'),
        ),
      ],
    );
  }

  Future<void> _startExport() async {
    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    try {
      final sl = GetIt.instance;
      final apiClient = sl<ApiClient>();
      final response = await apiClient.get('/api/v1/auth/export-data');

      setState(() {
        _exportData = response.asMap;
        _isExporting = false;
      });

      logger.i('Data export completed');
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка экспорта: $e';
        _isExporting = false;
      });
      logger.e('Data export failed: $e');
    }
  }

  void _shareData() {
    if (_exportData == null) return;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_exportData!);
    SharePlus.instance.share(ShareParams(text: jsonStr));
  }

  Future<void> _downloadToFile() async {
    if (_exportData == null) return;
    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(_exportData!);
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final file = File('${directory.path}/charo_data_export_$timestamp.json');
      await file.writeAsString(jsonStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Данные сохранены: ${file.path}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Поделиться',
              onPressed: () {
                SharePlus.instance.share(ShareParams(text: jsonStr));
              },
            ),
          ),
        );
      }
      logger.i('Data export saved to ${file.path}');
    } catch (e) {
      logger.e('Data export file save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
  }
}
