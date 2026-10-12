import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color, Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:utility_tool/features/image_tools/collage_maker_screen.dart';
import 'package:utility_tool/features/image_tools/image_toolkit_screen.dart';
import 'package:utility_tool/features/image_tools/photo_editor_service.dart';

img.Image _solid(int w, int h, int r, int g, int b, {int a = 255, int channels = 3}) {
  final image = img.Image(width: w, height: h, numChannels: channels);
  img.fill(image, color: img.ColorRgba8(r, g, b, a));
  return image;
}

void main() {
  group('Image Toolkit helpers', () {
    test('withExtension replaces or appends the extension', () {
      expect(withExtension('Compressed_photo.png', 'jpg'), 'Compressed_photo.jpg');
      expect(withExtension('Resized_noext', 'png'), 'Resized_noext.png');
      expect(withExtension('a.b.jpeg', 'gif'), 'a.b.gif');
    });

    test('flattenOnWhite turns transparent pixels white, not black, before JPEG', () {
      final transparent = _solid(4, 4, 0, 0, 0, a: 0, channels: 4);
      final jpg = img.decodeJpg(img.encodeJpg(flattenOnWhite(transparent)))!;
      expect(jpg.getPixel(1, 1).r, greaterThan(240));
    });

    test('cropToAspect centre-crops instead of stretching', () {
      // Left half red, right half blue, 200x100.
      final src = img.Image(width: 200, height: 100);
      img.fillRect(src, x1: 0, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(255, 0, 0));
      img.fillRect(src, x1: 100, y1: 0, x2: 199, y2: 99, color: img.ColorRgb8(0, 0, 255));
      final square = cropToAspect(src, 50, 50);
      expect(square.width, 50);
      expect(square.height, 50);
      // A centre crop keeps both halves; a stretch would too, so check the edges stay pure.
      expect(square.getPixel(0, 25).r, 255);
      expect(square.getPixel(49, 25).b, 255);

      final portrait = cropToAspect(src, 413, 531);
      expect(portrait.width, 413);
      expect(portrait.height, 531);
    });

    test('Base64 round trip keeps the real MIME type and tolerates whitespace / no padding', () {
      final jpg = Uint8List.fromList(img.encodeJpg(_solid(3, 3, 10, 200, 30)));
      expect(imageMimeType(jpg), 'image/jpeg');
      final png = Uint8List.fromList(img.encodePng(_solid(3, 3, 10, 200, 30)));
      expect(imageMimeType(png), 'image/png');

      final uri = 'data:${imageMimeType(png)};base64,${base64Encode(png)}';
      expect(decodeBase64Image(uri), png);

      final wrapped = base64Encode(png).replaceAll('=', '').replaceAllMapped(RegExp(r'.{20}'), (m) => '${m[0]}\n');
      expect(decodeBase64Image(wrapped), png);
    });

    test('decodeBase64Image rejects non-image data', () {
      expect(() => decodeBase64Image(base64Encode(utf8.encode('hello world'))), throwsFormatException);
    });

    test('stripImageMetadata removes EXIF (incl. GPS) and keeps PNG as PNG', () {
      final src = _solid(8, 8, 50, 60, 70);
      src.exif.imageIfd.make = 'SpyCam';
      src.exif.gpsIfd.gpsLatitude = 12.97;
      final withExif = Uint8List.fromList(img.encodeJpg(src));
      expect(img.decodeJpg(withExif)!.exif.isEmpty, isFalse);

      final (cleanJpg, ext) = stripImageMetadata(withExif)!;
      expect(ext, 'jpg');
      expect(img.decodeJpg(cleanJpg)!.exif.isEmpty, isTrue);

      final transparentPng = Uint8List.fromList(img.encodePng(_solid(4, 4, 0, 0, 0, a: 0, channels: 4)));
      final (cleanPng, pngExt) = stripImageMetadata(transparentPng)!;
      expect(pngExt, 'png');
      expect(img.decodePng(cleanPng)!.getPixel(0, 0).a, 0);
    });

    test('watermarkOrigin keeps text inside the image for every position', () {
      const w = 300, h = 200, tw = 120, th = 30;
      for (final pos in ['Center', 'Bottom Right', 'Top Left']) {
        final (x, y) = watermarkOrigin(pos, w, h, tw, th);
        expect(x, inInclusiveRange(0, w - tw), reason: pos);
        expect(y, inInclusiveRange(0, h - th), reason: pos);
      }
      expect(watermarkOrigin('Bottom Right', w, h, tw, th), (w - tw - 20, h - th - 20));
      expect(watermarkOrigin('Center', w, h, tw, th), ((w - tw) ~/ 2, (h - th) ~/ 2));
      // Text wider than the image is pinned to the left edge rather than going negative.
      expect(watermarkOrigin('Bottom Right', 100, 50, 400, 60), (0, 0));
    });

    test('watermarkFont shrinks to fit narrow images', () {
      const text = 'CONFIDENTIAL';
      expect(watermarkFont(text, 4000), img.arial48);
      expect(bitmapTextWidth(watermarkFont(text, 200), text), lessThanOrEqualTo(200));
    });

    test('passportSheetLayout never overlaps or leaves the 4x6 sheet', () {
      const presets = [(600, 600), (413, 531), (354, 472)];
      for (final (pw, ph) in presets) {
        for (final copies in [4, 6, 8, 12]) {
          final layout = passportSheetLayout(pw, ph, copies);
          expect(layout.slots.length, lessThanOrEqualTo(copies));
          expect(layout.slots, isNotEmpty);
          for (var i = 0; i < layout.slots.length; i++) {
            final (x, y) = layout.slots[i];
            expect(x, greaterThanOrEqualTo(0));
            expect(y, greaterThanOrEqualTo(0));
            expect(x + pw, lessThanOrEqualTo(layout.width));
            expect(y + ph, lessThanOrEqualTo(layout.height));
            for (var j = 0; j < i; j++) {
              final (ox, oy) = layout.slots[j];
              final overlaps = x < ox + pw && ox < x + pw && y < oy + ph && oy < y + ph;
              expect(overlaps, isFalse, reason: '$pw x $ph, $copies copies: slots $j and $i overlap');
            }
          }
        }
      }
      // US 2x2" fits 6 at true size; 35x45mm fits 8 in landscape.
      expect(passportSheetLayout(600, 600, 6).slots.length, 6);
      expect(passportSheetLayout(413, 531, 8).slots.length, 8);
    });
  });

  group('PhotoEditorService fixes', () {
    test('positive exposure brightens and negative darkens', () {
      final grey = _solid(4, 4, 128, 128, 128);
      final brighter = PhotoEditorService.adjustImage(source: grey, gamma: 1.0);
      final darker = PhotoEditorService.adjustImage(source: grey, gamma: -1.0);
      expect(brighter.getPixel(0, 0).r, greaterThan(128));
      expect(darker.getPixel(0, 0).r, lessThan(128));
    });

    test('toRgba8 expands palette images so sampled colours are real RGB', () {
      final rgb = _solid(4, 4, 200, 10, 10);
      final paletted = img.quantize(rgb, numberOfColors: 4);
      expect(paletted.hasPalette, isTrue);
      final rgba = PhotoEditorService.toRgba8(paletted);
      expect(rgba.hasPalette, isFalse);
      expect(rgba.numChannels, 4);
      expect(rgba.getPixel(0, 0).r, closeTo(200, 8));
      expect(identical(PhotoEditorService.toRgba8(rgb), rgb), isTrue);
    });

    test('blur box fully replaces the region even on translucent images', () {
      final src = img.Image(width: 20, height: 20, numChannels: 4);
      img.fill(src, color: img.ColorRgba8(0, 0, 0, 128));
      img.fillRect(src, x1: 0, y1: 0, x2: 4, y2: 19, color: img.ColorRgba8(255, 255, 255, 128), alphaBlend: false);
      final out = PhotoEditorService.applyBlurAreas(src, const [
        BlurArea(x: 0.0, y: 0.0, width: 1.0, height: 1.0, intensity: 10, isMosaic: true),
      ]);
      // Mosaic blocks must be uniform: no original pixel bleeding through the blend.
      final p = out.getPixel(1, 1);
      final q = out.getPixel(8, 8);
      expect(p.r, q.r);
      expect(p.a, 128);
    });

    test('applyBlurAreas tolerates boxes running off the image edge', () {
      final src = _solid(10, 10, 100, 100, 100);
      final out = PhotoEditorService.applyBlurAreas(src, const [
        BlurArea(x: 0.9, y: 0.9, width: 0.9, height: 0.9, intensity: 50),
      ]);
      expect(out.width, 10);
      expect(out.height, 10);
    });
  });

  group('Rotate & flip', () {
    // Every pixel is unique, so any mix-up of orientation shows.
    img.Image grid() {
      final g = img.Image(width: 5, height: 3);
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 5; x++) {
          g.setPixelRgb(x, y, x * 40, y * 80, 10);
        }
      }
      return g;
    }

    void expectSame(img.Image a, img.Image b, String reason) {
      expect((a.width, a.height), (b.width, b.height), reason: reason);
      for (var y = 0; y < a.height; y++) {
        for (var x = 0; x < a.width; x++) {
          final p = a.getPixel(x, y);
          final q = b.getPixel(x, y);
          expect([p.r, p.g, p.b], [q.r, q.g, q.b], reason: '$reason at $x,$y');
        }
      }
    }

    test('a positive angle turns the picture clockwise', () {
      final src = _solid(2, 1, 0, 0, 255);
      src.setPixelRgb(0, 0, 255, 0, 0); // left pixel red
      final turned = applyTransform(src, 90, false, false);
      expect((turned.width, turned.height), (1, 2));
      expect(turned.getPixel(0, 0).r, 255); // left went to the top
    });

    test('rotate buttons turn what is on screen, even with a mirror active', () {
      for (final a in [0, 90, 180, 270]) {
        for (final fh in [false, true]) {
          for (final fv in [false, true]) {
            final shown = applyTransform(grid(), a, fh, fv);
            final label = 'angle $a flipH $fh flipV $fv';
            expectSame(applyTransform(grid(), nextRotation(a, 90, fh, fv), fh, fv), applyTransform(shown, 90, false, false), 'cw $label');
            expectSame(applyTransform(grid(), nextRotation(a, -90, fh, fv), fh, fv), applyTransform(shown, -90, false, false), 'ccw $label');
          }
        }
      }
    });

    test('toggling a flip mirrors what is on screen', () {
      for (final a in [0, 90, 180, 270]) {
        for (final fh in [false, true]) {
          final shown = applyTransform(grid(), a, fh, false);
          expectSame(applyTransform(grid(), a, !fh, false), img.flipHorizontal(img.Image.from(shown)), 'angle $a flipH $fh');
        }
      }
    });

    test('nextRotation stays within 0..359', () {
      expect(nextRotation(0, -90, false, false), 270);
      expect(nextRotation(270, 90, false, false), 0);
      expect(nextRotation(0, 90, true, false), 270); // one mirror reverses the turn
      expect(nextRotation(0, 90, true, true), 90); // two mirrors are a half turn: no reversal
    });
  });

  group('Image toolkit processing', () {
    Uint8List png(img.Image i) => Uint8List.fromList(img.encodePng(i));

    test('convertImage writes each target format with its own signature', () {
      final src = png(_solid(8, 8, 200, 100, 50));
      expect(convertImage(src, 'PNG')!.sublist(1, 4), [0x50, 0x4E, 0x47]);
      expect(convertImage(src, 'JPG')!.sublist(0, 2), [0xFF, 0xD8]);
      expect(convertImage(src, 'BMP')!.sublist(0, 2), [0x42, 0x4D]);
      expect(convertImage(src, 'GIF')!.sublist(0, 3), [0x47, 0x49, 0x46]);
      expect(convertImage(Uint8List.fromList([1, 2, 3]), 'PNG'), isNull);
    });

    test('resizeImage crops to the target ratio and hits the exact size', () {
      final out = img.decodePng(resizeImage(png(_solid(200, 100, 1, 2, 3)), 40, 40)!)!;
      expect((out.width, out.height), (40, 40));
      expect(resizeImage(Uint8List(4), 10, 10), isNull);
    });

    test('compressImage returns a JPEG; smaller quality gives fewer bytes', () {
      final noisy = img.Image(width: 64, height: 64);
      for (final p in noisy) {
        p.r = (p.x * 37 + p.y * 11) % 256;
        p.g = (p.x * 13 + p.y * 53) % 256;
        p.b = (p.x * 71 + p.y * 5) % 256;
      }
      final src = png(noisy);
      final high = compressImage(src, 95)!;
      final low = compressImage(src, 10)!;
      expect(high.sublist(0, 2), [0xFF, 0xD8]);
      expect(low.length, lessThan(high.length));
    });

    test('combineImages needs two readable images and scales huge strips down', () {
      expect(combineImages([png(_solid(10, 10, 0, 0, 0)), Uint8List(3)], 'Side by Side', 5), isNull);
      final wide = png(_solid(5000, 100, 9, 9, 9));
      final strip = img.decodePng(combineImages([wide, wide, wide], 'Side by Side', 10)!)!;
      expect(strip.width, lessThanOrEqualTo(12000));
      final stack = img.decodePng(combineImages([png(_solid(100, 5000, 9, 9, 9)), png(_solid(100, 5000, 9, 9, 9))], 'Stacked Vertical', 10)!)!;
      expect(stack.height, lessThanOrEqualTo(12000));
      final grid = img.decodePng(combineImages([for (var i = 0; i < 6; i++) png(_solid(30, 30, 1, 1, 1))], '2x2 Grid', 10)!)!;
      expect((grid.width, grid.height), (1030, 1030));
    });

    test('watermarkImage draws visible text and honours the position', () {
      final src = png(_solid(300, 200, 255, 255, 255));
      final out = img.decodePng(watermarkImage(src, 'HI', 'Top Left', 1.0)!)!;
      var red = 0;
      for (final p in out) {
        if (p.r > 200 && p.g < 100) red++;
      }
      expect(red, greaterThan(20));
      // 'Top Left' keeps the opposite corner clean.
      final p = out.getPixel(290, 190);
      expect([p.r, p.g, p.b], [255, 255, 255]);
    });

    test('makePassportPhotos returns a photo and a sheet that really holds the copies', () {
      final out = makePassportPhotos(png(_solid(700, 900, 120, 130, 140)), 600, 600, 6)!;
      expect(out.placed, 6);
      final single = img.decodePng(out.single)!;
      expect((single.width, single.height), (600, 600));
      final sheet = img.decodeJpg(out.sheet)!;
      expect(sheet.width * sheet.height, 1200 * 1800);
    });
  });

  group('Photo Studio fixes', () {
    test('removeBackground clears the border region, keeps the subject, and respects enclosed areas', () {
      final src = img.Image(width: 12, height: 12);
      img.fill(src, color: img.ColorRgb8(255, 255, 255));
      img.fillRect(src, x1: 3, y1: 3, x2: 8, y2: 8, color: img.ColorRgb8(200, 0, 0));
      src.setPixelRgb(5, 5, 255, 255, 255); // white hole fully inside the subject

      final flood = PhotoEditorService.removeBackground(src, sampleR: 255, sampleG: 255, sampleB: 255, tolerance: 10);
      expect(flood.numChannels, 4);
      expect(flood.getPixel(0, 0).a, 0);
      expect(flood.getPixel(11, 11).a, 0);
      expect(flood.getPixel(4, 4).a, 255);
      expect(flood.getPixel(4, 4).r, 200);
      expect(flood.getPixel(5, 5).a, 255, reason: 'flood fill must not eat enclosed pixels');

      final keyed = PhotoEditorService.removeBackground(src, sampleR: 255, sampleG: 255, sampleB: 255, tolerance: 10, floodFillFromEdges: false);
      expect(keyed.getPixel(5, 5).a, 0, reason: 'colour keying removes every matching pixel');
      expect(keyed.getPixel(4, 4).a, 255);
    });

    test('tolerance widens what counts as background', () {
      final src = img.Image(width: 4, height: 4);
      img.fill(src, color: img.ColorRgb8(240, 240, 240));
      final tight = PhotoEditorService.removeBackground(src, sampleR: 255, sampleG: 255, sampleB: 255, tolerance: 2);
      final loose = PhotoEditorService.removeBackground(src, sampleR: 255, sampleG: 255, sampleB: 255, tolerance: 20);
      expect(tight.getPixel(1, 1).a, 255);
      expect(loose.getPixel(1, 1).a, 0);
    });

    test('censor strength scales with photo size so big photos are really obscured', () {
      expect(PhotoEditorService.censorScale(800, 600), 1.0);
      expect(PhotoEditorService.censorScale(4000, 3000), 4.0);

      img.Image gradient(int w) {
        final g = img.Image(width: w, height: 40);
        for (final p in g) {
          p.r = p.x % 256;
        }
        return g;
      }

      const area = [BlurArea(x: 0, y: 0, width: 1, height: 1, intensity: 10, isMosaic: true)];
      final small = PhotoEditorService.applyBlurAreas(gradient(500), area);
      expect(small.getPixel(25, 5).r, 20, reason: '10 px blocks on a small photo');
      final big = PhotoEditorService.applyBlurAreas(gradient(3000), area);
      expect(big.getPixel(25, 5).r, 0, reason: '30 px blocks on a 3000 px photo');
    });

    test('loadForEditing upright-decodes, caps the size and builds a small preview', () {
      final wide = img.Image(width: 5000, height: 100);
      final loaded = PhotoEditorService.loadForEditing(Uint8List.fromList(img.encodePng(wide)))!;
      expect(loaded.image.width, 4096);
      expect(loaded.originalWidth, 5000);
      expect(img.decodePng(loaded.preview)!.width, 1280);
      expect(PhotoEditorService.loadForEditing(Uint8List.fromList([1, 2, 3])), isNull);

      final sideways = img.Image(width: 40, height: 20);
      sideways.exif.imageIfd.orientation = 6; // camera held in portrait
      final jpg = Uint8List.fromList(img.encodeJpg(sideways));
      final upright = PhotoEditorService.loadForEditing(jpg)!;
      expect((upright.image.width, upright.image.height), (20, 40));
    });

    test('anchorOrigin puts an item on all nine anchors, inside the image', () {
      const w = 300, h = 200, iw = 40, ih = 20, m = 10;
      final expectedX = [m, (w - iw) ~/ 2, w - iw - m];
      final expectedY = [m, (h - ih) ~/ 2, h - ih - m];
      for (var anchor = 0; anchor < 9; anchor++) {
        final (x, y) = PhotoEditorService.anchorOrigin(anchor, w, h, iw, ih, m);
        expect(x, expectedX[anchor % 3], reason: 'anchor $anchor');
        expect(y, expectedY[anchor ~/ 3], reason: 'anchor $anchor');
      }
      // An item larger than the photo is pinned to the corner, never negative.
      expect(PhotoEditorService.anchorOrigin(8, 50, 50, 80, 80, 10), (0, 0));
    });

    test('logo opacity scales alpha, and the logo lands on the chosen anchor', () {
      final base = _solid(200, 100, 0, 0, 0, channels: 4);
      final logo = _solid(20, 20, 255, 255, 255, channels: 4);
      for (final opacity in [1.0, 0.5, 0.2]) {
        final out = PhotoEditorService.applyWatermark(base, logo: logo, logoScale: 0.2, logoOpacity: opacity, logoAnchor: 8);
        // 40 px logo, margin 10: bottom-right cell starts at (150, 50).
        expect(out.getPixel(170, 70).r, closeTo(255 * opacity, 3), reason: 'opacity $opacity');
        expect(out.getPixel(20, 20).r, 0, reason: 'top-left stays untouched');
      }
      final topLeft = PhotoEditorService.applyWatermark(base, logo: logo, logoScale: 0.2, logoAnchor: 0);
      expect(topLeft.getPixel(30, 30).r, 255);
      expect(topLeft.getPixel(170, 70).r, 0);
      final centre = PhotoEditorService.applyWatermark(base, logo: logo, logoScale: 0.2, logoAnchor: 4);
      expect(centre.getPixel(100, 50).r, 255);
      expect(identical(base, centre), isFalse);
      expect(base.getPixel(100, 50).r, 0, reason: 'the source is not modified');
    });

    test('applyOpacity keeps colour and scales only alpha', () {
      final solid = _solid(2, 2, 10, 20, 30, a: 200, channels: 4);
      final half = PhotoEditorService.applyOpacity(solid, 0.5);
      final p = half.getPixel(0, 0);
      expect([p.r, p.g, p.b, p.a], [10, 20, 30, 100]);
      expect(solid.getPixel(0, 0).a, 200);
    });

    test('text badge grows with the font size slider and never overflows the photo', () {
      final small = PhotoEditorService.renderTextBadge('Hello', 14, 720);
      final large = PhotoEditorService.renderTextBadge('Hello', 60, 720);
      expect(large.width, greaterThan(small.width * 2));
      final capped = PhotoEditorService.renderTextBadge('A very long watermark line ' * 4, 60, 300);
      expect(capped.width, lessThanOrEqualTo(271));
      // Bigger photos get proportionally bigger text.
      expect(PhotoEditorService.renderTextBadge('Hello', 28, 3000).width, greaterThan(PhotoEditorService.renderTextBadge('Hello', 28, 720).width * 2));
    });

    test('drawing points are stored as clamped fractions of the canvas', () {
      expect(PhotoEditorService.normalizePoint(const Offset(90, 45), const Size(180, 90)), const Offset(0.5, 0.5));
      expect(PhotoEditorService.normalizePoint(const Offset(-10, 400), const Size(180, 90)), const Offset(0, 1));
    });
  });

  group('Collage', () {
    test('collage canvas, cell placement and border colour', () {
      expect(collageCanvasSize(3, 2, 10), (3 * collageCellSize + 40, 2 * collageCellSize + 30));
      final red = _solid(collageCellSize, collageCellSize, 255, 0, 0);
      final blue = _solid(collageCellSize, collageCellSize, 0, 0, 255);
      final jpg = img.decodeJpg(renderCollage([red, blue], 2, 1, 10, const Color(0xFFFFFFFF)))!;
      expect((jpg.width, jpg.height), collageCanvasSize(2, 1, 10));
      expect(jpg.getPixel(5, 5).r, greaterThan(240)); // border is white
      expect(jpg.getPixel(10 + 400, 10 + 400).r, greaterThan(200)); // first cell is red
      expect(jpg.getPixel(10 + 400, 10 + 400).b, lessThan(60));
      final second = jpg.getPixel(20 + collageCellSize + 400, 10 + 400);
      expect(second.b, greaterThan(200)); // second cell is blue
    });

    test('photos beyond the grid are left out instead of crashing', () {
      final cell = _solid(collageCellSize, collageCellSize, 0, 255, 0);
      final out = img.decodeJpg(renderCollage([cell, cell, cell], 1, 1, 0, const Color(0xFF000000)))!;
      expect((out.width, out.height), (collageCellSize, collageCellSize));
    });

    test('decodeCollageCell crops to a square cell off the UI thread and rejects non-images', () async {
      final photo = Uint8List.fromList(img.encodePng(_solid(300, 200, 1, 2, 3)));
      final cell = await decodeCollageCell(photo);
      expect((cell!.width, cell.height), (collageCellSize, collageCellSize));
      expect(await decodeCollageCell(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('Background isolates accept the data they are sent', () {
    // These run the same code as the app, on a real second isolate: a closure that captured
    // something unsendable would throw here.
    final photo = Uint8List.fromList(img.encodePng(_solid(60, 40, 10, 120, 200)));

    test('toolkit wrappers', () async {
      expect(await readImageSizeInBackground(photo), (60, 40));
      expect((await compressImageInBackground(photo, 50))!.sublist(0, 2), [0xFF, 0xD8]);
      expect(img.decodePng((await resizeImageInBackground(photo, 20, 20))!)!.width, 20);
      expect((await convertImageInBackground(photo, 'BMP'))!.sublist(0, 2), [0x42, 0x4D]);
      expect(img.decodePng((await transformImageInBackground(photo, 90, true, false))!)!.width, 40);
      expect(await combineImagesInBackground([photo, photo], 'Side by Side', 4), isNotNull);
      expect((await stripImageMetadataInBackground(photo))!.$2, 'png');
      expect(await watermarkImageInBackground(photo, 'X', 'Center', 0.5), isNotNull);
      expect((await makePassportPhotosInBackground(photo, 600, 600, 4))!.placed, greaterThan(0));
    });

    test('Photo Studio wrappers', () async {
      final loaded = (await PhotoEditorService.loadForEditingInBackground(photo))!;
      final image = loaded.image;
      final (cutout, cutoutBytes) = await PhotoEditorService.removeBackgroundInBackground(
        image,
        sampleR: 10,
        sampleG: 120,
        sampleB: 200,
        tolerance: 10,
        floodFillFromEdges: true,
      );
      expect(cutout.getPixel(5, 5).a, 0);
      expect(img.decodePng(cutoutBytes), isNotNull);
      expect(await PhotoEditorService.replaceBackgroundInBackground(cutout, solidColor: const Color(0xFFFF0000)), isNotEmpty);
      expect(await PhotoEditorService.replaceBackgroundInBackground(cutout, gradientColors: const [Color(0xFF000000), Color(0xFFFFFFFF)]), isNotEmpty);
      expect(await PhotoEditorService.adjustImageInBackground(image, brightness: 0.2, contrast: 0, saturation: 0, sharpness: 0.3, gamma: 0, vignette: 0.2), isNotEmpty);
      expect(await PhotoEditorService.applyFilterInBackground(image, 'Sepia'), isNotEmpty);
      expect(await PhotoEditorService.applyBlurAreasInBackground(image, const [BlurArea(x: 0.1, y: 0.1, width: 0.5, height: 0.5)]), isNotEmpty);
      expect(
        await PhotoEditorService.applyWatermarkInBackground(
          image,
          logo: image,
          logoScale: 0.3,
          logoOpacity: 0.6,
          logoAnchor: 2,
          text: 'hello',
          textSize: 30,
          textBackground: true,
        ),
        isNotEmpty,
      );
    });
  });
}
