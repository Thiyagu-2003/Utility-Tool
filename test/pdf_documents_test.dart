import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:utility_tool/features/documents/office_document_service.dart';

/// Builds a one-page PDF of [size] with "HELLO" drawn at (10, 10).
Uint8List _pdfOfSize(Size size, {int pages = 1}) {
  final doc = PdfDocument();
  for (var i = 0; i < pages; i++) {
    final section = doc.sections!.add();
    section.pageSettings.margins.all = 0;
    section.pageSettings.orientation =
        size.width > size.height ? PdfPageOrientation.landscape : PdfPageOrientation.portrait;
    section.pageSettings.size = size;
    section.pages.add().graphics.drawString(
          'HELLO ${i + 1}',
          PdfStandardFont(PdfFontFamily.helvetica, 12),
          bounds: const Rect.fromLTWH(10, 10, 200, 20),
        );
  }
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

Uint8List _docx(String documentXml) {
  final archive = Archive();
  final bytes = utf8.encode(documentXml);
  archive.addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('parsePageRange', () {
    test('parses mixed singles and ranges, sorted and de-duplicated', () {
      expect(OfficeDocumentService.parsePageRange('1-3, 5, 2, 8-10', 10), [1, 2, 3, 5, 8, 9, 10]);
    });

    test('drops out-of-range pages and clamps ranges', () {
      expect(OfficeDocumentService.parsePageRange('0, 4, 11, 9-20', 10), [4, 9, 10]);
    });

    test('accepts reversed and open-ended ranges', () {
      expect(OfficeDocumentService.parsePageRange('5-3', 10), [3, 4, 5]);
      expect(OfficeDocumentService.parsePageRange('8-', 10), [8, 9, 10]);
      expect(OfficeDocumentService.parsePageRange('-2', 10), [1, 2]);
    });

    test('ignores garbage and empty input', () {
      expect(OfficeDocumentService.parsePageRange('', 10), isEmpty);
      expect(OfficeDocumentService.parsePageRange('abc, 1-2-3, x-4', 10), isEmpty);
      expect(OfficeDocumentService.parsePageRange('1-3', 0), isEmpty);
    });

    test('huge ranges are clamped instead of looping a billion times', () {
      expect(OfficeDocumentService.parsePageRange('1-999999999', 3), [1, 2, 3]);
    });
  });

  group('appendPageCopy', () {
    test('keeps source page size and does not shift content into margins', () {
      final src = PdfDocument(inputBytes: _pdfOfSize(const Size(300, 400)));
      final out = PdfDocument();
      OfficeDocumentService.appendPageCopy(out, src.pages[0]);
      final bytes = Uint8List.fromList(out.saveSync());
      out.dispose();
      src.dispose();

      final reloaded = PdfDocument(inputBytes: bytes);
      expect(reloaded.pages.count, 1);
      expect(reloaded.pages[0].size.width, closeTo(300, 0.5));
      expect(reloaded.pages[0].size.height, closeTo(400, 0.5));
      final lines = PdfTextExtractor(reloaded).extractTextLines();
      expect(lines.first.text.trim(), 'HELLO 1');
      expect(lines.first.bounds.left, lessThan(20)); // drawn at x=10, not 10 + 40pt margin
      reloaded.dispose();
    });

    test('preserves landscape orientation and applies requested rotation', () {
      final src = PdfDocument(inputBytes: _pdfOfSize(const Size(500, 300)));
      final out = PdfDocument();
      OfficeDocumentService.appendPageCopy(out, src.pages[0], rotation: PdfPageRotateAngle.rotateAngle90);
      final bytes = Uint8List.fromList(out.saveSync());
      out.dispose();
      src.dispose();

      final reloaded = PdfDocument(inputBytes: bytes);
      expect(reloaded.pages[0].rotation, PdfPageRotateAngle.rotateAngle90);
      reloaded.dispose();
    });
  });

  test('extractPagesToZip writes one correctly sized PDF per requested page', () {
    final zipBytes = OfficeDocumentService.extractPagesToZip(
      pdfBytes: _pdfOfSize(const Size(300, 400), pages: 3),
      pageNumbers: [1, 3, 7],
      baseName: 'Doc',
    );
    final archive = ZipDecoder().decodeBytes(zipBytes);
    expect(archive.files.map((f) => f.name), ['Doc_Page_1.pdf', 'Doc_Page_3.pdf']);
    final page3 = PdfDocument(inputBytes: archive.findFile('Doc_Page_3.pdf')!.content as List<int>);
    expect(page3.pages[0].size.width, closeTo(300, 0.5));
    expect(PdfTextExtractor(page3).extractText(), contains('HELLO 3'));
    page3.dispose();
  });

  test('wordToPdf does not leak run attributes like xml:space into the text', () async {
    final pdf = await OfficeDocumentService.wordToPdf(
      docxBytes: _docx('<w:document><w:body>'
          '<w:p w:rsidR="1"><w:r><w:t xml:space="preserve">Hello </w:t></w:r><w:r><w:t>World</w:t></w:r></w:p>'
          '<w:p/>'
          '<w:p><w:pPr/><w:r><w:t>Second &amp; last</w:t></w:r></w:p>'
          '</w:body></w:document>'),
    );
    final doc = PdfDocument(inputBytes: pdf);
    final text = PdfTextExtractor(doc).extractText().replaceAll(RegExp(r'\s+'), ' ');
    doc.dispose();
    expect(text, contains('Hello World'));
    expect(text, contains('Second & last'));
    expect(text, isNot(contains('preserve')));
  });

  test('excelToPdf tolerates ragged rows', () async {
    final pdf = await OfficeDocumentService.excelToPdf(rows: [
      ['A', 'B', 'C'],
      ['1'],
      ['1', '2', '3', '4'],
    ]);
    expect(pdf, isNotEmpty);
  });

  test('pdfToDocx strips XML-illegal control characters', () {
    final doc = PdfDocument();
    doc.pages.add().graphics.drawString('Plain text', PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(0, 0, 200, 20));
    final pdf = Uint8List.fromList(doc.saveSync());
    doc.dispose();

    final docx = ZipDecoder().decodeBytes(OfficeDocumentService.pdfToDocx(pdf));
    final xml = utf8.decode(docx.findFile('word/document.xml')!.content as List<int>);
    expect(xml, contains('Plain text'));
    expect(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]').hasMatch(xml), isFalse);
  });

  test('pdfToPptx produces a complete package with every relationship target present', () {
    final pptx = ZipDecoder().decodeBytes(OfficeDocumentService.pdfToPptx(_pdfOfSize(const Size(300, 400), pages: 2)));
    final names = pptx.files.map((f) => f.name).toSet();
    expect(
      names,
      containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'ppt/presentation.xml',
        'ppt/_rels/presentation.xml.rels',
        'ppt/slideMasters/slideMaster1.xml',
        'ppt/slideLayouts/slideLayout1.xml',
        'ppt/theme/theme1.xml',
        'ppt/slides/slide1.xml',
        'ppt/slides/slide2.xml',
      ]),
    );
    final presRels = utf8.decode(pptx.findFile('ppt/_rels/presentation.xml.rels')!.content as List<int>);
    for (final m in RegExp(r'Target="([^"]+)"').allMatches(presRels)) {
      expect(names, contains('ppt/${m.group(1)}'));
    }
    final contentTypes = utf8.decode(pptx.findFile('[Content_Types].xml')!.content as List<int>);
    expect(contentTypes, contains('/ppt/slides/slide2.xml'));
    final slide2 = utf8.decode(pptx.findFile('ppt/slides/slide2.xml')!.content as List<int>);
    expect(slide2, contains('HELLO 2'));
  });

  group('diffLines', () {
    test('an inserted line does not mark the following lines as changed', () {
      final diff = OfficeDocumentService.diffLines(['a', 'b', 'c', 'd'], ['a', 'NEW', 'b', 'c', 'd']);
      expect(diff.where((d) => d.type == 'added').map((d) => d.text), ['NEW']);
      expect(diff.where((d) => d.type == 'removed'), isEmpty);
      expect(diff.where((d) => d.type == 'same').length, 4);
    });

    test('replacement shows removed and added line', () {
      final diff = OfficeDocumentService.diffLines(['a', 'b', 'c'], ['a', 'x', 'c']);
      expect(diff.map((d) => '${d.type}:${d.text}'), ['same:a', 'removed:b', 'added:x', 'same:c']);
    });

    test('handles empty sides', () {
      expect(OfficeDocumentService.diffLines([], ['a']).single.type, 'added');
      expect(OfficeDocumentService.diffLines(['a'], []).single.type, 'removed');
      expect(OfficeDocumentService.diffLines([], []), isEmpty);
    });
  });

  group('parseCsv (RFC 4180)', () {
    test('quoted fields keep embedded commas', () {
      expect(OfficeDocumentService.parseCsv('Name,City\n"Doe, John","Paris, FR"\n'), [
        ['Name', 'City'],
        ['Doe, John', 'Paris, FR'],
      ]);
    });

    test('doubled quotes are an escaped quote and quoted fields may span lines', () {
      expect(OfficeDocumentService.parseCsv('a,"say ""hi""",c\n"line1\nline2",x,y'), [
        ['a', 'say "hi"', 'c'],
        ['line1\nline2', 'x', 'y'],
      ]);
    });

    test('CRLF, bare CR, blank lines and a missing final newline', () {
      expect(OfficeDocumentService.parseCsv('a,b\r\n\r\nc,d\re,f'), [
        ['a', 'b'],
        ['c', 'd'],
        ['e', 'f'],
      ]);
    });

    test('a quote in the middle of an unquoted cell stays literal', () {
      expect(OfficeDocumentService.parseCsv('MacBook Pro 16",Laptops,\$2499'), [
        ['MacBook Pro 16"', 'Laptops', '\$2499'],
      ]);
    });

    test('trims unquoted cells, keeps spaces inside quotes, allows a space before the opening quote', () {
      expect(OfficeDocumentService.parseCsv(' a , "  b  " ,c'), [
        ['a', '  b  ', 'c'],
      ]);
    });

    test('empty cells and a trailing delimiter are preserved; quoted empty line is not blank', () {
      expect(OfficeDocumentService.parseCsv('a,,c,\n""'), [
        ['a', '', 'c', ''],
        [''],
      ]);
    });

    test('picks tab or semicolon when the first line uses it', () {
      expect(OfficeDocumentService.parseCsv('a\tb,1\tc'), [
        ['a', 'b,1', 'c'],
      ]);
      expect(OfficeDocumentService.parseCsv('a;b;c\n1,5;2;3'), [
        ['a', 'b', 'c'],
        ['1,5', '2', '3'],
      ]);
    });

    test('empty input gives no rows', () {
      expect(OfficeDocumentService.parseCsv(''), isEmpty);
      expect(OfficeDocumentService.parseCsv(' \n \n'), isEmpty);
    });

    test('quoted commas survive into the generated PDF table', () async {
      final rows = OfficeDocumentService.parseCsv('Name,Note\n"Doe, John",ok');
      final pdf = await OfficeDocumentService.excelToPdf(rows: rows);
      final doc = PdfDocument(inputBytes: pdf);
      final text = PdfTextExtractor(doc).extractText().replaceAll(RegExp(r'\s+'), ' ');
      doc.dispose();
      expect(text, contains('Doe, John'));
    });
  });

  group('background-friendly PDF helpers', () {
    test('mergePdfs concatenates pages in order at their own sizes', () {
      final merged = OfficeDocumentService.mergePdfs([
        _pdfOfSize(const Size(300, 400), pages: 2),
        _pdfOfSize(const Size(500, 300)),
      ]);
      final doc = PdfDocument(inputBytes: merged);
      expect(doc.pages.count, 3);
      expect(doc.pages[1].size.width, closeTo(300, 0.5));
      expect(doc.pages[2].size.width, closeTo(500, 0.5));
      expect(PdfTextExtractor(doc).extractText(startPageIndex: 1, endPageIndex: 1), contains('HELLO 2'));
      doc.dispose();
    });

    test('extractPages keeps only the requested pages and ignores out-of-range ones', () {
      final out = OfficeDocumentService.extractPages(_pdfOfSize(const Size(300, 400), pages: 4), [4, 2, 9]);
      final doc = PdfDocument(inputBytes: out);
      expect(doc.pages.count, 2);
      expect(PdfTextExtractor(doc).extractText(startPageIndex: 0, endPageIndex: 0), contains('HELLO 4'));
      doc.dispose();
    });

    test('compressPdf returns null instead of a bigger file', () {
      final pdf = _pdfOfSize(const Size(300, 400), pages: 3);
      final out = OfficeDocumentService.compressPdf(pdf);
      expect(out == null || out.length < pdf.length, isTrue);
      final again = out == null ? null : OfficeDocumentService.compressPdf(out);
      expect(again == null || again.length < out!.length, isTrue);
    });

    test('extractText reads the text and is empty for a blank page', () {
      expect(OfficeDocumentService.extractText(_pdfOfSize(const Size(300, 400))), contains('HELLO 1'));
      final blank = PdfDocument()..pages.add();
      final bytes = Uint8List.fromList(blank.saveSync());
      blank.dispose();
      expect(OfficeDocumentService.extractText(bytes).trim(), isEmpty);
    });

    test('the *InBackground wrappers run in an isolate and return the same result', () async {
      final pdf = _pdfOfSize(const Size(300, 400), pages: 3);
      final out = await OfficeDocumentService.extractPagesInBackground(pdf, [2]);
      final doc = PdfDocument(inputBytes: out);
      expect(doc.pages.count, 1);
      doc.dispose();
      final cmp = await OfficeDocumentService.comparePdfsInBackground(pdf, pdf);
      expect(cmp.similarityPercent, 100);
      final xlsx = await OfficeDocumentService.excelToPdfInBackground([
        ['A', 'B'],
        ['1', '2'],
      ], 'T');
      expect(String.fromCharCodes(xlsx.sublist(0, 5)), '%PDF-');
    });
  });

  test('pdfToCsv keeps thousands separators inside one cell', () async {
    final doc = pw.Document();
    doc.addPage(pw.Page(build: (_) => pw.Text('Total   1,234.50   paid')));
    final csvText = OfficeDocumentService.pdfToCsv(await doc.save());
    final cells = OfficeDocumentService.parseCsv(csvText).expand((r) => r).toList();
    expect(cells, contains('1,234.50'));
    expect(cells, isNot(contains('234.50')));
  });
}
