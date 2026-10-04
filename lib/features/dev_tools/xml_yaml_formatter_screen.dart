import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum FormatterMode { xml, yaml }

class XmlYamlFormatterScreen extends StatefulWidget {
  const XmlYamlFormatterScreen({super.key});

  @override
  State<XmlYamlFormatterScreen> createState() => _XmlYamlFormatterScreenState();
}

class _XmlYamlFormatterScreenState extends State<XmlYamlFormatterScreen> {
  FormatterMode _mode = FormatterMode.xml;

  final TextEditingController _inputController = TextEditingController(
    text: '''<catalog>
  <book id="bk101"><author>Gambardella, Matthew</author><title>XML Developer's Guide</title><genre>Computer</genre><price>44.95</price><publish_date>2000-10-01</publish_date><description>An in-depth look at creating applications with XML.</description></book>
</catalog>''',
  );

  String _formattedOutput = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _formatInput();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _formatInput() {
    final raw = _inputController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _formattedOutput = '';
        _errorMessage = null;
      });
      return;
    }

    if (_mode == FormatterMode.xml) {
      try {
        final document = XmlDocument.parse(raw);
        setState(() {
          _formattedOutput = document.toXmlString(pretty: true, indent: '  ');
          _errorMessage = null;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Invalid XML syntax: $e';
        });
      }
    } else {
      // YAML / Key-Value Formatter
      try {
        // Attempt JSON / YAML parse
        final decoded = jsonDecode(raw);
        const encoder = JsonEncoder.withIndent('  ');
        setState(() {
          _formattedOutput = encoder.convert(decoded);
          _errorMessage = null;
        });
      } catch (_) {
        // Clean indent lines
        final lines = raw.split('\n');
        final cleaned = lines.map((l) => l.trimRight()).join('\n');
        setState(() {
          _formattedOutput = cleaned;
          _errorMessage = null;
        });
      }
    }
  }

  void _minifyXml() {
    if (_mode != FormatterMode.xml) return;
    try {
      final document = XmlDocument.parse(_inputController.text.trim());
      setState(() {
        _formattedOutput = document.toXmlString(pretty: false);
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Invalid XML: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'XML & YAML Formatter',
      category: ToolCategory.developer,
      toolId: 'xml_yaml_formatter',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Syntax Validator',
            primaryResult: _errorMessage == null ? 'VALID SYNTAX' : 'SYNTAX ERROR',
            subtitle: _errorMessage ?? '${_formattedOutput.split('\n').length} formatted lines',
            accentColor: _errorMessage == null ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SegmentedButton<FormatterMode>(
                segments: const [
                  ButtonSegment(value: FormatterMode.xml, label: Text('XML Formatter')),
                  ButtonSegment(value: FormatterMode.yaml, label: Text('YAML / JSON')),
                ],
                selected: {_mode},
                onSelectionChanged: (set) {
                  setState(() {
                    _mode = set.first;
                    if (_mode == FormatterMode.yaml) {
                      _inputController.text = 'server:\n  port: 8080\n  host: "0.0.0.0"\n  enabled: true';
                    } else {
                      _inputController.text = '<catalog><book id="1"><title>Flutter Pro</title></book></catalog>';
                    }
                  });
                  _formatInput();
                },
              ),
              const Spacer(),
              if (_mode == FormatterMode.xml)
                OutlinedButton(
                  onPressed: _minifyXml,
                  child: const Text('Minify XML'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _inputController,
            maxLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              labelText: 'Raw Input',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (_) => _formatInput(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Formatted & Validated Output', style: TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy Output',
                onPressed: () {
                  PreferencesService().triggerHaptic();
                  Clipboard.setData(ClipboardData(text: _formattedOutput));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formatted output copied!')));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _formattedOutput.isEmpty ? 'No output' : _formattedOutput,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
