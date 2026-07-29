import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../bloc/stories_bloc.dart';
import '../../data/story_item.dart';

/// Полноэкранный просмотрщик историй
/// Функции:
/// - Swipe между пользователями (горизонтально)
/// - Прогресс-бар с auto-advance
/// - Тап-зоны: левая = назад, правая = вперёд
/// - Закрытие по свайпу вниз
/// - Счётчик просмотров
/// - Длинное нажатие = пауза
class StoryViewerScreen extends StatefulWidget {
  final List<StoryItem> stories;
  final int initialUserIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialUserIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  Timer? _autoAdvanceTimer;
  bool _isPaused = false;

  /// Duration per story type
  static const _imageDuration = Duration(seconds: 5);
  static const _videoDuration = Duration(seconds: 15);
  static const _textDuration = Duration(seconds: 7);

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialUserIndex.clamp(0, widget.stories.length - 1);
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  List<StoryContentItem> get _currentStories {
    if (_currentUserIndex >= widget.stories.length) return [];
    return widget.stories[_currentUserIndex].items;
  }

  StoryContentItem? get _currentStory {
    final stories = _currentStories;
    if (_currentStoryIndex >= stories.length) return null;
    return stories[_currentStoryIndex];
  }

  Duration get _currentDuration {
    final story = _currentStory;
    if (story == null) return _imageDuration;
    switch (story.type) {
      case 'video':
        return _videoDuration;
      case 'text':
        return _textDuration;
      default:
        return _imageDuration;
    }
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (_isPaused) return;

    _autoAdvanceTimer = Timer(_currentDuration, () {
      _goToNextStory();
    });
  }

  void _goToNextStory() {
    if (_currentUserIndex >= widget.stories.length) return;

    final stories = _currentStories;
    if (_currentStoryIndex < stories.length - 1) {
      // Next story from same user
      setState(() => _currentStoryIndex++);
      _markViewed(stories[_currentStoryIndex]);
      _startAutoAdvance();
    } else if (_currentUserIndex < widget.stories.length - 1) {
      // Next user
      setState(() {
        _currentUserIndex++;
        _currentStoryIndex = 0;
      });
      _markViewed(_currentStories.isNotEmpty ? _currentStories[0] : null);
      _startAutoAdvance();
    } else {
      // All stories viewed
      Navigator.of(context).pop();
    }
  }

  void _goToPreviousStory() {
    if (_currentStoryIndex > 0) {
      setState(() => _currentStoryIndex--);
      _startAutoAdvance();
    } else if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        _currentStoryIndex = widget.stories[_currentUserIndex].items.length - 1;
      });
      _startAutoAdvance();
    }
  }

  void _markViewed(StoryContentItem? story) {
    if (story == null) return;
    final userId = widget.stories[_currentUserIndex].userId;
    context.read<StoriesBloc>().add(StoryViewRequested(userId: userId));
  }

  void _onTapLeft() {
    HapticService.light();
    _goToPreviousStory();
  }

  void _onTapRight() {
    HapticService.light();
    _goToNextStory();
  }

  void _onLongPressStart() {
    setState(() => _isPaused = true);
    _autoAdvanceTimer?.cancel();
  }

  void _onLongPressEnd() {
    setState(() => _isPaused = false);
    _startAutoAdvance();
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Нет историй', style: TextStyle(color: Colors.white))),
      );
    }

    final story = _currentStory;
    final user = widget.stories[_currentUserIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: _onVerticalDragEnd,
        child: SafeArea(
          child: Column(
            children: [
              // ── Progress bars + header ──────────────────────────
              _buildHeader(user, story),

              // ── Story content ───────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTapDown: (details) {
                    final width = MediaQuery.of(context).size.width;
                    final x = details.globalPosition.dx;
                    if (x < width / 3) {
                      _onTapLeft();
                    } else {
                      _onTapRight();
                    }
                  },
                  onLongPressStart: (_) => _onLongPressStart(),
                  onLongPressEnd: (_) => _onLongPressEnd(),
                  child: _buildStoryContent(story),
                ),
              ),

              // ── Reply bar ───────────────────────────────────────
              _buildReplyBar(user),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(StoryItem user, StoryContentItem? story) {
    final stories = _currentStories;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Progress bars ─────────────────────────────────────
          Row(
            children: List.generate(stories.length, (index) {
              final isCompleted = index < _currentStoryIndex;
              final isCurrent = index == _currentStoryIndex;

              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: isCurrent
                      ? _StoryProgressBar(
                          duration: _currentDuration,
                          isPaused: _isPaused,
                        )
                      : FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: isCompleted ? 1.0 : 0.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),

          // ── User info + close button ──────────────────────────
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.userName?.isNotEmpty == true ? user.userName![0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      )
                    : null,
              ),
              const SizedBox(width: 10),

              // Name + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.userName ?? 'Пользователь',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (story?.createdAt != null)
                      Text(
                        _formatTime(story!.createdAt!),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              // View count
              if (story?.viewCount != null && story!.viewCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, size: 14, color: Colors.white.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        '${story.viewCount}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // Close button
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoryContent(StoryContentItem? story) {
    if (story == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    switch (story.type) {
      case 'image':
        return _buildImageStory(story);
      case 'video':
        return _buildVideoStory(story);
      case 'text':
        return _buildTextStory(story);
      default:
        return _buildImageStory(story);
    }
  }

  Widget _buildImageStory(StoryContentItem story) {
    if (story.mediaUrl != null && story.mediaUrl!.isNotEmpty) {
      return Center(
        child: Image.network(
          story.mediaUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildPlaceholderStory(story),
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      );
    }
    return _buildPlaceholderStory(story);
  }

  Widget _buildVideoStory(StoryContentItem story) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (story.mediaUrl != null && story.mediaUrl!.isNotEmpty)
          Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_outline, color: Colors.white, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    'Видео',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          _buildPlaceholderStory(story),
      ],
    );
  }

  Widget _buildTextStory(StoryContentItem story) {
    final bgColor = _parseColor(story.backgroundColor);

    return Container(
      color: bgColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            story.textContent ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderStory(StoryContentItem story) {
    final bgColor = _parseColor(story.backgroundColor);

    return Container(
      color: bgColor,
      child: Center(
        child: Text(
          story.textContent ?? '📷',
          style: TextStyle(
            color: Colors.white,
            fontSize: story.textContent != null ? 22 : 48,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildReplyBar(StoryItem user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const TextField(
                style: TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ответить...',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.white, size: 24),
            onPressed: () {
              HapticService.light();
            },
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white, size: 24),
            onPressed: () {
              HapticService.light();
            },
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return const Color(0xFF6366F1);
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }
}

/// Анимированный прогресс-бар для текущей истории
class _StoryProgressBar extends StatefulWidget {
  final Duration duration;
  final bool isPaused;

  const _StoryProgressBar({
    required this.duration,
    required this.isPaused,
  });

  @override
  State<_StoryProgressBar> createState() => _StoryProgressBarState();
}

class _StoryProgressBarState extends State<_StoryProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(() {
        if (mounted) setState(() {});
      })..forward();
  }

  @override
  void didUpdateWidget(covariant _StoryProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused && !_controller.isDismissed) {
      _controller.stop();
    } else if (!widget.isPaused && !_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: _controller.value,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
