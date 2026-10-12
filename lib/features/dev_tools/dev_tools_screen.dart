import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum DevToolTab {
  json('JSON Formatter', Icons.data_object_rounded),
  base64('Base64 / URL', Icons.enhanced_encryption_rounded),
  uuid('UUID Generator', Icons.fingerprint_rounded),
  color('Color (HEX/RGB)', Icons.palette_rounded);

  final String label;
  final IconData icon;
  const DevToolTab(this.label, this.icon);
}

/// Decodes Base64 ignoring whitespace/line breaks, accepting the URL-safe
/// alphabet and missing padding. Throws [FormatException] on invalid input.
List<int> decodeBase64Lenient(String input) =>
    base64.decode(base64.normalize(input.replaceAll(RegExp(r'\s'), '')));

/// Parses CSS-style hex colours: #RGB, #RGBA, #RRGGBB and #RRGGBBAA.
/// Returns null for anything else.
Color? parseHexColor(String hex) {
  var clean = hex.trim();
  if (clean.startsWith('#')) clean = clean.substring(1);
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) return null;
  if (clean.length == 3 || clean.length == 4) {
    clean = clean.split('').map((c) => '$c$c').join();
  }
  if (clean.length == 6) clean = '${clean}FF';
  if (clean.length != 8) return null;
  final rgba = int.parse(clean, radix: 16);
  // Colour expects 0xAARRGGBB, so move the trailing alpha byte to the front.
  return Color(((rgba & 0xFF) << 24) | (rgba >> 8));
}

int _channel(double v) => (v * 255).round().clamp(0, 255);

/// `#RRGGBB`, or `#RRGGBBAA` when [withAlpha] is set (CSS order, alpha last).
String colorToHex(Color c, {bool withAlpha = false}) {
  String h(double v) => _channel(v).toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${h(c.r)}${h(c.g)}${h(c.b)}${withAlpha ? h(c.a) : ''}';
}

/// Builds a colour from 0-255 channels; null when any channel is out of range.
Color? colorFromRgb(int r, int g, int b, {double alpha = 1}) {
  if ([r, g, b].any((v) => v < 0 || v > 255)) return null;
  return Color.fromRGBO(r, g, b, alpha);
}

String _jsonError(Object e) => e is FormatException ? e.message : e.toString();

class DevToolsScreen extends StatefulWidget {
  const DevToolsScreen({super.key});

  @override
  State<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends State<DevToolsScreen> {
  DevToolTab _activeTab = DevToolTab.json;

  // JSON Tab state
  final TextEditingController _jsonController = TextEditingController(
    text: '{"tool":"UtilityApp","version":1.0,"features":["calculator","converter","developer"]}',
  );
  String _jsonStatus = 'Valid JSON';
  bool _isJsonValid = true;

  // Base64 Tab state
  final TextEditingController _base64InputController = TextEditingController(text: 'Hello, World!');
  final TextEditingController _base64OutputController = TextEditingController();

  // UUID Tab state
  String _generatedUuid = '';

  // Color Tab state
  final TextEditingController _hexController = TextEditingController(text: '#FF6D00');
  final TextEditingController _rController = TextEditingController();
  final TextEditingController _gController = TextEditingController();
  final TextEditingController _bController = TextEditingController();
  Color _previewColor = const Color(0xFFFF6D00);
  bool _colorInputValid = true;

  @override
  void initState() {
    super.initState();
    _syncRgbFields(_previewColor);
    _formatJson();
    _encodeBase64();
    _generateUuid();
  }

  void _formatJson() {
    try {
      final parsed = jsonDecode(_jsonController.text);
      const encoder = JsonEncoder.withIndent('  ');
      final formatted = encoder.convert(parsed);
      setState(() {
        _jsonController.text = formatted;
        _isJsonValid = true;
        _jsonStatus = 'Valid JSON (Formatted)';
      });
    } catch (e) {
      setState(() {
        _isJsonValid = false;
        _jsonStatus = 'Invalid JSON: ${_jsonError(e)}';
      });
    }
  }

  void _minifyJson() {
    try {
      final parsed = jsonDecode(_jsonController.text);
      final minified = jsonEncode(parsed);
      setState(() {
        _jsonController.text = minified;
        _isJsonValid = true;
        _jsonStatus = 'Valid JSON (Minified)';
      });
    } catch (e) {
      setState(() {
        _isJsonValid = false;
        _jsonStatus = 'Invalid JSON: ${_jsonError(e)}';
      });
    }
  }

  void _encodeBase64() {
    final bytes = utf8.encode(_base64InputController.text);
    setState(() {
      _base64OutputController.text = base64.encode(bytes);
    });
  }

  void _decodeBase64() {
    try {
      final bytes = decodeBase64Lenient(_base64InputController.text);
      setState(() {
        _base64OutputController.text = utf8.decode(bytes);
      });
    } catch (e) {
      setState(() {
        _base64OutputController.text = 'Decode error: Invalid Base64 string';
      });
    }
  }

  void _urlEncode() {
    setState(() {
      _base64OutputController.text = Uri.encodeComponent(_base64InputController.text);
    });
  }

  void _urlDecode() {
    try {
      setState(() {
        _base64OutputController.text = Uri.decodeComponent(_base64InputController.text);
      });
    } catch (e) {
      setState(() {
        _base64OutputController.text = 'Decode error: Invalid URL encoded string';
      });
    }
  }

  void _generateUuid() {
    PreferencesService().triggerHaptic();
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1

    final hexStr = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final uuid = '${hexStr.substring(0, 8)}-${hexStr.substring(8, 12)}-${hexStr.substring(12, 16)}-${hexStr.substring(16, 20)}-${hexStr.substring(20, 32)}';
    setState(() {
      _generatedUuid = uuid;
    });
  }

  void _syncRgbFields(Color c) {
    _rController.text = _channel(c.r).toString();
    _gController.text = _channel(c.g).toString();
    _bController.text = _channel(c.b).toString();
  }

  void _parseHexColor(String hex) {
    final color = parseHexColor(hex);
    setState(() {
      _colorInputValid = color != null;
      if (color != null) {
        _previewColor = color;
        _syncRgbFields(color);
      }
    });
  }

  void _parseRgb(String _) {
    final r = int.tryParse(_rController.text.trim());
    final g = int.tryParse(_gController.text.trim());
    final b = int.tryParse(_bController.text.trim());
    final color = (r == null || g == null || b == null) ? null : colorFromRgb(r, g, b, alpha: _previewColor.a);
    setState(() {
      _colorInputValid = color != null;
      if (color != null) {
        _previewColor = color;
        _hexController.text = colorToHex(color, withAlpha: color.a < 1);
      }
    });
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _base64InputController.dispose();
    _base64OutputController.dispose();
    _hexController.dispose();
    _rController.dispose();
    _gController.dispose();
    _bController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Developer Tools',
      category: ToolCategory.developer,
      toolId: 'dev_tools',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-tabs
          FeatureTabSelector<DevToolTab>(
            tabs: DevToolTab.values
                .map((tab) => FeatureTabItem(
                      value: tab,
                      label: tab.label,
                      icon: tab.icon,
                    ))
                .toList(),
            activeTab: _activeTab,
            onTabSelected: (tab) {
              setState(() => _activeTab = tab);
            },
            accentColor: AppColors.catDev,
            title: 'Developer Tools',
          ),
          const SizedBox(height: 16),

          // JSON Formatter Tab
          if (_activeTab == DevToolTab.json) ...[
            ResultCard(
              title: 'JSON Status',
              primaryResult: _isJsonValid ? 'Valid Syntax' : 'Syntax Error',
              subtitle: _jsonStatus,
              accentColor: _isJsonValid ? AppColors.catFinance : AppColors.error,
            ),
            const SizedBox(height: 20),
            ModernTextField(
              label: 'JSON Content',
              controller: _jsonController,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              onChanged: (_) {
                try {
                  jsonDecode(_jsonController.text);
                  setState(() {
                    _isJsonValid = true;
                    _jsonStatus = 'Valid JSON';
                  });
                } catch (e) {
                  setState(() {
                    _isJsonValid = false;
                    _jsonStatus = 'Error: ${_jsonError(e)}';
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.format_align_left_rounded),
                    label: const Text('Beautify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.catDev,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _formatJson,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.compress_rounded),
                    label: const Text('Minify'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _minifyJson,
                  ),
                ),
              ],
            ),
          ],

          // Base64 & URL Tab
          if (_activeTab == DevToolTab.base64) ...[
            ModernTextField(
              label: 'Input String',
              controller: _base64InputController,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.catDev, foregroundColor: Colors.white),
                  onPressed: _encodeBase64,
                  child: const Text('Base64 Encode'),
                ),
                OutlinedButton(
                  onPressed: _decodeBase64,
                  child: const Text('Base64 Decode'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.catDev, foregroundColor: Colors.white),
                  onPressed: _urlEncode,
                  child: const Text('URL Encode'),
                ),
                OutlinedButton(
                  onPressed: _urlDecode,
                  child: const Text('URL Decode'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ModernTextField(
              label: 'Output Result',
              controller: _base64OutputController,
              readOnly: true,
              maxLines: 4,
            ),
          ],

          // UUID Generator Tab
          if (_activeTab == DevToolTab.uuid) ...[
            ResultCard(
              title: 'UUID v4 Result',
              primaryResult: _generatedUuid,
              subtitle: 'Cryptographically pseudorandom UUID',
              accentColor: AppColors.catDev,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Generate New UUID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catDev,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _generateUuid,
              ),
            ),
          ],

          // Color Code Converter Tab
          if (_activeTab == DevToolTab.color) ...[
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _previewColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _previewColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'Color Preview',
                style: TextStyle(
                  color: _previewColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ResultCard(
              title: 'Color Formats',
              primaryResult: colorToHex(_previewColor, withAlpha: _previewColor.a < 1),
              subtitle: _colorInputValid
                  ? 'RGB(${_channel(_previewColor.r)}, ${_channel(_previewColor.g)}, ${_channel(_previewColor.b)})'
                  : 'Invalid input, showing the last valid colour',
              accentColor: _colorInputValid ? _previewColor : AppColors.error,
              breakdowns: [
                BreakdownItem(label: 'Red (R)', value: _channel(_previewColor.r).toString()),
                BreakdownItem(label: 'Green (G)', value: _channel(_previewColor.g).toString()),
                BreakdownItem(label: 'Blue (B)', value: _channel(_previewColor.b).toString()),
                BreakdownItem(label: 'Opacity', value: '${(_previewColor.a * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 20),
            ModernTextField(
              label: 'Enter Hex Color (#RGB, #RRGGBB or #RRGGBBAA)',
              controller: _hexController,
              hintText: '#FF6D00',
              prefixIcon: Icons.colorize_rounded,
              onChanged: _parseHexColor,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: ModernTextField(label: 'R (0-255)', controller: _rController, keyboardType: TextInputType.number, onChanged: _parseRgb)),
                const SizedBox(width: 8),
                Expanded(child: ModernTextField(label: 'G (0-255)', controller: _gController, keyboardType: TextInputType.number, onChanged: _parseRgb)),
                const SizedBox(width: 8),
                Expanded(child: ModernTextField(label: 'B (0-255)', controller: _bController, keyboardType: TextInputType.number, onChanged: _parseRgb)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
