import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

/// Настройки сети — прокси, VPN, DNS, Wi-Fi
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
      body: ListView(children: [
        SwitchListTile(
          title: const Text('Прокси'),
          subtitle: const Text('Использовать прокси-сервер для подключения'),
          value: _proxyEnabled,
          onChanged: (v) => setState(() => _proxyEnabled = v),
        ),
        if (_proxyEnabled) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton(segments: const [
              ButtonSegment(value: 'socks5', label: Text('SOCKS5')),
              ButtonSegment(value: 'http', label: Text('HTTP')),
              ButtonSegment(value: 'mtproto', label: Text('MTProto')),
            ], selected: {_proxyType}, onSelectionChanged: (v) => setState(() => _proxyType = v.first)),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(flex: 3, child: TextField(controller: _proxyHostController, decoration: const InputDecoration(hintText: 'Адрес сервера'), enabled: _proxyEnabled)),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: TextField(controller: _proxyPortController, decoration: const InputDecoration(hintText: 'Порт'), keyboardType: TextInputType.number, enabled: _proxyEnabled)),
            ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(child: TextField(controller: _proxyUserController, decoration: const InputDecoration(hintText: 'Логин (опционально)'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _proxyPassController, decoration: const InputDecoration(hintText: 'Пароль'), obscureText: true)),
            ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(onPressed: _testProxy, child: const Text('Проверить подключение'))),
          const Divider(height: 32),
        ],

        _Section(title: 'DNS-over-HTTPS'),
        SwitchListTile(title: const Text('Использовать DoH'), subtitle: const Text('Обход DNS-блокировок'), value: _dohEnabled, onChanged: (v) => setState(() => _dohEnabled = v)),
        if (_dohEnabled) ...[
          RadioListTile(title: const Text('Cloudflare (1.1.1.1)'), value: 'cloudflare', groupValue: _dohProvider, onChanged: (v) => setState(() => _dohProvider = v!)),
          RadioListTile(title: const Text('Google (8.8.8.8)'), value: 'google', groupValue: _dohProvider, onChanged: (v) => setState(() => _dohProvider = v!)),
          RadioListTile(title: const Text('Quad9 (9.9.9.9)'), value: 'quad9', groupValue: _dohProvider, onChanged: (v) => setState(() => _dohProvider = v!)),
        ],
        const Divider(),

        _Section(title: 'Встроенный VPN'),
        SwitchListTile(title: const Text('VPN-туннель'), subtitle: const Text('Шифрование всего трафика'), value: _vpnEnabled, onChanged: (v) => setState(() => _vpnEnabled = v)),
        const Divider(),

        _Section(title: 'Автоскачивание'),
        SwitchListTile(title: const Text('Только по Wi-Fi'), subtitle: const Text('Не скачивать медиа по мобильной сети'), value: _wifiOnlyAutoDownload, onChanged: (v) => setState(() => _wifiOnlyAutoDownload = v)),
      ]),
    );
  }

  void _testProxy() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Проверка подключения...')));
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 4), child: Text(title, style: context.typography.labelMedium?.copyWith(color: context.colors.primary)));
}
