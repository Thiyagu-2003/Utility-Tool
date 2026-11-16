import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:utility_tool/core/models/tool_model.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/features/smart_measure/models/smart_measure_capability.dart';
import 'package:utility_tool/features/smart_measure/models/measurement_types.dart';
import 'package:utility_tool/features/smart_measure/models/measurement_units.dart';
import 'package:utility_tool/features/smart_measure/models/smart_measure_point.dart';
import 'package:utility_tool/features/smart_measure/models/smart_measure_item.dart';
import 'package:utility_tool/features/smart_measure/services/spatial_anchor_tracker.dart';
import 'package:utility_tool/features/smart_measure/services/measurement_math_engine.dart';
import 'package:utility_tool/features/smart_measure/services/manual_calibration_engine.dart';
import 'package:utility_tool/features/smart_measure/services/smart_measure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SpatialAnchor Motion Tracking & Screen Projection', () {
    test('Anchor stays anchored when camera pans right and projects left on screen', () {
      final anchor = SpatialAnchor(
        id: 'start',
        yawDeg: 0.0,
        pitchDeg: 45.0,
        rollDeg: 0.0,
        depthMeters: 0.5,
        createdAt: DateTime.now(),
      );

      // Camera centered on anchor
      final p0 = anchor.projectToScreen(currentYawDeg: 0.0, currentPitchDeg: 45.0, currentRollDeg: 0.0);
      expect(p0.dx, closeTo(0.5, 0.001));
      expect(p0.dy, closeTo(0.5, 0.001));

      // Camera pans 10 degrees to the right: the anchored point moves to the LEFT on screen
      final pRight = anchor.projectToScreen(currentYawDeg: 10.0, currentPitchDeg: 45.0, currentRollDeg: 0.0);
      expect(pRight.dx, lessThan(0.5));
      expect(pRight.dy, closeTo(0.5, 0.01));

      // Camera pans 10 degrees to the left: the anchored point moves to the RIGHT on screen
      final pLeft = anchor.projectToScreen(currentYawDeg: -10.0, currentPitchDeg: 45.0, currentRollDeg: 0.0);
      expect(pLeft.dx, greaterThan(0.5));
      expect(pLeft.dy, closeTo(0.5, 0.01));

      // Real distance across 5 degrees at 0.5m depth is approximately 4.3 cm (mouse size)
      final distM = anchor.distanceTo(targetYawDeg: 5.0, targetPitchDeg: 45.0, targetDepthMeters: 0.5);
      final distCm = DistanceUnit.centimeter.fromMeters(distM);
      expect(distCm, closeTo(4.36, 0.1));
    });
  });

  group('ToolRegistry Integration', () {
    test('Smart Measure is properly registered in ToolRegistry', () {
      final tool = ToolRegistry.findById('smart_measure');
      expect(tool, isNotNull);
      expect(tool!.title, contains('Smart Measure'));
      expect(tool.category, ToolCategory.smartMeasure);
      expect(tool.keywords, contains('ar'));
      expect(tool.keywords, contains('tape'));
    });
  });

  group('MeasurementMathEngine 3D Euclidean & Vector Calculations', () {
    test('Distance between two 3D points matches exact geometry', () {
      final p1 = SmartMeasurePoint(
        id: 'p1',
        x: 0.0,
        y: 0.0,
        z: 0.0,
        screenPosition: const Offset(0.5, 0.5),
        timestamp: DateTime.now(),
      );

      // (3, 4, 0) -> distance should be 5.0
      final p2 = SmartMeasurePoint(
        id: 'p2',
        x: 3.0,
        y: 4.0,
        z: 0.0,
        screenPosition: const Offset(0.5, 0.5),
        timestamp: DateTime.now(),
      );

      final dist = MeasurementMathEngine.distance3D(p1, p2);
      expect(dist, closeTo(5.0, 0.0001));

      // 3D vector (1, 2, 2) -> sqrt(1 + 4 + 4) = 3.0
      final p3 = SmartMeasurePoint(
        id: 'p3',
        x: 1.0,
        y: 2.0,
        z: 2.0,
        screenPosition: const Offset(0.5, 0.5),
        timestamp: DateTime.now(),
      );
      expect(MeasurementMathEngine.distance3D(p1, p3), closeTo(3.0, 0.0001));
    });

    test('Cumulative polyline distance correctly sums segments', () {
      final p1 = SmartMeasurePoint(id: '1', x: 0, y: 0, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final p2 = SmartMeasurePoint(id: '2', x: 1, y: 0, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final p3 = SmartMeasurePoint(id: '3', x: 1, y: 1, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final p4 = SmartMeasurePoint(id: '4', x: 1, y: 1, z: 2, screenPosition: Offset.zero, timestamp: DateTime.now());

      final total = MeasurementMathEngine.cumulativeDistance([p1, p2, p3, p4]);
      // 1.0 + 1.0 + 2.0 = 4.0
      expect(total, closeTo(4.0, 0.0001));
    });

    test('Angle calculation between 3 points in 3D', () {
      final arm1 = SmartMeasurePoint(id: '1', x: 1, y: 0, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final vertex = SmartMeasurePoint(id: 'v', x: 0, y: 0, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final arm2 = SmartMeasurePoint(id: '2', x: 0, y: 1, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());

      // Orthogonal vectors (1,0,0) and (0,1,0) -> 90 degrees
      final deg90 = MeasurementMathEngine.angleBetween3D(point1: arm1, vertex: vertex, point2: arm2);
      expect(deg90, closeTo(90.0, 0.01));

      // Opposite collinear vectors (1,0,0) and (-1,0,0) -> 180 degrees
      final arm3 = SmartMeasurePoint(id: '3', x: -1, y: 0, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final deg180 = MeasurementMathEngine.angleBetween3D(point1: arm1, vertex: vertex, point2: arm3);
      expect(deg180, closeTo(180.0, 0.01));
    });

    test('3D Polygon Area calculation using Shoelace cross-product', () {
      // 3m x 4m rectangle on horizontal ground plane (Y=0)
      final p1 = SmartMeasurePoint(id: '1', x: 0, y: 0, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final p2 = SmartMeasurePoint(id: '2', x: 3, y: 0, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final p3 = SmartMeasurePoint(id: '3', x: 3, y: 0, z: 4, screenPosition: Offset.zero, timestamp: DateTime.now());
      final p4 = SmartMeasurePoint(id: '4', x: 0, y: 0, z: 4, screenPosition: Offset.zero, timestamp: DateTime.now());

      final area = MeasurementMathEngine.polygonArea3D([p1, p2, p3, p4]);
      expect(area, closeTo(12.0, 0.001));
    });

    test('Object 3D Bounding Box calculations', () {
      // 2m Length (p0-p1), 1.5m Width (p1-p2), 1m Height (p3.y - p0.y)
      final p0 = SmartMeasurePoint(id: '0', x: 0, y: 0, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final p1 = SmartMeasurePoint(id: '1', x: 2, y: 0, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final p2 = SmartMeasurePoint(id: '2', x: 2, y: 0, z: 1.5, screenPosition: Offset.zero, timestamp: DateTime.now());
      final p3 = SmartMeasurePoint(id: '3', x: 0, y: 1, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());

      final box = MeasurementMathEngine.calculateObjectBox([p0, p1, p2, p3]);
      expect(box.lengthMeters, closeTo(2.0, 0.01));
      expect(box.widthMeters, closeTo(1.5, 0.01));
      expect(box.heightMeters, closeTo(1.0, 0.01));
      expect(box.volumeCubicMeters, closeTo(3.0, 0.01)); // 2 * 1.5 * 1 = 3 m³
      // Surface area = 2 * (2*1.5 + 2*1 + 1.5*1) = 2 * (3 + 2 + 1.5) = 13 m²
      expect(box.surfaceAreaSqMeters, closeTo(13.0, 0.01));
    });

    test('Room Dimension Summary with multi-wall perimeter and area', () {
      // 5m x 4m room with 2.8m ceiling
      final c1 = SmartMeasurePoint(id: '1', x: 0, y: 0, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final c2 = SmartMeasurePoint(id: '2', x: 5, y: 0, z: 0, screenPosition: Offset.zero, timestamp: DateTime.now());
      final c3 = SmartMeasurePoint(id: '3', x: 5, y: 0, z: 4, screenPosition: Offset.zero, timestamp: DateTime.now());
      final c4 = SmartMeasurePoint(id: '4', x: 0, y: 0, z: 4, screenPosition: Offset.zero, timestamp: DateTime.now());

      final summary = MeasurementMathEngine.calculateRoomSummary([c1, c2, c3, c4], ceilingHeightMeters: 2.8);
      expect(summary.walls.length, 4);
      expect(summary.perimeterMeters, closeTo(18.0, 0.01)); // 5 + 4 + 5 + 4 = 18
      expect(summary.floorAreaSqMeters, closeTo(20.0, 0.01)); // 5 * 4 = 20 m²
      expect(summary.estimatedVolumeCuMeters, closeTo(56.0, 0.01)); // 20 * 2.8 = 56 m³
      expect(summary.isClosedPolygon, true);
    });

    test('Digital Level sensor physics calculation', () {
      // Flat horizontal phone: ax=0, ay=0, az=9.8
      final flat = MeasurementMathEngine.calculateLevel(0.0, 0.0, 9.8);
      expect(flat.rollDegrees, closeTo(0.0, 0.5));
      expect(flat.pitchDegrees, closeTo(0.0, 0.5));
      expect(flat.isLevel, isTrue);

      // Tilted phone: ax=4.9, ay=0, az=8.487 -> ~30 degree roll
      final tilted = MeasurementMathEngine.calculateLevel(4.9, 0.0, 8.487);
      expect(tilted.rollDegrees, closeTo(30.0, 1.0));
      expect(tilted.isLevel, isFalse);
    });

    test('Confidence audit correctly calculates error margin', () {
      final audit = MeasurementMathEngine.evaluateConfidence(
        trackingState: TrackingConfidence.high,
        engine: MeasurementTrackingEngine.iosLidar,
        measurementDistanceMeters: 2.0,
        sensorDepthMeters: 1.5,
      );
      expect(audit.confidence, TrackingConfidence.high);
      expect(audit.uncertaintyPercent, closeTo(0.5, 0.1));
      expect(audit.absoluteErrorMarginDisplay, contains('±'));
    });
  });

  group('DistanceUnit and AreaUnit Conversions', () {
    test('Meters conversion to Imperial and Metric units', () {
      const meters = 1.0;
      expect(DistanceUnit.centimeter.fromMeters(meters), closeTo(100.0, 0.001));
      expect(DistanceUnit.millimeter.fromMeters(meters), closeTo(1000.0, 0.001));
      expect(DistanceUnit.inch.fromMeters(meters), closeTo(39.3701, 0.01));
      expect(DistanceUnit.foot.fromMeters(meters), closeTo(3.28084, 0.01));
      expect(DistanceUnit.yard.fromMeters(meters), closeTo(1.09361, 0.01));
    });

    test('Square meters conversion to Square Feet and Square Yards', () {
      const sqMeters = 10.0;
      expect(AreaUnit.sqFoot.fromSqMeters(sqMeters), closeTo(107.639, 0.1));
      expect(AreaUnit.sqYard.fromSqMeters(sqMeters), closeTo(11.9599, 0.1));
    });
  });

  group('Manual Image Calibration Engine', () {
    test('Computes correct mmPerPixel scale from reference card', () {
      // Suppose a standard 85.6mm credit card spans 200 pixels on image
      final calib = ImageCalibration.fromPoints(
        referenceType: ReferenceItemType.creditCard,
        referenceRealMm: 85.6,
        start: const Offset(100, 100),
        end: const Offset(300, 100), // 200 px distance
      );

      expect(calib.pixelDistance, closeTo(200.0, 0.01));
      expect(calib.mmPerPixel, closeTo(85.6 / 200.0, 0.0001));

      // Measuring an object that spans 400 pixels should yield 171.2 mm
      final measuredMm = calib.measureDistanceMm(const Offset(0, 0), const Offset(400, 0));
      expect(measuredMm, closeTo(171.2, 0.01));
    });
  });

  group('SmartMeasureStorageService CRUD', () {
    test('Saves, retrieves, updates and deletes measurements', () async {
      final storage = SmartMeasureStorageService();
      await storage.init();
      await storage.clearAll();

      final item = SmartMeasureItem(
        id: 'test_123',
        name: 'Conference Table Length',
        toolType: SmartMeasureToolType.length,
        createdAt: DateTime.now(),
        primaryValue: 2.45,
        distanceUnit: DistanceUnit.meter,
        formattedValue: '2.45 m',
        confidence: TrackingConfidence.high,
        capabilityUsed: 'Apple LiDAR',
        notes: 'Main meeting room',
      );

      await storage.saveMeasurement(item);
      expect(storage.items.length, 1);
      expect(storage.items.first.name, 'Conference Table Length');

      // Update name and notes
      await storage.updateMeasurement('test_123', name: 'Boardroom Table', notes: 'Updated notes');
      expect(storage.items.first.name, 'Boardroom Table');
      expect(storage.items.first.notes, 'Updated notes');

      // Filter
      final filtered = storage.filter(query: 'Boardroom');
      expect(filtered.length, 1);

      // Report generation
      final report = storage.generateTextReport(storage.items.first);
      expect(report, contains('SMART MEASURE - AUDIT REPORT'));
      expect(report, contains('Boardroom Table'));
      expect(report, contains('2.45 m'));

      // Delete
      await storage.deleteMeasurement('test_123');
      expect(storage.items.isEmpty, isTrue);
    });
  });
}
