import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/smart_measure_item.dart';
import '../../models/measurement_types.dart';
import '../../services/smart_measure_storage_service.dart';

class MeasurementHistoryScreen extends StatefulWidget {
  const MeasurementHistoryScreen({super.key});

  @override
  State<MeasurementHistoryScreen> createState() => _MeasurementHistoryScreenState();
}

class _MeasurementHistoryScreenState extends State<MeasurementHistoryScreen> {
  final SmartMeasureStorageService _storage = SmartMeasureStorageService();
  String _searchQuery = '';
  SmartMeasureToolType? _selectedFilterType;

  @override
  void initState() {
    super.initState();
    _storage.init();
    _storage.addListener(_onStorageChange);
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _storage.removeListener(_onStorageChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onStorageChange() {
    if (mounted) setState(() {});
  }

  Future<void> _exportPdfReport(SmartMeasureItem item) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'ToolBox Pro - Smart Measure',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                      ),
                      pw.Text(
                        'OFFLINE AUDIT REPORT',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text('Measurement: ${item.name}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Tool: ${item.toolType.title}', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey800)),
                pw.Text('Date & Time: ${item.createdAt.toLocal().toString().split('.').first}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.blue300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('MEASURED VALUE', style: pw.TextStyle(fontSize: 10, color: PdfColors.blue900, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(item.formattedValue, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Audit & Calibration Metadata:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                pw.Bullet(text: 'Tracking Confidence: ${item.confidence.label}'),
                if (item.estimatedUncertaintyPercent != null)
                  pw.Bullet(text: 'Estimated Uncertainty: ±${item.estimatedUncertaintyPercent!.toStringAsFixed(1)}%'),
                pw.Bullet(text: 'Hardware Engine: ${item.capabilityUsed}'),
                pw.Bullet(text: 'Anchor Points Placed: ${item.points.length}'),
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Text('User Notes:', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text(item.notes!, style: const pw.TextStyle(fontSize: 12)),
                ],
                if (item.secondaryValues.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('Dimension Components:', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  ...item.secondaryValues.entries.map((e) => pw.Bullet(text: '${e.key}: ${e.value}')),
                ],
                pw.Spacer(),
                pw.Divider(),
                pw.Text('Generated offline with ToolBox Pro - Smart Measure Module.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Smart_Measure_${item.id.substring(0, 6)}.pdf',
    );
  }

  void _shareTextReport(SmartMeasureItem item) {
    final report = _storage.generateTextReport(item);
    SharePlus.instance.share(
      ShareParams(
        text: report,
        subject: 'Measurement: ${item.name}',
      ),
    );
  }

  void _showEditDialog(SmartMeasureItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final notesCtrl = TextEditingController(text: item.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Measurement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _storage.updateMeasurement(item.id, name: nameCtrl.text.trim(), notes: notesCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(SmartMeasureItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Measurement?'),
        content: Text('Are you sure you want to permanently delete "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              _storage.deleteMeasurement(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _storage.filter(query: _searchQuery, toolType: _selectedFilterType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurement History', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search measurements...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Tools'),
                  selected: _selectedFilterType == null,
                  onSelected: (_) => setState(() => _selectedFilterType = null),
                ),
                const SizedBox(width: 8),
                ...SmartMeasureToolType.values.take(14).map((type) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(type.title),
                      selected: _selectedFilterType == type,
                      onSelected: (sel) {
                        setState(() => _selectedFilterType = sel ? type : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // History List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? 'No matching measurements' : 'No measurements recorded yet',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Save measurements from AR or manual tools to view them here.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1.5,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: item.toolType.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(item.toolType.icon, color: item.toolType.color, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          '${item.toolType.title} • ${item.createdAt.toLocal().toString().split('.').first}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert_rounded),
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (_) => SafeArea(
                                          child: Wrap(
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                                                title: const Text('Export PDF Audit Report'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _exportPdfReport(item);
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.share_rounded),
                                                title: const Text('Share Summary Text'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _shareTextReport(item);
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.edit_rounded),
                                                title: const Text('Edit Name & Notes'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _showEditDialog(item);
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                                                title: const Text('Delete Measurement'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _confirmDelete(item);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Big Primary Value
                              Text(
                                item.formattedValue,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: item.toolType.color,
                                ),
                              ),
                              if (item.notes != null && item.notes!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  item.notes!,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                ),
                              ],
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              // Footer Audit Chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _AuditChip(label: item.confidence.label, color: const Color(0xFF10B981)),
                                  _AuditChip(label: item.capabilityUsed, color: Colors.blueGrey),
                                  if (item.estimatedUncertaintyPercent != null)
                                    _AuditChip(label: '±${item.estimatedUncertaintyPercent!.toStringAsFixed(1)}%', color: Colors.orange),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AuditChip extends StatelessWidget {
  final String label;
  final Color color;
  const _AuditChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
