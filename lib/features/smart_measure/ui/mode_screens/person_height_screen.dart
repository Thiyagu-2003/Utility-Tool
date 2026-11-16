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

class PersonHeightScreen extends StatefulWidget {
  const PersonHeightScreen({super.key});

  @override
  State<PersonHeightScreen> createState() => _PersonHeightScreenState();
}

class _PersonHeightScreenState extends State<PersonHeightScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  SmartMeasureCapability? _capability;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _pitchDeg = 45.0;
  double _rollDeg = 0.0;

  SmartMeasurePoint? _groundBasePoint;
  SmartMeasurePoint? _headTopPoint;
  SmartMeasurePoint? _liveTarget;
  double? _liveVerticalDist;
  Timer? _raycastTimer;

  final DistanceUnit _unit = DistanceUnit.centimeter;
  bool _isGroundLocked = false;

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
            if (_groundBasePoint != null) {
              _liveVerticalDist = (_groundBasePoint!.y - target.y).abs();
            }
          });
        });
      }
    } catch (_) {}
  }

  void _lockGroundOrHead() {
    if (_liveTarget == null) return;
    setState(() {
      if (!_isGroundLocked) {
        _groundBasePoint = _liveTarget!;
        _isGroundLocked = true;
      } else {
        _headTopPoint = _liveTarget!;
      }
    });
  }

  void _reset() {
    setState(() {
      _groundBasePoint = null;
      _headTopPoint = null;
      _isGroundLocked = false;
      _liveVerticalDist = null;
    });
  }

  void _save() {
    if (_groundBasePoint == null || _headTopPoint == null) return;
    final h = (_groundBasePoint!.y - _headTopPoint!.y).abs();

    final isLiDAR = _capability?.preferredEngine == MeasurementTrackingEngine.iosLidar;

    final audit = MeasurementMathEngine.evaluateConfidence(
      trackingState: TrackingConfidence.medium, // sensor-estimated, not ARCore-tracked
      engine: _capability?.preferredEngine ?? MeasurementTrackingEngine.androidArCore,
      measurementDistanceMeters: h,
      sensorDepthMeters: _groundBasePoint!.depthMeters,
    );

    final secondary = {
      'Height (Imperial)': '${DistanceUnit.foot.formatMeters(h)} (${DistanceUnit.inch.formatMeters(h)})',
      'Measurement Mode': isLiDAR ? 'LiDAR Direct Mesh Depth' : 'Ground Plane Projected Vertical Raycast',
      'Ground Distance': '${_groundBasePoint!.depthMeters.toStringAsFixed(2)} m',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeasurementSummarySheet(
        toolType: SmartMeasureToolType.personHeight,
        primaryValue: h,
        distanceUnit: _unit,
        formattedValue: _unit.formatMeters(h),
        secondaryValues: secondary,
        confidence: TrackingConfidence.medium, // sensor-estimated, not ARCore-tracked
        uncertaintyPercent: audit.uncertaintyPercent,
        capabilityUsed: _capability?.preferredEngine.title ?? 'Vertical Tracking Engine',
        points: [_groundBasePoint!, _headTopPoint!],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pointsList = <SmartMeasurePoint>[];
    if (_groundBasePoint != null) pointsList.add(_groundBasePoint!);
    if (_headTopPoint != null) pointsList.add(_headTopPoint!);

    final isLiDAR = _capability?.preferredEngine == MeasurementTrackingEngine.iosLidar;

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
            const Center(child: CircularProgressIndicator(color: Color(0xFFF43F5E))),

          // AR Line Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: MeasurementOverlayPainter(
                points: pointsList,
                activeTargetPos: const Offset(0.5, 0.5),
                activeTargetPoint: _liveTarget,
                unit: _unit,
                primaryColor: const Color(0xFFF43F5E),
              ),
            ),
          ),

          // Central Reticle
          IgnorePointer(
            child: ARReticle(
              isLockedOnSurface: true,
              liveDistanceMeters: _liveVerticalDist,
              distanceDisplay: _liveVerticalDist != null ? _unit.formatMeters(_liveVerticalDist!) : null,
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
                        'Height Measurement',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Ground-to-head vertical tracking',
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

          // Tracking & Precision Disclaimer Banner
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GuidanceToast(
                  message: !_isGroundLocked
                      ? 'Step 1: Aim at the ground/floor near the person\'s feet & tap "Lock Floor Base"'
                      : _headTopPoint == null
                          ? 'Step 2: Pan camera up to top of head / crown & tap "Lock Top"'
                          : 'Height captured! Tap Save to record',
                  icon: Icons.accessibility_new_rounded,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isLiDAR ? 'Direct LiDAR depth sensing active' : 'Estimated vertical raycast (Ground plane referenced)',
                    style: TextStyle(
                      color: isLiDAR ? const Color(0xFF10B981) : const Color(0xFFFBBF24),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Live Height Readout
          if (_isGroundLocked && _liveVerticalDist != null)
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
                    border: Border.all(color: const Color(0xFFF43F5E), width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF43F5E).withOpacity(0.35),
                        blurRadius: 14,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'VERTICAL HEIGHT',
                        style: TextStyle(color: Color(0xFFF43F5E), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _unit.formatMeters(_liveVerticalDist!),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${DistanceUnit.foot.formatMeters(_liveVerticalDist!)} (${DistanceUnit.inch.formatMeters(_liveVerticalDist!)})',
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
                      backgroundColor: const Color(0xFFF43F5E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _headTopPoint == null ? _lockGroundOrHead : null,
                    icon: Icon(!_isGroundLocked ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                    label: Text(
                      !_isGroundLocked ? 'Lock Floor Base' : (_headTopPoint == null ? 'Lock Top / Head' : 'Completed'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_headTopPoint != null) ...[
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
