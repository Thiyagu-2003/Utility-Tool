import 'dart:convert';
import 'preferences_service.dart';

class BackupService {
  static String exportBackupJson(PreferencesService prefs) {
    final Map<String, dynamic> data = {
      'app': 'ToolBox Pro',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'favorite_tools': prefs.favoriteToolIds.toList(),
      'recent_tools': prefs.recentToolIds,
      'custom_category_order': prefs.categoryOrder.map((c) => c.name).toList(),
      'calc_history': prefs.calculationHistory.map((r) => r.toJson()).toList(),
      'qr_scan_history': prefs.qrScanHistory.map((r) => r.toJson()).toList(),
      'theme_mode': prefs.themeMode.name,
      'haptic_feedback': prefs.hapticEnabled,
      'app_language': prefs.appLanguage,
      'font_scale': prefs.fontScale,
      'show_favorites': prefs.showFavorites,
      'show_recents': prefs.showRecents,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static bool validateBackupJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return false;
      return decoded.containsKey('app') && decoded['app'] == 'ToolBox Pro';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> importBackupJson(String jsonStr, PreferencesService prefs) async {
    try {
      if (!validateBackupJson(jsonStr)) return false;
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      await prefs.restoreFromBackupMap(data);
      return true;
    } catch (_) {
      return false;
    }
  }
}
