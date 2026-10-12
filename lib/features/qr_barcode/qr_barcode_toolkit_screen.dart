import 'dart:convert';
import 'dart:ui' as ui;
import 'package:barcode_widget/barcode_widget.dart' as bc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide ContactInfo;
import 'package:pdf/pdf.dart' as pw_format;
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/share_utils.dart';
import '../../core/utils/vcard_utils.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum QrToolkitTab {
  scanner('Scan Camera / File', Icons.qr_code_scanner_rounded),
  generator('Create QR Code', Icons.qr_code_2_rounded),
  wifi('Wi-Fi QR', Icons.wifi_rounded),
  contact('Contact & Web', Icons.contact_page_rounded),
  barcode('Create Barcode', Icons.view_week_rounded),
  bulk('Bulk Generator', Icons.dynamic_feed_rounded),
  history('Scan History', Icons.history_rounded);

  final String label;
  final IconData icon;
  const QrToolkitTab(this.label, this.icon);
}

/// Escapes the characters that are special in the Wi-Fi QR format: \ ; , : "
String escapeWifiField(String value) => value.replaceAllMapped(RegExp(r'[\\;,:"]'), (m) => '\\${m[0]}');

/// Builds a `WIFI:` QR payload. The password is kept verbatim (spaces are
/// significant) and omitted for open networks.
String buildWifiQrPayload({
  required String ssid,
  required String password,
  required String security,
  bool hidden = false,
}) {
  final pass = security == 'nopass' ? '' : 'P:${escapeWifiField(password)};';
  return 'WIFI:T:$security;S:${escapeWifiField(ssid)};$pass${hidden ? 'H:true;' : ''};';
}

class QrBarcodeToolkitScreen extends StatefulWidget {
  const QrBarcodeToolkitScreen({super.key});

  @override
  State<QrBarcodeToolkitScreen> createState() => _QrBarcodeToolkitScreenState();
}

class _QrBarcodeToolkitScreenState extends State<QrBarcodeToolkitScreen> {
  QrToolkitTab _activeTab = QrToolkitTab.scanner;
  final MobileScannerController _scannerController = MobileScannerController();

  // Scanner state
  String _scannedResult = '';
  String _scannedFormat = '';

  // Standard QR Generator state
  final TextEditingController _qrTextController = TextEditingController(text: 'https://github.com');
  Color _qrColor = Colors.black;
  Color _qrBgColor = Colors.white;
  int _qrErrorLevel = QrErrorCorrectLevel.M;

  // Wi-Fi QR state
  final TextEditingController _wifiSsidController = TextEditingController(text: 'Home_WiFi');
  final TextEditingController _wifiPasswordController = TextEditingController(text: 'secretPassword123');
  String _wifiSecurity = 'WPA'; // 'WPA', 'WEP', 'nopass'
  bool _wifiHidden = false;

  // Contact / Web QR state
  String _contactType = 'URL'; // 'URL', 'vCard', 'Email', 'Phone', 'SMS', 'Location'
  final TextEditingController _cNameController = TextEditingController(text: 'John Doe');
  final TextEditingController _cPhoneController = TextEditingController(text: '+1234567890');
  final TextEditingController _cEmailController = TextEditingController(text: 'john@example.com');
  final TextEditingController _cOrgController = TextEditingController(text: 'Acme Corp');
  final TextEditingController _cUrlController = TextEditingController(text: 'https://example.com');
  final TextEditingController _cSubjectController = TextEditingController(text: 'Inquiry');
  final TextEditingController _cMessageController = TextEditingController(text: 'Hello, I would like to connect.');
  final TextEditingController _cLatController = TextEditingController(text: '37.7749');
  final TextEditingController _cLngController = TextEditingController(text: '-122.4194');

  // Barcode Generator state
  final TextEditingController _barcodeDataController = TextEditingController(text: '978020137962');
  String _barcodeType = 'EAN-13'; // Code 128, EAN-13, EAN-8, UPC-A, Code 39, ISBN, PDF417, Aztec
  final double _barcodeHeight = 80;

  // Bulk QR state
  final TextEditingController _bulkInputController = TextEditingController(
    text: 'https://google.com\nhttps://apple.com\nhttps://flutter.dev\nhttps://github.com',
  );
  bool _isExportingBulk = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _qrTextController.dispose();
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    _cNameController.dispose();
    _cPhoneController.dispose();
    _cEmailController.dispose();
    _cOrgController.dispose();
    _cUrlController.dispose();
    _cSubjectController.dispose();
    _cMessageController.dispose();
    _cLatController.dispose();
    _cLngController.dispose();
    _barcodeDataController.dispose();
    _bulkInputController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  void _onBarcodeScanned(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first;
      final value = barcode.rawValue ?? barcode.displayValue ?? '';
      if (value.isNotEmpty && value != _scannedResult) {
        PreferencesService().triggerHaptic();
        final format = barcode.format.name;
        setState(() {
          _scannedResult = value;
          _scannedFormat = format;
        });
        PreferencesService().addQrScanRecord(content: value, format: format);
      }
    }
  }

  Future<void> _pickImageToScan() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (file != null && file.path != null) {
        final capture = await _scannerController.analyzeImage(file.path!);
        if (!mounted) return;
        if (capture != null && capture.barcodes.isNotEmpty) {
          final bc = capture.barcodes.first;
          final value = bc.rawValue ?? bc.displayValue ?? '';
          if (value.isEmpty) {
            _showToast('The code was found but contains no readable text.');
            return;
          }
          final format = bc.format.name;
          setState(() {
            _scannedResult = value;
            _scannedFormat = format;
          });
          PreferencesService().addQrScanRecord(content: value, format: format);
        } else {
          _showToast('No QR code or Barcode found in the selected image.');
        }
      }
    } catch (e) {
      _showToast('Scanning image failed: $e');
    }
  }

  /// Renders [data] as a PNG with a solid background and a quiet-zone margin
  /// (the painter alone yields a transparent, margin-less image that many
  /// scanners reject).
  Future<Uint8List?> _renderQrPng(String data, {required Color fg, required Color bg, required int level}) async {
    const size = 600.0, margin = 48.0;
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: fg),
      dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: fg),
      errorCorrectionLevel: level,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const total = size + margin * 2;
    canvas.drawRect(const Rect.fromLTWH(0, 0, total, total), Paint()..color = bg);
    canvas.translate(margin, margin);
    painter.paint(canvas, const Size(size, size));
    final image = await recorder.endRecording().toImage(total.toInt(), total.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  /// [custom] uses the generator tab's colours and error-correction level;
  /// other tabs export plain black-on-white at level M.
  Future<void> _exportQrImage(String data, {String filename = 'QRCode.png', bool custom = false}) async {
    PreferencesService().triggerHaptic();
    try {
      final bytes = await _renderQrPng(
        data,
        fg: custom ? _qrColor : Colors.black,
        bg: custom ? _qrBgColor : Colors.white,
        level: custom ? _qrErrorLevel : QrErrorCorrectLevel.M,
      );
      if (bytes == null) {
        _showToast('Could not render the QR code.');
        return;
      }
      await shareFileBytes(bytes, filename);
    } catch (e) {
      _showToast('Error saving QR code: $e');
    }
  }

  String _buildWifiPayload() => buildWifiQrPayload(
        ssid: _wifiSsidController.text.trim(),
        password: _wifiPasswordController.text,
        security: _wifiSecurity,
        hidden: _wifiHidden,
      );

  String _buildContactPayload() {
    switch (_contactType) {
      case 'URL':
        return _cUrlController.text.trim();
      case 'vCard':
        return VCardUtils.generateVCard(ContactInfo(
          firstName: _cNameController.text.trim(),
          organization: _cOrgController.text.trim(),
          phoneMobile: _cPhoneController.text.trim(),
          email: _cEmailController.text.trim(),
          website: _cUrlController.text.trim(),
        ));
      case 'Email':
        return 'mailto:${_cEmailController.text.trim()}?subject=${Uri.encodeComponent(_cSubjectController.text.trim())}&body=${Uri.encodeComponent(_cMessageController.text.trim())}';
      case 'Phone':
        return 'tel:${_cPhoneController.text.trim()}';
      case 'SMS':
        return 'smsto:${_cPhoneController.text.trim()}:${_cMessageController.text.trim()}';
      case 'Location':
        return 'geo:${_cLatController.text.trim()},${_cLngController.text.trim()}';
      default:
        return _cUrlController.text.trim();
    }
  }

  static String _safeName(String raw, String fallback) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  bc.Barcode _getBarcodeType() {
    switch (_barcodeType) {
      case 'Code 128':
        return bc.Barcode.code128();
      case 'EAN-13':
        return bc.Barcode.ean13();
      case 'EAN-8':
        return bc.Barcode.ean8();
      case 'UPC-A':
        return bc.Barcode.upcA();
      case 'Code 39':
        return bc.Barcode.code39();
      case 'ISBN':
        return bc.Barcode.isbn();
      case 'PDF417':
        return bc.Barcode.pdf417();
      case 'Aztec':
        return bc.Barcode.aztec();
      default:
        return bc.Barcode.code128();
    }
  }

  Future<void> _exportBulkQrPdf() async {
    final lines = _bulkInputController.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      _showToast('Enter at least one item to generate.');
      return;
    }

    setState(() => _isExportingBulk = true);
    PreferencesService().triggerHaptic();

    try {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: pw_format.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return [
              pw.Header(level: 0, child: pw.Text('Bulk QR Codes Sheet', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 12),
              pw.GridView(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
                children: lines.map((item) {
                  return pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: pw_format.PdfColors.grey400, width: 0.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: item,
                          width: 100,
                          height: 100,
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          item,
                          maxLines: 2,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ];
          },
        ),
      );

      await shareFileBytes(await doc.save(), 'Bulk_QRCodes_Sheet.pdf');
    } catch (e) {
      _showToast('Error generating bulk PDF: $e');
    } finally {
      if (mounted) setState(() => _isExportingBulk = false);
    }
  }

  Future<void> _runScannerAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _showToast('Camera action unavailable: $e');
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

    return ToolScaffold(
      title: 'QR & Barcode Suite',
      category: ToolCategory.qrBarcode,
      toolId: 'qr_barcode_toolkit',
      onReset: () {
        setState(() {
          _scannedResult = '';
          _scannedFormat = '';
          _qrTextController.text = 'https://github.com';
          _qrColor = Colors.black;
          _qrBgColor = Colors.white;
          _qrErrorLevel = QrErrorCorrectLevel.M;
          _wifiSsidController.text = 'Home_WiFi';
          _wifiPasswordController.text = 'secretPassword123';
          _wifiSecurity = 'WPA';
          _wifiHidden = false;
          _contactType = 'URL';
          _cNameController.text = 'John Doe';
          _cPhoneController.text = '+1234567890';
          _cEmailController.text = 'john@example.com';
          _cOrgController.text = 'Acme Corp';
          _cUrlController.text = 'https://example.com';
          _cSubjectController.text = 'Inquiry';
          _cMessageController.text = 'Hello, I would like to connect.';
          _cLatController.text = '37.7749';
          _cLngController.text = '-122.4194';
          _barcodeDataController.text = '978020137962';
          _barcodeType = 'EAN-13';
          _bulkInputController.text = 'https://google.com\nhttps://apple.com\nhttps://flutter.dev\nhttps://github.com';
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-tabs
          FeatureTabSelector<QrToolkitTab>(
            tabs: QrToolkitTab.values
                .map((tab) => FeatureTabItem(value: tab, label: tab.label, icon: tab.icon))
                .toList(),
            activeTab: _activeTab,
            accentColor: AppColors.primaryOrange,
            title: 'QR & Barcode Tools',
            onTabSelected: (tab) => setState(() => _activeTab = tab),
          ),
          const SizedBox(height: 20),

          if (_activeTab == QrToolkitTab.scanner) _buildScannerTab(isDark),
          if (_activeTab == QrToolkitTab.generator) _buildGeneratorTab(isDark),
          if (_activeTab == QrToolkitTab.wifi) _buildWifiTab(isDark),
          if (_activeTab == QrToolkitTab.contact) _buildContactTab(isDark),
          if (_activeTab == QrToolkitTab.barcode) _buildBarcodeTab(isDark),
          if (_activeTab == QrToolkitTab.bulk) _buildBulkTab(isDark),
          if (_activeTab == QrToolkitTab.history) _buildHistoryTab(isDark),
        ],
      ),
    );
  }

  // ===================== TABS =====================

  Widget _buildScannerTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Live Scanner',
          primaryResult: _scannedResult.isNotEmpty ? _scannedResult : 'Point at QR / Barcode',
          subtitle: _scannedFormat.isNotEmpty ? 'Format: $_scannedFormat' : 'Supports QR, EAN-13, Code 128, UPC-A, Aztec & PDF417',
          accentColor: AppColors.primaryOrange,
        ),
        const SizedBox(height: 16),
        Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryOrange, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onBarcodeScanned,
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Row(
                  children: [
                    // Torch state comes from the controller: it resets when the
                    // camera stops or switches, so a local flag would drift.
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _scannerController,
                      builder: (context, state, _) => IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        icon: Icon(state.torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
                        onPressed: () => _runScannerAction(_scannerController.toggleTorch),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                      onPressed: () => _runScannerAction(_scannerController.switchCamera),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.image_search_rounded),
          label: const Text('Scan QR / Barcode from Image File'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickImageToScan,
        ),
        if (_scannedResult.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy Text'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _scannedResult));
                    _showToast('Copied to clipboard!');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share Result'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    try {
                      await shareFileBytes(Uint8List.fromList(utf8.encode(_scannedResult)), 'Scanned_Code.txt');
                    } catch (e) {
                      _showToast('Could not share: $e');
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildGeneratorTab(bool isDark) {
    final text = _qrTextController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _qrBgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: QrImageView(
              data: text.isEmpty ? ' ' : text,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: _qrBgColor,
              eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: _qrColor),
              dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _qrColor),
              errorCorrectionLevel: _qrErrorLevel,
              errorStateBuilder: (context, _) => const SizedBox(
                width: 200,
                height: 200,
                child: Center(child: Text('Text is too long for this error-correction level.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black87))),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ModernTextField(
          label: 'QR Code Text / URL',
          controller: _qrTextController,
          hintText: 'e.g. https://mywebsite.com',
          prefixIcon: Icons.link_rounded,
          onChanged: (val) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _colorRow('QR Color', const [Colors.black, Color(0xFFFF6D00), Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFE11D48)], _qrColor, (c) => setState(() => _qrColor = c)),
        const SizedBox(height: 12),
        _colorRow('Background', const [Colors.white, Color(0xFFFFF7ED), Color(0xFFE0F2FE), Color(0xFFECFDF5), Color(0xFFFEF9C3)], _qrBgColor, (c) => setState(() => _qrBgColor = c)),
        const SizedBox(height: 16),
        const Text('Error Correction', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: QrErrorCorrectLevel.L, label: Text('L 7%')),
              ButtonSegment(value: QrErrorCorrectLevel.M, label: Text('M 15%')),
              ButtonSegment(value: QrErrorCorrectLevel.Q, label: Text('Q 25%')),
              ButtonSegment(value: QrErrorCorrectLevel.H, label: Text('H 30%')),
            ],
            selected: {_qrErrorLevel},
            onSelectionChanged: (v) => setState(() => _qrErrorLevel = v.first),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded),
            label: const Text('Save & Share QR Code (PNG)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _exportQrImage(text.isEmpty ? 'https://github.com' : text, custom: true),
          ),
        ),
      ],
    );
  }

  Widget _colorRow(String label, List<Color> options, Color selected, ValueChanged<Color> onSelect) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
        for (final color in options)
          Semantics(
            button: true,
            selected: color == selected,
            label: '$label option',
            child: GestureDetector(
              onTap: () => onSelect(color),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: color == selected ? AppColors.primaryOrange : Colors.grey.shade400, width: color == selected ? 3 : 1),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWifiTab(bool isDark) {
    final payload = _buildWifiPayload();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: payload,
              version: QrVersions.auto,
              size: 180.0,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ModernTextField(
          label: 'Wi-Fi Network Name (SSID)',
          controller: _wifiSsidController,
          hintText: 'Home_WiFi',
          prefixIcon: Icons.wifi_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'Wi-Fi Password',
          controller: _wifiPasswordController,
          hintText: 'Password',
          prefixIcon: Icons.lock_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Security Type',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          key: ValueKey('wifi-sec-$_wifiSecurity'),
          initialValue: _wifiSecurity,
          items: const [
            DropdownMenuItem(value: 'WPA', child: Text('WPA / WPA2 / WPA3 (Standard)')),
            DropdownMenuItem(value: 'WEP', child: Text('WEP')),
            DropdownMenuItem(value: 'nopass', child: Text('No Password (Open)')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _wifiSecurity = val);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hidden Network', style: TextStyle(fontWeight: FontWeight.w600)),
          value: _wifiHidden,
          activeThumbColor: AppColors.primaryOrange,
          onChanged: (val) => setState(() => _wifiHidden = val),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Wi-Fi QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _exportQrImage(payload, filename: 'WiFi_${_safeName(_wifiSsidController.text, 'Network')}.png'),
          ),
        ),
      ],
    );
  }

  Widget _buildContactTab(bool isDark) {
    final payload = _buildContactPayload();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(data: payload.isEmpty ? ' ' : payload, size: 170.0, backgroundColor: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'QR Payload Type',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          key: ValueKey('contact-type-$_contactType'),
          initialValue: _contactType,
          items: ['URL', 'vCard', 'Email', 'Phone', 'SMS', 'Location']
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _contactType = val);
          },
        ),
        const SizedBox(height: 16),
        if (_contactType == 'URL')
          ModernTextField(label: 'Website URL', controller: _cUrlController, keyboardType: TextInputType.url, prefixIcon: Icons.language_rounded, onChanged: (_) => setState(() {})),
        if (_contactType == 'vCard') ...[
          ModernTextField(label: 'Full Name', controller: _cNameController, keyboardType: TextInputType.name, prefixIcon: Icons.person_rounded, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          ModernTextField(label: 'Phone Number', controller: _cPhoneController, keyboardType: TextInputType.phone, prefixIcon: Icons.phone_rounded, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          ModernTextField(label: 'Email', controller: _cEmailController, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email_rounded, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          ModernTextField(label: 'Company / Org', controller: _cOrgController, prefixIcon: Icons.business_rounded, onChanged: (_) => setState(() {})),
        ],
        if (_contactType == 'Email') ...[
          ModernTextField(label: 'Recipient Email', controller: _cEmailController, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email_rounded, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          ModernTextField(label: 'Subject', controller: _cSubjectController, prefixIcon: Icons.subject_rounded, onChanged: (_) => setState(() {})),
        ],
        if (_contactType == 'Phone' || _contactType == 'SMS')
          ModernTextField(label: 'Phone Number', controller: _cPhoneController, keyboardType: TextInputType.phone, prefixIcon: Icons.phone_rounded, onChanged: (_) => setState(() {})),
        // The message is part of the Email and SMS payloads, so it must be editable there.
        if (_contactType == 'Email' || _contactType == 'SMS') ...[
          const SizedBox(height: 12),
          ModernTextField(label: 'Message', controller: _cMessageController, prefixIcon: Icons.message_rounded, maxLines: 3, onChanged: (_) => setState(() {})),
        ],
        if (_contactType == 'Location') ...[
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'Latitude', controller: _cLatController, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 12),
              Expanded(child: ModernTextField(label: 'Longitude', controller: _cLngController, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
            ],
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: Text('Export $_contactType QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _exportQrImage(payload, filename: 'Contact_${_contactType}_QR.png'),
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeTab(bool isDark) {
    final data = _barcodeDataController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: bc.BarcodeWidget(
              barcode: _getBarcodeType(),
              data: data.isEmpty ? '12345678' : data,
              width: 240,
              height: _barcodeHeight,
              drawText: true,
            ),
          ),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Barcode Standard',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          key: ValueKey('barcode-type-$_barcodeType'),
          initialValue: _barcodeType,
          items: ['EAN-13', 'Code 128', 'Code 39', 'EAN-8', 'UPC-A', 'ISBN', 'PDF417', 'Aztec']
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _barcodeType = val);
          },
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'Barcode Data',
          controller: _barcodeDataController,
          hintText: 'e.g. 978020137962',
          prefixIcon: Icons.view_week_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Export Barcode Image / PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              // Export the selected symbology, not just EAN-13/Code 128, and
              // reject invalid data (bad EAN checksum, letters, ...) up front.
              final barcode = _getBarcodeType();
              if (data.isEmpty || !barcode.isValid(data)) {
                _showToast('Invalid data for $_barcodeType barcode.');
                return;
              }
              try {
                final doc = pw.Document();
                doc.addPage(
                  pw.Page(
                    build: (c) => pw.Center(
                      child: pw.BarcodeWidget(
                        barcode: barcode,
                        data: data,
                        width: 200,
                        height: 80,
                      ),
                    ),
                  ),
                );
                final bytes = await doc.save();
                await shareFileBytes(bytes, 'Barcode_${_safeName(data, 'Code')}.pdf');
              } catch (e) {
                _showToast('Error exporting barcode: $e');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBulkTab(bool isDark) {
    final lines = _bulkInputController.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Bulk QR Generator',
          primaryResult: '${lines.length} Items Listed',
          subtitle: 'Generates a clean multi-page printable PDF catalog of QR codes',
          accentColor: AppColors.primaryOrange,
        ),
        const SizedBox(height: 20),
        ModernTextField(
          label: 'One URL or Text item per line',
          controller: _bulkInputController,
          hintText: 'https://site1.com\nhttps://site2.com\nhttps://site3.com',
          maxLines: 7,
          keyboardType: TextInputType.multiline,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _isExportingBulk
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(_isExportingBulk ? 'Generating Sheet...' : 'Export Printable Multi-QR PDF Sheet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isExportingBulk ? null : _exportBulkQrPdf,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    final history = PreferencesService().qrScanHistory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Scan Log',
          primaryResult: '${history.length} Scanned Items',
          subtitle: 'Tap any item to copy or share',
          accentColor: AppColors.primaryOrange,
        ),
        const SizedBox(height: 16),
        if (history.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 18),
              label: const Text('Clear Scan History', style: TextStyle(color: AppColors.error)),
              onPressed: () {
                PreferencesService().clearQrHistory();
                setState(() {});
              },
            ),
          ),
        if (history.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Text('No QR scans recorded yet.', style: TextStyle(color: AppColors.darkTextMuted)),
            ),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final item = history[idx];
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              leading: const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryOrange),
              title: Text(item.content, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${item.format} • ${item.timestamp.toLocal().toString().substring(0, 16)}', style: const TextStyle(fontSize: 11)),
              trailing: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: item.content));
                  _showToast('Copied to clipboard!');
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
