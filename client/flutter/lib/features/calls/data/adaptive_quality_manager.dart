// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';

import '../../../core/utils/logger.dart';
import 'webrtc_monitor.dart';

/// AdaptiveQualityManager — адаптивное управление качеством видео в звонках
///
/// Автоматически переключает качество видео на основе:
/// - Packet loss (процент потерянных пакетов)
/// - RTT (round-trip time, задержка)
/// - Available bitrate (доступная скорость)
///
/// Качества:
/// - high: VP9 720p, 1.5 Mbps
/// - medium: VP8 480p, 600 Kbps
/// - low: VP8 240p, 200 Kbps
/// - audioOnly: Только аудио, видео отключено
class AdaptiveQualityManager {
  VideoQuality _currentQuality = VideoQuality.high;
  final WebRtcMonitor _monitor;

  final _qualityController = StreamController<VideoQuality>.broadcast();
  Stream<VideoQuality> get qualityStream => _qualityController.stream;
  VideoQuality get currentQuality => _currentQuality;

  // Thresholds для переключения качества
  static const double _highPacketLossThreshold = 0.15; // >15% → downgrade
  static const double _mediumPacketLossThreshold = 0.08; // >8% → downgrade from high
  static const int _highRttThreshold = 500; // >500ms → downgrade
  static const int _mediumRttThreshold = 200; // >200ms → downgrade from high
  static const double _highBitrateThreshold = 1500; // <1.5 Mbps → downgrade
  static const double _mediumBitrateThreshold = 600; // <600 Kbps → downgrade from high

  Timer? _adaptationTimer;
  bool _disposed = false;

  AdaptiveQualityManager({required WebRtcMonitor monitor}) : _monitor = monitor {
    _startAdaptation();
  }

  void _startAdaptation() {
    // Каждые 3 секунды оцениваем качество и адаптируем
    _adaptationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_disposed) return;
      _adaptQuality();
    });

    // Также реагируем на обновление статистики
    _monitor.statsStream.listen((stats) {
      if (_disposed) return;
      _adaptQualityFromStats(stats);
    });
  }

  void _adaptQuality() {
    final stats = _monitor.currentStats;
    if (stats == null) return;

    final packetLoss = stats.packetLoss;
    final rtt = stats.rtt;
    final bitrate = stats.bitrate;

    final newQuality = _evaluateQuality(packetLoss, rtt, bitrate);

    if (newQuality != _currentQuality) {
      logger.i('📹 Quality adapted: ${_currentQuality.value} → ${newQuality.value}');
      _currentQuality = newQuality;
      _applyQuality(newQuality);
      _qualityController.add(newQuality);
    }
  }

  void _adaptQualityFromStats(WebRtcStats stats) {
    final newQuality = _evaluateQuality(stats.packetLoss, stats.rtt, stats.bitrate);

    // Immediate downgrade при критических показателях
    if (_shouldImmediateDowngrade(newQuality)) {
      _currentQuality = newQuality;
      _applyQuality(newQuality);
      _qualityController.add(newQuality);
    }
  }

  VideoQuality _evaluateQuality(double packetLoss, int rtt, double bitrate) {
    // При высоком packet loss — немедленное downgrade
    if (packetLoss > _highPacketLossThreshold) {
      return VideoQuality.audioOnly;
    }

    // При высоком RTT — downgrade до audioOnly
    if (rtt > _highRttThreshold) {
      return VideoQuality.audioOnly;
    }

    // При средних потерях — low quality
    if (packetLoss > _mediumPacketLossThreshold) {
      return VideoQuality.low;
    }

    // При средних RTT и достаточном bitrate — medium
    if (rtt > _mediumRttThreshold || bitrate < _mediumBitrateThreshold) {
      return VideoQuality.medium;
    }

    // При достаточном bitrate — high
    if (bitrate >= _highBitrateThreshold) {
      return VideoQuality.high;
    }

    // Default — medium
    return VideoQuality.medium;
  }

  bool _shouldImmediateDowngrade(VideoQuality newQuality) {
    final currentIndex = _currentQuality.index;
    final newIndex = newQuality.index;
    // Immediate downgrade если newQuality значительно ниже (>=2 уровня)
    return newIndex - currentIndex >= 2;
  }

  void _applyQuality(VideoQuality quality) {
    // Применение параметров качества к WebRTC соединению
    switch (quality) {
      case VideoQuality.high:
        _applyHighQuality();
        break;
      case VideoQuality.medium:
        _applyMediumQuality();
        break;
      case VideoQuality.low:
        _applyLowQuality();
        break;
      case VideoQuality.audioOnly:
        _applyAudioOnly();
        break;
    }
  }

  void _applyHighQuality() {
    // VP9 codec, 720p, 30fps, 1.5 Mbps
    // Simulcast: { low: 240p@15fps, mid: 480p@30fps, high: 720p@30fps }
    logger.d('📹 Applying HIGH quality: VP9 720p 30fps 1.5Mbps');
    _monitor.applyVideoSettings(
      codec: 'VP9',
      width: 1280,
      height: 720,
      fps: 30,
      maxBitrate: 1500,
      simulcastEnabled: true,
    );
  }

  void _applyMediumQuality() {
    // VP8 codec, 480p, 30fps, 600 Kbps
    // Simulcast: { low: 240p@15fps, mid: 480p@30fps }
    logger.d('📹 Applying MEDIUM quality: VP8 480p 30fps 600Kbps');
    _monitor.applyVideoSettings(
      codec: 'VP8',
      width: 640,
      height: 480,
      fps: 30,
      maxBitrate: 600,
      simulcastEnabled: true,
    );
  }

  void _applyLowQuality() {
    // VP8 codec, 240p, 15fps, 200 Kbps
    logger.d('📹 Applying LOW quality: VP8 240p 15fps 200Kbps');
    _monitor.applyVideoSettings(
      codec: 'VP8',
      width: 320,
      height: 240,
      fps: 15,
      maxBitrate: 200,
      simulcastEnabled: false,
    );
  }

  void _applyAudioOnly() {
    // Видео полностью отключено, только аудио
    logger.d('📹 Applying AUDIO_ONLY: video disabled');
    _monitor.disableVideo();
  }

  /// Manual override — пользователь выбирает качество вручную
  void setManualQuality(VideoQuality quality) {
    _currentQuality = quality;
    _applyQuality(quality);
    _qualityController.add(quality);
    logger.i('📹 Manual quality override: ${quality.value}');
  }

  /// Reset — возврат к автоматической адаптации
  void resetToAuto() {
    logger.i('📹 Reset quality to auto-adaptation');
    _adaptQuality();
  }

  void dispose() {
    _disposed = true;
    _adaptationTimer?.cancel();
    _qualityController.close();
  }
}

/// VideoQuality — уровни качества видео
enum VideoQuality {
  high('high', 'Высокое'),
  medium('medium', 'Среднее'),
  low('low', 'Низкое'),
  audioOnly('audioOnly', 'Только аудио');

  final String value;
  final String displayName;

  const VideoQuality(this.value, this.displayName);
}
