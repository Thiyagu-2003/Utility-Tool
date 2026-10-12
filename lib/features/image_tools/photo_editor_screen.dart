import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/share_utils.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';
import 'photo_editor_service.dart';

enum PhotoEditorTab {
  removeBg('Remove BG', Icons.layers_clear_rounded),
  changeBg('Change BG Color', Icons.format_color_fill_rounded),
  adjust('Adjustments', Icons.tune_rounded),
  filters('Filters & Effects', Icons.auto_fix_high_rounded),
  blurPrivacy('Blur & Censor', Icons.blur_on_rounded),
  annotate('Draw & Annotate', Icons.draw_rounded),
  textLogo('Text & Logo', Icons.branding_watermark_rounded);

  final String label;
  final IconData icon;
  const PhotoEditorTab(this.label, this.icon);
}

class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  PhotoEditorTab _activeTab = PhotoEditorTab.removeBg;
  bool _isProcessing = false;

  // Global Loaded Image State
  Uint8List? _sourceImageBytes; // the picked file as-is (only its size is shown)
  Uint8List? _previewBytes; // <=1280 px PNG of the working image, for on-screen display
  bool _isLoading = false;
  String? _scaledNote; // set when the photo was scaled down to the working size
  img.Image? _decodedSourceImage;
  String _sourceFileName = 'image.png';

  // 1. Remove Background State
  Uint8List? _cutoutBytes;
  img.Image? _cutoutImage;
  double _bgTolerance = 25.0; // 5 to 70
  bool _floodFillFromEdges = true;
  Color _sampledColor = Colors.white;
  Color _cornerColor = Colors.white;

  // 2. Change BG State
  Color _selectedBgColor = Colors.white;
  bool _useGradient = false;
  late List<Color> _selectedGradient = _presetGradients.first;
  Uint8List? _composedBgBytes;

  // 3. Adjustments State
  double _brightness = 0.0; // -1.0 to 1.0
  double _contrast = 0.0; // -1.0 to 1.0
  double _saturation = 0.0; // -1.0 to 1.0
  double _sharpness = 0.0; // 0.0 to 1.0
  double _exposure = 0.0; // -1.0 to 1.0
  double _vignette = 0.0; // 0.0 to 1.0
  Uint8List? _adjustedBytes;

  // 4. Filters State
  String _activeFilter = 'Original';
  Uint8List? _filteredBytes;

  // 5. Blur & Privacy State
  final List<BlurArea> _blurAreas = [
    const BlurArea(x: 0.3, y: 0.25, width: 0.4, height: 0.3, intensity: 15, isMosaic: false),
  ];
  int _activeBlurIndex = 0;
  Uint8List? _blurredBytes;

  // 6. Draw & Annotate State
  final List<AnnotationStroke> _strokes = [];
  final List<AnnotationStroke> _undoneStrokes = [];
  String _currentTool = 'pen'; // 'pen', 'highlighter', 'arrow', 'rect', 'circle', 'line'
  Color _strokeColor = const Color(0xFFEF4444);
  double _strokeWidth = 5.0;
  List<Offset> _currentPoints = [];

  // 7. Text & Logo Overlay State
  final TextEditingController _textOverlayController = TextEditingController(text: 'Sample Watermark');
  double _textFontSize = 28.0;
  bool _hasTextBackground = true;

  Uint8List? _logoImageBytes;
  img.Image? _decodedLogoImage;
  double _logoScale = 0.25;
  double _logoOpacity = 1.0;
  int _logoAnchor = 8; // 3x3 grid, row * 3 + column: 0 top-left ... 8 bottom-right
  Uint8List? _finalWatermarkedBytes;

  final List<Color> _presetColors = [
    Colors.white,
    const Color(0xFF0F172A), // Slate Dark
    const Color(0xFFEF4444), // Red
    const Color(0xFF10B981), // Emerald
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFFEC4899), // Pink
    const Color(0xFF06B6D4), // Cyan
    Colors.transparent,
  ];

  final List<List<Color>> _presetGradients = [
    [const Color(0xFFFF512F), const Color(0xFFDD2476)], // Sunset Glow
    [const Color(0xFF00B4DB), const Color(0xFF0083B0)], // Ocean Blue
    [const Color(0xFF8A2387), const Color(0xFFE94057)], // Neon Dusk
    [const Color(0xFF11998E), const Color(0xFF38EF7D)], // Mint Fresh
    [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)], // Dark Metal
    [const Color(0xFFFF8008), const Color(0xFFFFC837)], // Golden Sun
  ];

  final List<String> _filterPresets = [
    'Original',
    'Vintage',
    'Sepia',
    'B&W',
    'Film Noir',
    'Warm Sun',
    'Cool Ice',
    'Cyberpunk',
    'Emerald',
    'HDR Pop',
    'Pixelate',
    'Invert',
  ];

  Future<void> _pickImage() async {
    if (_isLoading) return;
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final file = files.first;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _isLoading = true);
      // Decoding a 12 MP photo takes seconds: do it off the UI thread.
      final loaded = await PhotoEditorService.loadForEditingInBackground(bytes);
      if (!mounted) return;
      if (loaded == null) {
        _showToast('Unsupported or corrupt image file.', isError: true);
        return;
      }
      final decoded = loaded.image;
      final p = decoded.getPixel(0, 0);
      setState(() {
        _resetEdits();
        _sourceImageBytes = bytes;
        _previewBytes = loaded.preview;
        _decodedSourceImage = decoded;
        _sourceFileName = file.name;
        _scaledNote = loaded.originalWidth > decoded.width || loaded.originalHeight > decoded.height
            ? 'Scaled down from ${loaded.originalWidth} × ${loaded.originalHeight} px so the editor stays fast'
            : null;
        // Sample corner pixel for background removal hint
        _cornerColor = Color.fromARGB(255, p.r.toInt(), p.g.toInt(), p.b.toInt());
        _sampledColor = _cornerColor;
      });
    } catch (e) {
      _showToast('Error picking image: $e', isError: true);
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  /// Clears every edit result and control for a fresh photo (the logo and overlay text are kept).
  void _resetEdits() {
    _cutoutBytes = null;
    _cutoutImage = null;
    _bgTolerance = 25.0;
    _floodFillFromEdges = true;
    _composedBgBytes = null;
    _useGradient = false;
    _selectedBgColor = Colors.white;
    _selectedGradient = _presetGradients.first;
    _brightness = _contrast = _saturation = _sharpness = _exposure = _vignette = 0.0;
    _adjustedBytes = null;
    _activeFilter = 'Original';
    _filteredBytes = null;
    _blurAreas
      ..clear()
      ..add(const BlurArea(x: 0.3, y: 0.25, width: 0.4, height: 0.3, intensity: 15, isMosaic: false));
    _activeBlurIndex = 0;
    _blurredBytes = null;
    _strokes.clear();
    _undoneStrokes.clear();
    _currentPoints = [];
    _finalWatermarkedBytes = null;
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isCurrent(img.Image src) => mounted && identical(src, _decodedSourceImage);

  /// Runs [work] on the loaded photo with the busy flag set. [work] should do its pixel
  /// maths in a background isolate and apply results only while [_isCurrent] still holds
  /// (the user may have changed or reset the photo in the meantime).
  Future<void> _runEdit(String failure, Future<void> Function(img.Image src) work, {String? success}) async {
    final src = _decodedSourceImage;
    if (src == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();
    try {
      await work(src);
      if (success != null && _isCurrent(src)) _showToast(success);
    } catch (e) {
      _showToast('$failure: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// 0..1 colour channel to 0..255.
  int _channel(double v) => (v * 255).round().clamp(0, 255);

  // --- 1. REMOVE BACKGROUND ---
  Future<void> _executeRemoveBackground() => _runEdit('Background removal failed', (src) async {
        final (cutout, bytes) = await PhotoEditorService.removeBackgroundInBackground(
          src,
          sampleR: _channel(_sampledColor.r),
          sampleG: _channel(_sampledColor.g),
          sampleB: _channel(_sampledColor.b),
          tolerance: _bgTolerance,
          floodFillFromEdges: _floodFillFromEdges,
        );
        if (!_isCurrent(src)) return;
        setState(() {
          _cutoutImage = cutout;
          _cutoutBytes = bytes;
        });
      }, success: 'Background removed successfully!');

  // --- 2. CHANGE BG COLOR ---
  Future<void> _executeChangeBackground() {
    final baseImage = _cutoutImage ?? _decodedSourceImage;
    if (baseImage == null) return Future.value();
    if (_cutoutImage == null && !baseImage.hasAlpha) {
      _showToast('Remove the background first - the photo has no transparent area to fill.', isError: true);
      return Future.value();
    }
    return _runEdit('Failed to apply background', (src) async {
      final bytes = await PhotoEditorService.replaceBackgroundInBackground(
        baseImage,
        solidColor: _useGradient ? null : _selectedBgColor,
        gradientColors: _useGradient ? _selectedGradient : null,
      );
      if (!_isCurrent(src)) return;
      setState(() => _composedBgBytes = bytes);
    }, success: 'Background updated!');
  }

  // --- 3. ADJUSTMENTS ---
  Future<void> _executeAdjustments() => _runEdit('Failed to adjust image', (src) async {
        final bytes = await PhotoEditorService.adjustImageInBackground(
          src,
          brightness: _brightness,
          contrast: _contrast,
          saturation: _saturation,
          sharpness: _sharpness,
          gamma: _exposure,
          vignette: _vignette,
        );
        if (!_isCurrent(src)) return;
        setState(() => _adjustedBytes = bytes);
      }, success: 'Adjustments applied!');

  // --- 4. FILTERS ---
  Future<void> _executeFilter(String filterName) {
    if (_isProcessing) return Future.value(); // one render at a time, so the chip always matches the preview
    setState(() => _activeFilter = filterName);
    return _runEdit('Filter error', (src) async {
      final bytes = await PhotoEditorService.applyFilterInBackground(src, filterName);
      if (!_isCurrent(src)) return;
      setState(() => _filteredBytes = bytes);
    });
  }

  // --- 5. BLUR & CENSOR ---
  Future<void> _executeBlur() => _runEdit('Blur failed', (src) async {
        final bytes = await PhotoEditorService.applyBlurAreasInBackground(src, List.of(_blurAreas));
        if (!_isCurrent(src)) return;
        setState(() => _blurredBytes = bytes);
      }, success: 'Selected areas blurred!');

  // --- 7. TEXT & LOGO ---
  Future<void> _pickLogoImage() async {
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final bytes = await files.first.readAsBytes();
      if (!mounted) return;
      // Decoded off the UI thread; a logo never needs more than ~1000 px.
      final loaded = await PhotoEditorService.loadForEditingInBackground(bytes);
      if (!mounted) return;
      if (loaded == null) {
        _showToast('Unsupported or corrupt logo image.', isError: true);
        return;
      }
      setState(() {
        _logoImageBytes = loaded.preview;
        _decodedLogoImage = loaded.image;
      });
    } catch (e) {
      _showToast('Failed to pick logo: $e', isError: true);
    }
  }

  Future<void> _executeWatermarkComposite() {
    if (_decodedLogoImage == null && _textOverlayController.text.trim().isEmpty) {
      _showToast('Add overlay text or pick a logo first.', isError: true);
      return Future.value();
    }
    return _runEdit('Composite error', (src) async {
      final bytes = await PhotoEditorService.applyWatermarkInBackground(
        src,
        logo: _decodedLogoImage,
        logoScale: _logoScale,
        logoOpacity: _logoOpacity,
        logoAnchor: _logoAnchor,
        text: _textOverlayController.text,
        textSize: _textFontSize,
        textBackground: _hasTextBackground,
      );
      if (!_isCurrent(src)) return;
      setState(() => _finalWatermarkedBytes = bytes);
    }, success: 'Text and Logo applied successfully!');
  }

  /// All editor outputs are PNG, whatever the source extension was.
  String _pngName(String prefix) {
    final dot = _sourceFileName.lastIndexOf('.');
    return '${prefix}_${dot > 0 ? _sourceFileName.substring(0, dot) : _sourceFileName}.png';
  }

  Future<void> _shareImage(Uint8List bytes, String filename) async {
    PreferencesService().triggerHaptic();
    try {
      await shareFileBytes(bytes, filename);
    } catch (e) {
      _showToast('Share failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Photo Studio & Editor',
      category: ToolCategory.imagePhoto,
      toolId: 'photo_editor_studio',
      onReset: () {
        setState(() {
          _resetEdits();
          _sourceImageBytes = null;
          _previewBytes = null;
          _decodedSourceImage = null;
          _scaledNote = null;
          _isProcessing = false;
          _isLoading = false;
          _logoImageBytes = null;
          _decodedLogoImage = null;
          _logoScale = 0.25;
          _logoOpacity = 1.0;
          _logoAnchor = 8;
          _textOverlayController.text = 'Sample Watermark';
          _textFontSize = 28.0;
          _hasTextBackground = true;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeatureTabSelector<PhotoEditorTab>(
            accentColor: AppColors.catImage,
            activeTab: _activeTab,
            onTabSelected: (tab) {
              PreferencesService().triggerHaptic();
              setState(() => _activeTab = tab);
            },
            tabs: PhotoEditorTab.values.map((t) => FeatureTabItem(value: t, label: t.label, icon: t.icon)).toList(),
          ),
          const SizedBox(height: 16),
          if (_isLoading) ...[
            const LinearProgressIndicator(color: AppColors.catImage),
            const SizedBox(height: 16),
          ],
          if (_sourceImageBytes == null)
            _buildEmptyUploadCard(isDark)
          else ...[
            _buildImageHeaderBar(isDark),
            const SizedBox(height: 16),
            _buildActiveTabContent(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyUploadCard(bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.catImage.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_photo_alternate_rounded, size: 48, color: AppColors.catImage),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select a Photo to Edit',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Remove backgrounds, tune colors, apply cinematic filters, censor faces, annotate, and add watermarks with 100% offline privacy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Choose Image from Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catImage,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _pickImage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageHeaderBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(_previewBytes!, width: 44, height: 44, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sourceFileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${_decodedSourceImage?.width ?? 0} × ${_decodedSourceImage?.height ?? 0} px  •  ${((_sourceImageBytes?.length ?? 0) / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                if (_scaledNote != null)
                  Text(_scaledNote!, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              ],
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Change'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.catImage,
              side: const BorderSide(color: AppColors.catImage),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _pickImage,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(bool isDark) {
    switch (_activeTab) {
      case PhotoEditorTab.removeBg:
        return _buildRemoveBgTab(isDark);
      case PhotoEditorTab.changeBg:
        return _buildChangeBgTab(isDark);
      case PhotoEditorTab.adjust:
        return _buildAdjustTab(isDark);
      case PhotoEditorTab.filters:
        return _buildFiltersTab(isDark);
      case PhotoEditorTab.blurPrivacy:
        return _buildBlurPrivacyTab(isDark);
      case PhotoEditorTab.annotate:
        return _buildAnnotateTab(isDark);
      case PhotoEditorTab.textLogo:
        return _buildTextLogoTab(isDark);
    }
  }

  // ================= 1. REMOVE BACKGROUND =================
  Widget _buildRemoveBgTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Smart Background Remover',
          primaryResult: _cutoutBytes != null ? 'Cutout Ready' : 'Ready to Process',
          subtitle: 'Pure offline chroma & edge flood-fill algorithm',
          accentColor: AppColors.catImage,
          breakdowns: [
            BreakdownItem(label: 'Tolerance', value: '${_bgTolerance.round()}%'),
            BreakdownItem(label: 'Mode', value: _floodFillFromEdges ? 'Edge Flood-Fill' : 'Color Key'),
            BreakdownItem(label: 'Sample RGB', value: '(${_channel(_sampledColor.r)}, ${_channel(_sampledColor.g)}, ${_channel(_sampledColor.b)})'),
          ],
        ),
        const SizedBox(height: 16),
        Text('Color Tolerance: ${_bgTolerance.round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(
          value: _bgTolerance,
          min: 5.0,
          max: 80.0,
          activeColor: AppColors.catImage,
          onChanged: (val) => setState(() => _bgTolerance = val),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Flood-Fill from Borders Only', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Prevents erasing matching colors inside the subject body'),
          value: _floodFillFromEdges,
          activeThumbColor: AppColors.catImage,
          onChanged: (val) => setState(() => _floodFillFromEdges = val),
        ),
        const SizedBox(height: 12),
        const Text('Sample Background Color Reference:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildSampleChip('Top-Left Corner', _cornerColor),
            _buildSampleChip('Pure White', Colors.white),
            _buildSampleChip('Pure Black', Colors.black),
            _buildSampleChip('Studio Green', const Color(0xFF00FF00)),
            _buildSampleChip('Studio Blue', const Color(0xFF0000FF)),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.layers_clear_rounded),
          label: Text(_isProcessing ? 'Removing Background...' : 'Remove Background'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catImage,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isProcessing ? null : _executeRemoveBackground,
        ),
        if (_cutoutBytes != null) ...[
          const SizedBox(height: 24),
          const Text('Transparent Cutout Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              // Checkerboard pattern representation
              color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(_cutoutBytes!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share Cutout (PNG)'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.catImage, foregroundColor: Colors.white),
                  onPressed: () => _shareImage(_cutoutBytes!, _pngName('Cutout')),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.palette_rounded),
                label: const Text('Add New BG'),
                onPressed: () => setState(() => _activeTab = PhotoEditorTab.changeBg),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSampleChip(String label, Color color) {
    final isSelected = _sampledColor == color;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      avatar: CircleAvatar(backgroundColor: color, radius: 8),
      selectedColor: AppColors.catImage.withValues(alpha: 0.2),
      onSelected: (_) => setState(() => _sampledColor = color),
    );
  }

  // ================= 2. CHANGE BG COLOR =================
  Widget _buildChangeBgTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Background Color Studio',
          primaryResult: _useGradient ? 'Vibrant Gradient' : 'Solid Color',
          subtitle: 'Replaces transparent background or creates portrait studio photo',
          accentColor: AppColors.catImage,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Solid Color')),
                selected: !_useGradient,
                selectedColor: AppColors.catImage.withValues(alpha: 0.25),
                onSelected: (val) => setState(() => _useGradient = false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Gradient Studio')),
                selected: _useGradient,
                selectedColor: AppColors.catImage.withValues(alpha: 0.25),
                onSelected: (val) => setState(() => _useGradient = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!_useGradient) ...[
          const Text('Pick Solid Background:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presetColors.map((color) {
              final isSelected = _selectedBgColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedBgColor = color),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.catImage : (isDark ? Colors.white30 : Colors.black26),
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.blue) : null,
                ),
              );
            }).toList(),
          ),
        ] else ...[
          const Text('Pick Studio Gradient:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presetGradients.map((grad) {
              final isSelected = _selectedGradient == grad;
              return GestureDetector(
                onTap: () => setState(() => _selectedGradient = grad),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: grad),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.format_color_fill_rounded),
          label: Text(_isProcessing ? 'Compositing...' : 'Apply Background'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catImage,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isProcessing ? null : _executeChangeBackground,
        ),
        if (_composedBgBytes != null) ...[
          const SizedBox(height: 24),
          const Text('Composited Output:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(_composedBgBytes!, height: 240, width: double.infinity, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Composited Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catImage,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
            ),
            onPressed: () => _shareImage(_composedBgBytes!, _pngName('Studio_Background')),
          ),
        ],
      ],
    );
  }

  // ================= 3. ADJUSTMENTS =================
  Widget _buildAdjustTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Color & Clarity Adjuster',
          primaryResult: 'Fine Tuning',
          subtitle: 'Real-time brightness, contrast, saturation, sharpness & vignette',
          accentColor: AppColors.catImage,
        ),
        const SizedBox(height: 16),
        _buildSliderTile('Brightness', _brightness, -1.0, 1.0, (v) => setState(() => _brightness = v)),
        _buildSliderTile('Contrast', _contrast, -1.0, 1.0, (v) => setState(() => _contrast = v)),
        _buildSliderTile('Saturation', _saturation, -1.0, 1.0, (v) => setState(() => _saturation = v)),
        _buildSliderTile('Sharpness', _sharpness, 0.0, 1.0, (v) => setState(() => _sharpness = v)),
        _buildSliderTile('Exposure / Gamma', _exposure, -1.0, 1.0, (v) => setState(() => _exposure = v)),
        _buildSliderTile('Vignette Lens', _vignette, 0.0, 1.0, (v) => setState(() => _vignette = v)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset Sliders'),
                onPressed: () {
                  setState(() {
                    _brightness = 0.0;
                    _contrast = 0.0;
                    _saturation = 0.0;
                    _sharpness = 0.0;
                    _exposure = 0.0;
                    _vignette = 0.0;
                    _adjustedBytes = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: _isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: const Text('Apply Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catImage,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isProcessing ? null : _executeAdjustments,
              ),
            ),
          ],
        ),
        if (_adjustedBytes != null) ...[
          const SizedBox(height: 24),
          const Text('Adjusted Image Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(_adjustedBytes!, height: 240, width: double.infinity, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Adjusted Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catImage,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
            ),
            onPressed: () => _shareImage(_adjustedBytes!, _pngName('Adjusted')),
          ),
        ],
      ],
    );
  }

  Widget _buildSliderTile(String title, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${(value * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.catImage)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: AppColors.catImage,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ================= 4. FILTERS & EFFECTS =================
  Widget _buildFiltersTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Photo Filters & Cinematic Effects',
          primaryResult: _activeFilter,
          subtitle: 'One-tap artistic colour grading presets',
          accentColor: AppColors.catImage,
        ),
        const SizedBox(height: 16),
        const Text('Select Filter Preset:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _filterPresets.map((f) {
            final isSelected = _activeFilter == f;
            return ChoiceChip(
              label: Text(f),
              selected: isSelected,
              selectedColor: AppColors.catImage.withValues(alpha: 0.25),
              onSelected: (_) => _executeFilter(f),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        if (_filteredBytes != null) ...[
          const Text('Filter Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(_filteredBytes!, height: 260, width: double.infinity, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: Text('Share $_activeFilter Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catImage,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
            ),
            onPressed: () => _shareImage(_filteredBytes!, _pngName('Filter_$_activeFilter')),
          ),
        ],
      ],
    );
  }

  // ================= 5. BLUR & PRIVACY =================
  Widget _buildBlurPrivacyTab(bool isDark) {
    final activeArea = _blurAreas.isNotEmpty && _activeBlurIndex < _blurAreas.length
        ? _blurAreas[_activeBlurIndex]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Face & Sensitive Region Censor',
          primaryResult: '${_blurAreas.length} Censor Area(s)',
          subtitle: 'Obscure faces, license plates, ID numbers and sensitive data',
          accentColor: AppColors.catImage,
        ),
        const SizedBox(height: 16),
        // Where each box sits on the photo; the selected one is outlined in the accent colour.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: AspectRatio(
              aspectRatio: _decodedSourceImage!.width / _decodedSourceImage!.height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_previewBytes!, fit: BoxFit.fill),
                    CustomPaint(painter: _BlurBoxPainter(List.of(_blurAreas), _activeBlurIndex)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_blurAreas.length > 1) ...[
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < _blurAreas.length; i++)
                ChoiceChip(
                  label: Text('Box ${i + 1}'),
                  selected: i == _activeBlurIndex,
                  selectedColor: AppColors.catImage.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _activeBlurIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (activeArea != null) ...[
          Text('Blur Mode & Type for Box #${_activeBlurIndex + 1}:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Gaussian Blur')),
                  selected: !activeArea.isMosaic,
                  selectedColor: AppColors.catImage.withValues(alpha: 0.25),
                  onSelected: (val) {
                    setState(() {
                      _blurAreas[_activeBlurIndex] = activeArea.copyWith(isMosaic: false);
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Mosaic Pixelate')),
                  selected: activeArea.isMosaic,
                  selectedColor: AppColors.catImage.withValues(alpha: 0.25),
                  onSelected: (val) {
                    setState(() {
                      _blurAreas[_activeBlurIndex] = activeArea.copyWith(isMosaic: true);
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Censor Intensity: ${activeArea.intensity}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: activeArea.intensity.toDouble(),
            min: 5.0,
            max: 50.0,
            activeColor: AppColors.catImage,
            onChanged: (val) {
              setState(() {
                _blurAreas[_activeBlurIndex] = activeArea.copyWith(intensity: val.round());
              });
            },
          ),
          _buildSliderTile('Box X Position', activeArea.x, 0.0, 0.9, (v) {
            setState(() => _blurAreas[_activeBlurIndex] = activeArea.copyWith(x: v));
          }),
          _buildSliderTile('Box Y Position', activeArea.y, 0.0, 0.9, (v) {
            setState(() => _blurAreas[_activeBlurIndex] = activeArea.copyWith(y: v));
          }),
          _buildSliderTile('Box Width', activeArea.width, 0.1, 0.9, (v) {
            setState(() => _blurAreas[_activeBlurIndex] = activeArea.copyWith(width: v));
          }),
          _buildSliderTile('Box Height', activeArea.height, 0.1, 0.9, (v) {
            setState(() => _blurAreas[_activeBlurIndex] = activeArea.copyWith(height: v));
          }),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add_box_rounded),
              label: const Text('Add Censor Box'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover, foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  _blurAreas.add(
                    const BlurArea(x: 0.2, y: 0.2, width: 0.35, height: 0.35, intensity: 15, isMosaic: false),
                  );
                  _activeBlurIndex = _blurAreas.length - 1;
                });
              },
            ),
            if (_blurAreas.length > 1)
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                label: const Text('Remove Box', style: TextStyle(color: AppColors.error)),
                onPressed: () {
                  setState(() {
                    _blurAreas.removeAt(_activeBlurIndex);
                    _activeBlurIndex = max(0, _blurAreas.length - 1);
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.blur_on_rounded),
          label: Text(_isProcessing ? 'Applying Blur...' : 'Render Blur on Image'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catImage,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isProcessing ? null : _executeBlur,
        ),
        if (_blurredBytes != null) ...[
          const SizedBox(height: 24),
          const Text('Censored Output:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(_blurredBytes!, height: 260, width: double.infinity, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Censored Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catImage,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
            ),
            onPressed: () => _shareImage(_blurredBytes!, _pngName('Censored')),
          ),
        ],
      ],
    );
  }

  // ================= 6. DRAW & ANNOTATE =================
  Widget _buildAnnotateTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Drawing & Annotation Studio',
          primaryResult: '${_strokes.length} Annotations',
          subtitle: 'Pen, highlighter, shapes, arrows, colors & stroke widths',
          accentColor: AppColors.catImage,
        ),
        const SizedBox(height: 14),
        // Toolbar
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildToolIcon(Icons.edit_rounded, 'pen', 'Pen'),
            _buildToolIcon(Icons.brush_rounded, 'highlighter', 'Highlighter'),
            _buildToolIcon(Icons.arrow_right_alt_rounded, 'arrow', 'Arrow'),
            _buildToolIcon(Icons.crop_square_rounded, 'rect', 'Rectangle'),
            _buildToolIcon(Icons.circle_outlined, 'circle', 'Circle'),
            _buildToolIcon(Icons.horizontal_rule_rounded, 'line', 'Line'),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._presetColors.take(6).map((c) {
              return GestureDetector(
                onTap: () => setState(() => _strokeColor = c),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: _strokeColor == c ? AppColors.catImage : Colors.grey, width: 2),
                  ),
                ),
              );
            }),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Undo',
              onPressed: _strokes.isNotEmpty
                  ? () => setState(() => _undoneStrokes.add(_strokes.removeLast()))
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo_rounded),
              tooltip: 'Redo',
              onPressed: _undoneStrokes.isNotEmpty
                  ? () => setState(() => _strokes.add(_undoneStrokes.removeLast()))
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear',
              onPressed: _strokes.isNotEmpty
                  ? () => setState(() {
                        _strokes.clear();
                        _undoneStrokes.clear();
                      })
                  : null,
            ),
          ],
        ),
        Row(
          children: [
            const Text('Width: ', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Slider(
                value: _strokeWidth,
                min: 2.0,
                max: 30.0,
                activeColor: AppColors.catImage,
                onChanged: (val) => setState(() => _strokeWidth = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // The canvas has exactly the photo's aspect ratio, so a point on it maps straight to
        // a point on the full-resolution image (strokes are stored as 0..1 fractions).
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: AspectRatio(
              aspectRatio: _decodedSourceImage!.width / _decodedSourceImage!.height,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvas = constraints.biggest;
                  final color = _currentTool == 'highlighter' ? _strokeColor.withValues(alpha: 0.4) : _strokeColor;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(_previewBytes!, fit: BoxFit.fill),
                        GestureDetector(
                          onPanStart: (details) {
                            setState(() => _currentPoints = [PhotoEditorService.normalizePoint(details.localPosition, canvas)]);
                          },
                          onPanUpdate: (details) {
                            final p = PhotoEditorService.normalizePoint(details.localPosition, canvas);
                            setState(() {
                              // Shapes need only their two corners; freehand tools keep the whole path.
                              if (_currentTool == 'pen' || _currentTool == 'highlighter') {
                                _currentPoints.add(p);
                              } else if (_currentPoints.isNotEmpty) {
                                _currentPoints = [_currentPoints.first, p];
                              }
                            });
                          },
                          onPanEnd: (details) {
                            setState(() {
                              if (_currentPoints.isNotEmpty) {
                                _strokes.add(AnnotationStroke(
                                  points: List.of(_currentPoints),
                                  color: color,
                                  strokeWidth: _strokeWidth,
                                  tool: _currentTool,
                                ));
                                _currentPoints = [];
                                _undoneStrokes.clear();
                              }
                            });
                          },
                          child: CustomPaint(
                            painter: _AnnotationPainter(
                              strokes: _strokes,
                              currentPoints: _currentPoints,
                              currentTool: _currentTool,
                              currentColor: color,
                              currentWidth: _strokeWidth,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.share_rounded),
          label: Text('Export & Share Annotated Photo (${_decodedSourceImage!.width} × ${_decodedSourceImage!.height})'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catImage,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isProcessing ? null : _exportAnnotated,
        ),
      ],
    );
  }

  /// Draws the strokes onto the full-resolution photo (not the on-screen preview) and shares it.
  Future<void> _exportAnnotated() => _runEdit('Export error', (src) async {
        final w = src.width;
        final h = src.height;
        final rgba = src.convert(format: img.Format.uint8, numChannels: 4, noAnimation: true).toUint8List();
        final base = Completer<ui.Image>();
        ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, base.complete);
        final photo = await base.future;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImage(photo, Offset.zero, Paint());
        _AnnotationPainter(
          strokes: _strokes,
          currentPoints: const [],
          currentTool: _currentTool,
          currentColor: _strokeColor,
          currentWidth: _strokeWidth,
        ).paint(canvas, Size(w.toDouble(), h.toDouble()));
        final picture = recorder.endRecording();
        final rendered = await picture.toImage(w, h);
        final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
        photo.dispose();
        picture.dispose();
        rendered.dispose();
        if (data == null) throw Exception('could not encode the annotated image');
        await _shareImage(data.buffer.asUint8List(), _pngName('Annotated'));
      });

  Widget _buildToolIcon(IconData icon, String toolName, String label) {
    final isSelected = _currentTool == toolName;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : null),
      label: Text(label, style: isSelected ? const TextStyle(color: Colors.white) : null),
      selected: isSelected,
      selectedColor: AppColors.catImage,
      onSelected: (_) => setState(() => _currentTool = toolName),
    );
  }

  // ================= 7. TEXT & LOGO =================
  Widget _buildTextLogoTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Text & Custom Logo Watermarker',
          primaryResult: 'Branding Ready',
          subtitle: 'Overlay high-res typography and PNG watermark logos',
          accentColor: AppColors.catImage,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _textOverlayController,
          decoration: InputDecoration(
            labelText: 'Overlay Text',
            prefixIcon: const Icon(Icons.title_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Background Pill', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          value: _hasTextBackground,
          activeThumbColor: AppColors.catImage,
          onChanged: (v) => setState(() => _hasTextBackground = v),
        ),
        Row(
          children: [
            const Text('Font Size: ', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Slider(
                value: _textFontSize,
                min: 14.0,
                max: 60.0,
                label: _textFontSize.round().toString(),
                activeColor: AppColors.catImage,
                onChanged: (v) => setState(() => _textFontSize = v),
              ),
            ),
          ],
        ),
        const Text('Text sits at the bottom-left; its size scales with the photo.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 16),
        const Text('Custom Logo / Watermark Image:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(_logoImageBytes != null ? 'Change Logo' : 'Select Logo File'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover, foregroundColor: Colors.white),
              onPressed: _pickLogoImage,
            ),
            if (_logoImageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_logoImageBytes!, width: 44, height: 44, fit: BoxFit.contain),
              ),
            if (_logoImageBytes != null)
              TextButton(
                onPressed: () => setState(() {
                  _logoImageBytes = null;
                  _decodedLogoImage = null;
                }),
                child: const Text('Remove'),
              ),
          ],
        ),
        if (_logoImageBytes != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Logo Size: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Slider(
                  value: _logoScale,
                  min: 0.1,
                  max: 0.6,
                  label: '${(_logoScale * 100).round()}%',
                  activeColor: AppColors.catImage,
                  onChanged: (v) => setState(() => _logoScale = v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Logo Opacity: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Slider(
                  value: _logoOpacity,
                  min: 0.1,
                  max: 1.0,
                  label: '${(_logoOpacity * 100).round()}%',
                  activeColor: AppColors.catImage,
                  onChanged: (v) => setState(() => _logoOpacity = v),
                ),
              ),
            ],
          ),
          const Text('Logo Position:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildAnchorGrid(),
        ],
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.branding_watermark_rounded),
          label: Text(_isProcessing ? 'Compositing...' : 'Render Watermarked Photo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catImage,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isProcessing ? null : _executeWatermarkComposite,
        ),
        if (_finalWatermarkedBytes != null) ...[
          const SizedBox(height: 24),
          const Text('Watermarked Result:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(_finalWatermarkedBytes!, height: 260, width: double.infinity, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Watermarked Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catImage,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
            ),
            onPressed: () => _shareImage(_finalWatermarkedBytes!, _pngName('Branded')),
          ),
        ],
      ],
    );
  }

  /// 3x3 grid of position cells for the logo (cell index = row * 3 + column).
  Widget _buildAnchorGrid() {
    const names = [
      'Top left', 'Top center', 'Top right',
      'Middle left', 'Center', 'Middle right',
      'Bottom left', 'Bottom center', 'Bottom right',
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 3; row++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var col = 0; col < 3; col++)
                  _buildAnchorCell(row * 3 + col, names[row * 3 + col]),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAnchorCell(int index, String name) {
    final selected = _logoAnchor == index;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Logo position: $name',
      child: Tooltip(
        message: name,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _logoAnchor = index),
          child: Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: selected ? AppColors.catImage : AppColors.catImage.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.catImage.withValues(alpha: selected ? 1 : 0.35)),
            ),
            child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
          ),
        ),
      ),
    );
  }
}

/// Outlines the censor boxes (fractions of the photo) over its preview; the active one is bold.
class _BlurBoxPainter extends CustomPainter {
  final List<BlurArea> areas;
  final int activeIndex;

  _BlurBoxPainter(this.areas, this.activeIndex);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < areas.length; i++) {
      final a = areas[i];
      final rect = Rect.fromLTWH(a.x * size.width, a.y * size.height, a.width * size.width, a.height * size.height);
      canvas.drawRect(rect, Paint()..color = (i == activeIndex ? AppColors.catImage : Colors.white).withValues(alpha: 0.18));
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == activeIndex ? 3 : 1.5
          ..color = i == activeIndex ? AppColors.catImage : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BlurBoxPainter oldDelegate) => true;
}

/// Paints annotation strokes whose points are 0..1 fractions of [size]. Line widths and the
/// arrowhead are defined for a 360 px wide canvas and scale with it, so the same strokes
/// look identical on screen and when painted onto the full-resolution photo.
class _AnnotationPainter extends CustomPainter {
  final List<AnnotationStroke> strokes;
  final List<Offset> currentPoints;
  final String currentTool;
  final Color currentColor;
  final double currentWidth;

  _AnnotationPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentTool,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / PhotoEditorService.annotationReferenceWidth;
    for (final stroke in strokes) {
      _drawStroke(canvas, size, k, stroke.points, stroke.color, stroke.strokeWidth, stroke.tool);
    }
    if (currentPoints.isNotEmpty) {
      _drawStroke(canvas, size, k, currentPoints, currentColor, currentWidth, currentTool);
    }
  }

  void _drawStroke(Canvas canvas, Size size, double k, List<Offset> norm, Color color, double width, String tool) {
    if (norm.isEmpty) return;
    final pts = [for (final p in norm) Offset(p.dx * size.width, p.dy * size.height)];
    final paint = Paint()
      ..color = color
      ..strokeWidth = width * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (tool == 'rect' && pts.length >= 2) {
      canvas.drawRect(Rect.fromPoints(pts.first, pts.last), paint);
    } else if (tool == 'circle' && pts.length >= 2) {
      canvas.drawOval(Rect.fromPoints(pts.first, pts.last), paint);
    } else if (tool == 'arrow' && pts.length >= 2) {
      final p1 = pts.first;
      final p2 = pts.last;
      canvas.drawLine(p1, p2, paint);
      // Draw arrowhead
      final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      final arrowSize = 16.0 * k;
      final path = Path()
        ..moveTo(p2.dx, p2.dy)
        ..lineTo(p2.dx - arrowSize * cos(angle - pi / 6), p2.dy - arrowSize * sin(angle - pi / 6))
        ..moveTo(p2.dx, p2.dy)
        ..lineTo(p2.dx - arrowSize * cos(angle + pi / 6), p2.dy - arrowSize * sin(angle + pi / 6));
      canvas.drawPath(path, paint);
    } else if (tool == 'line' && pts.length >= 2) {
      canvas.drawLine(pts.first, pts.last, paint);
    } else if (pts.length == 1) {
      // A tap: draw a dot (a one-point path draws nothing).
      canvas.drawCircle(pts.first, width * k / 2, paint..style = PaintingStyle.fill);
    } else {
      // Pen or highlighter continuous curve
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
