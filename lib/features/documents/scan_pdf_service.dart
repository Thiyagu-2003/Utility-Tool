import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart' as mlkit;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'office_document_service.dart';

/// Document-style enhancement filters, modelled on the presets scanner apps ship.
enum ScanFilter {
  original('Original'),
  magicColor('Magic Color'),
  lighten('No Shadow'),
  grayscale('Grayscale'),
  blackWhite('B&W');

  final String label;
  const ScanFilter(this.label);
}

/// Export compression presets. [maxSide] is in pixels (2480 ≈ A4 at 300 dpi);
/// [sizeFactor] is the rough output size relative to [high], used for the estimate.
enum ScanQuality {
  high('High', 2480, 88, 1.0),
  medium('Medium', 1754, 72, 0.45),
  small('Small', 1240, 60, 0.2);

  final String label;
  final int maxSide;
  final int jpegQuality;
  final double sizeFactor;
  const ScanQuality(this.label, this.maxSide, this.jpegQuality, this.sizeFactor);
}

/// Page sizes for scanner export. `null` format means "fit page to image".
enum ScanPageSize {
  fit('Fit to image', null),
  a4('A4', PdfPageFormat.a4),
  letter('Letter', PdfPageFormat.letter);

  final String label;
  final PdfPageFormat? format;
  const ScanPageSize(this.label, this.format);
}

/// One OCR line, with its box as fractions (0..1) of the page image.
class OcrLine {
  final String text;
  final double left, top, width, height;
  const OcrLine(this.text, this.left, this.top, this.width, this.height);
}

class ScanPdfPage {
  final Uint8List jpeg;
  final List<OcrLine> ocr;
  const ScanPdfPage(this.jpeg, [this.ocr = const []]);
}

class ScanPdfRequest {
  final List<ScanPdfPage> pages;

  /// Null = each page sized to its image.
  final PdfPageFormat? format;

  /// Rotate [format] to landscape for landscape images.
  final bool autoOrient;
  final double marginPt;
  final bool pageNumbers;
  final String title;

  /// Empty = no encryption.
  final String password;

  const ScanPdfRequest({required this.pages, this.format, this.autoOrient = true, this.marginPt = 0, this.pageNumbers = false, this.title = 'Scanned Document', this.password = ''});
}

/// Result of [renderScanPage]: a JPEG plus its pixel size.
typedef RenderedPage = ({Uint8List bytes, int width, int height});

/// Input for [renderScanPage]; a record so it can cross into `compute`.
typedef RenderJob = ({Uint8List source, ScanFilter filter, int rotation, int maxSide, int quality, bool trim});

class ScanPdfService {
  // ================= ML KIT SCANNER =================

  static bool get autoCropAvailable => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Opens Google's document scanner (edge detection, perspective crop, manual
  /// handles, filters, gallery import). Returns JPEG bytes per page, or null if
  /// the user cancelled. Throws on real failures (e.g. Play services missing).
  static Future<List<Uint8List>?> scanWithAutoCrop({int pageLimit = 50, bool galleryImport = true}) async {
    final scanner = mlkit.DocumentScanner(
      options: mlkit.DocumentScannerOptions(documentFormats: {mlkit.DocumentFormat.jpeg}, mode: mlkit.ScannerMode.full, pageLimit: pageLimit, isGalleryImport: galleryImport),
    );
    try {
      final result = await scanner.scanDocument();
      final out = <Uint8List>[];
      for (final path in result.images ?? const <String>[]) {
        final file = File(path);
        out.add(await file.readAsBytes());
        try {
          await file.delete(); // scanner leaves copies in the app cache
        } catch (_) {}
      }
      return out;
    } on PlatformException catch (e) {
      if ((e.message ?? '').toLowerCase().contains('cancel')) return null;
      rethrow;
    } finally {
      scanner.close().ignore();
    }
  }

  // ================= OCR =================

  static bool get ocrAvailable => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// OCR one rendered page; boxes are normalised to the page image so they
  /// survive scaling. Throws if ML Kit fails, so callers can tell "no text on
  /// the page" (empty list) from "recognition broke".
  static Future<List<OcrLine>> recognizeLines(TextRecognizer recognizer, RenderedPage page) async {
    final dir = await Directory.systemTemp.createTemp('scan_ocr');
    try {
      final file = File('${dir.path}/page.jpg');
      await file.writeAsBytes(page.bytes);
      final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
      final w = page.width.toDouble(), h = page.height.toDouble();
      return [
        for (final block in result.blocks)
          for (final line in block.lines) OcrLine(line.text, line.boundingBox.left / w, line.boundingBox.top / h, line.boundingBox.width / w, line.boundingBox.height / h),
      ];
    } finally {
      dir.delete(recursive: true).ignore();
    }
  }

  // ================= IMAGE PIPELINE =================

  /// Decodes [job.source], applies EXIF orientation, optional border trim,
  /// downscale, filter and rotation, and re-encodes as JPEG. Top-level-safe for `compute`.
  static RenderedPage renderScanPage(RenderJob job) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(job.source);
    } catch (_) {
      decoded = null; // some decoders throw RangeError on truncated/garbage input
    }
    if (decoded == null) throw const FormatException('Unsupported or corrupt image');
    // The filters write 0..255 channel values directly, so 16-bit/float and
    // palette (indexed PNG/GIF) images must be widened to plain 8-bit first.
    if (decoded.hasPalette || decoded.format != img.Format.uint8) {
      decoded = decoded.convert(format: img.Format.uint8, numChannels: decoded.hasAlpha ? 4 : 3, noAnimation: true);
    }
    var image = img.bakeOrientation(decoded);
    if (job.trim) image = trimBorders(image);
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > job.maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: job.maxSide, interpolation: img.Interpolation.average)
          : img.copyResize(image, height: job.maxSide, interpolation: img.Interpolation.average);
    }
    image = applyScanFilter(image, job.filter);
    if (job.rotation % 360 != 0) image = img.copyRotate(image, angle: job.rotation);
    return (bytes: Uint8List.fromList(img.encodeJpg(image, quality: job.quality)), width: image.width, height: image.height);
  }

  static Future<RenderedPage> render(RenderJob job) => compute(renderScanPage, job);

  static img.Image applyScanFilter(img.Image src, ScanFilter filter) {
    switch (filter) {
      case ScanFilter.original:
        return src;
      case ScanFilter.grayscale:
        return img.grayscale(src);
      case ScanFilter.lighten:
        return _flattenLighting(src);
      case ScanFilter.magicColor:
        return img.adjustColor(_flattenLighting(src), contrast: 1.2, saturation: 1.35);
      case ScanFilter.blackWhite:
        return _adaptiveThreshold(src);
    }
  }

  /// Box-filtered mean luminance around every pixel via an integral image (O(n)).
  static Float32List _localMeanLuminance(img.Image src, int radius) {
    final w = src.width, h = src.height;
    final integral = Float64List((w + 1) * (h + 1));
    for (var y = 0; y < h; y++) {
      var rowSum = 0.0;
      for (var x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        rowSum += img.getLuminanceRgb(p.r, p.g, p.b);
        integral[(y + 1) * (w + 1) + x + 1] = integral[y * (w + 1) + x + 1] + rowSum;
      }
    }
    final mean = Float32List(w * h);
    for (var y = 0; y < h; y++) {
      final y0 = y - radius < 0 ? 0 : y - radius, y1 = y + radius + 1 > h ? h : y + radius + 1;
      for (var x = 0; x < w; x++) {
        final x0 = x - radius < 0 ? 0 : x - radius, x1 = x + radius + 1 > w ? w : x + radius + 1;
        final sum = integral[y1 * (w + 1) + x1] - integral[y0 * (w + 1) + x1] - integral[y1 * (w + 1) + x0] + integral[y0 * (w + 1) + x0];
        mean[y * w + x] = sum / ((x1 - x0) * (y1 - y0));
      }
    }
    return mean;
  }

  static int _radiusFor(img.Image src) {
    final longest = src.width > src.height ? src.width : src.height;
    return (longest / 24).round().clamp(4, 80);
  }

  /// Divides out the local background brightness, so shadows and uneven
  /// lighting become paper-white while ink stays dark.
  static img.Image _flattenLighting(img.Image src) {
    final out = src.clone();
    final mean = _localMeanLuminance(src, _radiusFor(src));
    final w = src.width;
    for (final p in out) {
      final m = mean[p.y * w + p.x];
      final gain = 235 / (m < 24 ? 24 : m);
      p
        ..r = (p.r * gain).clamp(0, 255)
        ..g = (p.g * gain).clamp(0, 255)
        ..b = (p.b * gain).clamp(0, 255);
    }
    return out;
  }

  /// Black ink on white paper: a pixel is ink when noticeably darker than its
  /// neighbourhood, which survives shadows a global threshold would blacken.
  static img.Image _adaptiveThreshold(img.Image src) {
    final out = img.Image(width: src.width, height: src.height);
    final mean = _localMeanLuminance(src, _radiusFor(src));
    final w = src.width;
    for (final p in src) {
      final lum = img.getLuminanceRgb(p.r, p.g, p.b);
      final v = lum < mean[p.y * w + p.x] * 0.88 ? 0 : 255;
      out.setPixelRgb(p.x, p.y, v, v, v);
    }
    return out;
  }

  /// Crops uniform near-white or near-black borders (scanner bed, letterboxing,
  /// screenshot bars). Returns [src] unchanged when nothing (or everything) is border.
  static img.Image trimBorders(img.Image src, {int tolerance = 22, double minBorderRatio = 0.985}) {
    final w = src.width, h = src.height;
    if (w < 3 || h < 3) return src;

    // 1 = near-white, -1 = near-black, 0 = content.
    int tone(int x, int y) {
      final p = src.getPixel(x, y);
      final lum = img.getLuminanceRgb(p.r, p.g, p.b);
      if (lum >= 255 - tolerance) return 1;
      if (lum <= tolerance) return -1;
      return 0;
    }

    bool isBorderLine(int count, int Function(int i) toneAt) {
      final step = count > 600 ? count ~/ 600 : 1;
      var white = 0, black = 0, total = 0;
      for (var i = 0; i < count; i += step) {
        final t = toneAt(i);
        if (t == 1) white++;
        if (t == -1) black++;
        total++;
      }
      return white >= total * minBorderRatio || black >= total * minBorderRatio;
    }

    var top = 0, bottom = h - 1, left = 0, right = w - 1;
    while (top < bottom && isBorderLine(w, (x) => tone(x, top))) {
      top++;
    }
    while (bottom > top && isBorderLine(w, (x) => tone(x, bottom))) {
      bottom--;
    }
    while (left < right && isBorderLine(bottom - top + 1, (y) => tone(left, top + y))) {
      left++;
    }
    while (right > left && isBorderLine(bottom - top + 1, (y) => tone(right, top + y))) {
      right--;
    }

    final cw = right - left + 1, ch = bottom - top + 1;
    if (cw == w && ch == h) return src;
    // A blank page is "all border": keep it rather than crop to a sliver.
    if (cw < 3 || ch < 3) return src;
    return img.copyCrop(src, x: left, y: top, width: cw, height: ch);
  }

  // ================= PAGE MATH & NAMING =================

  /// Page format for an image of [imgW]x[imgH] px. With no [base], the page
  /// hugs the image (long side 842pt = A4 height) plus [margin] on each side.
  static PdfPageFormat pageFormatForImage(PdfPageFormat? base, int imgW, int imgH, {double margin = 0, bool autoOrient = true}) {
    if (base == null) {
      final scale = 842 / (imgW > imgH ? imgW : imgH);
      return PdfPageFormat(imgW * scale + margin * 2, imgH * scale + margin * 2, marginAll: margin);
    }
    final landscapeImage = imgW > imgH;
    final oriented = autoOrient ? (landscapeImage ? base.landscape : base.portrait) : base;
    return oriented.copyWith(marginLeft: margin, marginRight: margin, marginTop: margin, marginBottom: margin);
  }

  /// Largest [imgW]x[imgH] rectangle fitting [boxW]x[boxH], centred: (left, top, width, height).
  static (double, double, double, double) containRect(double boxW, double boxH, int imgW, int imgH) {
    final scale = boxW / imgW < boxH / imgH ? boxW / imgW : boxH / imgH;
    final w = imgW * scale, h = imgH * scale;
    return ((boxW - w) / 2, (boxH - h) / 2, w, h);
  }

  static String defaultScanName([DateTime? now]) => 'Scan_${DateFormat('yyyyMMdd_HHmm').format(now ?? DateTime.now())}';

  /// Strips path/illegal characters and guarantees a single `.pdf` suffix.
  static String pdfFileName(String raw, String fallback) {
    var name = raw.trim().replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '').replaceAll(RegExp(r'\s+'), '_');
    return '${name.isEmpty ? fallback : name}.pdf';
  }

  /// Moves the item at [from] so it ends up at index [to].
  static void moveItem<T>(List<T> list, int from, int to) {
    if (from == to || from < 0 || from >= list.length) return;
    final item = list.removeAt(from);
    list.insert(to.clamp(0, list.length), item);
  }

  static int nextRotation(int degrees) => (degrees + 90) % 360;

  static String formatBytes(num bytes) {
    if (bytes < 1024) return '${bytes.round()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ================= PDF =================

  /// Helvetica can't encode most non-Latin-1 glyphs; drop them from the invisible layer.
  static String _latin1(String s) => String.fromCharCodes(s.runes.where((r) => r >= 0x20 && r <= 0xFF));

  /// Builds a PDF with one image per page, an optional invisible OCR text layer
  /// positioned over the words (searchable/selectable), and optional AES-256 password.
  static Future<Uint8List> buildScanPdf(ScanPdfRequest req) async {
    final doc = pw.Document(title: req.title);
    for (var i = 0; i < req.pages.length; i++) {
      final page = req.pages[i];
      final image = pw.MemoryImage(page.jpeg);
      final w = image.width ?? 1, h = image.height ?? 1;
      final format = pageFormatForImage(req.format, w, h, margin: req.marginPt, autoOrient: req.autoOrient);
      final (left, top, dw, dh) = containRect(format.availableWidth, format.availableHeight, w, h);

      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (_) => pw.Stack(
            children: [
              pw.Positioned(
                left: left,
                top: top,
                child: pw.SizedBox(
                  width: dw,
                  height: dh,
                  child: pw.Image(image, fit: pw.BoxFit.fill),
                ),
              ),
              for (final line in page.ocr)
                if (_latin1(line.text).trim().isNotEmpty && line.width > 0 && line.height > 0)
                  pw.Positioned(
                    left: left + line.left * dw,
                    top: top + line.top * dh,
                    child: pw.SizedBox(
                      width: line.width * dw,
                      height: line.height * dh,
                      child: pw.FittedBox(
                        fit: pw.BoxFit.fill,
                        child: pw.Text(_latin1(line.text), softWrap: false, style: const pw.TextStyle(renderingMode: PdfTextRenderingMode.invisible)),
                      ),
                    ),
                  ),
              if (req.pageNumbers)
                pw.Positioned(
                  right: 4,
                  bottom: 2,
                  child: pw.Text('Page ${i + 1} of ${req.pages.length}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ),
            ],
          ),
        ),
      );
    }
    final bytes = await doc.save();
    if (req.password.isEmpty) return bytes;
    return OfficeDocumentService.protectPdf(bytes, userPassword: req.password);
  }

  static Future<Uint8List> buildScanPdfInBackground(ScanPdfRequest req) => compute(buildScanPdf, req);
}
