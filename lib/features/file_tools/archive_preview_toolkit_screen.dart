import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/tool_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/share_utils.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/tool_scaffold.dart';
import 'archive_compare_service.dart';
import 'file_zip_utils.dart';

enum ArchivePreviewTab {
  tarGzip('TAR & GZIP', Icons.archive_rounded),
  sevenZip('7z & RAR Explorer', Icons.folder_zip_rounded);

  final String label;
  final IconData icon;
  const ArchivePreviewTab(this.label, this.icon);
}

class ArchivePreviewToolkitScreen extends StatefulWidget {
  final int initialTabIndex;
  const ArchivePreviewToolkitScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ArchivePreviewToolkitScreen> createState() => _ArchivePreviewToolkitScreenState();
}

class _ArchivePreviewToolkitScreenState extends State<ArchivePreviewToolkitScreen> {
  late ArchivePreviewTab _activeTab;

  // 1. TAR & GZIP Archiver State

  bool _isCreatingTar = false;
  bool _isExtracting = false;
  String _tarCompressionType = 'tar.gz'; // 'tar', 'tar.gz', 'gz'
  final TextEditingController _archiveNameController = TextEditingController(text: 'backup_archive');
  final List<ArchiveEntry> _createFiles = [];
  final List<ArchiveEntry> _extractedEntries = [];
  String? _selectedArchiveName;
  int _selectedArchiveSize = 0;

  // 2. 7z & RAR Explorer State
  SevenZipInfo? _sevenZipInfo;
  RarArchiveInfo? _rarInfo;
  String? _sevenZipFileName;

  @override
  void initState() {
    super.initState();
    _activeTab = ArchivePreviewTab.values[widget.initialTabIndex.clamp(0, ArchivePreviewTab.values.length - 1)];
    _initSampleData();
  }

  void _initSampleData() {
    _createFiles.addAll([
      ArchiveEntry(
        name: 'documents/readme.txt',
        bytes: Uint8List.fromList(utf8.encode('Welcome to Toolbox Pro archive management!')),
      ),
      ArchiveEntry(
        name: 'config/settings.json',
        bytes: Uint8List.fromList(utf8.encode('{"theme": "dark", "offline": true, "version": "1.0.86"}')),
      ),
      ArchiveEntry(
        name: 'data/notes.md',
        bytes: Uint8List.fromList(utf8.encode('# Project Notes\n- Task 1\n- Task 2')),
      ),
    ]);
  }

  Future<void> _share(Uint8List bytes, String filename) async {
    try {
      await shareFileBytes(bytes, FileZipUtils.safeFileName(filename));
    } catch (e) {
      _showToast('Share failed: $e');
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Archive, Diff & File Studio',
      category: ToolCategory.compression,
      toolId: 'archive_compare_toolkit',
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline_rounded),
          tooltip: 'Archive Tools Guide',
          onPressed: _showInfoDialog,
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FeatureTabSelector<ArchivePreviewTab>(
              tabs: ArchivePreviewTab.values
                  .map((tab) => FeatureTabItem(value: tab, label: tab.label, icon: tab.icon))
                  .toList(),
              activeTab: _activeTab,
              accentColor: AppColors.primaryOrange,
              title: 'Archive & Diff Suite',
              onTabSelected: (tab) => setState(() => _activeTab = tab),
            ),
            const SizedBox(height: 16),
            _buildActiveTabContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case ArchivePreviewTab.tarGzip:
        return _buildTarGzipTab();
      case ArchivePreviewTab.sevenZip:
        return _buildSevenZipTab();
    }
  }

  // ==========================================
  // TAB 1: TAR & GZIP ARCHIVER
  // ==========================================
  Widget _buildTarGzipTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode 1: Create Archive Card
        _buildSectionCard(
          title: 'Create TAR / GZIP Archive',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ModernTextField(
                controller: _archiveNameController,
                label: 'Archive Base Name',
                hintText: 'archive_name',
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: _tarCompressionType,
                items: const [
                  DropdownMenuItem(value: 'tar', child: Text('.tar (Standard)')),
                  DropdownMenuItem(value: 'tar.gz', child: Text('.tar.gz (Gzip)')),
                  DropdownMenuItem(value: 'gz', child: Text('.gz (Single file)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _tarCompressionType = val);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Files to Pack (${_createFiles.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Files'),
                    onPressed: _pickFilesForCreateArchive,
                  ),
                  if (_createFiles.isNotEmpty)
                    TextButton(
                      child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () => setState(() => _createFiles.clear()),
                    ),
                ],
              ),
              if (_createFiles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: const Center(
                    child: Text('No files selected. Tap "Add Files" or use sample files.'),
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _createFiles.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = _createFiles[idx];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.insert_drive_file_rounded, color: AppColors.primaryOrange, size: 20),
                        title: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(item.formattedSize, style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                          onPressed: () => setState(() => _createFiles.removeAt(idx)),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.archive_rounded),
                label: Text(_isCreatingTar ? 'Creating...' : 'Build & Export .$_tarCompressionType'),
                onPressed: _isCreatingTar || _createFiles.isEmpty ? null : _buildAndExportArchive,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Mode 2: Extract Archive Card
        _buildSectionCard(
          title: 'Extract & Inspect Archive (.tar / .tar.gz / .gz)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.file_open_rounded),
                label: const Text('Pick Archive to Extract'),
                onPressed: _pickArchiveToExtract,
              ),
              if (_selectedArchiveName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_zip_rounded, color: AppColors.primaryOrange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedArchiveName!,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _isExtracting ? 'Size: ${(_selectedArchiveSize / 1024).toStringAsFixed(1)} KB • Unpacking...' : 'Size: ${(_selectedArchiveSize / 1024).toStringAsFixed(1)} KB • Extracted: ${_extractedEntries.length} files',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_isExtracting) const LinearProgressIndicator(color: AppColors.primaryOrange),
                if (_extractedEntries.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Extracted Contents (${_extractedEntries.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('Export All'),
                        onPressed: _exportAllExtractedFiles,
                      ),
                    ],
                  ),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _extractedEntries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final entry = _extractedEntries[idx];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            entry.isDirectory ? Icons.folder_rounded : Icons.description_rounded,
                            color: entry.isDirectory ? Colors.amber : AppColors.primaryOrange,
                            size: 20,
                          ),
                          title: Text(entry.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text('${entry.formattedSize} • SHA-256: ${entry.checksumSha256.substring(0, 8)}...'),
                          trailing: entry.isDirectory
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.share_rounded, size: 18),
                                  tooltip: 'Share File',
                                  onPressed: () => _share(entry.bytes, entry.name),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickFilesForCreateArchive() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        final picked = <ArchiveEntry>[];
        for (final f in files) {
          final bytes = await f.readAsBytes();
          picked.add(ArchiveEntry(
            name: f.name,
            size: bytes.length,
            bytes: bytes,
          ));
        }
        if (!mounted) return;
        setState(() => _createFiles.addAll(picked));
        _showToast('Added ${files.length} files to archive builder.');
      }
    } catch (e) {
      _showToast('Error selecting files: $e');
    }
  }

  Future<void> _buildAndExportArchive() async {
    if (_createFiles.isEmpty) return;
    setState(() => _isCreatingTar = true);

    try {
      final baseName = _archiveNameController.text.trim().isEmpty ? 'archive' : _archiveNameController.text.trim();
      final Uint8List outputBytes;
      String filename;

      if (_tarCompressionType == 'gz') {
        // .gz holds a single file: compress the first one and say so.
        final first = _createFiles.first;
        outputBytes = await ArchiveCompareService.buildArchiveInBackground([first], 'gz');
        filename = '${FileZipUtils.safeFileName(first.name)}.gz';
        if (_createFiles.length > 1) {
          _showToast('.gz holds one file: only "${first.name}" was compressed. Use .tar.gz for several.');
        }
      } else {
        outputBytes = await ArchiveCompareService.buildArchiveInBackground(List.of(_createFiles), _tarCompressionType);
        filename = '$baseName.$_tarCompressionType';
      }

      filename = FileZipUtils.safeFileName(filename);
      await shareFileBytes(outputBytes, filename);
      _showToast('Successfully generated $filename (${outputBytes.length} bytes)');
    } catch (e) {
      _showToast('Archive build error: $e');
    } finally {
      if (mounted) setState(() => _isCreatingTar = false);
    }
  }

  Future<void> _pickArchiveToExtract() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        final f = files.first;
        final bytes = await f.readAsBytes();
        if (!mounted) return;
        await _processExtractArchive(f.name, bytes);
      }
    } catch (e) {
      _showToast('Error picking archive: $e');
    }
  }

  Future<void> _processExtractArchive(String filename, Uint8List bytes) async {
    setState(() {
      _selectedArchiveName = filename;
      _selectedArchiveSize = bytes.length;
      _extractedEntries.clear();
      _isExtracting = true;
    });

    try {
      final extracted = await ArchiveCompareService.extractInBackground(filename, bytes);
      if (!mounted || _selectedArchiveName != filename) return;
      setState(() => _extractedEntries.addAll(extracted));
      _showToast(extracted.isEmpty ? 'No TAR/GZIP contents found in this file' : 'Unpacked ${extracted.length} file(s) from $filename');
    } catch (e) {
      _showToast('Could not unpack $filename: it is not a valid TAR / GZIP archive, or it is too large ($e)');
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _exportAllExtractedFiles() async {
    if (_extractedEntries.isEmpty) return;
    try {
      // Re-pack into tar.gz for universal clean export
      final tarGz = await ArchiveCompareService.buildArchiveInBackground(List.of(_extractedEntries), 'tar.gz');
      await shareFileBytes(tarGz, 'extracted_${DateTime.now().millisecondsSinceEpoch}.tar.gz');
      _showToast('Exported all unpacked files');
    } catch (e) {
      _showToast('Export error: $e');
    }
  }

  // ==========================================
  // TAB 2: 7Z & RAR ARCHIVE EXPLORER
  // ==========================================
  Widget _buildSevenZipTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: '7-Zip (7z) & RAR Archive Inspector',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Inspect 7z and RAR archives, verify magic signatures (7z: 37 7A BC AF 27 1C, RAR: 52 61 72 21 1A 07), parse headers, multi-volume flags, and format versions.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_zip_rounded),
                    label: const Text('Open .7z / .rar Archive'),
                    onPressed: _pickSevenZipFile,
                  ),
                  ElevatedButton(
                    onPressed: _loadDemoSevenZip,
                    child: const Text('Sample 7z'),
                  ),
                  ElevatedButton(
                    onPressed: _loadDemoRar,
                    child: const Text('Sample RAR'),
                  ),
                ],
              ),
              if (_sevenZipInfo != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_sevenZipInfo!.isValid7z ? AppColors.primaryOrange : Colors.redAccent).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (_sevenZipInfo!.isValid7z ? AppColors.primaryOrange : Colors.redAccent).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _sevenZipInfo!.isValid7z ? Icons.verified_rounded : Icons.warning_rounded,
                            color: _sevenZipInfo!.isValid7z ? Colors.green : Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _sevenZipFileName ?? '7z Archive',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _sevenZipInfo!.isValid7z ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _sevenZipInfo!.isValid7z ? 'VALID 7Z' : 'INVALID',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _sevenZipInfo!.isValid7z ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_sevenZipInfo!.status, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Diagnostic Metadata Table
                const Text('Container Header Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: _sevenZipInfo!.metadata.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 12),
                            Flexible(child: Text('${entry.value}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Extracted streams / files if any
                if (_sevenZipInfo!.extractedFiles.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Extracted Streams (${_sevenZipInfo!.extractedFiles.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('Export Stream'),
                        onPressed: () {
                          final file = _sevenZipInfo!.extractedFiles.first;
                          _share(file.bytes, file.name);
                        },
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.data_object_rounded, color: AppColors.primaryOrange),
                      title: Text(_sevenZipInfo!.extractedFiles.first.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text('${_sevenZipInfo!.extractedFiles.first.formattedSize} • SHA-256: ${_sevenZipInfo!.extractedFiles.first.checksumSha256.substring(0, 12)}...'),
                    ),
                  ),
                ],
              ],
              if (_rarInfo != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_rarInfo!.isValidRar ? AppColors.catPdf : Colors.redAccent).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (_rarInfo!.isValidRar ? AppColors.catPdf : Colors.redAccent).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _rarInfo!.isValidRar ? Icons.verified_rounded : Icons.warning_rounded,
                            color: _rarInfo!.isValidRar ? Colors.green : Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _sevenZipFileName ?? 'RAR Archive',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _rarInfo!.isValidRar ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _rarInfo!.isValidRar ? 'VALID ${_rarInfo!.version.toUpperCase()}' : 'INVALID',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _rarInfo!.isValidRar ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_rarInfo!.status, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('RAR Container Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: _rarInfo!.metadata.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 12),
                            Flexible(child: Text(entry.value.toString(), textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickSevenZipFile() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        final f = files.first;
        // Only the header is inspected, so never load a multi-GB archive into memory.
        final bytes = await FileZipUtils.readHead(f.readAsByteStream(), 1024 * 1024);
        final totalSize = f.lengthSync() ?? await f.length() ?? bytes.length;
        if (!mounted) return;
        final lower = f.name.toLowerCase();

        // Check if RAR or 7z
        final isRar = lower.endsWith('.rar') ||
            (bytes.length >= 7 && bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72);

        if (isRar) {
          final rarInfo = ArchiveCompareService.inspectRarArchive(bytes, totalSize: totalSize);
          setState(() {
            _sevenZipFileName = f.name;
            _rarInfo = rarInfo;
            _sevenZipInfo = null;
          });
          _showToast(rarInfo.isValidRar ? 'RAR Archive parsed successfully' : 'Warning: Not a valid RAR archive');
        } else {
          final info = ArchiveCompareService.inspect7zArchive(bytes, totalSize: totalSize);
          setState(() {
            _sevenZipFileName = f.name;
            _sevenZipInfo = info;
            _rarInfo = null;
          });
          _showToast(info.isValid7z ? '7z Archive parsed successfully' : 'Warning: Not a valid 7z archive');
        }
      }
    } catch (e) {
      _showToast('Error reading archive file: $e');
    }
  }

  void _loadDemoSevenZip() {
    // Generate valid 7z header (32 bytes) with magic bytes
    final bytes = Uint8List(64);
    bytes[0] = 0x37;
    bytes[1] = 0x7A;
    bytes[2] = 0xBC;
    bytes[3] = 0xAF;
    bytes[4] = 0x27;
    bytes[5] = 0x1C;
    bytes[6] = 0;
    bytes[7] = 4;
    bytes[8] = 0x12;
    bytes[9] = 0x34;
    bytes[10] = 0x56;
    bytes[11] = 0x78;
    bytes[12] = 32;

    final info = ArchiveCompareService.inspect7zArchive(bytes);
    setState(() {
      _sevenZipFileName = 'sample_container.7z';
      _sevenZipInfo = info;
      _rarInfo = null;
    });
    _showToast('Loaded sample 7z archive specification');
  }

  void _loadDemoRar() {
    // Generate valid RAR 5.0 header (8 bytes magic) + flags
    final bytes = Uint8List(32);
    // 52 61 72 21 1A 07 01 00
    bytes[0] = 0x52;
    bytes[1] = 0x61;
    bytes[2] = 0x72;
    bytes[3] = 0x21;
    bytes[4] = 0x1A;
    bytes[5] = 0x07;
    bytes[6] = 0x01;
    bytes[7] = 0x00;
    // Main archive header after the CRC32: size, type 1, no header flags, then
    // archive flags (vints).
    bytes[12] = 0x03;
    bytes[13] = 0x01;
    bytes[14] = 0x00;
    bytes[15] = 0x04; // solid archive

    final rarInfo = ArchiveCompareService.inspectRarArchive(bytes);
    setState(() {
      _sevenZipFileName = 'sample_backup.rar';
      _rarInfo = rarInfo;
      _sevenZipInfo = null;
    });
    _showToast('Loaded sample RAR 5.0 archive specification');
  }


  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TAR, GZIP & 7z Archive Studio'),
        content: const SingleChildScrollView(
          child: Text(
            '• TAR & GZIP: Create and unpack .tar, .tar.gz, and .gz archives with zero cloud reliance.\n\n'
            '• 7z & RAR Explorer: Container signature analysis, magic byte verification (37 7A BC AF 27 1C), header CRC checks, and stream extraction.\n\n'
            '> 100% Offline & Private on device.',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Got it'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
