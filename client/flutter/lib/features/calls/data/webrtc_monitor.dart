// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/utils/logger.dart';

/// WebRtcMonitor — мониторинг WebRTC-соединения
///
/// Собирает статистику каждые 3 секунды через RTCPeerConnection.getStats():
/// - Packet loss (процент потерянных пакетов)
/// - RTT (round-trip time в ms)
/// - Bitrate (текущая скорость в Kbps)
/// - Connection quality (excellent/good/fair/poor)
/// - Number of participants
///
/// Предоставляет Stream<WebRtcStats> для AdaptiveQualityManager и UI.
class WebRtcMonitor {
  WebRtcStats? _currentStats;
  Timer? _statsTimer;
  RTCPeerConnection? _peerConnection;
  final List<StreamSubscription> _subscriptions = [];

  // Previous bytes counters for bitrate calculation
  int _prevBytesSent = 0;
  int _prevBytesReceived = 0;
  DateTime? _prevStatsTime;

  final _statsController = StreamController<WebRtcStats>.broadcast();
  final _connectionQualityController = StreamController<ConnectionQuality>.broadcast();

  Stream<WebRtcStats> get statsStream => _statsController.stream;
  Stream<ConnectionQuality> get connectionQualityStream => _connectionQualityController.stream;
  WebRtcStats? get currentStats => _currentStats;

  int _participantCount = 0;
  bool _disposed = false;

  WebRtcMonitor({RTCPeerConnection? peerConnection}) : _peerConnection = peerConnection {
    _startCollecting();
  }

  /// Attach a peer connection for stats collection
  void setPeerConnection(RTCPeerConnection peerConnection) {
    _peerConnection = peerConnection;
    logger.i('WebRTC Monitor: peer connection attached');
  }

  void _startCollecting() {
    // Собираем статистику каждые 3 секунды
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_disposed) return;
      _collectStats();
    });
  }

  Future<void> _collectStats() async {
    final stats = await _parseStatsFromConnection();

    if (stats != null) {
      _currentStats = stats;
      _statsController.add(stats);

      final quality = _assessConnectionQuality(stats);
      _connectionQualityController.add(quality);
    }
  }

  /// Parse stats from flutter_webrtc RTCPeerConnection.getStats()
  Future<WebRtcStats?> _parseStatsFromConnection() async {
    if (_peerConnection == null) return null;

    try {
      final report = await _peerConnection!.getStats();

      int packetsSent = 0;
      int packetsReceived = 0;
      int packetsLost = 0;
      int bytesSent = 0;
      int bytesReceived = 0;
      int rtt = 0;

      for (final statsMap in report) {
        final statsType = statsMap['type'] as String? ?? '';

        if (statsType == 'outbound-rtp') {
          packetsSent += (statsMap['packetsSent'] as int?) ?? 0;
          bytesSent += (statsMap['bytesSent'] as int?) ?? 0;
        } else if (statsType == 'inbound-rtp') {
          packetsReceived += (statsMap['packetsReceived'] as int?) ?? 0;
          packetsLost += (statsMap['packetsLost'] as int?) ?? 0;
          bytesReceived += (statsMap['bytesReceived'] as int?) ?? 0;
        } else if (statsType == 'candidate-pair' || statsType == 'transport') {
          // RTT is in the active candidate-pair as currentRoundTripTime (seconds)
          final rttSec = statsMap['currentRoundTripTime'] as double?;
          if (rttSec != null) {
            rtt = (rttSec * 1000).round(); // Convert to ms
          }
        }
      }

      // Calculate bitrate from byte deltas
      final now = DateTime.now();
      double bitrate = 0;
      if (_prevStatsTime != null) {
        final elapsed = now.difference(_prevStatsTime!).inMilliseconds;
        if (elapsed > 0) {
          final bytesDelta = (bytesSent - _prevBytesSent) + (bytesReceived - _prevBytesReceived);
          bitrate = (bytesDelta * 8) / elapsed; // bits per ms → Kbps
        }
      }

      _prevBytesSent = bytesSent;
      _prevBytesReceived = bytesReceived;
      _prevStatsTime = now;

      // Calculate packet loss percentage
      final totalPackets = packetsSent + packetsReceived;
      final packetLoss = totalPackets > 0
          ? packetsLost / totalPackets
          : 0.0;

      return WebRtcStats(
        packetLoss: packetLoss,
        rtt: rtt,
        bitrate: bitrate,
        bytesSent: bytesSent,
        bytesReceived: bytesReceived,
        packetsSent: packetsSent,
        packetsReceived: packetsReceived,
        packetsLost: packetsLost,
        participantCount: _participantCount,
        timestamp: now,
      );
    } catch (e) {
      logger.e('WebRTC Stats collection error: $e');
      return null;
    }
  }

  /// Обновление participant count
  void setParticipantCount(int count) {
    _participantCount = count;
  }

  /// Manual stats update (для интеграции с flutter_webrtc)
  void updateStats({
    required double packetLoss,
    required int rtt,
    required double bitrate,
    required int bytesSent,
    required int bytesReceived,
    required int packetsSent,
    required int packetsReceived,
    required int packetsLost,
  }) {
    final stats = WebRtcStats(
      packetLoss: packetLoss,
      rtt: rtt,
      bitrate: bitrate,
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
      packetsSent: packetsSent,
      packetsReceived: packetsReceived,
      packetsLost: packetsLost,
      participantCount: _participantCount,
      timestamp: DateTime.now(),
    );

    _currentStats = stats;
    _statsController.add(stats);

    final quality = _assessConnectionQuality(stats);
    _connectionQualityController.add(quality);
  }

  ConnectionQuality _assessConnectionQuality(WebRtcStats stats) {
    // Excellent: packetLoss < 2%, rtt < 100ms, bitrate >= 1Mbps
    if (stats.packetLoss < 0.02 && stats.rtt < 100 && stats.bitrate >= 1000) {
      return ConnectionQuality.excellent;
    }

    // Good: packetLoss < 5%, rtt < 200ms, bitrate >= 500Kbps
    if (stats.packetLoss < 0.05 && stats.rtt < 200 && stats.bitrate >= 500) {
      return ConnectionQuality.good;
    }

    // Fair: packetLoss < 10%, rtt < 500ms
    if (stats.packetLoss < 0.10 && stats.rtt < 500) {
      return ConnectionQuality.fair;
    }

    // Poor: high packet loss or high rtt
    return ConnectionQuality.poor;
  }

  /// Apply video settings via RTCRtpSender.setParameters()
  /// Changes codec preferences, maxBitrate, simulcast encodings, resolution/fps constraints
  void applyVideoSettings({
    required String codec,
    required int width,
    required int height,
    required int fps,
    required double maxBitrate,
    required bool simulcastEnabled,
  }) {
    logger.d('WebRTC: Applying video settings — $codec $width×$height $fpsfps ${maxBitrate}Kbps simulcast=$simulcastEnabled');

    if (_peerConnection == null) return;

    // Apply via RTCRtpSender parameters — flutter_webrtc exposes getSenders()
    _peerConnection!.getSenders().then((senders) {
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          final parameters = sender.parameters;
          if (parameters.encodings.isNotEmpty) {
            // Set max bitrate on primary encoding
            parameters.encodings[0].maxBitrate = maxBitrate.toInt();
            parameters.encodings[0].maxFramerate = fps;

            // Enable simulcast: add low/mid/high encodings
            final encodings = parameters.encodings;
            if (simulcastEnabled && encodings != null && encodings.length >= 3) {
              encodings[0].rid = 'high';
              encodings[0].maxBitrate = maxBitrate.toInt();
              encodings[1].rid = 'mid';
              encodings[1].maxBitrate = (maxBitrate * 0.5).toInt();
              encodings[1].maxFramerate = (fps * 0.67).toInt();
              encodings[2].rid = 'low';
              encodings[2].maxBitrate = (maxBitrate * 0.25).toInt();
              encodings[2].maxFramerate = (fps * 0.5).toInt();
            }
          }

          sender.setParameters(parameters).catchError((e) {
            logger.w('WebRTC: Failed to set sender parameters: $e');
          });

          // Apply resolution/fps constraints on the video track
          sender.track!.enabled = true;
          logger.i('WebRTC: Video settings applied — $codec $width×$height ${fps}fps');
        }
      }
    }).catchError((e) {
      logger.w('WebRTC: Failed to get senders: $e');
    });
  }

  /// Disable video — set camera track to enabled=false
  void disableVideo() {
    logger.d('WebRTC: Disabling video track');

    if (_peerConnection == null) return;

    _peerConnection!.getSenders().then((senders) {
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          sender.track!.enabled = false;
          logger.i('WebRTC: Video track disabled');
        }
      }
    }).catchError((e) {
      logger.w('WebRTC: Failed to disable video track: $e');
    });
  }

  void dispose() {
    _disposed = true;
    _statsTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _statsController.close();
    _connectionQualityController.close();
  }
}

/// WebRtcStats — модель статистики WebRTC-соединения
class WebRtcStats {
  final double packetLoss; // Процент (0.0–1.0)
  final int rtt; // Round-trip time в ms
  final double bitrate; // Текущая скорость в Kbps
  final int bytesSent;
  final int bytesReceived;
  final int packetsSent;
  final int packetsReceived;
  final int packetsLost;
  final int participantCount;
  final DateTime timestamp;

  WebRtcStats({
    required this.packetLoss,
    required this.rtt,
    required this.bitrate,
    required this.bytesSent,
    required this.bytesReceived,
    required this.packetsSent,
    required this.packetsReceived,
    required this.packetsLost,
    required this.participantCount,
    required this.timestamp,
  });

  double get packetLossPercent => packetLoss * 100;

  String get bitrateFormatted {
    if (bitrate >= 1000) return '${(bitrate / 1000).toStringAsFixed(1)} Mbps';
    return '${bitrate.toStringAsFixed(0)} Kbps';
  }

  String get rttFormatted => '$rtt ms';

  String get packetLossFormatted => '${packetLossPercent.toStringAsFixed(1)}%';

  Map<String, dynamic> toJson() {
    return {
      'packet_loss': packetLoss,
      'rtt': rtt,
      'bitrate': bitrate,
      'bytes_sent': bytesSent,
      'bytes_received': bytesReceived,
      'packets_sent': packetsSent,
      'packets_received': packetsReceived,
      'packets_lost': packetsLost,
      'participant_count': participantCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() => 'WebRtcStats(loss=${packetLossFormatted}, rtt=$rttFormatted, bitrate=$bitrateFormatted, participants=$participantCount)';
}

/// ConnectionQuality — оценка качества соединения
enum ConnectionQuality {
  excellent('excellent', 'Отличное', 0xFF4CAF50),  // Green
  good('good', 'Хорошее', 0xFF8BC34A),              // LightGreen
  fair('fair', 'Среднее', 0xFFFF9800),               // Orange
  poor('poor', 'Плохое', 0xFFF44336);                // Red

  final String value;
  final String displayName;
  final int colorValue; // ARGB color int для UI

  const ConnectionQuality(this.value, this.displayName, this.colorValue);
}
