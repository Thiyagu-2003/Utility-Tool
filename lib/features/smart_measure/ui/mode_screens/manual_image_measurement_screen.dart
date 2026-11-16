import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/measurement_types.dart';
import '../../models/measurement_units.dart';
import '../../models/smart_measure_point.dart';
import '../../models/smart_measure_capability.dart';
import '../../services/manual_calibration_engine.dart';
import '../widgets/measurement_summary_sheet.dart';

class ManualImageMeasurementScreen extends StatefulWidget {
  final String? initialImagePath;

  const ManualImageMeasurementScreen({super.key, this.initialImagePath});

  @override
  State<ManualImageMeasurementScreen> createState() => _ManualImageMeasurementScreenState();
}

enum ManualMeasureStep {
  chooseImage,
  calibrateReference,
  measureObjects,
}

class _ManualImageMeasurementScreenState extends State<ManualImageMeasurementScreen> {
  String? _imagePath;
  ManualMeasureStep _step = ManualMeasureStep.chooseImage;

  // Calibration state
  ReferenceItemType _selectedRefType = ReferenceItemType.creditCard;
  double _customRefMm = 85.6;
  Offset? _calibStart;
  Offset? _calibEnd;
  ImageCalibration? _calibration;

  // Measurements lines
  final List<List<Offset>> _measuredLines = [];
  Offset? _currentLineStart;
  Offset? _currentLineEnd;

  DistanceUnit _unit = DistanceUnit.centimeter;
  final TextEditingController _customMmController = TextEditingController(text: '85.6');

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _imagePath = widget.initialImagePath;
      _step = ManualMeasureStep.calibrateReference;
    }
  }

  @override
  void dispose() {
    _customMmController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file != null && file.path != null) {
        setState(() {
          _imagePath = file.path;
          _step = ManualMeasureStep.calibrateReference;
          _calibStart = null;
          _calibEnd = null;
          _calibration = null;
          _measuredLines.clear();
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _finishCalibration() {
    if (_calibStart == null || _calibEnd == null) return;

    final realMm = _selectedRefType == ReferenceItemType.custom
        ? (double.tryParse(_customMmController.text) ?? 100.0)
        : _selectedRefType.defaultLengthMm;

    final calib = ImageCalibration.fromPoints(
      referenceType: _selectedRefType,
      referenceRealMm: realMm,
      start: _calibStart!,
      end: _calibEnd!,
    );

    setState(() {
      _calibration = calib;
      _step = ManualMeasureStep.measureObjects;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Calibration successful: ${(calib.mmPerPixel * 10).toStringAsFixed(2)} mm per 10 pixels',
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetCalibration() {
    setState(() {
      _calibStart = null;
      _calibEnd = null;
      _calibration = null;
      _measuredLines.clear();
      _step = ManualMeasureStep.calibrateReference;
    });
  }

  void _saveMeasurement() {
    if (_calibration == null || _measuredLines.isEmpty) return;

    // Calculate total primary length of measured lines
    double totalMm = 0.0;
    for (final line in _measuredLines) {
      if (line.length == 2) {
        totalMm += _calibration!.measureDistanceMm(line[0], line[1]);
      }
    }
    final totalMeters = totalMm / 1000.0;

    final secondary = {
      'Reference Standard': _selectedRefType.title,
      'Scale Ratio': '${_calibration!.mmPerPixel.toStringAsFixed(3)} mm/pixel',
      'Lines Measured': '${_measuredLines.length}',
      'Method': '2D Optical Scale Calibration',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeasurementSummarySheet(
        toolType: SmartMeasureToolType.manualImage,
        primaryValue: totalMeters,
        distanceUnit: _unit,
        formattedValue: _unit.formatMeters(totalMeters),
        secondaryValues: secondary,
        confidence: TrackingConfidence.medium,
        uncertaintyPercent: 2.5,
        capabilityUsed: 'Calibrated Scale Reference Engine',
        screenshotPath: _imagePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Manual Image Measurement', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          if (_imagePath != null) ...[
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_rounded),
              tooltip: 'Change Image',
              onPressed: _pickImage,
            ),
            if (_step == ManualMeasureStep.measureObjects && _measuredLines.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                tooltip: 'Save Measurement',
                onPressed: _saveMeasurement,
              ),
          ],
        ],
      ),
      body: _imagePath == null ? _buildEmptyState(theme) : _buildImageCanvas(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_size_select_actual_rounded, size: 56, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 20),
            Text(
              'Select an Image with a Known Reference',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Place a Credit Card, A4 paper, Coin, or standard ruler next to the object you want to measure, capture a photo, and calibrate the scale.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _pickImage,
              icon: const Icon(Icons.file_upload_rounded),
              label: const Text('Select Image from Device', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            // Perspective disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ImageCalibration.perspectiveDisclaimer,
                      style: TextStyle(color: Colors.amber.shade900, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCanvas(ThemeData theme) {
    return Column(
      children: [
        // Top Step Status Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: _step == ManualMeasureStep.calibrateReference
              ? const Color(0xFF3B82F6).withOpacity(0.12)
              : const Color(0xFF10B981).withOpacity(0.12),
          child: Row(
            children: [
              Icon(
                _step == ManualMeasureStep.calibrateReference
                    ? Icons.straighten_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
                color: _step == ManualMeasureStep.calibrateReference
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _step == ManualMeasureStep.calibrateReference
                      ? 'Calibrate Scale: Tap start and end of reference (${_selectedRefType.title})'
                      : 'Scale Active: Tap to mark start and end of dimensions to measure',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _step == ManualMeasureStep.calibrateReference
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF10B981),
                  ),
                ),
              ),
              if (_step == ManualMeasureStep.measureObjects)
                TextButton(
                  onPressed: _resetCalibration,
                  child: const Text('Recalibrate', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),

        // Interactive Image Canvas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) {
                  final tapPos = details.localPosition;
                  if (_step == ManualMeasureStep.calibrateReference) {
                    setState(() {
                      if (_calibStart == null) {
                        _calibStart = tapPos;
                      } else if (_calibEnd == null) {
                        _calibEnd = tapPos;
                      } else {
                        _calibStart = tapPos;
                        _calibEnd = null;
                      }
                    });
                  } else if (_step == ManualMeasureStep.measureObjects) {
                    setState(() {
                      if (_currentLineStart == null) {
                        _currentLineStart = tapPos;
                      } else {
                        _currentLineEnd = tapPos;
                        _measuredLines.add([_currentLineStart!, _currentLineEnd!]);
                        _currentLineStart = null;
                        _currentLineEnd = null;
                      }
                    });
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(_imagePath!),
                      fit: BoxFit.contain,
                    ),
                    CustomPaint(
                      painter: _ManualImagePainter(
                        step: _step,
                        calibStart: _calibStart,
                        calibEnd: _calibEnd,
                        calibration: _calibration,
                        measuredLines: _measuredLines,
                        currentLineStart: _currentLineStart,
                        unit: _unit,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Controls Toolbar
        _buildBottomBar(theme),
      ],
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    if (_step == ManualMeasureStep.calibrateReference) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ReferenceItemType>(
                      value: _selectedRefType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Reference Object',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: ReferenceItemType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text('${type.title} (${type.defaultLengthMm.toStringAsFixed(1)} mm)', style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRefType = val);
                      },
                    ),
                  ),
                  if (_selectedRefType == ReferenceItemType.custom) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _customMmController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'mm',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: (_calibStart != null && _calibEnd != null) ? _finishCalibration : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Lock Reference & Start Measuring', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.undo_rounded),
                onPressed: _measuredLines.isNotEmpty
                    ? () => setState(() => _measuredLines.removeLast())
                    : null,
                tooltip: 'Undo Line',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _measuredLines.isNotEmpty
                    ? () => setState(() => _measuredLines.clear())
                    : null,
                tooltip: 'Clear Lines',
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _measuredLines.isNotEmpty ? _saveMeasurement : null,
                icon: const Icon(Icons.save_rounded),
                label: Text('Save Result (${_measuredLines.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
  }
}

class _ManualImagePainter extends CustomPainter {
  final ManualMeasureStep step;
  final Offset? calibStart;
  final Offset? calibEnd;
  final ImageCalibration? calibration;
  final List<List<Offset>> measuredLines;
  final Offset? currentLineStart;
  final DistanceUnit unit;

  _ManualImagePainter({
    required this.step,
    this.calibStart,
    this.calibEnd,
    this.calibration,
    required this.measuredLines,
    this.currentLineStart,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Calibration reference markers
    if (calibStart != null) {
      final pointPaint = Paint()..color = const Color(0xFFF59E0B)..style = PaintingStyle.fill;
      canvas.drawCircle(calibStart!, 6, pointPaint);
      if (calibEnd != null) {
        canvas.drawCircle(calibEnd!, 6, pointPaint);
        final linePaint = Paint()
          ..color = const Color(0xFFF59E0B)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(calibStart!, calibEnd!, linePaint);

        // Reference label
        _drawPill(canvas, Offset((calibStart!.dx + calibEnd!.dx) / 2, (calibStart!.dy + calibEnd!.dy) / 2), 'REF SCALE', const Color(0xFFF59E0B));
      }
    }

    // 2. Draw user measured lines
    for (int i = 0; i < measuredLines.length; i++) {
      final line = measuredLines[i];
      if (line.length == 2) {
        final linePaint = Paint()
          ..color = const Color(0xFF2563EB)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(line[0], line[1], linePaint);

        final pPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
        canvas.drawCircle(line[0], 5, pPaint);
        canvas.drawCircle(line[1], 5, pPaint);

        if (calibration != null) {
          final mm = calibration!.measureDistanceMm(line[0], line[1]);
          final meters = mm / 1000.0;
          final mid = Offset((line[0].dx + line[1].dx) / 2, (line[0].dy + line[1].dy) / 2);
          _drawPill(canvas, mid, unit.formatMeters(meters), const Color(0xFF2563EB));
        }
      }
    }

    // 3. Current active line start point
    if (currentLineStart != null) {
      final activePaint = Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.fill;
      canvas.drawCircle(currentLineStart!, 6, activePaint);
    }
  }

  void _drawPill(Canvas canvas, Offset center, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: tp.width + 14, height: tp.height + 6),
      const Radius.circular(8),
    );

    canvas.drawRRect(pillRect, Paint()..color = Colors.black87);
    canvas.drawRRect(pillRect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ManualImagePainter oldDelegate) => true;
}
