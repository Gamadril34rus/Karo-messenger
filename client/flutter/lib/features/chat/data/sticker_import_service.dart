import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// ─── Sticker Import Service ──────────────────────────────────────
/// Импорт стикер-паков из Telegram, VK, WhatsApp, Viber
/// Поддерживает: .zip архивы, URL API, локальные файлы

enum StickerImportSource {
  telegram,
  vk,
  whatsapp,
  viber,
  localZip,
  localFolder,
}

class StickerImportResult {
  final String packId;
  final String packName;
  final List<ImportedSticker> stickers;
  final StickerImportSource source;
  final String? error;

  const StickerImportResult({
    required this.packId,
    required this.packName,
    required this.stickers,
    required this.source,
    this.error,
  });

  bool get isSuccess => error == null && stickers.isNotEmpty;
}

class ImportedSticker {
  final String id;
  final String filePath;
  final String? emoji;
  final String? label;
  final int sortOrder;

  const ImportedSticker({
    required this.id,
    required this.filePath,
    this.emoji,
    this.label,
    required this.sortOrder,
  });
}

class StickerImportService {
  static const _uuid = Uuid();

  final Dio _dio;

  StickerImportService({Dio? dio}) : _dio = dio ?? Dio();

  // ─── Telegram Import ────────────────────────────────────────────
  // Telegram sticker packs are accessible via @stickers bot or
  // third-party APIs. We download individual webp/png images.

  /// Импорт стикерпака из Telegram по имени пакета
  /// Telegram API: https://api.telegram.org/bot{token}/getStickerSet?name={pack_name}
  Future<StickerImportResult> importFromTelegram({
    required String botToken,
    required String packName,
  }) async {
    try {
      final response = await _dio.get(
        'https://api.telegram.org/bot$botToken/getStickerSet',
        queryParameters: {'name': packName},
      );

      final data = response.data['result'];
      final title = data['name'] as String? ?? packName;
      final stickersList = data['stickers'] as List? ?? [];

      final dir = await _getStickerDir('telegram_$packName');
      final imported = <ImportedSticker>[];

      for (int i = 0; i < stickersList.length; i++) {
        final sticker = stickersList[i];
        final fileId = sticker['file_id'] as String? ?? '';
        final emoji = sticker['emoji'] as String? ?? '';

        // Download sticker file
        final fileResponse = await _dio.get(
          'https://api.telegram.org/bot$botToken/getFile',
          queryParameters: {'file_id': fileId},
        );
        final filePath = fileResponse.data['result']['file_path'] as String? ?? '';

        final downloadUrl = 'https://api.telegram.org/file/bot$botToken/$filePath';
        final localPath = '${dir.path}/sticker_${i}.webp';

        await _dio.download(downloadUrl, localPath);

        imported.add(ImportedSticker(
          id: _uuid.v4(),
          filePath: localPath,
          emoji: emoji,
          sortOrder: i,
        ));
      }

      return StickerImportResult(
        packId: 'telegram_$packName',
        packName: title,
        stickers: imported,
        source: StickerImportSource.telegram,
      );
    } catch (e) {
      return StickerImportResult(
        packId: '',
        packName: '',
        stickers: [],
        source: StickerImportSource.telegram,
        error: 'Telegram import failed: $e',
      );
    }
  }

  // ─── VK Import ──────────────────────────────────────────────────
  // VK sticker packs are accessible via VK API.
  // Requires VK access token.

  /// Импорт стикерпака из VK по ID пакета
  Future<StickerImportResult> importFromVk({
    required String accessToken,
    required int packId,
  }) async {
    try {
      final response = await _dio.get(
        'https://api.vk.com/method/store.getStickersPack',
        queryParameters: {
          'access_token': accessToken,
          'pack_id': packId,
          'v': '5.131',
        },
      );

      final data = response.data['response'];
      final title = data['title'] as String? ?? 'VK Pack $packId';
      final stickersList = data['stickers'] as List? ?? [];

      final dir = await _getStickerDir('vk_$packId');
      final imported = <ImportedSticker>[];

      for (int i = 0; i < stickersList.length; i++) {
        final sticker = stickersList[i];
        final images = sticker['images'] as List? ?? [];
        // VK provides images in multiple sizes, pick 256x256 or largest
        final imageUrl = _pickBestVkImage(images);

        if (imageUrl.isNotEmpty) {
          final localPath = '${dir.path}/sticker_${i}.png';
          await _dio.download(imageUrl, localPath);

          imported.add(ImportedSticker(
            id: _uuid.v4(),
            filePath: localPath,
            emoji: sticker['emoji'] as String?,
            label: sticker['keywords']?.first as String?,
            sortOrder: i,
          ));
        }
      }

      return StickerImportResult(
        packId: 'vk_$packId',
        packName: title,
        stickers: imported,
        source: StickerImportSource.vk,
      );
    } catch (e) {
      return StickerImportResult(
        packId: '',
        packName: '',
        stickers: [],
        source: StickerImportSource.vk,
        error: 'VK import failed: $e',
      );
    }
  }

  String _pickBestVkImage(List images) {
    // VK returns images as list of {url, width, height} objects
    // We want the largest (typically 256 or 512)
    if (images.isEmpty) return '';
    // Sort by width descending and pick first
    final sorted = images.toList()
      ..sort((a, b) => ((b['width'] ?? 0) as int).compareTo((a['width'] ?? 0) as int));
    return sorted.first['url'] as String? ?? '';
  }

  // ─── WhatsApp Import ────────────────────────────────────────────
  // WhatsApp stickers come as .zip files containing webp images
  // and a sticker_packs.json manifest.

  /// Импорт стикерпака из WhatsApp zip файла
  Future<StickerImportResult> importFromWhatsAppZip({
    required String zipPath,
  }) async {
    try {
      // WhatsApp zip contains: sticker_packs.json + webp files
      // We need to unzip and extract
      final dir = await _getStickerDir('whatsapp_import');

      // Read zip file and extract
      final zipBytes = await File(zipPath).readAsBytes();

      // Parse manifest from zip
      // WhatsApp sticker packs contain a JSON manifest
      final imported = <ImportedSticker>[];
      int order = 0;

      // Use Dart's built-in approach or process via native
      // For now, extract individual files from known structure
      // WhatsApp format: stickers/01.webp, stickers/02.webp, etc.

      // Save zip content and process
      final manifestPath = '${dir.path}/sticker_packs.json';
      await File(zipPath).copy('${dir.path}/source.zip');

      // Parse manifest (simplified — real implementation uses zip extraction)
      // WhatsApp packs have emoji.txt mapping file and sticker_packs.json
      return StickerImportResult(
        packId: 'whatsapp_${_uuid.v4().substring(0, 8)}',
        packName: 'WhatsApp Import',
        stickers: imported,
        source: StickerImportSource.whatsapp,
      );
    } catch (e) {
      return StickerImportResult(
        packId: '',
        packName: '',
        stickers: [],
        source: StickerImportSource.whatsapp,
        error: 'WhatsApp import failed: $e',
      );
    }
  }

  // ─── Viber Import ──────────────────────────────────────────────
  // Viber sticker packs can be downloaded from Viber CDN

  /// Импорт стикерпака из Viber по ID пакета
  Future<StickerImportResult> importFromViber({
    required int packId,
  }) async {
    try {
      // Viber CDN pattern: https://stickers.viber.com/sticker_packs/{id}/...
      final response = await _dio.get(
        'https://stickers.viber.com/api/sticker_packs/$packId',
      );

      final data = response.data;
      final title = data['title'] as String? ?? 'Viber Pack $packId';
      final stickersList = data['stickers'] as List? ?? [];

      final dir = await _getStickerDir('viber_$packId');
      final imported = <ImportedSticker>[];

      for (int i = 0; i < stickersList.length; i++) {
        final sticker = stickersList[i];
        final imageUrl = sticker['image_url_256'] as String? ??
            sticker['image_url'] as String? ?? '';

        if (imageUrl.isNotEmpty) {
          final localPath = '${dir.path}/sticker_${i}.png';
          await _dio.download(imageUrl, localPath);

          imported.add(ImportedSticker(
            id: _uuid.v4(),
            filePath: localPath,
            emoji: sticker['emoji'] as String?,
            label: sticker['description'] as String?,
            sortOrder: i,
          ));
        }
      }

      return StickerImportResult(
        packId: 'viber_$packId',
        packName: title,
        stickers: imported,
        source: StickerImportSource.viber,
      );
    } catch (e) {
      return StickerImportResult(
        packId: '',
        packName: '',
        stickers: [],
        source: StickerImportSource.viber,
        error: 'Viber import failed: $e',
      );
    }
  }

  // ─── Local ZIP Import ──────────────────────────────────────────
  // Import from a .zip file containing PNG/WebP images + manifest.json

  /// Импорт стикерпака из локального ZIP-архива
  Future<StickerImportResult> importFromLocalZip({
    required String zipPath,
    String? packNameOverride,
  }) async {
    try {
      final zipBytes = await File(zipPath).readAsBytes();
      final packId = 'local_${_uuid.v4().substring(0, 8)}';
      final dir = await _getStickerDir(packId);

      // Copy source zip for processing
      await File(zipPath).copy('${dir.path}/source.zip');

      return StickerImportResult(
        packId: packId,
        packName: packNameOverride ?? 'Local Import',
        stickers: [],  // Actual extraction needs archive package
        source: StickerImportSource.localZip,
      );
    } catch (e) {
      return StickerImportResult(
        packId: '',
        packName: '',
        stickers: [],
        source: StickerImportSource.localZip,
        error: 'Local ZIP import failed: $e',
      );
    }
  }

  // ─── Local Folder Import ───────────────────────────────────────
  // Import all PNG/WebP images from a local directory

  /// Импорт стикерпака из локальной папки с изображениями
  Future<StickerImportResult> importFromLocalFolder({
    required String folderPath,
    required String packName,
    String? manifestPath,
  }) async {
    try {
      final packId = 'local_${_uuid.v4().substring(0, 8)}';
      final dir = await _getStickerDir(packId);

      final sourceDir = Directory(folderPath);
      if (!await sourceDir.exists()) {
        return StickerImportResult(
          packId: '',
          packName: '',
          stickers: [],
          source: StickerImportSource.localFolder,
          error: 'Source folder does not exist: $folderPath',
        );
      }

      final imported = <ImportedSticker>[];
      int order = 0;

      // Read manifest if available
      Map<String, dynamic>? manifest;
      if (manifestPath != null) {
        final manifestFile = File(manifestPath);
        if (await manifestFile.exists()) {
          manifest = jsonDecode(await manifestFile.readAsString());
        }
      }

      // Scan for image files
      final imageExtensions = ['.png', '.webp', '.jpg', '.jpeg', '.gif'];
      final files = await sourceDir.list().toList();
      final imageFiles = files
          .whereType<File>()
          .where((f) => imageExtensions.any((ext) => f.path.toLowerCase().endsWith(ext)))
          .toList();

      // Sort by name (natural order)
      imageFiles.sort((a, b) => a.path.compareTo(b.path));

      for (final file in imageFiles) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        final destPath = '${dir.path}/${fileName}';
        await file.copy(destPath);

        // Look up emoji from manifest if available
        String? emoji;
        String? label;
        if (manifest != null) {
          final stickerManifest = (manifest['stickers'] as List?)
              ?.firstWhere(
                (s) => (s['file'] as String?) == fileName,
                orElse: () => {},
              );
          emoji = stickerManifest?['emoji'] as String?;
          label = stickerManifest?['label'] as String?;
        }

        imported.add(ImportedSticker(
          id: _uuid.v4(),
          filePath: destPath,
          emoji: emoji ?? '😊',
          label: label ?? fileName.replaceAll(imageExtensions, ''),
          sortOrder: order++,
        ));
      }

      return StickerImportResult(
        packId: packId,
        packName: packName,
        stickers: imported,
        source: StickerImportSource.localFolder,
      );
    } catch (e) {
      return StickerImportResult(
        packId: '',
        packName: '',
        stickers: [],
        source: StickerImportSource.localFolder,
        error: 'Local folder import failed: $e',
      );
    }
  }

  // ─── Manifest Generation ───────────────────────────────────────

  /// Генерация manifest.json для импортированного стикерпака
  Future<String> generateManifest(StickerImportResult result) async {
    final manifest = {
      'id': result.packId,
      'name': result.packName,
      'source': result.source.name.toUpperCase(),
      'description': 'Imported from ${result.source.name}',
      'icon': result.stickers.isNotEmpty ? result.stickers.first.filePath.split('/').last : '',
      'isFeatured': false,
      'stickers': result.stickers.map((s) => {
        return {
          'id': s.id,
          'file': s.filePath.split('/').last,
          'emoji': s.emoji ?? '😊',
          'label': s.label ?? '',
          'sortOrder': s.sortOrder,
        };
      }).toList(),
    };

    final dir = Directory(result.stickers.first.filePath).parent;
    final manifestPath = '${dir.path}/manifest.json';
    await File(manifestPath).writeAsString(jsonEncode(manifest));

    return manifestPath;
  }

  // ─── Helpers ────────────────────────────────────────────────────

  Future<Directory> _getStickerDir(String packId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/stickers/$packId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Загрузка списка встроенных стикерпаков из assets
  Future<List<BuiltInStickerPack>> loadBuiltInPacks() async {
    // Scan assets/stickers/ for manifest.json files
    final packs = <BuiltInStickerPack>[];

    final packNames = ['charo_basics', 'charo_cats', 'charo_emotions', 'charo_food', 'charo_nature'];

    for (final name in packNames) {
      try {
        final manifestJson = await rootBundle.loadString(
          'assets/stickers/$name/manifest.json',
        );
        final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
        packs.add(BuiltInStickerPack(
          id: manifest['id'] as String,
          name: manifest['name'] as String,
          source: manifest['source'] as String,
          description: manifest['description'] as String,
          isFeatured: manifest['isFeatured'] as bool? ?? false,
          stickerCount: (manifest['stickers'] as List).length,
          assetPrefix: 'assets/stickers/$name',
        ));
      } catch (_) {
        // Pack not found in assets, skip
      }
    }

    return packs;
  }

  /// Загрузка списка ICQ эмодзи из assets
  Future<List<CustomEmoji>> loadIcqEmoji() async {
    final configJson = await rootBundle.loadString(
      'assets/emoji/emoji_config.json',
    );
    final config = jsonDecode(configJson) as Map<String, dynamic>;
    final images = config['customImages'] as List;

    return images.map((e) => CustomEmoji(
      id: e['id'] as String,
      assetPath: 'assets/emoji/${e['file']}',
      unicode: e['unicode'] as String,
      label: e['label'] as String,
    )).toList();
  }
}

class BuiltInStickerPack {
  final String id;
  final String name;
  final String source;
  final String description;
  final bool isFeatured;
  final int stickerCount;
  final String assetPrefix;

  const BuiltInStickerPack({
    required this.id,
    required this.name,
    required this.source,
    required this.description,
    required this.isFeatured,
    required this.stickerCount,
    required this.assetPrefix,
  });
}

class CustomEmoji {
  final String id;
  final String assetPath;
  final String unicode;
  final String label;

  const CustomEmoji({
    required this.id,
    required this.assetPath,
    required this.unicode,
    required this.label,
  });
}
