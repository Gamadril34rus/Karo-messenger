import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/domain/charo_repository.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/widgets/charo_widgets.dart';

/// ─── Global Search Screen ───────────────────────────────────────
/// Поиск по чатам, сообщениям и контактам.

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSearching = false;
  List<_SearchResult> _results = [];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final repository = GetIt.instance<CharoRepository>();
      final result = await repository.search(query.trim());

      final results = <_SearchResult>[];

      for (final chat in result.chats) {
        results.add(_SearchResult(
          type: 'chat',
          id: chat.id,
          title: chat.title ?? 'Чат',
          subtitle: chat.lastMessage ?? '',
          icon: Icons.chat_bubble_outline,
          color: const Color(0xFF2563EB),
        ));
      }

      for (final msg in result.messages) {
        results.add(_SearchResult(
          type: 'message',
          id: msg.id,
          title: msg.senderName ?? msg.senderId,
          subtitle: msg.text ?? '',
          icon: Icons.message_outlined,
          color: const Color(0xFF10B981),
          chatId: msg.chatId,
        ));
      }

      for (final contact in result.contacts) {
        results.add(_SearchResult(
          type: 'contact',
          id: contact.userId,
          title: contact.displayName ?? contact.username,
          subtitle: '@${contact.username}',
          icon: Icons.person_outline,
          color: const Color(0xFF8B5CF6),
        ));
      }

      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      logger.e('Search failed: $e');
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Поиск чатов, сообщений, контактов...',
            border: InputBorder.none,
          ),
          style: context.typography.bodyLarge,
          onChanged: _onSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _results = [];
                  _isSearching = false;
                });
              },
            ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? _buildEmptyState()
              : _buildResults(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: context.colors.outline),
          const SizedBox(height: 16),
          Text(
            'Начните вводить для поиска',
            style: context.typography.bodyLarge?.copyWith(
              color: context.colors.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    // Group by type
    final chatResults = _results.where((r) => r.type == 'chat').toList();
    final messageResults = _results.where((r) => r.type == 'message').toList();
    final contactResults = _results.where((r) => r.type == 'contact').toList();

    return ListView(
      children: [
        if (chatResults.isNotEmpty) ...[
          _buildSectionHeader('Чаты', chatResults.length),
          ...chatResults.map((r) => _buildResultTile(r, () => context.go('/chat/${r.id}'))),
        ],
        if (contactResults.isNotEmpty) ...[
          _buildSectionHeader('Контакты', contactResults.length),
          ...contactResults.map((r) => _buildResultTile(r, () => context.go('/profile/${r.id}'))),
        ],
        if (messageResults.isNotEmpty) ...[
          _buildSectionHeader('Сообщения', messageResults.length),
          ...messageResults.map((r) => _buildResultTile(r, () {
            if (r.chatId != null) context.go('/chat/${r.chatId}');
          })),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        '$title ($count)',
        style: context.typography.labelMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildResultTile(_SearchResult result, VoidCallback onTap) {
    return CharoTile(
      icon: result.icon,
      iconColor: result.color,
      title: result.title,
      subtitle: result.subtitle,
      onTap: onTap,
    );
  }
}

class _SearchResult {
  final String type;
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? chatId;

  const _SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.chatId,
  });
}
