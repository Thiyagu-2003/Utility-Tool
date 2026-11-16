import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Predefined real-world reference items for pixel-to-metric calibration.
enum ReferenceItemType {
  creditCard(
    'Standard Credit / ID Card (ISO/IEC 7810)',
    'Universal 85.60 mm width',
    85.6,
    Icons.credit_card_rounded,
  ),
  a4PaperLength(
    'A4 Paper (Long Edge)',
    'ISO 216 standard: 297.0 mm',
    297.0,
    Icons.description_rounded,
  ),
  a4PaperWidth(
    'A4 Paper (Short Edge)',
    'ISO 216 standard: 210.0 mm',
    210.0,
    Icons.insert_drive_file_outlined,
  ),
  usQuarter(
    'US Quarter (Coin)',
    'United States 25¢: 24.26 mm',
    24.26,
    Icons.monetization_on_rounded,
  ),
  euroOne(
    'Euro 1€ (Coin)',
    'European Union 1€: 23.25 mm',
    23.25,
    Icons.euro_rounded,
  ),
  inrTen(
    'Indian ₹10 Coin',
    'Bi-metallic 10 Rupee coin: 27.0 mm',
    27.0,
    Icons.currency_rupee_rounded,
  ),
  ruler30cm(
    'Standard 30 cm Ruler',
    'Metric drafting scale: 300.0 mm',
    300.0,
    Icons.straighten_rounded,
  ),
  ruler12in(
    'Standard 12 inch Ruler',
    'Imperial drafting scale: 304.8 mm',
    304.8,
    Icons.straighten_rounded,
  ),
  custom(
    'Custom Known Dimension',
    'Enter user-defined physical measurement',
    100.0,
    Icons.edit_road_rounded,
  );

  final String title;
  final String description;
  final double defaultLengthMm;
  final IconData icon;

  const ReferenceItemType(this.title, this.description, this.defaultLengthMm, this.icon);
}

/// Represents the calibration state of an image.
class ImageCalibration {
  final ReferenceItemType referenceType;
  final double referenceRealMm;
  final Offset refStartPoint;
  final Offset refEndPoint;
  final double pixelDistance;

  /// Millimeters per screen/image pixel: (Real mm / pixel distance).
  final double mmPerPixel;

  const ImageCalibration({
    required this.referenceType,
    required this.referenceRealMm,
    required this.refStartPoint,
    required this.refEndPoint,
    required this.pixelDistance,
    required this.mmPerPixel,
  });

  factory ImageCalibration.fromPoints({
    required ReferenceItemType referenceType,
    required double referenceRealMm,
    required Offset start,
    required Offset end,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final pixelDist = math.sqrt(dx * dx + dy * dy);
    final safePixelDist = pixelDist > 1.0 ? pixelDist : 1.0;
    final mmPerPx = referenceRealMm / safePixelDist;

    return ImageCalibration(
      referenceType: referenceType,
      referenceRealMm: referenceRealMm,
      refStartPoint: start,
      refEndPoint: end,
      pixelDistance: pixelDist,
      mmPerPixel: mmPerPx,
    );
  }

  /// Measure physical distance in millimeters between two arbitrary image points.
  double measureDistanceMm(Offset p1, Offset p2) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final pixelDist = math.sqrt(dx * dx + dy * dy);
    return pixelDist * mmPerPixel;
  }

  /// Measure physical area in square millimeters from polygon vertices.
  double measurePolygonAreaSqMm(List<Offset> polygon) {
    if (polygon.length < 3) return 0.0;
    double area = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      area += polygon[i].dx * polygon[j].dy;
      area -= polygon[j].dx * polygon[i].dy;
    }
    final pixelArea = (area.abs() / 2.0);
    // Area scale factor = (mm / pixel)²
    return pixelArea * (mmPerPixel * mmPerPixel);
  }

  static const String perspectiveDisclaimer =
      'Important Notice: 2D image measurements assume that both the reference object and target objects lie in the exact same plane perpendicular to the camera axis. Out-of-plane tilt, perspective distortion, or lens curvature can introduce estimation error.';
}
