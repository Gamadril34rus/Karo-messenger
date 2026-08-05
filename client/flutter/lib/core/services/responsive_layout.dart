// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';

/// ─── Responsive Layout ───────────────────────────────────────────
/// Адаптивный layout для мобильных / планшетов / десктопа.
/// Определяет тип устройства и предоставляет соответствующие виджеты.

enum DeviceType { mobile, tablet, desktop }

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// Определить тип устройства
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return DeviceType.desktop;
    if (width >= 600) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  /// Является ли десктопом
  static bool isDesktop(BuildContext context) => getDeviceType(context) == DeviceType.desktop;

  /// Является ли планшетом
  static bool isTablet(BuildContext context) => getDeviceType(context) == DeviceType.tablet;

  /// Является ли мобильным
  static bool isMobile(BuildContext context) => getDeviceType(context) == DeviceType.mobile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= 600) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}

/// Адаптивный Master-Detail layout для чатов
class MasterDetailLayout extends StatelessWidget {
  final Widget masterPanel;
  final Widget detailPanel;
  final Widget? emptyState;
  final bool hasSelection;

  const MasterDetailLayout({
    super.key,
    required this.masterPanel,
    required this.detailPanel,
    this.emptyState,
    this.hasSelection = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (isDesktop) {
      // Desktop: side-by-side panels
      return Row(
        children: [
          // Master panel (chat list) — fixed width
          SizedBox(
            width: 360,
            child: masterPanel,
          ),
          // Divider
          const VerticalDivider(width: 1),
          // Detail panel (chat detail) — fills remaining space
          Expanded(
            child: hasSelection
                ? detailPanel
                : emptyState ?? const _EmptyChatState(),
          ),
        ],
      );
    }

    // Mobile: full-screen panels
    return hasSelection ? detailPanel : masterPanel;
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Выберите чат',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
