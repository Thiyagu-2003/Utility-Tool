import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class TipSplitScreen extends StatefulWidget {
  const TipSplitScreen({super.key});

  @override
  State<TipSplitScreen> createState() => _TipSplitScreenState();
}

class _TipSplitScreenState extends State<TipSplitScreen> {
  final TextEditingController _billController = TextEditingController(text: '1200');
  double _tipPercent = 10;
  int _splitCount = 3;

  final List<double> _tipPresets = [0, 5, 10, 15, 20];

  Map<String, double> _calculateSplit() {
    final bill = double.tryParse(_billController.text.trim()) ?? 0;
    final tipAmount = bill * (_tipPercent / 100);
    final totalBill = bill + tipAmount;
    final count = _splitCount < 1 ? 1 : _splitCount;

    final perPersonTotal = totalBill / count;
    final perPersonTip = tipAmount / count;
    final perPersonBill = bill / count;

    return {
      'bill': bill,
      'tipAmount': tipAmount,
      'totalBill': totalBill,
      'perPersonTotal': perPersonTotal,
      'perPersonTip': perPersonTip,
      'perPersonBill': perPersonBill,
    };
  }

  @override
  void dispose() {
    _billController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _calculateSplit();
    final currencyFmt = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Tip & Split Bill',
      category: ToolCategory.finance,
      toolId: 'tip_split_calc',
      onReset: () {
        setState(() {
          _billController.text = '1200';
          _tipPercent = 10;
          _splitCount = 3;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Per Person Amount',
            primaryResult: currencyFmt.format(data['perPersonTotal']),
            subtitle: 'Split across $_splitCount people (incl. ${currencyFmt.format(data['perPersonTip'])} tip each)',
            accentColor: AppColors.catFinance,
            breakdowns: [
              BreakdownItem(
                label: 'Total with Tip',
                value: currencyFmt.format(data['totalBill']),
              ),
              BreakdownItem(
                label: 'Total Tip (${_tipPercent.toInt()}%)',
                value: currencyFmt.format(data['tipAmount']),
              ),
              BreakdownItem(
                label: 'Base Per Person',
                value: currencyFmt.format(data['perPersonBill']),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ModernTextField(
            label: 'Total Bill Amount',
            controller: _billController,
            hintText: '1200',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixText: '₹',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // Tip percentage selector
          const Text(
            'Select Tip Percentage',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: _tipPresets.map((tip) {
              final isSelected = _tipPercent == tip;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: ChoiceChip(
                    label: Center(child: Text('${tip.toInt()}%')),
                    selected: isSelected,
                    selectedColor: AppColors.catFinance,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _tipPercent = tip);
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Number of people split counter
          Text(
            'Split Among People'.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline_rounded, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      '$_splitCount ${_splitCount == 1 ? 'Person' : 'People'}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.darkCard : AppColors.lightCardHover,
                        ),
                        child: const Icon(Icons.remove, size: 18),
                      ),
                      onPressed: _splitCount > 1
                          ? () {
                              PreferencesService().triggerHaptic();
                              setState(() => _splitCount--);
                            }
                          : null,
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.darkCard : AppColors.lightCardHover,
                        ),
                        child: const Icon(Icons.add, size: 18),
                      ),
                      onPressed: () {
                        PreferencesService().triggerHaptic();
                        setState(() => _splitCount++);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
