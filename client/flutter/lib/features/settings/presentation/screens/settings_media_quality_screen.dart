import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Настройки качества медиа — премиальный grouped layout
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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          CharoSection(
            title: 'Фото при отправке',
            children: _buildQualityTiles('photo', _photoQuality, (v) => setState(() => _photoQuality = v)),
          ),

          CharoSection(
            title: 'Видео при отправке',
            children: _buildQualityTiles('video', _videoQuality, (v) => setState(() => _videoQuality = v)),
          ),

          CharoSection(
            title: 'Голосовые сообщения',
            children: _buildQualityTiles('voice', _voiceQuality, (v) => setState(() => _voiceQuality = v)),
          ),

          CharoSection(
            title: 'Дополнительные',
            children: [
              CharoSwitchTile(
                icon: Icons.upload_outlined,
                iconColor: context.colors.primary,
                title: 'Отправлять как файл',
                subtitle: 'Фото и видео без сжатия (оригинал)',
                value: _sendOriginalByDefault,
                onChanged: (v) => setState(() => _sendOriginalByDefault = v),
              ),
            ],
          ),

          // ── Info card ──────────────────────────────────────────
          CharoCard(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(16),
            gradientColors: [
              context.colors.primary.withOpacity(0.06),
              context.colors.outlineVariant,
            ],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.lightbulb_outline, color: context.colors.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Подсказка', style: context.typography.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        'Вы можете изменить качество для каждого файла отдельно при отправке. '
                        'Нажмите на скрепку → выберите файл → настройте качество перед отправкой.',
                        style: context.typography.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQualityTiles(String type, String current, ValueChanged<String> onChanged) {
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

      return GestureDetector(
        onTap: () => onChanged(entry.key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? context.colors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? context.colors.primary : context.colors.onSurface.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 12)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.typography.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? context.colors.primary : context.colors.onSurface,
                    )),
                    if (detail.isNotEmpty)
                      Text(detail, style: context.typography.bodySmall?.copyWith(
                        color: context.colors.onSurface.withOpacity(0.5),
                      )),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
