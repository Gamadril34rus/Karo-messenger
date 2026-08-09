// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/accessibility/charo_accessibility.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../bloc/stories_bloc.dart';
import '../../data/story_item.dart';
import 'story_viewer_screen.dart';

/// Экран историй — просмотр и публикация
class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<StoriesBloc>().add(StoriesLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Истории'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo),
            onPressed: () {
              HapticService.medium();
              _publishStory();
            },
          ),
        ],
      ),
      body: BlocBuilder<StoriesBloc, StoriesState>(
        builder: (context, state) {
          if (state is StoriesLoading) return const Center(child: CircularProgressIndicator());
          if (state is StoriesError) return Center(
            child: CharoCard(
              gradientColors: [context.colors.error.withOpacity(0.08), context.colors.outlineVariant],
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, size: 48, color: context.colors.error),
                const SizedBox(height: 16),
                Text(state.message),
                FilledButton(
                  onPressed: () {
                    HapticService.light();
                    context.read<StoriesBloc>().add(StoriesLoadRequested());
                  },
                  child: const Text('Повторить'),
                ),
              ]),
            ),
          );
          final stories = state is StoriesLoaded ? state.stories : <StoryItem>[];
          if (stories.isEmpty) return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome_outlined, size: 64, color: context.colors.onSurface.withOpacity(0.15)),
              const SizedBox(height: 16),
              Text('Нет историй', style: context.typography.titleLarge?.copyWith(
                color: context.colors.onSurface.withOpacity(0.4),
              )),
              const SizedBox(height: 8),
              Text('Добавьте свою!', style: context.typography.bodyMedium?.copyWith(
                color: context.colors.onSurface.withOpacity(0.3),
              )),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  HapticService.medium();
                  _publishStory();
                },
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Добавить историю'),
              ),
            ]),
          );
          return RefreshIndicator(
            onRefresh: () async {
              HapticService.light();
              context.read<StoriesBloc>().add(StoriesLoadRequested());
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: stories.length,
              itemBuilder: (context, index) => _StoryTile(story: stories[index], index: index),
            ),
          );
        },
      ),
    );
  }

  void _publishStory() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Новая история', style: context.typography.titleLarge)),
          CharoTile(icon: Icons.photo_camera, title: 'Фото', onTap: () {
            HapticService.light();
            Navigator.pop(ctx);
            context.go('/story-create', extra: {'storyType': 'image'});
          }),
          CharoTile(icon: Icons.videocam, title: 'Видео', onTap: () {
            HapticService.light();
            Navigator.pop(ctx);
            context.go('/story-create', extra: {'storyType': 'video'});
          }),
          CharoTile(icon: Icons.text_fields, title: 'Текст', onTap: () {
            HapticService.light();
            Navigator.pop(ctx);
            context.go('/story-create', extra: {'storyType': 'text'});
          }),
        ]),
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  final StoryItem story;
  final int index;

  const _StoryTile({required this.story, required this.index});

  @override
  Widget build(BuildContext context) {
    return CharoAccessibility.storyItem(
      userName: story.userName ?? 'Пользователь',
      hasUnviewed: !story.isViewed,
      child: CharoCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      radius: 14,
      borderWidth: story.isViewed ? 0 : 1.5,
      borderColor: story.isViewed ? null : context.colors.primary.withOpacity(0.5),
      onTap: () {
        HapticService.medium();
        // Открываем полноэкранный просмотрщик
        final allStories = BlocProvider.of<StoriesBloc>(context).state is StoriesLoaded
            ? (BlocProvider.of<StoriesBloc>(context).state as StoriesLoaded).stories
            : <StoryItem>[];
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoryViewerScreen(
              stories: allStories,
              initialUserIndex: index,
            ),
          ),
        );
      },
      child: Row(
        children: [
          CharoAvatar(
            radius: 26,
            imageUrl: story.avatarUrl,
            fallbackText: story.userName ?? '?',
            showRing: !story.isViewed,
            ringColors: [context.colors.primary, context.accentLight],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.userName ?? 'Пользователь',
                  style: context.typography.titleMedium?.copyWith(
                    fontWeight: !story.isViewed ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${story.count} история(ий)',
                  style: context.typography.bodySmall?.copyWith(
                    color: context.colors.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          CharoBadge(
            count: story.count,
            color: !story.isViewed ? context.colors.primary : context.colors.onSurface.withOpacity(0.3),
          ),
        ],
      ),
    ),
    );
  }
}
