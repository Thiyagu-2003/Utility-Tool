import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class CurrencyInfo {
  final String code;
  final String name;
  final String symbol;
  final String flag;
  final double rateToUsd; // 1 USD = rateToUsd units of this currency

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    required this.flag,
    required this.rateToUsd,
  });
}

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final TextEditingController _amountController = TextEditingController(text: '100');

  static const List<CurrencyInfo> _currencies = [
    CurrencyInfo(code: 'USD', name: 'United States Dollar', symbol: '\$', flag: '🇺🇸', rateToUsd: 1.0),
    CurrencyInfo(code: 'INR', name: 'Indian Rupee', symbol: '₹', flag: '🇮🇳', rateToUsd: 86.50),
    CurrencyInfo(code: 'EUR', name: 'Euro', symbol: '€', flag: '🇪🇺', rateToUsd: 0.92),
    CurrencyInfo(code: 'GBP', name: 'British Pound', symbol: '£', flag: '🇬🇧', rateToUsd: 0.79),
    CurrencyInfo(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', flag: '🇦🇪', rateToUsd: 3.67),
    CurrencyInfo(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flag: '🇯🇵', rateToUsd: 153.20),
    CurrencyInfo(code: 'CAD', name: 'Canadian Dollar', symbol: 'CA\$', flag: '🇨🇦', rateToUsd: 1.38),
    CurrencyInfo(code: 'AUD', name: 'Australian Dollar', symbol: 'AU\$', flag: '🇦🇺', rateToUsd: 1.54),
    CurrencyInfo(code: 'SGD', name: 'Singapore Dollar', symbol: 'SG\$', flag: '🇸🇬', rateToUsd: 1.35),
    CurrencyInfo(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flag: '🇨🇳', rateToUsd: 7.24),
    CurrencyInfo(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF', flag: '🇨🇭', rateToUsd: 0.89),
  ];

  late CurrencyInfo _fromCurrency;
  late CurrencyInfo _toCurrency;

  @override
  void initState() {
    super.initState();
    _fromCurrency = _currencies[0]; // USD
    _toCurrency = _currencies[1];   // INR
  }

  double _convert(double amount, CurrencyInfo from, CurrencyInfo to) {
    if (from.code == to.code) return amount;
    // convert from -> USD -> to
    final amountInUsd = amount / from.rateToUsd;
    return amountInUsd * to.rateToUsd;
  }

  void _swapCurrencies() {
    PreferencesService().triggerHaptic();
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final converted = _convert(amount, _fromCurrency, _toCurrency);

    final formatter = NumberFormat('#,##0.00');
    final formattedResult = '${_toCurrency.symbol} ${formatter.format(converted)}';
    final oneUnitRate = _convert(1, _fromCurrency, _toCurrency);

    return ToolScaffold(
      title: 'Currency Converter',
      category: ToolCategory.finance,
      toolId: 'currency_converter',
      onReset: () {
        setState(() {
          _amountController.text = '100';
          _fromCurrency = _currencies[0];
          _toCurrency = _currencies[1];
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: '${_fromCurrency.code} to ${_toCurrency.code}',
            primaryResult: formattedResult,
            subtitle: '1 ${_fromCurrency.code} = ${formatter.format(oneUnitRate)} ${_toCurrency.code} (Offline rate)',
            accentColor: AppColors.catFinance,
            breakdowns: [
              BreakdownItem(
                label: 'Base Rate (1 ${_fromCurrency.code})',
                value: '${_toCurrency.symbol} ${formatter.format(oneUnitRate)}',
              ),
              BreakdownItem(
                label: 'Inverse (1 ${_toCurrency.code})',
                value: '${_fromCurrency.symbol} ${formatter.format(_convert(1, _toCurrency, _fromCurrency))}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          ModernTextField(
            label: 'Enter Amount',
            controller: _amountController,
            hintText: '100',
            prefixText: _fromCurrency.symbol,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Currency Dropdowns with Swap Button
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightCardHover,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CurrencyInfo>(
                      isExpanded: true,
                      value: _fromCurrency,
                      items: _currencies.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text('${c.flag} ${c.code}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (newC) {
                        if (newC != null) {
                          PreferencesService().triggerSelectionHaptic();
                          setState(() => _fromCurrency = newC);
                        }
                      },
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Swap Currencies',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.catFinance.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: AppColors.catFinance),
                ),
                onPressed: _swapCurrencies,
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightCardHover,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CurrencyInfo>(
                      isExpanded: true,
                      value: _toCurrency,
                      items: _currencies.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text('${c.flag} ${c.code}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (newC) {
                        if (newC != null) {
                          PreferencesService().triggerSelectionHaptic();
                          setState(() => _toCurrency = newC);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Multi-Currency Comparison List
          Text(
            'All Currencies Comparison'.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currencies.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final curr = _currencies[index];
                final convertedVal = _convert(amount, _fromCurrency, curr);
                final isCurrent = curr.code == _toCurrency.code;

                return ListTile(
                  dense: true,
                  leading: Text(curr.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    curr.name,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? AppColors.catFinance : null,
                    ),
                  ),
                  subtitle: Text(curr.code),
                  trailing: Text(
                    '${curr.symbol} ${formatter.format(convertedVal)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isCurrent ? AppColors.catFinance : null,
                    ),
                  ),
                  onTap: () {
                    PreferencesService().triggerSelectionHaptic();
                    setState(() => _toCurrency = curr);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
