import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' as pw_format;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'office_document_service.dart';
import 'office_pdf_toolkit_screen.dart';
import 'scan_pdf_service.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/share_utils.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum PdfToolkitTab {
  imagesToPdf('Photo to PDF', Icons.photo_library_rounded),
  textToPdf('Text to PDF', Icons.text_snippet_rounded),
  merge('Merge PDFs', Icons.call_merge_rounded),
  split('Split PDF', Icons.call_split_rounded),
  pages('Organize Pages', Icons.view_carousel_rounded),
  compress('Compress', Icons.compress_rounded),
  protect('Protect / Lock', Icons.lock_rounded),
  pdfToImages('PDF to Images', Icons.image_rounded),
  signAnnotate('Sign & Stamp', Icons.draw_rounded),
  forms('Fill Forms', Icons.assignment_rounded),
  pdfToText('PDF to Text', Icons.text_fields_rounded);

  final String label;
  final IconData icon;
  const PdfToolkitTab(this.label, this.icon);
}

class ImageFileItem {
  final String name;
  final Uint8List bytes;
  ImageFileItem({required this.name, required this.bytes});
}

class PdfFileItem {
  final String name;
  final Uint8List bytes;
  final int pageCount;
  PdfFileItem({required this.name, required this.bytes, required this.pageCount});
}

class PageItemState {
  final int originalIndex;
  int rotation; // 0, 90, 180, 270
  bool isDeleted;
  PageItemState({required this.originalIndex, this.rotation = 0, this.isDeleted = false});
}

class SignaturePoint {
  final Offset offset;
  final bool isEnd;
  SignaturePoint(this.offset, {this.isEnd = false});
}

class PdfToolkitScreen extends StatefulWidget {
  /// Registry id for favourites/recents; 'photo_to_pdf' opens the same toolkit.
  final String toolId;
  const PdfToolkitScreen({super.key, this.toolId = 'pdf_toolkit'});

  @override
  State<PdfToolkitScreen> createState() => _PdfToolkitScreenState();
}

class _PdfToolkitScreenState extends State<PdfToolkitScreen> {
  PdfToolkitTab _activeTab = PdfToolkitTab.imagesToPdf;

  // 1. Images to PDF
  final List<ImageFileItem> _selectedImages = [];
  pw_format.PdfPageFormat _pageFormat = pw_format.PdfPageFormat.a4;
  bool _isLandscape = false;
  bool _addPageNumbers = true;
  bool _autoCropPhotos = true;
  bool _autoFitPage = true;
  bool _isGeneratingPdf = false;
  String? _photoProgress;
  final TextEditingController _imagePdfNameController = TextEditingController(text: 'Images_Document');

  // 2. Text to PDF
  final TextEditingController _docTitleController = TextEditingController(text: 'Document Report');
  final TextEditingController _authorController = TextEditingController(text: 'Author Name');
  final TextEditingController _docBodyController = TextEditingController(
    text:
        'This document was generated using the ToolBox Pro PDF Toolkit.\n\n'
        'You can type or paste any formatted notes, meeting minutes, contracts, or summaries here. '
        'The engine automatically computes text pagination, headers, footers, and page numbers.\n\n'
        'Key Highlights:\n'
        '• Clean high-resolution typography\n'
        '• Automatic multi-page flowing\n'
        '• Optional watermark protection\n'
        '• Instant sharing and export',
  );
  final TextEditingController _watermarkController = TextEditingController(text: 'CONFIDENTIAL');
  bool _enableWatermark = false;

  // 3. Merge PDFs
  final List<PdfFileItem> _mergePdfs = [];

  // 4. Split PDF
  PdfFileItem? _splitSourcePdf;
  final TextEditingController _splitRangeController = TextEditingController(text: '1-2');
  final TextEditingController _splitNameController = TextEditingController(text: 'Split_Document');

  // 5. Organize Pages
  PdfFileItem? _organizePdf;
  List<PageItemState> _pageItems = [];

  // 6. Compress PDF
  PdfFileItem? _compressPdf;
  int _compressReduction = 0;

  // 7. Protect PDF
  PdfFileItem? _protectPdf;
  // Empty on purpose: a pre-filled default password would end up on real documents.
  final TextEditingController _userPasswordController = TextEditingController();
  final TextEditingController _ownerPasswordController = TextEditingController();
  bool _allowPrint = true;
  bool _allowCopy = false;
  bool _allowEdit = false;

  // 8. PDF to Images
  PdfFileItem? _pdfToImageSource;
  List<Uint8List> _renderedPageImages = [];
  bool _isRenderingImages = false;
  static const _maxRasterPages = 60; // each page is a ~1-3 MB PNG held in memory

  // 9. Sign & Stamp
  PdfFileItem? _signPdf;
  final TextEditingController _stampTextController = TextEditingController(text: 'APPROVED');
  int _stampPage = 1;
  String _stampPosition = 'Bottom Right';

  // 10. Form Fill
  PdfFileItem? _formPdf;
  final Map<String, TextEditingController> _formControllers = {};
  final Map<String, bool> _formCheckboxes = {};
  int _formSkipped = 0; // dropdowns, radio groups, signatures: not editable here

  // 11. PDF to Text
  PdfFileItem? _pdfToTextSource;
  String _extractedText = '';
  static const _textPreviewLimit = 20000; // SelectableText lays out its whole string
  final TextEditingController _searchWordController = TextEditingController();
  int _matchCount = 0;

  @override
  void dispose() {
    _imagePdfNameController.dispose();
    _docTitleController.dispose();
    _authorController.dispose();
    _docBodyController.dispose();
    _watermarkController.dispose();
    _splitRangeController.dispose();
    _splitNameController.dispose();
    _userPasswordController.dispose();
    _ownerPasswordController.dispose();
    _stampTextController.dispose();
    _searchWordController.dispose();
    for (final c in _formControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // --- ACTIONS ---

  bool get _scanPhotos => _autoCropPhotos && ScanPdfService.autoCropAvailable;

  /// [scanner] routes through ML Kit's document scanner (gallery import on),
  /// which detects the document edges and crops/straightens each photo.
  Future<void> _pickImages({required bool scanner}) async {
    PreferencesService().triggerHaptic();
    if (scanner && _scanPhotos) {
      try {
        final scans = await ScanPdfService.scanWithAutoCrop(pageLimit: 50, galleryImport: true);
        if (scans == null || scans.isEmpty || !mounted) return;
        final start = _selectedImages.length;
        setState(() {
          for (var i = 0; i < scans.length; i++) {
            _selectedImages.add(ImageFileItem(name: 'Photo_${start + i + 1}.jpg', bytes: scans[i]));
          }
        });
        return;
      } catch (e) {
        _showError('Auto-crop needs Google Play services; opening the gallery instead.');
      }
    }
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);

      if (files.isNotEmpty) {
        final picked = <ImageFileItem>[];
        for (final file in files) {
          picked.add(ImageFileItem(name: file.name, bytes: await file.readAsBytes()));
        }
        if (!mounted) return;
        setState(() => _selectedImages.addAll(picked));
      }
    } catch (e) {
      _showError('Error picking images: $e');
    }
  }

  Future<void> _generateImagesPdf() async {
    if (_selectedImages.isEmpty || _isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);
    PreferencesService().triggerHaptic();

    try {
      final images = List<ImageFileItem>.of(_selectedImages);
      final pages = <ScanPdfPage>[];
      final skipped = <String>[];
      for (var i = 0; i < images.length; i++) {
        if (!mounted) return;
        setState(() => _photoProgress = 'Preparing photo ${i + 1} of ${images.length}…');
        try {
          // Bakes EXIF rotation, trims blank borders when fitting, caps size.
          final r = await ScanPdfService.render((source: images[i].bytes, filter: ScanFilter.original, rotation: 0, maxSide: ScanQuality.high.maxSide, quality: 85, trim: _autoFitPage));
          pages.add(ScanPdfPage(r.bytes));
        } catch (_) {
          skipped.add(images[i].name);
        }
      }
      if (pages.isEmpty) {
        _showError('None of the selected images could be read.');
        return;
      }
      if (!mounted) return;
      setState(() => _photoProgress = 'Building PDF…');
      final pdf = await ScanPdfService.buildScanPdfInBackground(
        ScanPdfRequest(
          pages: pages,
          format: _autoFitPage ? null : (_isLandscape ? _pageFormat.landscape : _pageFormat.portrait),
          autoOrient: false,
          marginPt: _autoFitPage ? 0 : 20,
          pageNumbers: _addPageNumbers,
        ),
      );
      if (skipped.isNotEmpty) _showError('Skipped unreadable images: ${skipped.join(', ')}');
      await shareFileBytes(pdf, ScanPdfService.pdfFileName(_imagePdfNameController.text, 'Photos_Document'));
    } catch (e) {
      _showError('Failed to generate PDF: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
          _photoProgress = null;
        });
      }
    }
  }

  Future<void> _generateTextPdf() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);
    PreferencesService().triggerHaptic();

    try {
      final doc = pw.Document();
      final title = _docTitleController.text.trim();
      final author = _authorController.text.trim();
      final body = _docBodyController.text.trim();
      final watermark = _watermarkController.text.trim();

      doc.addPage(
        pw.MultiPage(
          // Watermark goes in the page background so it repeats on every page
          // instead of being a flow widget that only appears once on page 1.
          pageTheme: pw.PageTheme(
            pageFormat: pw_format.PdfPageFormat.a4, // this tab has no page options; the Photo tab's must not leak in
            margin: const pw.EdgeInsets.all(32),
            buildBackground: _enableWatermark && watermark.isNotEmpty
                ? (pw.Context context) => pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Center(
                      child: pw.Transform.rotate(
                        angle: 0.6,
                        child: pw.Text(
                          watermark,
                          style: pw.TextStyle(fontSize: 60, fontWeight: pw.FontWeight.bold, color: pw_format.PdfColors.grey300),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          header: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: pw_format.PdfColors.grey300, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  if (author.isNotEmpty) pw.Text(author, style: const pw.TextStyle(color: pw_format.PdfColors.grey700, fontSize: 10)),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 16),
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: pw_format.PdfColors.grey300, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated by ToolBox Pro', style: const pw.TextStyle(fontSize: 8, color: pw_format.PdfColors.grey500)),
                  pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: pw_format.PdfColors.grey700)),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Paragraph(text: body, style: const pw.TextStyle(fontSize: 12, lineSpacing: 2)),
            ];
          },
        ),
      );

      await shareFileBytes(await doc.save(), ScanPdfService.pdfFileName(title, 'Document'));
    } catch (e) {
      _showError('Failed to generate PDF: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // --- MERGE PDFS ---
  Future<void> _pickMergePdfs() async {
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

      if (files.isNotEmpty) {
        final picked = <PdfFileItem>[];
        final failed = <String>[];
        for (final file in files) {
          try {
            final bytes = await file.readAsBytes();
            final doc = PdfDocument(inputBytes: bytes);
            final count = doc.pages.count;
            doc.dispose();
            picked.add(PdfFileItem(name: file.name, bytes: bytes, pageCount: count));
          } catch (_) {
            failed.add(file.name);
          }
        }
        if (!mounted) return;
        setState(() => _mergePdfs.addAll(picked));
        if (failed.isNotEmpty) _showError('Could not open (corrupt or password-protected): ${failed.join(', ')}');
      }
    } catch (e) {
      _showError('Error picking PDF files: $e');
    }
  }

  Future<void> _executeMerge() async {
    if (_mergePdfs.length < 2) {
      _showError('Please select at least 2 PDF files to merge.');
      return;
    }

    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);
    PreferencesService().triggerHaptic();

    try {
      final sources = [for (final item in _mergePdfs) item.bytes];
      final bytes = await compute(OfficeDocumentService.mergePdfs, sources);

      await shareFileBytes(bytes, 'Merged_Document_${DateTime.now().millisecondsSinceEpoch}.pdf');
    } catch (e) {
      _showError('Merge failed: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // --- SPLIT PDF ---
  Future<void> _pickSplitPdf() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        final doc = PdfDocument(inputBytes: bytes);
        final count = doc.pages.count;
        doc.dispose();
        setState(() {
          _splitSourcePdf = PdfFileItem(name: file.name, bytes: bytes, pageCount: count);
          _splitRangeController.text = '1-$count';
        });
      }
    } catch (e) {
      _showError('Error picking PDF: $e');
    }
  }

  Future<void> _executeSplit() async {
    if (_splitSourcePdf == null) return;
    final pagesToExtract = OfficeDocumentService.parsePageRange(_splitRangeController.text, _splitSourcePdf!.pageCount);
    if (pagesToExtract.isEmpty) {
      _showError('Please enter valid page numbers (e.g. 1-3, 5).');
      return;
    }

    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);
    PreferencesService().triggerHaptic();

    try {
      final source = _splitSourcePdf!.bytes;
      final bytes = await OfficeDocumentService.extractPagesInBackground(source, pagesToExtract);

      await shareFileBytes(bytes, ScanPdfService.pdfFileName(_splitNameController.text, 'Split_Document'));
    } catch (e) {
      _showError('Split failed: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // --- ORGANIZE PAGES ---
  Future<void> _pickOrganizePdf() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        final doc = PdfDocument(inputBytes: bytes);
        final count = doc.pages.count;
        doc.dispose();
        setState(() {
          _organizePdf = PdfFileItem(name: file.name, bytes: bytes, pageCount: count);
          _pageItems = List.generate(count, (i) => PageItemState(originalIndex: i));
        });
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _exportOrganizedPdf() async {
    if (_organizePdf == null) return;
    final activePages = _pageItems.where((p) => !p.isDeleted).toList();
    if (activePages.isEmpty) {
      _showError('All pages are marked as deleted.');
      return;
    }

    setState(() => _isGeneratingPdf = true);
    PreferencesService().triggerHaptic();

    try {
      final srcDoc = PdfDocument(inputBytes: _organizePdf!.bytes);
      final outDoc = PdfDocument();

      for (final p in activePages) {
        // Setting rotation on a newly added page is a no-op in Syncfusion; it
        // has to go on the section page settings, combined with the source's own.
        final page = srcDoc.pages[p.originalIndex];
        final rotation = PdfPageRotateAngle.values[(page.rotation.index + p.rotation ~/ 90) % 4];
        OfficeDocumentService.appendPageCopy(outDoc, page, rotation: rotation);
      }

      final List<int> bytes = outDoc.saveSync();
      srcDoc.dispose();
      outDoc.dispose();

      await shareFileBytes(Uint8List.fromList(bytes), 'Organized_${_organizePdf!.name}');
    } catch (e) {
      _showError('Organize export failed: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // --- COMPRESS PDF ---
  Future<void> _pickCompressPdf() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        final doc = PdfDocument(inputBytes: bytes);
        final count = doc.pages.count;
        doc.dispose();
        setState(() {
          _compressPdf = PdfFileItem(name: file.name, bytes: bytes, pageCount: count);
          _compressReduction = 0;
        });
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _executeCompress() async {
    if (_compressPdf == null) return;
    setState(() => _isGeneratingPdf = true);
    PreferencesService().triggerHaptic();

    try {
      final source = _compressPdf!.bytes;
      final bytes = await compute(OfficeDocumentService.compressPdf, source);
      if (!mounted) return;

      final diff = bytes == null ? 0 : ((source.length - bytes.length) / source.length * 100).round();
      if (bytes == null || diff <= 0) {
        setState(() => _compressReduction = 0);
        _showError('This PDF is already optimized; compression could not reduce its size.');
        return;
      }
      setState(() => _compressReduction = diff);

      await shareFileBytes(bytes, 'Compressed_${_compressPdf!.name}');
    } catch (e) {
      _showError('Compress failed: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // --- PROTECT PDF ---
  Future<void> _pickProtectPdf() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        final doc = PdfDocument(inputBytes: bytes);
        final count = doc.pages.count;
        doc.dispose();
        setState(() {
          _protectPdf = PdfFileItem(name: file.name, bytes: bytes, pageCount: count);
        });
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _executeProtect() async {
    if (_protectPdf == null) return;
    final userPass = _userPasswordController.text.trim();
    final ownerPass = _ownerPasswordController.text.trim();

    if (userPass.isEmpty && ownerPass.isEmpty) {
      _showError('Please set at least one password to protect the PDF.');
      return;
    }

    setState(() => _isGeneratingPdf = true);
    PreferencesService().triggerHaptic();

    try {
      final bytes = OfficeDocumentService.protectPdf(_protectPdf!.bytes, userPassword: userPass, ownerPassword: ownerPass, allowPrint: _allowPrint, allowCopy: _allowCopy, allowEdit: _allowEdit);

      await shareFileBytes(bytes, 'Protected_${_protectPdf!.name}');
    } catch (e) {
      _showError('Password protection failed: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // --- PDF TO IMAGES ---
  Future<void> _pickPdfToImages() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        final doc = PdfDocument(inputBytes: bytes);
        final count = doc.pages.count;
        doc.dispose();

        setState(() {
          _pdfToImageSource = PdfFileItem(name: file.name, bytes: bytes, pageCount: count);
          _renderedPageImages = [];
        });

        _renderAllPdfPages();
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _renderAllPdfPages() async {
    final source = _pdfToImageSource;
    if (source == null) return;
    setState(() => _isRenderingImages = true);

    try {
      final List<Uint8List> images = [];
      final shown = source.pageCount < _maxRasterPages ? source.pageCount : _maxRasterPages;
      await for (final page in Printing.raster(source.bytes, pages: [for (var i = 0; i < shown; i++) i], dpi: 150)) {
        final pngBytes = await page.toPng();
        images.add(pngBytes);
      }
      // Ignore results for a PDF that was replaced while rendering.
      if (!mounted || !identical(source, _pdfToImageSource)) return;
      setState(() => _renderedPageImages = images);
      if (source.pageCount > shown) _showError('Showing the first $shown of ${source.pageCount} pages to keep memory use down. Use Split PDF for the rest.');
    } catch (e) {
      _showError('Rasterization failed: $e');
    } finally {
      if (mounted && identical(source, _pdfToImageSource)) setState(() => _isRenderingImages = false);
    }
  }

  // --- SIGN & STAMP ---
  Future<void> _pickSignPdf() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        final doc = PdfDocument(inputBytes: bytes);
        final count = doc.pages.count;
        doc.dispose();
        setState(() {
          _signPdf = PdfFileItem(name: file.name, bytes: bytes, pageCount: count);
          _stampPage = 1;
        });
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _executeSignAndStamp() async {
    if (_signPdf == null) return;
    setState(() => _isGeneratingPdf = true);
    PreferencesService().triggerHaptic();

    try {
      final doc = PdfDocument(inputBytes: _signPdf!.bytes);
      final targetPageIdx = (_stampPage - 1).clamp(0, doc.pages.count - 1);
      final page = doc.pages[targetPageIdx];
      final graphics = page.graphics;

      final text = _stampTextController.text.trim();
      if (text.isNotEmpty) {
        final font = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
        final brush = PdfSolidBrush(PdfColor(225, 29, 72)); // Rose / Red stamp
        final pen = PdfPen(PdfColor(225, 29, 72), width: 2);

        double x = 40;
        double y = page.size.height - 80;
        if (_stampPosition == 'Bottom Right') {
          x = page.size.width - 180;
          y = page.size.height - 80;
        } else if (_stampPosition == 'Top Right') {
          x = page.size.width - 180;
          y = 40;
        } else if (_stampPosition == 'Center') {
          x = (page.size.width - 150) / 2;
          y = (page.size.height - 40) / 2;
        }

        graphics.drawRectangle(pen: pen, bounds: Rect.fromLTWH(x, y, 140, 36));
        graphics.drawString(
          text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(x + 10, y + 8, 120, 20),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
      }

      final List<int> bytes = doc.saveSync();
      doc.dispose();

      await shareFileBytes(Uint8List.fromList(bytes), 'Signed_${_signPdf!.name}');
    } catch (e) {
      _showError('Signing/stamping failed: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // --- FILL FORMS ---
  Future<void> _pickFormPdf() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        // Parse into locals first so a corrupt PDF leaves the current form intact.
        final controllers = <String, TextEditingController>{};
        final checkboxes = <String, bool>{};
        var skipped = 0;
        final doc = PdfDocument(inputBytes: bytes);
        final int count;
        try {
          count = doc.pages.count;
          final form = doc.form;
          for (int i = 0; i < form.fields.count; i++) {
            final field = form.fields[i];
            if (field is PdfTextBoxField) {
              controllers[field.name ?? 'Field_$i'] = TextEditingController(text: field.text);
            } else if (field is PdfCheckBoxField) {
              checkboxes[field.name ?? 'Field_$i'] = field.isChecked;
            } else {
              skipped++;
            }
          }
        } finally {
          doc.dispose();
        }

        _replaceFormFields(controllers, checkboxes);
        setState(() {
          _formSkipped = skipped;
          _formPdf = PdfFileItem(name: file.name, bytes: bytes, pageCount: count);
        });
      }
    } catch (e) {
      _showError('Error loading PDF form: $e');
    }
  }

  /// Swaps in new form fields. Old controllers are still attached to TextFields
  /// until the next frame, so they're disposed after it rather than now.
  void _replaceFormFields(Map<String, TextEditingController> controllers, Map<String, bool> checkboxes) {
    final old = _formControllers.values.toList();
    _formControllers
      ..clear()
      ..addAll(controllers);
    _formCheckboxes
      ..clear()
      ..addAll(checkboxes);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in old) {
        c.dispose();
      }
    });
  }

  Future<void> _saveFilledForm() async {
    if (_formPdf == null) return;
    setState(() => _isGeneratingPdf = true);
    PreferencesService().triggerHaptic();

    try {
      final doc = PdfDocument(inputBytes: _formPdf!.bytes);
      final form = doc.form;

      for (int i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        final name = field.name ?? 'Field_$i';
        if (field is PdfTextBoxField && _formControllers.containsKey(name)) {
          field.text = _formControllers[name]!.text;
        } else if (field is PdfCheckBoxField && _formCheckboxes.containsKey(name)) {
          field.isChecked = _formCheckboxes[name]!;
        }
      }

      final List<int> bytes = doc.saveSync();
      doc.dispose();

      await shareFileBytes(Uint8List.fromList(bytes), 'Filled_${_formPdf!.name}');
    } catch (e) {
      _showError('Saving filled form failed: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // --- PDF TO TEXT ---
  Future<void> _pickPdfToText() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        final doc = PdfDocument(inputBytes: bytes);
        final count = doc.pages.count;
        doc.dispose();
        final text = await compute(OfficeDocumentService.extractText, bytes);
        if (!mounted) return;

        setState(() {
          _pdfToTextSource = PdfFileItem(name: file.name, bytes: bytes, pageCount: count);
          _extractedText = text.trim().isEmpty ? '' : text; // empty = scanned/image-only; the UI says so
          _matchCount = 0;
          _searchWordController.clear();
        });
      }
    } catch (e) {
      _showError('Error extracting text: $e');
    }
  }

  void _searchExtractedText(String query) {
    if (query.trim().isEmpty || _extractedText.isEmpty) {
      setState(() => _matchCount = 0);
      return;
    }
    final matches = RegExp(RegExp.escape(query.trim()), caseSensitive: false).allMatches(_extractedText);
    setState(() => _matchCount = matches.length);
  }

  Future<void> _share(Uint8List bytes, String filename) async {
    try {
      await shareFileBytes(bytes, filename);
    } catch (e) {
      _showError('Could not share $filename: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: widget.toolId == 'photo_to_pdf' ? 'Photo to PDF' : 'Advanced PDF Toolkit',
      category: ToolCategory.pdfDocuments,
      toolId: widget.toolId,
      onReset: () {
        setState(() {
          _selectedImages.clear();
          _mergePdfs.clear();
          _splitSourcePdf = null;
          _organizePdf = null;
          _compressPdf = null;
          _protectPdf = null;
          _pdfToImageSource = null;
          _signPdf = null;
          _formPdf = null;
          _pdfToTextSource = null;
          _extractedText = '';
          // These lists render whenever non-empty, so reset must clear them too.
          _renderedPageImages = [];
          _pageItems = [];
          _compressReduction = 0;
          _matchCount = 0;
          _searchWordController.clear();
          _replaceFormFields({}, {});
          _formSkipped = 0;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              PreferencesService().triggerHaptic();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OfficePdfToolkitScreen()));
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.catPdf.withValues(alpha: 0.15), AppColors.catPdf.withValues(alpha: 0.05)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.catPdf.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.snippet_folder_rounded, color: AppColors.catPdf, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Need Office tools? Open Office & Advanced PDF Suite (Word, Excel, PPT, OCR & Compare)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.catPdf),
                ],
              ),
            ),
          ),
          // Sub-tabs
          FeatureTabSelector<PdfToolkitTab>(
            tabs: PdfToolkitTab.values.map((tab) => FeatureTabItem(value: tab, label: tab.label, icon: tab.icon)).toList(),
            activeTab: _activeTab,
            accentColor: AppColors.catPdf,
            title: 'PDF Studio Tools',
            onTabSelected: (tab) => setState(() => _activeTab = tab),
          ),
          const SizedBox(height: 20),

          // TAB 1: Images to PDF
          if (_activeTab == PdfToolkitTab.imagesToPdf) _buildImagesToPdf(isDark),

          // TAB 2: Text to PDF
          if (_activeTab == PdfToolkitTab.textToPdf) _buildTextToPdf(isDark),

          // TAB 3: Merge PDFs
          if (_activeTab == PdfToolkitTab.merge) _buildMergePdfs(isDark),

          // TAB 4: Split PDF
          if (_activeTab == PdfToolkitTab.split) _buildSplitPdf(isDark),

          // TAB 5: Organize Pages
          if (_activeTab == PdfToolkitTab.pages) _buildOrganizePages(isDark),

          // TAB 6: Compress PDF
          if (_activeTab == PdfToolkitTab.compress) _buildCompressPdf(isDark),

          // TAB 7: Protect PDF
          if (_activeTab == PdfToolkitTab.protect) _buildProtectPdf(isDark),

          // TAB 8: PDF to Images
          if (_activeTab == PdfToolkitTab.pdfToImages) _buildPdfToImages(isDark),

          // TAB 9: Sign & Stamp
          if (_activeTab == PdfToolkitTab.signAnnotate) _buildSignAndStamp(isDark),

          // TAB 10: Fill Forms
          if (_activeTab == PdfToolkitTab.forms) _buildFillForms(isDark),

          // TAB 11: PDF to Text
          if (_activeTab == PdfToolkitTab.pdfToText) _buildPdfToText(isDark),
        ],
      ),
    );
  }

  // ===================== TAB BUILDERS =====================

  Widget _buildImagesToPdf(bool isDark) {
    final formatName = _pageFormat == pw_format.PdfPageFormat.a4
        ? 'A4'
        : _pageFormat == pw_format.PdfPageFormat.legal
        ? 'Legal'
        : 'Letter';
    final muted = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final switchTitle = TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Photo to PDF',
          primaryResult: '${_selectedImages.length} ${_selectedImages.length == 1 ? 'Page' : 'Pages'}',
          subtitle: _autoFitPage ? 'Pages fitted to each photo, blank borders trimmed' : 'Page Format: $formatName • ${_isLandscape ? 'Landscape' : 'Portrait'}',
          accentColor: AppColors.catPdf,
          breakdowns: [
            BreakdownItem(label: 'Auto-Crop', value: _scanPhotos ? 'On' : 'Off'),
            BreakdownItem(label: 'Page Size', value: _autoFitPage ? 'Fit to photo' : formatName),
            BreakdownItem(label: 'Page Numbers', value: _addPageNumbers ? 'On' : 'Off'),
          ],
        ),
        const SizedBox(height: 20),
        ModernTextField(label: 'PDF File Name', controller: _imagePdfNameController, hintText: 'e.g. Scanned_Docs', prefixIcon: Icons.insert_drive_file_rounded),
        const SizedBox(height: 16),
        if (_scanPhotos) ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.crop_rounded),
            label: const Text('Add Photos with Auto-Crop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catPdf,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isGeneratingPdf ? null : () => _pickImages(scanner: true),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_rounded),
          label: Text(_scanPhotos ? 'Pick from Gallery (no crop)' : 'Pick from Gallery'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.catPdf,
            side: BorderSide(color: AppColors.catPdf.withValues(alpha: 0.6)),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isGeneratingPdf ? null : () => _pickImages(scanner: false),
        ),
        const SizedBox(height: 16),
        // Material (not a decorated Container) so the switch tiles' ink shows.
        Material(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                if (ScanPdfService.autoCropAvailable) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Auto-Crop Photos', style: switchTitle),
                    subtitle: const Text('Detects document edges, then crops and straightens'),
                    value: _autoCropPhotos,
                    activeThumbColor: AppColors.catPdf,
                    onChanged: (val) => setState(() => _autoCropPhotos = val),
                  ),
                  const Divider(height: 1),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Auto-fit page to image', style: switchTitle),
                  subtitle: const Text('No letterboxing; trims blank white or black borders'),
                  value: _autoFitPage,
                  activeThumbColor: AppColors.catPdf,
                  onChanged: (val) => setState(() => _autoFitPage = val),
                ),
                if (!_autoFitPage) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('Page Size', style: switchTitle)),
                        DropdownButton<pw_format.PdfPageFormat>(
                          value: _pageFormat,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: pw_format.PdfPageFormat.a4, child: Text('A4')),
                            DropdownMenuItem(value: pw_format.PdfPageFormat.letter, child: Text('US Letter')),
                            DropdownMenuItem(value: pw_format.PdfPageFormat.legal, child: Text('US Legal')),
                          ],
                          onChanged: (f) {
                            if (f != null) setState(() => _pageFormat = f);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Landscape Orientation', style: switchTitle),
                    value: _isLandscape,
                    activeThumbColor: AppColors.catPdf,
                    onChanged: (val) => setState(() => _isLandscape = val),
                  ),
                ],
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Add Page Numbers', style: switchTitle),
                  value: _addPageNumbers,
                  activeThumbColor: AppColors.catPdf,
                  onChanged: (val) => setState(() => _addPageNumbers = val),
                ),
              ],
            ),
          ),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('Pages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              TextButton.icon(icon: const Icon(Icons.clear_all_rounded), label: const Text('Clear'), onPressed: _isGeneratingPdf ? null : () => setState(() => _selectedImages.clear())),
            ],
          ),
          Text('Long-press and drag to reorder', style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              onReorderItem: (oldIdx, newIdx) => setState(() => ScanPdfService.moveItem(_selectedImages, oldIdx, newIdx)),
              itemBuilder: (context, idx) {
                final img = _selectedImages[idx];
                return Padding(
                  key: ObjectKey(img),
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 96,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBg : AppColors.lightBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.memory(img.bytes, fit: BoxFit.cover, cacheWidth: 240, gaplessPlayback: true),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: IconButton(
                            tooltip: 'Remove page ${idx + 1}',
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(backgroundColor: Colors.black54),
                            icon: const Icon(Icons.close, color: Colors.white, size: 16),
                            onPressed: _isGeneratingPdf ? null : () => setState(() => _selectedImages.removeAt(idx)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_photoProgress != null) ...[const SizedBox(height: 14), Text(_photoProgress!, style: TextStyle(fontSize: 13, color: muted))],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isGeneratingPdf ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_isGeneratingPdf ? 'Building PDF...' : 'Export & Share PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isGeneratingPdf ? null : _generateImagesPdf,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextToPdf(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernTextField(label: 'Document Title', controller: _docTitleController, hintText: 'e.g. Project Proposal', prefixIcon: Icons.title_rounded),
        const SizedBox(height: 16),
        ModernTextField(label: 'Author / Subtitle', controller: _authorController, hintText: 'e.g. John Doe', prefixIcon: Icons.person_outline_rounded),
        const SizedBox(height: 16),
        ModernTextField(label: 'Document Body', controller: _docBodyController, hintText: 'Type your report or content here...', maxLines: 7, keyboardType: TextInputType.multiline),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Add Watermark Stamp', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          value: _enableWatermark,
          activeThumbColor: AppColors.catPdf,
          onChanged: (val) => setState(() => _enableWatermark = val),
        ),
        if (_enableWatermark) ...[
          const SizedBox(height: 8),
          ModernTextField(label: 'Watermark Text', controller: _watermarkController, hintText: 'CONFIDENTIAL', prefixIcon: Icons.branding_watermark_rounded),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Export & Share PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catPdf,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isGeneratingPdf ? null : _generateTextPdf,
          ),
        ),
      ],
    );
  }

  Widget _buildMergePdfs(bool isDark) {
    final totalPages = _mergePdfs.fold<int>(0, (sum, item) => sum + item.pageCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Merge Overview',
          primaryResult: '${_mergePdfs.length} Files Selected',
          subtitle: '$totalPages Total Combined Pages',
          accentColor: AppColors.catPdf,
          breakdowns: [
            BreakdownItem(label: 'Files', value: _mergePdfs.length.toString()),
            BreakdownItem(label: 'Total Pages', value: totalPages.toString()),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_rounded),
          label: const Text('Select PDF Files to Merge'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickMergePdfs,
        ),
        const SizedBox(height: 16),
        if (_mergePdfs.isNotEmpty) ...[
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _mergePdfs.length,
            onReorderItem: (oldIdx, newIdx) => setState(() => ScanPdfService.moveItem(_mergePdfs, oldIdx, newIdx)),
            itemBuilder: (context, idx) {
              final pdf = _mergePdfs[idx];
              return ListTile(
                key: ObjectKey(pdf),
                leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.catPdf),
                title: Text(pdf.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${pdf.pageCount} pages'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  onPressed: () => setState(() => _mergePdfs.removeAt(idx)),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.call_merge_rounded),
              label: const Text('Merge & Share Combined PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isGeneratingPdf ? null : _executeMerge,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSplitPdf(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Split Status',
          primaryResult: _splitSourcePdf != null ? '${_splitSourcePdf!.pageCount} Pages' : 'Select a PDF',
          subtitle: _splitSourcePdf != null ? _splitSourcePdf!.name : 'Choose a file to extract specific page ranges',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Pick PDF to Split'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickSplitPdf,
        ),
        if (_splitSourcePdf != null) ...[
          const SizedBox(height: 16),
          ModernTextField(label: 'Page Range / Pages to Extract', controller: _splitRangeController, hintText: 'e.g. 1-3, 5, 8-10', prefixIcon: Icons.format_list_numbered_rounded),
          const SizedBox(height: 16),
          ModernTextField(label: 'Output File Name', controller: _splitNameController, hintText: 'Split_Document', prefixIcon: Icons.drive_file_rename_outline_rounded),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.call_split_rounded),
              label: const Text('Extract & Share Split PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isGeneratingPdf ? null : _executeSplit,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOrganizePages(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Organize Pages',
          primaryResult: _organizePdf != null ? '${_pageItems.where((p) => !p.isDeleted).length} Active Pages' : 'No PDF Loaded',
          subtitle: 'Long-press & drag to reorder; rotate or delete pages',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Pick PDF to Organize'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickOrganizePdf,
        ),
        if (_organizePdf != null) ...[
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8),
            itemCount: _pageItems.length,
            itemBuilder: (context, idx) {
              final page = _pageItems[idx];
              final tile = Container(
                decoration: BoxDecoration(
                  color: page.isDeleted ? AppColors.error.withValues(alpha: 0.1) : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: page.isDeleted ? AppColors.error : AppColors.catPdf),
                ),
                // scaleDown keeps the icon + label + buttons inside the tile at large font scales.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined, size: 36, color: page.isDeleted ? AppColors.error : AppColors.catPdf),
                      Text(
                        'Page ${page.originalIndex + 1}',
                        style: TextStyle(fontWeight: FontWeight.bold, decoration: page.isDeleted ? TextDecoration.lineThrough : null),
                      ),
                      if (page.rotation > 0) Text('${page.rotation}°', style: const TextStyle(fontSize: 10, color: AppColors.catPdf)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Rotate page',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.rotate_right_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                page.rotation = (page.rotation + 90) % 360;
                              });
                            },
                          ),
                          IconButton(
                            tooltip: page.isDeleted ? 'Restore page' : 'Delete page',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(page.isDeleted ? Icons.restore_rounded : Icons.delete_outline_rounded, size: 18, color: page.isDeleted ? AppColors.success : AppColors.error),
                            onPressed: () {
                              setState(() {
                                page.isDeleted = !page.isDeleted;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
              // Reorder was advertised but the grid had no way to move pages.
              return DragTarget<PageItemState>(
                onWillAcceptWithDetails: (d) => d.data != page,
                onAcceptWithDetails: (d) => setState(() {
                  _pageItems.remove(d.data);
                  _pageItems.insert(idx, d.data);
                }),
                builder: (context, candidates, _) => LongPressDraggable<PageItemState>(
                  data: page,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(width: 90, height: 112, child: Opacity(opacity: 0.85, child: tile)),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: tile),
                  child: candidates.isNotEmpty ? Opacity(opacity: 0.6, child: tile) : tile,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: const Text('Export & Share Organized PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isGeneratingPdf ? null : _exportOrganizedPdf,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompressPdf(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PDF Compressor',
          primaryResult: _compressPdf != null ? '${(_compressPdf!.bytes.length / 1024).toStringAsFixed(1)} KB' : 'No PDF Selected',
          subtitle: _compressReduction > 0 ? '$_compressReduction% Size Reduction' : 'Optimizes internal streams and fonts',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Pick PDF to Compress'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickCompressPdf,
        ),
        if (_compressPdf != null) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.compress_rounded),
              label: const Text('Compress & Share PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isGeneratingPdf ? null : _executeCompress,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProtectPdf(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PDF Security & Encryption',
          primaryResult: _protectPdf != null ? _protectPdf!.name : 'Select a PDF',
          subtitle: 'AES-256 Bit Encryption with Granular Permissions',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Pick PDF to Lock'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickProtectPdf,
        ),
        if (_protectPdf != null) ...[
          const SizedBox(height: 16),
          ModernTextField(label: 'User Open Password', controller: _userPasswordController, hintText: 'Required to open document', prefixIcon: Icons.password_rounded),
          const SizedBox(height: 16),
          ModernTextField(label: 'Owner / Master Password', controller: _ownerPasswordController, hintText: 'Admin password for permissions', prefixIcon: Icons.admin_panel_settings_rounded),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow Printing', style: TextStyle(fontWeight: FontWeight.w600)),
            value: _allowPrint,
            activeThumbColor: AppColors.catPdf,
            onChanged: (val) => setState(() => _allowPrint = val),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow Text/Content Copying', style: TextStyle(fontWeight: FontWeight.w600)),
            value: _allowCopy,
            activeThumbColor: AppColors.catPdf,
            onChanged: (val) => setState(() => _allowCopy = val),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow Annotations & Modifications', style: TextStyle(fontWeight: FontWeight.w600)),
            value: _allowEdit,
            activeThumbColor: AppColors.catPdf,
            onChanged: (val) => setState(() => _allowEdit = val),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Encrypt & Share Protected PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isGeneratingPdf ? null : _executeProtect,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPdfToImages(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PDF to High-Res Images',
          primaryResult: '${_renderedPageImages.length} Pages Extracted',
          subtitle: 'Converts each PDF page into a clean PNG image',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Pick PDF to Extract Images'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickPdfToImages,
        ),
        if (_isRenderingImages) ...[const SizedBox(height: 20), const Center(child: CircularProgressIndicator())],
        if (_renderedPageImages.isNotEmpty) ...[
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _renderedPageImages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, idx) {
              final imgBytes = _renderedPageImages[idx];
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
                    Text('Page ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(imgBytes, fit: BoxFit.contain, cacheWidth: 1080),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: Text('Share Page ${idx + 1} Image'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.catPdf, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 40)),
                      onPressed: () => _share(imgBytes, 'Page_${idx + 1}.png'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSignAndStamp(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Sign & Stamp Document',
          primaryResult: _signPdf != null ? _signPdf!.name : 'Pick a PDF',
          subtitle: 'Add stamps, approvals, or signatures directly onto pages',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Pick PDF to Sign / Stamp'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickSignPdf,
        ),
        if (_signPdf != null) ...[
          const SizedBox(height: 16),
          ModernTextField(label: 'Stamp Text / Signature Text', controller: _stampTextController, hintText: 'e.g. APPROVED or John Doe', prefixIcon: Icons.verified_rounded),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ObjectKey(_signPdf),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Target Page',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  initialValue: _stampPage,
                  items: List.generate(_signPdf!.pageCount, (i) => i + 1).map((p) => DropdownMenuItem(value: p, child: Text('Page $p'))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _stampPage = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Position',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  initialValue: _stampPosition,
                  items: const [
                    DropdownMenuItem(value: 'Bottom Right', child: Text('Bottom Right')),
                    DropdownMenuItem(value: 'Top Right', child: Text('Top Right')),
                    DropdownMenuItem(value: 'Center', child: Text('Center')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _stampPosition = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Apply Stamp & Share PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isGeneratingPdf ? null : _executeSignAndStamp,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFillForms(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PDF Form Filler',
          primaryResult: _formPdf != null ? '${_formControllers.length + _formCheckboxes.length} Form Fields' : 'No Form PDF Loaded',
          subtitle: 'Inspect and edit interactive fillable form fields',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Pick Fillable PDF Form'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickFormPdf,
        ),
        if (_formPdf != null) ...[
          const SizedBox(height: 16),
          if (_formControllers.isEmpty && _formCheckboxes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_formSkipped > 0 ? 'This form has no text or check-box fields to fill.' : 'No interactive form fields found in this PDF document.', style: const TextStyle(color: AppColors.warning)),
            ),
          if (_formSkipped > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('$_formSkipped other field(s) (drop-downs, radio buttons, signatures) cannot be edited here and are kept as they are.', style: const TextStyle(fontSize: 12.5, color: AppColors.warning)),
            ),
          ..._formControllers.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ModernTextField(label: e.key, controller: e.value, prefixIcon: Icons.edit_note_rounded),
            );
          }),
          ..._formCheckboxes.entries.map((e) {
            return CheckboxListTile(title: Text(e.key), value: e.value, onChanged: (val) => setState(() => _formCheckboxes[e.key] = val ?? false));
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_as_rounded),
              label: const Text('Save Filled Form & Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isGeneratingPdf ? null : _saveFilledForm,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPdfToText(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PDF Text Extractor',
          primaryResult: _pdfToTextSource == null ? 'Select a PDF' : '${_extractedText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length} Words',
          subtitle: _matchCount > 0
              ? '$_matchCount search matches found'
              : (_pdfToTextSource != null ? '${_pdfToTextSource!.name} (${_pdfToTextSource!.pageCount} pages)' : 'Extracts all machine-readable text into plain text'),
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Pick PDF to Extract Text'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickPdfToText,
        ),
        if (_pdfToTextSource != null && _extractedText.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('No readable text found. This PDF probably holds scanned images; run it through the Document Scanner with OCR to make it searchable.', style: TextStyle(color: AppColors.warning)),
          ),
        if (_extractedText.isNotEmpty) ...[
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Search in Extracted Text',
            controller: _searchWordController,
            hintText: 'Type to highlight occurrences...',
            prefixIcon: Icons.search_rounded,
            onChanged: _searchExtractedText,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: SingleChildScrollView(
              child: SelectableText(_extractedText.length > _textPreviewLimit ? '${_extractedText.substring(0, _textPreviewLimit)}\n\n… preview truncated; Copy or Export includes the full text.' : _extractedText, style: const TextStyle(fontSize: 13, height: 1.5, fontFamily: 'monospace')),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy Text'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _extractedText));
                    PreferencesService().triggerHaptic();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Export .TXT'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.catPdf, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    _share(Uint8List.fromList(utf8.encode(_extractedText)), 'Extracted_Text.txt');
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
