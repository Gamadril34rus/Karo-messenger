import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Настройки уведомлений — премиальный grouped layout с серверной синхронизацией
class SettingsNotificationsScreen extends StatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  State<SettingsNotificationsScreen> createState() => _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState extends State<SettingsNotificationsScreen> {
  bool _pushEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _previewEnabled = true;
  bool _groupMentions = true;
  String _ringtone = 'По умолчанию';
  String _quietHoursStart = '23:00';
  String _quietHoursEnd = '07:00';
  bool _quietHoursEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final apiClient = GetIt.instance<ApiClient>();
      final response = await apiClient.get('/api/v1/settings/push');
      final data = response.asMap;
      setState(() {
        _pushEnabled = data['push_enabled'] as bool? ?? true;
        _soundEnabled = data['sound_enabled'] as bool? ?? true;
        _vibrationEnabled = data['vibration_enabled'] as bool? ?? true;
        _previewEnabled = data['preview_enabled'] as bool? ?? true;
        _groupMentions = data['group_mentions'] as bool? ?? true;
        _isLoading = false;
      });
    } catch (e) {
      logger.w('Failed to load push settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final apiClient = GetIt.instance<ApiClient>();
      await apiClient.patch('/api/v1/settings/push', data: {
        'push_enabled': _pushEnabled,
        'sound_enabled': _soundEnabled,
        'vibration_enabled': _vibrationEnabled,
        'preview_enabled': _previewEnabled,
        'group_mentions': _groupMentions,
      });
    } catch (e) {
      logger.e('Failed to save push settings: $e');
    }
  }

  void _onChanged(VoidCallback change) {
    setState(change);
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Уведомления')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          CharoSection(
            title: 'Push-уведомления',
            children: [
              CharoSwitchTile(
                icon: Icons.notifications_active_outlined,
                iconColor: context.colors.primary,
                title: 'Push-уведомления',
                subtitle: 'Получать уведомления о новых сообщениях',
                value: _pushEnabled,
                onChanged: (v) => _onChanged(() => _pushEnabled = v),
              ),
            ],
          ),

          CharoSection(
            title: 'Звук и вибрация',
            children: [
              CharoSwitchTile(
                icon: Icons.volume_up_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Звук',
                value: _soundEnabled,
                onChanged: (v) => _onChanged(() => _soundEnabled = v),
              ),
              CharoSwitchTile(
                icon: Icons.vibration_outlined,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Вибрация',
                value: _vibrationEnabled,
                onChanged: (v) => _onChanged(() => _vibrationEnabled = v),
              ),
              CharoTile(
                icon: Icons.music_note_outlined,
                iconColor: const Color(0xFFF59E0B),
                title: 'Мелодия звонка',
                subtitle: _ringtone,
                onTap: () => _pickRingtone(),
              ),
            ],
          ),

          CharoSection(
            title: 'Конфиденциальность',
            children: [
              CharoSwitchTile(
                icon: Icons.visibility_off_outlined,
                iconColor: const Color(0xFFEC4899),
                title: 'Предпросмотр',
                subtitle: 'Показывать текст сообщения в уведомлении',
                value: _previewEnabled,
                onChanged: (v) => _onChanged(() => _previewEnabled = v),
              ),
            ],
          ),

          CharoSection(
            title: 'Группы',
            children: [
              CharoSwitchTile(
                icon: Icons.group_outlined,
                iconColor: const Color(0xFF3B82F6),
                title: 'Упоминания в группах',
                subtitle: 'Уведомлять при @упоминании',
                value: _groupMentions,
                onChanged: (v) => _onChanged(() => _groupMentions = v),
              ),
            ],
          ),

          CharoSection(
            title: 'Тихие часы',
            children: [
              CharoSwitchTile(
                icon: Icons.bedtime_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'Включить тихие часы',
                subtitle: '$_quietHoursStart — $_quietHoursEnd',
                value: _quietHoursEnabled,
                onChanged: (v) => _onChanged(() => _quietHoursEnabled = v),
              ),
              if (_quietHoursEnabled)
                CharoTile(
                  icon: Icons.schedule_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Начало',
                  subtitle: _quietHoursStart,
                  onTap: () => _pickTime(true),
                ),
              if (_quietHoursEnabled)
                CharoTile(
                  icon: Icons.schedule_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Конец',
                  subtitle: _quietHoursEnd,
                  onTap: () => _pickTime(false),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _pickRingtone() {
    final ringtones = ['По умолчанию', 'Мелодия 1', 'Мелодия 2', 'Без звука'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Мелодия звонка', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...ringtones.map((r) => CharoTile(
                title: r,
                trailing: _ringtone == r ? Icon(Icons.check_circle, color: context.colors.primary) : null,
                onTap: () { _onChanged(() => _ringtone = r); Navigator.pop(ctx); },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      _onChanged(() {
        final str = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (isStart) _quietHoursStart = str; else _quietHoursEnd = str;
      });
    }
  }
}
