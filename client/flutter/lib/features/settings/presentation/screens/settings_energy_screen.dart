import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Настройки энергопотребления — режим экономии, фоновые процессы
class SettingsEnergyScreen extends StatefulWidget {
  const SettingsEnergyScreen({super.key});

  @override
  State<SettingsEnergyScreen> createState() => _SettingsEnergyScreenState();
}

class _SettingsEnergyScreenState extends State<SettingsEnergyScreen> {
  bool _powerSaving = false;
  bool _backgroundSync = true;
  bool _backgroundUpload = false;
  int _syncIntervalMinutes = 15;
  bool _reduceAnimations = false;
  bool _darkModeSaves = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Энергопотребление')),
      body: ListView(children: [
        SwitchListTile(
          title: const Text('Режим экономии'),
          subtitle: const Text('Снижает фоновую активность и частоту синхронизации'),
          value: _powerSaving,
          onChanged: (v) => setState(() { _powerSaving = v; if (v) { _backgroundSync = false; _reduceAnimations = true; _syncIntervalMinutes = 60; } else { _backgroundSync = true; _reduceAnimations = false; _syncIntervalMinutes = 15; } }),
        ),
        const Divider(),
        _Section(title: 'Фоновые процессы'),
        SwitchListTile(title: const Text('Фоновая синхронизация'), subtitle: const Text('Получать сообщения в фоне'), value: _backgroundSync, onChanged: (v) => setState(() => _backgroundSync = v)),
        SwitchListTile(title: const Text('Фоновая загрузка'), subtitle: const Text('Завершать отправку файлов в фоне'), value: _backgroundUpload, onChanged: (v) => setState(() => _backgroundUpload = v)),
        ListTile(title: const Text('Интервал синхронизации'), subtitle: Text('Каждые $_syncIntervalMinutes мин'), trailing: const Icon(Icons.chevron_right), onTap: _pickSyncInterval),
        const Divider(),
        _Section(title: 'Оптимизация'),
        SwitchListTile(title: const Text('Сократить анимации'), subtitle: const Text('Уменьшает расход батареи'), value: _reduceAnimations, onChanged: (v) => setState(() => _reduceAnimations = v)),
        SwitchListTile(title: const Text('Тёмная тема экономит'), subtitle: const Text('На AMOLED-экранах тёмная тема снижает расход'), value: _darkModeSaves, onChanged: (v) => setState(() => _darkModeSaves = v)),
      ]),
    );
  }

  void _pickSyncInterval() => showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [5, 15, 30, 60].map((v) => ListTile(
    title: Text('$v минут'), trailing: _syncIntervalMinutes == v ? Icon(Icons.check, color: context.colors.primary) : null,
    onTap: () { setState(() => _syncIntervalMinutes = v); Navigator.pop(ctx); },
  )).toList())));
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 4), child: Text(title, style: context.typography.labelMedium?.copyWith(color: context.colors.primary)));
}
