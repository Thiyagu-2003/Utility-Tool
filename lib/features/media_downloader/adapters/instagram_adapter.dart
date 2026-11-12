import 'package:http/http.dart' as http;
import '../models/media_downloader_models.dart';
import 'media_source_adapter.dart';

/// Independent adapter for Instagram URLs.
///
/// Instagram requires authenticated Meta Graph API access and does not provide
/// unauthenticated direct media download endpoints.
class InstagramSourceAdapter implements MediaSourceAdapter {
  static const Set<String> _hosts = {
    'instagram.com',
    'www.instagram.com',
    'm.instagram.com',
    'instagr.am',
  };

  @override
  String get id => 'instagram';

  @override
  String get displayName => 'Instagram';

  @override
  bool canHandle(Uri uri) => _hosts.contains(uri.host.toLowerCase());

  @override
  Future<UrlAnalysisResult> analyze(
    Uri uri, {
    required http.Client client,
  }) async {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    String kind = 'Instagram Post';
    if (segments.isNotEmpty) {
      switch (segments.first.toLowerCase()) {
        case 'reel':
        case 'reels':
          kind = 'Instagram Reel';
          break;
        case 'stories':
          kind = 'Instagram Story';
          break;
        case 'tv':
          kind = 'Instagram Video';
          break;
      }
    }

    return UrlAnalysisResult.failure(
      originalUrl: uri.toString(),
      isValidUrl: true,
      isSupported: true,
      isPlatformRestricted: true,
      sourceId: id,
      sourceName: displayName,
      title: kind,
      errorMessage:
          'Instagram does not permit unauthenticated direct media downloading '
          '(access requires an authorized Meta Graph API token and user permissions). '
          'You can download your own uploads via Meta Accounts Center or open the original link.',
    );
  }
}
