import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validation_utils.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

/// One year (12 instalments) of a loan schedule.
class AmortizationYear {
  final int year;
  final double principalPaid;
  final double interestPaid;
  final double balance;
  const AmortizationYear(this.year, this.principalPaid, this.interestPaid, this.balance);
}

/// Month-by-month reducing-balance schedule folded into years.
List<AmortizationYear> amortizationByYear({required double principal, required double annualRate, required int months}) {
  if (principal <= 0 || months <= 0 || annualRate < 0) return const [];
  final r = annualRate / 1200;
  final growth = math.pow(1 + r, months).toDouble();
  final emi = r == 0 ? principal / months : principal * r * growth / (growth - 1);
  final years = <AmortizationYear>[];
  var balance = principal, yearPrincipal = 0.0, yearInterest = 0.0;
  for (var m = 1; m <= months; m++) {
    final interest = balance * r;
    final paid = emi - interest;
    balance -= paid;
    yearPrincipal += paid;
    yearInterest += interest;
    if (m % 12 == 0 || m == months) {
      years.add(AmortizationYear((m + 11) ~/ 12, yearPrincipal, yearInterest, balance.abs() < 0.005 ? 0 : balance));
      yearPrincipal = yearInterest = 0;
    }
  }
  return years;
}

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
    final principal = ValidationUtils.safeParseDouble(_principalController.text);
    final annualRate = ValidationUtils.safeParseDouble(_rateController.text);
    final tenureVal = ValidationUtils.safeParseDouble(_tenureController.text);

    // Capped at 100 years: beyond that (1 + r)^n overflows a double.
    final monthsExact = _isTenureInYears ? tenureVal * 12 : tenureVal;
    final totalMonths = monthsExact.isFinite && monthsExact <= 1200 ? monthsExact.round() : 0;

    if (principal <= 0 || annualRate < 0 || totalMonths <= 0) {
      return {
        'emi': 0,
        'totalInterest': 0,
        'totalPayment': 0,
        'interestRatio': 0,
        'months': 0,
      };
    }

    final monthlyRate = annualRate / (12 * 100);
    // EMI formula: P * r * (1 + r)^n / ((1 + r)^n - 1); at 0% it is simply P / n.
    final mathPower = math.pow(1 + monthlyRate, totalMonths).toDouble();
    final emi = monthlyRate == 0
        ? principal / totalMonths
        : (principal * monthlyRate * mathPower) / (mathPower - 1);
    final totalPayment = emi * totalMonths;
    final totalInterest = totalPayment - principal;
    final interestRatio = (totalInterest / totalPayment) * 100;

    if (!emi.isFinite || !totalPayment.isFinite) {
      return {'emi': 0, 'totalInterest': 0, 'totalPayment': 0, 'interestRatio': 0, 'months': 0};
    }

    return {
      'months': totalMonths.toDouble(),
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
                value: currencyFmt.format(ValidationUtils.safeParseDouble(_principalController.text)),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixText: '₹',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Annual Interest Rate (%)',
            controller: _rateController,
            hintText: '8.5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixText: '% p.a.',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Loan Tenure',
            controller: _tenureController,
            hintText: '15',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          const SizedBox(height: 16),
          _buildSchedule(),
        ],
      ),
    );
  }

  Widget _buildSchedule() {
    final schedule = amortizationByYear(
      principal: ValidationUtils.safeParseDouble(_principalController.text),
      annualRate: ValidationUtils.safeParseDouble(_rateController.text),
      months: _calculateEmi()['months']!.toInt(),
    );
    if (schedule.isEmpty) return const SizedBox.shrink();
    final fmt = NumberFormat.decimalPattern();
    Widget cell(String text, {int flex = 2, bool bold = false}) => Expanded(
          flex: flex,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(text, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
        );
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Yearly Amortization Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Principal vs interest paid each year'),
      children: [
        Row(children: [cell('Year', flex: 1, bold: true), cell('Principal', bold: true), cell('Interest', bold: true), cell('Balance', bold: true)]),
        const Divider(height: 12),
        for (final y in schedule)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              cell('${y.year}', flex: 1),
              cell(fmt.format(y.principalPaid.round())),
              cell(fmt.format(y.interestPaid.round())),
              cell(fmt.format(y.balance.round())),
            ]),
          ),
      ],
    );
  }
}
