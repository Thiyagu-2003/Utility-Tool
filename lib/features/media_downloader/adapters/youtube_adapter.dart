import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../file_tools/file_zip_utils.dart';
import '../models/media_downloader_models.dart';
import 'media_source_adapter.dart';

/// Independent adapter for YouTube URLs using `youtube_explode_dart` to
/// extract video metadata and downloadable stream quality options.
///
/// Uses YouTube's InnerTube player endpoint (`requireWatchPage: false`) and
/// oEmbed metadata to avoid hitting `GET /watch`, which triggers IP-based
/// `/sorry/` rate limits on mobile carrier networks.
class YouTubeSourceAdapter implements MediaSourceAdapter {
  static const Set<String> _hosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'www.youtu.be',
  };

  /// 8 MiB chunk size for YouTube muxed CDN streams so transfers stay
  /// unthrottled and resume cleanly via Range requests.
  static const int _youtubeChunkBytes = 8 * 1024 * 1024;

  static const String _modernBrowserUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  @override
  String get id => 'youtube';

  @override
  String get displayName => 'YouTube';

  @override
  bool canHandle(Uri uri) => _hosts.contains(uri.host.toLowerCase());

  static String? extractVideoId(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' || host == 'www.youtu.be') {
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
            segments.first == 'v' ||
            segments.first == 'watch')) {
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
    if (videoId == null || videoId.isEmpty) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isValidUrl: true,
        isSupported: true,
        sourceId: id,
        sourceName: displayName,
        errorMessage:
            'Could not find a valid YouTube video ID in this URL. '
            'Paste a standard watch, Shorts, or youtu.be link.',
      );
    }

    final capturedMeta = _CapturedVideoMeta();
    final yt = YoutubeExplode(
      httpClient: YoutubeHttpClient(
        _YouTubeProxyClient(client, capturedMeta),
      ),
    );

    try {
      // Run InnerTube stream extraction (no /watch GET) and oEmbed metadata
      // lookup concurrently so mobile carrier IPs are not rate-limited.
      final oembedFuture = _fetchOembedMeta(videoId, client: client);
      late StreamManifest manifest;
      try {
        manifest = await yt.videos.streamsClient
            .getManifest(videoId, requireWatchPage: false)
            .timeout(const Duration(seconds: 25));
      } on YoutubeExplodeException {
        // Only fall back to watch-page extraction if InnerTube alone failed.
        manifest = await yt.videos.streamsClient
            .getManifest(videoId, requireWatchPage: true)
            .timeout(const Duration(seconds: 25));
      }

      final oembed = await oembedFuture;
      final title =
          _firstNonEmpty([oembed.title, capturedMeta.title]) ??
          'YouTube Video ($videoId)';
      final author = _firstNonEmpty([oembed.author, capturedMeta.author]);
      final thumbnailUrl =
          _firstNonEmpty([oembed.thumbnailUrl, capturedMeta.thumbnailUrl]) ??
          'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

      if (capturedMeta.isLive) {
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
              'Live YouTube broadcasts cannot be downloaded as a file while '
              'streaming. Try again after the live stream finishes.',
        );
      }

      final options = _buildQualityOptions(manifest, title);
      if (options.isEmpty) {
        return UrlAnalysisResult.failure(
          originalUrl: uri.toString(),
          isValidUrl: true,
          isSupported: true,
          sourceId: id,
          sourceName: displayName,
          title: title,
          author: author,
          thumbnailUrl: thumbnailUrl,
          errorMessage:
              'No direct downloadable streams were found for this YouTube video.',
        );
      }

      final primary = options.first;
      final baseFileName = _sanitizeBaseName(title, fallback: 'youtube_$videoId');
      final fileName = '$baseFileName.${primary.format}';

      return UrlAnalysisResult(
        isValidUrl: true,
        isSupported: true,
        canDownload: true,
        sourceId: id,
        sourceName: displayName,
        originalUrl: uri.toString(),
        resolvedUrl: primary.downloadUrl,
        title: title,
        author: author,
        thumbnailUrl: thumbnailUrl,
        fileName: fileName,
        mimeType: primary.mimeType,
        extension: primary.format,
        mediaCategory: MediaLibraryCategory.classify(
          fileName: fileName,
          mimeType: primary.mimeType,
        ),
        fileSizeBytes: primary.fileSizeBytes,
        supportsResume: primary.supportsResume,
        qualityOptions: options,
      );
    } on RequestLimitExceededException {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isValidUrl: true,
        isSupported: true,
        isPlatformRestricted: true,
        sourceId: id,
        sourceName: displayName,
        errorMessage:
            'YouTube temporarily rate-limited requests from your current IP '
            'network. Please wait a moment, switch networks/Wi-Fi, or try again.',
      );
    } on VideoRequiresPurchaseException {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isValidUrl: true,
        isSupported: true,
        isPlatformRestricted: true,
        sourceId: id,
        sourceName: displayName,
        errorMessage:
            'This YouTube video requires purchase or membership and cannot be '
            'downloaded.',
      );
    } on VideoUnavailableException {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isValidUrl: true,
        isSupported: true,
        sourceId: id,
        sourceName: displayName,
        errorMessage:
            'This YouTube video is unavailable, private, or has been removed.',
      );
    } on VideoUnplayableException catch (e) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isValidUrl: true,
        isSupported: true,
        isPlatformRestricted: true,
        sourceId: id,
        sourceName: displayName,
        errorMessage:
            e.message.trim().isNotEmpty
                ? e.message.trim()
                : 'This YouTube video is unplayable (restricted or age-gated).',
      );
    } on TimeoutException {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isValidUrl: true,
        isSupported: true,
        sourceId: id,
        sourceName: displayName,
        errorMessage:
            'Timed out while fetching YouTube video streams. Check your connection and try again.',
      );
    } on SocketException catch (e) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isValidUrl: true,
        isSupported: true,
        sourceId: id,
        sourceName: displayName,
        errorMessage: 'Network error while contacting YouTube: ${e.message}.',
      );
    } catch (e) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isValidUrl: true,
        isSupported: true,
        sourceId: id,
        sourceName: displayName,
        errorMessage: 'Could not extract YouTube streams: $e',
      );
    } finally {
      yt.close();
    }
  }

  Future<_CapturedVideoMeta> _fetchOembedMeta(
    String videoId, {
    required http.Client client,
  }) async {
    final meta = _CapturedVideoMeta();
    try {
      final oembedUri = Uri.https('www.youtube.com', '/oembed', {
        'url': 'https://www.youtube.com/watch?v=$videoId',
        'format': 'json',
      });
      final resp = await client
          .get(oembedUri, headers: {'User-Agent': _modernBrowserUa})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) {
          meta.title = (decoded['title'] as String?)?.trim();
          meta.author = (decoded['author_name'] as String?)?.trim();
          meta.thumbnailUrl = (decoded['thumbnail_url'] as String?)?.trim();
        }
      }
    } catch (_) {}
    return meta;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  List<MediaQualityOption> _buildQualityOptions(
    StreamManifest manifest,
    String title,
  ) {
    final options = <MediaQualityOption>[];
    final safeBase = _sanitizeBaseName(title, fallback: 'youtube_media');
    final downloadHeaders = <String, String>{
      'User-Agent':
          YoutubeHttpClient.defaultHeaders['user-agent'] ?? _modernBrowserUa,
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
    };

    // 1. Muxed streams (Video + Audio combined in one playable file).
    final muxed = manifest.muxed.toList()
      ..sort((a, b) {
        final h = b.videoResolution.height.compareTo(a.videoResolution.height);
        return h != 0 ? h : b.bitrate.compareTo(a.bitrate);
      });

    var maxMuxedHeight = 0;
    for (final s in muxed) {
      if (s.fragments.isNotEmpty || _isHlsUrl(s.url)) continue;
      if (s.videoResolution.height > maxMuxedHeight) {
        maxMuxedHeight = s.videoResolution.height;
      }
      final ext = s.container.name.toLowerCase();
      final sizeBytes = s.size.totalBytes > 0 ? s.size.totalBytes : null;
      options.add(
        MediaQualityOption(
          id: 'yt_muxed_${s.tag}',
          label: '${s.qualityLabel} ${ext.toUpperCase()}',
          format: ext,
          resolution: '${s.qualityLabel} (Video + Audio)',
          codec: _shortVideoCodec(s.videoCodec),
          bitrateKbps: s.bitrate.kiloBitsPerSecond.round(),
          fileSizeBytes: sizeBytes,
          downloadUrl: s.url.toString(),
          isOriginal: true,
          supportsResume: true,
          mimeType: s.codec.mimeType,
          headers: downloadHeaders,
          chunkSizeBytes: _youtubeChunkBytes,
          fileName: '$safeBase.$ext',
        ),
      );
    }

    // Only fall back to adaptive streams when no muxed stream is available,
    // because YouTube enforces PO-token checks on adaptive chunks > ~1 MB.
    if (options.isNotEmpty) {
      return options;
    }

    // 2. Fallback: Audio-only streams (M4A / WEBM).
    final audioStreams =
        manifest.audioOnly
            .where((s) => s.fragments.isEmpty && !_isHlsUrl(s.url))
            .where(
              (s) => s.audioTrack == null || s.audioTrack!.audioIsDefault,
            )
            .toList()
          ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

    final seenAudioFormats = <String>{};
    for (final s in audioStreams) {
      final rawContainer = s.container.name.toLowerCase();
      final ext = rawContainer == 'mp4' ? 'm4a' : rawContainer;
      final kbps = s.bitrate.kiloBitsPerSecond.round();
      final dedupeKey = '$ext:${(kbps / 16).round()}';
      if (!seenAudioFormats.add(dedupeKey)) continue;

      final sizeBytes = s.size.totalBytes > 0 ? s.size.totalBytes : null;
      final mime = rawContainer == 'mp4' ? 'audio/mp4' : 'audio/$rawContainer';
      options.add(
        MediaQualityOption(
          id: 'yt_audio_${s.tag}',
          label: 'Audio ${ext.toUpperCase()} ($kbps kbps)',
          format: ext,
          resolution: 'Audio Only',
          codec: _shortAudioCodec(s.audioCodec),
          bitrateKbps: kbps,
          fileSizeBytes: sizeBytes,
          downloadUrl: s.url.toString(),
          isOriginal: false,
          supportsResume: true,
          mimeType: mime,
          headers: downloadHeaders,
          chunkSizeBytes: _youtubeChunkBytes,
          fileName: '$safeBase.$ext',
        ),
      );
      if (seenAudioFormats.length >= 4) break;
    }

    // 3. Fallback: High-res Video-only streams above the best muxed height.
    final videoOnly =
        manifest.videoOnly
            .where((s) => s.fragments.isEmpty && !_isHlsUrl(s.url))
            .where((s) => s.videoResolution.height > maxMuxedHeight)
            .toList()
          ..sort((a, b) {
            final h = b.videoResolution.height.compareTo(
              a.videoResolution.height,
            );
            if (h != 0) return h;
            final aScore = _videoContainerScore(a);
            final bScore = _videoContainerScore(b);
            if (aScore != bScore) return bScore.compareTo(aScore);
            return b.bitrate.compareTo(a.bitrate);
          });

    final seenResolutions = <String>{};
    for (final s in videoOnly) {
      if (!seenResolutions.add(s.qualityLabel)) continue;
      final ext = s.container.name.toLowerCase();
      final sizeBytes = s.size.totalBytes > 0 ? s.size.totalBytes : null;
      options.add(
        MediaQualityOption(
          id: 'yt_video_${s.tag}',
          label: '${s.qualityLabel} ${ext.toUpperCase()} (No Audio)',
          format: ext,
          resolution: '${s.qualityLabel} (Video Only)',
          codec: _shortVideoCodec(s.videoCodec),
          bitrateKbps: s.bitrate.kiloBitsPerSecond.round(),
          fileSizeBytes: sizeBytes,
          downloadUrl: s.url.toString(),
          isOriginal: false,
          supportsResume: true,
          mimeType: s.codec.mimeType,
          headers: downloadHeaders,
          chunkSizeBytes: _youtubeChunkBytes,
          fileName: '${safeBase}_${s.qualityLabel}.$ext',
        ),
      );
      if (seenResolutions.length >= 4) break;
    }

    return options;
  }

  static bool _isHlsUrl(Uri url) =>
      url.path.toLowerCase().endsWith('.m3u8');

  static int _videoContainerScore(VideoOnlyStreamInfo s) {
    final container = s.container.name.toLowerCase();
    final codec = s.videoCodec.toLowerCase();
    var score = container == 'mp4' ? 10 : 0;
    if (codec.startsWith('avc')) score += 5;
    if (codec.startsWith('vp9')) score += 3;
    return score;
  }

  static String _shortVideoCodec(String raw) {
    final lower = raw.toLowerCase();
    if (lower.startsWith('avc')) return 'H.264';
    if (lower.startsWith('av01')) return 'AV1';
    if (lower.startsWith('vp9') || lower.startsWith('vp09')) return 'VP9';
    return raw.split('.').first.toUpperCase();
  }

  static String _shortAudioCodec(String raw) {
    final lower = raw.toLowerCase();
    if (lower.startsWith('mp4a')) return 'AAC';
    if (lower.contains('opus')) return 'Opus';
    return raw.split('.').first.toUpperCase();
  }

  static String _sanitizeBaseName(String title, {required String fallback}) {
    var safe = FileZipUtils.safeFileName(title, fallback: fallback);
    safe = safe.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (safe.length > 64) {
      safe = safe.substring(0, 64).trim();
    }
    return safe.isEmpty ? fallback : safe;
  }
}

class _CapturedVideoMeta {
  String? title;
  String? author;
  String? thumbnailUrl;
  bool isLive = false;
}

/// Delegates HTTP calls to [_inner] without closing it when [YoutubeExplode]
/// closes, and captures `videoDetails` from `/youtubei/v1/player` responses so
/// we never need to request the rate-limited `/watch` HTML page.
class _YouTubeProxyClient extends http.BaseClient {
  final http.Client _inner;
  final _CapturedVideoMeta _meta;

  _YouTubeProxyClient(this._inner, this._meta);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Strip the stale CONSENT cookie on InnerTube API calls and modernize UA
    // if YoutubeHttpClient injected its 2021 Chrome/96 default header.
    if (request.url.path.contains('/youtubei/')) {
      request.headers.remove('cookie');
      request.headers.remove('Cookie');
    }
    final ua = request.headers['user-agent'] ?? request.headers['User-Agent'];
    if (ua != null && ua.contains('Chrome/96.')) {
      request.headers.remove('user-agent');
      request.headers['User-Agent'] = YouTubeSourceAdapter._modernBrowserUa;
    }

    final response = await _inner.send(request);
    if (!request.url.path.contains('/youtubei/v1/player') ||
        response.statusCode != 200) {
      return response;
    }

    // Buffer the player JSON once so we can read videoDetails and still pass
    // the exact bytes through to YoutubeExplode.
    final bytes = await response.stream.toBytes();
    _tryExtractPlayerMeta(bytes);
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  void _tryExtractPlayerMeta(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      if (decoded is! Map<String, dynamic>) return;
      final details = decoded['videoDetails'];
      if (details is Map<String, dynamic>) {
        final t = (details['title'] as String?)?.trim();
        final a = (details['author'] as String?)?.trim();
        if (t != null && t.isNotEmpty) _meta.title ??= t;
        if (a != null && a.isNotEmpty) _meta.author ??= a;
        if (details['isLiveContent'] == true || details['isLive'] == true) {
          _meta.isLive = true;
        }
        final thumbs = details['thumbnail'];
        if (thumbs is Map && thumbs['thumbnails'] is List) {
          final list = thumbs['thumbnails'] as List;
          if (list.isNotEmpty && list.last is Map) {
            final url = (list.last['url'] as String?)?.trim();
            if (url != null && url.isNotEmpty) {
              _meta.thumbnailUrl ??= url;
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  void close() {
    // Intentionally a no-op: lifecycle is managed by the caller.
  }
}
