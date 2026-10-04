import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

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

  PickedFileItem({
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.bytes,
    this.path,
  });
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
  final TextEditingController _zipNameController = TextEditingController(text: 'Archive');
  bool _isCreatingZip = false;

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

  // 6. Duplicate Finder State
  final List<PickedFileItem> _duplicateSearchFiles = [];
  Map<String, List<PickedFileItem>> _duplicateGroups = {};

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

  Future<List<PickedFileItem>> _pickMultipleFiles() async {
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        final List<PickedFileItem> items = [];
        for (final f in files) {
          final bytes = await f.readAsBytes();
          items.add(
            PickedFileItem(
              name: f.name,
              extension: f.extension?.toUpperCase() ?? 'FILE',
              sizeBytes: bytes.length,
              bytes: bytes,
              path: f.path,
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

  Future<PickedFileItem?> _pickSingleGenericFile({List<String>? allowedExtensions}) async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        return PickedFileItem(
          name: file.name,
          extension: file.extension?.toUpperCase() ?? 'FILE',
          sizeBytes: bytes.length,
          bytes: bytes,
          path: file.path,
        );
      }
    } catch (e) {
      _showToast('Error picking file: $e');
    }
    return null;
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
    if (picked.isNotEmpty) {
      setState(() => _zipFiles.addAll(picked));
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
      final archive = Archive();
      for (final item in _zipFiles) {
        final file = ArchiveFile(item.name, item.bytes.length, item.bytes);
        archive.addFile(file);
      }

      final zipData = ZipEncoder().encode(archive);
      final name = _zipNameController.text.trim().isEmpty ? 'Archive' : _zipNameController.text.trim();
      await Printing.sharePdf(
        bytes: Uint8List.fromList(zipData),
        filename: '${name.replaceAll(' ', '_')}.zip',
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
    if (file != null) {
      setState(() {
        _selectedZipFile = file;
        _extractedFiles.clear();
        _isExtracting = true;
      });

      try {
        final archive = ZipDecoder().decodeBytes(file.bytes);
        setState(() {
          _extractedFiles.addAll(archive.files);
        });
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
    if (picked.isNotEmpty) {
      setState(() => _renameFiles.addAll(picked));
    }
  }

  String _computeRenamedName(String origName, int index) {
    var nameWithoutExt = origName;
    var ext = '';
    if (origName.contains('.')) {
      final lastDot = origName.lastIndexOf('.');
      nameWithoutExt = origName.substring(0, lastDot);
      ext = origName.substring(lastDot);
    }

    var result = nameWithoutExt;

    // Find and replace
    final find = _renameFindController.text;
    final replace = _renameReplaceController.text;
    if (find.isNotEmpty) {
      result = result.replaceAll(find, replace);
    }

    // Prefix & Suffix
    final prefix = _renamePrefixController.text;
    final suffix = _renameSuffixController.text;
    result = '$prefix$result$suffix';

    // Numbering
    if (_addNumbering) {
      final numStr = (index + 1).toString().padLeft(3, '0');
      result = '${result}_$numStr';
    }

    // Case formatting
    if (_renameCaseMode == 'lowercase') {
      result = result.toLowerCase();
    } else if (_renameCaseMode == 'UPPERCASE') {
      result = result.toUpperCase();
    } else if (_renameCaseMode == 'Title Case') {
      result = result.split('_').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}' : '').join('_');
    }

    return '$result$ext';
  }

  Future<void> _exportRenamedZip() async {
    if (_renameFiles.isEmpty) return;
    try {
      final archive = Archive();
      for (int i = 0; i < _renameFiles.length; i++) {
        final item = _renameFiles[i];
        final newName = _computeRenamedName(item.name, i);
        archive.addFile(ArchiveFile(newName, item.bytes.length, item.bytes));
      }
      final zipData = ZipEncoder().encode(archive);
      await Printing.sharePdf(
        bytes: Uint8List.fromList(zipData),
        filename: 'Renamed_Files.zip',
      );
    } catch (e) {
      _showToast('Error exporting renamed files: $e');
    }
  }

  // --- TAB 4: SIZE ANALYZER ---
  Future<void> _addFilesToAnalyze() async {
    final picked = await _pickMultipleFiles();
    if (picked.isNotEmpty) {
      setState(() => _analyzedFiles.addAll(picked));
    }
  }

  // --- TAB 5: HASH CALCULATOR ---
  Future<void> _pickHashFile() async {
    final file = await _pickSingleGenericFile();
    if (file != null) {
      final md5Val = md5.convert(file.bytes).toString();
      final sha1Val = sha1.convert(file.bytes).toString();
      final sha256Val = sha256.convert(file.bytes).toString();
      final sha512Val = sha512.convert(file.bytes).toString();

      setState(() {
        _hashTargetFile = file;
        _md5Hash = md5Val;
        _sha1Hash = sha1Val;
        _sha256Hash = sha256Val;
        _sha512Hash = sha512Val;
        _hashMatchResult = null;
      });
    }
  }

  void _verifyHash(String target) {
    if (_hashTargetFile == null || target.trim().isEmpty) {
      setState(() => _hashMatchResult = null);
      return;
    }
    final clean = target.trim().toLowerCase();
    final match = clean == _md5Hash || clean == _sha1Hash || clean == _sha256Hash || clean == _sha512Hash;
    setState(() => _hashMatchResult = match);
  }

  // --- TAB 6: DUPLICATE FINDER ---
  Future<void> _pickDuplicateFiles() async {
    final picked = await _pickMultipleFiles();
    if (picked.isNotEmpty) {
      setState(() => _duplicateSearchFiles.addAll(picked));
      _computeDuplicates();
    }
  }

  void _computeDuplicates() {
    final Map<String, List<PickedFileItem>> hashGroups = {};
    for (final file in _duplicateSearchFiles) {
      final hash = sha256.convert(file.bytes).toString();
      hashGroups.putIfAbsent(hash, () => []).add(file);
    }
    final duplicatesOnly = Map<String, List<PickedFileItem>>.fromEntries(
      hashGroups.entries.where((e) => e.value.length > 1),
    );
    setState(() => _duplicateGroups = duplicatesOnly);
  }

  // --- TAB 7: METADATA ---
  Future<void> _pickMetadataFile() async {
    final file = await _pickSingleGenericFile();
    if (file != null) {
      String mime = 'application/octet-stream';
      String header = '';

      final ext = file.extension.toUpperCase();
      if (ext == 'PNG') mime = 'image/png';
      if (ext == 'JPG' || ext == 'JPEG') mime = 'image/jpeg';
      if (ext == 'PDF') mime = 'application/pdf';
      if (ext == 'ZIP') mime = 'application/zip';
      if (ext == 'CSV') mime = 'text/csv';
      if (ext == 'JSON') mime = 'application/json';
      if (ext == 'TXT') mime = 'text/plain';

      if (file.bytes.isNotEmpty) {
        final headBytes = file.bytes.take(8).toList();
        header = headBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      }

      setState(() {
        _metadataTargetFile = file;
        _mimeType = mime;
        _magicHeader = header;
      });
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
      final decoded = jsonDecode(raw);

      if (decoded is List) {
        final List<List<dynamic>> rows = [];
        final Set<String> keys = {};
        for (final item in decoded) {
          if (item is Map) {
            keys.addAll(item.keys.map((k) => k.toString()));
          }
        }

        final headerList = keys.toList();
        rows.add(headerList);

        for (final item in decoded) {
          if (item is Map) {
            final row = headerList.map((k) => item[k] ?? '').toList();
            rows.add(row);
          }
        }

        final csvString = csv.encode(rows);
        setState(() {
          _csvInputController.text = csvString;
        });
      }
    } catch (e) {
      _showToast('JSON parse error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'File & ZIP Suite',
      category: ToolCategory.filesText,
      toolId: 'file_zip_toolkit',
      onReset: () {
        setState(() {
          _zipFiles.clear();
          _selectedZipFile = null;
          _extractedFiles.clear();
          _renameFiles.clear();
          _analyzedFiles.clear();
          _hashTargetFile = null;
          _duplicateSearchFiles.clear();
          _duplicateGroups.clear();
          _metadataTargetFile = null;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: FileZipTab.values.map((tab) {
                final isSelected = tab == _activeTab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    avatar: Icon(tab.icon, size: 16, color: isSelected ? Colors.white : AppColors.catPdf),
                    label: Text(tab.label),
                    selected: isSelected,
                    selectedColor: AppColors.catPdf,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _activeTab = tab);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
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
    final totalSizeKb = _zipFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes) / 1024;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'ZIP Archiver',
          primaryResult: '${_zipFiles.length} Files Selected',
          subtitle: 'Uncompressed Total: ${totalSizeKb.toStringAsFixed(1)} KB',
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
                onPressed: () => setState(() => _zipFiles.clear()),
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
                  onPressed: () => setState(() => _zipFiles.removeAt(idx)),
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
            itemCount: _extractedFiles.length,
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
                subtitle: Text('${(file.size / 1024).toStringAsFixed(1)} KB'),
                trailing: IconButton(
                  icon: const Icon(Icons.share_rounded, size: 18),
                  onPressed: () {
                    final rawBytes = file.content as List<int>;
                    Printing.sharePdf(bytes: Uint8List.fromList(rawBytes), filename: file.name);
                  },
                ),
              );
            },
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
            value: _renameCaseMode,
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
              label: const Text('Export Renamed Files as ZIP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _exportRenamedZip,
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
          onPressed: _pickHashFile,
        ),
        if (_hashTargetFile != null) ...[
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
          onPressed: _pickDuplicateFiles,
        ),
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
          ListTile(
            title: const Text('File Size'),
            trailing: Text('${(_metadataTargetFile!.sizeBytes / 1024).toStringAsFixed(2)} KB (${_metadataTargetFile!.sizeBytes} bytes)'),
          ),
          ListTile(
            title: const Text('MIME Type'),
            trailing: Text(_mimeType),
          ),
          ListTile(
            title: const Text('Extension'),
            trailing: Text(_metadataTargetFile!.extension),
          ),
          ListTile(
            title: const Text('Magic Header (Hex)'),
            subtitle: Text(_magicHeader, style: const TextStyle(fontFamily: 'monospace')),
          ),
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
                onPressed: () {
                  final bytes = Uint8List.fromList(utf8.encode(_jsonInputController.text));
                  Printing.sharePdf(bytes: bytes, filename: 'Data.json');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
