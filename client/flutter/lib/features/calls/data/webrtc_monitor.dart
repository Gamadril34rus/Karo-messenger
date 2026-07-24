import 'dart:async';

import '../../../core/utils/logger.dart';

/// WebRtcMonitor — мониторинг WebRTC-соединения
///
/// Собирает статистику каждые 3 секунды:
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
  final List<StreamSubscription> _subscriptions = [];

  final _statsController = StreamController<WebRtcStats>.broadcast();
  final _connectionQualityController = StreamController<ConnectionQuality>.broadcast();

  Stream<WebRtcStats> get statsStream => _statsController.stream;
  Stream<ConnectionQuality> get connectionQualityStream => _connectionQualityController.stream;
  WebRtcStats? get currentStats => _currentStats;

  int _participantCount = 0;
  bool _disposed = false;

  WebRtcMonitor() {
    _startCollecting();
  }

  void _startCollecting() {
    // Собираем статистику каждые 3 секунды
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_disposed) return;
      _collectStats();
    });
  }

  void _collectStats() {
    // В реальности — вызов peerConnection.getStats() и парсинг RTCStatsReport
    // Здесь — генерация статистики из WebRTC connection
    final stats = _parseStatsFromConnection();

    if (stats != null) {
      _currentStats = stats;
      _statsController.add(stats);

      final quality = _assessConnectionQuality(stats);
      _connectionQualityController.add(quality);
    }
  }

  WebRtcStats? _parseStatsFromConnection() {
    // Реальная реализация:
    // final report = await peerConnection.getStats();
    // Парсинг RTCStatsReport для извлечения:
    // - packetsSent, packetsReceived, packetsLost
    // - roundTripTime
    // - bytesSent, bytesReceived (за период)
    //
    // Placeholder — в реальности подключается к flutter_webrtc
    return null;
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

  /// Apply video settings (для AdaptiveQualityManager)
  void applyVideoSettings({
    required String codec,
    required int width,
    required int height,
    required int fps,
    required double maxBitrate,
    required bool simulcastEnabled,
  }) {
    logger.d('WebRTC: Applying video settings — $codec $width×$height $fpsfps ${maxBitrate}Kbps simulcast=$simulcastEnabled');
    // В реальности — отправка video constraints через MediaStreamTrack.setEnabled + RTCConfiguration
    // или через LiveKit Room.localParticipant.setParameters()
  }

  /// Disable video (audioOnly mode)
  void disableVideo() {
    logger.d('WebRTC: Disabling video track');
    // В реальности — room.localParticipant.setCameraEnabled(false)
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
