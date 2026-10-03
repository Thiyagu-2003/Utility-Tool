import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class LoanEmiCalculatorScreen extends StatefulWidget {
  const LoanEmiCalculatorScreen({super.key});

  @override
  State<LoanEmiCalculatorScreen> createState() => _LoanEmiCalculatorScreenState();
}

class _LoanEmiCalculatorScreenState extends State<LoanEmiCalculatorScreen> {
  final TextEditingController _principalController = TextEditingController(text: '1000000');
  final TextEditingController _rateController = TextEditingController(text: '8.5');
  final TextEditingController _tenureController = TextEditingController(text: '15');
  bool _isTenureInYears = true;

  Map<String, double> _calculateEmi() {
    final principal = double.tryParse(_principalController.text.trim()) ?? 0;
    final annualRate = double.tryParse(_rateController.text.trim()) ?? 0;
    final tenureVal = double.tryParse(_tenureController.text.trim()) ?? 0;

    final totalMonths = _isTenureInYears ? (tenureVal * 12).round() : tenureVal.round();

    if (principal <= 0 || annualRate <= 0 || totalMonths <= 0) {
      return {
        'emi': 0,
        'totalInterest': 0,
        'totalPayment': principal,
        'interestRatio': 0,
      };
    }

    final monthlyRate = annualRate / (12 * 100);
    // EMI formula: P * r * (1 + r)^n / ((1 + r)^n - 1)
    final mathPower = math.pow(1 + monthlyRate, totalMonths).toDouble();
    final emi = (principal * monthlyRate * mathPower) / (mathPower - 1);
    final totalPayment = emi * totalMonths;
    final totalInterest = totalPayment - principal;
    final interestRatio = (totalInterest / totalPayment) * 100;

    return {
      'emi': emi,
      'totalInterest': totalInterest,
      'totalPayment': totalPayment,
      'interestRatio': interestRatio,
    };
  }

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _calculateEmi();
    final currencyFmt = NumberFormat.currency(symbol: '₹ ', decimalDigits: 0);

    return ToolScaffold(
      title: 'Loan EMI Calculator',
      category: ToolCategory.finance,
      toolId: 'loan_emi_calc',
      onReset: () {
        setState(() {
          _principalController.text = '1000000';
          _rateController.text = '8.5';
          _tenureController.text = '15';
          _isTenureInYears = true;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Monthly EMI',
            primaryResult: currencyFmt.format(data['emi']),
            subtitle: 'Total Payment: ${currencyFmt.format(data['totalPayment'])}',
            accentColor: AppColors.catFinance,
            breakdowns: [
              BreakdownItem(
                label: 'Principal Amount',
                value: currencyFmt.format(double.tryParse(_principalController.text.trim()) ?? 0),
              ),
              BreakdownItem(
                label: 'Total Interest',
                value: currencyFmt.format(data['totalInterest']),
              ),
              BreakdownItem(
                label: 'Interest Share',
                value: '${data['interestRatio']!.toStringAsFixed(1)}%',
              ),
            ],
          ),
          const SizedBox(height: 24),
          ModernTextField(
            label: 'Loan Principal Amount',
            controller: _principalController,
            hintText: '1000000',
            prefixText: '₹',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Annual Interest Rate (%)',
            controller: _rateController,
            hintText: '8.5',
            suffixText: '% p.a.',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Loan Tenure',
            controller: _tenureController,
            hintText: '15',
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChoiceChip(
                  label: const Text('Yrs'),
                  selected: _isTenureInYears,
                  selectedColor: AppColors.catFinance,
                  labelStyle: TextStyle(
                    color: _isTenureInYears ? Colors.white : null,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) {
                      PreferencesService().triggerHaptic();
                      setState(() => _isTenureInYears = true);
                    }
                  },
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Mos'),
                  selected: !_isTenureInYears,
                  selectedColor: AppColors.catFinance,
                  labelStyle: TextStyle(
                    color: !_isTenureInYears ? Colors.white : null,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) {
                      PreferencesService().triggerHaptic();
                      setState(() => _isTenureInYears = false);
                    }
                  },
                ),
              ],
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
