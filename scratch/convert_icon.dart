import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final inputBytes = File('assets/images/app_icon.png').readAsBytesSync();
  final decoded = img.decodeImage(inputBytes);
  if (decoded == null) {
    print('Failed to decode image');
    return;
  }

  // Generate clean square PNG launcher icons at standard Android mipmap resolutions
  final resMap = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in resMap.entries) {
    final resized = img.copyResize(decoded, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    final pngBytes = img.encodePng(resized);
    File('android/app/src/main/res/${entry.key}/ic_launcher.png').writeAsBytesSync(pngBytes);
  }

  // Also update assets/images/app_icon.png to genuine PNG
  final standardPng = img.encodePng(decoded);
  File('assets/images/app_icon.png').writeAsBytesSync(standardPng);

  print('Successfully generated valid resized PNG launcher icons for all Android densities!');
}
