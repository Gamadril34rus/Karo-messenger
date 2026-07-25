import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Настройки языка — премиальный grouped layout с поиском
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
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск языка...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // System language option
          CharoCard(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            radius: 16,
            borderWidth: _selectedLanguage == 'system' ? 2 : 0,
            borderColor: _selectedLanguage == 'system' ? context.colors.primary : null,
            gradientColors: _selectedLanguage == 'system'
                ? [context.colors.primary.withOpacity(0.06), context.colors.outlineVariant]
                : null,
            child: CharoTile(
              icon: Icons.language_outlined,
              iconColor: context.colors.primary,
              title: 'Системный язык',
              subtitle: 'Автоматически по настройкам устройства',
              trailing: _selectedLanguage == 'system'
                  ? Icon(Icons.check_circle, color: context.colors.primary)
                  : null,
              onTap: () => setState(() => _selectedLanguage = 'system'),
            ),
          ),

          // Languages of Russia section
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                CharoSection(
                  title: 'Языки России',
                  children: _buildLanguageTiles(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLanguageTiles() {
    final filtered = AppConstants.supportedLanguages.entries
        .where((e) => _matchesSearch(e.value))
        .toList();

    return filtered.map((entry) {
      final isSelected = _selectedLanguage == entry.key;
      return CharoTile(
        title: entry.value,
        trailing: isSelected
            ? Icon(Icons.check_circle, color: context.colors.primary)
            : Icon(Icons.circle_outlined, size: 20, color: context.colors.onSurface.withOpacity(0.3)),
        onTap: () => setState(() => _selectedLanguage = entry.key),
      );
    }).toList();
  }

  bool _matchesSearch(String name) {
    if (_searchController.text.isEmpty) return true;
    return name.toLowerCase().contains(_searchController.text.toLowerCase());
  }
}
