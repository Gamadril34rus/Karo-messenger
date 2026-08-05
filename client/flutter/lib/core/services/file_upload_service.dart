// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';
import '../utils/logger.dart';

/// ─── File Upload Service ─────────────────────────────────────────
/// Загрузка файлов на сервер (фото, видео, голосовые, документы).
/// Использует multipart/form-data для загрузки в MinIO.

class FileUploadService {
  static FileUploadService? _instance;
  static FileUploadService get instance => _instance ??= FileUploadService._();

  FileUploadService._();

  final _uuid = Uuid();

  /// Максимальный размер файла (100 MB)
  static const int maxFileSize = 100 * 1024 * 1024;

  /// Загрузить файл на сервер
  Future<UploadedFileResult?> uploadFile({
    required String filePath,
    required String chatId,
    String? mimeType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      logger.e('Upload failed: file does not exist — $filePath');
      return null;
    }

    final size = await file.length();
    if (size > maxFileSize) {
      logger.e('Upload failed: file too large ($size bytes, max $maxFileSize)');
      return null;
    }

    try {
      final apiClient = GetIt.instance<ApiClient>();
      final fileName = filePath.split('/').last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
        'chatId': chatId,
      });

      final response = await apiClient.post(
        '/api/v1/media/upload',
        data: formData,
        onSendProgress: onProgress,
      );

      final data = response.asMap;
      final url = data['url'] as String? ?? '';
      final thumbnailUrl = data['thumbnail_url'] as String? ?? '';
      final mediaType = data['type'] as String? ?? _inferType(filePath);
      final uploadedSize = data['size'] as int? ?? size;

      logger.i('📤 File uploaded: $fileName (${_formatBytes(uploadedSize)}) → $url');

      return UploadedFileResult(
        url: url,
        thumbnailUrl: thumbnailUrl,
        type: mediaType,
        fileName: fileName,
        fileSize: uploadedSize,
      );
    } catch (e) {
      logger.e('📤 File upload failed: $e');
      return null;
    }
  }

  /// Загрузить несколько файлов
  Future<List<UploadedFileResult>> uploadMultiple({
    required List<String> filePaths,
    required String chatId,
  }) async {
    final results = <UploadedFileResult>[];
    for (final path in filePaths) {
      final result = await uploadFile(filePath: path, chatId: chatId);
      if (result != null) {
        results.add(result);
      }
    }
    return results;
  }

  /// Скачать файл из сервера
  Future<String?> downloadFile({
    required String url,
    required String fileName,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$fileName';

      // Проверяем, не скачан ли уже
      if (await File(savePath).exists()) {
        return savePath;
      }

      final dio = Dio();
      await dio.download(url, savePath);

      logger.i('📥 File downloaded: $fileName → $savePath');
      return savePath;
    } catch (e) {
      logger.e('📥 File download failed: $e');
      return null;
    }
  }

  /// Определить тип файла по расширению
  String _inferType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'svg':
      case 'avif':
        return 'image';
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
        return 'video';
      case 'm4a':
      case 'mp3':
      case 'ogg':
      case 'opus':
      case 'wav':
      case 'flac':
        return 'voice';
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
      case 'txt':
      case 'zip':
      case 'rar':
        return 'file';
      default:
        return 'file';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class UploadedFileResult {
  final String url;
  final String thumbnailUrl;
  final String type;
  final String fileName;
  final int fileSize;

  const UploadedFileResult({
    required this.url,
    this.thumbnailUrl = '',
    required this.type,
    required this.fileName,
    required this.fileSize,
  });
}
