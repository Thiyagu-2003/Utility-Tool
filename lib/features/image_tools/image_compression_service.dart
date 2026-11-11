import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Supported image formats for compression and export
enum ImageCompressionFormat {
  original('Keep Original', ''),
  jpeg('JPEG (.jpg)', 'jpg'),
  png('PNG (.png)', 'png'),
  webp('WebP (.webp)', 'webp');

  final String label;
  final String extension;
  const ImageCompressionFormat(this.label, this.extension);
}

/// Compression Quality Presets
enum QualityPreset {
  low('Low', 40, 'Smaller file size'),
  medium('Medium', 70, 'Balanced compression'),
  high('High', 90, 'Good visual quality'),
  best('Best', 98, 'Maximum visual quality');

  final String label;
  final int quality;
  final String description;
  const QualityPreset(this.label, this.quality, this.description);
}

/// Parameters configuring image compression
class CompressionConfig {
  final int quality; // 10 to 100
  final ImageCompressionFormat format;
  final int? customWidth;
  final int? customHeight;
  final bool maintainAspectRatio;
  final int? targetSizeBytes; // in bytes (e.g. 500 * 1024)

  const CompressionConfig({
    this.quality = 90,
    this.format = ImageCompressionFormat.original,
    this.customWidth,
    this.customHeight,
    this.maintainAspectRatio = true,
    this.targetSizeBytes,
  });

  CompressionConfig copyWith({
    int? quality,
    ImageCompressionFormat? format,
    int? customWidth,
    int? customHeight,
    bool? maintainAspectRatio,
    int? targetSizeBytes,
    bool clearTargetSize = false,
    bool clearCustomDimensions = false,
  }) {
    return CompressionConfig(
      quality: quality ?? this.quality,
      format: format ?? this.format,
      customWidth: clearCustomDimensions ? null : (customWidth ?? this.customWidth),
      customHeight: clearCustomDimensions ? null : (customHeight ?? this.customHeight),
      maintainAspectRatio: maintainAspectRatio ?? this.maintainAspectRatio,
      targetSizeBytes: clearTargetSize ? null : (targetSizeBytes ?? this.targetSizeBytes),
    );
  }
}

/// Result of a compression operation
class CompressionResult {
  final Uint8List bytes;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final int originalWidth;
  final int originalHeight;
  final int outputWidth;
  final int outputHeight;
  final String outputFormatName;
  final String outputExtension;
  final int achievedQuality;
  final bool targetSizeReached;
  final String? warningMessage;

  const CompressionResult({
    required this.bytes,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.outputWidth,
    required this.outputHeight,
    required this.outputFormatName,
    required this.outputExtension,
    required this.achievedQuality,
    this.targetSizeReached = true,
    this.warningMessage,
  });

  int get bytesSaved => originalSizeBytes - compressedSizeBytes;
  double get compressionPercentage {
    if (originalSizeBytes <= 0) return 0.0;
    return (bytesSaved / originalSizeBytes) * 100.0;
  }
}

/// Service providing core image compression, format adaptation, and target size search
class ImageCompressionService {
  /// Detects the format of an image from its magic header bytes
  static ImageCompressionFormat detectFormat(Uint8List bytes) {
    if (bytes.length < 12) return ImageCompressionFormat.jpeg;
    // JPEG magic: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return ImageCompressionFormat.jpeg;
    }
    // PNG magic: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return ImageCompressionFormat.png;
    }
    // WebP magic: RIFF .... WEBP
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
      if (bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
        return ImageCompressionFormat.webp;
      }
    }
    return ImageCompressionFormat.jpeg;
  }

  /// Compresses [bytes] according to [config]
  static CompressionResult? processImage(Uint8List bytes, CompressionConfig config) {
    if (bytes.length < 8) return null;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final origW = decoded.width;
    final origH = decoded.height;
    final detected = detectFormat(bytes);

    // Resolve target format
    ImageCompressionFormat targetFmt = config.format;
    if (targetFmt == ImageCompressionFormat.original) {
      targetFmt = detected;
    }

    // Dimension handling: Preserve original by default!
    img.Image workingImage = decoded;
    if (config.customWidth != null || config.customHeight != null) {
      int targetW = config.customWidth ?? origW;
      int targetH = config.customHeight ?? origH;

      if (config.maintainAspectRatio) {
        if (config.customWidth != null && config.customHeight == null) {
          targetH = (origH * targetW / origW).round();
        } else if (config.customHeight != null && config.customWidth == null) {
          targetW = (origW * targetH / origH).round();
        } else if (config.customWidth != null && config.customHeight != null) {
          final ratioW = targetW / origW;
          final ratioH = targetH / origH;
          final scale = min(ratioW, ratioH);
          targetW = (origW * scale).round();
          targetH = (origH * scale).round();
        }
      }
      targetW = max(1, targetW);
      targetH = max(1, targetH);

      if (targetW != origW || targetH != origH) {
        workingImage = img.copyResize(
          decoded,
          width: targetW,
          height: targetH,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    final outW = workingImage.width;
    final outH = workingImage.height;

    // Check target size compression search
    if (config.targetSizeBytes != null && config.targetSizeBytes! > 0) {
      return _compressToTargetSize(
        image: workingImage,
        targetBytes: config.targetSizeBytes!,
        format: targetFmt,
        originalSizeBytes: bytes.length,
        origW: origW,
        origH: origH,
      );
    }

    // Direct quality compression
    int quality = config.quality.clamp(10, 100);
    final (encoded, achievedQ) = _encodeImage(workingImage, targetFmt, quality);

    return CompressionResult(
      bytes: encoded,
      originalSizeBytes: bytes.length,
      compressedSizeBytes: encoded.length,
      originalWidth: origW,
      originalHeight: origH,
      outputWidth: outW,
      outputHeight: outH,
      outputFormatName: targetFmt.label,
      outputExtension: targetFmt.extension,
      achievedQuality: achievedQ,
      targetSizeReached: true,
    );
  }

  /// Encodes image to target format preserving transparency where supported
  static (Uint8List, int) _encodeImage(img.Image image, ImageCompressionFormat format, int quality) {
    switch (format) {
      case ImageCompressionFormat.png:
        // PNG level 0-9 (lossless optimization)
        final level = ((100 - quality) / 10).round().clamp(0, 9);
        final encoded = img.encodePng(image, level: level);
        return (Uint8List.fromList(encoded), quality);

      case ImageCompressionFormat.webp:
        // WebP quality 1-100 (lossy or lossless, supports transparency)
        final encoder = img.WebPEncoder(
          lossless: quality >= 99,
          quality: quality,
        );
        final encoded = encoder.encode(image);
        return (Uint8List.fromList(encoded), quality);

      case ImageCompressionFormat.jpeg:
      case ImageCompressionFormat.original:
        // JPEG does not support alpha, so flatten onto white
        final flattened = _flattenOnWhiteIfAlpha(image);
        final encoded = img.encodeJpg(flattened, quality: quality);
        return (Uint8List.fromList(encoded), quality);
    }
  }

  /// Flattens image onto a solid white background only if alpha is present
  static img.Image _flattenOnWhiteIfAlpha(img.Image src) {
    if (!src.hasAlpha) return src;
    final bg = img.Image(width: src.width, height: src.height);
    img.fill(bg, color: img.ColorRgb8(255, 255, 255));
    return img.compositeImage(bg, src);
  }

  /// Attempts binary search on quality to meet target file size
  static CompressionResult _compressToTargetSize({
    required img.Image image,
    required int targetBytes,
    required ImageCompressionFormat format,
    required int originalSizeBytes,
    required int origW,
    required int origH,
  }) {
    int lowQ = 10;
    int highQ = 98;
    int bestQ = lowQ;
    Uint8List? bestBytes;

    while (lowQ <= highQ) {
      final midQ = (lowQ + highQ) ~/ 2;
      final (encoded, _) = _encodeImage(image, format, midQ);

      if (encoded.length <= targetBytes) {
        bestQ = midQ;
        bestBytes = encoded;
        lowQ = midQ + 1;
      } else {
        highQ = midQ - 1;
      }
    }

    if (bestBytes != null) {
      return CompressionResult(
        bytes: bestBytes,
        originalSizeBytes: originalSizeBytes,
        compressedSizeBytes: bestBytes.length,
        originalWidth: origW,
        originalHeight: origH,
        outputWidth: image.width,
        outputHeight: image.height,
        outputFormatName: format.label,
        outputExtension: format.extension,
        achievedQuality: bestQ,
        targetSizeReached: true,
      );
    }

    final (minQBytes, _) = _encodeImage(image, format, 10);
    final targetKb = (targetBytes / 1024).round();
    final achievedKb = (minQBytes.length / 1024).round();

    return CompressionResult(
      bytes: minQBytes,
      originalSizeBytes: originalSizeBytes,
      compressedSizeBytes: minQBytes.length,
      originalWidth: origW,
      originalHeight: origH,
      outputWidth: image.width,
      outputHeight: image.height,
      outputFormatName: format.label,
      outputExtension: format.extension,
      achievedQuality: 10,
      targetSizeReached: false,
      warningMessage:
          'Target of $targetKb KB is too small for this image without excessive distortion (lowest size achieved: $achievedKb KB at 10% quality). Consider resizing dimensions or selecting a higher target size.',
    );
  }
}
