import 'package:flutter/material.dart';

enum SlateToolType {
  pen('Pen', Icons.edit_outlined),
  brush('Brush', Icons.brush_outlined),
  marker('Marker', Icons.highlight_outlined),
  eraser('Eraser', Icons.cleaning_services_outlined),
  line('Line', Icons.horizontal_rule_rounded),
  box('Box', Icons.crop_square_rounded),
  circle('Circle', Icons.circle_outlined);

  final String label;
  final IconData icon;
  const SlateToolType(this.label, this.icon);
}

enum SlatePaperType {
  blank('Blank'),
  grid('Grid'),
  lined('Lined'),
  dark('Dark');

  final String label;
  const SlatePaperType(this.label);
}

class SlatePoint {
  final double x;
  final double y;

  const SlatePoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory SlatePoint.fromJson(Map<String, dynamic> json) => SlatePoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );

  Offset toOffset() => Offset(x, y);
}

class SlateStroke {
  final SlateToolType tool;
  final Color color;
  final double size;
  final double opacity;
  final List<SlatePoint> points;

  const SlateStroke({
    required this.tool,
    required this.color,
    required this.size,
    required this.opacity,
    required this.points,
  });

  SlateStroke copyWith({
    SlateToolType? tool,
    Color? color,
    double? size,
    double? opacity,
    List<SlatePoint>? points,
  }) {
    return SlateStroke(
      tool: tool ?? this.tool,
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() => {
        'tool': tool.name,
        'color': color.toARGB32(),
        'size': size,
        'opacity': opacity,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory SlateStroke.fromJson(Map<String, dynamic> json) {
    return SlateStroke(
      tool: SlateToolType.values.firstWhere(
        (t) => t.name == json['tool'],
        orElse: () => SlateToolType.pen,
      ),
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF0F172A),
      size: (json['size'] as num?)?.toDouble() ?? 4.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      points: (json['points'] as List<dynamic>?)
              ?.map((p) => SlatePoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SlateDocument {
  final String id;
  String title;
  DateTime updatedAt;
  SlatePaperType paperType;
  List<SlateStroke> strokes;
  String? thumbnailBase64;

  SlateDocument({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.paperType = SlatePaperType.blank,
    required this.strokes,
    this.thumbnailBase64,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'paperType': paperType.name,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'thumbnailBase64': thumbnailBase64,
      };

  factory SlateDocument.fromJson(Map<String, dynamic> json) {
    return SlateDocument(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled slate',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      paperType: SlatePaperType.values.firstWhere(
        (p) => p.name == json['paperType'],
        orElse: () => SlatePaperType.blank,
      ),
      strokes: (json['strokes'] as List<dynamic>?)
              ?.map((s) => SlateStroke.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      thumbnailBase64: json['thumbnailBase64'] as String?,
    );
  }

  SlateDocument clone({String? newTitle}) {
    return SlateDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: newTitle ?? '$title (Copy)',
      updatedAt: DateTime.now(),
      paperType: paperType,
      strokes: strokes.map((s) => s.copyWith()).toList(),
      thumbnailBase64: thumbnailBase64,
    );
  }
}
