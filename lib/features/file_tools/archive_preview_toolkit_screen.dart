import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:printing/printing.dart';
import '../../core/models/tool_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/tool_scaffold.dart';
import 'archive_compare_service.dart';

enum ArchivePreviewTab {
  tarGzip('TAR & GZIP', Icons.archive_rounded),
  sevenZip('7z & RAR Explorer', Icons.folder_zip_rounded),
  folderCompare('Folder Compare', Icons.compare_arrows_rounded),
  fileDiff('File Diff', Icons.difference_rounded),
  filePreview('File Previewer', Icons.preview_rounded);

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

  // 3. Folder Compare State
  final List<ArchiveEntry> _folderAFiles = [];
  final List<ArchiveEntry> _folderBFiles = [];
  FolderDiffResult? _folderDiffResult;
  String _folderFilter = 'All'; // 'All', 'Identical', 'Modified', 'Only A', 'Only B'

  // 4. File Diff State
  String _fileAName = 'original.txt';
  String _fileBName = 'updated.txt';
  Uint8List _fileABytes = Uint8List(0);
  Uint8List _fileBBytes = Uint8List(0);
  FileDiffResult? _fileDiffResult;
  bool _isSideBySide = true;
  final TextEditingController _manualTextAController = TextEditingController();
  final TextEditingController _manualTextBController = TextEditingController();
  bool _isManualInput = false;

  // 5. Universal File Preview State
  String? _previewFileName;
  Uint8List? _previewFileBytes;
  PreviewFileType? _previewFileType;
  bool _isWordWrap = true;

  @override
  void initState() {
    super.initState();
    _activeTab = ArchivePreviewTab.values[widget.initialTabIndex.clamp(0, ArchivePreviewTab.values.length - 1)];
    _initSampleData();
  }

  void _initSampleData() {
    // Populate sample data for fast testing and intuitive demo
    _createFiles.addAll([
      ArchiveEntry(
        name: 'documents/readme.txt',
        size: 42,
        bytes: Uint8List.fromList(utf8.encode('Welcome to Toolbox Pro archive management!')),
      ),
      ArchiveEntry(
        name: 'config/settings.json',
        size: 58,
        bytes: Uint8List.fromList(utf8.encode('{"theme": "dark", "offline": true, "version": "1.0.86"}')),
      ),
      ArchiveEntry(
        name: 'data/notes.md',
        size: 35,
        bytes: Uint8List.fromList(utf8.encode('# Project Notes\n- Task 1\n- Task 2')),
      ),
    ]);

    // Sample folder files
    _folderAFiles.addAll([
      ArchiveEntry(name: 'src/index.js', size: 120, bytes: Uint8List.fromList(utf8.encode('console.log("v1");'))),
      ArchiveEntry(name: 'src/utils.js', size: 85, bytes: Uint8List.fromList(utf8.encode('function add(a, b) { return a + b; }'))),
      ArchiveEntry(name: 'assets/logo.png', size: 250, bytes: Uint8List.fromList(List.filled(250, 10))),
      ArchiveEntry(name: 'docs/guide.md', size: 90, bytes: Uint8List.fromList(utf8.encode('# User Guide v1'))),
    ]);

    _folderBFiles.addAll([
      ArchiveEntry(name: 'src/index.js', size: 135, bytes: Uint8List.fromList(utf8.encode('console.log("v2 updated");'))),
      ArchiveEntry(name: 'src/utils.js', size: 85, bytes: Uint8List.fromList(utf8.encode('function add(a, b) { return a + b; }'))),
      ArchiveEntry(name: 'assets/logo.png', size: 250, bytes: Uint8List.fromList(List.filled(250, 10))),
      ArchiveEntry(name: 'docs/changelog.md', size: 110, bytes: Uint8List.fromList(utf8.encode('## Release Notes v2'))),
    ]);
    _runFolderComparison();

    // Sample diff texts
    const sampleTextA = 'First line: Welcome\nSecond line: Offline utility\nThird line: Build 85\nFourth line: Done.';
    const sampleTextB = 'First line: Welcome\nSecond line: Offline utility powerhouse\nThird line: Build 86 with TAR & 7z\nNew line: Additional feature\nFourth line: Done.';
    _manualTextAController.text = sampleTextA;
    _manualTextBController.text = sampleTextB;
    _fileABytes = Uint8List.fromList(utf8.encode(sampleTextA));
    _fileBBytes = Uint8List.fromList(utf8.encode(sampleTextB));
    _runFileDiff();

    // Default preview file
    _previewFileName = 'welcome_guide.md';
    _previewFileBytes = Uint8List.fromList(utf8.encode(
      '# Advanced Archive & File Studio\n\n'
      '### Key Capabilities:\n'
      '- **TAR & GZIP**: Pack and unpack standard POSIX TAR and GZ archives.\n'
      '- **7z Explorer**: Container inspection, signature verification, and stream unpacking.\n'
      '- **Folder Comparison**: Tree diffing, modified checks, and SHA-256 validation.\n'
      '- **File Content Diff**: Side-by-side and unified textual diff with similarity scores.\n'
      '- **Universal Previewer**: Live renderer for images, text, code, markdown, and hex dumps.\n\n'
      '> 100% Offline & Private on device.\n',
    ));
    _previewFileType = PreviewFileType.markdown;
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
      category: ToolCategory.filesText,
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
      case ArchivePreviewTab.folderCompare:
        return _buildFolderCompareTab();
      case ArchivePreviewTab.fileDiff:
        return _buildFileDiffTab();
      case ArchivePreviewTab.filePreview:
        return _buildFilePreviewTab();
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
              Row(
                children: [
                  Expanded(
                    child: ModernTextField(
                      controller: _archiveNameController,
                      label: 'Archive Base Name',
                      hintText: 'archive_name',
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _tarCompressionType,
                    items: const [
                      DropdownMenuItem(value: 'tar', child: Text('.tar (Standard)')),
                      DropdownMenuItem(value: 'tar.gz', child: Text('.tar.gz (Gzip)')),
                      DropdownMenuItem(value: 'gz', child: Text('.gz (Single) ')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _tarCompressionType = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Files to Pack (${_createFiles.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
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
                    separatorBuilder: (_, __) => const Divider(height: 1),
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
                              'Size: ${(_selectedArchiveSize / 1024).toStringAsFixed(1)} KB • Extracted: ${_extractedEntries.length} files',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_extractedEntries.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Extracted Contents (${_extractedEntries.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
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
                          trailing: IconButton(
                            icon: const Icon(Icons.share_rounded, size: 18),
                            tooltip: 'Share File',
                            onPressed: () => Printing.sharePdf(
                              bytes: entry.bytes,
                              filename: entry.name.split('/').last,
                            ),
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
        for (final f in files) {
          final bytes = await f.readAsBytes();
          _createFiles.add(ArchiveEntry(
            name: f.name,
            size: bytes.length,
            bytes: bytes,
          ));
        }
        setState(() {});
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
      Uint8List outputBytes;
      String filename;

      if (_tarCompressionType == 'tar') {
        outputBytes = ArchiveCompareService.createTar(_createFiles);
        filename = '$baseName.tar';
      } else if (_tarCompressionType == 'tar.gz') {
        outputBytes = ArchiveCompareService.createTarGz(_createFiles);
        filename = '$baseName.tar.gz';
      } else {
        // Gzip first file
        final first = _createFiles.first;
        outputBytes = ArchiveCompareService.compressGzip(first.bytes);
        filename = '${first.name}.gz';
      }

      await Printing.sharePdf(bytes: outputBytes, filename: filename);
      _showToast('Successfully generated $filename (${outputBytes.length} bytes)');
    } catch (e) {
      _showToast('Archive build error: $e');
    } finally {
      setState(() => _isCreatingTar = false);
    }
  }

  Future<void> _pickArchiveToExtract() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        final f = files.first;
        final bytes = await f.readAsBytes();
        _processExtractArchive(f.name, bytes);
      }
    } catch (e) {
      _showToast('Error picking archive: $e');
    }
  }

  void _processExtractArchive(String filename, Uint8List bytes) {
    setState(() {
      _selectedArchiveName = filename;
      _selectedArchiveSize = bytes.length;
      _extractedEntries.clear();
    });

    try {
      final lower = filename.toLowerCase();
      if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
        final extracted = ArchiveCompareService.extractTarGz(bytes);
        setState(() => _extractedEntries.addAll(extracted));
        _showToast('Unpacked ${extracted.length} files from TAR.GZ archive');
      } else if (lower.endsWith('.tar')) {
        final extracted = ArchiveCompareService.extractTar(bytes);
        setState(() => _extractedEntries.addAll(extracted));
        _showToast('Unpacked ${extracted.length} files from TAR archive');
      } else if (lower.endsWith('.gz')) {
        final decompressed = ArchiveCompareService.decompressGzip(bytes);
        final innerName = filename.replaceAll(RegExp(r'\.gz$', caseSensitive: false), '');
        setState(() {
          _extractedEntries.add(ArchiveEntry(
            name: innerName,
            size: decompressed.length,
            bytes: decompressed,
          ));
        });
        _showToast('Decompressed GZIP file ($innerName)');
      } else {
        // Auto-detect format by trial
        try {
          final extracted = ArchiveCompareService.extractTarGz(bytes);
          setState(() => _extractedEntries.addAll(extracted));
        } catch (_) {
          final extracted = ArchiveCompareService.extractTar(bytes);
          setState(() => _extractedEntries.addAll(extracted));
        }
      }
    } catch (e) {
      _showToast('Extraction error: $e');
    }
  }

  Future<void> _exportAllExtractedFiles() async {
    if (_extractedEntries.isEmpty) return;
    try {
      // Re-pack into tar.gz for universal clean export
      final tarGz = ArchiveCompareService.createTarGz(_extractedEntries);
      await Printing.sharePdf(
        bytes: tarGz,
        filename: 'extracted_${DateTime.now().millisecondsSinceEpoch}.tar.gz',
      );
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.folder_zip_rounded),
                      label: const Text('Open .7z / .rar Archive'),
                      onPressed: _pickSevenZipFile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loadDemoSevenZip,
                    child: const Text('Sample 7z'),
                  ),
                  const SizedBox(width: 8),
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
                            Text('${entry.value}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
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
                          Printing.sharePdf(bytes: file.bytes, filename: file.name);
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
                            Text(entry.value.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
        final bytes = await f.readAsBytes();
        final lower = f.name.toLowerCase();

        // Check if RAR or 7z
        final isRar = lower.endsWith('.rar') ||
            (bytes.length >= 7 && bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72);

        if (isRar) {
          final rarInfo = ArchiveCompareService.inspectRarArchive(bytes);
          setState(() {
            _sevenZipFileName = f.name;
            _rarInfo = rarInfo;
            _sevenZipInfo = null;
          });
          _showToast(rarInfo.isValidRar ? 'RAR Archive parsed successfully' : 'Warning: Not a valid RAR archive');
        } else {
          final info = ArchiveCompareService.inspect7zArchive(bytes);
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
    bytes[10] = 0x04; // solid archive

    final rarInfo = ArchiveCompareService.inspectRarArchive(bytes);
    setState(() {
      _sevenZipFileName = 'sample_backup.rar';
      _rarInfo = rarInfo;
      _sevenZipInfo = null;
    });
    _showToast('Loaded sample RAR 5.0 archive specification');
  }

  // ==========================================
  // TAB 3: FOLDER COMPARISON
  // ==========================================
  Widget _buildFolderCompareTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Folder & Directory Tree Comparison',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open_rounded, color: Colors.blueAccent),
                      label: Text('Folder A (${_folderAFiles.length})'),
                      onPressed: () => _pickFolderFiles(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open_rounded, color: Colors.purpleAccent),
                      label: Text('Folder B (${_folderBFiles.length})'),
                      onPressed: () => _pickFolderFiles(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_folderDiffResult != null) ...[
                // Metric Summary Cards
                Row(
                  children: [
                    _buildSummaryMetric(
                      'Similarity',
                      '${_folderDiffResult!.similarityPercent.toStringAsFixed(1)}%',
                      AppColors.primaryOrange,
                    ),
                    const SizedBox(width: 8),
                    _buildSummaryMetric(
                      'Identical',
                      '${_folderDiffResult!.identicalCount}',
                      Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _buildSummaryMetric(
                      'Modified',
                      '${_folderDiffResult!.modifiedCount}',
                      Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    _buildSummaryMetric(
                      'Only A',
                      '${_folderDiffResult!.onlyInACount}',
                      Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    _buildSummaryMetric(
                      'Only B',
                      '${_folderDiffResult!.onlyInBCount}',
                      Colors.blueAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filter Chips
                Wrap(
                  spacing: 8,
                  children: ['All', 'Identical', 'Modified', 'Only A', 'Only B'].map((filter) {
                    final isSelected = _folderFilter == filter;
                    return ChoiceChip(
                      label: Text(filter, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _folderFilter = filter);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Comparison Items List
                Builder(
                  builder: (context) {
                    final filteredItems = _folderDiffResult!.items.where((item) {
                      if (_folderFilter == 'All') return true;
                      if (_folderFilter == 'Identical') return item.status == FolderEntryStatus.identical;
                      if (_folderFilter == 'Modified') return item.status == FolderEntryStatus.modified;
                      if (_folderFilter == 'Only A') return item.status == FolderEntryStatus.onlyInA;
                      if (_folderFilter == 'Only B') return item.status == FolderEntryStatus.onlyInB;
                      return true;
                    }).toList();

                    if (filteredItems.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No files match current filter.')),
                      );
                    }

                    return Container(
                      constraints: const BoxConstraints(maxHeight: 340),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = filteredItems[idx];
                          return ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Color(item.status.colorValue).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.status.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(item.status.colorValue),
                                ),
                              ),
                            ),
                            title: Text(item.relativePath, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              item.status == FolderEntryStatus.identical
                                  ? 'Size: ${item.sizeA} B • SHA-256 match'
                                  : item.status == FolderEntryStatus.modified
                                      ? 'A: ${item.sizeA} B ➔ B: ${item.sizeB} B (${item.sizeDiff > 0 ? "+${item.sizeDiff}" : item.sizeDiff} B)'
                                      : item.status == FolderEntryStatus.onlyInA
                                          ? 'Present in Folder A only (${item.sizeA} B)'
                                          : 'Present in Folder B only (${item.sizeB} B)',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: item.status == FolderEntryStatus.modified
                                ? IconButton(
                                    icon: const Icon(Icons.difference_rounded, size: 18, color: AppColors.primaryOrange),
                                    tooltip: 'Compare in Diff View',
                                    onPressed: () => _openInDiff(item.relativePath),
                                  )
                                : null,
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryMetric(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFolderFiles(bool isFolderA) async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        final target = isFolderA ? _folderAFiles : _folderBFiles;
        target.clear();
        for (final f in files) {
          final bytes = await f.readAsBytes();
          target.add(ArchiveEntry(name: f.name, size: bytes.length, bytes: bytes));
        }
        setState(() {});
        _runFolderComparison();
        _showToast('Updated ${isFolderA ? "Folder A" : "Folder B"} with ${files.length} files');
      }
    } catch (e) {
      _showToast('Error picking folder files: $e');
    }
  }

  void _runFolderComparison() {
    setState(() {
      _folderDiffResult = ArchiveCompareService.compareFolders(_folderAFiles, _folderBFiles);
    });
  }

  void _openInDiff(String relativePath) {
    final entryA = _folderAFiles.firstWhere((e) => e.name == relativePath);
    final entryB = _folderBFiles.firstWhere((e) => e.name == relativePath);
    setState(() {
      _fileAName = 'A: $relativePath';
      _fileBName = 'B: $relativePath';
      _fileABytes = entryA.bytes;
      _fileBBytes = entryB.bytes;
      _manualTextAController.text = utf8.decode(entryA.bytes, allowMalformed: true);
      _manualTextBController.text = utf8.decode(entryB.bytes, allowMalformed: true);
      _activeTab = ArchivePreviewTab.fileDiff;
    });
    _runFileDiff();
  }

  // ==========================================
  // TAB 4: FILE CONTENT DIFF
  // ==========================================
  Widget _buildFileDiffTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'File Content Comparison & Visual Diff',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.file_upload_rounded),
                      label: Text(_fileAName, overflow: TextOverflow.ellipsis),
                      onPressed: () => _pickDiffFile(true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.compare_arrows_rounded, color: Colors.grey),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.file_upload_rounded),
                      label: Text(_fileBName, overflow: TextOverflow.ellipsis),
                      onPressed: () => _pickDiffFile(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Diff Mode: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Side-by-Side', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: false, label: Text('Unified', style: TextStyle(fontSize: 11))),
                        ],
                        selected: {_isSideBySide},
                        onSelectionChanged: (set) => setState(() => _isSideBySide = set.first),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    icon: Icon(_isManualInput ? Icons.check_rounded : Icons.edit_note_rounded, size: 18),
                    label: Text(_isManualInput ? 'Apply Text' : 'Edit Inputs'),
                    onPressed: () {
                      if (_isManualInput) {
                        _fileABytes = Uint8List.fromList(utf8.encode(_manualTextAController.text));
                        _fileBBytes = Uint8List.fromList(utf8.encode(_manualTextBController.text));
                        _runFileDiff();
                      }
                      setState(() => _isManualInput = !_isManualInput);
                    },
                  ),
                ],
              ),
              if (_isManualInput) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Original Text (File A)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _manualTextAController,
                            maxLines: 6,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Modified Text (File B)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _manualTextBController,
                            maxLines: 6,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              if (_fileDiffResult != null) ...[
                // Diff KPI Row
                Row(
                  children: [
                    _buildSummaryMetric('Similarity', '${_fileDiffResult!.similarityPercent.toStringAsFixed(1)}%', AppColors.primaryOrange),
                    const SizedBox(width: 8),
                    _buildSummaryMetric('Unchanged', '${_fileDiffResult!.unchanged}', Colors.grey),
                    const SizedBox(width: 8),
                    _buildSummaryMetric('Additions (+)', '${_fileDiffResult!.additions}', Colors.green),
                    const SizedBox(width: 8),
                    _buildSummaryMetric('Deletions (-)', '${_fileDiffResult!.deletions}', Colors.redAccent),
                    const SizedBox(width: 8),
                    _buildSummaryMetric('Modified (~)', '${_fileDiffResult!.modifications}', Colors.amber),
                  ],
                ),
                const SizedBox(height: 16),

                // Visual Diff Viewer
                if (_fileDiffResult!.isBinary)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.data_object_rounded, size: 40, color: AppColors.primaryOrange),
                        const SizedBox(height: 8),
                        const Text('Binary Files Compared', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('File A: ${_fileDiffResult!.sizeA} bytes • Hash: ${_fileDiffResult!.hashA.substring(0, 16)}...'),
                        Text('File B: ${_fileDiffResult!.sizeB} bytes • Hash: ${_fileDiffResult!.hashB.substring(0, 16)}...'),
                        const SizedBox(height: 8),
                        Text(
                          _fileDiffResult!.similarityPercent == 100.0 ? '✓ Exact binary match!' : '≠ Binary files differ',
                          style: TextStyle(
                            color: _fileDiffResult!.similarityPercent == 100.0 ? Colors.green : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _isSideBySide ? _buildSideBySideDiffView() : _buildUnifiedDiffView(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSideBySideDiffView() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 380),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Scrollbar(
        child: ListView.builder(
          itemCount: _fileDiffResult!.lines.length,
          itemBuilder: (context, idx) {
            final line = _fileDiffResult!.lines[idx];
            Color? rowColor;
            if (line.type == DiffLineType.added) {
              rowColor = Colors.green.withValues(alpha: 0.15);
            } else if (line.type == DiffLineType.removed) {
              rowColor = Colors.red.withValues(alpha: 0.15);
            } else if (line.type == DiffLineType.modified) {
              rowColor = Colors.amber.withValues(alpha: 0.15);
            }

            return Container(
              color: rowColor,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side (A)
                  SizedBox(
                    width: 32,
                    child: Text(
                      line.lineNumA != null ? '${line.lineNumA}' : '',
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line.textA,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: line.type == DiffLineType.removed ? const Color(0xFFFF8A80) : Colors.white70,
                      ),
                    ),
                  ),
                  Container(width: 1, height: 18, color: Colors.grey.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  // Right Side (B)
                  SizedBox(
                    width: 32,
                    child: Text(
                      line.lineNumB != null ? '${line.lineNumB}' : '',
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line.textB,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: line.type == DiffLineType.added ? const Color(0xFFB9F6CA) : Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUnifiedDiffView() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 380),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Scrollbar(
        child: ListView.builder(
          itemCount: _fileDiffResult!.lines.length,
          itemBuilder: (context, idx) {
            final line = _fileDiffResult!.lines[idx];
            Color textColor = Colors.white70;
            Color bgColor = Colors.transparent;
            String prefix = ' ';

            if (line.type == DiffLineType.added) {
              textColor = const Color(0xFFB9F6CA);
              bgColor = Colors.green.withValues(alpha: 0.15);
              prefix = '+';
            } else if (line.type == DiffLineType.removed) {
              textColor = const Color(0xFFFF8A80);
              bgColor = Colors.red.withValues(alpha: 0.15);
              prefix = '-';
            } else if (line.type == DiffLineType.modified) {
              textColor = const Color(0xFFFFE082);
              bgColor = Colors.amber.withValues(alpha: 0.15);
              prefix = '~';
            }

            return Container(
              color: bgColor,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      line.lineNumA != null ? '${line.lineNumA}' : '',
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      line.lineNumB != null ? '${line.lineNumB}' : '',
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                  SizedBox(
                    width: 16,
                    child: Text(
                      prefix,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line.type == DiffLineType.removed ? line.textA : line.textB,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: textColor),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickDiffFile(bool isFileA) async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        final f = files.first;
        final bytes = await f.readAsBytes();
        setState(() {
          if (isFileA) {
            _fileAName = f.name;
            _fileABytes = bytes;
            _manualTextAController.text = utf8.decode(bytes, allowMalformed: true);
          } else {
            _fileBName = f.name;
            _fileBBytes = bytes;
            _manualTextBController.text = utf8.decode(bytes, allowMalformed: true);
          }
        });
        _runFileDiff();
      }
    } catch (e) {
      _showToast('Error picking file: $e');
    }
  }

  void _runFileDiff() {
    setState(() {
      _fileDiffResult = ArchiveCompareService.compareFileContents(
        _fileAName,
        _fileABytes,
        _fileBName,
        _fileBBytes,
      );
    });
  }

  // ==========================================
  // TAB 5: UNIVERSAL FILE PREVIEWER
  // ==========================================
  Widget _buildFilePreviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Universal File Previewer',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.file_open_rounded),
                      label: Text(_previewFileName ?? 'Pick Any File to Preview', overflow: TextOverflow.ellipsis),
                      onPressed: _pickPreviewFile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'Copy Content',
                    onPressed: _copyPreviewContent,
                  ),
                  IconButton(
                    icon: Icon(_isWordWrap ? Icons.wrap_text_rounded : Icons.menu_rounded),
                    tooltip: _isWordWrap ? 'Wrap Text: ON' : 'Wrap Text: OFF',
                    onPressed: () => setState(() => _isWordWrap = !_isWordWrap),
                  ),
                ],
              ),
              if (_previewFileName != null && _previewFileBytes != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _previewFileType?.label ?? 'File',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                      ),
                    ),
                    Text(
                      '${(_previewFileBytes!.length / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Format specific viewer
                _buildSpecificPreviewer(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificPreviewer() {
    if (_previewFileBytes == null) return const SizedBox.shrink();

    switch (_previewFileType) {
      case PreviewFileType.image:
        return Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: InteractiveViewer(
            child: Center(
              child: Image.memory(
                _previewFileBytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );

      case PreviewFileType.markdown:
        return Container(
          constraints: const BoxConstraints(maxHeight: 400),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Markdown(
            data: utf8.decode(_previewFileBytes!, allowMalformed: true),
            shrinkWrap: true,
          ),
        );

      case PreviewFileType.pdf:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const Icon(Icons.picture_as_pdf_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 8),
              Text(_previewFileName ?? 'document.pdf', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('${(_previewFileBytes!.length / 1024).toStringAsFixed(1)} KB PDF Document'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('View PDF via Printing Engine'),
                onPressed: () => Printing.layoutPdf(onLayout: (_) async => _previewFileBytes!),
              ),
            ],
          ),
        );

      case PreviewFileType.textCode:
        final text = utf8.decode(_previewFileBytes!, allowMalformed: true);
        final lines = text.split('\n');
        return Container(
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Scrollbar(
            child: ListView.builder(
              itemCount: lines.length,
              itemBuilder: (context, idx) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          lines[idx],
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                          softWrap: _isWordWrap,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

      case PreviewFileType.binaryHex:
      default:
        final hexLines = ArchiveCompareService.generateHexDump(_previewFileBytes!);
        return Container(
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Scrollbar(
            child: ListView.builder(
              itemCount: hexLines.length,
              itemBuilder: (context, idx) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    hexLines[idx],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF80D8FF),
                    ),
                  ),
                );
              },
            ),
          ),
        );
    }
  }

  Future<void> _pickPreviewFile() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        final f = files.first;
        final bytes = await f.readAsBytes();
        final type = ArchiveCompareService.detectFileType(f.name, bytes);
        setState(() {
          _previewFileName = f.name;
          _previewFileBytes = bytes;
          _previewFileType = type;
        });
      }
    } catch (e) {
      _showToast('Error picking file: $e');
    }
  }

  void _copyPreviewContent() {
    if (_previewFileBytes == null) return;
    try {
      final text = utf8.decode(_previewFileBytes!, allowMalformed: true);
      Clipboard.setData(ClipboardData(text: text));
      _showToast('File content copied to clipboard');
    } catch (_) {
      final hex = ArchiveCompareService.generateHexDump(_previewFileBytes!).join('\n');
      Clipboard.setData(ClipboardData(text: hex));
      _showToast('Hex dump copied to clipboard');
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive & Comparison Studio'),
        content: const SingleChildScrollView(
          child: Text(
            '• TAR & GZIP: Create and unpack .tar, .tar.gz, and .gz archives with zero cloud reliance.\n\n'
            '• 7z Explorer: Container signature analysis, magic byte verification (37 7A BC AF 27 1C), header CRC checks, and stream extraction.\n\n'
            '• Folder Comparison: Tree difference finder identifying identical, modified, and unique files with SHA-256 validation.\n\n'
            '• File Content Diff: Visual side-by-side or unified textual diff with color highlights (+/-/~) and similarity %.\n\n'
            '• Universal Previewer: In-app live rendering for images, code/text, markdown, PDFs, and hexadecimal binary dumps.',
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
