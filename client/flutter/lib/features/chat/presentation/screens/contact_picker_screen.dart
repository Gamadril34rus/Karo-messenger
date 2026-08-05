// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../core/domain/charo_repository.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// Экран выбора контактов — для добавления участников в группу
/// или создания нового чата
class ContactPickerScreen extends StatefulWidget {
  final String chatId;
  final bool multiSelect;
  final String title;

  const ContactPickerScreen({
    super.key,
    required this.chatId,
    this.multiSelect = true,
    this.title = 'Добавить участников',
  });

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  List<ContactPickItem> _contacts = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repository = GetIt.instance<CharoRepository>();
      final contacts = await repository.getContacts();
      setState(() {
        _contacts = contacts.map((c) => ContactPickItem(
          userId: c.userId,
          displayName: c.displayName,
          username: c.username,
          avatarUrl: c.avatarUrl,
          isOnline: c.isOnline,
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Failed to load contacts: $e');
      setState(() {
        _error = 'Не удалось загрузить контакты';
        _isLoading = false;
      });
    }
  }

  List<ContactPickItem> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    final q = _searchQuery.toLowerCase();
    return _contacts.where((c) =>
        c.displayName.toLowerCase().contains(q) ||
        c.username.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_selectedIds.isNotEmpty)
            FilledButton(
              onPressed: _addSelected,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Добавить (${_selectedIds.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск контактов...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
          ),
          const SizedBox(height: 8),

          // Contact list
          Expanded(child: _buildBody()),
        ],
      ),
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
            FilledButton(onPressed: _loadContacts, child: const Text('Повторить')),
          ],
        ),
      );
    }

    final contacts = _filteredContacts;
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: context.colors.outline),
            const SizedBox(height: 16),
            Text('Нет контактов', style: context.typography.titleMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final isSelected = _selectedIds.contains(contact.userId);
        return _ContactPickTile(
          contact: contact,
          isSelected: isSelected,
          onTap: () {
            HapticService.selection();
            setState(() {
              if (isSelected) {
                _selectedIds.remove(contact.userId);
              } else {
                if (widget.multiSelect) {
                  _selectedIds.add(contact.userId);
                } else {
                  _selectedIds.clear();
                  _selectedIds.add(contact.userId);
                }
              }
            });
          },
        );
      },
    );
  }

  Future<void> _addSelected() async {
    if (_selectedIds.isEmpty) return;
    try {
      final repository = GetIt.instance<CharoRepository>();
      await repository.addChatMembers(widget.chatId, _selectedIds.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Добавлено ${_selectedIds.length} участников')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      logger.e('Add members failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
}

/// Модель контакта для выбора
class ContactPickItem {
  final String userId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final bool isOnline;

  const ContactPickItem({
    required this.userId,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.isOnline = false,
  });
}

/// Tile контакта с чекбоксом
class _ContactPickTile extends StatelessWidget {
  final ContactPickItem contact;
  final bool isSelected;
  final VoidCallback onTap;

  const _ContactPickTile({
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? context.colors.primary.withOpacity(0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                CharoAvatar(
                  radius: 24,
                  imageUrl: contact.avatarUrl,
                  fallbackText: contact.displayName,
                  isOnline: contact.isOnline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        style: context.typography.titleSmall?.copyWith(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      Text(
                        '@${contact.username}',
                        style: context.typography.bodySmall?.copyWith(
                          color: context.colors.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? context.colors.primary : Colors.transparent,
                    border: isSelected ? null : Border.all(color: context.colors.outline, width: 2),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
