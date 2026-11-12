import 'dart:async';
import 'package:http/http.dart' as http;
import '../../file_tools/file_zip_utils.dart';

/// Result of validating and normalizing a user-entered download URL.
class UrlValidationResult {
  final bool isValid;
  final Uri? uri;
  final String? errorMessage;

  const UrlValidationResult.valid(this.uri)
      : isValid = true,
        errorMessage = null;

  const UrlValidationResult.invalid(this.errorMessage)
      : isValid = false,
        uri = null;
}

/// Validates URLs, sanitizes filenames, enforces safe redirects, and blocks
/// automatic downloading of executable files.
class UrlSecurityValidator {
  static const int maxRedirects = 5;
  static const Duration requestTimeout = Duration(seconds: 20);
  static const int maxAllowedFileSizeBytes = 4 * 1024 * 1024 * 1024; // 4 GiB

  static const Set<String> blockedExecutableExtensions = {
    'exe',
    'msi',
    'bat',
    'cmd',
    'com',
    'scr',
    'pif',
    'vbs',
    'vbe',
    'wsf',
    'wsh',
    'ps1',
    'psm1',
    'sh',
    'bash',
    'zsh',
    'apk',
    'aab',
    'ipa',
    'dmg',
    'pkg',
    'deb',
    'rpm',
    'appimage',
    'dll',
    'so',
    'dylib',
    'sys',
    'jar',
    'cpl',
    'hta',
    'reg',
  };

  static const Map<String, String> mimeToExtension = {
    'video/mp4': 'mp4',
    'video/webm': 'webm',
    'video/x-matroska': 'mkv',
    'video/quicktime': 'mov',
    'video/x-msvideo': 'avi',
    'audio/mpeg': 'mp3',
    'audio/mp3': 'mp3',
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    'audio/aac': 'aac',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
    'audio/ogg': 'ogg',
    'audio/flac': 'flac',
    'audio/webm': 'weba',
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/gif': 'gif',
    'image/bmp': 'bmp',
    'image/svg+xml': 'svg',
    'application/pdf': 'pdf',
    'application/zip': 'zip',
    'application/x-zip-compressed': 'zip',
    'application/x-tar': 'tar',
    'application/gzip': 'gz',
    'application/x-7z-compressed': '7z',
    'application/vnd.rar': 'rar',
    'text/plain': 'txt',
    'text/csv': 'csv',
    'text/markdown': 'md',
    'application/json': 'json',
    'application/xml': 'xml',
    'text/xml': 'xml',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        'docx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        'pptx',
  };

  /// Validates that [rawInput] is a safe, well-formed `http` or `https` URL.
  static UrlValidationResult validate(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      return const UrlValidationResult.invalid('Please enter a URL to analyze.');
    }

    if (RegExp(r'[\x00-\x1F\x7F\s]').hasMatch(trimmed)) {
      return const UrlValidationResult.invalid(
        'URL contains invalid whitespace or control characters.',
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      return const UrlValidationResult.invalid(
        'Invalid URL. Please enter a full http:// or https:// address.',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return UrlValidationResult.invalid(
        'Unsupported protocol "$scheme:". Only HTTP and HTTPS URLs are allowed.',
      );
    }

    if (uri.host.trim().isEmpty || uri.host.contains('..')) {
      return const UrlValidationResult.invalid(
        'URL is missing a valid domain or host name.',
      );
    }

    if (uri.userInfo.isNotEmpty) {
      return const UrlValidationResult.invalid(
        'URLs with embedded username/password credentials are blocked for security.',
      );
    }

    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      return const UrlValidationResult.invalid('URL contains an invalid port.');
    }

    return UrlValidationResult.valid(uri);
  }

  /// Strips query parameters and userinfo so sensitive tokens are never logged.
  static String redactUrlForLog(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return '<invalid-url>';
    return uri
        .replace(
          userInfo: '',
          query: uri.hasQuery ? 'redacted' : null,
          fragment: null,
        )
        .toString();
  }

  /// Extracts lowercase extension without the leading dot, or empty string.
  static String extractExtension(String fileName) {
    final clean = FileZipUtils.safeFileName(fileName, fallback: '');
    final dot = clean.lastIndexOf('.');
    if (dot <= 0 || dot >= clean.length - 1) return '';
    return clean.substring(dot + 1).toLowerCase();
  }

  /// Returns true if [fileName] or its extension is a blocked executable type.
  static bool isBlockedExecutable(String fileName, {String mimeType = ''}) {
    final ext = extractExtension(fileName);
    if (blockedExecutableExtensions.contains(ext)) return true;
    final mime = mimeType.toLowerCase().split(';').first.trim();
    return mime == 'application/x-msdownload' ||
        mime == 'application/x-executable' ||
        mime == 'application/x-sh' ||
        mime == 'application/vnd.android.package-archive';
  }

  /// Parses a safe filename from `Content-Disposition`, falling back to [uri]
  /// path and MIME-derived extension.
  static String resolveSafeFileName({
    required Uri uri,
    String? contentDisposition,
    String mimeType = '',
  }) {
    String? rawName;

    if (contentDisposition != null && contentDisposition.isNotEmpty) {
      final utf8Match = RegExp(
        r"filename\*\s*=\s*(?:UTF-8|utf-8)''([^;]+)",
      ).firstMatch(contentDisposition);
      if (utf8Match != null) {
        try {
          rawName = Uri.decodeComponent(utf8Match.group(1)!.trim());
        } catch (_) {}
      }
      rawName ??= RegExp(
        r'filename\s*=\s*"([^"]+)"',
        caseSensitive: false,
      ).firstMatch(contentDisposition)?.group(1);
      rawName ??= RegExp(
        r'filename\s*=\s*([^;\s]+)',
        caseSensitive: false,
      ).firstMatch(contentDisposition)?.group(1);
    }

    if (rawName == null || rawName.trim().isEmpty) {
      final segments = uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
      if (segments.isNotEmpty) {
        try {
          rawName = Uri.decodeComponent(segments.last);
        } catch (_) {
          rawName = segments.last;
        }
      }
    }

    var safe = FileZipUtils.safeFileName(rawName ?? '', fallback: 'download');
    final ext = extractExtension(safe);
    final normalizedMime = mimeType.toLowerCase().split(';').first.trim();
    if (ext.isEmpty && mimeToExtension.containsKey(normalizedMime)) {
      safe = '$safe.${mimeToExtension[normalizedMime]!}';
    }
    return safe;
  }

  /// Sends an HTTP request using [client], manually following up to
  /// [maxRedirects] safe `http`/`https` redirects.
  static Future<SafeHttpResponse> sendWithSafeRedirects({
    required http.Client client,
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    Duration timeout = requestTimeout,
  }) async {
    var currentUri = uri;
    final visited = <String>{};

    for (var hop = 0; hop <= maxRedirects; hop++) {
      if (!visited.add(currentUri.toString())) {
        throw const FormatException('Redirect loop detected.');
      }

      final request = http.Request(method, currentUri)
        ..followRedirects = false
        ..headers.addAll({
          'User-Agent': 'ToolBoxPro/1.0 MediaDownloader',
          ...headers,
        });

      final streamed = await client.send(request).timeout(timeout);
      final status = streamed.statusCode;

      if (status == 301 ||
          status == 302 ||
          status == 303 ||
          status == 307 ||
          status == 308) {
        final location = streamed.headers['location'];
        // Drain redirect body before closing/continuing.
        await streamed.stream.drain<void>();
        if (location == null || location.trim().isEmpty) {
          throw const FormatException('Server sent an empty redirect target.');
        }
        final resolved = currentUri.resolve(location.trim());
        final check = validate(resolved.toString());
        if (!check.isValid || check.uri == null) {
          throw FormatException(
            'Blocked unsafe redirect target: ${check.errorMessage ?? 'invalid URL'}',
          );
        }
        currentUri = check.uri!;
        continue;
      }

      return SafeHttpResponse(finalUri: currentUri, response: streamed);
    }

    throw const FormatException('Too many HTTP redirects.');
  }
}

/// Paired streamed HTTP response and its final resolved URI after redirects.
class SafeHttpResponse {
  final Uri finalUri;
  final http.StreamedResponse response;

  const SafeHttpResponse({
    required this.finalUri,
    required this.response,
  });
}
