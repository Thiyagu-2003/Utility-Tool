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

enum InterestMode {
  compound('Compound'),
  simple('Simple'),
  sip('SIP'),
  cagr('CAGR');

  final String label;
  const InterestMode(this.label);
}

class InterestCalculatorScreen extends StatefulWidget {
  const InterestCalculatorScreen({super.key});

  @override
  State<InterestCalculatorScreen> createState() => _InterestCalculatorScreenState();
}

class _InterestCalculatorScreenState extends State<InterestCalculatorScreen> {
  final TextEditingController _principalController = TextEditingController(text: '50000');
  final TextEditingController _rateController = TextEditingController(text: '7.5');
  final TextEditingController _timeController = TextEditingController(text: '5');
  InterestMode _mode = InterestMode.compound;
  int _compoundFrequency = 1; // 1 = Annually, 4 = Quarterly, 12 = Monthly

  Map<String, dynamic> _calculateData() {
    final currencyFmt = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

    switch (_mode) {
      case InterestMode.compound:
        final rawP = ValidationUtils.safeParseDouble(_principalController.text);
        final p = (rawP.isFinite && rawP > 0) ? rawP : 0.0;
        final rawR = ValidationUtils.safeParseDouble(_rateController.text);
        final r = (rawR.isFinite && rawR >= 0) ? rawR / 100 : 0.0;
        final rawT = ValidationUtils.safeParseDouble(_timeController.text);
        final t = (rawT.isFinite && rawT >= 0 && rawT <= 100) ? rawT : 0.0;

        final n = _compoundFrequency > 0 ? _compoundFrequency : 1;
        double totalAmount = p * math.pow(1 + (r / n), n * t).toDouble();
        double interestEarned = totalAmount - p;

        if (!totalAmount.isFinite || !interestEarned.isFinite) {
          totalAmount = p;
          interestEarned = 0.0;
        }
        final growthPercent = p > 0 ? (interestEarned / p) * 100 : 0.0;
        final safeGrowth = growthPercent.isFinite ? growthPercent : 0.0;

        return {
          'title': 'Maturity Value',
          'primary': currencyFmt.format(totalAmount),
          'subtitle': 'Total Interest: ${currencyFmt.format(interestEarned)} (+${safeGrowth.toStringAsFixed(1)}%)',
          'breakdowns': [
            BreakdownItem(label: 'Principal Invested', value: currencyFmt.format(p)),
            BreakdownItem(label: 'Interest Earned', value: currencyFmt.format(interestEarned)),
            BreakdownItem(label: 'Return on Investment', value: '${safeGrowth.toStringAsFixed(1)}%'),
          ],
        };

      case InterestMode.simple:
        final rawP = ValidationUtils.safeParseDouble(_principalController.text);
        final p = (rawP.isFinite && rawP > 0) ? rawP : 0.0;
        final rawR = ValidationUtils.safeParseDouble(_rateController.text);
        final r = (rawR.isFinite && rawR >= 0) ? rawR / 100 : 0.0;
        final rawT = ValidationUtils.safeParseDouble(_timeController.text);
        final t = (rawT.isFinite && rawT >= 0 && rawT <= 100) ? rawT : 0.0;

        double interestEarned = p * r * t;
        double totalAmount = p + interestEarned;

        if (!totalAmount.isFinite || !interestEarned.isFinite) {
          totalAmount = p;
          interestEarned = 0.0;
        }
        final growthPercent = p > 0 ? (interestEarned / p) * 100 : 0.0;
        final safeGrowth = growthPercent.isFinite ? growthPercent : 0.0;

        return {
          'title': 'Maturity Value',
          'primary': currencyFmt.format(totalAmount),
          'subtitle': 'Total Interest: ${currencyFmt.format(interestEarned)} (+${safeGrowth.toStringAsFixed(1)}%)',
          'breakdowns': [
            BreakdownItem(label: 'Principal Invested', value: currencyFmt.format(p)),
            BreakdownItem(label: 'Interest Earned', value: currencyFmt.format(interestEarned)),
            BreakdownItem(label: 'Return on Investment', value: '${safeGrowth.toStringAsFixed(1)}%'),
          ],
        };

      case InterestMode.sip:
        final rawMonthly = ValidationUtils.safeParseDouble(_principalController.text);
        final monthly = (rawMonthly.isFinite && rawMonthly > 0) ? rawMonthly : 0.0;
        final rawRate = ValidationUtils.safeParseDouble(_rateController.text);
        final rate = (rawRate.isFinite && rawRate >= 0) ? rawRate : 0.0;
        final rawYears = ValidationUtils.safeParseDouble(_timeController.text);
        final years = (rawYears.isFinite && rawYears >= 0 && rawYears <= 100) ? rawYears : 0.0;

        final totalMonths = (years * 12).round();
        final totalInvested = monthly * totalMonths;
        double maturityValue = 0.0;

        if (totalMonths <= 0 || monthly <= 0) {
          maturityValue = 0.0;
        } else if (rate == 0) {
          maturityValue = totalInvested;
        } else {
          final i = (rate / 100) / 12;
          final growth = math.pow(1 + i, totalMonths).toDouble();
          maturityValue = growth.isFinite ? monthly * ((growth - 1) / i) * (1 + i) : totalInvested;
        }

        if (!maturityValue.isFinite || maturityValue < totalInvested) maturityValue = totalInvested;
        final wealthGained = maturityValue - totalInvested;
        final growthPercent = totalInvested > 0 ? (wealthGained / totalInvested) * 100 : 0.0;
        final safeGrowth = growthPercent.isFinite ? growthPercent : 0.0;

        return {
          'title': 'Expected Total Wealth (SIP)',
          'primary': currencyFmt.format(maturityValue),
          'subtitle': 'Total Invested: ${currencyFmt.format(totalInvested)} • Wealth Gained: ${currencyFmt.format(wealthGained)}',
          'breakdowns': [
            BreakdownItem(label: 'Invested Amount', value: currencyFmt.format(totalInvested)),
            BreakdownItem(label: 'Estimated Returns', value: currencyFmt.format(wealthGained)),
            BreakdownItem(label: 'Total Growth %', value: '${safeGrowth.toStringAsFixed(1)}%'),
          ],
        };

      case InterestMode.cagr:
        final rawBeginning = ValidationUtils.safeParseDouble(_principalController.text);
        final beginning = (rawBeginning.isFinite && rawBeginning > 0) ? rawBeginning : 0.0;
        final rawEnding = ValidationUtils.safeParseDouble(_rateController.text);
        final ending = (rawEnding.isFinite && rawEnding > 0) ? rawEnding : 0.0;
        final rawYears = ValidationUtils.safeParseDouble(_timeController.text);
        final years = (rawYears.isFinite && rawYears > 0 && rawYears <= 100) ? rawYears : 0.0;

        double cagrPercent = 0.0;
        if (beginning > 0 && ending > 0 && years > 0) {
          final growth = math.pow(ending / beginning, 1 / years).toDouble();
          if (growth.isFinite) {
            cagrPercent = (growth - 1) * 100;
          }
        }
        final safeCagr = cagrPercent.isFinite ? cagrPercent : 0.0;
        final absoluteGain = ending - beginning;
        final absolutePercent = beginning > 0 ? (absoluteGain / beginning) * 100 : 0.0;

        return {
          'title': 'CAGR (Annual Growth Rate)',
          'primary': '${safeCagr.toStringAsFixed(2)}% p.a.',
          'subtitle': 'Absolute Gain: ${currencyFmt.format(absoluteGain >= 0 ? absoluteGain : 0)} (${absolutePercent.toStringAsFixed(1)}%)',
          'breakdowns': [
            BreakdownItem(label: 'Beginning Value', value: currencyFmt.format(beginning)),
            BreakdownItem(label: 'Ending Value', value: currencyFmt.format(ending)),
            BreakdownItem(label: 'Absolute Return', value: '${absolutePercent.toStringAsFixed(1)}%'),
          ],
        };
    }
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
    final data = _calculateData();

    return ToolScaffold(
      title: 'Interest & Investment Calculator',
      category: ToolCategory.finance,
      toolId: 'interest_calc',
      onReset: () {
        setState(() {
          _principalController.text = '50000';
          _rateController.text = '7.5';
          _timeController.text = '5';
          _mode = InterestMode.compound;
          _compoundFrequency = 1;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode Selector Chips
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightCardHover,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: InterestMode.values.map((mode) {
                final isSelected = _mode == mode;
                return Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(mode.label)),
                    selected: isSelected,
                    selectedColor: AppColors.catFinance,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() {
                          _mode = mode;
                          if (mode == InterestMode.sip && _principalController.text == '50000') {
                            _principalController.text = '5000';
                            _rateController.text = '12';
                          } else if (mode == InterestMode.cagr && _rateController.text == '7.5') {
                            _principalController.text = '10000';
                            _rateController.text = '25000';
                          }
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          ResultCard(
            title: data['title'] as String,
            primaryResult: data['primary'] as String,
            subtitle: data['subtitle'] as String,
            accentColor: AppColors.catFinance,
            breakdowns: data['breakdowns'] as List<BreakdownItem>,
          ),
          const SizedBox(height: 24),

          ModernTextField(
            label: _mode == InterestMode.sip
                ? 'Monthly Investment Amount'
                : (_mode == InterestMode.cagr ? 'Beginning / Initial Investment' : 'Principal Investment Amount'),
            controller: _principalController,
            hintText: _mode == InterestMode.sip ? '5000' : '50000',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixText: '₹',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            label: _mode == InterestMode.cagr
                ? 'Ending / Final Value'
                : (_mode == InterestMode.sip ? 'Expected Annual Return (%)' : 'Annual Interest Rate (%)'),
            controller: _rateController,
            hintText: _mode == InterestMode.cagr ? '25000' : '7.5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixText: _mode == InterestMode.cagr ? '₹' : null,
            suffixText: _mode == InterestMode.cagr ? null : '% p.a.',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            label: _mode == InterestMode.cagr ? 'Duration / Period (Years)' : 'Investment Period (Years)',
            controller: _timeController,
            hintText: '5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixText: 'Years',
            onChanged: (_) => setState(() {}),
          ),

          if (_mode == InterestMode.compound) ...[
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
