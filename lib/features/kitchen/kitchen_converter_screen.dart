import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validation_utils.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/tool_scaffold.dart';

const _kitchenAccent = Color(0xFFF97316);

enum KitchenTab {
  scaler('Recipe Scaler', Icons.restaurant_menu),
  converter('Volume Converter', Icons.swap_horiz);

  final String label;
  final IconData icon;
  const KitchenTab(this.label, this.icon);
}

/// US customary kitchen volumes in millilitres.
const Map<String, double> kitchenVolumeToMl = {
  'tsp': 4.92892,
  'tbsp': 14.7868,
  'fl oz': 29.5735,
  'cup': 236.588,
  'pint': 473.176,
  'quart': 946.353,
  'ml': 1.0,
  'liter': 1000.0,
};

double convertKitchenVolume(double amount, String from, String to) =>
    amount * (kitchenVolumeToMl[from] ?? 1.0) / (kitchenVolumeToMl[to] ?? 1.0);

/// Multiplier from [base] servings to [target]. A blank/invalid or non-positive
/// base or target means "no scaling" (1.0) rather than a made-up serving count.
double recipeScaleFactor(double? base, double? target) {
  if (base == null || target == null || base <= 0 || target <= 0) return 1.0;
  return target / base;
}

class Ingredient {
  final String name;
  final double amount;
  final String unit;
  const Ingredient(this.name, this.amount, this.unit);
}

String _trim(double v, [int digits = 2]) {
  final s = v.toStringAsFixed(digits);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

class KitchenConverterScreen extends StatefulWidget {
  const KitchenConverterScreen({super.key});

  @override
  State<KitchenConverterScreen> createState() => _KitchenConverterScreenState();
}

class _KitchenConverterScreenState extends State<KitchenConverterScreen> {
  KitchenTab _tab = KitchenTab.scaler;

  // Recipe Scaler state
  final TextEditingController _baseServingsCtrl = TextEditingController(text: '2');
  final TextEditingController _targetServingsCtrl = TextEditingController(text: '4');
  static const List<Ingredient> _defaultIngredients = [
    Ingredient('All-purpose Flour', 250, 'g'),
    Ingredient('Granulated Sugar', 100, 'g'),
    Ingredient('Unsalted Butter', 120, 'g'),
    Ingredient('Fresh Milk', 150, 'ml'),
    Ingredient('Baking Powder', 2, 'tsp'),
  ];
  List<Ingredient> _ingredients = List.of(_defaultIngredients);

  // Volume converter state
  final TextEditingController _inputAmountCtrl = TextEditingController(text: '1');
  String _selectedFromUnit = 'cup';
  String _selectedToUnit = 'tbsp';

  @override
  void dispose() {
    _baseServingsCtrl.dispose();
    _targetServingsCtrl.dispose();
    _inputAmountCtrl.dispose();
    super.dispose();
  }

  double get _scaleFactor => recipeScaleFactor(
        double.tryParse(_baseServingsCtrl.text.trim()),
        double.tryParse(_targetServingsCtrl.text.trim()),
      );

  double get _convertedKitchenUnit =>
      convertKitchenVolume(ValidationUtils.safeParseDouble(_inputAmountCtrl.text), _selectedFromUnit, _selectedToUnit);

  Future<void> _addIngredient() async {
    final added = await showDialog<Ingredient>(context: context, builder: (_) => const _AddIngredientDialog());
    if (added != null && mounted) setState(() => _ingredients = [..._ingredients, added]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Kitchen & Recipe Tools',
      category: ToolCategory.kitchen,
      toolId: 'kitchen_calc',
      onReset: () {
        setState(() {
          _baseServingsCtrl.text = '2';
          _targetServingsCtrl.text = '4';
          _ingredients = List.of(_defaultIngredients);
          _inputAmountCtrl.text = '1';
          _selectedFromUnit = 'cup';
          _selectedToUnit = 'tbsp';
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeatureTabSelector<KitchenTab>(
            tabs: KitchenTab.values.map((t) => FeatureTabItem(value: t, label: t.label, icon: t.icon)).toList(),
            activeTab: _tab,
            accentColor: _kitchenAccent,
            title: 'Kitchen Tools',
            onTabSelected: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 16),
          if (_tab == KitchenTab.scaler) _buildRecipeScaler(isDark),
          if (_tab == KitchenTab.converter) _buildVolumeConverter(isDark),
        ],
      ),
    );
  }

  Widget _buildRecipeScaler(bool isDark) {
    final factor = _scaleFactor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Servings config card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kitchenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people_outline, color: _kitchenAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Serving Yield Adjuster',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kitchenAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${factor.toStringAsFixed(2)}x scale',
                      style: const TextStyle(color: _kitchenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _baseServingsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Original Servings',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _targetServingsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Target Servings',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [0.5, 1.0, 1.5, 2.0, 3.0, 4.0].map((preset) {
                  return ActionChip(
                    label: Text('${_trim(preset, 1)}x'),
                    onPressed: () {
                      PreferencesService().triggerHaptic();
                      final base = ValidationUtils.safeParseDouble(_baseServingsCtrl.text, defaultValue: 2.0);
                      setState(() => _targetServingsCtrl.text = _trim(base * preset, 1));
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text('Scaled Ingredients', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            TextButton.icon(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_ingredients.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No ingredients yet. Tap Add to enter one.', style: TextStyle(color: Colors.grey)),
          ),
        for (var i = 0; i < _ingredients.length; i++) _ingredientCard(i, factor, isDark),
      ],
    );
  }

  Widget _ingredientCard(int index, double factor, bool isDark) {
    final item = _ingredients[index];
    final scaled = item.amount * factor;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: _kitchenAccent,
          foregroundColor: Colors.white,
          child: Icon(Icons.check, size: 18),
        ),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Original: ${_trim(item.amount, 1)} ${item.unit}', style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${scaled >= 10 ? scaled.toStringAsFixed(1) : scaled.toStringAsFixed(2)} ${item.unit}',
              style: const TextStyle(color: _kitchenAccent, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              tooltip: 'Remove ${item.name}',
              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
              onPressed: () => setState(() => _ingredients = [..._ingredients]..removeAt(index)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeConverter(bool isDark) {
    final result = _convertedKitchenUnit;
    final amount = ValidationUtils.safeParseDouble(_inputAmountCtrl.text);
    final inMl = amount * (kitchenVolumeToMl[_selectedFromUnit] ?? 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _inputAmountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantity to Convert',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('from-$_selectedFromUnit'),
                      initialValue: _selectedFromUnit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'From Unit', border: OutlineInputBorder()),
                      items: kitchenVolumeToMl.keys
                          .map((unit) => DropdownMenuItem(value: unit, child: Text(unit.toUpperCase())))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedFromUnit = val);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Swap Units',
                    icon: const Icon(Icons.swap_horiz_rounded),
                    onPressed: () {
                      setState(() {
                        final temp = _selectedFromUnit;
                        _selectedFromUnit = _selectedToUnit;
                        _selectedToUnit = temp;
                      });
                    },
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('to-$_selectedToUnit'),
                      initialValue: _selectedToUnit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'To Unit', border: OutlineInputBorder()),
                      items: kitchenVolumeToMl.keys
                          .map((unit) => DropdownMenuItem(value: unit, child: Text(unit.toUpperCase())))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedToUnit = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kitchenAccent.withValues(alpha: 0.18),
                const Color(0xFFEA580C).withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kitchenAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Text('Calculated Measurement', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_trim(result, 3)} $_selectedToUnit',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _kitchenAccent),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_trim(amount, 3)} $_selectedFromUnit = ${_trim(inMl, 2)} ml',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Quick Reference Equivalencies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        _buildRefRow('1 Cup', '16 Tablespoons / ~237 ml (US)'),
        _buildRefRow('1 Tablespoon', '3 Teaspoons / ~15 ml'),
        _buildRefRow('1 Fluid Ounce', '2 Tablespoons / ~30 ml'),
        _buildRefRow('1 Stick Butter', '1/2 Cup / 113 grams / 8 tbsp'),
      ],
    );
  }

  Widget _buildRefRow(String left, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(left, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 12),
          Expanded(child: Text(right, textAlign: TextAlign.end, style: const TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}

/// Owns its controllers so they outlive the dialog's closing animation.
class _AddIngredientDialog extends StatefulWidget {
  const _AddIngredientDialog();

  @override
  State<_AddIngredientDialog> createState() => _AddIngredientDialogState();
}

class _AddIngredientDialogState extends State<_AddIngredientDialog> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _unit = 'g';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Ingredient'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: ['g', 'kg', 'ml', 'l', 'tsp', 'tbsp', 'cup', 'oz', 'lb', 'pcs']
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _unit = v ?? _unit),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final amount = ValidationUtils.safeParseDouble(_amountCtrl.text);
            if (_nameCtrl.text.trim().isEmpty || amount <= 0) return;
            Navigator.pop(context, Ingredient(_nameCtrl.text.trim(), amount, _unit));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
