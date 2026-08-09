// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Настройки энергопотребления — премиальный grouped layout
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Энергопотребление')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Power saving mode ────────────────────────────────
          CharoCard(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(16),
            gradientColors: _powerSaving
                ? [context.success.withOpacity(0.1), context.colors.outlineVariant]
                : null,
            borderWidth: _powerSaving ? 1.5 : 0,
            borderColor: _powerSaving ? context.success.withOpacity(0.5) : null,
            child: CharoSwitchTile(
              icon: Icons.battery_saver,
              iconColor: _powerSaving ? context.success : context.colors.onSurface.withOpacity(0.7),
              title: 'Режим экономии',
              subtitle: 'Снижает фоновую активность и частоту синхронизации',
              value: _powerSaving,
              onChanged: (v) => setState(() {
                _powerSaving = v;
                if (v) { _backgroundSync = false; _reduceAnimations = true; _syncIntervalMinutes = 60; }
                else { _backgroundSync = true; _reduceAnimations = false; _syncIntervalMinutes = 15; }
              }),
            ),
          ),

          CharoSection(
            title: 'Фоновые процессы',
            children: [
              CharoSwitchTile(
                icon: Icons.cloud_sync_outlined,
                iconColor: context.colors.primary,
                title: 'Фоновая синхронизация',
                subtitle: 'Получать сообщения в фоне',
                value: _backgroundSync,
                onChanged: (v) => setState(() => _backgroundSync = v),
              ),
              CharoSwitchTile(
                icon: Icons.cloud_upload_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Фоновая загрузка',
                subtitle: 'Завершать отправку файлов в фоне',
                value: _backgroundUpload,
                onChanged: (v) => setState(() => _backgroundUpload = v),
              ),
              CharoTile(
                icon: Icons.schedule_outlined,
                iconColor: const Color(0xF59E0B),
                title: 'Интервал синхронизации',
                subtitle: 'Каждые $_syncIntervalMinutes мин',
                onTap: _pickSyncInterval,
              ),
            ],
          ),

          CharoSection(
            title: 'Оптимизация',
            children: [
              CharoSwitchTile(
                icon: Icons.animation_outlined,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Сократить анимации',
                subtitle: 'Уменьшает расход батареи',
                value: _reduceAnimations,
                onChanged: (v) => setState(() => _reduceAnimations = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _pickSyncInterval() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Интервал синхронизации', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...[5, 15, 30, 60].map((v) => CharoTile(
              title: '$v минут',
              trailing: _syncIntervalMinutes == v ? Icon(Icons.check_circle, color: context.colors.primary) : null,
              onTap: () { setState(() => _syncIntervalMinutes = v); Navigator.pop(ctx); },
            )),
          ],
        ),
      ),
    ),
  );
}
