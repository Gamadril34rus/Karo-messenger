import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/block_list_service.dart';
import '../../../../core/domain/charo_repository.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// ─── Block List Screen ─────────────────────────────────────────
/// Чёрный список: просмотр и управление заблокированными.

class BlockListScreen extends StatefulWidget {
  const BlockListScreen({super.key});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  late BlockListService _blockService;
  bool _isLoading = true;
  List<BlockedUser> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _blockService = BlockListService(repository: GetIt.instance<CharoRepository>());
    _loadBlockedUsers();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    try {
      await _blockService.loadBlockList();
      final ids = _blockService.blockedUserIds;
      setState(() {
        _blockedUsers = ids.map((id) => BlockedUser(
          id: id,
          username: id.length > 8 ? id.substring(0, 8) : id,
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Block list load failed: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заблокированные'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? _buildEmptyState(theme)
              : _buildBlockList(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Нет заблокированных пользователей',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Заблокируйте пользователя из его профиля',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockList(ThemeData theme) {
    return ListView.builder(
      itemCount: _blockedUsers.length,
      itemBuilder: (context, index) {
        final user = _blockedUsers[index];
        return CharoTile(
          icon: Icons.person_outline,
          iconColor: theme.colorScheme.error,
          title: user.username,
          trailing: TextButton(
            onPressed: () => _unblockUser(user.id),
            child: const Text('Разблокировать'),
          ),
        );
      },
    );
  }

  Future<void> _unblockUser(String userId) async {
    try {
      await _blockService.unblockUser(userId);
      _loadBlockedUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь разблокирован')),
        );
      }
    } catch (e) {
      logger.e('Unblock failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
}

class BlockedUser {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  const BlockedUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });
}
