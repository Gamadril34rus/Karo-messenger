import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../core/services/file_upload_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../bloc/stories_bloc.dart';

/// Экран создания истории — выбор фото/видео/текст, предпросмотр, публикация
class StoryCreateScreen extends StatefulWidget {
  final String storyType;

  const StoryCreateScreen({super.key, this.storyType = 'image'});

  @override
  State<StoryCreateScreen> createState() => _StoryCreateScreenState();
}

class _StoryCreateScreenState extends State<StoryCreateScreen> {
  String _type = 'image';
  File? _selectedFile;
  String? _mediaUrl;
  String _textContent = '';
  String _backgroundColor = '#6366F1';
  bool _isUploading = false;
  bool _isPublishing = false;

  final _textController = TextEditingController();

  static const _bgColors = [
    '#6366F1', '#3B82F6', '#10B981', '#F59E0B', '#EF4444',
    '#8B5CF6', '#EC4899', '#06B6D4', '#1E293B', '#0F172A',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.storyType;
    if (_type == 'text') {
      _textController.addListener(() => setState(() => _textContent = _textController.text));
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая история'),
        actions: [
          if (_canPublish())
            FilledButton(
              onPressed: _isPublishing ? null : _publish,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isPublishing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Опубликовать'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Type selector ──────────────────────────────────────
            _buildTypeSelector(),
            const SizedBox(height: 20),

            // ── Content area ───────────────────────────────────────
            if (_type == 'image' || _type == 'video')
              _buildMediaSection(),
            if (_type == 'text')
              _buildTextSection(),

            const SizedBox(height: 24),

            // ── Preview ────────────────────────────────────────────
            if (_selectedFile != null || _textContent.isNotEmpty)
              _buildPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        _TypeChip(label: 'Фото', icon: Icons.photo_outlined, selected: _type == 'image', onTap: () => setState(() => _type = 'image')),
        const SizedBox(width: 8),
        _TypeChip(label: 'Видео', icon: Icons.videocam_outlined, selected: _type == 'video', onTap: () => setState(() => _type = 'video')),
        const SizedBox(width: 8),
        _TypeChip(label: 'Текст', icon: Icons.text_fields, selected: _type == 'text', onTap: () => setState(() => _type = 'text')),
      ],
    );
  }

  Widget _buildMediaSection() {
    return Column(
      children: [
        if (_selectedFile != null)
          Stack(
            children: [
              Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: _type == 'image'
                    ? Image.file(_selectedFile!, fit: BoxFit.contain)
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(color: Colors.black87),
                          const Icon(Icons.play_circle_outline, color: Colors.white, size: 64),
                          Positioned(
                            bottom: 16,
                            child: Text(
                              'Видео выбрано',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                            ),
                          ),
                        ],
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => setState(() => _selectedFile = null),
                  icon: const Icon(Icons.close, size: 18),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
              if (_isUploading)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
            ],
          )
        else
          GestureDetector(
            onTap: _pickMedia,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: context.colors.outlineVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.colors.outline.withOpacity(0.3), width: 2, strokeAlign: BorderSide.strokeAlignOutside),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _type == 'image' ? Icons.add_photo_alternate_outlined : Icons.videocam_outlined,
                    size: 64,
                    color: context.colors.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _type == 'image' ? 'Выбрать фото' : 'Выбрать видео',
                    style: context.typography.titleMedium?.copyWith(
                      color: context.colors.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Нажмите, чтобы выбрать из галереи',
                    style: context.typography.bodySmall?.copyWith(
                      color: context.colors.onSurface.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (_selectedFile == null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickMedia,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Галерея'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Камера'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTextSection() {
    return Column(
      children: [
        // Background color picker
        Text('Цвет фона', style: context.typography.labelMedium?.copyWith(
          color: context.colors.primary, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _bgColors.map((hex) {
            final isSelected = _backgroundColor == hex;
            return GestureDetector(
              onTap: () => setState(() => _backgroundColor = hex),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _parseColor(hex),
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                  boxShadow: isSelected ? [BoxShadow(color: _parseColor(hex), blurRadius: 8)] : null,
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Text input
        TextField(
          controller: _textController,
          maxLines: 6,
          maxLength: 500,
          style: context.typography.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          decoration: InputDecoration(
            hintText: 'Напишите что-нибудь...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return CharoCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.preview_outlined, size: 20, color: context.colors.primary),
              const SizedBox(width: 8),
              Text('Предпросмотр', style: context.typography.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: _type == 'text' ? _parseColor(_backgroundColor) : Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _type == 'text'
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _textContent.isEmpty ? 'Ваш текст...' : _textContent,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : _selectedFile != null && _type == 'image'
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_selectedFile!, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
            ),
          ),
        ],
      ),
    );
  }

  bool _canPublish() {
    if (_type == 'text') return _textContent.trim().isNotEmpty;
    return _selectedFile != null;
  }

  Future<void> _pickMedia() async {
    HapticService.light();
    try {
      final fileType = _type == 'image' ? FileType.image : FileType.video;
      final result = await FilePicker.platform.pickFiles(type: fileType, allowMultiple: false);
      if (result != null && result.files.single.path != null) {
        setState(() => _selectedFile = File(result.files.single.path!));
      }
    } catch (e) {
      logger.e('Media pick failed: $e');
    }
  }

  Future<void> _pickCamera() async {
    HapticService.light();
    try {
      // Camera capture — use image_picker or camera package
      // For now, fall back to gallery
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (result != null && result.files.single.path != null) {
        setState(() => _selectedFile = File(result.files.single.path!));
      }
    } catch (e) {
      logger.e('Camera pick failed: $e');
    }
  }

  Future<void> _publish() async {
    setState(() => _isPublishing = true);
    try {
      String? mediaUrl;

      // Upload media if image/video
      if (_selectedFile != null && _type != 'text') {
        setState(() => _isUploading = true);
        final upload = await FileUploadService.instance.uploadFile(
          filePath: _selectedFile!.path,
          chatId: 'stories',
          mimeType: _type == 'image' ? 'image/jpeg' : 'video/mp4',
        );
        mediaUrl = upload?.url;
        setState(() => _isUploading = false);

        if (mediaUrl == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ошибка загрузки медиа')),
            );
          }
          setState(() => _isPublishing = false);
          return;
        }
      }

      // Create story via API
      final data = <String, dynamic>{
        'type': _type.toUpperCase(),
      };

      if (_type == 'text') {
        data['content'] = _textContent;
        data['background_color'] = _backgroundColor;
      } else if (mediaUrl != null) {
        data['media_url'] = mediaUrl;
      }

      context.read<StoriesBloc>().add(StoryPublishRequested(type: _type));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('История опубликована! ✨')),
        );
        context.go('/stories');
      }
    } catch (e) {
      logger.e('Story publish failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}

/// Chip for selecting story type
class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticService.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? context.colors.primary : context.colors.outlineVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : context.colors.onSurface.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text(label, style: context.typography.bodyMedium?.copyWith(
              color: selected ? Colors.white : context.colors.onSurface.withOpacity(0.6),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }
}
