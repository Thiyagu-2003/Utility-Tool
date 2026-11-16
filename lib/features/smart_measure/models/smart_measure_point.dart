import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Represents a measured anchor point in 3D AR space and its 2D screen projection.
class SmartMeasurePoint {
  /// Unique point identifier.
  final String id;

  /// 3D World coordinates in meters relative to AR session origin.
  final double x;
  final double y;
  final double z;

  /// Normalized screen coordinate (0.0 to 1.0) when placed.
  final Offset screenPosition;

  /// Timestamp when placed.
  final DateTime timestamp;

  /// Plane orientation classification if point was placed on a detected surface.
  final PlaneType planeType;

  /// Confidence score for this point (0.0 to 1.0).
  final double confidence;

  /// Depth in meters from camera to this point at placement time.
  final double depthMeters;

  const SmartMeasurePoint({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.screenPosition,
    required this.timestamp,
    this.planeType = PlaneType.arbitrary,
    this.confidence = 1.0,
    this.depthMeters = 1.0,
  });

  /// Euclidean 3D distance between two points in meters: sqrt(dx² + dy² + dz²).
  double distanceTo(SmartMeasurePoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Create a copy with updated screen position (for dragging/repositioning).
  SmartMeasurePoint copyWith({
    String? id,
    double? x,
    double? y,
    double? z,
    Offset? screenPosition,
    DateTime? timestamp,
    PlaneType? planeType,
    double? confidence,
    double? depthMeters,
  }) {
    return SmartMeasurePoint(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      screenPosition: screenPosition ?? this.screenPosition,
      timestamp: timestamp ?? this.timestamp,
      planeType: planeType ?? this.planeType,
      confidence: confidence ?? this.confidence,
      depthMeters: depthMeters ?? this.depthMeters,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'z': z,
        'screenX': screenPosition.dx,
        'screenY': screenPosition.dy,
        'timestamp': timestamp.toIso8601String(),
        'planeType': planeType.name,
        'confidence': confidence,
        'depthMeters': depthMeters,
      };

  factory SmartMeasurePoint.fromJson(Map<String, dynamic> json) {
    return SmartMeasurePoint(
      id: json['id'] as String? ?? UniqueKey().toString(),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      screenPosition: Offset(
        (json['screenX'] as num).toDouble(),
        (json['screenY'] as num).toDouble(),
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      planeType: PlaneType.values.firstWhere(
        (p) => p.name == json['planeType'],
        orElse: () => PlaneType.arbitrary,
      ),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      depthMeters: (json['depthMeters'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

enum PlaneType {
  horizontalUpward,
  horizontalDownward,
  vertical,
  arbitrary,
}
