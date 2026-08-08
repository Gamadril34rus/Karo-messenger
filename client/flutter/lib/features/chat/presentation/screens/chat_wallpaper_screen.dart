// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Экран выбора фона чата — предустановленные и кастомные обои
class ChatWallpaperScreen extends StatefulWidget {
  final String chatId;

  const ChatWallpaperScreen({super.key, required this.chatId});

  @override
  State<ChatWallpaperScreen> createState() => _ChatWallpaperScreenState();
}

class _ChatWallpaperScreenState extends State<ChatWallpaperScreen> {
  String _selectedWallpaper = 'default';

  static const _wallpapers = [
    WallpaperOption(id: 'default', name: 'По умолчанию', colors: [Color(0xFFF5F5F5), Color(0xFFE8E8E8)]),
    WallpaperOption(id: 'ocean', name: 'Океан', colors: [Color(0xFF0077B6), Color(0xFF00B4D8)]),
    WallpaperOption(id: 'sunset', name: 'Закат', colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)]),
    WallpaperOption(id: 'forest', name: 'Лес', colors: [Color(0xFF2D6A4F), Color(0xFF52B788)]),
    WallpaperOption(id: 'lavender', name: 'Лаванда', colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)]),
    WallpaperOption(id: 'night', name: 'Ночь', colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
    WallpaperOption(id: 'peach', name: 'Персик', colors: [Color(0xFFFFBE76), Color(0xFFFF7979)]),
    WallpaperOption(id: 'mint', name: 'Мята', colors: [Color(0xFF00B894), Color(0xFF55EFC4)]),
    WallpaperOption(id: 'charcoal', name: 'Уголь', colors: [Color(0xFF2D3436), Color(0xFF636E72)]),
    WallpaperOption(id: 'sky', name: 'Небо', colors: [Color(0xFF74B9FF), Color(0xFFA29BFE)]),
    WallpaperOption(id: 'rose', name: 'Роза', colors: [Color(0xFFFD79A8), Color(0xFFFDCB6E)]),
    WallpaperOption(id: 'none', name: 'Без фона', colors: [Colors.white, Colors.white]),
  ];

  @override
  void initState() {
    super.initState();
    _loadWallpaper();
  }

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedWallpaper = prefs.getString('wallpaper_${widget.chatId}') ??
          prefs.getString('wallpaper_default') ??
          'default';
    });
  }

  Future<void> _selectWallpaper(String id) async {
    HapticService.selection();
    setState(() => _selectedWallpaper = id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallpaper_${widget.chatId}', id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Фон чата')),
      body: Column(
        children: [
          // Preview
          Container(
            height: 200,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colors.outline.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: _selectedWallpaper == 'none'
                          ? null
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _wallpapers.firstWhere((w) => w.id == _selectedWallpaper).colors,
                            ),
                      color: _selectedWallpaper == 'none' ? Colors.white : null,
                    ),
                  ),
                  // Mock messages
                  Positioned(
                    left: 16,
                    top: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Привет! 👋', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Привет! Как дела?', style: TextStyle(fontSize: 14, color: Colors.white)),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 110,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Всё отлично! 🎉', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Grid of wallpapers
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _wallpapers.length,
              itemBuilder: (context, index) {
                final wallpaper = _wallpapers[index];
                final isSelected = _selectedWallpaper == wallpaper.id;
                return GestureDetector(
                  onTap: () => _selectWallpaper(wallpaper.id),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: wallpaper.id == 'none'
                          ? null
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: wallpaper.colors,
                            ),
                      color: wallpaper.id == 'none' ? Colors.white : null,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: context.colors.primary, width: 3)
                          : Border.all(color: context.colors.outline.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSelected)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: context.colors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 18),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          wallpaper.name,
                          style: context.typography.bodySmall?.copyWith(
                            color: wallpaper.id == 'night' || wallpaper.id == 'charcoal'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Модель обоев
class WallpaperOption {
  final String id;
  final String name;
  final List<Color> colors;

  const WallpaperOption({
    required this.id,
    required this.name,
    required this.colors,
  });
}
