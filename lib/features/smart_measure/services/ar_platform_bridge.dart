import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/smart_measure_capability.dart';
import '../models/smart_measure_point.dart';

/// Bridge between Flutter UI and native ARCore (Android) / ARKit (iOS) / Desktop fallback.
class ARPlatformBridge {
  static const MethodChannel _channel = MethodChannel('com.utility.app/smart_measure_ar');

  static final ARPlatformBridge _instance = ARPlatformBridge._internal();
  factory ARPlatformBridge() => _instance;
  ARPlatformBridge._internal();

  SmartMeasureCapability? _cachedCapability;
  CameraController? _activeCameraController;
  bool _isTorchOn = false;

  /// Check and retrieve device capabilities across Android, iOS, and Desktop platforms.
  Future<SmartMeasureCapability> checkCapabilities() async {
    if (_cachedCapability != null) return _cachedCapability!;

    if (kIsWeb) {
      _cachedCapability = SmartMeasureCapability.fallback(platform: 'web');
      return _cachedCapability!;
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _cachedCapability = SmartMeasureCapability.fallback(
        platform: Platform.operatingSystem,
        hasMotionSensors: false,
      );
      return _cachedCapability!;
    }

    // Mobile platforms: query native channel
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkCapabilities');
      if (res != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(res);
        _cachedCapability = SmartMeasureCapability.fromNative(data);
        return _cachedCapability!;
      }
    } catch (e) {
      debugPrint('ARPlatformBridge checkCapabilities error: $e');
    }

    // Default fallback if native query failed
    _cachedCapability = SmartMeasureCapability.fallback(
      platform: Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown'),
      hasMotionSensors: true,
    );
    return _cachedCapability!;
  }

  /// Request ARCore installation on Android devices if supported but not installed.
  Future<String?> requestInstallARCore() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<String>('requestInstallARCore');
      } catch (e) {
        debugPrint('Error requesting ARCore install: $e');
      }
    }
    return null;
  }

  /// Set the active camera controller for hardware control (torch, focus, exposure).
  void setActiveCameraController(CameraController? controller) {
    _activeCameraController = controller;
    _isTorchOn = false;
  }

  bool get isTorchOn => _isTorchOn;

  /// Toggle torch / flashlight if supported by device.
  Future<bool> toggleTorch() async {
    if (_activeCameraController == null || !_activeCameraController!.value.isInitialized) {
      return false;
    }
    try {
      if (_isTorchOn) {
        await _activeCameraController!.setFlashMode(FlashMode.off);
        _isTorchOn = false;
      } else {
        await _activeCameraController!.setFlashMode(FlashMode.torch);
        _isTorchOn = true;
      }
      return _isTorchOn;
    } catch (e) {
      debugPrint('Torch error: $e');
      return false;
    }
  }

  /// Perform raycast hit-test from screen coordinate (0.0 to 1.0) into the real-world scene.
  /// If native AR session is active, queries ARCore/ARKit hit-test pose.
  /// Otherwise, computes geometric perspective depth projection based on camera tilt,
  /// estimated ground plane, or depth calibration.
  Future<SmartMeasurePoint> raycastHitTest({
    required Offset normalizedScreenPos,
    required double cameraPitchDegrees,
    required double cameraRollDegrees,
    required double estimatedDeviceHeightMeters,
    required double currentFocalScale,
    PlaneType assumedPlane = PlaneType.horizontalDownward,
  }) async {
    // 1. Check if device supports native AR hit-test
    final cap = await checkCapabilities();
    if (cap.canUseLiveAR) {
      try {
        final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('raycastHitTest', {
          'x': normalizedScreenPos.dx,
          'y': normalizedScreenPos.dy,
        });
        if (res != null) {
          return SmartMeasurePoint(
            id: UniqueKey().toString(),
            x: (res['x'] as num).toDouble(),
            y: (res['y'] as num).toDouble(),
            z: (res['z'] as num).toDouble(),
            screenPosition: normalizedScreenPos,
            timestamp: DateTime.now(),
            planeType: assumedPlane,
            confidence: (res['confidence'] as num?)?.toDouble() ?? 0.95,
            depthMeters: (res['depth'] as num?)?.toDouble() ?? 1.5,
          );
        }
      } catch (_) {
        // Native AR hit-test fallback to geometric optical raycast
      }
    }

    // 2. Optical Geometric Pinhole Raycast (Accurate Ground & Object Depth Trigonometry):
    // Standard phone camera FOV: ~60° horizontal, ~75° vertical.
    // Screen center is (0.5, 0.5).
    final vFovRad = 70.0 * (math.pi / 180.0);
    final hFovRad = 55.0 * (math.pi / 180.0);

    // Angle offset from camera optical center
    final deltaYAngle = (0.5 - normalizedScreenPos.dy) * vFovRad;
    final deltaXAngle = (normalizedScreenPos.dx - 0.5) * hFovRad;

    // Total downward elevation angle relative to horizontal ground
    final totalDownAngle = (cameraPitchDegrees * (math.pi / 180.0)) - deltaYAngle;

    double depth;
    double worldX;
    double worldY;
    double worldZ;

    // Ground plane trigonometry: h / sin(angle)
    if (totalDownAngle > 0.08 && assumedPlane == PlaneType.horizontalDownward) {
      // Ray intersects ground plane at distance D = H / sin(totalDownAngle)
      final groundDistance = estimatedDeviceHeightMeters / math.tan(totalDownAngle);
      depth = math.sqrt(groundDistance * groundDistance + estimatedDeviceHeightMeters * estimatedDeviceHeightMeters);
      worldZ = groundDistance;
      worldX = groundDistance * math.tan(deltaXAngle);
      worldY = -estimatedDeviceHeightMeters;
    } else {
      // Fixed reference depth plane (e.g. 1.2m default object inspection distance)
      depth = (1.2 * currentFocalScale).clamp(0.2, 10.0);
      worldZ = depth * math.cos(totalDownAngle);
      worldX = depth * math.tan(deltaXAngle);
      worldY = depth * math.sin(-totalDownAngle);
    }

    return SmartMeasurePoint(
      id: UniqueKey().toString(),
      x: worldX,
      y: worldY,
      z: worldZ,
      screenPosition: normalizedScreenPos,
      timestamp: DateTime.now(),
      planeType: assumedPlane,
      confidence: cap.canUseLiveAR ? 0.9 : 0.75,
      depthMeters: depth,
    );
  }
}
