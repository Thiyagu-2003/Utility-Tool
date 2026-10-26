import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/share_utils.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';
import 'photo_editor_screen.dart';
import 'photo_editor_service.dart';
import 'collage_maker_screen.dart';

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
  String _targetFormat = 'PNG'; // JPG, PNG, BMP, GIF
  String _convertedFormat = 'PNG'; // format _convertedBytes really is
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
  String? _base64Full; // the whole string when the text box shows only the start of a huge one
  static const _base64BoxLimit = 20000;

  // 7. Remove EXIF State
  LoadedImage? _exifSourceImage;
  Uint8List? _cleanExifBytes;
  String _cleanExifExt = 'jpg';

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
  int _passportPlaced = 0;

  @override
  void dispose() {
    _resizeWidthController.dispose();
    _resizeHeightController.dispose();
    _base64StringController.dispose();
    _watermarkTextController.dispose();
    super.dispose();
  }

  // --- HELPERS ---

  bool _isBusy = false;
  Future<void> Function()? _queuedJob;

  /// Runs [job] with the busy flag set and reports failures. Heavy pixel work inside [job] must go
  /// through an `...InBackground` function so the UI never freezes. Only one job runs at a time; a
  /// request that arrives meanwhile is queued (the newest one wins) rather than silently dropped.
  Future<void> _work(String failure, Future<void> Function() job) async {
    if (_isBusy) {
      _queuedJob = () => _work(failure, job);
      return;
    }
    PreferencesService().triggerHaptic();
    setState(() => _isBusy = true);
    try {
      await job();
    } catch (e) {
      _showError('$failure: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
      final next = _queuedJob;
      _queuedJob = null;
      if (next != null && mounted) next();
    }
  }

  Future<LoadedImage?> _pickSingleImage() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (!mounted) return null;
      final size = await readImageSizeInBackground(bytes);
      if (!mounted) return null;
      if (size == null) {
        _showError('Unsupported or corrupt image file.');
        return null;
      }
      return LoadedImage(
        name: file.name,
        bytes: bytes,
        width: size.$1,
        height: size.$2,
        sizeBytes: bytes.length,
        format: file.extension?.toUpperCase() ?? 'JPG',
      );
    } catch (e) {
      _showError('Error picking image: $e');
      return null;
    }
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

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _share(Uint8List bytes, String filename) async {
    PreferencesService().triggerHaptic();
    try {
      await shareFileBytes(bytes, filename);
    } catch (e) {
      _showError('Share failed: $e');
    }
  }

  // --- TAB 1: COMPRESS ---
  Future<void> _pickCompressImage() async {
    final image = await _pickSingleImage();
    if (image != null && mounted) {
      setState(() {
        _compressImage = image;
        _compressedBytes = null;
        _compressedSizeBytes = 0;
      });
      _runCompression();
    }
  }

  Future<void> _runCompression() async {
    final source = _compressImage;
    if (source == null) return;
    final quality = _compressQuality.round().clamp(1, 100);
    await _work('Compression error', () async {
      final out = await compressImageInBackground(source.bytes, quality);
      if (!mounted || !identical(source, _compressImage)) return; // another image was picked meanwhile
      if (out == null) {
        _showError('Could not read that image.');
        return;
      }
      setState(() {
        _compressedBytes = out;
        _compressedSizeBytes = out.length;
      });
    });
  }

  // --- TAB 2: RESIZE & CROP ---
  Future<void> _pickResizeImage() async {
    final image = await _pickSingleImage();
    if (image != null && mounted) {
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
      // Lock subsequent edits to the preset's ratio, not the original image's.
      _aspectRatioFactor = switch (preset) {
        '1:1 Square' => 1.0,
        '16:9 Landscape' => 16 / 9,
        '4:3 Standard' => 4 / 3,
        '9:16 Story' => 9 / 16,
        _ => _aspectRatioFactor,
      };
      _resizedBytes = null;
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

  /// Keeps the other dimension in step while the aspect ratio is locked; a half-typed or empty
  /// field leaves it alone (it used to flip to 0). Any edit makes the old result stale.
  void _onResizeDimensionChanged({required bool widthChanged, required String text}) {
    final value = int.tryParse(text);
    if (_maintainAspectRatio && value != null && value > 0) {
      if (widthChanged) {
        _resizeHeightController.text = (value / _aspectRatioFactor).round().toString();
      } else {
        _resizeWidthController.text = (value * _aspectRatioFactor).round().toString();
      }
    }
    if (_resizedBytes != null) setState(() => _resizedBytes = null);
  }

  Future<void> _runResizeCrop() async {
    final source = _resizeImage;
    if (source == null) return;
    final targetW = int.tryParse(_resizeWidthController.text.trim()) ?? source.width;
    final targetH = int.tryParse(_resizeHeightController.text.trim()) ?? source.height;
    if (targetW < 1 || targetH < 1 || targetW > 10000 || targetH > 10000) {
      _showError('Width and height must be between 1 and 10000 px.');
      return;
    }
    if (targetW * targetH > maxResizePixels) {
      _showError('That output is over ${maxResizePixels ~/ 1000000} megapixels, more than a phone can safely build. Use smaller dimensions.');
      return;
    }
    await _work('Resize failed', () async {
      // Centre-crop to the target ratio first so presets crop instead of stretching.
      final out = await resizeImageInBackground(source.bytes, targetW, targetH);
      if (!mounted || !identical(source, _resizeImage)) return;
      if (out == null) {
        _showError('Could not read that image.');
        return;
      }
      setState(() => _resizedBytes = out);
    });
  }

  // --- TAB 3: FORMAT CONVERT ---
  Future<void> _pickConvertImage() async {
    final image = await _pickSingleImage();
    if (image != null && mounted) {
      setState(() {
        _convertImage = image;
        _convertedBytes = null;
      });
    }
  }

  Future<void> _runFormatConvert() async {
    final source = _convertImage;
    if (source == null) return;
    final format = _targetFormat;
    await _work('Conversion failed', () async {
      final out = await convertImageInBackground(source.bytes, format);
      if (!mounted || !identical(source, _convertImage)) return;
      if (out == null) {
        _showError('Could not read that image.');
        return;
      }
      setState(() {
        _convertedBytes = out;
        _convertedFormat = format;
      });
    });
  }

  // --- TAB 4: ROTATE & FLIP ---
  Future<void> _pickRotateImage() async {
    final image = await _pickSingleImage();
    if (image != null && mounted) {
      setState(() {
        _rotateImage = image;
        _rotationAngle = 0;
        _flipHorizontal = false;
        _flipVertical = false;
        _transformedBytes = null;
      });
      _runTransform();
    }
  }

  Future<void> _runTransform() async {
    final source = _rotateImage;
    if (source == null) return;
    final angle = _rotationAngle;
    final flipH = _flipHorizontal;
    final flipV = _flipVertical;
    await _work('Transformation failed', () async {
      final out = await transformImageInBackground(source.bytes, angle, flipH, flipV);
      if (!mounted || !identical(source, _rotateImage)) return;
      if (out == null) {
        _showError('Could not read that image.');
        return;
      }
      setState(() => _transformedBytes = out);
    });
  }

  /// Turn the picture by [delta] degrees as seen on screen, then refresh the preview.
  void _rotate(int delta) {
    setState(() => _rotationAngle = nextRotation(_rotationAngle, delta, _flipHorizontal, _flipVertical));
    _runTransform();
  }

  // --- TAB 5: COMBINE IMAGES ---
  Future<void> _pickCombineImages() async {
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (files.isNotEmpty) {
        var skipped = 0;
        for (final file in files) {
          final bytes = await file.readAsBytes();
          if (!mounted) return;
          final size = await readImageSizeInBackground(bytes);
          if (!mounted) return;
          if (size == null) {
            skipped++;
            continue;
          }
          _combineImages.add(
            LoadedImage(
              name: file.name,
              bytes: bytes,
              width: size.$1,
              height: size.$2,
              sizeBytes: bytes.length,
              format: file.extension?.toUpperCase() ?? 'PNG',
            ),
          );
        }
        if (skipped > 0) _showError('$skipped file(s) could not be read as images and were skipped.');
        setState(() => _combinedResultBytes = null);
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
    final inputs = [for (final i in _combineImages) i.bytes];
    final layout = _combineLayout;
    final spacing = _combineSpacing.toInt();
    if (layout == '2x2 Grid' && inputs.length > 4) {
      _showInfo('2x2 Grid uses the first 4 images only.');
    }
    await _work('Combine error', () async {
      final out = await combineImagesInBackground(inputs, layout, spacing);
      if (!mounted) return;
      if (out == null) {
        _showError('Fewer than 2 of those files could be read as images.');
        return;
      }
      setState(() => _combinedResultBytes = out);
    });
  }

  // --- TAB 6: BASE64 ---

  /// The text the Base64 buttons act on: the real string, even when the box only shows the start
  /// of a very large one (a multi-megabyte string in a text field freezes the UI).
  String get _base64Text => _base64Full ?? _base64StringController.text;

  Future<void> _pickBase64Image() async {
    final image = await _pickSingleImage();
    if (image == null || !mounted) return;
    final full = 'data:${imageMimeType(image.bytes)};base64,${base64Encode(image.bytes)}';
    final isBig = full.length > _base64BoxLimit;
    setState(() {
      _base64SourceImage = image;
      _base64DecodedBytes = null;
      _base64Full = isBig ? full : null;
      _base64StringController.text = isBig
          ? '${full.substring(0, _base64BoxLimit ~/ 10)}...\n[${full.length} characters in total - only the start is shown. '
              'Copy Base64 Data copies all of it.]'
          : full;
    });
  }

  void _decodeBase64String() {
    final input = _base64Text.trim();
    if (input.isEmpty) return;
    try {
      final bytes = decodeBase64Image(input);
      setState(() {
        _base64DecodedBytes = bytes;
      });
      PreferencesService().triggerHaptic();
    } catch (e) {
      _showError('Invalid Base64 string: $e');
    }
  }

  String _base64DecodedExt() => imageMimeType(_base64DecodedBytes!).split('/').last.replaceAll('jpeg', 'jpg');

  // --- TAB 7: REMOVE EXIF ---
  Future<void> _pickExifImage() async {
    final image = await _pickSingleImage();
    if (image != null && mounted) {
      setState(() {
        _exifSourceImage = image;
        _cleanExifBytes = null;
      });
      _stripExif();
    }
  }

  Future<void> _stripExif() async {
    final source = _exifSourceImage;
    if (source == null) return;
    await _work('EXIF stripping failed', () async {
      final clean = await stripImageMetadataInBackground(source.bytes);
      if (!mounted || !identical(source, _exifSourceImage)) return;
      if (clean == null) {
        _showError('Could not read that image.');
        return;
      }
      setState(() {
        _cleanExifBytes = clean.$1;
        _cleanExifExt = clean.$2;
      });
    });
  }

  // --- TAB 8: WATERMARK ---
  Future<void> _pickWatermarkImage() async {
    final image = await _pickSingleImage();
    if (image != null && mounted) {
      setState(() {
        _watermarkSourceImage = image;
        _watermarkedBytes = null;
      });
    }
  }

  Future<void> _applyWatermark() async {
    final source = _watermarkSourceImage;
    if (source == null) return;
    final text = _watermarkTextController.text.trim();
    if (text.isEmpty) {
      _showError('Enter watermark text first.');
      return;
    }
    final position = _watermarkPosition;
    final opacity = _watermarkOpacity;
    await _work('Watermarking failed', () async {
      final out = await watermarkImageInBackground(source.bytes, text, position, opacity);
      if (!mounted || !identical(source, _watermarkSourceImage)) return;
      if (out == null) {
        _showError('Could not read that image.');
        return;
      }
      setState(() => _watermarkedBytes = out);
    });
  }

  // --- TAB 9: PASSPORT PHOTO MAKER ---
  Future<void> _pickPassportImage() async {
    final image = await _pickSingleImage();
    if (image != null && mounted) {
      setState(() {
        _passportSourceImage = image;
        _passportSingleBytes = null;
        _passportSheetBytes = null;
      });
      _generatePassportPhotos();
    }
  }

  Future<void> _generatePassportPhotos() async {
    final source = _passportSourceImage;
    if (source == null) return;
    var targetW = 600;
    var targetH = 600;
    if (_passportPreset == 'Schengen / India (35x45mm)') {
      targetW = 413;
      targetH = 531;
    } else if (_passportPreset == 'ID Card (30x40mm)') {
      targetW = 354;
      targetH = 472;
    }
    final copies = _sheetCopies;
    await _work('Passport photo generation error', () async {
      final result = await makePassportPhotosInBackground(source.bytes, targetW, targetH, copies);
      if (!mounted || !identical(source, _passportSourceImage)) return;
      if (result == null) {
        _showError('Could not read that image.');
        return;
      }
      setState(() {
        _passportSingleBytes = result.single;
        _passportSheetBytes = result.sheet;
        _passportPlaced = result.placed;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Image Toolkit',
      category: ToolCategory.imagePhoto,
      toolId: 'image_toolkit',
      onReset: () {
        _queuedJob = null;
        setState(() {
          _compressImage = null;
          _compressedBytes = null;
          _compressedSizeBytes = 0;
          _compressQuality = 75;
          _resizeImage = null;
          _resizedBytes = null;
          _resizeWidthController.clear();
          _resizeHeightController.clear();
          _maintainAspectRatio = true;
          _aspectRatioFactor = 1.0;
          _convertImage = null;
          _convertedBytes = null;
          _targetFormat = 'PNG';
          _convertedFormat = 'PNG';
          _rotateImage = null;
          _transformedBytes = null;
          _rotationAngle = 0;
          _flipHorizontal = false;
          _flipVertical = false;
          _combineImages.clear();
          _combineLayout = 'Side by Side';
          _combinedResultBytes = null;
          _base64SourceImage = null;
          _base64StringController.clear();
          _base64Full = null;
          _base64DecodedBytes = null;
          _exifSourceImage = null;
          _cleanExifBytes = null;
          _cleanExifExt = 'jpg';
          _watermarkSourceImage = null;
          _watermarkedBytes = null;
          _watermarkTextController.text = 'CONFIDENTIAL';
          _watermarkPosition = 'Center';
          _watermarkOpacity = 0.5;
          _passportSourceImage = null;
          _passportSingleBytes = null;
          _passportSheetBytes = null;
          _passportPreset = 'US Passport (2x2 in)';
          _sheetCopies = 6;
          _passportPlaced = 0;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              PreferencesService().triggerHaptic();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhotoEditorScreen()));
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.catImage.withValues(alpha: 0.15),
                  AppColors.catImage.withValues(alpha: 0.05),
                ]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.catImage.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high_rounded, color: AppColors.catImage, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Looking for Photo Editing? Open Photo Studio & Editor (Background Removal, Censor, Filters & Draw)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.catImage),
                ],
              ),
            ),
          ),
          // Navigation Chips
          FeatureTabSelector<ImageToolkitTab>(
            tabs: ImageToolkitTab.values
                .map((tab) => FeatureTabItem(value: tab, label: tab.label, icon: tab.icon))
                .toList(),
            activeTab: _activeTab,
            accentColor: AppColors.catConverter,
            title: 'Image Studio Tools',
            onTabSelected: (tab) => setState(() => _activeTab = tab),
          ),
          const SizedBox(height: 20),
          if (_isBusy) ...[
            const LinearProgressIndicator(color: AppColors.catConverter),
            const SizedBox(height: 16),
          ],

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
          subtitle: _compressedSizeBytes == 0
              ? 'Reduces file size with smart JPEG encoding'
              : (savedPercent >= 0
                  ? 'Saved $savedPercent% of original $origKb KB'
                  : '${-savedPercent}% larger than the original $origKb KB - lower the quality'),
          accentColor: AppColors.catConverter,
          breakdowns: [
            BreakdownItem(label: 'Original Size', value: '$origKb KB'),
            BreakdownItem(label: 'Quality Level', value: '${_compressQuality.round()}%'),
            BreakdownItem(label: 'Compression', value: _compressedSizeBytes == 0 ? 'Ready' : (savedPercent >= 0 ? '-$savedPercent%' : '+${-savedPercent}%')),
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
            onChanged: (val) => setState(() => _compressQuality = val),
            // Re-encode once on release instead of on every drag tick.
            onChangeEnd: (_) => _runCompression(),
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
                onPressed: () => _share(_compressedBytes!, withExtension('Compressed_${_compressImage!.name}', 'jpg')),
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
                  onChanged: (val) => _onResizeDimensionChanged(widthChanged: true, text: val),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ModernTextField(
                  label: 'Height (px)',
                  controller: _resizeHeightController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.swap_vert_rounded,
                  onChanged: (val) => _onResizeDimensionChanged(widthChanged: false, text: val),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lock Aspect Ratio', style: TextStyle(fontWeight: FontWeight.w600)),
            value: _maintainAspectRatio,
            activeThumbColor: AppColors.catConverter,
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
              onPressed: () => _share(_resizedBytes!, withExtension('Resized_${_resizeImage!.name}', 'png')),
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
          subtitle: 'Converts between JPG, PNG, BMP, and GIF formats',
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
            initialValue: _targetFormat,
            items: ['PNG', 'JPG', 'BMP', 'GIF'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (val) {
              // The old conversion is in the previous format, so drop it rather than mislabel it.
              if (val != null) {
                setState(() {
                  _targetFormat = val;
                  _convertedBytes = null;
                });
              }
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.change_circle_rounded),
              label: Text('Convert to $_targetFormat'),
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
              label: Text('Share $_convertedFormat File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catConverter,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () => _share(_convertedBytes!, withExtension('Converted_${_convertImage!.name}', _convertedFormat.toLowerCase())),
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
          subtitle: !_flipHorizontal && !_flipVertical
              ? 'Original orientation'
              : [if (_flipHorizontal) 'Horizontal Flip', if (_flipVertical) 'Vertical Flip'].join(' • '),
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
                tooltip: 'Rotate left',
                icon: const Icon(Icons.rotate_left_rounded),
                onPressed: () => _rotate(-90),
              ),
              IconButton.filledTonal(
                tooltip: 'Rotate right',
                icon: const Icon(Icons.rotate_right_rounded),
                onPressed: () => _rotate(90),
              ),
              IconButton.filledTonal(
                tooltip: 'Flip horizontally',
                icon: const Icon(Icons.flip_rounded),
                onPressed: () {
                  setState(() => _flipHorizontal = !_flipHorizontal);
                  _runTransform();
                },
              ),
              IconButton.filledTonal(
                tooltip: 'Flip vertically',
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
                onPressed: () => _share(_transformedBytes!, withExtension('Transformed_${_rotateImage!.name}', 'png')),
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
        InkWell(
          onTap: () {
            PreferencesService().triggerHaptic();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollageMakerScreen()));
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.catImage.withValues(alpha: 0.15),
                AppColors.catImage.withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.catImage.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.dashboard_customize_rounded, color: AppColors.catImage, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Looking for full creative collage layouts? Open Collage Maker Studio (Templates, borders & aspect ratios)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.catImage),
              ],
            ),
          ),
        ),
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Clear selection'),
              onPressed: () => setState(() {
                _combineImages.clear();
                _combinedResultBytes = null;
              }),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Combine Layout',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            initialValue: _combineLayout,
            items: ['Side by Side', 'Stacked Vertical', '2x2 Grid']
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _combineLayout = val;
                  _combinedResultBytes = null;
                });
              }
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
              onPressed: () => _share(_combinedResultBytes!, 'Combined_Image.png'),
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
          // Editing the box means the user now owns its text, not the stored full string.
          onChanged: (_) => setState(() => _base64Full = null),
        ),
        const SizedBox(height: 12),
        if (_base64Text.isNotEmpty)
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy Base64 Data'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _base64Text));
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
            onPressed: () => _share(_base64DecodedBytes!, 'Decoded_Image.${_base64DecodedExt()}'),
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
              onPressed: () => _share(_cleanExifBytes!, withExtension('Clean_${_exifSourceImage!.name}', _cleanExifExt)),
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
            initialValue: _watermarkPosition,
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
              onPressed: () => _share(_watermarkedBytes!, withExtension('Watermarked_${_watermarkSourceImage!.name}', 'png')),
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
          subtitle: _passportSheetBytes != null && _passportPlaced < _sheetCopies
              ? 'Only $_passportPlaced of $_sheetCopies photos fit on a 4x6" sheet at true size'
              : 'Generates single photo & printable $_sheetCopies-photo 4x6" Sheet',
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
            initialValue: _passportPreset,
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
            initialValue: _sheetCopies,
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
                        onPressed: () => _share(_passportSingleBytes!, 'Passport_Single.png'),
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
                        onPressed: () => _share(_passportSheetBytes!, 'Passport_Print_Sheet.jpg'),
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

// ===================== PURE HELPERS (tested in test/image_tools_test.dart) =====================

/// Replaces the extension of [name] (or appends one) so shared files match their bytes.
String withExtension(String name, String ext) {
  final dot = name.lastIndexOf('.');
  return '${dot > 0 ? name.substring(0, dot) : name}.$ext';
}

/// JPEG has no alpha channel: composite onto white so transparent areas don't turn black.
img.Image flattenOnWhite(img.Image src) {
  if (!src.hasAlpha) return src;
  final bg = img.Image(width: src.width, height: src.height);
  img.fill(bg, color: img.ColorRgb8(255, 255, 255));
  return img.compositeImage(bg, src);
}

/// Centre-crops [src] to the [width]:[height] ratio, then resizes to exactly that size.
img.Image cropToAspect(img.Image src, int width, int height) {
  var cropW = src.width;
  var cropH = src.height;
  if (cropW * height > cropH * width) {
    cropW = max(1, (cropH * width / height).round());
  } else {
    cropH = max(1, (cropW * height / width).round());
  }
  final cropped = img.copyCrop(
    src,
    x: (src.width - cropW) ~/ 2,
    y: (src.height - cropH) ~/ 2,
    width: cropW,
    height: cropH,
  );
  return img.copyResize(cropped, width: width, height: height, interpolation: img.Interpolation.linear);
}

/// MIME type of encoded image [bytes], used for Base64 data URIs.
String imageMimeType(Uint8List bytes) {
  switch (img.findFormatForData(bytes)) {
    case img.ImageFormat.jpg:
      return 'image/jpeg';
    case img.ImageFormat.gif:
      return 'image/gif';
    case img.ImageFormat.bmp:
      return 'image/bmp';
    case img.ImageFormat.webp:
      return 'image/webp';
    default:
      return 'image/png';
  }
}

/// Decodes a Base64 string or data URI into image bytes. Tolerates whitespace/newlines,
/// URL-safe alphabets and missing padding. Throws [FormatException] for non-images.
Uint8List decodeBase64Image(String input) {
  var data = input.trim();
  final comma = data.indexOf(',');
  if (comma != -1) data = data.substring(comma + 1);
  data = data.replaceAll(RegExp(r'\s'), '');
  final bytes = base64Decode(base64.normalize(data));
  const displayable = {
    img.ImageFormat.jpg,
    img.ImageFormat.png,
    img.ImageFormat.gif,
    img.ImageFormat.bmp,
    img.ImageFormat.webp,
  };
  if (!displayable.contains(img.findFormatForData(bytes))) {
    throw const FormatException('Decoded data is not a JPG, PNG, GIF, BMP or WebP image');
  }
  return bytes;
}

/// Re-encodes [bytes] without EXIF / text metadata. PNG stays PNG (keeping transparency);
/// everything else becomes JPEG. Returns the clean bytes and their file extension.
(Uint8List, String)? stripImageMetadata(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final clean = img.Image.from(decoded)
    ..exif.clear()
    ..textData = null;
  if (img.findFormatForData(bytes) == img.ImageFormat.png) {
    return (Uint8List.fromList(img.encodePng(clean)), 'png');
  }
  return (Uint8List.fromList(img.encodeJpg(flattenOnWhite(clean), quality: 95)), 'jpg');
}

/// Rendered width of [text] in [font], matching how `img.drawString` advances.
int bitmapTextWidth(img.BitmapFont font, String text) =>
    text.codeUnits.fold(0, (w, c) => w + (font.characters[c]?.xAdvance ?? font.base ~/ 2));

/// Largest bundled font whose rendering of [text] fits in 90% of [imageWidth].
img.BitmapFont watermarkFont(String text, int imageWidth) {
  for (final font in [img.arial48, img.arial24]) {
    if (bitmapTextWidth(font, text) <= imageWidth * 0.9) return font;
  }
  return img.arial14;
}

/// Top-left origin for a [textW]×[textH] watermark so it stays inside the image.
(int, int) watermarkOrigin(String position, int imageW, int imageH, int textW, int textH) {
  const pad = 20;
  final (x, y) = switch (position) {
    'Bottom Right' => (imageW - textW - pad, imageH - textH - pad),
    'Top Left' => (pad, pad),
    _ => ((imageW - textW) ~/ 2, (imageH - textH) ~/ 2),
  };
  return (max(0, x), max(0, y));
}

/// Lays out up to [copies] photos of [photoW]×[photoH] px on a 300-dpi 4×6" sheet. Tries
/// portrait (1200×1800) and landscape (1800×1200) and keeps whichever fits more; photos are
/// never scaled, so fewer than [copies] slots may be returned. Gaps are spread evenly.
({int width, int height, List<(int, int)> slots}) passportSheetLayout(int photoW, int photoH, int copies) {
  ({int width, int height, List<(int, int)> slots})? best;
  for (final (sheetW, sheetH) in const [(1200, 1800), (1800, 1200)]) {
    final cols = sheetW ~/ photoW;
    final rows = sheetH ~/ photoH;
    final count = min(copies, cols * rows);
    if (best != null && count <= best.slots.length) continue;
    final usedCols = min(cols, count);
    final usedRows = count == 0 ? 0 : (count + cols - 1) ~/ cols;
    final gapX = (sheetW - usedCols * photoW) ~/ (usedCols + 1);
    final gapY = (sheetH - usedRows * photoH) ~/ (usedRows + 1);
    best = (
      width: sheetW,
      height: sheetH,
      slots: [
        for (var i = 0; i < count; i++)
          (gapX + (i % cols) * (photoW + gapX), gapY + (i ~/ cols) * (photoH + gapY)),
      ],
    );
  }
  return best!;
}

// ===================== BACKGROUND PROCESSING =====================
// Decoding, resizing and encoding photos takes seconds on a phone, so every tool runs its pixel
// work in an isolate. The functions are plain top-level ones (no widget state) so they can be
// sent to an isolate and unit tested directly; the `...InBackground` wrappers just call them.

/// Largest output (width x height) the resize tool will build: 40 MP is ~160 MB of pixels.
const int maxResizePixels = 40000000;

/// Longest side / total length a combined picture is scaled down to, to bound memory.
const int _combineMaxSide = 2400;
const int _combineMaxTotal = 12000;

img.Image? _safeDecodeImage(Uint8List bytes) {
  if (bytes.length < 8) return null;
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}

/// Width and height of [bytes] after EXIF orientation, or null if it is not a decodable image.
(int, int)? readImageSize(Uint8List bytes) {
  final decoded = _safeDecodeImage(bytes);
  return decoded == null ? null : (decoded.width, decoded.height);
}

Uint8List? compressImage(Uint8List bytes, int quality) {
  final decoded = _safeDecodeImage(bytes);
  if (decoded == null) return null;
  return Uint8List.fromList(img.encodeJpg(flattenOnWhite(decoded), quality: quality));
}

/// Centre-crops to the target ratio, resizes to exactly [width] x [height] and returns PNG bytes.
Uint8List? resizeImage(Uint8List bytes, int width, int height) {
  final decoded = _safeDecodeImage(bytes);
  if (decoded == null) return null;
  return Uint8List.fromList(img.encodePng(cropToAspect(decoded, width, height)));
}

/// Re-encodes [bytes] as 'JPG', 'PNG', 'BMP' or 'GIF'.
Uint8List? convertImage(Uint8List bytes, String format) {
  final decoded = _safeDecodeImage(bytes);
  if (decoded == null) return null;
  final List<int> out = switch (format) {
    'JPG' => img.encodeJpg(flattenOnWhite(decoded), quality: 90),
    'BMP' => img.encodeBmp(decoded),
    'GIF' => img.encodeGif(decoded),
    _ => img.encodePng(decoded),
  };
  return Uint8List.fromList(out);
}

/// Rotates clockwise by [angle] degrees, then mirrors. Works on a copy.
img.Image applyTransform(img.Image src, int angle, bool flipH, bool flipV) {
  var current = angle != 0 ? img.copyRotate(src, angle: angle.toDouble()) : img.Image.from(src);
  if (flipH) current = img.flipHorizontal(current);
  if (flipV) current = img.flipVertical(current);
  return current;
}

/// The angle to store after the user turns the picture by [delta] degrees *as seen on screen*.
/// [applyTransform] rotates first and mirrors second, and a mirror reverses the sense of a turn,
/// so with exactly one mirror active the stored angle must move the other way.
int nextRotation(int angle, int delta, bool flipH, bool flipV) {
  final d = flipH != flipV ? -delta : delta;
  return ((angle + d) % 360 + 360) % 360;
}

Uint8List? transformImage(Uint8List bytes, int angle, bool flipH, bool flipV) {
  final decoded = _safeDecodeImage(bytes);
  if (decoded == null) return null;
  return Uint8List.fromList(img.encodePng(applyTransform(decoded, angle, flipH, flipV)));
}

/// Stitches photos into one PNG: 'Side by Side', 'Stacked Vertical' or '2x2 Grid' (first four).
/// Unreadable inputs are skipped; null if fewer than two remain. Large results are scaled down.
Uint8List? combineImages(List<Uint8List> inputs, String layout, int spacing) {
  final decodedList = <img.Image>[];
  for (final bytes in inputs) {
    final d = _safeDecodeImage(bytes);
    if (d != null) decodedList.add(d);
  }
  if (decodedList.length < 2) return null;

  final white = img.ColorRgba8(255, 255, 255, 255);
  final n = decodedList.length;
  img.Image canvas;

  if (layout == 'Side by Side') {
    // Common height, capped so the whole strip stays under _combineMaxTotal px wide.
    final ratioSum = decodedList.fold<double>(0, (s, i) => s + i.width / i.height);
    var targetH = decodedList.map((i) => i.height).reduce(max);
    targetH = min(targetH, min(_combineMaxSide, ((_combineMaxTotal - spacing * (n + 1)) / ratioSum).floor()));
    targetH = max(1, targetH);
    final scaled = [for (final item in decodedList) img.copyResize(item, height: targetH, interpolation: img.Interpolation.linear)];
    final totalW = scaled.fold<int>(spacing, (w, i) => w + i.width + spacing);
    canvas = img.Image(width: totalW, height: targetH + spacing * 2);
    img.fill(canvas, color: white);
    var x = spacing;
    for (final item in scaled) {
      img.compositeImage(canvas, item, dstX: x, dstY: spacing);
      x += item.width + spacing;
    }
  } else if (layout == 'Stacked Vertical') {
    final ratioSum = decodedList.fold<double>(0, (s, i) => s + i.height / i.width);
    var targetW = decodedList.map((i) => i.width).reduce(max);
    targetW = min(targetW, min(_combineMaxSide, ((_combineMaxTotal - spacing * (n + 1)) / ratioSum).floor()));
    targetW = max(1, targetW);
    final scaled = [for (final item in decodedList) img.copyResize(item, width: targetW, interpolation: img.Interpolation.linear)];
    final totalH = scaled.fold<int>(spacing, (h, i) => h + i.height + spacing);
    canvas = img.Image(width: targetW + spacing * 2, height: totalH);
    img.fill(canvas, color: white);
    var y = spacing;
    for (final item in scaled) {
      img.compositeImage(canvas, item, dstX: spacing, dstY: y);
      y += item.height + spacing;
    }
  } else {
    // 2x2 grid: the first four images, each centre-cropped to a square cell.
    const cell = 500;
    canvas = img.Image(width: cell * 2 + spacing * 3, height: cell * 2 + spacing * 3);
    img.fill(canvas, color: white);
    for (var i = 0; i < n && i < 4; i++) {
      final res = cropToAspect(decodedList[i], cell, cell);
      img.compositeImage(canvas, res, dstX: spacing + (i % 2) * (cell + spacing), dstY: spacing + (i ~/ 2) * (cell + spacing));
    }
  }
  return Uint8List.fromList(img.encodePng(canvas));
}

/// Draws red [text] at [position] ('Center', 'Bottom Right', 'Top Left' or 'Repeat Diagonal')
/// with alpha [opacity] and returns PNG bytes.
Uint8List? watermarkImage(Uint8List bytes, String text, String position, double opacity) {
  final raw = _safeDecodeImage(bytes);
  if (raw == null) return null;
  // Palette / 16-bit images cannot take an RGBA8 text colour directly.
  final decoded = PhotoEditorService.toRgba8(raw);
  final font = watermarkFont(text, decoded.width);
  final textW = bitmapTextWidth(font, text);
  final textH = font.lineHeight;
  final color = img.ColorRgba8(255, 0, 0, (opacity * 255).round());

  if (position == 'Repeat Diagonal') {
    // Tile with steps derived from the text size, staggering rows for a diagonal look.
    final stepX = textW + 80;
    final stepY = textH + 100;
    for (int y = 20, row = 0; y < decoded.height; y += stepY, row++) {
      for (int x = 20 - (row % 2) * (stepX ~/ 2); x < decoded.width; x += stepX) {
        img.drawString(decoded, text, font: font, x: x, y: y, color: color);
      }
    }
  } else {
    final (x, y) = watermarkOrigin(position, decoded.width, decoded.height, textW, textH);
    img.drawString(decoded, text, font: font, x: x, y: y, color: color);
  }
  return Uint8List.fromList(img.encodePng(decoded));
}

/// A centre-cropped [targetW] x [targetH] photo (PNG) and a 300-dpi 4x6" sheet (JPEG) holding
/// up to [copies] of it at true size; `placed` is how many really fit.
({Uint8List single, Uint8List sheet, int placed})? makePassportPhotos(Uint8List bytes, int targetW, int targetH, int copies) {
  final decoded = _safeDecodeImage(bytes);
  if (decoded == null) return null;
  // Centre-crop to the preset's aspect ratio, then resize (no stretching).
  final single = cropToAspect(decoded, targetW, targetH);
  final layout = passportSheetLayout(targetW, targetH, copies);
  final sheet = img.Image(width: layout.width, height: layout.height);
  img.fill(sheet, color: img.ColorRgba8(255, 255, 255, 255));
  for (final (x, y) in layout.slots) {
    img.compositeImage(sheet, single, dstX: x, dstY: y);
  }
  return (
    single: Uint8List.fromList(img.encodePng(single)),
    sheet: Uint8List.fromList(img.encodeJpg(sheet, quality: 98)),
    placed: layout.slots.length,
  );
}

Future<(int, int)?> readImageSizeInBackground(Uint8List bytes) => Isolate.run(() => readImageSize(bytes));
Future<Uint8List?> compressImageInBackground(Uint8List bytes, int quality) => Isolate.run(() => compressImage(bytes, quality));
Future<Uint8List?> resizeImageInBackground(Uint8List bytes, int width, int height) =>
    Isolate.run(() => resizeImage(bytes, width, height));
Future<Uint8List?> convertImageInBackground(Uint8List bytes, String format) => Isolate.run(() => convertImage(bytes, format));
Future<Uint8List?> transformImageInBackground(Uint8List bytes, int angle, bool flipH, bool flipV) =>
    Isolate.run(() => transformImage(bytes, angle, flipH, flipV));
Future<Uint8List?> combineImagesInBackground(List<Uint8List> inputs, String layout, int spacing) =>
    Isolate.run(() => combineImages(inputs, layout, spacing));
Future<(Uint8List, String)?> stripImageMetadataInBackground(Uint8List bytes) => Isolate.run(() => stripImageMetadata(bytes));
Future<Uint8List?> watermarkImageInBackground(Uint8List bytes, String text, String position, double opacity) =>
    Isolate.run(() => watermarkImage(bytes, text, position, opacity));
Future<({Uint8List single, Uint8List sheet, int placed})?> makePassportPhotosInBackground(
        Uint8List bytes, int targetW, int targetH, int copies) =>
    Isolate.run(() => makePassportPhotos(bytes, targetW, targetH, copies));
