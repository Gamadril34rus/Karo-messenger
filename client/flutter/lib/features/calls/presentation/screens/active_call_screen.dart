// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/haptic/haptic_service.dart';
import '../../../../core/audio/notification_service.dart';
import '../../../../core/network/ws_client.dart';
import '../../../../core/utils/logger.dart';
import '../../data/adaptive_quality_manager.dart';
import '../../data/data_channel_service.dart';
import '../../data/webrtc_monitor.dart';

/// Экран активного звонка — WebRTC video/audio call UI
///
/// Features:
/// - Local/remote video rendering via RTCVideoRenderer
/// - Adaptive quality management
/// - Haptic feedback for call events
/// - Charo call sound (loop until answered)
/// - Camera/mic/speaker toggles
/// - Call timer
/// - Minimize call (floating bubble)
class ActiveCallScreen extends StatefulWidget {
  final String callId;
  final String recipientName;
  final String recipientAvatarUrl;
  final bool isVideo;
  final bool isOutgoing;

  const ActiveCallScreen({
    super.key,
    required this.callId,
    required this.recipientName,
    this.recipientAvatarUrl = '',
    this.isVideo = false,
    this.isOutgoing = true,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  // ─── WebRTC ──────────────────────────────────────────────────────
  RTCPeerConnection? _peerConnection;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  // ─── DataChannel ─────────────────────────────────────────────────
  DataChannelService? _dataChannel;

  // ─── Quality ─────────────────────────────────────────────────────
  WebRtcMonitor? _monitor;
  AdaptiveQualityManager? _qualityManager;

  // ─── State ───────────────────────────────────────────────────────
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isConnected = false;
  bool _isRinging = true;
  Duration _callDuration = Duration.zero;
  Timer? _callTimer;
  StreamSubscription? _wsSubscription;

  // ─── ICE servers (TURN/STUN) ─────────────────────────────────────
  static const _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {
      'urls': 'turn:turn.charo.chat:3478',
      'username': 'charo',
      'credential': 'charo-turn-secret',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupCall();

    // Play Charo call sound for outgoing calls
    if (widget.isOutgoing) {
      NotificationService.instance.playCallSound();
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _wsSubscription?.cancel();
    _dataChannel?.dispose();
    _qualityManager?.dispose();
    _monitor?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    NotificationService.instance.stopCallSound();
    super.dispose();
  }

  // ─── Initialization ──────────────────────────────────────────────

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _setupCall() async {
    final config = {
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    _peerConnection = await createPeerConnection(config);

    // Monitor for adaptive quality
    _monitor = WebRtcMonitor();
    _monitor!.setPeerConnection(_peerConnection!);
    _qualityManager = AdaptiveQualityManager(monitor: _monitor!);

    // Add transceivers for audio/video
    _peerConnection!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
    );

    if (widget.isVideo) {
      _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
    }

    // Get local stream (camera/mic)
    try {
      final localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.isVideo
            ? {'width': 1280, 'height': 720, 'frameRate': 30}
            : false,
      });

      _localRenderer.srcObject = localStream;

      for (final track in localStream.getTracks()) {
        _peerConnection!.addTrack(track, localStream);
      }

      logger.i('📞 Local media stream added (video=${widget.isVideo})');
    } catch (e) {
      logger.e('📞 Failed to get local media: $e');
      // Continue with audio only
      final audioStream = await navigator.mediaDevices.getUserMedia({'audio': true});
      _localRenderer.srcObject = audioStream;
      for (final track in audioStream.getTracks()) {
        _peerConnection!.addTrack(track, audioStream);
      }
    }

    // PeerConnection event handlers
    _peerConnection!.onIceCandidate = (candidate) {
      // Send ICE candidate to remote via WebSocket signaling
      logger.d('📞 ICE candidate: ${candidate.candidate}');
      final wsClient = GetIt.instance<WsClient>();
      wsClient.callSignal(widget.callId, 'ice', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        logger.i('📞 Remote track received');
      }
    };

    _peerConnection!.onConnectionState = (state) {
      logger.i('📞 Connection state: $state');
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          setState(() {
            _isConnected = true;
            _isRinging = false;
          });
          _startCallTimer();
          NotificationService.instance.stopCallSound();
          HapticService.medium();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
          _endCall();
          break;
      }
    };

    // DataChannel for in-call messaging
    _peerConnection!.onDataChannel = (channel) {
      _dataChannel = DataChannelService();
      _dataChannel!.connectToDataChannel(channel);
      logger.i('📞 DataChannel received: ${channel.label}');
    };

    // If outgoing, create offer
    if (widget.isOutgoing) {
      _createOffer();
    }

    // Subscribe to incoming WebSocket signaling for this call
    _wsSubscription = GetIt.instance<WsClient>().messages.listen((event) {
      if (event.type.startsWith('call.') && event.data['callId'] == widget.callId) {
        _handleCallSignal(event);
      }
    });
  }

  void _handleCallSignal(WsEvent event) {
    final signalType = event.type.replaceFirst('call.', '');
    final data = event.data['data'] as Map<String, dynamic>? ?? event.data;

    switch (signalType) {
      case 'ice':
        final candidate = RTCIceCandidate(
          data['candidate'] as String?,
          data['sdpMid'] as String?,
          data['sdpMLineIndex'] as int?,
        );
        _peerConnection?.addCandidate(candidate);
        logger.d('📞 Remote ICE candidate added');
        break;
      case 'offer':
        final sdp = data['sdp'] as String?;
        if (sdp != null) {
          _peerConnection?.setRemoteDescription(
            RTCSessionDescription(sdp, 'offer'),
          );
          _createAnswer();
        }
        break;
      case 'answer':
        final sdp = data['sdp'] as String?;
        if (sdp != null) {
          _peerConnection?.setRemoteDescription(
            RTCSessionDescription(sdp, 'answer'),
          );
        }
        break;
      case 'hangup':
        _endCall();
        break;
    }
  }

  Future<void> _createOffer() async {
    try {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': widget.isVideo,
      });
      await _peerConnection!.setLocalDescription(offer);

      logger.i('📞 SDP offer created');

      // DataChannel for outgoing caller
      _dataChannel = DataChannelService();
      _dataChannel!.createDataChannel(_peerConnection!);

      // Send offer via WebSocket signaling
      final wsClient = GetIt.instance<WsClient>();
      wsClient.callSignal(widget.callId, 'offer', {
        'sdp': offer.sdp,
        'type': offer.type,
      });
    } catch (e) {
      logger.e('📞 Failed to create offer: $e');
    }
  }

  Future<void> _createAnswer() async {
    try {
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      logger.i('📞 SDP answer created');

      // Send answer via WebSocket signaling
      final wsClient = GetIt.instance<WsClient>();
      wsClient.callSignal(widget.callId, 'answer', {
        'sdp': answer.sdp,
        'type': answer.type,
      });
    } catch (e) {
      logger.e('📞 Failed to create answer: $e');
    }
  }

  // ─── Call timer ──────────────────────────────────────────────────

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _callDuration += const Duration(seconds: 1);
      });
    });
  }

  // ─── Controls ────────────────────────────────────────────────────

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    HapticService.light();

    _peerConnection?.getSenders().then((senders) {
      for (final sender in senders) {
        if (sender.track?.kind == 'audio') {
          sender.track!.setEnabled(!_isMuted);
        }
      }
    });
  }

  void _toggleCamera() {
    setState(() => _isCameraOff = !_isCameraOff);
    HapticService.light();

    _peerConnection?.getSenders().then((senders) {
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          sender.track!.setEnabled(!_isCameraOff);
        }
      }
    });
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    HapticService.light();
    // In production, switch audio output device via flutter_webrtc
  }

  void _switchCamera() {
    HapticService.medium();
    // Switch front/back camera
    _peerConnection?.getSenders().then((senders) {
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          // Helper method in flutter_webrtc
          helper.switchCamera(sender.track!);
        }
      }
    });
  }

  void _endCall() {
    HapticService.heavy();
    NotificationService.instance.stopCallSound();
    _callTimer?.cancel();

    _peerConnection?.close();
    Navigator.of(context).pop();
  }

  // ─── UI ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Remote video (full screen) ──────────────────────────
            if (widget.isVideo)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: false,
                ),
              ),

            // ── Local video (small overlay) ─────────────────────────
            if (widget.isVideo && _isConnected)
              Positioned(
                top: 60,
                right: 16,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: RTCVideoView(
                    _localRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    mirror: true,
                  ),
                ),
              ),

            // ── Call info overlay ───────────────────────────────────
            if (!widget.isVideo || !_isConnected)
              _buildCallInfoOverlay(colors),

            // ── Ringing animation ───────────────────────────────────
            if (_isRinging)
              _buildRingingIndicator(colors),

            // ── Call controls ───────────────────────────────────────
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _buildCallControls(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallInfoOverlay(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withOpacity(0.15),
            ),
            child: widget.recipientAvatarUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      widget.recipientAvatarUrl,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackAvatar(colors),
                    ),
                  )
                : _buildFallbackAvatar(colors),
          ),

          const SizedBox(height: 24),

          // Name
          Text(
            widget.recipientName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          // Status
          Text(
            _isConnected
                ? _formatDuration(_callDuration)
                : _isRinging
                    ? (widget.isOutgoing ? 'Вызов...' : 'Входящий звонок...')
                    : 'Подключение...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackAvatar(ColorScheme colors) {
    return Center(
      child: Text(
        widget.recipientName.isNotEmpty
            ? widget.recipientName[0].toUpperCase()
            : '?',
        style: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: colors.primary,
        ),
      ),
    );
  }

  Widget _buildRingingIndicator(ColorScheme colors) {
    return Positioned(
      top: 120,
      left: 0,
      right: 0,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.2),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withOpacity(0.3),
                ),
                child: Icon(
                  Icons.phone_in_talk,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            );
          },
          onEnd: () => setState(() {}), // Loop animation
        ),
      ),
    );
  }

  Widget _buildCallControls(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer display (only when connected)
          if (_isConnected)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _formatDuration(_callDuration),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),

          // Main controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? 'Микрофон' : 'Микрофон',
                isActive: !_isMuted,
                onTap: _toggleMute,
                color: colors.error,
              ),

              if (widget.isVideo)
                _ControlButton(
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  label: 'Камера',
                  isActive: !_isCameraOff,
                  onTap: _toggleCamera,
                  color: colors.error,
                ),

              if (widget.isVideo)
                _ControlButton(
                  icon: Icons.cameraswitch,
                  label: 'Переключить',
                  isActive: true,
                  onTap: _switchCamera,
                  color: colors.primary,
                ),

              _ControlButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                label: 'Динамик',
                isActive: _isSpeakerOn,
                onTap: _toggleSpeaker,
                color: colors.primary,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // End call button
          SizedBox(
            width: 72,
            height: 72,
            child: FloatingActionButton(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              onPressed: _endCall,
              child: const Icon(Icons.call_end, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Control button for call UI
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive
        ? Colors.white.withOpacity(0.2)
        : color.withOpacity(0.7);
    final iconColor = isActive ? Colors.white : Colors.white.withOpacity(0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: iconColor, size: 28),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
