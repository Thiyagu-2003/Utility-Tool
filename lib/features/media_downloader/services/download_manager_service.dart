import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../file_tools/file_zip_utils.dart';
import '../adapters/media_source_adapter.dart';
import '../models/media_downloader_models.dart';
import '../../../core/services/notification_service.dart';
import 'mp4_audio_extractor.dart';
import 'platform_storage_service.dart';
import 'url_security_validator.dart';

/// Outcome returned when attempting to enqueue a new download.
enum StartDownloadStatus {
  started,
  alreadyActive,
  alreadyCompleted,
  rejected,
}

class StartDownloadOutcome {
  final StartDownloadStatus status;
  final DownloadRecord? record;
  final String? message;

  const StartDownloadOutcome({
    required this.status,
    this.record,
    this.message,
  });
}

class _ActiveTaskControl {
  final http.Client client;
  bool paused = false;
  bool cancelled = false;
  Completer<void> finished = Completer<void>();

  _ActiveTaskControl(this.client);
}

/// Manages URL analysis, concurrent download queuing, HTTP Range pause/resume,
/// streaming disk writes, integrity hashing, and persistent history.
class DownloadManagerService extends ChangeNotifier {
  static final DownloadManagerService _instance =
      DownloadManagerService._internal();
  factory DownloadManagerService() => _instance;

  DownloadManagerService._internal()
      : _clientFactory = http.Client.new,
        _storage = PlatformStorageService(),
        _adapterRegistry = SourceAdapterRegistry();

  /// Isolated constructor for unit and integration tests.
  @visibleForTesting
  DownloadManagerService.isolated({
    http.Client Function()? clientFactory,
    PlatformStorageService? storage,
    SourceAdapterRegistry? adapterRegistry,
  })  : _clientFactory = clientFactory ?? http.Client.new,
        _storage = storage ?? PlatformStorageService(),
        _adapterRegistry = adapterRegistry ?? SourceAdapterRegistry();

  static const String _keyRecords = 'media_downloader_records_v1';
  static const String _keyMaxConcurrent = 'media_downloader_max_concurrent_v1';
  static const Duration _chunkReadTimeout = Duration(seconds: 30);

  final http.Client Function() _clientFactory;
  final PlatformStorageService _storage;
  final SourceAdapterRegistry _adapterRegistry;

  bool _initialized = false;
  int _maxConcurrentDownloads = 2;
  final List<DownloadRecord> _records = [];
  final Map<String, _ActiveTaskControl> _activeTasks = {};
  final Map<String, DownloadRuntimeStats> _runtimeStats = {};
  final Map<String, DateTime> _lastUiNotify = {};

  bool get isInitialized => _initialized;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  List<DownloadRecord> get records => List.unmodifiable(_records);
  PlatformStorageService get storage => _storage;

  List<DownloadRecord> get completedFiles => _records
      .where((r) => r.status == DownloadStatus.completed)
      .toList();

  int get activeCount =>
      _records.where((r) => r.status.isActive).length;

  int get runningCount =>
      _records.where((r) => r.status == DownloadStatus.downloading).length;

  int get totalDownloadedStorageBytes => completedFiles.fold<int>(
        0,
        (sum, r) => sum + (r.totalBytes ?? r.downloadedBytes),
      );

  DownloadRuntimeStats runtimeStatsFor(String id) =>
      _runtimeStats[id] ?? const DownloadRuntimeStats();

  /// Initializes state from [SharedPreferences] and recovers any interrupted
  /// tasks from a previous app session.
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    _maxConcurrentDownloads =
        (prefs.getInt(_keyMaxConcurrent) ?? 2).clamp(1, 5);

    final rawList = prefs.getStringList(_keyRecords) ?? const [];
    _records.clear();
    var mutated = false;

    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw);
        if (map is! Map<String, dynamic>) continue;
        var record = DownloadRecord.fromJson(map);
        if (record.id.isEmpty) continue;

        if (record.status == DownloadStatus.downloading ||
            record.status == DownloadStatus.queued) {
          mutated = true;
          final partFile = File(record.tempFilePath);
          final partExists =
              record.tempFilePath.isNotEmpty && await partFile.exists();
          final partBytes = partExists ? await partFile.length() : 0;

          if (record.supportsResume && partExists && partBytes > 0) {
            record = record.copyWith(
              status: DownloadStatus.paused,
              downloadedBytes: partBytes,
              errorMessage: 'Paused when app closed. Tap Resume to continue.',
            );
          } else {
            record = record.copyWith(
              status: DownloadStatus.failed,
              errorMessage: 'Download interrupted when app closed.',
            );
          }
        }
        _records.add(record);
      } catch (_) {}
    }

    _initialized = true;
    if (mutated) {
      await _persistRecords();
    }
    notifyListeners();
  }

  /// Updates the concurrent download limit (1..5) and triggers queued items.
  Future<void> setMaxConcurrentDownloads(int value) async {
    final clamped = value.clamp(1, 5);
    if (clamped == _maxConcurrentDownloads) return;
    _maxConcurrentDownloads = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMaxConcurrent, clamped);
    notifyListeners();
    unawaited(_processQueue());
  }

  /// Validates and analyzes [rawUrl] using the registered source adapters.
  Future<UrlAnalysisResult> analyzeUrl(String rawUrl) async {
    final validation = UrlSecurityValidator.validate(rawUrl);
    if (!validation.isValid || validation.uri == null) {
      return UrlAnalysisResult.failure(
        originalUrl: rawUrl.trim(),
        isValidUrl: false,
        errorMessage: validation.errorMessage ?? 'Invalid URL.',
      );
    }

    final client = _clientFactory();
    try {
      return await _adapterRegistry.analyze(validation.uri!, client: client);
    } finally {
      client.close();
    }
  }

  /// Checks whether [downloadUrl] + [qualityId] already exists in active or
  /// completed downloads.
  DownloadRecord? findDuplicate(String downloadUrl, String qualityId) {
    for (final r in _records) {
      final sameUrl = r.downloadUrl == downloadUrl || r.originalUrl == downloadUrl;
      final sameQuality = (r.selectedQuality?.id ?? 'original') == qualityId;
      if (!sameUrl || !sameQuality) continue;
      if (r.status.isActive) return r;
      if (r.status == DownloadStatus.completed &&
          r.filePath.isNotEmpty &&
          File(r.filePath).existsSync()) {
        return r;
      }
    }
    return null;
  }

  /// Enqueues a download from an analyzed URL and selected [quality].
  Future<StartDownloadOutcome> startDownload({
    required UrlAnalysisResult analysis,
    MediaQualityOption? quality,
    bool allowDuplicate = false,
  }) async {
    if (!_initialized) await init();

    if (!analysis.canDownload) {
      return StartDownloadOutcome(
        status: StartDownloadStatus.rejected,
        message:
            analysis.errorMessage ?? 'This URL cannot be downloaded directly.',
      );
    }

    final chosen =
        quality ??
        (analysis.qualityOptions.isNotEmpty
            ? analysis.qualityOptions.first
            : null);

    if (chosen == null || chosen.downloadUrl.isEmpty) {
      return const StartDownloadOutcome(
        status: StartDownloadStatus.rejected,
        message: 'No valid downloadable stream or file option is available.',
      );
    }

    final urlCheck = UrlSecurityValidator.validate(chosen.downloadUrl);
    if (!urlCheck.isValid) {
      return StartDownloadOutcome(
        status: StartDownloadStatus.rejected,
        message: urlCheck.errorMessage ?? 'Invalid download URL.',
      );
    }

    if (!allowDuplicate) {
      final dup = findDuplicate(chosen.downloadUrl, chosen.id);
      if (dup != null) {
        if (dup.status.isActive) {
          return StartDownloadOutcome(
            status: StartDownloadStatus.alreadyActive,
            record: dup,
            message: 'This file is already in your active download queue.',
          );
        }
        return StartDownloadOutcome(
          status: StartDownloadStatus.alreadyCompleted,
          record: dup,
          message: 'This file has already been downloaded.',
        );
      }
    }

    final dir = await _storage.getDownloadsDirectory();
    final expectedTotal = chosen.fileSizeBytes ?? analysis.fileSizeBytes;
    if (expectedTotal != null && expectedTotal > 0) {
      final freeBytes = await _storage.getAvailableFreeSpaceBytes(dir.path);
      if (freeBytes != null && expectedTotal > freeBytes) {
        return StartDownloadOutcome(
          status: StartDownloadStatus.rejected,
          message:
              'Insufficient storage space. Required ${formatBytes(expectedTotal)}, '
              'available ${formatBytes(freeBytes)}.',
        );
      }
    }

    final baseName = _buildSafeFileName(
      preferredName: analysis.fileName,
      quality: chosen,
      fallbackUri: urlCheck.uri!,
    );
    if (UrlSecurityValidator.isBlockedExecutable(
      baseName,
      mimeType: chosen.mimeType,
    )) {
      return const StartDownloadOutcome(
        status: StartDownloadStatus.rejected,
        message: 'Blocked executable file type for security.',
      );
    }

    final uniqueName = await _allocateUniqueFileName(dir, baseName);
    final finalPath = '${dir.path}${Platform.pathSeparator}$uniqueName';
    final id = _generateId();
    final tempPath =
        '${dir.path}${Platform.pathSeparator}.$id.$uniqueName.part';
    final ext = UrlSecurityValidator.extractExtension(uniqueName);
    final category = MediaLibraryCategory.classify(
      fileName: uniqueName,
      mimeType: chosen.mimeType,
    );

    final record = DownloadRecord(
      id: id,
      originalUrl: analysis.originalUrl,
      downloadUrl: chosen.downloadUrl,
      title: analysis.title.isNotEmpty ? analysis.title : uniqueName,
      fileName: uniqueName,
      filePath: finalPath,
      tempFilePath: tempPath,
      mimeType: chosen.mimeType,
      extension: ext,
      mediaCategory: category,
      totalBytes: expectedTotal,
      downloadedBytes: 0,
      status: DownloadStatus.queued,
      selectedQuality: chosen,
      availableQualities: analysis.qualityOptions,
      supportsResume: chosen.supportsResume || analysis.supportsResume,
      etag: analysis.etag,
      lastModified: analysis.lastModified,
      createdAt: DateTime.now(),
      sourceName: analysis.sourceName,
      thumbnailUrl: analysis.thumbnailUrl,
    );

    _records.insert(0, record);
    await _persistRecords();
    notifyListeners();

    unawaited(_processQueue());
    return StartDownloadOutcome(
      status: StartDownloadStatus.started,
      record: record,
    );
  }

  /// Pauses a queued or active download, keeping partial data when supported.
  Future<void> pauseDownload(String id) async {
    final idx = _indexOf(id);
    if (idx == -1) return;
    final record = _records[idx];

    if (record.status == DownloadStatus.queued) {
      _records[idx] = record.copyWith(
        status: DownloadStatus.paused,
        clearErrorMessage: true,
      );
      await _persistRecords();
      notifyListeners();
      return;
    }

    if (record.status == DownloadStatus.downloading) {
      final task = _activeTasks[id];
      if (task != null) {
        task.paused = true;
        task.client.close();
        await task.finished.future.catchError((_) {});
      }
    }
  }

  /// Resumes a paused download or retries a failed download.
  Future<void> resumeOrRetryDownload(String id) async {
    final idx = _indexOf(id);
    if (idx == -1) return;
    final record = _records[idx];
    if (record.status != DownloadStatus.paused &&
        record.status != DownloadStatus.failed &&
        record.status != DownloadStatus.cancelled) {
      return;
    }

    _records[idx] = record.copyWith(
      status: DownloadStatus.queued,
      clearErrorMessage: true,
    );
    await _persistRecords();
    notifyListeners();
    unawaited(_processQueue());
  }

  /// Cancels an active or queued download and removes its temporary `.part` file.
  Future<void> cancelDownload(String id) async {
    final idx = _indexOf(id);
    if (idx == -1) return;
    final record = _records[idx];

    final task = _activeTasks[id];
    if (task != null) {
      task.cancelled = true;
      task.client.close();
      await task.finished.future.catchError((_) {});
      return;
    }

    await _deleteTempFile(record.tempFilePath);
    _runtimeStats.remove(id);
    _records[idx] = record.copyWith(
      status: DownloadStatus.cancelled,
      downloadedBytes: 0,
      errorMessage: 'Cancelled by user.',
    );
    await _persistRecords();
    notifyListeners();
    unawaited(_processQueue());
  }

  /// Removes a history entry from the list without deleting any completed
  /// file on disk.
  Future<void> removeHistoryRecord(String id) async {
    final idx = _indexOf(id);
    if (idx == -1) return;
    final record = _records[idx];
    if (record.status == DownloadStatus.downloading) {
      await cancelDownload(id);
    } else if (record.status != DownloadStatus.completed) {
      await _deleteTempFile(record.tempFilePath);
    }
    _records.removeWhere((r) => r.id == id);
    _runtimeStats.remove(id);
    await _persistRecords();
    notifyListeners();
  }

  /// Clears terminal (completed/failed/cancelled) entries from the dashboard
  /// history list without touching downloaded files on disk.
  Future<void> clearFinishedHistory() async {
    final toRemove = _records.where((r) => r.status.isTerminal).toList();
    for (final r in toRemove) {
      if (r.status != DownloadStatus.completed) {
        await _deleteTempFile(r.tempFilePath);
      }
      _runtimeStats.remove(r.id);
    }
    _records.removeWhere((r) => r.status.isTerminal);
    await _persistRecords();
    notifyListeners();
  }

  /// Renames a downloaded file on disk safely and updates its record.
  Future<String?> renameDownloadedFile(String id, String rawNewName) async {
    final idx = _indexOf(id);
    if (idx == -1) return 'Download record not found.';
    final record = _records[idx];
    final file = File(record.filePath);
    if (!await file.exists()) {
      return 'File no longer exists on disk.';
    }

    var safe = FileZipUtils.safeFileName(rawNewName, fallback: '');
    if (safe.isEmpty) return 'Please enter a valid file name.';

    if (UrlSecurityValidator.extractExtension(safe).isEmpty &&
        record.extension.isNotEmpty) {
      safe = '$safe.${record.extension}';
    }

    if (UrlSecurityValidator.isBlockedExecutable(safe)) {
      return 'Executable extensions are not permitted.';
    }

    final parent = file.parent;
    final targetPath = '${parent.path}${Platform.pathSeparator}$safe';
    if (targetPath != record.filePath && await File(targetPath).exists()) {
      return 'A file named "$safe" already exists.';
    }

    try {
      if (targetPath != record.filePath) {
        await file.rename(targetPath);
      }
      final newExt = UrlSecurityValidator.extractExtension(safe);
      _records[idx] = record.copyWith(
        fileName: safe,
        title: safe,
        filePath: targetPath,
        extension: newExt,
        mediaCategory: MediaLibraryCategory.classify(
          fileName: safe,
          mimeType: record.mimeType,
        ),
      );
      await _persistRecords();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Rename failed: $e';
    }
  }

  /// Deletes a downloaded file from disk and removes its record.
  Future<String?> deleteDownloadedFile(String id) async {
    final idx = _indexOf(id);
    if (idx == -1) return 'Download record not found.';
    final record = _records[idx];

    try {
      if (record.filePath.isNotEmpty) {
        final f = File(record.filePath);
        if (await f.exists()) {
          await f.delete();
        }
      }
      await _deleteTempFile(record.tempFilePath);
      _records.removeAt(idx);
      _runtimeStats.remove(id);
      await _persistRecords();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to delete file: $e';
    }
  }

  /// Verifies file existence, byte length, and SHA-256 checksum on disk.
  Future<FileIntegrityResult> verifyFileIntegrity(String id) async {
    final idx = _indexOf(id);
    if (idx == -1) {
      return const FileIntegrityResult(
        exists: false,
        matchesExpectedSize: false,
        matchesRecordedHash: false,
        message: 'Record not found.',
      );
    }
    final record = _records[idx];
    final file = File(record.filePath);
    if (!await file.exists()) {
      return const FileIntegrityResult(
        exists: false,
        matchesExpectedSize: false,
        matchesRecordedHash: false,
        message: 'File is missing from disk.',
      );
    }

    final actualSize = await file.length();
    final sizeMatches =
        record.totalBytes == null ||
        record.totalBytes! <= 0 ||
        actualSize == record.totalBytes;

    final hashes = await FileZipUtils.hashFileInBackground(
      record.filePath,
      const ['sha256'],
    );
    final sha256 = hashes['sha256'] ?? '';
    final hashMatches = record.sha256 == null || record.sha256 == sha256;

    return FileIntegrityResult(
      exists: true,
      actualBytes: actualSize,
      sha256: sha256,
      matchesExpectedSize: sizeMatches,
      matchesRecordedHash: hashMatches,
      message:
          sizeMatches && hashMatches
              ? 'File integrity verified (SHA-256 matches).'
              : 'File size or checksum differs from the recorded download.',
    );
  }

  Future<void> _processQueue() async {
    while (_activeTasks.length < _maxConcurrentDownloads) {
      // Pick oldest queued item (list is newest-first).
      final nextIdx = _records.lastIndexWhere(
        (r) => r.status == DownloadStatus.queued,
      );
      if (nextIdx == -1) break;

      final record = _records[nextIdx];
      final client = _clientFactory();
      final control = _ActiveTaskControl(client);
      _activeTasks[record.id] = control;
      _records[nextIdx] = record.copyWith(
        status: DownloadStatus.downloading,
        clearErrorMessage: true,
      );
      _runtimeStats[record.id] = const DownloadRuntimeStats();
      await _persistRecords();
      notifyListeners();

      unawaited(_executeDownload(record.id, control));
    }
  }

  Future<void> _executeDownload(String id, _ActiveTaskControl control) async {
    RandomAccessFile? raf;
    try {
      final initialIdx = _indexOf(id);
      if (initialIdx == -1) return;
      var record = _records[initialIdx];

      final uriCheck = UrlSecurityValidator.validate(record.downloadUrl);
      if (!uriCheck.isValid || uriCheck.uri == null) {
        throw FormatException(
          uriCheck.errorMessage ?? 'Invalid download URL.',
        );
      }

      final partFile = File(record.tempFilePath);
      if (!await partFile.parent.exists()) {
        await partFile.parent.create(recursive: true);
      }

      var existingBytes = 0;
      if (record.supportsResume && await partFile.exists()) {
        existingBytes = await partFile.length();
      } else if (await partFile.exists()) {
        await partFile.delete();
      }

      // Check free space before opening connection if expected size is known.
      if (record.totalBytes != null && record.totalBytes! > existingBytes) {
        final remaining = record.totalBytes! - existingBytes;
        final freeBytes = await _storage.getAvailableFreeSpaceBytes(
          partFile.parent.path,
        );
        if (freeBytes != null && remaining > freeBytes) {
          throw FileSystemException(
            'Insufficient storage space: need ${formatBytes(remaining)}, '
            'only ${formatBytes(freeBytes)} free.',
            partFile.path,
            const OSError('No space left on device', 28),
          );
        }
      }

      var downloadUri = uriCheck.uri!;
      final customHeaders =
          record.selectedQuality?.headers ?? const <String, String>{};
      final chunkSize = record.selectedQuality?.chunkSizeBytes;
      final isChunkedRangeMode =
          chunkSize != null &&
          chunkSize > 0 &&
          record.totalBytes != null &&
          record.totalBytes! > 0;

      if (isChunkedRangeMode) {
        final expectedTotal = record.totalBytes!;
        if (existingBytes >= expectedTotal) {
          await _finalizeCompletedDownload(id, partFile, existingBytes);
          return;
        }

        raf = await partFile.open(
          mode: existingBytes > 0 ? FileMode.writeOnlyAppend : FileMode.writeOnly,
        );

        var currentBytes = existingBytes;
        var windowBytes = 0;
        var windowStart = DateTime.now();
        var smoothedSpeed = 0.0;
        var refreshedUrl = false;

        while (currentBytes < expectedTotal &&
            !control.cancelled &&
            !control.paused) {
          final endByte = (currentBytes + chunkSize - 1).clamp(
            currentBytes,
            expectedTotal - 1,
          );
          final chunkHeaders = <String, String>{...customHeaders};
          var requestUri = downloadUri;
          if (downloadUri.host.contains('googlevideo.com') &&
              downloadUri.queryParameters['c'] != 'ANDROID') {
            final qp = Map<String, String>.from(downloadUri.queryParameters);
            qp['range'] = '$currentBytes-$endByte';
            requestUri = downloadUri.replace(queryParameters: qp);
          } else {
            chunkHeaders['Range'] = 'bytes=$currentBytes-$endByte';
          }

          final safeResp = await UrlSecurityValidator.sendWithSafeRedirects(
            client: control.client,
            method: 'GET',
            uri: requestUri,
            headers: chunkHeaders,
          );
          final response = safeResp.response;
          final statusCode = response.statusCode;

          if ((statusCode == 403 || statusCode == 410) &&
              !refreshedUrl &&
              record.originalUrl != record.downloadUrl) {
            await response.stream.drain<void>();
            refreshedUrl = true;
            final updated = await _tryRefreshSignedUrl(record);
            if (updated != null) {
              record = updated;
              downloadUri = Uri.parse(updated.downloadUrl);
              continue;
            }
          }

          if (statusCode < 200 || statusCode >= 300) {
            await response.stream.drain<void>();
            throw HttpException(
              'Server returned HTTP $statusCode',
              uri: safeResp.finalUri,
            );
          }

          final contentType =
              (response.headers['content-type'] ?? '')
                  .toLowerCase()
                  .split(';')
                  .first
                  .trim();
          if (contentType == 'text/html' ||
              contentType == 'application/xhtml+xml') {
            await response.stream.drain<void>();
            throw const FormatException(
              'Server returned an HTML web page instead of the requested media/file.',
            );
          }

          if (statusCode == 200 && currentBytes > 0) {
            // Server ignored Range and restarted from byte 0.
            await response.stream.drain<void>();
            throw const HttpException(
              'Server restarted stream instead of serving requested byte range.',
            );
          }

          final streamIterator = StreamIterator(
            response.stream.timeout(_chunkReadTimeout),
          );
          try {
            while (await streamIterator.moveNext()) {
              if (control.cancelled || control.paused) break;
              final chunk = streamIterator.current;
              if (chunk.isEmpty) continue;

              if (currentBytes + chunk.length >
                  UrlSecurityValidator.maxAllowedFileSizeBytes) {
                throw const FormatException(
                  'Download aborted: file exceeded maximum allowed size.',
                );
              }

              raf.writeFromSync(chunk);
              currentBytes += chunk.length;
              windowBytes += chunk.length;

              final now = DateTime.now();
              final elapsedMs = now.difference(windowStart).inMilliseconds;
              if (elapsedMs >= 400) {
                final instantSpeed = windowBytes / (elapsedMs / 1000.0);
                smoothedSpeed =
                    smoothedSpeed == 0
                        ? instantSpeed
                        : (smoothedSpeed * 0.65 + instantSpeed * 0.35);
                windowBytes = 0;
                windowStart = now;
              }

              int? eta;
              if (expectedTotal > currentBytes && smoothedSpeed > 0) {
                eta = ((expectedTotal - currentBytes) / smoothedSpeed).ceil();
              }

              _runtimeStats[id] = DownloadRuntimeStats(
                bytesPerSecond: smoothedSpeed,
                etaSeconds: eta,
              );
              _updateRecordThrottled(
                id,
                (r) => r.copyWith(downloadedBytes: currentBytes),
              );
            }
          } finally {
            await streamIterator.cancel().catchError((_) {});
          }

          if (statusCode == 200) {
            break;
          }
        }

        await raf.flush();
        await raf.close();
        raf = null;

        if (control.cancelled) {
          await _deleteTempFile(record.tempFilePath);
          _runtimeStats.remove(id);
          _updateRecord(
            id,
            (r) => r.copyWith(
              status: DownloadStatus.cancelled,
              downloadedBytes: 0,
              errorMessage: 'Cancelled by user.',
            ),
          );
          await _persistRecords();
          notifyListeners();
          return;
        }

        if (control.paused) {
          _runtimeStats.remove(id);
          _updateRecord(
            id,
            (r) => r.copyWith(
              status: DownloadStatus.paused,
              downloadedBytes: currentBytes,
              clearErrorMessage: true,
            ),
          );
          await _persistRecords();
          notifyListeners();
          return;
        }

        if (currentBytes != expectedTotal) {
          throw HttpException(
            'Incomplete transfer: received ${formatBytes(currentBytes)} of '
            '${formatBytes(expectedTotal)}.',
          );
        }

        await _finalizeCompletedDownload(id, partFile, currentBytes);
        return;
      }

      var refreshedUrl = false;
      late SafeHttpResponse safeResp;
      while (true) {
        final requestHeaders = <String, String>{...customHeaders};
        if (existingBytes > 0) {
          requestHeaders['Range'] = 'bytes=$existingBytes-';
        }

        safeResp = await UrlSecurityValidator.sendWithSafeRedirects(
          client: control.client,
          method: 'GET',
          uri: downloadUri,
          headers: requestHeaders,
        );
        final status = safeResp.response.statusCode;
        if ((status == 403 || status == 410) &&
            !refreshedUrl &&
            record.originalUrl != record.downloadUrl) {
          await safeResp.response.stream.drain<void>();
          refreshedUrl = true;
          final updated = await _tryRefreshSignedUrl(record);
          if (updated != null) {
            record = updated;
            downloadUri = Uri.parse(updated.downloadUrl);
            continue;
          }
        }
        break;
      }
      final response = safeResp.response;
      final statusCode = response.statusCode;

      if (statusCode == 416 &&
          existingBytes > 0 &&
          record.totalBytes != null &&
          existingBytes >= record.totalBytes!) {
        await response.stream.drain<void>();
        await _finalizeCompletedDownload(id, partFile, existingBytes);
        return;
      }

      if (statusCode < 200 || statusCode >= 300) {
        await response.stream.drain<void>();
        throw HttpException(
          'Server returned HTTP $statusCode',
          uri: safeResp.finalUri,
        );
      }

      final contentType =
          (response.headers['content-type'] ?? '')
              .toLowerCase()
              .split(';')
              .first
              .trim();
      if (contentType == 'text/html' ||
          contentType == 'application/xhtml+xml') {
        await response.stream.drain<void>();
        throw const FormatException(
          'Server returned an HTML web page instead of the requested media/file.',
        );
      }

      var appendMode = false;
      var startOffset = 0;
      int? expectedTotal = record.totalBytes;

      if (statusCode == 206 && existingBytes > 0) {
        appendMode = true;
        startOffset = existingBytes;
        final rangeTotal = _parseTotalFromContentRange(
          response.headers['content-range'],
        );
        if (rangeTotal != null) {
          expectedTotal = rangeTotal;
        } else if (response.contentLength != null &&
            response.contentLength! >= 0) {
          expectedTotal = existingBytes + response.contentLength!;
        }
      } else {
        // 200 OK: start from byte 0 (even if Range was requested).
        if (existingBytes > 0 && await partFile.exists()) {
          await partFile.delete();
        }
        if (response.contentLength != null && response.contentLength! >= 0) {
          expectedTotal = response.contentLength!;
        }
      }

      final acceptRanges =
          (response.headers['accept-ranges'] ?? '').toLowerCase();
      final supportsResumeNow =
          record.supportsResume ||
          statusCode == 206 ||
          acceptRanges.contains('bytes');

      if (expectedTotal != null &&
          expectedTotal > UrlSecurityValidator.maxAllowedFileSizeBytes) {
        await response.stream.drain<void>();
        throw FormatException(
          'File size (${formatBytes(expectedTotal)}) exceeds safety limit.',
        );
      }

      if (expectedTotal != null && expectedTotal > startOffset) {
        final freeBytes = await _storage.getAvailableFreeSpaceBytes(
          partFile.parent.path,
        );
        if (freeBytes != null && (expectedTotal - startOffset) > freeBytes) {
          await response.stream.drain<void>();
          throw FileSystemException(
            'Insufficient storage space for ${formatBytes(expectedTotal)}.',
            partFile.path,
            const OSError('No space left on device', 28),
          );
        }
      }

      _updateRecord(
        id,
        (r) => r.copyWith(
          totalBytes: expectedTotal,
          downloadedBytes: startOffset,
          supportsResume: supportsResumeNow,
          etag: response.headers['etag'] ?? r.etag,
          lastModified: response.headers['last-modified'] ?? r.lastModified,
        ),
      );

      raf = await partFile.open(
        mode: appendMode ? FileMode.writeOnlyAppend : FileMode.writeOnly,
      );

      var currentBytes = startOffset;
      var windowBytes = 0;
      var windowStart = DateTime.now();
      var smoothedSpeed = 0.0;

      final streamIterator = StreamIterator(
        response.stream.timeout(_chunkReadTimeout),
      );

      try {
        while (await streamIterator.moveNext()) {
          if (control.cancelled || control.paused) break;
          final chunk = streamIterator.current;
          if (chunk.isEmpty) continue;

          if (currentBytes + chunk.length >
              UrlSecurityValidator.maxAllowedFileSizeBytes) {
            throw const FormatException(
              'Download aborted: file exceeded maximum allowed size.',
            );
          }

          raf.writeFromSync(chunk);
          currentBytes += chunk.length;
          windowBytes += chunk.length;

          final now = DateTime.now();
          final elapsedMs = now.difference(windowStart).inMilliseconds;
          if (elapsedMs >= 400) {
            final instantSpeed = windowBytes / (elapsedMs / 1000.0);
            smoothedSpeed =
                smoothedSpeed == 0
                    ? instantSpeed
                    : (smoothedSpeed * 0.65 + instantSpeed * 0.35);
            windowBytes = 0;
            windowStart = now;
          }

          int? eta;
          if (expectedTotal != null &&
              expectedTotal > currentBytes &&
              smoothedSpeed > 0) {
            eta = ((expectedTotal - currentBytes) / smoothedSpeed).ceil();
          }

          _runtimeStats[id] = DownloadRuntimeStats(
            bytesPerSecond: smoothedSpeed,
            etaSeconds: eta,
          );
          _updateRecordThrottled(
            id,
            (r) => r.copyWith(downloadedBytes: currentBytes),
          );
        }
      } finally {
        await streamIterator.cancel().catchError((_) {});
      }

      await raf.flush();
      await raf.close();
      raf = null;

      if (control.cancelled) {
        await _deleteTempFile(record.tempFilePath);
        _runtimeStats.remove(id);
        _updateRecord(
          id,
          (r) => r.copyWith(
            status: DownloadStatus.cancelled,
            downloadedBytes: 0,
            errorMessage: 'Cancelled by user.',
          ),
        );
        await _persistRecords();
        notifyListeners();
        return;
      }

      if (control.paused) {
        final idx = _indexOf(id);
        final latest = idx != -1 ? _records[idx] : record;
        if (!latest.supportsResume) {
          await _deleteTempFile(latest.tempFilePath);
        }
        _runtimeStats.remove(id);
        _updateRecord(
          id,
          (r) => r.copyWith(
            status: DownloadStatus.paused,
            downloadedBytes: latest.supportsResume ? currentBytes : 0,
            errorMessage:
                latest.supportsResume
                    ? null
                    : 'Server does not support Range resume; resuming will restart.',
          ),
        );
        await _persistRecords();
        notifyListeners();
        return;
      }

      // Verify byte count if server provided Content-Length.
      if (expectedTotal != null &&
          expectedTotal > 0 &&
          currentBytes != expectedTotal) {
        throw HttpException(
          'Incomplete transfer: received ${formatBytes(currentBytes)} of '
          '${formatBytes(expectedTotal)}.',
        );
      }

      await _finalizeCompletedDownload(id, partFile, currentBytes);
    } catch (e) {
      try {
        await raf?.close();
      } catch (_) {}

      if (control.cancelled) {
        final idx = _indexOf(id);
        if (idx != -1) {
          await _deleteTempFile(_records[idx].tempFilePath);
          _updateRecord(
            id,
            (r) => r.copyWith(
              status: DownloadStatus.cancelled,
              downloadedBytes: 0,
              errorMessage: 'Cancelled by user.',
            ),
          );
          await _persistRecords();
          notifyListeners();
        }
      } else if (control.paused) {
        final idx = _indexOf(id);
        if (idx != -1) {
          final latest = _records[idx];
          final part = File(latest.tempFilePath);
          final len =
              latest.supportsResume && await part.exists()
                  ? await part.length()
                  : 0;
          if (!latest.supportsResume) {
            await _deleteTempFile(latest.tempFilePath);
          }
          _updateRecord(
            id,
            (r) => r.copyWith(
              status: DownloadStatus.paused,
              downloadedBytes: len,
            ),
          );
          await _persistRecords();
          notifyListeners();
        }
      } else {
        final idx = _indexOf(id);
        if (idx != -1) {
          final latest = _records[idx];
          final isStorageFull =
              PlatformStorageService.isInsufficientStorageError(e);
          if (isStorageFull || !latest.supportsResume) {
            await _deleteTempFile(latest.tempFilePath);
          }
          final part = File(latest.tempFilePath);
          final keptBytes =
              (!isStorageFull && latest.supportsResume && await part.exists())
                  ? await part.length()
                  : 0;
          _updateRecord(
            id,
            (r) => r.copyWith(
              status: DownloadStatus.failed,
              downloadedBytes: keptBytes,
              errorMessage: _friendlyErrorMessage(e, isStorageFull),
            ),
          );
          await _persistRecords();
          notifyListeners();
          debugPrint(
            'MediaDownloader failed for ${UrlSecurityValidator.redactUrlForLog(latest.downloadUrl)}: $e',
          );
        }
      }
    } finally {
      _runtimeStats.remove(id);
      _lastUiNotify.remove(id);
      control.client.close();
      _activeTasks.remove(id);
      if (!control.finished.isCompleted) {
        control.finished.complete();
      }
      unawaited(_processQueue());
    }
  }

  Future<void> _finalizeCompletedDownload(
    String id,
    File partFile,
    int totalBytes,
  ) async {
    final idx = _indexOf(id);
    if (idx == -1) return;
    final record = _records[idx];

    final dir = partFile.parent;
    var destPath = record.filePath;
    var destName = record.fileName;
    if (await File(destPath).exists()) {
      destName = await _allocateUniqueFileName(dir, record.fileName);
      destPath = '${dir.path}${Platform.pathSeparator}$destName';
    }

    var finalBytes = totalBytes;
    if (record.selectedQuality?.extractAudioOnly == true) {
      final srcPath = partFile.path;
      final outPath = destPath;
      try {
        await Isolate.run(
          () => Mp4AudioExtractor.extractM4a(
            inputMp4Path: srcPath,
            outputM4aPath: outPath,
          ),
        );
      } catch (e) {
        await _deleteTempFile(outPath);
        rethrow;
      }
      await _deleteTempFile(srcPath);
      finalBytes = await File(destPath).length();
    } else {
      await partFile.rename(destPath);
    }

    final hashes = await FileZipUtils.hashFileInBackground(
      destPath,
      const ['sha256'],
    );
    final sha256 = hashes['sha256'];

    _updateRecord(
      id,
      (r) => r.copyWith(
        fileName: destName,
        filePath: destPath,
        totalBytes: finalBytes,
        downloadedBytes: finalBytes,
        status: DownloadStatus.completed,
        completedAt: DateTime.now(),
        sha256: sha256,
        clearErrorMessage: true,
      ),
    );
    await _persistRecords();
    notifyListeners();

    try {
      NotificationService().showInstantNotification(
        title: 'Download Complete',
        body: '$destName (${formatBytes(finalBytes)}) is ready',
        payload: destPath,
      );
    } catch (_) {}
  }

  static int? _parseTotalFromContentRange(String? header) {
    if (header == null) return null;
    final match = RegExp(r'/(\d+)$').firstMatch(header.trim());
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  static String _friendlyErrorMessage(Object error, bool isStorageFull) {
    if (isStorageFull) {
      return 'Insufficient storage space on device. Free up space and retry.';
    }
    if (error is TimeoutException) {
      return 'Connection timed out during download. Tap Retry to resume.';
    }
    if (error is SocketException) {
      return 'Network connection interrupted (${error.message}).';
    }
    if (error is HttpException) {
      return error.message;
    }
    if (error is FormatException) {
      return error.message;
    }
    if (error is FileSystemException) {
      return 'Storage write error: ${error.message}';
    }
    return 'Download failed: $error';
  }

  Future<DownloadRecord?> _tryRefreshSignedUrl(DownloadRecord record) async {
    try {
      final fresh = await analyzeUrl(record.originalUrl);
      if (!fresh.canDownload || fresh.qualityOptions.isEmpty) return null;

      final targetId = record.selectedQuality?.id;
      MediaQualityOption matched = fresh.qualityOptions.first;
      if (targetId != null) {
        for (final opt in fresh.qualityOptions) {
          if (opt.id == targetId) {
            matched = opt;
            break;
          }
        }
      }

      final urlCheck = UrlSecurityValidator.validate(matched.downloadUrl);
      if (!urlCheck.isValid) return null;

      _updateRecord(
        record.id,
        (r) => r.copyWith(
          downloadUrl: matched.downloadUrl,
          selectedQuality: matched,
          availableQualities: fresh.qualityOptions,
        ),
      );
      await _persistRecords();
      final idx = _indexOf(record.id);
      return idx != -1 ? _records[idx] : null;
    } catch (_) {
      return null;
    }
  }

  String _buildSafeFileName({
    required String preferredName,
    required MediaQualityOption quality,
    required Uri fallbackUri,
  }) {
    final overrideName = quality.fileName;
    if (overrideName != null && overrideName.trim().isNotEmpty) {
      final cleanOverride = FileZipUtils.safeFileName(
        overrideName,
        fallback: '',
      );
      if (cleanOverride.isNotEmpty) {
        if (UrlSecurityValidator.extractExtension(cleanOverride).isEmpty &&
            quality.format.isNotEmpty) {
          return '$cleanOverride.${quality.format}';
        }
        return cleanOverride;
      }
    }

    var name = FileZipUtils.safeFileName(preferredName, fallback: '');
    if (name.isEmpty) {
      name = UrlSecurityValidator.resolveSafeFileName(
        uri: fallbackUri,
        mimeType: quality.mimeType,
      );
    }
    final currentExt = UrlSecurityValidator.extractExtension(name);
    final desiredExt = quality.format.trim().toLowerCase();
    if (desiredExt.isNotEmpty) {
      if (currentExt.isEmpty) {
        name = '$name.$desiredExt';
      } else if (currentExt != desiredExt) {
        final dot = name.lastIndexOf('.');
        if (dot > 0) {
          name = '${name.substring(0, dot)}.$desiredExt';
        }
      }
    }
    return name;
  }

  Future<String> _allocateUniqueFileName(Directory dir, String baseName) async {
    final taken = <String>{};
    if (await dir.exists()) {
      await for (final entity in dir.list(followLinks: false)) {
        final seg = entity.uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (seg.isNotEmpty) taken.add(seg.last);
      }
    }
    for (final r in _records) {
      if (r.fileName.isNotEmpty) taken.add(r.fileName);
    }
    return FileZipUtils.uniqueName(baseName, taken);
  }

  int _indexOf(String id) => _records.indexWhere((r) => r.id == id);

  void _updateRecord(
    String id,
    DownloadRecord Function(DownloadRecord current) transform,
  ) {
    final idx = _indexOf(id);
    if (idx != -1) {
      _records[idx] = transform(_records[idx]);
    }
  }

  void _updateRecordThrottled(
    String id,
    DownloadRecord Function(DownloadRecord current) transform,
  ) {
    _updateRecord(id, transform);
    final now = DateTime.now();
    final last = _lastUiNotify[id];
    if (last == null || now.difference(last).inMilliseconds >= 140) {
      _lastUiNotify[id] = now;
      notifyListeners();
    }
  }

  Future<void> _deleteTempFile(String path) async {
    if (path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _persistRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _records.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_keyRecords, encoded);
  }

  static String _generateId() =>
      'dl_${DateTime.now().microsecondsSinceEpoch}';
}

/// Result of verifying a downloaded file on disk.
class FileIntegrityResult {
  final bool exists;
  final int? actualBytes;
  final String? sha256;
  final bool matchesExpectedSize;
  final bool matchesRecordedHash;
  final String message;

  const FileIntegrityResult({
    required this.exists,
    this.actualBytes,
    this.sha256,
    required this.matchesExpectedSize,
    required this.matchesRecordedHash,
    required this.message,
  });

  bool get isValid => exists && matchesExpectedSize && matchesRecordedHash;
}
