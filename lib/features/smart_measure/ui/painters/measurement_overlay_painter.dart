import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/smart_measure_point.dart';
import '../../models/measurement_units.dart';
import '../../services/measurement_math_engine.dart';

/// Renders measurement lines, anchor points, distance tags, and polygon overlays.
class MeasurementOverlayPainter extends CustomPainter {
  final List<SmartMeasurePoint> points;
  final Offset? activeTargetPos;
  final SmartMeasurePoint? activeTargetPoint;
  final DistanceUnit unit;
  final bool isClosedPolygon;
  final int? selectedPointIndex;
  final Color primaryColor;
  final double animationPulse;

  MeasurementOverlayPainter({
    required this.points,
    this.activeTargetPos,
    this.activeTargetPoint,
    required this.unit,
    this.isClosedPolygon = false,
    this.selectedPointIndex,
    this.primaryColor = const Color(0xFF2563EB),
    this.animationPulse = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty && activeTargetPos == null) return;

    // Convert normalized (0..1) screen positions to canvas pixels
    List<Offset> pixelPoints = points.map((p) {
      return Offset(p.screenPosition.dx * size.width, p.screenPosition.dy * size.height);
    }).toList();

    Offset? activePixelPos;
    if (activeTargetPos != null) {
      activePixelPos = Offset(activeTargetPos!.dx * size.width, activeTargetPos!.dy * size.height);
    }

    // 1. Draw Polygon fill if 3 or more points and closed
    if (isClosedPolygon && pixelPoints.length >= 3) {
      final polyPath = Path()..moveTo(pixelPoints[0].dx, pixelPoints[0].dy);
      for (int i = 1; i < pixelPoints.length; i++) {
        polyPath.lineTo(pixelPoints[i].dx, pixelPoints[i].dy);
      }
      polyPath.close();

      final fillPaint = Paint()
        ..color = primaryColor.withOpacity(0.18)
        ..style = PaintingStyle.fill;
      canvas.drawPath(polyPath, fillPaint);
    }

    // 2. Draw measurement lines between placed points
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final shadowPaint = Paint()
      ..color = Colors.black45
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < pixelPoints.length - 1; i++) {
      final p1 = pixelPoints[i];
      final p2 = pixelPoints[i + 1];

      canvas.drawLine(p1, p2, shadowPaint);
      canvas.drawLine(p1, p2, linePaint);

      // Distance tag pill at line midpoint
      final distMeters = MeasurementMathEngine.distance3D(points[i], points[i + 1]);
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _drawDistancePill(canvas, mid, unit.formatMeters(distMeters));
    }

    // If closed polygon, draw line from last point back to first
    if (isClosedPolygon && pixelPoints.length >= 3) {
      final pLast = pixelPoints.last;
      final pFirst = pixelPoints.first;
      canvas.drawLine(pLast, pFirst, shadowPaint);
      canvas.drawLine(pLast, pFirst, linePaint);

      final distMeters = MeasurementMathEngine.distance3D(points.last, points.first);
      final mid = Offset((pLast.dx + pFirst.dx) / 2, (pLast.dy + pFirst.dy) / 2);
      _drawDistancePill(canvas, mid, unit.formatMeters(distMeters));
    }

    // 3. Draw active dynamic dashed/pulsing line from last point to reticle
    if (pixelPoints.isNotEmpty && activePixelPos != null && !isClosedPolygon) {
      final pLast = pixelPoints.last;
      final activePaint = Paint()
        ..color = primaryColor.withOpacity(0.85)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;

      _drawDottedLine(canvas, pLast, activePixelPos, activePaint);

      if (activeTargetPoint != null) {
        final liveDistMeters = MeasurementMathEngine.distance3D(points.last, activeTargetPoint!);
        final mid = Offset((pLast.dx + activePixelPos.dx) / 2, (pLast.dy + activePixelPos.dy) / 2);
        _drawDistancePill(canvas, mid, unit.formatMeters(liveDistMeters), isLive: true);
      }
    }

    // 4. Draw Anchor Points markers
    for (int i = 0; i < pixelPoints.length; i++) {
      final pos = pixelPoints[i];
      final isSelected = selectedPointIndex == i;

      // Outer white ring
      final outerPaint = Paint()
        ..color = isSelected ? const Color(0xFFF59E0B) : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 8.0, outerPaint);

      // Inner dot
      final innerPaint = Paint()
        ..color = isSelected ? Colors.black : primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 5.0, innerPaint);

      // Point index badge
      _drawPointBadge(canvas, Offset(pos.dx, pos.dy - 16), '${i + 1}');
    }
  }

  void _drawDistancePill(Canvas canvas, Offset center, String text, {bool isLive = false}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: isLive ? primaryColor : Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final pillWidth = textPainter.width + 16;
    final pillHeight = textPainter.height + 8;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: pillWidth, height: pillHeight),
      const Radius.circular(10),
    );

    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isLive ? primaryColor.withOpacity(0.9) : Colors.white24
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(pillRect, bgPaint);
    canvas.drawRRect(pillRect, borderPaint);

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  void _drawPointBadge(Canvas canvas, Offset center, String label) {
    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final bgPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 9.0, bgPaint);
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  void _drawDottedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 4) return;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double currentDist = 0.0;

    final cosA = dx / dist;
    final sinA = dy / dist;

    while (currentDist < dist) {
      final start = Offset(p1.dx + currentDist * cosA, p1.dy + currentDist * sinA);
      currentDist += dashWidth;
      final end = Offset(p1.dx + math.min(currentDist, dist) * cosA, p1.dy + math.min(currentDist, dist) * sinA);
      canvas.drawLine(start, end, paint);
      currentDist += dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant MeasurementOverlayPainter oldDelegate) {
    return true;
  }
}
