import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Honest summary of platform-specific downloader storage & execution rules.
class PlatformCapabilitiesInfo {
  final String platformName;
  final String storageLocationSummary;
  final String backgroundBehaviorNote;
  final String fileAccessNote;

  const PlatformCapabilitiesInfo({
    required this.platformName,
    required this.storageLocationSummary,
    required this.backgroundBehaviorNote,
    required this.fileAccessNote,
  });
}

/// Cross-platform storage resolution, free-space probing, file opening,
/// sharing, and external URL launching.
class PlatformStorageService {
  final Future<Directory> Function()? _directoryOverride;
  final Future<int?> Function(String path)? _freeSpaceOverride;

  PlatformStorageService({
    Future<Directory> Function()? directoryOverride,
    Future<int?> Function(String path)? freeSpaceOverride,
  })  : _directoryOverride = directoryOverride,
        _freeSpaceOverride = freeSpaceOverride;

  /// Resolves and ensures the managed ToolBox Pro downloads directory exists.
  Future<Directory> getDownloadsDirectory() async {
    if (_directoryOverride != null) {
      final dir = await _directoryOverride();
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }

    Directory? baseDir;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        baseDir = await getDownloadsDirectorySafe();
      } catch (_) {}
    }

    baseDir ??= await getApplicationDocumentsDirectory();
    final subFolder =
        (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
            ? 'ToolBox Pro'
            : 'ToolBoxProDownloads';
    final target = Directory(
      '${baseDir.path}${Platform.pathSeparator}$subFolder',
    );
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target;
  }

  /// Calls `path_provider.getDownloadsDirectory()` safely inside a try-catch.
  Future<Directory?> getDownloadsDirectorySafe() async {
    try {
      return await getDownloadsDirectoryFromProvider();
    } catch (_) {
      return null;
    }
  }

  static Future<Directory?> getDownloadsDirectoryFromProvider() {
    // Uses path_provider's getDownloadsDirectory().
    return getDownloadsDirectoryPlatform();
  }

  /// Returns free disk space in bytes for [directoryPath], or `null` when
  /// unavailable on the current platform without a native plugin.
  Future<int?> getAvailableFreeSpaceBytes(String directoryPath) async {
    if (_freeSpaceOverride != null) {
      return _freeSpaceOverride(directoryPath);
    }
    if (kIsWeb) return null;

    try {
      if (Platform.isWindows) {
        final match = RegExp(r'^([A-Za-z]):').firstMatch(directoryPath);
        if (match == null) return null;
        final drive = match.group(1)!.toUpperCase();
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          '(Get-PSDrive -Name "$drive").Free',
        ]).timeout(const Duration(seconds: 4));
        if (result.exitCode == 0) {
          return int.tryParse(result.stdout.toString().trim());
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run(
          'df',
          ['-k', directoryPath],
        ).timeout(const Duration(seconds: 4));
        if (result.exitCode == 0) {
          final lines =
              result.stdout
                  .toString()
                  .trim()
                  .split('\n')
                  .where((l) => l.trim().isNotEmpty)
                  .toList();
          if (lines.length >= 2) {
            final cols = lines.last.trim().split(RegExp(r'\s+'));
            if (cols.length >= 4) {
              final kb = int.tryParse(cols[3]);
              if (kb != null) return kb * 1024;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Detects OS-level insufficient storage errors from [FileSystemException].
  static bool isInsufficientStorageError(Object error) {
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      // POSIX ENOSPC = 28, EDQUOT = 122 (Linux) / 69 (macOS), Windows ERROR_DISK_FULL = 112.
      if (code == 28 || code == 112 || code == 122 || code == 69) return true;
      final msg = '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
      return msg.contains('no space') ||
          msg.contains('disk full') ||
          msg.contains('not enough space') ||
          msg.contains('insufficient');
    }
    return false;
  }

  /// Opens a local file using the platform's default associated viewer.
  /// Never executes files directly; returns an error message if opening fails.
  Future<String?> openLocalFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return 'File no longer exists at $path';
    }
    try {
      final result = await OpenFilex.open(path);
      if (result.type == ResultType.done) return null;
      return result.message.isNotEmpty
          ? result.message
          : 'No compatible app found to open this file.';
    } catch (e) {
      return 'Unable to open file: $e';
    }
  }

  /// Shares a local file via the system share sheet.
  Future<String?> shareLocalFile(String path, {String? text}) async {
    final file = File(path);
    if (!await file.exists()) {
      return 'File no longer exists at $path';
    }
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: text),
      );
      return null;
    } catch (e) {
      return 'Unable to share file: $e';
    }
  }

  /// Exports a copy of a downloaded file to a user-chosen location.
  Future<String?> exportCopyToUserFolder({
    required String sourcePath,
    required String fileName,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      return 'Original file does not exist.';
    }
    try {
      final bytes = await file.readAsBytes();
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save Copy As',
        fileName: fileName,
        bytes: bytes,
      );
      if (saved == null) return 'Export cancelled.';
      return null;
    } catch (e) {
      return 'Failed to export copy: $e';
    }
  }

  /// Opens an external HTTP/HTTPS URL in the system browser.
  Future<bool> openExternalUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Returns an accurate description of the current OS's capabilities.
  PlatformCapabilitiesInfo describeCurrentPlatform() {
    if (kIsWeb) {
      return const PlatformCapabilitiesInfo(
        platformName: 'Web',
        storageLocationSummary: 'Browser download sandbox (not supported for local library)',
        backgroundBehaviorNote: 'Web browsers manage downloads independently.',
        fileAccessNote: 'Local disk library requires native Android, iOS, Windows, Linux, or macOS.',
      );
    }
    if (Platform.isAndroid) {
      return const PlatformCapabilitiesInfo(
        platformName: 'Android',
        storageLocationSummary: 'App-private Downloads directory (Scoped Storage compliant)',
        backgroundBehaviorNote:
            'Downloads stream while the app is active. If Android suspends background execution, resumable downloads can continue via HTTP Range on return.',
        fileAccessNote:
            'Files can be opened via FileProvider, shared via the Android share sheet, or exported to a chosen folder.',
      );
    }
    if (Platform.isIOS) {
      return const PlatformCapabilitiesInfo(
        platformName: 'iOS',
        storageLocationSummary: 'App Documents/ToolBoxProDownloads (visible in Apple Files app)',
        backgroundBehaviorNote:
            'iOS suspends network sockets shortly after backgrounding; resumable transfers resume cleanly via HTTP Range when reopened.',
        fileAccessNote:
            'Files are accessible in the iOS Files app and via Share / Open With.',
      );
    }
    if (Platform.isWindows) {
      return const PlatformCapabilitiesInfo(
        platformName: 'Windows',
        storageLocationSummary: 'User Downloads\\ToolBox Pro folder',
        backgroundBehaviorNote:
            'Full concurrent background streaming while the app window remains open.',
        fileAccessNote:
            'Direct filesystem access, free disk space checks, and native shell open/share.',
      );
    }
    if (Platform.isMacOS) {
      return const PlatformCapabilitiesInfo(
        platformName: 'macOS',
        storageLocationSummary: 'User Downloads/ToolBox Pro (sandboxed entitlement) or App Documents',
        backgroundBehaviorNote:
            'Full concurrent streaming while running inside the macOS App Sandbox.',
        fileAccessNote:
            'Opens with Finder/default macOS apps and supports system Share.',
      );
    }
    if (Platform.isLinux) {
      return const PlatformCapabilitiesInfo(
        platformName: 'Linux',
        storageLocationSummary: 'User Downloads/ToolBox Pro (XDG Downloads or Documents)',
        backgroundBehaviorNote:
            'Full concurrent streaming while running.',
        fileAccessNote:
            'Opens via xdg-open / default desktop handlers and supports free-space checks.',
      );
    }
    return const PlatformCapabilitiesInfo(
      platformName: 'Desktop / Mobile',
      storageLocationSummary: 'App Documents folder',
      backgroundBehaviorNote: 'Active-session streaming with HTTP Range resume.',
      fileAccessNote: 'Managed local downloads library.',
    );
  }
}

Future<Directory?> getDownloadsDirectoryPlatform() => getDownloadsDirectory();
