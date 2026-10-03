import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class GstCalculatorScreen extends StatefulWidget {
  const GstCalculatorScreen({super.key});

  @override
  State<GstCalculatorScreen> createState() => _GstCalculatorScreenState();
}

class _GstCalculatorScreenState extends State<GstCalculatorScreen> {
  final TextEditingController _amountController = TextEditingController(text: '1000');
  final TextEditingController _customRateController = TextEditingController(text: '18');
  bool _isGstExclusive = true; // true = Add GST (exclusive), false = Remove GST (inclusive)
  double _selectedRate = 18.0;
  bool _isCustomRate = false;

  final List<double> _presetRates = [5.0, 12.0, 18.0, 28.0];

  Map<String, double> _calculateGst() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final rate = _isCustomRate
        ? (double.tryParse(_customRateController.text.trim()) ?? 0)
        : _selectedRate;

    double netAmount = 0;
    double gstAmount = 0;
    double totalAmount = 0;

    if (_isGstExclusive) {
      // Exclusive: Amount is base price; Add GST
      netAmount = amount;
      gstAmount = amount * (rate / 100);
      totalAmount = netAmount + gstAmount;
    } else {
      // Inclusive: Amount is total price; Extract GST
      totalAmount = amount;
      netAmount = amount / (1 + (rate / 100));
      gstAmount = totalAmount - netAmount;
    }

    final cgst = gstAmount / 2;
    final sgst = gstAmount / 2;

    return {
      'netAmount': netAmount,
      'gstAmount': gstAmount,
      'totalAmount': totalAmount,
      'cgst': cgst,
      'sgst': sgst,
      'rate': rate,
    };
  }

  @override
  void dispose() {
    _amountController.dispose();
    _customRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _calculateGst();
    final currencyFmt = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

    return ToolScaffold(
      title: 'GST Calculator',
      category: ToolCategory.finance,
      toolId: 'gst_calc',
      onReset: () {
        setState(() {
          _amountController.text = '1000';
          _selectedRate = 18.0;
          _isCustomRate = false;
          _isGstExclusive = true;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inclusive / Exclusive Selector Toggle
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
                    label: const Center(child: Text('Exclusive (Add GST)')),
                    selected: _isGstExclusive,
                    selectedColor: AppColors.catFinance,
                    labelStyle: TextStyle(
                      color: _isGstExclusive ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _isGstExclusive = true);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Inclusive (Remove GST)')),
                    selected: !_isGstExclusive,
                    selectedColor: AppColors.catFinance,
                    labelStyle: TextStyle(
                      color: !_isGstExclusive ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _isGstExclusive = false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Result Card
          ResultCard(
            title: _isGstExclusive ? 'Total Amount (With Tax)' : 'Net Amount (Pre-Tax)',
            primaryResult: currencyFmt.format(_isGstExclusive ? data['totalAmount'] : data['netAmount']),
            subtitle: 'GST Tax @ ${data['rate']}%: ${currencyFmt.format(data['gstAmount'])}',
            accentColor: AppColors.catFinance,
            breakdowns: [
              BreakdownItem(
                label: 'Net Price',
                value: currencyFmt.format(data['netAmount']),
              ),
              BreakdownItem(
                label: 'Total GST Tax',
                value: currencyFmt.format(data['gstAmount']),
              ),
              BreakdownItem(
                label: 'CGST (${(data['rate']! / 2).toStringAsFixed(1)}%)',
                value: currencyFmt.format(data['cgst']),
              ),
              BreakdownItem(
                label: 'SGST (${(data['rate']! / 2).toStringAsFixed(1)}%)',
                value: currencyFmt.format(data['sgst']),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Amount Input
          ModernTextField(
            label: _isGstExclusive ? 'Base Amount' : 'Gross Amount (Tax Included)',
            controller: _amountController,
            hintText: '1000',
            prefixText: '₹',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // Rate Selector Chips
          const Text(
            'Select GST Tax Rate',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ..._presetRates.map((rate) {
                final isSelected = !_isCustomRate && _selectedRate == rate;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: ChoiceChip(
                      label: Center(child: Text('${rate.toInt()}%')),
                      selected: isSelected,
                      selectedColor: AppColors.catFinance,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        if (val) {
                          PreferencesService().triggerHaptic();
                          setState(() {
                            _selectedRate = rate;
                            _isCustomRate = false;
                          });
                        }
                      },
                    ),
                  ),
                );
              }),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: ChoiceChip(
                    label: const Center(child: Text('Custom')),
                    selected: _isCustomRate,
                    selectedColor: AppColors.catFinance,
                    labelStyle: TextStyle(
                      color: _isCustomRate ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _isCustomRate = true);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          if (_isCustomRate) ...[
            const SizedBox(height: 16),
            ModernTextField(
              label: 'Custom Tax Rate (%)',
              controller: _customRateController,
              hintText: 'e.g. 15',
              suffixText: '%',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }
}
