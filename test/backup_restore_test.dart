import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utility_tool/core/services/preferences_service.dart';
import 'package:utility_tool/core/services/backup_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  group('Automated Backup & Restore Service Tests', () {
    test('exportBackupJson generates valid JSON with correct schema', () {
      final prefs = PreferencesService();
      final jsonStr = BackupService.exportBackupJson(prefs);

      expect(jsonStr, isNotEmpty);
      expect(BackupService.validateBackupJson(jsonStr), isTrue);
      expect(jsonStr, contains('"app": "ToolBox Pro"'));
      expect(jsonStr, contains('"version": 1'));
      expect(jsonStr, contains('"favorite_tools"'));
      expect(jsonStr, contains('"recent_tools"'));
      expect(jsonStr, contains('"calc_history"'));
    });

    test('validateBackupJson rejects invalid and corrupt payloads', () {
      expect(BackupService.validateBackupJson(''), isFalse);
      expect(BackupService.validateBackupJson('{ invalid json }'), isFalse);
      expect(BackupService.validateBackupJson('{"app": "Another App"}'), isFalse);
      expect(BackupService.validateBackupJson('{"random_key": 123}'), isFalse);
    });

    test('importBackupJson accurately restores preferences and favorites', () async {
      final prefs = PreferencesService();

      const mockBackup = '''
      {
        "app": "ToolBox Pro",
        "version": 1,
        "favorite_tools": ["age_calc", "kitchen_calc", "gpa_calc"],
        "recent_tools": ["gst_calc", "unit_converter"],
        "custom_category_order": ["kitchen", "finance", "math"],
        "theme_mode": "dark",
        "haptic_feedback": false,
        "app_language": "ta",
        "font_scale": 1.15,
        "show_favorites": true,
        "show_recents": false
      }
      ''';

      final success = await BackupService.importBackupJson(mockBackup, prefs);
      expect(success, isTrue);

      // Verify restored preferences
      expect(prefs.favoriteToolIds.contains('kitchen_calc'), isTrue);
      expect(prefs.favoriteToolIds.contains('gpa_calc'), isTrue);
      expect(prefs.recentToolIds.contains('gst_calc'), isTrue);
      expect(prefs.hapticEnabled, isFalse);
      expect(prefs.appLanguage, 'ta');
      expect(prefs.fontScale, 1.15);
      expect(prefs.showRecents, isFalse);
    });
  });
}
