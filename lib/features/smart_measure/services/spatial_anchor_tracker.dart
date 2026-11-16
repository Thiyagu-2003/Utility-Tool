import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Represents a spatially anchored point that stays pinned in real-world 3D space.
class SpatialAnchor {
  final String id;
  final double yawDeg;
  final double pitchDeg;
  final double rollDeg;
  final double depthMeters;
  final DateTime createdAt;

  const SpatialAnchor({
    required this.id,
    required this.yawDeg,
    required this.pitchDeg,
    required this.rollDeg,
    required this.depthMeters,
    required this.createdAt,
  });

  /// Project this anchor to 2D normalized screen coordinates (0.0 to 1.0)
  /// given the current camera orientation.
  Offset projectToScreen({
    required double currentYawDeg,
    required double currentPitchDeg,
    required double currentRollDeg,
    double fovHorizontalDeg = 58.0,
    double fovVerticalDeg = 75.0,
  }) {
    // Angular difference relative to camera heading
    double deltaYaw = currentYawDeg - yawDeg;
    // Normalize to [-180..180]
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

    double deltaRoll = (currentRollDeg - rollDeg) * (math.pi / 180.0);

    final fovHRad = fovHorizontalDeg * (math.pi / 180.0);
    final fovVRad = fovVerticalDeg * (math.pi / 180.0);

    // Perspective projection
    final deltaYawRad = deltaYaw * (math.pi / 180.0);
    final deltaPitchRad = deltaPitch * (math.pi / 180.0);

    // If user pans right (deltaYaw > 0), the anchor on the object moves to the left on screen
    double dxNorm = -math.tan(deltaYawRad) * (0.5 / math.tan(fovHRad / 2));
    // If user tilts up (deltaPitch > 0), the anchor moves down on screen
    double dyNorm = math.tan(deltaPitchRad) * (0.5 / math.tan(fovVRad / 2));

    // Rotate by roll angle
    double rotX = dxNorm * math.cos(deltaRoll) - dyNorm * math.sin(deltaRoll);
    double rotY = dxNorm * math.sin(deltaRoll) + dyNorm * math.cos(deltaRoll);

    return Offset(0.5 + rotX, 0.5 + rotY);
  }

  /// Physical distance in meters from this anchor to another anchor or target.
  double distanceTo({
    required double targetYawDeg,
    required double targetPitchDeg,
    required double targetDepthMeters,
  }) {
    double deltaYaw = (targetYawDeg - yawDeg) * (math.pi / 180.0);
    double deltaPitch = (targetPitchDeg - pitchDeg) * (math.pi / 180.0);

    // Angular separation via spherical law of cosines
    double cosAlpha = (math.cos(deltaPitch) * math.cos(deltaYaw)).clamp(-1.0, 1.0);
    double alpha = math.acos(cosAlpha);

    // Distance = sqrt(D1² + D2² - 2*D1*D2*cos(alpha))
    double dSq = depthMeters * depthMeters +
        targetDepthMeters * targetDepthMeters -
        2 * depthMeters * targetDepthMeters * math.cos(alpha);

    return math.sqrt(math.max(0.000001, dSq));
  }
}

/// Continuous spatial sensor orientation tracker.
class SpatialAnchorTracker {
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  double currentYawDeg = 0.0;
  double currentPitchDeg = 45.0;
  double currentRollDeg = 0.0;
  double currentDepthMeters = 0.65; // default ~65cm desk distance

  DateTime _lastGyroTime = DateTime.now();

  void startTracking({VoidCallback? onUpdate}) {
    stopTracking();

    _lastGyroTime = DateTime.now();

    try {
      _gyroSub = gyroscopeEventStream().listen((event) {
        final now = DateTime.now();
        final dt = (now.difference(_lastGyroTime).inMicroseconds) / 1000000.0;
        _lastGyroTime = now;

        if (dt > 0 && dt < 0.2) {
          // Gyroscope gives rad/s.
          // Event.y is yaw rate in portrait orientation, Event.x is pitch rate, Event.z is roll rate
          final yawRateDeg = event.y * (180.0 / math.pi);
          currentYawDeg += yawRateDeg * dt;

          onUpdate?.call();
        }
      }, onError: (_) {});
    } catch (_) {}

    try {
      _accelSub = accelerometerEventStream().listen((event) {
        // Accelerometer gives absolute gravity vector for pitch and roll
        final ax = event.x;
        final ay = event.y;
        final az = event.z;
        final norm = math.sqrt(ax * ax + ay * ay + az * az);

        if (norm > 0.1) {
          final pitchRad = math.atan2(ay, math.sqrt(ax * ax + az * az));
          final rollRad = math.atan2(ax, math.sqrt(ay * ay + az * az));

          // Complementary smoothing
          currentPitchDeg = currentPitchDeg * 0.85 + (pitchRad * (180.0 / math.pi)) * 0.15;
          currentRollDeg = currentRollDeg * 0.85 + (rollRad * (180.0 / math.pi)) * 0.15;

          onUpdate?.call();
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void stopTracking() {
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _gyroSub = null;
    _accelSub = null;
  }
}
