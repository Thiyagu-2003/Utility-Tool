import 'package:flutter/material.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/toolbox_pro_logo.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showClearHistoryDialog(BuildContext context, PreferencesService prefs) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear Calculation History?'),
          content: const Text('This will erase all your saved calculator and tool computation history.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              onPressed: () {
                prefs.clearHistory();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calculation history cleared')),
                );
              },
              child: const Text('Clear History'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: AnimatedBuilder(
        animation: prefs,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Appearance Section
              Text(
                'APPEARANCE & THEME',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: const Text('System Default', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Automatically adapt to device settings'),
                      secondary: const Icon(Icons.brightness_auto_rounded),
                      value: ThemeMode.system,
                      groupValue: prefs.themeMode,
                      activeColor: AppColors.primaryOrange,
                      onChanged: (val) {
                        if (val != null) prefs.setThemeMode(val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      title: const Text('Light Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Clean high-contrast daytime interface'),
                      secondary: const Icon(Icons.wb_sunny_rounded),
                      value: ThemeMode.light,
                      groupValue: prefs.themeMode,
                      activeColor: AppColors.primaryOrange,
                      onChanged: (val) {
                        if (val != null) prefs.setThemeMode(val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Sleek dark theme easy on the eyes'),
                      secondary: const Icon(Icons.nightlight_round),
                      value: ThemeMode.dark,
                      groupValue: prefs.themeMode,
                      activeColor: AppColors.primaryOrange,
                      onChanged: (val) {
                        if (val != null) prefs.setThemeMode(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Feedback & Haptics
              Text(
                'FEEDBACK & INTERACTION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: SwitchListTile(
                  secondary: const Icon(Icons.vibration_rounded),
                  title: const Text('Haptic Vibration Feedback', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Tactile buzz on keypads, toggles and button presses'),
                  value: prefs.hapticEnabled,
                  activeColor: AppColors.primaryOrange,
                  onChanged: (val) => prefs.toggleHaptics(val),
                ),
              ),
              const SizedBox(height: 24),

              // Data & Storage
              Text(
                'DATA & PRIVACY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  title: const Text('Clear Calculation History', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
                  subtitle: Text('${prefs.calculationHistory.length} saved records'),
                  onTap: () => _showClearHistoryDialog(context, prefs),
                ),
              ),
              const SizedBox(height: 24),

              // About & ToolBox Pro Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ToolBoxProLogo(iconSize: 48, showTagline: true),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.catFinance.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined, color: AppColors.catFinance, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '100% Offline & Private',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'All calculators, converters, PDF engines, and scanners process data entirely on your device with no internet tracking.',
                                style: TextStyle(fontSize: 11, color: AppColors.darkTextMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
