import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utility_tool/core/localization/app_localizations.dart';
import 'package:utility_tool/core/models/tool_model.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/core/services/backup_service.dart';
import 'package:utility_tool/core/services/preferences_service.dart';
import 'package:utility_tool/core/services/search_calculator_service.dart';
import 'package:utility_tool/features/slate/slate_models.dart';
import 'package:utility_tool/features/slate/slate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // PreferencesService is a singleton that only init()s once per process, so the
  // saved state below (an order from before the category split) is what it loads.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'custom_category_order': ['kitchen', 'filesText', 'calculate', 'calculate', 'all'],
    });
    await PreferencesService().init();
  });

  group('Category order', () {
    test('saved order with removed filesText still yields all 18 home categories', () {
      final order = PreferencesService().categoryOrder;
      expect(order.first, ToolCategory.kitchen);
      expect(order[1], ToolCategory.calculate);
      expect(order.length, PreferencesService.defaultCategories.length);
      expect(order.toSet().length, order.length);
      expect(order, isNot(contains(ToolCategory.all)));
      expect(order.toSet(), PreferencesService.defaultCategories.toSet());
    });

    test('defaultCategories covers every real category exactly once', () {
      final real = ToolCategory.values.where((c) => c != ToolCategory.all).toSet();
      expect(PreferencesService.defaultCategories.toSet(), real);
      expect(PreferencesService.defaultCategories.length, 18);
    });

    test('restoring a backup order drops all/unknown/duplicate names', () async {
      final prefs = PreferencesService();
      await prefs.restoreFromBackupMap({
        'custom_category_order': ['all', 'finance', 'finance', 'filesText', 42, 'kitchen'],
      });
      final order = prefs.categoryOrder;
      expect(order.take(2), [ToolCategory.finance, ToolCategory.kitchen]);
      expect(order, isNot(contains(ToolCategory.all)));
      expect(order.length, 18);
      expect(order.toSet().length, 18);
    });
  });

  group('Backup restore with bad data', () {
    test('unsupported language and out-of-range font scale are rejected/clamped', () async {
      final prefs = PreferencesService();
      await prefs.setAppLanguage('en');
      await prefs.restoreFromBackupMap({'app_language': 'xx', 'font_scale': 9.0});
      expect(prefs.appLanguage, 'en');
      expect(prefs.fontScale, 1.3);

      await prefs.restoreFromBackupMap({'font_scale': 0.1});
      expect(prefs.fontScale, 1.0);
    });

    test('recents are de-duplicated, capped at 12 and non-strings dropped', () async {
      final prefs = PreferencesService();
      final ids = ['gst_calc', 'gst_calc', null, 5, ...List.generate(20, (i) => 'tool_$i')];
      await prefs.restoreFromBackupMap({'recent_tools': ids, 'favorite_tools': ['age_calc', null]});
      expect(prefs.recentToolIds.length, 12);
      expect(prefs.recentToolIds.first, 'gst_calc');
      expect(prefs.recentToolIds.toSet().length, 12);
      expect(prefs.favoriteToolIds, {'age_calc'});
    });

    test('import survives garbage history entries', () async {
      final prefs = PreferencesService();
      final ok = await BackupService.importBackupJson(
        jsonEncode({
          'app': 'ToolBox Pro',
          'calc_history': [
            'nonsense',
            {'id': '1', 'toolTitle': 'GST', 'expression': '100+18%', 'result': '118', 'timestamp': 'bad'},
          ],
        }),
        prefs,
      );
      expect(ok, isTrue);
      expect(prefs.calculationHistory.length, 1);
      expect(prefs.calculationHistory.first.toolTitle, 'GST');
    });
  });

  group('Registry ids', () {
    test('tool ids are unique and unknown ids resolve to null', () {
      final ids = ToolRegistry.allTools.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ToolRegistry.findById('battery_display_info'), isNull);
      expect(ToolRegistry.findById('slate'), isNotNull);
    });

    test('every home category has at least one tool', () {
      for (final cat in PreferencesService.defaultCategories) {
        expect(ToolRegistry.getByCategory(cat), isNotEmpty, reason: cat.name);
      }
    });
  });

  group('Search calculator edge cases', () {
    test('% between operands is modulo, trailing % is percent', () {
      expect(SearchCalculatorService.evaluate('10%3')?.result, '1');
      expect(SearchCalculatorService.evaluate('200+10%')?.result, '200.1');
    });

    test('non-finite and malformed input returns null instead of throwing', () {
      expect(SearchCalculatorService.evaluate('1/0'), isNull);
      expect(SearchCalculatorService.evaluate('0/0'), isNull);
      expect(SearchCalculatorService.evaluate('2^100000'), isNull);
      expect(SearchCalculatorService.evaluate('5 + * 3'), isNull);
      expect(SearchCalculatorService.evaluate('((2+3'), isNull);
    });
  });

  group('Slate storage', () {
    test('a corrupt saved slate does not hide (and later wipe) the others', () async {
      final good = SlateDocument(
        id: 'ok',
        title: 'Kept',
        updatedAt: DateTime(2026, 1, 1),
        strokes: const [
          SlateStroke(tool: SlateToolType.pen, color: Color(0xFF000000), size: 4, opacity: 1, points: [SlatePoint(1, 2)]),
        ],
      );
      SharedPreferences.setMockInitialValues({
        'slate_saved_slates_list': ['{not json', jsonEncode(good.toJson())],
      });

      final slates = await SlateService().getMySlates();
      expect(slates.map((s) => s.id), ['ok']);
      expect(slates.first.strokes.single.points.single.y, 2);
    });
  });

  group('Category localisation', () {
    const langs = ['en', 'ta', 'hi', 'es'];

    test('every category has a label and description in all four languages', () {
      for (final lang in langs) {
        final loc = AppLocalizations(Locale(lang));
        for (final cat in ToolCategory.values) {
          final label = loc.categoryLabel(cat);
          final desc = loc.categoryDescription(cat);
          expect(label, isNotEmpty, reason: '$lang ${cat.name}');
          expect(label, isNot(startsWith('cat_')), reason: 'missing label key: $lang ${cat.name}');
          expect(desc, isNot(startsWith('cat_')), reason: 'missing description key: $lang ${cat.name}');
        }
      }
    });

    test('English matches the enum, other languages are translated, stale files_text is gone', () {
      final en = AppLocalizations(const Locale('en'));
      for (final cat in PreferencesService.defaultCategories) {
        expect(en.categoryLabel(cat), cat.label);
        expect(en.categoryDescription(cat), cat.description);
        for (final lang in ['ta', 'hi', 'es']) {
          final loc = AppLocalizations(Locale(lang));
          expect(loc.categoryLabel(cat), isNotEmpty);
          expect(loc.categoryDescription(cat), isNot(cat.description), reason: '$lang ${cat.name}');
        }
      }
      expect(en.categoryLabel(ToolCategory.all), 'All Tools');
      for (final lang in langs) {
        expect(AppLocalizations(Locale(lang)).tr('files_text'), 'files_text', reason: 'stale key still defined');
      }
    });

    test('unknown languages fall back to English', () {
      final fr = AppLocalizations(const Locale('fr'));
      expect(fr.categoryLabel(ToolCategory.kitchen), 'Kitchen');
    });
  });

  group('Category reordering', () {
    test('moveCategory takes the final index, reorderCategory keeps the legacy semantics', () async {
      final prefs = PreferencesService();
      final d = PreferencesService.defaultCategories;

      await prefs.resetCategoryOrder();
      await prefs.moveCategory(0, 2);
      expect(prefs.categoryOrder.take(3), [d[1], d[2], d[0]]);

      await prefs.resetCategoryOrder();
      await prefs.reorderCategory(0, 3); // old onReorder reported the slot before removal
      expect(prefs.categoryOrder.take(3), [d[1], d[2], d[0]]);

      await prefs.resetCategoryOrder();
      await prefs.moveCategory(3, 0);
      expect(prefs.categoryOrder.first, d[3]);
      await prefs.moveCategory(0, 99); // out of range is ignored
      await prefs.moveCategory(-1, 0);
      expect(prefs.categoryOrder.first, d[3]);
      expect(prefs.categoryOrder.length, d.length);
      await prefs.resetCategoryOrder();
    });
  });

  group('Backup restore details', () {
    test('history is capped at 50 and an unknown theme_mode falls back to system', () async {
      final prefs = PreferencesService();
      final many = List.generate(
        80,
        (i) => {'id': '$i', 'toolTitle': 'T', 'expression': '$i+1', 'result': '${i + 1}', 'timestamp': '2026-01-01T00:00:00'},
      );
      await prefs.restoreFromBackupMap({'calc_history': many, 'theme_mode': 'banana'});
      expect(prefs.calculationHistory.length, 50);
      expect(prefs.themeMode.name, 'system');
    });
  });

  group('Slate helpers', () {
    test('parseHexColor accepts 6 and 8 digits and rejects junk', () {
      expect(parseHexColor('#EA580C'), const Color(0xFFEA580C));
      expect(parseHexColor('ea580c'), const Color(0xFFEA580C));
      expect(parseHexColor('  #80112233 '), const Color(0x80112233));
      expect(parseHexColor('#FFF'), isNull);
      expect(parseHexColor('#GGGGGG'), isNull);
      expect(parseHexColor('-12345'), isNull);
      expect(parseHexColor(''), isNull);
    });

    test('colorToHex round-trips and drops alpha', () {
      expect(colorToHex(const Color(0xFF0F172A)), '#0F172A');
      expect(colorToHex(const Color(0x80FFFFFF)), '#FFFFFF');
      expect(parseHexColor(colorToHex(const Color(0xFFEA580C))), const Color(0xFFEA580C));
    });

    test('pngFileName sanitises the title and always ends in .png', () {
      expect(SlateService.pngFileName('My slate'), 'My slate.png');
      expect(SlateService.pngFileName('a/b:c'), 'a_b_c.png');
      expect(SlateService.pngFileName('   '), 'Slate.png');
    });

    test('renameSlate renames only the target and keeps its strokes', () async {
      SlateDocument doc(String id, String title) => SlateDocument(
            id: id,
            title: title,
            updatedAt: DateTime(2026, 1, 1),
            strokes: const [
              SlateStroke(tool: SlateToolType.pen, color: Color(0xFF000000), size: 4, opacity: 1, points: [SlatePoint(1, 2)]),
            ],
          );
      SharedPreferences.setMockInitialValues({
        'slate_saved_slates_list': [jsonEncode(doc('a', 'Old').toJson()), jsonEncode(doc('b', 'Other').toJson())],
      });
      final service = SlateService();

      await service.renameSlate('a', '  New name ');
      var slates = await service.getMySlates();
      expect(slates.firstWhere((s) => s.id == 'a').title, 'New name');
      expect(slates.firstWhere((s) => s.id == 'a').strokes.length, 1);
      expect(slates.firstWhere((s) => s.id == 'b').title, 'Other');

      await service.renameSlate('a', '   '); // blank is ignored
      await service.renameSlate('missing', 'X'); // unknown id is ignored
      slates = await service.getMySlates();
      expect(slates.map((s) => s.title).toSet(), {'New name', 'Other'});

      await service.deleteSlate('a');
      expect((await service.getMySlates()).map((s) => s.id), ['b']);
    });
  });
}
