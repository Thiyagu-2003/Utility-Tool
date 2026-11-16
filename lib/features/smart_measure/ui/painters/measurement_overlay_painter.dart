import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/smart_measure_point.dart';
import '../../models/measurement_units.dart';
import '../../services/measurement_math_engine.dart';

/// Segment of a measured line between two anchor points on screen.
class RenderedMeasurementSegment {
  final Offset start;
  final Offset end;
  final String label;
  final bool isLive;

  const RenderedMeasurementSegment({
    required this.start,
    required this.end,
    required this.label,
    this.isLive = false,
  });
}

/// Apple Measure style overlay painter (reference Image 2).
/// Renders clean white anchor points, connecting lines, and rotated white measurement capsules.
/// Supports both spatial segments rendering and point-list rendering.
class MeasurementOverlayPainter extends CustomPainter {
  final List<RenderedMeasurementSegment> segments;
  final List<Offset> anchorPoints;
  final Offset? activeStartPoint;
  final Offset? reticleCenter;
  final String? activeDistanceLabel;

  // Optional point-based parameters for specialized mode screens
  final List<SmartMeasurePoint>? points;
  final Offset? activeTargetPos;
  final SmartMeasurePoint? activeTargetPoint;
  final DistanceUnit? unit;
  final bool isClosedPolygon;
  final Color primaryColor;

  MeasurementOverlayPainter({
    List<RenderedMeasurementSegment>? segments,
    List<Offset>? anchorPoints,
    this.activeStartPoint,
    this.reticleCenter,
    this.activeDistanceLabel,
    this.points,
    this.activeTargetPos,
    this.activeTargetPoint,
    this.unit,
    this.isClosedPolygon = false,
    this.primaryColor = Colors.white,
  })  : segments = segments ?? [],
        anchorPoints = anchorPoints ?? [];

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw direct segments if provided
    for (final seg in segments) {
      _drawSegment(canvas, seg.start, seg.end, seg.label, isLive: false);
    }

    // 2. Draw active stretching line from active start point to center reticle
    if (activeStartPoint != null && reticleCenter != null && activeDistanceLabel != null) {
      _drawSegment(canvas, activeStartPoint!, reticleCenter!, activeDistanceLabel!, isLive: true);
    }

    // 3. Draw direct anchor points
    for (final pt in anchorPoints) {
      _drawAnchorPoint(canvas, pt);
    }
    if (activeStartPoint != null) {
      _drawAnchorPoint(canvas, activeStartPoint!);
    }

    // 4. Point-list rendering (for Room, Object Box, Person Height, Angle screens)
    if (points != null && points!.isNotEmpty) {
      _paintPointsList(canvas, size);
    }
  }

  void _paintPointsList(Canvas canvas, Size size) {
    final pts = points!;
    final u = unit ?? DistanceUnit.centimeter;

    List<Offset> pixelPoints = pts.map((p) {
      return Offset(p.screenPosition.dx * size.width, p.screenPosition.dy * size.height);
    }).toList();

    Offset? activePixelPos;
    if (activeTargetPos != null) {
      activePixelPos = Offset(activeTargetPos!.dx * size.width, activeTargetPos!.dy * size.height);
    }

    // Draw polygon fill if closed
    if (isClosedPolygon && pixelPoints.length >= 3) {
      final polyPath = Path()..moveTo(pixelPoints[0].dx, pixelPoints[0].dy);
      for (int i = 1; i < pixelPoints.length; i++) {
        polyPath.lineTo(pixelPoints[i].dx, pixelPoints[i].dy);
      }
      polyPath.close();

      final fillPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill;
      canvas.drawPath(polyPath, fillPaint);
    }

    // Draw lines between points
    for (int i = 0; i < pixelPoints.length - 1; i++) {
      final p1 = pixelPoints[i];
      final p2 = pixelPoints[i + 1];
      final dist = MeasurementMathEngine.distance3D(pts[i], pts[i + 1]);
      _drawSegment(canvas, p1, p2, u.formatMeters(dist), isLive: false);
    }

    // Closed polygon final segment
    if (isClosedPolygon && pixelPoints.length >= 3) {
      final pLast = pixelPoints.last;
      final pFirst = pixelPoints.first;
      final dist = MeasurementMathEngine.distance3D(pts.last, pts.first);
      _drawSegment(canvas, pLast, pFirst, u.formatMeters(dist), isLive: false);
    }

    // Active line from last point to reticle
    if (pixelPoints.isNotEmpty && activePixelPos != null && !isClosedPolygon) {
      final pLast = pixelPoints.last;
      String label = '';
      if (activeTargetPoint != null) {
        final liveDist = MeasurementMathEngine.distance3D(pts.last, activeTargetPoint!);
        label = u.formatMeters(liveDist);
      }
      _drawSegment(canvas, pLast, activePixelPos, label, isLive: true);
    }

    // Draw anchor dots
    for (final pt in pixelPoints) {
      _drawAnchorPoint(canvas, pt);
    }
  }

  void _drawSegment(Canvas canvas, Offset p1, Offset p2, String label, {bool isLive = false}) {
    // Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(p1, p2, shadowPaint);

    // Clean solid white line
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = isLive ? 3.0 : 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(p1, p2, linePaint);

    if (label.isEmpty) return;

    // Midpoint for measurement pill
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

    // Compute line angle for capsule rotation
    double angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    if (angle > math.pi / 2) {
      angle -= math.pi;
    } else if (angle < -math.pi / 2) {
      angle += math.pi;
    }

    _drawMeasurementCapsule(canvas, mid, label, angle, isLive: isLive);
  }

  void _drawAnchorPoint(Canvas canvas, Offset pos) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 8.0, shadowPaint);

    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 6.5, outerPaint);

    final innerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 2.0, innerPaint);
  }

  void _drawMeasurementCapsule(Canvas canvas, Offset center, String text, double angle, {bool isLive = false}) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final pillWidth = textPainter.width + 18;
    final pillHeight = textPainter.height + 10;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: pillWidth, height: pillHeight),
      const Radius.circular(16),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(pillRect.shift(const Offset(0, 1.5)), shadowPaint);

    // Solid white capsule
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(pillRect, bgPaint);

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MeasurementOverlayPainter oldDelegate) => true;
}
