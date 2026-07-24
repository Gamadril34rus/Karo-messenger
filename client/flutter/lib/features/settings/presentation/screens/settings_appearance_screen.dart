import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

/// Настройки внешнего вида — темы, оформление чатов, размер текста
class SettingsAppearanceScreen extends StatefulWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  State<SettingsAppearanceScreen> createState() =>
      _SettingsAppearanceScreenState();
}

class _SettingsAppearanceScreenState extends State<SettingsAppearanceScreen> {
  String _themeMode = 'system';
  String _accentColor = 'blue';
  String _chatBubbleStyle = 'rounded'; // rounded, modern, minimal
  double _textScale = 1.0;
  String _chatBackground = 'default';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оформление')),
      body: ListView(
        children: [
          // ─── Тема ──────────────────────────────────────────────
          _SectionHeader(title: 'Тема'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: AppConstants.themeOptions.map((option) {
                final isSelected = _themeMode == option['key'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _themeMode = option['key']!),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.colors.primary
                            : context.colors.outlineVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            option['key'] == 'light'
                                ? Icons.light_mode
                                : option['key'] == 'dark'
                                    ? Icons.dark_mode
                                    : option['key'] == 'amoled'
                                        ? Icons.nights_stay
                                        : Icons.brightness_auto,
                            color: isSelected ? Colors.white : context.colors.onSurface,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option['label']!,
                            style: TextStyle(
                              color: isSelected ? Colors.white : context.colors.onSurface,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 32),

          // ─── Цвет акцента ──────────────────────────────────────
          _SectionHeader(title: 'Цвет акцента'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ColorOption(color: const Color(0xFF2563EB), name: 'Синий', isSelected: _accentColor == 'blue', onTap: () => setState(() => _accentColor = 'blue')),
                _ColorOption(color: const Color(0xFF8B5CF6), name: 'Фиолетовый', isSelected: _accentColor == 'violet', onTap: () => setState(() => _accentColor = 'violet')),
                _ColorOption(color: const Color(0xFF10B981), name: 'Зелёный', isSelected: _accentColor == 'green', onTap: () => setState(() => _accentColor = 'green')),
                _ColorOption(color: const Color(0xFFF59E0B), name: 'Оранжевый', isSelected: _accentColor == 'orange', onTap: () => setState(() => _accentColor = 'orange')),
                _ColorOption(color: const Color(0xFFEF4444), name: 'Красный', isSelected: _accentColor == 'red', onTap: () => setState(() => _accentColor = 'red')),
                _ColorOption(color: const Color(0xFFEC4899), name: 'Розовый', isSelected: _accentColor == 'pink', onTap: () => setState(() => _accentColor = 'pink')),
                _ColorOption(color: const Color(0xFF06B6D4), name: 'Голубой', isSelected: _accentColor == 'cyan', onTap: () => setState(() => _accentColor = 'cyan')),
              ],
            ),
          ),

          const Divider(height: 32),

          // ─── Размер текста ─────────────────────────────────────
          _SectionHeader(title: 'Размер текста'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('А', style: context.typography.bodySmall),
                    Text('А', style: context.typography.headlineLarge),
                  ],
                ),
                Slider(
                  value: _textScale,
                  min: AppConstants.textScaleMin,
                  max: AppConstants.textScaleMax,
                  divisions: 10,
                  label: _textScaleLabel(_textScale),
                  onChanged: (v) => setState(() => _textScale = v),
                ),
                Text(
                  'Пример текста сообщения с текущим размером',
                  style: TextStyle(
                    fontSize: 14 * _textScale,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          // ─── Оформление чатов ──────────────────────────────────
          _SectionHeader(title: 'Оформление чатов'),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Стиль пузырьков'),
            subtitle: Text(_bubbleStyleLabel(_chatBubbleStyle)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBubbleStylePicker(),
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper_outlined),
            title: const Text('Фон чатов'),
            subtitle: const Text('По умолчанию'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showWallpaperPicker(),
          ),

          const Divider(height: 32),

          // ─── Иконка приложения ─────────────────────────────────
          _SectionHeader(title: 'Иконка приложения'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _AppIconOption(icon: Icons.bolt, isSelected: true),
                const SizedBox(width: 12),
                _AppIconOption(icon: Icons.flash_on, isSelected: false),
                const SizedBox(width: 12),
                _AppIconOption(icon: Icons.auto_awesome, isSelected: false),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _textScaleLabel(double scale) {
    if (scale <= 0.85) return 'Крошечный';
    if (scale <= 0.95) return 'Маленький';
    if (scale <= 1.05) return 'Нормальный';
    if (scale <= 1.25) return 'Большой';
    if (scale <= 1.5) return 'Очень большой';
    return 'Огромный';
  }

  String _bubbleStyleLabel(String style) {
    switch (style) {
      case 'rounded': return 'Скруглённые';
      case 'modern': return 'Современные';
      case 'minimal': return 'Минималистичные';
      default: return 'Скруглённые';
    }
  }

  void _showBubbleStylePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Стиль пузырьков', style: Theme.of(ctx).textTheme.titleLarge),
            ),
            _bubbleOption('rounded', 'Скруглённые', ctx),
            _bubbleOption('modern', 'Современные', ctx),
            _bubbleOption('minimal', 'Минималистичные', ctx),
          ],
        ),
      ),
    );
  }

  Widget _bubbleOption(String key, String label, BuildContext ctx) {
    return ListTile(
      title: Text(label),
      trailing: _chatBubbleStyle == key
          ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
          : null,
      onTap: () {
        setState(() => _chatBubbleStyle = key);
        Navigator.pop(ctx);
      },
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.color,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: context.colors.onSurface, width: 3)
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 4),
          Text(name, style: context.typography.bodySmall),
        ],
      ),
    );
  }
}

class _AppIconOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;

  const _AppIconOption({required this.icon, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isSelected ? context.colors.primary : context.colors.outlineVariant,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? Border.all(color: context.colors.onSurface, width: 2) : null,
      ),
      child: Icon(icon, color: isSelected ? Colors.white : context.colors.onSurface),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: context.typography.labelMedium?.copyWith(
        color: context.colors.primary,
      )),
    );
  }
}
