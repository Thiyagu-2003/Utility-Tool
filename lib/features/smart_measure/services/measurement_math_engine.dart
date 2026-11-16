import 'dart:math' as math;
import '../models/smart_measure_capability.dart';
import '../models/smart_measure_point.dart';
import '../models/room_dimension_model.dart';
import '../models/object_dimension_model.dart';

/// Rigorous 3D and 2D mathematical computations for Smart Measure.
class MeasurementMathEngine {
  /// Euclidean distance between two 3D points in meters.
  static double distance3D(SmartMeasurePoint p1, SmartMeasurePoint p2) {
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    final dz = p2.z - p1.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Cumulative distance along a sequence of continuous points in meters.
  static double cumulativeDistance(List<SmartMeasurePoint> points) {
    if (points.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      sum += distance3D(points[i], points[i + 1]);
    }
    return sum;
  }

  /// Calculate the angle formed by three 3D points: point1 -> vertex -> point2.
  /// Returns angle in degrees [0..180].
  static double angleBetween3D({
    required SmartMeasurePoint point1,
    required SmartMeasurePoint vertex,
    required SmartMeasurePoint point2,
  }) {
    // Vector u = point1 - vertex
    final ux = point1.x - vertex.x;
    final uy = point1.y - vertex.y;
    final uz = point1.z - vertex.z;

    // Vector v = point2 - vertex
    final vx = point2.x - vertex.x;
    final vy = point2.y - vertex.y;
    final vz = point2.z - vertex.z;

    final dot = ux * vx + uy * vy + uz * vz;
    final magU = math.sqrt(ux * ux + uy * uy + uz * uz);
    final magV = math.sqrt(vx * vx + vy * vy + vz * vz);

    if (magU < 0.0001 || magV < 0.0001) return 0.0;

    final cosTheta = (dot / (magU * magV)).clamp(-1.0, 1.0);
    return math.acos(cosTheta) * (180.0 / math.pi);
  }

  /// Exact 3D planar polygon area using vector cross products:
  /// Area = 0.5 * || sum_{i=0}^{n-1} (p_i x p_{i+1}) ||
  static double polygonArea3D(List<SmartMeasurePoint> points) {
    if (points.length < 3) return 0.0;

    double crossX = 0.0;
    double crossY = 0.0;
    double crossZ = 0.0;

    final n = points.length;
    for (int i = 0; i < n; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % n];

      crossX += (p1.y * p2.z - p1.z * p2.y);
      crossY += (p1.z * p2.x - p1.x * p2.z);
      crossZ += (p1.x * p2.y - p1.y * p2.x);
    }

    final normalMagnitude = math.sqrt(crossX * crossX + crossY * crossY + crossZ * crossZ);
    return 0.5 * normalMagnitude;
  }

  /// Vertical height measurement along gravity axis (Y axis).
  static double verticalHeight(SmartMeasurePoint bottom, SmartMeasurePoint top) {
    return (top.y - bottom.y).abs();
  }

  /// Build 3D Object Dimension Model from placed corners.
  static ObjectDimensionModel calculateObjectBox(List<SmartMeasurePoint> points) {
    if (points.length < 2) {
      return ObjectDimensionModel(lengthMeters: 0, widthMeters: 0, heightMeters: 0);
    }

    if (points.length == 2) {
      // 2 points: Primary length
      final l = distance3D(points[0], points[1]);
      return ObjectDimensionModel(
        lengthMeters: l,
        widthMeters: 0,
        heightMeters: 0,
        cornerPoints: points,
      );
    }

    if (points.length == 3) {
      // 3 points: Length (P0-P1) and Width (P1-P2)
      final l = distance3D(points[0], points[1]);
      final w = distance3D(points[1], points[2]);
      return ObjectDimensionModel(
        lengthMeters: l,
        widthMeters: w,
        heightMeters: 0,
        cornerPoints: points,
      );
    }

    // 4 or more points: Length, Width, Height
    final l = distance3D(points[0], points[1]);
    final w = distance3D(points[1], points[2]);
    // Height is vertical rise only; points on one plane have none (don't report a floor edge as height).
    final h = (points[3].y - points[0].y).abs();
    final actualH = h > 0.01 ? h : 0.0;

    return ObjectDimensionModel(
      lengthMeters: l,
      widthMeters: w,
      heightMeters: actualH,
      cornerPoints: points,
    );
  }

  /// Build a complete RoomDimensionSummary from wall corner anchor points.
  static RoomDimensionSummary calculateRoomSummary(
    List<SmartMeasurePoint> corners, {
    double? ceilingHeightMeters,
  }) {
    if (corners.length < 3) {
      return RoomDimensionSummary(
        walls: [],
        perimeterMeters: 0,
        floorAreaSqMeters: 0,
        ceilingHeightMeters: ceilingHeightMeters,
        estimatedVolumeCuMeters: null,
        estimatedLengthMeters: 0,
        estimatedWidthMeters: 0,
        isClosedPolygon: false,
      );
    }

    final walls = <RoomWallSegment>[];
    double perimeter = 0.0;
    final count = corners.length;

    for (int i = 0; i < count; i++) {
      final p1 = corners[i];
      final p2 = corners[(i + 1) % count];
      final len = distance3D(p1, p2);
      perimeter += len;

      // Heading angle relative to forward axis
      final dx = p2.x - p1.x;
      final dz = p2.z - p1.z;
      var heading = math.atan2(dx, dz) * (180.0 / math.pi);
      if (heading < 0) heading += 360.0;

      walls.add(RoomWallSegment(
        id: 'wall_${i + 1}',
        startPoint: p1,
        endPoint: p2,
        lengthMeters: len,
        heightMeters: ceilingHeightMeters,
        angleDegrees: heading,
      ));
    }

    final area = polygonArea3D(corners);

    // Length & width: corner extents along the longest wall and its perpendicular, so the result
    // doesn't depend on how the room happens to sit in the (arbitrarily rotated) world frame.
    final longest = walls.reduce((a, b) => a.lengthMeters >= b.lengthMeters ? a : b);
    var ax = longest.endPoint.x - longest.startPoint.x;
    var az = longest.endPoint.z - longest.startPoint.z;
    final axLen = math.sqrt(ax * ax + az * az);
    if (axLen > 1e-9) {
      ax /= axLen;
      az /= axLen;
    } else {
      ax = 1;
      az = 0;
    }
    double minU = double.infinity, maxU = -double.infinity;
    double minV = double.infinity, maxV = -double.infinity;
    for (final c in corners) {
      final u = c.x * ax + c.z * az;
      final v = -c.x * az + c.z * ax;
      minU = math.min(minU, u);
      maxU = math.max(maxU, u);
      minV = math.min(minV, v);
      maxV = math.max(maxV, v);
    }
    final estLength = maxU - minU;
    final estWidth = maxV - minV;

    final volume = ceilingHeightMeters != null ? area * ceilingHeightMeters : null;

    return RoomDimensionSummary(
      walls: walls,
      perimeterMeters: perimeter,
      floorAreaSqMeters: area,
      ceilingHeightMeters: ceilingHeightMeters,
      estimatedVolumeCuMeters: volume,
      estimatedLengthMeters: estLength,
      estimatedWidthMeters: estWidth,
      isClosedPolygon: true,
    );
  }

  /// Calculate measurement confidence and physical error bounds (+/- mm/cm)
  /// based on tracking state, depth sensor availability, point distance and incident angle.
  static MeasurementConfidenceAudit evaluateConfidence({
    required TrackingConfidence trackingState,
    required MeasurementTrackingEngine engine,
    required double measurementDistanceMeters,
    required double sensorDepthMeters,
  }) {
    double baseUncertaintyPercent;

    switch (engine) {
      case MeasurementTrackingEngine.iosLidar:
        baseUncertaintyPercent = 0.5; // LiDAR gives 0.5% typical error
        break;
      case MeasurementTrackingEngine.androidDepthArCore:
        baseUncertaintyPercent = 1.0; // Depth API gives ~1% error
        break;
      case MeasurementTrackingEngine.iosArKit:
        baseUncertaintyPercent = 1.5;
        break;
      case MeasurementTrackingEngine.androidArCore:
        baseUncertaintyPercent = 2.0;
        break;
      case MeasurementTrackingEngine.manualCalibration:
        baseUncertaintyPercent = 2.5;
        break;
    }

    // Distance penalty: measurements beyond 3 meters carry larger uncertainty
    if (sensorDepthMeters > 3.0) {
      baseUncertaintyPercent += (sensorDepthMeters - 3.0) * 0.8;
    }

    // Tracking state degradation
    if (trackingState == TrackingConfidence.medium) {
      baseUncertaintyPercent += 1.5;
    } else if (trackingState == TrackingConfidence.low) {
      baseUncertaintyPercent += 4.0;
    } else if (trackingState == TrackingConfidence.unavailable) {
      baseUncertaintyPercent = 15.0;
    }

    // Physical absolute uncertainty in millimeters
    final absoluteErrorMeters = measurementDistanceMeters * (baseUncertaintyPercent / 100.0);
    final absoluteErrorMm = absoluteErrorMeters * 1000.0;

    String marginDisplay;
    if (absoluteErrorMm < 10) {
      marginDisplay = '± ${absoluteErrorMm.toStringAsFixed(1)} mm';
    } else {
      marginDisplay = '± ${(absoluteErrorMm / 10.0).toStringAsFixed(1)} cm';
    }

    return MeasurementConfidenceAudit(
      confidence: trackingState,
      uncertaintyPercent: baseUncertaintyPercent,
      absoluteErrorMarginDisplay: marginDisplay,
    );
  }

  /// Back-camera angle below the horizon, from accelerometer (portrait): 0° = phone upright
  /// (camera at horizon), 90° = phone flat face-up (camera at floor), negative = aiming up.
  /// This is what the ray-plane raycasts expect — NOT [LevelReading.pitchDegrees], which is 90° upright.
  static double cameraDownAngleDegrees(double ax, double ay, double az) {
    return math.atan2(az, math.sqrt(ax * ax + ay * ay)) * (180.0 / math.pi);
  }

  /// Calculate level angles from device accelerometer readings (ax, ay, az in m/s²).
  static LevelReading calculateLevel(double ax, double ay, double az) {
    if (!ax.isFinite || !ay.isFinite || !az.isFinite) {
      return const LevelReading(rollDegrees: 0, pitchDegrees: 0, totalTiltDegrees: 0, isLevel: false);
    }

    final norm = math.sqrt(ax * ax + ay * ay + az * az);
    if (norm < 0.1) {
      return const LevelReading(rollDegrees: 0, pitchDegrees: 0, totalTiltDegrees: 0, isLevel: false);
    }

    // Roll: rotation around Y (device horizontal axis)
    final rollRad = math.atan2(ax, math.sqrt(ay * ay + az * az));
    final rollDeg = rollRad * (180.0 / math.pi);

    // Pitch: rotation around X (device vertical axis)
    final pitchRad = math.atan2(ay, math.sqrt(ax * ax + az * az));
    final pitchDeg = pitchRad * (180.0 / math.pi);

    // Total tilt from flat surface
    final tiltRad = math.acos((az / norm).clamp(-1.0, 1.0));
    final tiltDeg = tiltRad * (180.0 / math.pi);

    final isFlatLevel = tiltDeg.abs() <= 1.0 || (180.0 - tiltDeg).abs() <= 1.0;
    final isVerticalLevel = (pitchDeg.abs() - 90.0).abs() <= 1.0;

    return LevelReading(
      rollDegrees: rollDeg,
      pitchDegrees: pitchDeg,
      totalTiltDegrees: tiltDeg,
      isLevel: isFlatLevel || isVerticalLevel,
    );
  }
}

class MeasurementConfidenceAudit {
  final TrackingConfidence confidence;
  final double uncertaintyPercent;
  final String absoluteErrorMarginDisplay;

  const MeasurementConfidenceAudit({
    required this.confidence,
    required this.uncertaintyPercent,
    required this.absoluteErrorMarginDisplay,
  });
}

class LevelReading {
  final double rollDegrees;
  final double pitchDegrees;
  final double totalTiltDegrees;
  final bool isLevel;

  const LevelReading({
    required this.rollDegrees,
    required this.pitchDegrees,
    required this.totalTiltDegrees,
    required this.isLevel,
  });
}
