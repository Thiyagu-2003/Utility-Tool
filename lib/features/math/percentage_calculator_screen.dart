import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum PercentMode {
  percentOf('What is X% of Y?'),
  xIsWhatPercentOfY('X is what % of Y?'),
  percentChange('% Change from X to Y');

  final String label;
  const PercentMode(this.label);
}

class PercentageCalculatorScreen extends StatefulWidget {
  const PercentageCalculatorScreen({super.key});

  @override
  State<PercentageCalculatorScreen> createState() => _PercentageCalculatorScreenState();
}

class _PercentageCalculatorScreenState extends State<PercentageCalculatorScreen> {
  PercentMode _mode = PercentMode.percentOf;
  final TextEditingController _val1Controller = TextEditingController(text: '18');
  final TextEditingController _val2Controller = TextEditingController(text: '2500');

  final NumberFormat _fmt = NumberFormat('#,##0.######');

  Map<String, dynamic> _compute() {
    final v1 = double.tryParse(_val1Controller.text.trim()) ?? 0;
    final v2 = double.tryParse(_val2Controller.text.trim()) ?? 0;

    String primary = '0';
    String subtitle = '';
    List<BreakdownItem> items = [];

    switch (_mode) {
      case PercentMode.percentOf:
        // What is v1% of v2?
        final res = (v1 / 100) * v2;
        primary = _fmt.format(res);
        subtitle = '$v1% of $v2 is $primary';
        items = [
          BreakdownItem(label: 'Percentage', value: '$v1%'),
          BreakdownItem(label: 'Base Number', value: _fmt.format(v2)),
          BreakdownItem(label: 'Remaining (${(100 - v1).toStringAsFixed(1)}%)', value: _fmt.format(v2 - res)),
        ];
        break;

      case PercentMode.xIsWhatPercentOfY:
        // v1 is what % of v2?
        if (v2 == 0) {
          primary = 'Undefined (div by 0)';
          subtitle = 'Cannot divide by zero';
        } else {
          final res = (v1 / v2) * 100;
          primary = '${_fmt.format(res)}%';
          subtitle = '$v1 is $primary of $v2';
          items = [
            BreakdownItem(label: 'Part (X)', value: _fmt.format(v1)),
            BreakdownItem(label: 'Total (Y)', value: _fmt.format(v2)),
            BreakdownItem(label: 'Ratio', value: '1 : ${_fmt.format(v2 / (v1 == 0 ? 1 : v1))}'),
          ];
        }
        break;

      case PercentMode.percentChange:
        // % change from v1 to v2
        if (v1 == 0) {
          primary = 'Undefined';
          subtitle = 'Initial value cannot be zero';
        } else {
          final diff = v2 - v1;
          final pct = (diff / v1) * 100;
          final isIncrease = diff >= 0;
          primary = '${isIncrease ? '+' : ''}${_fmt.format(pct)}%';
          subtitle = '${isIncrease ? 'Increase' : 'Decrease'} of ${_fmt.format(diff.abs())}';
          items = [
            BreakdownItem(label: 'Initial (X)', value: _fmt.format(v1)),
            BreakdownItem(label: 'Final (Y)', value: _fmt.format(v2)),
            BreakdownItem(label: 'Absolute Difference', value: _fmt.format(diff)),
          ];
        }
        break;
    }

    return {
      'primary': primary,
      'subtitle': subtitle,
      'items': items,
    };
  }

  @override
  void dispose() {
    _val1Controller.dispose();
    _val2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final computed = _compute();

    return ToolScaffold(
      title: 'Percentage Calculator',
      category: ToolCategory.calculators,
      toolId: 'percentage_calc',
      onReset: () {
        setState(() {
          _val1Controller.text = '18';
          _val2Controller.text = '2500';
          _mode = PercentMode.percentOf;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PercentMode.values.map((m) {
                final isSelected = m == _mode;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(m.label),
                    selected: isSelected,
                    selectedColor: AppColors.catMath,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _mode = m);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          ResultCard(
            title: 'Result',
            primaryResult: computed['primary'],
            subtitle: computed['subtitle'],
            accentColor: AppColors.catMath,
            breakdowns: computed['items'],
          ),
          const SizedBox(height: 24),

          ModernTextField(
            label: _mode == PercentMode.percentOf
                ? 'Percentage (%)'
                : (_mode == PercentMode.xIsWhatPercentOfY ? 'Value (X)' : 'Initial Value (X)'),
            controller: _val1Controller,
            hintText: 'e.g. 18',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixText: _mode == PercentMode.percentOf ? '%' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          ModernTextField(
            label: _mode == PercentMode.percentOf
                ? 'Of Value (Y)'
                : (_mode == PercentMode.xIsWhatPercentOfY ? 'Total Value (Y)' : 'Final Value (Y)'),
            controller: _val2Controller,
            hintText: 'e.g. 2500',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
