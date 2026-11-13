import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/tool_model.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feature_tab_selector.dart';
import '../../../shared/widgets/modern_text_field.dart';
import '../../../shared/widgets/tool_scaffold.dart';
import '../models/media_downloader_models.dart';
import '../services/download_manager_service.dart';
import '../services/url_security_validator.dart';
import 'download_task_card.dart';
import 'downloads_library_view.dart';

enum MediaDownloaderTab {
  downloader('Downloader', Icons.download_rounded),
  library('Downloads Library', Icons.folder_copy_rounded);

  final String label;
  final IconData icon;
  const MediaDownloaderTab(this.label, this.icon);
}

/// Phase 1 Media Downloader dashboard and local downloads library.
class MediaDownloaderScreen extends StatefulWidget {
  final DownloadManagerService? manager;
  final MediaDownloaderTab initialTab;

  const MediaDownloaderScreen({
    super.key,
    this.manager,
    this.initialTab = MediaDownloaderTab.downloader,
  });

  @override
  State<MediaDownloaderScreen> createState() => _MediaDownloaderScreenState();
}

class _MediaDownloaderScreenState extends State<MediaDownloaderScreen> {
  late final DownloadManagerService _manager;
  final TextEditingController _urlController = TextEditingController();

  late MediaDownloaderTab _activeTab;
  DownloadFilter _activeFilter = DownloadFilter.all;
  bool _isAnalyzing = false;
  UrlAnalysisResult? _analysis;
  MediaQualityOption? _selectedQuality;

  @override
  void initState() {
    super.initState();
    _manager = widget.manager ?? DownloadManagerService();
    _activeTab = widget.initialTab;
    _manager.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForMediaUrl();
    });
  }

  Future<void> _checkClipboardForMediaUrl() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty || _urlController.text.trim().isNotEmpty) return;
      final uri = Uri.tryParse(text);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.hasAuthority) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.link_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Link in clipboard (${uri.host})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Paste & Analyze',
              textColor: Colors.amberAccent,
              onPressed: () {
                _urlController.text = text;
                _urlController.selection = TextSelection.collapsed(offset: text.length);
                _analyzeUrl();
              },
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    PreferencesService().triggerHaptic();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _showSnack('Clipboard is empty.', isError: true);
      return;
    }
    _urlController.text = text;
    _urlController.selection = TextSelection.collapsed(offset: text.length);
    setState(() {
      _analysis = null;
      _selectedQuality = null;
    });
  }

  Future<void> _analyzeUrl() async {
    PreferencesService().triggerHaptic();
    FocusScope.of(context).unfocus();
    setState(() {
      _isAnalyzing = true;
      _analysis = null;
      _selectedQuality = null;
    });

    final result = await _manager.analyzeUrl(_urlController.text);
    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _analysis = result;
      _selectedQuality =
          result.qualityOptions.isNotEmpty ? result.qualityOptions.first : null;
    });
  }

  Future<void> _startDownload({bool allowDuplicate = false}) async {
    final analysis = _analysis;
    if (analysis == null || !analysis.canDownload) return;
    PreferencesService().triggerHaptic();

    final outcome = await _manager.startDownload(
      analysis: analysis,
      quality: _selectedQuality,
      allowDuplicate: allowDuplicate,
    );
    if (!mounted) return;

    switch (outcome.status) {
      case StartDownloadStatus.started:
        _showSnack('Download started: ${outcome.record!.fileName}');
        break;
      case StartDownloadStatus.alreadyActive:
        _showSnack(
          outcome.message ?? 'This download is already active.',
          isError: true,
        );
        break;
      case StartDownloadStatus.alreadyCompleted:
        final dup = outcome.record;
        final downloadAgain = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Already Downloaded'),
                content: Text(
                  '"${dup?.fileName ?? 'This file'}" is already in your Downloads Library. '
                  'Would you like to open the existing file or download another copy?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop(false);
                      setState(() => _activeTab = MediaDownloaderTab.library);
                    },
                    child: const Text('View in Library'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Download Again'),
                  ),
                ],
              ),
        );
        if (!mounted) return;
        if (downloadAgain == true) {
          await _startDownload(allowDuplicate: true);
        }
        break;
      case StartDownloadStatus.rejected:
        _showSnack(
          outcome.message ?? 'Download could not be started.',
          isError: true,
        );
        break;
    }
  }

  Future<void> _openExternalUrl(String url) async {
    PreferencesService().triggerHaptic();
    final ok = await _manager.storage.openExternalUrl(url);
    if (!ok && mounted) {
      _showSnack('Could not open external link in browser.', isError: true);
    }
  }

  Future<void> _showSettingsSheet() async {
    PreferencesService().triggerHaptic();
    final dir = await _manager.storage.getDownloadsDirectory();
    final caps = _manager.storage.describeCurrentPlatform();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => AnimatedBuilder(
            animation: _manager,
            builder: (context, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Downloader Settings & Platform Info',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Max Concurrent Downloads',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${_manager.maxConcurrentDownloads}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _manager.maxConcurrentDownloads.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '${_manager.maxConcurrentDownloads}',
                          activeColor: AppColors.primaryOrange,
                          onChanged:
                              (v) => _manager.setMaxConcurrentDownloads(
                                v.round(),
                              ),
                        ),
                        const SizedBox(height: 8),
                        _PlatformInfoTile(
                          title: 'Storage Directory (${caps.platformName})',
                          body: '${caps.storageLocationSummary}\n${dir.path}',
                        ),
                        const SizedBox(height: 8),
                        _PlatformInfoTile(
                          title: 'Background & Resume Behavior',
                          body: caps.backgroundBehaviorNote,
                        ),
                        const SizedBox(height: 8),
                        _PlatformInfoTile(
                          title: 'File Access & Sharing',
                          body: caps.fileAccessNote,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
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

  List<DownloadRecord> _filteredRecords(List<DownloadRecord> all) {
    switch (_activeFilter) {
      case DownloadFilter.all:
        return all;
      case DownloadFilter.active:
        return all.where((r) => r.status.isActive).toList();
      case DownloadFilter.completed:
        return all
            .where((r) => r.status == DownloadStatus.completed)
            .toList();
      case DownloadFilter.failed:
        return all
            .where(
              (r) =>
                  r.status == DownloadStatus.failed ||
                  r.status == DownloadStatus.cancelled,
            )
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Media Downloader',
      category: ToolCategory.media,
      toolId: 'media_downloader',
      isScrollable: false,
      padding: EdgeInsets.zero,
      actions: [
        IconButton(
          tooltip: 'Downloader Settings',
          icon: Icon(
            Icons.tune_rounded,
            color:
                isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
          ),
          onPressed: _showSettingsSheet,
        ),
      ],
      body: AnimatedBuilder(
        animation: _manager,
        builder: (context, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: FeatureTabSelector<MediaDownloaderTab>(
                  tabs:
                      MediaDownloaderTab.values
                          .map(
                            (t) => FeatureTabItem(
                              value: t,
                              label:
                                  t == MediaDownloaderTab.library
                                      ? '${t.label} (${_manager.completedFiles.length})'
                                      : t.label,
                              icon: t.icon,
                            ),
                          )
                          .toList(),
                  activeTab: _activeTab,
                  onTabSelected: (t) => setState(() => _activeTab = t),
                  accentColor: AppColors.primaryOrange,
                  title: 'Media Downloader Views',
                ),
              ),
              Expanded(
                child:
                    _activeTab == MediaDownloaderTab.downloader
                        ? _buildDownloaderDashboard(context, isDark)
                        : DownloadsLibraryView(manager: _manager),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDownloaderDashboard(BuildContext context, bool isDark) {
    final all = _manager.records;
    final activeCount = all.where((r) => r.status.isActive).length;
    final completedCount =
        all.where((r) => r.status == DownloadStatus.completed).length;
    final failedCount =
        all
            .where(
              (r) =>
                  r.status == DownloadStatus.failed ||
                  r.status == DownloadStatus.cancelled,
            )
            .length;
    final filtered = _filteredRecords(all);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      physics: const BouncingScrollPhysics(),
      children: [
        // URL Input Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModernTextField(
                label: 'Media or File URL',
                hintText: 'YouTube, Instagram, or direct media URL',
                controller: _urlController,
                prefixIcon: Icons.link_rounded,
                keyboardType: TextInputType.url,
                onChanged: (_) {
                  if (_analysis != null) {
                    setState(() {
                      _analysis = null;
                      _selectedQuality = null;
                    });
                  } else {
                    setState(() {});
                  }
                },
                suffix:
                    _urlController.text.isNotEmpty
                        ? IconButton(
                          tooltip: 'Clear URL',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _urlController.clear();
                            setState(() {
                              _analysis = null;
                              _selectedQuality = null;
                            });
                          },
                        )
                        : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded, size: 17),
                    label: const Text('Paste URL'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isAnalyzing ? null : _analyzeUrl,
                      icon:
                          _isAnalyzing
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.search_rounded, size: 18),
                      label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze URL'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (_analysis != null) ...[
          const SizedBox(height: 12),
          _buildAnalysisCard(context, isDark, _analysis!),
        ],

        const SizedBox(height: 12),

        // Downloaded Files Shortcut + Stats Row
        InkWell(
          onTap: () {
            PreferencesService().triggerHaptic();
            setState(() => _activeTab = MediaDownloaderTab.library);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryOrange.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.folder_special_rounded,
                    color: AppColors.primaryOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Downloaded Files Library',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_manager.completedFiles.length} saved files • '
                        '${formatBytes(_manager.totalDownloadedStorageBytes)}',
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
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.primaryOrange,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Filter Chips + Clear History
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'All (${all.length})',
                      selected: _activeFilter == DownloadFilter.all,
                      onTap:
                          () => setState(() => _activeFilter = DownloadFilter.all),
                    ),
                    _FilterPill(
                      label: 'Active ($activeCount)',
                      selected: _activeFilter == DownloadFilter.active,
                      onTap:
                          () => setState(
                            () => _activeFilter = DownloadFilter.active,
                          ),
                    ),
                    _FilterPill(
                      label: 'Completed ($completedCount)',
                      selected: _activeFilter == DownloadFilter.completed,
                      onTap:
                          () => setState(
                            () => _activeFilter = DownloadFilter.completed,
                          ),
                    ),
                    _FilterPill(
                      label: 'Failed ($failedCount)',
                      selected: _activeFilter == DownloadFilter.failed,
                      onTap:
                          () => setState(
                            () => _activeFilter = DownloadFilter.failed,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (all.any((r) => r.status.isTerminal))
              TextButton(
                onPressed: _manager.clearFinishedHistory,
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (filtered.isEmpty)
          _EmptyDownloadsState(filter: _activeFilter)
        else
          for (final record in filtered)
            DownloadTaskCard(
              record: record,
              runtimeStats: _manager.runtimeStatsFor(record.id),
              onPause: () => _manager.pauseDownload(record.id),
              onResumeOrRetry: () => _manager.resumeOrRetryDownload(record.id),
              onCancel: () => _manager.cancelDownload(record.id),
              onOpen: () async {
                final err = await _manager.storage.openLocalFile(
                  record.filePath,
                );
                if (err != null) _showSnack(err, isError: true);
              },
              onShare: () async {
                final err = await _manager.storage.shareLocalFile(
                  record.filePath,
                  text: record.fileName,
                );
                if (err != null) _showSnack(err, isError: true);
              },
              onDetails: () => setState(() => _activeTab = MediaDownloaderTab.library),
              onRemoveFromHistory:
                  () => _manager.removeHistoryRecord(record.id),
            ),
      ],
    );
  }

  Widget _buildAnalysisCard(
    BuildContext context,
    bool isDark,
    UrlAnalysisResult analysis,
  ) {
    final accent = analysis.canDownload ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (analysis.thumbnailUrl != null &&
                  analysis.thumbnailUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      analysis.thumbnailUrl!,
                      width: 68,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, _, _) => _AnalysisIconTile(analysis: analysis),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _AnalysisIconTile(analysis: analysis),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      analysis.title.isNotEmpty
                          ? analysis.title
                          : analysis.sourceName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _TagChip(label: analysis.sourceName, color: accent),
                        if (analysis.canDownload) ...[
                          _TagChip(
                            label:
                                (_selectedQuality?.format.isNotEmpty ?? false)
                                    ? _selectedQuality!.format.toUpperCase()
                                    : (analysis.extension.isNotEmpty
                                        ? analysis.extension.toUpperCase()
                                        : analysis.mediaCategory.label),
                            color: analysis.mediaCategory.color,
                          ),
                          _TagChip(
                            label:
                                (_selectedQuality?.fileSizeBytes ??
                                            analysis.fileSizeBytes) !=
                                        null
                                    ? formatBytes(
                                      (_selectedQuality?.fileSizeBytes ??
                                          analysis.fileSizeBytes)!,
                                    )
                                    : 'Size unknown',
                            color: AppColors.info,
                          ),
                          _TagChip(
                            label:
                                (_selectedQuality?.supportsResume ??
                                        analysis.supportsResume)
                                    ? 'Resumable'
                                    : 'Single stream',
                            color:
                                (_selectedQuality?.supportsResume ??
                                        analysis.supportsResume)
                                    ? AppColors.success
                                    : AppColors.darkTextMuted,
                          ),
                        ],
                      ],
                    ),
                    if (analysis.author != null &&
                        analysis.author!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'By ${analysis.author}',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (analysis.canDownload) ...[
            const SizedBox(height: 12),
            Text(
              'Available Format & Quality',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final option in analysis.qualityOptions)
                  ChoiceChip(
                    label: Text(option.subtitleSummary),
                    selected: _selectedQuality?.id == option.id,
                    onSelected:
                        (_) => setState(() => _selectedQuality = option),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _startDownload(),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.errorMessage ??
                        'This URL cannot be downloaded directly.',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                    ),
                  ),
                  if (analysis.isPlatformRestricted) ...[
                    const SizedBox(height: 8),
                    Text(
                      UrlSecurityValidator.redactUrlForLog(
                        analysis.originalUrl,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openExternalUrl(analysis.originalUrl),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 17),
                      label: const Text('Open Original Link'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalysisIconTile extends StatelessWidget {
  final UrlAnalysisResult analysis;
  const _AnalysisIconTile({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final color =
        analysis.canDownload ? analysis.mediaCategory.color : AppColors.warning;
    final icon =
        analysis.canDownload
            ? analysis.mediaCategory.icon
            : (analysis.isPlatformRestricted
                ? Icons.public_rounded
                : Icons.error_outline_rounded);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        showCheckmark: false,
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primaryOrange,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? Colors.white : null,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _EmptyDownloadsState extends StatelessWidget {
  final DownloadFilter filter;
  const _EmptyDownloadsState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
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
            Icons.cloud_download_outlined,
            size: 42,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(height: 10),
          Text(
            filter == DownloadFilter.all
                ? 'No downloads yet'
                : 'No ${filter.label.toLowerCase()} downloads',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Paste a YouTube, Instagram, or direct media URL above and tap Analyze URL to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
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

class _PlatformInfoTile extends StatelessWidget {
  final String title;
  final String body;
  const _PlatformInfoTile({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightCardHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            body,
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
    );
  }
}
