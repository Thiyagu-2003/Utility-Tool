import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Set<String> get favoriteToolIds => _favoriteToolIds;
  List<String> get recentToolIds => _recentToolIds;
  List<CalculationRecord> get calculationHistory => _calculationHistory;
  List<QrScanRecord> get qrScanHistory => _qrScanHistory;
  ThemeMode get themeMode => _themeMode;
  bool get hapticEnabled => _hapticEnabled;

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

    _initialized = true;
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

  void triggerHaptic() {
    if (_hapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void triggerSelectionHaptic() {
    if (_hapticEnabled) {
      HapticFeedback.selectionClick();
    }
  }
}
