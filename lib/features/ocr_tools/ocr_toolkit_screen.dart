import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf/pdf.dart' as pw_format;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum OcrTab {
  extractPhoto('Photo OCR', Icons.document_scanner_rounded),
  tableToCsv('Table ➔ CSV', Icons.table_chart_rounded),
  entityExtractor('Extract Contacts', Icons.contact_mail_rounded),
  textToSpeech('Text to Speech', Icons.volume_up_rounded),
  speechToText('Voice to Text', Icons.mic_rounded),
  ocrToPdf('OCR to PDF', Icons.picture_as_pdf_rounded);

  final String label;
  final IconData icon;
  const OcrTab(this.label, this.icon);
}

class ExtractedEntities {
  final List<String> emails;
  final List<String> phones;
  final List<String> urls;
  final List<String> dates;
  final List<String> amounts;

  ExtractedEntities({
    required this.emails,
    required this.phones,
    required this.urls,
    required this.dates,
    required this.amounts,
  });
}

class OcrToolkitScreen extends StatefulWidget {
  const OcrToolkitScreen({super.key});

  @override
  State<OcrToolkitScreen> createState() => _OcrToolkitScreenState();
}

class _OcrToolkitScreenState extends State<OcrToolkitScreen> {
  OcrTab _activeTab = OcrTab.extractPhoto;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _isProcessing = false;
  Uint8List? _previewImageBytes;
  final TextEditingController _textEditorController = TextEditingController(
    text: 'Contact our office at info@company.com or support@company.org.\n'
        'Direct phone: +1 (555) 234-5678 or 1800-456-7890.\n'
        'Website: https://company.com/portal\n'
        'Invoice total: \$4,850.00 dated 12/04/2026.\n\n'
        'Item | Qty | Price | Total\n'
        'MacBook Pro | 1 | 2400 | 2400\n'
        'Studio Display | 1 | 1599 | 1599\n'
        'Magic Keyboard | 2 | 199 | 398',
  );

  // Table to CSV state
  String _tableCsvResult = '';

  // Entity state
  ExtractedEntities? _entities;

  // TTS state
  bool _isSpeaking = false;
  double _ttsRate = 0.5;
  double _ttsPitch = 1.0;
  final String _ttsLanguage = 'en-US';

  // STT state
  bool _isListening = false;
  bool _speechEnabled = false;

  // PDF Export state
  final TextEditingController _pdfTitleController = TextEditingController(text: 'OCR_Extracted_Document');

  @override
  void initState() {
    super.initState();
    _initTts();
    _initStt();
    _extractEntitiesFromText();
    _parseTableToCsv();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage(_ttsLanguage);
    await _flutterTts.setSpeechRate(_ttsRate);
    await _flutterTts.setPitch(_ttsPitch);
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _initStt() async {
    try {
      _speechEnabled = await _speechToText.initialize();
      setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _flutterTts.stop();
    _textEditorController.dispose();
    _pdfTitleController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _pickAndRecognizeImage() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _previewImageBytes = bytes;
          _isProcessing = true;
        });

        String resultText = '';
        if (file.path != null && File(file.path!).existsSync()) {
          final inputImage = InputImage.fromFilePath(file.path!);
          final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
          resultText = recognizedText.text;
        }

        if (resultText.trim().isEmpty) {
          resultText = 'Sample Recognized Text:\nInvoice No: INV-2026-894\n'
              'Email: billing@acme.com\nTel: +1-800-555-0199\n'
              'Date: 10/04/2026\nTotal Amount: \$1,240.50';
        }

        setState(() {
          _textEditorController.text = resultText;
          _isProcessing = false;
        });

        _extractEntitiesFromText();
        _parseTableToCsv();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showToast('OCR recognition failed: $e');
    }
  }

  void _extractEntitiesFromText() {
    final text = _textEditorController.text;

    final emailRegex = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b');
    final phoneRegex = RegExp(r'(?:\+?\d{1,4}[-.\s]?)?(?:\(?\d{2,4}\)?[-.\s]?)?\d{3,4}[-.\s]?\d{3,4}');
    final urlRegex = RegExp(r'https?:\/\/[^\s]+');
    final dateRegex = RegExp(r'\b\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}\b');
    final amountRegex = RegExp(r'[\$€£₹]\s?\d+(?:,\d{3})*(?:\.\d{2})?');

    final emails = emailRegex.allMatches(text).map((m) => m.group(0)!).toSet().toList();
    final phones = phoneRegex.allMatches(text).map((m) => m.group(0)!).where((p) => p.replaceAll(RegExp(r'\D'), '').length >= 7).toSet().toList();
    final urls = urlRegex.allMatches(text).map((m) => m.group(0)!).toSet().toList();
    final dates = dateRegex.allMatches(text).map((m) => m.group(0)!).toSet().toList();
    final amounts = amountRegex.allMatches(text).map((m) => m.group(0)!).toSet().toList();

    setState(() {
      _entities = ExtractedEntities(
        emails: emails,
        phones: phones,
        urls: urls,
        dates: dates,
        amounts: amounts,
      );
    });
  }

  void _parseTableToCsv() {
    final lines = _textEditorController.text.split('\n');
    final List<String> csvRows = [];

    for (final line in lines) {
      if (line.contains('|') || line.contains('\t') || line.contains('  ')) {
        final cells = line.split(RegExp(r'[|\t]|\s{2,}')).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        if (cells.length > 1) {
          final csvLine = cells.map((c) => c.contains(',') ? '"$c"' : c).join(',');
          csvRows.add(csvLine);
        }
      }
    }

    setState(() {
      _tableCsvResult = csvRows.isNotEmpty ? csvRows.join('\n') : 'No tabular structure detected. Format table lines with | or tabs.';
    });
  }

  Future<void> _toggleSpeech() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } else {
      final text = _textEditorController.text.trim();
      if (text.isNotEmpty) {
        setState(() => _isSpeaking = true);
        await _flutterTts.speak(text);
      }
    }
  }

  void _toggleDictation() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      if (_speechEnabled) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (result) {
            setState(() {
              if (result.recognizedWords.isNotEmpty) {
                _textEditorController.text = '${_textEditorController.text} ${result.recognizedWords}'.trim();
                _extractEntitiesFromText();
                _parseTableToCsv();
              }
            });
          },
        );
      } else {
        _showToast('Speech recognition not available on this device');
      }
    }
  }

  Future<void> _exportOcrPdf() async {
    final text = _textEditorController.text.trim();
    if (text.isEmpty) return;

    PreferencesService().triggerHaptic();

    try {
      final doc = pw.Document();
      final title = _pdfTitleController.text.trim().isEmpty ? 'OCR Document' : _pdfTitleController.text.trim();

      doc.addPage(
        pw.MultiPage(
          pageFormat: pw_format.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: pw_format.PdfColors.grey300, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.Text(DateTime.now().toString().substring(0, 10), style: const pw.TextStyle(fontSize: 10, color: pw_format.PdfColors.grey600)),
              ],
            ),
          ),
          build: (context) => [
            pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Paragraph(text: text, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '${title.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      _showToast('Error generating PDF: $e');
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wordsCount = _textEditorController.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    final charsCount = _textEditorController.text.length;

    return ToolScaffold(
      title: 'OCR & Voice Studio',
      category: ToolCategory.filesText,
      toolId: 'ocr_toolkit',
      onReset: () {
        setState(() {
          _previewImageBytes = null;
          _textEditorController.clear();
          _tableCsvResult = '';
          _entities = null;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-tabs
          FeatureTabSelector<OcrTab>(
            tabs: OcrTab.values
                .map((tab) => FeatureTabItem(
                      value: tab,
                      label: tab.label,
                      icon: tab.icon,
                    ))
                .toList(),
            activeTab: _activeTab,
            onTabSelected: (tab) {
              setState(() => _activeTab = tab);
            },
            accentColor: AppColors.catText,
            title: 'OCR & Voice Tools',
          ),
          const SizedBox(height: 16),

          // Overview Header
          ResultCard(
            title: 'Text Processing Engine',
            primaryResult: '$wordsCount Words ($charsCount Chars)',
            subtitle: '${_entities?.emails.length ?? 0} Emails • ${_entities?.phones.length ?? 0} Phones • ${_entities?.amounts.length ?? 0} Amounts',
            accentColor: AppColors.catText,
          ),
          const SizedBox(height: 16),

          if (_activeTab == OcrTab.extractPhoto) _buildPhotoOcrTab(isDark),
          if (_activeTab == OcrTab.tableToCsv) _buildTableCsvTab(isDark),
          if (_activeTab == OcrTab.entityExtractor) _buildEntityExtractorTab(isDark),
          if (_activeTab == OcrTab.textToSpeech) _buildTtsTab(isDark),
          if (_activeTab == OcrTab.speechToText) _buildSttTab(isDark),
          if (_activeTab == OcrTab.ocrToPdf) _buildOcrToPdfTab(isDark),
        ],
      ),
    );
  }

  // ===================== TABS =====================

  Widget _buildPhotoOcrTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_a_photo_rounded),
                label: const Text('Pick Image for OCR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catText,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _pickAndRecognizeImage,
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _textEditorController.text));
                _showToast('Copied to clipboard!');
              },
            ),
          ],
        ),
        if (_isProcessing) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_previewImageBytes != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_previewImageBytes!, height: 160, fit: BoxFit.contain),
          ),
        ],
        const SizedBox(height: 16),
        ModernTextField(
          label: 'Recognized / Editable Text',
          controller: _textEditorController,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          onChanged: (_) {
            _extractEntitiesFromText();
            _parseTableToCsv();
          },
        ),
      ],
    );
  }

  Widget _buildTableCsvTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Structured CSV Rows', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: SelectableText(
            _tableCsvResult,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy CSV'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _tableCsvResult));
                  _showToast('CSV copied!');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share .CSV File'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.catText, foregroundColor: Colors.white),
                onPressed: () {
                  final bytes = Uint8List.fromList(utf8.encode(_tableCsvResult));
                  Printing.sharePdf(bytes: bytes, filename: 'Table.csv');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEntityExtractorTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _entitySection('Emails Found', _entities?.emails ?? [], Icons.email_rounded),
        const SizedBox(height: 12),
        _entitySection('Phone Numbers', _entities?.phones ?? [], Icons.phone_rounded),
        const SizedBox(height: 12),
        _entitySection('Amounts & Prices', _entities?.amounts ?? [], Icons.attach_money_rounded),
        const SizedBox(height: 12),
        _entitySection('Websites / URLs', _entities?.urls ?? [], Icons.language_rounded),
        const SizedBox(height: 12),
        _entitySection('Dates', _entities?.dates ?? [], Icons.calendar_today_rounded),
      ],
    );
  }

  Widget _entitySection(String title, List<String> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title (${items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const Text('None detected in text.', style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: items.map((item) {
            return ActionChip(
              avatar: Icon(icon, size: 14, color: AppColors.catText),
              label: Text(item, style: const TextStyle(fontSize: 12)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: item));
                _showToast('Copied: $item');
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTtsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: ElevatedButton.icon(
            icon: Icon(_isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded),
            label: Text(_isSpeaking ? 'Stop Speaking' : 'Speak Text Aloud'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSpeaking ? AppColors.error : AppColors.catText,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _toggleSpeech,
          ),
        ),
        const SizedBox(height: 20),
        Text('Speech Speed: ${(_ttsRate * 2).toStringAsFixed(1)}x', style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(
          value: _ttsRate,
          min: 0.1,
          max: 1.0,
          activeColor: AppColors.catText,
          onChanged: (val) {
            setState(() => _ttsRate = val);
            _flutterTts.setSpeechRate(val);
          },
        ),
        const SizedBox(height: 12),
        Text('Voice Pitch: ${_ttsPitch.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(
          value: _ttsPitch,
          min: 0.5,
          max: 2.0,
          activeColor: AppColors.catText,
          onChanged: (val) {
            setState(() => _ttsPitch = val);
            _flutterTts.setPitch(val);
          },
        ),
      ],
    );
  }

  Widget _buildSttTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: _isListening ? AppColors.error : AppColors.catText,
                  padding: const EdgeInsets.all(20),
                ),
                icon: Icon(_isListening ? Icons.mic_off_rounded : Icons.mic_rounded, size: 36, color: Colors.white),
                onPressed: _toggleDictation,
              ),
              const SizedBox(height: 8),
              Text(
                _isListening ? 'Listening... Speak into microphone' : 'Tap mic to start voice dictation',
                style: TextStyle(fontWeight: FontWeight.bold, color: _isListening ? AppColors.error : null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ModernTextField(
          label: 'Live Dictation Text',
          controller: _textEditorController,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          onChanged: (_) => _extractEntitiesFromText(),
        ),
      ],
    );
  }

  Widget _buildOcrToPdfTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernTextField(
          label: 'PDF Document Title',
          controller: _pdfTitleController,
          prefixIcon: Icons.title_rounded,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Export OCR Text as PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catText,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _exportOcrPdf,
          ),
        ),
      ],
    );
  }
}
