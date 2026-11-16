import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../services/measurement_math_engine.dart';
import '../../models/measurement_types.dart';
import '../../models/measurement_units.dart';
import '../../models/smart_measure_capability.dart';
import '../widgets/measurement_summary_sheet.dart';

class DigitalLevelScreen extends StatefulWidget {
  const DigitalLevelScreen({super.key});

  @override
  State<DigitalLevelScreen> createState() => _DigitalLevelScreenState();
}

class _DigitalLevelScreenState extends State<DigitalLevelScreen> {
  StreamSubscription<AccelerometerEvent>? _accelSub;

  double _rollDeg = 0.0;
  double _pitchDeg = 0.0;
  double _totalTiltDeg = 0.0;
  bool _isLevel = false;

  // Zero-calibration offsets
  double _zeroRollOffset = 0.0;
  double _zeroPitchOffset = 0.0;

  bool _isLocked = false;
  bool _hasHapticFired = false;

  @override
  void initState() {
    super.initState();
    _startSensors();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _startSensors() {
    try {
      _accelSub = accelerometerEventStream().listen((event) {
        if (!mounted || _isLocked) return;

        final reading = MeasurementMathEngine.calculateLevel(event.x, event.y, event.z);

        final adjustedRoll = reading.rollDegrees - _zeroRollOffset;
        final adjustedPitch = reading.pitchDegrees - _zeroPitchOffset;
        final adjustedTilt = math.sqrt(adjustedRoll * adjustedRoll + adjustedPitch * adjustedPitch);
        final levelStatus = adjustedTilt.abs() <= 0.8;

        if (levelStatus && !_hasHapticFired) {
          HapticFeedback.mediumImpact();
          _hasHapticFired = true;
        } else if (!levelStatus) {
          _hasHapticFired = false;
        }

        setState(() {
          _rollDeg = adjustedRoll;
          _pitchDeg = adjustedPitch;
          _totalTiltDeg = adjustedTilt;
          _isLevel = levelStatus;
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  void _calibrateZero() {
    HapticFeedback.lightImpact();
    setState(() {
      _zeroRollOffset += _rollDeg;
      _zeroPitchOffset += _pitchDeg;
      _rollDeg = 0.0;
      _pitchDeg = 0.0;
      _totalTiltDeg = 0.0;
      _isLevel = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Level calibrated to current surface'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetCalibration() {
    HapticFeedback.lightImpact();
    setState(() {
      _zeroRollOffset = 0.0;
      _zeroPitchOffset = 0.0;
    });
  }

  void _toggleLock() {
    HapticFeedback.selectionClick();
    setState(() => _isLocked = !_isLocked);
  }

  void _saveLevelMeasurement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeasurementSummarySheet(
        toolType: SmartMeasureToolType.levelTool,
        primaryValue: _totalTiltDeg,
        distanceUnit: DistanceUnit.centimeter,
        angleUnit: AngleUnit.degree,
        formattedValue: '${_totalTiltDeg.toStringAsFixed(1)}° (${_isLevel ? "PERFECT LEVEL" : "TILTED"})',
        secondaryValues: {
          'Roll Angle': '${_rollDeg.toStringAsFixed(1)}°',
          'Pitch Angle': '${_pitchDeg.toStringAsFixed(1)}°',
          'Status': _isLevel ? 'Level Aligned (±0.8°)' : 'Out of Alignment',
          'Zero Calibrated': (_zeroRollOffset != 0 || _zeroPitchOffset != 0) ? 'Yes' : 'Factory Zero',
        },
        confidence: TrackingConfidence.high,
        uncertaintyPercent: 0.2,
        capabilityUsed: 'Hardware Accelerometer Sensor',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _isLevel ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Digital Precision Level', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isLocked ? Icons.lock_rounded : Icons.lock_open_rounded),
            color: _isLocked ? const Color(0xFFEF4444) : Colors.white70,
            tooltip: _isLocked ? 'Unlock Sensors' : 'Lock Reading',
            onPressed: _toggleLock,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_added_rounded),
            color: const Color(0xFF10B981),
            tooltip: 'Save Measurement',
            onPressed: _saveLevelMeasurement,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Angle Readout Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: activeColor.withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withOpacity(0.25),
                    blurRadius: 16,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isLevel ? 'PERFECT LEVEL' : 'TILT DEVIATION',
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_totalTiltDeg.toStringAsFixed(1)}°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Roll: ${_rollDeg.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(width: 16),
                      Text('Pitch: ${_pitchDeg.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 2D Bullseye Spirit Level
            Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: CustomPaint(
                  painter: _BullseyeLevelPainter(
                    rollDeg: _rollDeg,
                    pitchDeg: _pitchDeg,
                    isLevel: _isLevel,
                    activeColor: activeColor,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Horizontal & Vertical Level Bars
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  // Horizontal Tube Level
                  _TubeLevelBar(
                    label: 'HORIZONTAL (X)',
                    degrees: _rollDeg,
                    activeColor: activeColor,
                  ),
                  const SizedBox(height: 14),
                  // Vertical Tube Level
                  _TubeLevelBar(
                    label: 'VERTICAL (Y)',
                    degrees: _pitchDeg,
                    activeColor: activeColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Calibration Control Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _resetCalibration,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reset Zero'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _calibrateZero,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Calibrate Surface'),
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
}

class _BullseyeLevelPainter extends CustomPainter {
  final double rollDeg;
  final double pitchDeg;
  final bool isLevel;
  final Color activeColor;

  _BullseyeLevelPainter({
    required this.rollDeg,
    required this.pitchDeg,
    required this.isLevel,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer dark casing
    final casePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, casePaint);

    // Outer boundary ring
    final borderPaint = Paint()
      ..color = activeColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 2, borderPaint);

    // Concentric rings (10°, 5°, 2°, 1°)
    final ringPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius * 0.75, ringPaint);
    canvas.drawCircle(center, radius * 0.50, ringPaint);
    canvas.drawCircle(center, radius * 0.25, ringPaint);

    // Center target ring (Bullseye boundary)
    final targetPaint = Paint()
      ..color = activeColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, 22.0, targetPaint);

    // Crosshairs
    final crossPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - radius + 10, center.dy), Offset(center.dx + radius - 10, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius + 10), Offset(center.dx, center.dy + radius - 10), crossPaint);

    // Moving fluid bubble position
    // Max displacement radius = radius * 0.8
    final maxDisp = radius * 0.78;
    // 15 degrees tilt maps to full radius
    final dx = (rollDeg / 15.0).clamp(-1.0, 1.0) * maxDisp;
    final dy = (pitchDeg / 15.0).clamp(-1.0, 1.0) * maxDisp;

    final bubblePos = Offset(center.dx + dx, center.dy + dy);

    // Bubble glow
    final glowPaint = Paint()
      ..color = activeColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bubblePos, 20.0, glowPaint);

    // Bubble body
    final bubblePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bubblePos, 14.0, bubblePaint);

    // Bubble inner shine
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.75)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(bubblePos.dx - 3, bubblePos.dy - 3), 4.0, shinePaint);
  }

  @override
  bool shouldRepaint(covariant _BullseyeLevelPainter oldDelegate) {
    return oldDelegate.rollDeg != rollDeg ||
        oldDelegate.pitchDeg != pitchDeg ||
        oldDelegate.isLevel != isLevel;
  }
}

class _TubeLevelBar extends StatelessWidget {
  final String label;
  final double degrees;
  final Color activeColor;

  const _TubeLevelBar({
    required this.label,
    required this.degrees,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    // Clamped -1.0 to 1.0 position within tube
    final normPos = (degrees / 10.0).clamp(-1.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
            Text('${degrees.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final centerX = w / 2;
              final bubbleX = centerX + (normPos * (centerX - 16));

              return Stack(
                children: [
                  // Center zero target zone
                  Center(
                    child: Container(
                      width: 28,
                      height: 24,
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          vertical: BorderSide(color: activeColor.withOpacity(0.7), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  // Bubble
                  Positioned(
                    left: bubbleX - 10,
                    top: 3,
                    child: Container(
                      width: 20,
                      height: 16,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withOpacity(0.4),
                            blurRadius: 4,
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
