import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/tool_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/tool_scaffold.dart';

class ColorTestItem {
  final String name;
  final Color color;
  final String purpose;
  final bool isGradient;

  const ColorTestItem({
    required this.name,
    required this.color,
    required this.purpose,
    this.isGradient = false,
  });
}

class ScreenColorTestScreen extends StatefulWidget {
  const ScreenColorTestScreen({super.key});

  @override
  State<ScreenColorTestScreen> createState() => _ScreenColorTestScreenState();
}

class _ScreenColorTestScreenState extends State<ScreenColorTestScreen> {
  static const List<ColorTestItem> _testPatterns = [
    ColorTestItem(name: 'Pure Red', color: Color(0xFFFF0000), purpose: 'Detects dead or stuck red sub-pixels'),
    ColorTestItem(name: 'Pure Green', color: Color(0xFF00FF00), purpose: 'Detects green sub-pixel defects'),
    ColorTestItem(name: 'Pure Blue', color: Color(0xFF0000FF), purpose: 'Detects blue sub-pixel defects'),
    ColorTestItem(name: 'Pure White', color: Color(0xFFFFFFFF), purpose: 'Checks overall color uniformity & dark dead pixels'),
    ColorTestItem(name: 'Pure Black', color: Color(0xFF000000), purpose: 'Tests for backlight bleed, IPS glow & OLED dead pixels'),
    ColorTestItem(name: 'Neutral 50% Gray', color: Color(0xFF808080), purpose: 'Standard gray balance & dirty screen effect (DSE)'),
    ColorTestItem(name: 'Cyan', color: Color(0xFF00FFFF), purpose: 'Secondary color convergence check (G + B)'),
    ColorTestItem(name: 'Magenta', color: Color(0xFFFF00FF), purpose: 'Secondary color convergence check (R + B)'),
    ColorTestItem(name: 'Yellow', color: Color(0xFFFFFF00), purpose: 'Secondary color convergence check (R + G)'),
    ColorTestItem(name: '256-Level Gradient', color: Colors.black, purpose: 'Detects 8-bit banding and gamma clipping', isGradient: true),
  ];

  void _launchFullscreenTest(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenColorInspectionView(initialIndex: initialIndex, patterns: _testPatterns),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Screen Color & Pixel Test',
      category: ToolCategory.moreTools,
      toolId: 'screen_color_test',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.catImage.withValues(alpha: 0.15),
                  AppColors.catDev.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.catImage.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.catImage.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.palette_rounded, color: AppColors.catImage, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display Quality & Pixel Audit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Launch immersive fullscreen patterns to spot dead pixels, stuck subpixels, IPS backlight bleeding, and OLED burn-in.',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary Launch Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.fullscreen_rounded),
            label: const Text('Start Fullscreen Inspection Tour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            onPressed: () => _launchFullscreenTest(context, 0),
          ),
          const SizedBox(height: 24),

          Text(
            'SELECT SPECIFIC TEST PATTERN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),

          ..._testPatterns.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: ListTile(
                onTap: () => _launchFullscreenTest(context, idx),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.4), width: 1.5),
                    gradient: item.isGradient
                        ? const LinearGradient(colors: [Colors.black, Colors.white])
                        : null,
                  ),
                ),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(item.purpose, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class FullscreenColorInspectionView extends StatefulWidget {
  final int initialIndex;
  final List<ColorTestItem> patterns;

  const FullscreenColorInspectionView({
    super.key,
    required this.initialIndex,
    required this.patterns,
  });

  @override
  State<FullscreenColorInspectionView> createState() => _FullscreenColorInspectionViewState();
}

class _FullscreenColorInspectionViewState extends State<FullscreenColorInspectionView> {
  late int _currentIndex;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Auto-hide overlay after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _nextPattern() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.patterns.length;
    });
    HapticFeedback.selectionClick();
  }

  void _prevPattern() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + widget.patterns.length) % widget.patterns.length;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final pattern = widget.patterns[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() => _showOverlay = !_showOverlay);
        },
        onDoubleTap: _nextPattern,
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -100) {
            _nextPattern();
          } else if ((details.primaryVelocity ?? 0) > 100) {
            _prevPattern();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The Color Canvas
            pattern.isGradient
                ? Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.black, Colors.white],
                      ),
                    ),
                  )
                : Container(color: pattern.color),

            // Subtle Hint Overlay
            if (_showOverlay)
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Column(
                            children: [
                              Text(
                                pattern.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                              ),
                              Text(
                                '${_currentIndex + 1} of ${widget.patterns.length}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Navigation Bar
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                            onPressed: _prevPattern,
                          ),
                          const Text(
                            'Swipe / Double-Tap to advance • Tap to hide HUD',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                            onPressed: _nextPattern,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
