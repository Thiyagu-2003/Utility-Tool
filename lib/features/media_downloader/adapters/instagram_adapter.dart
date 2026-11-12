import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../file_tools/file_zip_utils.dart';
import '../models/media_downloader_models.dart';
import '../services/url_security_validator.dart';
import 'media_source_adapter.dart';

/// Independent adapter for Instagram URLs (Reels, Posts, IGTV, Carousels,
/// and Share links).
class InstagramSourceAdapter implements MediaSourceAdapter {
  static const Set<String> _hosts = {
    'instagram.com',
    'www.instagram.com',
    'm.instagram.com',
    'instagr.am',
  };

  static const String _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const String _igAppId = '936619743392459';
  static const String _defaultLsd = 'AVqbxe3J_YA';
  static const String _graphqlDocId = '8845758582119845';

  @override
  String get id => 'instagram';

  @override
  String get displayName => 'Instagram';

  @override
  bool canHandle(Uri uri) => _hosts.contains(uri.host.toLowerCase());

  /// Extracts `(kindSegment, shortcode)` from an Instagram URL when present.
  static ({String kind, String? shortcode}) parseUrlInfo(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i].toLowerCase();
      if (seg == 'reel' || seg == 'reels' || seg == 'p' || seg == 'tv') {
        final code =
            (i + 1 < segments.length && segments[i + 1].isNotEmpty)
                ? segments[i + 1]
                : null;
        final normalizedKind = (seg == 'reels') ? 'reel' : seg;
        return (kind: normalizedKind, shortcode: code);
      }
    }
    return (kind: 'p', shortcode: null);
  }

  static String _kindLabel(String kind, List<String> segments) {
    final lower = segments.map((s) => s.toLowerCase()).toList();
    if (lower.contains('reel') || lower.contains('reels') || kind == 'reel') {
      return 'Instagram Reel';
    }
    if (lower.contains('stories')) return 'Instagram Story';
    if (lower.contains('tv') || kind == 'tv') return 'Instagram Video';
    return 'Instagram Post';
  }

  @override
  Future<UrlAnalysisResult> analyze(
    Uri uri, {
    required http.Client client,
  }) async {
    var parsed = parseUrlInfo(uri);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    var kindLabel = _kindLabel(parsed.kind, segments);

    final pageHeaders = <String, String>{
      'User-Agent': _browserUserAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Upgrade-Insecure-Requests': '1',
    };

    String? htmlBody;
    String? csrfToken;
    String? lsdToken;
    String? cookieHeader;

    try {
      // Strategy 1: Fetch the canonical post/reel page (or follow /share/ redirects).
      final targetUri =
          parsed.shortcode != null
              ? Uri.https(
                'www.instagram.com',
                '/${parsed.kind}/${parsed.shortcode}/',
              )
              : uri;

      final resp = await UrlSecurityValidator.sendWithSafeRedirects(
        client: client,
        method: 'GET',
        uri: targetUri,
        headers: pageHeaders,
        timeout: const Duration(seconds: 20),
      );
      final bodyBytes = await resp.response.stream.toBytes();
      if (resp.response.statusCode >= 200 && resp.response.statusCode < 300) {
        htmlBody = utf8.decode(bodyBytes, allowMalformed: true);
        final resolvedInfo = parseUrlInfo(resp.finalUri);
        if (resolvedInfo.shortcode != null) {
          parsed = resolvedInfo;
          kindLabel = _kindLabel(
            parsed.kind,
            resp.finalUri.pathSegments.where((s) => s.isNotEmpty).toList(),
          );
        }
        final setCookie = resp.response.headers['set-cookie'] ?? '';
        csrfToken = RegExp(r'csrftoken=([^;]+)').firstMatch(setCookie)?.group(1);
        final cookieParts = <String>[];
        for (final match in RegExp(
          r'(?:^|,)\s*([A-Za-z0-9_]+=[^;,\s]+)',
        ).allMatches(setCookie)) {
          final kv = match.group(1);
          if (kv != null) cookieParts.add(kv);
        }
        if (cookieParts.isNotEmpty) {
          cookieHeader = cookieParts.join('; ');
        }
        lsdToken =
            RegExp(r'"LSD",\[\],\{"token":"([^"]+)"')
                .firstMatch(htmlBody)
                ?.group(1);

        final extracted = _extractFromHtml(
          htmlBody,
          shortcode: parsed.shortcode,
          defaultTitle: kindLabel,
        );
        if (extracted != null && extracted.options.isNotEmpty) {
          return await _buildSuccessResult(
            originalUrl: uri.toString(),
            extracted: extracted,
            shortcode: parsed.shortcode,
            client: client,
          );
        }
      }

      // Strategy 2: Embed captioned page fallback.
      if (parsed.shortcode != null) {
        final embedUri = Uri.https(
          'www.instagram.com',
          '/p/${parsed.shortcode}/embed/captioned/',
        );
        final embedResp = await UrlSecurityValidator.sendWithSafeRedirects(
          client: client,
          method: 'GET',
          uri: embedUri,
          headers: pageHeaders,
          timeout: const Duration(seconds: 15),
        );
        final embedBytes = await embedResp.response.stream.toBytes();
        if (embedResp.response.statusCode >= 200 &&
            embedResp.response.statusCode < 300) {
          final embedHtml = utf8.decode(embedBytes, allowMalformed: true);
          final extracted = _extractFromHtml(
            embedHtml,
            shortcode: parsed.shortcode,
            defaultTitle: kindLabel,
          );
          if (extracted != null && extracted.options.isNotEmpty) {
            return await _buildSuccessResult(
              originalUrl: uri.toString(),
              extracted: extracted,
              shortcode: parsed.shortcode,
              client: client,
            );
          }
        }
      }

      // Strategy 3: Public Web GraphQL query fallback.
      if (parsed.shortcode != null) {
        final gqlExtracted = await _tryGraphqlFallback(
          client: client,
          shortcode: parsed.shortcode!,
          defaultTitle: kindLabel,
          csrfToken: csrfToken,
          lsdToken: lsdToken,
          cookieHeader: cookieHeader,
        );
        if (gqlExtracted != null && gqlExtracted.options.isNotEmpty) {
          return await _buildSuccessResult(
            originalUrl: uri.toString(),
            extracted: gqlExtracted,
            shortcode: parsed.shortcode,
            client: client,
          );
        }
      }
    } on TimeoutException {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isValidUrl: true,
        isSupported: true,
        sourceId: id,
        sourceName: displayName,
        title: kindLabel,
        errorMessage:
            'Timed out while contacting Instagram. Please check your connection and try again.',
      );
    } on SocketException catch (e) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isValidUrl: true,
        isSupported: true,
        sourceId: id,
        sourceName: displayName,
        title: kindLabel,
        errorMessage: 'Network error while contacting Instagram: ${e.message}.',
      );
    } catch (e) {
      return UrlAnalysisResult.failure(
        originalUrl: uri.toString(),
        isValidUrl: true,
        isSupported: true,
        sourceId: id,
        sourceName: displayName,
        title: kindLabel,
        errorMessage: 'Failed to analyze Instagram URL: $e',
      );
    }

    return UrlAnalysisResult.failure(
      originalUrl: uri.toString(),
      isValidUrl: true,
      isSupported: true,
      isPlatformRestricted: true,
      sourceId: id,
      sourceName: displayName,
      title: kindLabel,
      errorMessage:
          'Could not extract downloadable media from this Instagram link. '
          'The post or Reel may be private, deleted, require login, or be '
          'temporarily rate-limited.',
    );
  }

  Future<_IgExtraction?> _tryGraphqlFallback({
    required http.Client client,
    required String shortcode,
    required String defaultTitle,
    String? csrfToken,
    String? lsdToken,
    String? cookieHeader,
  }) async {
    try {
      final lsd = lsdToken ?? _defaultLsd;
      final gqlHeaders = <String, String>{
        'User-Agent': _browserUserAgent,
        'X-IG-App-ID': _igAppId,
        'X-FB-LSD': lsd,
        'X-ASBD-ID': '129477',
        'Sec-Fetch-Site': 'same-origin',
        'Referer': 'https://www.instagram.com/reel/$shortcode/',
        'X-CSRFToken': ?csrfToken,
        'Cookie': ?cookieHeader,
      };
      final response = await client
          .post(
            Uri.https('www.instagram.com', '/graphql/query'),
            headers: gqlHeaders,
            body: {
              'av': '0',
              '__d': 'www',
              '__user': '0',
              '__a': '1',
              '__req': '3',
              'lsd': lsd,
              'fb_api_caller_class': 'RelayModern',
              'fb_api_req_friendly_name': 'PolarisPostActionLoadPostQueryQuery',
              'variables': jsonEncode({
                'shortcode': shortcode,
                'fetch_tagged_user_count': null,
                'hoisted_comment_id': null,
                'hoisted_reply_id': null,
              }),
              'server_timestamps': 'true',
              'doc_id': _graphqlDocId,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final ct = (response.headers['content-type'] ?? '').toLowerCase();
      if (!ct.contains('json') && !response.body.trimLeft().startsWith('{')) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      return _extractFromDecodedJson(
        decoded,
        shortcode: shortcode,
        defaultTitle: defaultTitle,
      );
    } catch (_) {
      return null;
    }
  }

  Future<UrlAnalysisResult> _buildSuccessResult({
    required String originalUrl,
    required _IgExtraction extracted,
    required String? shortcode,
    required http.Client client,
  }) async {
    var options = extracted.options;
    final primary = options.first;

    int? probedSize = primary.fileSizeBytes;
    bool supportsResume = primary.supportsResume;

    // Best-effort HEAD probe so the analysis card displays file size & resume status.
    if (probedSize == null) {
      try {
        final headResp = await UrlSecurityValidator.sendWithSafeRedirects(
          client: client,
          method: 'HEAD',
          uri: Uri.parse(primary.downloadUrl),
          headers: primary.headers,
          timeout: const Duration(seconds: 6),
        );
        await headResp.response.stream.drain<void>();
        if (headResp.response.statusCode >= 200 &&
            headResp.response.statusCode < 300) {
          final cl = int.tryParse(
            headResp.response.headers['content-length'] ?? '',
          );
          if (cl != null && cl > 0) {
            probedSize = cl;
          }
          final ar =
              (headResp.response.headers['accept-ranges'] ?? '').toLowerCase();
          if (ar.contains('bytes')) {
            supportsResume = true;
          }
        }
      } catch (_) {
        // Non-fatal; download can still proceed without pre-probed size.
      }
    }

    if (probedSize != primary.fileSizeBytes ||
        supportsResume != primary.supportsResume) {
      options = [
        MediaQualityOption(
          id: primary.id,
          label: primary.label,
          format: primary.format,
          resolution: primary.resolution,
          codec: primary.codec,
          bitrateKbps: primary.bitrateKbps,
          fileSizeBytes: probedSize,
          downloadUrl: primary.downloadUrl,
          isOriginal: primary.isOriginal,
          supportsResume: supportsResume,
          mimeType: primary.mimeType,
          headers: primary.headers,
          fileName: primary.fileName,
        ),
        ...options.skip(1),
      ];
    }

    final updatedPrimary = options.first;
    final fileName =
        updatedPrimary.fileName ??
        '${_sanitizeBaseName(extracted.title, fallback: 'instagram_${shortcode ?? 'media'}')}.${updatedPrimary.format}';

    return UrlAnalysisResult(
      isValidUrl: true,
      isSupported: true,
      canDownload: true,
      sourceId: id,
      sourceName: displayName,
      originalUrl: originalUrl,
      resolvedUrl: updatedPrimary.downloadUrl,
      title: extracted.title,
      author: extracted.author,
      thumbnailUrl: extracted.thumbnailUrl,
      fileName: fileName,
      mimeType: updatedPrimary.mimeType,
      extension: updatedPrimary.format,
      mediaCategory: MediaLibraryCategory.classify(
        fileName: fileName,
        mimeType: updatedPrimary.mimeType,
      ),
      fileSizeBytes: updatedPrimary.fileSizeBytes,
      supportsResume: updatedPrimary.supportsResume,
      qualityOptions: options,
    );
  }

  _IgExtraction? _extractFromHtml(
    String html, {
    required String? shortcode,
    required String defaultTitle,
  }) {
    // 1. Parse all embedded <script type="application/json"> payloads.
    final scriptMatches = RegExp(
      r'<script[^>]*type="application/json"[^>]*>(.*?)</script>',
      dotAll: true,
      caseSensitive: false,
    ).allMatches(html);

    for (final match in scriptMatches) {
      final raw = match.group(1);
      if (raw == null || raw.isEmpty) continue;
      if (!raw.contains('video_versions') &&
          !raw.contains('image_versions2') &&
          !raw.contains('carousel_media') &&
          !raw.contains('video_url') &&
          !raw.contains('display_url')) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        final res = _extractFromDecodedJson(
          decoded,
          shortcode: shortcode,
          defaultTitle: defaultTitle,
        );
        if (res != null && res.options.isNotEmpty) {
          return res;
        }
      } catch (_) {}
    }

    // 2. Check legacy window.__additionalDataLoaded / gql_data script blocks.
    final additionalMatch = RegExp(
      r"window\.__additionalDataLoaded\([^,]+,\s*(\{.*?\})\s*\)\s*;",
      dotAll: true,
    ).firstMatch(html);
    if (additionalMatch != null) {
      try {
        final decoded = jsonDecode(additionalMatch.group(1)!);
        final res = _extractFromDecodedJson(
          decoded,
          shortcode: shortcode,
          defaultTitle: defaultTitle,
        );
        if (res != null && res.options.isNotEmpty) {
          return res;
        }
      } catch (_) {}
    }

    // 3. Fallback: OpenGraph meta tags & escaped video_url regex.
    final ogVideo =
        _extractMetaContent(html, 'og:video:secure_url') ??
        _extractMetaContent(html, 'og:video');
    final ogImage = _extractMetaContent(html, 'og:image');
    final ogTitle = _extractMetaContent(html, 'og:title');

    final downloadHeaders = _downloadHeaders();
    final safeBase = _sanitizeBaseName(
      ogTitle ?? defaultTitle,
      fallback: 'instagram_${shortcode ?? 'media'}',
    );

    final options = <MediaQualityOption>[];
    if (ogVideo != null) {
      final clean = _cleanExtractedUrl(ogVideo);
      if (clean != null) {
        options.add(
          MediaQualityOption(
            id: 'ig_og_video',
            label: 'Video MP4',
            format: 'mp4',
            resolution: 'Original Video',
            downloadUrl: clean,
            supportsResume: true,
            mimeType: 'video/mp4',
            headers: downloadHeaders,
            fileName: '$safeBase.mp4',
          ),
        );
      }
    }

    // Look for JSON-escaped video_url in inline scripts.
    if (options.isEmpty) {
      final videoUrlMatch = RegExp(
        r'"video_url"\s*:\s*"(https?:\\?/\\?/[^"]+)"',
      ).firstMatch(html);
      if (videoUrlMatch != null) {
        final clean = _cleanExtractedUrl(videoUrlMatch.group(1)!);
        if (clean != null) {
          options.add(
            MediaQualityOption(
              id: 'ig_inline_video',
              label: 'Video MP4',
              format: 'mp4',
              resolution: 'Original Video',
              downloadUrl: clean,
              supportsResume: true,
              mimeType: 'video/mp4',
              headers: downloadHeaders,
              fileName: '$safeBase.mp4',
            ),
          );
        }
      }
    }

    final cleanThumb = ogImage != null ? _cleanExtractedUrl(ogImage) : null;
    if (options.isEmpty && cleanThumb != null) {
      options.add(
        MediaQualityOption(
          id: 'ig_og_image',
          label: 'Image JPG',
          format: 'jpg',
          resolution: 'Original Image',
          downloadUrl: cleanThumb,
          supportsResume: true,
          mimeType: 'image/jpeg',
          headers: downloadHeaders,
          fileName: '$safeBase.jpg',
        ),
      );
    }

    if (options.isEmpty) return null;

    final title = _cleanTitle(ogTitle) ?? defaultTitle;
    return _IgExtraction(
      title: title,
      author: null,
      thumbnailUrl: cleanThumb,
      options: options,
    );
  }

  _IgExtraction? _extractFromDecodedJson(
    dynamic root, {
    required String? shortcode,
    required String defaultTitle,
  }) {
    final candidates = <Map<String, dynamic>>[];

    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final hasMedia =
            node.containsKey('video_versions') ||
            node.containsKey('carousel_media') ||
            node.containsKey('video_url') ||
            node.containsKey('edge_sidecar_to_children') ||
            (node.containsKey('image_versions2') &&
                (node.containsKey('code') || node.containsKey('pk'))) ||
            (node.containsKey('display_url') &&
                (node.containsKey('shortcode') || node.containsKey('id')));
        if (hasMedia) {
          candidates.add(node);
        }
        for (final v in node.values) {
          walk(v);
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item);
        }
      }
    }

    walk(root);
    if (candidates.isEmpty) return null;

    // Prefer the node whose code/shortcode matches the requested URL shortcode.
    Map<String, dynamic> target = candidates.first;
    if (shortcode != null && shortcode.isNotEmpty) {
      for (final c in candidates) {
        final nodeCode = (c['code'] ?? c['shortcode']) as String?;
        if (nodeCode == shortcode) {
          target = c;
          break;
        }
      }
    }

    final author = _extractAuthor(target);
    final caption = _extractCaption(target);
    final title =
        _cleanTitle(caption) ??
        (author != null ? '$defaultTitle by $author' : defaultTitle);
    final safeBase = _sanitizeBaseName(
      title,
      fallback: 'instagram_${shortcode ?? 'media'}',
    );
    final thumbnailUrl = _extractBestImageUrl(target);
    final downloadHeaders = _downloadHeaders();

    final options = <MediaQualityOption>[];

    // 1. Carousel / sidecar posts (multiple videos or images).
    final carousel = target['carousel_media'];
    if (carousel is List && carousel.isNotEmpty) {
      for (var i = 0; i < carousel.length; i++) {
        final slide = carousel[i];
        if (slide is! Map<String, dynamic>) continue;
        final slideVideos = _extractVideoVersions(slide);
        if (slideVideos.isNotEmpty) {
          final best = slideVideos.first;
          final res =
              (best.width != null && best.height != null)
                  ? '${best.width}×${best.height}'
                  : 'Video';
          options.add(
            MediaQualityOption(
              id: 'ig_slide_${i + 1}_video',
              label: 'Slide ${i + 1} Video ($res)',
              format: 'mp4',
              resolution: 'Slide ${i + 1} • $res',
              downloadUrl: best.url,
              supportsResume: true,
              mimeType: 'video/mp4',
              headers: downloadHeaders,
              fileName: '${safeBase}_slide_${i + 1}.mp4',
            ),
          );
        } else {
          final slideImgs = _extractImageCandidates(slide);
          if (slideImgs.isNotEmpty) {
            final best = slideImgs.first;
            final res =
                (best.width != null && best.height != null)
                    ? '${best.width}×${best.height}'
                    : 'Photo';
            options.add(
              MediaQualityOption(
                id: 'ig_slide_${i + 1}_image',
                label: 'Slide ${i + 1} Photo ($res)',
                format: 'jpg',
                resolution: 'Slide ${i + 1} • $res',
                downloadUrl: best.url,
                supportsResume: true,
                mimeType: 'image/jpeg',
                headers: downloadHeaders,
                fileName: '${safeBase}_slide_${i + 1}.jpg',
              ),
            );
          }
        }
      }
    }

    // Legacy GraphQL sidecar format.
    if (options.isEmpty) {
      final sidecar = target['edge_sidecar_to_children'];
      if (sidecar is Map && sidecar['edges'] is List) {
        final edges = sidecar['edges'] as List;
        for (var i = 0; i < edges.length; i++) {
          final edge = edges[i];
          if (edge is! Map || edge['node'] is! Map<String, dynamic>) continue;
          final node = edge['node'] as Map<String, dynamic>;
          final videoUrl = _cleanExtractedUrl(node['video_url'] as String?);
          final displayUrl = _cleanExtractedUrl(node['display_url'] as String?);
          if (videoUrl != null) {
            options.add(
              MediaQualityOption(
                id: 'ig_sidecar_${i + 1}_video',
                label: 'Slide ${i + 1} Video (MP4)',
                format: 'mp4',
                resolution: 'Slide ${i + 1} • Video',
                downloadUrl: videoUrl,
                supportsResume: true,
                mimeType: 'video/mp4',
                headers: downloadHeaders,
                fileName: '${safeBase}_slide_${i + 1}.mp4',
              ),
            );
          } else if (displayUrl != null) {
            options.add(
              MediaQualityOption(
                id: 'ig_sidecar_${i + 1}_image',
                label: 'Slide ${i + 1} Photo (JPG)',
                format: 'jpg',
                resolution: 'Slide ${i + 1} • Photo',
                downloadUrl: displayUrl,
                supportsResume: true,
                mimeType: 'image/jpeg',
                headers: downloadHeaders,
                fileName: '${safeBase}_slide_${i + 1}.jpg',
              ),
            );
          }
        }
      }
    }

    // 2. Single Reel / Video (`video_versions` or `video_url`).
    if (options.isEmpty) {
      final videos = _extractVideoVersions(target);
      for (var i = 0; i < videos.length && i < 4; i++) {
        final v = videos[i];
        final res =
            (v.width != null && v.height != null)
                ? '${v.width}×${v.height}'
                : (i == 0 ? 'HD Video' : 'Variant ${i + 1}');
        options.add(
          MediaQualityOption(
            id: 'ig_video_${i + 1}',
            label: i == 0 ? 'Best MP4 ($res)' : 'MP4 ($res)',
            format: 'mp4',
            resolution: res,
            downloadUrl: v.url,
            isOriginal: i == 0,
            supportsResume: true,
            mimeType: 'video/mp4',
            headers: downloadHeaders,
            fileName: '$safeBase.mp4',
          ),
        );
      }
      if (videos.isNotEmpty) {
        options.add(
          MediaQualityOption(
            id: 'ig_audio_m4a',
            label: 'Audio M4A (AAC)',
            format: 'm4a',
            resolution: 'Audio Only',
            codec: 'AAC',
            downloadUrl: videos.first.url,
            isOriginal: false,
            supportsResume: true,
            mimeType: 'audio/mp4',
            headers: downloadHeaders,
            fileName: '$safeBase.m4a',
            extractAudioOnly: true,
          ),
        );
      }
    }

    // 3. Single Photo post (`image_versions2` or `display_url`).
    if (options.isEmpty) {
      final images = _extractImageCandidates(target);
      for (var i = 0; i < images.length && i < 3; i++) {
        final img = images[i];
        final res =
            (img.width != null && img.height != null)
                ? '${img.width}×${img.height}'
                : (i == 0 ? 'Original' : 'Variant ${i + 1}');
        options.add(
          MediaQualityOption(
            id: 'ig_image_${i + 1}',
            label: i == 0 ? 'Original Photo ($res)' : 'Photo ($res)',
            format: 'jpg',
            resolution: res,
            downloadUrl: img.url,
            isOriginal: i == 0,
            supportsResume: true,
            mimeType: 'image/jpeg',
            headers: downloadHeaders,
            fileName: '$safeBase.jpg',
          ),
        );
      }
    }

    if (options.isEmpty) return null;
    return _IgExtraction(
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      options: options,
    );
  }

  static List<_IgMediaCandidate> _extractVideoVersions(
    Map<String, dynamic> node,
  ) {
    final results = <_IgMediaCandidate>[];
    final seenUrls = <String>{};

    final vv = node['video_versions'];
    if (vv is List) {
      for (final item in vv) {
        if (item is! Map) continue;
        final clean = _cleanExtractedUrl(item['url'] as String?);
        if (clean == null || !seenUrls.add(clean)) continue;
        final w = _asInt(item['width']);
        final h = _asInt(item['height']);
        results.add(_IgMediaCandidate(url: clean, width: w, height: h));
      }
    }

    final directVideoUrl = _cleanExtractedUrl(node['video_url'] as String?);
    if (directVideoUrl != null && seenUrls.add(directVideoUrl)) {
      final dims = node['dimensions'];
      final w = dims is Map ? _asInt(dims['width']) : _asInt(node['original_width']);
      final h = dims is Map ? _asInt(dims['height']) : _asInt(node['original_height']);
      results.add(_IgMediaCandidate(url: directVideoUrl, width: w, height: h));
    }

    results.sort((a, b) => b.area.compareTo(a.area));
    return results;
  }

  static List<_IgMediaCandidate> _extractImageCandidates(
    Map<String, dynamic> node,
  ) {
    final results = <_IgMediaCandidate>[];
    final seenUrls = <String>{};

    final iv = node['image_versions2'];
    if (iv is Map && iv['candidates'] is List) {
      for (final item in iv['candidates'] as List) {
        if (item is! Map) continue;
        final clean = _cleanExtractedUrl(item['url'] as String?);
        if (clean == null || !seenUrls.add(clean)) continue;
        results.add(
          _IgMediaCandidate(
            url: clean,
            width: _asInt(item['width']),
            height: _asInt(item['height']),
          ),
        );
      }
    }

    final displayUrl = _cleanExtractedUrl(node['display_url'] as String?);
    if (displayUrl != null && seenUrls.add(displayUrl)) {
      final dims = node['dimensions'];
      results.add(
        _IgMediaCandidate(
          url: displayUrl,
          width: dims is Map ? _asInt(dims['width']) : null,
          height: dims is Map ? _asInt(dims['height']) : null,
        ),
      );
    }

    results.sort((a, b) => b.area.compareTo(a.area));
    return results;
  }

  static String? _extractBestImageUrl(Map<String, dynamic> node) {
    final imgs = _extractImageCandidates(node);
    if (imgs.isNotEmpty) return imgs.first.url;
    final carousel = node['carousel_media'];
    if (carousel is List && carousel.isNotEmpty && carousel.first is Map<String, dynamic>) {
      final slideImgs = _extractImageCandidates(carousel.first as Map<String, dynamic>);
      if (slideImgs.isNotEmpty) return slideImgs.first.url;
    }
    return null;
  }

  static String? _extractAuthor(Map<String, dynamic> node) {
    final user = node['user'] ?? node['owner'];
    if (user is Map) {
      final username = (user['username'] as String?)?.trim();
      if (username != null && username.isNotEmpty) {
        return username.startsWith('@') ? username : '@$username';
      }
      final fullName = (user['full_name'] as String?)?.trim();
      if (fullName != null && fullName.isNotEmpty) return fullName;
    }
    return null;
  }

  static String? _extractCaption(Map<String, dynamic> node) {
    final cap = node['caption'];
    if (cap is Map) {
      final text = (cap['text'] as String?)?.trim();
      if (text != null && text.isNotEmpty) return text;
    } else if (cap is String && cap.trim().isNotEmpty) {
      return cap.trim();
    }
    final edges = node['edge_media_to_caption'];
    if (edges is Map && edges['edges'] is List && (edges['edges'] as List).isNotEmpty) {
      final first = (edges['edges'] as List).first;
      if (first is Map && first['node'] is Map) {
        final text = (first['node']['text'] as String?)?.trim();
        if (text != null && text.isNotEmpty) return text;
      }
    }
    return null;
  }

  static String? _extractMetaContent(String html, String property) {
    final p1 = RegExp(
      '<meta[^>]+(?:property|name)=["\']${RegExp.escape(property)}["\'][^>]+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    ).firstMatch(html);
    if (p1 != null) return p1.group(1);

    final p2 = RegExp(
      '<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']${RegExp.escape(property)}["\']',
      caseSensitive: false,
    ).firstMatch(html);
    return p2?.group(1);
  }

  static String? _cleanExtractedUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var cleaned = raw
        .trim()
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0026', '&')
        .replaceAll('&amp;', '&');
    final check = UrlSecurityValidator.validate(cleaned);
    return check.isValid ? check.uri.toString() : null;
  }

  static String? _cleanTitle(String? raw) {
    if (raw == null) return null;
    final firstLine = raw
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) return null;
    return firstLine.length > 90
        ? '${firstLine.substring(0, 90).trim()}...'
        : firstLine;
  }

  static String _sanitizeBaseName(String title, {required String fallback}) {
    var safe = FileZipUtils.safeFileName(title, fallback: fallback);
    safe = safe.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (safe.length > 56) {
      safe = safe.substring(0, 56).trim();
    }
    return safe.isEmpty ? fallback : safe;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Map<String, String> _downloadHeaders() => const {
    'User-Agent': _browserUserAgent,
    'Referer': 'https://www.instagram.com/',
  };
}

class _IgMediaCandidate {
  final String url;
  final int? width;
  final int? height;

  const _IgMediaCandidate({required this.url, this.width, this.height});

  int get area => (width ?? 0) * (height ?? 0);
}

class _IgExtraction {
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final List<MediaQualityOption> options;

  const _IgExtraction({
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.options,
  });
}
