import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

/// Настройки языка — все языки России + мировые
class SettingsLanguageScreen extends StatefulWidget {
  const SettingsLanguageScreen({super.key});

  @override
  State<SettingsLanguageScreen> createState() => _SettingsLanguageScreenState();
}

class _SettingsLanguageScreenState extends State<SettingsLanguageScreen> {
  String _selectedLanguage = 'system';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Язык')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Поиск языка...', prefixIcon: Icon(Icons.search)),
          onChanged: (_) => setState(() {}),
        )),
        Expanded(child: ListView(children: [
          // Системный язык
          _LanguageTile(code: 'system', name: 'Системный', isSelected: _selectedLanguage == 'system', onTap: () => setState(() => _selectedLanguage = 'system')),
          const Divider(),

          // Языки России
          _Section(title: 'Языки России'),
          for (final entry in AppConstants.supportedLanguages.entries)
            if (_matchesSearch(entry.value))
              _LanguageTile(code: entry.key, name: entry.value, isSelected: _selectedLanguage == entry.key, onTap: () => setState(() => _selectedLanguage = entry.key)),
        ])),
      ]),
    );
  }

  bool _matchesSearch(String name) {
    if (_searchController.text.isEmpty) return true;
    return name.toLowerCase().contains(_searchController.text.toLowerCase());
  }
}

class _LanguageTile extends StatelessWidget {
  final String code;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  const _LanguageTile({required this.code, required this.name, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? context.colors.primary : context.colors.onSurface)),
      trailing: isSelected ? Icon(Icons.check, color: context.colors.primary) : null,
      onTap: onTap,
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 4), child: Text(title, style: context.typography.labelMedium?.copyWith(color: context.colors.primary)));
}
