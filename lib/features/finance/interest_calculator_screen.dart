import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class InterestCalculatorScreen extends StatefulWidget {
  const InterestCalculatorScreen({super.key});

  @override
  State<InterestCalculatorScreen> createState() => _InterestCalculatorScreenState();
}

class _InterestCalculatorScreenState extends State<InterestCalculatorScreen> {
  final TextEditingController _principalController = TextEditingController(text: '50000');
  final TextEditingController _rateController = TextEditingController(text: '7.5');
  final TextEditingController _timeController = TextEditingController(text: '5');
  bool _isCompound = true;
  int _compoundFrequency = 1; // 1 = Annually, 4 = Quarterly, 12 = Monthly

  Map<String, double> _calculateInterest() {
    final p = double.tryParse(_principalController.text.trim()) ?? 0;
    final r = (double.tryParse(_rateController.text.trim()) ?? 0) / 100;
    final t = double.tryParse(_timeController.text.trim()) ?? 0;

    double totalAmount = 0;
    double interestEarned = 0;

    if (_isCompound) {
      final n = _compoundFrequency;
      totalAmount = p * math.pow(1 + (r / n), n * t).toDouble();
      interestEarned = totalAmount - p;
    } else {
      interestEarned = p * r * t;
      totalAmount = p + interestEarned;
    }

    final growthPercent = p > 0 ? (interestEarned / p) * 100 : 0.0;

    return {
      'principal': p,
      'interestEarned': interestEarned,
      'totalAmount': totalAmount,
      'growthPercent': growthPercent,
    };
  }

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _calculateInterest();
    final currencyFmt = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

    return ToolScaffold(
      title: 'Interest Calculator',
      category: ToolCategory.finance,
      toolId: 'interest_calc',
      onReset: () {
        setState(() {
          _principalController.text = '50000';
          _rateController.text = '7.5';
          _timeController.text = '5';
          _isCompound = true;
          _compoundFrequency = 1;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simple vs Compound Chip
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightCardHover,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Compound Interest')),
                    selected: _isCompound,
                    selectedColor: AppColors.catFinance,
                    labelStyle: TextStyle(
                      color: _isCompound ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _isCompound = true);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Simple Interest')),
                    selected: !_isCompound,
                    selectedColor: AppColors.catFinance,
                    labelStyle: TextStyle(
                      color: !_isCompound ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _isCompound = false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          ResultCard(
            title: 'Maturity Value',
            primaryResult: currencyFmt.format(data['totalAmount']),
            subtitle: 'Total Interest: ${currencyFmt.format(data['interestEarned'])} (+${data['growthPercent']!.toStringAsFixed(1)}%)',
            accentColor: AppColors.catFinance,
            breakdowns: [
              BreakdownItem(
                label: 'Principal Invested',
                value: currencyFmt.format(data['principal']),
              ),
              BreakdownItem(
                label: 'Interest Earned',
                value: currencyFmt.format(data['interestEarned']),
              ),
              BreakdownItem(
                label: 'Return on Investment',
                value: '${data['growthPercent']!.toStringAsFixed(1)}%',
              ),
            ],
          ),
          const SizedBox(height: 24),

          ModernTextField(
            label: 'Principal Investment Amount',
            controller: _principalController,
            hintText: '50000',
            prefixText: '₹',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Annual Interest Rate (%)',
            controller: _rateController,
            hintText: '7.5',
            suffixText: '% p.a.',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Investment Period (Years)',
            controller: _timeController,
            hintText: '5',
            suffixText: 'Years',
            onChanged: (_) => setState(() {}),
          ),

          if (_isCompound) ...[
            const SizedBox(height: 16),
            const Text(
              'Compounding Frequency',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Annually')),
                    selected: _compoundFrequency == 1,
                    selectedColor: AppColors.catFinance,
                    labelStyle: TextStyle(
                      color: _compoundFrequency == 1 ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _compoundFrequency = 1);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Quarterly')),
                    selected: _compoundFrequency == 4,
                    selectedColor: AppColors.catFinance,
                    labelStyle: TextStyle(
                      color: _compoundFrequency == 4 ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _compoundFrequency = 4);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Monthly')),
                    selected: _compoundFrequency == 12,
                    selectedColor: AppColors.catFinance,
                    labelStyle: TextStyle(
                      color: _compoundFrequency == 12 ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _compoundFrequency = 12);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
