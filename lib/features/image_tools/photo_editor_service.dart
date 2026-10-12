import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart' show Color, Offset, Size;
import 'package:image/image.dart' as img;

/// Represents a region to blur or pixelate for privacy/censorship.
class BlurArea {
  final double x; // Normalized 0.0 to 1.0
  final double y; // Normalized 0.0 to 1.0
  final double width; // Normalized 0.0 to 1.0
  final double height; // Normalized 0.0 to 1.0
  final int intensity; // Blur radius or pixel block size (e.g. 5 to 50)
  final bool isMosaic; // True = pixelate/mosaic, False = gaussian blur

  const BlurArea({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.intensity = 15,
    this.isMosaic = false,
  });

  BlurArea copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    int? intensity,
    bool? isMosaic,
  }) {
    return BlurArea(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      intensity: intensity ?? this.intensity,
      isMosaic: isMosaic ?? this.isMosaic,
    );
  }
}

/// Drawing stroke for image annotation
class AnnotationStroke {
  final List<Offset> points; // Normalized 0.0 to 1.0
  final Color color;
  final double strokeWidth;
  final String tool; // 'pen', 'highlighter', 'arrow', 'rect', 'circle', 'line'

  AnnotationStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.tool,
  });
}

/// Core offline pure-Dart photo processing engine
class PhotoEditorService {
  /// Expands palette / 16-bit / float images to 8-bit RGBA so per-pixel 0-255 maths,
  /// colour sampling and drawing behave. Plain 8-bit images are returned unchanged.
  static img.Image toRgba8(img.Image src) {
    if (!src.hasPalette && src.format == img.Format.uint8) return src;
    return src.convert(format: img.Format.uint8, numChannels: 4);
  }

  /// Decodes [bytes] for editing: 8-bit RGBA, upright (the JPEG decoder applies EXIF
  /// orientation), longest side capped at [maxSide] so a 100 MP photo cannot exhaust memory.
  /// Also returns a PNG preview of at most [previewSide] px for on-screen display.
  /// Null if the bytes are not a decodable image. Heavy: call through [loadForEditingInBackground].
  static ({img.Image image, Uint8List preview, int originalWidth, int originalHeight})? loadForEditing(
    Uint8List bytes, {
    int maxSide = 4096,
    int previewSide = 1280,
  }) {
    final raw = img.decodeImage(bytes);
    if (raw == null) return null;
    var image = toRgba8(raw);
    final originalWidth = image.width;
    final originalHeight = image.height;
    final longest = max(originalWidth, originalHeight);
    if (longest > maxSide) {
      image = originalWidth >= originalHeight
          ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.linear)
          : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.linear);
    }
    final preview = max(image.width, image.height) > previewSide
        ? (image.width >= image.height
            ? img.copyResize(image, width: previewSide, interpolation: img.Interpolation.linear)
            : img.copyResize(image, height: previewSide, interpolation: img.Interpolation.linear))
        : image;
    return (
      image: image,
      preview: Uint8List.fromList(img.encodePng(preview)),
      originalWidth: originalWidth,
      originalHeight: originalHeight,
    );
  }

  // The *InBackground helpers run the heavy pixel work on another isolate so the UI
  // never freezes. They are static (no `this`) so the isolate closure stays sendable.

  static Future<({img.Image image, Uint8List preview, int originalWidth, int originalHeight})?> loadForEditingInBackground(
          Uint8List bytes) =>
      Isolate.run(() => loadForEditing(bytes));

  static Future<(img.Image, Uint8List)> removeBackgroundInBackground(
    img.Image source, {
    required int sampleR,
    required int sampleG,
    required int sampleB,
    required double tolerance,
    required bool floodFillFromEdges,
  }) =>
      Isolate.run(() {
        final cutout = removeBackground(
          source,
          sampleR: sampleR,
          sampleG: sampleG,
          sampleB: sampleB,
          tolerance: tolerance,
          floodFillFromEdges: floodFillFromEdges,
        );
        return (cutout, Uint8List.fromList(img.encodePng(cutout)));
      });

  static Future<Uint8List> replaceBackgroundInBackground(img.Image cutout, {Color? solidColor, List<Color>? gradientColors}) =>
      Isolate.run(() => Uint8List.fromList(img.encodePng(replaceBackground(cutout, solidColor: solidColor, gradientColors: gradientColors))));

  static Future<Uint8List> adjustImageInBackground(
    img.Image source, {
    required double brightness,
    required double contrast,
    required double saturation,
    required double sharpness,
    required double gamma,
    required double vignette,
  }) =>
      Isolate.run(() => Uint8List.fromList(img.encodePng(adjustImage(
            source: source,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            sharpness: sharpness,
            gamma: gamma,
            vignette: vignette,
          ))));

  static Future<Uint8List> applyFilterInBackground(img.Image source, String filterName) =>
      Isolate.run(() => Uint8List.fromList(img.encodePng(applyFilter(source, filterName))));

  static Future<Uint8List> applyBlurAreasInBackground(img.Image source, List<BlurArea> areas) =>
      Isolate.run(() => Uint8List.fromList(img.encodePng(applyBlurAreas(source, areas))));

  static Future<Uint8List> applyWatermarkInBackground(
    img.Image source, {
    img.Image? logo,
    required double logoScale,
    required double logoOpacity,
    required int logoAnchor,
    required String text,
    required double textSize,
    required bool textBackground,
  }) =>
      Isolate.run(() => Uint8List.fromList(img.encodePng(applyWatermark(
            source,
            logo: logo,
            logoScale: logoScale,
            logoOpacity: logoOpacity,
            logoAnchor: logoAnchor,
            text: text,
            textSize: textSize,
            textBackground: textBackground,
          ))));

  /// Smart background removal with chroma/tolerance & flood fill
  static img.Image removeBackground(
    img.Image source, {
    required int sampleR,
    required int sampleG,
    required int sampleB,
    double tolerance = 25.0, // 0 to 100
    bool floodFillFromEdges = true,
  }) {
    final width = source.width;
    final height = source.height;
    // A private single-frame 8-bit RGBA copy, edited straight in its byte buffer
    // (getPixel/setPixel per pixel is an order of magnitude slower on large photos).
    final copy = source.convert(format: img.Format.uint8, numChannels: 4, noAnimation: true);
    final bytes = copy.toUint8List();

    // Tolerance distance scaled to 0-255 (of the 0-441 Euclidean RGB range), compared squared.
    final maxDist = (tolerance / 100.0) * 255.0;
    final maxDist2 = maxDist * maxDist;

    bool matches(int pixel) {
      final o = pixel * 4;
      final dr = bytes[o] - sampleR;
      final dg = bytes[o + 1] - sampleG;
      final db = bytes[o + 2] - sampleB;
      return dr * dr + dg * dg + db * db <= maxDist2;
    }

    void clear(int pixel) {
      final o = pixel * 4;
      bytes[o] = 0;
      bytes[o + 1] = 0;
      bytes[o + 2] = 0;
      bytes[o + 3] = 0;
    }

    if (floodFillFromEdges) {
      final seen = Uint8List(width * height);
      // Every pixel is queued at most once, so a fixed-size queue is enough.
      final queue = Int32List(width * height);
      var tail = 0;

      void visit(int x, int y) {
        if (x < 0 || x >= width || y < 0 || y >= height) return;
        final idx = y * width + x;
        if (seen[idx] == 1) return;
        seen[idx] = 1;
        if (matches(idx)) queue[tail++] = idx;
      }

      for (int x = 0; x < width; x++) {
        visit(x, 0);
        visit(x, height - 1);
      }
      for (int y = 0; y < height; y++) {
        visit(0, y);
        visit(width - 1, y);
      }

      var head = 0;
      while (head < tail) {
        final current = queue[head++];
        final cx = current % width;
        final cy = current ~/ width;
        clear(current);
        visit(cx + 1, cy);
        visit(cx - 1, cy);
        visit(cx, cy + 1);
        visit(cx, cy - 1);
      }
    } else {
      // Direct color range keying across whole image
      for (int i = 0; i < width * height; i++) {
        if (matches(i)) clear(i);
      }
    }

    return copy;
  }

  /// Replaces transparent background with solid color or gradient
  static img.Image replaceBackground(
    img.Image cutout, {
    Color? solidColor,
    List<Color>? gradientColors,
    bool isVertical = true,
  }) {
    final width = cutout.width;
    final height = cutout.height;
    final output = img.Image(width: width, height: height, numChannels: 4);

    if (gradientColors != null && gradientColors.length >= 2) {
      final c1 = gradientColors.first;
      final c2 = gradientColors.last;

      final c1R = (c1.r * 255.0).round().clamp(0, 255);
      final c1G = (c1.g * 255.0).round().clamp(0, 255);
      final c1B = (c1.b * 255.0).round().clamp(0, 255);

      final c2R = (c2.r * 255.0).round().clamp(0, 255);
      final c2G = (c2.g * 255.0).round().clamp(0, 255);
      final c2B = (c2.b * 255.0).round().clamp(0, 255);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final t = isVertical ? (y / (height > 1 ? height - 1 : 1)) : (x / (width > 1 ? width - 1 : 1));
          final r = ((1 - t) * c1R + t * c2R).round().clamp(0, 255);
          final g = ((1 - t) * c1G + t * c2G).round().clamp(0, 255);
          final b = ((1 - t) * c1B + t * c2B).round().clamp(0, 255);
          output.setPixelRgba(x, y, r, g, b, 255);
        }
      }
    } else if (solidColor != null) {
      final r = (solidColor.r * 255.0).round().clamp(0, 255);
      final g = (solidColor.g * 255.0).round().clamp(0, 255);
      final b = (solidColor.b * 255.0).round().clamp(0, 255);
      final a = (solidColor.a * 255.0).round().clamp(0, 255);
      img.fill(output, color: img.ColorRgba8(r, g, b, a));
    }

    // Blend cutout on top of background
    img.compositeImage(output, cutout);
    return output;
  }

  /// Adjusts brightness, contrast, saturation, sharpness, gamma, vignette
  static img.Image adjustImage({
    required img.Image source,
    double brightness = 0.0, // -1.0 to 1.0
    double contrast = 0.0, // -1.0 to 1.0
    double saturation = 0.0, // -1.0 to 1.0
    double sharpness = 0.0, // 0.0 to 1.0
    double gamma = 0.0, // -1.0 to 1.0
    double vignette = 0.0, // 0.0 to 1.0
  }) {
    var result = img.Image.from(source);

    // 1. Color adjustments
    final imgBrightness = 1.0 + brightness;
    final imgContrast = 1.0 + contrast;
    final imgSaturation = 1.0 + saturation;
    // Positive exposure must brighten: image's gamma < 1 brightens, > 1 darkens.
    final imgGamma = pow(2.0, -gamma).toDouble();

    if (brightness != 0.0 || contrast != 0.0 || saturation != 0.0 || gamma != 0.0) {
      result = img.adjustColor(
        result,
        brightness: imgBrightness.clamp(0.0, 3.0),
        contrast: imgContrast.clamp(0.0, 3.0),
        saturation: imgSaturation.clamp(0.0, 3.0),
        gamma: imgGamma.clamp(0.1, 3.0),
      );
    }

    // 2. Sharpness via 3x3 unsharp convolution kernel
    if (sharpness > 0.01) {
      final s = sharpness * 1.5;
      final kernel = [
        0.0, -s, 0.0,
        -s, 1.0 + 4.0 * s, -s,
        0.0, -s, 0.0,
      ];
      result = img.convolution(result, filter: kernel);
    }

    // 3. Vignette
    if (vignette > 0.01) {
      result = img.vignette(result, start: 1.0 - (vignette * 0.6), end: 1.0);
    }

    return result;
  }

  /// Preset filters
  static img.Image applyFilter(img.Image source, String filterName) {
    var copy = img.Image.from(source);

    switch (filterName) {
      case 'Vintage':
        copy = img.sepia(copy, amount: 0.4);
        copy = img.adjustColor(copy, contrast: 1.15, saturation: 0.85);
        copy = img.vignette(copy, start: 0.6, end: 1.0);
        break;
      case 'Sepia':
        copy = img.sepia(copy, amount: 0.9);
        break;
      case 'B&W':
        copy = img.grayscale(copy);
        break;
      case 'Film Noir':
        copy = img.grayscale(copy);
        copy = img.adjustColor(copy, contrast: 1.6, brightness: 0.9);
        copy = img.vignette(copy, start: 0.5, end: 1.0);
        break;
      case 'Warm Sun':
        copy = img.adjustColor(copy, brightness: 1.05, saturation: 1.25);
        // Boost warm tones
        for (final pixel in copy) {
          final r = (pixel.r * 1.1).round().clamp(0, 255);
          final b = (pixel.b * 0.9).round().clamp(0, 255);
          pixel.r = r;
          pixel.b = b;
        }
        break;
      case 'Cool Ice':
        copy = img.adjustColor(copy, brightness: 1.05, saturation: 1.1);
        for (final pixel in copy) {
          final r = (pixel.r * 0.85).round().clamp(0, 255);
          final b = (pixel.b * 1.2).round().clamp(0, 255);
          pixel.r = r;
          pixel.b = b;
        }
        break;
      case 'Cyberpunk':
        copy = img.adjustColor(copy, contrast: 1.35, saturation: 1.5);
        for (final pixel in copy) {
          if (pixel.r > pixel.g) {
            pixel.r = (pixel.r * 1.2).round().clamp(0, 255);
            pixel.b = (pixel.b * 1.2).round().clamp(0, 255);
          } else {
            pixel.b = (pixel.b * 1.3).round().clamp(0, 255);
            pixel.g = (pixel.g * 1.1).round().clamp(0, 255);
          }
        }
        break;
      case 'Emerald':
        copy = img.adjustColor(copy, contrast: 1.2, saturation: 1.2);
        for (final pixel in copy) {
          pixel.g = (pixel.g * 1.25).round().clamp(0, 255);
        }
        break;
      case 'HDR Pop':
        copy = img.adjustColor(copy, contrast: 1.4, saturation: 1.45, brightness: 1.1);
        copy = img.convolution(copy, filter: [
          0.0, -0.4, 0.0,
          -0.4, 2.6, -0.4,
          0.0, -0.4, 0.0,
        ]);
        break;
      case 'Pixelate':
        copy = img.pixelate(copy, size: 12);
        break;
      case 'Invert':
        copy = img.invert(copy);
        break;
      case 'Original':
      default:
        break;
    }

    return copy;
  }

  /// Intensity is defined for a ~1000 px photo; bigger photos scale it up, otherwise a
  /// 15 px mosaic on a 4000 px picture would leave a face easy to recognise.
  static double censorScale(int width, int height) => max(1.0, max(width, height) / 1000.0);

  /// Blur or pixelate specific sensitive rectangular areas (e.g. faces, license plates)
  static img.Image applyBlurAreas(img.Image source, List<BlurArea> areas) {
    if (areas.isEmpty) return source;
    final result = img.Image.from(source);
    final w = result.width;
    final h = result.height;
    final scale = censorScale(w, h);

    for (final area in areas) {
      final startX = (area.x * w).round().clamp(0, w - 1);
      final startY = (area.y * h).round().clamp(0, h - 1);
      final boxW = (area.width * w).round().clamp(1, w - startX);
      final boxH = (area.height * h).round().clamp(1, h - startY);

      if (boxW <= 0 || boxH <= 0) continue;

      // Crop the target region
      final cropped = img.copyCrop(result, x: startX, y: startY, width: boxW, height: boxH);

      img.Image processed;
      if (area.isMosaic) {
        final blockSize = max(4, (area.intensity * scale).round());
        processed = img.pixelate(cropped, size: blockSize);
      } else {
        final radius = max(2, (area.intensity * scale).round());
        processed = img.gaussianBlur(cropped, radius: radius);
      }

      // Composite processed region back into the original image
      // Direct copy: alpha blending would let original detail show through translucent pixels.
      img.compositeImage(result, processed, dstX: startX, dstY: startY, blend: img.BlendMode.direct);
    }

    return result;
  }

// --- ANNOTATION GEOMETRY ---  /// Stroke widths and arrowheads are defined for a canvas this wide and scale with it.  static const double annotationReferenceWidth = 360;  /// A touch position on a [canvas] as a 0..1 fraction of it (clamped), the form strokes are stored in.  static Offset normalizePoint(Offset local, Size canvas) => Offset(        (local.dx / canvas.width).clamp(0.0, 1.0),        (local.dy / canvas.height).clamp(0.0, 1.0),      );
  // --- ANNOTATION GEOMETRY ---

  /// Stroke widths and arrowheads are defined for a canvas this wide and scale with it.
  static const double annotationReferenceWidth = 360;

  /// A touch position on a [canvas] as a 0..1 fraction of it (clamped), the form strokes are stored in.
  static Offset normalizePoint(Offset local, Size canvas) => Offset(
        (local.dx / canvas.width).clamp(0.0, 1.0),
        (local.dy / canvas.height).clamp(0.0, 1.0),
      );

  // --- TEXT & LOGO WATERMARK ---

  /// Top-left origin that places a [w]x[h] item on one of 9 anchors of an [imageW]x[imageH] image.
  /// [anchor] is row * 3 + column: 0 top-left ... 4 centre ... 8 bottom-right. Never negative.
  static (int, int) anchorOrigin(int anchor, int imageW, int imageH, int w, int h, int margin) {
    final col = anchor % 3;
    final row = anchor ~/ 3;
    final x = col == 0 ? margin : (col == 1 ? (imageW - w) ~/ 2 : imageW - w - margin);
    final y = row == 0 ? margin : (row == 1 ? (imageH - h) ~/ 2 : imageH - h - margin);
    return (max(0, x), max(0, y));
  }

  /// A copy of [source] (8-bit RGBA) with every pixel's alpha multiplied by [opacity] (0..1).
  static img.Image applyOpacity(img.Image source, double opacity) {
    final out = toRgba8(source).convert(format: img.Format.uint8, numChannels: 4, noAnimation: true);
    if (opacity >= 1.0) return out;
    final bytes = out.toUint8List();
    final factor = opacity.clamp(0.0, 1.0);
    for (var i = 3; i < bytes.length; i += 4) {
      bytes[i] = (bytes[i] * factor).round();
    }
    return out;
  }

  static int _textWidth(img.BitmapFont font, String text) =>
      text.codeUnits.fold(0, (w, c) => w + (font.characters[c]?.xAdvance ?? font.base ~/ 2));

  /// Text rendered with the nearest bundled bitmap font on a transparent badge, then scaled so it
  /// is [textSize] logical px tall on a 720 px wide photo (proportionally larger on bigger ones).
  /// The bundled fonts only come in 14/24/48 px, so scaling is what makes the slider continuous.
  static img.Image renderTextBadge(String text, double textSize, int imageWidth, {bool background = true}) {
    final targetPx = max(8.0, textSize * imageWidth / 720.0);
    final font = targetPx < 19 ? img.arial14 : (targetPx < 36 ? img.arial24 : img.arial48);
    const padX = 8;
    const padY = 4;
    final badge = img.Image(width: _textWidth(font, text) + padX * 2, height: font.lineHeight + padY * 2, numChannels: 4);
    if (background) {
      img.fillRect(badge, x1: 0, y1: 0, x2: badge.width - 1, y2: badge.height - 1, color: img.ColorRgba8(0, 0, 0, 150), radius: 8);
    }
    img.drawString(badge, text, font: font, x: padX, y: padY, color: img.ColorRgba8(255, 255, 255, 255));

    var scale = targetPx / font.size;
    // Never wider than 90% of the photo.
    scale = min(scale, imageWidth * 0.9 / badge.width);
    if ((scale - 1).abs() < 0.02) return badge;
    return img.copyResize(
      badge,
      width: max(1, (badge.width * scale).round()),
      interpolation: img.Interpolation.linear,
    );
  }

  /// Composites an optional logo ([logoScale] of the photo width, [logoOpacity] 0..1, on one of the
  /// 9 [logoAnchor] cells) and optional text badge (bottom-left) onto a copy of [source].
  static img.Image applyWatermark(
    img.Image source, {
    img.Image? logo,
    double logoScale = 0.25,
    double logoOpacity = 1.0,
    int logoAnchor = 8,
    String text = '',
    double textSize = 28,
    bool textBackground = true,
  }) {
    final base = source.convert(format: img.Format.uint8, numChannels: 4, noAnimation: true);
    final margin = max(10, (base.width * 0.02).round());

    if (logo != null) {
      final targetW = (base.width * logoScale).round().clamp(1, base.width);
      var scaled = img.copyResize(toRgba8(logo), width: targetW, interpolation: img.Interpolation.linear);
      scaled = applyOpacity(scaled, logoOpacity);
      final (x, y) = anchorOrigin(logoAnchor, base.width, base.height, scaled.width, scaled.height, margin);
      img.compositeImage(base, scaled, dstX: x, dstY: y);
    }

    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      final badge = renderTextBadge(trimmed, textSize, base.width, background: textBackground);
      final (x, y) = anchorOrigin(6, base.width, base.height, badge.width, badge.height, margin);
      img.compositeImage(base, badge, dstX: x, dstY: y);
    }
    return base;
  }
}
