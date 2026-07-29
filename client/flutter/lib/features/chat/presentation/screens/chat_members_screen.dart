import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Экран участников чата — показывает список участников группы/канала
class ChatMembersScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;

  const ChatMembersScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
  });

  @override
  State<ChatMembersScreen> createState() => _ChatMembersScreenState();
}

class _ChatMembersScreenState extends State<ChatMembersScreen> {
  List<ChatMemberInfo> _members = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiClient = GetIt.instance<ApiClient>();
      final response = await apiClient.get('/api/v1/chats/${widget.chatId}');
      final data = response.asMap;
      final membersList = data['members'] as List? ?? [];

      setState(() {
        _members = membersList
            .map((m) => ChatMemberInfo.fromJson(m as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Failed to load members: $e');
      setState(() {
        _error = 'Не удалось загрузить участников';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatTitle),
            Text(
              '${_members.length} участников',
              style: context.typography.bodySmall?.copyWith(
                color: context.colors.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _addMember,
            tooltip: 'Добавить участника',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.colors.error),
            const SizedBox(height: 16),
            Text(_error!, style: context.typography.bodyLarge),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadMembers,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: context.colors.outline),
            const SizedBox(height: 16),
            Text('Нет участников', style: context.typography.titleMedium),
          ],
        ),
      );
    }

    // Group members by role
    final owners = _members.where((m) => m.role == 'OWNER').toList();
    final admins = _members.where((m) => m.role == 'ADMIN').toList();
    final members = _members.where((m) => m.role == 'MEMBER').toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (owners.isNotEmpty)
          CharoSection(
            title: 'Владелец',
            children: owners.map((m) => _buildMemberTile(m)).toList(),
          ),
        if (admins.isNotEmpty)
          CharoSection(
            title: 'Администраторы (${admins.length})',
            children: admins.map((m) => _buildMemberTile(m)).toList(),
          ),
        if (members.isNotEmpty)
          CharoSection(
            title: 'Участники (${members.length})',
            children: members.map((m) => _buildMemberTile(m)).toList(),
          ),
      ],
    );
  }

  Widget _buildMemberTile(ChatMemberInfo member) {
    final roleLabel = member.role == 'OWNER'
        ? '👑 Владелец'
        : member.role == 'ADMIN'
            ? '⭐ Админ'
            : null;

    return CharoTile(
      icon: Icons.person_outline,
      iconColor: member.isOnline ? const Color(0xFF10B981) : context.colors.onSurface.withOpacity(0.4),
      title: member.displayName ?? member.username,
      subtitle: roleLabel ?? (member.isOnline ? 'В сети' : null),
      leading: CharoAvatar(
        radius: 22,
        imageUrl: member.avatarUrl,
        fallbackText: member.displayName ?? member.username,
        isOnline: member.isOnline,
      ),
      onTap: () => _viewMemberProfile(member),
    );
  }

  void _addMember() {
    // Navigate to contacts screen for member selection
    // In a full implementation, this would open a contact picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Выберите контакт для добавления')),
    );
  }

  void _viewMemberProfile(ChatMemberInfo member) {
    // Navigate to user profile
    context.goNamed('profile', pathParameters: {'id': member.userId});
  }
}

/// Модель участника чата
class ChatMemberInfo {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String role;
  final bool isOnline;

  const ChatMemberInfo({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.role = 'MEMBER',
    this.isOnline = false,
  });

  factory ChatMemberInfo.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? json;
    return ChatMemberInfo(
      userId: (user['id'] ?? json['userId'] ?? '') as String,
      username: (user['username'] ?? '') as String,
      displayName: user['displayName'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      role: (json['role'] ?? 'MEMBER') as String,
      isOnline: (user['isOnline'] ?? false) as bool,
    );
  }
}
