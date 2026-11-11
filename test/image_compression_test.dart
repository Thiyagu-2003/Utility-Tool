import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:utility_tool/features/image_tools/image_compression_service.dart';

Uint8List createTestImage({
  int width = 100,
  int height = 80,
  bool withAlpha = false,
  String format = 'PNG',
}) {
  final image = img.Image(width: width, height: height, numChannels: withAlpha ? 4 : 3);
  for (final p in image) {
    p.r = (p.x * 25 + p.y * 13) % 256;
    p.g = (p.x * 7 + p.y * 31) % 256;
    p.b = (p.x * 43 + p.y * 17) % 256;
    if (withAlpha) {
      p.a = (p.x < width ~/ 2) ? 0 : 255; // Left half transparent
    }
  }

  if (format == 'JPEG') {
    final bg = img.Image(width: width, height: height);
    img.fill(bg, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(bg, image);
    return Uint8List.fromList(img.encodeJpg(bg, quality: 90));
  } else if (format == 'WEBP') {
    final encoder = img.WebPEncoder(lossless: false, quality: 80);
    return Uint8List.fromList(encoder.encode(image));
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('Image Compression Service Tests', () {
    test('Format detection recognizes JPEG, PNG, and WebP correctly', () {
      final pngBytes = createTestImage(format: 'PNG');
      final jpgBytes = createTestImage(format: 'JPEG');
      final webpBytes = createTestImage(format: 'WEBP');

      expect(ImageCompressionService.detectFormat(pngBytes), ImageCompressionFormat.png);
      expect(ImageCompressionService.detectFormat(jpgBytes), ImageCompressionFormat.jpeg);
      expect(ImageCompressionService.detectFormat(webpBytes), ImageCompressionFormat.webp);
    });

    test('Preserves original dimensions by default without auto-resizing', () {
      final src = createTestImage(width: 320, height: 240, format: 'JPEG');
      const config = CompressionConfig(quality: 90);

      final result = ImageCompressionService.processImage(src, config)!;
      expect(result.originalWidth, 320);
      expect(result.originalHeight, 240);
      expect(result.outputWidth, 320);
      expect(result.outputHeight, 240);
    });

    test('Allows custom width and height with aspect ratio preservation', () {
      final src = createTestImage(width: 400, height: 200, format: 'JPEG');
      const config = CompressionConfig(
        quality: 85,
        customWidth: 200,
        maintainAspectRatio: true,
      );

      final result = ImageCompressionService.processImage(src, config);
      expect(result, isNotNull);
      expect(result!.outputWidth, 200);
      expect(result.outputHeight, 100); // 2:1 ratio maintained
    });

    test('PNG compression preserves transparency', () {
      final src = createTestImage(width: 80, height: 80, withAlpha: true, format: 'PNG');
      const config = CompressionConfig(
        quality: 90,
        format: ImageCompressionFormat.png,
      );

      final result = ImageCompressionService.processImage(src, config);
      expect(result, isNotNull);
      final decodedOut = img.decodeImage(result!.bytes);
      expect(decodedOut, isNotNull);
      expect(decodedOut!.hasAlpha, true);
      // Verify transparent pixels remain transparent
      final pixel = decodedOut.getPixel(10, 10);
      expect(pixel.a, 0);
    });

    test('WebP compression supports transparency and quality reduction', () {
      final src = createTestImage(width: 80, height: 80, withAlpha: true, format: 'PNG');
      const highQConfig = CompressionConfig(quality: 95, format: ImageCompressionFormat.webp);
      const lowQConfig = CompressionConfig(quality: 20, format: ImageCompressionFormat.webp);

      final highRes = ImageCompressionService.processImage(src, highQConfig)!;
      final lowRes = ImageCompressionService.processImage(src, lowQConfig)!;

      expect(highRes.outputExtension, 'webp');
      expect(lowRes.outputExtension, 'webp');
      expect(lowRes.compressedSizeBytes, lessThan(highRes.compressedSizeBytes));

      final decodedWebp = img.decodeImage(highRes.bytes);
      expect(decodedWebp, isNotNull);
      expect(decodedWebp!.hasAlpha, true);
    });

    test('Quality presets and slider range: 10% to 100%', () {
      final src = createTestImage(width: 150, height: 150, format: 'JPEG');

      final bestResult = ImageCompressionService.processImage(
        src,
        CompressionConfig(quality: QualityPreset.best.quality),
      )!;
      final highResult = ImageCompressionService.processImage(
        src,
        CompressionConfig(quality: QualityPreset.high.quality),
      )!;
      final mediumResult = ImageCompressionService.processImage(
        src,
        CompressionConfig(quality: QualityPreset.medium.quality),
      )!;
      final lowResult = ImageCompressionService.processImage(
        src,
        CompressionConfig(quality: QualityPreset.low.quality),
      )!;

      expect(bestResult.achievedQuality, 98);
      expect(highResult.achievedQuality, 90);
      expect(mediumResult.achievedQuality, 70);
      expect(lowResult.achievedQuality, 40);

      expect(lowResult.compressedSizeBytes, lessThan(mediumResult.compressedSizeBytes));
      expect(mediumResult.compressedSizeBytes, lessThan(bestResult.compressedSizeBytes));
    });

    test('Target file size binary search achieves target within reason', () {
      final src = createTestImage(width: 250, height: 250, format: 'JPEG');
      final originalSize = src.length;

      // Request target file size around 60% of original
      final targetBytes = (originalSize * 0.6).round();
      final config = CompressionConfig(targetSizeBytes: targetBytes);

      final result = ImageCompressionService.processImage(src, config)!;
      expect(result.compressedSizeBytes, lessThanOrEqualTo(targetBytes));
      expect(result.targetSizeReached, true);
    });

    test('Target file size warns clearly when target is too aggressive', () {
      final src = createTestImage(width: 300, height: 300, format: 'JPEG');

      // Request an impossibly tiny size (e.g. 50 bytes)
      const config = CompressionConfig(targetSizeBytes: 50);

      final result = ImageCompressionService.processImage(src, config)!;
      expect(result.targetSizeReached, false);
      expect(result.warningMessage, contains('too small'));
    });

    test('Corrupt or invalid image bytes fail gracefully', () {
      final badData = Uint8List.fromList([1, 2, 3, 4]);
      const config = CompressionConfig(quality: 90);

      final result = ImageCompressionService.processImage(badData, config);
      expect(result, isNull);
    });
  });
}
