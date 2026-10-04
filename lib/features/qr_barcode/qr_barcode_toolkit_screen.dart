import 'dart:convert';
import 'dart:typed_data';
import 'package:barcode_widget/barcode_widget.dart' as bc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart' as pw_format;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
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
  bool _isTorchOn = false;

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
  double _barcodeHeight = 80;

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
        if (capture != null && capture.barcodes.isNotEmpty) {
          final bc = capture.barcodes.first;
          final value = bc.rawValue ?? bc.displayValue ?? '';
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

  Future<void> _exportQrImage(String data, {String filename = 'QRCode.png'}) async {
    PreferencesService().triggerHaptic();
    try {
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: _qrColor),
        dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _qrColor),
        errorCorrectionLevel: _qrErrorLevel,
      );

      final picData = await painter.toImageData(600);
      if (picData != null) {
        final bytes = picData.buffer.asUint8List();
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (e) {
      _showToast('Error saving QR code: $e');
    }
  }

  String _buildWifiPayload() {
    final ssid = _wifiSsidController.text.trim();
    final pass = _wifiPasswordController.text.trim();
    final type = _wifiSecurity;
    final hidden = _wifiHidden ? 'true' : 'false';
    return 'WIFI:T:$type;S:$ssid;P:$pass;H:$hidden;;';
  }

  String _buildContactPayload() {
    switch (_contactType) {
      case 'URL':
        return _cUrlController.text.trim();
      case 'vCard':
        return 'BEGIN:VCARD\nVERSION:3.0\nN:${_cNameController.text.trim()}\nFN:${_cNameController.text.trim()}\nORG:${_cOrgController.text.trim()}\nTEL:${_cPhoneController.text.trim()}\nEMAIL:${_cEmailController.text.trim()}\nURL:${_cUrlController.text.trim()}\nEND:VCARD';
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

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'Bulk_QRCodes_Sheet.pdf',
      );
    } catch (e) {
      _showToast('Error generating bulk PDF: $e');
    } finally {
      if (mounted) setState(() => _isExportingBulk = false);
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
      category: ToolCategory.developer,
      toolId: 'qr_barcode_toolkit',
      onReset: () {
        setState(() {
          _scannedResult = '';
          _scannedFormat = '';
          _qrTextController.text = 'https://github.com';
          _wifiSsidController.text = 'Home_WiFi';
          _wifiPasswordController.text = 'secretPassword123';
          _bulkInputController.text = 'https://google.com\nhttps://apple.com\nhttps://flutter.dev\nhttps://github.com';
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: QrToolkitTab.values.map((tab) {
                final isSelected = tab == _activeTab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    avatar: Icon(tab.icon, size: 16, color: isSelected ? Colors.white : AppColors.primaryOrange),
                    label: Text(tab.label),
                    selected: isSelected,
                    selectedColor: AppColors.primaryOrange,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      icon: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
                      onPressed: () {
                        _scannerController.toggleTorch();
                        setState(() => _isTorchOn = !_isTorchOn);
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                      onPressed: () => _scannerController.switchCamera(),
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
                  onPressed: () => Printing.sharePdf(
                    bytes: Uint8List.fromList(utf8.encode(_scannedResult)),
                    filename: 'Scanned_Code.txt',
                  ),
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
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Text('QR Color:', style: TextStyle(fontWeight: FontWeight.bold)),
            _colorCircle(Colors.black, (c) => setState(() => _qrColor = c), _qrColor == Colors.black),
            _colorCircle(const Color(0xFFFF6D00), (c) => setState(() => _qrColor = c), _qrColor == const Color(0xFFFF6D00)),
            _colorCircle(const Color(0xFF3B82F6), (c) => setState(() => _qrColor = c), _qrColor == const Color(0xFF3B82F6)),
            _colorCircle(const Color(0xFF10B981), (c) => setState(() => _qrColor = c), _qrColor == const Color(0xFF10B981)),
            _colorCircle(const Color(0xFFE11D48), (c) => setState(() => _qrColor = c), _qrColor == const Color(0xFFE11D48)),
          ],
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
            onPressed: () => _exportQrImage(text.isEmpty ? 'https://github.com' : text),
          ),
        ),
      ],
    );
  }

  Widget _colorCircle(Color color, Function(Color) onSelect, bool isSelected) {
    return GestureDetector(
      onTap: () => onSelect(color),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
          boxShadow: isSelected ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
        ),
      ),
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
          value: _wifiSecurity,
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
          activeColor: AppColors.primaryOrange,
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
            onPressed: () => _exportQrImage(payload, filename: 'WiFi_${_wifiSsidController.text}.png'),
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
          value: _contactType,
          items: ['URL', 'vCard', 'Email', 'Phone', 'SMS', 'Location']
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _contactType = val);
          },
        ),
        const SizedBox(height: 16),
        if (_contactType == 'URL')
          ModernTextField(label: 'Website URL', controller: _cUrlController, prefixIcon: Icons.language_rounded, onChanged: (_) => setState(() {})),
        if (_contactType == 'vCard') ...[
          ModernTextField(label: 'Full Name', controller: _cNameController, prefixIcon: Icons.person_rounded, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          ModernTextField(label: 'Phone Number', controller: _cPhoneController, prefixIcon: Icons.phone_rounded, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          ModernTextField(label: 'Email', controller: _cEmailController, prefixIcon: Icons.email_rounded, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          ModernTextField(label: 'Company / Org', controller: _cOrgController, prefixIcon: Icons.business_rounded, onChanged: (_) => setState(() {})),
        ],
        if (_contactType == 'Email') ...[
          ModernTextField(label: 'Recipient Email', controller: _cEmailController, prefixIcon: Icons.email_rounded, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          ModernTextField(label: 'Subject', controller: _cSubjectController, prefixIcon: Icons.subject_rounded, onChanged: (_) => setState(() {})),
        ],
        if (_contactType == 'Phone' || _contactType == 'SMS')
          ModernTextField(label: 'Phone Number', controller: _cPhoneController, prefixIcon: Icons.phone_rounded, onChanged: (_) => setState(() {})),
        if (_contactType == 'Location') ...[
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'Latitude', controller: _cLatController, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 12),
              Expanded(child: ModernTextField(label: 'Longitude', controller: _cLngController, onChanged: (_) => setState(() {}))),
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
          value: _barcodeType,
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
              // Share as printable PDF/image
              final doc = pw.Document();
              doc.addPage(
                pw.Page(
                  build: (c) => pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: _barcodeType == 'EAN-13' ? pw.Barcode.ean13() : pw.Barcode.code128(),
                      data: data,
                      width: 200,
                      height: 80,
                    ),
                  ),
                ),
              );
              final bytes = await doc.save();
              await Printing.sharePdf(bytes: bytes, filename: 'Barcode_$data.pdf');
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
          separatorBuilder: (_, __) => const SizedBox(height: 8),
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
