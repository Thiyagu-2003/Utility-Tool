import 'package:http/http.dart' as http;
import '../models/media_downloader_models.dart';
import 'direct_media_adapter.dart';
import 'facebook_adapter.dart';
import 'instagram_adapter.dart';
import 'x_adapter.dart';
import 'youtube_adapter.dart';

/// Contract for an independent source adapter that analyzes a URL and
/// determines whether and how it may be downloaded.
abstract class MediaSourceAdapter {
  String get id;
  String get displayName;

  /// Returns true if this adapter owns URLs matching [uri].
  bool canHandle(Uri uri);

  /// Analyzes [uri] without bypassing authentication, DRM, or platform rules.
  Future<UrlAnalysisResult> analyze(Uri uri, {required http.Client client});
}

/// Ordered registry of independent source adapters.
class SourceAdapterRegistry {
  final List<MediaSourceAdapter> adapters;

  SourceAdapterRegistry({List<MediaSourceAdapter>? adapters})
      : adapters = adapters ??
            [
              YouTubeSourceAdapter(),
              InstagramSourceAdapter(),
              FacebookSourceAdapter(),
              XSourceAdapter(),
              DirectMediaSourceAdapter(),
            ];

  /// Selects the first matching adapter and analyzes [uri].
  Future<UrlAnalysisResult> analyze(Uri uri, {required http.Client client}) {
    for (final adapter in adapters) {
      if (adapter.canHandle(uri)) {
        return adapter.analyze(uri, client: client);
      }
    }
    return Future.value(
      UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        errorMessage: 'No supported source adapter matched this URL.',
      ),
    );
  }
}
