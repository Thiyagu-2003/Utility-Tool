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
  Color _previewColor = AppColors.primaryOrange;

  @override
  void initState() {
    super.initState();
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
        _jsonStatus = 'Invalid JSON: ${e.toString()}';
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
        _jsonStatus = 'Invalid JSON: ${e.toString()}';
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
      final bytes = base64.decode(_base64InputController.text.trim());
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
    final random = math.Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1

    final hexStr = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final uuid = '${hexStr.substring(0, 8)}-${hexStr.substring(8, 12)}-${hexStr.substring(12, 16)}-${hexStr.substring(16, 20)}-${hexStr.substring(20, 32)}';
    setState(() {
      _generatedUuid = uuid;
    });
  }

  void _parseHexColor(String hex) {
    String clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      clean = 'FF$clean';
    }
    if (clean.length == 8) {
      final intVal = int.tryParse(clean, radix: 16);
      if (intVal != null) {
        setState(() {
          _previewColor = Color(intVal);
        });
      }
    }
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _base64InputController.dispose();
    _base64OutputController.dispose();
    _hexController.dispose();
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
                    _jsonStatus = 'Error: ${e.toString()}';
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
                    color: _previewColor.withOpacity(0.4),
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
              primaryResult: '#${_previewColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
              subtitle: 'RGB(${_previewColor.red}, ${_previewColor.green}, ${_previewColor.blue})',
              accentColor: _previewColor,
              breakdowns: [
                BreakdownItem(
                  label: 'Red (R)',
                  value: _previewColor.red.toString(),
                ),
                BreakdownItem(
                  label: 'Green (G)',
                  value: _previewColor.green.toString(),
                ),
                BreakdownItem(
                  label: 'Blue (B)',
                  value: _previewColor.blue.toString(),
                ),
                BreakdownItem(
                  label: 'Opacity',
                  value: '${(_previewColor.opacity * 100).toInt()}%',
                ),
              ],
            ),
            const SizedBox(height: 20),
            ModernTextField(
              label: 'Enter Hex Color (e.g. #FF6D00)',
              controller: _hexController,
              hintText: '#FF6D00',
              prefixIcon: Icons.colorize_rounded,
              onChanged: _parseHexColor,
            ),
          ],
        ],
      ),
    );
  }
}
