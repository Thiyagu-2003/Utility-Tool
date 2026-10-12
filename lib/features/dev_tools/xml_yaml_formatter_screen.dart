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

const _sampleXml = '''<catalog>
  <book id="bk101"><author>Gambardella, Matthew</author><title>XML Developer's Guide</title><genre>Computer</genre><price>44.95</price><publish_date>2000-10-01</publish_date><description>An in-depth look at creating applications with XML.</description></book>
</catalog>''';
const _sampleYaml = 'server:\n  port: 8080\n  host: "0.0.0.0"\n  enabled: true';

final _blockScalarHeader = RegExp(r'^[|>][+-]?\d?[+-]?$');

/// Result of scanning one line of YAML outside quotes and comments.
typedef _YamlScan = ({int depth, bool openQuote, int colon, int end});

_YamlScan _scanYamlLine(String s, int depthIn) {
  var depth = depthIn, colon = -1, end = s.length;
  String? quote;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (quote != null) {
      if (c == quote) {
        if (quote == "'" && i + 1 < s.length && s[i + 1] == "'") {
          i++; // '' is an escaped single quote
        } else {
          quote = null;
        }
      } else if (c == r'\' && quote == '"') {
        i++;
      }
      continue;
    }
    final prev = i == 0 ? ' ' : s[i - 1];
    final tokenStart = prev == ' ' || prev == '[' || prev == '{' || prev == ',';
    if (c == '#' && prev == ' ') {
      end = i;
      break;
    }
    if (tokenStart && (c == '"' || c == "'")) {
      quote = c;
    } else if (tokenStart && (c == '[' || c == '{')) {
      depth++;
    } else if ((c == ']' || c == '}') && depth > 0) {
      depth--;
    } else if (c == ':' && depth == 0 && colon < 0 && (i + 1 == s.length || s[i + 1] == ' ')) {
      colon = i;
    }
  }
  return (depth: depth, openQuote: quote != null, colon: colon, end: end);
}

/// Structural check for common YAML: tab indentation, inconsistent
/// indentation, duplicate keys, a missing `:`, "mapping values are not
/// allowed here", unterminated quotes and unclosed `[`/`{`.
/// It is NOT a full YAML parser (no anchors/tags/complex-key validation), so
/// it returns null for anything it cannot prove wrong. The message is
/// prefixed with the 1-based line number.
String? validateYamlLite(String text) {
  final lines = text.split('\n');
  final indents = <int>[];
  final keys = <Set<String>>[];
  var flowDepth = 0;
  int? blockScalarIndent;
  var prevHasValue = false;

  String err(int n, String m) => 'Line ${n + 1}: $m';

  // Returns an error when [ind] dedents to a level that was never opened.
  String? enter(int ind, int n) {
    var popped = false;
    while (indents.isNotEmpty && indents.last > ind) {
      indents.removeLast();
      keys.removeLast();
      popped = true;
    }
    if (popped && (indents.isEmpty || indents.last != ind)) {
      return err(n, 'inconsistent indentation');
    }
    if (indents.isEmpty || indents.last < ind) {
      indents.add(ind);
      keys.add(<String>{});
    }
    return null;
  }

  for (var n = 0; n < lines.length; n++) {
    final raw = lines[n].trimRight();
    final trimmed = raw.trimLeft();
    if (trimmed.isEmpty) continue;
    final indent = raw.length - trimmed.length;
    if (blockScalarIndent != null) {
      if (indent > blockScalarIndent) continue;
      blockScalarIndent = null;
    }
    if (trimmed.startsWith('#')) continue;
    if (raw.substring(0, indent).contains('\t')) return err(n, 'tab used for indentation');
    if (indent == 0 && (trimmed == '---' || trimmed == '...' || trimmed.startsWith('--- '))) {
      indents.clear();
      keys.clear();
      prevHasValue = false;
      continue;
    }
    if (flowDepth > 0) {
      final scan = _scanYamlLine(trimmed, flowDepth);
      if (scan.openQuote) return err(n, 'unterminated quoted string');
      flowDepth = scan.depth;
      continue;
    }

    var content = trimmed;
    var effective = indent;
    var dashed = false;
    while (content == '-' || content.startsWith('- ')) {
      dashed = true;
      final rest = content.length == 1 ? '' : content.substring(1);
      final stripped = rest.trimLeft();
      effective += content.length - stripped.length;
      content = stripped;
    }
    if (content.startsWith('? ') || content == '?') continue; // complex keys: not validated
    final scan = _scanYamlLine(content, 0);
    if (scan.openQuote) return err(n, 'unterminated quoted string');

    if (indents.isNotEmpty && indent > indents.last && prevHasValue) {
      if (dashed || scan.colon >= 0) return err(n, 'mapping values are not allowed here');
      // Otherwise it continues the previous multi-line plain scalar.
      flowDepth = scan.depth;
      continue;
    }
    final indentError = enter(indent, n);
    if (indentError != null) return indentError;
    if (dashed && content.isNotEmpty && scan.colon >= 0) {
      final e = enter(effective, n);
      if (e != null) return e;
    }

    prevHasValue = false;
    flowDepth = scan.depth;
    if (content.isEmpty) {
      // A bare "-": its value is nested on the following lines.
    } else if (_blockScalarHeader.hasMatch(content)) {
      blockScalarIndent = indent;
    } else if (scan.colon >= 0) {
      var key = content.substring(0, scan.colon).trim();
      if (key.length >= 2 && (key[0] == '"' || key[0] == "'") && key.endsWith(key[0])) {
        key = key.substring(1, key.length - 1);
      }
      if (!keys.last.add(key)) return err(n, 'duplicate key "$key"');
      final value = content.substring(scan.colon + 1, scan.end).trim();
      if (value.isEmpty) {
        // "key:" with nothing after it: the value is nested on the next lines.
      } else if (_blockScalarHeader.hasMatch(value)) {
        blockScalarIndent = effective;
      } else {
        prevHasValue = scan.depth == 0;
      }
    } else if (!dashed && indents.isNotEmpty && keys.last.isNotEmpty) {
      return err(n, 'expected "key: value" but found no ":"');
    }
  }
  if (flowDepth > 0) return 'Unclosed [ or { at end of input';
  return null;
}

class XmlYamlFormatterScreen extends StatefulWidget {
  const XmlYamlFormatterScreen({super.key});

  @override
  State<XmlYamlFormatterScreen> createState() => _XmlYamlFormatterScreenState();
}

class _XmlYamlFormatterScreenState extends State<XmlYamlFormatterScreen> {
  FormatterMode _mode = FormatterMode.xml;

  final TextEditingController _inputController = TextEditingController(text: _sampleXml);
  // Each mode keeps its own text so switching never discards what was typed.
  String _stashedText = _sampleYaml;

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
          _formattedOutput = '';
          _errorMessage = 'Invalid XML syntax: $e';
        });
      }
      return;
    }

    // JSON is valid YAML, so pretty-print it when it parses as JSON.
    try {
      final decoded = jsonDecode(raw);
      const encoder = JsonEncoder.withIndent('  ');
      setState(() {
        _formattedOutput = encoder.convert(decoded);
        _errorMessage = null;
      });
      return;
    } catch (_) {}
    final problem = validateYamlLite(raw);
    setState(() {
      _formattedOutput = problem == null ? raw.split('\n').map((l) => l.trimRight()).join('\n') : '';
      _errorMessage = problem == null ? null : 'Invalid YAML: $problem';
    });
  }

  void _minifyXml() {
    if (_mode != FormatterMode.xml) return;
    try {
      final document = XmlDocument.parse(_inputController.text.trim());
      setState(() {
        // Pretty-printing with no indent/newline drops the whitespace-only
        // text nodes; pretty: false would keep the original formatting.
        _formattedOutput = document.toXmlString(pretty: true, indent: '', newLine: '');
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _formattedOutput = '';
        _errorMessage = 'Invalid XML: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'XML & YAML Formatter',
      category: ToolCategory.developer,
      toolId: 'xml_yaml_formatter',
      onReset: () {
        _inputController.text = _mode == FormatterMode.xml ? _sampleXml : _sampleYaml;
        _stashedText = _mode == FormatterMode.xml ? _sampleYaml : _sampleXml;
        _formatInput();
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Syntax Validator',
            primaryResult: _errorMessage == null ? 'VALID SYNTAX' : 'SYNTAX ERROR',
            subtitle: _errorMessage ??
                (_mode == FormatterMode.yaml
                    ? '${_formattedOutput.split('\n').length} formatted lines. YAML check covers common syntax only; JSON is fully validated.'
                    : '${_formattedOutput.split('\n').length} formatted lines'),
            accentColor: _errorMessage == null ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<FormatterMode>(
              segments: const [
                ButtonSegment(value: FormatterMode.xml, label: Text('XML')),
                ButtonSegment(value: FormatterMode.yaml, label: Text('YAML / JSON')),
              ],
              selected: {_mode},
              onSelectionChanged: (set) {
                if (set.first == _mode) return;
                final current = _inputController.text;
                _inputController.text = _stashedText;
                _stashedText = current;
                setState(() => _mode = set.first);
                _formatInput();
              },
            ),
          ),
          if (_mode == FormatterMode.xml) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: _minifyXml,
                child: const Text('Minify XML'),
              ),
            ),
          ],
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
              const Flexible(child: Text('Formatted & Validated Output', style: TextStyle(fontWeight: FontWeight.bold))),
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
