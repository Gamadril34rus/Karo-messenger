import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/stories_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      appBar: AppBar(title: const Text('Истории'), actions: [
        IconButton(icon: const Icon(Icons.add_a_photo), onPressed: _publishStory),
      ]),
      body: BlocBuilder<StoriesBloc, StoriesState>(
        builder: (context, state) {
          if (state is StoriesLoading) return const Center(child: CircularProgressIndicator());
          if (state is StoriesError) return Center(child: Text(state.message));
          final stories = state is StoriesLoaded ? state.stories : <StoryItem>[];
          if (stories.isEmpty) return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome_outlined, size: 64, color: context.colors.onSurface.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text('Нет историй', style: context.typography.titleLarge?.copyWith(color: context.colors.onSurface.withOpacity(0.5))),
              const SizedBox(height: 8),
              Text('Добавьте свою!', style: context.typography.bodyMedium?.copyWith(color: context.colors.onSurface.withOpacity(0.4))),
            ]),
          );
          return RefreshIndicator(
            onRefresh: () async => context.read<StoriesBloc>().add(StoriesLoadRequested()),
            child: ListView.builder(
              itemCount: stories.length,
              itemBuilder: (context, index) => _StoryTile(story: stories[index]),
            ),
          );
        },
      ),
    );
  }

  void _publishStory() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Фото'), onTap: () { Navigator.pop(ctx); context.read<StoriesBloc>().add(StoryPublishRequested(type: 'image')); }),
          ListTile(leading: const Icon(Icons.videocam), title: const Text('Видео'), onTap: () { Navigator.pop(ctx); context.read<StoriesBloc>().add(StoryPublishRequested(type: 'video')); }),
          ListTile(leading: const Icon(Icons.text_fields), title: const Text('Текст'), onTap: () { Navigator.pop(ctx); context.read<StoriesBloc>().add(StoryPublishRequested(type: 'text')); }),
        ]),
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  final StoryItem story;
  const _StoryTile({required this.story});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(children: [
        CircleAvatar(radius: 28, backgroundColor: context.colors.primary.withOpacity(0.1),
          backgroundImage: story.avatarUrl != null ? NetworkImage(story.avatarUrl!) : null,
          child: story.avatarUrl == null ? Text((story.userName ?? '?')[0].toUpperCase(), style: TextStyle(color: context.colors.primary)) : null,
        ),
        if (!story.isViewed) Positioned.fill(child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.colors.primary, width: 3)),
        )),
      ]),
      title: Text(story.userName ?? 'Пользователь', style: context.typography.titleMedium),
      subtitle: Text('${story.count} история(ий)', style: context.typography.bodySmall),
      onTap: () => _viewStories(context, story),
    );
  }

  void _viewStories(BuildContext context, StoryItem story) {
    context.read<StoriesBloc>().add(StoryViewRequested(userId: story.userId));
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => _StoryViewer(story: story)));
  }
}

class _StoryViewer extends StatefulWidget {
  final StoryItem story;
  const _StoryViewer({required this.story});

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _animateProgress();
  }

  void _animateProgress() async {
    for (var i = 0; i < 100; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      setState(() => _progress = i / 100);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [
        LinearProgressIndicator(value: _progress, backgroundColor: Colors.white24, color: Colors.white),
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          CircleAvatar(radius: 16, child: Text((widget.story.userName ?? '?')[0])),
          const SizedBox(width: 8),
          Text(widget.story.userName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ])),
        Expanded(child: Center(child: widget.story.type == 'text'
          ? Container(color: Colors.deepPurple, child: Center(child: Text(widget.story.textContent ?? '', style: const TextStyle(color: Colors.white, fontSize: 24)))),
          : Container(color: Colors.grey[900], child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white54, size: 64))),
        )),
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: TextField(decoration: InputDecoration(hintText: 'Ответить...', hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Colors.white12, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.favorite_border, color: Colors.white), onPressed: () {}),
        ])),
      ])),
    );
  }
}

class StoryItem {
  final String userId;
  final String? userName;
  final String? avatarUrl;
  final String type; // image, video, text
  final String? textContent;
  final int count;
  final bool isViewed;

  const StoryItem({required this.userId, this.userName, this.avatarUrl, this.type = 'image', this.textContent, this.count = 1, this.isViewed = false});
}
