import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

/// Настройки уведомлений — звуки, вибрация, режимы
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: ListView(children: [
        SwitchListTile(title: const Text('Push-уведомления'), subtitle: const Text('Получать уведомления о новых сообщениях'), value: _pushEnabled, onChanged: (v) => setState(() => _pushEnabled = v)),
        const Divider(),
        _Section(title: 'Звук и вибрация'),
        SwitchListTile(title: const Text('Звук'), value: _soundEnabled, onChanged: (v) => setState(() => _soundEnabled = v)),
        SwitchListTile(title: const Text('Вибрация'), value: _vibrationEnabled, onChanged: (v) => setState(() => _vibrationEnabled = v)),
        ListTile(title: const Text('Мелодия звонка'), subtitle: Text(_ringtone), trailing: const Icon(Icons.chevron_right), onTap: () => _pickRingtone()),
        const Divider(),
        _Section(title: 'Конфиденциальность'),
        SwitchListTile(title: const Text('Предпросмотр'), subtitle: const Text('Показывать текст сообщения в уведомлении'), value: _previewEnabled, onChanged: (v) => setState(() => _previewEnabled = v)),
        const Divider(),
        _Section(title: 'Группы'),
        SwitchListTile(title: const Text('Упоминания в группах'), subtitle: const Text('Уведомлять при @упоминании'), value: _groupMentions, onChanged: (v) => setState(() => _groupMentions = v)),
        const Divider(),
        _Section(title: 'Тихие часы'),
        SwitchListTile(title: const Text('Включить тихие часы'), subtitle: Text('$_quietHoursStart — $_quietHoursEnd'), value: _quietHoursEnabled, onChanged: (v) => setState(() => _quietHoursEnabled = v)),
        if (_quietHoursEnabled) ...[
          ListTile(title: const Text('Начало'), subtitle: Text(_quietHoursStart), trailing: const Icon(Icons.chevron_right), onTap: () => _pickTime(true)),
          ListTile(title: const Text('Конец'), subtitle: Text(_quietHoursEnd), trailing: const Icon(Icons.chevron_right), onTap: () => _pickTime(false)),
        ],
      ]),
    );
  }

  void _pickRingtone() {
    final ringtones = ['По умолчанию', 'Мелодия 1', 'Мелодия 2', 'Без звука'];
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: ringtones.map((r) => ListTile(
      title: Text(r), trailing: _ringtone == r ? Icon(Icons.check, color: context.colors.primary) : null,
      onTap: () { setState(() => _ringtone = r); Navigator.pop(ctx); },
    )).toList())));
  }

  void _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        final str = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (isStart) _quietHoursStart = str; else _quietHoursEnd = str;
      });
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 4), child: Text(title, style: context.typography.labelMedium?.copyWith(color: context.colors.primary)));
}
