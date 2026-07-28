import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/sticker_import_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/charo_widgets.dart';

/// ─── Sticker Import Screen ──────────────────────────────────────
/// Экран импорта стикер-паков из ZIP-архивов и локальных папок.
///
/// Правовое предупреждение: пользователь несёт ответственность за
/// соблюдение авторских прав при импорте стикеров из любых источников.

class StickerImportScreen extends StatefulWidget {
  const StickerImportScreen({super.key});

  @override
  State<StickerImportScreen> createState() => _StickerImportScreenState();
}

class _StickerImportScreenState extends State<StickerImportScreen> {
  final StickerImportService _service = StickerImportService();
  bool _isLoading = false;
  StickerImportResult? _result;
  String? _packName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Импорт стикеров'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Legal Disclaimer ───────────────────────────────────
            CharoCard(
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
            ),
            const SizedBox(height: 24),

            // ─── Pack Name Input ────────────────────────────────────
            CharoSection(
              title: 'Название пака',
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Например: Мои стикеры',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                onChanged: (value) => _packName = value,
              ),
            ),
            const SizedBox(height: 24),

            // ─── Import Methods ────────────────────────────────────
            CharoSection(
              title: 'Источник стикеров',
              child: Column(
                children: [
                  // WhatsApp ZIP Import
                  CharoTile(
                    leading: const Icon(Icons.archive_outlined, color: Color(0xFF25D366)),
                    title: 'ZIP-архив (WhatsApp формат)',
                    subtitle: 'Импорт из .zip файла со sticker_packs.json',
                    onTap: _isLoading ? null : _importFromWhatsAppZip,
                  ),
                  const Divider(height: 1),
                  // Local ZIP Import
                  CharoTile(
                    leading: const Icon(Icons.folder_zip_outlined, color: Color(0xFF7B1FA2)),
                    title: 'ZIP-архив (любой формат)',
                    subtitle: 'Импорт из произвольного .zip файла',
                    onTap: _isLoading ? null : _importFromLocalZip,
                  ),
                  const Divider(height: 1),
                  // Local Folder Import
                  CharoTile(
                    leading: const Icon(Icons.folder_outlined, color: Color(0xFF0288D1)),
                    title: 'Локальная папка',
                    subtitle: 'Импорт PNG/WebP изображений из папки',
                    onTap: _isLoading ? null : _importFromLocalFolder,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Loading Indicator ──────────────────────────────────
            if (_isLoading)
              const Center(
                child: CharoProgressRing(size: 48),
              ),

            // ─── Import Result ──────────────────────────────────────
            if (_result != null && !_isLoading) ...[
              const SizedBox(height: 16),
              _buildResultCard(theme, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme, bool isDark) {
    final result = _result!;
    final isSuccess = result.isSuccess;

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
                    isSuccess ? 'Стикеры импортированы!' : 'Ошибка импорта',
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
            if (isSuccess) ...[
              _buildInfoRow('Пак ID', result.packId),
              _buildInfoRow('Название', result.packName),
              _buildInfoRow('Стикеров', '${result.stickers.length}'),
              _buildInfoRow('Источник', result.source.name),
              const SizedBox(height: 16),
              // Preview stickers grid
              if (result.stickers.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: result.stickers.length.clamp(0, 20),
                    itemBuilder: (context, index) {
                      final sticker = result.stickers[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(sticker.filePath),
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
                                  sticker.emoji ?? '😊',
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
            ] else ...[
              Text(
                result.error ?? 'Неизвестная ошибка',
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

  // ─── Import Actions ────────────────────────────────────────────

  Future<void> _importFromWhatsAppZip() async {
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
      setState(() {
        _result = importResult;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('WhatsApp ZIP import failed: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromLocalZip() async {
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
      setState(() {
        _result = importResult;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Local ZIP import failed: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromLocalFolder() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Выберите папку со стикерами',
    );

    if (result == null || result.files.isEmpty) return;

    // file_picker with pickFiles returns files, not a folder path
    // Use getDirectoryPath for folder selection
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
      setState(() {
        _result = importResult;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Local folder import failed: $e');
      setState(() => _isLoading = false);
    }
  }
}
