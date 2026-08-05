// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// CharoAccessibility — centralized accessibility helpers for the ЧАРО messenger.
///
/// Provides semantic label helpers, announce helpers, and a11y testing utilities.
class CharoAccessibility {
  CharoAccessibility._();

  /// Wrap a widget with a semantic label for screen readers.
  static Widget labeled({
    required String label,
    required Widget child,
    String? hint,
    bool button = false,
    bool enabled = true,
    bool inMutuallyExclusiveGroup = false,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: button,
      enabled: enabled,
      inMutuallyExclusiveGroup: inMutuallyExclusiveGroup,
      child: child,
    );
  }

  /// Create a semantic button for screen readers.
  static Widget iconButton({
    required String label,
    required Widget icon,
    required VoidCallback onPressed,
    String? hint,
  }) {
    return Semantics(
      label: label,
      hint: hint ?? 'Нажмите для действия',
      button: true,
      enabled: true,
      child: GestureDetector(
        onTap: onPressed,
        child: icon,
      ),
    );
  }

  /// Create a live region for dynamic content updates.
  static Widget liveRegion({
    required Widget child,
    bool assertive = false,
  }) {
    return Semantics(
      liveRegion: true,
      attributedLabel: AttributedString(assertive ? '' : ''),
      child: child,
    );
  }

  /// Announce a message to screen readers via the semantics tree.
  static void announce(BuildContext context, String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Create a semantic header for sections.
  static Widget header({
    required String label,
    required Widget child,
  }) {
    return Semantics(
      header: true,
      label: label,
      child: child,
    );
  }

  /// Create a semantic group for related items.
  static Widget group({
    required String label,
    required Widget child,
  }) {
    return Semantics(
      container: true,
      label: label,
      child: child,
    );
  }

  /// Create a chat list item with full semantic accessibility.
  static Widget chatItem({
    required String chatTitle,
    required String lastMessage,
    required int unreadCount,
    required bool isOnline,
    required bool isPinned,
    required bool isMuted,
    required Widget child,
  }) {
    final parts = <String>[
      chatTitle,
      if (isOnline) 'в сети',
      if (isPinned) 'закреплён',
      if (isMuted) 'уведомления отключены',
      lastMessage,
      if (unreadCount > 0) '$unreadCount непрочитанных',
    ];

    return Semantics(
      label: parts.join(', '),
      button: true,
      enabled: true,
      child: child,
    );
  }

  /// Create a message bubble with full semantic accessibility.
  static Widget messageBubble({
    required String senderName,
    required String content,
    required String time,
    required bool isMe,
    required bool isRead,
    required bool isEdited,
    required Widget child,
  }) {
    final parts = <String>[
      isMe ? 'Вы' : senderName,
      content,
      time,
      if (isEdited) 'редактировано',
      if (isMe && isRead) 'прочитано',
    ];

    return Semantics(
      label: parts.join(', '),
      child: child,
    );
  }

  /// Create a contact item with semantic accessibility.
  static Widget contactItem({
    required String displayName,
    required String? username,
    required bool isOnline,
    required bool isBlocked,
    required Widget child,
  }) {
    final parts = <String>[
      displayName,
      if (username != null) '@$username',
      if (isOnline) 'в сети',
      if (isBlocked) 'заблокирован',
    ];

    return Semantics(
      label: parts.join(', '),
      button: true,
      enabled: !isBlocked,
      child: child,
    );
  }

  /// Create a call item with semantic accessibility.
  static Widget callItem({
    required String callerName,
    required String callType,
    required String direction,
    required String time,
    required bool isMissed,
    required Widget child,
  }) {
    final parts = <String>[
      callerName,
      callType,
      direction == 'incoming' ? 'входящий' : 'исходящий',
      if (isMissed) 'пропущенный',
      time,
    ];

    return Semantics(
      label: parts.join(', '),
      button: true,
      enabled: true,
      child: child,
    );
  }

  /// Create a story item with semantic accessibility.
  static Widget storyItem({
    required String userName,
    required bool hasUnviewed,
    required Widget child,
  }) {
    return Semantics(
      label: 'История от $userName${hasUnviewed ? ', непросмотренная' : ''}',
      button: true,
      enabled: true,
      child: child,
    );
  }
}
