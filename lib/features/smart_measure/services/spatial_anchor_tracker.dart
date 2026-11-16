import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum SurfacePreset {
  desk('Desk / Countertop', 0.35, Icons.table_chart_rounded),
  table('Tabletop / Furniture', 0.60, Icons.table_restaurant_rounded),
  floor('Floor / Ground Plane', 1.20, Icons.border_all_rounded);

  final String label;
  final double distanceMeters;
  final IconData icon;

  const SurfacePreset(this.label, this.distanceMeters, this.icon);
}

/// Represents a spatially anchored point pinned in 3D real-world space.
class SpatialAnchor {
  final String id;
  final double worldX;
  final double worldY;
  final double worldZ;
  final double yawDeg;
  final double pitchDeg;
  final double rollDeg;
  final double depthMeters;
  final DateTime createdAt;

  const SpatialAnchor({
    required this.id,
    required this.worldX,
    required this.worldY,
    required this.worldZ,
    required this.yawDeg,
    required this.pitchDeg,
    required this.rollDeg,
    required this.depthMeters,
    required this.createdAt,
  });

  /// Factory that constructs a 3D SpatialAnchor by intersecting a camera ray
  /// from screen coordinates through the horizontal surface plane at [surfaceHeightMeters].
  static SpatialAnchor fromRayPlane({
    required String id,
    required Offset normalizedScreen,
    required double currentYawDeg,
    required double currentPitchDeg,
    required double currentRollDeg,
    required double surfaceHeightMeters,
    double cameraPosX = 0.0,
    double cameraPosY = 0.0,
    double cameraPosZ = 0.0,
    double fovHorizontalDeg = 58.0,
    double fovVerticalDeg = 75.0,
  }) {
    final fovHRad = fovHorizontalDeg * (math.pi / 180.0);
    final fovVRad = fovVerticalDeg * (math.pi / 180.0);

    // Screen pixel relative to center (-0.5 to 0.5)
    final nx = (normalizedScreen.dx - 0.5).clamp(-0.5, 0.5);
    final ny = (normalizedScreen.dy - 0.5).clamp(-0.5, 0.5);

    // Camera space ray vector
    final tanH = math.tan(fovHRad / 2);
    final tanV = math.tan(fovVRad / 2);

    final rx = nx * (2.0 * tanH);
    final ry = -ny * (2.0 * tanV);
    const rz = 1.0;

    final rayMag = math.sqrt(rx * rx + ry * ry + rz * rz);
    final ux = rx / rayMag;
    final uy = ry / rayMag;
    final uz = rz / rayMag;

    // Rotate camera ray to world frame using yaw and pitch
    final pitchRad = currentPitchDeg * (math.pi / 180.0);
    final yawRad = currentYawDeg * (math.pi / 180.0);

    // Rotate by pitch around X axis
    final pX = ux;
    final pY = uy * math.cos(pitchRad) - uz * math.sin(pitchRad);
    final pZ = uy * math.sin(pitchRad) + uz * math.cos(pitchRad);

    // Rotate by yaw around Y axis
    final wX = pX * math.cos(yawRad) + pZ * math.sin(yawRad);
    final wY = pY;
    final wZ = -pX * math.sin(yawRad) + pZ * math.cos(yawRad);

    // Intersect horizontal ground plane Y = -surfaceHeightMeters
    // Camera is at cameraPosY (0.0). Plane is at -H.
    // Ray: cameraPosY + t * wY = -H  ==>  t = (-H - cameraPosY) / wY
    double t;
    if (wY < -0.05) {
      t = (-surfaceHeightMeters - cameraPosY) / wY;
    } else {
      // Horizontal or upward ray never meets the floor: keep the true ray direction at a nominal
      // distance (flipping wY used to mirror the point above the camera).
      t = surfaceHeightMeters / math.sin(math.max(0.15, pitchRad.abs()));
    }

    t = t.clamp(0.1, 8.0); // Safe bounds between 10cm and 8m

    final worldX = cameraPosX + t * wX;
    final worldY = cameraPosY + t * wY;
    final worldZ = cameraPosZ + t * wZ;

    return SpatialAnchor(
      id: id,
      worldX: worldX,
      worldY: worldY,
      worldZ: worldZ,
      yawDeg: currentYawDeg,
      pitchDeg: currentPitchDeg,
      rollDeg: currentRollDeg,
      depthMeters: t,
      createdAt: DateTime.now(),
    );
  }

  /// Legacy helper for screen-space touch coordinates
  static SpatialAnchor fromScreenPoint({
    required String id,
    required Offset normalizedScreen,
    required double currentYawDeg,
    required double currentPitchDeg,
    required double currentRollDeg,
    required double depthMeters,
    double fovHorizontalDeg = 58.0,
    double fovVerticalDeg = 75.0,
  }) {
    return fromRayPlane(
      id: id,
      normalizedScreen: normalizedScreen,
      currentYawDeg: currentYawDeg,
      currentPitchDeg: currentPitchDeg,
      currentRollDeg: currentRollDeg,
      surfaceHeightMeters: depthMeters * 0.7,
      fovHorizontalDeg: fovHorizontalDeg,
      fovVerticalDeg: fovVerticalDeg,
    );
  }

  /// Project this 3D anchor to 2D normalized screen coordinates (0.0 to 1.0)
  /// given the current camera position and orientation.
  Offset projectToScreen({
    required double currentYawDeg,
    required double currentPitchDeg,
    required double currentRollDeg,
    double cameraPosX = 0.0,
    double cameraPosY = 0.0,
    double cameraPosZ = 0.0,
    double fovHorizontalDeg = 58.0,
    double fovVerticalDeg = 75.0,
  }) {
    // Relative vector from camera to anchor in world space
    final dx = worldX - cameraPosX;
    final dy = worldY - cameraPosY;
    final dz = worldZ - cameraPosZ;

    final yawRad = currentYawDeg * (math.pi / 180.0);
    final pitchRad = currentPitchDeg * (math.pi / 180.0);

    // Inverse Yaw rotation
    final cx = dx * math.cos(-yawRad) + dz * math.sin(-yawRad);
    final cy = dy;
    final cz = -dx * math.sin(-yawRad) + dz * math.cos(-yawRad);

    // Inverse Pitch rotation
    final px = cx;
    final py = cy * math.cos(-pitchRad) - cz * math.sin(-pitchRad);
    final pz = cy * math.sin(-pitchRad) + cz * math.cos(-pitchRad);

    final fovHRad = fovHorizontalDeg * (math.pi / 180.0);
    final fovVRad = fovVerticalDeg * (math.pi / 180.0);

    // If point is in front of camera
    if (pz > 0.05) {
      final tanH = math.tan(fovHRad / 2);
      final tanV = math.tan(fovVRad / 2);

      final screenNormX = 0.5 + (px / (pz * 2.0 * tanH));
      final screenNormY = 0.5 - (py / (pz * 2.0 * tanV));

      return Offset(screenNormX.clamp(-0.2, 1.2), screenNormY.clamp(-0.2, 1.2));
    }

    // Fallback: angular projection if behind or near clip plane
    double deltaYaw = currentYawDeg - yawDeg;
    while (deltaYaw > 180) {
      deltaYaw -= 360;
    }
    while (deltaYaw < -180) {
      deltaYaw += 360;
    }

    double deltaPitch = currentPitchDeg - pitchDeg;
    while (deltaPitch > 180) {
      deltaPitch -= 360;
    }
    while (deltaPitch < -180) {
      deltaPitch += 360;
    }

    double dxNorm = -math.tan(deltaYaw * (math.pi / 180.0)) * (0.5 / math.tan(fovHRad / 2));
    double dyNorm = math.tan(deltaPitch * (math.pi / 180.0)) * (0.5 / math.tan(fovVRad / 2));

    return Offset(0.5 + dxNorm, 0.5 + dyNorm);
  }

  /// True physical 3D distance in meters to another anchor or 3D point.
  double distanceToPoint(SpatialAnchor other) {
    final dx = other.worldX - worldX;
    final dy = other.worldY - worldY;
    final dz = other.worldZ - worldZ;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Helper for live distance to current camera reticle
  double distanceTo({
    required double targetYawDeg,
    required double targetPitchDeg,
    required double targetDepthMeters,
  }) {
    // If other point is defined by angle and depth, compute 3D coordinate
    final pitchRad = targetPitchDeg * (math.pi / 180.0);
    final yawRad = targetYawDeg * (math.pi / 180.0);

    final otherX = targetDepthMeters * math.sin(yawRad) * math.cos(pitchRad);
    final otherY = -targetDepthMeters * math.sin(pitchRad);
    final otherZ = targetDepthMeters * math.cos(yawRad) * math.cos(pitchRad);

    final dx = otherX - worldX;
    final dy = otherY - worldY;
    final dz = otherZ - worldZ;

    return math.sqrt(math.max(0.0001, dx * dx + dy * dy + dz * dz));
  }
}

/// Continuous spatial sensor orientation & surface raycasting tracker.
/// Extends [ChangeNotifier] and throttles updates to 60 FPS for zero UI lag.
class SpatialAnchorTracker extends ChangeNotifier {
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  double currentYawDeg = 0.0;
  double currentPitchDeg = 45.0; // Default 45° downward handheld tilt
  double currentRollDeg = 0.0;

  // Surface Distance (height above table/floor in meters)
  SurfacePreset surfacePreset = SurfacePreset.desk;
  double surfaceHeightMeters = 0.35; // 35 cm typical desk height

  // Estimated camera 3D position
  double cameraPosX = 0.0;
  double cameraPosY = 0.0;
  double cameraPosZ = 0.0;

  DateTime _lastGyroTime = DateTime.now();
  DateTime _lastNotifyTime = DateTime.now();

  void setSurfacePreset(SurfacePreset preset) {
    surfacePreset = preset;
    surfaceHeightMeters = preset.distanceMeters;
    notifyListeners();
  }

  void setCustomSurfaceHeight(double meters) {
    surfaceHeightMeters = meters.clamp(0.15, 4.0);
    notifyListeners();
  }

  void startTracking({VoidCallback? onUpdate}) {
    stopTracking();

    _lastGyroTime = DateTime.now();
    _lastNotifyTime = DateTime.now();

    try {
      _gyroSub = gyroscopeEventStream().listen((event) {
        final now = DateTime.now();
        final dt = (now.difference(_lastGyroTime).inMicroseconds) / 1000000.0;
        _lastGyroTime = now;

        if (dt > 0 && dt < 0.2) {
          // Gyroscope yaw rate around phone Y-axis in portrait
          // Android: +y rate = counter-clockwise seen from above = turning LEFT; our yaw is +right.
          final yawRateDeg = event.y * (180.0 / math.pi);
          currentYawDeg -= yawRateDeg * dt;

          _throttleNotify(onUpdate);
        }
      }, onError: (_) {});
    } catch (_) {}

    try {
      _accelSub = accelerometerEventStream().listen((event) {
        final ax = event.x;
        final ay = event.y;
        final az = event.z;
        final norm = math.sqrt(ax * ax + ay * ay + az * az);

        if (norm > 0.1) {
          // Camera angle below the horizon: upright = 0°, flat face-up = 90°, aiming up < 0.
          final rollRad = math.atan2(ax, math.sqrt(ay * ay + az * az));

          final newPitchDeg = math.atan2(az, math.sqrt(ax * ax + ay * ay)) * (180.0 / math.pi);
          final newRollDeg = rollRad * (180.0 / math.pi);

          // Exponential moving average filter (reduces hand tremors by 80%)
          currentPitchDeg = currentPitchDeg * 0.82 + newPitchDeg * 0.18;
          currentRollDeg = currentRollDeg * 0.82 + newRollDeg * 0.18;

          _throttleNotify(onUpdate);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  /// Throttles UI notifications to 60 FPS (16ms) to prevent UI thread starvation
  void _throttleNotify(VoidCallback? onUpdate) {
    final now = DateTime.now();
    if (now.difference(_lastNotifyTime).inMilliseconds >= 16) {
      _lastNotifyTime = now;
      notifyListeners();
      onUpdate?.call();
    }
  }

  /// Create an anchor intersecting the target surface at the given screen coordinate
  SpatialAnchor createAnchorAtScreenPoint(String id, Offset normalizedScreen) {
    return SpatialAnchor.fromRayPlane(
      id: id,
      normalizedScreen: normalizedScreen,
      currentYawDeg: currentYawDeg,
      currentPitchDeg: currentPitchDeg,
      currentRollDeg: currentRollDeg,
      surfaceHeightMeters: surfaceHeightMeters,
      cameraPosX: cameraPosX,
      cameraPosY: cameraPosY,
      cameraPosZ: cameraPosZ,
    );
  }

  /// Calculates the live 3D surface distance between an existing anchor and the screen reticle
  double liveDistanceToReticle(SpatialAnchor startAnchor, Offset reticleNorm) {
    final currentTargetAnchor = createAnchorAtScreenPoint('temp_reticle', reticleNorm);
    return startAnchor.distanceToPoint(currentTargetAnchor);
  }

  void stopTracking() {
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _gyroSub = null;
    _accelSub = null;
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
