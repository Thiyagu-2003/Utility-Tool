import 'package:flutter/material.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/toolbox_pro_logo.dart';
import '../home/main_navigation_scaffold.dart';

class OnboardingSlide {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String badge;

  const OnboardingSlide({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.badge,
  });
}

class AppOnboardingScreen extends StatefulWidget {
  final bool isReplay;

  const AppOnboardingScreen({super.key, this.isReplay = false});

  @override
  State<AppOnboardingScreen> createState() => _AppOnboardingScreenState();
}

class _AppOnboardingScreenState extends State<AppOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<OnboardingSlide> _slides = [
    OnboardingSlide(
      icon: Icons.apps_rounded,
      color: AppColors.primaryOrange,
      badge: '32+ POWERFUL TOOLS',
      title: 'Your Complete Multi-Tool Workspace',
      subtitle:
          'From Scientific Math, Unit Conversions, and Financial GST/EMI to Health, Kitchen, and Hardware Sensors — everything you need in one sleek app.',
    ),
    OnboardingSlide(
      icon: Icons.calculate_rounded,
      color: Color(0xFF3B82F6),
      badge: 'SMART SEARCH SHORTCUTS',
      title: 'Instant Math & Unit Calculations',
      subtitle:
          'Type expressions like "25 * 40", "15% of 2500", or "10 km to m" straight into the search bar for live, instant evaluated results without opening any tool.',
    ),
    OnboardingSlide(
      icon: Icons.tune_rounded,
      color: Color(0xFF10B981),
      badge: 'CUSTOMIZABLE WORKSPACE',
      title: 'Drag & Reorder Your Categories',
      subtitle:
          'Want Kitchen or Finance at the top? Simply long-press and drag any category to customize your home layout, or tap the Edit Toolbox button.',
    ),
    OnboardingSlide(
      icon: Icons.shield_rounded,
      color: Color(0xFFE11D48),
      badge: '100% PRIVATE & OFFLINE',
      title: 'Zero Tracking • Complete Privacy',
      subtitle:
          'All PDF processing, OCR text extraction, document scans, and calculation history remain strictly on your device. Zero internet tracking.',
    ),
  ];

  void _finishOnboarding() {
    PreferencesService().triggerHaptic();
    PreferencesService().completeOnboarding();
    if (widget.isReplay) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScaffold()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _finishOnboarding,
            child: Text(
              widget.isReplay ? 'Close' : 'Skip',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Logo header
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: ToolBoxProLogo(iconSize: 32),
            ),

            // Page carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Giant Feature Icon Container
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                slide.color.withOpacity(0.25),
                                slide.color.withOpacity(0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: slide.color.withOpacity(0.4),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: slide.color.withOpacity(0.2),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(slide.icon, color: slide.color, size: 52),
                        ),
                        const SizedBox(height: 32),

                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: slide.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            slide.badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: slide.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subtitle
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation & Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dot Indicators
                  Row(
                    children: List.generate(_slides.length, (i) {
                      final isSelected = _currentPage == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: isSelected ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryOrange : (isDark ? Colors.white24 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next / Get Started Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (_currentPage < _slides.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _finishOnboarding();
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
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
