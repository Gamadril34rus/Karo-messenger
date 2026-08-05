// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/domain/charo_repository.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Экран создания нового чата — выбор пользователя
class CreateChatScreen extends StatefulWidget {
  final String chatType; // private, group, channel, secret

  const CreateChatScreen({super.key, this.chatType = 'private'});

  @override
  State<CreateChatScreen> createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends State<CreateChatScreen> {
  final _searchController = TextEditingController();
  List<UserSearchResult> _users = [];
  List<UserSearchResult> _selectedUsers = [];
  bool _isLoading = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().length < 2) {
      setState(() => _users = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repository = GetIt.instance<CharoRepository>();
      final users = await repository.searchUsers(query.trim());
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Search users failed: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleUser(UserSearchResult user) {
    HapticService.light();
    setState(() {
      if (_selectedUsers.any((u) => u.userId == user.userId)) {
        _selectedUsers.removeWhere((u) => u.userId == user.userId);
      } else {
        if (widget.chatType == 'private' && _selectedUsers.length >= 1) {
          _selectedUsers.clear();
        }
        _selectedUsers.add(user);
      }
    });
  }

  Future<void> _createChat() async {
    if (_selectedUsers.isEmpty) return;

    setState(() => _isCreating = true);
    HapticService.medium();

    try {
      final repository = GetIt.instance<CharoRepository>();

      final memberIds = _selectedUsers.map((u) => u.userId).toList();
      final chat = await repository.createChat(widget.chatType, null, memberIds);
      if (mounted) context.go('/chat/${chat.id}');
    } catch (e) {
      logger.e('Create chat failed: $e');
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось создать чат')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (_selectedUsers.isNotEmpty)
            TextButton(
              onPressed: _isCreating ? null : _createChat,
              child: _isCreating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Создать', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Selected users chips ───────────────────────────────
          if (_selectedUsers.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _selectedUsers.map((u) {
                  return Chip(
                    avatar: CharoAvatar(
                      radius: 14,
                      imageUrl: u.avatarUrl,
                      fallbackText: u.displayName ?? u.username,
                    ),
                    label: Text(u.displayName ?? u.username),
                    onDeleted: () => _toggleUser(u),
                  );
                }).toList(),
              ),
            ),

          // ── Search bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Поиск по имени или username...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: _searchUsers,
            ),
          ),

          const SizedBox(height: 8),

          // ── Results ────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search, size: 48, color: context.colors.onSurface.withOpacity(0.15)),
                            const SizedBox(height: 16),
                            Text('Введите имя для поиска', style: context.typography.bodyLarge?.copyWith(
                              color: context.colors.onSurface.withOpacity(0.4),
                            )),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final isSelected = _selectedUsers.any((u) => u.userId == user.userId);
                          return CharoTile(
                            icon: isSelected ? Icons.check_circle : Icons.person_outline,
                            iconColor: isSelected ? context.colors.primary : context.colors.onSurface.withOpacity(0.5),
                            title: user.displayName ?? user.username,
                            subtitle: '@${user.username}',
                            onTap: () => _toggleUser(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String get _title {
    switch (widget.chatType) {
      case 'group': return 'Новая группа';
      case 'channel': return 'Новый канал';
      case 'secret': return 'Секретный чат';
      default: return 'Новый чат';
    }
  }
}
