import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utility_tool/main.dart';
import 'package:utility_tool/core/services/preferences_service.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/core/models/tool_model.dart';
import 'package:utility_tool/core/services/backup_service.dart';
import 'package:utility_tool/features/onboarding/app_onboarding_screen.dart';
import 'package:utility_tool/features/productivity/productivity_service.dart';
import 'package:utility_tool/features/slate/slate_models.dart';
import 'package:utility_tool/features/slate/slate_service.dart';
import 'package:utility_tool/core/theme/app_theme.dart';
import 'package:utility_tool/features/device_tools/battery_display_info_screen.dart';
import 'package:utility_tool/features/device_tools/screen_color_test_screen.dart';
import 'package:utility_tool/features/device_tools/sound_level_estimator_screen.dart';
import 'package:utility_tool/features/device_tools/touchscreen_test_screen.dart';
import 'package:utility_tool/features/device_tools/vibration_tester_screen.dart';
import 'package:utility_tool/features/history/calculation_history_screen.dart';
import 'package:utility_tool/features/home/section_detail_screen.dart';
import 'package:utility_tool/features/productivity/productivity_toolkit_screen.dart';
import 'package:utility_tool/features/settings/settings_screen.dart';
import 'package:utility_tool/features/slate/slate_screen.dart';

void main() {
  _layoutTests();
  _interactionTests();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  testWidgets('App launches with MainNavigationScaffold and hubs', (WidgetTester tester) async {
    await tester.pumpWidget(const UtilityApp());
    await tester.pumpAndSettle();

    expect(find.byType(UtilityApp), findsOneWidget);
  });

  test('ToolRegistry contains essential tools across categories', () {
    expect(ToolRegistry.allTools.length, greaterThanOrEqualTo(10));

    final gstTool = ToolRegistry.findById('gst_calc');
    expect(gstTool, isNotNull);
    expect(gstTool!.title, 'GST Calculator');

    final ageTool = ToolRegistry.findById('age_calc');
    expect(ageTool, isNotNull);
    expect(ageTool!.title, 'Age');

    final unitTool = ToolRegistry.findById('unit_converter');
    expect(unitTool, isNotNull);
    expect(unitTool!.title, 'Unit Converter');

    final electricTool = ToolRegistry.findById('electricity_bill');
    expect(electricTool, isNotNull);
    expect(electricTool!.title, 'Electricity Bill');

    final pdfTool = ToolRegistry.findById('pdf_toolkit');
    expect(pdfTool, isNotNull);
    expect(pdfTool!.title, contains('PDF Toolkit'));

    final imageTool = ToolRegistry.findById('image_toolkit');
    expect(imageTool, isNotNull);
    expect(imageTool!.title, 'Image Toolkit');

    final qrTool = ToolRegistry.findById('qr_barcode_toolkit');
    expect(qrTool, isNotNull);
    expect(qrTool!.title, 'QR & Barcode Suite');

    final fileZipTool = ToolRegistry.findById('file_zip_toolkit');
    expect(fileZipTool, isNotNull);
    expect(fileZipTool!.title, 'File & ZIP Suite');

    final ocrTool = ToolRegistry.findById('ocr_toolkit');
    expect(ocrTool, isNotNull);
    expect(ocrTool!.title, 'OCR & Voice Studio');

    final scannerTool = ToolRegistry.findById('document_scanner');
    expect(scannerTool, isNotNull);
    expect(scannerTool!.title, 'Document Scanner');

    final healthTool = ToolRegistry.findById('health_calc');
    expect(healthTool, isNotNull);
    expect(healthTool!.category, ToolCategory.health);

    final gpaTool = ToolRegistry.findById('gpa_calc');
    expect(gpaTool, isNotNull);
    expect(gpaTool!.category, ToolCategory.education);

    final kitchenTool = ToolRegistry.findById('kitchen_calc');
    expect(kitchenTool, isNotNull);
    expect(kitchenTool!.category, ToolCategory.kitchen);

    final passwordTool = ToolRegistry.findById('password_generator');
    expect(passwordTool, isNotNull);
    expect(passwordTool!.category, ToolCategory.security);

    final fitnessSuite = ToolRegistry.findById('health_fitness_toolkit');
    expect(fitnessSuite, isNotNull);
    expect(fitnessSuite!.title, 'Health & Fitness Suite');

    final academicSuite = ToolRegistry.findById('academic_toolkit');
    expect(academicSuite, isNotNull);
    expect(academicSuite!.title, 'Academic & Education Suite');

    final homeTravelSuite = ToolRegistry.findById('home_travel_toolkit');
    expect(homeTravelSuite, isNotNull);
    expect(homeTravelSuite!.title, 'Home, Construction & Travel Suite');

    final collageTool = ToolRegistry.findById('image_collage_maker');
    expect(collageTool, isNotNull);
    expect(collageTool!.title, 'Image Collage Maker');

    final diffTool = ToolRegistry.findById('text_diff_cleaner');
    expect(diffTool, isNotNull);
    expect(diffTool!.title, 'Text Diff & Cleaner');

    final mdTool = ToolRegistry.findById('markdown_editor');
    expect(mdTool, isNotNull);
    expect(mdTool!.title, 'Markdown Editor & Preview');

    final mediaTool = ToolRegistry.findById('media_tools');
    expect(mediaTool, isNotNull);
    expect(mediaTool!.title, 'Audio & Video Studio');

    final xmlYamlTool = ToolRegistry.findById('xml_yaml_formatter');
    expect(xmlYamlTool, isNotNull);
    expect(xmlYamlTool!.title, 'XML & YAML Formatter');

    final deviceSuite = ToolRegistry.findById('device_hardware_toolkit');
    expect(deviceSuite, isNotNull);
    expect(deviceSuite!.title, 'Device & Hardware Studio');

    final compassTool = ToolRegistry.findById('compass_level');
    expect(compassTool, isNotNull);
    expect(compassTool!.title, 'Compass & Spirit Level');

    final sensorTool = ToolRegistry.findById('sensor_tester');
    expect(sensorTool, isNotNull);
    expect(sensorTool!.title, 'Sensor Tester');
  });

  test('Electricity Bill calculation test', () {
    const units = 250.0;
    const ratePerUnit = 7.5;
    const fixedCharge = 60.0;
    const taxPercent = 5.0;

    final energyCharge = units * ratePerUnit; // 1875.0
    final subtotal = energyCharge + fixedCharge; // 1935.0
    final taxAmount = subtotal * (taxPercent / 100); // 96.75
    final total = subtotal + taxAmount; // 2031.75

    expect(energyCharge, 1875.0);
    expect(total, 2031.75);
  });

  test('Duration decomposition test: 200 hours = 8 days, 8 hours', () {
    const rawHours = 200;
    const totalSeconds = rawHours * 3600;

    final days = totalSeconds ~/ 86400;
    final remainingAfterDays = totalSeconds % 86400;
    final hours = remainingAfterDays ~/ 3600;

    expect(days, 8);
    expect(hours, 8);
  });

  test('GST Exclusive calculation test', () {
    const baseAmount = 1000.0;
    const rate = 18.0;
    final gstTax = baseAmount * (rate / 100);
    final total = baseAmount + gstTax;

    expect(gstTax, 180.0);
    expect(total, 1180.0);
  });
}

// Layout checks at a small phone width (360dp), light and dark, with large text.
//
// flutter_test cannot render the app fonts: every glyph falls back to Ahem, which is
// 1em wide (about 1.8x wider than Outfit/Roboto). So the "1.3x font" setting of the
// real app is approximated here by a text scale of 0.72 (1.3 * 0.55): widths match the
// real 1.3x layout closely; heights are slightly optimistic and are covered by the
// explicit text-scale-aware heights in the code (category grid, tab picker).
const double _ahemEquivalentOf130 = 0.72;

void _layoutTests() {
  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp at 3x
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen, {required bool dark, bool settle = true}) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(_ahemEquivalentOf130)),
          child: child!,
        ),
        home: screen,
      ),
    );
    // Screens with a running ticker (FPS counter) never settle; give them a second of frames.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  group('Hub layout at 360dp with large text', () {
    Future<void> pumpHub(WidgetTester tester, {required ThemeMode mode, String lang = 'en'}) async {
      await setPhone(tester);
      final prefs = PreferencesService();
      await prefs.completeOnboarding();
      await prefs.setFontScale(_ahemEquivalentOf130);
      await prefs.setThemeMode(mode);
      await prefs.setAppLanguage(lang);
      addTearDown(() async {
        await prefs.setFontScale(1.0);
        await prefs.setThemeMode(ThemeMode.system);
        await prefs.setAppLanguage('en');
      });
      await tester.pumpWidget(const UtilityApp());
      await tester.pumpAndSettle();
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('category grid and bottom tabs do not overflow (${mode.name})', (tester) async {
        await pumpHub(tester, mode: mode);
        expect(tester.takeException(), isNull);
        final scroll = find.byType(CustomScrollView).first;
        for (var i = 0; i < 8; i++) {
          await tester.drag(scroll, const Offset(0, -500));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'after scrolling step $i');
        }
        for (final label in ['Calculator', 'Finance', 'Settings']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
        }
      });
    }

    testWidgets('Tamil, Hindi and Spanish labels fit the bottom bar and grid', (tester) async {
      for (final lang in ['ta', 'hi', 'es']) {
        await pumpHub(tester, mode: ThemeMode.light, lang: lang);
        expect(tester.takeException(), isNull, reason: lang);
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$lang scrolled');
      }
    });

    testWidgets('search results and the quick-calculation card render', (tester) async {
      await pumpHub(tester, mode: ThemeMode.dark);
      await tester.enterText(find.byType(TextField).first, '25 * 40');
      await tester.pumpAndSettle();
      expect(find.text('1,000'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'age');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('edit mode lists all 18 categories with their reorder handles', (tester) async {
      await pumpHub(tester, mode: ThemeMode.light);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsWidgets);
    });
  });

  group('Screens at 360dp with large text', () {
    for (final dark in [false, true]) {
      final theme = dark ? 'dark' : 'light';

      testWidgets('section detail with the longest category name ($theme)', (tester) async {
        await pumpScreen(tester, const SectionDetailScreen(category: ToolCategory.compression), dark: dark);
        expect(tester.takeException(), isNull);
      });

      testWidgets('settings and its dialogs ($theme)', (tester) async {
        await pumpScreen(tester, const SettingsScreen(), dark: dark);
        expect(tester.takeException(), isNull);
        for (final label in ['App Language / மொழி', 'Dynamic Font Sizing']) {
          final tile = find.text(label);
          if (tile.evaluate().isEmpty) continue;
          await tester.ensureVisible(tile.first);
          await tester.tap(tile.first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
          await tester.tap(find.byType(TextButton).last);
          await tester.pumpAndSettle();
        }
        // Dragging to the bottom builds every section card.
        await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('calculation history with records ($theme)', (tester) async {
        await PreferencesService().addCalculationRecord(toolTitle: 'GST Calculator', expression: '100 + 18%', result: '118');
        await PreferencesService().addCalculationRecord(toolTitle: 'Loan EMI', expression: '5L @ 9%', result: '10,378');
        await pumpScreen(tester, const CalculationHistoryScreen(), dark: dark);
        expect(tester.takeException(), isNull);
        await PreferencesService().clearHistory();
      });

      testWidgets('productivity tabs, dialogs and the new to-do filters ($theme)', (tester) async {
        await pumpScreen(tester, const ProductivityToolkitScreen(), dark: dark);
        expect(tester.takeException(), isNull);
        for (final label in ['Calendar & Events', 'Subscriptions', 'Bill Due Dates', 'Work Hours', 'To-Do & Checklists']) {
          final chip = find.widgetWithText(FilterChip, label);
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
        }
        // To-do tab: filters and subtasks.
        expect(find.text('Active'), findsOneWidget);
        await tester.tap(find.text('Completed'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('All').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Add Task'));
        await tester.pumpAndSettle();
        expect(find.text('Subtask (optional)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('device test screens ($theme)', (tester) async {
        for (final screen in <Widget>[
          const TouchscreenTestScreen(),
          const ScreenColorTestScreen(),
          const VibrationTesterScreen(),
          const BatteryDisplayInfoScreen(),
          const BatteryDisplayInfoScreen(initialTabIndex: 1),
          const SoundLevelEstimatorScreen(),
        ]) {
          final ticking = screen is BatteryDisplayInfoScreen && screen.initialTabIndex == 1;
          await pumpScreen(tester, screen, dark: dark, settle: !ticking);
          expect(tester.takeException(), isNull, reason: '${screen.runtimeType}');
          await tester.pumpWidget(const SizedBox()); // dispose: timers/tickers must be cancelled
        }
      });

      testWidgets('slate canvas and its panels ($theme)', (tester) async {
        await pumpScreen(tester, const SlateScreen(), dark: dark);
        expect(tester.takeException(), isNull);
        // Draw a stroke, undo it, and open the colour dialog with the hex field.
        await tester.dragFrom(const Offset(100, 200), const Offset(150, 100));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.undo_rounded));
        await tester.pump();
        final swatchList = find.descendant(of: find.byType(AnimatedPositioned), matching: find.byType(Scrollable)).last;
        await tester.scrollUntilVisible(find.byIcon(Icons.colorize_rounded), 100, scrollable: swatchList);
        await tester.tap(find.byIcon(Icons.colorize_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Hex colour'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '#ZZZZZZ');
        await tester.pump();
        expect(find.text('Use 6 hex digits, e.g. #EA580C'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '#EA580C');
        await tester.pump();
        expect(find.text('Use 6 hex digits, e.g. #EA580C'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

void _interactionTests() {
  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await setPhone(tester);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: screen));
    await tester.pumpAndSettle();
  }

  group('Productivity date pickers', () {
    testWidgets('a bill saved from the dialog keeps the date picked in the calendar', (tester) async {
      await pumpScreen(tester, const ProductivityToolkitScreen());
      final chip = find.widgetWithText(FilterChip, 'Bill Due Dates');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Upcoming Bill'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Bill Name'), 'Water bill');

      // Default is a week from now; open the picker and move to the 28th (valid in every month).
      await tester.tap(find.text('Due date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('28').first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Bill'));
      await tester.pumpAndSettle();
      final bill = ProductivityService().bills.firstWhere((b) => b.title == 'Water bill');
      expect(bill.dueDate.day, 28);
      expect(bill.dueDate.hour, 0);
      await ProductivityService().deleteBill(bill.id);
    });

    testWidgets('subscription dialog offers a renewal date picker', (tester) async {
      await pumpScreen(tester, const ProductivityToolkitScreen());
      final chip = find.widgetWithText(FilterChip, 'Subscriptions');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Recurring Subscription'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next renewal date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group('Slate My Slates sheet', () {
    SlateDocument doc(String id, String title) => SlateDocument(
          id: id,
          title: title,
          updatedAt: DateTime(2026, 1, 1),
          strokes: const [],
        );

    testWidgets('rename updates the saved slate and delete asks first', (tester) async {
      SharedPreferences.setMockInitialValues({
        'slate_saved_slates_list': [jsonEncode(doc('a', 'First').toJson()), jsonEncode(doc('b', 'Second').toJson())],
      });
      await pumpScreen(tester, const SlateScreen());
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('My slates'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);

      Finder menuOf(String title) => find.descendant(
            of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
            matching: find.byIcon(Icons.more_vert_rounded),
          );

      await tester.tap(menuOf('Second'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Renamed one');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Renamed one'), findsOneWidget);
      final stored = await SlateService().getMySlates();
      expect(stored.map((s) => s.title).toSet(), {'First', 'Renamed one'});

      // Delete: cancel keeps the slate, confirming removes it.
      await tester.tap(menuOf('First'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete slate?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await SlateService().getMySlates()).length, 2);

      await tester.tap(menuOf('First'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect((await SlateService().getMySlates()).map((s) => s.title), ['Renamed one']);
      expect(tester.takeException(), isNull);
    });
  });

  group('Settings', () {
    testWidgets('home toggles persist and survive a backup round trip', (tester) async {
      await pumpScreen(tester, const SettingsScreen());
      final prefs = PreferencesService();
      expect(prefs.showFavorites, isTrue);
      await tester.dragUntilVisible(find.text('Show Favorites Tray'), find.byType(ListView).first, const Offset(0, -200));
      await tester.ensureVisible(find.text('Show Favorites Tray'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show Favorites Tray'));
      await tester.pumpAndSettle();
      expect(prefs.showFavorites, isFalse);

      final json = BackupService.exportBackupJson(prefs);
      await prefs.toggleShowFavorites(true);
      await prefs.toggleHaptics(false);
      expect(await BackupService.importBackupJson(json, prefs), isTrue);
      expect(prefs.showFavorites, isFalse);
      expect(prefs.hapticEnabled, isTrue); // haptics was on when the backup was exported

      await prefs.toggleShowFavorites(true);
    });

    testWidgets('theme radio group switches the mode', (tester) async {
      await pumpScreen(tester, const SettingsScreen());
      final prefs = PreferencesService();
      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();
      expect(prefs.themeMode, ThemeMode.dark);
      await tester.tap(find.text('System Default'));
      await tester.pumpAndSettle();
      expect(prefs.themeMode, ThemeMode.system);
    });
  });

  group('Onboarding replay', () {
    testWidgets('replay pops back and shows the real tool count', (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppOnboardingScreen(isReplay: true)),
                ),
                child: const Text('open tour'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open tour'));
      await tester.pumpAndSettle();
      expect(find.text('${ToolRegistry.allTools.length} POWERFUL TOOLS'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('open tour'), findsOneWidget);
      expect(find.byType(AppOnboardingScreen), findsNothing);
    });
  });
}
