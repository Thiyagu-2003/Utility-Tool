import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
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
        height: 84,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.grid_view_rounded,
                label: 'Tools',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.calculate_outlined,
                label: 'Calculator',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.account_balance_wallet_outlined,
                label: 'Finance',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.settings_outlined,
                label: 'Settings',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final activeTextColor = isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C);
    final activePillColor = isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5);
    final inactiveTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Active item sits in a 60x34 pill (#FFEDD5)
            Container(
              width: 60,
              height: 34,
              decoration: BoxDecoration(
                color: isSelected ? activePillColor : Colors.transparent,
                borderRadius: BorderRadius.circular(17),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? activeTextColor : inactiveTextColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? activeTextColor : inactiveTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
