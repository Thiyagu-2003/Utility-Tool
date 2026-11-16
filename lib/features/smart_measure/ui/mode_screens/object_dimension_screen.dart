import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../models/smart_measure_capability.dart';
import '../../models/measurement_types.dart';
import '../../models/measurement_units.dart';
import '../../models/smart_measure_point.dart';
import '../../models/object_dimension_model.dart';
import '../../services/ar_platform_bridge.dart';
import '../../services/measurement_math_engine.dart';
import '../widgets/ar_reticle.dart';
import '../widgets/guidance_toast.dart';
import '../widgets/measurement_summary_sheet.dart';
import '../painters/measurement_overlay_painter.dart';

class ObjectDimensionScreen extends StatefulWidget {
  const ObjectDimensionScreen({super.key});

  @override
  State<ObjectDimensionScreen> createState() => _ObjectDimensionScreenState();
}

class _ObjectDimensionScreenState extends State<ObjectDimensionScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  SmartMeasureCapability? _capability;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _pitchDeg = 45.0;
  double _rollDeg = 0.0;

  final List<SmartMeasurePoint> _corners = [];
  SmartMeasurePoint? _liveTarget;
  double? _liveDist;
  Timer? _raycastTimer;

  final DistanceUnit _unit = DistanceUnit.centimeter;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _raycastTimer?.cancel();
    _accelSub?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final cap = await ARPlatformBridge().checkCapabilities();
    if (!mounted) return;
    setState(() => _capability = cap);

    try {
      _accelSub = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        final r = MeasurementMathEngine.calculateLevel(event.x, event.y, event.z);
        _pitchDeg = r.pitchDegrees.abs();
        _rollDeg = r.rollDegrees;
      });
    } catch (_) {}

    try {
      final cams = await availableCameras();
      if (cams.isNotEmpty) {
        final backCam = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cams.first,
        );
        final ctrl = CameraController(backCam, ResolutionPreset.high, enableAudio: false);
        await ctrl.initialize();
        if (!mounted) {
          ctrl.dispose();
          return;
        }
        _cameraController = ctrl;
        ARPlatformBridge().setActiveCameraController(ctrl);
        setState(() => _isCameraReady = true);

        _raycastTimer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
          if (!mounted || _cameraController == null) return;
          final target = await ARPlatformBridge().raycastHitTest(
            normalizedScreenPos: const Offset(0.5, 0.5),
            cameraPitchDegrees: _pitchDeg,
            cameraRollDegrees: _rollDeg,
            estimatedDeviceHeightMeters: 1.35,
            currentFocalScale: 1.0,
          );
          if (!mounted) return;
          setState(() {
            _liveTarget = target;
            if (_corners.isNotEmpty) {
              _liveDist = MeasurementMathEngine.distance3D(_corners.last, target);
            } else {
              _liveDist = target.depthMeters;
            }
          });
        });
      }
    } catch (_) {}
  }

  String get _instruction {
    switch (_corners.length) {
      case 0:
        return 'Step 1: Aim at Corner #1 of object base and tap "Set Point"';
      case 1:
        return 'Step 2: Aim at Corner #2 (Length axis) and tap "Set Point"';
      case 2:
        return 'Step 3: Aim at Corner #3 (Width axis) and tap "Set Point"';
      case 3:
        return 'Step 4: Aim at Top Corner #4 (Height axis) and tap "Set Point"';
      default:
        return '3D Bounding Box Complete! Tap "Save Result" to store';
    }
  }

  void _addCorner() {
    if (_liveTarget == null || _corners.length >= 4) return;
    setState(() {
      _corners.add(_liveTarget!);
    });
  }

  void _reset() {
    setState(() {
      _corners.clear();
    });
  }

  void _save() {
    if (_corners.length < 2) return;
    final box = MeasurementMathEngine.calculateObjectBox(_corners);

    final audit = MeasurementMathEngine.evaluateConfidence(
      trackingState: TrackingConfidence.high,
      engine: _capability?.preferredEngine ?? MeasurementTrackingEngine.androidArCore,
      measurementDistanceMeters: box.spatialDiagonalMeters,
      sensorDepthMeters: _corners.first.depthMeters,
    );

    final secondary = {
      'Length': _unit.formatMeters(box.lengthMeters),
      'Width': _unit.formatMeters(box.widthMeters),
      'Height': _unit.formatMeters(box.heightMeters),
      'Volume': '${(box.volumeCubicMeters * 1000).toStringAsFixed(1)} Liters (${box.volumeCubicMeters.toStringAsFixed(3)} m³)',
      'Surface Area': '${box.surfaceAreaSqMeters.toStringAsFixed(2)} m²',
      '3D Diagonal': _unit.formatMeters(box.spatialDiagonalMeters),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeasurementSummarySheet(
        toolType: SmartMeasureToolType.objectDimension,
        primaryValue: box.volumeCubicMeters,
        distanceUnit: _unit,
        formattedValue: '${_unit.formatMeters(box.lengthMeters)} × ${_unit.formatMeters(box.widthMeters)} × ${_unit.formatMeters(box.heightMeters)}',
        secondaryValues: secondary,
        confidence: TrackingConfidence.high,
        uncertaintyPercent: audit.uncertaintyPercent,
        capabilityUsed: _capability?.preferredEngine.title ?? '3D AR Bounding Engine',
        points: List.from(_corners),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = MeasurementMathEngine.calculateObjectBox(_corners);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isCameraReady && _cameraController != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899))),

          // AR Overlay lines
          Positioned.fill(
            child: CustomPaint(
              painter: MeasurementOverlayPainter(
                points: _corners,
                activeTargetPos: const Offset(0.5, 0.5),
                activeTargetPoint: _liveTarget,
                unit: _unit,
                isClosedPolygon: _corners.length >= 3,
                primaryColor: const Color(0xFFEC4899),
              ),
            ),
          ),

          // Reticle
          IgnorePointer(
            child: ARReticle(
              isLockedOnSurface: true,
              liveDistanceMeters: _liveDist,
              distanceDisplay: _liveDist != null ? _unit.formatMeters(_liveDist!) : null,
            ),
          ),

          // Top App Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Object 3D Bounding Box',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Length × Width × Height & Volume',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  onPressed: _reset,
                  tooltip: 'Reset',
                ),
              ],
            ),
          ),

          // Guidance Banner
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            left: 16,
            right: 16,
            child: GuidanceToast(
              message: _instruction,
              icon: Icons.view_in_ar_rounded,
            ),
          ),

          // Live Dimensions Readout Panel
          if (_corners.isNotEmpty)
            Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.7), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _DimensionPill(label: 'L', value: _unit.formatMeters(box.lengthMeters)),
                        _DimensionPill(label: 'W', value: _unit.formatMeters(box.widthMeters)),
                        _DimensionPill(label: 'H', value: _unit.formatMeters(box.heightMeters)),
                      ],
                    ),
                    if (box.volumeCubicMeters > 0) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Colors.white24),
                      const SizedBox(height: 8),
                      Text(
                        'Volume: ${(box.volumeCubicMeters * 1000).toStringAsFixed(1)} L (${box.volumeCubicMeters.toStringAsFixed(3)} m³)',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Bottom Controls
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _corners.length < 4 ? _addCorner : null,
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: Text(
                      _corners.length < 4 ? 'Set Corner #${_corners.length + 1}' : 'Box Finished',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_corners.length >= 2) ...[
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    backgroundColor: const Color(0xFF10B981),
                    onPressed: _save,
                    child: const Icon(Icons.check_rounded, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DimensionPill extends StatelessWidget {
  final String label;
  final String value;
  const _DimensionPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
