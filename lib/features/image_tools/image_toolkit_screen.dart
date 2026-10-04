import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum ImageToolkitTab {
  compress('Compress', Icons.compress_rounded),
  resizeCrop('Resize & Crop', Icons.crop_rounded),
  convert('Format Convert', Icons.transform_rounded),
  rotateFlip('Rotate & Flip', Icons.rotate_right_rounded),
  combine('Combine / Grid', Icons.grid_view_rounded),
  base64('Image ⇄ Base64', Icons.code_rounded),
  removeExif('Strip EXIF', Icons.shield_outlined),
  watermark('Watermark', Icons.branding_watermark_rounded),
  passport('Passport Photo', Icons.badge_outlined);

  final String label;
  final IconData icon;
  const ImageToolkitTab(this.label, this.icon);
}

class LoadedImage {
  final String name;
  final Uint8List bytes;
  final int width;
  final int height;
  final int sizeBytes;
  final String format;

  LoadedImage({
    required this.name,
    required this.bytes,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.format,
  });
}

class ImageToolkitScreen extends StatefulWidget {
  const ImageToolkitScreen({super.key});

  @override
  State<ImageToolkitScreen> createState() => _ImageToolkitScreenState();
}

class _ImageToolkitScreenState extends State<ImageToolkitScreen> {
  ImageToolkitTab _activeTab = ImageToolkitTab.compress;

  // 1. Compress State
  LoadedImage? _compressImage;
  double _compressQuality = 75; // 1 to 100
  Uint8List? _compressedBytes;
  int _compressedSizeBytes = 0;

  // 2. Resize & Crop State
  LoadedImage? _resizeImage;
  final TextEditingController _resizeWidthController = TextEditingController();
  final TextEditingController _resizeHeightController = TextEditingController();
  bool _maintainAspectRatio = true;
  double _aspectRatioFactor = 1.0;
  Uint8List? _resizedBytes;

  // 3. Format Convert State
  LoadedImage? _convertImage;
  String _targetFormat = 'PNG'; // JPG, PNG, WEBP, BMP
  Uint8List? _convertedBytes;

  // 4. Rotate & Flip State
  LoadedImage? _rotateImage;
  int _rotationAngle = 0; // 0, 90, 180, 270
  bool _flipHorizontal = false;
  bool _flipVertical = false;
  Uint8List? _transformedBytes;

  // 5. Combine Images State
  final List<LoadedImage> _combineImages = [];
  String _combineLayout = 'Side by Side'; // 'Side by Side', 'Stacked Vertical', '2x2 Grid'
  final double _combineSpacing = 10;
  Uint8List? _combinedResultBytes;

  // 6. Base64 State
  LoadedImage? _base64SourceImage;
  final TextEditingController _base64StringController = TextEditingController();
  Uint8List? _base64DecodedBytes;

  // 7. Remove EXIF State
  LoadedImage? _exifSourceImage;
  Uint8List? _cleanExifBytes;

  // 8. Watermark State
  LoadedImage? _watermarkSourceImage;
  final TextEditingController _watermarkTextController = TextEditingController(text: 'CONFIDENTIAL');
  String _watermarkPosition = 'Center'; // 'Center', 'Bottom Right', 'Top Left', 'Repeat Diagonal'
  double _watermarkOpacity = 0.5;
  Uint8List? _watermarkedBytes;

  // 9. Passport Photo Maker State
  LoadedImage? _passportSourceImage;
  String _passportPreset = 'US Passport (2x2 in)'; // US Passport, Schengen / Indian (35x45mm), ID Card (30x40mm)
  int _sheetCopies = 6; // 4, 6, 8, 12
  Uint8List? _passportSingleBytes;
  Uint8List? _passportSheetBytes;

  @override
  void dispose() {
    _resizeWidthController.dispose();
    _resizeHeightController.dispose();
    _base64StringController.dispose();
    _watermarkTextController.dispose();
    super.dispose();
  }

  // --- HELPERS ---

  Future<LoadedImage?> _pickSingleImage() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final ext = file.extension?.toUpperCase() ?? 'JPG';
          return LoadedImage(
            name: file.name,
            bytes: bytes,
            width: decoded.width,
            height: decoded.height,
            sizeBytes: bytes.length,
            format: ext,
          );
        }
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
    return null;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- TAB 1: COMPRESS ---
  Future<void> _pickCompressImage() async {
    final image = await _pickSingleImage();
    if (image != null) {
      setState(() {
        _compressImage = image;
        _compressedBytes = null;
        _compressedSizeBytes = 0;
      });
      _runCompression();
    }
  }

  Future<void> _runCompression() async {
    if (_compressImage == null) return;
    PreferencesService().triggerHaptic();

    try {
      final decoded = img.decodeImage(_compressImage!.bytes);
      if (decoded != null) {
        final quality = _compressQuality.round().clamp(1, 100);
        final compressed = img.encodeJpg(decoded, quality: quality);
        setState(() {
          _compressedBytes = Uint8List.fromList(compressed);
          _compressedSizeBytes = compressed.length;
        });
      }
    } catch (e) {
      _showError('Compression error: $e');
    }
  }

  // --- TAB 2: RESIZE & CROP ---
  Future<void> _pickResizeImage() async {
    final image = await _pickSingleImage();
    if (image != null) {
      setState(() {
        _resizeImage = image;
        _resizeWidthController.text = image.width.toString();
        _resizeHeightController.text = image.height.toString();
        _aspectRatioFactor = image.width / (image.height == 0 ? 1 : image.height);
        _resizedBytes = null;
      });
    }
  }

  void _applyCropPreset(String preset) {
    if (_resizeImage == null) return;
    setState(() {
      final w = _resizeImage!.width;
      if (preset == '1:1 Square') {
        final side = w < _resizeImage!.height ? w : _resizeImage!.height;
        _resizeWidthController.text = side.toString();
        _resizeHeightController.text = side.toString();
      } else if (preset == '16:9 Landscape') {
        final targetH = (w * 9 / 16).round();
        _resizeWidthController.text = w.toString();
        _resizeHeightController.text = targetH.toString();
      } else if (preset == '4:3 Standard') {
        final targetH = (w * 3 / 4).round();
        _resizeWidthController.text = w.toString();
        _resizeHeightController.text = targetH.toString();
      } else if (preset == '9:16 Story') {
        final targetW = (_resizeImage!.height * 9 / 16).round();
        _resizeWidthController.text = targetW.toString();
        _resizeHeightController.text = _resizeImage!.height.toString();
      }
    });
  }

  Future<void> _runResizeCrop() async {
    if (_resizeImage == null) return;
    PreferencesService().triggerHaptic();

    try {
      final decoded = img.decodeImage(_resizeImage!.bytes);
      if (decoded != null) {
        final targetW = int.tryParse(_resizeWidthController.text) ?? decoded.width;
        final targetH = int.tryParse(_resizeHeightController.text) ?? decoded.height;

        final resized = img.copyResize(
          decoded,
          width: targetW,
          height: targetH,
          interpolation: img.Interpolation.linear,
        );

        final encoded = img.encodePng(resized);
        setState(() {
          _resizedBytes = Uint8List.fromList(encoded);
        });
      }
    } catch (e) {
      _showError('Resize failed: $e');
    }
  }

  // --- TAB 3: FORMAT CONVERT ---
  Future<void> _pickConvertImage() async {
    final image = await _pickSingleImage();
    if (image != null) {
      setState(() {
        _convertImage = image;
        _convertedBytes = null;
      });
    }
  }

  Future<void> _runFormatConvert() async {
    if (_convertImage == null) return;
    PreferencesService().triggerHaptic();

    try {
      final decoded = img.decodeImage(_convertImage!.bytes);
      if (decoded != null) {
        List<int> encodedBytes;
        switch (_targetFormat) {
          case 'JPG':
            encodedBytes = img.encodeJpg(decoded, quality: 90);
            break;
          case 'PNG':
            encodedBytes = img.encodePng(decoded);
            break;
          case 'BMP':
            encodedBytes = img.encodeBmp(decoded);
            break;
          case 'GIF':
            encodedBytes = img.encodeGif(decoded);
            break;
          default:
            encodedBytes = img.encodePng(decoded);
        }
        setState(() {
          _convertedBytes = Uint8List.fromList(encodedBytes);
        });
      }
    } catch (e) {
      _showError('Conversion failed: $e');
    }
  }

  // --- TAB 4: ROTATE & FLIP ---
  Future<void> _pickRotateImage() async {
    final image = await _pickSingleImage();
    if (image != null) {
      setState(() {
        _rotateImage = image;
        _rotationAngle = 0;
        _flipHorizontal = false;
        _flipVertical = false;
        _transformedBytes = null;
      });
    }
  }

  Future<void> _runTransform() async {
    if (_rotateImage == null) return;
    PreferencesService().triggerHaptic();

    try {
      var current = img.decodeImage(_rotateImage!.bytes);
      if (current != null) {
        if (_rotationAngle != 0) {
          current = img.copyRotate(current, angle: _rotationAngle.toDouble());
        }
        if (_flipHorizontal) {
          current = img.flipHorizontal(current);
        }
        if (_flipVertical) {
          current = img.flipVertical(current);
        }

        final encoded = img.encodePng(current);
        setState(() {
          _transformedBytes = Uint8List.fromList(encoded);
        });
      }
    } catch (e) {
      _showError('Transformation failed: $e');
    }
  }

  // --- TAB 5: COMBINE IMAGES ---
  Future<void> _pickCombineImages() async {
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (files.isNotEmpty) {
        for (final file in files) {
          final bytes = await file.readAsBytes();
          final decoded = img.decodeImage(bytes);
          if (decoded != null) {
            _combineImages.add(
              LoadedImage(
                name: file.name,
                bytes: bytes,
                width: decoded.width,
                height: decoded.height,
                sizeBytes: bytes.length,
                format: file.extension?.toUpperCase() ?? 'PNG',
              ),
            );
          }
        }
        setState(() {});
      }
    } catch (e) {
      _showError('Error picking images: $e');
    }
  }

  Future<void> _runCombine() async {
    if (_combineImages.length < 2) {
      _showError('Select at least 2 images to combine.');
      return;
    }

    PreferencesService().triggerHaptic();

    try {
      final List<img.Image> decodedList = [];
      for (final item in _combineImages) {
        final dec = img.decodeImage(item.bytes);
        if (dec != null) decodedList.add(dec);
      }

      final spacing = _combineSpacing.toInt();
      img.Image canvas;

      if (_combineLayout == 'Side by Side') {
        final targetH = decodedList.map((i) => i.height).reduce((a, b) => a > b ? a : b);
        var totalW = spacing;
        final List<img.Image> scaled = [];

        for (final item in decodedList) {
          final res = img.copyResize(item, height: targetH);
          scaled.add(res);
          totalW += res.width + spacing;
        }

        canvas = img.Image(width: totalW, height: targetH + (spacing * 2));
        img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

        var currentX = spacing;
        for (final item in scaled) {
          img.compositeImage(canvas, item, dstX: currentX, dstY: spacing);
          currentX += item.width + spacing;
        }
      } else if (_combineLayout == 'Stacked Vertical') {
        final targetW = decodedList.map((i) => i.width).reduce((a, b) => a > b ? a : b);
        var totalH = spacing;
        final List<img.Image> scaled = [];

        for (final item in decodedList) {
          final res = img.copyResize(item, width: targetW);
          scaled.add(res);
          totalH += res.height + spacing;
        }

        canvas = img.Image(width: targetW + (spacing * 2), height: totalH);
        img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

        var currentY = spacing;
        for (final item in scaled) {
          img.compositeImage(canvas, item, dstX: spacing, dstY: currentY);
          currentY += item.height + spacing;
        }
      } else {
        // 2x2 Grid (for up to 4 images)
        final cellW = 500;
        final cellH = 500;
        canvas = img.Image(width: (cellW * 2) + (spacing * 3), height: (cellH * 2) + (spacing * 3));
        img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

        for (int i = 0; i < decodedList.length && i < 4; i++) {
          final res = img.copyResize(decodedList[i], width: cellW, height: cellH);
          final row = i ~/ 2;
          final col = i % 2;
          final x = spacing + col * (cellW + spacing);
          final y = spacing + row * (cellH + spacing);
          img.compositeImage(canvas, res, dstX: x, dstY: y);
        }
      }

      final encoded = img.encodePng(canvas);
      setState(() {
        _combinedResultBytes = Uint8List.fromList(encoded);
      });
    } catch (e) {
      _showError('Combine error: $e');
    }
  }

  // --- TAB 6: BASE64 ---
  Future<void> _pickBase64Image() async {
    final image = await _pickSingleImage();
    if (image != null) {
      final base64Str = 'data:image/png;base64,${base64Encode(image.bytes)}';
      setState(() {
        _base64SourceImage = image;
        _base64StringController.text = base64Str;
      });
    }
  }

  void _decodeBase64String() {
    final input = _base64StringController.text.trim();
    if (input.isEmpty) return;
    try {
      var clean = input;
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      final bytes = base64Decode(clean);
      setState(() {
        _base64DecodedBytes = bytes;
      });
      PreferencesService().triggerHaptic();
    } catch (e) {
      _showError('Invalid Base64 string: $e');
    }
  }

  // --- TAB 7: REMOVE EXIF ---
  Future<void> _pickExifImage() async {
    final image = await _pickSingleImage();
    if (image != null) {
      setState(() {
        _exifSourceImage = image;
        _cleanExifBytes = null;
      });
      _stripExif();
    }
  }

  Future<void> _stripExif() async {
    if (_exifSourceImage == null) return;
    PreferencesService().triggerHaptic();

    try {
      final decoded = img.decodeImage(_exifSourceImage!.bytes);
      if (decoded != null) {
        final cleanImage = img.Image.from(decoded);
        cleanImage.exif.clear();
        final encoded = img.encodeJpg(cleanImage, quality: 95);
        setState(() {
          _cleanExifBytes = Uint8List.fromList(encoded);
        });
      }
    } catch (e) {
      _showError('EXIF stripping failed: $e');
    }
  }

  // --- TAB 8: WATERMARK ---
  Future<void> _pickWatermarkImage() async {
    final image = await _pickSingleImage();
    if (image != null) {
      setState(() {
        _watermarkSourceImage = image;
        _watermarkedBytes = null;
      });
    }
  }

  Future<void> _applyWatermark() async {
    if (_watermarkSourceImage == null) return;
    PreferencesService().triggerHaptic();

    try {
      final decoded = img.decodeImage(_watermarkSourceImage!.bytes);
      if (decoded != null) {
        final text = _watermarkTextController.text.trim();
        final font = img.arial48;

        if (_watermarkPosition == 'Repeat Diagonal') {
          for (int y = 50; y < decoded.height; y += 180) {
            for (int x = 50; x < decoded.width; x += 300) {
              img.drawString(
                decoded,
                text,
                font: font,
                x: x,
                y: y,
                color: img.ColorRgba8(255, 0, 0, (_watermarkOpacity * 255).round()),
              );
            }
          }
        } else {
          int x = (decoded.width / 2 - 100).toInt();
          int y = (decoded.height / 2 - 20).toInt();

          if (_watermarkPosition == 'Bottom Right') {
            x = decoded.width - 250;
            y = decoded.height - 80;
          } else if (_watermarkPosition == 'Top Left') {
            x = 40;
            y = 40;
          }

          img.drawString(
            decoded,
            text,
            font: font,
            x: x.clamp(0, decoded.width),
            y: y.clamp(0, decoded.height),
            color: img.ColorRgba8(255, 0, 0, (_watermarkOpacity * 255).round()),
          );
        }

        final encoded = img.encodePng(decoded);
        setState(() {
          _watermarkedBytes = Uint8List.fromList(encoded);
        });
      }
    } catch (e) {
      _showError('Watermarking failed: $e');
    }
  }

  // --- TAB 9: PASSPORT PHOTO MAKER ---
  Future<void> _pickPassportImage() async {
    final image = await _pickSingleImage();
    if (image != null) {
      setState(() {
        _passportSourceImage = image;
        _passportSingleBytes = null;
        _passportSheetBytes = null;
      });
      _generatePassportPhotos();
    }
  }

  Future<void> _generatePassportPhotos() async {
    if (_passportSourceImage == null) return;
    PreferencesService().triggerHaptic();

    try {
      final decoded = img.decodeImage(_passportSourceImage!.bytes);
      if (decoded != null) {
        int targetW = 600;
        int targetH = 600;

        if (_passportPreset == 'Schengen / India (35x45mm)') {
          targetW = 413;
          targetH = 531;
        } else if (_passportPreset == 'ID Card (30x40mm)') {
          targetW = 354;
          targetH = 472;
        }

        // Center crop and resize
        final cropSide = decoded.width < decoded.height ? decoded.width : decoded.height;
        final cropX = (decoded.width - cropSide) ~/ 2;
        final cropY = (decoded.height - cropSide) ~/ 2;
        final cropped = img.copyCrop(decoded, x: cropX, y: cropY, width: cropSide, height: cropSide);
        final single = img.copyResize(cropped, width: targetW, height: targetH);

        final singleBytes = img.encodePng(single);

        // Generate printable 4x6" Sheet (1200 x 1800 px)
        final sheet = img.Image(width: 1200, height: 1800);
        img.fill(sheet, color: img.ColorRgba8(255, 255, 255, 255));

        final cols = 2;
        final rows = _sheetCopies ~/ 2;
        final marginX = 80;
        final marginY = 80;
        final gapX = (1200 - (2 * marginX) - (cols * targetW)) ~/ (cols - 1 > 0 ? cols - 1 : 1);
        final gapY = (1800 - (2 * marginY) - (rows * targetH)) ~/ (rows - 1 > 0 ? rows - 1 : 1);

        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            final x = marginX + c * (targetW + gapX);
            final y = marginY + r * (targetH + gapY);
            img.compositeImage(sheet, single, dstX: x, dstY: y);
          }
        }

        final sheetBytes = img.encodeJpg(sheet, quality: 98);

        setState(() {
          _passportSingleBytes = Uint8List.fromList(singleBytes);
          _passportSheetBytes = Uint8List.fromList(sheetBytes);
        });
      }
    } catch (e) {
      _showError('Passport photo generation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Image Toolkit',
      category: ToolCategory.filesText,
      toolId: 'image_toolkit',
      onReset: () {
        setState(() {
          _compressImage = null;
          _compressedBytes = null;
          _resizeImage = null;
          _resizedBytes = null;
          _convertImage = null;
          _convertedBytes = null;
          _rotateImage = null;
          _transformedBytes = null;
          _combineImages.clear();
          _combinedResultBytes = null;
          _base64SourceImage = null;
          _base64StringController.clear();
          _base64DecodedBytes = null;
          _exifSourceImage = null;
          _cleanExifBytes = null;
          _watermarkSourceImage = null;
          _watermarkedBytes = null;
          _passportSourceImage = null;
          _passportSingleBytes = null;
          _passportSheetBytes = null;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigation Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ImageToolkitTab.values.map((tab) {
                final isSelected = tab == _activeTab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    avatar: Icon(tab.icon, size: 16, color: isSelected ? Colors.white : AppColors.catConverter),
                    label: Text(tab.label),
                    selected: isSelected,
                    selectedColor: AppColors.catConverter,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _activeTab = tab);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          if (_activeTab == ImageToolkitTab.compress) _buildCompressTab(isDark),
          if (_activeTab == ImageToolkitTab.resizeCrop) _buildResizeCropTab(isDark),
          if (_activeTab == ImageToolkitTab.convert) _buildConvertTab(isDark),
          if (_activeTab == ImageToolkitTab.rotateFlip) _buildRotateFlipTab(isDark),
          if (_activeTab == ImageToolkitTab.combine) _buildCombineTab(isDark),
          if (_activeTab == ImageToolkitTab.base64) _buildBase64Tab(isDark),
          if (_activeTab == ImageToolkitTab.removeExif) _buildRemoveExifTab(isDark),
          if (_activeTab == ImageToolkitTab.watermark) _buildWatermarkTab(isDark),
          if (_activeTab == ImageToolkitTab.passport) _buildPassportTab(isDark),
        ],
      ),
    );
  }

  // ===================== INDIVIDUAL TABS =====================

  Widget _buildCompressTab(bool isDark) {
    final origKb = _compressImage != null ? (_compressImage!.sizeBytes / 1024).toStringAsFixed(1) : '0';
    final compKb = _compressedSizeBytes > 0 ? (_compressedSizeBytes / 1024).toStringAsFixed(1) : '0';
    final savedPercent = (_compressImage != null && _compressedSizeBytes > 0)
        ? (((_compressImage!.sizeBytes - _compressedSizeBytes) / _compressImage!.sizeBytes) * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Compression Overview',
          primaryResult: _compressedSizeBytes > 0 ? '$compKb KB' : 'Select an Image',
          subtitle: _compressedSizeBytes > 0 ? 'Saved $savedPercent% of original $origKb KB' : 'Reduces file size with smart JPEG encoding',
          accentColor: AppColors.catConverter,
          breakdowns: [
            BreakdownItem(label: 'Original Size', value: '$origKb KB'),
            BreakdownItem(label: 'Quality Level', value: '${_compressQuality.round()}%'),
            BreakdownItem(label: 'Compression', value: savedPercent > 0 ? '-$savedPercent%' : 'Ready'),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_rounded),
          label: const Text('Pick Image to Compress'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catConverter,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickCompressImage,
        ),
        if (_compressImage != null) ...[
          const SizedBox(height: 20),
          Text('Compression Quality: ${_compressQuality.round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _compressQuality,
            min: 5,
            max: 100,
            divisions: 19,
            activeColor: AppColors.catConverter,
            label: '${_compressQuality.round()}%',
            onChanged: (val) {
              setState(() => _compressQuality = val);
              _runCompression();
            },
          ),
          if (_compressedBytes != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_compressedBytes!, height: 200, fit: BoxFit.contain),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Save / Share Compressed Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catConverter,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Printing.sharePdf(bytes: _compressedBytes!, filename: 'Compressed_${_compressImage!.name}'),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildResizeCropTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Dimensions',
          primaryResult: _resizeImage != null ? '${_resizeImage!.width} × ${_resizeImage!.height} px' : 'Pick an Image',
          subtitle: 'Resize by custom pixel dimensions or standard aspect ratios',
          accentColor: AppColors.catConverter,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.photo_size_select_actual_rounded),
          label: const Text('Pick Image to Resize / Crop'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catConverter,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickResizeImage,
        ),
        if (_resizeImage != null) ...[
          const SizedBox(height: 16),
          const Text('Standard Aspect Ratio Presets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['1:1 Square', '16:9 Landscape', '4:3 Standard', '9:16 Story'].map((p) {
              return ActionChip(
                label: Text(p),
                onPressed: () => _applyCropPreset(p),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  label: 'Width (px)',
                  controller: _resizeWidthController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.swap_horiz_rounded,
                  onChanged: (val) {
                    if (_maintainAspectRatio) {
                      final w = int.tryParse(val) ?? 0;
                      final h = (w / _aspectRatioFactor).round();
                      _resizeHeightController.text = h.toString();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ModernTextField(
                  label: 'Height (px)',
                  controller: _resizeHeightController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.swap_vert_rounded,
                  onChanged: (val) {
                    if (_maintainAspectRatio) {
                      final h = int.tryParse(val) ?? 0;
                      final w = (h * _aspectRatioFactor).round();
                      _resizeWidthController.text = w.toString();
                    }
                  },
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lock Aspect Ratio', style: TextStyle(fontWeight: FontWeight.w600)),
            value: _maintainAspectRatio,
            activeColor: AppColors.catConverter,
            onChanged: (val) => setState(() => _maintainAspectRatio = val),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.crop_rotate_rounded),
              label: const Text('Apply Resize & Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catConverter,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _runResizeCrop,
            ),
          ),
          if (_resizedBytes != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_resizedBytes!, height: 180, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share Resized Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catConverter,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () => Printing.sharePdf(bytes: _resizedBytes!, filename: 'Resized_${_resizeImage!.name}'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildConvertTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Format Converter',
          primaryResult: _convertImage != null ? '${_convertImage!.format} ➔ $_targetFormat' : 'Select an Image',
          subtitle: 'Converts between JPG, PNG, BMP, and GIF formats losslessly',
          accentColor: AppColors.catConverter,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.transform_rounded),
          label: const Text('Pick Image to Convert'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catConverter,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickConvertImage,
        ),
        if (_convertImage != null) ...[
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Target Format',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            value: _targetFormat,
            items: ['PNG', 'JPG', 'BMP', 'GIF'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _targetFormat = val);
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.change_circle_rounded),
              label: Text('Convert to $_targetFormat & Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catConverter,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _runFormatConvert,
            ),
          ),
          if (_convertedBytes != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_convertedBytes!, height: 180, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: Text('Share $_targetFormat File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catConverter,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () => Printing.sharePdf(bytes: _convertedBytes!, filename: 'Converted_${_convertImage!.name}.$_targetFormat'.toLowerCase()),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildRotateFlipTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Transform',
          primaryResult: '$_rotationAngle° Rotation',
          subtitle: '${_flipHorizontal ? 'Horizontal Flip • ' : ''}${_flipVertical ? 'Vertical Flip' : 'Original orientation'}',
          accentColor: AppColors.catConverter,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.rotate_90_degrees_cw_rounded),
          label: const Text('Pick Image to Rotate & Flip'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catConverter,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickRotateImage,
        ),
        if (_rotateImage != null) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.rotate_left_rounded),
                onPressed: () {
                  setState(() => _rotationAngle = (_rotationAngle - 90 + 360) % 360);
                  _runTransform();
                },
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.rotate_right_rounded),
                onPressed: () {
                  setState(() => _rotationAngle = (_rotationAngle + 90) % 360);
                  _runTransform();
                },
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.flip_rounded),
                onPressed: () {
                  setState(() => _flipHorizontal = !_flipHorizontal);
                  _runTransform();
                },
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.swap_vert_rounded),
                onPressed: () {
                  setState(() => _flipVertical = !_flipVertical);
                  _runTransform();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_transformedBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_transformedBytes!, height: 200, fit: BoxFit.contain),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Save & Share Transformed Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catConverter,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Printing.sharePdf(bytes: _transformedBytes!, filename: 'Transformed_${_rotateImage!.name}'),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCombineTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Combine & Stitch',
          primaryResult: '${_combineImages.length} Images Selected',
          subtitle: 'Layout: $_combineLayout',
          accentColor: AppColors.catConverter,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_rounded),
          label: const Text('Add Images to Combine'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catConverter,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickCombineImages,
        ),
        if (_combineImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Combine Layout',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            value: _combineLayout,
            items: ['Side by Side', 'Stacked Vertical', '2x2 Grid']
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _combineLayout = val);
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.grid_on_rounded),
              label: const Text('Combine & Stitch Images'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catConverter,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _runCombine,
            ),
          ),
          if (_combinedResultBytes != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_combinedResultBytes!, height: 200, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share Combined Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catConverter,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () => Printing.sharePdf(bytes: _combinedResultBytes!, filename: 'Combined_Image.png'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildBase64Tab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Base64 Converter',
          primaryResult: _base64SourceImage != null ? 'Image Encoded' : 'Decode or Encode',
          subtitle: 'Convert between raw image bytes and Base64 Data URI strings',
          accentColor: AppColors.catConverter,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.image_rounded),
                label: const Text('Image ➔ Base64'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catConverter,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _pickBase64Image,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.code_rounded),
                label: const Text('Decode String'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _decodeBase64String,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'Base64 String',
          controller: _base64StringController,
          hintText: 'Paste data:image/png;base64,... string here',
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        if (_base64StringController.text.isNotEmpty)
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy Base64 Data'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _base64StringController.text));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Base64 copied!')));
            },
          ),
        if (_base64DecodedBytes != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_base64DecodedBytes!, height: 180, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Decoded Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catConverter,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () => Printing.sharePdf(bytes: _base64DecodedBytes!, filename: 'Decoded_Image.png'),
          ),
        ],
      ],
    );
  }

  Widget _buildRemoveExifTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'EXIF Metadata Stripper',
          primaryResult: _exifSourceImage != null ? _exifSourceImage!.name : 'Select an Image',
          subtitle: 'Removes GPS coordinates, camera model, lens info, and timestamps',
          accentColor: AppColors.catConverter,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.security_rounded),
          label: const Text('Pick Image to Clean EXIF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catConverter,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickExifImage,
        ),
        if (_cleanExifBytes != null) ...[
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success),
              SizedBox(width: 8),
              Text('EXIF Privacy Data Successfully Removed!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share Clean Anonymous Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catConverter,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Printing.sharePdf(bytes: _cleanExifBytes!, filename: 'Clean_${_exifSourceImage!.name}'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWatermarkTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Photo Watermark',
          primaryResult: _watermarkTextController.text,
          subtitle: 'Position: $_watermarkPosition • Opacity: ${(_watermarkOpacity * 100).round()}%',
          accentColor: AppColors.catConverter,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.branding_watermark_rounded),
          label: const Text('Pick Image to Watermark'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catConverter,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickWatermarkImage,
        ),
        if (_watermarkSourceImage != null) ...[
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Watermark Text',
            controller: _watermarkTextController,
            prefixIcon: Icons.edit_rounded,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Watermark Position',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            value: _watermarkPosition,
            items: ['Center', 'Bottom Right', 'Top Left', 'Repeat Diagonal']
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _watermarkPosition = val);
            },
          ),
          const SizedBox(height: 16),
          Text('Opacity: ${(_watermarkOpacity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _watermarkOpacity,
            min: 0.1,
            max: 1.0,
            activeColor: AppColors.catConverter,
            onChanged: (val) => setState(() => _watermarkOpacity = val),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: const Text('Apply Watermark & Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catConverter,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _applyWatermark,
            ),
          ),
          if (_watermarkedBytes != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_watermarkedBytes!, height: 180, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share Watermarked Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catConverter,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () => Printing.sharePdf(bytes: _watermarkedBytes!, filename: 'Watermarked_${_watermarkSourceImage!.name}'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPassportTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Passport Photo Maker',
          primaryResult: _passportPreset,
          subtitle: 'Generates single photo & printable $_sheetCopies-photo 4x6" Sheet',
          accentColor: AppColors.catConverter,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.face_rounded),
          label: const Text('Pick Portrait Photo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catConverter,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _pickPassportImage,
        ),
        if (_passportSourceImage != null) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Passport Dimension Preset',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            value: _passportPreset,
            items: [
              'US Passport (2x2 in)',
              'Schengen / India (35x45mm)',
              'ID Card (30x40mm)',
            ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _passportPreset = val);
                _generatePassportPhotos();
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: 'Sheet Print Copies',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            value: _sheetCopies,
            items: [4, 6, 8, 12].map((c) => DropdownMenuItem(value: c, child: Text('$c Photos on 4x6" Sheet'))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _sheetCopies = val);
                _generatePassportPhotos();
              }
            },
          ),
          const SizedBox(height: 20),
          if (_passportSingleBytes != null && _passportSheetBytes != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Single Cutout', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_passportSingleBytes!, height: 140, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.catConverter, foregroundColor: Colors.white),
                        onPressed: () => Printing.sharePdf(bytes: _passportSingleBytes!, filename: 'Passport_Single.png'),
                        child: const Text('Share Single'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Printable Sheet', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_passportSheetBytes!, height: 140, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.catConverter, foregroundColor: Colors.white),
                        onPressed: () => Printing.sharePdf(bytes: _passportSheetBytes!, filename: 'Passport_Print_Sheet.jpg'),
                        child: const Text('Share Sheet'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
