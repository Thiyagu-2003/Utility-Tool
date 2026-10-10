// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bannerFile = File('assets/images/app_banner.png');
  if (bannerFile.existsSync()) {
    final dec = img.decodeImage(bannerFile.readAsBytesSync());
    if (dec != null) {
      bannerFile.writeAsBytesSync(img.encodePng(dec));
      print('app_banner.png is now genuine PNG');
    }
  }
}
