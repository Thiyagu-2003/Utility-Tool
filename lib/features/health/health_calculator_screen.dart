import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/utils/validation_utils.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum Gender { male, female }

/// Ideal body weight (kg) from the four classic height formulas, which all
/// take the inches of height above 5 ft (extrapolated below 5 ft, never < 0).
({double devine, double robinson, double miller, double hamwi}) idealWeightFormulas(double heightCm, {required bool male}) {
  final over = heightCm / 2.54 - 60;
  double kg(double base, double perInch) => (base + perInch * over).clamp(0.0, double.infinity);
  return male
      ? (devine: kg(50, 2.3), robinson: kg(52, 1.9), miller: kg(56.2, 1.41), hamwi: kg(48, 2.7))
      : (devine: kg(45.5, 2.3), robinson: kg(49, 1.7), miller: kg(53.1, 1.36), hamwi: kg(45.5, 2.2));
}

class HealthCalculatorScreen extends StatefulWidget {
  const HealthCalculatorScreen({super.key});

  @override
  State<HealthCalculatorScreen> createState() => _HealthCalculatorScreenState();
}

class _HealthCalculatorScreenState extends State<HealthCalculatorScreen> {
  final TextEditingController _heightController = TextEditingController(text: '175');
  final TextEditingController _weightController = TextEditingController(text: '70');
  final TextEditingController _ageController = TextEditingController(text: '25');
  Gender _gender = Gender.male;
  bool _isCm = true;

  Map<String, dynamic> _computeHealthMetrics() {
    // Blank/invalid fields count as 0 (shown as "Invalid") instead of silently using made-up defaults.
    double heightCm = ValidationUtils.safeParseDouble(_heightController.text);
    final weightKg = ValidationUtils.safeParseDouble(_weightController.text);
    final age = ValidationUtils.safeParseDouble(_ageController.text);

    if (!_isCm) {
      // height is in feet: e.g. 5.9 -> convert to cm
      heightCm = heightCm * 30.48;
    }

    if (heightCm <= 0 || heightCm > 300 || weightKg <= 0 || weightKg > 700) {
      return {
        'bmi': 0.0,
        'category': 'Enter a valid height and weight',
        'idealMin': 0.0,
        'idealMax': 0.0,
        'bmr': 0.0,
        'moderateCalories': 0.0, // read with a non-null cast in build()
        'valid': false,
      };
    }

    final heightM = heightCm / 100.0;
    final bmi = weightKg / (heightM * heightM);

    String category;
    Color color;
    if (bmi < 18.5) {
      category = 'Underweight';
      color = Colors.blue;
    } else if (bmi < 25) {
      category = 'Normal Weight';
      color = const Color(0xFF10B981);
    } else if (bmi < 30) {
      category = 'Overweight';
      color = const Color(0xFFF59E0B);
    } else {
      category = 'Obese';
      color = const Color(0xFFEF4444);
    }

    // Ideal weight based on BMI 18.5 - 24.9
    final idealMin = 18.5 * (heightM * heightM);
    final idealMax = 24.9 * (heightM * heightM);

    // Mifflin-St Jeor BMR formula
    double bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    if (_gender == Gender.male) {
      bmr += 5;
    } else {
      bmr -= 161;
    }

    return {
      'valid': true,
      'hasAge': age > 0 && age <= 120,
      'ideal': idealWeightFormulas(heightCm, male: _gender == Gender.male),
      'bmi': bmi,
      'category': category,
      'color': color,
      'idealMin': idealMin,
      'idealMax': idealMax,
      'bmr': bmr,
      'moderateCalories': bmr * 1.55,
    };
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _computeHealthMetrics();
    final bmi = metrics['bmi'] as double;
    final idealMin = metrics['idealMin'] as double;
    final idealMax = metrics['idealMax'] as double;
    final bmr = metrics['bmr'] as double;
    final valid = metrics['valid'] as bool;
    final hasAge = valid && metrics['hasAge'] as bool;
    final ideal = metrics['ideal'] as ({double devine, double robinson, double miller, double hamwi})?;
    String kgText(double v) => '${v.toStringAsFixed(1)} kg';

    return ToolScaffold(
      title: 'Health & BMI Calculator',
      category: ToolCategory.health,
      toolId: 'health_calc',
      onReset: () {
        setState(() {
          _heightController.text = '175';
          _weightController.text = '70';
          _ageController.text = '25';
          _gender = Gender.male;
          _isCm = true;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Body Mass Index (BMI)',
            primaryResult: bmi.toStringAsFixed(1),
            subtitle: 'Status: ${metrics['category']}',
            accentColor: metrics['color'] as Color? ?? const Color(0xFFEF4444),
            breakdowns: [
              if (ideal != null) ...[
                BreakdownItem(label: 'Ideal Weight (Devine)', value: kgText(ideal.devine)),
                BreakdownItem(label: 'Ideal Weight (Robinson)', value: kgText(ideal.robinson)),
                BreakdownItem(label: 'Ideal Weight (Miller)', value: kgText(ideal.miller)),
                BreakdownItem(label: 'Ideal Weight (Hamwi)', value: kgText(ideal.hamwi)),
              ],
              BreakdownItem(
                label: 'Healthy BMI Range (18.5-24.9)',
                value: '${idealMin.toStringAsFixed(1)} - ${idealMax.toStringAsFixed(1)} kg',
              ),
              BreakdownItem(
                label: 'Basal Metabolic Rate',
                value: hasAge ? '${bmr.round()} kcal / day' : 'Enter age',
              ),
              BreakdownItem(
                label: 'Maintenance (moderate activity)',
                value: hasAge ? '${(metrics['moderateCalories'] as double).round()} kcal' : 'Enter age',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gender selection
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  avatar: const Icon(Icons.male_rounded, size: 18),
                  label: const Center(child: Text('Male')),
                  selected: _gender == Gender.male,
                  selectedColor: const Color(0xFF3B82F6),
                  onSelected: (val) {
                    if (val) {
                      PreferencesService().triggerHaptic();
                      setState(() => _gender = Gender.male);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  avatar: const Icon(Icons.female_rounded, size: 18),
                  label: const Center(child: Text('Female')),
                  selected: _gender == Gender.female,
                  selectedColor: const Color(0xFFEC4899),
                  onSelected: (val) {
                    if (val) {
                      PreferencesService().triggerHaptic();
                      setState(() => _gender = Gender.female);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ModernTextField(
            label: 'Height',
            controller: _heightController,
            hintText: _isCm ? '175' : '5.5 (decimal feet)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icons.height_rounded,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChoiceChip(
                  label: const Text('cm'),
                  selected: _isCm,
                  selectedColor: const Color(0xFFEF4444),
                  onSelected: (val) {
                    if (val) setState(() => _isCm = true);
                  },
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('ft'),
                  selected: !_isCm,
                  selectedColor: const Color(0xFFEF4444),
                  onSelected: (val) {
                    if (val) setState(() => _isCm = false);
                  },
                ),
              ],
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  label: 'Weight (kg)',
                  controller: _weightController,
                  hintText: '70',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.fitness_center_rounded,
                  suffixText: 'kg',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ModernTextField(
                  label: 'Age (years)',
                  controller: _ageController,
                  hintText: '25',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.cake_outlined,
                  suffixText: 'yrs',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
