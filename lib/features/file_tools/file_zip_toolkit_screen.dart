import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  extractZip('Extract ZIP', Icons.unarchive_rounded),
  batchRename('Batch Rename', Icons.drive_file_rename_outline_rounded),
  sizeAnalyzer('Size Analyzer', Icons.pie_chart_outline_rounded),
  hashCalc('Hash Calculator', Icons.tag_rounded),
  duplicateFinder('Duplicate Finder', Icons.content_copy_rounded),
  metadata('Metadata', Icons.info_outline_rounded),
  csvJson('CSV ⇄ JSON', Icons.sync_alt_rounded);

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

  /// The picked file, so big files can be streamed instead of loaded whole.
  final PlatformFile? source;

  PickedFileItem({
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.bytes,
    this.path,
    this.source,
  });

  /// Digests of the file read as a stream. Runs in a background isolate when the
  /// file is on disk; falls back to the picker's own stream otherwise.
  Future<Map<String, String>> hashes(List<String> algorithms) {
    final p = path;
    if (p != null) {
      return FileZipUtils.hashFileInBackground(p, algorithms);
    }
    if (source != null) return FileZipUtils.hashStream(source!.readAsByteStream(), algorithms);
    return FileZipUtils.hashStream(Stream.value(bytes), algorithms);
  }

  /// First [count] bytes of the file without reading the rest.
  Future<Uint8List> head(int count) async {
    final s = source;
    return FileZipUtils.readHead(s != null ? s.readAsByteStream() : Stream.value(bytes), count);
  }
}

class FileZipToolkitScreen extends StatefulWidget {
  const FileZipToolkitScreen({super.key});

  @override
  State<FileZipToolkitScreen> createState() => _FileZipToolkitScreenState();
}

class _FileZipToolkitScreenState extends State<FileZipToolkitScreen> {
  static const _maxListedEntries = 300;

  FileZipTab _activeTab = FileZipTab.createZip;

  // 1. Create ZIP State
  final List<PickedFileItem> _zipFiles = [];
  final TextEditingController _zipNameController = TextEditingController(text: 'Archive');
  bool _isCreatingZip = false;
  int? _lastZipSize;

  // 2. Extract ZIP State
  PickedFileItem? _selectedZipFile;
  final List<ArchiveFile> _extractedFiles = [];
  bool _isExtracting = false;

  // 3. Batch Rename State
  final List<PickedFileItem> _renameFiles = [];
  final TextEditingController _renamePrefixController = TextEditingController();
  final TextEditingController _renameSuffixController = TextEditingController();
  final TextEditingController _renameFindController = TextEditingController();
  final TextEditingController _renameReplaceController = TextEditingController();
  String _renameCaseMode = 'Keep Original'; // 'Keep Original', 'lowercase', 'UPPERCASE', 'Title Case'
  bool _addNumbering = true;

  // 4. File Size Analyzer State
  final List<PickedFileItem> _analyzedFiles = [];

  // 5. Hash Calculator State
  PickedFileItem? _hashTargetFile;
  String _md5Hash = '';
  String _sha1Hash = '';
  String _sha256Hash = '';
  String _sha512Hash = '';
  final TextEditingController _hashCompareController = TextEditingController();
  bool? _hashMatchResult;
  bool _isHashing = false;

  // 6. Duplicate Finder State
  final List<PickedFileItem> _duplicateSearchFiles = [];
  bool _duplicateScanDone = false;
  Map<String, List<PickedFileItem>> _duplicateGroups = {};
  bool _isScanningDuplicates = false;
  final Map<PickedFileItem, String> _duplicateHashes = {}; // sha256 per file, so adding files never re-hashes old ones

  // 7. Metadata State
  PickedFileItem? _metadataTargetFile;
  String _mimeType = 'Unknown';
  String _magicHeader = '';

  // 8. CSV ⇄ JSON State
  final TextEditingController _csvInputController = TextEditingController(
    text: 'id,name,role,salary\n1,Alice,Engineer,95000\n2,Bob,Designer,82000\n3,Charlie,Product,105000',
  );
  final TextEditingController _jsonInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _convertCsvToJson();
  }

  @override
  void dispose() {
    _zipNameController.dispose();
    _renamePrefixController.dispose();
    _renameSuffixController.dispose();
    _renameFindController.dispose();
    _renameReplaceController.dispose();
    _hashCompareController.dispose();
    _csvInputController.dispose();
    _jsonInputController.dispose();
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
          // Size-only callers skip reading the file so huge files don't OOM.
          final bytes = loadBytes ? await f.readAsBytes() : Uint8List(0);
          items.add(
            PickedFileItem(
              name: f.name,
              extension: f.extension?.toUpperCase() ?? 'FILE',
              sizeBytes: loadBytes ? bytes.length : (f.lengthSync() ?? await f.length() ?? 0),
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

  /// With [loadBytes] false the file is not read (hash / inspect callers stream it).
  Future<PickedFileItem?> _pickSingleGenericFile({List<String>? allowedExtensions, bool loadBytes = true}) async {
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
          sizeBytes: loadBytes ? bytes.length : (file.lengthSync() ?? await file.length() ?? 0),
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
      // The extension picks the MIME type, so keep it; strip any directory part.
      await shareFileBytes(Uint8List.fromList(bytes), FileZipUtils.safeFileName(filename));
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
      // Deflating many MB would freeze the UI, so do it in a background isolate.
      final zipData = await FileZipUtils.createZipInBackground(entries);
      if (mounted) setState(() => _lastZipSize = zipData.length);
      var name = _zipNameController.text.trim().replaceAll(RegExp(r'\.zip$', caseSensitive: false), '');
      if (name.isEmpty) name = 'Archive';
      await _shareBytes(zipData, '${name.replaceAll(RegExp(r'[\s/\\]'), '_')}.zip');
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

  // --- TAB 3: BATCH RENAME ---
  Future<void> _addRenameFiles() async {
    final picked = await _pickMultipleFiles();
    if (picked.isNotEmpty && mounted) {
      setState(() => _renameFiles.addAll(picked));
    }
  }

  String _computeRenamedName(String origName, int index) => FileZipUtils.computeRenamedName(
        origName,
        index,
        prefix: _renamePrefixController.text,
        suffix: _renameSuffixController.text,
        find: _renameFindController.text,
        replace: _renameReplaceController.text,
        caseMode: _renameCaseMode,
        addNumbering: _addNumbering,
      );

  Future<void> _exportRenamedZip() async {
    if (_renameFiles.isEmpty || _isCreatingZip) return;
    setState(() => _isCreatingZip = true);
    try {
      final entries = [
        for (int i = 0; i < _renameFiles.length; i++)
          MapEntry(_computeRenamedName(_renameFiles[i].name, i), _renameFiles[i].bytes),
      ];
      final zipData = await FileZipUtils.createZipInBackground(entries);
      await _shareBytes(zipData, 'Renamed_Files.zip');
    } catch (e) {
      _showToast('Error exporting renamed files: $e');
    } finally {
      if (mounted) setState(() => _isCreatingZip = false);
    }
  }

  // --- TAB 4: SIZE ANALYZER ---
  Future<void> _addFilesToAnalyze() async {
    final picked = await _pickMultipleFiles(loadBytes: false);
    if (picked.isNotEmpty && mounted) {
      setState(() => _analyzedFiles.addAll(picked));
    }
  }

  // --- TAB 5: HASH CALCULATOR ---
  Future<void> _pickHashFile() async {
    final file = await _pickSingleGenericFile(loadBytes: false);
    if (file == null || !mounted) return;
    setState(() {
      _hashTargetFile = file;
      _isHashing = true;
      _hashMatchResult = null;
      _md5Hash = _sha1Hash = _sha256Hash = _sha512Hash = '';
    });
    try {
      final h = await file.hashes(FileZipUtils.hashAlgorithms);
      if (!mounted || !identical(_hashTargetFile, file)) return; // another file was picked meanwhile
      setState(() {
        _md5Hash = h['md5']!;
        _sha1Hash = h['sha1']!;
        _sha256Hash = h['sha256']!;
        _sha512Hash = h['sha512']!;
        _isHashing = false;
      });
      // Re-check an already pasted hash against the newly picked file.
      _verifyHash(_hashCompareController.text);
    } catch (e) {
      _showToast('Could not read the file: $e');
      if (mounted && identical(_hashTargetFile, file)) {
        setState(() {
          _hashTargetFile = null;
          _isHashing = false;
        });
      }
    }
  }

  void _verifyHash(String target) {
    if (_hashTargetFile == null || _isHashing || target.trim().isEmpty) {
      setState(() => _hashMatchResult = null);
      return;
    }
    final clean = target.replaceAll(RegExp(r'\s'), '').toLowerCase();
    final match = clean == _md5Hash || clean == _sha1Hash || clean == _sha256Hash || clean == _sha512Hash;
    setState(() => _hashMatchResult = match);
  }

  // --- TAB 6: DUPLICATE FINDER ---
  Future<void> _pickDuplicateFiles() async {
    final picked = await _pickMultipleFiles(loadBytes: false);
    if (picked.isNotEmpty && mounted) {
      // Re-picking the same file must not report it as a duplicate of itself.
      final seenPaths = <String?>{for (final f in _duplicateSearchFiles) f.path};
      setState(() {
        _duplicateSearchFiles.addAll(picked.where((f) => f.path == null || seenPaths.add(f.path)));
        _duplicateScanDone = true;
      });
      await _computeDuplicates();
    }
  }

  /// Only files that share a size can be duplicates, so just those are hashed (streamed,
  /// off the UI thread), and each file is hashed once.
  Future<void> _computeDuplicates() async {
    final bySize = <int, List<PickedFileItem>>{};
    for (final file in _duplicateSearchFiles) {
      bySize.putIfAbsent(file.sizeBytes, () => []).add(file);
    }
    setState(() => _isScanningDuplicates = true);
    try {
      final groups = <String, List<PickedFileItem>>{};
      for (final sameSize in bySize.values.where((l) => l.length > 1)) {
        for (final file in sameSize) {
          final hash = _duplicateHashes[file] ??= (await file.hashes(const ['sha256']))['sha256']!;
          groups.putIfAbsent('${file.sizeBytes}:$hash', () => []).add(file);
        }
      }
      if (!mounted) return;
      setState(() => _duplicateGroups = {
            for (final e in groups.entries)
              if (e.value.length > 1) e.key: e.value,
          });
    } catch (e) {
      _showToast('Could not scan a file: $e');
    } finally {
      if (mounted) setState(() => _isScanningDuplicates = false);
    }
  }

  // --- TAB 7: METADATA ---
  Future<void> _pickMetadataFile() async {
    final file = await _pickSingleGenericFile(loadBytes: false);
    if (file == null || !mounted) return;
    try {
      // MIME sniffing and the magic header only need the first bytes.
      final head = await file.head(16);
      final mime = FileZipUtils.detectMimeType(head, file.extension);
      final header = head.take(8).map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      if (!mounted) return;
      setState(() {
        _metadataTargetFile = file;
        _mimeType = mime;
        _magicHeader = header;
      });
    } catch (e) {
      _showToast('Could not read the file: $e');
    }
  }

  // --- TAB 8: CSV ⇄ JSON ---
  void _convertCsvToJson() {
    try {
      final raw = _csvInputController.text.trim();
      if (raw.isEmpty) return;
      final rows = csv.decode(raw);
      if (rows.isEmpty) return;

      final headers = rows.first.map((h) => h.toString()).toList();
      final List<Map<String, dynamic>> jsonList = [];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final Map<String, dynamic> rowMap = {};
        for (int c = 0; c < headers.length; c++) {
          if (c < row.length) {
            rowMap[headers[c]] = row[c];
          }
        }
        jsonList.add(rowMap);
      }

      const encoder = JsonEncoder.withIndent('  ');
      setState(() {
        _jsonInputController.text = encoder.convert(jsonList);
      });
    } catch (e) {
      _showToast('CSV parse error: $e');
    }
  }

  void _convertJsonToCsv() {
    try {
      final raw = _jsonInputController.text.trim();
      if (raw.isEmpty) return;
      final rows = FileZipUtils.jsonToCsvRows(jsonDecode(raw));
      setState(() {
        _csvInputController.text = csv.encode(rows);
      });
    } catch (e) {
      _showToast('JSON parse error: $e');
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
          tooltip: 'TAR, 7z & Diff Studio',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArchivePreviewToolkitScreen()),
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
          _renameFiles.clear();
          _renamePrefixController.clear();
          _renameSuffixController.clear();
          _renameFindController.clear();
          _renameReplaceController.clear();
          _renameCaseMode = 'Keep Original';
          _addNumbering = true;
          _analyzedFiles.clear();
          _hashTargetFile = null;
          _isHashing = false;
          _md5Hash = _sha1Hash = _sha256Hash = _sha512Hash = '';
          _hashMatchResult = null;
          _hashCompareController.clear();
          _duplicateSearchFiles.clear();
          _duplicateHashes.clear();
          _duplicateGroups = {};
          _isScanningDuplicates = false;
          _duplicateScanDone = false;
          _metadataTargetFile = null;
          _mimeType = 'Unknown';
          _magicHeader = '';
          _lastZipSize = null;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab bar
          FeatureTabSelector<FileZipTab>(
            tabs: FileZipTab.values
                .map((tab) => FeatureTabItem(value: tab, label: tab.label, icon: tab.icon))
                .toList(),
            activeTab: _activeTab,
            accentColor: AppColors.catPdf,
            title: 'File & ZIP Suite',
            onTabSelected: (tab) => setState(() => _activeTab = tab),
          ),
          const SizedBox(height: 20),

          if (_activeTab == FileZipTab.createZip) _buildCreateZipTab(isDark),
          if (_activeTab == FileZipTab.extractZip) _buildExtractZipTab(isDark),
          if (_activeTab == FileZipTab.batchRename) _buildBatchRenameTab(isDark),
          if (_activeTab == FileZipTab.sizeAnalyzer) _buildSizeAnalyzerTab(isDark),
          if (_activeTab == FileZipTab.hashCalc) _buildHashCalcTab(isDark),
          if (_activeTab == FileZipTab.duplicateFinder) _buildDuplicateFinderTab(isDark),
          if (_activeTab == FileZipTab.metadata) _buildMetadataTab(isDark),
          if (_activeTab == FileZipTab.csvJson) _buildCsvJsonTab(isDark),
        ],
      ),
    );
  }

  // ===================== TABS =====================

  Widget _buildCreateZipTab(bool isDark) {
    final totalBytes = _zipFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    final totalSizeKb = totalBytes / 1024;
    var stats = 'Uncompressed Total: ${totalSizeKb.toStringAsFixed(1)} KB';
    if (_lastZipSize != null) {
      final saved = FileZipUtils.compressionSavingsPercent(totalBytes, _lastZipSize!);
      stats += ' • ZIP: ${(_lastZipSize! / 1024).toStringAsFixed(1)} KB '
          '(${saved >= 0 ? '${saved.toStringAsFixed(1)}% saved' : 'no reduction'})';
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _addZipFiles,
              ),
            ),
            if (_zipFiles.isNotEmpty) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => setState(() {
                  _zipFiles.clear();
                  _lastZipSize = null;
                }),
              ),
            ],
          ],
        ),
        if (_zipFiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _zipFiles.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final file = _zipFiles[idx];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                leading: const Icon(Icons.insert_drive_file_rounded, color: AppColors.catPdf),
                title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${(file.sizeBytes / 1024).toStringAsFixed(1)} KB • ${file.extension}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  onPressed: () => setState(() {
                    _zipFiles.removeAt(idx);
                    _lastZipSize = null;
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isCreatingZip
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.archive_rounded),
              label: Text(_isCreatingZip ? 'Compressing...' : 'Build & Share ZIP Archive'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isCreatingZip ? null : _buildAndShareZip,
            ),
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
          primaryResult: _selectedZipFile != null ? '${_extractedFiles.length} Contained Files' : 'Select a .zip File',
          subtitle: _selectedZipFile != null ? _selectedZipFile!.name : 'Inspect and unpack archive contents',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Pick .ZIP File to Extract'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickZipToExtract,
        ),
        if (_isExtracting) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_extractedFiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // A shrink-wrapped list builds every row, so very large archives show the first rows only.
            itemCount: _extractedFiles.length > _maxListedEntries ? _maxListedEntries : _extractedFiles.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final file = _extractedFiles[idx];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                leading: Icon(
                  file.isFile ? Icons.description_rounded : Icons.folder_rounded,
                  color: AppColors.catPdf,
                ),
                title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(file.isFile ? '${(file.size / 1024).toStringAsFixed(1)} KB' : 'Folder'),
                trailing: file.isFile
                    ? IconButton(
                        icon: const Icon(Icons.share_rounded, size: 18),
                        onPressed: () {
                          try {
                            // Entry names like "../x" or "dir/x" are reduced to a safe base name.
                            _shareBytes(file.content, file.name);
                          } catch (e) {
                            _showToast('Cannot read entry (encrypted or corrupt?): $e');
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

  Widget _buildBatchRenameTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Batch File Renamer',
          primaryResult: '${_renameFiles.length} Files Loaded',
          subtitle: 'Prefix, suffix, find & replace, and automatic number sequencing',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_rounded),
          label: const Text('Select Files to Rename'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _addRenameFiles,
        ),
        if (_renameFiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'Prefix', controller: _renamePrefixController, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: ModernTextField(label: 'Suffix', controller: _renameSuffixController, onChanged: (_) => setState(() {}))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'Find Text', controller: _renameFindController, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: ModernTextField(label: 'Replace With', controller: _renameReplaceController, onChanged: (_) => setState(() {}))),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Letter Case Mode',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            initialValue: _renameCaseMode,
            items: ['Keep Original', 'lowercase', 'UPPERCASE', 'Title Case']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _renameCaseMode = val);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add Sequential Numbering (e.g. _001)', style: TextStyle(fontWeight: FontWeight.w600)),
            value: _addNumbering,
            activeTrackColor: AppColors.catPdf,
            onChanged: (val) => setState(() => _addNumbering = val),
          ),
          const SizedBox(height: 12),
          const Text('Live Preview (Old ➔ New)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _renameFiles.length,
            separatorBuilder: (_, index) => const SizedBox(height: 6),
            itemBuilder: (context, idx) {
              final orig = _renameFiles[idx].name;
              final renamed = _computeRenamedName(orig, idx);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(orig, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.catPdf),
                    const SizedBox(width: 6),
                    Expanded(child: Text(renamed, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.catPdf), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: Text(_isCreatingZip ? 'Compressing...' : 'Export Renamed Files as ZIP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isCreatingZip ? null : _exportRenamedZip,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSizeAnalyzerTab(bool isDark) {
    final totalBytes = _analyzedFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(2);

    final sorted = List<PickedFileItem>.from(_analyzedFiles)
      ..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Storage Analyzer',
          primaryResult: '$totalMb MB Total',
          subtitle: '${_analyzedFiles.length} Files Scanned',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Add Files to Analyze Size'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _addFilesToAnalyze,
        ),
        if (sorted.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Largest Files Ranked', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sorted.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final item = sorted[idx];
              final ratio = totalBytes > 0 ? (item.sizeBytes / totalBytes) : 0.0;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        Text('${(item.sizeBytes / 1024).toStringAsFixed(1)} KB (${(ratio * 100).toStringAsFixed(1)}%)'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: ratio, color: AppColors.catPdf, backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildHashCalcTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'File Checksum Hashes',
          primaryResult: _hashTargetFile != null ? _hashTargetFile!.name : 'Pick a File',
          subtitle: 'Calculates cryptographic checksums for integrity verification',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Pick File to Compute Hashes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isHashing ? null : _pickHashFile,
        ),
        if (_hashTargetFile != null && _isHashing) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(color: AppColors.catPdf),
          const SizedBox(height: 8),
          Text('Hashing ${(_hashTargetFile!.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB...'),
        ],
        if (_hashTargetFile != null && !_isHashing) ...[
          const SizedBox(height: 16),
          _hashRow('SHA-256', _sha256Hash),
          _hashRow('SHA-1', _sha1Hash),
          _hashRow('MD5', _md5Hash),
          _hashRow('SHA-512', _sha512Hash),
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Verify against expected hash',
            controller: _hashCompareController,
            hintText: 'Paste expected hash to compare...',
            onChanged: _verifyHash,
          ),
          if (_hashMatchResult != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(_hashMatchResult! ? Icons.check_circle_rounded : Icons.cancel_rounded, color: _hashMatchResult! ? AppColors.success : AppColors.error),
                const SizedBox(width: 8),
                Text(
                  _hashMatchResult! ? 'Checksum MATCHES!' : 'Checksum DOES NOT match!',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _hashMatchResult! ? AppColors.success : AppColors.error),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _hashRow(String algo, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.catPdf.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text('$algo: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Expanded(child: Text(val, style: const TextStyle(fontFamily: 'monospace', fontSize: 11), overflow: TextOverflow.ellipsis)),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: val));
                _showToast('$algo copied!');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuplicateFinderTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Duplicate Finder',
          primaryResult: '${_duplicateGroups.length} Duplicate Clusters',
          subtitle: 'Matches identical files by cryptographic byte content',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.folder_copy_rounded),
          label: const Text('Add Files to Scan for Duplicates'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isScanningDuplicates ? null : _pickDuplicateFiles,
        ),
        if (_isScanningDuplicates) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(color: AppColors.catPdf),
        ],
        if (_duplicateSearchFiles.isNotEmpty && !_isScanningDuplicates) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.clear_all_rounded),
              label: Text('Clear ${_duplicateSearchFiles.length} files'),
              onPressed: () => setState(() {
                _duplicateSearchFiles.clear();
                _duplicateHashes.clear();
                _duplicateGroups = {};
                _duplicateScanDone = false;
              }),
            ),
          ),
        ],
        if (_duplicateScanDone && !_isScanningDuplicates && _duplicateGroups.isEmpty) ...[
          const SizedBox(height: 16),
          Text('No duplicates among ${_duplicateSearchFiles.length} scanned files.'),
        ],
        if (_duplicateGroups.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._duplicateGroups.entries.map((e) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Duplicate Match Group', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
                  const SizedBox(height: 6),
                  ...e.value.map((f) => Text('• ${f.name} (${(f.sizeBytes / 1024).toStringAsFixed(1)} KB)', style: const TextStyle(fontSize: 12))),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  /// Label/value line whose value wraps, so long MIME types fit narrow screens and large fonts.
  Widget _infoRow(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontFamily: mono ? 'monospace' : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'File Inspector',
          primaryResult: _metadataTargetFile != null ? _metadataTargetFile!.name : 'Select a File',
          subtitle: 'Inspects headers, extension, size, and MIME classification',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.search_rounded),
          label: const Text('Pick File to Inspect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickMetadataFile,
        ),
        if (_metadataTargetFile != null) ...[
          const SizedBox(height: 16),
          _infoRow('File Size', '${(_metadataTargetFile!.sizeBytes / 1024).toStringAsFixed(2)} KB (${_metadataTargetFile!.sizeBytes} bytes)'),
          _infoRow('MIME Type', _mimeType),
          _infoRow('Extension', _metadataTargetFile!.extension),
          _infoRow('Magic Header (Hex)', _magicHeader.isEmpty ? '(empty file)' : _magicHeader, mono: true),
        ],
      ],
    );
  }

  Widget _buildCsvJsonTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_downward_rounded),
                label: const Text('CSV ➔ JSON'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.catPdf, foregroundColor: Colors.white),
                onPressed: _convertCsvToJson,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_upward_rounded),
                label: const Text('JSON ➔ CSV'),
                onPressed: _convertJsonToCsv,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'CSV Data',
          controller: _csvInputController,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'JSON Data',
          controller: _jsonInputController,
          maxLines: 7,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy JSON'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _jsonInputController.text));
                  _showToast('JSON copied!');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Export JSON'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.catPdf, foregroundColor: Colors.white),
                onPressed: () => _shareBytes(utf8.encode(_jsonInputController.text), 'Data.json'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
