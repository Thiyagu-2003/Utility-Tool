import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';

class CalculationHistoryScreen extends StatefulWidget {
  const CalculationHistoryScreen({super.key});

  @override
  State<CalculationHistoryScreen> createState() => _CalculationHistoryScreenState();
}

class _CalculationHistoryScreenState extends State<CalculationHistoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchFilter = '';
  String _selectedCategory = 'All';

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy • hh:mm a');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _copyToClipboard(CalculationRecord record) {
    PreferencesService().triggerHaptic();
    Clipboard.setData(ClipboardData(text: '${record.toolTitle}: ${record.expression} = ${record.result}'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: ${record.result}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _exportHistory(List<CalculationRecord> records) {
    PreferencesService().triggerHaptic();
    final buffer = StringBuffer();
    buffer.writeln('=== ToolBox Pro - Calculation History Export ===\n');
    for (final r in records) {
      buffer.writeln('[${_dateFormat.format(r.timestamp)}] ${r.toolTitle}');
      buffer.writeln('Expression: ${r.expression}');
      buffer.writeln('Result: ${r.result}\n');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entire calculation history copied to clipboard!'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Calculation History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          AnimatedBuilder(
            animation: prefs,
            builder: (context, _) {
              if (prefs.calculationHistory.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Export History',
                icon: const Icon(Icons.share_rounded, size: 20),
                onPressed: () => _exportHistory(prefs.calculationHistory),
              );
            },
          ),
          AnimatedBuilder(
            animation: prefs,
            builder: (context, _) {
              if (prefs.calculationHistory.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear All History',
                icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear History?'),
                      content: const Text('This will delete all saved calculation logs permanently.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                          onPressed: () {
                            prefs.clearHistory();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: prefs,
        builder: (context, _) {
          final allRecords = prefs.calculationHistory;

          // Distinct tool titles for filtering
          final toolTitles = <String>{'All', ...allRecords.map((r) => r.toolTitle)}.toList();

          final filteredRecords = allRecords.where((r) {
            final matchesCategory = _selectedCategory == 'All' || r.toolTitle == _selectedCategory;
            final query = _searchFilter.trim().toLowerCase();
            final matchesSearch = query.isEmpty ||
                r.toolTitle.toLowerCase().contains(query) ||
                r.expression.toLowerCase().contains(query) ||
                r.result.toLowerCase().contains(query);
            return matchesCategory && matchesSearch;
          }).toList();

          return Column(
            children: [
              // Search & Filter header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchFilter = val),
                    decoration: InputDecoration(
                      hintText: 'Search history (e.g. GST, 2500, 18%)...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchFilter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchFilter = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),

              // Filter chips horizontal row
              if (toolTitles.length > 2)
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: toolTitles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final title = toolTitles[i];
                      final isSelected = _selectedCategory == title;
                      return ChoiceChip(
                        label: Text(title, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: AppColors.primaryOrange.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primaryOrange : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        onSelected: (sel) {
                          if (sel) setState(() => _selectedCategory = title);
                        },
                      );
                    },
                  ),
                ),

              const SizedBox(height: 8),

              // Records list or empty state
              Expanded(
                child: filteredRecords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded, size: 54, color: AppColors.darkTextMuted.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text(
                              allRecords.isEmpty
                                  ? 'No calculations logged yet'
                                  : 'No matching calculations found',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Results from tools & calculator appear here automatically',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filteredRecords.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final record = filteredRecords[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryOrange.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        record.toolTitle,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryOrange,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _dateFormat.format(record.timestamp),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  record.expression,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        record.result,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Copy Result',
                                      icon: const Icon(Icons.copy_rounded, size: 18),
                                      onPressed: () => _copyToClipboard(record),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
