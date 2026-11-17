import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/measurement_units.dart';
import '../models/measurement_types.dart';
import '../models/smart_measure_capability.dart';
import '../services/spatial_anchor_tracker.dart';
import '../services/ar_platform_bridge.dart';
import '../services/measurement_math_engine.dart';
import 'painters/measurement_overlay_painter.dart';
import 'widgets/measurement_summary_sheet.dart';
import 'widgets/unit_selector_sheet.dart';
import 'widgets/ar_reticle.dart';
import 'smart_measure_dashboard_screen.dart';

/// Apple / iPhone Measure inspired live camera measurement screen.
/// Backed by real Google ARCore 3D plane detection & spatial anchors on Android,
/// with 60 FPS non-blocking overlays, proper camera permissions, and safe navigation insets.
class ARMeasurementScreen extends StatefulWidget {
  final SmartMeasureToolType initialTool;

  const ARMeasurementScreen({
    super.key,
    this.initialTool = SmartMeasureToolType.quickMeasure,
  });

  @override
  State<ARMeasurementScreen> createState() => _ARMeasurementScreenState();
}

enum _DragTargetType {
  none,
  activeStart,
  segmentStart,
  segmentEnd,
}

class _ARAnchorData {
  final String id;
  // Native anchors: refreshed every frame from the ARCore anchor's current pose.
  double worldX;
  double worldY;
  double worldZ;
  Offset screenPosition; // 0.0 to 1.0 normalized
  final bool isNative;
  bool visible = true; // false while ARCore isn't tracking it or it is behind the camera

  _ARAnchorData({
    required this.id,
    required this.worldX,
    required this.worldY,
    required this.worldZ,
    required this.screenPosition,
    this.isNative = false,
  });

  double distanceTo(_ARAnchorData other) {
    final dx = other.worldX - worldX;
    final dy = other.worldY - worldY;
    final dz = other.worldZ - worldZ;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

class _LockedSegment {
  _ARAnchorData start;
  _ARAnchorData end;
  double distanceMeters;
  String label;

  _LockedSegment({
    required this.start,
    required this.end,
    required this.distanceMeters,
    required this.label,
  });

  void recalculate(DistanceUnit unit) {
    // Native segments are frozen at placement (from the two anchor poses); only re-label them.
    if (!start.isNative || !end.isNative) distanceMeters = start.distanceTo(end);
    label = unit.formatMeasurement(distanceMeters);
  }
}

class _ARMeasurementScreenState extends State<ARMeasurementScreen> with WidgetsBindingObserver {
  // Permission state
  bool _hasCameraPermission = true;
  bool _isCheckingPermission = true;

  // Native ARCore state
  bool _useNativeARCore = false;
  bool _isNativeViewReady = false;
  int? _nativeViewId;
  Timer? _arTrackingTimer;

  // Camera fallback for devices without ARCore
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraReady = false;

  // Spatial Sensor Tracker (for sensor-fusion & fallback raycasting)
  final SpatialAnchorTracker _spatialTracker = SpatialAnchorTracker();

  // Anchors and Segments
  _ARAnchorData? _activeStartAnchor;
  final List<_LockedSegment> _lockedSegments = [];

  // Live 3D reticle coordinates from ARCore tracking (null = no stable surface hit)
  double? _reticleWorldX;
  double? _reticleWorldY;
  double? _reticleWorldZ;
  bool _isSyncingTracking = false;
  bool _isPlacingPoint = false;

  // Surface Detection & Guidance State
  bool _isSurfaceDetected = false;
  bool _canPlacePoint = false; // ARCore TRACKING and reticle on a tracked plane/depth hit
  String _rangeHint = ''; // "Move closer" / "Move further away", empty when distance is fine
  String _surfaceStatusMessage = 'Searching for a surface...';
  String _surfaceType = 'NONE';
  int _planesCount = 0;

  // Dragging & Interaction State
  _DragTargetType _activeDragType = _DragTargetType.none;
  int? _activeDragSegmentIndex;
  int? _selectedAnchorIndex;

  // Units & Torch
  DistanceUnit _unit = DistanceUnit.centimeter;
  bool _isTorchOn = false;

  // Bottom dock mode: 0 = Measure, 1 = Level
  int _activeDockTab = 0;

  // Level sensors state (for Level tab)
  StreamSubscription<AccelerometerEvent>? _levelAccelSub;
  double _levelRollDeg = 0.0;
  double _levelPitchDeg = 0.0;
  double _levelTotalTiltDeg = 0.0;
  bool _isLevelAligned = false;
  bool _levelHapticFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initMeasurementSystem();
    _startLevelSensors();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _arTrackingTimer?.cancel();
    _spatialTracker.stopTracking();
    _levelAccelSub?.cancel();
    _cameraController?.dispose();
    ARPlatformBridge().clearNativeView(_nativeViewId);
    ARPlatformBridge().setActiveCameraController(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      if (_useNativeARCore) {
        ARPlatformBridge().pauseNativeSession();
      } else {
        // Null it before disposing so CameraPreview never rebuilds on a disposed controller.
        final c = _cameraController;
        _cameraController = null;
        ARPlatformBridge().setActiveCameraController(null);
        if (mounted) setState(() => _isCameraReady = false);
        c?.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_useNativeARCore) {
        ARPlatformBridge().resumeNativeSession();
      } else if (_hasCameraPermission) {
        _initCameraFallback();
      }
    }
  }

  Future<void> _initMeasurementSystem() async {
    // 1. Request and verify camera permission
    final hasPerm = await ARPlatformBridge().hasCameraPermission();
    if (!hasPerm) {
      final granted = await ARPlatformBridge().requestCameraPermission();
      if (!granted) {
        if (mounted) {
          setState(() {
            _hasCameraPermission = false;
            _isCheckingPermission = false;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _hasCameraPermission = true;
        _isCheckingPermission = false;
      });
    }

    _spatialTracker.startTracking();

    if (!kIsWeb && Platform.isAndroid) {
      final cap = await ARPlatformBridge().checkCapabilities();
      if (cap.canUseLiveAR) {
        if (mounted) {
          setState(() {
            _useNativeARCore = true;
          });
        }
        return;
      }
    }

    // Fallback: Flutter CameraPreview + SpatialAnchorTracker
    await _initCameraFallback();
  }

  Future<void> _initCameraFallback() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) return;

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
      setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera fallback init error: $e');
    }
  }

  void _onPlatformViewCreated(int viewId) {
    _nativeViewId = viewId;
    ARPlatformBridge().setNativeViewId(viewId);
    setState(() => _isNativeViewReady = true);

    // Make sure the native ARCore session opens the camera hardware immediately
    ARPlatformBridge().resumeNativeSession();

    // Start 60 FPS periodic sync for anchor reprojecting & surface status
    _arTrackingTimer?.cancel();
    _arTrackingTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      _syncARCoreTracking();
    });
  }

  Future<void> _syncARCoreTracking() async {
    if (!_useNativeARCore || !_isNativeViewReady || _isSyncingTracking) return;
    _isSyncingTracking = true;

    try {
      // 1. Query surface state
      final status = await ARPlatformBridge().querySurfaceStatus();
      if (status != null && mounted) {
        final hasSurf = status['hasSurface'] as bool? ?? false;
        final canPlace = status['canPlace'] as bool? ?? false;
        final planes = status['planesCount'] as int? ?? 0;
        final type = status['surfaceType'] as String? ?? 'NONE';
        final msg = status['statusMessage'] as String? ?? '';
        final hint = status['hint'] as String? ?? '';

        if (_isSurfaceDetected != hasSurf ||
            _canPlacePoint != canPlace ||
            _rangeHint != hint ||
            _surfaceStatusMessage != msg ||
            _planesCount != planes) {
          setState(() {
            _isSurfaceDetected = hasSurf;
            _canPlacePoint = canPlace;
            _rangeHint = hint;
            _planesCount = planes;
            _surfaceType = type;
            _surfaceStatusMessage = msg;
          });
        }
      }

      // 2. Query anchor screen reprojection and live reticle world pose from ARCore camera matrix
      final anchorIds = <String>[];
      if (_activeStartAnchor != null && _activeStartAnchor!.isNative) {
        anchorIds.add(_activeStartAnchor!.id);
      }
      for (final seg in _lockedSegments) {
        if (seg.start.isNative) anchorIds.add(seg.start.id);
        if (seg.end.isNative) anchorIds.add(seg.end.id);
      }

      final positions = await ARPlatformBridge().getAnchorScreenPositions(anchorIds);
      if (!mounted) return;

      // Reticle: only a stable plane/depth hit counts; otherwise no live end point.
      final reticle = positions['__reticle__'];
      if (reticle is Map && reticle['hasHit'] == true) {
        _reticleWorldX = (reticle['worldX'] as num).toDouble();
        _reticleWorldY = (reticle['worldY'] as num).toDouble();
        _reticleWorldZ = (reticle['worldZ'] as num).toDouble();
      } else {
        _reticleWorldX = _reticleWorldY = _reticleWorldZ = null;
      }

      // Anchors: current pose + projection every frame. Missing (not tracking) or behind
      // the camera = hidden, never left at a stale screen position.
      void apply(_ARAnchorData a) {
        if (!a.isNative) return;
        final data = positions[a.id];
        a.visible = data is Map && data['inView'] == true;
        if (!a.visible) return;
        a.screenPosition = Offset((data['x'] as num).toDouble(), (data['y'] as num).toDouble());
        a.worldX = (data['worldX'] as num).toDouble();
        a.worldY = (data['worldY'] as num).toDouble();
        a.worldZ = (data['worldZ'] as num).toDouble();
      }

      if (_activeStartAnchor != null) apply(_activeStartAnchor!);
      for (final seg in _lockedSegments) {
        apply(seg.start);
        apply(seg.end);
      }

      if (_activeStartAnchor != null || _lockedSegments.isNotEmpty) {
        setState(() {});
      }
    } finally {
      _isSyncingTracking = false;
    }
  }

  void _startLevelSensors() {
    try {
      _levelAccelSub = accelerometerEventStream().listen((event) {
        if (!mounted || _activeDockTab != 1) return;

        final reading = MeasurementMathEngine.calculateLevel(event.x, event.y, event.z);
        final tilt = math.sqrt(reading.rollDegrees * reading.rollDegrees + reading.pitchDegrees * reading.pitchDegrees);
        final isAligned = tilt.abs() <= 0.8;

        if (isAligned && !_levelHapticFired) {
          HapticFeedback.mediumImpact();
          _levelHapticFired = true;
        } else if (!isAligned) {
          _levelHapticFired = false;
        }

        setState(() {
          _levelRollDeg = reading.rollDegrees;
          _levelPitchDeg = reading.pitchDegrees;
          _levelTotalTiltDeg = tilt;
          _isLevelAligned = isAligned;
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  // --- Point Creation & AR Hit Testing ---

  Future<void> _onPlusButtonTapped() async {
    if (_isPlacingPoint) return;

    _ARAnchorData newAnchor;

    if (_useNativeARCore) {
      // Only place real ARCore anchors on a tracked surface. Never mix in sensor-estimated
      // points: they live in a different coordinate space and slide on screen.
      if (!_isNativeViewReady || !_canPlacePoint) {
        HapticFeedback.heavyImpact();
        return;
      }
      HapticFeedback.mediumImpact();
      _isPlacingPoint = true;
      final hit = await ARPlatformBridge().nativeHitTest(x: 0.5, y: 0.5);
      _isPlacingPoint = false;
      if (hit == null || !mounted) return;
      newAnchor = _ARAnchorData(
        id: hit['anchorId'] as String,
        worldX: (hit['x'] as num).toDouble(),
        worldY: (hit['y'] as num).toDouble(),
        worldZ: (hit['z'] as num).toDouble(),
        screenPosition: const Offset(0.5, 0.5),
        isNative: true,
      );
    } else {
      HapticFeedback.mediumImpact();
      // Optical fallback raycasting
      final rayAnchor = _spatialTracker.createAnchorAtScreenPoint(
        UniqueKey().toString(),
        const Offset(0.5, 0.5),
      );
      newAnchor = _ARAnchorData(
        id: rayAnchor.id,
        worldX: rayAnchor.worldX,
        worldY: rayAnchor.worldY,
        worldZ: rayAnchor.worldZ,
        screenPosition: const Offset(0.5, 0.5),
        isNative: false,
      );
    }

    setState(() {
      if (_activeStartAnchor == null) {
        _activeStartAnchor = newAnchor;
      } else {
        final dist = _activeStartAnchor!.distanceTo(newAnchor);
        final label = _unit.formatMeasurement(dist);

        _lockedSegments.add(
          _LockedSegment(
            start: _activeStartAnchor!,
            end: newAnchor,
            distanceMeters: dist,
            label: label,
          ),
        );

        _activeStartAnchor = null;
      }
    });
  }

  // --- Pan / Dragging Points on Screen ---

  void _handlePanStart(Offset localPos, Size size) {
    // Dragging re-places a point by sensor raycast, which would replace a world-locked
    // ARCore anchor with a drifting estimate. ARCore mode: undo and re-place instead.
    if (_useNativeARCore) return;
    const hitRadius = 42.0;

    if (_activeStartAnchor != null) {
      final px = Offset(_activeStartAnchor!.screenPosition.dx * size.width, _activeStartAnchor!.screenPosition.dy * size.height);
      if ((localPos - px).distance <= hitRadius) {
        HapticFeedback.selectionClick();
        setState(() {
          _activeDragType = _DragTargetType.activeStart;
          _selectedAnchorIndex = 999;
        });
        return;
      }
    }

    for (int i = _lockedSegments.length - 1; i >= 0; i--) {
      final seg = _lockedSegments[i];
      final endPx = Offset(seg.end.screenPosition.dx * size.width, seg.end.screenPosition.dy * size.height);
      if ((localPos - endPx).distance <= hitRadius) {
        HapticFeedback.selectionClick();
        setState(() {
          _activeDragType = _DragTargetType.segmentEnd;
          _activeDragSegmentIndex = i;
          _selectedAnchorIndex = i * 2 + 1;
        });
        return;
      }

      final startPx = Offset(seg.start.screenPosition.dx * size.width, seg.start.screenPosition.dy * size.height);
      if ((localPos - startPx).distance <= hitRadius) {
        HapticFeedback.selectionClick();
        setState(() {
          _activeDragType = _DragTargetType.segmentStart;
          _activeDragSegmentIndex = i;
          _selectedAnchorIndex = i * 2;
        });
        return;
      }
    }
  }

  void _handlePanUpdate(Offset localPos, Size size) {
    if (_activeDragType == _DragTargetType.none) return;

    final norm = Offset(
      (localPos.dx / size.width).clamp(0.02, 0.98),
      (localPos.dy / size.height).clamp(0.04, 0.94),
    );

    final rayAnchor = _spatialTracker.createAnchorAtScreenPoint(
      UniqueKey().toString(),
      norm,
    );

    final updatedData = _ARAnchorData(
      id: rayAnchor.id,
      worldX: rayAnchor.worldX,
      worldY: rayAnchor.worldY,
      worldZ: rayAnchor.worldZ,
      screenPosition: norm,
      isNative: false,
    );

    setState(() {
      if (_activeDragType == _DragTargetType.activeStart && _activeStartAnchor != null) {
        _activeStartAnchor = updatedData;
      } else if (_activeDragType == _DragTargetType.segmentStart && _activeDragSegmentIndex != null) {
        _lockedSegments[_activeDragSegmentIndex!].start = updatedData;
        _lockedSegments[_activeDragSegmentIndex!].recalculate(_unit);
      } else if (_activeDragType == _DragTargetType.segmentEnd && _activeDragSegmentIndex != null) {
        _lockedSegments[_activeDragSegmentIndex!].end = updatedData;
        _lockedSegments[_activeDragSegmentIndex!].recalculate(_unit);
      }
    });
  }

  void _handlePanEnd() {
    if (_activeDragType != _DragTargetType.none) {
      HapticFeedback.lightImpact();
      setState(() {
        _activeDragType = _DragTargetType.none;
        _activeDragSegmentIndex = null;
        _selectedAnchorIndex = null;
      });
    }
  }

  void _handleScreenTap(Offset localPos, Size size) {
    _onPlusButtonTapped();
  }

  void _undo() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_activeStartAnchor != null) {
        if (_activeStartAnchor!.isNative) {
          ARPlatformBridge().removeNativeAnchor(_activeStartAnchor!.id);
        }
        _activeStartAnchor = null;
      } else if (_lockedSegments.isNotEmpty) {
        final removed = _lockedSegments.removeLast();
        if (removed.start.isNative) ARPlatformBridge().removeNativeAnchor(removed.start.id);
        if (removed.end.isNative) ARPlatformBridge().removeNativeAnchor(removed.end.id);
      }
    });
  }

  void _clearAll() {
    HapticFeedback.lightImpact();
    ARPlatformBridge().clearAllNativeAnchors();
    setState(() {
      _activeStartAnchor = null;
      _lockedSegments.clear();
      _selectedAnchorIndex = null;
    });
  }

  Future<void> _toggleTorch() async {
    final newState = await ARPlatformBridge().toggleTorch();
    if (!mounted) return;
    setState(() => _isTorchOn = newState);
  }

  void _showSurfacePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.straighten_rounded, color: Color(0xFF60A5FA), size: 22),
                  SizedBox(width: 8),
                  Text('Surface Distance & Plane Calibration', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _useNativeARCore
                    ? 'Engine: Google ARCore (Planes: $_planesCount, Surface: $_surfaceType)'
                    : 'Engine: Optical Depth Raycasting (Select surface height):',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              for (final preset in SurfacePreset.values)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: _spatialTracker.surfacePreset == preset ? const Color(0xFF2563EB).withValues(alpha: 0.25) : Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _spatialTracker.surfacePreset == preset ? const Color(0xFF3B82F6) : Colors.white12,
                      width: _spatialTracker.surfacePreset == preset ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(preset.icon, color: _spatialTracker.surfacePreset == preset ? const Color(0xFF60A5FA) : Colors.white60),
                    title: Text(preset.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('~${(preset.distanceMeters * 100).toStringAsFixed(0)} cm surface elevation', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: _spatialTracker.surfacePreset == preset ? const Icon(Icons.check_circle_rounded, color: Color(0xFF60A5FA)) : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _spatialTracker.setSurfacePreset(preset);
                        for (final s in _lockedSegments) {
                          s.recalculate(_unit);
                        }
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnitPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnitSelectorSheet(
        currentUnit: _unit,
        onSelected: (u) {
          setState(() {
            _unit = u;
            for (final seg in _lockedSegments) {
              seg.recalculate(u);
            }
          });
        },
      ),
    );
  }

  void _snapAndSaveMeasurement() {
    if (_lockedSegments.isEmpty && _activeStartAnchor == null) return;
    HapticFeedback.heavyImpact();

    double totalDist = 0.0;
    for (final seg in _lockedSegments) {
      totalDist += seg.distanceMeters;
    }

    final secondary = <String, dynamic>{
      'Segments Count': _lockedSegments.length,
      'AR Engine': _useNativeARCore ? 'Google ARCore Plane Detection' : 'Optical 3D Raycasting',
      'Planes Count': _planesCount,
    };
    for (int i = 0; i < _lockedSegments.length; i++) {
      secondary['Segment #${i + 1}'] = _lockedSegments[i].label;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeasurementSummarySheet(
        toolType: widget.initialTool,
        primaryValue: totalDist,
        distanceUnit: _unit,
        formattedValue: _unit.formatMeters(totalDist),
        secondaryValues: secondary,
        confidence: _useNativeARCore && _isSurfaceDetected ? TrackingConfidence.high : TrackingConfidence.medium,
        uncertaintyPercent: _useNativeARCore ? 0.5 : 1.2,
        capabilityUsed: _useNativeARCore ? 'Google ARCore Hardware Planes' : 'Optical Depth Raycasting',
      ),
    );
  }

  String get _topInstructionText {
    if (_useNativeARCore && !_canPlacePoint) {
      return _surfaceStatusMessage; // tracking guidance from ARCore ("Move your phone slowly", …)
    } else if (_useNativeARCore && _rangeHint.isNotEmpty) {
      return _rangeHint;
    } else if (_activeStartAnchor != null) {
      return 'Move to end point & tap +';
    } else if (_lockedSegments.isNotEmpty) {
      double total = 0.0;
      for (final s in _lockedSegments) {
        total += s.distanceMeters;
      }
      return 'Total: ${_unit.formatMeasurement(total)} (${_lockedSegments.length} seg)';
    } else if (_useNativeARCore) {
      return _isSurfaceDetected ? 'Surface detected • Ready to measure' : 'Move camera slowly to detect surfaces';
    } else {
      return 'Ready to measure • Tap + to start';
    }
  }

  @override
  Widget build(BuildContext context) {
    // If checking camera permission or permission was denied
    if (_isCheckingPermission) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (!_hasCameraPermission) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('Camera Permission'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.videocam_off_rounded, color: Color(0xFF60A5FA), size: 40),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Camera Access Required',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Smart Measure requires camera permission to detect real-world surfaces and measure objects accurately using AR.',
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    final granted = await ARPlatformBridge().requestCameraPermission();
                    if (granted) {
                      _initMeasurementSystem();
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Grant Camera Permission', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Content View based on active dock tab (0 = Measure, 1 = Level)
          // Measure stays mounted under Level: unmounting the AndroidView would close the ARCore
          // session and lose every anchor.
          Offstage(offstage: _activeDockTab != 0, child: _buildMeasureView(bottomInset)),
          if (_activeDockTab == 1) _buildLevelView(bottomInset),

          // 2. Persistent Bottom Dock: [ Measure ] and [ Level ] (Non-overlapping above navigation bar)
          Positioned(
            bottom: bottomInset > 0 ? bottomInset + 10 : 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Measure Tab
                    _buildDockTab(
                      label: 'Measure',
                      icon: Icons.straighten_rounded,
                      isSelected: _activeDockTab == 0,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _activeDockTab = 0);
                      },
                    ),

                    // Level Tab
                    _buildDockTab(
                      label: 'Level',
                      icon: Icons.architecture_rounded,
                      isSelected: _activeDockTab == 1,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _activeDockTab = 1);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MEASURE VIEW (ARCore Native Preview + 60 FPS Apple Measure Overlay) ---

  Widget _buildMeasureView(double bottomInset) {
    final size = MediaQuery.of(context).size;
    final reticleCenter = Offset(size.width * 0.5, size.height * 0.5);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Camera Feed: Native ARCore AndroidView OR Flutter CameraPreview fallback
        if (_useNativeARCore)
          AndroidView(
            viewType: 'com.utility.app/smart_measure_ar_view',
            onPlatformViewCreated: _onPlatformViewCreated,
          )
        else if (_isCameraReady && _cameraController != null)
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),

        // 2. Interactive Gesture Area with AnimatedBuilder for 60 FPS fluid rendering
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) => _handleScreenTap(details.localPosition, size),
            onPanStart: (details) => _handlePanStart(details.localPosition, size),
            onPanUpdate: (details) => _handlePanUpdate(details.localPosition, size),
            onPanEnd: (_) => _handlePanEnd(),
            child: AnimatedBuilder(
              animation: _spatialTracker,
              builder: (context, _) {
                // Project active start anchor to screen
                Offset? activeStartScreenPos;
                String? liveDistanceLabel;

                if (_activeStartAnchor != null && _activeStartAnchor!.visible) {
                  activeStartScreenPos = Offset(
                    _activeStartAnchor!.screenPosition.dx * size.width,
                    _activeStartAnchor!.screenPosition.dy * size.height,
                  );

                  // Compute live 3D distance from active start point to center reticle
                  double? liveDist;
                  if (_useNativeARCore) {
                    // Start anchor's current pose -> smoothed, dead-banded reticle hit.
                    // No stable hit = no number, rather than a guessed one.
                    if (_reticleWorldX != null && _reticleWorldY != null && _reticleWorldZ != null) {
                      final dx = _reticleWorldX! - _activeStartAnchor!.worldX;
                      final dy = _reticleWorldY! - _activeStartAnchor!.worldY;
                      final dz = _reticleWorldZ! - _activeStartAnchor!.worldZ;
                      liveDist = math.sqrt(dx * dx + dy * dy + dz * dz);
                    }
                  } else {
                    final currentReticleAnchor = _spatialTracker.createAnchorAtScreenPoint(
                      'reticle_temp',
                      const Offset(0.5, 0.5),
                    );
                    final dx = currentReticleAnchor.worldX - _activeStartAnchor!.worldX;
                    final dy = currentReticleAnchor.worldY - _activeStartAnchor!.worldY;
                    final dz = currentReticleAnchor.worldZ - _activeStartAnchor!.worldZ;
                    liveDist = math.sqrt(dx * dx + dy * dy + dz * dz);
                  }

                  if (liveDist != null) {
                    liveDistanceLabel = _unit.formatMeasurement(liveDist);
                  }
                }

                // Project locked segments and endpoints
                final renderedSegments = <RenderedMeasurementSegment>[];
                final renderedAnchors = <Offset>[];

                for (int i = 0; i < _lockedSegments.length; i++) {
                  final seg = _lockedSegments[i];
                  if (!seg.start.visible || !seg.end.visible) continue;
                  final sPx = Offset(seg.start.screenPosition.dx * size.width, seg.start.screenPosition.dy * size.height);
                  final ePx = Offset(seg.end.screenPosition.dx * size.width, seg.end.screenPosition.dy * size.height);

                  renderedSegments.add(
                    RenderedMeasurementSegment(
                      start: sPx,
                      end: ePx,
                      label: seg.label,
                      isSelected: _activeDragSegmentIndex == i,
                    ),
                  );

                  renderedAnchors.add(sPx);
                  renderedAnchors.add(ePx);
                }

                return CustomPaint(
                  painter: MeasurementOverlayPainter(
                    segments: renderedSegments,
                    anchorPoints: renderedAnchors,
                    activeStartPoint: activeStartScreenPos,
                    reticleCenter: reticleCenter,
                    activeDistanceLabel: liveDistanceLabel,
                    selectedAnchorIndex: _selectedAnchorIndex,
                  ),
                );
              },
            ),
          ),
        ),

        // 3. Small Measure-style aiming reticle (bright when on a real surface)
        IgnorePointer(child: ARReticle(isLockedOnSurface: _isSurfaceDetected)),

        // 4. Top Header Controls (Undo, Center Instruction with indicator, Unit, Torch, Trash)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 14,
          right: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top-Left: Undo circular button
              _buildCircularIconButton(
                icon: Icons.undo_rounded,
                onTap: (_activeStartAnchor != null || _lockedSegments.isNotEmpty) ? _undo : null,
                tooltip: 'Undo',
              ),

              // Top-Center: Apple Measure style instruction capsule
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isSurfaceDetected ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _isSurfaceDetected ? const Color(0xFF10B981) : Colors.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _topInstructionText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isSurfaceDetected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: _isSurfaceDetected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Top-Right: Torch, Unit selector & Trash/Clear
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flashlight (Flutter camera fallback only: ARCore owns the camera in native mode)
                  if (!_useNativeARCore) ...[
                    _buildCircularIconButton(
                      icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      onTap: _toggleTorch,
                      tooltip: 'Torch',
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Unit pill
                  GestureDetector(
                    onTap: _showUnitPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.60),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _unit.symbol,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Trash / Clear button
                  _buildCircularIconButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: (_activeStartAnchor != null || _lockedSegments.isNotEmpty) ? _clearAll : null,
                    tooltip: 'Clear All',
                  ),
                ],
              ),
            ],
          ),
        ),

        // 5. Bottom Controls (Non-overlapping above navigation buttons)
        Positioned(
          bottom: bottomInset > 0 ? bottomInset + 78 : 84,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: size.width,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center Large Circular (+) Button (diameter 74dp)
                  GestureDetector(
                    onTap: _onPlusButtonTapped,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: (!_useNativeARCore || _canPlacePoint) ? 1.0 : 0.35,
                      child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.28),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                    ),
                  ),

                  // Right Camera Shutter Button (diameter 56dp)
                  Positioned(
                    right: 32,
                    child: GestureDetector(
                      onTap: _snapAndSaveMeasurement,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Left Tools Menu Button (Access all 15 tools)
                  Positioned(
                    left: 32,
                    child: _buildCircularIconButton(
                      icon: Icons.apps_rounded,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SmartMeasureDashboardScreen()),
                        );
                        // A screen opened from there (e.g. another Measure) may have re-pointed the
                        // shared bridge at its own AR view; point it back at ours.
                        final id = _nativeViewId;
                        if (mounted && id != null) ARPlatformBridge().setNativeViewId(id);
                      },
                      tooltip: 'All 15 Tools',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- LEVEL VIEW (Seamless Apple Measure Spirit Level tab) ---

  Widget _buildLevelView(double bottomInset) {
    final activeColor = _isLevelAligned ? const Color(0xFF10B981) : Colors.white;

    return Container(
      color: _isLevelAligned ? const Color(0xFF064E3B) : Colors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Digital readout in degrees
            Text(
              '${_levelTotalTiltDeg.toStringAsFixed(0)}°',
              style: TextStyle(
                color: activeColor,
                fontSize: 88,
                fontWeight: FontWeight.w200,
                letterSpacing: -2,
              ),
            ),
            Text(
              _isLevelAligned ? 'LEVEL' : 'ALIGN DEVICE',
              style: TextStyle(
                color: activeColor.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),

            // Bullseye Level Circles
            Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: CustomPaint(
                  painter: _InlineLevelPainter(
                    rollDeg: _levelRollDeg,
                    pitchDeg: _levelPitchDeg,
                    isLevel: _isLevelAligned,
                    activeColor: activeColor,
                  ),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(height: bottomInset > 0 ? bottomInset + 76 : 84),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    String? tooltip,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.60),
          border: Border.all(color: Colors.white.withValues(alpha: isEnabled ? 0.25 : 0.08)),
        ),
        child: Center(
          child: Icon(
            icon,
            color: isEnabled ? Colors.white : Colors.white24,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildDockTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.24) : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineLevelPainter extends CustomPainter {
  final double rollDeg;
  final double pitchDeg;
  final bool isLevel;
  final Color activeColor;

  _InlineLevelPainter({
    required this.rollDeg,
    required this.pitchDeg,
    required this.isLevel,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer target circle
    final targetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 10, targetPaint);

    // Inner target zero ring
    final centerRingPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, 40.0, centerRingPaint);

    // Moving bubble circle
    final maxDisp = radius - 45;
    final dx = (rollDeg / 20.0).clamp(-1.0, 1.0) * maxDisp;
    final dy = (pitchDeg / 20.0).clamp(-1.0, 1.0) * maxDisp;
    final bubblePos = Offset(center.dx + dx, center.dy + dy);

    final bubblePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bubblePos, 36.0, bubblePaint);

    final centerDotPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bubblePos, 4.0, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _InlineLevelPainter oldDelegate) {
    return oldDelegate.rollDeg != rollDeg || oldDelegate.pitchDeg != pitchDeg || oldDelegate.isLevel != isLevel;
  }
}
