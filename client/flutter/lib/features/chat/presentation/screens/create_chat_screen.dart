import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../core/network/api_client.dart';
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
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _selectedUsers = [];
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
      final apiClient = ApiClient.instance;
      final response = await apiClient.get(
        '/api/v1/users/search',
        queryParameters: {'q': query.trim()},
      );
      final data = response.asMap;
      final users = (data['data'] as List?) ?? [];
      setState(() {
        _users = users.map<Map<String, dynamic>>((u) => u as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Search users failed: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleUser(Map<String, dynamic> user) {
    HapticService.light();
    final userId = user['id'] as String;
    setState(() {
      if (_selectedUsers.any((u) => u['id'] == userId)) {
        _selectedUsers.removeWhere((u) => u['id'] == userId);
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
      final apiClient = ApiClient.instance;
      final targetUserId = _selectedUsers.first['id'] as String;

      if (widget.chatType == 'private') {
        final response = await apiClient.post('/api/v1/chats', data: {
          'type': 'private',
          'targetUserId': targetUserId,
        });
        final chatData = response.asMap;
        final chatId = chatData['id'] as String;
        if (mounted) context.go('/chat/$chatId');
      } else {
        // Group/Channel/Secret
        final memberIds = _selectedUsers.map((u) => u['id'] as String).toList();
        final response = await apiClient.post('/api/v1/chats', data: {
          'type': widget.chatType,
          'memberIds': memberIds,
        });
        final chatData = response.asMap;
        final chatId = chatData['id'] as String;
        if (mounted) context.go('/chat/$chatId');
      }
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
                      imageUrl: u['avatar_url'] as String?,
                      fallbackText: (u['display_name'] as String?) ?? (u['username'] as String?) ?? '?',
                    ),
                    label: Text(u['display_name'] as String? ?? u['username'] as String? ?? ''),
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
                          final isSelected = _selectedUsers.any((u) => u['id'] == user['id']);
                          return CharoTile(
                            icon: isSelected ? Icons.check_circle : Icons.person_outline,
                            iconColor: isSelected ? context.colors.primary : context.colors.onSurface.withOpacity(0.5),
                            title: user['display_name'] as String? ?? user['username'] as String? ?? 'Без имени',
                            subtitle: '@${user['username'] ?? ''}',
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
