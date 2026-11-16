import 'dart:math' as math;
import 'smart_measure_point.dart';
import 'measurement_units.dart';

/// 3D Object Bounding Box and Dimension Model.
class ObjectDimensionModel {
  final double lengthMeters;
  final double widthMeters;
  final double heightMeters;
  final List<SmartMeasurePoint> cornerPoints;

  ObjectDimensionModel({
    required this.lengthMeters,
    required this.widthMeters,
    required this.heightMeters,
    this.cornerPoints = const [],
  });

  /// Volume in cubic meters (L * W * H).
  double get volumeCubicMeters => lengthMeters * widthMeters * heightMeters;

  /// Total surface area in square meters: 2 * (LW + LH + WH).
  double get surfaceAreaSqMeters =>
      2 * (lengthMeters * widthMeters + lengthMeters * heightMeters + widthMeters * heightMeters);

  /// Diagonal distance across 3D box: sqrt(L² + W² + H²).
  double get spatialDiagonalMeters =>
      math.sqrt(lengthMeters * lengthMeters + widthMeters * widthMeters + heightMeters * heightMeters);

  String formatSummary(DistanceUnit unit) {
    return '${unit.formatMeters(lengthMeters)} x ${unit.formatMeters(widthMeters)} x ${unit.formatMeters(heightMeters)}';
  }

  Map<String, dynamic> toJson() => {
        'lengthMeters': lengthMeters,
        'widthMeters': widthMeters,
        'heightMeters': heightMeters,
        'cornerPoints': cornerPoints.map((p) => p.toJson()).toList(),
      };

  factory ObjectDimensionModel.fromJson(Map<String, dynamic> json) {
    return ObjectDimensionModel(
      lengthMeters: (json['lengthMeters'] as num).toDouble(),
      widthMeters: (json['widthMeters'] as num).toDouble(),
      heightMeters: (json['heightMeters'] as num).toDouble(),
      cornerPoints: (json['cornerPoints'] as List<dynamic>?)
              ?.map((p) => SmartMeasurePoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
