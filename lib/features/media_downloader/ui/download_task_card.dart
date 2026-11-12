import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/media_downloader_models.dart';

/// Card displaying a queued, active, paused, completed, or failed download task.
class DownloadTaskCard extends StatelessWidget {
  final DownloadRecord record;
  final DownloadRuntimeStats runtimeStats;
  final VoidCallback? onPause;
  final VoidCallback? onResumeOrRetry;
  final VoidCallback? onCancel;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;
  final VoidCallback? onDetails;
  final VoidCallback? onRemoveFromHistory;

  const DownloadTaskCard({
    super.key,
    required this.record,
    required this.runtimeStats,
    this.onPause,
    this.onResumeOrRetry,
    this.onCancel,
    this.onOpen,
    this.onShare,
    this.onDetails,
    this.onRemoveFromHistory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(record.status);
    final progress = record.progress;
    final percentText =
        progress != null ? '${(progress * 100).toStringAsFixed(0)}%' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              record.status == DownloadStatus.downloading
                  ? AppColors.primaryOrange.withValues(alpha: 0.45)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: record.mediaCategory.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  record.mediaCategory.icon,
                  color: record.mediaCategory.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MiniBadge(
                          label: record.status.label,
                          color: statusColor,
                        ),
                        if (record.selectedQuality != null)
                          _MiniBadge(
                            label: record.selectedQuality!.label,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                            neutral: true,
                          ),
                        Text(
                          record.sourceName,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (record.status == DownloadStatus.downloading ||
              record.status == DownloadStatus.paused ||
              record.status == DownloadStatus.queued) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child:
                  progress == null && record.status == DownloadStatus.downloading
                      ? const LinearProgressIndicator(minHeight: 7)
                      : TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: progress ?? 0),
                        duration: const Duration(milliseconds: 180),
                        builder: (context, animatedValue, _) {
                          return LinearProgressIndicator(
                            value: animatedValue,
                            minHeight: 7,
                            backgroundColor:
                                isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightBg,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              statusColor,
                            ),
                          );
                        },
                      ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              children: [
                if (percentText != null)
                  Text(
                    percentText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                Text(
                  record.totalBytes != null
                      ? '${formatBytes(record.downloadedBytes)} / ${formatBytes(record.totalBytes!)}'
                      : formatBytes(record.downloadedBytes),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                  ),
                ),
                if (record.status == DownloadStatus.downloading &&
                    runtimeStats.bytesPerSecond > 0)
                  Text(
                    formatSpeed(runtimeStats.bytesPerSecond),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                    ),
                  ),
                if (record.status == DownloadStatus.downloading &&
                    runtimeStats.etaSeconds != null)
                  Text(
                    '~${formatEta(runtimeStats.etaSeconds!)} left',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                    ),
                  ),
              ],
            ),
          ] else if (record.status == DownloadStatus.completed) ...[
            const SizedBox(height: 8),
            Text(
              '${formatBytes(record.totalBytes ?? record.downloadedBytes)} • ${record.mediaCategory.label}',
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
          ],
          if (record.errorMessage != null &&
              record.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                record.errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _buildActions(context, isDark),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, bool isDark) {
    final actions = <Widget>[];
    switch (record.status) {
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
        if (onPause != null) {
          actions.add(
            _ActionChipButton(
              icon: Icons.pause_rounded,
              label: record.supportsResume ? 'Pause' : 'Pause (Restart)',
              onPressed: onPause!,
              isDark: isDark,
            ),
          );
        }
        if (onCancel != null) {
          actions.add(
            _ActionChipButton(
              icon: Icons.close_rounded,
              label: 'Cancel',
              color: AppColors.error,
              onPressed: onCancel!,
              isDark: isDark,
            ),
          );
        }
        break;
      case DownloadStatus.paused:
        if (onResumeOrRetry != null) {
          actions.add(
            _ActionChipButton(
              icon: Icons.play_arrow_rounded,
              label: 'Resume',
              color: AppColors.primaryOrange,
              onPressed: onResumeOrRetry!,
              isDark: isDark,
            ),
          );
        }
        if (onCancel != null) {
          actions.add(
            _ActionChipButton(
              icon: Icons.close_rounded,
              label: 'Cancel',
              color: AppColors.error,
              onPressed: onCancel!,
              isDark: isDark,
            ),
          );
        }
        break;
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        if (onResumeOrRetry != null) {
          actions.add(
            _ActionChipButton(
              icon: Icons.refresh_rounded,
              label: 'Retry',
              color: AppColors.primaryOrange,
              onPressed: onResumeOrRetry!,
              isDark: isDark,
            ),
          );
        }
        if (onRemoveFromHistory != null) {
          actions.add(
            _ActionChipButton(
              icon: Icons.delete_outline_rounded,
              label: 'Remove',
              onPressed: onRemoveFromHistory!,
              isDark: isDark,
            ),
          );
        }
        break;
      case DownloadStatus.completed:
        if (onOpen != null) {
          actions.add(
            _ActionChipButton(
              icon: Icons.open_in_new_rounded,
              label: 'Open',
              color: AppColors.primaryOrange,
              onPressed: onOpen!,
              isDark: isDark,
            ),
          );
        }
        if (onShare != null) {
          actions.add(
            _ActionChipButton(
              icon: Icons.share_outlined,
              label: 'Share',
              onPressed: onShare!,
              isDark: isDark,
            ),
          );
        }
        if (onDetails != null) {
          actions.add(
            _ActionChipButton(
              icon: Icons.info_outline_rounded,
              label: 'Details',
              onPressed: onDetails!,
              isDark: isDark,
            ),
          );
        }
        if (onRemoveFromHistory != null) {
          actions.add(
            _ActionChipButton(
              icon: Icons.history_toggle_off_rounded,
              label: 'Clear Entry',
              onPressed: onRemoveFromHistory!,
              isDark: isDark,
            ),
          );
        }
        break;
    }
    return actions;
  }

  static Color _statusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
        return AppColors.info;
      case DownloadStatus.downloading:
        return AppColors.primaryOrange;
      case DownloadStatus.paused:
        return AppColors.warning;
      case DownloadStatus.completed:
        return AppColors.success;
      case DownloadStatus.failed:
        return AppColors.error;
      case DownloadStatus.cancelled:
        return AppColors.darkTextMuted;
    }
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool neutral;

  const _MiniBadge({
    required this.label,
    required this.color,
    this.neutral = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: neutral ? 0.1 : 0.14),
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

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onPressed;
  final bool isDark;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fg =
        color ??
        (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: fg),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(
          color:
              color?.withValues(alpha: 0.4) ??
              (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
