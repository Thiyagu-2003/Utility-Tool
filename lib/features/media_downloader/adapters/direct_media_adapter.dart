import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/media_downloader_models.dart';
import '../services/url_security_validator.dart';
import 'media_source_adapter.dart';

/// General adapter for direct HTTP/HTTPS media and file URLs (MP4, WebM, MP3,
/// M4A, WAV, JPEG, PNG, WebP, PDF, ZIP, and other permitted file types).
class DirectMediaSourceAdapter implements MediaSourceAdapter {
  @override
  String get id => 'direct';

  @override
  String get displayName => 'Direct Media / File';

  @override
  bool canHandle(Uri uri) =>
      uri.scheme.toLowerCase() == 'http' || uri.scheme.toLowerCase() == 'https';

  @override
  Future<UrlAnalysisResult> analyze(
    Uri uri, {
    required http.Client client,
  }) async {
    SafeHttpResponse? safeResp;
    try {
      safeResp = await UrlSecurityValidator.sendWithSafeRedirects(
        client: client,
        method: 'HEAD',
        uri: uri,
      );
      await safeResp.response.stream.drain<void>();

      final status = safeResp.response.statusCode;
      if (status == 405 || status == 501 || status == 403) {
        // Some CDNs/servers disallow HEAD; probe header with a 1-byte Range GET.
        safeResp = await UrlSecurityValidator.sendWithSafeRedirects(
          client: client,
          method: 'GET',
          uri: safeResp.finalUri,
          headers: const {'Range': 'bytes=0-0'},
        );
        await safeResp.response.stream.drain<void>();
      }
    } on TimeoutException {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        sourceId: id,
        sourceName: displayName,
        errorMessage:
            'Connection timed out while checking the URL. Please verify your network and try again.',
      );
    } on SocketException catch (e) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        sourceId: id,
        sourceName: displayName,
        errorMessage: 'Network error: ${e.message}.',
      );
    } on FormatException catch (e) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        sourceId: id,
        sourceName: displayName,
        errorMessage: e.message,
      );
    } catch (e) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        sourceId: id,
        sourceName: displayName,
        errorMessage: 'Could not analyze URL: $e',
      );
    }

    final response = safeResp.response;
    final finalUri = safeResp.finalUri;
    final status = response.statusCode;

    if (status < 200 || status >= 300) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        sourceId: id,
        sourceName: displayName,
        errorMessage: _describeHttpStatus(status),
      );
    }

    final headers = response.headers;
    final rawContentType = headers['content-type'] ?? '';
    final mimeType = rawContentType.toLowerCase().split(';').first.trim();

    if (mimeType == 'text/html' || mimeType == 'application/xhtml+xml') {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isSupported: false,
        sourceId: id,
        sourceName: displayName,
        errorMessage:
            'This URL returns a web page (HTML) rather than a direct downloadable '
            'media or file link. Please paste a direct file URL (e.g. .mp4, .mp3, .png, .pdf, .zip).',
      );
    }

    final fileName = UrlSecurityValidator.resolveSafeFileName(
      uri: finalUri,
      contentDisposition: headers['content-disposition'],
      mimeType: mimeType,
    );
    final ext = UrlSecurityValidator.extractExtension(fileName);

    if (UrlSecurityValidator.isBlockedExecutable(fileName, mimeType: mimeType)) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isSupported: false,
        sourceId: id,
        sourceName: displayName,
        errorMessage:
            'Blocked for security: executable or installer files '
            '(${ext.isEmpty ? mimeType : '.$ext'}) cannot be downloaded automatically.',
      );
    }

    final contentLength = _parseTotalLength(headers, status);
    if (contentLength != null &&
        contentLength > UrlSecurityValidator.maxAllowedFileSizeBytes) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        sourceId: id,
        sourceName: displayName,
        errorMessage:
            'File size (${formatBytes(contentLength)}) exceeds the safety limit of '
            '${formatBytes(UrlSecurityValidator.maxAllowedFileSizeBytes)}.',
      );
    }

    final acceptRanges = (headers['accept-ranges'] ?? '').toLowerCase();
    final supportsResume =
        status == 206 || acceptRanges.contains('bytes');

    final effectiveMime =
        mimeType.isEmpty ? 'application/octet-stream' : mimeType;
    final category = MediaLibraryCategory.classify(
      fileName: fileName,
      mimeType: effectiveMime,
    );

    final formatLabel =
        ext.isNotEmpty
            ? ext.toUpperCase()
            : effectiveMime.split('/').last.toUpperCase();

    final option = MediaQualityOption(
      id: 'original',
      label: 'Original ($formatLabel)',
      format: ext.isNotEmpty ? ext : formatLabel.toLowerCase(),
      downloadUrl: finalUri.toString(),
      fileSizeBytes: contentLength,
      isOriginal: true,
      supportsResume: supportsResume,
      mimeType: effectiveMime,
    );

    return UrlAnalysisResult(
      isValidUrl: true,
      isSupported: true,
      canDownload: true,
      sourceId: id,
      sourceName: displayName,
      originalUrl: uri.toString(),
      resolvedUrl: finalUri.toString(),
      title: fileName,
      thumbnailUrl:
          category == MediaLibraryCategory.images ? finalUri.toString() : null,
      fileName: fileName,
      mimeType: effectiveMime,
      extension: ext,
      mediaCategory: category,
      fileSizeBytes: contentLength,
      supportsResume: supportsResume,
      etag: headers['etag'],
      lastModified: headers['last-modified'],
      qualityOptions: [option],
    );
  }

  static int? _parseTotalLength(Map<String, String> headers, int status) {
    if (status == 206) {
      final contentRange = headers['content-range'];
      if (contentRange != null) {
        final match = RegExp(r'/(\d+)$').firstMatch(contentRange.trim());
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
      }
      return null;
    }
    final raw = headers['content-length'];
    if (raw == null) return null;
    final parsed = int.tryParse(raw.trim());
    return (parsed != null && parsed >= 0) ? parsed : null;
  }

  static String _describeHttpStatus(int status) {
    switch (status) {
      case 401:
      case 403:
        return 'Access denied (HTTP $status). This link may require authentication or have expired.';
      case 404:
      case 410:
        return 'File not found (HTTP $status). Verify that the URL is still available.';
      case 429:
        return 'Server rate limit reached (HTTP 429). Please wait and try again.';
      default:
        return 'Server returned HTTP $status and could not provide this file.';
    }
  }
}
