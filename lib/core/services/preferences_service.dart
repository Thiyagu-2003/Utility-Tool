import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tool_model.dart';
import 'vibration_service.dart';

class CalculationRecord {
  final String id;
  final String toolTitle;
  final String expression;
  final String result;
  final DateTime timestamp;

  CalculationRecord({
    required this.id,
    required this.toolTitle,
    required this.expression,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'toolTitle': toolTitle,
    'expression': expression,
    'result': result,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CalculationRecord.fromJson(Map<String, dynamic> json) => CalculationRecord(
    id: json['id'] ?? '',
    toolTitle: json['toolTitle'] ?? '',
    expression: json['expression'] ?? '',
    result: json['result'] ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
  );
}

class QrScanRecord {
  final String id;
  final String content;
  final String format;
  final DateTime timestamp;

  QrScanRecord({
    required this.id,
    required this.content,
    required this.format,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'format': format,
    'timestamp': timestamp.toIso8601String(),
  };

  factory QrScanRecord.fromJson(Map<String, dynamic> json) => QrScanRecord(
    id: json['id'] ?? '',
    content: json['content'] ?? '',
    format: json['format'] ?? 'QR_CODE',
    timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
  );
}

class PreferencesService extends ChangeNotifier {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  final Set<String> _favoriteToolIds = {};
  final List<String> _recentToolIds = [];
  final List<CalculationRecord> _calculationHistory = [];
  final List<QrScanRecord> _qrScanHistory = [];
  ThemeMode _themeMode = ThemeMode.system;
  bool _hapticEnabled = true;

  static const List<ToolCategory> defaultCategories = [
    ToolCategory.calculate,
    ToolCategory.convert,
    ToolCategory.dateTime,
    ToolCategory.finance,
    ToolCategory.health,
    ToolCategory.education,
    ToolCategory.homeTravel,
    ToolCategory.filesText,
    ToolCategory.developer,
    ToolCategory.security,
    ToolCategory.kitchen,
    ToolCategory.moreTools,
  ];

  final List<ToolCategory> _categoryOrder = [];
  List<ToolCategory> get categoryOrder => List.unmodifiable(_categoryOrder);

  Set<String> get favoriteToolIds => _favoriteToolIds;
  List<String> get recentToolIds => _recentToolIds;
  List<CalculationRecord> get calculationHistory => _calculationHistory;
  List<QrScanRecord> get qrScanHistory => _qrScanHistory;
  ThemeMode get themeMode => _themeMode;
  bool get hapticEnabled => _hapticEnabled;

  String _appLanguage = 'en';
  double _fontScale = 1.0;
  bool _showFavorites = true;
  bool _showRecents = true;
  bool _hasSeenOnboarding = false;

  String get appLanguage => _appLanguage;
  double get fontScale => _fontScale;
  bool get showFavorites => _showFavorites;
  bool get showRecents => _showRecents;
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();

    // Favorites
    final favList = _prefs.getStringList('favorite_tools') ?? ['age_calc', 'gst_calc', 'discount_calc', 'unit_converter'];
    _favoriteToolIds.addAll(favList);

    // Recents
    final recents = _prefs.getStringList('recent_tools') ?? [];
    _recentToolIds.addAll(recents);

    // History
    final historyJson = _prefs.getStringList('calc_history') ?? [];
    for (final str in historyJson) {
      try {
        _calculationHistory.add(CalculationRecord.fromJson(jsonDecode(str)));
      } catch (_) {}
    }

    // QR Scan History
    final qrHistoryJson = _prefs.getStringList('qr_scan_history') ?? [];
    for (final str in qrHistoryJson) {
      try {
        _qrScanHistory.add(QrScanRecord.fromJson(jsonDecode(str)));
      } catch (_) {}
    }

    // Category Order
    final savedCatNames = _prefs.getStringList('custom_category_order');
    if (savedCatNames != null && savedCatNames.isNotEmpty) {
      for (final name in savedCatNames) {
        try {
          final cat = ToolCategory.values.firstWhere((c) => c.name == name);
          if (defaultCategories.contains(cat) && !_categoryOrder.contains(cat)) {
            _categoryOrder.add(cat);
          }
        } catch (_) {}
      }
      for (final cat in defaultCategories) {
        if (!_categoryOrder.contains(cat)) {
          _categoryOrder.add(cat);
        }
      }
    } else {
      _categoryOrder.addAll(defaultCategories);
    }

    // Theme Mode
    final themeStr = _prefs.getString('theme_mode') ?? 'system';
    switch (themeStr) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }

    // Haptics
    _hapticEnabled = _prefs.getBool('haptic_feedback') ?? true;

    // Language & Accessibility & Home customization
    _appLanguage = _prefs.getString('app_language') ?? 'en';
    _fontScale = _prefs.getDouble('font_scale') ?? 1.0;
    _showFavorites = _prefs.getBool('show_favorites') ?? true;
    _showRecents = _prefs.getBool('show_recents') ?? true;
    _hasSeenOnboarding = _prefs.getBool('has_seen_onboarding') ?? false;

    _initialized = true;
    notifyListeners();
  }

  Future<void> reorderCategory(int oldIndex, int newIndex) async {
    triggerSelectionHaptic();
    if (oldIndex < 0 || oldIndex >= _categoryOrder.length) return;
    if (newIndex < 0 || newIndex > _categoryOrder.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _categoryOrder.removeAt(oldIndex);
    _categoryOrder.insert(newIndex, item);
    await _prefs.setStringList(
      'custom_category_order',
      _categoryOrder.map((c) => c.name).toList(),
    );
    notifyListeners();
  }

  Future<void> moveCategoryToTop(ToolCategory category) async {
    triggerHaptic();
    final index = _categoryOrder.indexOf(category);
    if (index > 0) {
      final item = _categoryOrder.removeAt(index);
      _categoryOrder.insert(0, item);
      await _prefs.setStringList(
        'custom_category_order',
        _categoryOrder.map((c) => c.name).toList(),
      );
      notifyListeners();
    }
  }

  Future<void> resetCategoryOrder() async {
    triggerHaptic();
    _categoryOrder.clear();
    _categoryOrder.addAll(defaultCategories);
    await _prefs.remove('custom_category_order');
    notifyListeners();
  }

  bool isFavorite(String toolId) => _favoriteToolIds.contains(toolId);

  Future<void> toggleFavorite(String toolId) async {
    triggerHaptic();
    if (_favoriteToolIds.contains(toolId)) {
      _favoriteToolIds.remove(toolId);
    } else {
      _favoriteToolIds.add(toolId);
    }
    await _prefs.setStringList('favorite_tools', _favoriteToolIds.toList());
    notifyListeners();
  }

  Future<void> addRecent(String toolId) async {
    _recentToolIds.remove(toolId);
    _recentToolIds.insert(0, toolId);
    if (_recentToolIds.length > 12) {
      _recentToolIds.removeLast();
    }
    await _prefs.setStringList('recent_tools', _recentToolIds);
    notifyListeners();
  }

  Future<void> addCalculationRecord({
    required String toolTitle,
    required String expression,
    required String result,
  }) async {
    final record = CalculationRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      toolTitle: toolTitle,
      expression: expression,
      result: result,
      timestamp: DateTime.now(),
    );
    _calculationHistory.insert(0, record);
    if (_calculationHistory.length > 50) {
      _calculationHistory.removeLast();
    }
    final encoded = _calculationHistory.map((r) => jsonEncode(r.toJson())).toList();
    await _prefs.setStringList('calc_history', encoded);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _calculationHistory.clear();
    await _prefs.remove('calc_history');
    notifyListeners();
  }

  Future<void> addQrScanRecord({
    required String content,
    String format = 'QR_CODE',
  }) async {
    final record = QrScanRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      format: format,
      timestamp: DateTime.now(),
    );
    _qrScanHistory.removeWhere((r) => r.content == content);
    _qrScanHistory.insert(0, record);
    if (_qrScanHistory.length > 50) {
      _qrScanHistory.removeLast();
    }
    final encoded = _qrScanHistory.map((r) => jsonEncode(r.toJson())).toList();
    await _prefs.setStringList('qr_scan_history', encoded);
    notifyListeners();
  }

  Future<void> removeQrScanRecord(String id) async {
    _qrScanHistory.removeWhere((r) => r.id == id);
    final encoded = _qrScanHistory.map((r) => jsonEncode(r.toJson())).toList();
    await _prefs.setStringList('qr_scan_history', encoded);
    notifyListeners();
  }

  Future<void> clearQrHistory() async {
    _qrScanHistory.clear();
    await _prefs.remove('qr_scan_history');
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await _prefs.setString('theme_mode', modeStr);
    notifyListeners();
  }

  Future<void> toggleHaptics(bool enabled) async {
    _hapticEnabled = enabled;
    await _prefs.setBool('haptic_feedback', enabled);
    notifyListeners();
  }

  Future<void> clearRecents() async {
    _recentToolIds.clear();
    await _prefs.remove('recent_tools');
    notifyListeners();
  }

  Future<void> setAppLanguage(String lang) async {
    _appLanguage = lang;
    await _prefs.setString('app_language', lang);
    notifyListeners();
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    await _prefs.setDouble('font_scale', scale);
    notifyListeners();
  }

  Future<void> toggleShowFavorites(bool show) async {
    _showFavorites = show;
    await _prefs.setBool('show_favorites', show);
    notifyListeners();
  }

  Future<void> toggleShowRecents(bool show) async {
    _showRecents = show;
    await _prefs.setBool('show_recents', show);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _hasSeenOnboarding = true;
    await _prefs.setBool('has_seen_onboarding', true);
    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    _hasSeenOnboarding = false;
    await _prefs.setBool('has_seen_onboarding', false);
    notifyListeners();
  }

  Future<void> restoreFromBackupMap(Map<String, dynamic> data) async {
    // Favorites
    if (data['favorite_tools'] is List) {
      _favoriteToolIds.clear();
      _favoriteToolIds.addAll((data['favorite_tools'] as List).map((e) => e.toString()));
      await _prefs.setStringList('favorite_tools', _favoriteToolIds.toList());
    }

    // Recents
    if (data['recent_tools'] is List) {
      _recentToolIds.clear();
      _recentToolIds.addAll((data['recent_tools'] as List).map((e) => e.toString()));
      await _prefs.setStringList('recent_tools', _recentToolIds);
    }

    // Category Order
    if (data['custom_category_order'] is List) {
      _categoryOrder.clear();
      for (final name in data['custom_category_order']) {
        try {
          final cat = ToolCategory.values.firstWhere((c) => c.name == name);
          _categoryOrder.add(cat);
        } catch (_) {}
      }
      for (final cat in defaultCategories) {
        if (!_categoryOrder.contains(cat)) _categoryOrder.add(cat);
      }
      await _prefs.setStringList('custom_category_order', _categoryOrder.map((c) => c.name).toList());
    }

    // Calculation History
    if (data['calc_history'] is List) {
      _calculationHistory.clear();
      for (final item in data['calc_history']) {
        try {
          _calculationHistory.add(CalculationRecord.fromJson(item));
        } catch (_) {}
      }
      final encoded = _calculationHistory.map((r) => jsonEncode(r.toJson())).toList();
      await _prefs.setStringList('calc_history', encoded);
    }

    // QR Scan History
    if (data['qr_scan_history'] is List) {
      _qrScanHistory.clear();
      for (final item in data['qr_scan_history']) {
        try {
          _qrScanHistory.add(QrScanRecord.fromJson(item));
        } catch (_) {}
      }
      final encoded = _qrScanHistory.map((r) => jsonEncode(r.toJson())).toList();
      await _prefs.setStringList('qr_scan_history', encoded);
    }

    // Theme Mode
    if (data['theme_mode'] is String) {
      final themeStr = data['theme_mode'] as String;
      if (themeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      await _prefs.setString('theme_mode', themeStr);
    }

    // Haptics
    if (data['haptic_feedback'] is bool) {
      _hapticEnabled = data['haptic_feedback'] as bool;
      await _prefs.setBool('haptic_feedback', _hapticEnabled);
    }

    // Language & Accessibility & Home
    if (data['app_language'] is String) {
      _appLanguage = data['app_language'] as String;
      await _prefs.setString('app_language', _appLanguage);
    }
    if (data['font_scale'] is num) {
      _fontScale = (data['font_scale'] as num).toDouble();
      await _prefs.setDouble('font_scale', _fontScale);
    }
    if (data['show_favorites'] is bool) {
      _showFavorites = data['show_favorites'] as bool;
      await _prefs.setBool('show_favorites', _showFavorites);
    }
    if (data['show_recents'] is bool) {
      _showRecents = data['show_recents'] as bool;
      await _prefs.setBool('show_recents', _showRecents);
    }

    notifyListeners();
  }

  void triggerHaptic() {
    if (_hapticEnabled) {
      VibrationService.lightImpact();
    }
  }

  void triggerSelectionHaptic() {
    if (_hapticEnabled) {
      VibrationService.selectionClick();
    }
  }
}
