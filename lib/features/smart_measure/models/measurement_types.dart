import 'package:flutter/material.dart';

/// The 15 advanced measurement tools of Smart Measure.
enum SmartMeasureToolType {
  quickMeasure(
    'Quick Measure',
    'Point and tap to measure immediate distance or length between surfaces',
    Icons.flash_on_rounded,
    Color(0xFF2563EB),
    'Instant 2-point direct raycast dimensioning',
  ),
  pointToPoint(
    'Point-to-Point',
    'Multi-point Euclidean 3D distance between marked surface points',
    Icons.linear_scale_rounded,
    Color(0xFF0284C7),
    'Mark consecutive anchors and compute cumulative distance',
  ),
  length(
    'Length Measurement',
    'Accurately measure the primary horizontal span of any object or furniture',
    Icons.straighten_rounded,
    Color(0xFF0D9488),
    'Guided horizontal axis alignment',
  ),
  width(
    'Width Measurement',
    'Measure cross-sectional span perpendicular to the length axis',
    Icons.swap_horiz_rounded,
    Color(0xFF10B981),
    'Guided lateral span measurement',
  ),
  height(
    'Height Measurement',
    'Vertical height from floor or base to ceiling, door, or furniture top',
    Icons.height_rounded,
    Color(0xFF8B5CF6),
    'Gravity-aligned vertical dimensioning',
  ),
  area(
    'Area Measurement',
    'Calculate 2D surface area of rectangles or multi-point polygons',
    Icons.aspect_ratio_rounded,
    Color(0xFF6366F1),
    'Multi-point polygon boundary triangulation',
  ),
  room(
    'Room Measurement',
    'Map wall segments, calculate perimeter, floor area & room dimensions',
    Icons.meeting_room_rounded,
    Color(0xFFD97706),
    'Connected perimeter walls & floor plane estimation',
  ),
  objectDimension(
    'Object Dimension',
    'Full 3D bounding box: length, width, height and estimated volume',
    Icons.view_in_ar_rounded,
    Color(0xFFEC4899),
    'Corner-by-corner 3D bounding box guide',
  ),
  personHeight(
    'Person Height',
    'Measure human height from floor plane to the crown of the head',
    Icons.accessibility_new_rounded,
    Color(0xFFF43F5E),
    'Floor plane lock with vertical crown alignment',
  ),
  distance(
    'Distance Measurement',
    'Live continuous distance from camera lens to any detected surface',
    Icons.track_changes_rounded,
    Color(0xFF06B6D4),
    'Continuous center-reticle depth tracking',
  ),
  angle(
    'Angle Measurement',
    'Calculate the interior and exterior angle formed by three selected points',
    Icons.square_foot_rounded,
    Color(0xFF84CC16),
    'Vertex + 2 arm 3D vector angle calculation',
  ),
  levelTool(
    'Level Tool',
    'High-precision digital level: 2D bullseye bubble, tubular pitch & roll',
    Icons.architecture_rounded,
    Color(0xFFF59E0B),
    'Sensor-driven inclinometer with haptic feedback',
  ),
  surface(
    'Surface Measurement',
    'Measure surface inclination, horizontal/vertical plane tilt and area',
    Icons.layers_rounded,
    Color(0xFF14B8A6),
    'Plane normal vector & inclination slope',
  ),
  manualImage(
    'Manual Image Measurement',
    'Measure objects from captured or selected photos using a known reference',
    Icons.photo_size_select_actual_rounded,
    Color(0xFF3B82F6),
    'Reference-scale calibration (Credit card, A4, Coin)',
  ),
  history(
    'Measurement History',
    'Browse, search, export reports and share saved measurements',
    Icons.history_rounded,
    Color(0xFF64748B),
    'Offline records, PDF reports & photo logs',
  );

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String details;

  const SmartMeasureToolType(
    this.title,
    this.description,
    this.icon,
    this.color,
    this.details,
  );
}
