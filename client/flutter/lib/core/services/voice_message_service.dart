// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../utils/logger.dart';

/// ─── Voice Message Service ───────────────────────────────────────
/// Запись голосовых сообщений с реальным микрофоном.
/// Воспроизведение через AudioPlayer.
/// Waveform generation для визуализации.

class VoiceMessageService {
  static VoiceMessageService? _instance;
  static VoiceMessageService get instance => _instance ??= VoiceMessageService._();

  VoiceMessageService._();

  final AudioRecorder _recorder = AudioRecorder();
  final _uuid = Uuid();

  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  StreamSubscription<RecordState>? _stateSubscription;

  /// Записывается ли сейчас аудио
  bool get isRecording => _isRecording;

  /// Длительность текущей записи
  Duration get currentDuration => _recordingStartTime != null
      ? DateTime.now().difference(_recordingStartTime!)
      : Duration.zero;

  /// Начать запись голосового сообщения
  Future<String?> startRecording() async {
    if (_isRecording) return null;

    try {
      // Проверить разрешение на микрофон
      if (!await _recorder.hasPermission()) {
        logger.e('🎙 Microphone permission denied');
        return null;
      }

      final appDir = await getTemporaryDirectory();
      final fileName = 'voice_${_uuid.v4().substring(0, 8)}.m4a';
      _currentRecordingPath = '${appDir.path}/$fileName';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      logger.i('🎙 Recording started: $_currentRecordingPath');

      return _currentRecordingPath;
    } catch (e) {
      logger.e('🎙 Failed to start recording: $e');
      return null;
    }
  }

  /// Остановить запись и вернуть путь к файлу + длительность
  Future<VoiceRecordingResult?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;

      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;

      _recordingStartTime = null;

      if (path == null) {
        logger.e('🎙 Recording stopped but no file path returned');
        return null;
      }

      // Проверить что файл существует и не пустой
      final file = File(path);
      if (!await file.exists()) {
        logger.e('🎙 Recording file does not exist: $path');
        return null;
      }

      final size = await file.length();
      if (size < 100) {
        logger.w('🎙 Recording too small ($size bytes), discarding');
        await file.delete();
        return null;
      }

      logger.i('🎙 Recording stopped: $path (${duration.inSeconds}s, $size bytes)');

      return VoiceRecordingResult(
        filePath: path,
        duration: duration,
        fileSize: size,
        waveformData: await generateWaveform(path),
      );
    } catch (e) {
      logger.e('🎙 Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Отменить запись (без сохранения)
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.stop();
      _isRecording = false;
      _recordingStartTime = null;

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      logger.i('🎙 Recording cancelled');
    } catch (e) {
      logger.e('🎙 Failed to cancel recording: $e');
    }
  }

  /// Генерация waveform данных для визуализации
  /// Возвращает список амплитуд (0.0-1.0) для отрисовки
  Future<List<double>> generateWaveform(String filePath) async {
    try {
      // В реальной реализации — анализ аудио-семплов
      // Для быстрого запуска — генерация на основе длительности файла
      final file = File(filePath);
      if (!await file.exists()) return [];

      final size = await file.length();
      final barCount = 30;
      final bars = <double>[];

      // Генерируем реалистичный waveform на основе размера файла
      for (int i = 0; i < barCount; i++) {
        final center = barCount / 2;
        final distance = (i - center).abs() / center;
        final base = 0.7 * (1 - distance * 0.5);
        final variation = ((i * 7 + size) % 13) / 26;
        bars.add((base + variation * 0.3).clamp(0.1, 1.0));
      }

      return bars;
    } catch (e) {
      logger.e('🎙 Waveform generation failed: $e');
      return List.generate(30, (_) => 0.5);
    }
  }

  /// Освободить ресурсы
  Future<void> dispose() async {
    await _recorder.dispose();
    _stateSubscription?.cancel();
  }
}

class VoiceRecordingResult {
  final String filePath;
  final Duration duration;
  final int fileSize;
  final List<double> waveformData;

  const VoiceRecordingResult({
    required this.filePath,
    required this.duration,
    required this.fileSize,
    required this.waveformData,
  });

  /// Форматированная длительность (MM:SS)
  String get formattedDuration {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
