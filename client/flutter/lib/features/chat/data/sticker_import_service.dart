import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/logger.dart';

/// ─── Supported Image Formats ─────────────────────────────────────
/// Единый список поддерживаемых форматов для стикеров и эмодзи.
/// WebP, PNG, JPG/JPEG, GIF, AVIF, BMP, SVG — все принимаются.

const List<String> _supportedImageExtensions = [
  '.webp', '.png', '.jpg', '.jpeg', '.gif', '.avif', '.bmp', '.svg',
];

/// Проверка: является ли файл поддерживаемым изображением
bool _isImageFile(String fileName) {
  final lower = fileName.toLowerCase();
  return _supportedImageExtensions.any((ext) => lower.endsWith(ext));
}

/// ─── Sticker Import Service ──────────────────────────────────────
/// Импорт стикер-паков и эмодзи-паков из локальных ZIP-архивов и папок.
///
/// Поддерживаемые форматы: WebP, PNG, JPG/JPEG, GIF, AVIF, BMP, SVG
///
/// ⚖️ ВНИМАНИЕ: Юридические ограничения
/// - Telegram/VK/Viber API импорт REMOVED — нарушение ToS и авторских прав
/// - WhatsApp ZIP формат = открытый формат — допустимо
/// - Пользователь несёт ответственность за соблюдение авторских прав
///
/// ⚠️ Правовое предупреждение для UI:
/// «Импортируйте только стикеры и эмодзи, для которых вы имеете право использования.
///   Нарушение авторских прав может повлечь юридическую ответственность.»

// ─── Sticker Import ──────────────────────────────────────────────

enum StickerImportSource {
  whatsappZip,
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

// ─── Emoji Import ────────────────────────────────────────────────

enum EmojiImportSource {
  localZip,
  localFolder,
}

class EmojiImportResult {
  final String packId;
  final String packName;
  final List<ImportedEmoji> emojis;
  final EmojiImportSource source;
  final String? error;

  const EmojiImportResult({
    required this.packId,
    required this.packName,
    required this.emojis,
    required this.source,
    this.error,
  });

  bool get isSuccess => error == null && emojis.isNotEmpty;
}

class ImportedEmoji {
  final String id;
  final String filePath;
  final String unicode;
  final String label;
  final int sortOrder;

  const ImportedEmoji({
    required this.id,
    required this.filePath,
    this.unicode = '😊',
    this.label = '',
    required this.sortOrder,
  });
}

// ─── Service ─────────────────────────────────────────────────────

class StickerImportService {
  static const _uuid = Uuid();

  /// Правовое предупреждение для отображения в UI перед импортом
  static const String legalDisclaimer =
      'Импортируйте только стикеры и эмодзи, для которых вы имеете право использования. '
      'Нарушение авторских прав может повлечь юридическую ответственность.';

  /// Поддерживаемые форматы изображений (для отображения в UI)
  static const List<String> supportedFormats = _supportedImageExtensions;

  StickerImportService();

  // ════════════════════════════════════════════════════════════════
  //  STICKER IMPORT METHODS
  // ════════════════════════════════════════════════════════════════

  // ─── WhatsApp ZIP Import ────────────────────────────────────────

  /// Импорт стикерпака из ZIP-архива (WhatsApp формат)
  /// Принимает изображения: WebP, PNG, JPG, GIF, AVIF, BMP, SVG
  Future<StickerImportResult> importFromWhatsAppZip({
    required String zipPath,
  }) async {
    try {
      final dir = await _getStickerDir('whatsapp_import');
      final imported = <ImportedSticker>[];
      int order = 0;

      final zipFile = File(zipPath);
      final bytes = await zipFile.readAsBytes();

      try {
        final entries = _parseZipEntries(bytes);
        for (final entry in entries) {
          final fileName = entry.fileName;
          if (_isImageFile(fileName)) {
            final stickerData = entry.data;
            final localName = fileName.split('/').last;
            final localPath = '${dir.path}/$localName';
            await File(localPath).writeAsBytes(stickerData);
            imported.add(ImportedSticker(
              id: _uuid.v4(),
              filePath: localPath,
              emoji: '😊',
              sortOrder: order++,
            ));
          } else if (fileName.toLowerCase().contains('sticker_packs.json') ||
              fileName.toLowerCase().contains('manifest')) {
            final manifestJson = utf8.decode(entry.data);
            final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
            final stickerList = manifest['stickers'] as List<dynamic>? ?? [];
            for (int i = 0; i < imported.length && i < stickerList.length; i++) {
              final stickerManifest = stickerList[i] as Map<String, dynamic>;
              imported[i] = ImportedSticker(
                id: imported[i].id,
                filePath: imported[i].filePath,
                emoji: stickerManifest['emoji'] as String? ?? '😊',
                label: stickerManifest['label'] as String?,
                sortOrder: imported[i].sortOrder,
              );
            }
          }
        }
      } catch (e) {
        logger.w('ZIP extraction failed, returning empty result: $e');
      }

      return StickerImportResult(
        packId: 'whatsapp_${_uuid.v4().substring(0, 8)}',
        packName: 'ZIP-архив (WhatsApp формат)',
        stickers: imported,
        source: StickerImportSource.whatsappZip,
      );
    } catch (e) {
      return StickerImportResult(
        packId: '',
        packName: '',
        stickers: [],
        source: StickerImportSource.whatsappZip,
        error: 'WhatsApp ZIP import failed: $e',
      );
    }
  }

  // ─── Local ZIP Import ──────────────────────────────────────────

  /// Импорт стикерпака из локального ZIP-архива
  /// Принимает изображения: WebP, PNG, JPG/JPEG, GIF, AVIF, BMP, SVG
  Future<StickerImportResult> importFromLocalZip({
    required String zipPath,
    String? packNameOverride,
  }) async {
    try {
      final zipBytes = await File(zipPath).readAsBytes();
      final packId = 'local_${_uuid.v4().substring(0, 8)}';
      final dir = await _getStickerDir(packId);

      await File(zipPath).copy('${dir.path}/source.zip');

      final entries = _parseZipEntries(zipBytes);
      final imported = <ImportedSticker>[];
      int order = 0;

      Map<String, dynamic>? manifestData;
      for (final entry in entries) {
        if (entry.fileName.toLowerCase().contains('manifest.json') ||
            entry.fileName.toLowerCase().contains('sticker_packs.json')) {
          try {
            manifestData = jsonDecode(utf8.decode(entry.data, allowMalformed: true)) as Map<String, dynamic>;
          } catch (_) {}
        }
      }

      for (final entry in entries) {
        final fileName = entry.fileName.split('/').last;
        if (_isImageFile(fileName)) {
          final localPath = '${dir.path}/$fileName';
          await File(localPath).writeAsBytes(entry.data);
          imported.add(ImportedSticker(
            id: _uuid.v4(),
            filePath: localPath,
            emoji: '😊',
            sortOrder: order++,
          ));
        }
      }

      if (manifestData != null) {
        final stickersList = manifestData['stickers'] as List<dynamic>? ?? [];
        for (int i = 0; i < imported.length && i < stickersList.length; i++) {
          final s = stickersList[i] as Map<String, dynamic>;
          imported[i] = ImportedSticker(
            id: imported[i].id,
            filePath: imported[i].filePath,
            emoji: s['emoji'] as String? ?? imported[i].emoji,
            label: s['label'] as String?,
            sortOrder: imported[i].sortOrder,
          );
        }
      }

      return StickerImportResult(
        packId: packId,
        packName: packNameOverride ?? manifestData?['name'] as String? ?? 'Local Import',
        stickers: imported,
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

  /// Импорт стикерпака из локальной папки с изображениями
  /// Принимает: WebP, PNG, JPG/JPEG, GIF, AVIF, BMP, SVG
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

      Map<String, dynamic>? manifest;
      if (manifestPath != null) {
        final manifestFile = File(manifestPath);
        if (await manifestFile.exists()) {
          manifest = jsonDecode(await manifestFile.readAsString());
        }
      }

      final files = await sourceDir.list().toList();
      final imageFiles = files
          .whereType<File>()
          .where((f) => _isImageFile(f.path))
          .toList();

      imageFiles.sort((a, b) => a.path.compareTo(b.path));

      for (final file in imageFiles) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        final destPath = '${dir.path}/$fileName';
        await file.copy(destPath);

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
          label: label ?? fileName.replaceAll(RegExp(r'\.(webp|png|jpg|jpeg|gif|avif|bmp|svg)$'), ''),
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

  // ════════════════════════════════════════════════════════════════
  //  EMOJI IMPORT METHODS
  // ════════════════════════════════════════════════════════════════

  // ─── Emoji ZIP Import ──────────────────────────────────────────

  /// Импорт кастомных эмодзи из ZIP-архива
  /// Принимает: WebP, PNG, JPG/JPEG, GIF, AVIF, BMP, SVG
  ///
  /// ZIP может содержать:
  /// - manifest.json с полями emoji/label для каждого файла
  /// - Или просто набор изображений (emoji = 😊 по умолчанию)
  Future<EmojiImportResult> importEmojiFromZip({
    required String zipPath,
    String? packNameOverride,
  }) async {
    try {
      final zipBytes = await File(zipPath).readAsBytes();
      final packId = 'emoji_${_uuid.v4().substring(0, 8)}';
      final dir = await _getEmojiDir(packId);

      await File(zipPath).copy('${dir.path}/source.zip');

      final entries = _parseZipEntries(zipBytes);
      final imported = <ImportedEmoji>[];
      int order = 0;

      Map<String, dynamic>? manifestData;
      for (final entry in entries) {
        if (entry.fileName.toLowerCase().contains('manifest.json') ||
            entry.fileName.toLowerCase().contains('emoji_config.json')) {
          try {
            manifestData = jsonDecode(utf8.decode(entry.data, allowMalformed: true)) as Map<String, dynamic>;
          } catch (_) {}
        }
      }

      for (final entry in entries) {
        final fileName = entry.fileName.split('/').last;
        if (_isImageFile(fileName)) {
          final localPath = '${dir.path}/$fileName';
          await File(localPath).writeAsBytes(entry.data);

          String unicode = '😊';
          String label = '';
          if (manifestData != null) {
            final emojiList = manifestData['emojis'] as List<dynamic>? ?? manifestData['customImages'] as List<dynamic>? ?? [];
            final match = emojiList.firstWhere(
              (e) => (e['file'] as String?)?.split('/').last == fileName || (e['file'] as String?) == fileName,
              orElse: () => {},
            );
            unicode = match?['unicode'] as String? ?? '😊';
            label = match?['label'] as String? ?? '';
          }

          imported.add(ImportedEmoji(
            id: _uuid.v4(),
            filePath: localPath,
            unicode: unicode,
            label: label,
            sortOrder: order++,
          ));
        }
      }

      return EmojiImportResult(
        packId: packId,
        packName: packNameOverride ?? manifestData?['name'] as String? ?? 'Custom Emoji',
        emojis: imported,
        source: EmojiImportSource.localZip,
      );
    } catch (e) {
      return EmojiImportResult(
        packId: '',
        packName: '',
        emojis: [],
        source: EmojiImportSource.localZip,
        error: 'Emoji ZIP import failed: $e',
      );
    }
  }

  // ─── Emoji Folder Import ───────────────────────────────────────

  /// Импорт кастомных эмодзи из локальной папки
  /// Принимает: WebP, PNG, JPG/JPEG, GIF, AVIF, BMP, SVG
  Future<EmojiImportResult> importEmojiFromFolder({
    required String folderPath,
    required String packName,
    String? manifestPath,
  }) async {
    try {
      final packId = 'emoji_${_uuid.v4().substring(0, 8)}';
      final dir = await _getEmojiDir(packId);

      final sourceDir = Directory(folderPath);
      if (!await sourceDir.exists()) {
        return EmojiImportResult(
          packId: '',
          packName: '',
          emojis: [],
          source: EmojiImportSource.localFolder,
          error: 'Source folder does not exist: $folderPath',
        );
      }

      final imported = <ImportedEmoji>[];
      int order = 0;

      Map<String, dynamic>? manifest;
      if (manifestPath != null) {
        final manifestFile = File(manifestPath);
        if (await manifestFile.exists()) {
          manifest = jsonDecode(await manifestFile.readAsString());
        }
      }

      final files = await sourceDir.list().toList();
      final imageFiles = files
          .whereType<File>()
          .where((f) => _isImageFile(f.path))
          .toList();

      imageFiles.sort((a, b) => a.path.compareTo(b.path));

      for (final file in imageFiles) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        final destPath = '${dir.path}/$fileName';
        await file.copy(destPath);

        String unicode = '😊';
        String label = '';
        if (manifest != null) {
          final emojiList = manifest['emojis'] as List<dynamic>? ?? manifest['customImages'] as List<dynamic>? ?? [];
          final match = emojiList.firstWhere(
            (e) => (e['file'] as String?)?.split('/').last == fileName || (e['file'] as String?) == fileName,
            orElse: () => {},
          );
          unicode = match?['unicode'] as String? ?? '😊';
          label = match?['label'] as String? ?? '';
        }

        imported.add(ImportedEmoji(
          id: _uuid.v4(),
          filePath: destPath,
          unicode: unicode,
          label: label.isEmpty ? fileName.replaceAll(RegExp(r'\.(webp|png|jpg|jpeg|gif|avif|bmp|svg)$'), '') : label,
          sortOrder: order++,
        ));
      }

      return EmojiImportResult(
        packId: packId,
        packName: packName,
        emojis: imported,
        source: EmojiImportSource.localFolder,
      );
    } catch (e) {
      return EmojiImportResult(
        packId: '',
        packName: '',
        emojis: [],
        source: EmojiImportSource.localFolder,
        error: 'Emoji folder import failed: $e',
      );
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  MANIFEST + BUILT-IN PACKS
  // ════════════════════════════════════════════════════════════════

  /// Генерация manifest.json для импортированного стикерпака
  Future<String> generateStickerManifest(StickerImportResult result) async {
    final manifest = {
      'id': result.packId,
      'name': result.packName,
      'source': result.source.name.toUpperCase(),
      'description': 'Imported sticker pack',
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

  /// Генерация emoji_config.json для импортированного эмодзи-пака
  Future<String> generateEmojiManifest(EmojiImportResult result) async {
    final config = {
      'name': result.packName,
      'version': '1.0.0',
      'description': 'Custom imported emoji pack',
      'license': 'User-provided — check rights before distribution',
      'customImages': result.emojis.map((e) => {
        return {
          'id': e.id,
          'file': e.filePath.split('/').last,
          'unicode': e.unicode,
          'label': e.label,
        };
      }).toList(),
    };

    final dir = Directory(result.emojis.first.filePath).parent;
    final manifestPath = '${dir.path}/emoji_config.json';
    await File(manifestPath).writeAsString(jsonEncode(config));

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

  Future<Directory> _getEmojiDir(String packId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/emoji/$packId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Загрузка списка встроенных стикерпаков из assets
  Future<List<BuiltInStickerPack>> loadBuiltInPacks() async {
    final packs = <BuiltInStickerPack>[];

    final packNames = [
      'charo_basics', 'charo_cats', 'charo_emotions', 'charo_food', 'charo_nature',
      'charo_animals', 'charo_weather', 'charo_holidays', 'charo_meme', 'charo_work',
      'charo_travel', 'charo_gaming', 'charo_love', 'charo_retro', 'charo_food_ru',
    ];

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
      } catch (_) {}
    }

    return packs;
  }

  /// Загрузка списка Charo эмодзи из assets
  Future<List<CustomEmoji>> loadCharoEmoji() async {
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

// ─── ZIP Parser ────────────────────────────────────────────────────

class _ZipEntry {
  final String fileName;
  final Uint8List data;
  const _ZipEntry({required this.fileName, required this.data});
}

List<_ZipEntry> _parseZipEntries(Uint8List bytes) {
  final entries = <_ZipEntry>[];
  int pos = 0;

  while (pos < bytes.length - 4) {
    final sig = bytes[pos] | (bytes[pos + 1] << 8) | (bytes[pos + 2] << 16) | (bytes[pos + 3] << 24);
    if (sig != 0x04034b50) {
      pos++;
      continue;
    }

    final compressionMethod = bytes[pos + 8] | (bytes[pos + 9] << 8);
    final compressedSize = bytes[pos + 18] | (bytes[pos + 19] << 8) |
                          (bytes[pos + 20] << 16) | (bytes[pos + 21] << 24);
    final fileNameLen = bytes[pos + 26] | (bytes[pos + 27] << 8);
    final extraFieldLen = bytes[pos + 28] | (bytes[pos + 29] << 8);

    final fileNameStart = pos + 30;
    final fileNameBytes = bytes.sublist(fileNameStart, fileNameStart + fileNameLen);
    final fileName = utf8.decode(fileNameBytes, allowMalformed: true);

    final dataStart = fileNameStart + fileNameLen + extraFieldLen;
    final compressedData = bytes.sublist(dataStart, dataStart + compressedSize);

    Uint8List data;
    if (compressionMethod == 0) {
      data = Uint8List.fromList(compressedData);
    } else if (compressionMethod == 8) {
      try {
        final decoded = zlib.decode(compressedData);
        data = Uint8List.fromList(decoded);
      } catch (e) {
        pos = dataStart + compressedSize;
        continue;
      }
    } else {
      pos = dataStart + compressedSize;
      continue;
    }

    entries.add(_ZipEntry(fileName: fileName, data: data));
    pos = dataStart + compressedSize;
  }

  return entries;
}
