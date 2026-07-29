import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/ws_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Экран пересылки сообщения — выбор целевого чата
class ForwardMessageScreen extends StatefulWidget {
  final String messageId;
  final String? messagePreview;

  const ForwardMessageScreen({
    super.key,
    required this.messageId,
    this.messagePreview,
  });

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final apiClient = ApiClient.instance;
      final response = await apiClient.get('/api/v1/chats');
      final data = response.asList;
      setState(() {
        _chats = data.map<Map<String, dynamic>>((c) => c as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Failed to load chats for forwarding: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredChats {
    if (_searchQuery.isEmpty) return _chats;
    return _chats.where((c) {
      final title = (c['title'] as String?) ?? '';
      return title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _forwardTo(String chatId) {
    HapticService.medium();
    final wsClient = WsClient.instance;
    wsClient.send('message.forward', {
      'messageId': widget.messageId,
      'targetChatId': chatId,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Сообщение переслано'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Переслать'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              HapticService.light();
              // Toggle search
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Message preview ────────────────────────────────────
          if (widget.messagePreview != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: context.colors.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Пересылаемое сообщение', style: context.typography.labelSmall?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 4),
                  Text(
                    widget.messagePreview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodyMedium,
                  ),
                ],
              ),
            ),

          // ── Search bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск чатов...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
          ),

          const SizedBox(height: 8),

          // ── Chat list ──────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: context.colors.onSurface.withOpacity(0.15)),
                            const SizedBox(height: 16),
                            Text('Нет чатов', style: context.typography.titleMedium?.copyWith(
                              color: context.colors.onSurface.withOpacity(0.4),
                            )),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          final title = chat['title'] as String? ?? 'Чат';
                          final avatarUrl = chat['avatar_url'] as String?;
                          final lastMessage = chat['last_message'] as String?;

                          return CharoTile(
                            icon: Icons.chat_bubble_outline,
                            iconColor: context.colors.primary,
                            title: title,
                            subtitle: lastMessage ?? '',
                            onTap: () => _forwardTo(chat['id'] as String),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
