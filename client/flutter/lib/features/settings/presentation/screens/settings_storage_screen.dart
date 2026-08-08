// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Настройки хранилища — премиальный UI с CharoProgressRing и grouped sections
class SettingsStorageScreen extends StatefulWidget {
  const SettingsStorageScreen({super.key});

  @override
  State<SettingsStorageScreen> createState() => _SettingsStorageScreenState();
}

class _SettingsStorageScreenState extends State<SettingsStorageScreen> {
  double _cacheSizeMB = 156.7;
  double _photosSizeMB = 2340.5;
  double _videosSizeMB = 5678.2;
  double _filesSizeMB = 432.1;
  double _voiceSizeMB = 89.3;
  double _stickersSizeMB = 67.8;
  bool _autoDownloadPhotos = true;
  bool _autoDownloadVoice = true;
  bool _autoDownloadVideos = false;
  int _autoDownloadWifiLimitMB = AppConstants.autoDownloadWifiMaxMB;
  int _autoDownloadMobileLimitMB = AppConstants.autoDownloadMobileMaxMB;
  int _keepMediaDays = 30;

  double get _totalUsed => _cacheSizeMB + _photosSizeMB + _videosSizeMB + _filesSizeMB + _voiceSizeMB + _stickersSizeMB;
  String _formatMB(double mb) => mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} ГБ' : '${mb.toStringAsFixed(1)} МБ';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Хранилище')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Circular progress with total used ────────────────
          CharoCard(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            padding: const EdgeInsets.all(24),
            radius: 20,
            gradientColors: [
              context.colors.primary.withOpacity(0.06),
              context.colors.outlineVariant,
            ],
            child: Column(
              children: [
                CharoProgressRing(
                  value: _totalUsed,
                  max: 1024 * 1024,
                  centerLabel: _formatMB(_totalUsed),
                  centerSublabel: 'использовано',
                  progressColor: context.colors.primary,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StorageBar(label: 'Фото', size: _photosSizeMB, color: Colors.blue),
                    _StorageBar(label: 'Видео', size: _videosSizeMB, color: Colors.red),
                    _StorageBar(label: 'Файлы', size: _filesSizeMB, color: Colors.purple),
                    _StorageBar(label: 'Голос', size: _voiceSizeMB, color: Colors.orange),
                    _StorageBar(label: 'Кэш', size: _cacheSizeMB, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),

          // ── Auto-download ────────────────────────────────────
          CharoSection(
            title: 'Автоскачивание',
            children: [
              CharoSwitchTile(
                icon: Icons.photo_outlined,
                iconColor: Colors.blue,
                title: 'Фото',
                subtitle: 'Скачивать автоматически',
                value: _autoDownloadPhotos,
                onChanged: (v) => setState(() => _autoDownloadPhotos = v),
              ),
              CharoSwitchTile(
                icon: Icons.headphones_outlined,
                iconColor: Colors.orange,
                title: 'Голосовые',
                value: _autoDownloadVoice,
                onChanged: (v) => setState(() => _autoDownloadVoice = v),
              ),
              CharoSwitchTile(
                icon: Icons.videocam_outlined,
                iconColor: Colors.red,
                title: 'Видео',
                subtitle: 'Может расходовать много трафика',
                value: _autoDownloadVideos,
                onChanged: (v) => setState(() => _autoDownloadVideos = v),
              ),
            ],
          ),

          // ── Limits ───────────────────────────────────────────
          CharoSection(
            title: 'Лимиты автоскачивания',
            children: [
              CharoTile(
                icon: Icons.wifi_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'По Wi-Fi',
                subtitle: 'До $_autoDownloadWifiLimitMB МБ',
                onTap: _pickWifiLimit,
              ),
              CharoTile(
                icon: Icons.signal_cellular_alt_outlined,
                iconColor: const Color(0xF59E0B),
                title: 'По мобильной сети',
                subtitle: 'До $_autoDownloadMobileLimitMB МБ',
                onTap: _pickMobileLimit,
              ),
            ],
          ),

          // ── Media retention ─────────────────────────────────
          CharoSection(
            title: 'Хранение медиа',
            children: [
              CharoTile(
                icon: Icons.auto_delete_outlined,
                iconColor: context.colors.primary,
                title: 'Хранить медиа',
                subtitle: _keepMediaDays == 0 ? 'Всегда' : '$_keepMediaDays дней',
                onTap: _pickKeepDays,
              ),
            ],
          ),

          // ── Clear cache button ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: FilledButton.icon(
              onPressed: _clearCache,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: Text('Очистить кэш (${_formatMB(_cacheSizeMB)})'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearCache() => setState(() => _cacheSizeMB = 0);

  void _pickWifiLimit() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Лимит по Wi-Fi', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...[5, 10, 25, 50, 100].map((v) => CharoTile(
              title: 'До $v МБ',
              trailing: _autoDownloadWifiLimitMB == v ? Icon(Icons.check_circle, color: context.colors.primary) : null,
              onTap: () { setState(() => _autoDownloadWifiLimitMB = v); Navigator.pop(ctx); },
            )),
          ],
        ),
      ),
    ),
  );

  void _pickMobileLimit() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Лимит по мобильной сети', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...[1, 5, 10, 25].map((v) => CharoTile(
              title: 'До $v МБ',
              trailing: _autoDownloadMobileLimitMB == v ? Icon(Icons.check_circle, color: context.colors.primary) : null,
              onTap: () { setState(() => _autoDownloadMobileLimitMB = v); Navigator.pop(ctx); },
            )),
          ],
        ),
      ),
    ),
  );

  void _pickKeepDays() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Хранение медиа', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...[
              MapEntry(0, 'Всегда'),
              MapEntry(7, '7 дней'),
              MapEntry(30, '30 дней'),
              MapEntry(90, '90 дней'),
            ].map((e) => CharoTile(
              title: e.value,
              trailing: _keepMediaDays == e.key ? Icon(Icons.check_circle, color: context.colors.primary) : null,
              onTap: () { setState(() => _keepMediaDays = e.key); Navigator.pop(ctx); },
            )),
          ],
        ),
      ),
    ),
  );
}

/// Storage bar indicator
class _StorageBar extends StatelessWidget {
  final String label;
  final double size;
  final Color color;
  const _StorageBar({required this.label, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    final mb = size >= 1024 ? '${(size / 1024).toStringAsFixed(1)} Г' : '${size.toStringAsFixed(0)} М';
    return Column(
      children: [
        Container(
          width: 8,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(mb, style: context.typography.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        Text(label, style: context.typography.bodySmall),
      ],
    );
  }
}
