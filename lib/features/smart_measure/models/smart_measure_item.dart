import 'smart_measure_capability.dart';
import 'smart_measure_point.dart';
import 'measurement_types.dart';
import 'measurement_units.dart';

/// Stored measurement record with full audit metadata.
class SmartMeasureItem {
  final String id;
  String name;
  final SmartMeasureToolType toolType;
  final DateTime createdAt;
  final double primaryValue;
  final DistanceUnit distanceUnit;
  final AreaUnit? areaUnit;
  final AngleUnit? angleUnit;
  final String formattedValue;
  final Map<String, dynamic> secondaryValues;
  final TrackingConfidence confidence;
  final double? estimatedUncertaintyPercent;
  final String capabilityUsed;
  String? notes;
  String? screenshotPath;
  final List<SmartMeasurePoint> points;
  final Map<String, dynamic>? extraMetadata;

  SmartMeasureItem({
    required this.id,
    required this.name,
    required this.toolType,
    required this.createdAt,
    required this.primaryValue,
    required this.distanceUnit,
    this.areaUnit,
    this.angleUnit,
    required this.formattedValue,
    this.secondaryValues = const {},
    required this.confidence,
    this.estimatedUncertaintyPercent,
    required this.capabilityUsed,
    this.notes,
    this.screenshotPath,
    this.points = const [],
    this.extraMetadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'toolType': toolType.name,
        'createdAt': createdAt.toIso8601String(),
        'primaryValue': primaryValue,
        'distanceUnit': distanceUnit.name,
        'areaUnit': areaUnit?.name,
        'angleUnit': angleUnit?.name,
        'formattedValue': formattedValue,
        'secondaryValues': secondaryValues,
        'confidence': confidence.name,
        'estimatedUncertaintyPercent': estimatedUncertaintyPercent,
        'capabilityUsed': capabilityUsed,
        'notes': notes,
        'screenshotPath': screenshotPath,
        'points': points.map((p) => p.toJson()).toList(),
        'extraMetadata': extraMetadata,
      };

  factory SmartMeasureItem.fromJson(Map<String, dynamic> json) {
    return SmartMeasureItem(
      id: json['id'] as String,
      name: json['name'] as String,
      toolType: SmartMeasureToolType.values.firstWhere(
        (t) => t.name == json['toolType'],
        orElse: () => SmartMeasureToolType.pointToPoint,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      primaryValue: (json['primaryValue'] as num).toDouble(),
      distanceUnit: DistanceUnit.values.firstWhere(
        (u) => u.name == json['distanceUnit'],
        orElse: () => DistanceUnit.centimeter,
      ),
      areaUnit: json['areaUnit'] != null
          ? AreaUnit.values.firstWhere(
              (u) => u.name == json['areaUnit'],
              orElse: () => AreaUnit.sqMeter,
            )
          : null,
      angleUnit: json['angleUnit'] != null
          ? AngleUnit.values.firstWhere(
              (u) => u.name == json['angleUnit'],
              orElse: () => AngleUnit.degree,
            )
          : null,
      formattedValue: json['formattedValue'] as String? ?? '',
      secondaryValues: json['secondaryValues'] as Map<String, dynamic>? ?? {},
      confidence: TrackingConfidence.values.firstWhere(
        (c) => c.name == json['confidence'],
        orElse: () => TrackingConfidence.medium,
      ),
      estimatedUncertaintyPercent: (json['estimatedUncertaintyPercent'] as num?)?.toDouble(),
      capabilityUsed: json['capabilityUsed'] as String? ?? 'General AR',
      notes: json['notes'] as String?,
      screenshotPath: json['screenshotPath'] as String?,
      points: (json['points'] as List<dynamic>?)
              ?.map((p) => SmartMeasurePoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      extraMetadata: json['extraMetadata'] as Map<String, dynamic>?,
    );
  }
}
