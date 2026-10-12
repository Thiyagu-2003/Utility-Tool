import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/share_utils.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/toolbox_pro_logo.dart';
import '../history/calculation_history_screen.dart';
import '../onboarding/app_onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showLanguageDialog(BuildContext context, PreferencesService prefs) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Language / மொழி'),
          content: RadioGroup<String>(
            groupValue: prefs.appLanguage,
            onChanged: (val) {
              if (val == null) return;
              prefs.setAppLanguage(val);
              Navigator.pop(context);
              final name = AppLocalizations.languageNames[val] ?? val;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Language changed to $name')),
              );
            },
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLocalizations.supportedLocales.map((loc) {
              final code = loc.languageCode;
              final name = AppLocalizations.languageNames[code] ?? code;
              final isSelected = prefs.appLanguage == code;

              return RadioListTile<String>(
                title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                value: code,
                activeColor: AppColors.primaryOrange,
              );
            }).toList(),
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showFontScaleDialog(BuildContext context, PreferencesService prefs) {
    final scales = [
      {'label': 'Standard (1.0x)', 'scale': 1.0, 'sub': 'Default system size'},
      {'label': 'Large (1.15x)', 'scale': 1.15, 'sub': 'Comfortable reading for everyday use'},
      {'label': 'Extra Large (1.30x)', 'scale': 1.30, 'sub': 'Maximum legibility and high contrast'},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dynamic Font Sizing'),
          content: RadioGroup<double>(
            groupValue: scales.map((s) => s["scale"] as double).firstWhere((s) => (prefs.fontScale - s).abs() < 0.05, orElse: () => 1.0),
            onChanged: (val) {
              if (val == null) return;
              prefs.setFontScale(val);
              Navigator.pop(context);
            },
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: scales.map((item) {
              final scale = item['scale'] as double;
              final label = item['label'] as String;
              final sub = item['sub'] as String;
              final isSelected = (prefs.fontScale - scale).abs() < 0.05;

              return RadioListTile<double>(
                title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
                value: scale,
                activeColor: AppColors.primaryOrange,
              );
            }).toList(),
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showImportBackupDialog(BuildContext context, PreferencesService prefs) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore from Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the JSON backup string previously exported from ToolBox Pro:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: '{\n  "app": "ToolBox Pro",\n  ...\n}',
                  hintStyle: const TextStyle(fontSize: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.paste_rounded, size: 16),
                label: const Text('Paste from Clipboard'),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    textController.text = data!.text!;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final jsonStr = textController.text.trim();
                final success = await BackupService.importBackupJson(jsonStr, prefs);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Backup restored successfully! All preferences, favorites, and history loaded.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid backup data format. Please check the JSON payload.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Restore Data'),
            ),
          ],
        );
      },
    );
  }

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
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('settings'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: AnimatedBuilder(
        animation: prefs,
        builder: (context, _) {
          final curLangName = AppLocalizations.languageNames[prefs.appLanguage] ?? 'English';

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Appearance Section
              Text(
                loc.tr('appearance').toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              // Material (not a decorated Container) so the tiles' ink splashes stay visible.
              Material(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: RadioGroup<ThemeMode>(
                  groupValue: prefs.themeMode,
                  onChanged: (val) {
                    if (val != null) prefs.setThemeMode(val);
                  },
                  child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text(loc.tr('system_mode'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Automatically adapt to device settings'),
                      secondary: const Icon(Icons.brightness_auto_rounded),
                      value: ThemeMode.system,
                      activeColor: AppColors.primaryOrange,
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      title: Text(loc.tr('light_mode'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Clean high-contrast daytime interface'),
                      secondary: const Icon(Icons.wb_sunny_rounded),
                      value: ThemeMode.light,
                      activeColor: AppColors.primaryOrange,
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      title: Text(loc.tr('dark_mode'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Sleek dark theme easy on the eyes'),
                      secondary: const Icon(Icons.nightlight_round),
                      value: ThemeMode.dark,
                      activeColor: AppColors.primaryOrange,
                    ),
                  ],
                ),
                ),
              ),
              const SizedBox(height: 24),

              // Language & Accessibility Section
              Text(
                'LANGUAGE & ACCESSIBILITY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              // Material (not a decorated Container) so the tiles' ink splashes stay visible.
              Material(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.translate_rounded, color: AppColors.catText),
                      title: Text(loc.tr('language'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(curLangName, style: const TextStyle(fontSize: 13)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showLanguageDialog(context, prefs),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.format_size_rounded, color: AppColors.catTime),
                      title: Text(loc.tr('font_size'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        prefs.fontScale >= 1.25
                            ? 'Extra Large (1.30x)'
                            : (prefs.fontScale >= 1.1 ? 'Large (1.15x)' : 'Standard (1.0x)'),
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showFontScaleDialog(context, prefs),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Home Screen Customization
              Text(
                'HOME SCREEN CUSTOMIZATION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              // Material (not a decorated Container) so the tiles' ink splashes stay visible.
              Material(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.star_rounded, color: AppColors.warning),
                      title: const Text('Show Favorites Tray', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${prefs.favoriteToolIds.length} tools pinned for quick access'),
                      value: prefs.showFavorites,
                      activeThumbColor: AppColors.primaryOrange,
                      onChanged: (val) => prefs.toggleShowFavorites(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.history_rounded, color: AppColors.catConverter),
                      title: const Text('Show Recently Used Tools', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${prefs.recentToolIds.length} recently opened tools tracked'),
                      value: prefs.showRecents,
                      activeThumbColor: AppColors.primaryOrange,
                      onChanged: (val) => prefs.toggleShowRecents(val),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.restart_alt_rounded, color: AppColors.primaryOrange),
                      title: Text(loc.tr('reset_order'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Restore default layout for categories'),
                      onTap: () {
                        prefs.resetCategoryOrder();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Category layout reset to default')),
                        );
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
              // Material (not a decorated Container) so the tiles' ink splashes stay visible.
              Material(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  secondary: const Icon(Icons.vibration_rounded),
                  title: Text(loc.tr('haptics'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Tactile buzz on keypads, toggles and button presses'),
                  value: prefs.hapticEnabled,
                  activeThumbColor: AppColors.primaryOrange,
                  onChanged: (val) => prefs.toggleHaptics(val),
                ),
              ),
              const SizedBox(height: 24),

              // Calculation History & Data
              Text(
                'CALCULATION HISTORY & STORAGE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              // Material (not a decorated Container) so the tiles' ink splashes stay visible.
              Material(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.receipt_long_rounded, color: AppColors.catFinance),
                      title: Text(loc.tr('calculation_history'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${prefs.calculationHistory.length} saved computations with filters & search'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CalculationHistoryScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      title: const Text('Clear Calculation History', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
                      subtitle: const Text('Permanently erase cached calculations'),
                      onTap: () => _showClearHistoryDialog(context, prefs),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Backup & Restore
              Text(
                'BACKUP & DATA PORTABILITY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              // Material (not a decorated Container) so the tiles' ink splashes stay visible.
              Material(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.file_upload_outlined, color: AppColors.catFinance),
                      title: Text(loc.tr('export_backup'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Share a backup file of preferences, favorites and history'),
                      trailing: const Icon(Icons.ios_share_rounded, size: 20),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final json = BackupService.exportBackupJson(prefs);
                        try {
                          await shareFileBytes(
                            Uint8List.fromList(utf8.encode(json)),
                            'toolbox_pro_backup_${DateTime.now().millisecondsSinceEpoch ~/ 1000}.json',
                          );
                        } catch (_) {
                          // Sharing unavailable: fall back to the clipboard.
                          await Clipboard.setData(ClipboardData(text: json));
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Sharing failed; backup copied to clipboard (${json.length} characters)'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined, color: AppColors.catConverter),
                      title: Text(loc.tr('import_backup'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Import saved backup payload with verification'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showImportBackupDialog(context, prefs),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Onboarding & Help
              Text(
                'GUIDES & TUTORIALS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              // Material (not a decorated Container) so the tiles' ink splashes stay visible.
              Material(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.auto_stories_rounded, color: AppColors.primaryOrange),
                  title: const Text('Replay App Onboarding Tour', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Interactive 4-step walkthrough of features & customization'),
                  trailing: const Icon(Icons.play_circle_outline_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      // isReplay pops back here; otherwise finishing pushes a second MainNavigationScaffold.
                      MaterialPageRoute(builder: (_) => const AppOnboardingScreen(isReplay: true)),
                    );
                  },
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
                            color: AppColors.catFinance.withValues(alpha: 0.12),
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
                                'All calculators, converters, PDF engines, and scanners process data entirely on your device with zero cloud tracking.',
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
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
