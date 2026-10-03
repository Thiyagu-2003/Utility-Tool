import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../calculator/calculator_screen.dart';
import 'category_hub_screen.dart';
import '../settings/settings_screen.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    PreferencesService().triggerHaptic();
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildTopNavItem({
    required int index,
    required IconData icon,
    required String tooltip,
    Widget? customIcon,
  }) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onTabTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryOrange.withOpacity(0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: customIcon ??
              Icon(
                icon,
                size: 26,
                color: isSelected
                    ? AppColors.primaryOrange
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Tab 0: Calculator (=)
                _buildTopNavItem(
                  index: 0,
                  icon: Icons.equalizer_rounded,
                  tooltip: 'Calculator',
                  customIcon: Container(
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      '=',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _currentIndex == 0
                            ? AppColors.primaryOrange
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                  ),
                ),

                // Tab 1: Category Hub (::)
                _buildTopNavItem(
                  index: 1,
                  icon: Icons.grid_view_rounded,
                  tooltip: 'Tools Hub',
                ),

                // Tab 2: Finance Hub ($)
                _buildTopNavItem(
                  index: 2,
                  icon: Icons.account_balance_wallet_outlined,
                  tooltip: 'Finance & Shopping',
                ),

                // Tab 3: Settings (...)
                _buildTopNavItem(
                  index: 3,
                  icon: Icons.more_horiz_rounded,
                  tooltip: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          PreferencesService().triggerSelectionHaptic();
          setState(() {
            _currentIndex = index;
          });
        },
        children: const [
          CalculatorScreen(),
          CategoryHubScreen(initialCategory: ToolCategory.all),
          CategoryHubScreen(initialCategory: ToolCategory.finance, isFinanceFocused: true),
          SettingsScreen(),
        ],
      ),
    );
  }
}
