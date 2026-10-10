import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/preferences_service.dart';
import 'slate_models.dart';
import 'slate_service.dart';

class SlateScreen extends StatefulWidget {
  final SlateDocument? initialSlate;

  const SlateScreen({super.key, this.initialSlate});

  @override
  State<SlateScreen> createState() => _SlateScreenState();
}

class _SlateScreenState extends State<SlateScreen> {
  final SlateService _slateService = SlateService();

  late SlateDocument _currentDocument;

  // Active Drawing Settings
  SlateToolType _activeTool = SlateToolType.pen;
  Color _activeColor = const Color(0xFF0F172A);
  double _activeSize = 6.0;
  double _activeOpacity = 1.0;

  // Strokes & History
  List<SlateStroke> _strokes = [];
  SlateStroke? _currentStroke;

  final List<List<SlateStroke>> _undoStack = [];
  final List<List<SlateStroke>> _redoStack = [];
  static const int _maxHistory = 30;

  // UI Overlays State
  bool _isPanelVisible = true;
  bool _isFocusMode = false;
  bool _isFullScreen = false;

  Timer? _autoSaveDebounce;

  // 14 Standard Colour Swatches
  static const List<Color> _swatches = [
    Color(0xFF0F172A),
    Color(0xFFE11D48),
    Color(0xFFEA580C),
    Color(0xFFFACC15),
    Color(0xFF16A34A),
    Color(0xFF0D9488),
    Color(0xFF0891B2),
    Color(0xFF2563EB),
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFFC026D3),
    Color(0xFF92400E),
    Color(0xFF94A3B8),
    Color(0xFFFFFFFF),
  ];

  @override
  void initState() {
    super.initState();

    _currentDocument = widget.initialSlate ??
        SlateDocument(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Untitled slate',
          updatedAt: DateTime.now(),
          paperType: SlatePaperType.blank,
          strokes: [],
        );

    _strokes = List.from(_currentDocument.strokes);

    if (widget.initialSlate == null) {
      _loadLastActiveSlate();
    }
  }

  Future<void> _loadLastActiveSlate() async {
    final saved = await _slateService.loadCurrent();
    if (saved != null && mounted) {
      setState(() {
        _currentDocument = saved;
        _strokes = List.from(saved.strokes);
      });
    }
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _triggerAutoSaveSync();
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _triggerAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(seconds: 2), _triggerAutoSaveSync);
  }

  void _triggerAutoSaveSync() {
    _currentDocument.strokes = List.from(_strokes);
    _currentDocument.updatedAt = DateTime.now();
    _slateService.autoSaveCurrent(_currentDocument);
  }

  void _pushUndoState() {
    _undoStack.add(List.from(_strokes));
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    PreferencesService().triggerHaptic();
    setState(() {
      _redoStack.add(List.from(_strokes));
      _strokes = _undoStack.removeLast();
    });
    _triggerAutoSave();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    PreferencesService().triggerHaptic();
    setState(() {
      _undoStack.add(List.from(_strokes));
      _strokes = _redoStack.removeLast();
    });
    _triggerAutoSave();
  }

  void _clearScreen() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Clear whole slate?',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Everything on the canvas will be removed. You can still undo right after.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                PreferencesService().triggerHaptic();
                setState(() {
                  _pushUndoState();
                  _strokes.clear();
                });
                _triggerAutoSave();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Clear',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _saveSlate() async {
    PreferencesService().triggerHaptic();
    final size = MediaQuery.of(context).size;
    final bytes = await _slateService.renderCanvasToPng(
      strokes: _strokes,
      paperType: _currentDocument.paperType,
      size: size,
    );

    // Update thumbnail in document
    _currentDocument.thumbnailBase64 = base64Encode(bytes);
    _currentDocument.strokes = List.from(_strokes);
    await _slateService.saveToMySlates(_currentDocument);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Saved to gallery',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Export PNG',
          textColor: const Color(0xFFEA580C),
          onPressed: () {
            _slateService.sharePng(bytes, _currentDocument.title);
          },
        ),
      ),
    );
  }

  void _renameSlate() {
    final controller = TextEditingController(text: _currentDocument.title);
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Rename slate',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.outfit(
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Enter slate title...',
              hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _currentDocument.title = text;
                  });
                  _triggerAutoSave();
                }
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleFocusMode() {
    setState(() {
      _isFocusMode = !_isFocusMode;
    });
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _togglePanel() {
    setState(() {
      _isPanelVisible = !_isPanelVisible;
    });
  }

  // Pointer & Gesture Event Handlers
  void _onPointerDown(PointerDownEvent event) {
    if (_isFocusMode) return;
    _pushUndoState();
    final point = SlatePoint(event.localPosition.dx, event.localPosition.dy);
    setState(() {
      _currentStroke = SlateStroke(
        tool: _activeTool,
        color: _activeColor,
        size: _activeSize,
        opacity: _activeOpacity,
        points: [point],
      );
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_currentStroke == null) return;
    final point = SlatePoint(event.localPosition.dx, event.localPosition.dy);

    setState(() {
      if (_activeTool == SlateToolType.line ||
          _activeTool == SlateToolType.box ||
          _activeTool == SlateToolType.circle) {
        // Shapes only need start and current end
        _currentStroke = _currentStroke!.copyWith(
          points: [_currentStroke!.points.first, point],
        );
      } else {
        // Freehand: append point and re-render entire stroke with smoothing
        _currentStroke = _currentStroke!.copyWith(
          points: [..._currentStroke!.points, point],
        );
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_currentStroke == null) return;
    setState(() {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
    });
    _triggerAutoSave();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_currentStroke == null) return;
    setState(() {
      _currentStroke = null;
    });
  }

  void _pickCustomColor() {
    showDialog(
      context: context,
      builder: (ctx) {
        double hue = 0;
        double saturation = 1.0;
        double lightness = 0.5;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentColor = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();

            return AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Custom Colour',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Hue', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                  Slider(
                    value: hue,
                    min: 0,
                    max: 360,
                    activeColor: const Color(0xFFEA580C),
                    onChanged: (v) => setDialogState(() => hue = v),
                  ),
                  Text('Saturation', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                  Slider(
                    value: saturation,
                    min: 0,
                    max: 1.0,
                    activeColor: const Color(0xFFEA580C),
                    onChanged: (v) => setDialogState(() => saturation = v),
                  ),
                  Text('Lightness', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                  Slider(
                    value: lightness,
                    min: 0.1,
                    max: 0.9,
                    activeColor: const Color(0xFFEA580C),
                    onChanged: (v) => setDialogState(() => lightness = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.outfit()),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
                  onPressed: () {
                    setState(() {
                      _activeColor = currentColor;
                      if (_activeTool == SlateToolType.eraser) {
                        _activeTool = SlateToolType.pen;
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text('Select', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMySlatesSheet() async {
    final slates = await _slateService.getMySlates();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Slates',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: slates.isEmpty
                        ? Center(
                            child: Text(
                              'No saved slates yet',
                              style: GoogleFonts.outfit(
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: slates.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = slates[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Thumbnail preview
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: item.thumbnailBase64 != null
                                          ? Image.memory(
                                              base64Decode(item.thumbnailBase64!),
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: isDark
                                                  ? const Color(0xFFF1F5F9)
                                                  : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${item.strokes.length} strokes • ${item.updatedAt.day}/${item.updatedAt.month}/${item.updatedAt.year}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Action popup menu
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded),
                                      onSelected: (val) async {
                                        if (val == 'open') {
                                          Navigator.pop(ctx);
                                          setState(() {
                                            _currentDocument = item;
                                            _strokes = List.from(item.strokes);
                                            _undoStack.clear();
                                            _redoStack.clear();
                                          });
                                        } else if (val == 'rename') {
                                          Navigator.pop(ctx);
                                          _renameSlate();
                                        } else if (val == 'duplicate') {
                                          final dup = await _slateService.duplicateSlate(item);
                                          setSheetState(() {
                                            slates.insert(0, dup);
                                          });
                                        } else if (val == 'delete') {
                                          await _slateService.deleteSlate(item.id);
                                          setSheetState(() {
                                            slates.removeAt(index);
                                          });
                                        } else if (val == 'share') {
                                          if (item.thumbnailBase64 != null) {
                                            final bytes = base64Decode(item.thumbnailBase64!);
                                            _slateService.sharePng(bytes, item.title);
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'open', child: Text('Open')),
                                        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                                        const PopupMenuItem(value: 'share', child: Text('Share PNG')),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete', style: TextStyle(color: Color(0xFFE11D48))),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _currentDocument.paperType == SlatePaperType.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            // 1. FULL-SCREEN CANVAS (Edge to Edge, never resized by overlays)
            Positioned.fill(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: CustomPaint(
                  painter: _SlateCanvasPainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                    paperType: _currentDocument.paperType,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),

            // 2. OVERLAY TOP BAR (60dp height)
            if (!_isFocusMode)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(isDark),
              ),

            // 3. OVERLAY TOOLS PANEL (Portrait bottom sheet, Landscape right side panel)
            if (!_isFocusMode)
              isLandscape
                  ? _buildLandscapeSidePanel(isDark)
                  : _buildPortraitBottomPanel(isDark),

            // 4. FLOATING PILL (when panel is hidden)
            if (!_isFocusMode && !_isPanelVisible)
              Positioned(
                bottom: 24,
                left: isLandscape ? null : 0,
                right: isLandscape ? 24 : 0,
                child: Center(
                  child: _buildFloatingPill(isDark),
                ),
              ),

            // 5. FOCUS MODE RESTORE BUTTON (48dp translucent eye button, top right)
            if (_isFocusMode)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleFocusMode,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.visibility_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Top Bar ---
  Widget _buildTopBar(bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;
    final barBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return Container(
      padding: EdgeInsets.fromLTRB(8, topPadding + 4, 8, 4),
      decoration: BoxDecoration(
        color: barBg.withValues(alpha: 0.96),
        border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            // Back Button
            _buildBarIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back to Home',
              onPressed: () {
                PreferencesService().triggerHaptic();
                Navigator.of(context).pop();
              },
              isDark: isDark,
            ),
            const SizedBox(width: 4),

            // Editable Slate Name
            Expanded(
              child: InkWell(
                onTap: _renameSlate,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _currentDocument.title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Undo Button
            _buildBarIconButton(
              icon: Icons.undo_rounded,
              tooltip: 'Undo',
              onPressed: _undoStack.isNotEmpty ? _undo : null,
              isDark: isDark,
            ),

            // Redo Button
            _buildBarIconButton(
              icon: Icons.redo_rounded,
              tooltip: 'Redo',
              onPressed: _redoStack.isNotEmpty ? _redo : null,
              isDark: isDark,
            ),

            // Save Button
            _buildBarIconButton(
              icon: Icons.save_alt_rounded,
              tooltip: 'Save to Gallery',
              onPressed: _saveSlate,
              isDark: isDark,
            ),

            // ⋯ Menu Button
            PopupMenuButton<String>(
              tooltip: 'Slate Options',
              icon: Icon(
                Icons.more_vert_rounded,
                size: 24,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                PreferencesService().triggerHaptic();
                if (val == 'focus') {
                  _toggleFocusMode();
                } else if (val == 'fullscreen') {
                  _toggleFullScreen();
                } else if (val == 'my_slates') {
                  _showMySlatesSheet();
                } else if (val == 'clear') {
                  _clearScreen();
                } else if (val.startsWith('paper_')) {
                  final paperName = val.replaceFirst('paper_', '');
                  setState(() {
                    _currentDocument.paperType = SlatePaperType.values.firstWhere(
                      (p) => p.name == paperName,
                      orElse: () => SlatePaperType.blank,
                    );
                  });
                  _triggerAutoSave();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'focus',
                  child: Row(
                    children: [
                      const Icon(Icons.fullscreen_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text('Focus mode', style: GoogleFonts.outfit()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'fullscreen',
                  child: Row(
                    children: [
                      Icon(
                        _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fit_screen_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(_isFullScreen ? 'Exit immersive' : 'Full screen', style: GoogleFonts.outfit()),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'my_slates',
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text('My slates', style: GoogleFonts.outfit()),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: 'paper_blank',
                  checked: _currentDocument.paperType == SlatePaperType.blank,
                  child: Text('Paper: Blank', style: GoogleFonts.outfit()),
                ),
                CheckedPopupMenuItem(
                  value: 'paper_grid',
                  checked: _currentDocument.paperType == SlatePaperType.grid,
                  child: Text('Paper: Grid (24px)', style: GoogleFonts.outfit()),
                ),
                CheckedPopupMenuItem(
                  value: 'paper_lined',
                  checked: _currentDocument.paperType == SlatePaperType.lined,
                  child: Text('Paper: Lined (32px)', style: GoogleFonts.outfit()),
                ),
                CheckedPopupMenuItem(
                  value: 'paper_dark',
                  checked: _currentDocument.paperType == SlatePaperType.dark,
                  child: Text('Paper: Dark slate', style: GoogleFonts.outfit()),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFE11D48)),
                      const SizedBox(width: 10),
                      Text(
                        'Clear screen',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFE11D48),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    final isEnabled = onPressed != null;
    final color = isEnabled
        ? (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A))
        : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1));

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }

  // --- Portrait Bottom Sheet Panel ---
  Widget _buildPortraitBottomPanel(bool isDark) {
    final panelBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      bottom: _isPanelVisible ? 0 : -480,
      left: 0,
      right: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.62,
        ),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with TOOLS and ▾ hide button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOOLS',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
                      tooltip: 'Hide Tools Panel',
                      onPressed: _togglePanel,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Tool Row (7 tools)
                      _buildToolSelectorRow(isDark, isLandscape: false),
                      const SizedBox(height: 16),

                      // 2. Size & Live Preview Dot
                      _buildSizeControl(isDark),
                      const SizedBox(height: 12),

                      // 3. Opacity Slider
                      _buildOpacityControl(isDark),
                      const SizedBox(height: 14),

                      // 4. Colour Swatches
                      _buildColourSwatches(isDark, isLandscape: false),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Landscape Side Panel (300dp on right) ---
  Widget _buildLandscapeSidePanel(bool isDark) {
    final panelBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      top: 60,
      bottom: 0,
      right: _isPanelVisible ? 0 : -320,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
              blurRadius: 16,
              offset: const Offset(-3, 0),
            ),
          ],
        ),
        child: SafeArea(
          left: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOOLS',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                      tooltip: 'Hide Tools Panel',
                      onPressed: _togglePanel,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tool buttons wrap into 4 columns in landscape
                      _buildToolSelectorRow(isDark, isLandscape: true),
                      const SizedBox(height: 16),
                      _buildSizeControl(isDark),
                      const SizedBox(height: 12),
                      _buildOpacityControl(isDark),
                      const SizedBox(height: 14),
                      _buildColourSwatches(isDark, isLandscape: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Floating Pill when Panel is Hidden ---
  Widget _buildFloatingPill(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _togglePanel,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _activeTool.label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              // Color dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _activeTool == SlateToolType.eraser ? Colors.transparent : _activeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_activeSize.toInt()}px',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: Color(0xFFEA580C)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Tool Selector Grid/Row ---
  Widget _buildToolSelectorRow(bool isDark, {required bool isLandscape}) {
    final activeBg = isDark ? const Color(0xFF431407) : const Color(0xFFFFEDD5);
    final activeFg = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
    final inactiveBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final inactiveFg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    if (isLandscape) {
      // 4 columns wrap
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: SlateToolType.values.map((tool) {
          final isSelected = _activeTool == tool;
          return SizedBox(
            width: (300 - 28 - 24) / 4,
            child: _buildToolItem(
              tool: tool,
              isSelected: isSelected,
              activeBg: activeBg,
              activeFg: activeFg,
              inactiveBg: inactiveBg,
              inactiveFg: inactiveFg,
            ),
          );
        }).toList(),
      );
    }

    // Portrait row scrollable
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: SlateToolType.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tool = SlateToolType.values[i];
          final isSelected = _activeTool == tool;
          return SizedBox(
            width: 64,
            child: _buildToolItem(
              tool: tool,
              isSelected: isSelected,
              activeBg: activeBg,
              activeFg: activeFg,
              inactiveBg: inactiveBg,
              inactiveFg: inactiveFg,
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolItem({
    required SlateToolType tool,
    required bool isSelected,
    required Color activeBg,
    required Color activeFg,
    required Color inactiveBg,
    required Color inactiveFg,
  }) {
    return Material(
      color: isSelected ? activeBg : inactiveBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          PreferencesService().triggerHaptic();
          setState(() {
            _activeTool = tool;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: const Color(0xFFEA580C), width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tool.icon, size: 22, color: isSelected ? activeFg : inactiveFg),
              const SizedBox(height: 2),
              Text(
                tool.label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? activeFg : inactiveFg,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Size Slider & Live Preview Dot ---
  Widget _buildSizeControl(bool isDark) {
    return Row(
      children: [
        Text(
          'Size: ${_activeSize.toInt()}',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: _activeSize,
            min: 1.0,
            max: 40.0,
            activeColor: const Color(0xFFEA580C),
            inactiveColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            onChanged: (val) {
              setState(() {
                _activeSize = val;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        // Live Preview Dot (current colour, outlined so visible in dark mode)
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Container(
            width: (_activeSize * 0.7).clamp(4.0, 28.0),
            height: (_activeSize * 0.7).clamp(4.0, 28.0),
            decoration: BoxDecoration(
              color: _activeTool == SlateToolType.eraser ? Colors.transparent : _activeColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Opacity Slider ---
  Widget _buildOpacityControl(bool isDark) {
    return Row(
      children: [
        Text(
          'Opacity: ${(_activeOpacity * 100).toInt()}%',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: _activeOpacity,
            min: 0.1,
            max: 1.0,
            activeColor: const Color(0xFFEA580C),
            inactiveColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            onChanged: (val) {
              setState(() {
                _activeOpacity = val;
              });
            },
          ),
        ),
      ],
    );
  }

  // --- 14 Colour Swatches + Custom Picker ---
  Widget _buildColourSwatches(bool isDark, {required bool isLandscape}) {
    final widgets = <Widget>[
      // 14 standard swatches
      ..._swatches.map((col) {
        final isSelected = _activeColor == col && _activeTool != SlateToolType.eraser;
        return GestureDetector(
          onTap: () {
            PreferencesService().triggerHaptic();
            setState(() {
              _activeColor = col;
              // Choosing a colour while eraser is selected switches back to Pen
              if (_activeTool == SlateToolType.eraser) {
                _activeTool = SlateToolType.pen;
              }
            });
          },
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: col,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFEA580C)
                    : (col == const Color(0xFFFFFFFF)
                        ? const Color(0xFFCBD5E1)
                        : Colors.transparent),
                width: isSelected ? 3.0 : 1.2,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
          ),
        );
      }),

      // Custom color picker (circle with rainbow gradient)
      GestureDetector(
        onTap: _pickCustomColor,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.cyan,
                Colors.blue,
                Colors.purple,
                Colors.pink,
                Colors.red,
              ],
            ),
            border: Border.all(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.colorize_rounded, size: 16, color: Colors.white),
        ),
      ),
    ];

    if (isLandscape) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: widgets,
      );
    }

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widgets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) => widgets[i],
      ),
    );
  }
}

// --- Custom Painter for Smooth Canvas Drawing with Layers ---
class _SlateCanvasPainter extends CustomPainter {
  final List<SlateStroke> strokes;
  final SlateStroke? currentStroke;
  final SlatePaperType paperType;

  _SlateCanvasPainter({
    required this.strokes,
    required this.currentStroke,
    required this.paperType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Paper Background
    _drawPaper(canvas, size);

    // 2. Save Layer for strokes so BlendMode.clear only clears strokes and reveals the paper!
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }

    canvas.restore();
  }

  void _drawPaper(Canvas canvas, Size size) {
    Color bgColor;
    switch (paperType) {
      case SlatePaperType.dark:
        bgColor = const Color(0xFF1E293B);
        break;
      case SlatePaperType.blank:
      case SlatePaperType.grid:
      case SlatePaperType.lined:
        bgColor = Colors.white;
        break;
    }

    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (paperType == SlatePaperType.grid) {
      final linePaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 1.0;
      const step = 24.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    } else if (paperType == SlatePaperType.lined) {
      final linePaint = Paint()
        ..color = const Color(0xFFBFDBFE)
        ..strokeWidth = 1.0;
      const step = 32.0;
      for (double y = 48.0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    } else if (paperType == SlatePaperType.dark) {
      final linePaint = Paint()
        ..color = const Color(0xFF334155).withValues(alpha: 0.45)
        ..strokeWidth = 0.8;
      const step = 28.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    }
  }

  void _drawStroke(Canvas canvas, SlateStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = stroke.size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (stroke.tool) {
      case SlateToolType.pen:
        paint.color = stroke.color.withValues(alpha: stroke.opacity);
        break;
      case SlateToolType.brush:
        paint.color = stroke.color.withValues(alpha: stroke.opacity);
        paint.strokeWidth = stroke.size * 1.5;
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, (stroke.size * 1.5) * 0.22);
        break;
      case SlateToolType.marker:
        final markerOpacity = (stroke.opacity * 0.38).clamp(0.08, 0.40);
        paint.color = stroke.color.withValues(alpha: markerOpacity);
        paint.strokeWidth = stroke.size * 3.0;
        paint.strokeCap = StrokeCap.square;
        paint.strokeJoin = StrokeJoin.miter;
        break;
      case SlateToolType.eraser:
        paint.blendMode = BlendMode.clear;
        paint.strokeWidth = stroke.size * 2.0;
        break;
      case SlateToolType.line:
      case SlateToolType.box:
      case SlateToolType.circle:
        paint.color = stroke.color.withValues(alpha: stroke.opacity);
        break;
    }

    if (stroke.tool == SlateToolType.line) {
      if (stroke.points.length >= 2) {
        canvas.drawLine(stroke.points.first.toOffset(), stroke.points.last.toOffset(), paint);
      }
      return;
    }

    if (stroke.tool == SlateToolType.box) {
      if (stroke.points.length >= 2) {
        canvas.drawRect(
          Rect.fromPoints(stroke.points.first.toOffset(), stroke.points.last.toOffset()),
          paint,
        );
      }
      return;
    }

    if (stroke.tool == SlateToolType.circle) {
      if (stroke.points.length >= 2) {
        canvas.drawOval(
          Rect.fromPoints(stroke.points.first.toOffset(), stroke.points.last.toOffset()),
          paint,
        );
      }
      return;
    }

    // Freehand with midpoint quadratic smoothing
    if (stroke.points.length == 1) {
      final p = stroke.points.first.toOffset();
      canvas.drawCircle(p, paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(stroke.points[0].x, stroke.points[0].y);

    for (int i = 1; i < stroke.points.length; i++) {
      final pPrev = stroke.points[i - 1];
      final pCurr = stroke.points[i];
      final midX = (pPrev.x + pCurr.x) / 2;
      final midY = (pPrev.y + pCurr.y) / 2;
      path.quadraticBezierTo(pPrev.x, pPrev.y, midX, midY);
    }
    path.lineTo(stroke.points.last.x, stroke.points.last.y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SlateCanvasPainter oldDelegate) {
    return true;
  }
}
