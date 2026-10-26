import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/share_utils.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';
import 'archive_preview_toolkit_screen.dart';
import 'file_zip_utils.dart';

enum FileZipTab {
  createZip('Create ZIP', Icons.folder_zip_rounded),
  extractZip('Extract ZIP', Icons.unarchive_rounded);

  final String label;
  final IconData icon;
  const FileZipTab(this.label, this.icon);
}

class PickedFileItem {
  final String name;
  final String extension;
  final int sizeBytes;
  final Uint8List bytes;
  final String? path;
  final PlatformFile? source;

  PickedFileItem({
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.bytes,
    this.path,
    this.source,
  });

  Future<Map<String, String>> hashes(List<String> algorithms) {
    final p = path;
    if (p != null) {
      return FileZipUtils.hashFileInBackground(p, algorithms);
    }
    if (source != null) {
      return FileZipUtils.hashStream(source!.readAsByteStream(), algorithms);
    }
    return FileZipUtils.hashStream(Stream.value(bytes), algorithms);
  }

  Future<List<int>> head(int maxBytes) {
    final s = source;
    if (s != null) {
      return FileZipUtils.readHead(s.readAsByteStream(), maxBytes);
    }
    return FileZipUtils.readHead(
      Stream.value(bytes),
      maxBytes,
    );
  }
}

class FileZipToolkitScreen extends StatefulWidget {
  const FileZipToolkitScreen({super.key});

  @override
  State<FileZipToolkitScreen> createState() => _FileZipToolkitScreenState();
}

class _FileZipToolkitScreenState extends State<FileZipToolkitScreen> {
  FileZipTab _activeTab = FileZipTab.createZip;

  // 1. Create ZIP State
  final List<PickedFileItem> _zipFiles = [];
  final TextEditingController _zipNameController =
      TextEditingController(text: 'Archive');
  bool _isCreatingZip = false;
  int? _lastZipSize;

  // 2. Extract ZIP State
  PickedFileItem? _selectedZipFile;
  final List<ArchiveFile> _extractedFiles = [];
  bool _isExtracting = false;

  static const _maxListedEntries = 200;

  @override
  void dispose() {
    _zipNameController.dispose();
    super.dispose();
  }

  // --- HELPERS ---

  Future<List<PickedFileItem>> _pickMultipleFiles({bool loadBytes = true}) async {
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        final List<PickedFileItem> items = [];
        for (final f in files) {
          final bytes = loadBytes ? await f.readAsBytes() : Uint8List(0);
          items.add(
            PickedFileItem(
              name: f.name,
              extension: f.extension?.toUpperCase() ?? 'FILE',
              sizeBytes: loadBytes
                  ? bytes.length
                  : (f.lengthSync() ?? await f.length() ?? 0),
              bytes: bytes,
              path: f.path,
              source: f,
            ),
          );
        }
        return items;
      }
    } catch (e) {
      _showToast('Error picking files: $e');
    }
    return [];
  }

  Future<PickedFileItem?> _pickSingleGenericFile({
    List<String>? allowedExtensions,
    bool loadBytes = true,
  }) async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );
      if (file != null) {
        final bytes = loadBytes ? await file.readAsBytes() : Uint8List(0);
        return PickedFileItem(
          name: file.name,
          extension: file.extension?.toUpperCase() ?? 'FILE',
          sizeBytes: loadBytes
              ? bytes.length
              : (file.lengthSync() ?? await file.length() ?? 0),
          bytes: bytes,
          path: file.path,
          source: file,
        );
      }
    } catch (e) {
      _showToast('Error picking file: $e');
    }
    return null;
  }

  Future<void> _shareBytes(List<int> bytes, String filename) async {
    try {
      await shareFileBytes(
        Uint8List.fromList(bytes),
        FileZipUtils.safeFileName(filename),
      );
    } catch (e) {
      _showToast('Share failed: $e');
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // --- TAB 1: CREATE ZIP ---
  Future<void> _addZipFiles() async {
    final picked = await _pickMultipleFiles();
    if (picked.isNotEmpty && mounted) {
      setState(() {
        _zipFiles.addAll(picked);
        _lastZipSize = null;
      });
    }
  }

  Future<void> _buildAndShareZip() async {
    if (_zipFiles.isEmpty) {
      _showToast('Select files to archive into ZIP.');
      return;
    }

    setState(() => _isCreatingZip = true);
    PreferencesService().triggerHaptic();

    try {
      final entries = [for (final f in _zipFiles) MapEntry(f.name, f.bytes)];
      final zipData = await FileZipUtils.createZipInBackground(entries);
      if (mounted) setState(() => _lastZipSize = zipData.length);
      var name = _zipNameController.text
          .trim()
          .replaceAll(RegExp(r'\.zip$', caseSensitive: false), '');
      if (name.isEmpty) name = 'Archive';
      await _shareBytes(
        zipData,
        '${name.replaceAll(RegExp(r'[\s/\\]'), '_')}.zip',
      );
    } catch (e) {
      _showToast('Failed to create ZIP: $e');
    } finally {
      if (mounted) setState(() => _isCreatingZip = false);
    }
  }

  // --- TAB 2: EXTRACT ZIP ---
  Future<void> _pickZipToExtract() async {
    final file = await _pickSingleGenericFile(allowedExtensions: ['zip']);
    if (file != null && mounted) {
      setState(() {
        _selectedZipFile = file;
        _extractedFiles.clear();
        _isExtracting = true;
      });

      try {
        final archive = ZipDecoder().decodeBytes(file.bytes);
        if (mounted) setState(() => _extractedFiles.addAll(archive.files));
      } catch (e) {
        _showToast('Error extracting ZIP archive: $e');
      } finally {
        if (mounted) setState(() => _isExtracting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'File & ZIP Suite',
      category: ToolCategory.compression,
      toolId: 'file_zip_toolkit',
      actions: [
        IconButton(
          icon: const Icon(Icons.archive_rounded),
          tooltip: 'TAR & 7z Archive Studio',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ArchivePreviewToolkitScreen(),
            ),
          ),
        ),
      ],
      onReset: () {
        setState(() {
          _zipFiles.clear();
          _zipNameController.text = 'Archive';
          _selectedZipFile = null;
          _extractedFiles.clear();
          _isExtracting = false;
          _lastZipSize = null;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeatureTabSelector<FileZipTab>(
            tabs: FileZipTab.values
                .map((tab) =>
                    FeatureTabItem(value: tab, label: tab.label, icon: tab.icon))
                .toList(),
            activeTab: _activeTab,
            accentColor: AppColors.catPdf,
            title: 'ZIP & Compression',
            onTabSelected: (tab) => setState(() => _activeTab = tab),
          ),
          const SizedBox(height: 20),

          if (_activeTab == FileZipTab.createZip) _buildCreateZipTab(isDark),
          if (_activeTab == FileZipTab.extractZip) _buildExtractZipTab(isDark),
        ],
      ),
    );
  }

  // ===================== TABS =====================

  Widget _buildCreateZipTab(bool isDark) {
    final totalBytes = _zipFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    var stats =
        '${(totalBytes / 1024).toStringAsFixed(1)} KB Uncompressed total';
    if (_lastZipSize != null) {
      final saved =
          FileZipUtils.compressionSavingsPercent(totalBytes, _lastZipSize!);
      stats +=
          '   ZIP: ${(_lastZipSize! / 1024).toStringAsFixed(1)} KB (${saved >= 0 ? "-$saved%" : "+${-saved}%"})';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'ZIP Archiver',
          primaryResult: '${_zipFiles.length} Files Selected',
          subtitle: stats,
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'Archive Name',
          controller: _zipNameController,
          hintText: 'Archive',
          prefixIcon: Icons.folder_zip_rounded,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Files to ZIP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catPdf,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _addZipFiles,
              ),
            ),
            if (_zipFiles.isNotEmpty) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Clear'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => setState(() {
                  _zipFiles.clear();
                  _lastZipSize = null;
                }),
              ),
            ],
          ],
        ),
        if (_zipFiles.isNotEmpty) ...[
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _zipFiles.length,
            itemBuilder: (ctx, idx) {
              final file = _zipFiles[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCardHover,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
                ),
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_rounded),
                  title: Text(file.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${(file.sizeBytes / 1024).toStringAsFixed(1)} KB • ${file.extension}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() {
                      _zipFiles.removeAt(idx);
                      _lastZipSize = null;
                    }),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: _isCreatingZip
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.archive_rounded),
            label: Text(_isCreatingZip
                ? 'Compressing...'
                : 'Build & Share ZIP Archive'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catPdf,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isCreatingZip ? null : _buildAndShareZip,
          ),
        ],
      ],
    );
  }

  Widget _buildExtractZipTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'ZIP Extractor',
          primaryResult: _selectedZipFile != null
              ? '${_extractedFiles.length} Contained Files'
              : 'Select a .zip File',
          subtitle: _selectedZipFile != null
              ? _selectedZipFile!.name
              : 'Inspect and unpack archive contents',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.unarchive_rounded),
          label: const Text('Pick .ZIP File to Extract'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickZipToExtract,
        ),
        if (_isExtracting) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ] else if (_extractedFiles.isNotEmpty) ...[
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _extractedFiles.length > _maxListedEntries
                ? _maxListedEntries
                : _extractedFiles.length,
            itemBuilder: (ctx, idx) {
              final file = _extractedFiles[idx];
              final isDir = !file.isFile;
              return ListTile(
                leading: Icon(
                    isDir
                        ? Icons.folder_rounded
                        : Icons.insert_drive_file_rounded,
                    color: AppColors.catPdf),
                title: Text(file.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    isDir ? 'Directory' : '${(file.size / 1024).toStringAsFixed(1)} KB'),
                trailing: file.isFile
                    ? IconButton(
                        icon: const Icon(Icons.share_rounded, size: 20),
                        tooltip: 'Share Extracted File',
                        onPressed: () {
                          try {
                            _shareBytes(file.content as List<int>, file.name);
                          } catch (e) {
                            _showToast(
                                'Cannot read entry (encrypted or corrupt?): $e');
                          }
                        },
                      )
                    : null,
              );
            },
          ),
          if (_extractedFiles.length > _maxListedEntries)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Showing the first $_maxListedEntries of ${_extractedFiles.length} entries.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ],
    );
  }
}
