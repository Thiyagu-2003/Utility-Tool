import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/smart_measure_item.dart';
import '../models/measurement_types.dart';

/// Local offline storage service for Smart Measure records.
class SmartMeasureStorageService extends ChangeNotifier {
  static const String _storageKey = 'toolbox_smart_measure_history_v1';

  static final SmartMeasureStorageService _instance = SmartMeasureStorageService._internal();
  factory SmartMeasureStorageService() => _instance;
  SmartMeasureStorageService._internal();

  List<SmartMeasureItem> _items = [];
  bool _isLoaded = false;

  List<SmartMeasureItem> get items => List.unmodifiable(_items);
  bool get isLoaded => _isLoaded;

  /// Initialize and load saved measurements from local SharedPreferences.
  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _items = decoded
            .map((item) => SmartMeasureItem.fromJson(item as Map<String, dynamic>))
            .toList();
        // Sort newest first
        _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      debugPrint('Error loading Smart Measure history: $e');
      _items = [];
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Save a new measurement.
  Future<void> saveMeasurement(SmartMeasureItem item) async {
    _items.insert(0, item);
    await _persist();
    notifyListeners();
  }

  /// Update an existing measurement (e.g. name or notes).
  Future<void> updateMeasurement(String id, {String? name, String? notes}) async {
    final index = _items.indexWhere((m) => m.id == id);
    if (index != -1) {
      if (name != null) _items[index].name = name;
      if (notes != null) _items[index].notes = notes;
      await _persist();
      notifyListeners();
    }
  }

  /// Delete a saved measurement by ID.
  Future<void> deleteMeasurement(String id) async {
    _items.removeWhere((m) => m.id == id);
    await _persist();
    notifyListeners();
  }

  /// Clear all history.
  Future<void> clearAll() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }

  /// Search and filter saved measurements.
  List<SmartMeasureItem> filter({
    String query = '',
    SmartMeasureToolType? toolType,
  }) {
    final clean = query.trim().toLowerCase();
    return _items.where((item) {
      if (toolType != null && item.toolType != toolType) {
        return false;
      }
      if (clean.isNotEmpty) {
        final matchesName = item.name.toLowerCase().contains(clean);
        final matchesType = item.toolType.title.toLowerCase().contains(clean);
        final matchesNotes = item.notes?.toLowerCase().contains(clean) ?? false;
        final matchesVal = item.formattedValue.toLowerCase().contains(clean);
        if (!matchesName && !matchesType && !matchesNotes && !matchesVal) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Generate a clean plain-text audit report of history or a single item.
  String generateTextReport(SmartMeasureItem item) {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('SMART MEASURE - AUDIT REPORT');
    buffer.writeln('========================================');
    buffer.writeln('Name:         ${item.name}');
    buffer.writeln('Tool:         ${item.toolType.title}');
    buffer.writeln('Measured:     ${item.formattedValue}');
    buffer.writeln('Date & Time:  ${item.createdAt.toLocal().toString().split('.').first}');
    buffer.writeln('Confidence:   ${item.confidence.label}');
    if (item.estimatedUncertaintyPercent != null) {
      buffer.writeln('Uncertainty:  ± ${item.estimatedUncertaintyPercent!.toStringAsFixed(1)}%');
    }
    buffer.writeln('Engine:       ${item.capabilityUsed}');
    if (item.notes != null && item.notes!.trim().isNotEmpty) {
      buffer.writeln('Notes:        ${item.notes}');
    }
    if (item.secondaryValues.isNotEmpty) {
      buffer.writeln('----------------------------------------');
      buffer.writeln('Detailed Dimensions:');
      item.secondaryValues.forEach((key, val) {
        buffer.writeln('  • $key: $val');
      });
    }
    buffer.writeln('========================================');
    buffer.writeln('Generated with Toolbox Pro Smart Measure');
    return buffer.toString();
  }

  /// Persist current list to SharedPreferences.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _items.map((item) => item.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving Smart Measure items: $e');
    }
  }
}
