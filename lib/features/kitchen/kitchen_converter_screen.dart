import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class KitchenConverterScreen extends StatefulWidget {
  const KitchenConverterScreen({super.key});

  @override
  State<KitchenConverterScreen> createState() => _KitchenConverterScreenState();
}

class _KitchenConverterScreenState extends State<KitchenConverterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Recipe Scaler state
  final TextEditingController _baseServingsCtrl =
      TextEditingController(text: '2');
  final TextEditingController _targetServingsCtrl =
      TextEditingController(text: '4');
  final List<Map<String, dynamic>> _ingredients = [
    {'name': 'All-purpose Flour', 'amount': 250.0, 'unit': 'g'},
    {'name': 'Granulated Sugar', 'amount': 100.0, 'unit': 'g'},
    {'name': 'Unsalted Butter', 'amount': 120.0, 'unit': 'g'},
    {'name': 'Fresh Milk', 'amount': 150.0, 'unit': 'ml'},
    {'name': 'Baking Powder', 'amount': 2.0, 'unit': 'tsp'},
  ];

  // Volume & Weight Kitchen Converter state
  final TextEditingController _inputAmountCtrl =
      TextEditingController(text: '1');
  String _selectedFromUnit = 'cup';
  String _selectedToUnit = 'tbsp';

  static const Map<String, double> _volumeToMl = {
    'tsp': 4.92892,
    'tbsp': 14.7868,
    'fl oz': 29.5735,
    'cup': 236.588,
    'pint': 473.176,
    'quart': 946.353,
    'ml': 1.0,
    'liter': 1000.0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _baseServingsCtrl.dispose();
    _targetServingsCtrl.dispose();
    _inputAmountCtrl.dispose();
    super.dispose();
  }

  double get _scaleFactor {
    final base = double.tryParse(_baseServingsCtrl.text) ?? 1.0;
    final target = double.tryParse(_targetServingsCtrl.text) ?? 1.0;
    if (base <= 0) return 1.0;
    return target / base;
  }

  double get _convertedKitchenUnit {
    final amount = double.tryParse(_inputAmountCtrl.text) ?? 0.0;
    final fromInMl = (amount * (_volumeToMl[_selectedFromUnit] ?? 1.0));
    final toMlPerUnit = _volumeToMl[_selectedToUnit] ?? 1.0;
    return fromInMl / toMlPerUnit;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Kitchen & Recipe Tools'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF97316),
          labelColor: const Color(0xFFF97316),
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Recipe Scaler'),
            Tab(icon: Icon(Icons.swap_horiz), text: 'Volume Converter'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecipeScaler(isDark),
          _buildVolumeConverter(isDark),
        ],
      ),
    );
  }

  Widget _buildRecipeScaler(bool isDark) {
    final factor = _scaleFactor;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Servings config card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      color: Color(0xFFF97316),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Serving Yield Adjuster',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${factor.toStringAsFixed(2)}x scale',
                      style: const TextStyle(
                        color: Color(0xFFF97316),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Original Servings',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
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
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Target Servings',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
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
                    label: Text('${preset}x'),
                    onPressed: () {
                      final base = double.tryParse(_baseServingsCtrl.text) ?? 2.0;
                      _targetServingsCtrl.text =
                          (base * preset).round().toString();
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'Scaled Ingredients',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),

        ..._ingredients.map((item) {
          final scaledAmt = (item['amount'] as double) * factor;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF97316),
                foregroundColor: Colors.white,
                child: Icon(Icons.check, size: 18),
              ),
              title: Text(
                item['name'],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Original: ${(item['amount'] as double).toStringAsFixed(1)} ${item['unit']}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                '${scaledAmt >= 10 ? scaledAmt.toStringAsFixed(1) : scaledAmt.toStringAsFixed(2)} ${item['unit']}',
                style: const TextStyle(
                  color: Color(0xFFF97316),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVolumeConverter(bool isDark) {
    final result = _convertedKitchenUnit;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _inputAmountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                      value: _selectedFromUnit,
                      decoration: const InputDecoration(
                        labelText: 'From Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: _volumeToMl.keys.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedFromUnit = val);
                      },
                    ),
                  ),
                  IconButton(
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
                      value: _selectedToUnit,
                      decoration: const InputDecoration(
                        labelText: 'To Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: _volumeToMl.keys.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit.toUpperCase()),
                        );
                      }).toList(),
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF97316).withOpacity(0.18),
                const Color(0xFFEA580C).withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF97316).withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Calculated Measurement',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.toStringAsFixed(3)} $_selectedToUnit',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF97316),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_inputAmountCtrl.text} $_selectedFromUnit = ${(double.tryParse(_inputAmountCtrl.text) ?? 1) * (_volumeToMl[_selectedFromUnit] ?? 1)} ml',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'Quick Reference Equivalencies',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildRefRow('1 Cup', '16 Tablespoons / 240 ml'),
        _buildRefRow('1 Tablespoon', '3 Teaspoons / 15 ml'),
        _buildRefRow('1 Fluid Ounce', '2 Tablespoons / ~30 ml'),
        _buildRefRow('1 Stick Butter', '1/2 Cup / 113 grams / 8 tbsp'),
      ],
    );
  }

  Widget _buildRefRow(String left, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(right, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
