import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'slate_models.dart';

class SlateService {
  static final SlateService _instance = SlateService._internal();
  factory SlateService() => _instance;
  SlateService._internal();

  static const String _keyCurrentSlate = 'slate_active_slate';
  static const String _keyMySlates = 'slate_saved_slates_list';

  /// Auto-save the currently open slate
  Future<void> autoSaveCurrent(SlateDocument slate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(slate.toJson());
      await prefs.setString(_keyCurrentSlate, jsonString);
    } catch (_) {}
  }

  /// Load the last active slate, or null if none
  Future<SlateDocument?> loadCurrent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyCurrentSlate);
      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonString);
        return SlateDocument.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Get all saved slates
  Future<List<SlateDocument>> getMySlates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_keyMySlates) ?? [];
      return jsonList
          .map((item) => SlateDocument.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  /// Save or update a slate in the My Slates list
  Future<void> saveToMySlates(SlateDocument slate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getMySlates();
      final index = list.indexWhere((s) => s.id == slate.id);
      slate.updatedAt = DateTime.now();

      if (index >= 0) {
        list[index] = slate;
      } else {
        list.insert(0, slate);
      }

      final encoded = list.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_keyMySlates, encoded);
      await autoSaveCurrent(slate);
    } catch (_) {}
  }

  /// Delete a slate from My Slates
  Future<void> deleteSlate(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getMySlates();
      list.removeWhere((s) => s.id == id);
      final encoded = list.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_keyMySlates, encoded);
    } catch (_) {}
  }

  /// Duplicate a slate
  Future<SlateDocument> duplicateSlate(SlateDocument slate) async {
    final cloned = slate.clone();
    await saveToMySlates(cloned);
    return cloned;
  }

  /// Export canvas to PNG bytes with paper background
  Future<Uint8List> renderCanvasToPng({
    required List<SlateStroke> strokes,
    required SlatePaperType paperType,
    required Size size,
    double pixelRatio = 2.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final width = size.width * pixelRatio;
    final height = size.height * pixelRatio;

    // Scale canvas to match target high-res pixel ratio
    canvas.scale(pixelRatio, pixelRatio);

    // 1. Draw Paper Background
    _drawPaperBackground(canvas, size, paperType);

    // 2. Draw Strokes inside saveLayer so BlendMode.clear only clears stroke layer
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    for (final stroke in strokes) {
      _renderStroke(canvas, stroke);
    }
    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Draw paper background
  static void _drawPaperBackground(Canvas canvas, Size size, SlatePaperType paper) {
    Color bgColor;
    switch (paper) {
      case SlatePaperType.dark:
        bgColor = const Color(0xFF1E293B);
        break;
      case SlatePaperType.blank:
      case SlatePaperType.grid:
      case SlatePaperType.lined:
        bgColor = Colors.white;
        break;
    }

    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (paper == SlatePaperType.grid) {
      final linePaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 1.0;
      const step = 24.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    } else if (paper == SlatePaperType.lined) {
      final linePaint = Paint()
        ..color = const Color(0xFFBFDBFE)
        ..strokeWidth = 1.0;
      const step = 32.0;
      for (double y = 48.0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    } else if (paper == SlatePaperType.dark) {
      final linePaint = Paint()
        ..color = const Color(0xFF334155).withValues(alpha: 0.4)
        ..strokeWidth = 0.8;
      const step = 28.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    }
  }

  /// Draw an individual stroke
  static void _renderStroke(Canvas canvas, SlateStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = stroke.size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (stroke.tool) {
      case SlateToolType.pen:
        paint.color = stroke.color.withValues(alpha: stroke.opacity);
        break;
      case SlateToolType.brush:
        paint.color = stroke.color.withValues(alpha: stroke.opacity);
        paint.strokeWidth = stroke.size * 1.5;
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, (stroke.size * 1.5) * 0.22);
        break;
      case SlateToolType.marker:
        final markerOpacity = (stroke.opacity * 0.38).clamp(0.08, 0.40);
        paint.color = stroke.color.withValues(alpha: markerOpacity);
        paint.strokeWidth = stroke.size * 3.0;
        paint.strokeCap = StrokeCap.square;
        paint.strokeJoin = StrokeJoin.miter;
        break;
      case SlateToolType.eraser:
        paint.blendMode = BlendMode.clear;
        paint.strokeWidth = stroke.size * 2.0;
        break;
      case SlateToolType.line:
      case SlateToolType.box:
      case SlateToolType.circle:
        paint.color = stroke.color.withValues(alpha: stroke.opacity);
        break;
    }

    if (stroke.tool == SlateToolType.line) {
      if (stroke.points.length >= 2) {
        canvas.drawLine(stroke.points.first.toOffset(), stroke.points.last.toOffset(), paint);
      }
      return;
    }

    if (stroke.tool == SlateToolType.box) {
      if (stroke.points.length >= 2) {
        canvas.drawRect(
          Rect.fromPoints(stroke.points.first.toOffset(), stroke.points.last.toOffset()),
          paint,
        );
      }
      return;
    }

    if (stroke.tool == SlateToolType.circle) {
      if (stroke.points.length >= 2) {
        canvas.drawOval(
          Rect.fromPoints(stroke.points.first.toOffset(), stroke.points.last.toOffset()),
          paint,
        );
      }
      return;
    }

    // Freehand drawing (Pen, Brush, Marker, Eraser) with quadratic bezier smoothing
    if (stroke.points.length == 1) {
      final p = stroke.points.first.toOffset();
      canvas.drawCircle(p, paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(stroke.points[0].x, stroke.points[0].y);

    for (int i = 1; i < stroke.points.length; i++) {
      final pPrev = stroke.points[i - 1];
      final pCurr = stroke.points[i];
      final midX = (pPrev.x + pCurr.x) / 2;
      final midY = (pPrev.y + pCurr.y) / 2;
      path.quadraticBezierTo(pPrev.x, pPrev.y, midX, midY);
    }
    path.lineTo(stroke.points.last.x, stroke.points.last.y);

    canvas.drawPath(path, paint);
  }

  /// Share or save image using native share sheet / printer
  Future<void> sharePng(Uint8List bytes, String title) async {
    final sanitized = title.replaceAll(RegExp(r'[^\w\s\.-]'), '_').trim();
    final filename = '${sanitized.isEmpty ? "Slate" : sanitized}.png';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
