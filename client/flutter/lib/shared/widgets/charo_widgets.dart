// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

// ─── CharoCard ──────────────────────────────────────────────────────
/// Premium card with glassmorphism effect, rounded corners, and optional
/// gradient background. Use for all grouped content sections.
class CharoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color? color;
  final List<Color>? gradientColors;
  final Gradient? gradient;
  final double borderWidth;
  final Color? borderColor;
  final double elevation;

  const CharoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.radius = 16,
    this.color,
    this.gradientColors,
    this.gradient,
    this.borderWidth = 0,
    this.borderColor,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bgColor = color ?? colors.outlineVariant;

    BoxDecoration decoration;
    if (gradient != null) {
      decoration = BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? colors.outline, width: borderWidth)
            : null,
        boxShadow: elevation > 0
            ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: elevation * 2, offset: Offset(0, elevation))]
            : null,
      );
    } else if (gradientColors != null && gradientColors!.length >= 2) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors!,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? colors.outline, width: borderWidth)
            : null,
      );
    } else {
      decoration = BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? colors.outline, width: borderWidth)
            : null,
        boxShadow: elevation > 0
            ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: elevation * 2, offset: Offset(0, elevation))]
            : null,
      );
    }

    return Container(
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );
  }
}

// ─── CharoSection ───────────────────────────────────────────────────
/// Grouped settings section with a title header and rounded card body.
/// Replaces raw Divider + ListTile patterns with premium grouped layout.
class CharoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const CharoSection({
    super.key,
    required this.title,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: context.typography.labelMedium?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        CharoCard(
          margin: margin,
          padding: EdgeInsets.zero,
          radius: 16,
          child: Column(
            children: _insertDividers(children, context),
          ),
        ),
      ],
    );
  }

  /// Insert subtle dividers between items, but not after the last one
  List<Widget> _insertDividers(List<Widget> items, BuildContext context) {
    final result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: context.colors.outline.withOpacity(0.5),
          ),
        ));
      }
    }
    return result;
  }
}

// ─── CharoTile ──────────────────────────────────────────────────────
/// Premium list tile with rounded background, smooth tap animation,
/// and proper visual hierarchy. Used inside CharoSection cards.
class CharoTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isDestructive;

  const CharoTile({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textColor = isDestructive ? colors.error : colors.onSurface;
    final resolvedIconColor = iconColor ?? (isDestructive ? colors.error : colors.onSurface.withOpacity(0.7));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: resolvedIconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon!, color: resolvedIconColor, size: 22),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.typography.bodyLarge?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: context.typography.bodySmall?.copyWith(
                            color: colors.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(Icons.chevron_right, size: 20, color: colors.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CharoAvatar ────────────────────────────────────────────────────
/// Premium avatar with optional shimmer gradient ring, online indicator
/// overlay, and premium border. The ring animates with a subtle shimmer.
class CharoAvatar extends StatefulWidget {
  final double radius;
  final String? imageUrl;
  final String? fallbackText;
  final bool isOnline;
  final bool showRing;
  final List<Color>? ringColors;
  final double ringWidth;
  final bool showEditBadge;
  final VoidCallback? onEditTap;

  const CharoAvatar({
    super.key,
    this.radius = 48,
    this.imageUrl,
    this.fallbackText,
    this.isOnline = false,
    this.showRing = false,
    this.ringColors,
    this.ringWidth = 3,
    this.showEditBadge = false,
    this.onEditTap,
  });

  @override
  State<CharoAvatar> createState() => _CharoAvatarState();
}

class _CharoAvatarState extends State<CharoAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.showRing) {
      _shimmerController.repeat();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ringColors = widget.ringColors ?? [colors.primary, colors.secondary];

    return GestureDetector(
      onTap: widget.showEditBadge ? widget.onEditTap : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ring shimmer
          if (widget.showRing)
            ListenableBuilder(
              listenable: _shimmerController,
              builder: (context, child) {
                final progress = _shimmerController.value;
                return Container(
                  width: (widget.radius + widget.ringWidth) * 2,
                  height: (widget.radius + widget.ringWidth) * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      startAngle: 0.0,
                      endAngle: 6.283,
                      colors: [
                        ringColors[0].withOpacity(0.3 + 0.7 * progress),
                        ringColors[1],
                        ringColors[0].withOpacity(0.3 + 0.7 * (1 - progress)),
                        ringColors[1].withOpacity(0.5),
                        ringColors[0],
                      ],
                      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                  ),
                  child: child,
                );
              },
              child: Center(
                child: CircleAvatar(
                  radius: widget.radius,
                  backgroundColor: colors.primary.withOpacity(0.08),
                  backgroundImage: widget.imageUrl != null
                      ? NetworkImage(widget.imageUrl!)
                      : null,
                  child: widget.imageUrl == null
                      ? Text(
                          (widget.fallbackText ?? '?')[0].toUpperCase(),
                          style: context.typography.headlineMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
            )
          else
            CircleAvatar(
              radius: widget.radius,
              backgroundColor: colors.primary.withOpacity(0.08),
              backgroundImage: widget.imageUrl != null
                  ? NetworkImage(widget.imageUrl!)
                  : null,
              child: widget.imageUrl == null
                  ? Text(
                      (widget.fallbackText ?? '?')[0].toUpperCase(),
                      style: context.typography.headlineMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),

          // Online indicator
          if (widget.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: widget.radius * 0.45,
                height: widget.radius * 0.45,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.surface,
                    width: 2.5,
                  ),
                ),
              ),
            ),

          // Edit badge
          if (widget.showEditBadge)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: widget.radius * 0.5,
                height: widget.radius * 0.5,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.surface,
                    width: 2.5,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: widget.radius * 0.22,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── CharoBadge ─────────────────────────────────────────────────────
/// Animated unread badge with scale animation on count change.
class CharoBadge extends StatefulWidget {
  final int count;
  final double size;
  final Color? color;
  final TextStyle? style;

  const CharoBadge({
    super.key,
    required this.count,
    this.size = 24,
    this.color,
    this.style,
  });

  @override
  State<CharoBadge> createState() => _CharoBadgeState();
}

class _CharoBadgeState extends State<CharoBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.8,
      upperBound: 1.2,
    );
    _scaleController.value = 1.0;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return const SizedBox.shrink();

    // Animate on count change
    if (widget.count != _previousCount) {
      _previousCount = widget.count;
      _scaleController.forward(from: 0.8).then((_) {
        _scaleController.reverse();
      });
    }

    final bgColor = widget.color ?? context.colors.primary;
    final label = widget.count > 99 ? '99+' : '${widget.count}';

    return ScaleTransition(
      scale: _scaleController,
      child: Container(
        constraints: BoxConstraints(
          minWidth: widget.size,
          minHeight: widget.size,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.size / 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: widget.style ?? context.typography.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ─── CharoHeaderCard ────────────────────────────────────────────────
/// Premium header card with gradient background for profile/settings header.
class CharoHeaderCard extends StatelessWidget {
  final Widget child;
  final List<Color>? gradientColors;
  final double height;
  final double radius;

  const CharoHeaderCard({
    super.key,
    required this.child,
    this.gradientColors,
    this.height = 180,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gradColors = gradientColors ?? [
      colors.primary.withOpacity(0.15),
      colors.secondary.withOpacity(0.1),
      colors.surface,
    ];

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradColors,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        ),
      ),
      child: child,
    );
  }
}

// ─── CharoSwitchTile ────────────────────────────────────────────────
/// Premium switch tile with icon container, used inside CharoSection.
class CharoSwitchTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const CharoSwitchTile({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final resolvedIconColor = iconColor ?? colors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: resolvedIconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon!, color: resolvedIconColor, size: 22),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.typography.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: context.typography.bodySmall?.copyWith(
                      color: colors.onSurface.withOpacity(0.5),
                    )),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: colors.primary,
          ),
        ],
      ),
    );
  }
}

// ─── CharoProgressRing ──────────────────────────────────────────────
/// Premium circular progress ring with label, used for storage display.
class CharoProgressRing extends StatelessWidget {
  final double value;        // 0.0..1.0
  final double max;
  final String centerLabel;
  final String centerSublabel;
  final double size;
  final double strokeWidth;
  final Color? progressColor;

  const CharoProgressRing({
    super.key,
    required this.value,
    this.max = 1.0,
    required this.centerLabel,
    this.centerSublabel = '',
    this.size = 160,
    this.strokeWidth = 12,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: value / max,
            strokeWidth: strokeWidth,
            backgroundColor: colors.outlineVariant,
            color: progressColor ?? colors.primary,
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(centerLabel, style: context.typography.headlineMedium),
            if (centerSublabel.isNotEmpty)
              Text(centerSublabel, style: context.typography.bodySmall),
          ],
        ),
      ],
    );
  }
}
