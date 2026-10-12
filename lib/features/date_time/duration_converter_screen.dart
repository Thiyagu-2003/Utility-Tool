import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum DurationInputUnit {
  hours('Hours', 3600),
  minutes('Minutes', 60),
  seconds('Seconds', 1),
  days('Days', 86400),
  weeks('Weeks', 604800);

  final String label;
  final int toSeconds;
  const DurationInputUnit(this.label, this.toSeconds);
}

class DurationConverterScreen extends StatefulWidget {
  const DurationConverterScreen({super.key});

  @override
  State<DurationConverterScreen> createState() => _DurationConverterScreenState();
}

class _DurationConverterScreenState extends State<DurationConverterScreen> {
  final TextEditingController _inputController = TextEditingController(text: '200');
  DurationInputUnit _selectedUnit = DurationInputUnit.hours;

  Map<String, dynamic> _computeDuration() {
    final double parsed = double.tryParse(_inputController.text.trim()) ?? 0;
    // Infinity/NaN would throw in round(); negatives would break ~/ and %.
    final double rawVal = parsed.isFinite ? parsed : 0;
    final isNegative = rawVal < 0;
    // Capped (about 285 million years) so huge input can't overflow to Infinity.
    final seconds0 = rawVal.abs() * _selectedUnit.toSeconds;
    final tooLarge = !seconds0.isFinite || seconds0 > 9e15;
    final totalSeconds = (tooLarge ? 9e15 : seconds0).round();
    final sign = isNegative ? -1 : 1;

    final days = totalSeconds ~/ 86400;
    final remainingAfterDays = totalSeconds % 86400;
    final hours = remainingAfterDays ~/ 3600;
    final remainingAfterHours = remainingAfterDays % 3600;
    final minutes = remainingAfterHours ~/ 60;
    final seconds = remainingAfterHours % 60;

    // Formatted readable decomposition: e.g. "8 days, 8 hours"
    List<String> parts = [];
    if (days > 0) parts.add('$days ${days == 1 ? 'day' : 'days'}');
    if (hours > 0) parts.add('$hours ${hours == 1 ? 'hr' : 'hrs'}');
    if (minutes > 0) parts.add('$minutes ${minutes == 1 ? 'min' : 'mins'}');
    if (seconds > 0 || parts.isEmpty) parts.add('$seconds ${seconds == 1 ? 'sec' : 'secs'}');

    final totalHours = totalSeconds / 3600.0;
    final totalDays = totalSeconds / 86400.0;
    final totalMinutes = totalSeconds / 60.0;

    return {
      'formatted': '${isNegative ? '-' : ''}${parts.join(', ')}',
      'tooLarge': tooLarge,
      'totalDays': totalDays * sign,
      'totalHours': totalHours * sign,
      'totalMinutes': totalMinutes * sign,
      'totalSeconds': totalSeconds * sign,
    };
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _computeDuration();
    final numberFmt = NumberFormat('#,##0.##');

    return ToolScaffold(
      title: 'Duration Converter',
      category: ToolCategory.timeDuration,
      toolId: 'duration_converter',
      onReset: () {
        setState(() {
          _inputController.text = '200';
          _selectedUnit = DurationInputUnit.hours;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Decomposed Duration',
            primaryResult: data['formatted'],
            subtitle: data['tooLarge'] == true ? 'Value too large, capped at the maximum shown' : 'Equivalent duration breakdown',
            accentColor: AppColors.catTime,
            breakdowns: [
              BreakdownItem(
                label: 'Total Days',
                value: numberFmt.format(data['totalDays']),
              ),
              BreakdownItem(
                label: 'Total Hours',
                value: numberFmt.format(data['totalHours']),
              ),
              BreakdownItem(
                label: 'Total Minutes',
                value: numberFmt.format(data['totalMinutes']),
              ),
              BreakdownItem(
                label: 'Total Seconds',
                value: NumberFormat('#,###').format(data['totalSeconds']),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ModernTextField(
            label: 'Enter Value',
            controller: _inputController,
            hintText: 'e.g. 200',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icons.timer_outlined,
            onChanged: (_) => setState(() {}),
            suffix: DropdownButtonHideUnderline(
              child: DropdownButton<DurationInputUnit>(
                value: _selectedUnit,
                borderRadius: BorderRadius.circular(12),
                items: DurationInputUnit.values.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(
                      unit.label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (newUnit) {
                  if (newUnit != null) {
                    PreferencesService().triggerSelectionHaptic();
                    setState(() {
                      _selectedUnit = newUnit;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Quick presets chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [24, 48, 100, 168, 200, 500, 1000].map((val) {
              return ActionChip(
                label: Text('$val ${_selectedUnit.label.toLowerCase()}'),
                onPressed: () {
                  PreferencesService().triggerHaptic();
                  setState(() {
                    _inputController.text = val.toString();
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
