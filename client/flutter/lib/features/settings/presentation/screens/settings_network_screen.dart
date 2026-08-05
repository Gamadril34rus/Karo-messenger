// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Настройки сети — премиальный grouped layout
class SettingsNetworkScreen extends StatefulWidget {
  const SettingsNetworkScreen({super.key});

  @override
  State<SettingsNetworkScreen> createState() => _SettingsNetworkScreenState();
}

class _SettingsNetworkScreenState extends State<SettingsNetworkScreen> {
  bool _proxyEnabled = false;
  String _proxyType = 'socks5';
  final _proxyHostController = TextEditingController(text: '');
  final _proxyPortController = TextEditingController(text: '1080');
  final _proxyUserController = TextEditingController();
  final _proxyPassController = TextEditingController();
  bool _dohEnabled = true;
  String _dohProvider = 'cloudflare';
  bool _vpnEnabled = false;
  bool _wifiOnlyAutoDownload = true;

  @override
  void dispose() {
    _proxyHostController.dispose();
    _proxyPortController.dispose();
    _proxyUserController.dispose();
    _proxyPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сеть и прокси')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ─── Proxy ────────────────────────────────────────────
          CharoSection(
            title: 'Прокси',
            children: [
              CharoSwitchTile(
                icon: Icons.swap_horiz_outlined,
                iconColor: context.colors.primary,
                title: 'Прокси',
                subtitle: 'Использовать прокси-сервер для подключения',
                value: _proxyEnabled,
                onChanged: (v) => setState(() => _proxyEnabled = v),
              ),
            ],
          ),

          if (_proxyEnabled)
            CharoCard(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Proxy type
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SegmentedButton(segments: const [
                      ButtonSegment(value: 'socks5', label: Text('SOCKS5')),
                      ButtonSegment(value: 'http', label: Text('HTTP')),
                      ButtonSegment(value: 'mtproto', label: Text('MTProto')),
                    ], selected: {_proxyType}, onSelectionChanged: (v) => setState(() => _proxyType = v.first)),
                  ),
                  Row(children: [
                    Expanded(flex: 3, child: TextField(controller: _proxyHostController, decoration: const InputDecoration(labelText: 'Адрес сервера'))),
                    const SizedBox(width: 8),
                    Expanded(flex: 1, child: TextField(controller: _proxyPortController, decoration: const InputDecoration(labelText: 'Порт'), keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: _proxyUserController, decoration: const InputDecoration(labelText: 'Логин (опционально)'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _proxyPassController, decoration: const InputDecoration(labelText: 'Пароль'), obscureText: true)),
                  ]),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _testProxy,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Проверить подключение'),
                  ),
                ],
              ),
            ),

          // ─── DNS-over-HTTPS ──────────────────────────────────
          CharoSection(
            title: 'DNS-over-HTTPS',
            children: [
              CharoSwitchTile(
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Использовать DoH',
                subtitle: 'Обход DNS-блокировок',
                value: _dohEnabled,
                onChanged: (v) => setState(() => _dohEnabled = v),
              ),
              if (_dohEnabled)
                CharoTile(
                  icon: Icons.dns_outlined,
                  iconColor: _dohProvider == 'cloudflare'
                      ? const Color(0xFF2563EB)
                      : _dohProvider == 'google'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                  title: _dohProvider == 'cloudflare'
                      ? 'Cloudflare (1.1.1.1)'
                      : _dohProvider == 'google'
                          ? 'Google (8.8.8.8)'
                          : 'Quad9 (9.9.9.9)',
                  subtitle: 'Провайдер DoH',
                  onTap: () => _pickDohProvider(),
                ),
            ],
          ),

          // ─── VPN ──────────────────────────────────────────────
          CharoSection(
            title: 'Встроенный VPN',
            children: [
              CharoSwitchTile(
                icon: Icons.vpn_lock_outlined,
                iconColor: const Color(0xFF8B5CF6),
                title: 'VPN-туннель',
                subtitle: 'Шифрование всего трафика',
                value: _vpnEnabled,
                onChanged: (v) => setState(() => _vpnEnabled = v),
              ),
            ],
          ),

          // ─── Auto-download ───────────────────────────────────
          CharoSection(
            title: 'Автоскачивание',
            children: [
              CharoSwitchTile(
                icon: Icons.wifi_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'Только по Wi-Fi',
                subtitle: 'Не скачивать медиа по мобильной сети',
                value: _wifiOnlyAutoDownload,
                onChanged: (v) => setState(() => _wifiOnlyAutoDownload = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _testProxy() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Проверка подключения...'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _pickDohProvider() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Провайдер DoH', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              CharoTile(
                title: 'Cloudflare (1.1.1.1)',
                trailing: _dohProvider == 'cloudflare' ? Icon(Icons.check_circle, color: context.colors.primary) : null,
                onTap: () { setState(() => _dohProvider = 'cloudflare'); Navigator.pop(ctx); },
              ),
              CharoTile(
                title: 'Google (8.8.8.8)',
                trailing: _dohProvider == 'google' ? Icon(Icons.check_circle, color: context.colors.primary) : null,
                onTap: () { setState(() => _dohProvider = 'google'); Navigator.pop(ctx); },
              ),
              CharoTile(
                title: 'Quad9 (9.9.9.9)',
                trailing: _dohProvider == 'quad9' ? Icon(Icons.check_circle, color: context.colors.primary) : null,
                onTap: () { setState(() => _dohProvider = 'quad9'); Navigator.pop(ctx); },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
