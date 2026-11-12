import 'package:flutter/material.dart';

/// Current lifecycle status of a managed download task.
enum DownloadStatus {
  queued('Queued'),
  downloading('Downloading'),
  paused('Paused'),
  completed('Completed'),
  failed('Failed'),
  cancelled('Cancelled');

  final String label;
  const DownloadStatus(this.label);

  bool get isActive =>
      this == DownloadStatus.queued ||
      this == DownloadStatus.downloading ||
      this == DownloadStatus.paused;

  bool get isTerminal =>
      this == DownloadStatus.completed ||
      this == DownloadStatus.failed ||
      this == DownloadStatus.cancelled;
}

/// Filter tabs for the downloader dashboard list.
enum DownloadFilter {
  all('All'),
  active('Active'),
  completed('Completed'),
  failed('Failed');

  final String label;
  const DownloadFilter(this.label);
}

/// Logical library categories for downloaded files.
enum MediaLibraryCategory {
  videos('Videos', Icons.video_library_rounded, Color(0xFF9333EA)),
  audio('Audio', Icons.audiotrack_rounded, Color(0xFF0891B2)),
  images('Images', Icons.image_rounded, Color(0xFFDB2777)),
  documents('Documents', Icons.description_rounded, Color(0xFFDC2626)),
  archives('Archives', Icons.folder_zip_rounded, Color(0xFF65A30D)),
  other('Other files', Icons.insert_drive_file_rounded, Color(0xFF475569));

  final String label;
  final IconData icon;
  final Color color;
  const MediaLibraryCategory(this.label, this.icon, this.color);

  static const Set<String> _videoExts = {
    'mp4',
    'webm',
    'mkv',
    'mov',
    'avi',
    'm4v',
    '3gp',
    'flv',
    'wmv',
    'ts',
  };

  static const Set<String> _audioExts = {
    'mp3',
    'm4a',
    'wav',
    'aac',
    'ogg',
    'flac',
    'opus',
    'wma',
    'oga',
  };

  static const Set<String> _imageExts = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'svg',
    'ico',
    'heic',
    'avif',
  };

  static const Set<String> _documentExts = {
    'pdf',
    'txt',
    'md',
    'csv',
    'json',
    'xml',
    'yaml',
    'yml',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'rtf',
    'epub',
    'odt',
    'ods',
  };

  static const Set<String> _archiveExts = {
    'zip',
    'tar',
    'gz',
    'tgz',
    '7z',
    'rar',
    'bz2',
    'xz',
    'zst',
  };

  /// Classifies a file into a library category using MIME type and extension.
  static MediaLibraryCategory classify({
    required String fileName,
    String mimeType = '',
  }) {
    final mime = mimeType.toLowerCase().split(';').first.trim();
    final dot = fileName.lastIndexOf('.');
    final ext =
        dot >= 0 && dot < fileName.length - 1
            ? fileName.substring(dot + 1).toLowerCase()
            : '';

    if (_videoExts.contains(ext) || mime.startsWith('video/')) {
      return MediaLibraryCategory.videos;
    }
    if (_audioExts.contains(ext) || mime.startsWith('audio/')) {
      return MediaLibraryCategory.audio;
    }
    if (_imageExts.contains(ext) || mime.startsWith('image/')) {
      return MediaLibraryCategory.images;
    }
    if (_archiveExts.contains(ext) ||
        mime == 'application/zip' ||
        mime == 'application/x-tar' ||
        mime == 'application/gzip' ||
        mime == 'application/x-7z-compressed' ||
        mime == 'application/vnd.rar') {
      return MediaLibraryCategory.archives;
    }
    if (_documentExts.contains(ext) ||
        mime == 'application/pdf' ||
        mime.startsWith('text/') ||
        mime == 'application/json' ||
        mime == 'application/xml' ||
        mime.contains('officedocument') ||
        mime.contains('msword') ||
        mime.contains('spreadsheet') ||
        mime.contains('presentation')) {
      return MediaLibraryCategory.documents;
    }
    return MediaLibraryCategory.other;
  }
}

/// Sort options for the local downloads library.
enum LibrarySortBy {
  dateDesc('Newest first'),
  dateAsc('Oldest first'),
  nameAsc('Name (A–Z)'),
  nameDesc('Name (Z–A)'),
  sizeDesc('Largest first'),
  sizeAsc('Smallest first');

  final String label;
  const LibrarySortBy(this.label);
}

/// A real downloadable stream/file variant exposed by a source adapter.
class MediaQualityOption {
  final String id;
  final String label;
  final String format;
  final String? resolution;
  final String? codec;
  final int? bitrateKbps;
  final int? fileSizeBytes;
  final String downloadUrl;
  final bool isOriginal;
  final bool supportsResume;
  final String mimeType;

  const MediaQualityOption({
    required this.id,
    required this.label,
    required this.format,
    required this.downloadUrl,
    this.resolution,
    this.codec,
    this.bitrateKbps,
    this.fileSizeBytes,
    this.isOriginal = true,
    this.supportsResume = false,
    this.mimeType = 'application/octet-stream',
  });

  String get subtitleSummary {
    final parts = <String>[
      format.toUpperCase(),
      if (resolution != null && resolution!.isNotEmpty) resolution!,
      if (codec != null && codec!.isNotEmpty) codec!,
      if (bitrateKbps != null && bitrateKbps! > 0) '$bitrateKbps kbps',
      if (fileSizeBytes != null && fileSizeBytes! > 0)
        formatBytes(fileSizeBytes!),
    ];
    return parts.join(' • ');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'format': format,
    'resolution': resolution,
    'codec': codec,
    'bitrateKbps': bitrateKbps,
    'fileSizeBytes': fileSizeBytes,
    'downloadUrl': downloadUrl,
    'isOriginal': isOriginal,
    'supportsResume': supportsResume,
    'mimeType': mimeType,
  };

  factory MediaQualityOption.fromJson(Map<String, dynamic> json) =>
      MediaQualityOption(
        id: json['id'] as String? ?? 'original',
        label: json['label'] as String? ?? 'Original',
        format: json['format'] as String? ?? '',
        resolution: json['resolution'] as String?,
        codec: json['codec'] as String?,
        bitrateKbps: json['bitrateKbps'] as int?,
        fileSizeBytes: json['fileSizeBytes'] as int?,
        downloadUrl: json['downloadUrl'] as String? ?? '',
        isOriginal: json['isOriginal'] as bool? ?? true,
        supportsResume: json['supportsResume'] as bool? ?? false,
        mimeType:
            json['mimeType'] as String? ?? 'application/octet-stream',
      );
}

/// Result returned by a source adapter after analyzing a user-supplied URL.
class UrlAnalysisResult {
  final bool isValidUrl;
  final bool isSupported;
  final bool canDownload;
  final bool isPlatformRestricted;
  final String sourceId;
  final String sourceName;
  final String originalUrl;
  final String? resolvedUrl;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final String fileName;
  final String mimeType;
  final String extension;
  final MediaLibraryCategory mediaCategory;
  final int? fileSizeBytes;
  final bool supportsResume;
  final String? etag;
  final String? lastModified;
  final List<MediaQualityOption> qualityOptions;
  final String? limitationReason;
  final String? errorMessage;

  const UrlAnalysisResult({
    required this.isValidUrl,
    required this.isSupported,
    required this.canDownload,
    this.isPlatformRestricted = false,
    required this.sourceId,
    required this.sourceName,
    required this.originalUrl,
    this.resolvedUrl,
    required this.title,
    this.author,
    this.thumbnailUrl,
    required this.fileName,
    required this.mimeType,
    required this.extension,
    required this.mediaCategory,
    this.fileSizeBytes,
    this.supportsResume = false,
    this.etag,
    this.lastModified,
    this.qualityOptions = const [],
    this.limitationReason,
    this.errorMessage,
  });

  factory UrlAnalysisResult.failure({
    required String originalUrl,
    required String errorMessage,
    bool isValidUrl = true,
    bool isSupported = false,
    bool isPlatformRestricted = false,
    String sourceId = 'unknown',
    String sourceName = 'Unsupported Source',
    String? title,
    String? author,
    String? thumbnailUrl,
  }) {
    return UrlAnalysisResult(
      isValidUrl: isValidUrl,
      isSupported: isSupported,
      canDownload: false,
      isPlatformRestricted: isPlatformRestricted,
      sourceId: sourceId,
      sourceName: sourceName,
      originalUrl: originalUrl,
      title: title ?? sourceName,
      author: author,
      thumbnailUrl: thumbnailUrl,
      fileName: '',
      mimeType: 'application/octet-stream',
      extension: '',
      mediaCategory: MediaLibraryCategory.other,
      limitationReason: isPlatformRestricted ? errorMessage : null,
      errorMessage: errorMessage,
    );
  }
}

/// Persistent download record stored in SharedPreferences.
class DownloadRecord {
  final String id;
  final String originalUrl;
  final String downloadUrl;
  final String title;
  final String fileName;
  final String filePath;
  final String tempFilePath;
  final String mimeType;
  final String extension;
  final MediaLibraryCategory mediaCategory;
  final int? totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final MediaQualityOption? selectedQuality;
  final List<MediaQualityOption> availableQualities;
  final bool supportsResume;
  final String? etag;
  final String? lastModified;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final String sourceName;
  final String? thumbnailUrl;
  final String? sha256;

  const DownloadRecord({
    required this.id,
    required this.originalUrl,
    required this.downloadUrl,
    required this.title,
    required this.fileName,
    required this.filePath,
    required this.tempFilePath,
    required this.mimeType,
    required this.extension,
    required this.mediaCategory,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.status,
    this.selectedQuality,
    this.availableQualities = const [],
    this.supportsResume = false,
    this.etag,
    this.lastModified,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
    this.sourceName = 'Direct Media',
    this.thumbnailUrl,
    this.sha256,
  });

  double? get progress {
    if (status == DownloadStatus.completed) return 1.0;
    if (totalBytes == null || totalBytes! <= 0) return null;
    return (downloadedBytes / totalBytes!).clamp(0.0, 1.0);
  }

  DownloadRecord copyWith({
    String? downloadUrl,
    String? title,
    String? fileName,
    String? filePath,
    String? tempFilePath,
    String? mimeType,
    String? extension,
    MediaLibraryCategory? mediaCategory,
    int? totalBytes,
    bool clearTotalBytes = false,
    int? downloadedBytes,
    DownloadStatus? status,
    MediaQualityOption? selectedQuality,
    List<MediaQualityOption>? availableQualities,
    bool? supportsResume,
    String? etag,
    String? lastModified,
    DateTime? completedAt,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? sourceName,
    String? thumbnailUrl,
    String? sha256,
  }) {
    return DownloadRecord(
      id: id,
      originalUrl: originalUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      tempFilePath: tempFilePath ?? this.tempFilePath,
      mimeType: mimeType ?? this.mimeType,
      extension: extension ?? this.extension,
      mediaCategory: mediaCategory ?? this.mediaCategory,
      totalBytes: clearTotalBytes ? null : (totalBytes ?? this.totalBytes),
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      selectedQuality: selectedQuality ?? this.selectedQuality,
      availableQualities: availableQualities ?? this.availableQualities,
      supportsResume: supportsResume ?? this.supportsResume,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      sourceName: sourceName ?? this.sourceName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      sha256: sha256 ?? this.sha256,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalUrl': originalUrl,
    'downloadUrl': downloadUrl,
    'title': title,
    'fileName': fileName,
    'filePath': filePath,
    'tempFilePath': tempFilePath,
    'mimeType': mimeType,
    'extension': extension,
    'mediaCategory': mediaCategory.name,
    'totalBytes': totalBytes,
    'downloadedBytes': downloadedBytes,
    'status': status.name,
    'selectedQuality': selectedQuality?.toJson(),
    'availableQualities': availableQualities.map((q) => q.toJson()).toList(),
    'supportsResume': supportsResume,
    'etag': etag,
    'lastModified': lastModified,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'errorMessage': errorMessage,
    'sourceName': sourceName,
    'thumbnailUrl': thumbnailUrl,
    'sha256': sha256,
  };

  factory DownloadRecord.fromJson(Map<String, dynamic> json) {
    final categoryName = json['mediaCategory'] as String? ?? 'other';
    final category = MediaLibraryCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => MediaLibraryCategory.other,
    );
    final statusName = json['status'] as String? ?? 'failed';
    final status = DownloadStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => DownloadStatus.failed,
    );
    final selectedJson = json['selectedQuality'];
    final qualitiesRaw = json['availableQualities'] as List<dynamic>? ?? const [];

    return DownloadRecord(
      id: json['id'] as String? ?? '',
      originalUrl: json['originalUrl'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      title: json['title'] as String? ?? json['fileName'] as String? ?? 'Download',
      fileName: json['fileName'] as String? ?? 'file',
      filePath: json['filePath'] as String? ?? '',
      tempFilePath: json['tempFilePath'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      extension: json['extension'] as String? ?? '',
      mediaCategory: category,
      totalBytes: json['totalBytes'] as int?,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      status: status,
      selectedQuality:
          selectedJson is Map<String, dynamic>
              ? MediaQualityOption.fromJson(selectedJson)
              : null,
      availableQualities: [
        for (final q in qualitiesRaw)
          if (q is Map<String, dynamic>) MediaQualityOption.fromJson(q),
      ],
      supportsResume: json['supportsResume'] as bool? ?? false,
      etag: json['etag'] as String?,
      lastModified: json['lastModified'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt:
          json['completedAt'] != null
              ? DateTime.tryParse(json['completedAt'] as String)
              : null,
      errorMessage: json['errorMessage'] as String?,
      sourceName: json['sourceName'] as String? ?? 'Direct Media',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      sha256: json['sha256'] as String?,
    );
  }
}

/// Live transient transfer metrics for an active download.
class DownloadRuntimeStats {
  final double bytesPerSecond;
  final int? etaSeconds;

  const DownloadRuntimeStats({
    this.bytesPerSecond = 0,
    this.etaSeconds,
  });
}

/// Formats byte counts into readable B, KB, MB, GB strings.
String formatBytes(int bytes) {
  if (bytes < 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Formats transfer rate in bytes/sec.
String formatSpeed(double bytesPerSecond) {
  if (bytesPerSecond <= 0 || !bytesPerSecond.isFinite) return '0 B/s';
  if (bytesPerSecond < 1024) return '${bytesPerSecond.round()} B/s';
  if (bytesPerSecond < 1024 * 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
  }
  return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
}

/// Formats remaining seconds as `45s`, `3m 12s`, or `1h 05m`.
String formatEta(int seconds) {
  if (seconds < 0) return '--';
  if (seconds < 60) return '${seconds}s';
  final mins = seconds ~/ 60;
  final secs = seconds % 60;
  if (mins < 60) return '${mins}m ${secs.toString().padLeft(2, '0')}s';
  final hrs = mins ~/ 60;
  final remMins = mins % 60;
  return '${hrs}h ${remMins.toString().padLeft(2, '0')}m';
}
