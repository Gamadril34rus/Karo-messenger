// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/sticker_import_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// ─── Import Screen ──────────────────────────────────────────────
/// Экран импорта стикер-паков и эмодзи-паков из ZIP-архивов и папок.
///
/// Поддерживаемые форматы: WebP, PNG, JPG/JPEG, GIF, AVIF, BMP, SVG
///
/// Правовое предупреждение: пользователь несёт ответственность за
/// соблюдение авторских прав при импорте стикеров и эмодзи.

class StickerImportScreen extends StatefulWidget {
  const StickerImportScreen({super.key});

  @override
  State<StickerImportScreen> createState() => _StickerImportScreenState();
}

class _StickerImportScreenState extends State<StickerImportScreen> {
  final StickerImportService _service = StickerImportService();
  bool _isLoading = false;

  // Sticker state
  StickerImportResult? _stickerResult;
  // Emoji state
  EmojiImportResult? _emojiResult;

  String? _packName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Импорт'),
        elevation: 0,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // ─── Tab Bar ────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.sticky_note_2_outlined), text: 'Стикеры'),
                  Tab(icon: Icon(Icons.emoji_emotions_outlined), text: 'Эмодзи'),
                ],
              ),
            ),
            // ─── Tab Content ────────────────────────────────────────
            Expanded(
              child: TabBarView(
                children: [
                  _buildStickerTab(theme, isDark),
                  _buildEmojiTab(theme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STICKER TAB
  // ════════════════════════════════════════════════════════════════

  Widget _buildStickerTab(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Legal Disclaimer ───────────────────────────────────
          _buildDisclaimerCard(theme, isDark),
          const SizedBox(height: 16),

          // ─── Supported Formats ──────────────────────────────────
          CharoCard(
            color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF3E5F5),
            borderColor: const Color(0xFF7B1FA2),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(Icons.image_outlined, color: const Color(0xFF7B1FA2), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Форматы: ${StickerImportService.supportedFormats.map((e) => e.toUpperCase()).join(', ')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Pack Name ──────────────────────────────────────────
          CharoSection(
            title: 'Название пака',
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Например: Мои стикеры',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.label_outline),
              ),
              onChanged: (value) => _packName = value,
            ),
          ),
          const SizedBox(height: 16),

          // ─── Import Methods ────────────────────────────────────
          CharoSection(
            title: 'Источник',
            child: Column(
              children: [
                CharoTile(
                  leading: const Icon(Icons.archive_outlined, color: Color(0xFF25D366)),
                  title: 'ZIP-архив (WhatsApp формат)',
                  subtitle: 'WebP, PNG, JPG, GIF — с sticker_packs.json',
                  onTap: _isLoading ? null : _importStickersFromWhatsAppZip,
                ),
                const Divider(height: 1),
                CharoTile(
                  leading: const Icon(Icons.folder_zip_outlined, color: Color(0xFF7B1FA2)),
                  title: 'ZIP-архив (любой формат)',
                  subtitle: 'WebP, PNG, JPG, GIF, AVIF, BMP, SVG',
                  onTap: _isLoading ? null : _importStickersFromLocalZip,
                ),
                const Divider(height: 1),
                CharoTile(
                  leading: const Icon(Icons.folder_outlined, color: Color(0xFF0288D1)),
                  title: 'Локальная папка',
                  subtitle: 'Все форматы — сканирует папку автоматически',
                  onTap: _isLoading ? null : _importStickersFromLocalFolder,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading) const Center(child: CharoProgressRing(size: 48)),
          if (_stickerResult != null && !_isLoading) _buildStickerResultCard(theme, isDark),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  EMOJI TAB
  // ════════════════════════════════════════════════════════════════

  Widget _buildEmojiTab(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDisclaimerCard(theme, isDark),
          const SizedBox(height: 16),

          // ─── Supported Formats ──────────────────────────────────
          CharoCard(
            color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF3E5F5),
            borderColor: const Color(0xFF7B1FA2),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(Icons.emoji_emotions_outlined, color: const Color(0xFF7B1FA2), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Форматы: ${StickerImportService.supportedFormats.map((e) => e.toUpperCase()).join(', ')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Pack Name ──────────────────────────────────────────
          CharoSection(
            title: 'Название пака эмодзи',
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Например: Мои эмодзи',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.label_outline),
              ),
              onChanged: (value) => _packName = value,
            ),
          ),
          const SizedBox(height: 16),

          // ─── Import Methods ────────────────────────────────────
          CharoSection(
            title: 'Источник',
            child: Column(
              children: [
                CharoTile(
                  leading: const Icon(Icons.folder_zip_outlined, color: Color(0xFFE91E63)),
                  title: 'ZIP-архив',
                  subtitle: 'WebP, PNG, JPG, GIF, AVIF, BMP, SVG + manifest',
                  onTap: _isLoading ? null : _importEmojiFromZip,
                ),
                const Divider(height: 1),
                CharoTile(
                  leading: const Icon(Icons.folder_outlined, color: Color(0xFF9C27B0)),
                  title: 'Локальная папка',
                  subtitle: 'Все форматы — сканирует папку автоматически',
                  onTap: _isLoading ? null : _importEmojiFromFolder,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading) const Center(child: CharoProgressRing(size: 48)),
          if (_emojiResult != null && !_isLoading) _buildEmojiResultCard(theme, isDark),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SHARED UI COMPONENTS
  // ════════════════════════════════════════════════════════════════

  Widget _buildDisclaimerCard(ThemeData theme, bool isDark) {
    return CharoCard(
      color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFFFF3E0),
      borderColor: const Color(0xFFFF9800),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: const Color(0xFFFF9800), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                StickerImportService.legalDisclaimer,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sticker Result ────────────────────────────────────────────

  Widget _buildStickerResultCard(ThemeData theme, bool isDark) {
    final result = _stickerResult!;
    final isSuccess = result.isSuccess;

    return _buildResultContainer(
      theme: theme,
      isDark: isDark,
      isSuccess: isSuccess,
      title: isSuccess ? 'Стикеры импортированы!' : 'Ошибка импорта',
      infoRows: isSuccess ? [
        ('Пак ID', result.packId),
        ('Название', result.packName),
        ('Стикеров', '${result.stickers.length}'),
        ('Источник', result.source.name),
      ] : null,
      errorText: result.error,
      previewItems: isSuccess ? result.stickers : null,
      itemEmojiGetter: (item) => (item as ImportedSticker).emoji ?? '😊',
      itemFilePathGetter: (item) => (item as ImportedSticker).filePath,
    );
  }

  // ─── Emoji Result ──────────────────────────────────────────────

  Widget _buildEmojiResultCard(ThemeData theme, bool isDark) {
    final result = _emojiResult!;
    final isSuccess = result.isSuccess;

    return _buildResultContainer(
      theme: theme,
      isDark: isDark,
      isSuccess: isSuccess,
      title: isSuccess ? 'Эмодзи импортированы!' : 'Ошибка импорта',
      infoRows: isSuccess ? [
        ('Пак ID', result.packId),
        ('Название', result.packName),
        ('Эмодзи', '${result.emojis.length}'),
        ('Источник', result.source.name),
      ] : null,
      errorText: result.error,
      previewItems: isSuccess ? result.emojis : null,
      itemEmojiGetter: (item) => (item as ImportedEmoji).unicode,
      itemFilePathGetter: (item) => (item as ImportedEmoji).filePath,
    );
  }

  // ─── Generic Result Container ──────────────────────────────────

  Widget _buildResultContainer({
    required ThemeData theme,
    required bool isDark,
    required bool isSuccess,
    required String title,
    List<(String, String)>? infoRows,
    String? errorText,
    List<dynamic>? previewItems,
    required String Function(dynamic) itemEmojiGetter,
    required String Function(dynamic) itemFilePathGetter,
  }) {
    return CharoCard(
      color: isSuccess
          ? (isDark ? const Color(0xFF1B5E20) : const Color(0xFFE8F5E9))
          : (isDark ? const Color(0xFFB71C1C) : const Color(0xFFFFEBEE)),
      borderColor: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                  color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSuccess
                          ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                          : (isDark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828)),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isSuccess && infoRows != null) ...[
              for (final (label, value) in infoRows)
                _buildInfoRow(label, value),
              const SizedBox(height: 16),
              if (previewItems != null && previewItems.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: previewItems.length.clamp(0, 20),
                    itemBuilder: (context, index) {
                      final item = previewItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(itemFilePathGetter(item)),
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  itemEmojiGetter(item),
                                  style: const TextStyle(fontSize: 32),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
            if (!isSuccess && errorText != null) ...[
              Text(
                errorText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STICKER IMPORT ACTIONS
  // ════════════════════════════════════════════════════════════════

  Future<void> _importStickersFromWhatsAppZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Выберите ZIP-архив (WhatsApp формат)',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _isLoading = true);
    try {
      final importResult = await _service.importFromWhatsAppZip(zipPath: path);
      setState(() { _stickerResult = importResult; _isLoading = false; });
    } catch (e) {
      logger.e('WhatsApp ZIP sticker import failed: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importStickersFromLocalZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Выберите ZIP-архив со стикерами',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _isLoading = true);
    try {
      final importResult = await _service.importFromLocalZip(
        zipPath: path,
        packNameOverride: _packName,
      );
      setState(() { _stickerResult = importResult; _isLoading = false; });
    } catch (e) {
      logger.e('Local ZIP sticker import failed: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importStickersFromLocalFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку со стикерами',
    );
    if (dirPath == null) return;

    final packName = _packName ?? 'Imported Pack';
    setState(() => _isLoading = true);
    try {
      final importResult = await _service.importFromLocalFolder(
        folderPath: dirPath,
        packName: packName,
      );
      setState(() { _stickerResult = importResult; _isLoading = false; });
    } catch (e) {
      logger.e('Local folder sticker import failed: $e');
      setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  EMOJI IMPORT ACTIONS
  // ════════════════════════════════════════════════════════════════

  Future<void> _importEmojiFromZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Выберите ZIP-архив с эмодзи',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _isLoading = true);
    try {
      final importResult = await _service.importEmojiFromZip(
        zipPath: path,
        packNameOverride: _packName,
      );
      setState(() { _emojiResult = importResult; _isLoading = false; });
    } catch (e) {
      logger.e('Emoji ZIP import failed: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importEmojiFromFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку с эмодзи',
    );
    if (dirPath == null) return;

    final packName = _packName ?? 'Custom Emoji';
    setState(() => _isLoading = true);
    try {
      final importResult = await _service.importEmojiFromFolder(
        folderPath: dirPath,
        packName: packName,
      );
      setState(() { _emojiResult = importResult; _isLoading = false; });
    } catch (e) {
      logger.e('Emoji folder import failed: $e');
      setState(() => _isLoading = false);
    }
  }
}
