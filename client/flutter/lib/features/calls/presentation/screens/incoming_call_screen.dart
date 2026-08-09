// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../core/audio/notification_service.dart';
import '../../../../core/network/ws_client.dart';
import '../../../../core/utils/logger.dart';

/// Экран входящего звонка — Accept/Reject
/// Появляется при получении WS события call.incoming
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerAvatarUrl;
  final bool isVideo;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl,
    this.isVideo = false,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _ringTimeout;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.playCallSound();
    HapticService.instance.heavy();

    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-dismiss after 30 seconds if not answered
    _ringTimeout = Timer(const Duration(seconds: 30), () {
      _rejectCall();
    });

    // Listen for call.hangup from caller
    _wsSubscription = GetIt.instance<WsClient>().messages.listen((event) {
      if (event.type == 'call.hangup' &&
          event.data['callId'] == widget.callId) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringTimeout?.cancel();
    _wsSubscription?.cancel();
    NotificationService.instance.stopCallSound();
    super.dispose();
  }

  void _acceptCall() {
    HapticService.instance.medium();
    NotificationService.instance.stopCallSound();
    _ringTimeout?.cancel();

    // Navigate to active call screen
    context.go('/call/${widget.callId}', extra: {
      'recipientName': widget.callerName,
      'recipientAvatarUrl': widget.callerAvatarUrl ?? '',
      'isVideo': widget.isVideo,
      'isOutgoing': false,
    });
  }

  void _rejectCall() {
    HapticService.instance.heavy();
    NotificationService.instance.stopCallSound();
    _ringTimeout?.cancel();

    // Send hangup via WS
    final wsClient = GetIt.instance<WsClient>();
    wsClient.callSignal(widget.callId, 'hangup', {
      'reason': 'declined',
    });

    _dismiss();
  }

  void _dismiss() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Caller info ───────────────────────────────────────
            _PulseBuilder(
              listenable: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withOpacity(0.15),
                      border: Border.all(
                        color: colors.primary.withOpacity(0.4),
                        width: 3,
                      ),
                    ),
                    child: widget.callerAvatarUrl != null &&
                            widget.callerAvatarUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              widget.callerAvatarUrl!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildFallbackAvatar(colors),
                            ),
                          )
                        : _buildFallbackAvatar(colors),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Name
            Text(
              widget.callerName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            // Call type label
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isVideo ? Icons.videocam : Icons.phone,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isVideo
                      ? 'Входящий видеозвонок...'
                      : 'Входящий звонок...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),

            const Spacer(flex: 3),

            // ── Action buttons ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline
                  _CallActionButton(
                    icon: Icons.call_end,
                    label: 'Отклонить',
                    color: colors.error,
                    onTap: _rejectCall,
                  ),

                  // Accept
                  _CallActionButton(
                    icon: widget.isVideo ? Icons.videocam : Icons.phone,
                    label: widget.isVideo ? 'Видео' : 'Принять',
                    color: const Color(0xFF10B981),
                    onTap: _acceptCall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(ColorScheme colors) {
    return Center(
      child: Text(
        widget.callerName.isNotEmpty
            ? widget.callerName[0].toUpperCase()
            : '?',
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: colors.primary,
        ),
      ),
    );
  }
}

/// Кнопка действия на экране входящего звонка
class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 32),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// _PulseBuilder — виджет для анимации пульса
class _PulseBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const _PulseBuilder({
    required super.listenable,
    required this.builder,
    this.child,
  });

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
