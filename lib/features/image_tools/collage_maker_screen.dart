import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class CollageMakerScreen extends StatefulWidget {
  const CollageMakerScreen({super.key});

  @override
  State<CollageMakerScreen> createState() => _CollageMakerScreenState();
}

class _CollageMakerScreenState extends State<CollageMakerScreen> {
  final List<Uint8List> _rawImages = [];
  final List<img.Image> _decodedImages = [];

  int _cols = 2;
  int _rows = 2;
  double _spacing = 8.0;
  Color _bgColor = Colors.white;
  bool _isProcessing = false;
  Uint8List? _previewCollageBytes;

  Future<void> _pickImages() async {
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isNotEmpty) {
        setState(() => _isProcessing = true);
        for (final f in files) {
          final bytes = await f.readAsBytes();
          final decoded = img.decodeImage(bytes);
          if (decoded != null) {
            _rawImages.add(bytes);
            _decodedImages.add(decoded);
          }
        }
        _autoSelectLayout();
        _renderCollage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _autoSelectLayout() {
    final count = _decodedImages.length;
    if (count <= 2) {
      _cols = count == 1 ? 1 : 2;
      _rows = 1;
    } else if (count <= 4) {
      _cols = 2;
      _rows = 2;
    } else if (count <= 6) {
      _cols = 3;
      _rows = 2;
    } else {
      _cols = 3;
      _rows = 3;
    }
  }

  void _renderCollage() {
    if (_decodedImages.isEmpty) {
      setState(() => _previewCollageBytes = null);
      return;
    }

    const cellW = 400;
    const cellH = 400;
    final totalW = (_cols * cellW) + ((_cols + 1) * _spacing.toInt());
    final totalH = (_rows * cellH) + ((_rows + 1) * _spacing.toInt());

    final canvas = img.Image(width: totalW, height: totalH);
    // Fill background
    final bgR = (_bgColor.r * 255).round();
    final bgG = (_bgColor.g * 255).round();
    final bgB = (_bgColor.b * 255).round();
    img.fill(canvas, color: img.ColorRgb8(bgR, bgG, bgB));

    int imgIdx = 0;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        if (imgIdx >= _decodedImages.length) break;

        final src = _decodedImages[imgIdx];
        final resized = img.copyResizeCropSquare(src, size: cellW);

        final dstX = _spacing.toInt() + (c * (cellW + _spacing.toInt()));
        final dstY = _spacing.toInt() + (r * (cellH + _spacing.toInt()));

        img.compositeImage(canvas, resized, dstX: dstX, dstY: dstY);
        imgIdx++;
      }
    }

    final jpgBytes = Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
    setState(() => _previewCollageBytes = jpgBytes);
  }

  Future<void> _shareCollage() async {
    if (_previewCollageBytes == null) return;
    PreferencesService().triggerHaptic();
    await Printing.sharePdf(
      bytes: _previewCollageBytes!,
      filename: 'Collage_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Image Collage Maker',
      category: ToolCategory.filesText,
      toolId: 'image_collage_maker',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Collage Canvas',
            primaryResult: '${_decodedImages.length} Photos Selected',
            subtitle: 'Grid Layout: $_cols Columns × $_rows Rows',
            accentColor: AppColors.catImage,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Add Images'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.catImage,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _pickImages,
                ),
              ),
              if (_previewCollageBytes != null) ...[
                const SizedBox(width: 10),
                IconButton.filled(
                  icon: const Icon(Icons.share_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: _shareCollage,
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () {
                    setState(() {
                      _rawImages.clear();
                      _decodedImages.clear();
                      _previewCollageBytes = null;
                    });
                  },
                ),
              ],
            ],
          ),
          if (_decodedImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: '$_cols x $_rows',
                    decoration: InputDecoration(labelText: 'Grid Format', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    items: ['1 x 2', '2 x 1', '2 x 2', '3 x 1', '3 x 2', '3 x 3']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        final parts = v.split(' x ');
                        setState(() {
                          _cols = int.parse(parts[0]);
                          _rows = int.parse(parts[1]);
                        });
                        _renderCollage();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<Color>(
                    value: _bgColor,
                    decoration: InputDecoration(labelText: 'Border Color', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    items: [
                      const DropdownMenuItem(value: Colors.white, child: Text('White')),
                      const DropdownMenuItem(value: Colors.black, child: Text('Black')),
                      const DropdownMenuItem(value: Color(0xFFF3F4F6), child: Text('Light Grey')),
                      const DropdownMenuItem(value: Color(0xFF1E293B), child: Text('Dark Slate')),
                    ],
                    onChanged: (c) {
                      if (c != null) {
                        setState(() => _bgColor = c);
                        _renderCollage();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Border Spacing: '),
                Expanded(
                  child: Slider(
                    value: _spacing,
                    min: 0,
                    max: 30,
                    divisions: 6,
                    label: '${_spacing.toInt()} px',
                    onChanged: (v) {
                      setState(() => _spacing = v);
                      _renderCollage();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else if (_previewCollageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _previewCollageBytes!,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
