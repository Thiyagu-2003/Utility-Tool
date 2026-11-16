import 'smart_measure_point.dart';
import 'measurement_units.dart';

/// Single wall segment in a room measurement.
class RoomWallSegment {
  final String id;
  final SmartMeasurePoint startPoint;
  final SmartMeasurePoint endPoint;
  final double lengthMeters;
  final double? heightMeters;
  final double angleDegrees;

  RoomWallSegment({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    required this.lengthMeters,
    this.heightMeters,
    required this.angleDegrees,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startPoint': startPoint.toJson(),
        'endPoint': endPoint.toJson(),
        'lengthMeters': lengthMeters,
        'heightMeters': heightMeters,
        'angleDegrees': angleDegrees,
      };

  factory RoomWallSegment.fromJson(Map<String, dynamic> json) {
    return RoomWallSegment(
      id: json['id'] as String,
      startPoint: SmartMeasurePoint.fromJson(json['startPoint'] as Map<String, dynamic>),
      endPoint: SmartMeasurePoint.fromJson(json['endPoint'] as Map<String, dynamic>),
      lengthMeters: (json['lengthMeters'] as num).toDouble(),
      heightMeters: (json['heightMeters'] as num?)?.toDouble(),
      angleDegrees: (json['angleDegrees'] as num).toDouble(),
    );
  }
}

/// Comprehensive multi-wall room dimension summary.
class RoomDimensionSummary {
  final List<RoomWallSegment> walls;
  final double perimeterMeters;
  final double floorAreaSqMeters;
  final double? ceilingHeightMeters;
  final double? estimatedVolumeCuMeters;
  final double estimatedLengthMeters;
  final double estimatedWidthMeters;
  final bool isClosedPolygon;

  RoomDimensionSummary({
    required this.walls,
    required this.perimeterMeters,
    required this.floorAreaSqMeters,
    this.ceilingHeightMeters,
    this.estimatedVolumeCuMeters,
    required this.estimatedLengthMeters,
    required this.estimatedWidthMeters,
    required this.isClosedPolygon,
  });

  /// Generate a structured human-readable text summary of room dimensions.
  String generateReport(DistanceUnit distUnit, AreaUnit areaUnit) {
    final buffer = StringBuffer();
    buffer.writeln('=== ROOM DIMENSION SUMMARY ===');
    buffer.writeln('Total Wall Segments: ${walls.length}');
    buffer.writeln('Floor Area: ${areaUnit.formatSqMeters(floorAreaSqMeters)}');
    buffer.writeln('Perimeter: ${distUnit.formatMeters(perimeterMeters)}');
    buffer.writeln('Est. Span (L x W): ${distUnit.formatMeters(estimatedLengthMeters)} x ${distUnit.formatMeters(estimatedWidthMeters)}');
    if (ceilingHeightMeters != null) {
      buffer.writeln('Ceiling Height: ${distUnit.formatMeters(ceilingHeightMeters!)}');
    }
    if (estimatedVolumeCuMeters != null) {
      buffer.writeln('Room Volume: ${estimatedVolumeCuMeters!.toStringAsFixed(2)} m³');
    }
    buffer.writeln('--------------------------------');
    for (int i = 0; i < walls.length; i++) {
      final w = walls[i];
      buffer.writeln('Wall #${i + 1}: ${distUnit.formatMeters(w.lengthMeters)} (Heading: ${w.angleDegrees.toStringAsFixed(0)}°)');
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'walls': walls.map((w) => w.toJson()).toList(),
        'perimeterMeters': perimeterMeters,
        'floorAreaSqMeters': floorAreaSqMeters,
        'ceilingHeightMeters': ceilingHeightMeters,
        'estimatedVolumeCuMeters': estimatedVolumeCuMeters,
        'estimatedLengthMeters': estimatedLengthMeters,
        'estimatedWidthMeters': estimatedWidthMeters,
        'isClosedPolygon': isClosedPolygon,
      };

  factory RoomDimensionSummary.fromJson(Map<String, dynamic> json) {
    return RoomDimensionSummary(
      walls: (json['walls'] as List<dynamic>?)
              ?.map((w) => RoomWallSegment.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
      perimeterMeters: (json['perimeterMeters'] as num).toDouble(),
      floorAreaSqMeters: (json['floorAreaSqMeters'] as num).toDouble(),
      ceilingHeightMeters: (json['ceilingHeightMeters'] as num?)?.toDouble(),
      estimatedVolumeCuMeters: (json['estimatedVolumeCuMeters'] as num?)?.toDouble(),
      estimatedLengthMeters: (json['estimatedLengthMeters'] as num).toDouble(),
      estimatedWidthMeters: (json['estimatedWidthMeters'] as num).toDouble(),
      isClosedPolygon: json['isClosedPolygon'] as bool? ?? false,
    );
  }
}
