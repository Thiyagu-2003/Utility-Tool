import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
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
  Uint8List? _sourceImageBytes;
  img.Image? _decodedSourceImage;
  String _sourceFileName = 'image.png';

  // 1. Remove Background State
  Uint8List? _cutoutBytes;
  img.Image? _cutoutImage;
  double _bgTolerance = 25.0; // 5 to 70
  bool _floodFillFromEdges = true;
  Color _sampledColor = Colors.white;

  // 2. Change BG State
  Color _selectedBgColor = Colors.white;
  bool _useGradient = false;
  List<Color> _selectedGradient = [const Color(0xFFFF512F), const Color(0xFFDD2476)];
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
  final GlobalKey _repaintBoundaryKey = GlobalKey();
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
  Alignment _logoAlignment = Alignment.bottomRight;
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
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          setState(() {
            _sourceImageBytes = bytes;
            _decodedSourceImage = decoded;
            _sourceFileName = file.name;
            // Sample corner pixel for background removal hint
            final p = decoded.getPixel(0, 0);
            _sampledColor = Color.fromARGB(255, p.r.toInt(), p.g.toInt(), p.b.toInt());

            // Reset states
            _cutoutBytes = null;
            _cutoutImage = null;
            _composedBgBytes = null;
            _adjustedBytes = null;
            _filteredBytes = null;
            _blurredBytes = null;
            _strokes.clear();
            _finalWatermarkedBytes = null;
          });
        }
      }
    } catch (e) {
      _showToast('Error picking image: $e', isError: true);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- 1. REMOVE BACKGROUND ---
  Future<void> _executeRemoveBackground() async {
    if (_decodedSourceImage == null) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final cutout = PhotoEditorService.removeBackground(
        _decodedSourceImage!,
        sampleR: _sampledColor.red,
        sampleG: _sampledColor.green,
        sampleB: _sampledColor.blue,
        tolerance: _bgTolerance,
        floodFillFromEdges: _floodFillFromEdges,
      );

      final bytes = Uint8List.fromList(img.encodePng(cutout));
      setState(() {
        _cutoutImage = cutout;
        _cutoutBytes = bytes;
      });
      _showToast('Background removed successfully!');
    } catch (e) {
      _showToast('Background removal failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- 2. CHANGE BG COLOR ---
  Future<void> _executeChangeBackground() async {
    final baseImage = _cutoutImage ?? _decodedSourceImage;
    if (baseImage == null) return;

    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final composed = PhotoEditorService.replaceBackground(
        baseImage,
        solidColor: _useGradient ? null : _selectedBgColor,
        gradientColors: _useGradient ? _selectedGradient : null,
      );
      final bytes = Uint8List.fromList(img.encodePng(composed));
      setState(() => _composedBgBytes = bytes);
      _showToast('Background updated!');
    } catch (e) {
      _showToast('Failed to apply background: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- 3. ADJUSTMENTS ---
  Future<void> _executeAdjustments() async {
    if (_decodedSourceImage == null) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final adjusted = PhotoEditorService.adjustImage(
        source: _decodedSourceImage!,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        sharpness: _sharpness,
        gamma: _exposure,
        vignette: _vignette,
      );
      final bytes = Uint8List.fromList(img.encodePng(adjusted));
      setState(() => _adjustedBytes = bytes);
      _showToast('Adjustments applied!');
    } catch (e) {
      _showToast('Failed to adjust image: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- 4. FILTERS ---
  Future<void> _executeFilter(String filterName) async {
    if (_decodedSourceImage == null) return;
    setState(() {
      _activeFilter = filterName;
      _isProcessing = true;
    });
    PreferencesService().triggerHaptic();

    try {
      final filtered = PhotoEditorService.applyFilter(_decodedSourceImage!, filterName);
      final bytes = Uint8List.fromList(img.encodePng(filtered));
      setState(() => _filteredBytes = bytes);
    } catch (e) {
      _showToast('Filter error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- 5. BLUR & CENSOR ---
  Future<void> _executeBlur() async {
    if (_decodedSourceImage == null) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      final blurred = PhotoEditorService.applyBlurAreas(_decodedSourceImage!, _blurAreas);
      final bytes = Uint8List.fromList(img.encodePng(blurred));
      setState(() => _blurredBytes = bytes);
      _showToast('Selected areas blurred!');
    } catch (e) {
      _showToast('Blur failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- 7. TEXT & LOGO ---
  Future<void> _pickLogoImage() async {
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isNotEmpty) {
        final bytes = await files.first.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          setState(() {
            _logoImageBytes = bytes;
            _decodedLogoImage = decoded;
          });
        }
      }
    } catch (e) {
      _showToast('Failed to pick logo: $e', isError: true);
    }
  }

  Future<void> _executeWatermarkComposite() async {
    if (_decodedSourceImage == null) return;
    setState(() => _isProcessing = true);
    PreferencesService().triggerHaptic();

    try {
      var base = img.Image.from(_decodedSourceImage!);

      // Composite logo if chosen
      if (_decodedLogoImage != null) {
        final targetW = (base.width * _logoScale).round().clamp(10, base.width);
        final scaledLogo = img.copyResize(_decodedLogoImage!, width: targetW);

        // Calculate position based on alignment
        int dstX = 20;
        int dstY = 20;
        if (_logoAlignment == Alignment.topRight) {
          dstX = base.width - scaledLogo.width - 20;
        } else if (_logoAlignment == Alignment.bottomRight) {
          dstX = base.width - scaledLogo.width - 20;
          dstY = base.height - scaledLogo.height - 20;
        } else if (_logoAlignment == Alignment.bottomLeft) {
          dstY = base.height - scaledLogo.height - 20;
        } else if (_logoAlignment == Alignment.center) {
          dstX = (base.width - scaledLogo.width) ~/ 2;
          dstY = (base.height - scaledLogo.height) ~/ 2;
        }

        img.compositeImage(base, scaledLogo, dstX: dstX, dstY: dstY);
      }

      if (_textOverlayController.text.trim().isNotEmpty) {
        final txt = _textOverlayController.text.trim();
        img.drawString(
          base,
          txt,
          font: img.arial24,
          x: 20,
          y: base.height - 35,
          color: img.ColorRgba8(255, 255, 255, 255),
        );
      }

      final bytes = Uint8List.fromList(img.encodePng(base));
      setState(() => _finalWatermarkedBytes = bytes);
      _showToast('Text and Logo applied successfully!');
    } catch (e) {
      _showToast('Composite error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareImage(Uint8List bytes, String filename) async {
    PreferencesService().triggerHaptic();
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Photo Studio & Editor',
      category: ToolCategory.filesText,
      toolId: 'photo_editor_studio',
      onReset: () {
        setState(() {
          _sourceImageBytes = null;
          _decodedSourceImage = null;
          _cutoutBytes = null;
          _composedBgBytes = null;
          _adjustedBytes = null;
          _filteredBytes = null;
          _blurredBytes = null;
          _strokes.clear();
          _finalWatermarkedBytes = null;
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
            child: Image.memory(_sourceImageBytes!, width: 44, height: 44, fit: BoxFit.cover),
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
            BreakdownItem(label: 'Sample RGB', value: '(${_sampledColor.red}, ${_sampledColor.green}, ${_sampledColor.blue})'),
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
            _buildSampleChip('Top-Left Corner', _sampledColor),
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
                  onPressed: () => _shareImage(_cutoutBytes!, 'Cutout_${_sourceFileName.replaceAll('.jpg', '.png')}'),
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
            onPressed: () => _shareImage(_composedBgBytes!, 'Studio_Background_$_sourceFileName'),
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
            onPressed: () => _shareImage(_adjustedBytes!, 'Adjusted_$_sourceFileName'),
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
            onPressed: () => _shareImage(_filteredBytes!, 'Filter_${_activeFilter}_$_sourceFileName'),
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
        Row(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add_box_rounded),
              label: const Text('Add Censor Box'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover),
              onPressed: () {
                setState(() {
                  _blurAreas.add(
                    const BlurArea(x: 0.2, y: 0.2, width: 0.35, height: 0.35, intensity: 15, isMosaic: false),
                  );
                  _activeBlurIndex = _blurAreas.length - 1;
                });
              },
            ),
            const SizedBox(width: 12),
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
            onPressed: () => _shareImage(_blurredBytes!, 'Censored_$_sourceFileName'),
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
        Row(
          children: [
            Text('Color: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            ..._presetColors.take(6).map((c) {
              return GestureDetector(
                onTap: () => setState(() => _strokeColor = c),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
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
            const Spacer(),
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
        const SizedBox(height: 8),
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
        // Interactive Drawing Canvas Overlay
        RepaintBoundary(
          key: _repaintBoundaryKey,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  _sourceImageBytes!,
                  height: 320,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _currentPoints = [details.localPosition];
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _currentPoints.add(details.localPosition);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      if (_currentPoints.isNotEmpty) {
                        _strokes.add(
                          AnnotationStroke(
                            points: List.from(_currentPoints),
                            color: _currentTool == 'highlighter'
                                ? _strokeColor.withValues(alpha: 0.4)
                                : _strokeColor,
                            strokeWidth: _strokeWidth,
                            tool: _currentTool,
                          ),
                        );
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
                      currentColor: _currentTool == 'highlighter'
                          ? _strokeColor.withValues(alpha: 0.4)
                          : _strokeColor,
                      currentWidth: _strokeWidth,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.share_rounded),
          label: const Text('Export & Share Annotated Photo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catImage,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () async {
            try {
              final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
              if (boundary != null) {
                final image = await boundary.toImage(pixelRatio: 2.0);
                final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                if (byteData != null) {
                  await _shareImage(byteData.buffer.asUint8List(), 'Annotated_$_sourceFileName');
                }
              }
            } catch (e) {
              _showToast('Export error: $e', isError: true);
            }
          },
        ),
      ],
    );
  }

  Widget _buildToolIcon(IconData icon, String toolName, String label) {
    final isSelected = _currentTool == toolName;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : null),
      label: Text(label),
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
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Background Pill', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _hasTextBackground,
                activeThumbColor: AppColors.catImage,
                onChanged: (v) => setState(() => _hasTextBackground = v),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Font Size: ', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Slider(
                value: _textFontSize,
                min: 14.0,
                max: 60.0,
                activeColor: AppColors.catImage,
                onChanged: (v) => setState(() => _textFontSize = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Custom Logo / Watermark Image:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(_logoImageBytes != null ? 'Change Logo' : 'Select Logo File'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkCardHover),
              onPressed: _pickLogoImage,
            ),
            const SizedBox(width: 12),
            if (_logoImageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_logoImageBytes!, width: 44, height: 44, fit: BoxFit.contain),
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
                  activeColor: AppColors.catImage,
                  onChanged: (v) => setState(() => _logoScale = v),
                ),
              ),
            ],
          ),
          const Text('Logo Alignment:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Bottom Right'),
                selected: _logoAlignment == Alignment.bottomRight,
                onSelected: (_) => setState(() => _logoAlignment = Alignment.bottomRight),
              ),
              ChoiceChip(
                label: const Text('Bottom Left'),
                selected: _logoAlignment == Alignment.bottomLeft,
                onSelected: (_) => setState(() => _logoAlignment = Alignment.bottomLeft),
              ),
              ChoiceChip(
                label: const Text('Top Right'),
                selected: _logoAlignment == Alignment.topRight,
                onSelected: (_) => setState(() => _logoAlignment = Alignment.topRight),
              ),
              ChoiceChip(
                label: const Text('Center'),
                selected: _logoAlignment == Alignment.center,
                onSelected: (_) => setState(() => _logoAlignment = Alignment.center),
              ),
            ],
          ),
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
            onPressed: () => _shareImage(_finalWatermarkedBytes!, 'Branded_$_sourceFileName'),
          ),
        ],
      ],
    );
  }
}

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
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.strokeWidth, stroke.tool);
    }
    if (currentPoints.isNotEmpty) {
      _drawStroke(canvas, currentPoints, currentColor, currentWidth, currentTool);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> pts, Color color, double width, String tool) {
    if (pts.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (tool == 'rect' && pts.length >= 2) {
      final rect = Rect.fromPoints(pts.first, pts.last);
      canvas.drawRect(rect, paint);
    } else if (tool == 'circle' && pts.length >= 2) {
      final rect = Rect.fromPoints(pts.first, pts.last);
      canvas.drawOval(rect, paint);
    } else if (tool == 'arrow' && pts.length >= 2) {
      final p1 = pts.first;
      final p2 = pts.last;
      canvas.drawLine(p1, p2, paint);
      // Draw arrowhead
      final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      const arrowSize = 16.0;
      final path = Path()
        ..moveTo(p2.dx, p2.dy)
        ..lineTo(p2.dx - arrowSize * cos(angle - pi / 6), p2.dy - arrowSize * sin(angle - pi / 6))
        ..moveTo(p2.dx, p2.dy)
        ..lineTo(p2.dx - arrowSize * cos(angle + pi / 6), p2.dy - arrowSize * sin(angle + pi / 6));
      canvas.drawPath(path, paint);
    } else if (tool == 'line' && pts.length >= 2) {
      canvas.drawLine(pts.first, pts.last, paint);
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
