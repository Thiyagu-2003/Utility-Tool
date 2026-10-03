import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum PdfToolkitTab {
  imagesToPdf('Images to PDF'),
  textToPdf('Text to PDF'),
  watermark('Watermark & Pages'),
  metadata('Metadata & Tools');

  final String label;
  const PdfToolkitTab(this.label);
}

class ImageFileItem {
  final String name;
  final Uint8List bytes;

  ImageFileItem({required this.name, required this.bytes});
}

class PdfToolkitScreen extends StatefulWidget {
  const PdfToolkitScreen({super.key});

  @override
  State<PdfToolkitScreen> createState() => _PdfToolkitScreenState();
}

class _PdfToolkitScreenState extends State<PdfToolkitScreen> {
  PdfToolkitTab _activeTab = PdfToolkitTab.imagesToPdf;

  // Images to PDF state
  final List<ImageFileItem> _selectedImages = [];
  PdfPageFormat _pageFormat = PdfPageFormat.a4;
  bool _isLandscape = false;
  bool _addPageNumbers = true;
  bool _isGeneratingPdf = false;

  // Text to PDF state
  final TextEditingController _docTitleController = TextEditingController(text: 'Document Report');
  final TextEditingController _authorController = TextEditingController(text: 'Author Name');
  final TextEditingController _docBodyController = TextEditingController(
    text: 'This document was generated using the Omni Utility App PDF Toolkit.\n\n'
        'You can type or paste any formatted notes, meeting minutes, contracts, or summaries here. '
        'The engine automatically computes text pagination, headers, footers, and page numbers.\n\n'
        'Key Highlights:\n'
        '• Clean high-resolution typography\n'
        '• Automatic multi-page flowing\n'
        '• Optional watermark protection\n'
        '• Instant sharing and wireless printing',
  );
  final TextEditingController _watermarkController = TextEditingController(text: 'CONFIDENTIAL');
  bool _enableWatermark = false;

  // Metadata / Info State
  PlatformFile? _inspectedPdf;
  String _pdfInfo = 'No PDF selected yet';

  Future<void> _pickImages() async {
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (files.isNotEmpty) {
        for (final file in files) {
          final bytes = await file.readAsBytes();
          _selectedImages.add(ImageFileItem(name: file.name, bytes: bytes));
        }
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Future<void> _generateImagesPdf() async {
    if (_selectedImages.isEmpty) return;

    setState(() => _isGeneratingPdf = true);
    PreferencesService().triggerHaptic();

    try {
      final doc = pw.Document();
      final resolvedFormat = _isLandscape ? _pageFormat.landscape : _pageFormat;

      for (int i = 0; i < _selectedImages.length; i++) {
        final img = _selectedImages[i];
        final pdfImage = pw.MemoryImage(img.bytes);

        doc.addPage(
          pw.Page(
            pageFormat: resolvedFormat,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  pw.Center(
                    child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                  ),
                  if (_addPageNumbers)
                    pw.Positioned(
                      bottom: 0,
                      right: 0,
                      child: pw.Text(
                        'Page ${i + 1} of ${_selectedImages.length}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Images_Document.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _generateTextPdf() async {
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
          pageFormat: _isLandscape ? _pageFormat.landscape : _pageFormat,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  if (author.isNotEmpty)
                    pw.Text(author, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 16),
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated by Omni Utility Tool', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              if (_enableWatermark && watermark.isNotEmpty)
                pw.Center(
                  child: pw.Transform.rotate(
                    angle: -0.5,
                    child: pw.Text(
                      watermark,
                      style: pw.TextStyle(
                        fontSize: 48,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey300,
                      ),
                    ),
                  ),
                ),
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.Paragraph(
                text: body,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 2),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: '${title.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _pickAndInspectPdf() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (file != null) {
        final sizeBytes = await file.length() ?? 0;
        final kbSize = (sizeBytes / 1024).toStringAsFixed(1);
        setState(() {
          _inspectedPdf = file;
          _pdfInfo = 'Filename: ${file.name}\nSize: $kbSize KB\nExtension: ${file.extension?.toUpperCase()}\nStatus: Verified PDF Document';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inspecting PDF: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _docTitleController.dispose();
    _authorController.dispose();
    _docBodyController.dispose();
    _watermarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'PDF Toolkit',
      category: ToolCategory.documents,
      toolId: 'pdf_toolkit',
      onReset: () {
        setState(() {
          _selectedImages.clear();
          _docTitleController.text = 'Document Report';
          _authorController.text = 'Author Name';
          _docBodyController.text = 'Notes & content...';
          _watermarkController.text = 'CONFIDENTIAL';
          _enableWatermark = false;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PdfToolkitTab.values.map((tab) {
                final isSelected = tab == _activeTab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(tab.label),
                    selected: isSelected,
                    selectedColor: AppColors.catPdf,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _activeTab = tab);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // TAB 1: Images to PDF
          if (_activeTab == PdfToolkitTab.imagesToPdf) ...[
            ResultCard(
              title: 'PDF Summary',
              primaryResult: '${_selectedImages.length} ${_selectedImages.length == 1 ? 'Page' : 'Pages'}',
              subtitle: 'Page Format: ${_pageFormat == PdfPageFormat.a4 ? 'A4' : 'Letter'} • ${_isLandscape ? 'Landscape' : 'Portrait'}',
              accentColor: AppColors.catPdf,
              breakdowns: [
                BreakdownItem(label: 'Total Images', value: _selectedImages.length.toString()),
                BreakdownItem(label: 'Page Numbers', value: _addPageNumbers ? 'Enabled' : 'Disabled'),
                BreakdownItem(label: 'Status', value: _selectedImages.isEmpty ? 'Ready' : 'Prepared'),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: const Text('Add Images'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.catPdf,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _pickImages,
                  ),
                ),
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear_all_rounded),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      setState(() => _selectedImages.clear());
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Page format and orientation controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Page Size', style: TextStyle(fontWeight: FontWeight.w600)),
                      DropdownButton<PdfPageFormat>(
                        value: _pageFormat,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: PdfPageFormat.a4, child: Text('A4 (Standard)')),
                          DropdownMenuItem(value: PdfPageFormat.letter, child: Text('US Letter')),
                        ],
                        onChanged: (f) {
                          if (f != null) setState(() => _pageFormat = f);
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Landscape Orientation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    value: _isLandscape,
                    activeColor: AppColors.catPdf,
                    onChanged: (val) => setState(() => _isLandscape = val),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Add Page Numbers (Page X of Y)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    value: _addPageNumbers,
                    activeColor: AppColors.catPdf,
                    onChanged: (val) => setState(() => _addPageNumbers = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Image Thumbnails Grid
            if (_selectedImages.isNotEmpty) ...[
              Text(
                'Selected Pages (${_selectedImages.length})'.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, idx) {
                    final img = _selectedImages[idx];
                    return Stack(
                      children: [
                        Container(
                          width: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.catPdf.withOpacity(0.5)),
                            image: DecorationImage(image: MemoryImage(img.bytes), fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedImages.removeAt(idx));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                            child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isGeneratingPdf
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(_isGeneratingPdf ? 'Building PDF...' : 'Convert Images to PDF & Share'),
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

          // TAB 2: Text to PDF
          if (_activeTab == PdfToolkitTab.textToPdf) ...[
            ModernTextField(
              label: 'Document Title',
              controller: _docTitleController,
              hintText: 'e.g. Project Proposal',
              prefixIcon: Icons.title_rounded,
            ),
            const SizedBox(height: 16),
            ModernTextField(
              label: 'Author / Subtitle',
              controller: _authorController,
              hintText: 'e.g. John Doe',
              prefixIcon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 16),
            ModernTextField(
              label: 'Document Body / Notes',
              controller: _docBodyController,
              hintText: 'Type your report or content here...',
              maxLines: 8,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add Background Watermark', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              value: _enableWatermark,
              activeColor: AppColors.catPdf,
              onChanged: (val) => setState(() => _enableWatermark = val),
            ),
            if (_enableWatermark) ...[
              const SizedBox(height: 8),
              ModernTextField(
                label: 'Watermark Text',
                controller: _watermarkController,
                hintText: 'CONFIDENTIAL',
                prefixIcon: Icons.branding_watermark_rounded,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print_rounded),
                label: const Text('Generate Print-Ready PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catPdf,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _generateTextPdf,
              ),
            ),
          ],

          // TAB 3: Watermark & Page Settings
          if (_activeTab == PdfToolkitTab.watermark) ...[
            ResultCard(
              title: 'Watermark Guide',
              primaryResult: 'Diagonal Stamp',
              subtitle: 'Protects confidential files, drafts, and receipts',
              accentColor: AppColors.catPdf,
              breakdowns: const [
                BreakdownItem(label: 'Standard Presets', value: 'CONFIDENTIAL'),
                BreakdownItem(label: 'Angle', value: '45° Diagonal'),
                BreakdownItem(label: 'Opacity', value: '25% Translucent'),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Recommended Watermark Presets'.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['CONFIDENTIAL', 'DRAFT', 'OFFICIAL', 'COPY', 'PAID', 'APPROVED'].map((preset) {
                return ActionChip(
                  label: Text(preset),
                  onPressed: () {
                    PreferencesService().triggerHaptic();
                    setState(() {
                      _watermarkController.text = preset;
                      _enableWatermark = true;
                      _activeTab = PdfToolkitTab.textToPdf;
                    });
                  },
                );
              }).toList(),
            ),
          ],

          // TAB 4: Metadata Viewer
          if (_activeTab == PdfToolkitTab.metadata) ...[
            ResultCard(
              title: 'PDF Inspector',
              primaryResult: _inspectedPdf != null ? _inspectedPdf!.name : 'Select a File',
              subtitle: _pdfInfo,
              accentColor: AppColors.catPdf,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.file_open_rounded),
                label: const Text('Pick PDF to Inspect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catPdf,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _pickAndInspectPdf,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
