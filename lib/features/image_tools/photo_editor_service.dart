import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart' show Color, Offset;
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
    final copy = img.Image(width: width, height: height, numChannels: 4);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final p = source.getPixel(x, y);
        copy.setPixelRgba(x, y, p.r, p.g, p.b, p.a);
      }
    }

    // Tolerance distance scaled to 0-441 Euclidean RGB distance
    final maxDist = (tolerance / 100.0) * 255.0;

    if (floodFillFromEdges) {
      // 2D visited array
      final visited = Uint8List(width * height);
      final queue = <int>[];

      void checkAndEnqueue(int x, int y) {
        if (x < 0 || x >= width || y < 0 || y >= height) return;
        final idx = y * width + x;
        if (visited[idx] == 1) return;

        final pixel = copy.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        // Euclidean color distance
        final dist = sqrt(
          (r - sampleR) * (r - sampleR) +
          (g - sampleG) * (g - sampleG) +
          (b - sampleB) * (b - sampleB),
        );

        if (dist <= maxDist) {
          visited[idx] = 1;
          queue.add(idx);
        }
      }

      // Enqueue border pixels
      for (int x = 0; x < width; x++) {
        checkAndEnqueue(x, 0);
        checkAndEnqueue(x, height - 1);
      }
      for (int y = 0; y < height; y++) {
        checkAndEnqueue(0, y);
        checkAndEnqueue(width - 1, y);
      }

      // BFS flood fill
      int head = 0;
      while (head < queue.length) {
        final current = queue[head++];
        final cx = current % width;
        final cy = current ~/ width;

        // Make transparent
        copy.setPixelRgba(cx, cy, 0, 0, 0, 0);

        checkAndEnqueue(cx + 1, cy);
        checkAndEnqueue(cx - 1, cy);
        checkAndEnqueue(cx, cy + 1);
        checkAndEnqueue(cx, cy - 1);
      }
    } else {
      // Direct color range keying across whole image
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = copy.getPixel(x, y);
          final dist = sqrt(
            pow(pixel.r - sampleR, 2) +
            pow(pixel.g - sampleG, 2) +
            pow(pixel.b - sampleB, 2),
          );
          if (dist <= maxDist) {
            copy.setPixelRgba(x, y, 0, 0, 0, 0);
          }
        }
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
    final imgGamma = 1.0 + gamma;

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

  /// Blur or pixelate specific sensitive rectangular areas (e.g. faces, license plates)
  static img.Image applyBlurAreas(img.Image source, List<BlurArea> areas) {
    if (areas.isEmpty) return source;
    final result = img.Image.from(source);
    final w = result.width;
    final h = result.height;

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
        final blockSize = max(4, area.intensity);
        processed = img.pixelate(cropped, size: blockSize);
      } else {
        final radius = max(2, area.intensity);
        processed = img.gaussianBlur(cropped, radius: radius);
      }

      // Composite processed region back into the original image
      img.compositeImage(result, processed, dstX: startX, dstY: startY);
    }

    return result;
  }
}
