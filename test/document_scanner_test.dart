import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/core/services/preferences_service.dart';
import 'package:utility_tool/core/theme/app_theme.dart';
import 'package:utility_tool/features/documents/document_scanner_screen.dart';
import 'package:utility_tool/features/documents/office_pdf_toolkit_screen.dart';
import 'package:utility_tool/features/documents/pdf_toolkit_screen.dart';
import 'package:utility_tool/features/documents/scan_pdf_service.dart';

/// White page with a grey "document" block at [x],[y] of [w]x[h].
img.Image _framed({int width = 100, int height = 80, int x = 20, int y = 10, int w = 50, int h = 40, int border = 255}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(border, border, border));
  img.fillRect(image, x1: x, y1: y, x2: x + w - 1, y2: y + h - 1, color: img.ColorRgb8(120, 90, 60));
  return image;
}

num _lum(img.Pixel p) => img.getLuminanceRgb(p.r, p.g, p.b);

void main() {
  group('trimBorders', () {
    test('crops uniform white borders to the content box', () {
      final out = ScanPdfService.trimBorders(_framed());
      expect([out.width, out.height], [50, 40]);
    });

    test('crops uniform black borders too', () {
      final out = ScanPdfService.trimBorders(_framed(border: 0));
      expect([out.width, out.height], [50, 40]);
    });

    test('leaves borderless and blank images untouched', () {
      final full = _framed(x: 0, y: 0, w: 100, h: 80);
      expect(identical(ScanPdfService.trimBorders(full), full), isTrue);
      final blank = img.Image(width: 40, height: 40);
      img.fill(blank, color: img.ColorRgb8(255, 255, 255));
      expect(identical(ScanPdfService.trimBorders(blank), blank), isTrue);
    });
  });

  group('applyScanFilter', () {
    // Left half: "paper" in shadow (grey 150); a dark ink line through it.
    img.Image shadowedPage() {
      final image = img.Image(width: 60, height: 60);
      img.fill(image, color: img.ColorRgb8(235, 235, 235));
      img.fillRect(image, x1: 0, y1: 0, x2: 29, y2: 59, color: img.ColorRgb8(150, 150, 150));
      img.fillRect(image, x1: 0, y1: 29, x2: 59, y2: 30, color: img.ColorRgb8(20, 20, 20));
      return image;
    }

    test('original is a no-op', () {
      final src = shadowedPage();
      expect(identical(ScanPdfService.applyScanFilter(src, ScanFilter.original), src), isTrue);
    });

    test('grayscale removes colour', () {
      final out = ScanPdfService.applyScanFilter(_framed(), ScanFilter.grayscale);
      final p = out.getPixel(30, 20);
      expect(p.r, p.g);
      expect(p.g, p.b);
    });

    test('B&W is pure black/white, paper white even in shadow, ink black', () {
      final out = ScanPdfService.applyScanFilter(shadowedPage(), ScanFilter.blackWhite);
      for (final p in out) {
        expect(p.r == 0 || p.r == 255, isTrue);
      }
      expect(out.getPixel(10, 10).r, 255); // shadowed paper
      expect(out.getPixel(50, 10).r, 255); // lit paper
      expect(out.getPixel(10, 29).r, 0); // ink
    });

    test('shadow removal brightens shadowed paper and keeps ink dark', () {
      final src = shadowedPage();
      final out = ScanPdfService.applyScanFilter(src, ScanFilter.lighten);
      expect(_lum(out.getPixel(5, 5)), greaterThan(_lum(src.getPixel(5, 5)) + 40));
      expect(_lum(out.getPixel(5, 29)), lessThan(100));
    });

    test('magic color boosts saturation', () {
      final src = img.Image(width: 20, height: 20);
      img.fill(src, color: img.ColorRgb8(170, 120, 110));
      final out = ScanPdfService.applyScanFilter(src, ScanFilter.magicColor);
      final a = src.getPixel(10, 10), b = out.getPixel(10, 10);
      expect(b.r - b.b, greaterThan(a.r - a.b));
    });
  });

  group('renderScanPage', () {
    test('downscales to maxSide, rotates and returns the new size', () {
      final src = Uint8List.fromList(img.encodePng(img.Image(width: 400, height: 200)));
      final r = ScanPdfService.renderScanPage((source: src, filter: ScanFilter.grayscale, rotation: 90, maxSide: 100, quality: 80, trim: false));
      expect([r.width, r.height], [50, 100]);
      expect(img.decodeJpg(r.bytes), isNotNull);
    });

    num centreLum(Uint8List jpg) {
      final out = img.decodeJpg(jpg)!;
      final p = out.getPixel(out.width ~/ 2, out.height ~/ 2);
      return img.getLuminanceRgb(p.r, p.g, p.b);
    }

    test('16-bit images are widened so the 0..255 filters do not blacken them', () {
      final src = img.Image(width: 40, height: 40, format: img.Format.uint16);
      for (final p in src) {
        p.r = p.g = p.b = 61680; // ~240/255 of the 16-bit range
      }
      final png = Uint8List.fromList(img.encodePng(src));
      expect(img.decodePng(png)!.format, img.Format.uint16);
      for (final f in [ScanFilter.lighten, ScanFilter.magicColor, ScanFilter.blackWhite]) {
        final r = ScanPdfService.renderScanPage((source: png, filter: f, rotation: 0, maxSide: 100, quality: 90, trim: false));
        expect(centreLum(r.bytes), greaterThan(200), reason: f.label);
      }
    });

    test('palette (indexed) images are expanded before the filters write channels', () {
      final src = img.Image(width: 40, height: 40, withPalette: true);
      src.palette!.setRgb(0, 235, 235, 235);
      final png = Uint8List.fromList(img.encodePng(src));
      expect(img.decodePng(png)!.hasPalette, isTrue);
      final r = ScanPdfService.renderScanPage((source: png, filter: ScanFilter.lighten, rotation: 0, maxSide: 100, quality: 90, trim: false));
      expect(centreLum(r.bytes), greaterThan(200));
    });

    test('transparent PNGs land on white paper, not black', () {
      final src = img.Image(width: 40, height: 40, numChannels: 4); // fully transparent
      final png = Uint8List.fromList(img.encodePng(src));
      final r = ScanPdfService.renderScanPage((source: png, filter: ScanFilter.original, rotation: 0, maxSide: 100, quality: 90, trim: false));
      expect(centreLum(r.bytes), greaterThan(240));
    });

    test('rejects non-images', () {
      expect(() => ScanPdfService.renderScanPage((source: Uint8List.fromList([1, 2, 3]), filter: ScanFilter.original, rotation: 0, maxSide: 100, quality: 80, trim: false)), throwsFormatException);
    });
  });

  group('page math', () {
    test('fit-to-image page uses A4 long side and adds margins', () {
      final f = ScanPdfService.pageFormatForImage(null, 1000, 2000, margin: 10);
      expect(f.width, closeTo(441, 0.01));
      expect(f.height, closeTo(862, 0.01));
      expect(f.marginLeft, 10);
    });

    test('fixed sizes auto-orient to the image unless told not to', () {
      final land = ScanPdfService.pageFormatForImage(PdfPageFormat.a4, 300, 200);
      expect(land.width, greaterThan(land.height));
      final kept = ScanPdfService.pageFormatForImage(PdfPageFormat.a4, 300, 200, autoOrient: false);
      expect(kept.width, PdfPageFormat.a4.width);
    });

    test('containRect centres the image without distortion', () {
      final (l, t, w, h) = ScanPdfService.containRect(200, 400, 100, 100);
      expect([l, t, w, h], [0, 100, 200, 200]);
    });
  });

  group('naming and list helpers', () {
    test('default name is Scan_yyyyMMdd_HHmm', () {
      expect(ScanPdfService.defaultScanName(DateTime(2026, 3, 7, 9, 5)), 'Scan_20260307_0905');
    });

    test('pdfFileName sanitises and adds a single .pdf', () {
      expect(ScanPdfService.pdfFileName(' My scan:1/2 ', 'X'), 'My_scan12.pdf');
      expect(ScanPdfService.pdfFileName('report.PDF', 'X'), 'report.pdf');
      expect(ScanPdfService.pdfFileName('  ', 'Fallback'), 'Fallback.pdf');
    });

    test('moveItem places the item at the target index', () {
      final list = ['a', 'b', 'c', 'd'];
      ScanPdfService.moveItem(list, 0, 2);
      expect(list, ['b', 'c', 'a', 'd']);
      ScanPdfService.moveItem(list, 3, 0);
      expect(list, ['d', 'b', 'c', 'a']);
      ScanPdfService.moveItem(list, 9, 0); // out of range is ignored
      expect(list, ['d', 'b', 'c', 'a']);
    });

    test('rotation cycles through quarter turns', () {
      expect([0, 90, 180, 270].map(ScanPdfService.nextRotation), [90, 180, 270, 0]);
    });
  });

  group('buildScanPdf', () {
    Uint8List jpeg(int w, int h) => Uint8List.fromList(img.encodeJpg(img.Image(width: w, height: h)));

    test('one page per image, fitted pages, searchable OCR text layer', () async {
      final bytes = await ScanPdfService.buildScanPdf(
        ScanPdfRequest(
          pages: [
            ScanPdfPage(jpeg(100, 200), const [OcrLine('INVOICE 42', 0.1, 0.1, 0.5, 0.05)]),
            ScanPdfPage(jpeg(300, 100)),
          ],
        ),
      );
      final doc = PdfDocument(inputBytes: bytes);
      expect(doc.pages.count, 2);
      expect(doc.pages[0].size.height, closeTo(842, 1));
      expect(doc.pages[1].size.width, closeTo(842, 1));
      // The pdf package emits words separately, which Syncfusion's extractor splits onto lines.
      final text = PdfTextExtractor(doc).extractText(startPageIndex: 0, endPageIndex: 0);
      expect(text, allOf(contains('INVOICE'), contains('42')));
      expect(PdfTextExtractor(doc).extractText(startPageIndex: 1, endPageIndex: 1).trim(), isEmpty);
      doc.dispose();
    });

    test('password-protected output needs the password to open', () async {
      final bytes = await ScanPdfService.buildScanPdf(ScanPdfRequest(pages: [ScanPdfPage(jpeg(50, 50))], password: 'secret'));
      expect(() => PdfDocument(inputBytes: bytes), throwsA(anything));
      final doc = PdfDocument(inputBytes: bytes, password: 'secret');
      expect(doc.pages.count, 1);
      doc.dispose();
    });
  });

  group('layout at 360dp and 1.3x text', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService().init();
    });

    Future<void> pump(WidgetTester tester, Widget screen, ThemeData theme) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 780), textScaler: TextScaler.linear(1.3)),
            child: screen,
          ),
        ),
      );
      await tester.pump();
    }

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      testWidgets('scanner (${theme.brightness.name}) renders without overflow', (tester) async {
        await pump(tester, const DocumentScannerScreen(), theme);
        expect(tester.takeException(), isNull);
        expect(find.text('Document Scanner'), findsWidgets);
      });

      testWidgets('Photo to PDF tab (${theme.brightness.name}) renders without overflow', (tester) async {
        await pump(tester, const PdfToolkitScreen(toolId: 'photo_to_pdf'), theme);
        expect(tester.takeException(), isNull);
        expect(find.text('Auto-fit page to image'), findsOneWidget);
        await tester.ensureVisible(find.text('Auto-fit page to image'));
        await tester.pump();
        await tester.tap(find.text('Auto-fit page to image'));
        await tester.pump();
        expect(find.text('Landscape Orientation'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('every toolkit tab at 360dp and 1.3x text', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService().init();
    });

    Future<void> visitTabs(WidgetTester tester, Widget screen, ThemeData theme, List<String> labels) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(data: const MediaQueryData(size: Size(360, 780), textScaler: TextScaler.linear(1.3)), child: screen),
        ),
      );
      await tester.pump();
      for (final label in labels) {
        // Switch through the "All (N)" sheet: the chip row scrolls, the sheet lists every tab.
        await tester.tap(find.textContaining('All ('));
        await tester.pumpAndSettle();
        final entry = find.descendant(of: find.byType(BottomSheet), matching: find.text(label));
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing, reason: label);
        expect(tester.takeException(), isNull, reason: label);
      }
    }

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      testWidgets('PDF toolkit (${theme.brightness.name})', (tester) async {
        await visitTabs(tester, const PdfToolkitScreen(), theme, [for (final t in PdfToolkitTab.values) t.label]);
      });

      testWidgets('Office suite (${theme.brightness.name})', (tester) async {
        await visitTabs(tester, const OfficePdfToolkitScreen(), theme, [for (final t in OfficePdfTab.values) t.label]);
      });
    }
  });

  test('Photo to PDF is registered and searchable', () {
    final tool = ToolRegistry.allTools.firstWhere((t) => t.id == 'photo_to_pdf');
    expect(tool.keywords, containsAll(['photo to pdf', 'auto crop']));
    expect(ToolRegistry.allTools.where((t) => t.id == 'photo_to_pdf').length, 1);
  });
}
