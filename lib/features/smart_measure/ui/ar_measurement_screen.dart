import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/smart_measure_capability.dart';
import '../models/measurement_types.dart';
import '../models/measurement_units.dart';
import '../models/smart_measure_point.dart';
import '../services/ar_platform_bridge.dart';
import '../services/measurement_math_engine.dart';
import 'widgets/ar_reticle.dart';
import 'widgets/confidence_pill.dart';
import 'widgets/guidance_toast.dart';
import 'widgets/measurement_controls_bar.dart';
import 'widgets/unit_selector_sheet.dart';
import 'widgets/measurement_summary_sheet.dart';
import 'painters/measurement_overlay_painter.dart';
import 'mode_screens/manual_image_measurement_screen.dart';

class ARMeasurementScreen extends StatefulWidget {
  final SmartMeasureToolType initialTool;

  const ARMeasurementScreen({
    super.key,
    this.initialTool = SmartMeasureToolType.pointToPoint,
  });

  @override
  State<ARMeasurementScreen> createState() => _ARMeasurementScreenState();
}

class _ARMeasurementScreenState extends State<ARMeasurementScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitializing = true;
  String? _cameraErrorMessage;

  SmartMeasureCapability? _capability;
  TrackingConfidence _trackingState = TrackingConfidence.medium;
  bool _isSurfaceLocked = false;
  String _guidanceMessage = 'Move phone slowly to detect surfaces';
  bool _guidanceIsWarning = false;

  // Sensor state for tilt / optical raycasting
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _cameraPitchDeg = 45.0; // Default 45° downward angle
  double _cameraRollDeg = 0.0;
  final double _deviceHeightMeters = 1.35; // Typical chest-height holding position

  // Point tracking & Undo/Redo history stacks
  final List<SmartMeasurePoint> _points = [];
  final List<SmartMeasurePoint> _redoPoints = [];
  int? _selectedPointIndex;

  // Live raycast target point at center of screen (0.5, 0.5)
  SmartMeasurePoint? _liveTargetPoint;
  double? _liveDistanceMeters;

  // Active units
  DistanceUnit _distanceUnit = DistanceUnit.centimeter;
  final AreaUnit _areaUnit = AreaUnit.sqMeter;
  bool _isTorchOn = false;

  // Measurement timer to periodic raycast
  Timer? _raycastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCapabilitiesAndCamera();
    _startSensors();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _raycastTimer?.cancel();
    _accelSub?.cancel();
    _cameraController?.dispose();
    ARPlatformBridge().setActiveCameraController(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  void _startSensors() {
    try {
      _accelSub = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        final reading = MeasurementMathEngine.calculateLevel(event.x, event.y, event.z);
        setState(() {
          _cameraPitchDeg = reading.pitchDegrees.abs();
          _cameraRollDeg = reading.rollDegrees;
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _initializeCapabilitiesAndCamera() async {
    final cap = await ARPlatformBridge().checkCapabilities();
    if (!mounted) return;
    setState(() => _capability = cap);

    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isCameraInitializing = true;
      _cameraErrorMessage = null;
    });

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _isCameraInitializing = false;
          _cameraErrorMessage = 'No camera found on this device.';
        });
        return;
      }

      // Select back-facing camera
      final backCam = _availableCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );

      final controller = CameraController(
        backCam,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      _cameraController = controller;
      ARPlatformBridge().setActiveCameraController(controller);

      setState(() {
        _isCameraInitializing = false;
        _trackingState = TrackingConfidence.high;
        _isSurfaceLocked = true;
        _guidanceMessage = 'Surface locked. Aim and tap "Add Point" to measure';
        _guidanceIsWarning = false;
      });

      _startRaycastLoop();
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraErrorMessage = 'Camera permission required or device camera is in use.';
        });
      }
    }
  }

  void _startRaycastLoop() {
    _raycastTimer?.cancel();
    _raycastTimer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      if (!mounted || _cameraController == null || !_cameraController!.value.isInitialized) return;

      final target = await ARPlatformBridge().raycastHitTest(
        normalizedScreenPos: const Offset(0.5, 0.5),
        cameraPitchDegrees: _cameraPitchDeg,
        cameraRollDegrees: _cameraRollDeg,
        estimatedDeviceHeightMeters: _deviceHeightMeters,
        currentFocalScale: 1.0,
      );

      if (!mounted) return;

      setState(() {
        _liveTargetPoint = target;
        if (_points.isNotEmpty) {
          _liveDistanceMeters = MeasurementMathEngine.distance3D(_points.last, target);
        } else {
          _liveDistanceMeters = target.depthMeters;
        }
      });
    });
  }

  Future<void> _toggleTorch() async {
    final newState = await ARPlatformBridge().toggleTorch();
    setState(() => _isTorchOn = newState);
  }

  void _addPointAtCenter() {
    if (_liveTargetPoint == null) return;

    setState(() {
      _points.add(_liveTargetPoint!);
      _redoPoints.clear();
      _selectedPointIndex = null;

      if (_points.length == 1) {
        _guidanceMessage = 'First point placed! Move to target and add second point';
        _guidanceIsWarning = false;
      } else {
        final totalDist = MeasurementMathEngine.cumulativeDistance(_points);
        _guidanceMessage = 'Total: ${_distanceUnit.formatMeters(totalDist)}. Tap Save to record';
      }
    });
  }

  void _undo() {
    if (_points.isEmpty) return;
    setState(() {
      _redoPoints.add(_points.removeLast());
      _selectedPointIndex = null;
      if (_points.isEmpty) {
        _guidanceMessage = 'Aim and tap "Add Point" to measure';
      }
    });
  }

  void _redo() {
    if (_redoPoints.isEmpty) return;
    setState(() {
      _points.add(_redoPoints.removeLast());
      _selectedPointIndex = null;
    });
  }

  void _clear() {
    setState(() {
      _points.clear();
      _redoPoints.clear();
      _selectedPointIndex = null;
      _guidanceMessage = 'Cleared. Aim and tap "Add Point" to begin';
    });
  }

  void _showUnitPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnitSelectorSheet(
        currentUnit: _distanceUnit,
        onSelected: (u) => setState(() => _distanceUnit = u),
      ),
    );
  }

  void _saveCurrentMeasurement() {
    if (_points.length < 2) return;

    final primaryDist = MeasurementMathEngine.cumulativeDistance(_points);
    final audit = MeasurementMathEngine.evaluateConfidence(
      trackingState: _trackingState,
      engine: _capability?.preferredEngine ?? MeasurementTrackingEngine.androidArCore,
      measurementDistanceMeters: primaryDist,
      sensorDepthMeters: _liveTargetPoint?.depthMeters ?? 1.5,
    );

    final Map<String, dynamic> secondary = {
      'Points Count': _points.length,
      'Point 1 Depth': '${_points.first.depthMeters.toStringAsFixed(2)} m',
      'End Point Depth': '${_points.last.depthMeters.toStringAsFixed(2)} m',
    };

    if (_points.length >= 3) {
      final area = MeasurementMathEngine.polygonArea3D(_points);
      secondary['Enclosed Area'] = _areaUnit.formatSqMeters(area);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeasurementSummarySheet(
        toolType: widget.initialTool,
        primaryValue: primaryDist,
        distanceUnit: _distanceUnit,
        areaUnit: _areaUnit,
        formattedValue: _distanceUnit.formatMeters(primaryDist),
        secondaryValues: secondary,
        confidence: _trackingState,
        uncertaintyPercent: audit.uncertaintyPercent,
        capabilityUsed: _capability?.preferredEngine.title ?? 'Optical AR Engine',
        points: List.from(_points),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isClosedPoly = widget.initialTool == SmartMeasureToolType.area ||
        widget.initialTool == SmartMeasureToolType.surface;

    // Measurement uncertainty audit calculation
    final activeDist = _points.length >= 2
        ? MeasurementMathEngine.cumulativeDistance(_points)
        : (_liveDistanceMeters ?? 1.0);

    final audit = MeasurementMathEngine.evaluateConfidence(
      trackingState: _trackingState,
      engine: _capability?.preferredEngine ?? MeasurementTrackingEngine.androidArCore,
      measurementDistanceMeters: activeDist,
      sensorDepthMeters: _liveTargetPoint?.depthMeters ?? 1.5,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Preview or Desktop Fallback Placeholder
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            _buildCameraFallbackView(theme),

          // 2. Interactive Augmented Reality Lines and Anchor Overlay
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) {
                // Check if user tapped near an existing point to select/reposition
                final size = MediaQuery.of(context).size;
                final tapNorm = Offset(details.localPosition.dx / size.width, details.localPosition.dy / size.height);

                for (int i = 0; i < _points.length; i++) {
                  final dist = (tapNorm - _points[i].screenPosition).distance;
                  if (dist < 0.06) {
                    setState(() => _selectedPointIndex = i);
                    HapticFeedback.selectionClick();
                    return;
                  }
                }

                // If not near a point, add point at tap position
                if (_liveTargetPoint != null) {
                  _addPointAtCenter();
                }
              },
              child: CustomPaint(
                painter: MeasurementOverlayPainter(
                  points: _points,
                  activeTargetPos: const Offset(0.5, 0.5),
                  activeTargetPoint: _liveTargetPoint,
                  unit: _distanceUnit,
                  isClosedPolygon: isClosedPoly && _points.length >= 3,
                  selectedPointIndex: _selectedPointIndex,
                  primaryColor: widget.initialTool.color,
                ),
              ),
            ),
          ),

          // 3. Central Aiming Reticle with real-time depth readout
          IgnorePointer(
            child: ARReticle(
              isLockedOnSurface: _isSurfaceLocked,
              liveDistanceMeters: _liveDistanceMeters,
              distanceDisplay: _liveDistanceMeters != null
                  ? _distanceUnit.formatMeters(_liveDistanceMeters!)
                  : null,
            ),
          ),

          // 4. Top Header: Navigation, Tool Title, Flashlight, Unit Switcher
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.initialTool.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _capability?.preferredEngine.title ?? 'Smart Measure Engine',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // Torch Toggle
                  IconButton(
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white70,
                    ),
                    onPressed: _toggleTorch,
                    tooltip: 'Flashlight',
                  ),

                  // Unit Selector Pill
                  GestureDetector(
                    onTap: _showUnitPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _distanceUnit.symbol,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Tracking Guidance Toast & Confidence Pill
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConfidencePill(
                  confidence: _trackingState,
                  errorMargin: audit.absoluteErrorMarginDisplay,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Tracking Confidence: ${_trackingState.label}\n${_trackingState.hint}\nUncertainty: ±${audit.uncertaintyPercent.toStringAsFixed(1)}%',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                GuidanceToast(
                  message: _guidanceMessage,
                  isWarning: _guidanceIsWarning,
                  icon: _guidanceIsWarning ? Icons.warning_amber_rounded : Icons.radar_rounded,
                ),
              ],
            ),
          ),

          // 6. Live Distance Readout Banner
          if (_points.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: widget.initialTool.color.withOpacity(0.8), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: widget.initialTool.color.withOpacity(0.3),
                        blurRadius: 12,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.initialTool.icon, color: widget.initialTool.color, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        _distanceUnit.formatMeters(MeasurementMathEngine.cumulativeDistance(_points)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isClosedPoly && _points.length >= 3) ...[
                        const SizedBox(width: 12),
                        Container(width: 1, height: 16, color: Colors.white24),
                        const SizedBox(width: 12),
                        Text(
                          _areaUnit.formatSqMeters(MeasurementMathEngine.polygonArea3D(_points)),
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // 7. Bottom Measurement Controls Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MeasurementControlsBar(
              onAddPoint: _addPointAtCenter,
              onUndo: _undo,
              onRedo: _redo,
              onClear: _clear,
              onSave: _saveCurrentMeasurement,
              canUndo: _points.isNotEmpty,
              canRedo: _redoPoints.isNotEmpty,
              canSave: _points.length >= 2,
              pointsCount: _points.length,
              primaryActionLabel: _points.isEmpty ? 'Start Point' : 'Add Point',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraFallbackView(ThemeData theme) {
    if (_isCameraInitializing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: widget.initialTool.color),
            const SizedBox(height: 16),
            const Text(
              'Initializing camera & AR sensors...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Text(
              _cameraErrorMessage ?? 'Live Camera Unsupported',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'For desktop or devices without active webcam support, use the Calibrated Image Measurement tool.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ManualImageMeasurementScreen()),
                );
              },
              icon: const Icon(Icons.photo_size_select_actual_rounded),
              label: const Text('Open Manual Image Measurement'),
            ),
          ],
        ),
      ),
    );
  }
}
