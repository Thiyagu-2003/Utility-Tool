import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class TextAnalyzerScreen extends StatefulWidget {
  const TextAnalyzerScreen({super.key});

  @override
  State<TextAnalyzerScreen> createState() => _TextAnalyzerScreenState();
}

class _TextAnalyzerScreenState extends State<TextAnalyzerScreen> {
  final TextEditingController _textController = TextEditingController(
    text: 'Flutter is an open source framework by Google for building beautiful, natively compiled, multi-platform applications from a single codebase.',
  );

  Map<String, dynamic> _analyzeText() {
    final text = _textController.text;

    final charCount = text.length;
    final charNoSpaces = text.replaceAll(RegExp(r'\s+'), '').length;

    final words = text.trim().isEmpty ? <String>[] : text.trim().split(RegExp(r'\s+'));
    final wordCount = words.length;

    final sentences = text.trim().isEmpty
        ? <String>[]
        : text.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).toList();
    final sentenceCount = sentences.length;

    final paragraphs = text.trim().isEmpty
        ? <String>[]
        : text.split(RegExp(r'\n+')).where((p) => p.trim().isNotEmpty).toList();
    final paragraphCount = paragraphs.length;

    // Reading time: average reading speed ~200 words per minute
    final readingTimeSec = (wordCount / 200 * 60).round();
    final readingTimeStr = readingTimeSec < 60
        ? '$readingTimeSec sec'
        : '${(readingTimeSec / 60).toStringAsFixed(1)} min';

    return {
      'words': wordCount,
      'characters': charCount,
      'charNoSpaces': charNoSpaces,
      'sentences': sentenceCount,
      'paragraphs': paragraphCount,
      'readingTime': readingTimeStr,
    };
  }

  void _applyTransformation(String Function(String) transform) {
    PreferencesService().triggerHaptic();
    final newText = transform(_textController.text);
    setState(() {
      _textController.text = newText;
    });
  }

  String _toTitleCase(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _toSlug(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  String _cleanExtraSpaces(String text) {
    return text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _analyzeText();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Text Analyzer & Case Tools',
      category: ToolCategory.text,
      toolId: 'text_analyzer',
      onReset: () {
        setState(() {
          _textController.clear();
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Word Count',
            primaryResult: '${stats['words']} Words',
            subtitle: 'Estimated reading time: ${stats['readingTime']}',
            accentColor: AppColors.catText,
            breakdowns: [
              BreakdownItem(
                label: 'Characters (Total)',
                value: stats['characters'].toString(),
              ),
              BreakdownItem(
                label: 'Without Spaces',
                value: stats['charNoSpaces'].toString(),
              ),
              BreakdownItem(
                label: 'Sentences',
                value: stats['sentences'].toString(),
              ),
              BreakdownItem(
                label: 'Paragraphs',
                value: stats['paragraphs'].toString(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ModernTextField(
            label: 'Input Text',
            controller: _textController,
            hintText: 'Type or paste text here...',
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          Text(
            'Quick Text Transformations'.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('UPPERCASE'),
                onPressed: () => _applyTransformation((t) => t.toUpperCase()),
              ),
              ActionChip(
                label: const Text('lowercase'),
                onPressed: () => _applyTransformation((t) => t.toLowerCase()),
              ),
              ActionChip(
                label: const Text('Title Case'),
                onPressed: () => _applyTransformation(_toTitleCase),
              ),
              ActionChip(
                label: const Text('Clean Spaces'),
                onPressed: () => _applyTransformation(_cleanExtraSpaces),
              ),
              ActionChip(
                label: const Text('text-slug'),
                onPressed: () => _applyTransformation(_toSlug),
              ),
              ActionChip(
                label: const Text('Reverse'),
                onPressed: () => _applyTransformation((t) => t.split('').reversed.join()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
