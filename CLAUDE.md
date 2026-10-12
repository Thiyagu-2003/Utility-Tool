# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**ToolBox Pro** (package `utility_tool`) is a Flutter app bundling ~49 offline utility tools (calculators, converters, PDF/image/OCR/QR tools, device diagnostics, productivity, a drawing "Slate"). It is fully offline: there is no backend and no network API. Persistence uses `shared_preferences` only. Android is the primary target. `app_features.md` is the feature inventory and release-status document. Update it when you add or change a tool.

## Commands

```bash
flutter pub get
flutter analyze                          # lints: package:flutter_lints/flutter.yaml
flutter test                             # all tests
flutter test test/math_calculation_test.dart              # one file
flutter test --plain-name "ToolRegistry contains"         # one test by name
flutter run                              # run on a connected device or emulator
flutter build apk --release
dart run scratch/convert_icon.dart       # regenerates Android mipmap launcher icons from assets/images/app_icon.png
```

The version lives in `pubspec.yaml` (`version: x.y.z+build`) and is bumped on each release. `app_features.md` states the release version too, so keep the two in sync.

## Architecture

**Tool registry is the spine.** `lib/core/registry/tool_registry.dart` holds `ToolRegistry.allTools`, a static list of `ToolItem` entries (`lib/core/models/tool_model.dart`), each with an `id`, title, description, `ToolCategory`, icon, search `keywords` and a `builder` returning the screen. The home hub, search, favourites, recents and the category screens are all driven from this list. To add a tool:
1. Create the screen under `lib/features/<domain>/`.
2. Add a `ToolItem` to the registry.

Tool `id`s are persisted (favourites, recents, backups), so don't rename existing ones.

**Categories** are the `ToolCategory` enum, which carries the label, icon, colour and description. It also defines backward-compatible static aliases (`calculators`, `text`, `everyday`, …) that map to the current values; keep them, because older code refers to them. `ToolCategory.all` is a pseudo-category handled in `getByCategory`.

**Navigation shell:** `main.dart` → `AppOnboardingScreen` (first run) or `MainNavigationScaffold`, a bottom-nav `IndexedStack` with four tabs: the All-tools `CategoryHubScreen`, `CalculatorScreen`, a finance-focused `CategoryHubScreen` and `SettingsScreen`. Tools open by pushing `tool.builder` and calling `PreferencesService().addRecent(tool.id)`. Slate has a special card in `category_hub_screen.dart` that does the same thing by hand.

**Global state:** `PreferencesService` (`lib/core/services/preferences_service.dart`) is a singleton `ChangeNotifier` (`PreferencesService()` always returns the same instance). It must be `init()`-ed before `runApp`. It owns the theme mode, language, font scale, haptics, category order, favourites, recents, calculation history and QR scan history. `UtilityApp` rebuilds the whole `MaterialApp` through `AnimatedBuilder(animation: prefs)`. There is no Provider/Riverpod/Bloc, and you shouldn't introduce one.

**Backup/restore:** `BackupService` serialises `PreferencesService` state to JSON (tagged `'app': 'ToolBox Pro'`) and restores it through `restoreFromBackupMap`. When you add a persisted preference, wire it into both the export map and `restoreFromBackupMap`. `test/backup_restore_test.dart` covers the round-trip.

**Feature-local persistence:** larger features keep their own data in `SharedPreferences` through a feature service (for example `productivity_service.dart` and `slate_service.dart`), each with a `*_models.dart` beside it. They are not part of `PreferencesService` or the backup.

**Feature layout:** most domains are a single large "toolkit" screen with internal tabs (for example `AcademicToolkitScreen` and `HomeTravelToolkitScreen`), which use `shared/widgets/feature_tab_selector.dart`. Several files run to thousands of lines. Wrap screens in `shared/widgets/tool_scaffold.dart` (`ToolScaffold`, which takes `title`, `category` and `toolId`) and use the shared `ModernTextField`/`ResultCard` for consistency. Pure logic that tests exercise lives in services and utils, for example `archive_compare_service.dart`, `photo_editor_service.dart`, `office_document_service.dart`, `core/utils/validation_utils.dart` and `vcard_utils.dart`.

**Search-as-calculator:** `SearchCalculatorService.evaluate` lets the hub search box evaluate maths expressions and unit queries (through `math_expressions`) as well as filter tools.

**Localization:** `lib/core/localization/app_localizations.dart` is a hand-rolled map supporting `en`, `ta`, `hi` and `es`, with `tr(key)` falling back to English and then to the key itself. Only the app shell and settings use it; most tool screens hard-code English strings. When you add a key, add it to all four language maps.

**Theming:** `core/theme/app_theme.dart` (light and dark `ThemeData`) and `app_colors.dart`. Screens branch on `Theme.of(context).brightness`, so check both themes when changing UI.

## Tests

Tests in `test/` call `SharedPreferences.setMockInitialValues({})` followed by `await PreferencesService().init()` in `setUp`. Because `PreferencesService` is a singleton, state carries over between tests in the same file unless it is reset. Plugin-backed features (camera/ML Kit, sensors, TTS, file picker) aren't unit-tested; the tests target pure logic and services.

## Repo notes

- `reference ui/` holds design reference screenshots, not code.
- `scratch/` holds one-off Dart asset scripts that aren't part of the app.
