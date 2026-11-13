import 'dart:convert';
import '../../features/entertainment/entertainment_service.dart';
import 'preferences_service.dart';

class BackupService {
  static String exportBackupJson(PreferencesService prefs) {
    final sp = prefs.rawPrefs;
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

      // Universal content backup:
      if (sp.getString('entertainment_tracker_items_v1') != null)
        'entertainment_tracker_items_v1': jsonDecode(sp.getString('entertainment_tracker_items_v1')!),
      if (sp.getString('prod_notes_list') != null)
        'prod_notes_list': jsonDecode(sp.getString('prod_notes_list')!),
      if (sp.getString('prod_events_list') != null)
        'prod_events_list': jsonDecode(sp.getString('prod_events_list')!),
      if (sp.getString('prod_subscriptions_list') != null)
        'prod_subscriptions_list': jsonDecode(sp.getString('prod_subscriptions_list')!),
      if (sp.getString('prod_bills_list') != null)
        'prod_bills_list': jsonDecode(sp.getString('prod_bills_list')!),
      if (sp.getString('prod_work_sessions_list') != null)
        'prod_work_sessions_list': jsonDecode(sp.getString('prod_work_sessions_list')!),
      if (sp.getString('prod_todos_list') != null)
        'prod_todos_list': jsonDecode(sp.getString('prod_todos_list')!),
      if (sp.getString('prod_reminders_list') != null)
        'prod_reminders_list': jsonDecode(sp.getString('prod_reminders_list')!),
      if (sp.getStringList('prod_note_folders_list') != null)
        'prod_note_folders_list': sp.getStringList('prod_note_folders_list'),
      if (sp.getString('slate_current_canvas_v1') != null)
        'slate_current_canvas_v1': sp.getString('slate_current_canvas_v1'),
      if (sp.getStringList('slate_my_slates_v1') != null)
        'slate_my_slates_v1': sp.getStringList('slate_my_slates_v1'),
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

      final sp = prefs.rawPrefs;

      // Restore Entertainment
      if (data.containsKey('entertainment_tracker_items_v1')) {
        await sp.setString('entertainment_tracker_items_v1', jsonEncode(data['entertainment_tracker_items_v1']));
        EntertainmentService().reload();
      }

      // Restore Productivity
      const prodKeys = [
        'prod_notes_list',
        'prod_events_list',
        'prod_subscriptions_list',
        'prod_bills_list',
        'prod_work_sessions_list',
        'prod_todos_list',
        'prod_reminders_list',
      ];
      for (final k in prodKeys) {
        if (data.containsKey(k)) {
          await sp.setString(k, jsonEncode(data[k]));
        }
      }
      if (data.containsKey('prod_note_folders_list')) {
        final list = List<String>.from(data['prod_note_folders_list']);
        await sp.setStringList('prod_note_folders_list', list);
      }

      // Restore Slate
      if (data.containsKey('slate_current_canvas_v1')) {
        await sp.setString('slate_current_canvas_v1', data['slate_current_canvas_v1'].toString());
      }
      if (data.containsKey('slate_my_slates_v1')) {
        final list = List<String>.from(data['slate_my_slates_v1']);
        await sp.setStringList('slate_my_slates_v1', list);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
