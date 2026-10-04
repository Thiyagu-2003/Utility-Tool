import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:printing/printing.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class MarkdownEditorScreen extends StatefulWidget {
  const MarkdownEditorScreen({super.key});

  @override
  State<MarkdownEditorScreen> createState() => _MarkdownEditorScreenState();
}

class _MarkdownEditorScreenState extends State<MarkdownEditorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _markdownController = TextEditingController(
    text: '''# Markdown Document

Welcome to the **Markdown Studio**! You can write, preview, and export clean documentation.

## Feature Checklist
- [x] Live formatting & preview
- [x] Syntax helper toolbar
- [ ] Export to .md file

### Code Example
```dart
void main() {
  print("Hello, ToolBox Pro!");
}
```

### Table Example
| Tool | Category | Status |
| :--- | :--- | :--- |
| Markdown Editor | Files & Text | Ready |
| Text Diff | Files & Text | Ready |

> "Simplicity is prerequisite for reliability." — Edsger W. Dijkstra
''',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _markdownController.dispose();
    super.dispose();
  }

  void _insertSyntax(String prefix, [String suffix = '']) {
    PreferencesService().triggerHaptic();
    final text = _markdownController.text;
    final selection = _markdownController.selection;

    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _markdownController.text = newText;
      _markdownController.selection = TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.start + prefix.length + selectedText.length,
      );
    } else {
      final pos = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(pos, pos, '$prefix$suffix');
      _markdownController.text = newText;
      _markdownController.selection = TextSelection.collapsed(offset: pos + prefix.length);
    }
    setState(() {});
  }

  Future<void> _exportMarkdown() async {
    PreferencesService().triggerHaptic();
    final bytes = Uint8List.fromList(utf8.encode(_markdownController.text));
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Document_${DateTime.now().millisecondsSinceEpoch}.md',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final words = _markdownController.text.trim().isEmpty
        ? 0
        : _markdownController.text.trim().split(RegExp(r'\s+')).length;
    final chars = _markdownController.text.length;

    return ToolScaffold(
      title: 'Markdown Editor & Preview',
      category: ToolCategory.filesText,
      toolId: 'markdown_editor',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Document Metrics',
            primaryResult: '$words Words',
            subtitle: '$chars Characters',
            accentColor: AppColors.catPdf,
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.catPdf,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.catPdf,
            tabs: const [
              Tab(icon: Icon(Icons.edit_rounded), text: 'Editor'),
              Tab(icon: Icon(Icons.visibility_rounded), text: 'Preview'),
            ],
          ),
          const SizedBox(height: 12),
          // Syntax Toolbar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _toolButton('H1', () => _insertSyntax('# ')),
                _toolButton('H2', () => _insertSyntax('## ')),
                _toolButton('H3', () => _insertSyntax('### ')),
                _toolButton('B', () => _insertSyntax('**', '**'), isBold: true),
                _toolButton('I', () => _insertSyntax('*', '*'), isItalic: true),
                _toolButton('Code', () => _insertSyntax('`', '`')),
                _toolButton('Block', () => _insertSyntax('```\n', '\n```')),
                _toolButton('Quote', () => _insertSyntax('> ')),
                _toolButton('• List', () => _insertSyntax('- ')),
                _toolButton('1. List', () => _insertSyntax('1. ')),
                _toolButton('[x] Task', () => _insertSyntax('- [ ] ')),
                _toolButton('Table', () => _insertSyntax('| Header 1 | Header 2 |\n| :--- | :--- |\n| Data 1 | Data 2 |\n')),
                _toolButton('Link', () => _insertSyntax('[title](', ')')),
                _toolButton('---', () => _insertSyntax('\n---\n')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Editor
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: TextField(
                    controller: _markdownController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type your markdown here...',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // Tab 2: Preview
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Markdown(
                    data: _markdownController.text,
                    selectable: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Export .md File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.catPdf,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _exportMarkdown,
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy Markdown',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _markdownController.text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Markdown text copied!')));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolButton(String label, VoidCallback onTap, {bool isBold = false, bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size(36, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
