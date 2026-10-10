import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart' show Offset, Size;
import 'package:pdf/pdf.dart' as pw_format;
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Data model representing PDF metadata
class PdfMetadataInfo {
  final String title;
  final String author;
  final String subject;
  final String keywords;
  final String creator;
  final String producer;
  final DateTime? creationDate;
  final DateTime? modificationDate;
  final int pageCount;
  final int sizeBytes;

  const PdfMetadataInfo({
    required this.title,
    required this.author,
    required this.subject,
    required this.keywords,
    required this.creator,
    required this.producer,
    this.creationDate,
    this.modificationDate,
    required this.pageCount,
    required this.sizeBytes,
  });
}

/// Data model representing a PDF bookmark
class PdfBookmarkItem {
  final String title;
  final int pageNumber; // 1-indexed

  const PdfBookmarkItem({required this.title, required this.pageNumber});
}

/// Data model representing a PDF diff line
class DiffLine {
  final String text;
  final String type; // 'same', 'added', 'removed'

  const DiffLine(this.text, this.type);
}

/// Data model representing a PDF comparison summary
class PdfComparisonResult {
  final int doc1Pages;
  final int doc2Pages;
  final int doc1Size;
  final int doc2Size;
  final double similarityPercent;
  final int addedCount;
  final int removedCount;
  final int unchangedCount;
  final List<DiffLine> diffLines;

  const PdfComparisonResult({
    required this.doc1Pages,
    required this.doc2Pages,
    required this.doc1Size,
    required this.doc2Size,
    required this.similarityPercent,
    required this.addedCount,
    required this.removedCount,
    required this.unchangedCount,
    required this.diffLines,
  });
}

/// High-performance offline service for Office and advanced PDF manipulations
class OfficeDocumentService {
  // ================= 1. WORD TO PDF =================
  /// Extracts text and paragraphs from .docx OpenXML archive and renders to PDF
  static Future<Uint8List> wordToPdf({
    required Uint8List docxBytes,
    String documentTitle = 'Word Document',
  }) async {
    final archive = ZipDecoder().decodeBytes(docxBytes);
    final documentFile = archive.findFile('word/document.xml');

    final paragraphs = <String>[];
    if (documentFile != null) {
      final xmlContent = utf8.decode(documentFile.content as List<int>, allowMalformed: true);
      // Extract text inside <w:p>...</w:p>
      final pRegex = RegExp(r'<w:p[ >](.*?)</w:p>', dotAll: true);
      final tRegex = RegExp(r'<w:t[ >](.*?)</w:t>', dotAll: true);

      for (final pMatch in pRegex.allMatches(xmlContent)) {
        final pContent = pMatch.group(1) ?? '';
        final buffer = StringBuffer();
        for (final tMatch in tRegex.allMatches(pContent)) {
          var text = tMatch.group(1) ?? '';
          text = text
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&amp;', '&')
              .replaceAll('&quot;', '"')
              .replaceAll('&apos;', "'");
          buffer.write(text);
        }
        final fullLine = buffer.toString().trim();
        if (fullLine.isNotEmpty) {
          paragraphs.add(fullLine);
        }
      }
    }

    if (paragraphs.isEmpty) {
      paragraphs.add('No readable text content found in the Word document.');
    }

    // Build PDF
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: pw_format.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            documentTitle,
            style: const pw.TextStyle(color: pw_format.PdfColors.grey700, fontSize: 9),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(color: pw_format.PdfColors.grey600, fontSize: 10),
          ),
        ),
        build: (context) => [
          pw.Text(
            documentTitle,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: pw_format.PdfColors.blue900),
          ),
          pw.Divider(thickness: 1, color: pw_format.PdfColors.blue200),
          pw.SizedBox(height: 14),
          ...paragraphs.map((p) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  p,
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                ),
              )),
        ],
      ),
    );

    return doc.save();
  }

  // ================= 2. EXCEL TO PDF =================
  /// Converts CSV, TSV or Excel tabular data to formatted PDF table
  static Future<Uint8List> excelToPdf({
    required List<List<dynamic>> rows,
    String sheetTitle = 'Spreadsheet Report',
  }) async {
    final doc = pw.Document();

    if (rows.isEmpty) {
      rows = [
        ['Column 1', 'Column 2', 'Column 3'],
        ['Item A', '100', 'Active'],
        ['Item B', '250', 'Completed'],
      ];
    }

    final headers = rows.first.map((e) => e.toString()).toList();
    final dataRows = rows.skip(1).map((r) => r.map((c) => c.toString()).toList()).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: pw_format.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(sheetTitle, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Text('Generated by Omni Utility', style: const pw.TextStyle(fontSize: 9, color: pw_format.PdfColors.grey700)),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 14),
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9)),
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: dataRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pw_format.PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: pw_format.PdfColors.blue800),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: pw_format.PdfColors.grey300, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            oddRowDecoration: const pw.BoxDecoration(color: pw_format.PdfColors.grey100),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ================= 3. POWERPOINT TO PDF =================
  /// Extracts slides from .pptx OpenXML archive and renders to presentation PDF
  static Future<Uint8List> pptxToPdf({
    required Uint8List pptxBytes,
    String presentationTitle = 'Presentation Slides',
  }) async {
    final archive = ZipDecoder().decodeBytes(pptxBytes);
    final slideFiles = archive.files.where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml')).toList();

    // Sort slide1, slide2, etc. numerically
    slideFiles.sort((a, b) {
      final numA = int.tryParse(RegExp(r'\d+').firstMatch(a.name)?.group(0) ?? '0') ?? 0;
      final numB = int.tryParse(RegExp(r'\d+').firstMatch(b.name)?.group(0) ?? '0') ?? 0;
      return numA.compareTo(numB);
    });

    final doc = pw.Document();

    if (slideFiles.isEmpty) {
      // Fallback single slide
      doc.addPage(
        pw.Page(
          pageFormat: pw_format.PdfPageFormat.a4.landscape,
          build: (context) => pw.Center(
            child: pw.Text('No slide content found in PPTX.', style: const pw.TextStyle(fontSize: 18)),
          ),
        ),
      );
    } else {
      for (int i = 0; i < slideFiles.length; i++) {
        final slideXml = utf8.decode(slideFiles[i].content as List<int>, allowMalformed: true);
        final tRegex = RegExp(r'<a:t[ >](.*?)</a:t>', dotAll: true);
        final textLines = <String>[];

        for (final match in tRegex.allMatches(slideXml)) {
          var t = match.group(1) ?? '';
          t = t
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&amp;', '&')
              .replaceAll('&quot;', '"');
          if (t.trim().isNotEmpty) {
            textLines.add(t.trim());
          }
        }

        final slideTitle = textLines.isNotEmpty ? textLines.first : 'Slide ${i + 1}';
        final bulletPoints = textLines.length > 1 ? textLines.sublist(1) : <String>[];

        doc.addPage(
          pw.Page(
            pageFormat: pw_format.PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(40),
            build: (context) => pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: pw_format.PdfColors.grey400, width: 1),
                borderRadius: pw.BorderRadius.circular(12),
                color: pw_format.PdfColors.white,
              ),
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        slideTitle,
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: pw_format.PdfColors.orange800),
                      ),
                      pw.Text('Slide ${i + 1}', style: const pw.TextStyle(fontSize: 12, color: pw_format.PdfColors.grey600)),
                    ],
                  ),
                  pw.Divider(thickness: 1.5, color: pw_format.PdfColors.orange300),
                  pw.SizedBox(height: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: bulletPoints.map((pt) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 12),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              margin: const pw.EdgeInsets.only(top: 4, right: 8),
                              width: 6,
                              height: 6,
                              decoration: const pw.BoxDecoration(color: pw_format.PdfColors.orange700, shape: pw.BoxShape.circle),
                            ),
                            pw.Expanded(child: pw.Text(pt, style: const pw.TextStyle(fontSize: 14))),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.bottomRight,
                    child: pw.Text(presentationTitle, style: const pw.TextStyle(fontSize: 9, color: pw_format.PdfColors.grey500)),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return doc.save();
  }

  // ================= 4. PDF TO WORD (DOCX) =================
  /// Extracts text from PDF and packages into a valid OpenXML .docx file
  static Uint8List pdfToDocx(Uint8List pdfBytes) {
    final pdfDoc = PdfDocument(inputBytes: pdfBytes);
    final textExtractor = PdfTextExtractor(pdfDoc);
    final extractedText = textExtractor.extractText();
    pdfDoc.dispose();

    final lines = extractedText.split('\n');

    // Build document.xml
    final docXmlBuffer = StringBuffer();
    docXmlBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    docXmlBuffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    docXmlBuffer.writeln('<w:body>');

    for (final line in lines) {
      final safeLine = line
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;');
      docXmlBuffer.writeln('<w:p><w:r><w:t>$safeLine</w:t></w:r></w:p>');
    }

    docXmlBuffer.writeln('</w:body></w:document>');

    // Standard OpenXML boilerplate
    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    final archive = Archive();
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));
    final docBytes = utf8.encode(docXmlBuffer.toString());
    archive.addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));

    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    return Uint8List.fromList(encoded);
  }

  // ================= 5. PDF TO EXCEL (CSV) =================
  /// Extracts tabular rows and delimited structures from PDF into CSV
  static String pdfToCsv(Uint8List pdfBytes) {
    final pdfDoc = PdfDocument(inputBytes: pdfBytes);
    final textExtractor = PdfTextExtractor(pdfDoc);
    final text = textExtractor.extractText();
    pdfDoc.dispose();

    final lines = text.split('\n');
    final rows = <List<String>>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      // Split by tab, multiple spaces (2+), or comma
      final parts = line.split(RegExp(r'\t+|\s{2,}|,'));
      rows.add(parts.map((p) => p.trim()).toList());
    }

    if (rows.isEmpty) {
      rows.add(['Extracted Content']);
      rows.add([text.trim()]);
    }

    return csv.encode(rows);
  }

  // ================= 6. PDF TO POWERPOINT (PPTX) =================
  /// Extracts PDF pages into an OpenXML .pptx presentation deck
  static Uint8List pdfToPptx(Uint8List pdfBytes) {
    final pdfDoc = PdfDocument(inputBytes: pdfBytes);
    final pageCount = pdfDoc.pages.count;
    final textExtractor = PdfTextExtractor(pdfDoc);

    final archive = Archive();
    final slideCount = pageCount > 0 ? pageCount : 1;

    for (int i = 0; i < slideCount; i++) {
      String pageText = '';
      try {
        pageText = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
      } catch (_) {
        pageText = 'Page ${i + 1} Content';
      }

      final safeText = pageText
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');

      final slideXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr/>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p><a:r><a:t>Slide ${i + 1}</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Content"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr/>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p><a:r><a:t>$safeText</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';

      final slideBytes = utf8.encode(slideXml);
      archive.addFile(ArchiveFile('ppt/slides/slide${i + 1}.xml', slideBytes.length, slideBytes));
    }

    pdfDoc.dispose();

    // Content types & rels
    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
</Types>''';

    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';

    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  // ================= 7. SEARCHABLE PDF WITH OCR LAYER =================
  /// Generates a Searchable PDF with image background and selectable text overlay
  static Future<Uint8List> createSearchablePdf({
    required Uint8List imageBytes,
    required String ocrText,
    String title = 'Searchable OCR Document',
  }) async {
    final doc = pw.Document();
    final imageProvider = pw.MemoryImage(imageBytes);

    doc.addPage(
      pw.Page(
        pageFormat: pw_format.PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Stack(
          children: [
            // Visual Image Layer
            pw.Positioned.fill(
              child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
            ),
            // Selectable / Searchable Text Layer overlay
            pw.Positioned.fill(
              child: pw.Opacity(
                opacity: 0.0, // Invisible selectable text layer
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(36),
                  child: pw.Text(
                    ocrText,
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // ================= 8. PDF METADATA VIEWER & EDITOR =================
  /// Reads metadata properties from PDF document
  static PdfMetadataInfo readMetadata(Uint8List pdfBytes) {
    final doc = PdfDocument(inputBytes: pdfBytes);
    final info = doc.documentInformation;
    final result = PdfMetadataInfo(
      title: info.title,
      author: info.author,
      subject: info.subject,
      keywords: info.keywords,
      creator: info.creator,
      producer: info.producer,
      creationDate: info.creationDate,
      modificationDate: info.modificationDate,
      pageCount: doc.pages.count,
      sizeBytes: pdfBytes.length,
    );
    doc.dispose();
    return result;
  }

  /// Updates and embeds new metadata into PDF document
  static Uint8List updateMetadata({
    required Uint8List pdfBytes,
    required String title,
    required String author,
    required String subject,
    required String keywords,
    required String creator,
    required String producer,
  }) {
    final doc = PdfDocument(inputBytes: pdfBytes);
    doc.documentInformation.title = title;
    doc.documentInformation.author = author;
    doc.documentInformation.subject = subject;
    doc.documentInformation.keywords = keywords;
    doc.documentInformation.creator = creator;
    doc.documentInformation.producer = producer;
    doc.documentInformation.modificationDate = DateTime.now();

    final updated = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return updated;
  }

  // ================= 9. PDF PAGE EXTRACTION TO SEPARATE FILES =================
  /// Extracts specified pages into individual standalone single-page PDFs bundled in ZIP
  static Uint8List extractPagesToZip({
    required Uint8List pdfBytes,
    required List<int> pageNumbers, // 1-indexed
    String baseName = 'Document',
  }) {
    final sourceDoc = PdfDocument(inputBytes: pdfBytes);
    final total = sourceDoc.pages.count;
    final archive = Archive();

    for (final pageNum in pageNumbers) {
      if (pageNum < 1 || pageNum > total) continue;

      final singleDoc = PdfDocument();
      // Import page
      final template = sourceDoc.pages[pageNum - 1].createTemplate();
      final newPage = singleDoc.pages.add();
      newPage.graphics.drawPdfTemplate(
        template,
        Offset.zero,
        Size(newPage.size.width, newPage.size.height),
      );

      final singleBytes = singleDoc.saveSync();
      singleDoc.dispose();

      final fileName = '${baseName}_Page_$pageNum.pdf';
      archive.addFile(ArchiveFile(fileName, singleBytes.length, singleBytes));
    }

    sourceDoc.dispose();
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  // ================= 10. PDF BOOKMARKS & TABLE-OF-CONTENTS =================
  /// Reads bookmarks outline from PDF
  static List<PdfBookmarkItem> readBookmarks(Uint8List pdfBytes) {
    final doc = PdfDocument(inputBytes: pdfBytes);
    final list = <PdfBookmarkItem>[];
    for (int i = 0; i < doc.bookmarks.count; i++) {
      final bm = doc.bookmarks[i];
      int pageIndex = 1;
      if (bm.destination != null) {
        pageIndex = doc.pages.indexOf(bm.destination!.page) + 1;
      }
      list.add(PdfBookmarkItem(title: bm.title, pageNumber: pageIndex > 0 ? pageIndex : 1));
    }
    doc.dispose();
    return list;
  }

  /// Adds or updates bookmarks outline in PDF document
  static Uint8List saveBookmarks({
    required Uint8List pdfBytes,
    required List<PdfBookmarkItem> bookmarks,
  }) {
    final doc = PdfDocument(inputBytes: pdfBytes);
    doc.bookmarks.clear();

    for (final item in bookmarks) {
      if (item.pageNumber >= 1 && item.pageNumber <= doc.pages.count) {
        final targetPage = doc.pages[item.pageNumber - 1];
        final bm = doc.bookmarks.add(item.title);
        bm.destination = PdfDestination(targetPage, Offset.zero);
      }
    }

    final updated = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return updated;
  }

  // ================= 11. PDF FORM FLATTENING =================
  /// Flattens all interactive AcroForm fields into permanent static graphics
  static Uint8List flattenForms(Uint8List pdfBytes) {
    final doc = PdfDocument(inputBytes: pdfBytes);
    doc.form.flattenAllFields();
    final flattened = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return flattened;
  }

  // ================= 12. PDF COMPARISON TOOL =================
  /// Compares two PDF documents by page count, size, and line-by-line text diff
  static PdfComparisonResult comparePdfs(Uint8List pdfA, Uint8List pdfB) {
    final docA = PdfDocument(inputBytes: pdfA);
    final docB = PdfDocument(inputBytes: pdfB);

    final pagesA = docA.pages.count;
    final pagesB = docB.pages.count;

    final textA = PdfTextExtractor(docA).extractText();
    final textB = PdfTextExtractor(docB).extractText();

    docA.dispose();
    docB.dispose();

    final linesA = textA.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final linesB = textB.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    final diff = <DiffLine>[];
    int matching = 0;
    int added = 0;
    int removed = 0;

    final maxLen = linesA.length > linesB.length ? linesA.length : linesB.length;
    for (int i = 0; i < maxLen; i++) {
      if (i < linesA.length && i < linesB.length) {
        if (linesA[i] == linesB[i]) {
          diff.add(DiffLine(linesA[i], 'same'));
          matching++;
        } else {
          diff.add(DiffLine(linesA[i], 'removed'));
          diff.add(DiffLine(linesB[i], 'added'));
          removed++;
          added++;
        }
      } else if (i < linesA.length) {
        diff.add(DiffLine(linesA[i], 'removed'));
        removed++;
      } else if (i < linesB.length) {
        diff.add(DiffLine(linesB[i], 'added'));
        added++;
      }
    }

    final totalEvaluated = matching + (added + removed) / 2;
    final similarity = totalEvaluated > 0 ? ((matching / totalEvaluated) * 100).clamp(0.0, 100.0) : 100.0;

    return PdfComparisonResult(
      doc1Pages: pagesA,
      doc2Pages: pagesB,
      doc1Size: pdfA.length,
      doc2Size: pdfB.length,
      similarityPercent: similarity,
      addedCount: added,
      removedCount: removed,
      unchangedCount: matching,
      diffLines: diff,
    );
  }
}
