// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Кастомный заголовок окна для десктопа
/// Поддерживает перетаскивание, кнопки управления, тему
class DesktopTitleBar extends StatelessWidget {
  final Widget? title;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;

  const DesktopTitleBar({
    super.key,
    this.title,
    this.actions,
    this.showBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Кнопка назад
          if (showBack)
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              onPressed: onBack,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),

          // Drag area + title
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: title ?? _defaultTitle(theme),
              ),
            ),
          ),

          // Custom actions
          if (actions != null) ...actions!,

          // Window control buttons (Windows & Linux)
          if (Platform.isWindows || Platform.isLinux) ..._windowButtons(isDark),
        ],
      ),
    );
  }

  Widget _defaultTitle(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.chat_bubble,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'ЧАРО',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.brightness == Brightness.dark
                ? Colors.white70
                : Colors.black87,
          ),
        ),
      ],
    );
  }

  List<Widget> _windowButtons(bool isDark) {
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final hoverColor = isDark ? Colors.white12 : Colors.black5;

    return [
      // Minimize
      _WindowButton(
        icon: Icons.remove,
        iconColor: iconColor,
        hoverColor: hoverColor,
        onTap: () => windowManager.minimize(),
      ),
      // Maximize/Restore
      _WindowButton(
        icon: Icons.crop_square,
        iconColor: iconColor,
        hoverColor: hoverColor,
        onTap: () async {
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        },
      ),
      // Close
      _WindowButton(
        icon: Icons.close,
        iconColor: iconColor,
        hoverColor: Colors.red.withOpacity(0.1),
        hoverIconColor: Colors.red,
        onTap: () => windowManager.close(),
      ),
    ];
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color hoverColor;
  final Color? hoverIconColor;
  final VoidCallback onTap;

  const _WindowButton({
    required this.icon,
    required this.iconColor,
    required this.hoverColor,
    this.hoverIconColor,
    required this.onTap,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 40,
          color: _hovering ? widget.hoverColor : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _hovering && widget.hoverIconColor != null
                ? widget.hoverIconColor
                : widget.iconColor,
          ),
        ),
      ),
    );
  }
}
