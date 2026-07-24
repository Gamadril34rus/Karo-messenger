import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

/// Настройки качества медиа — фото, видео, голос при отправке
class SettingsMediaQualityScreen extends StatefulWidget {
  const SettingsMediaQualityScreen({super.key});

  @override
  State<SettingsMediaQualityScreen> createState() => _SettingsMediaQualityScreenState();
}

class _SettingsMediaQualityScreenState extends State<SettingsMediaQualityScreen> {
  String _photoQuality = 'high';
  String _videoQuality = 'high';
  String _voiceQuality = 'high';
  bool _sendOriginalByDefault = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Качество медиа')),
      body: ListView(children: [
        _Section(title: 'Фото при отправке'),
        ..._buildQualityOptions('photo', _photoQuality, (v) => setState(() => _photoQuality = v)),
        const Divider(),
        _Section(title: 'Видео при отправке'),
        ..._buildQualityOptions('video', _videoQuality, (v) => setState(() => _videoQuality = v)),
        const Divider(),
        _Section(title: 'Голосовые сообщения'),
        ..._buildQualityOptions('voice', _voiceQuality, (v) => setState(() => _voiceQuality = v)),
        const Divider(),
        SwitchListTile(
          title: const Text('Отправлять как файл'),
          subtitle: const Text('Фото и видео без сжатия (оригинал)'),
          value: _sendOriginalByDefault,
          onChanged: (v) => setState(() => _sendOriginalByDefault = v),
        ),
        const SizedBox(height: 24),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.colors.outlineVariant, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.info_outline, size: 20, color: context.colors.primary),
              const SizedBox(width: 8),
              Text('Подсказка', style: context.typography.titleMedium),
            ]),
            const SizedBox(height: 8),
            Text('Вы можете изменить качество для каждого файла отдельно при отправке. Нажмите на скрепку → выберите файл → настройте качество перед отправкой.', style: context.typography.bodyMedium),
          ]),
        )),
      ]),
    );
  }

  List<Widget> _buildQualityOptions(String type, String current, ValueChanged<String> onChanged) {
    return AppConstants.mediaQuality.entries.map((entry) {
      final label = entry.value['label'] as String;
      final isSelected = current == entry.key;
      String detail = '';
      if (type == 'photo' && entry.value['photoMaxDim'] != null) {
        detail = 'до ${entry.value['photoMaxDim']}px, качество ${entry.value['photoQuality']}%';
      } else if (type == 'video' && entry.value['videoBitrate'] != null) {
        detail = '${(entry.value['videoBitrate'] as int) ~/ 1000} кбит/с';
      } else if (type == 'voice') {
        detail = entry.key == 'original' ? 'Без сжатия' : entry.key == 'high' ? 'Высокое' : entry.key == 'medium' ? 'Среднее' : 'Эконом';
      }
      return RadioListTile<String>(
        title: Text(label),
        subtitle: detail.isNotEmpty ? Text(detail, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))) : null,
        value: entry.key,
        groupValue: current,
        onChanged: (v) { if (v != null) onChanged(v); },
      );
    }).toList();
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 4), child: Text(title, style: context.typography.labelMedium?.copyWith(color: context.colors.primary)));
}
