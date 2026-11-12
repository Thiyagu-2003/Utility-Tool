import 'package:http/http.dart' as http;
import '../models/media_downloader_models.dart';
import 'media_source_adapter.dart';

/// Independent adapter for Facebook URLs.
///
/// Facebook requires Meta Graph API authorization and user permissions for
/// owned media and does not expose unauthenticated direct download links.
class FacebookSourceAdapter implements MediaSourceAdapter {
  static const Set<String> _hosts = {
    'facebook.com',
    'www.facebook.com',
    'm.facebook.com',
    'fb.watch',
    'fb.com',
    'www.fb.com',
  };

  @override
  String get id => 'facebook';

  @override
  String get displayName => 'Facebook';

  @override
  bool canHandle(Uri uri) => _hosts.contains(uri.host.toLowerCase());

  @override
  Future<UrlAnalysisResult> analyze(
    Uri uri, {
    required http.Client client,
  }) async {
    final path = uri.path.toLowerCase();
    String title = 'Facebook Link';
    if (uri.host.toLowerCase() == 'fb.watch' || path.contains('/watch')) {
      title = 'Facebook Watch Video';
    } else if (path.contains('/reel')) {
      title = 'Facebook Reel';
    } else if (path.contains('/videos')) {
      title = 'Facebook Video';
    }

    return UrlAnalysisResult.failure(
      originalUrl: uri.toString(),
      isValidUrl: true,
      isSupported: true,
      isPlatformRestricted: true,
      sourceId: id,
      sourceName: displayName,
      title: title,
      errorMessage:
          'Facebook does not expose direct unauthenticated media downloads '
          'for post URLs. Download your own content via Facebook "Download Your '
          'Information" or open the original link in your browser.',
    );
  }
}
