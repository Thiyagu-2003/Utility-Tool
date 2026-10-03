import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum CalculationMode {
  byUnits('By Monthly Units (kWh)'),
  byAppliance('By Appliance Usage');

  final String label;
  const CalculationMode(this.label);
}

class AppliancePreset {
  final String name;
  final int wattage;
  final double typicalHours;
  final IconData icon;

  const AppliancePreset(this.name, this.wattage, this.typicalHours, this.icon);
}

class ElectricityBillScreen extends StatefulWidget {
  const ElectricityBillScreen({super.key});

  @override
  State<ElectricityBillScreen> createState() => _ElectricityBillScreenState();
}

class _ElectricityBillScreenState extends State<ElectricityBillScreen> {
  CalculationMode _mode = CalculationMode.byUnits;

  // By Units State
  final TextEditingController _unitsController = TextEditingController(text: '250');
  final TextEditingController _ratePerUnitController = TextEditingController(text: '7.5');
  final TextEditingController _fixedChargesController = TextEditingController(text: '60');
  final TextEditingController _taxPercentController = TextEditingController(text: '5');

  // By Appliance State
  final TextEditingController _applianceWattController = TextEditingController(text: '1500');
  final TextEditingController _hoursPerDayController = TextEditingController(text: '8');
  final TextEditingController _quantityController = TextEditingController(text: '1');

  static const List<AppliancePreset> _presets = [
    AppliancePreset('Air Conditioner (1.5T)', 1500, 8, Icons.ac_unit_rounded),
    AppliancePreset('Refrigerator', 200, 24, Icons.kitchen_rounded),
    AppliancePreset('Water Geyser', 2000, 1.5, Icons.water_drop_rounded),
    AppliancePreset('Ceiling Fan', 75, 12, Icons.mode_fan_off_rounded),
    AppliancePreset('LED TV (55")', 100, 5, Icons.tv_rounded),
    AppliancePreset('Washing Machine', 500, 1, Icons.local_laundry_service_rounded),
    AppliancePreset('Microwave Oven', 1200, 0.5, Icons.microwave_rounded),
    AppliancePreset('Laptop / PC', 120, 8, Icons.computer_rounded),
    AppliancePreset('LED Bulb', 10, 8, Icons.lightbulb_outline_rounded),
  ];

  Map<String, double> _calculateBill() {
    final ratePerUnit = double.tryParse(_ratePerUnitController.text.trim()) ?? 0;
    final fixedCharge = double.tryParse(_fixedChargesController.text.trim()) ?? 0;
    final taxPercent = double.tryParse(_taxPercentController.text.trim()) ?? 0;

    double monthlyKwh = 0;

    if (_mode == CalculationMode.byUnits) {
      monthlyKwh = double.tryParse(_unitsController.text.trim()) ?? 0;
    } else {
      final watts = double.tryParse(_applianceWattController.text.trim()) ?? 0;
      final hours = double.tryParse(_hoursPerDayController.text.trim()) ?? 0;
      final qty = double.tryParse(_quantityController.text.trim()) ?? 1;

      // kWh per day = (Watts * hours * qty) / 1000
      final dailyKwh = (watts * hours * qty) / 1000.0;
      monthlyKwh = dailyKwh * 30.0;
    }

    final energyCharge = monthlyKwh * ratePerUnit;
    final subtotal = energyCharge + fixedCharge;
    final taxAmount = subtotal * (taxPercent / 100.0);
    final totalBill = subtotal + taxAmount;
    final dailyCost = totalBill / 30.0;
    final annualCost = totalBill * 12.0;

    return {
      'monthlyKwh': monthlyKwh,
      'dailyKwh': monthlyKwh / 30.0,
      'energyCharge': energyCharge,
      'fixedCharge': fixedCharge,
      'taxAmount': taxAmount,
      'totalBill': totalBill,
      'dailyCost': dailyCost,
      'annualCost': annualCost,
    };
  }

  void _applyPreset(AppliancePreset preset) {
    PreferencesService().triggerHaptic();
    setState(() {
      _applianceWattController.text = preset.wattage.toString();
      _hoursPerDayController.text = preset.typicalHours.toString();
    });
  }

  @override
  void dispose() {
    _unitsController.dispose();
    _ratePerUnitController.dispose();
    _fixedChargesController.dispose();
    _taxPercentController.dispose();
    _applianceWattController.dispose();
    _hoursPerDayController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = _calculateBill();
    final currencyFmt = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
    final numFmt = NumberFormat('#,##0.##');

    return ToolScaffold(
      title: 'Electricity Bill Estimator',
      category: ToolCategory.finance,
      toolId: 'electricity_bill',
      onReset: () {
        setState(() {
          _unitsController.text = '250';
          _ratePerUnitController.text = '7.5';
          _fixedChargesController.text = '60';
          _taxPercentController.text = '5';
          _applianceWattController.text = '1500';
          _hoursPerDayController.text = '8';
          _quantityController.text = '1';
          _mode = CalculationMode.byUnits;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightCardHover,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: CalculationMode.values.map((mode) {
                final isSelected = mode == _mode;
                return Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(mode.label)),
                    selected: isSelected,
                    selectedColor: AppColors.catFinance,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _mode = mode);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Primary Result Card
          ResultCard(
            title: 'Estimated Monthly Bill',
            primaryResult: currencyFmt.format(data['totalBill']),
            subtitle: 'Power Consumption: ${numFmt.format(data['monthlyKwh'])} kWh (Units) / month',
            accentColor: AppColors.catFinance,
            breakdowns: [
              BreakdownItem(
                label: 'Energy Charges',
                value: currencyFmt.format(data['energyCharge']),
              ),
              BreakdownItem(
                label: 'Fixed / Meter Fee',
                value: currencyFmt.format(data['fixedCharge']),
              ),
              BreakdownItem(
                label: 'Tax / Duty Amount',
                value: currencyFmt.format(data['taxAmount']),
              ),
              BreakdownItem(
                label: 'Estimated Daily Cost',
                value: currencyFmt.format(data['dailyCost']),
              ),
              BreakdownItem(
                label: 'Annual Cost Projection',
                value: currencyFmt.format(data['annualCost']),
              ),
              BreakdownItem(
                label: 'Avg Daily Power',
                value: '${numFmt.format(data['dailyKwh'])} kWh',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Rate and Common Settings
          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  label: 'Rate per Unit (kWh)',
                  controller: _ratePerUnitController,
                  hintText: '7.5',
                  prefixText: '₹',
                  suffixText: '/ unit',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ModernTextField(
                  label: 'Fixed Charges',
                  controller: _fixedChargesController,
                  hintText: '60',
                  prefixText: '₹',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ModernTextField(
            label: 'Electricity Duty / Tax (%)',
            controller: _taxPercentController,
            hintText: '5',
            suffixText: '%',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          if (_mode == CalculationMode.byUnits) ...[
            ModernTextField(
              label: 'Monthly Units Consumed (kWh)',
              controller: _unitsController,
              hintText: '250',
              prefixIcon: Icons.bolt_rounded,
              suffixText: 'kWh',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [100, 150, 200, 250, 300, 400, 500].map((units) {
                return ActionChip(
                  label: Text('$units units'),
                  onPressed: () {
                    PreferencesService().triggerHaptic();
                    setState(() => _unitsController.text = units.toString());
                  },
                );
              }).toList(),
            ),
          ] else ...[
            // Appliance Mode
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ModernTextField(
                    label: 'Appliance Power (Watts)',
                    controller: _applianceWattController,
                    hintText: '1500',
                    prefixIcon: Icons.power_rounded,
                    suffixText: 'Watts',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModernTextField(
                    label: 'Quantity',
                    controller: _quantityController,
                    hintText: '1',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ModernTextField(
              label: 'Daily Usage (Hours / Day)',
              controller: _hoursPerDayController,
              hintText: '8',
              prefixIcon: Icons.access_time_rounded,
              suffixText: 'hrs / day',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            Text(
              'Quick Appliance Presets'.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                return ActionChip(
                  avatar: Icon(preset.icon, size: 16, color: AppColors.catFinance),
                  label: Text('${preset.name} (${preset.wattage}W)'),
                  onPressed: () => _applyPreset(preset),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
