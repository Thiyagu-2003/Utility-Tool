import 'dart:isolate';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/share_utils.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

/// Edge length in pixels of one collage cell in the exported picture.
const int collageCellSize = 800;

/// Decodes [bytes] and centre-crops it to a square cell, so only small images are kept
/// in memory and re-rendered. Null if it is not a decodable image. Runs on a background isolate.
Future<img.Image?> decodeCollageCell(Uint8List bytes) => Isolate.run(() => _decodeCell(bytes));

img.Image? _decodeCell(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return img.copyResizeCropSquare(decoded, size: collageCellSize, interpolation: img.Interpolation.linear);
}

/// Total canvas size for a [cols]x[rows] grid with [spacing] px borders (also around the edge).
(int, int) collageCanvasSize(int cols, int rows, int spacing) =>
    (cols * collageCellSize + (cols + 1) * spacing, rows * collageCellSize + (rows + 1) * spacing);

/// Lays the square [cells] row by row on a [background] canvas and encodes it as JPEG.
/// Cells beyond [cols] x [rows] are left out.
Uint8List renderCollage(List<img.Image> cells, int cols, int rows, int spacing, Color background) {
  final (totalW, totalH) = collageCanvasSize(cols, rows, spacing);
  final canvas = img.Image(width: totalW, height: totalH);
  img.fill(
    canvas,
    color: img.ColorRgb8(
      (background.r * 255).round(),
      (background.g * 255).round(),
      (background.b * 255).round(),
    ),
  );
  for (var i = 0; i < cells.length && i < cols * rows; i++) {
    final dstX = spacing + (i % cols) * (collageCellSize + spacing);
    final dstY = spacing + (i ~/ cols) * (collageCellSize + spacing);
    img.compositeImage(canvas, cells[i], dstX: dstX, dstY: dstY);
  }
  return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
}

Future<Uint8List> renderCollageInBackground(List<img.Image> cells, int cols, int rows, int spacing, Color background) =>
    Isolate.run(() => renderCollage(cells, cols, rows, spacing, background));

class CollageMakerScreen extends StatefulWidget {
  const CollageMakerScreen({super.key});

  @override
  State<CollageMakerScreen> createState() => _CollageMakerScreenState();
}

class _CollageMakerScreenState extends State<CollageMakerScreen> {
  final List<img.Image> _cells = [];

  int _cols = 2;
  int _rows = 2;
  double _spacing = 8.0;
  Color _bgColor = Colors.white;
  bool _isProcessing = false;
  int _renderRun = 0; // only the newest render may update the preview
  Uint8List? _previewCollageBytes;

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImages() async {
    PreferencesService().triggerHaptic();
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty || !mounted) return;
      setState(() => _isProcessing = true);
      var skipped = 0;
      for (final f in files) {
        final bytes = await f.readAsBytes();
        final cell = await decodeCollageCell(bytes);
        if (!mounted) return;
        if (cell == null) {
          skipped++;
        } else {
          _cells.add(cell);
        }
      }
      if (skipped > 0) _showToast('$skipped file(s) could not be read as images and were skipped.');
      _autoSelectLayout();
      await _renderCollage();
    } catch (e) {
      _showToast('Error picking images: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _autoSelectLayout() {
    final count = _cells.length;
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
      // 3 columns and as many rows as needed, so no picked photo is dropped.
      _cols = 3;
      _rows = (count / 3).ceil();
    }
  }

  Future<void> _renderCollage() async {
    if (_cells.isEmpty) {
      if (mounted) setState(() => _previewCollageBytes = null);
      return;
    }
    final run = ++_renderRun;
    try {
      // Compositing a few million pixels and JPEG-encoding them must not block the UI.
      final bytes = await renderCollageInBackground(List.of(_cells), _cols, _rows, _spacing.toInt(), _bgColor);
      if (!mounted || run != _renderRun) return;
      setState(() => _previewCollageBytes = bytes);
    } catch (e) {
      _showToast('Collage render failed: $e');
    }
  }

  Future<void> _shareCollage() async {
    if (_previewCollageBytes == null) return;
    PreferencesService().triggerHaptic();
    try {
      await shareFileBytes(_previewCollageBytes!, 'Collage_${DateTime.now().millisecondsSinceEpoch}.jpg');
    } catch (e) {
      _showToast('Share failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hidden = _cells.length - _cols * _rows;
    return ToolScaffold(
      title: 'Image Collage Maker',
      category: ToolCategory.imagePhoto,
      toolId: 'image_collage_maker',
      onReset: () {
        _renderRun++; // drop any render still in flight
        setState(() {
          _cells.clear();
          _previewCollageBytes = null;
          _isProcessing = false;
          _cols = 2;
          _rows = 2;
          _spacing = 8.0;
          _bgColor = Colors.white;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Collage Canvas',
            primaryResult: '${_cells.length} Photos Selected',
            subtitle: hidden > 0
                ? 'Grid $_cols × $_rows shows ${_cols * _rows}; $hidden photo(s) left out. Pick a bigger grid.'
                : 'Grid Layout: $_cols Columns × $_rows Rows',
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
                  onPressed: _isProcessing ? null : _pickImages,
                ),
              ),
              if (_previewCollageBytes != null) ...[
                const SizedBox(width: 10),
                IconButton.filled(
                  icon: const Icon(Icons.share_rounded),
                  tooltip: 'Share collage',
                  style: IconButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: _shareCollage,
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Remove all photos',
                  onPressed: () {
                    _renderRun++;
                    setState(() {
                      _cells.clear();
                      _previewCollageBytes = null;
                    });
                  },
                ),
              ],
            ],
          ),
          if (_cells.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    // initialValue is read once, and picking photos changes the layout from outside.
                    key: ValueKey('$_cols x $_rows'),
                    initialValue: '$_cols x $_rows',
                    decoration: InputDecoration(labelText: 'Grid Format', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    // Always include the current layout (e.g. auto-picked 1 x 1 or 3 x 4),
                    // otherwise the dropdown asserts on a value missing from its items.
                    items: {'1 x 1', '1 x 2', '2 x 1', '2 x 2', '3 x 1', '3 x 2', '3 x 3', '$_cols x $_rows'}
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
                    isExpanded: true,
                    initialValue: _bgColor,
                    decoration: InputDecoration(labelText: 'Border Color', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    items: const [
                      DropdownMenuItem(value: Colors.white, child: Text('White')),
                      DropdownMenuItem(value: Colors.black, child: Text('Black')),
                      DropdownMenuItem(value: Color(0xFFF3F4F6), child: Text('Light Grey')),
                      DropdownMenuItem(value: Color(0xFF1E293B), child: Text('Dark Slate')),
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
                    onChanged: (v) => setState(() => _spacing = v),
                    // Re-render once on release, not on every drag tick.
                    onChangeEnd: (_) => _renderCollage(),
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
