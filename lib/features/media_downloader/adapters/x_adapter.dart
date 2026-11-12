import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_downloader_models.dart';
import 'media_source_adapter.dart';

/// Independent adapter for X (formerly Twitter) URLs using X's public oEmbed API.
class XSourceAdapter implements MediaSourceAdapter {
  static const Set<String> _hosts = {
    'x.com',
    'www.x.com',
    'twitter.com',
    'www.twitter.com',
    'mobile.twitter.com',
  };

  @override
  String get id => 'x';

  @override
  String get displayName => 'X (Twitter)';

  @override
  bool canHandle(Uri uri) => _hosts.contains(uri.host.toLowerCase());

  @override
  Future<UrlAnalysisResult> analyze(
    Uri uri, {
    required http.Client client,
  }) async {
    String title = 'X Post';
    String? author;

    try {
      final oembedUri = Uri.https('publish.twitter.com', '/oembed', {
        'url': uri.toString(),
        'omit_script': 'true',
      });
      final response = await client
          .get(oembedUri, headers: {'User-Agent': 'ToolBoxPro/1.0'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final authorName = (decoded['author_name'] as String?)?.trim();
          if (authorName != null && authorName.isNotEmpty) {
            author = authorName;
            title = 'Post by $authorName';
          }
        }
      }
    } catch (_) {
      // Metadata lookup is best-effort.
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
      errorMessage:
          'X post URLs do not expose unauthenticated direct video or media '
          'files via public APIs. If you have a direct authorized media file URL '
          '(e.g. a direct .mp4 or image link), paste that URL, or open the original post.',
    );
  }
}
