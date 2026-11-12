import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/core/services/preferences_service.dart';
import 'package:utility_tool/core/theme/app_theme.dart';
import 'package:utility_tool/features/media_downloader/adapters/facebook_adapter.dart';
import 'package:utility_tool/features/media_downloader/adapters/instagram_adapter.dart';
import 'package:utility_tool/features/media_downloader/adapters/media_source_adapter.dart';
import 'package:utility_tool/features/media_downloader/adapters/x_adapter.dart';
import 'package:utility_tool/features/media_downloader/adapters/youtube_adapter.dart';
import 'package:utility_tool/features/media_downloader/models/media_downloader_models.dart';
import 'package:utility_tool/features/media_downloader/services/download_manager_service.dart';
import 'package:utility_tool/features/media_downloader/services/platform_storage_service.dart';
import 'package:utility_tool/features/media_downloader/services/url_security_validator.dart';
import 'package:utility_tool/features/media_downloader/ui/media_downloader_screen.dart';

Uint8List _makeSampleBytes(List<int> header, int totalLength) {
  final bytes = Uint8List(totalLength);
  for (var i = 0; i < header.length && i < totalLength; i++) {
    bytes[i] = header[i];
  }
  for (var i = header.length; i < totalLength; i++) {
    bytes[i] = (i * 31 + 7) & 0xFF;
  }
  return bytes;
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  late HttpServer server;
  late String baseUrl;
  late Directory tempDir;

  late Uint8List mp4Bytes;
  late Uint8List mp3Bytes;
  late Uint8List pngBytes;
  late Uint8List pdfBytes;
  late Uint8List largeBytes;
  late Uint8List slowResumableBytes;
  late Uint8List interruptBytes;
  var interruptAttempts = 0;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    mp4Bytes = _makeSampleBytes(
      [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32],
      24 * 1024,
    );
    mp3Bytes = _makeSampleBytes([0x49, 0x44, 0x33, 0x03, 0x00], 16 * 1024);
    pngBytes = _makeSampleBytes(
      [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      8 * 1024,
    );
    pdfBytes = _makeSampleBytes(
      [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34],
      12 * 1024,
    );
    largeBytes = _makeSampleBytes([0x00, 0x00, 0x00, 0x18], 6 * 1024 * 1024);
    slowResumableBytes = _makeSampleBytes(
      [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70],
      256 * 1024,
    );
    interruptBytes = _makeSampleBytes(
      [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70],
      96 * 1024,
    );

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';

    server.listen((HttpRequest req) async {
      final path = req.uri.path;
      if (path == '/page.html') {
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.html;
        req.response.write('<html><body>Hello</body></html>');
        await req.response.close();
        return;
      }

      if (path == '/installer.exe') {
        req.response.statusCode = 200;
        req.response.headers.set('content-type', 'application/x-msdownload');
        req.response.headers.contentLength = 1024;
        if (req.method != 'HEAD') {
          req.response.add(Uint8List(1024));
        }
        await req.response.close();
        return;
      }

      if (path == '/redirect.mp4') {
        req.response.statusCode = 302;
        req.response.headers.set('location', '$baseUrl/sample.mp4');
        await req.response.close();
        return;
      }

      if (path == '/interrupt.mp4') {
        req.response.headers.set('accept-ranges', 'bytes');
        req.response.headers.set('content-type', 'video/mp4');
        if (req.method == 'HEAD') {
          req.response.statusCode = 200;
          req.response.headers.contentLength = interruptBytes.length;
          await req.response.close();
          return;
        }
        interruptAttempts++;
        final rangeHeader = req.headers.value('range');
        if (interruptAttempts == 1 && rangeHeader == null) {
          final socket = await req.response.detachSocket(writeHeaders: false);
          socket.write(
            'HTTP/1.1 200 OK\r\n'
            'Content-Type: video/mp4\r\n'
            'Accept-Ranges: bytes\r\n'
            'Content-Length: ${interruptBytes.length}\r\n\r\n',
          );
          socket.add(interruptBytes.sublist(0, 32 * 1024));
          await socket.flush();
          socket.destroy();
          return;
        }
        var start = 0;
        if (rangeHeader != null) {
          final m = RegExp(r'bytes=(\d+)-').firstMatch(rangeHeader);
          if (m != null) start = int.parse(m.group(1)!);
        }
        final slice = interruptBytes.sublist(start);
        req.response.statusCode = start > 0 ? 206 : 200;
        if (start > 0) {
          req.response.headers.set(
            'content-range',
            'bytes $start-${interruptBytes.length - 1}/${interruptBytes.length}',
          );
        }
        req.response.headers.contentLength = slice.length;
        req.response.add(slice);
        await req.response.close();
        return;
      }

      Uint8List? payload;
      String? mime;
      var slowChunked = false;

      switch (path) {
        case '/sample.mp4':
          payload = mp4Bytes;
          mime = 'video/mp4';
          break;
        case '/sample.mp3':
          payload = mp3Bytes;
          mime = 'audio/mpeg';
          break;
        case '/sample.png':
          payload = pngBytes;
          mime = 'image/png';
          break;
        case '/sample.pdf':
          payload = pdfBytes;
          mime = 'application/pdf';
          break;
        case '/large.bin':
          payload = largeBytes;
          mime = 'application/octet-stream';
          break;
        case '/slow-resumable.mp4':
          payload = slowResumableBytes;
          mime = 'video/mp4';
          slowChunked = true;
          break;
      }

      if (payload == null || mime == null) {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }

      req.response.headers.set('accept-ranges', 'bytes');
      req.response.headers.set('content-type', mime);

      if (req.method == 'HEAD') {
        req.response.statusCode = 200;
        req.response.headers.contentLength = payload.length;
        await req.response.close();
        return;
      }

      var start = 0;
      final rangeHeader = req.headers.value('range');
      if (rangeHeader != null) {
        final m = RegExp(r'bytes=(\d+)-').firstMatch(rangeHeader);
        if (m != null) start = int.parse(m.group(1)!);
      }

      if (start >= payload.length) {
        req.response.statusCode = 416;
        await req.response.close();
        return;
      }

      final slice = payload.sublist(start);
      if (start > 0) {
        req.response.statusCode = 206;
        req.response.headers.set(
          'content-range',
          'bytes $start-${payload.length - 1}/${payload.length}',
        );
      } else {
        req.response.statusCode = 200;
      }
      req.response.headers.contentLength = slice.length;

      if (!slowChunked) {
        const chunkSize = 64 * 1024;
        for (var offset = 0; offset < slice.length; offset += chunkSize) {
          final end = (offset + chunkSize).clamp(0, slice.length);
          req.response.add(slice.sublist(offset, end));
        }
        await req.response.close();
      } else {
        const chunkSize = 8 * 1024;
        try {
          for (var offset = 0; offset < slice.length; offset += chunkSize) {
            final end = (offset + chunkSize).clamp(0, slice.length);
            req.response.add(slice.sublist(offset, end));
            await req.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
          await req.response.close();
        } catch (_) {
          // Client paused/cancelled mid-stream.
        }
      }
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
    tempDir = await Directory.systemTemp.createTemp('toolbox_dl_test_');
    interruptAttempts = 0;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  DownloadManagerService createManager({
    Future<int?> Function(String path)? freeSpaceOverride,
    http.Client Function()? clientFactory,
  }) {
    return DownloadManagerService.isolated(
      clientFactory: clientFactory,
      storage: PlatformStorageService(
        directoryOverride: () async => tempDir,
        freeSpaceOverride: freeSpaceOverride ?? (_) async => 1024 * 1024 * 1024,
      ),
    );
  }

  group('URL Security Validator & Path Traversal', () {
    test('rejects invalid URLs, unsupported schemes, and embedded credentials', () {
      expect(UrlSecurityValidator.validate('').isValid, isFalse);
      expect(UrlSecurityValidator.validate('not a url').isValid, isFalse);
      expect(UrlSecurityValidator.validate('ftp://example.com/file.mp4').isValid, isFalse);
      expect(UrlSecurityValidator.validate('javascript:alert(1)').isValid, isFalse);
      expect(UrlSecurityValidator.validate('file:///etc/passwd').isValid, isFalse);
      expect(
        UrlSecurityValidator.validate('https://user:secret@example.com/a.mp4').isValid,
        isFalse,
      );
      expect(
        UrlSecurityValidator.validate('https://example.com/video.mp4').isValid,
        isTrue,
      );
    });

    test('sanitizes path traversal filenames and redacts query tokens in logs', () {
      final safe = UrlSecurityValidator.resolveSafeFileName(
        uri: Uri.parse('https://example.com/files/a.mp4'),
        contentDisposition: 'attachment; filename="../../etc/evil:name.mp4"',
      );
      expect(safe.contains('..'), isFalse);
      expect(safe.contains('/'), isFalse);
      expect(safe.contains('\\'), isFalse);
      expect(safe, 'evil_name.mp4');

      final redacted = UrlSecurityValidator.redactUrlForLog(
        'https://cdn.example.com/video.mp4?token=supersecret&sig=123',
      );
      expect(redacted.contains('supersecret'), isFalse);
      expect(redacted, 'https://cdn.example.com/video.mp4?redacted');
    });
  });

  group('Source Adapters & Social Media Compliance', () {
    test('YouTube adapter parses oEmbed metadata and reports restriction honestly', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'www.youtube.com');
        expect(request.url.path, '/oembed');
        return http.Response(
          jsonEncode({
            'title': 'Flutter Demo Video',
            'author_name': 'Flutter Dev',
            'thumbnail_url': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
          }),
          200,
        );
      });

      final adapter = YouTubeSourceAdapter();
      final uri = Uri.parse('https://youtu.be/dQw4w9WgXcQ');
      expect(adapter.canHandle(uri), isTrue);

      final result = await adapter.analyze(uri, client: mockClient);
      expect(result.isValidUrl, isTrue);
      expect(result.isPlatformRestricted, isTrue);
      expect(result.canDownload, isFalse);
      expect(result.title, 'Flutter Demo Video');
      expect(result.author, 'Flutter Dev');
      expect(result.thumbnailUrl, isNotNull);
      expect(result.errorMessage, contains('YouTube'));
    });

    test('Instagram, Facebook, and X adapters handle URLs independently without scraping', () async {
      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode({'author_name': '@toolbox'}), 200),
      );
      final registry = SourceAdapterRegistry();

      final ig = await registry.analyze(
        Uri.parse('https://www.instagram.com/reel/abc123/'),
        client: mockClient,
      );
      expect(ig.sourceId, 'instagram');
      expect(ig.isPlatformRestricted, isTrue);
      expect(ig.canDownload, isFalse);

      final fb = await registry.analyze(
        Uri.parse('https://www.facebook.com/watch/?v=123456'),
        client: mockClient,
      );
      expect(fb.sourceId, 'facebook');
      expect(fb.isPlatformRestricted, isTrue);
      expect(fb.canDownload, isFalse);

      final x = await registry.analyze(
        Uri.parse('https://x.com/flutterdev/status/12345'),
        client: mockClient,
      );
      expect(x.sourceId, 'x');
      expect(x.isPlatformRestricted, isTrue);
      expect(x.canDownload, isFalse);
      expect(x.author, '@toolbox');

      expect(InstagramSourceAdapter().canHandle(Uri.parse('https://example.com')), isFalse);
      expect(FacebookSourceAdapter().canHandle(Uri.parse('https://example.com')), isFalse);
      expect(XSourceAdapter().canHandle(Uri.parse('https://example.com')), isFalse);
    });
  });

  group('Direct Downloads, Resume, Interruption, Storage & Integrity', () {
    test('downloads MP4, MP3, PNG, PDF and verifies bytes + SHA-256 integrity', () async {
      final manager = createManager();
      await manager.init();

      final cases = <(String, Uint8List, MediaLibraryCategory)>[
        ('$baseUrl/sample.mp4', mp4Bytes, MediaLibraryCategory.videos),
        ('$baseUrl/sample.mp3', mp3Bytes, MediaLibraryCategory.audio),
        ('$baseUrl/sample.png', pngBytes, MediaLibraryCategory.images),
        ('$baseUrl/sample.pdf', pdfBytes, MediaLibraryCategory.documents),
      ];

      for (final (url, expected, expectedCat) in cases) {
        final analysis = await manager.analyzeUrl(url);
        expect(analysis.canDownload, isTrue, reason: 'Analyze failed for $url');
        expect(analysis.mediaCategory, expectedCat);
        expect(analysis.fileSizeBytes, expected.length);

        final outcome = await manager.startDownload(analysis: analysis);
        expect(outcome.status, StartDownloadStatus.started);
        final id = outcome.record!.id;

        await _waitUntil(
          () => manager.records.firstWhere((r) => r.id == id).status ==
              DownloadStatus.completed,
        );

        final completed = manager.records.firstWhere((r) => r.id == id);
        final savedBytes = await File(completed.filePath).readAsBytes();
        expect(savedBytes, expected);
        expect(completed.sha256, sha256.convert(expected).toString());

        final integrity = await manager.verifyFileIntegrity(id);
        expect(integrity.isValid, isTrue);
      }
    });

    test('follows safe redirects and rejects HTML pages & blocked executables', () async {
      final manager = createManager();
      await manager.init();

      final htmlAnalysis = await manager.analyzeUrl('$baseUrl/page.html');
      expect(htmlAnalysis.canDownload, isFalse);
      expect(htmlAnalysis.errorMessage, contains('HTML'));

      final exeAnalysis = await manager.analyzeUrl('$baseUrl/installer.exe');
      expect(exeAnalysis.canDownload, isFalse);
      expect(exeAnalysis.errorMessage, contains('Blocked'));

      final redirectAnalysis = await manager.analyzeUrl('$baseUrl/redirect.mp4');
      expect(redirectAnalysis.canDownload, isTrue);
      expect(redirectAnalysis.resolvedUrl, '$baseUrl/sample.mp4');
    });

    test('streams a large file (6 MB) accurately to disk', () async {
      final manager = createManager();
      await manager.init();

      final analysis = await manager.analyzeUrl('$baseUrl/large.bin');
      expect(analysis.canDownload, isTrue);
      expect(analysis.fileSizeBytes, largeBytes.length);

      final outcome = await manager.startDownload(analysis: analysis);
      final id = outcome.record!.id;

      await _waitUntil(
        () => manager.records.firstWhere((r) => r.id == id).status ==
            DownloadStatus.completed,
      );

      final rec = manager.records.firstWhere((r) => r.id == id);
      expect(await File(rec.filePath).length(), largeBytes.length);
      expect(rec.sha256, sha256.convert(largeBytes).toString());
    });

    test('pauses and resumes a Range-supported download cleanly', () async {
      final manager = createManager();
      await manager.init();

      final analysis = await manager.analyzeUrl('$baseUrl/slow-resumable.mp4');
      expect(analysis.canDownload, isTrue);
      expect(analysis.supportsResume, isTrue);

      final outcome = await manager.startDownload(analysis: analysis);
      final id = outcome.record!.id;

      await _waitUntil(
        () => manager.records.firstWhere((r) => r.id == id).downloadedBytes >=
            16 * 1024,
      );

      await manager.pauseDownload(id);
      final paused = manager.records.firstWhere((r) => r.id == id);
      expect(paused.status, DownloadStatus.paused);
      expect(paused.downloadedBytes, greaterThan(0));
      expect(paused.downloadedBytes, lessThan(slowResumableBytes.length));
      expect(await File(paused.tempFilePath).exists(), isTrue);

      await manager.resumeOrRetryDownload(id);
      await _waitUntil(
        () => manager.records.firstWhere((r) => r.id == id).status ==
            DownloadStatus.completed,
      );

      final done = manager.records.firstWhere((r) => r.id == id);
      expect(await File(done.filePath).readAsBytes(), slowResumableBytes);
    });

    test('cancels an active download and cleans up temporary .part file', () async {
      final manager = createManager();
      await manager.init();

      final analysis = await manager.analyzeUrl('$baseUrl/slow-resumable.mp4');
      final outcome = await manager.startDownload(analysis: analysis);
      final id = outcome.record!.id;

      await _waitUntil(
        () => manager.records.firstWhere((r) => r.id == id).downloadedBytes >=
            8 * 1024,
      );

      await manager.cancelDownload(id);
      final cancelled = manager.records.firstWhere((r) => r.id == id);
      expect(cancelled.status, DownloadStatus.cancelled);
      expect(await File(cancelled.tempFilePath).exists(), isFalse);
    });

    test('handles network interruption mid-stream and recovers on Retry via Range', () async {
      final manager = createManager();
      await manager.init();

      final analysis = await manager.analyzeUrl('$baseUrl/interrupt.mp4');
      expect(analysis.canDownload, isTrue);

      final outcome = await manager.startDownload(analysis: analysis);
      final id = outcome.record!.id;

      await _waitUntil(
        () => manager.records.firstWhere((r) => r.id == id).status ==
            DownloadStatus.failed,
      );

      final failed = manager.records.firstWhere((r) => r.id == id);
      expect(failed.downloadedBytes, greaterThan(0));
      expect(await File(failed.tempFilePath).exists(), isTrue);

      await manager.resumeOrRetryDownload(id);
      await _waitUntil(
        () => manager.records.firstWhere((r) => r.id == id).status ==
            DownloadStatus.completed,
      );

      final recovered = manager.records.firstWhere((r) => r.id == id);
      expect(await File(recovered.filePath).readAsBytes(), interruptBytes);
    });

    test('handles insufficient storage before starting download', () async {
      final manager = createManager(freeSpaceOverride: (_) async => 1024);
      await manager.init();

      final analysis = await manager.analyzeUrl('$baseUrl/sample.mp4');
      expect(analysis.canDownload, isTrue);

      final outcome = await manager.startDownload(analysis: analysis);
      expect(outcome.status, StartDownloadStatus.rejected);
      expect(outcome.message, contains('Insufficient storage'));
    });

    test('persists history across restarts and reconciles interrupted tasks', () async {
      final manager1 = createManager();
      await manager1.init();

      final analysis = await manager1.analyzeUrl('$baseUrl/sample.png');
      final outcome = await manager1.startDownload(analysis: analysis);
      final id = outcome.record!.id;

      await _waitUntil(
        () => manager1.records.firstWhere((r) => r.id == id).status ==
            DownloadStatus.completed,
      );

      // Simulate an in-progress download whose app process was killed.
      final partPath = '${tempDir.path}${Platform.pathSeparator}.interrupted.part';
      await File(partPath).writeAsBytes(Uint8List(4096));
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('media_downloader_records_v1') ?? [];
      final orphaned = DownloadRecord(
        id: 'dl_orphan',
        originalUrl: '$baseUrl/slow-resumable.mp4',
        downloadUrl: '$baseUrl/slow-resumable.mp4',
        title: 'slow-resumable.mp4',
        fileName: 'slow-resumable.mp4',
        filePath: '${tempDir.path}${Platform.pathSeparator}slow-resumable.mp4',
        tempFilePath: partPath,
        mimeType: 'video/mp4',
        extension: 'mp4',
        mediaCategory: MediaLibraryCategory.videos,
        totalBytes: slowResumableBytes.length,
        downloadedBytes: 4096,
        status: DownloadStatus.downloading,
        supportsResume: true,
        createdAt: DateTime.now(),
      );
      await prefs.setStringList(
        'media_downloader_records_v1',
        [...existing, jsonEncode(orphaned.toJson())],
      );

      // Fresh instance simulates app restart.
      final manager2 = createManager();
      await manager2.init();

      expect(manager2.completedFiles.length, 1);
      expect(manager2.completedFiles.first.id, id);

      final reconciled = manager2.records.firstWhere((r) => r.id == 'dl_orphan');
      expect(reconciled.status, DownloadStatus.paused);
      expect(reconciled.downloadedBytes, 4096);
    });

    test('renames, detects file tampering, and deletes downloaded files safely', () async {
      final manager = createManager();
      await manager.init();

      final analysis = await manager.analyzeUrl('$baseUrl/sample.png');
      final outcome = await manager.startDownload(analysis: analysis);
      final id = outcome.record!.id;

      await _waitUntil(
        () => manager.records.firstWhere((r) => r.id == id).status ==
            DownloadStatus.completed,
      );

      final badRename = await manager.renameDownloadedFile(id, 'virus.exe');
      expect(badRename, isNotNull);

      final goodRename = await manager.renameDownloadedFile(id, 'renamed_pic.png');
      expect(goodRename, isNull);
      final renamed = manager.records.firstWhere((r) => r.id == id);
      expect(renamed.fileName, 'renamed_pic.png');
      expect(await File(renamed.filePath).exists(), isTrue);

      // Tamper with file and confirm integrity check flags mismatch.
      await File(renamed.filePath).writeAsBytes([1, 2, 3]);
      final integrity = await manager.verifyFileIntegrity(id);
      expect(integrity.isValid, isFalse);

      final delErr = await manager.deleteDownloadedFile(id);
      expect(delErr, isNull);
      expect(await File(renamed.filePath).exists(), isFalse);
      expect(manager.records.where((r) => r.id == id), isEmpty);
    });
  });

  group('ToolRegistry & Responsive UI Widget Tests', () {
    test('Media Downloader is registered in ToolRegistry and searchable', () {
      final tool = ToolRegistry.findById('media_downloader');
      expect(tool, isNotNull);
      expect(tool!.title, 'Media Downloader');
      expect(
        ToolRegistry.searchTools('downloader').any((t) => t.id == 'media_downloader'),
        isTrue,
      );
    });

    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'MediaDownloaderScreen renders without overflow at 360dp 1.3x (${brightness.name})',
        (tester) async {
          final manager = createManager();
          await manager.init();

          await tester.binding.setSurfaceSize(const Size(360, 780));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MaterialApp(
              theme:
                  brightness == Brightness.dark
                      ? AppTheme.darkTheme
                      : AppTheme.lightTheme,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 780),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: MediaDownloaderScreen(manager: manager),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Media Downloader'), findsOneWidget);
          expect(find.text('Paste URL'), findsOneWidget);
          expect(find.text('Analyze URL'), findsOneWidget);
          expect(find.text('Downloaded Files Library'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Switch to Downloads Library tab and verify empty state fits cleanly.
          await tester.tap(find.text('Downloaded Files Library'));
          await tester.pumpAndSettle();
          expect(find.text('No downloaded files yet'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('analyzes URL, downloads file, filters, and confirms delete in UI', (
      tester,
    ) async {
      final manager = createManager();
      await manager.init();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaDownloaderScreen(manager: manager),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        '$baseUrl/sample.pdf',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Analyze URL'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text('sample.pdf'), findsWidgets);
      expect(find.text('Download'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Download'));
        await tester.pump();
        await _waitUntil(() => manager.completedFiles.length == 1);
      });
      await tester.pumpAndSettle();

      // Scroll down to Filter Row and verify Completed filter shows the downloaded item.
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Completed (1)'));
      await tester.tap(find.text('Completed (1)'));
      await tester.pumpAndSettle();
      expect(find.text('sample.pdf'), findsWidgets);

      // Navigate to Downloads Library via the top FeatureTabSelector chip and test Delete confirmation dialog.
      await tester.tap(find.text('Downloads Library (1)'));
      await tester.pumpAndSettle();
      expect(find.text('sample.pdf'), findsWidgets);

      await tester.ensureVisible(find.text('Delete').first);
      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();
      expect(find.text('Delete Downloaded File?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 30 && manager.completedFiles.isNotEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(manager.completedFiles, isEmpty);
      expect(find.text('No downloaded files yet'), findsOneWidget);
    });
  });
}
