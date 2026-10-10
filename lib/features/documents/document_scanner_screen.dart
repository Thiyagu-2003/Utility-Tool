import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum ScannerMode {
  document('Multi-Page Document', Icons.document_scanner_rounded),
  idCard('ID Card Front & Back', Icons.badge_rounded),
  signature('Signature Pad', Icons.draw_rounded);

  final String label;
  final IconData icon;
  const ScannerMode(this.label, this.icon);
}

enum DocFilter {
  original('Color'),
  grayscale('Grayscale'),
  blackAndWhite('B&W Contrast');

  final String label;
  const DocFilter(this.label);
}

class ScannedPage {
  Uint8List originalBytes;
  Uint8List processedBytes;
  DocFilter currentFilter;
  int rotationDegrees;

  ScannedPage({
    required this.originalBytes,
    required this.processedBytes,
    this.currentFilter = DocFilter.original,
    this.rotationDegrees = 0,
  });
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

  // ID Card State
  Uint8List? _idCardFront;
  Uint8List? _idCardBack;

  // Signature Pad State
  final List<List<Offset>> _signatureStrokes = [];
  List<Offset> _currentStroke = [];
  Color _penColor = Colors.black;
  final double _strokeWidth = 3.0;

  Future<void> _addDocumentPage() async {
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (files.isNotEmpty) {
        for (final f in files) {
          final bytes = await f.readAsBytes();
          _pages.add(ScannedPage(
            originalBytes: bytes,
            processedBytes: bytes,
          ));
        }
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding image: $e')),
        );
      }
    }
  }

  Future<void> _pickIdCard({required bool isFront}) async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          if (isFront) {
            _idCardFront = bytes;
          } else {
            _idCardBack = bytes;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _applyFilter(int pageIndex, DocFilter filter) {
    PreferencesService().triggerHaptic();
    final page = _pages[pageIndex];

    try {
      final decoded = img_lib.decodeImage(page.originalBytes);
      if (decoded == null) return;

      img_lib.Image processed = decoded;
      if (filter == DocFilter.grayscale) {
        processed = img_lib.grayscale(decoded);
      } else if (filter == DocFilter.blackAndWhite) {
        processed = img_lib.grayscale(decoded);
        processed = img_lib.contrast(processed, contrast: 150);
      }

      final encoded = Uint8List.fromList(img_lib.encodeJpg(processed, quality: 90));
      setState(() {
        page.currentFilter = filter;
        page.processedBytes = encoded;
      });
    } catch (e) {
      // Fallback
    }
  }

  void _rotatePage(int pageIndex) {
    PreferencesService().triggerHaptic();
    final page = _pages[pageIndex];
    try {
      final decoded = img_lib.decodeImage(page.processedBytes);
      if (decoded == null) return;

      final rotated = img_lib.copyRotate(decoded, angle: 90);
      final encoded = Uint8List.fromList(img_lib.encodeJpg(rotated, quality: 90));
      setState(() {
        page.rotationDegrees = (page.rotationDegrees + 90) % 360;
        page.processedBytes = encoded;
      });
    } catch (_) {}
  }

  Future<void> _exportDocumentPdf() async {
    if (_pages.isEmpty) return;
    PreferencesService().triggerHaptic();

    try {
      final pdf = pw.Document();

      for (int i = 0; i < _pages.length; i++) {
        final imgBytes = _pages[i].processedBytes;
        final pwImg = pw.MemoryImage(imgBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(16),
            build: (context) {
              return pw.Center(
                child: pw.Image(pwImg, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Scanned_Document.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  Future<void> _exportIdCardPdf() async {
    if (_idCardFront == null && _idCardBack == null) return;
    PreferencesService().triggerHaptic();

    try {
      final pdf = pw.Document();
      final frontImg = _idCardFront != null ? pw.MemoryImage(_idCardFront!) : null;
      final backImg = _idCardBack != null ? pw.MemoryImage(_idCardBack!) : null;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('ID CARD COPY', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 24),
                if (frontImg != null) ...[
                  pw.Container(
                    width: 320,
                    height: 200,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Image(frontImg, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Front Side', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
                pw.SizedBox(height: 32),
                if (backImg != null) ...[
                  pw.Container(
                    width: 320,
                    height: 200,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Image(backImg, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Back Side', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'ID_Card_Document.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ID Card export error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Document Scanner',
      category: ToolCategory.documents,
      toolId: 'document_scanner',
      onReset: () {
        setState(() {
          _pages.clear();
          _idCardFront = null;
          _idCardBack = null;
          _signatureStrokes.clear();
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode Selector
          FeatureTabSelector<ScannerMode>(
            tabs: ScannerMode.values
                .map((mode) => FeatureTabItem(
                      value: mode,
                      label: mode.label,
                      icon: mode.icon,
                    ))
                .toList(),
            activeTab: _scannerMode,
            onTabSelected: (mode) {
              setState(() => _scannerMode = mode);
            },
            accentColor: AppColors.catPdf,
            title: 'Scanner Mode',
          ),
          const SizedBox(height: 16),

          // MODE 1: Multi-Page Document Scanner
          if (_scannerMode == ScannerMode.document) ...[
            ResultCard(
              title: 'Scanned Document',
              primaryResult: '${_pages.length} ${_pages.length == 1 ? 'Page' : 'Pages'}',
              subtitle: 'Filters: Original, Grayscale & B&W High-Contrast',
              accentColor: AppColors.catPdf,
              breakdowns: [
                BreakdownItem(label: 'Total Pages', value: _pages.length.toString()),
                BreakdownItem(label: 'Format', value: 'A4 Export'),
                BreakdownItem(label: 'Status', value: _pages.isEmpty ? 'Ready to Scan' : 'Ready to Export'),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.document_scanner_rounded),
                    label: const Text('Add Document Page'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.catPdf,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _addDocumentPage,
                  ),
                ),
                if (_pages.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.catFinance,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _exportDocumentPdf,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Page list with filters and tools
            if (_pages.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, idx) {
                  final page = _pages[idx];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Page ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Rotate 90°',
                                  icon: const Icon(Icons.rotate_right_rounded, size: 20),
                                  onPressed: () => _rotatePage(idx),
                                ),
                                IconButton(
                                  tooltip: 'Delete Page',
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                  onPressed: () {
                                    setState(() => _pages.removeAt(idx));
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: Image.memory(
                              page.processedBytes,
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Filter chips
                        Row(
                          children: DocFilter.values.map((f) {
                            final isSelected = page.currentFilter == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: Text(f.label, style: const TextStyle(fontSize: 12)),
                                selected: isSelected,
                                selectedColor: AppColors.catPdf,
                                onSelected: (val) {
                                  if (val) _applyFilter(idx, f);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],

          // MODE 2: ID Card Front & Back Scanner
          if (_scannerMode == ScannerMode.idCard) ...[
            ResultCard(
              title: 'ID Card Mode',
              primaryResult: 'Front & Back on 1 Page',
              subtitle: 'Optimized layout for Driver\'s License, National IDs & Badges',
              accentColor: AppColors.catPdf,
            ),
            const SizedBox(height: 20),

            // Front Side Box
            Container(
              width: double.infinity,
              height: 170,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: _idCardFront != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Center(child: Image.memory(_idCardFront!, fit: BoxFit.contain)),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                            onPressed: () => _pickIdCard(isFront: true),
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _pickIdCard(isFront: true),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined, size: 40, color: AppColors.catPdf),
                          SizedBox(height: 8),
                          Text('Tap to Capture ID Card (Front Side)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Back Side Box
            Container(
              width: double.infinity,
              height: 170,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: _idCardBack != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Center(child: Image.memory(_idCardBack!, fit: BoxFit.contain)),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                            onPressed: () => _pickIdCard(isFront: false),
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _pickIdCard(isFront: false),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.credit_card_rounded, size: 40, color: AppColors.catPdf),
                          SizedBox(height: 8),
                          Text('Tap to Capture ID Card (Back Side)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            if (_idCardFront != null || _idCardBack != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Export ID Card Document PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.catPdf,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _exportIdCardPdf,
                ),
              ),
          ],

          // MODE 3: Signature Pad
          if (_scannerMode == ScannerMode.signature) ...[
            ResultCard(
              title: 'Digital Signature',
              primaryResult: 'Sign & Annotate',
              subtitle: 'Draw with finger or stylus for document signing',
              accentColor: AppColors.catPdf,
            ),
            const SizedBox(height: 16),

            // Drawing canvas
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.catPdf.withOpacity(0.4), width: 2),
              ),
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentStroke = [details.localPosition];
                    _signatureStrokes.add(_currentStroke);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentStroke.add(details.localPosition);
                  });
                },
                child: CustomPaint(
                  painter: SignaturePainter(
                    strokes: _signatureStrokes,
                    color: _penColor,
                    strokeWidth: _strokeWidth,
                  ),
                  child: Container(),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ...[Colors.black, const Color(0xFF1E3A8A), const Color(0xFFDC2626)].map((c) {
                      return GestureDetector(
                        onTap: () => setState(() => _penColor = c),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _penColor == c ? AppColors.primaryOrange : Colors.grey,
                              width: _penColor == c ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo_rounded),
                      onPressed: _signatureStrokes.isNotEmpty
                          ? () {
                              setState(() => _signatureStrokes.removeLast());
                            }
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Clear Pad',
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      onPressed: () {
                        setState(() => _signatureStrokes.clear());
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  SignaturePainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
