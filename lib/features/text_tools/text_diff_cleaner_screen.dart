import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum TextToolTab {
  diff('Text Diff & Comparison', Icons.compare_arrows_rounded),
  dedupe('Duplicate Line Remover', Icons.playlist_remove_rounded);

  final String label;
  final IconData icon;
  const TextToolTab(this.label, this.icon);
}

enum DiffType { added, removed, unchanged }

class DiffLine {
  final DiffType type;
  final String text;
  final int? origLineNum;
  final int? modLineNum;
  DiffLine({required this.type, required this.text, this.origLineNum, this.modLineNum});
}

class TextDiffCleanerScreen extends StatefulWidget {
  const TextDiffCleanerScreen({super.key});

  @override
  State<TextDiffCleanerScreen> createState() => _TextDiffCleanerScreenState();
}

class _TextDiffCleanerScreenState extends State<TextDiffCleanerScreen> {
  TextToolTab _activeTab = TextToolTab.diff;

  // 1. DIFF STATE
  final _origTextCtrl = TextEditingController(
    text: 'Apples\nBananas\nCherries\nDragonfruit\nElderberry',
  );
  final _modTextCtrl = TextEditingController(
    text: 'Apples\nBlueberries\nCherries\nDragonfruit\nElderberry\nFigs',
  );

  // 2. DEDUPE STATE
  final _dedupeInputCtrl = TextEditingController(
    text: 'Apple\nBanana\napple\nOrange\nBanana\nGrape\nOrange\nMango\n\nApple',
  );
  bool _caseSensitive = false;
  bool _trimWhitespace = true;
  bool _removeEmptyLines = true;
  String _sortMode = 'Keep Original Order';
  String _cleanedResult = '';

  @override
  void initState() {
    super.initState();
    _processDeduplication();
  }

  @override
  void dispose() {
    _origTextCtrl.dispose();
    _modTextCtrl.dispose();
    _dedupeInputCtrl.dispose();
    super.dispose();
  }

  // --- DIFF LOGIC ---
  List<DiffLine> _computeDiff() {
    final origLines = _origTextCtrl.text.split('\n');
    final modLines = _modTextCtrl.text.split('\n');

    final List<DiffLine> diffs = [];
    final origSet = origLines.toSet();
    final modSet = modLines.toSet();

    int origIdx = 0;
    int modIdx = 0;

    while (origIdx < origLines.length || modIdx < modLines.length) {
      if (origIdx < origLines.length && modIdx < modLines.length) {
        if (origLines[origIdx] == modLines[modIdx]) {
          diffs.add(DiffLine(type: DiffType.unchanged, text: origLines[origIdx], origLineNum: origIdx + 1, modLineNum: modIdx + 1));
          origIdx++;
          modIdx++;
          continue;
        }
      }

      if (origIdx < origLines.length && !modSet.contains(origLines[origIdx])) {
        diffs.add(DiffLine(type: DiffType.removed, text: origLines[origIdx], origLineNum: origIdx + 1));
        origIdx++;
      } else if (modIdx < modLines.length && !origSet.contains(modLines[modIdx])) {
        diffs.add(DiffLine(type: DiffType.added, text: modLines[modIdx], modLineNum: modIdx + 1));
        modIdx++;
      } else {
        // Line modified or displaced
        if (origIdx < origLines.length) {
          diffs.add(DiffLine(type: DiffType.removed, text: origLines[origIdx], origLineNum: origIdx + 1));
          origIdx++;
        }
        if (modIdx < modLines.length) {
          diffs.add(DiffLine(type: DiffType.added, text: modLines[modIdx], modLineNum: modIdx + 1));
          modIdx++;
        }
      }
    }

    return diffs;
  }

  // --- DEDUPE LOGIC ---
  void _processDeduplication() {
    final raw = _dedupeInputCtrl.text;
    final lines = raw.split('\n');

    final seen = <String>{};
    final List<String> uniqueList = [];

    for (var line in lines) {
      if (_trimWhitespace) line = line.trim();
      if (_removeEmptyLines && line.isEmpty) continue;

      final key = _caseSensitive ? line : line.toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueList.add(line);
      }
    }

    if (_sortMode == 'A to Z (Alphabetical)') {
      uniqueList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else if (_sortMode == 'Z to A (Reverse)') {
      uniqueList.sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase()));
    } else if (_sortMode == 'Shortest to Longest') {
      uniqueList.sort((a, b) => a.length.compareTo(b.length));
    } else if (_sortMode == 'Longest to Shortest') {
      uniqueList.sort((a, b) => b.length.compareTo(a.length));
    }

    setState(() {
      _cleanedResult = uniqueList.join('\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Text Diff & Cleaner',
      category: ToolCategory.filesText,
      toolId: 'text_diff_cleaner',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSegmentChips(isDark),
          const SizedBox(height: 16),
          if (_activeTab == TextToolTab.diff) _buildDiffTab(isDark),
          if (_activeTab == TextToolTab.dedupe) _buildDedupeTab(isDark),
        ],
      ),
    );
  }

  Widget _buildSegmentChips(bool isDark) {
    return Row(
      children: TextToolTab.values.map((tab) {
        final isSelected = _activeTab == tab;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ChoiceChip(
            showCheckmark: false,
            avatar: Icon(tab.icon, size: 16, color: isSelected ? Colors.white : null),
            label: Text(tab.label),
            selected: isSelected,
            selectedColor: AppColors.catPdf,
            onSelected: (_) {
              PreferencesService().triggerHaptic();
              setState(() => _activeTab = tab);
            },
          ),
        );
      }).toList(),
    );
  }

  // --- TAB 1: TEXT DIFF ---
  Widget _buildDiffTab(bool isDark) {
    final diffs = _computeDiff();
    final addedCount = diffs.where((d) => d.type == DiffType.added).length;
    final removedCount = diffs.where((d) => d.type == DiffType.removed).length;
    final unchangedCount = diffs.where((d) => d.type == DiffType.unchanged).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Text Comparison Summary',
          primaryResult: '+$addedCount added • -$removedCount removed',
          subtitle: '$unchangedCount lines unchanged',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _origTextCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Original Text',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _modTextCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Modified Text',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Difference Highlighting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Unified Diff'),
              onPressed: () {
                final str = diffs.map((d) {
                  final p = d.type == DiffType.added ? '+ ' : d.type == DiffType.removed ? '- ' : '  ';
                  return '$p${d.text}';
                }).join('\n');
                Clipboard.setData(ClipboardData(text: str));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unified diff copied to clipboard!')));
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            children: diffs.map((d) {
              Color bg;
              Color textCol;
              String prefix;

              switch (d.type) {
                case DiffType.added:
                  bg = Colors.green.withValues(alpha: isDark ? 0.25 : 0.15);
                  textCol = Colors.green;
                  prefix = '+ ';
                  break;
                case DiffType.removed:
                  bg = Colors.red.withValues(alpha: isDark ? 0.25 : 0.15);
                  textCol = Colors.red;
                  prefix = '- ';
                  break;
                case DiffType.unchanged:
                  bg = Colors.transparent;
                  textCol = isDark ? Colors.white70 : Colors.black87;
                  prefix = '  ';
                  break;
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: bg,
                child: Row(
                  children: [
                    Text(prefix, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: textCol)),
                    Expanded(
                      child: Text(
                        d.text.isEmpty ? ' ' : d.text,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: textCol),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- TAB 2: DEDUPE ---
  Widget _buildDedupeTab(bool isDark) {
    final origCount = _dedupeInputCtrl.text.split('\n').length;
    final cleanCount = _cleanedResult.isEmpty ? 0 : _cleanedResult.split('\n').length;
    final removed = origCount - cleanCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Duplicate Removal Metrics',
          primaryResult: '$cleanCount Unique Lines',
          subtitle: '$removed duplicate lines eliminated',
          accentColor: AppColors.catPdf,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _dedupeInputCtrl,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Paste Lines with Duplicates',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (_) => _processDeduplication(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              label: const Text('Case Sensitive'),
              selected: _caseSensitive,
              onSelected: (v) {
                setState(() => _caseSensitive = v);
                _processDeduplication();
              },
            ),
            FilterChip(
              label: const Text('Trim Whitespace'),
              selected: _trimWhitespace,
              onSelected: (v) {
                setState(() => _trimWhitespace = v);
                _processDeduplication();
              },
            ),
            FilterChip(
              label: const Text('Remove Blank Lines'),
              selected: _removeEmptyLines,
              onSelected: (v) {
                setState(() => _removeEmptyLines = v);
                _processDeduplication();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _sortMode,
          decoration: InputDecoration(labelText: 'Sort Order', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          items: [
            'Keep Original Order',
            'A to Z (Alphabetical)',
            'Z to A (Reverse)',
            'Shortest to Longest',
            'Longest to Shortest',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _sortMode = v);
              _processDeduplication();
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Cleaned Output', style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copy Output',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _cleanedResult));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleaned text copied!')));
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              _cleanedResult.isEmpty ? 'No text to display' : _cleanedResult,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
