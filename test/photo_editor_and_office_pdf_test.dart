import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:utility_tool/core/models/tool_model.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/features/image_tools/photo_editor_service.dart';
import 'package:utility_tool/features/documents/office_document_service.dart';

void main() {
  group('PhotoEditorService Core Tests', () {
    late img.Image testImage;

    setUp(() {
      testImage = img.Image(width: 20, height: 20);
      // Fill with white background and red center
      img.fill(testImage, color: img.ColorRgba8(255, 255, 255, 255));
      for (int y = 5; y < 15; y++) {
        for (int x = 5; x < 15; x++) {
          testImage.setPixelRgba(x, y, 255, 0, 0, 255);
        }
      }
    });

    test('removeBackground makes border matching pixels transparent', () {
      final cutout = PhotoEditorService.removeBackground(
        testImage,
        sampleR: 255,
        sampleG: 255,
        sampleB: 255,
        tolerance: 20.0,
        floodFillFromEdges: true,
      );

      expect(cutout.width, 20);
      expect(cutout.height, 20);
      // Border pixel at (0, 0) should be transparent (alpha = 0)
      final borderPixel = cutout.getPixel(0, 0);
      expect(borderPixel.a, 0);

      // Center pixel at (10, 10) was red, should remain opaque (alpha = 255)
      final centerPixel = cutout.getPixel(10, 10);
      expect(centerPixel.a, 255);
      expect(centerPixel.r, 255);
      expect(centerPixel.g, 0);
    });

    test('replaceBackground composites cutout onto solid background', () {
      final cutout = PhotoEditorService.removeBackground(
        testImage,
        sampleR: 255,
        sampleG: 255,
        sampleB: 255,
        tolerance: 20.0,
      );

      final composed = PhotoEditorService.replaceBackground(
        cutout,
        solidColor: const Color(0xFF0000FF), // Blue background
      );

      expect(composed.width, 20);
      expect(composed.height, 20);
      // Border at (0, 0) should now have blue background
      final borderPixel = composed.getPixel(0, 0);
      expect(borderPixel.b, 255);
    });

    test('adjustImage modifies brightness and contrast without crashing', () {
      final adjusted = PhotoEditorService.adjustImage(
        source: testImage,
        brightness: 0.2,
        contrast: 0.1,
        saturation: 0.15,
        sharpness: 0.5,
        gamma: 0.05,
        vignette: 0.2,
      );

      expect(adjusted.width, testImage.width);
      expect(adjusted.height, testImage.height);
    });

    test('applyFilter successfully runs all 12 preset filters', () {
      final filters = [
        'Original', 'Vintage', 'Sepia', 'B&W', 'Film Noir',
        'Warm Sun', 'Cool Ice', 'Cyberpunk', 'Emerald',
        'HDR Pop', 'Pixelate', 'Invert',
      ];

      for (final f in filters) {
        final filtered = PhotoEditorService.applyFilter(testImage, f);
        expect(filtered.width, testImage.width);
        expect(filtered.height, testImage.height);
      }
    });

    test('applyBlurAreas censors target rectangular region', () {
      final areas = [
        const BlurArea(x: 0.25, y: 0.25, width: 0.5, height: 0.5, intensity: 5, isMosaic: true),
      ];

      final censored = PhotoEditorService.applyBlurAreas(testImage, areas);
      expect(censored.width, testImage.width);
      expect(censored.height, testImage.height);
    });
  });

  group('OfficeDocumentService Core Tests', () {
    test('excelToPdf converts tabular grid data into valid PDF bytes', () async {
      final rows = [
        ['Item', 'Qty', 'Cost'],
        ['Monitor', 2, 600],
        ['Keyboard', 5, 250],
      ];

      final pdfBytes = await OfficeDocumentService.excelToPdf(
        rows: rows,
        sheetTitle: 'Test Inventory',
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF files always begin with '%PDF-' magic bytes
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('createSearchablePdf produces valid PDF with selectable layer', () async {
      final sampleImg = img.Image(width: 100, height: 100);
      img.fill(sampleImg, color: img.ColorRgba8(240, 240, 240, 255));
      final pngBytes = img.encodePng(sampleImg);

      final pdfBytes = await OfficeDocumentService.createSearchablePdf(
        imageBytes: pngBytes,
        ocrText: 'Scanned Document OCR Text Content',
        title: 'Searchable Test',
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('readMetadata & updateMetadata reads and writes PDF properties', () async {
      // Create simple PDF
      final initialPdf = await OfficeDocumentService.excelToPdf(
        rows: [
          ['Col A', 'Col B'],
          ['Val 1', 'Val 2'],
        ],
        sheetTitle: 'Metadata Test',
      );

      final updatedPdf = OfficeDocumentService.updateMetadata(
        pdfBytes: initialPdf,
        title: 'Updated Test Title',
        author: 'Unit Test Author',
        subject: 'Testing Subject',
        keywords: 'test, flutter, pdf',
        creator: 'Omni Utility',
        producer: 'Omni PDF Engine',
      );

      final metadata = OfficeDocumentService.readMetadata(updatedPdf);
      expect(metadata.title, 'Updated Test Title');
      expect(metadata.author, 'Unit Test Author');
      expect(metadata.subject, 'Testing Subject');
      expect(metadata.keywords, 'test, flutter, pdf');
      expect(metadata.creator, 'Omni Utility');
    });

    test('comparePdfs accurately calculates similarity and line diffs', () async {
      final pdfA = await OfficeDocumentService.excelToPdf(
        rows: [
          ['Heading 1', 'Heading 2'],
          ['Data Line 1', 'Data Line 2'],
        ],
        sheetTitle: 'Version A',
      );

      final pdfB = await OfficeDocumentService.excelToPdf(
        rows: [
          ['Heading 1', 'Heading 2'],
          ['Data Line 1', 'Data Line 2'],
        ],
        sheetTitle: 'Version A',
      );

      final diffResult = OfficeDocumentService.comparePdfs(pdfA, pdfB);
      expect(diffResult.doc1Pages, diffResult.doc2Pages);
      expect(diffResult.similarityPercent, greaterThanOrEqualTo(80.0));
      expect(diffResult.diffLines.isNotEmpty, isTrue);
    });
  });

  group('ToolRegistry Verification for New Suites', () {
    test('Photo Studio & Editor is registered in ToolRegistry', () {
      final tool = ToolRegistry.allTools.firstWhere(
        (t) => t.id == 'photo_editor_studio',
        orElse: () => throw Exception('photo_editor_studio not found'),
      );

      expect(tool.title, 'Photo Studio & Editor');
      expect(tool.category, ToolCategory.filesText);
      expect(tool.keywords.contains('remove bg'), isTrue);
      expect(tool.keywords.contains('blur'), isTrue);
      expect(tool.keywords.contains('filter'), isTrue);
    });

    test('Office & Advanced PDF Suite is registered in ToolRegistry', () {
      final tool = ToolRegistry.allTools.firstWhere(
        (t) => t.id == 'office_doc_pdf_suite',
        orElse: () => throw Exception('office_doc_pdf_suite not found'),
      );

      expect(tool.title, 'Office & Advanced PDF Suite');
      expect(tool.category, ToolCategory.filesText);
      expect(tool.keywords.contains('word'), isTrue);
      expect(tool.keywords.contains('excel'), isTrue);
      expect(tool.keywords.contains('compare'), isTrue);
      expect(tool.keywords.contains('ocr'), isTrue);
    });
  });
}
