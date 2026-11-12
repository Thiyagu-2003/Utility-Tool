import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_downloader_models.dart';
import 'media_source_adapter.dart';

/// Independent adapter for YouTube URLs using YouTube's official oEmbed API.
///
/// Direct stream extraction is intentionally not performed to respect YouTube's
/// Terms of Service and platform stream protections.
class YouTubeSourceAdapter implements MediaSourceAdapter {
  static const Set<String> _hosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
  };

  @override
  String get id => 'youtube';

  @override
  String get displayName => 'YouTube';

  @override
  bool canHandle(Uri uri) => _hosts.contains(uri.host.toLowerCase());

  static String? extractVideoId(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be') {
      final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      return seg.isNotEmpty ? seg.first : null;
    }
    final v = uri.queryParameters['v'];
    if (v != null && v.trim().isNotEmpty) return v.trim();

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 &&
        (segments.first == 'shorts' ||
            segments.first == 'live' ||
            segments.first == 'embed' ||
            segments.first == 'v')) {
      return segments[1];
    }
    return null;
  }

  @override
  Future<UrlAnalysisResult> analyze(
    Uri uri, {
    required http.Client client,
  }) async {
    final videoId = extractVideoId(uri);
    final canonicalUrl =
        videoId != null
            ? 'https://www.youtube.com/watch?v=$videoId'
            : uri.toString();

    String title = videoId != null ? 'YouTube Video ($videoId)' : 'YouTube Link';
    String? author;
    String? thumbnailUrl;

    try {
      final oembedUri = Uri.https('www.youtube.com', '/oembed', {
        'url': canonicalUrl,
        'format': 'json',
      });
      final response = await client
          .get(oembedUri, headers: {'User-Agent': 'ToolBoxPro/1.0'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final fetchedTitle = decoded['title'] as String?;
          if (fetchedTitle != null && fetchedTitle.trim().isNotEmpty) {
            title = fetchedTitle.trim();
          }
          author = (decoded['author_name'] as String?)?.trim();
          thumbnailUrl = (decoded['thumbnail_url'] as String?)?.trim();
        }
      }
    } catch (_) {
      // Metadata lookup is best-effort (may fail offline or for unlisted/private videos).
    }

    return UrlAnalysisResult.failure(
      originalUrl: uri.toString(),
      isValidUrl: true,
      isSupported: true,
      isPlatformRestricted: true,
      sourceId: id,
      sourceName: displayName,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      errorMessage:
          'Direct downloading from YouTube is not supported because YouTube '
          'restricts unauthorized third-party stream downloads. Use YouTube Studio '
          'or Google Takeout to download your own content, or open the original link.',
    );
  }
}
