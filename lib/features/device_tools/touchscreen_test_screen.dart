import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/vibration_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/tool_scaffold.dart';

class TouchscreenTestScreen extends StatefulWidget {
  const TouchscreenTestScreen({super.key});

  @override
  State<TouchscreenTestScreen> createState() => _TouchscreenTestScreenState();
}

class _TouchscreenTestScreenState extends State<TouchscreenTestScreen> {
  int _activeTab = 0; // 0: Grid Coverage, 1: Multi-Touch Tracer

  // Grid Matrix State (10 cols x 16 rows = 160 cells)
  static const int _cols = 10;
  static const int _rows = 16;
  static const int _totalCells = _cols * _rows;
  final Set<int> _testedCells = {};

  // Multi-Touch Pointer State
  final Map<int, Offset> _activePointers = {};
  final List<List<Offset>> _drawnTrails = [];
  List<Offset> _currentTrail = [];

  void _markCellAt(Offset localPos, Size size) {
    final cellWidth = size.width / _cols;
    final cellHeight = size.height / _rows;

    final col = (localPos.dx / cellWidth).floor().clamp(0, _cols - 1);
    final row = (localPos.dy / cellHeight).floor().clamp(0, _rows - 1);
    final index = row * _cols + col;

    if (!_testedCells.contains(index)) {
      setState(() {
        _testedCells.add(index);
      });
      if (_testedCells.length == _totalCells) {
        VibrationService.heavyImpact();
      } else {
        VibrationService.selectionClick();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Touchscreen Digitizer Test',
      category: ToolCategory.moreTools,
      toolId: 'touchscreen_test',
      isScrollable: false,
      body: Column(
        children: [
          // Control Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Grid Coverage'), icon: Icon(Icons.grid_on_rounded, size: 16)),
                      ButtonSegment(value: 1, label: Text('Multi-Touch'), icon: Icon(Icons.fingerprint_rounded, size: 16)),
                    ],
                    selected: {_activeTab},
                    onSelectionChanged: (val) => setState(() => _activeTab = val.first),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Reset Test',
                  onPressed: () {
                    setState(() {
                      _testedCells.clear();
                      _drawnTrails.clear();
                      _currentTrail.clear();
                    });
                  },
                ),
              ],
            ),
          ),

          // Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_activeTab == 0) ...[
                  Text(
                    'Coverage: ${_testedCells.length}/$_totalCells (${((_testedCells.length / _totalCells) * 100).toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _testedCells.length == _totalCells ? AppColors.success : AppColors.primaryOrange,
                    ),
                  ),
                  Text(
                    _testedCells.length == _totalCells ? 'PASSED: 100% HEALTHY' : 'Drag finger across screen',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _testedCells.length == _totalCells ? AppColors.success : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Active Fingers: ${_activePointers.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.catConverter),
                  ),
                  Text(
                    'Touch and draw with multiple fingers',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ],
              ],
            ),
          ),

          // Main Interactive Canvas Area
          Expanded(
            child: _activeTab == 0 ? _buildGridMatrixTest(isDark) : _buildMultiTouchTracer(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildGridMatrixTest(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final cellW = constraints.maxWidth / _cols;
        final cellH = constraints.maxHeight / _rows;
        final cellRatio = cellH > 0 ? (cellW / cellH) : 0.65;

        return GestureDetector(
          onPanDown: (details) => _markCellAt(details.localPosition, size),
          onPanUpdate: (details) => _markCellAt(details.localPosition, size),
          child: Container(
            color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _totalCells,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _cols,
                childAspectRatio: cellRatio,
              ),
              itemBuilder: (context, index) {
                final isTested = _testedCells.contains(index);
                return Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: isTested
                        ? AppColors.success.withValues(alpha: 0.85)
                        : (isDark ? AppColors.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isTested
                          ? AppColors.success
                          : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
                      width: 0.5,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMultiTouchTracer(bool isDark) {
    return Listener(
      onPointerDown: (event) {
        setState(() {
          _activePointers[event.pointer] = event.localPosition;
          _currentTrail = [event.localPosition];
          _drawnTrails.add(_currentTrail);
        });
        VibrationService.selectionClick();
      },
      onPointerMove: (event) {
        setState(() {
          _activePointers[event.pointer] = event.localPosition;
          _currentTrail.add(event.localPosition);
        });
      },
      onPointerUp: (event) {
        setState(() {
          _activePointers.remove(event.pointer);
        });
      },
      onPointerCancel: (event) {
        setState(() {
          _activePointers.remove(event.pointer);
        });
      },
      child: Container(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: CustomPaint(
          painter: MultiTouchPainter(
            pointers: _activePointers,
            trails: _drawnTrails,
            isDark: isDark,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class MultiTouchPainter extends CustomPainter {
  final Map<int, Offset> pointers;
  final List<List<Offset>> trails;
  final bool isDark;

  MultiTouchPainter({required this.pointers, required this.trails, required this.isDark});

  static const List<Color> _pointerColors = [
    Colors.redAccent,
    Colors.greenAccent,
    Colors.blueAccent,
    Colors.amberAccent,
    Colors.purpleAccent,
    Colors.tealAccent,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.cyanAccent,
    Colors.limeAccent,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw trails
    for (int t = 0; t < trails.length; t++) {
      final trail = trails[t];
      if (trail.length < 2) continue;
      final paint = Paint()
        ..color = _pointerColors[t % _pointerColors.length].withValues(alpha: 0.6)
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()..moveTo(trail.first.dx, trail.first.dy);
      for (int i = 1; i < trail.length; i++) {
        path.lineTo(trail[i].dx, trail[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // 2. Draw active pointer crosshairs & badges
    int pIdx = 0;
    pointers.forEach((id, pos) {
      final color = _pointerColors[pIdx % _pointerColors.length];

      // Outer ripple
      canvas.drawCircle(
        pos,
        42,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );

      // Inner solid point
      canvas.drawCircle(
        pos,
        18,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      // Coordinate text banner
      final textSpan = TextSpan(
        text: 'P$id (${pos.dx.toInt()}, ${pos.dy.toInt()})',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          backgroundColor: isDark ? Colors.black54 : Colors.white70,
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(pos.dx + 24, pos.dy - 12));

      pIdx++;
    });
  }

  @override
  bool shouldRepaint(covariant MultiTouchPainter oldDelegate) => true;
}
