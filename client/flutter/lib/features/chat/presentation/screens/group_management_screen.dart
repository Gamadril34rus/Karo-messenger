// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/group_management_service.dart';
import '../../../../core/domain/charo_repository.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// ─── Group Management Screen ────────────────────────────────────
/// Управление группой: название, аватар, участники, роли.

class GroupManagementScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;
  final String? avatarUrl;

  const GroupManagementScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    this.avatarUrl,
  });

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late TextEditingController _titleController;
  bool _isLoading = false;
  List<GroupMember> _members = [];
  late GroupManagementService _groupService;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.chatTitle);
    _groupService = GroupManagementService(repository: GetIt.instance<CharoRepository>());
    _loadMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final repository = GetIt.instance<CharoRepository>();
      final members = await repository.getChatMembers(widget.chatId);
      setState(() {
        _members = members.map((m) => ListTile(
          userId: m.userId,
          username: m.username,
          displayName: m.displayName,
          avatarUrl: m.avatarUrl,
          role: m.role,
          isOnline: m.isOnline,
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Failed to load members: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление группой'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Avatar ────────────────────────────────────────────
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: widget.avatarUrl != null
                        ? NetworkImage(widget.avatarUrl!)
                        : null,
                    child: widget.avatarUrl == null
                        ? Text(widget.chatTitle[0].toUpperCase(), style: const TextStyle(fontSize: 36))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.camera_alt, color: theme.colorScheme.onPrimary, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Title ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('Название группы', style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              )),
            ),
            CharoCard(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'Название группы',
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Members ──────────────────────────────────────────
            CharoSection(
              title: 'Участники (${_members.length})',
              children: [
                CharoTile(
                  icon: Icons.person_add_outlined,
                  iconColor: const Color(0xFF4CAF50),
                  title: 'Добавить участника',
                  onTap: _addMember,
                ),
                for (final member in _members)
                  _buildMemberTile(context, member),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Danger Zone ──────────────────────────────────────
            CharoSection(
              title: 'Опасная зона',
              children: [
                CharoTile(
                  icon: Icons.exit_to_app,
                  iconColor: const Color(0xFFFF9800),
                  title: 'Покинуть группу',
                  onTap: _leaveGroup,
                ),
                CharoTile(
                  icon: Icons.delete_forever,
                  iconColor: const Color(0xFFF44336),
                  title: 'Удалить группу',
                  isDestructive: true,
                  onTap: _deleteGroup,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, GroupMember member) {
    final roleLabel = member.role == 'OWNER' ? '👑 Владелец'
        : member.role == 'ADMIN' ? '⭐ Админ' : '';
    return CharoTile(
      icon: Icons.person_outline,
      iconColor: const Color(0xFF3B82F6),
      title: member.displayName ?? member.username,
      subtitle: roleLabel.isNotEmpty ? roleLabel : null,
      trailing: member.role != 'OWNER'
          ? PopupMenuButton<String>(
              onSelected: (action) => _handleMemberAction(action, member),
              itemBuilder: (_) => [
                if (member.role == 'MEMBER') const PopupMenuItem(value: 'admin', child: Text('Сделать админом')),
                if (member.role == 'ADMIN') const PopupMenuItem(value: 'member', child: Text('Снять админа')),
                const PopupMenuItem(value: 'remove', child: Text('Удалить')),
              ],
            )
          : null,
    );
  }

  void _addMember() {
    // Show contact picker — navigate to contacts screen
  }

  void _handleMemberAction(String action, GroupMember member) async {
    try {
      if (action == 'admin') {
        await _groupService.updateMemberRole(
          chatId: widget.chatId, userId: member.userId, role: 'ADMIN',
        );
      } else if (action == 'member') {
        await _groupService.updateMemberRole(
          chatId: widget.chatId, userId: member.userId, role: 'MEMBER',
        );
      } else if (action == 'remove') {
        await _groupService.removeMember(
          chatId: widget.chatId, userId: member.userId,
        );
      }
      _loadMembers();
    } catch (e) {
      logger.e('Member action failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty) return;
    try {
      await _groupService.updateGroupInfo(
        chatId: widget.chatId,
        title: _titleController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      logger.e('Save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Покинуть группу?'),
        content: const Text('Вы не сможете вернуться без приглашения.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Покинуть')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _groupService.leaveGroup(widget.chatId);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        logger.e('Leave group failed: $e');
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: const Text('Это действие необратимо. Все сообщения будут удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _groupService.deleteGroup(widget.chatId);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        logger.e('Delete group failed: $e');
      }
    }
  }
}
