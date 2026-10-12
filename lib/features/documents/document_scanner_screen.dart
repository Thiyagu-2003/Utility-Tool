import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/share_utils.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';
import 'scan_pdf_service.dart';

// Not the ML Kit `ScannerMode` (that one is used via the `mlkit` prefix in scan_pdf_service.dart).
enum ScannerMode {
  document('Multi-Page Document', Icons.document_scanner_rounded),
  idCard('ID Card Front & Back', Icons.badge_rounded),
  signature('Signature Pad', Icons.draw_rounded);

  final String label;
  final IconData icon;
  const ScannerMode(this.label, this.icon);
}

class ScannedPage {
  /// As captured (auto-cropped scan or imported photo); every edit re-renders from this.
  Uint8List source;

  /// Rendered at [ScanQuality.high] with [filter] and [rotation] applied.
  Uint8List bytes;
  int width;
  int height;
  ScanFilter filter = ScanFilter.original;
  int rotation = 0;
  int version = 0;
  bool busy = false;

  ScannedPage(this.source, RenderedPage r) : bytes = r.bytes, width = r.width, height = r.height;
}

class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({super.key});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  ScannerMode _scannerMode = ScannerMode.document;

  // Multi-page document scan state
  final List<ScannedPage> _pages = [];
  ScannedPage? _selected;
  bool _scannerFailed = false;
  String? _busyMessage;

  // Export settings
  final TextEditingController _nameController = TextEditingController(text: ScanPdfService.defaultScanName());
  final TextEditingController _passwordController = TextEditingController();
  ScanPageSize _pageSize = ScanPageSize.fit;
  bool _smallMargin = false;
  ScanQuality _quality = ScanQuality.high;
  bool _ocr = false;
  bool _protect = false;
  bool _showPassword = false;

  // ID Card State
  Uint8List? _idCardFront;
  Uint8List? _idCardBack;

  // Signature Pad State
  final List<List<Offset>> _signatureStrokes = [];
  final List<Color> _strokeColors = [];
  Color _penColor = Colors.black;
  final double _strokeWidth = 3.0;
  final GlobalKey _signatureKey = GlobalKey();

  bool get _useScanner => ScanPdfService.autoCropAvailable && !_scannerFailed;
  bool get _anyBusy => _busyMessage != null || _pages.any((p) => p.busy);

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, action: action));
  }

  // ================= CAPTURE =================

  /// Gets page images from the auto-crop scanner, or the file picker when
  /// [scanner] is false / unavailable. Empty on cancel.
  Future<List<Uint8List>> _acquire({required bool scanner, required int limit}) async {
    PreferencesService().triggerHaptic();
    if (scanner && _useScanner) {
      try {
        return await ScanPdfService.scanWithAutoCrop(pageLimit: limit) ?? const [];
      } catch (e) {
        if (!mounted) return const [];
        setState(() => _scannerFailed = true);
        _showSnack('Auto-crop scanner unavailable on this device (needs Google Play services). Opening photo import instead.');
      }
    }
    try {
      if (limit == 1) {
        final file = await FilePicker.pickFile(type: FileType.image);
        return file == null ? const [] : [await file.readAsBytes()];
      }
      final files = await FilePicker.pickFiles(type: FileType.image);
      return [for (final f in files) await f.readAsBytes()];
    } catch (e) {
      _showSnack('Could not open images: $e');
      return const [];
    }
  }

  Future<void> _addPages({required bool scanner}) async {
    final images = await _acquire(scanner: scanner, limit: 50);
    if (images.isEmpty || !mounted) return;
    var failed = 0;
    for (var i = 0; i < images.length; i++) {
      if (!mounted) return;
      setState(() => _busyMessage = 'Processing page ${i + 1} of ${images.length}…');
      try {
        final r = await ScanPdfService.render(_job(images[i], ScanFilter.original, 0));
        if (!mounted) return;
        final page = ScannedPage(images[i], r);
        setState(() {
          _pages.add(page);
          _selected ??= page;
        });
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() {
      _busyMessage = null;
      _selected = _pages.isNotEmpty ? (_selected ?? _pages.last) : null;
    });
    if (failed > 0) _showSnack('$failed image(s) could not be read and were skipped.');
  }

  RenderJob _job(Uint8List source, ScanFilter filter, int rotation) =>
      (source: source, filter: filter, rotation: rotation, maxSide: ScanQuality.high.maxSide, quality: ScanQuality.high.jpegQuality, trim: false);

  /// Re-renders [page] from its source. Results for an edit superseded by a
  /// newer one (or a deleted page) are dropped.
  Future<void> _rerender(ScannedPage page, {ScanFilter? filter, int? rotation, Uint8List? source}) async {
    final f = filter ?? page.filter, rot = rotation ?? page.rotation;
    final version = ++page.version;
    setState(() => page.busy = true);
    try {
      final r = await ScanPdfService.render(_job(source ?? page.source, f, rot));
      if (!mounted || page.version != version) return;
      setState(() {
        page
          ..source = source ?? page.source // only swapped once the new image rendered
          ..bytes = r.bytes
          ..width = r.width
          ..height = r.height
          ..filter = f
          ..rotation = rot
          ..busy = false;
      });
    } catch (e) {
      if (!mounted || page.version != version) return;
      setState(() => page.busy = false);
      _showSnack('Could not process this page.');
    }
  }

  Future<void> _applyFilterToAll(ScanFilter filter) async {
    PreferencesService().triggerHaptic();
    final targets = _pages.where((p) => p.filter != filter).toList();
    for (final p in targets) {
      if (!mounted) return;
      if (!_pages.contains(p)) continue;
      await _rerender(p, filter: filter);
    }
    _showSnack('${filter.label} applied to all ${_pages.length} pages.');
  }

  Future<void> _retake(ScannedPage page) async {
    final images = await _acquire(scanner: true, limit: 1);
    if (images.isEmpty || !mounted || !_pages.contains(page)) return;
    await _rerender(page, rotation: 0, source: images.first);
  }

  void _deletePage(ScannedPage page) {
    PreferencesService().triggerHaptic();
    final idx = _pages.indexOf(page);
    if (idx < 0) return;
    setState(() {
      page.version++; // cancel any in-flight render
      _pages.removeAt(idx);
      if (_selected == page) _selected = _pages.isEmpty ? null : _pages[idx.clamp(0, _pages.length - 1)];
    });
  }

  void _openZoom(ScannedPage page) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 6,
                child: Center(child: Image.memory(page.bytes, fit: BoxFit.contain)),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Close',
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= EXPORT =================

  Future<void> _exportDocumentPdf() async {
    if (_pages.isEmpty || _anyBusy) return;
    final password = _passwordController.text;
    if (_protect && password.isEmpty) {
      _showSnack('Enter a password, or turn off password protection.');
      return;
    }
    PreferencesService().triggerHaptic();
    final quality = _quality;
    final pages = List<ScannedPage>.of(_pages);
    TextRecognizer? recognizer;
    var ocrFailures = 0;
    try {
      final out = <ScanPdfPage>[];
      if (_ocr && ScanPdfService.ocrAvailable) recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      for (var i = 0; i < pages.length; i++) {
        if (!mounted) return;
        setState(() => _busyMessage = recognizer != null ? 'Reading text on page ${i + 1} of ${pages.length}…' : 'Preparing page ${i + 1} of ${pages.length}…');
        var r = (bytes: pages[i].bytes, width: pages[i].width, height: pages[i].height);
        if (quality != ScanQuality.high) {
          r = await ScanPdfService.render((source: r.bytes, filter: ScanFilter.original, rotation: 0, maxSide: quality.maxSide, quality: quality.jpegQuality, trim: false));
        }
        var lines = const <OcrLine>[];
        if (recognizer != null) {
          try {
            lines = await ScanPdfService.recognizeLines(recognizer, r);
          } catch (_) {
            ocrFailures++; // the page still exports as an image
          }
        }
        out.add(ScanPdfPage(r.bytes, lines));
      }
      if (!mounted) return;
      setState(() => _busyMessage = 'Building PDF…');
      final name = ScanPdfService.pdfFileName(_nameController.text, ScanPdfService.defaultScanName());
      final pdf = await ScanPdfService.buildScanPdfInBackground(
        ScanPdfRequest(pages: out, format: _pageSize.format, marginPt: _smallMargin ? 18 : 0, title: name.replaceAll('.pdf', ''), password: _protect ? password : ''),
      );
      if (!mounted) return;
      setState(() => _busyMessage = null);
      if (ocrFailures > 0) _showSnack('Text recognition failed on $ocrFailures page(s); they are exported without searchable text.');
      await shareFileBytes(pdf, name);
    } catch (e) {
      _showSnack('Export error: $e');
    } finally {
      recognizer?.close();
      if (mounted) setState(() => _busyMessage = null);
    }
  }

  // ================= ID CARD =================

  Future<void> _pickIdCard({required bool isFront}) async {
    final images = await _acquire(scanner: true, limit: 1);
    if (images.isEmpty || !mounted) return;
    // Gallery photos carry an EXIF rotation that the PDF writer ignores, so
    // bake it in (and cap the size) before the image is embedded.
    final Uint8List bytes;
    try {
      bytes = (await ScanPdfService.render(_job(images.first, ScanFilter.original, 0))).bytes;
    } catch (_) {
      _showSnack('That image could not be read.');
      return;
    }
    if (!mounted) return;
    setState(() {
      if (isFront) {
        _idCardFront = bytes;
      } else {
        _idCardBack = bytes;
      }
    });
  }

  Future<void> _exportIdCardPdf() async {
    if (_idCardFront == null && _idCardBack == null) return;
    PreferencesService().triggerHaptic();

    try {
      final pdf = pw.Document();
      final frontImg = _idCardFront != null ? pw.MemoryImage(_idCardFront!) : null;
      final backImg = _idCardBack != null ? pw.MemoryImage(_idCardBack!) : null;

      pw.Widget side(pw.ImageProvider image, String label) => pw.Column(
        children: [
          pw.Container(
            width: 320,
            height: 200,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 8),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            children: [
              pw.Text('ID CARD COPY', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 24),
              if (frontImg != null) side(frontImg, 'Front Side'),
              if (frontImg != null && backImg != null) pw.SizedBox(height: 32),
              if (backImg != null) side(backImg, 'Back Side'),
            ],
          ),
        ),
      );

      await shareFileBytes(await pdf.save(), 'ID_Card_Document.pdf');
    } catch (e) {
      _showSnack('ID Card export error: $e');
    }
  }

  // ================= SIGNATURE =================

  Future<void> _exportSignaturePng() async {
    if (_signatureStrokes.isEmpty) return;
    PreferencesService().triggerHaptic();
    try {
      final boundary = _signatureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      await shareFileBytes(data.buffer.asUint8List(), 'Signature.png');
    } catch (e) {
      _showSnack('Signature export error: $e');
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Document Scanner',
      category: ToolCategory.documents,
      toolId: 'document_scanner',
      onReset: () {
        setState(() {
          for (final p in _pages) {
            p.version++;
          }
          _pages.clear();
          _selected = null;
          _idCardFront = null;
          _idCardBack = null;
          _signatureStrokes.clear();
          _strokeColors.clear();
          _nameController.text = ScanPdfService.defaultScanName();
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeatureTabSelector<ScannerMode>(
            tabs: ScannerMode.values.map((mode) => FeatureTabItem(value: mode, label: mode.label, icon: mode.icon)).toList(),
            activeTab: _scannerMode,
            onTabSelected: (mode) => setState(() => _scannerMode = mode),
            accentColor: AppColors.catPdf,
            title: 'Scanner Mode',
          ),
          const SizedBox(height: 16),
          if (_scannerMode == ScannerMode.document) ..._buildDocumentMode(isDark),
          if (_scannerMode == ScannerMode.idCard) ..._buildIdCardMode(isDark),
          if (_scannerMode == ScannerMode.signature) ..._buildSignatureMode(),
        ],
      ),
    );
  }

  BoxDecoration _panel(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
  );

  Color _muted(bool isDark) => isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  ButtonStyle get _primaryStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.catPdf,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  ButtonStyle get _secondaryStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.catPdf,
    side: BorderSide(color: AppColors.catPdf.withValues(alpha: 0.6)),
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _choice<T>(String label, List<T> values, T selected, String Function(T) labelOf, ValueChanged<T> onSelect, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted(isDark)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(labelOf(v)),
                  selected: v == selected,
                  selectedColor: AppColors.catPdf,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: v == selected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  onSelected: (_) => onSelect(v),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDocumentMode(bool isDark) {
    final totalBytes = _pages.fold<int>(0, (s, p) => s + p.bytes.length) * _quality.sizeFactor;
    final selected = _selected;
    return [
      ResultCard(
        title: 'Scanned Document',
        primaryResult: '${_pages.length} ${_pages.length == 1 ? 'Page' : 'Pages'}',
        subtitle: _useScanner ? 'Auto edge detection, perspective crop & shadow removal' : 'Import photos, then enhance, reorder and export',
        accentColor: AppColors.catPdf,
        breakdowns: [
          BreakdownItem(label: 'Page Size', value: _pageSize.label),
          BreakdownItem(label: 'Est. Size', value: _pages.isEmpty ? '—' : '≈ ${ScanPdfService.formatBytes(totalBytes)}'),
          BreakdownItem(label: 'Status', value: _pages.isEmpty ? 'Ready to Scan' : 'Ready to Export'),
        ],
      ),
      const SizedBox(height: 16),
      if (_useScanner) ...[
        ElevatedButton.icon(
          icon: const Icon(Icons.document_scanner_rounded),
          label: const Text('Scan with Auto-Crop'),
          style: _primaryStyle,
          onPressed: _anyBusy ? null : () => _addPages(scanner: true),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.photo_library_rounded),
          label: const Text('Import Photos (no crop)'),
          style: _secondaryStyle,
          onPressed: _anyBusy ? null : () => _addPages(scanner: false),
        ),
      ] else ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: _muted(isDark)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Auto-crop scanning needs Android with Google Play services. Import photos and use the filters to clean them up.', style: TextStyle(fontSize: 13, color: _muted(isDark))),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(icon: const Icon(Icons.photo_library_rounded), label: const Text('Import Photos'), style: _primaryStyle, onPressed: _anyBusy ? null : () => _addPages(scanner: false)),
      ],
      if (_busyMessage != null) ...[
        const SizedBox(height: 14),
        Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.catPdf)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_busyMessage!, style: TextStyle(fontSize: 13, color: _muted(isDark))),
            ),
          ],
        ),
      ],
      if (selected != null) ...[
        const SizedBox(height: 20),
        _buildPageEditor(selected, isDark),
        const SizedBox(height: 20),
        _buildPageGrid(isDark),
        const SizedBox(height: 20),
        _buildExportSettings(isDark),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: _busyMessage != null ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_busyMessage != null ? 'Working…' : 'Export & Share PDF'),
          style: _primaryStyle,
          onPressed: _anyBusy ? null : _exportDocumentPdf,
        ),
      ],
    ];
  }

  Widget _buildPageEditor(ScannedPage page, bool isDark) {
    final index = _pages.indexOf(page);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panel(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Page ${index + 1} of ${_pages.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              if (page.busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.catPdf)),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: 'Open page ${index + 1} full screen',
            child: GestureDetector(
              onTap: () => _openZoom(page),
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(color: isDark ? AppColors.darkBg : AppColors.lightBg, borderRadius: BorderRadius.circular(12)),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.memory(page.bytes, fit: BoxFit.contain, gaplessPlayback: true),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.rotate_right_rounded),
                label: const Text('Rotate'),
                onPressed: page.busy ? null : () => _rerender(page, rotation: ScanPdfService.nextRotation(page.rotation)),
              ),
              TextButton.icon(icon: const Icon(Icons.flip_camera_android_rounded), label: const Text('Retake'), onPressed: _anyBusy ? null : () => _retake(page)),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () => _deletePage(page),
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            'Filter',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted(isDark)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in ScanFilter.values)
                ChoiceChip(
                  label: Text(f.label),
                  selected: page.filter == f,
                  selectedColor: AppColors.catPdf,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: page.filter == f ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  onSelected: page.busy ? null : (_) => _rerender(page, filter: f),
                ),
            ],
          ),
          if (_pages.length > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.done_all_rounded),
                label: Text('Apply ${page.filter.label} to all pages'),
                onPressed: _anyBusy ? null : () => _applyFilterToAll(page.filter),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageGrid(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text('Tap to edit · long-press and drag to reorder', style: TextStyle(fontSize: 12, color: _muted(isDark))),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 110).floor().clamp(3, 6);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72),
              itemCount: _pages.length + 1,
              itemBuilder: (context, idx) {
                if (idx == _pages.length) return _addTile(isDark);
                final page = _pages[idx];
                final tile = _thumb(page, idx, isDark);
                return DragTarget<ScannedPage>(
                  onWillAcceptWithDetails: (d) => d.data != page,
                  onAcceptWithDetails: (d) => setState(() => ScanPdfService.moveItem(_pages, _pages.indexOf(d.data), idx)),
                  builder: (context, candidates, _) => LongPressDraggable<ScannedPage>(
                    data: page,
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(width: 90, height: 125, child: Opacity(opacity: 0.85, child: tile)),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: tile),
                    child: candidates.isNotEmpty ? Opacity(opacity: 0.6, child: tile) : tile,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _thumb(ScannedPage page, int idx, bool isDark) {
    final isSelected = page == _selected;
    return GestureDetector(
      onTap: () {
        PreferencesService().triggerHaptic();
        setState(() => _selected = page);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : AppColors.lightBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.catPdf : (isDark ? AppColors.darkBorder : AppColors.lightBorder), width: isSelected ? 2.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Image.memory(page.bytes, fit: BoxFit.contain, cacheWidth: 300, gaplessPlayback: true),
            ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: isSelected ? AppColors.catPdf : Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '${idx + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (page.busy)
              const ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _addTile(bool isDark) {
    return Semantics(
      button: true,
      label: 'Add pages',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _anyBusy ? null : () => _addPages(scanner: true),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.catPdf.withValues(alpha: 0.5), width: 1.5),
            color: AppColors.catPdf.withValues(alpha: isDark ? 0.10 : 0.06),
          ),
          child: const Center(child: Icon(Icons.add_rounded, color: AppColors.catPdf, size: 32)),
        ),
      ),
    );
  }

  Widget _buildExportSettings(bool isDark) {
    final pageBytes = _pages.fold<int>(0, (s, p) => s + p.bytes.length);
    // Material (not a decorated Container) so the switch tiles' ink shows.
    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ModernTextField(label: 'File Name', controller: _nameController, hintText: 'Scan_20260101_0900', prefixIcon: Icons.drive_file_rename_outline_rounded),
            _choice<ScanPageSize>('Page Size', ScanPageSize.values, _pageSize, (s) => s.label, (s) => setState(() => _pageSize = s), isDark),
            _choice<bool>('Margins', const [false, true], _smallMargin, (m) => m ? 'Small' : 'None', (m) => setState(() => _smallMargin = m), isDark),
            _choice<ScanQuality>(
              'Image Quality',
              ScanQuality.values,
              _quality,
              (q) => '${q.label} · ≈${ScanPdfService.formatBytes(pageBytes * q.sizeFactor)}',
              (q) => setState(() => _quality = q),
              isDark,
            ),
            const SizedBox(height: 8),
            if (ScanPdfService.ocrAvailable)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Searchable text (OCR)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Recognises the words so you can search and copy them in the PDF'),
                value: _ocr,
                activeThumbColor: AppColors.catPdf,
                onChanged: (v) => setState(() => _ocr = v),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Password protect', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('AES-256 encryption; the password is needed to open the file'),
              value: _protect,
              activeThumbColor: AppColors.catPdf,
              onChanged: (v) => setState(() => _protect = v),
            ),
            if (_protect)
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'PDF Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _idSlot({required bool isFront, required bool isDark}) {
    final bytes = isFront ? _idCardFront : _idCardBack;
    final side = isFront ? 'Front' : 'Back';
    return Container(
      width: double.infinity,
      height: 190,
      decoration: _panel(isDark),
      clipBehavior: Clip.antiAlias,
      child: bytes != null
          ? Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Retake $side',
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    onPressed: () => _pickIdCard(isFront: isFront),
                  ),
                ),
              ],
            )
          : InkWell(
              onTap: () => _pickIdCard(isFront: isFront),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isFront ? Icons.badge_outlined : Icons.credit_card_rounded, size: 40, color: AppColors.catPdf),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to ${_useScanner ? 'scan' : 'add'} ID card ($side side)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_useScanner) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Edges are detected and cropped automatically',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: _muted(isDark)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _buildIdCardMode(bool isDark) {
    return [
      ResultCard(title: 'ID Card Mode', primaryResult: 'Front & Back on 1 Page', subtitle: 'Optimized layout for Driver\'s License, National IDs & Badges', accentColor: AppColors.catPdf),
      const SizedBox(height: 20),
      _idSlot(isFront: true, isDark: isDark),
      const SizedBox(height: 16),
      _idSlot(isFront: false, isDark: isDark),
      const SizedBox(height: 24),
      if (_idCardFront != null || _idCardBack != null)
        ElevatedButton.icon(icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('Export ID Card PDF'), style: _primaryStyle, onPressed: _exportIdCardPdf),
    ];
  }

  List<Widget> _buildSignatureMode() {
    return [
      ResultCard(title: 'Digital Signature', primaryResult: 'Sign & Annotate', subtitle: 'Draw with finger or stylus for document signing', accentColor: AppColors.catPdf),
      const SizedBox(height: 16),
      Container(
        height: 220,
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.catPdf.withValues(alpha: 0.4), width: 2),
        ),
        // Claim the gesture arena on touch-down so the page doesn't scroll
        // (and steal vertical strokes) while signing.
        child: RawGestureDetector(
          gestures: {EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(EagerGestureRecognizer.new, (_) {})},
          child: Listener(
            onPointerDown: (e) => setState(() {
              _signatureStrokes.add([e.localPosition]);
              _strokeColors.add(_penColor);
            }),
            onPointerMove: (e) {
              if (_signatureStrokes.isEmpty) return;
              setState(() => _signatureStrokes.last.add(e.localPosition));
            },
            child: RepaintBoundary(
              key: _signatureKey,
              child: CustomPaint(
                painter: SignaturePainter(strokes: _signatureStrokes, colors: _strokeColors, strokeWidth: _strokeWidth),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          for (final c in [Colors.black, const Color(0xFF1E3A8A), const Color(0xFFDC2626)])
            Semantics(
              button: true,
              selected: _penColor == c,
              label: 'Pen colour',
              child: GestureDetector(
                onTap: () => setState(() => _penColor = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: _penColor == c ? AppColors.primaryOrange : Colors.grey, width: _penColor == c ? 3 : 1),
                  ),
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo_rounded),
            onPressed: _signatureStrokes.isNotEmpty
                ? () => setState(() {
                    _signatureStrokes.removeLast();
                    _strokeColors.removeLast();
                  })
                : null,
          ),
          IconButton(
            tooltip: 'Clear Pad',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () => setState(() {
              _signatureStrokes.clear();
              _strokeColors.clear();
            }),
          ),
        ],
      ),
      const SizedBox(height: 14),
      ElevatedButton.icon(icon: const Icon(Icons.image_rounded), label: const Text('Export Signature PNG'), style: _primaryStyle, onPressed: _signatureStrokes.isEmpty ? null : _exportSignaturePng),
    ];
  }
}

class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Color> colors; // one per stroke, so changing pen colour doesn't recolour earlier strokes
  final double strokeWidth;

  SignaturePainter({required this.strokes, required this.colors, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    for (int s = 0; s < strokes.length; s++) {
      final stroke = strokes[s];
      paint.color = s < colors.length ? colors[s] : Colors.black;
      if (stroke.length == 1) canvas.drawCircle(stroke.first, strokeWidth / 2, paint); // a tap is a dot
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
