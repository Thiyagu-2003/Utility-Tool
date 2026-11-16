import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../models/smart_measure_capability.dart';
import '../../models/measurement_types.dart';
import '../../models/measurement_units.dart';
import '../../models/smart_measure_point.dart';
import '../../services/ar_platform_bridge.dart';
import '../../services/measurement_math_engine.dart';
import '../widgets/ar_reticle.dart';
import '../widgets/guidance_toast.dart';
import '../widgets/measurement_summary_sheet.dart';
import '../painters/measurement_overlay_painter.dart';

class AngleMeasurementScreen extends StatefulWidget {
  const AngleMeasurementScreen({super.key});

  @override
  State<AngleMeasurementScreen> createState() => _AngleMeasurementScreenState();
}

class _AngleMeasurementScreenState extends State<AngleMeasurementScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  SmartMeasureCapability? _capability;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _pitchDeg = 45.0;
  double _rollDeg = 0.0;

  final List<SmartMeasurePoint> _anglePoints = [];
  SmartMeasurePoint? _liveTarget;
  double? _liveDist;
  Timer? _raycastTimer;

  final AngleUnit _angleUnit = AngleUnit.degree;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _raycastTimer?.cancel();
    _accelSub?.cancel();
    ARPlatformBridge().setActiveCameraController(null); // bridge must not keep a disposed controller
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
        _pitchDeg = MeasurementMathEngine.cameraDownAngleDegrees(event.x, event.y, event.z); // below-horizon angle the raycast expects
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
            if (_anglePoints.isNotEmpty) {
              _liveDist = MeasurementMathEngine.distance3D(_anglePoints.last, target);
            } else {
              _liveDist = target.depthMeters;
            }
          });
        });
      }
    } catch (_) {}
  }

  void _addPoint() {
    if (_liveTarget == null || _anglePoints.length >= 3) return;
    setState(() {
      _anglePoints.add(_liveTarget!);
    });
  }

  void _reset() {
    setState(() => _anglePoints.clear());
  }

  String get _instruction {
    switch (_anglePoints.length) {
      case 0:
        return 'Step 1: Aim at point on First Arm and tap "Set Point #1"';
      case 1:
        return 'Step 2: Aim at the Vertex (Corner/Hinge) and tap "Set Vertex #2"';
      case 2:
        return 'Step 3: Aim at point on Second Arm and tap "Set Point #3"';
      default:
        return 'Angle calculation complete! Tap Save to record';
    }
  }

  void _save() {
    if (_anglePoints.length < 3) return;

    final deg = MeasurementMathEngine.angleBetween3D(
      point1: _anglePoints[0],
      vertex: _anglePoints[1],
      point2: _anglePoints[2],
    );

    final audit = MeasurementMathEngine.evaluateConfidence(
      trackingState: TrackingConfidence.medium, // sensor-estimated, not ARCore-tracked
      engine: _capability?.preferredEngine ?? MeasurementTrackingEngine.androidArCore,
      measurementDistanceMeters: 1.0,
      sensorDepthMeters: _anglePoints[1].depthMeters,
    );

    final secondary = {
      'Interior Angle': '${deg.toStringAsFixed(1)}°',
      'Reflex Angle': '${(360.0 - deg).toStringAsFixed(1)}°',
      'Arm 1 Length': DistanceUnit.centimeter.formatMeters(MeasurementMathEngine.distance3D(_anglePoints[1], _anglePoints[0])),
      'Arm 2 Length': DistanceUnit.centimeter.formatMeters(MeasurementMathEngine.distance3D(_anglePoints[1], _anglePoints[2])),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeasurementSummarySheet(
        toolType: SmartMeasureToolType.angle,
        primaryValue: deg,
        distanceUnit: DistanceUnit.centimeter,
        angleUnit: _angleUnit,
        formattedValue: '${deg.toStringAsFixed(1)}°',
        secondaryValues: secondary,
        confidence: TrackingConfidence.medium, // sensor-estimated, not ARCore-tracked
        uncertaintyPercent: audit.uncertaintyPercent,
        capabilityUsed: _capability?.preferredEngine.title ?? '3D Vector Angle Engine',
        points: List.from(_anglePoints),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double? calculatedAngle;
    if (_anglePoints.length == 3) {
      calculatedAngle = MeasurementMathEngine.angleBetween3D(
        point1: _anglePoints[0],
        vertex: _anglePoints[1],
        point2: _anglePoints[2],
      );
    } else if (_anglePoints.length == 2 && _liveTarget != null) {
      calculatedAngle = MeasurementMathEngine.angleBetween3D(
        point1: _anglePoints[0],
        vertex: _anglePoints[1],
        point2: _liveTarget!,
      );
    }

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
            const Center(child: CircularProgressIndicator(color: Color(0xFF84CC16))),

          // AR Line Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: MeasurementOverlayPainter(
                points: _anglePoints,
                activeTargetPos: const Offset(0.5, 0.5),
                activeTargetPoint: _liveTarget,
                unit: DistanceUnit.centimeter,
                primaryColor: const Color(0xFF84CC16),
              ),
            ),
          ),

          // Central Reticle
          IgnorePointer(
            child: ARReticle(
              isLockedOnSurface: true,
              liveDistanceMeters: _liveDist,
              distanceDisplay: _liveDist != null ? DistanceUnit.centimeter.formatMeters(_liveDist!) : null,
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
                        '3-Point Angle Tool',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Arm 1 ➔ Vertex Hinge ➔ Arm 2',
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
              icon: Icons.square_foot_rounded,
            ),
          ),

          // Live Angle Hero Card
          if (calculatedAngle != null)
            Positioned(
              bottom: 110,
              left: 24,
              right: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF84CC16), width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF84CC16).withOpacity(0.3),
                        blurRadius: 14,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'MEASURED ANGLE',
                        style: TextStyle(color: Color(0xFF84CC16), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${calculatedAngle.toStringAsFixed(1)}°',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Reflex: ${(360.0 - calculatedAngle).toStringAsFixed(1)}°',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Action Bar
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84CC16),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _anglePoints.length < 3 ? _addPoint : null,
                    icon: const Icon(Icons.touch_app_rounded),
                    label: Text(
                      _anglePoints.isEmpty
                          ? 'Set Arm Point #1'
                          : (_anglePoints.length == 1
                              ? 'Set Vertex #2'
                              : (_anglePoints.length == 2 ? 'Set Arm Point #3' : 'Angle Locked')),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_anglePoints.length == 3) ...[
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
