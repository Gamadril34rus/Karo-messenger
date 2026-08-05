// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';

/// ─── Reactions Picker ───────────────────────────────────────────
/// Быстрый выбор эмодзи-реакции на сообщение.
/// Long-press → реакция → отправка на сервер.

class ReactionsPicker extends StatelessWidget {
  final ValueChanged<String> onReactionSelected;
  final List<String> recentReactions;

  const ReactionsPicker({
    super.key,
    required this.onReactionSelected,
    this.recentReactions = const [],
  });

  /// Быстрые реакции (6 штук) — как в Telegram/WhatsApp
  static const List<String> quickReactions = [
    '❤️', '👍', '😂', '😮', '😢', '🔥',
  ];

  /// Расширенный набор
  static const List<String> extendedReactions = [
    '❤️', '👍', '👎', '😂', '😮', '😢', '🔥', '🎉',
    '🤔', '👀', '💯', '🙏', '👏', '🤝', '💀', '🤣',
    '😤', '🥺', '😍', '🤮', '💪', '🫡', '🤯', '😏',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick reactions
          for (final emoji in quickReactions)
            _ReactionButton(
              emoji: emoji,
              onTap: () => onReactionSelected(emoji),
            ),
          // More button
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showExtendedPicker(context),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.add, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExtendedPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Recent
            if (recentReactions.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Недавние', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recentReactions.map((e) => _ReactionButton(
                  emoji: e,
                  onTap: () { onReactionSelected(e); Navigator.pop(context); },
                  size: 36,
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            // Extended
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Все реакции', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: extendedReactions.map((e) => _ReactionButton(
                emoji: e,
                onTap: () { onReactionSelected(e); Navigator.pop(context); },
                size: 36,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;
  final double size;

  const _ReactionButton({
    required this.emoji,
    required this.onTap,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(emoji, style: TextStyle(fontSize: size * 0.55)),
        ),
      ),
    );
  }
}
