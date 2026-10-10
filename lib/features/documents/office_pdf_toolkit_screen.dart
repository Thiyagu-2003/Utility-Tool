import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';
import 'office_document_service.dart';

enum OfficePdfTab {
  wordToPdf('Word to PDF', Icons.description_rounded),
  excelToPdf('Excel to PDF', Icons.table_chart_rounded),
  pptxToPdf('PPT to PDF', Icons.slideshow_rounded),
  pdfToWord('PDF to Word', Icons.text_snippet_rounded),
  pdfToExcel('PDF to Excel', Icons.grid_on_rounded),
  pdfToPptx('PDF to PPT', Icons.present_to_all_rounded),
  searchableOcr('Searchable OCR', Icons.find_in_page_rounded),
  metadata('Metadata Editor', Icons.info_outline_rounded),
  pageExtraction('Extract Pages', Icons.call_split_rounded),
  bookmarks('TOC & Bookmarks', Icons.bookmark_border_rounded),
  flattenForms('Flatten Forms', Icons.lock_outline_rounded),
  comparePdfs('PDF Compare', Icons.compare_arrows_rounded);

  final String label;
  final IconData icon;
  const OfficePdfTab(this.label, this.icon);
}

class OfficePdfToolkitScreen extends StatefulWidget {
  const OfficePdfToolkitScreen({super.key});

  @override
  State<OfficePdfToolkitScreen> createState() => _OfficePdfToolkitScreenState();
}

class _OfficePdfToolkitScreenState extends State<OfficePdfToolkitScreen> {
  OfficePdfTab _activeTab = OfficePdfTab.wordToPdf;
  bool _isProcessing = false;

  // 1. Word to PDF
  Uint8List? _docxSourceBytes;
  String _docxFileName = '';
  final TextEditingController _docxTitleController = TextEditingController(text: 'Converted Word Document');
  Uint8List? _generatedDocxPdfBytes;

  // 2. Excel to PDF
  final TextEditingController _excelDataController = TextEditingController(
    text: 'Product,Category,Price,Stock\n'
        'MacBook Pro 16",Laptops,\$2499,14\n'
        'Dell XPS 15,Laptops,\$1899,22\n'
        'iPad Pro 13",Tablets,\$1199,35\n'
        'Sony WH-1000XM5,Audio,\$399,58\n'
        'Logitech MX Master 3S,Accessories,\$99,120',
  );
  final TextEditingController _excelTitleController = TextEditingController(text: 'Inventory & Sales Report');
  Uint8List? _generatedExcelPdfBytes;

  // 3. PPT to PDF
  Uint8List? _pptxSourceBytes;
  String _pptxFileName = '';
  final TextEditingController _pptxTitleController = TextEditingController(text: 'Keynote Presentation');
  Uint8List? _generatedPptxPdfBytes;

  // 4. PDF to Word
  Uint8List? _pdfForWordBytes;
  String _pdfForWordName = '';
  Uint8List? _generatedDocxBytes;

  // 5. PDF to Excel
  Uint8List? _pdfForExcelBytes;
  String _pdfForExcelName = '';
  String? _extractedCsvContent;

  // 6. PDF to PPT
  Uint8List? _pdfForPptBytes;
  String _pdfForPptName = '';
  Uint8List? _generatedPptxBytes;

  // 7. Searchable OCR
  Uint8List? _ocrImageBytes;
  String _ocrImageName = '';
  final TextEditingController _ocrTextController = TextEditingController(
    text: 'OMNI UTILITY TOOLS\n'
        'Invoice #INV-2026-884\n'
        'Date: October 10, 2026\n'
        'Billed to: Enterprise Client Corp\n'
        'Amount Due: \$4,850.00 USD\n\n'
        'This scanned document now contains an embedded searchable text layer.',
  );
  Uint8List? _generatedSearchablePdfBytes;

  // 8. Metadata
  Uint8List? _metadataPdfBytes;
  String _metadataPdfName = '';
  PdfMetadataInfo? _loadedMetadata;
  final TextEditingController _metaTitleCtrl = TextEditingController();
  final TextEditingController _metaAuthorCtrl = TextEditingController();
  final TextEditingController _metaSubjectCtrl = TextEditingController();
  final TextEditingController _metaKeywordsCtrl = TextEditingController();
  final TextEditingController _metaCreatorCtrl = TextEditingController();
  final TextEditingController _metaProducerCtrl = TextEditingController();
  Uint8List? _updatedMetadataPdfBytes;

  // 9. Page Extraction
  Uint8List? _extractSourcePdfBytes;
  String _extractSourcePdfName = '';
  int _extractSourcePageCount = 0;
  final TextEditingController _extractPagesController = TextEditingController(text: '1, 2');
  Uint8List? _extractedZipBytes;

  // 10. Bookmarks
  Uint8List? _bookmarksPdfBytes;
  String _bookmarksPdfName = '';
  List<PdfBookmarkItem> _loadedBookmarks = [];
  final TextEditingController _newBmTitleCtrl = TextEditingController();
  final TextEditingController _newBmPageCtrl = TextEditingController(text: '1');
  Uint8List? _updatedBookmarksPdfBytes;

  // 11. Flatten Forms
  Uint8List? _flattenPdfBytes;
  String _flattenPdfName = '';
  Uint8List? _flattenedResultPdfBytes;

  // 12. Compare PDFs
  Uint8List? _comparePdfABytes;
  String _comparePdfAName = '';
  Uint8List? _comparePdfBBytes;
  String _comparePdfBName = '';
  PdfComparisonResult? _comparisonResult;

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareFile(Uint8List bytes, String filename) async {
    PreferencesService().triggerHaptic();
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  // ================= 1. WORD TO PDF =================
  Future<void> _pickWordFile() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['docx']);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _docxSourceBytes = bytes;
          _docxFileName = file.name;
          _docxTitleController.text = file.name.replaceAll('.docx', '');
          _generatedDocxPdfBytes = null;
        });
      }
    } catch (e) {
      _showToast('Error picking Word file: $e', isError: true);
    }
  }

  Future<void> _runWordToPdf() async {
    if (_docxSourceBytes == null) {
      _showToast('Please select a .docx file first', isError: true);
      return;
    }
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final pdfBytes = await OfficeDocumentService.wordToPdf(
        docxBytes: _docxSourceBytes!,
        documentTitle: _docxTitleController.text.trim(),
      );
      setState(() => _generatedDocxPdfBytes = pdfBytes);
      _showToast('Word converted to PDF successfully!');
    } catch (e) {
      _showToast('Conversion failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 2. EXCEL TO PDF =================
  Future<void> _runExcelToPdf() async {
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final rawText = _excelDataController.text.trim();
      final lines = rawText.split('\n');
      final rows = <List<dynamic>>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        rows.add(line.split(',').map((c) => c.trim()).toList());
      }

      final pdfBytes = await OfficeDocumentService.excelToPdf(
        rows: rows,
        sheetTitle: _excelTitleController.text.trim(),
      );
      setState(() => _generatedExcelPdfBytes = pdfBytes);
      _showToast('Spreadsheet converted to PDF table!');
    } catch (e) {
      _showToast('Excel to PDF error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 3. PPT TO PDF =================
  Future<void> _pickPptxFile() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pptx']);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _pptxSourceBytes = bytes;
          _pptxFileName = file.name;
          _pptxTitleController.text = file.name.replaceAll('.pptx', '');
          _generatedPptxPdfBytes = null;
        });
      }
    } catch (e) {
      _showToast('Error picking PPTX file: $e', isError: true);
    }
  }

  Future<void> _runPptxToPdf() async {
    if (_pptxSourceBytes == null) {
      _showToast('Please select a .pptx file first', isError: true);
      return;
    }
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final pdfBytes = await OfficeDocumentService.pptxToPdf(
        pptxBytes: _pptxSourceBytes!,
        presentationTitle: _pptxTitleController.text.trim(),
      );
      setState(() => _generatedPptxPdfBytes = pdfBytes);
      _showToast('PowerPoint slides converted to PDF!');
    } catch (e) {
      _showToast('PPT conversion failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 4. PDF TO WORD =================
  Future<void> _pickPdfForWord() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _pdfForWordBytes = bytes;
          _pdfForWordName = file.name;
          _generatedDocxBytes = null;
        });
      }
    } catch (e) {
      _showToast('Error picking PDF: $e', isError: true);
    }
  }

  void _runPdfToWord() {
    if (_pdfForWordBytes == null) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final docx = OfficeDocumentService.pdfToDocx(_pdfForWordBytes!);
      setState(() => _generatedDocxBytes = docx);
      _showToast('PDF extracted into Word (.docx) document!');
    } catch (e) {
      _showToast('Failed to convert PDF to Word: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 5. PDF TO EXCEL =================
  Future<void> _pickPdfForExcel() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _pdfForExcelBytes = bytes;
          _pdfForExcelName = file.name;
          _extractedCsvContent = null;
        });
      }
    } catch (e) {
      _showToast('Error picking PDF: $e', isError: true);
    }
  }

  void _runPdfToExcel() {
    if (_pdfForExcelBytes == null) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final csv = OfficeDocumentService.pdfToCsv(_pdfForExcelBytes!);
      setState(() => _extractedCsvContent = csv);
      _showToast('Tables extracted into CSV spreadsheet!');
    } catch (e) {
      _showToast('PDF to Excel error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 6. PDF TO PPT =================
  Future<void> _pickPdfForPpt() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _pdfForPptBytes = bytes;
          _pdfForPptName = file.name;
          _generatedPptxBytes = null;
        });
      }
    } catch (e) {
      _showToast('Error picking PDF: $e', isError: true);
    }
  }

  void _runPdfToPpt() {
    if (_pdfForPptBytes == null) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final pptx = OfficeDocumentService.pdfToPptx(_pdfForPptBytes!);
      setState(() => _generatedPptxBytes = pptx);
      _showToast('PDF converted to PowerPoint deck!');
    } catch (e) {
      _showToast('PDF to PPT failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 7. SEARCHABLE OCR =================
  Future<void> _pickOcrImage() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _ocrImageBytes = bytes;
          _ocrImageName = file.name;
          _generatedSearchablePdfBytes = null;
        });
      }
    } catch (e) {
      _showToast('Error picking image: $e', isError: true);
    }
  }

  Future<void> _runSearchableOcr() async {
    if (_ocrImageBytes == null) {
      _showToast('Please select a document image first', isError: true);
      return;
    }
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final pdfBytes = await OfficeDocumentService.createSearchablePdf(
        imageBytes: _ocrImageBytes!,
        ocrText: _ocrTextController.text.trim(),
      );
      setState(() => _generatedSearchablePdfBytes = pdfBytes);
      _showToast('Searchable PDF with OCR layer created!');
    } catch (e) {
      _showToast('Searchable PDF error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 8. METADATA =================
  Future<void> _pickPdfForMetadata() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final meta = OfficeDocumentService.readMetadata(bytes);
        setState(() {
          _metadataPdfBytes = bytes;
          _metadataPdfName = file.name;
          _loadedMetadata = meta;
          _metaTitleCtrl.text = meta.title;
          _metaAuthorCtrl.text = meta.author;
          _metaSubjectCtrl.text = meta.subject;
          _metaKeywordsCtrl.text = meta.keywords;
          _metaCreatorCtrl.text = meta.creator;
          _metaProducerCtrl.text = meta.producer;
          _updatedMetadataPdfBytes = null;
        });
      }
    } catch (e) {
      _showToast('Error inspecting PDF metadata: $e', isError: true);
    }
  }

  void _runUpdateMetadata() {
    if (_metadataPdfBytes == null) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final updated = OfficeDocumentService.updateMetadata(
        pdfBytes: _metadataPdfBytes!,
        title: _metaTitleCtrl.text.trim(),
        author: _metaAuthorCtrl.text.trim(),
        subject: _metaSubjectCtrl.text.trim(),
        keywords: _metaKeywordsCtrl.text.trim(),
        creator: _metaCreatorCtrl.text.trim(),
        producer: _metaProducerCtrl.text.trim(),
      );
      setState(() => _updatedMetadataPdfBytes = updated);
      _showToast('PDF metadata updated & saved!');
    } catch (e) {
      _showToast('Metadata update failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 9. PAGE EXTRACTION =================
  Future<void> _pickPdfForExtraction() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final meta = OfficeDocumentService.readMetadata(bytes);
        setState(() {
          _extractSourcePdfBytes = bytes;
          _extractSourcePdfName = file.name;
          _extractSourcePageCount = meta.pageCount;
          _extractedZipBytes = null;
        });
      }
    } catch (e) {
      _showToast('Error picking PDF: $e', isError: true);
    }
  }

  void _runPageExtraction() {
    if (_extractSourcePdfBytes == null) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final input = _extractPagesController.text.trim();
      final pageNumbers = <int>[];

      for (final part in input.split(',')) {
        final trimmed = part.trim();
        if (trimmed.contains('-')) {
          final bounds = trimmed.split('-');
          final start = int.tryParse(bounds[0].trim()) ?? 1;
          final end = int.tryParse(bounds[1].trim()) ?? start;
          for (int p = start; p <= end; p++) {
            pageNumbers.add(p);
          }
        } else {
          final p = int.tryParse(trimmed);
          if (p != null) pageNumbers.add(p);
        }
      }

      if (pageNumbers.isEmpty) {
        _showToast('Please specify valid page numbers (e.g. 1, 3, 5)', isError: true);
        return;
      }

      final zip = OfficeDocumentService.extractPagesToZip(
        pdfBytes: _extractSourcePdfBytes!,
        pageNumbers: pageNumbers.toSet().toList()..sort(),
        baseName: _extractSourcePdfName.replaceAll('.pdf', ''),
      );

      setState(() => _extractedZipBytes = zip);
      _showToast('Extracted ${pageNumbers.length} pages into ZIP archive!');
    } catch (e) {
      _showToast('Page extraction failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 10. BOOKMARKS =================
  Future<void> _pickPdfForBookmarks() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final bms = OfficeDocumentService.readBookmarks(bytes);
        setState(() {
          _bookmarksPdfBytes = bytes;
          _bookmarksPdfName = file.name;
          _loadedBookmarks = bms;
          _updatedBookmarksPdfBytes = null;
        });
      }
    } catch (e) {
      _showToast('Error reading bookmarks: $e', isError: true);
    }
  }

  void _runSaveBookmarks() {
    if (_bookmarksPdfBytes == null) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final updated = OfficeDocumentService.saveBookmarks(
        pdfBytes: _bookmarksPdfBytes!,
        bookmarks: _loadedBookmarks,
      );
      setState(() => _updatedBookmarksPdfBytes = updated);
      _showToast('Bookmarks saved to PDF!');
    } catch (e) {
      _showToast('Save bookmarks failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 11. FLATTEN FORMS =================
  Future<void> _pickPdfForFlatten() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _flattenPdfBytes = bytes;
          _flattenPdfName = file.name;
          _flattenedResultPdfBytes = null;
        });
      }
    } catch (e) {
      _showToast('Error picking PDF: $e', isError: true);
    }
  }

  void _runFlattenForms() {
    if (_flattenPdfBytes == null) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final flattened = OfficeDocumentService.flattenForms(_flattenPdfBytes!);
      setState(() => _flattenedResultPdfBytes = flattened);
      _showToast('All interactive form fields permanently flattened!');
    } catch (e) {
      _showToast('Flattening error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 12. COMPARE PDFS =================
  Future<void> _pickComparePdfA() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _comparePdfABytes = bytes;
          _comparePdfAName = file.name;
          _comparisonResult = null;
        });
      }
    } catch (e) {
      _showToast('Error picking Document A: $e', isError: true);
    }
  }

  Future<void> _pickComparePdfB() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _comparePdfBBytes = bytes;
          _comparePdfBName = file.name;
          _comparisonResult = null;
        });
      }
    } catch (e) {
      _showToast('Error picking Document B: $e', isError: true);
    }
  }

  void _runComparePdfs() {
    if (_comparePdfABytes == null || _comparePdfBBytes == null) {
      _showToast('Please select both Document A and Document B', isError: true);
      return;
    }
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final result = OfficeDocumentService.comparePdfs(_comparePdfABytes!, _comparePdfBBytes!);
      setState(() => _comparisonResult = result);
      _showToast('Comparison completed! (${result.similarityPercent.toStringAsFixed(1)}% match)');
    } catch (e) {
      _showToast('Comparison error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Office & Advanced PDF Suite',
      category: ToolCategory.filesText,
      toolId: 'office_doc_pdf_suite',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeatureTabSelector<OfficePdfTab>(
            accentColor: AppColors.catPdf,
            activeTab: _activeTab,
            onTabSelected: (tab) {
              PreferencesService().triggerHaptic();
              setState(() => _activeTab = tab);
            },
            tabs: OfficePdfTab.values.map((t) => FeatureTabItem(value: t, label: t.label, icon: t.icon)).toList(),
          ),
          const SizedBox(height: 16),
          _buildActiveTab(isDark),
        ],
      ),
    );
  }

  Widget _buildActiveTab(bool isDark) {
    switch (_activeTab) {
      case OfficePdfTab.wordToPdf:
        return _buildWordToPdfTab(isDark);
      case OfficePdfTab.excelToPdf:
        return _buildExcelToPdfTab(isDark);
      case OfficePdfTab.pptxToPdf:
        return _buildPptxToPdfTab(isDark);
      case OfficePdfTab.pdfToWord:
        return _buildPdfToWordTab(isDark);
      case OfficePdfTab.pdfToExcel:
        return _buildPdfToExcelTab(isDark);
      case OfficePdfTab.pdfToPptx:
        return _buildPdfToPptxTab(isDark);
      case OfficePdfTab.searchableOcr:
        return _buildSearchableOcrTab(isDark);
      case OfficePdfTab.metadata:
        return _buildMetadataTab(isDark);
      case OfficePdfTab.pageExtraction:
        return _buildPageExtractionTab(isDark);
      case OfficePdfTab.bookmarks:
        return _buildBookmarksTab(isDark);
      case OfficePdfTab.flattenForms:
        return _buildFlattenFormsTab(isDark);
      case OfficePdfTab.comparePdfs:
        return _buildComparePdfsTab(isDark);
    }
  }

  // --- 1. WORD TO PDF ---
  Widget _buildWordToPdfTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Word Document to PDF Converter',
          primaryResult: _docxFileName.isNotEmpty ? _docxFileName : 'Select DOCX',
          subtitle: 'Parses OpenXML headings, paragraphs, and styles into formatted PDF',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_open_rounded),
          label: Text(_docxFileName.isNotEmpty ? 'Change DOCX File' : 'Pick .docx Word Document'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkCardHover,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: _pickWordFile,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _docxTitleController,
          decoration: InputDecoration(
            labelText: 'PDF Document Header Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Convert Word to PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isProcessing ? null : _runWordToPdf,
        ),
        if (_generatedDocxPdfBytes != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Converted PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () => _shareFile(_generatedDocxPdfBytes!, '${_docxTitleController.text.trim()}.pdf'),
          ),
        ],
      ],
    );
  }

  // --- 2. EXCEL TO PDF ---
  Widget _buildExcelToPdfTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Excel / CSV Spreadsheet to PDF',
          primaryResult: 'Tabular PDF Engine',
          subtitle: 'Generates landscape tabular PDF report with zebra striping',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _excelTitleController,
          decoration: InputDecoration(
            labelText: 'Report Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _excelDataController,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Comma-Separated Data (CSV / Tabular)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.table_view_rounded),
          label: const Text('Generate Tabular PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isProcessing ? null : _runExcelToPdf,
        ),
        if (_generatedExcelPdfBytes != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Tabular PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () => _shareFile(_generatedExcelPdfBytes!, '${_excelTitleController.text.trim()}.pdf'),
          ),
        ],
      ],
    );
  }

  // --- 3. PPT TO PDF ---
  Widget _buildPptxToPdfTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PowerPoint (.pptx) to PDF',
          primaryResult: _pptxFileName.isNotEmpty ? _pptxFileName : 'Select PPTX',
          subtitle: 'Transforms presentation slide decks into 16:9 landscape PDF slides',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.slideshow_rounded),
          label: Text(_pptxFileName.isNotEmpty ? 'Change PPTX' : 'Pick .pptx Presentation'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover, minimumSize: const Size(double.infinity, 48)),
          onPressed: _pickPptxFile,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pptxTitleController,
          decoration: InputDecoration(
            labelText: 'Deck Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Convert Slides to PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isProcessing ? null : _runPptxToPdf,
        ),
        if (_generatedPptxPdfBytes != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Presentation PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            onPressed: () => _shareFile(_generatedPptxPdfBytes!, '${_pptxTitleController.text.trim()}.pdf'),
          ),
        ],
      ],
    );
  }

  // --- 4. PDF TO WORD ---
  Widget _buildPdfToWordTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PDF to Word (.docx) Converter',
          primaryResult: _pdfForWordName.isNotEmpty ? _pdfForWordName : 'Select PDF',
          subtitle: 'Packages extracted text layout into standard OpenXML Word document',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_pdfForWordName.isNotEmpty ? 'Change PDF' : 'Pick PDF to Convert'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover, minimumSize: const Size(double.infinity, 48)),
          onPressed: _pickPdfForWord,
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.description_rounded),
          label: const Text('Extract & Generate .docx'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pdfForWordBytes != null && !_isProcessing ? _runPdfToWord : null,
        ),
        if (_generatedDocxBytes != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded),
            label: const Text('Share .docx Document'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            onPressed: () => _shareFile(_generatedDocxBytes!, '${_pdfForWordName.replaceAll('.pdf', '')}.docx'),
          ),
        ],
      ],
    );
  }

  // --- 5. PDF TO EXCEL ---
  Widget _buildPdfToExcelTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PDF to Excel / CSV Table Extractor',
          primaryResult: _pdfForExcelName.isNotEmpty ? _pdfForExcelName : 'Select PDF',
          subtitle: 'Detects columns, rows, and structured financial data',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_pdfForExcelName.isNotEmpty ? 'Change PDF' : 'Pick PDF with Tables'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover, minimumSize: const Size(double.infinity, 48)),
          onPressed: _pickPdfForExcel,
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.grid_on_rounded),
          label: const Text('Extract Tables to CSV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pdfForExcelBytes != null && !_isProcessing ? _runPdfToExcel : null,
        ),
        if (_extractedCsvContent != null) ...[
          const SizedBox(height: 20),
          const Text('Extracted CSV Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCardHover,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: SelectableText(
              _extractedCsvContent!,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share CSV Spreadsheet'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            onPressed: () => _shareFile(Uint8List.fromList(utf8.encode(_extractedCsvContent!)), '${_pdfForExcelName.replaceAll('.pdf', '')}.csv'),
          ),
        ],
      ],
    );
  }

  // --- 6. PDF TO PPT ---
  Widget _buildPdfToPptxTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PDF to PowerPoint (.pptx) Deck',
          primaryResult: _pdfForPptName.isNotEmpty ? _pdfForPptName : 'Select PDF',
          subtitle: 'Converts multi-page PDF into editable OpenXML slide presentation',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_pdfForPptName.isNotEmpty ? 'Change PDF' : 'Pick PDF Document'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover, minimumSize: const Size(double.infinity, 48)),
          onPressed: _pickPdfForPpt,
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.present_to_all_rounded),
          label: const Text('Convert Pages to PPTX'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pdfForPptBytes != null && !_isProcessing ? _runPdfToPpt : null,
        ),
        if (_generatedPptxBytes != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded),
            label: const Text('Share .pptx Presentation'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            onPressed: () => _shareFile(_generatedPptxBytes!, '${_pdfForPptName.replaceAll('.pdf', '')}.pptx'),
          ),
        ],
      ],
    );
  }

  // --- 7. SEARCHABLE OCR ---
  Widget _buildSearchableOcrTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Searchable PDF with OCR Layer',
          primaryResult: _ocrImageName.isNotEmpty ? _ocrImageName : 'Select Scanned Image',
          subtitle: 'Overlays invisible selectable & searchable text layer atop image',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.image_rounded),
          label: Text(_ocrImageName.isNotEmpty ? 'Change Document Photo' : 'Pick Scanned Image / Document'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover, minimumSize: const Size(double.infinity, 48)),
          onPressed: _pickOcrImage,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ocrTextController,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Searchable OCR Text Layer',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.find_in_page_rounded),
          label: const Text('Generate Searchable PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _ocrImageBytes != null && !_isProcessing ? _runSearchableOcr : null,
        ),
        if (_generatedSearchablePdfBytes != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Searchable PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            onPressed: () => _shareFile(_generatedSearchablePdfBytes!, 'Searchable_OCR_Document.pdf'),
          ),
        ],
      ],
    );
  }

  // --- 8. METADATA EDITOR ---
  Widget _buildMetadataTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PDF Metadata Viewer & Editor',
          primaryResult: _metadataPdfName.isNotEmpty ? _metadataPdfName : 'Select PDF',
          subtitle: 'Inspect and edit Title, Author, Subject, Keywords, Creator & Producer',
          accentColor: AppColors.catPdf,
          breakdowns: _loadedMetadata != null
              ? [
                  BreakdownItem(label: 'Pages', value: '${_loadedMetadata!.pageCount}'),
                  BreakdownItem(label: 'File Size', value: '${(_loadedMetadata!.sizeBytes / 1024).toStringAsFixed(1)} KB'),
                ]
              : null,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_metadataPdfName.isNotEmpty ? 'Change PDF' : 'Pick PDF to Inspect'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover, minimumSize: const Size(double.infinity, 48)),
          onPressed: _pickPdfForMetadata,
        ),
        if (_loadedMetadata != null) ...[
          const SizedBox(height: 16),
          TextField(controller: _metaTitleCtrl, decoration: InputDecoration(labelText: 'Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 10),
          TextField(controller: _metaAuthorCtrl, decoration: InputDecoration(labelText: 'Author', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 10),
          TextField(controller: _metaSubjectCtrl, decoration: InputDecoration(labelText: 'Subject', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 10),
          TextField(controller: _metaKeywordsCtrl, decoration: InputDecoration(labelText: 'Keywords', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 10),
          TextField(controller: _metaCreatorCtrl, decoration: InputDecoration(labelText: 'Creator', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_rounded),
            label: const Text('Update & Save Metadata'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.catPdf, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            onPressed: _runUpdateMetadata,
          ),
          if (_updatedMetadataPdfBytes != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share PDF with New Metadata'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
              onPressed: () => _shareFile(_updatedMetadataPdfBytes!, 'Updated_Meta_$_metadataPdfName'),
            ),
          ],
        ],
      ],
    );
  }

  // --- 9. PAGE EXTRACTION ---
  Widget _buildPageExtractionTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Extract Pages to Separate Files',
          primaryResult: _extractSourcePdfName.isNotEmpty ? '$_extractSourcePageCount Pages Total' : 'Select PDF',
          subtitle: 'Splits chosen pages into individual PDFs bundled in a ZIP archive',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.call_split_rounded),
          label: Text(_extractSourcePdfName.isNotEmpty ? 'Change PDF' : 'Pick Multi-Page PDF'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover, minimumSize: const Size(double.infinity, 48)),
          onPressed: _pickPdfForExtraction,
        ),
        if (_extractSourcePdfBytes != null) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _extractPagesController,
            decoration: InputDecoration(
              labelText: 'Pages to Extract (e.g. 1, 3, 5-8)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_zip_rounded),
            label: const Text('Extract Pages to ZIP Archive'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.catPdf, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            onPressed: _runPageExtraction,
          ),
          if (_extractedZipBytes != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share Extracted Pages ZIP'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
              onPressed: () => _shareFile(_extractedZipBytes!, 'Extracted_Pages.zip'),
            ),
          ],
        ],
      ],
    );
  }

  // --- 10. BOOKMARKS & TOC ---
  Widget _buildBookmarksTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Bookmarks & Table-of-Contents Manager',
          primaryResult: '${_loadedBookmarks.length} Bookmark(s)',
          subtitle: 'Create interactive navigation outlines for easy document reading',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_bookmarksPdfName.isNotEmpty ? 'Change PDF' : 'Pick PDF to Manage Bookmarks'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover, minimumSize: const Size(double.infinity, 48)),
          onPressed: _pickPdfForBookmarks,
        ),
        if (_bookmarksPdfBytes != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _newBmTitleCtrl,
                  decoration: InputDecoration(labelText: 'Bookmark Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _newBmPageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Page #', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(backgroundColor: AppColors.catPdf),
                onPressed: () {
                  final title = _newBmTitleCtrl.text.trim();
                  final page = int.tryParse(_newBmPageCtrl.text.trim()) ?? 1;
                  if (title.isNotEmpty) {
                    setState(() {
                      _loadedBookmarks.add(PdfBookmarkItem(title: title, pageNumber: page));
                      _newBmTitleCtrl.clear();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _loadedBookmarks.length,
            itemBuilder: (context, i) {
              final bm = _loadedBookmarks[i];
              return ListTile(
                leading: const Icon(Icons.bookmark_rounded, color: AppColors.catPdf),
                title: Text(bm.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Target: Page ${bm.pageNumber}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => setState(() => _loadedBookmarks.removeAt(i)),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Bookmarks to PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.catPdf, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            onPressed: _runSaveBookmarks,
          ),
          if (_updatedBookmarksPdfBytes != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share PDF with TOC Bookmarks'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
              onPressed: () => _shareFile(_updatedBookmarksPdfBytes!, 'Bookmarked_$_bookmarksPdfName'),
            ),
          ],
        ],
      ],
    );
  }

  // --- 11. FLATTEN FORMS ---
  Widget _buildFlattenFormsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PDF Form Flattening Engine',
          primaryResult: _flattenPdfName.isNotEmpty ? _flattenPdfName : 'Select Form PDF',
          subtitle: 'Locks interactive fillable fields into non-editable static document graphics',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_flattenPdfName.isNotEmpty ? 'Change PDF' : 'Pick Fillable Form PDF'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover, minimumSize: const Size(double.infinity, 48)),
          onPressed: _pickPdfForFlatten,
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.lock_rounded),
          label: const Text('Flatten All Form Fields'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.catPdf, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
          onPressed: _flattenPdfBytes != null && !_isProcessing ? _runFlattenForms : null,
        ),
        if (_flattenedResultPdfBytes != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Flattened Tamper-Proof PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            onPressed: () => _shareFile(_flattenedResultPdfBytes!, 'Flattened_$_flattenPdfName'),
          ),
        ],
      ],
    );
  }

  // --- 12. COMPARE PDFS ---
  Widget _buildComparePdfsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'PDF Document Comparison',
          primaryResult: _comparisonResult != null
              ? '${_comparisonResult!.similarityPercent.toStringAsFixed(1)}% Match'
              : 'Select 2 Files',
          subtitle: 'Compares page counts, sizes, and line-by-line textual revisions',
          accentColor: AppColors.catPdf,
          breakdowns: _comparisonResult != null
              ? [
                  BreakdownItem(label: 'Unchanged', value: '${_comparisonResult!.unchangedCount} lines'),
                  BreakdownItem(label: 'Additions', value: '+${_comparisonResult!.addedCount} lines'),
                  BreakdownItem(label: 'Deletions', value: '-${_comparisonResult!.removedCount} lines'),
                ]
              : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.file_present_rounded),
                label: Text(_comparePdfAName.isNotEmpty ? _comparePdfAName : 'Document A'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover),
                onPressed: _pickComparePdfA,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.file_present_rounded),
                label: Text(_comparePdfBName.isNotEmpty ? _comparePdfBName : 'Document B'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover),
                onPressed: _pickComparePdfB,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.compare_arrows_rounded),
          label: const Text('Run Side-by-Side Comparison'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.catPdf, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
          onPressed: _comparePdfABytes != null && _comparePdfBBytes != null && !_isProcessing ? _runComparePdfs : null,
        ),
        if (_comparisonResult != null) ...[
          const SizedBox(height: 20),
          const Text('Revision Diffs:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 240,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCardHover,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: ListView.builder(
              itemCount: _comparisonResult!.diffLines.length,
              itemBuilder: (context, i) {
                final line = _comparisonResult!.diffLines[i];
                Color textColor = isDark ? Colors.white70 : Colors.black87;
                Color bgColor = Colors.transparent;
                String prefix = '  ';

                if (line.type == 'added') {
                  textColor = AppColors.success;
                  bgColor = AppColors.success.withValues(alpha: 0.12);
                  prefix = '+ ';
                } else if (line.type == 'removed') {
                  textColor = AppColors.error;
                  bgColor = AppColors.error.withValues(alpha: 0.12);
                  prefix = '- ';
                }

                return Container(
                  color: bgColor,
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Text(
                    '$prefix${line.text}',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: textColor),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
