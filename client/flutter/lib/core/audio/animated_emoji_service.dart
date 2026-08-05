// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ─── Animated Emoji Service ──────────────────────────────────────
/// Покадровая анимация Charo-эмодзи в Flutter.
/// Загружает frames из assets и воспроизводит циклично.

class AnimatedEmojiData {
  final String id;
  final String name;
  final int frameCount;
  final int fps;
  final bool loop;
  final String unicode;
  final String description;
  final List<String> frameFiles;
  final List<int> frameOrder;

  const AnimatedEmojiData({
    required this.id,
    required this.name,
    required this.frameCount,
    required this.fps,
    required this.loop,
    required this.unicode,
    required this.description,
    required this.frameFiles,
    required this.frameOrder,
  });

  factory AnimatedEmojiData.fromJson(Map<String, dynamic> json) {
    return AnimatedEmojiData(
      id: json['id'] as String,
      name: json['name'] as String,
      frameCount: json['frames'] as int,
      fps: json['fps'] as int,
      loop: json['loop'] as bool? ?? true,
      unicode: json['unicode'] as String,
      description: json['description'] as String? ?? '',
      frameFiles: (json['frameFiles'] as List).cast<String>(),
      frameOrder: (json['frameOrder'] as List).cast<int>(),
    );
  }

  /// Asset prefix for this emoji's frames
  String get assetPrefix => 'assets/emoji/charo_animated/$id';
}

/// ─── Animated Emoji Widget ────────────────────────────────────────
/// Displays an animated emoji by cycling through PNG frames.
/// Uses Timer-based frame switching for smooth animation.

class AnimatedEmoji extends StatefulWidget {
  final AnimatedEmojiData data;
  final double size;
  final bool autoPlay;
  final int? repeatCount; // null = infinite loop

  const AnimatedEmoji({
    super.key,
    required this.data,
    this.size = 48.0,
    this.autoPlay = true,
    this.repeatCount,
  });

  @override
  State<AnimatedEmoji> createState() => _AnimatedEmojiState();
}

class _AnimatedEmojiState extends State<AnimatedEmoji> {
  int _currentFrame = 0;
  Timer? _timer;
  int _playCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) {
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    final intervalMs = (1000 / widget.data.fps).round();
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted) return;

      setState(() {
        final orderIndex = _currentFrame;
        if (orderIndex < widget.data.frameOrder.length) {
          _currentFrame = (orderIndex + 1) % widget.data.frameCount;
        } else {
          _currentFrame = (_currentFrame + 1) % widget.data.frameCount;
        }

        if (!widget.data.loop && _currentFrame == 0) {
          _playCount++;
          if (widget.repeatCount != null && _playCount >= widget.repeatCount!) {
            _timer?.cancel();
          }
        }
      });
    });
  }

  void _stopAnimation() {
    _timer?.cancel();
    setState(() {
      _currentFrame = 0;
      _playCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final framePath = '${widget.data.assetPrefix}/frame_${_currentFrame}.png';

    return GestureDetector(
      onTap: () {
        if (_timer?.isActive ?? false) {
          _stopAnimation();
        } else {
          _startAnimation();
        }
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image.asset(
          framePath,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to Unicode emoji if asset fails
            return Center(
              child: Text(
                widget.data.unicode,
                style: TextStyle(fontSize: widget.size * 0.7),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ─── Animated Emoji Registry ──────────────────────────────────────
/// Central registry of all animated Charo emoji.
/// Loads animation.json configs and provides AnimatedEmojiData instances.

class AnimatedEmojiRegistry {
  static const _emojiIds = [
    'bang_wall',  // Бьётся об стену — самый iconic!
    'wave',       // Машет рукой
    'pushup',     // Отжимается
    'roll_eyes',  // Закатывает глаза
    'walk_away',  // Уходит
    'bloom',      // Расцветает
  ];

  static final Map<String, AnimatedEmojiData> _cache = {};

  /// Load all animated emoji data from assets
  static Future<void> preloadAll() async {
    for (final id in _emojiIds) {
      try {
        final jsonStr = await rootBundle.loadString(
          'assets/emoji/charo_animated/$id/animation.json',
        );
        final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
        _cache[id] = AnimatedEmojiData.fromJson(jsonMap);
      } catch (e) {
        debugPrint('⚠️ Failed to load animated emoji $id: $e');
      }
    }
  }

  /// Get animated emoji data by ID
  static AnimatedEmojiData? get(String id) => _cache[id];

  /// Get all loaded animated emoji IDs
  static List<String> get allIds => _emojiIds;

  /// Get all loaded AnimatedEmojiData instances
  static List<AnimatedEmojiData> get allData =>
      _emojiIds.map((id) => _cache[id]).whereType<AnimatedEmojiData>().toList();

  /// Quick widget builder for an animated emoji
  static Widget build({
    required String id,
    double size = 48.0,
    bool autoPlay = true,
    int? repeatCount,
  }) {
    final data = _cache[id];
    if (data == null) {
      // Fallback: show Unicode emoji
      final unicodeMap = {
        'bang_wall': '😩',
        'wave': '👋',
        'pushup': '💪',
        'roll_eyes': '🙄',
        'walk_away': '🚶',
        'bloom': '🌸',
      };
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            unicodeMap[id] ?? '😊',
            style: TextStyle(fontSize: size * 0.7),
          ),
        ),
      );
    }
    return AnimatedEmoji(
      data: data,
      size: size,
      autoPlay: autoPlay,
      repeatCount: repeatCount,
    );
  }
}
