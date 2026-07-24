import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

/// Настройки хранилища — кэш, автоскачивание, управление
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
  double _cacheLimitGB = 1.0;
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
      body: ListView(children: [
        // Общее использование
        Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(width: 160, height: 160, child: CircularProgressIndicator(
              value: _totalUsed / (1024 * 1024), // relative to 1TB
              strokeWidth: 12,
              backgroundColor: context.colors.outlineVariant,
              color: context.colors.primary,
            )),
            Column(children: [
              Text(_formatMB(_totalUsed), style: context.typography.headlineMedium),
              Text('использовано', style: context.typography.bodySmall),
            ]),
          ]),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _UsageItem(label: 'Фото', size: _photosSizeMB, color: Colors.blue, onClear: () => _clearCategory('photos')),
            _UsageItem(label: 'Видео', size: _videosSizeMB, color: Colors.red, onClear: () => _clearCategory('videos')),
            _UsageItem(label: 'Файлы', size: _filesSizeMB, color: Colors.purple, onClear: () => _clearCategory('files')),
            _UsageItem(label: 'Голос', size: _voiceSizeMB, color: Colors.orange, onClear: () => _clearCategory('voice')),
            _UsageItem(label: 'Кэш', size: _cacheSizeMB, color: Colors.grey, onClear: _clearCache),
          ]),
        ])),
        const Divider(),

        _Section(title: 'Автоскачивание'),
        SwitchListTile(title: const Text('Фото'), subtitle: const Text('Скачивать автоматически'), value: _autoDownloadPhotos, onChanged: (v) => setState(() => _autoDownloadPhotos = v)),
        SwitchListTile(title: const Text('Голосовые'), value: _autoDownloadVoice, onChanged: (v) => setState(() => _autoDownloadVoice = v)),
        SwitchListTile(title: const Text('Видео'), subtitle: const Text('Может расходовать много трафика'), value: _autoDownloadVideos, onChanged: (v) => setState(() => _autoDownloadVideos = v)),
        const Divider(),

        _Section(title: 'Лимиты автоскачивания'),
        ListTile(title: const Text('По Wi-Fi'), subtitle: Text('До $_autoDownloadWifiLimitMB МБ'), trailing: const Icon(Icons.chevron_right), onTap: _pickWifiLimit),
        ListTile(title: const Text('По мобильной сети'), subtitle: Text('До $_autoDownloadMobileLimitMB МБ'), trailing: const Icon(Icons.chevron_right), onTap: _pickMobileLimit),
        const Divider(),

        _Section(title: 'Хранение медиа'),
        ListTile(title: const Text('Хранить медиа'), subtitle: Text(_keepMediaDays == 0 ? 'Всегда' : '$_keepMediaDays дней'), trailing: const Icon(Icons.chevron_right), onTap: _pickKeepDays),
        const Divider(),

        Padding(padding: const EdgeInsets.all(16), child: OutlinedButton.icon(
          onPressed: _clearCache,
          icon: const Icon(Icons.cleaning_services),
          label: Text('Очистить кэш (${_formatMB(_cacheSizeMB)})'),
        )),
      ]),
    );
  }

  void _clearCache() => setState(() => _cacheSizeMB = 0);
  void _clearCategory(String cat) => setState(() {
    switch (cat) {
      case 'photos': _photosSizeMB = 0; break;
      case 'videos': _videosSizeMB = 0; break;
      case 'files': _filesSizeMB = 0; break;
      case 'voice': _voiceSizeMB = 0; break;
    }
  });

  void _pickWifiLimit() => showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [5, 10, 25, 50, 100].map((v) => ListTile(
    title: Text('До $v МБ'), trailing: _autoDownloadWifiLimitMB == v ? Icon(Icons.check, color: context.colors.primary) : null,
    onTap: () { setState(() => _autoDownloadWifiLimitMB = v); Navigator.pop(ctx); },
  )).toList())));

  void _pickMobileLimit() => showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [1, 5, 10, 25].map((v) => ListTile(
    title: Text('До $v МБ'), trailing: _autoDownloadMobileLimitMB == v ? Icon(Icons.check, color: context.colors.primary) : null,
    onTap: () { setState(() => _autoDownloadMobileLimitMB = v); Navigator.pop(ctx); },
  )).toList())));

  void _pickKeepDays() => showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
    MapEntry(0, 'Всегда'), MapEntry(7, '7 дней'), MapEntry(30, '30 дней'), MapEntry(90, '90 дней'),
  ].map((e) => ListTile(
    title: Text(e.value), trailing: _keepMediaDays == e.key ? Icon(Icons.check, color: context.colors.primary) : null,
    onTap: () { setState(() => _keepMediaDays = e.key); Navigator.pop(ctx); },
  )).toList())));
}

class _UsageItem extends StatelessWidget {
  final String label;
  final double size;
  final Color color;
  final VoidCallback onClear;
  const _UsageItem({required this.label, required this.size, required this.color, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final mb = size >= 1024 ? '${(size / 1024).toStringAsFixed(1)} Г' : '${size.toStringAsFixed(0)} М';
    return GestureDetector(onTap: onClear, child: Column(children: [
      Container(width: 8, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 4),
      Text(mb, style: context.typography.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      Text(label, style: context.typography.bodySmall),
    ]));
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 4), child: Text(title, style: context.typography.labelMedium?.copyWith(color: context.colors.primary)));
}
