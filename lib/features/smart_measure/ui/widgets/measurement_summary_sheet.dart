import 'package:flutter/material.dart';
import '../../models/smart_measure_item.dart';
import '../../models/measurement_types.dart';
import '../../models/measurement_units.dart';
import '../../models/smart_measure_capability.dart';
import '../../models/smart_measure_point.dart';
import '../../services/smart_measure_storage_service.dart';

class MeasurementSummarySheet extends StatefulWidget {
  final SmartMeasureToolType toolType;
  final double primaryValue;
  final DistanceUnit distanceUnit;
  final AreaUnit? areaUnit;
  final AngleUnit? angleUnit;
  final String formattedValue;
  final Map<String, dynamic> secondaryValues;
  final TrackingConfidence confidence;
  final double? uncertaintyPercent;
  final String capabilityUsed;
  final List<SmartMeasurePoint> points;
  final String? screenshotPath;
  final Map<String, dynamic>? extraMetadata;

  const MeasurementSummarySheet({
    super.key,
    required this.toolType,
    required this.primaryValue,
    required this.distanceUnit,
    this.areaUnit,
    this.angleUnit,
    required this.formattedValue,
    this.secondaryValues = const {},
    required this.confidence,
    this.uncertaintyPercent,
    required this.capabilityUsed,
    this.points = const [],
    this.screenshotPath,
    this.extraMetadata,
  });

  @override
  State<MeasurementSummarySheet> createState() => _MeasurementSummarySheetState();
}

class _MeasurementSummarySheetState extends State<MeasurementSummarySheet> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final dateStr = DateTime.now().toString().split('.').first;
    _nameController = TextEditingController(
      text: '${widget.toolType.title} ($dateStr)',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : widget.toolType.title;

    setState(() => _isSaving = true);

    final item = SmartMeasureItem(
      id: UniqueKey().toString(),
      name: name,
      toolType: widget.toolType,
      createdAt: DateTime.now(),
      primaryValue: widget.primaryValue,
      distanceUnit: widget.distanceUnit,
      areaUnit: widget.areaUnit,
      angleUnit: widget.angleUnit,
      formattedValue: widget.formattedValue,
      secondaryValues: widget.secondaryValues,
      confidence: widget.confidence,
      estimatedUncertaintyPercent: widget.uncertaintyPercent,
      capabilityUsed: widget.capabilityUsed,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      screenshotPath: widget.screenshotPath,
      points: widget.points,
      extraMetadata: widget.extraMetadata,
    );

    await SmartMeasureStorageService().saveMeasurement(item);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Measurement "$name" saved to history'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.toolType.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.toolType.icon, color: widget.toolType.color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Save Measurement',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Measured Value Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.toolType.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.toolType.color.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MEASURED RESULT',
                    style: TextStyle(
                      color: widget.toolType.color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.formattedValue,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (widget.secondaryValues.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: widget.secondaryValues.entries.map((e) {
                        return Text(
                          '${e.key}: ${e.value}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Name field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Measurement Name',
                prefixIcon: const Icon(Icons.label_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Notes field
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes / Location (Optional)',
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Metadata summary chips
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Confidence', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          widget.confidence.label,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Engine', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          widget.capabilityUsed,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save to History',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
