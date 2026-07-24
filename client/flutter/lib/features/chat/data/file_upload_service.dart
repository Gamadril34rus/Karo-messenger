import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/e2ee/e2ee_manager.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/logger.dart';

/// FileUploadService — загрузка файлов с прогрессом и E2EE шифрованием
///
/// Особенности:
/// - Stream<double> progress (0.0 → 1.0) для UI progress bar
/// - E2EE шифрование файлов перед отправкой (encryptFileData)
/// - Разбиение на 512KB chunks для надежной загрузки
/// - Отмена загрузки через CancelToken
/// - Retry при временных ошибках (3 попытки)
/// - Поддержка всех типов файлов (изображения, видео, аудио, документы)
class FileUploadService {
  final ApiClient _apiClient;
  final E2EEKeyManager _e2ee;
  final SecureStorageHelper _secureStorage;

  static const int _chunkSize = 512 * 1024; // 512KB
  static const int _maxRetries = 3;

  FileUploadService({
    required ApiClient apiClient,
    E2EEKeyManager? e2ee,
    SecureStorageHelper? secureStorage,
  }) : _apiClient = apiClient,
       _e2ee = e2ee ?? E2EEKeyManager.instance,
       _secureStorage = secureStorage ?? SecureStorageHelper();

  /// Загрузка файла с прогрессом и E2EE шифрованием
  ///
  /// Возвращает Stream<double> — прогресс загрузки (0.0 → 1.0)
  /// По завершению — fileId и URL для включения в сообщение
  Stream<FileUploadResult> uploadFileWithProgress({
    required String filePath,
    required String chatId,
    required String recipientId,
    required bool encryptWithE2ee,
    String? mimeType,
    int? width,
    int? height,
    int? durationMs,
    CancelToken? cancelToken,
  }) async* {
    final file = File(filePath);
    if (!await file.exists()) {
      yield FileUploadResult(
        progress: 0.0,
        status: UploadStatus.failed,
        error: 'Файл не найден: $filePath',
      );
      return;
    }

    final fileSize = await file.length();
    final fileName = file.path.split('/').last;

    logger.i('📤 Starting file upload: $fileName ($_formatFileSize(fileSize))');

    // 1. Чтение файла
    yield FileUploadResult(progress: 0.05, status: UploadStatus.reading);

    Uint8List fileBytes;
    try {
      fileBytes = await file.readAsBytes();
    } catch (e) {
      yield FileUploadResult(
        progress: 0.0,
        status: UploadStatus.failed,
        error: 'Ошибка чтения файла: $e',
      );
      return;
    }

    // 2. E2EE шифрование (если требуется)
    Uint8List uploadBytes;
    String? encryptedKeyRef;

    if (encryptWithE2ee) {
      yield FileUploadResult(progress: 0.1, status: UploadStatus.encrypting);
      logger.d('🔐 Encrypting file with E2EE for $recipientId');

      try {
        final encrypted = await _e2ee.encryptFileData(recipientId, fileBytes);
        uploadBytes = Uint8List.fromList(base64Decode(encrypted));
        encryptedKeyRef = 'e2ee_${DateTime.now().millisecondsSinceEpoch}';
        logger.i('🔐 File encrypted (${_formatFileSize(fileBytes.length)} → ${_formatFileSize(uploadBytes.length)})');
      } catch (e) {
        logger.e('E2EE encryption failed: $e');
        yield FileUploadResult(
          progress: 0.0,
          status: UploadStatus.failed,
          error: 'Ошибка E2EE шифрования: $e',
        );
        return;
      }
    } else {
      uploadBytes = fileBytes;
    }

    // 3. Разбиение на chunks
    yield FileUploadResult(progress: 0.15, status: UploadStatus.chunking);

    final totalChunks = (uploadBytes.length / _chunkSize).ceil();
    final chunks = <Uint8List>[];

    for (int i = 0; i < totalChunks; i++) {
      final start = i * _chunkSize;
      final end = (start + _chunkSize).clamp(0, uploadBytes.length);
      chunks.add(Uint8List.sublistView(uploadBytes, start, end));
    }

    logger.d('📤 Split into $totalChunks chunks');

    // 4. Загрузка chunks на сервер
    String? fileId;
    String? fileUrl;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        // 4a. Создание upload session
        final sessionResponse = await _apiClient.post('/api/v1/media/upload/session', data: {
          'chat_id': chatId,
          'file_name': encryptWithE2ee ? 'encrypted_$fileName' : fileName,
          'file_size': uploadBytes.length,
          'mime_type': mimeType ?? _guessMimeType(fileName),
          'total_chunks': totalChunks,
          'is_encrypted': encryptWithE2ee,
          if (encryptedKeyRef != null) 'encrypted_key_ref': encryptedKeyRef,
          if (width != null) 'width': width,
          if (height != null) 'height': height,
          if (durationMs != null) 'duration_ms': durationMs,
        });

        fileId = sessionResponse.asMap['file_id'] as String?;
        final uploadUrl = sessionResponse.asMap['upload_url'] as String?;

        // 4b. Загрузка каждого chunk
        for (int i = 0; i < chunks.length; i++) {
          if (cancelToken?.isCancelled ?? false) {
            yield FileUploadResult(progress: 0.0, status: UploadStatus.cancelled);
            return;
          }

          final chunkProgress = 0.15 + (i / totalChunks) * 0.75;
          yield FileUploadResult(progress: chunkProgress, status: UploadStatus.uploading);

          final formData = FormData();
          formData.fields.add(MapEntry('chunk_index', i.toString()));
          formData.fields.add(MapEntry('total_chunks', totalChunks.toString()));
          formData.fields.add(MapEntry('file_id', fileId ?? ''));

          final chunkFileName = 'chunk_$i.bin';
          formData.files.add(MapEntry(
            'file',
            MultipartFile.fromBytes(chunks[i], filename: chunkFileName),
          ));

          await _apiClient.upload(
            uploadUrl ?? '/api/v1/media/upload/chunk',
            formData: formData,
            onSendProgress: (sent, total) {
              // Внутренний прогресс chunk загрузки
              logger.d('📤 Chunk $i: $sent/$total bytes');
            },
            cancelToken: cancelToken,
          );

          logger.d('📤 Chunk $i uploaded');
        }

        // 4c. Завершение upload session
        final completeResponse = await _apiClient.post(
          '/api/v1/media/upload/$fileId/complete',
          data: {
            'total_chunks': totalChunks,
            'file_size': uploadBytes.length,
          },
        );

        fileUrl = completeResponse.asMap['url'] as String?;
        final thumbnailUrl = completeResponse.asMap['thumbnail_url'] as String?;

        yield FileUploadResult(
          progress: 1.0,
          status: UploadStatus.completed,
          fileId: fileId,
          fileUrl: fileUrl,
          thumbnailUrl: thumbnailUrl,
          fileSize: fileSize,
          fileName: fileName,
          isEncrypted: encryptWithE2ee,
          encryptedKeyRef: encryptedKeyRef,
        );

        logger.i('📤 File upload completed: $fileUrl');
        return;
      } on CharoApiException catch (e) {
        if (attempt < _maxRetries - 1 && e.type == CharoExceptionType.network) {
          logger.w('Upload attempt ${attempt + 1} failed — retrying...');
          continue;
        }

        yield FileUploadResult(
          progress: 0.0,
          status: UploadStatus.failed,
          error: e.message,
        );
        return;
      } catch (e) {
        logger.e('Upload error: $e');
        yield FileUploadResult(
          progress: 0.0,
          status: UploadStatus.failed,
          error: 'Ошибка загрузки: $e',
        );
        return;
      }
    }

    yield FileUploadResult(
      progress: 0.0,
      status: UploadStatus.failed,
      error: 'Превышено количество попыток загрузки',
    );
  }

  /// Загрузка нескольких файлов (batch)
  Stream<BatchUploadProgress> uploadMultipleFiles({
    required List<String> filePaths,
    required String chatId,
    required String recipientId,
    required bool encryptWithE2ee,
    CancelToken? cancelToken,
  }) async* {
    var completed = 0;
    final total = filePaths.length;
    final results = <FileUploadResult>[];

    for (final filePath in filePaths) {
      final uploadStream = uploadFileWithProgress(
        filePath: filePath,
        chatId: chatId,
        recipientId: recipientId,
        encryptWithE2ee: encryptWithE2ee,
        cancelToken: cancelToken,
      );

      await for (final result in uploadStream) {
        yield BatchUploadProgress(
          completedFiles: completed,
          totalFiles: total,
          currentFileProgress: result.progress,
          currentFileIndex: completed,
          overallProgress: (completed + result.progress) / total,
        );

        if (result.status == UploadStatus.completed || result.status == UploadStatus.failed) {
          results.add(result);
          completed++;
        }
      }
    }

    yield BatchUploadProgress(
      completedFiles: completed,
      totalFiles: total,
      currentFileProgress: 1.0,
      currentFileIndex: completed - 1,
      overallProgress: 1.0,
    );
  }

  String _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mp3':
        return 'audio/mpeg';
      case 'ogg':
      case 'opus':
        return 'audio/ogg';
      case 'wav':
        return 'audio/wav';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

}

/// FileUploadResult — результат загрузки файла
class FileUploadResult {
  final double progress; // 0.0 → 1.0
  final UploadStatus status;
  final String? fileId;
  final String? fileUrl;
  final String? thumbnailUrl;
  final int? fileSize;
  final String? fileName;
  final bool isEncrypted;
  final String? encryptedKeyRef;
  final String? error;

  FileUploadResult({
    required this.progress,
    required this.status,
    this.fileId,
    this.fileUrl,
    this.thumbnailUrl,
    this.fileSize,
    this.fileName,
    this.isEncrypted = false,
    this.encryptedKeyRef,
    this.error,
  });

  @override
  String toString() => 'FileUpload(${status.value}, ${progress.toStringAsFixed(2)}, ${fileName ?? 'unknown'})';
}

/// UploadStatus — статус загрузки
enum UploadStatus {
  reading('reading', 'Чтение файла'),
  encrypting('encrypting', 'Шифрование'),
  chunking('chunking', 'Разбиение'),
  uploading('uploading', 'Загрузка'),
  completed('completed', 'Завершено'),
  failed('failed', 'Ошибка'),
  cancelled('cancelled', 'Отменено');

  final String value;
  final String displayName;

  const UploadStatus(this.value, this.displayName);
}

/// BatchUploadProgress — прогресс batch загрузки
class BatchUploadProgress {
  final int completedFiles;
  final int totalFiles;
  final double currentFileProgress;
  final int currentFileIndex;
  final double overallProgress;

  BatchUploadProgress({
    required this.completedFiles,
    required this.totalFiles,
    required this.currentFileProgress,
    required this.currentFileIndex,
    required this.overallProgress,
  });
}
