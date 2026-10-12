import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart' show Offset;
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
  // ================= SHARED HELPERS =================
  /// Parses "1-3, 5, 8-10" into sorted, de-duplicated 1-indexed page numbers
  /// within 1..[maxPages]. Reversed ranges ("5-3") are accepted; open ends
  /// ("4-" / "-2") run to the last / from the first page.
  static List<int> parsePageRange(String input, int maxPages) {
    final pages = <int>{};
    for (final part in input.split(',')) {
      final clean = part.trim();
      if (clean.isEmpty) continue;
      if (clean.contains('-')) {
        final sub = clean.split('-');
        if (sub.length != 2) continue;
        final a = sub[0].trim().isEmpty ? 1 : int.tryParse(sub[0].trim());
        final b = sub[1].trim().isEmpty ? maxPages : int.tryParse(sub[1].trim());
        if (a == null || b == null) continue;
        // Clamp before looping so "1-999999999" can't freeze the UI.
        final start = (a < b ? a : b).clamp(1, maxPages < 1 ? 1 : maxPages);
        final end = (a < b ? b : a).clamp(0, maxPages);
        for (int i = start; i <= end; i++) {
          pages.add(i);
        }
      } else {
        final single = int.tryParse(clean);
        if (single != null && single >= 1 && single <= maxPages) pages.add(single);
      }
    }
    return pages.toList()..sort();
  }

  /// Appends a visual copy of [source] to [target] at the source page's own
  /// size, with zero margins and its rotation preserved (or [rotation] if given).
  /// A plain `target.pages.add()` would use A4 + 40pt margins, shifting and
  /// clipping the copied content.
  static void appendPageCopy(PdfDocument target, PdfPage source, {PdfPageRotateAngle? rotation}) {
    final template = source.createTemplate();
    final section = target.sections!.add();
    final settings = section.pageSettings;
    settings.margins.all = 0;
    settings.orientation =
        template.size.width > template.size.height ? PdfPageOrientation.landscape : PdfPageOrientation.portrait;
    settings.size = template.size;
    settings.rotate = rotation ?? source.rotation;
    section.pages.add().graphics.drawPdfTemplate(template, Offset.zero);
  }

  /// Parses CSV/TSV [text] per RFC 4180: quoted fields may hold the delimiter,
  /// doubled quotes (`""`) and line breaks; CRLF/LF/CR all end a row; blank lines
  /// are skipped. A quote only opens a quoted field at the start of a field, so
  /// a stray one (`16" screen`) stays literal. Unquoted cells are trimmed.
  /// With no [delimiter] it is picked from the first line (comma, tab or semicolon).
  static List<List<String>> parseCsv(String text, {String? delimiter}) {
    var delim = delimiter;
    if (delim == null) {
      final firstLine = text.split(RegExp(r'\r\n|\n|\r')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      int count(String c) => c.allMatches(firstLine).length;
      var best = ',';
      for (final c in ['\t', ';']) {
        if (count(c) > count(best)) best = c;
      }
      delim = best;
    }
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false, wasQuoted = false, rowHadQuotes = false;

    void endField() {
      row.add(wasQuoted ? field.toString() : field.toString().trim());
      field.clear();
      wasQuoted = false;
    }

    void endRow() {
      endField();
      // A row of one empty unquoted cell is a blank line.
      if (row.length > 1 || row.first.isNotEmpty || rowHadQuotes) rows.add(row);
      row = <String>[];
      rowHadQuotes = false;
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inQuotes) {
        if (c != '"') {
          field.write(c);
        } else if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else if (c == '"' && !wasQuoted && field.toString().trim().isEmpty) {
        field.clear();
        inQuotes = wasQuoted = rowHadQuotes = true;
      } else if (c == delim) {
        endField();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      } else if (wasQuoted && (c == ' ' || c == '	')) {
        // Padding between a closing quote and the next delimiter.
      } else {
        field.write(c);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty || wasQuoted) endRow();
    return rows;
  }

  /// Merges [pdfs] in order, one output page per source page.
  static Uint8List mergePdfs(List<Uint8List> pdfs) {
    final out = PdfDocument();
    try {
      for (final bytes in pdfs) {
        final doc = PdfDocument(inputBytes: bytes);
        try {
          for (var i = 0; i < doc.pages.count; i++) {
            appendPageCopy(out, doc.pages[i]);
          }
        } finally {
          doc.dispose();
        }
      }
      return Uint8List.fromList(out.saveSync());
    } finally {
      out.dispose();
    }
  }

  /// One PDF holding only [pageNumbers] (1-indexed, in the given order).
  static Uint8List extractPages(Uint8List pdfBytes, List<int> pageNumbers) {
    final src = PdfDocument(inputBytes: pdfBytes);
    final out = PdfDocument();
    try {
      for (final p in pageNumbers) {
        if (p >= 1 && p <= src.pages.count) appendPageCopy(out, src.pages[p - 1]);
      }
      return Uint8List.fromList(out.saveSync());
    } finally {
      src.dispose();
      out.dispose();
    }
  }

  /// Re-saves with maximum stream compression. Returns null when that does not
  /// make the file smaller.
  static Uint8List? compressPdf(Uint8List pdfBytes) {
    final doc = PdfDocument(inputBytes: pdfBytes);
    try {
      doc.compressionLevel = PdfCompressionLevel.best;
      doc.fileStructure.crossReferenceType = PdfCrossReferenceType.crossReferenceStream;
      final out = Uint8List.fromList(doc.saveSync());
      return out.length < pdfBytes.length ? out : null;
    } finally {
      doc.dispose();
    }
  }

  /// All machine-readable text of the PDF.
  static String extractText(Uint8List pdfBytes) {
    final doc = PdfDocument(inputBytes: pdfBytes);
    try {
      return PdfTextExtractor(doc).extractText();
    } finally {
      doc.dispose();
    }
  }

  // ---- Background variants ----
  // Isolate.run copies everything its closure can reach. Built here, in static
  // methods, the closures capture only their arguments; built inside a State
  // method they would drag the State (not sendable) along and throw.

  static Future<Uint8List> wordToPdfInBackground(Uint8List docx, String title) => Isolate.run(() => wordToPdf(docxBytes: docx, documentTitle: title));

  static Future<Uint8List> pptxToPdfInBackground(Uint8List pptx, String title) => Isolate.run(() => pptxToPdf(pptxBytes: pptx, presentationTitle: title));

  static Future<Uint8List> excelToPdfInBackground(List<List<String>> rows, String title) => Isolate.run(() => excelToPdf(rows: rows, sheetTitle: title));

  static Future<Uint8List> extractPagesInBackground(Uint8List pdf, List<int> pages) => Isolate.run(() => extractPages(pdf, pages));

  static Future<Uint8List> extractPagesToZipInBackground(Uint8List pdf, List<int> pages, String baseName) =>
      Isolate.run(() => extractPagesToZip(pdfBytes: pdf, pageNumbers: pages, baseName: baseName));

  static Future<PdfComparisonResult> comparePdfsInBackground(Uint8List a, Uint8List b) => Isolate.run(() => comparePdfs(a, b));

  /// AES-256 encrypts [pdfBytes]. The owner password falls back to the user one.
  static Uint8List protectPdf(
    Uint8List pdfBytes, {
    required String userPassword,
    String ownerPassword = '',
    bool allowPrint = true,
    bool allowCopy = true,
    bool allowEdit = false,
  }) {
    final doc = PdfDocument(inputBytes: pdfBytes);
    try {
      final security = doc.security;
      security.userPassword = userPassword;
      security.ownerPassword = ownerPassword.isNotEmpty ? ownerPassword : userPassword;
      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
      security.permissions.clear();
      if (allowPrint) security.permissions.add(PdfPermissionsFlags.print);
      if (allowCopy) security.permissions.add(PdfPermissionsFlags.copyContent);
      if (allowEdit) security.permissions.add(PdfPermissionsFlags.editAnnotations);
      return Uint8List.fromList(doc.saveSync());
    } finally {
      doc.dispose();
    }
  }

  /// Strips characters that are illegal in XML 1.0 and escapes markup.
  static String _xmlText(String s) => s
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F￾￿]'), '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _xmlUnescape(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

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
      // Extract text inside <w:p>...</w:p>. The tag pattern skips attributes
      // (e.g. xml:space="preserve") and self-closing empty paragraphs.
      final pRegex = RegExp(r'<w:p(?:\s[^>]*[^>/])?>(.*?)</w:p>', dotAll: true);
      final tRegex = RegExp(r'<w:t(?:\s[^>]*[^>/])?>(.*?)</w:t>', dotAll: true);

      for (final pMatch in pRegex.allMatches(xmlContent)) {
        final pContent = pMatch.group(1) ?? '';
        final buffer = StringBuffer();
        for (final tMatch in tRegex.allMatches(pContent)) {
          buffer.write(_xmlUnescape(tMatch.group(1) ?? ''));
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

    // Pad ragged rows to a common width; the PDF table needs equal column counts.
    final width = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    List<String> pad(List<dynamic> r) => [...r.map((c) => c.toString()), for (var i = r.length; i < width; i++) ''];
    final headers = pad(rows.first);
    final dataRows = rows.skip(1).map(pad).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: pw_format.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(sheetTitle, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Text('Generated by ToolBox Pro', style: const pw.TextStyle(fontSize: 9, color: pw_format.PdfColors.grey700)),
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
        final tRegex = RegExp(r'<a:t(?:\s[^>]*[^>/])?>(.*?)</a:t>', dotAll: true);
        final textLines = <String>[];

        for (final match in tRegex.allMatches(slideXml)) {
          final t = _xmlUnescape(match.group(1) ?? '');
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
      // Extracted PDF text can contain control chars that make Word reject the file.
      docXmlBuffer.writeln('<w:p><w:r><w:t xml:space="preserve">${_xmlText(line.replaceAll('\r', ''))}</w:t></w:r></w:p>');
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
      // Columns are tabs or runs of 2+ spaces. Commas stay inside cells: splitting
      // on them cut numbers like "1,234.50" in two (csv.encode quotes them).
      final parts = line.trim().split(RegExp(r'\t+|\s{2,}'));
      rows.add(parts.map((p) => p.trim()).toList());
    }

    if (rows.isEmpty) {
      rows.add(['Extracted Content']);
      rows.add([text.trim()]);
    }

    return csv.encode(rows);
  }

  // ================= 6. PDF TO POWERPOINT (PPTX) =================
  /// Extracts PDF pages into an OpenXML .pptx presentation deck.
  /// Writes the minimum valid package (presentation, master, layout, theme);
  /// without those parts PowerPoint refuses to open the file.
  static Uint8List pdfToPptx(Uint8List pdfBytes) {
    final pdfDoc = PdfDocument(inputBytes: pdfBytes);
    final pageCount = pdfDoc.pages.count;
    final textExtractor = PdfTextExtractor(pdfDoc);

    const nsA = 'http://schemas.openxmlformats.org/drawingml/2006/main';
    const nsP = 'http://schemas.openxmlformats.org/presentationml/2006/main';
    const nsR = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    const relBase = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    const ctBase = 'application/vnd.openxmlformats-officedocument.presentationml';
    const xmlHead = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
    const emptyTree =
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>';

    final archive = Archive();
    void add(String name, String xml) {
      final bytes = utf8.encode(xmlHead + xml);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    String textBox(int id, String name, int y, int cy, int size, List<String> lines) {
      final paras = lines.isEmpty
          ? '<a:p/>'
          : lines.map((l) => '<a:p><a:r><a:rPr lang="en-US" sz="$size"/><a:t>${_xmlText(l)}</a:t></a:r></a:p>').join();
      return '<p:sp><p:nvSpPr><p:cNvPr id="$id" name="$name"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
          '<p:spPr><a:xfrm><a:off x="457200" y="$y"/><a:ext cx="11277600" cy="$cy"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
          '<p:txBody><a:bodyPr wrap="square"><a:normAutofit/></a:bodyPr><a:lstStyle/>$paras</p:txBody></p:sp>';
    }

    final slideCount = pageCount > 0 ? pageCount : 1;
    final slideOverrides = StringBuffer();
    final slideRels = StringBuffer();
    final slideIds = StringBuffer();

    for (int i = 0; i < slideCount; i++) {
      String pageText = '';
      try {
        pageText = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
      } catch (_) {
        pageText = 'Page ${i + 1} Content';
      }
      final lines = pageText.split('\n').map((l) => l.replaceAll('\r', '').trimRight()).where((l) => l.trim().isNotEmpty).toList();

      final n = i + 1;
      add(
        'ppt/slides/slide$n.xml',
        '<p:sld xmlns:a="$nsA" xmlns:p="$nsP" xmlns:r="$nsR"><p:cSld><p:spTree>$emptyTree'
            '${textBox(2, 'Title', 228600, 914400, 2800, ['Slide $n'])}'
            '${textBox(3, 'Content', 1295400, 5257800, 1400, lines)}'
            '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>',
      );
      add(
        'ppt/slides/_rels/slide$n.xml.rels',
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="$relBase/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>',
      );
      slideOverrides.write('<Override PartName="/ppt/slides/slide$n.xml" ContentType="$ctBase.slide+xml"/>');
      slideRels.write('<Relationship Id="rId${n + 2}" Type="$relBase/slide" Target="slides/slide$n.xml"/>');
      slideIds.write('<p:sldId id="${255 + n}" r:id="rId${n + 2}"/>');
    }

    pdfDoc.dispose();

    add(
      '[Content_Types].xml',
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/ppt/presentation.xml" ContentType="$ctBase.presentation.main+xml"/>'
          '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="$ctBase.slideMaster+xml"/>'
          '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="$ctBase.slideLayout+xml"/>'
          '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>'
          '$slideOverrides</Types>',
    );
    add(
      '_rels/.rels',
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="$relBase/officeDocument" Target="ppt/presentation.xml"/></Relationships>',
    );
    add(
      'ppt/presentation.xml',
      '<p:presentation xmlns:a="$nsA" xmlns:p="$nsP" xmlns:r="$nsR">'
          '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
          '<p:sldIdLst>$slideIds</p:sldIdLst>'
          '<p:sldSz cx="12192000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>',
    );
    add(
      'ppt/_rels/presentation.xml.rels',
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="$relBase/slideMaster" Target="slideMasters/slideMaster1.xml"/>'
          '<Relationship Id="rId2" Type="$relBase/theme" Target="theme/theme1.xml"/>'
          '$slideRels</Relationships>',
    );
    add(
      'ppt/slideMasters/slideMaster1.xml',
      '<p:sldMaster xmlns:a="$nsA" xmlns:p="$nsP" xmlns:r="$nsR"><p:cSld><p:spTree>$emptyTree</p:spTree></p:cSld>'
          '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" '
          'accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
          '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst></p:sldMaster>',
    );
    add(
      'ppt/slideMasters/_rels/slideMaster1.xml.rels',
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="$relBase/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
          '<Relationship Id="rId2" Type="$relBase/theme" Target="../theme/theme1.xml"/></Relationships>',
    );
    add(
      'ppt/slideLayouts/slideLayout1.xml',
      '<p:sldLayout xmlns:a="$nsA" xmlns:p="$nsP" xmlns:r="$nsR" type="blank" preserve="1">'
          '<p:cSld name="Blank"><p:spTree>$emptyTree</p:spTree></p:cSld>'
          '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>',
    );
    add(
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="$relBase/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>',
    );
    String clr(String tag, String hex) => '<a:$tag><a:srgbClr val="$hex"/></a:$tag>';
    const fill = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>';
    const font = '<a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/>';
    add(
      'ppt/theme/theme1.xml',
      '<a:theme xmlns:a="$nsA" name="Office Theme"><a:themeElements>'
          '<a:clrScheme name="Office">${clr('dk1', '000000')}${clr('lt1', 'FFFFFF')}${clr('dk2', '1F497D')}'
          '${clr('lt2', 'EEECE1')}${clr('accent1', '4F81BD')}${clr('accent2', 'C0504D')}${clr('accent3', '9BBB59')}'
          '${clr('accent4', '8064A2')}${clr('accent5', '4BACC6')}${clr('accent6', 'F79646')}'
          '${clr('hlink', '0000FF')}${clr('folHlink', '800080')}</a:clrScheme>'
          '<a:fontScheme name="Office"><a:majorFont>$font</a:majorFont><a:minorFont>$font</a:minorFont></a:fontScheme>'
          '<a:fmtScheme name="Office"><a:fillStyleLst>$fill$fill$fill</a:fillStyleLst>'
          '<a:lnStyleLst><a:ln w="9525">$fill</a:ln><a:ln w="25400">$fill</a:ln><a:ln w="38100">$fill</a:ln></a:lnStyleLst>'
          '<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle>'
          '<a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>'
          '<a:bgFillStyleLst>$fill$fill$fill</a:bgFillStyleLst></a:fmtScheme>'
          '</a:themeElements></a:theme>',
    );

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
      // Malformed date strings make these getters throw; don't fail the whole read.
      creationDate: _tryDate(() => info.creationDate),
      modificationDate: _tryDate(() => info.modificationDate),
      pageCount: doc.pages.count,
      sizeBytes: pdfBytes.length,
    );
    doc.dispose();
    return result;
  }

  static DateTime? _tryDate(DateTime Function() read) {
    try {
      return read();
    } catch (_) {
      return null;
    }
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
      appendPageCopy(singleDoc, sourceDoc.pages[pageNum - 1]);

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
    // Walk nested bookmarks too: saveBookmarks clears the whole outline, so
    // reading only top-level entries would silently delete the children.
    void walk(PdfBookmarkBase parent) {
      for (int i = 0; i < parent.count; i++) {
        final bm = parent[i];
        final dest = bm.destination ?? bm.namedDestination?.destination;
        final pageIndex = dest != null ? doc.pages.indexOf(dest.page) + 1 : 1;
        list.add(PdfBookmarkItem(title: bm.title, pageNumber: pageIndex > 0 ? pageIndex : 1));
        walk(bm);
      }
    }

    walk(doc.bookmarks);
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

    final diff = diffLines(linesA, linesB);
    final matching = diff.where((d) => d.type == 'same').length;
    final added = diff.where((d) => d.type == 'added').length;
    final removed = diff.where((d) => d.type == 'removed').length;

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

  /// Line diff via LCS, so an inserted/removed line doesn't mark every later
  /// line as changed (which a positional comparison does).
  static List<DiffLine> diffLines(List<String> a, List<String> b) {
    var pre = 0;
    while (pre < a.length && pre < b.length && a[pre] == b[pre]) {
      pre++;
    }
    var suf = 0;
    while (suf < a.length - pre && suf < b.length - pre && a[a.length - 1 - suf] == b[b.length - 1 - suf]) {
      suf++;
    }
    final midA = a.sublist(pre, a.length - suf);
    final midB = b.sublist(pre, b.length - suf);
    final n = midA.length, m = midB.length;
    final middle = <DiffLine>[];

    if (n * m > 4000000) {
      // ponytail: O(n*m) LCS table capped at ~16MB; huge rewrites fall back to removed-then-added.
      middle
        ..addAll(midA.map((l) => DiffLine(l, 'removed')))
        ..addAll(midB.map((l) => DiffLine(l, 'added')));
    } else {
      final w = m + 1;
      final lcs = Uint32List((n + 1) * w);
      for (var i = n - 1; i >= 0; i--) {
        for (var j = m - 1; j >= 0; j--) {
          lcs[i * w + j] = midA[i] == midB[j]
              ? lcs[(i + 1) * w + j + 1] + 1
              : (lcs[(i + 1) * w + j] >= lcs[i * w + j + 1] ? lcs[(i + 1) * w + j] : lcs[i * w + j + 1]);
        }
      }
      var i = 0, j = 0;
      while (i < n && j < m) {
        if (midA[i] == midB[j]) {
          middle.add(DiffLine(midA[i], 'same'));
          i++;
          j++;
        } else if (lcs[(i + 1) * w + j] >= lcs[i * w + j + 1]) {
          middle.add(DiffLine(midA[i++], 'removed'));
        } else {
          middle.add(DiffLine(midB[j++], 'added'));
        }
      }
      while (i < n) {
        middle.add(DiffLine(midA[i++], 'removed'));
      }
      while (j < m) {
        middle.add(DiffLine(midB[j++], 'added'));
      }
    }

    return [
      for (final l in a.sublist(0, pre)) DiffLine(l, 'same'),
      ...middle,
      for (final l in a.sublist(a.length - suf)) DiffLine(l, 'same'),
    ];
  }
}
