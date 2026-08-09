// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Настройки внешнего вида — премиальный grouped layout
class SettingsAppearanceScreen extends StatefulWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  State<SettingsAppearanceScreen> createState() => _SettingsAppearanceScreenState();
}

class _SettingsAppearanceScreenState extends State<SettingsAppearanceScreen> {
  String _themeMode = 'system';
  String _accentColor = 'blue';
  String _chatBubbleStyle = 'rounded';
  double _textScale = 1.0;
  String _chatBackground = 'default';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оформление')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Theme picker ──────────────────────────────────────
          CharoSection(
            title: 'Тема',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: AppConstants.themeOptions.map((option) {
                    final isSelected = _themeMode == option['key'];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _themeMode = option['key']!),
                        child: AnimatedContainer(
                          duration: AppConstants.animationDurationMedium,
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
                                size: 24,
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
            ],
          ),

          // ── Accent color ──────────────────────────────────────
          CharoSection(
            title: 'Цвет акцента',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _AccentColorOption(color: const Color(0xFF2563EB), name: 'Синий', optionKey: 'blue', selectedKey: _accentColor, onSelect: (k) => setState(() => _accentColor = k)),
                    _AccentColorOption(color: const Color(0xFF8B5CF6), name: 'Фиолетовый', optionKey: 'violet', selectedKey: _accentColor, onSelect: (k) => setState(() => _accentColor = k)),
                    _AccentColorOption(color: const Color(0xFF10B981), name: 'Зелёный', optionKey: 'green', selectedKey: _accentColor, onSelect: (k) => setState(() => _accentColor = k)),
                    _AccentColorOption(color: const Color(0xFFF59E0B), name: 'Оранжевый', optionKey: 'orange', selectedKey: _accentColor, onSelect: (k) => setState(() => _accentColor = k)),
                    _AccentColorOption(color: const Color(0xFFEF4444), name: 'Красный', optionKey: 'red', selectedKey: _accentColor, onSelect: (k) => setState(() => _accentColor = k)),
                    _AccentColorOption(color: const Color(0xFFEC4899), name: 'Розовый', optionKey: 'pink', selectedKey: _accentColor, onSelect: (k) => setState(() => _accentColor = k)),
                    _AccentColorOption(color: const Color(0xFF06B6D4), name: 'Голубой', optionKey: 'cyan', selectedKey: _accentColor, onSelect: (k) => setState(() => _accentColor = k)),
                  ],
                ),
              ),
            ],
          ),

          // ── Text scale ────────────────────────────────────────
          CharoSection(
            title: 'Размер текста',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('А', style: context.typography.bodySmall),
                        Text(_textScaleLabel(_textScale), style: context.typography.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.primary,
                        )),
                        Text('А', style: context.typography.headlineLarge),
                      ],
                    ),
                    Slider(
                      value: _textScale,
                      min: AppConstants.textScaleMin,
                      max: AppConstants.textScaleMax,
                      divisions: 10,
                      onChanged: (v) => setState(() => _textScale = v),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.outlineVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Пример текста сообщения с текущим размером',
                        style: TextStyle(fontSize: 14 * _textScale, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Chat decoration ───────────────────────────────────
          CharoSection(
            title: 'Оформление чатов',
            children: [
              CharoTile(
                icon: Icons.chat_bubble_outline,
                iconColor: context.colors.primary,
                title: 'Стиль пузырьков',
                subtitle: _bubbleStyleLabel(_chatBubbleStyle),
                onTap: () => _showBubbleStylePicker(),
              ),
              CharoTile(
                icon: Icons.wallpaper_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Фон чатов',
                subtitle: 'По умолчанию',
                onTap: () => _showWallpaperPicker(),
              ),
            ],
          ),

          // ── App icon ──────────────────────────────────────────
          CharoSection(
            title: 'Иконка приложения',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _AppIconOption(icon: Icons.bolt, isSelected: true, label: 'Базовая'),
                    const SizedBox(width: 12),
                    _AppIconOption(icon: Icons.flash_on, isSelected: false, label: 'Динамичная'),
                    const SizedBox(width: 12),
                    _AppIconOption(icon: Icons.auto_awesome, isSelected: false, label: 'Премиум'),
                  ],
                ),
              ),
            ],
          ),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Стиль пузырьков', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              CharoTile(
                title: 'Скруглённые',
                trailing: _chatBubbleStyle == 'rounded' ? Icon(Icons.check_circle, color: context.colors.primary) : null,
                onTap: () { setState(() => _chatBubbleStyle = 'rounded'); Navigator.pop(ctx); },
              ),
              CharoTile(
                title: 'Современные',
                trailing: _chatBubbleStyle == 'modern' ? Icon(Icons.check_circle, color: context.colors.primary) : null,
                onTap: () { setState(() => _chatBubbleStyle = 'modern'); Navigator.pop(ctx); },
              ),
              CharoTile(
                title: 'Минималистичные',
                trailing: _chatBubbleStyle == 'minimal' ? Icon(Icons.check_circle, color: context.colors.primary) : null,
                onTap: () { setState(() => _chatBubbleStyle = 'minimal'); Navigator.pop(ctx); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWallpaperPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Фон чатов', style: context.typography.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _WallpaperOption(label: 'По умолчанию', color: context.colors.outlineVariant, isSelected: _chatBackground == 'default'),
                  _WallpaperOption(label: 'Тёмный', color: const Color(0xFF1A1A2E), isSelected: _chatBackground == 'dark'),
                  _WallpaperOption(label: 'Градиент', color: context.colors.primary.withOpacity(0.2), isSelected: _chatBackground == 'gradient'),
                  _WallpaperOption(label: 'Ночной', color: const Color(0xFF0F172A), isSelected: _chatBackground == 'night'),
                  _WallpaperOption(label: 'Бумага', color: const Color(0xFFF5F5DC), isSelected: _chatBackground == 'paper'),
                  _WallpaperOption(label: 'Свой', color: context.colors.outlineVariant, icon: Icons.add_photo_alternate_outlined, isSelected: false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Accent color option with animated selection ring
class _AccentColorOption extends StatelessWidget {
  final Color color;
  final String name;
  final String optionKey;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  const _AccentColorOption({
    required this.color,
    required this.name,
    required this.optionKey,
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedKey == optionKey;
    return GestureDetector(
      onTap: () => onSelect(optionKey),
      child: Column(
        children: [
          AnimatedContainer(
            duration: AppConstants.animationDurationShort,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: context.colors.onSurface, width: 3)
                  : Border.all(color: context.colors.outline, width: 1),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(height: 4),
          Text(name, style: context.typography.bodySmall?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          )),
        ],
      ),
    );
  }
}

/// App icon option
class _AppIconOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final String label;

  const _AppIconOption({required this.icon, required this.isSelected, required this.label});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppConstants.animationDurationShort,
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: isSelected ? context.colors.primary : context.colors.outlineVariant,
        borderRadius: BorderRadius.circular(20),
        border: isSelected ? Border.all(color: context.colors.onSurface, width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? Colors.white : context.colors.onSurface, size: 24),
          const SizedBox(height: 2),
          Text(label, style: context.typography.bodySmall?.copyWith(
            color: isSelected ? Colors.white : context.colors.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w500,
            fontSize: 9,
          )),
        ],
      ),
    );
  }
}

/// Wallpaper option
class _WallpaperOption extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isSelected;

  const _WallpaperOption({
    required this.label,
    required this.color,
    this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: context.colors.primary, width: 2.5) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon!, color: context.colors.primary, size: 24)
          else if (isSelected)
            Icon(Icons.check_circle, color: context.colors.primary, size: 20),
          const SizedBox(height: 4),
          Text(label, style: context.typography.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
