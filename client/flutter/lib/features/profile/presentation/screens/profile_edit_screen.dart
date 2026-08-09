// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../core/services/file_upload_service.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../bloc/profile_bloc.dart';

/// Экран редактирования профиля
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<ProfileBloc>().state;
    final profile = state is ProfileLoaded ? state : null;
    _nameController = TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Сохранить', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Avatar ────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _showAvatarOptions,
                child: Stack(
                  children: [
                    BlocBuilder<ProfileBloc, ProfileState>(
                      builder: (context, state) {
                        final avatarUrl = state is ProfileLoaded ? state.avatarUrl : null;
                        return CharoAvatar(
                          radius: 56,
                          imageUrl: avatarUrl,
                          fallbackText: _nameController.text.isNotEmpty ? _nameController.text[0] : '?',
                        );
                      },
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.colors.surface, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Name ──────────────────────────────────────────────
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Имя',
                hintText: 'Ваше имя',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 128,
            ),

            const SizedBox(height: 16),

            // ── Bio ───────────────────────────────────────────────
            TextField(
              controller: _bioController,
              decoration: InputDecoration(
                labelText: 'О себе',
                hintText: 'Расскажите о себе',
                prefixIcon: const Icon(Icons.info_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
              maxLength: 256,
            ),

            const SizedBox(height: 24),

            // ── Info ──────────────────────────────────────────────
            CharoCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Видимость', style: context.typography.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 12),
                  Text('Ваше имя и аватар видны всем. О себе можно скрыть в настройках приватности.',
                    style: context.typography.bodyMedium?.copyWith(
                      color: context.colors.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarOptions() {
    HapticService.instance.medium();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Изменить аватар', style: context.typography.titleLarge),
              const SizedBox(height: 16),
              CharoTile(icon: Icons.photo_camera, title: 'Камера', onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.camera);
              }),
              CharoTile(icon: Icons.photo_library, title: 'Галерея', onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.gallery);
              }),
              CharoTile(icon: Icons.auto_awesome, title: 'AI-аватар', onTap: () {
                Navigator.pop(ctx);
                context.read<ProfileBloc>().add(ProfileAvatarChanged(source: 'ai'));
              }),
              CharoTile(icon: Icons.delete_outline, title: 'Удалить', isDestructive: true, onTap: () {
                Navigator.pop(ctx);
                context.read<ProfileBloc>().add(ProfileAvatarChanged(source: 'remove'));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final type = source == ImageSource.camera ? FileType.image : FileType.image;
    final result = await FilePicker.platform.pickFiles(type: type, allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      final upload = await FileUploadService.instance.uploadFile(
        filePath: result.files.single.path!,
        chatId: 'avatar',
      );
      if (upload != null) {
        if (mounted) {
          context.read<ProfileBloc>().add(ProfileAvatarChanged(source: 'gallery'));
        }
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    HapticService.instance.medium();

    context.read<ProfileBloc>().add(ProfileUpdated(
      displayName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
    ));

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль обновлён'), duration: Duration(seconds: 2)),
      );
      Navigator.of(context).pop();
    }
  }
}

enum ImageSource { camera, gallery }
