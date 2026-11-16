import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../models/smart_measure_capability.dart';
import '../../models/measurement_types.dart';
import '../../models/measurement_units.dart';
import '../../models/smart_measure_point.dart';
import '../../models/room_dimension_model.dart';
import '../../services/ar_platform_bridge.dart';
import '../../services/measurement_math_engine.dart';
import '../widgets/ar_reticle.dart';
import '../widgets/guidance_toast.dart';
import '../widgets/measurement_summary_sheet.dart';
import '../painters/measurement_overlay_painter.dart';

class RoomMeasurementScreen extends StatefulWidget {
  const RoomMeasurementScreen({super.key});

  @override
  State<RoomMeasurementScreen> createState() => _RoomMeasurementScreenState();
}

class _RoomMeasurementScreenState extends State<RoomMeasurementScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  SmartMeasureCapability? _capability;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _pitchDeg = 45.0;
  double _rollDeg = 0.0;

  final List<SmartMeasurePoint> _wallCorners = [];
  SmartMeasurePoint? _liveTarget;
  double? _liveDist;
  Timer? _raycastTimer;

  final DistanceUnit _unit = DistanceUnit.meter;
  final AreaUnit _areaUnit = AreaUnit.sqMeter;
  final double? _ceilingHeight = 2.70; // Standard 2.7m ceiling default

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
            assumedPlane: PlaneType.horizontalDownward,
          );
          if (!mounted) return;
          setState(() {
            _liveTarget = target;
            if (_wallCorners.isNotEmpty) {
              _liveDist = MeasurementMathEngine.distance3D(_wallCorners.last, target);
            } else {
              _liveDist = target.depthMeters;
            }
          });
        });
      }
    } catch (_) {}
  }

  void _addWallCorner() {
    if (_liveTarget == null) return;
    setState(() {
      _wallCorners.add(_liveTarget!);
    });
  }

  void _undo() {
    if (_wallCorners.isNotEmpty) {
      setState(() => _wallCorners.removeLast());
    }
  }

  void _clear() {
    setState(() => _wallCorners.clear());
  }

  void _saveRoom() {
    if (_wallCorners.length < 3) return;

    final summary = MeasurementMathEngine.calculateRoomSummary(
      _wallCorners,
      ceilingHeightMeters: _ceilingHeight,
    );

    final audit = MeasurementMathEngine.evaluateConfidence(
      trackingState: TrackingConfidence.high,
      engine: _capability?.preferredEngine ?? MeasurementTrackingEngine.androidArCore,
      measurementDistanceMeters: summary.perimeterMeters,
      sensorDepthMeters: _wallCorners.first.depthMeters,
    );

    final secondary = {
      'Floor Area': _areaUnit.formatSqMeters(summary.floorAreaSqMeters),
      'Perimeter': _unit.formatMeters(summary.perimeterMeters),
      'Wall Count': '${summary.walls.length} Walls',
      'Est. Length': _unit.formatMeters(summary.estimatedLengthMeters),
      'Est. Width': _unit.formatMeters(summary.estimatedWidthMeters),
      if (_ceilingHeight != null) 'Ceiling Height': _unit.formatMeters(_ceilingHeight!),
      if (summary.estimatedVolumeCuMeters != null)
        'Volume': '${summary.estimatedVolumeCuMeters!.toStringAsFixed(1)} m³',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeasurementSummarySheet(
        toolType: SmartMeasureToolType.room,
        primaryValue: summary.floorAreaSqMeters,
        distanceUnit: _unit,
        areaUnit: _areaUnit,
        formattedValue: _areaUnit.formatSqMeters(summary.floorAreaSqMeters),
        secondaryValues: secondary,
        confidence: TrackingConfidence.high,
        uncertaintyPercent: audit.uncertaintyPercent,
        capabilityUsed: _capability?.preferredEngine.title ?? 'Multi-Plane Room Engine',
        points: List.from(_wallCorners),
        extraMetadata: summary.toJson(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = MeasurementMathEngine.calculateRoomSummary(_wallCorners, ceilingHeightMeters: _ceilingHeight);

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
            const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),

          // AR Overlay for wall polygon
          Positioned.fill(
            child: CustomPaint(
              painter: MeasurementOverlayPainter(
                points: _wallCorners,
                activeTargetPos: const Offset(0.5, 0.5),
                activeTargetPoint: _liveTarget,
                unit: _unit,
                isClosedPolygon: _wallCorners.length >= 3,
                primaryColor: const Color(0xFFD97706),
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
                        'Room Measurement Plan',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Floor plane & connected perimeter walls',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  onPressed: _clear,
                  tooltip: 'Clear',
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
              message: _wallCorners.isEmpty
                  ? 'Aim at starting wall corner on the floor and tap "Add Wall Corner"'
                  : 'Wall #${_wallCorners.length} marked. Aim at next corner and tap "Add Wall Corner"',
              icon: Icons.meeting_room_rounded,
            ),
          ),

          // Floating Room Metrics Card
          if (_wallCorners.length >= 3)
            Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD97706).withOpacity(0.8), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('FLOOR AREA', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          _areaUnit.formatSqMeters(summary.floorAreaSqMeters),
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 28, color: Colors.white24),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('PERIMETER', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          _unit.formatMeters(summary.perimeterMeters),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 28, color: Colors.white24),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('WALLS', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          '${summary.walls.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
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
                if (_wallCorners.isNotEmpty) ...[
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.white24),
                    icon: const Icon(Icons.undo_rounded, color: Colors.white),
                    onPressed: _undo,
                    tooltip: 'Undo Corner',
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _addWallCorner,
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: Text(
                      'Add Corner #${_wallCorners.length + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_wallCorners.length >= 3) ...[
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    backgroundColor: const Color(0xFF10B981),
                    onPressed: _saveRoom,
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
