import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/measurement_units.dart';
import '../models/measurement_types.dart';
import '../models/smart_measure_capability.dart';
import '../services/spatial_anchor_tracker.dart';
import '../services/ar_platform_bridge.dart';
import 'painters/measurement_overlay_painter.dart';
import 'mode_screens/digital_level_screen.dart';
import 'widgets/measurement_summary_sheet.dart';
import 'widgets/unit_selector_sheet.dart';
import 'smart_measure_dashboard_screen.dart';

/// Apple Measure inspired live camera measurement screen (Reference: Image 2).
class ARMeasurementScreen extends StatefulWidget {
  final SmartMeasureToolType initialTool;

  const ARMeasurementScreen({
    super.key,
    this.initialTool = SmartMeasureToolType.quickMeasure,
  });

  @override
  State<ARMeasurementScreen> createState() => _ARMeasurementScreenState();
}

class _LockedSegment {
  final SpatialAnchor start;
  final SpatialAnchor end;
  final double distanceMeters;
  final String label;

  const _LockedSegment({
    required this.start,
    required this.end,
    required this.distanceMeters,
    required this.label,
  });
}

class _ARMeasurementScreenState extends State<ARMeasurementScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraReady = false;

  // Spatial Sensor Tracker
  final SpatialAnchorTracker _spatialTracker = SpatialAnchorTracker();

  // Anchors and Segments
  SpatialAnchor? _activeStartAnchor;
  final List<_LockedSegment> _lockedSegments = [];
  final List<_LockedSegment> _undoHistory = [];

  // Units
  DistanceUnit _unit = DistanceUnit.centimeter;
  bool _isTorchOn = false;

  // Bottom dock mode: 0 = Measure, 1 = Level
  int _activeDockTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSensorsAndCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _spatialTracker.stopTracking();
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

  void _onPlusButtonTapped() {
    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    final currentAnchor = SpatialAnchor(
      id: UniqueKey().toString(),
      yawDeg: _spatialTracker.currentYawDeg,
      pitchDeg: _spatialTracker.currentPitchDeg,
      rollDeg: _spatialTracker.currentRollDeg,
      depthMeters: _spatialTracker.currentDepthMeters,
      createdAt: now,
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
        onSelected: (u) => setState(() => _unit = u),
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
      return 'Measurement complete. Tap + to measure more';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final reticleCenter = Offset(size.width * 0.5, size.height * 0.5);

    // Project active start anchor to screen
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

    for (final seg in _lockedSegments) {
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

      renderedSegments.add(
        RenderedMeasurementSegment(
          start: sPx,
          end: ePx,
          label: seg.label,
        ),
      );

      renderedAnchors.add(sPx);
      renderedAnchors.add(ePx);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
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

          // 2. Apple Measure Style Measurement Overlay (Image 2)
          Positioned.fill(
            child: CustomPaint(
              painter: MeasurementOverlayPainter(
                segments: renderedSegments,
                anchorPoints: renderedAnchors,
                activeStartPoint: activeStartScreenPos,
                reticleCenter: reticleCenter,
                activeDistanceLabel: liveDistanceLabel,
              ),
            ),
          ),

          // 3. Apple Measure Aiming Reticle (Subtle center dot & ring)
          Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
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

          // 4. Top Controls (Matching Image 2)
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
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        _topInstructionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                // Top-Right: Unit selector & Trash/Clear button & Torch
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flashlight
                    _buildCircularIconButton(
                      icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      onTap: _toggleTorch,
                      tooltip: 'Torch',
                    ),
                    const SizedBox(width: 8),

                    // Unit pill
                    GestureDetector(
                      onTap: _showUnitPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
                    const SizedBox(width: 8),

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

                    // Left Tools Menu Button
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

          // 6. Bottom Dock: [ Measure ] and [ Level ] Tabs (Exact Apple Measure layout in Image 2)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
                        setState(() => _activeDockTab = 0);
                      },
                    ),

                    // Level Tab
                    _buildDockTab(
                      label: 'Level',
                      icon: Icons.architecture_rounded,
                      isSelected: _activeDockTab == 1,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DigitalLevelScreen()),
                        );
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
          color: Colors.black.withValues(alpha: 0.55),
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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
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
