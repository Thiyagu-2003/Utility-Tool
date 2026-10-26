import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum UnitType {
  length('Length', Icons.straighten_rounded),
  mass('Mass & Weight', Icons.fitness_center_rounded),
  temperature('Temperature', Icons.thermostat_rounded),
  area('Area', Icons.crop_square_rounded),
  volume('Volume', Icons.opacity_rounded),
  speed('Speed', Icons.speed_rounded),
  data('Data Storage', Icons.sd_storage_rounded);

  final String label;
  final IconData icon;
  const UnitType(this.label, this.icon);
}

final _plainFormat = NumberFormat('#,##0.######');

/// Plain grouped number for everyday values; scientific notation when the
/// plain form would show "0" for a non-zero value or run past 15 digits.
String formatUnitValue(double v) {
  if (v.isNaN) return 'NaN';
  if (v.isInfinite) return v.isNegative ? '-∞' : '∞';
  final a = v.abs();
  if (a != 0 && (a < 1e-6 || a >= 1e15)) {
    return v.toStringAsExponential(6).replaceFirst(RegExp(r'\.?0+e'), 'e').replaceFirst('e+', 'e');
  }
  return _plainFormat.format(v);
}

class UnitDefinition {
  final String name;
  final String symbol;
  final double toBaseFactor;

  const UnitDefinition(this.name, this.symbol, this.toBaseFactor);
}

class UnitConverterScreen extends StatefulWidget {
  const UnitConverterScreen({super.key});

  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  UnitType _currentType = UnitType.length;
  final TextEditingController _inputController = TextEditingController(text: '1');
  late UnitDefinition _fromUnit;
  late UnitDefinition _toUnit;

  static const Map<UnitType, List<UnitDefinition>> _units = {
    UnitType.length: [
      UnitDefinition('Meter', 'm', 1.0),
      UnitDefinition('Kilometer', 'km', 1000.0),
      UnitDefinition('Centimeter', 'cm', 0.01),
      UnitDefinition('Millimeter', 'mm', 0.001),
      UnitDefinition('Mile', 'mi', 1609.344),
      UnitDefinition('Yard', 'yd', 0.9144),
      UnitDefinition('Foot', 'ft', 0.3048),
      UnitDefinition('Inch', 'in', 0.0254),
      UnitDefinition('Nautical Mile', 'NM', 1852.0),
    ],
    UnitType.mass: [
      UnitDefinition('Kilogram', 'kg', 1.0),
      UnitDefinition('Gram', 'g', 0.001),
      UnitDefinition('Milligram', 'mg', 0.000001),
      UnitDefinition('Metric Ton', 't', 1000.0),
      UnitDefinition('Pound', 'lb', 0.45359237),
      UnitDefinition('Ounce', 'oz', 0.028349523125),
    ],
    UnitType.temperature: [
      UnitDefinition('Celsius', '°C', 1.0),
      UnitDefinition('Fahrenheit', '°F', 1.0),
      UnitDefinition('Kelvin', 'K', 1.0),
    ],
    UnitType.area: [
      UnitDefinition('Square Meter', 'm²', 1.0),
      UnitDefinition('Square Kilometer', 'km²', 1000000.0),
      UnitDefinition('Square Foot', 'ft²', 0.09290304),
      UnitDefinition('Square Yard', 'yd²', 0.83612736),
      UnitDefinition('Acre', 'ac', 4046.8564224),
      UnitDefinition('Hectare', 'ha', 10000.0),
      UnitDefinition('Cent', 'cent', 40.468564224),
      UnitDefinition('Guntha', 'guntha', 101.17141056),
      UnitDefinition('Ground', 'ground', 222.967296),
      UnitDefinition('Bigha', 'bigha', 2508.38208),
      UnitDefinition('Bigha (UP/Bihar Pucca)', 'bigha (UP)', 2529.285264),
      UnitDefinition('Bigha (Bengal/Assam)', 'bigha (WB)', 1337.803776),
    ],
    UnitType.volume: [
      UnitDefinition('Liter', 'L', 1.0),
      UnitDefinition('Milliliter', 'mL', 0.001),
      UnitDefinition('Cubic Meter', 'm³', 1000.0),
      UnitDefinition('US Gallon', 'gal', 3.785411784),
      UnitDefinition('US Pint', 'pt', 0.473176473),
      UnitDefinition('Fluid Ounce', 'fl oz', 0.0295735295625),
    ],
    UnitType.speed: [
      UnitDefinition('Meters / second', 'm/s', 1.0),
      UnitDefinition('Kilometers / hour', 'km/h', 1 / 3.6),
      UnitDefinition('Miles / hour', 'mph', 0.44704),
      UnitDefinition('Knot', 'kn', 1852 / 3600),
    ],
    UnitType.data: [
      UnitDefinition('Byte', 'B', 1.0),
      UnitDefinition('Kilobyte', 'KB', 1024.0),
      UnitDefinition('Megabyte', 'MB', 1048576.0),
      UnitDefinition('Gigabyte', 'GB', 1073741824.0),
      UnitDefinition('Terabyte', 'TB', 1099511627776.0),
      UnitDefinition('Petabyte', 'PB', 1125899906842624.0),
    ],
  };

  @override
  void initState() {
    super.initState();
    _resetUnitsForType();
  }

  void _resetUnitsForType() {
    final list = _units[_currentType]!;
    _fromUnit = list[0];
    _toUnit = list.length > 1 ? list[1] : list[0];
  }

  double _convertValue(double inputVal, UnitDefinition from, UnitDefinition to) {
    if (_currentType == UnitType.temperature) {
      if (from.name == to.name) return inputVal;
      // Convert from to Celsius first
      double celsius = inputVal;
      if (from.name == 'Fahrenheit') {
        celsius = (inputVal - 32) * 5 / 9;
      } else if (from.name == 'Kelvin') {
        celsius = inputVal - 273.15;
      }

      // Convert Celsius to toUnit
      if (to.name == 'Celsius') return celsius;
      if (to.name == 'Fahrenheit') return (celsius * 9 / 5) + 32;
      if (to.name == 'Kelvin') return celsius + 273.15;
      return celsius;
    }

    final baseVal = inputVal * from.toBaseFactor;
    return baseVal / to.toBaseFactor;
  }

  void _swapUnits() {
    PreferencesService().triggerHaptic();
    setState(() {
      final temp = _fromUnit;
      _fromUnit = _toUnit;
      _toUnit = temp;
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentList = _units[_currentType]!;

    // Non-finite input ("1e999") is treated like empty input instead of showing Infinity/NaN.
    final parsed = double.tryParse(_inputController.text.trim());
    final inputVal = parsed != null && parsed.isFinite ? parsed : 0.0;
    final resultVal = _convertValue(inputVal, _fromUnit, _toUnit);

    final formattedResult = '${formatUnitValue(resultVal)} ${_toUnit.symbol}';

    return ToolScaffold(
      title: 'Unit Converter',
      category: ToolCategory.converters,
      toolId: 'unit_converter',
      onReset: () {
        setState(() {
          _inputController.text = '1';
          _resetUnitsForType();
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category selector
          FeatureTabSelector<UnitType>(
            tabs: UnitType.values
                .map((type) => FeatureTabItem(value: type, label: type.label, icon: type.icon))
                .toList(),
            activeTab: _currentType,
            accentColor: AppColors.catConverter,
            title: 'Unit Converter Categories',
            onTabSelected: (type) {
              setState(() {
                _currentType = type;
                _resetUnitsForType();
              });
            },
          ),
          const SizedBox(height: 20),

          // Main Result Card
          ResultCard(
            title: '${_fromUnit.name} to ${_toUnit.name}',
            primaryResult: formattedResult,
            subtitle: '${formatUnitValue(inputVal)} ${_fromUnit.symbol} = $formattedResult',
            accentColor: AppColors.catConverter,
          ),
          const SizedBox(height: 20),

          // Input Value
          ModernTextField(
            label: 'Enter Value',
            controller: _inputController,
            hintText: '1.0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icons.edit_note_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Units Row with Swap Button
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
                    child: DropdownButton<UnitDefinition>(
                      isExpanded: true,
                      value: _fromUnit,
                      items: currentList.map((u) {
                        return DropdownMenuItem(
                          value: u,
                          child: Text('${u.name} (${u.symbol})', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (newU) {
                        if (newU != null) {
                          PreferencesService().triggerSelectionHaptic();
                          setState(() => _fromUnit = newU);
                        }
                      },
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Swap Units',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.catConverter.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: AppColors.catConverter),
                ),
                onPressed: _swapUnits,
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
                    child: DropdownButton<UnitDefinition>(
                      isExpanded: true,
                      value: _toUnit,
                      items: currentList.map((u) {
                        return DropdownMenuItem(
                          value: u,
                          child: Text('${u.name} (${u.symbol})', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (newU) {
                        if (newU != null) {
                          PreferencesService().triggerSelectionHaptic();
                          setState(() => _toUnit = newU);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // All Units Quick Reference List
          Text(
            'All Equivalent Values'.toUpperCase(),
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
            child: Material(
              type: MaterialType.transparency,
              child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentList.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final unit = currentList[index];
                final converted = _convertValue(inputVal, _fromUnit, unit);
                final isCurrentTarget = unit.name == _toUnit.name;

                final accent = isCurrentTarget ? AppColors.catConverter : null;
                return InkWell(
                  onTap: () {
                    PreferencesService().triggerSelectionHaptic();
                    setState(() => _toUnit = unit);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            unit.name,
                            style: TextStyle(fontWeight: isCurrentTarget ? FontWeight.bold : FontWeight.w500, color: accent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${formatUnitValue(converted)} ${unit.symbol}',
                            textAlign: TextAlign.end,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ),
          ),
        ],
      ),
    );
  }
}
