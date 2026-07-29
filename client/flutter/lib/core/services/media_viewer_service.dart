import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/logger.dart';

/// ─── Media Viewer Service ────────────────────────────────────────
/// Полноэкранный просмотр фото и видео в чате.
/// Pinch-to-zoom, swipe между медиа, кнопки «Сохранить»/«Поделиться».

class MediaViewerScreen extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final int initialIndex;
  final String chatTitle;

  const MediaViewerScreen({
    super.key,
    required this.mediaItems,
    this.initialIndex = 0,
    this.chatTitle = '',
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls ? AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.mediaItems.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt, color: Colors.white),
            onPressed: () => _saveMedia(context),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareMedia(context),
          ),
        ],
      ) : null,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.mediaItems.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final item = widget.mediaItems[index];
            return _buildMediaItem(context, item);
          },
        ),
      ),
    );
  }

  Widget _buildMediaItem(BuildContext context, MediaItem item) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: item.type == MediaType.video
            ? _buildVideoPlaceholder(item)
            : _buildImage(item),
      ),
    );
  }

  Widget _buildImage(MediaItem item) {
    if (item.url != null && item.url!.isNotEmpty) {
      return Image.network(
        item.url!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
              color: Colors.white,
            ),
          );
        },
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image,
          color: Colors.white54,
          size: 64,
        ),
      );
    }
    return const Icon(Icons.image, color: Colors.white54, size: 64);
  }

  Widget _buildVideoPlaceholder(MediaItem item) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (item.thumbnailUrl != null)
          Image.network(item.thumbnailUrl!, fit: BoxFit.contain),
        Container(
          decoration: const BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(16),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
        ),
      ],
    );
  }

  Future<void> _saveMedia(BuildContext context) async {
    final item = widget.mediaItems[_currentIndex];
    final sourcePath = item.localPath ?? item.url;

    if (sourcePath == null || sourcePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Невозможно сохранить — нет файла')),
      );
      return;
    }

    try {
      // If it's a local file, share it directly (which also allows saving)
      if (item.localPath != null && File(item.localPath!).existsSync()) {
        await Share.shareXFiles([XFile(item.localPath!)], text: 'ЧАРО — медиа');
      } else {
        // For network images, share the URL
        await Share.share(sourcePath, subject: 'ЧАРО — медиа');
      }
      logger.i('💾 Media saved/shared: ${item.id}');
    } catch (e) {
      logger.e('💾 Save/share failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _shareMedia(BuildContext context) async {
    final item = widget.mediaItems[_currentIndex];
    final sourcePath = item.localPath ?? item.url;

    if (sourcePath == null || sourcePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Невозможно поделиться — нет файла')),
      );
      return;
    }

    try {
      if (item.localPath != null && File(item.localPath!).existsSync()) {
        await Share.shareXFiles([XFile(item.localPath!)], text: 'ЧАРО — медиа');
      } else {
        await Share.share(sourcePath, subject: 'ЧАРО — медиа');
      }
      logger.i('📤 Media shared: ${item.id}');
    } catch (e) {
      logger.e('📤 Share failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }
}

class MediaItem {
  final String id;
  final MediaType type;
  final String? url;
  final String? thumbnailUrl;
  final String? localPath;

  const MediaItem({
    required this.id,
    required this.type,
    this.url,
    this.thumbnailUrl,
    this.localPath,
  });
}

enum MediaType { image, video }
