import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum Gender { male, female }

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
    double heightCm = double.tryParse(_heightController.text.trim()) ?? 170;
    final weightKg = double.tryParse(_weightController.text.trim()) ?? 70;
    final age = double.tryParse(_ageController.text.trim()) ?? 25;

    if (!_isCm) {
      // height is in feet: e.g. 5.9 -> convert to cm
      heightCm = heightCm * 30.48;
    }

    if (heightCm <= 0 || weightKg <= 0) {
      return {
        'bmi': 0.0,
        'category': 'Invalid',
        'idealMin': 0.0,
        'idealMax': 0.0,
        'bmr': 0.0,
      };
    }

    final heightM = heightCm / 100.0;
    final bmi = weightKg / (heightM * heightM);

    String category;
    Color color;
    if (bmi < 18.5) {
      category = 'Underweight';
      color = Colors.blue;
    } else if (bmi < 24.9) {
      category = 'Normal Weight';
      color = const Color(0xFF10B981);
    } else if (bmi < 29.9) {
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
              BreakdownItem(
                label: 'Ideal Weight Range',
                value: '${idealMin.toStringAsFixed(1)} - ${idealMax.toStringAsFixed(1)} kg',
              ),
              BreakdownItem(
                label: 'Basal Metabolic Rate',
                value: '${bmr.round()} kcal / day',
              ),
              BreakdownItem(
                label: 'Daily Maintenance Needs',
                value: '${(metrics['moderateCalories'] as double).round()} kcal',
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
            hintText: _isCm ? '175' : '5.8',
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
