import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/media_downloader_models.dart';
import '../services/download_manager_service.dart';
import '../services/url_security_validator.dart';

/// Local Downloads Library with category filtering, search, sorting, storage
/// metrics, in-app previews, rename, share, open, and confirmed deletion.
class DownloadsLibraryView extends StatefulWidget {
  final DownloadManagerService manager;

  const DownloadsLibraryView({super.key, required this.manager});

  @override
  State<DownloadsLibraryView> createState() => _DownloadsLibraryViewState();
}

class _DownloadsLibraryViewState extends State<DownloadsLibraryView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MediaLibraryCategory? _selectedCategory; // null = All
  LibrarySortBy _sortBy = LibrarySortBy.dateDesc;
  int? _freeSpaceBytes;

  @override
  void initState() {
    super.initState();
    _refreshFreeSpace();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFreeSpace() async {
    try {
      final dir = await widget.manager.storage.getDownloadsDirectory();
      final free = await widget.manager.storage.getAvailableFreeSpaceBytes(
        dir.path,
      );
      if (mounted) {
        setState(() => _freeSpaceBytes = free);
      }
    } catch (_) {}
  }

  List<DownloadRecord> _filteredAndSorted(List<DownloadRecord> allCompleted) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered =
        allCompleted.where((r) {
          if (_selectedCategory != null && r.mediaCategory != _selectedCategory) {
            return false;
          }
          if (query.isEmpty) return true;
          return r.fileName.toLowerCase().contains(query) ||
              r.title.toLowerCase().contains(query) ||
              r.mimeType.toLowerCase().contains(query) ||
              r.originalUrl.toLowerCase().contains(query);
        }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case LibrarySortBy.dateDesc:
          return (b.completedAt ?? b.createdAt).compareTo(
            a.completedAt ?? a.createdAt,
          );
        case LibrarySortBy.dateAsc:
          return (a.completedAt ?? a.createdAt).compareTo(
            b.completedAt ?? b.createdAt,
          );
        case LibrarySortBy.nameAsc:
          return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
        case LibrarySortBy.nameDesc:
          return b.fileName.toLowerCase().compareTo(a.fileName.toLowerCase());
        case LibrarySortBy.sizeDesc:
          return (b.totalBytes ?? b.downloadedBytes).compareTo(
            a.totalBytes ?? a.downloadedBytes,
          );
        case LibrarySortBy.sizeAsc:
          return (a.totalBytes ?? a.downloadedBytes).compareTo(
            b.totalBytes ?? b.downloadedBytes,
          );
      }
    });
    return filtered;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openFile(DownloadRecord record) async {
    PreferencesService().triggerHaptic();
    final err = await widget.manager.storage.openLocalFile(record.filePath);
    if (err != null) _showSnack(err, isError: true);
  }

  Future<void> _shareFile(DownloadRecord record) async {
    PreferencesService().triggerHaptic();
    final err = await widget.manager.storage.shareLocalFile(
      record.filePath,
      text: record.fileName,
    );
    if (err != null) _showSnack(err, isError: true);
  }

  Future<void> _exportCopy(DownloadRecord record) async {
    PreferencesService().triggerHaptic();
    final err = await widget.manager.storage.exportCopyToUserFolder(
      sourcePath: record.filePath,
      fileName: record.fileName,
    );
    if (err != null) {
      _showSnack(err, isError: err != 'Export cancelled.');
    } else {
      _showSnack('Exported copy of ${record.fileName}');
    }
  }

  Future<void> _promptRename(DownloadRecord record) async {
    final controller = TextEditingController(text: record.fileName);
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Rename File'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'File name',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text('Rename'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (result == null || result.isEmpty || result == record.fileName) return;

    final err = await widget.manager.renameDownloadedFile(record.id, result);
    if (err != null) {
      _showSnack(err, isError: true);
    } else {
      _showSnack('Renamed file successfully.');
    }
  }

  Future<void> _confirmDelete(DownloadRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Downloaded File?'),
            content: Text(
              'Permanently delete "${record.fileName}" from local storage? '
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final err = await widget.manager.deleteDownloadedFile(record.id);
    if (err != null) {
      _showSnack(err, isError: true);
    } else {
      _showSnack('Deleted "${record.fileName}".');
      unawaited(_refreshFreeSpace());
    }
  }

  Future<void> _showPreview(DownloadRecord record) async {
    PreferencesService().triggerHaptic();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _FilePreviewSheet(
            record: record,
            onOpen: () {
              Navigator.of(ctx).pop();
              _openFile(record);
            },
            onShare: () {
              Navigator.of(ctx).pop();
              _shareFile(record);
            },
            onVerify: () => widget.manager.verifyFileIntegrity(record.id),
          ),
    );
  }

  Future<void> _showDetails(DownloadRecord record) async {
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => _FileDetailsDialog(
            record: record,
            onVerify: () => widget.manager.verifyFileIntegrity(record.id),
            onOpenUrl: () async {
              await widget.manager.storage.openExternalUrl(record.originalUrl);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = widget.manager.completedFiles;
    final visible = _filteredAndSorted(completed);
    final totalUsed = widget.manager.totalDownloadedStorageBytes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // Storage Usage Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.sd_storage_rounded,
                      size: 20,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatBytes(totalUsed)} used across ${completed.length} ${completed.length == 1 ? 'file' : 'files'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          _freeSpaceBytes != null
                              ? 'Device free space: ${formatBytes(_freeSpaceBytes!)}'
                              : 'Stored in app-managed local downloads folder',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (completed.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cat in MediaLibraryCategory.values)
                      if (completed.any((r) => r.mediaCategory == cat))
                        _StorageCategoryPill(
                          category: cat,
                          count:
                              completed
                                  .where((r) => r.mediaCategory == cat)
                                  .length,
                        ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search & Sort row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search downloads...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                          : null,
                  isDense: true,
                  filled: true,
                  fillColor:
                      isDark ? AppColors.darkCard : AppColors.lightSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<LibrarySortBy>(
              tooltip: 'Sort downloads',
              initialValue: _sortBy,
              onSelected: (v) => setState(() => _sortBy = v),
              itemBuilder:
                  (ctx) => [
                    for (final s in LibrarySortBy.values)
                      PopupMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            if (s == _sortBy)
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppColors.primaryOrange,
                              )
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            Text(s.label),
                          ],
                        ),
                      ),
                  ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort_rounded, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'Sort',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Category chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('All (${completed.length})'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
              ),
              for (final cat in MediaLibraryCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(cat.icon, size: 16, color: cat.color),
                    label: Text(
                      '${cat.label} (${completed.where((r) => r.mediaCategory == cat).length})',
                    ),
                    selected: _selectedCategory == cat,
                    onSelected:
                        (_) => setState(
                          () =>
                              _selectedCategory =
                                  _selectedCategory == cat ? null : cat,
                        ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (visible.isEmpty)
          _EmptyLibraryState(hasAnyDownloads: completed.isNotEmpty)
        else
          for (final record in visible)
            _LibraryFileCard(
              record: record,
              onPreview: () => _showPreview(record),
              onOpen: () => _openFile(record),
              onShare: () => _shareFile(record),
              onExportCopy: () => _exportCopy(record),
              onRename: () => _promptRename(record),
              onDetails: () => _showDetails(record),
              onDelete: () => _confirmDelete(record),
            ),
      ],
    );
  }
}

class _StorageCategoryPill extends StatelessWidget {
  final MediaLibraryCategory category;
  final int count;

  const _StorageCategoryPill({required this.category, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 13, color: category.color),
          const SizedBox(width: 4),
          Text(
            '${category.label}: $count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryFileCard extends StatelessWidget {
  final DownloadRecord record;
  final VoidCallback onPreview;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onExportCopy;
  final VoidCallback onRename;
  final VoidCallback onDetails;
  final VoidCallback onDelete;

  const _LibraryFileCard({
    required this.record,
    required this.onPreview,
    required this.onOpen,
    required this.onShare,
    required this.onExportCopy,
    required this.onRename,
    required this.onDetails,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exists =
        record.filePath.isNotEmpty && File(record.filePath).existsSync();
    final isImage = record.mediaCategory == MediaLibraryCategory.images && exists;
    final dateStr = DateFormat.yMMMd().add_jm().format(
      record.completedAt ?? record.createdAt,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onPreview,
                borderRadius: BorderRadius.circular(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: record.mediaCategory.color.withValues(alpha: 0.14),
                    child:
                        isImage
                            ? Image.file(
                              File(record.filePath),
                              fit: BoxFit.cover,
                              cacheWidth: 160,
                              errorBuilder:
                                  (_, _, _) => Icon(
                                    record.mediaCategory.icon,
                                    color: record.mediaCategory.color,
                                  ),
                            )
                            : Icon(
                              record.mediaCategory.icon,
                              color: record.mediaCategory.color,
                              size: 24,
                            ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onPreview,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatBytes(record.totalBytes ?? record.downloadedBytes)} • ${record.mediaCategory.label} • $dateStr',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                        ),
                      ),
                      if (!exists)
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Text(
                            'File not found on disk (moved or deleted externally)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More file actions',
                onSelected: (value) {
                  switch (value) {
                    case 'preview':
                      onPreview();
                      break;
                    case 'rename':
                      onRename();
                      break;
                    case 'export':
                      onExportCopy();
                      break;
                    case 'details':
                      onDetails();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder:
                    (ctx) => const [
                      PopupMenuItem(
                        value: 'preview',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.visibility_outlined),
                          title: Text('Preview'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rename',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.drive_file_rename_outline),
                          title: Text('Rename'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.save_alt_rounded),
                          title: Text('Save Copy As...'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'details',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.info_outline_rounded),
                          title: Text('Details & Checksum'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                          ),
                          title: Text(
                            'Delete',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: const Text('Preview', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: exists ? onOpen : null,
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('Open', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: exists ? onShare : null,
                icon: const Icon(Icons.share_outlined, size: 15),
                label: const Text('Share', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 15,
                  color: AppColors.error,
                ),
                label: const Text(
                  'Delete',
                  style: TextStyle(fontSize: 12, color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  final bool hasAnyDownloads;

  const _EmptyLibraryState({required this.hasAnyDownloads});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(
            hasAnyDownloads
                ? Icons.filter_list_off_rounded
                : Icons.folder_open_rounded,
            size: 44,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(height: 10),
          Text(
            hasAnyDownloads
                ? 'No files match your filter'
                : 'No downloaded files yet',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            hasAnyDownloads
                ? 'Try clearing your search query or switching category.'
                : 'Completed downloads from the Downloader tab will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePreviewSheet extends StatefulWidget {
  final DownloadRecord record;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final Future<FileIntegrityResult> Function() onVerify;

  const _FilePreviewSheet({
    required this.record,
    required this.onOpen,
    required this.onShare,
    required this.onVerify,
  });

  @override
  State<_FilePreviewSheet> createState() => _FilePreviewSheetState();
}

class _FilePreviewSheetState extends State<_FilePreviewSheet> {
  String? _textPreview;
  int? _pdfPageCount;
  String? _previewNote;
  FileIntegrityResult? _integrity;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final r = widget.record;
    final file = File(r.filePath);
    if (!await file.exists()) {
      if (mounted) {
        setState(() {
          _previewNote = 'File does not exist on disk.';
          _loading = false;
        });
      }
      return;
    }

    try {
      final ext = r.extension.toLowerCase();
      if (r.mediaCategory == MediaLibraryCategory.images) {
        // Image.file handles rendering directly.
      } else if (ext == 'pdf') {
        final len = await file.length();
        if (len <= 25 * 1024 * 1024) {
          final bytes = await file.readAsBytes();
          final doc = PdfDocument(inputBytes: bytes);
          _pdfPageCount = doc.pages.count;
          doc.dispose();
        } else {
          _previewNote = 'Large PDF (${formatBytes(len)}) — tap Open to view.';
        }
      } else if (const {
        'txt',
        'md',
        'csv',
        'json',
        'xml',
        'yaml',
        'yml',
        'log',
      }.contains(ext)) {
        const maxPreviewBytes = 64 * 1024;
        final builder = BytesBuilder(copy: false);
        await for (final chunk in file.openRead(0, maxPreviewBytes)) {
          builder.add(chunk);
        }
        _textPreview = utf8.decode(builder.takeBytes(), allowMalformed: true);
      } else {
        _previewNote =
            'In-app preview is not available for ${r.extension.toUpperCase()} files. '
            'Use Open to launch your device viewer.';
      }
    } catch (e) {
      _previewNote = 'Preview unavailable: $e';
    }

    _integrity = await widget.onVerify();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.record;
    final exists = File(r.filePath).existsSync();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    r.mediaCategory.icon,
                    color: r.mediaCategory.color,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (r.mediaCategory == MediaLibraryCategory.images && exists)
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      color: Colors.black12,
                      child: InteractiveViewer(
                        child: Image.file(
                          File(r.filePath),
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, _, _) => const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Could not render image preview.'),
                              ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (_textPreview != null)
                Flexible(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isDark ? AppColors.darkBg : AppColors.lightCardHover,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _textPreview!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightCardHover,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_pdfPageCount != null)
                        Text(
                          'PDF Document • $_pdfPageCount ${_pdfPageCount == 1 ? 'page' : 'pages'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      if (_previewNote != null) Text(_previewNote!),
                      if (_integrity != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _integrity!.isValid
                                  ? Icons.verified_rounded
                                  : Icons.warning_amber_rounded,
                              size: 16,
                              color:
                                  _integrity!.isValid
                                      ? AppColors.success
                                      : AppColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _integrity!.message,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: exists ? widget.onOpen : null,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Open'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: exists ? widget.onShare : null,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileDetailsDialog extends StatefulWidget {
  final DownloadRecord record;
  final Future<FileIntegrityResult> Function() onVerify;
  final VoidCallback onOpenUrl;

  const _FileDetailsDialog({
    required this.record,
    required this.onVerify,
    required this.onOpenUrl,
  });

  @override
  State<_FileDetailsDialog> createState() => _FileDetailsDialogState();
}

class _FileDetailsDialogState extends State<_FileDetailsDialog> {
  FileIntegrityResult? _result;
  bool _verifying = false;

  Future<void> _verify() async {
    setState(() => _verifying = true);
    final res = await widget.onVerify();
    if (mounted) {
      setState(() {
        _result = res;
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return AlertDialog(
      title: const Text('File Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('File Name', r.fileName),
            _DetailRow('Category', r.mediaCategory.label),
            _DetailRow('MIME Type', r.mimeType),
            _DetailRow(
              'Size',
              formatBytes(r.totalBytes ?? r.downloadedBytes),
            ),
            _DetailRow(
              'Downloaded',
              DateFormat.yMMMd().add_jm().format(r.completedAt ?? r.createdAt),
            ),
            _DetailRow(
              'Source',
              UrlSecurityValidator.redactUrlForLog(r.originalUrl),
            ),
            _DetailRow('Local Path', r.filePath),
            if (r.sha256 != null) _DetailRow('SHA-256', r.sha256!),
            const SizedBox(height: 8),
            if (_verifying)
              const LinearProgressIndicator()
            else if (_result != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_result!.isValid
                          ? AppColors.success
                          : AppColors.error)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _result!.message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        _result!.isValid ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onOpenUrl,
          child: const Text('Open Link'),
        ),
        TextButton(
          onPressed: _verifying ? null : _verify,
          child: const Text('Verify Integrity'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          SelectableText(value, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }
}
