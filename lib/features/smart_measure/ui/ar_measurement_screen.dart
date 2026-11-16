import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
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
import 'smart_measure_dashboard_screen.dart';

/// Apple / iPhone Measure inspired live camera measurement screen.
/// Implements dynamic dotted tracking line, 3D AR spatial world anchoring,
/// and auto-orienting measurement labels that follow the line angle.
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

class _LockedSegment {
  SpatialAnchor start;
  SpatialAnchor end;
  double distanceMeters;
  String label;
  bool isSelected;

  _LockedSegment({
    required this.start,
    required this.end,
    required this.distanceMeters,
    required this.label,
    this.isSelected = false,
  });

  void recalculate(DistanceUnit unit) {
    distanceMeters = start.distanceTo(
      targetYawDeg: end.yawDeg,
      targetPitchDeg: end.pitchDeg,
      targetDepthMeters: end.depthMeters,
    );
    label = unit.formatMeters(distanceMeters, decimals: distanceMeters < 0.1 ? 1 : 0);
  }
}

class _ARMeasurementScreenState extends State<ARMeasurementScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraReady = false;

  // Spatial Sensor Tracker (Gyroscope + Accelerometer fusion)
  final SpatialAnchorTracker _spatialTracker = SpatialAnchorTracker();

  // Anchors and Segments
  SpatialAnchor? _activeStartAnchor;
  final List<_LockedSegment> _lockedSegments = [];
  final List<_LockedSegment> _undoHistory = [];

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
    _initSensorsAndCamera();
    _startLevelSensors();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _spatialTracker.stopTracking();
    _levelAccelSub?.cancel();
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
      _initCamera();
    }
  }

  Future<void> _initSensorsAndCamera() async {
    _spatialTracker.startTracking(onUpdate: () {
      if (mounted) setState(() {});
    });

    await _initCamera();
  }

  Future<void> _initCamera() async {
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
      debugPrint('Camera init error: $e');
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

  // --- Point Creation & Interaction ---

  void _onPlusButtonTapped() {
    HapticFeedback.mediumImpact();

    final currentAnchor = SpatialAnchor(
      id: UniqueKey().toString(),
      yawDeg: _spatialTracker.currentYawDeg,
      pitchDeg: _spatialTracker.currentPitchDeg,
      rollDeg: _spatialTracker.currentRollDeg,
      depthMeters: _spatialTracker.currentDepthMeters,
      createdAt: DateTime.now(),
    );

    setState(() {
      if (_activeStartAnchor == null) {
        // Step 1: Start measuring from current reticle position
        _activeStartAnchor = currentAnchor;
      } else {
        // Step 2: Lock segment between start anchor and current position
        final dist = _activeStartAnchor!.distanceTo(
          targetYawDeg: currentAnchor.yawDeg,
          targetPitchDeg: currentAnchor.pitchDeg,
          targetDepthMeters: currentAnchor.depthMeters,
        );

        final label = _unit.formatMeters(dist, decimals: dist < 0.1 ? 1 : 0);

        _lockedSegments.add(
          _LockedSegment(
            start: _activeStartAnchor!,
            end: currentAnchor,
            distanceMeters: dist,
            label: label,
          ),
        );

        _activeStartAnchor = null;
      }
    });
  }

  // --- Pan / Dragging Points on Screen ---

  void _handlePanStart(Offset localPos, Size size, Offset? activeStartPx, List<Offset> segStarts, List<Offset> segEnds) {
    const hitRadius = 40.0;

    // Check active start anchor
    if (activeStartPx != null && (localPos - activeStartPx).distance <= hitRadius) {
      HapticFeedback.selectionClick();
      setState(() {
        _activeDragType = _DragTargetType.activeStart;
        _selectedAnchorIndex = 999;
      });
      return;
    }

    // Check locked segments
    for (int i = _lockedSegments.length - 1; i >= 0; i--) {
      if (i < segEnds.length && (localPos - segEnds[i]).distance <= hitRadius) {
        HapticFeedback.selectionClick();
        setState(() {
          _activeDragType = _DragTargetType.segmentEnd;
          _activeDragSegmentIndex = i;
          _selectedAnchorIndex = i * 2 + 1;
        });
        return;
      }
      if (i < segStarts.length && (localPos - segStarts[i]).distance <= hitRadius) {
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

    final newAnchor = SpatialAnchor.fromScreenPoint(
      id: UniqueKey().toString(),
      normalizedScreen: norm,
      currentYawDeg: _spatialTracker.currentYawDeg,
      currentPitchDeg: _spatialTracker.currentPitchDeg,
      currentRollDeg: _spatialTracker.currentRollDeg,
      depthMeters: _spatialTracker.currentDepthMeters,
    );

    setState(() {
      if (_activeDragType == _DragTargetType.activeStart && _activeStartAnchor != null) {
        _activeStartAnchor = newAnchor;
      } else if (_activeDragType == _DragTargetType.segmentStart && _activeDragSegmentIndex != null) {
        _lockedSegments[_activeDragSegmentIndex!].start = newAnchor;
        _lockedSegments[_activeDragSegmentIndex!].recalculate(_unit);
      } else if (_activeDragType == _DragTargetType.segmentEnd && _activeDragSegmentIndex != null) {
        _lockedSegments[_activeDragSegmentIndex!].end = newAnchor;
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
    // If user taps anywhere on screen, add or advance measurement
    _onPlusButtonTapped();
  }

  void _undo() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_activeStartAnchor != null) {
        _activeStartAnchor = null;
      } else if (_lockedSegments.isNotEmpty) {
        _undoHistory.add(_lockedSegments.removeLast());
      }
    });
  }

  void _clearAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _activeStartAnchor = null;
      _lockedSegments.clear();
      _undoHistory.clear();
      _selectedAnchorIndex = null;
    });
  }

  Future<void> _toggleTorch() async {
    final newState = await ARPlatformBridge().toggleTorch();
    setState(() => _isTorchOn = newState);
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
        confidence: TrackingConfidence.high,
        uncertaintyPercent: 1.0,
        capabilityUsed: 'Apple-Style 3D Spatial Tracking',
      ),
    );
  }

  String get _topInstructionText {
    if (_activeStartAnchor == null && _lockedSegments.isEmpty) {
      return 'Find a nearby surface to measure';
    } else if (_activeStartAnchor != null) {
      return 'Move to end point & tap +';
    } else {
      double total = 0.0;
      for (final s in _lockedSegments) {
        total += s.distanceMeters;
      }
      return 'Total: ${_unit.formatMeters(total)} (${_lockedSegments.length} seg)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Content View based on active dock tab (0 = Measure, 1 = Level)
          if (_activeDockTab == 0) _buildMeasureView() else _buildLevelView(),

          // 2. Persistent Bottom Dock: [ Measure ] and [ Level ]
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
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

  // --- MEASURE VIEW (Apple Measure UI with Dotted Tracking Line) ---

  Widget _buildMeasureView() {
    final size = MediaQuery.of(context).size;
    final reticleCenter = Offset(size.width * 0.5, size.height * 0.5);

    // Project active start anchor to 2D screen coordinate
    Offset? activeStartScreenPos;
    String? liveDistanceLabel;

    if (_activeStartAnchor != null) {
      activeStartScreenPos = _activeStartAnchor!.projectToScreen(
        currentYawDeg: _spatialTracker.currentYawDeg,
        currentPitchDeg: _spatialTracker.currentPitchDeg,
        currentRollDeg: _spatialTracker.currentRollDeg,
      );
      activeStartScreenPos = Offset(
        activeStartScreenPos.dx * size.width,
        activeStartScreenPos.dy * size.height,
      );

      final liveDist = _activeStartAnchor!.distanceTo(
        targetYawDeg: _spatialTracker.currentYawDeg,
        targetPitchDeg: _spatialTracker.currentPitchDeg,
        targetDepthMeters: _spatialTracker.currentDepthMeters,
      );

      // Clean Apple Measure label: e.g. "4 cm"
      liveDistanceLabel = _unit.formatMeters(liveDist, decimals: liveDist < 0.1 ? 1 : 0);
    }

    // Project locked segments and endpoints to screen
    final renderedSegments = <RenderedMeasurementSegment>[];
    final renderedAnchors = <Offset>[];
    final segStarts = <Offset>[];
    final segEnds = <Offset>[];

    for (int i = 0; i < _lockedSegments.length; i++) {
      final seg = _lockedSegments[i];
      final sNorm = seg.start.projectToScreen(
        currentYawDeg: _spatialTracker.currentYawDeg,
        currentPitchDeg: _spatialTracker.currentPitchDeg,
        currentRollDeg: _spatialTracker.currentRollDeg,
      );
      final eNorm = seg.end.projectToScreen(
        currentYawDeg: _spatialTracker.currentYawDeg,
        currentPitchDeg: _spatialTracker.currentPitchDeg,
        currentRollDeg: _spatialTracker.currentRollDeg,
      );

      final sPx = Offset(sNorm.dx * size.width, sNorm.dy * size.height);
      final ePx = Offset(eNorm.dx * size.width, eNorm.dy * size.height);

      segStarts.add(sPx);
      segEnds.add(ePx);

      renderedSegments.add(
        RenderedMeasurementSegment(
          start: sPx,
          end: ePx,
          label: seg.label,
          isSelected: seg.isSelected,
        ),
      );

      renderedAnchors.add(sPx);
      renderedAnchors.add(ePx);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Live Camera Preview
        if (_isCameraReady && _cameraController != null)
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

        // 2. Interactive Gesture Area for Screen Tap & Anchor Dragging
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) => _handleScreenTap(details.localPosition, size),
            onPanStart: (details) => _handlePanStart(details.localPosition, size, activeStartScreenPos, segStarts, segEnds),
            onPanUpdate: (details) => _handlePanUpdate(details.localPosition, size),
            onPanEnd: (_) => _handlePanEnd(),
            child: CustomPaint(
              painter: MeasurementOverlayPainter(
                segments: renderedSegments,
                anchorPoints: renderedAnchors,
                activeStartPoint: activeStartScreenPos,
                reticleCenter: reticleCenter,
                activeDistanceLabel: liveDistanceLabel,
                selectedAnchorIndex: _selectedAnchorIndex,
              ),
            ),
          ),
        ),

        // 3. Apple Measure Aiming Reticle (Center dot with subtle ring)
        Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),

        // 4. Top Header Controls (Matching Image 2 Reference)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top-Left: Undo circular button
              _buildCircularIconButton(
                icon: Icons.undo_rounded,
                onTap: (_activeStartAnchor != null || _lockedSegments.isNotEmpty) ? _undo : null,
                tooltip: 'Undo',
              ),

              // Top-Center: Translucent instruction capsule
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: Text(
                      _topInstructionText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // Top-Right: Torch, Unit selector & Trash/Clear
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flashlight
                  _buildCircularIconButton(
                    icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    onTap: _toggleTorch,
                    tooltip: 'Torch',
                  ),
                  const SizedBox(width: 6),

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
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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

        // 5. Bottom Controls (Apple Measure style large + button & Shutter)
        Positioned(
          bottom: 74,
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SmartMeasureDashboardScreen()),
                        );
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

  Widget _buildLevelView() {
    final activeColor = _isLevelAligned ? const Color(0xFF10B981) : Colors.white;

    return Container(
      color: _isLevelAligned ? const Color(0xFF064E3B) : Colors.black,
      child: SafeArea(
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
            const SizedBox(height: 80),
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
