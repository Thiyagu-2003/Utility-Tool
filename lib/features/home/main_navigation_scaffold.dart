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

  // Direct list of pages — no PageView swiping
  static const List<Widget> _pages = [
    CategoryHubScreen(initialCategory: ToolCategory.all),
    CalculatorScreen(),
    CategoryHubScreen(initialCategory: ToolCategory.finance, isFinanceFocused: true),
    SettingsScreen(),
  ];

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    PreferencesService().triggerHaptic();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.grid_view_rounded,
                  activeIcon: Icons.grid_view_rounded,
                  label: 'Tools',
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.calculate_outlined,
                  activeIcon: Icons.calculate_rounded,
                  label: 'Calculator',
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet_rounded,
                  label: 'Finance',
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing icon container when selected
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 20 : 12,
                  vertical: isSelected ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryOrange.withOpacity(0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 24,
                  color: isSelected
                      ? AppColors.primaryOrange
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primaryOrange
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
