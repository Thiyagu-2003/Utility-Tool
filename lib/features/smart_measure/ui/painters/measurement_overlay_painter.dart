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
  final bool isSelected;
  final String? id;

  const RenderedMeasurementSegment({
    required this.start,
    required this.end,
    required this.label,
    this.isLive = false,
    this.isSelected = false,
    this.id,
  });
}

/// iPhone Measure inspired overlay painter.
/// Renders a dynamic white dotted/dashed tracking line, clearly visible circular
/// endpoint markers, and an auto-rotating measurement label that follows the line's
/// orientation and prevents upside-down text.
class MeasurementOverlayPainter extends CustomPainter {
  final List<RenderedMeasurementSegment> segments;
  final List<Offset> anchorPoints;
  final Offset? activeStartPoint;
  final Offset? reticleCenter;
  final String? activeDistanceLabel;
  final int? selectedAnchorIndex;

  // Optional point-based parameters for specialized mode screens
  final List<SmartMeasurePoint>? points;
  final Offset? activeTargetPos;
  final SmartMeasurePoint? activeTargetPoint;
  final DistanceUnit? unit;
  final bool isClosedPolygon;
  final Color primaryColor;

  /// ARCore mode: lines and points are drawn natively in the camera frame; only draw labels here.
  final bool labelsOnly;

  MeasurementOverlayPainter({
    this.labelsOnly = false,
    List<RenderedMeasurementSegment>? segments,
    List<Offset>? anchorPoints,
    this.activeStartPoint,
    this.reticleCenter,
    this.activeDistanceLabel,
    this.selectedAnchorIndex,
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
    // 1. Draw completed locked segments (dotted line + rotated pill)
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      _drawDottedSegment(
        canvas,
        seg.start,
        seg.end,
        seg.label,
        size,
        isLive: false,
        isSelected: seg.isSelected,
      );
    }

    // 2. Draw live dynamic stretching dotted line from start point to center reticle
    if (activeStartPoint != null && reticleCenter != null && activeDistanceLabel != null) {
      _drawDottedSegment(
        canvas,
        activeStartPoint!,
        reticleCenter!,
        activeDistanceLabel!,
        size,
        isLive: true,
        isSelected: false,
      );
    }

    // 3. Draw circular endpoint markers
    for (int i = 0; i < anchorPoints.length && !labelsOnly; i++) {
      final isSelected = selectedAnchorIndex != null && selectedAnchorIndex == i;
      _drawAnchorMarker(canvas, anchorPoints[i], isSelected: isSelected);
    }

    if (activeStartPoint != null && !labelsOnly) {
      _drawAnchorMarker(canvas, activeStartPoint!);
    }

    // 4. Point-list rendering (for polygon/room mode screens)
    if (points != null && points!.isNotEmpty) {
      _paintPointsList(canvas, size);
    }
  }

  /// Draws a dotted/dashed line with drop shadow, rounded caps, and an auto-rotating label.
  void _drawDottedSegment(
    Canvas canvas,
    Offset p1,
    Offset p2,
    String label,
    Size screenSize, {
    required bool isLive,
    bool isSelected = false,
  }) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final lineLength = math.sqrt(dx * dx + dy * dy);
    if (lineLength <= 1.0) return;

    final ux = dx / lineLength;
    final uy = dy / lineLength;

    final fill = isSelected ? const Color(0xFF60A5FA) : Colors.white;
    if (labelsOnly) {
      // line drawn natively
    } else if (isLive) {
      // Live line: round dots, equal size and spacing, first and last dot exactly on the endpoints.
      _renderDots(canvas, p1, p2, lineLength, 3.2, Paint()..color = Colors.black.withValues(alpha: 0.35)); // contrast halo
      _renderDots(canvas, p1, p2, lineLength, 2.3, Paint()..color = fill);
    } else {
      // Finished measurement: solid line, as iPhone Measure does once the second point is placed.
      final stroke = Paint()
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, stroke..color = Colors.black.withValues(alpha: 0.35)..strokeWidth = 5.0);
      canvas.drawLine(p1, p2, stroke..color = fill..strokeWidth = 3.0);
    }

    if (label.isEmpty) return;

    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

    // Label stays horizontal (always faces the viewer) rather than rotating with the line,
    // which made it swing and jitter as the projected angle changed.
    _drawMeasurementCapsule(
      canvas,
      mid,
      label,
      0,
      lineLength: lineLength,
      lineNormal: Offset(-uy, ux),
      screenSize: screenSize,
      isLive: isLive,
      isSelected: isSelected,
    );
  }

  static const double _dotSpacing = 9.0;

  /// Evenly spaced dots from [a] to [b]: spacing is stretched slightly so dots land on both ends.
  void _renderDots(Canvas canvas, Offset a, Offset b, double length, double radius, Paint paint) {
    final n = math.max(1, (length / _dotSpacing).round());
    for (int i = 0; i <= n; i++) {
      canvas.drawCircle(Offset.lerp(a, b, i / n)!, radius, paint);
    }
  }

  /// Small white endpoint dot (iPhone Measure style). Blue ring only while being dragged.
  void _drawAnchorMarker(Canvas canvas, Offset pos, {bool isSelected = false}) {
    canvas.drawCircle(pos, 6.0, Paint()..color = Colors.black.withValues(alpha: 0.35));
    if (isSelected) {
      canvas.drawCircle(
        pos,
        10.0,
        Paint()
          ..color = const Color(0xFF3B82F6).withValues(alpha: 0.5)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawCircle(pos, 4.8, Paint()..color = isSelected ? const Color(0xFF60A5FA) : Colors.white);
  }

  /// iPhone Measure rotated measurement pill with screen boundary protection
  void _drawMeasurementCapsule(
    Canvas canvas,
    Offset mid,
    String text,
    double angle, {
    required double lineLength,
    required Offset lineNormal,
    required Size screenSize,
    bool isLive = false,
    bool isSelected = false,
  }) {
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

    // Position adjustment: if the line is short, offset perpendicularly to avoid covering endpoints
    Offset capsuleCenter = mid;
    if (lineLength < pillWidth + 24) {
      capsuleCenter = mid + (lineNormal * 24.0);
    }

    // Screen bounds clamping so label never disappears outside the screen
    final clampedX = capsuleCenter.dx.clamp(pillWidth / 2 + 12, screenSize.width - (pillWidth / 2 + 12));
    final clampedY = capsuleCenter.dy.clamp(pillHeight / 2 + 50, screenSize.height - (pillHeight / 2 + 80));
    // Whole-pixel position: sub-pixel tracking noise otherwise makes the text shimmer.
    capsuleCenter = Offset(clampedX.roundToDouble(), clampedY.roundToDouble());

    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: pillWidth, height: pillHeight),
      const Radius.circular(16),
    );

    canvas.save();
    canvas.translate(capsuleCenter.dx, capsuleCenter.dy);
    canvas.rotate(angle);

    // Pill shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    canvas.drawRRect(pillRect.shift(const Offset(0, 1.8)), shadowPaint);

    // Solid white background
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(pillRect, bgPaint);

    // Highlight border if selected
    if (isSelected) {
      final borderPaint = Paint()
        ..color = const Color(0xFF2563EB)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(pillRect, borderPaint);
    }

    // Draw text inside pill
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );

    canvas.restore();
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

    // Draw dotted lines between points
    for (int i = 0; i < pixelPoints.length - 1; i++) {
      final p1 = pixelPoints[i];
      final p2 = pixelPoints[i + 1];
      final dist = MeasurementMathEngine.distance3D(pts[i], pts[i + 1]);
      _drawDottedSegment(canvas, p1, p2, u.formatMeters(dist), size, isLive: false);
    }

    // Closed polygon final segment
    if (isClosedPolygon && pixelPoints.length >= 3) {
      final pLast = pixelPoints.last;
      final pFirst = pixelPoints.first;
      final dist = MeasurementMathEngine.distance3D(pts.last, pts.first);
      _drawDottedSegment(canvas, pLast, pFirst, u.formatMeters(dist), size, isLive: false);
    }

    // Active dotted line from last point to reticle
    if (pixelPoints.isNotEmpty && activePixelPos != null && !isClosedPolygon) {
      final pLast = pixelPoints.last;
      String label = '';
      if (activeTargetPoint != null) {
        final liveDist = MeasurementMathEngine.distance3D(pts.last, activeTargetPoint!);
        label = u.formatMeters(liveDist);
      }
      _drawDottedSegment(canvas, pLast, activePixelPos, label, size, isLive: true);
    }

    // Draw anchor dots
    for (final pt in pixelPoints) {
      _drawAnchorMarker(canvas, pt);
    }
  }

  @override
  bool shouldRepaint(covariant MeasurementOverlayPainter oldDelegate) => true;
}
