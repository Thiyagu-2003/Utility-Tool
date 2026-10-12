import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class DiscountCalculatorScreen extends StatefulWidget {
  const DiscountCalculatorScreen({super.key});

  @override
  State<DiscountCalculatorScreen> createState() => _DiscountCalculatorScreenState();
}

class _DiscountCalculatorScreenState extends State<DiscountCalculatorScreen> {
  final TextEditingController _priceController = TextEditingController(text: '2499');
  final TextEditingController _discountController = TextEditingController(text: '30');
  final TextEditingController _extraDiscountController = TextEditingController(text: '10');
  final TextEditingController _taxController = TextEditingController(text: '0');
  bool _enableExtraDiscount = false;

  final List<double> _presetDiscounts = [10, 15, 20, 25, 30, 50];

  // Empty, invalid or non-finite ("1e999") input counts as 0.
  double _num(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    return v != null && v.isFinite ? v : 0.0;
  }

  Map<String, double> _calculateDiscount() {
    final originalPrice = _num(_priceController);
    // Discounts are clamped to 0-100% so the price can't go negative.
    final discountPercent = _num(_discountController).clamp(0.0, 100.0);
    final extraDiscountPercent = _enableExtraDiscount ? _num(_extraDiscountController).clamp(0.0, 100.0) : 0.0;
    final taxPercent = _num(_taxController).clamp(0.0, 100.0);

    final firstDiscountAmount = originalPrice * (discountPercent / 100);
    final priceAfterFirst = originalPrice - firstDiscountAmount;

    final extraDiscountAmount = priceAfterFirst * (extraDiscountPercent / 100);
    final discountedPrice = priceAfterFirst - extraDiscountAmount;
    // Sales tax applies to the discounted price; savings are discount-only.
    final taxAmount = discountedPrice * (taxPercent / 100);
    final finalPrice = discountedPrice + taxAmount;
    final totalSavings = originalPrice - discountedPrice;
    final effectiveDiscountPercent = originalPrice > 0 ? (totalSavings / originalPrice) * 100 : 0.0;

    return {
      'taxAmount': taxAmount,
      'finalPrice': finalPrice,
      'totalSavings': totalSavings,
      'effectivePercent': effectiveDiscountPercent,
      'originalPrice': originalPrice,
    };
  }

  @override
  void dispose() {
    _priceController.dispose();
    _discountController.dispose();
    _extraDiscountController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _calculateDiscount();
    final currencyFmt = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

    return ToolScaffold(
      title: 'Discount Calculator',
      category: ToolCategory.finance,
      toolId: 'discount_calc',
      onReset: () {
        setState(() {
          _priceController.text = '2499';
          _discountController.text = '30';
          _extraDiscountController.text = '10';
          _taxController.text = '0';
          _enableExtraDiscount = false;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Final Price to Pay',
            primaryResult: currencyFmt.format(data['finalPrice']),
            subtitle: 'You save ${currencyFmt.format(data['totalSavings'])} (${data['effectivePercent']!.toStringAsFixed(1)}% off)',
            accentColor: AppColors.catFinance,
            breakdowns: [
              BreakdownItem(
                label: 'Original Price',
                value: currencyFmt.format(data['originalPrice']),
              ),
              BreakdownItem(
                label: 'Total Discount',
                value: currencyFmt.format(data['totalSavings']),
              ),
              BreakdownItem(
                label: 'Total Savings %',
                value: '${data['effectivePercent']!.toStringAsFixed(1)}%',
              ),
              BreakdownItem(
                label: 'Sales Tax',
                value: currencyFmt.format(data['taxAmount']),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ModernTextField(
            label: 'Original Price',
            controller: _priceController,
            hintText: '2499',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixText: '₹',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Primary Discount (%)',
            controller: _discountController,
            hintText: '30',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixText: '%',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Quick discount chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetDiscounts.map((preset) {
              return ActionChip(
                label: Text('${preset.toInt()}%'),
                onPressed: () {
                  PreferencesService().triggerHaptic();
                  setState(() {
                    _discountController.text = preset.toInt().toString();
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Add Additional Discount (e.g. 50% + 10% off)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text('Calculate multi-tier stackable promo discount'),
            value: _enableExtraDiscount,
            activeThumbColor: AppColors.catFinance,
            onChanged: (val) {
              PreferencesService().triggerHaptic();
              setState(() => _enableExtraDiscount = val);
            },
          ),
          if (_enableExtraDiscount) ...[
            const SizedBox(height: 8),
            ModernTextField(
              label: 'Additional Discount (%)',
              controller: _extraDiscountController,
              hintText: '10',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              suffixText: '% extra',
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Sales Tax Rate (%) - optional',
            controller: _taxController,
            hintText: '0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixText: '%',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
