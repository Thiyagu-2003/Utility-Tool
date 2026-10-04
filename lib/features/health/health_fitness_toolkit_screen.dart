import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum HealthTab {
  bodyFat('Body Fat %', Icons.accessibility_new_rounded),
  whtr('Waist / Height', Icons.straighten_rounded),
  pace('Running Pace', Icons.directions_run_rounded),
  steps('Step to Distance', Icons.nordic_walking_rounded),
  heartRate('HR Zones', Icons.favorite_rounded),
  intervalTimer('Interval Timer', Icons.timer_rounded),
  macros('Protein & Macros', Icons.restaurant_rounded),
  waterTracker('Water Tracker', Icons.water_drop_rounded);

  final String label;
  final IconData icon;
  const HealthTab(this.label, this.icon);
}

class HealthFitnessToolkitScreen extends StatefulWidget {
  const HealthFitnessToolkitScreen({super.key});

  @override
  State<HealthFitnessToolkitScreen> createState() => _HealthFitnessToolkitScreenState();
}

class _HealthFitnessToolkitScreenState extends State<HealthFitnessToolkitScreen> with TickerProviderStateMixin {
  HealthTab _activeTab = HealthTab.bodyFat;

  // 1. BODY FAT (US Navy Method)
  bool _isMale = true;
  final _bfHeightCtrl = TextEditingController(text: '175');
  final _bfNeckCtrl = TextEditingController(text: '38');
  final _bfWaistCtrl = TextEditingController(text: '82');
  final _bfHipCtrl = TextEditingController(text: '96');

  // 2. WAIST TO HEIGHT RATIO
  final _whtrWaistCtrl = TextEditingController(text: '80');
  final _whtrHeightCtrl = TextEditingController(text: '175');

  // 3. RUNNING PACE
  final _paceDistCtrl = TextEditingController(text: '10');
  final _paceHoursCtrl = TextEditingController(text: '0');
  final _paceMinsCtrl = TextEditingController(text: '50');
  final _paceSecsCtrl = TextEditingController(text: '0');
  bool _paceIsKm = true;

  // 4. STEP TO DISTANCE
  final _stepCountCtrl = TextEditingController(text: '8000');
  final _stepHeightCtrl = TextEditingController(text: '175');
  final _stepWeightCtrl = TextEditingController(text: '70');

  // 5. HEART RATE ZONES
  final _hrAgeCtrl = TextEditingController(text: '28');
  final _hrRestCtrl = TextEditingController(text: '65');

  // 6. WORKOUT INTERVAL TIMER
  int _timerWorkSec = 30;
  int _timerRestSec = 15;
  int _timerSets = 5;
  int _timerCurrentSet = 1;
  bool _isWorkPhase = true;
  int _timerSecondsRemaining = 30;
  bool _isTimerRunning = false;
  Timer? _timer;

  // 7. MACROS & PROTEIN
  final _macroWeightCtrl = TextEditingController(text: '72');
  final _macroHeightCtrl = TextEditingController(text: '175');
  final _macroAgeCtrl = TextEditingController(text: '26');
  String _macroActivity = 'Moderate (3-5 days/wk)';
  String _macroGoal = 'Lean Muscle Gain (+250 kcal)';

  // 8. WATER TRACKER
  final _waterWeightCtrl = TextEditingController(text: '70');
  int _waterLoggedTodayMl = 1250;
  final List<String> _waterLogs = [
    '250 ml (08:30 AM)',
    '500 ml (11:15 AM)',
    '500 ml (02:40 PM)',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _bfHeightCtrl.dispose();
    _bfNeckCtrl.dispose();
    _bfWaistCtrl.dispose();
    _bfHipCtrl.dispose();
    _whtrWaistCtrl.dispose();
    _whtrHeightCtrl.dispose();
    _paceDistCtrl.dispose();
    _paceHoursCtrl.dispose();
    _paceMinsCtrl.dispose();
    _paceSecsCtrl.dispose();
    _stepCountCtrl.dispose();
    _stepHeightCtrl.dispose();
    _stepWeightCtrl.dispose();
    _hrAgeCtrl.dispose();
    _hrRestCtrl.dispose();
    _macroWeightCtrl.dispose();
    _macroHeightCtrl.dispose();
    _macroAgeCtrl.dispose();
    super.dispose();
  }

  // --- CALCULATION LOGIC ---

  // 1. Body Fat
  Map<String, dynamic> _calcBodyFat() {
    final h = double.tryParse(_bfHeightCtrl.text) ?? 175;
    final neck = double.tryParse(_bfNeckCtrl.text) ?? 38;
    final waist = double.tryParse(_bfWaistCtrl.text) ?? 82;
    final hip = double.tryParse(_bfHipCtrl.text) ?? 96;

    if (h <= 0 || neck <= 0 || waist <= 0) {
      return {'bf': 0.0, 'category': 'Invalid', 'color': Colors.grey};
    }

    double bf;
    if (_isMale) {
      final diff = waist - neck;
      if (diff <= 0) return {'bf': 5.0, 'category': 'Athletic', 'color': AppColors.catHealth};
      bf = 495 / (1.0324 - 0.19077 * (log(diff) / ln10) + 0.15456 * (log(h) / ln10)) - 450;
    } else {
      final sum = waist + hip - neck;
      if (sum <= 0) return {'bf': 12.0, 'category': 'Athletic', 'color': AppColors.catHealth};
      bf = 495 / (1.29579 - 0.35004 * (log(sum) / ln10) + 0.22100 * (log(h) / ln10)) - 450;
    }

    bf = bf.clamp(3.0, 60.0);
    String category;
    Color color;

    if (_isMale) {
      if (bf < 6) {
        category = 'Essential Fat';
        color = Colors.blue;
      } else if (bf <= 13) {
        category = 'Athletes';
        color = AppColors.success;
      } else if (bf <= 17) {
        category = 'Fitness';
        color = const Color(0xFF10B981);
      } else if (bf <= 24) {
        category = 'Average';
        color = const Color(0xFFF59E0B);
      } else {
        category = 'Obese';
        color = AppColors.error;
      }
    } else {
      if (bf < 14) {
        category = 'Essential Fat';
        color = Colors.blue;
      } else if (bf <= 20) {
        category = 'Athletes';
        color = AppColors.success;
      } else if (bf <= 24) {
        category = 'Fitness';
        color = const Color(0xFF10B981);
      } else if (bf <= 31) {
        category = 'Average';
        color = const Color(0xFFF59E0B);
      } else {
        category = 'Obese';
        color = AppColors.error;
      }
    }

    return {'bf': bf, 'category': category, 'color': color};
  }

  // 2. WHtR
  Map<String, dynamic> _calcWhtr() {
    final waist = double.tryParse(_whtrWaistCtrl.text) ?? 80;
    final height = double.tryParse(_whtrHeightCtrl.text) ?? 175;
    if (height <= 0 || waist <= 0) {
      return {'ratio': 0.0, 'status': 'Invalid', 'color': Colors.grey};
    }

    final ratio = waist / height;
    String status;
    Color color;

    if (ratio < 0.40) {
      status = 'Take Care (Underweight / Too Slim)';
      color = Colors.blue;
    } else if (ratio <= 0.49) {
      status = 'Healthy & Low Health Risk';
      color = AppColors.success;
    } else if (ratio <= 0.59) {
      status = 'Increased Cardiovascular Risk';
      color = const Color(0xFFF59E0B);
    } else {
      status = 'High Health Risk';
      color = AppColors.error;
    }

    return {'ratio': ratio, 'status': status, 'color': color};
  }

  // 3. Running Pace
  Map<String, dynamic> _calcRunningPace() {
    final dist = double.tryParse(_paceDistCtrl.text) ?? 10;
    final h = int.tryParse(_paceHoursCtrl.text) ?? 0;
    final m = int.tryParse(_paceMinsCtrl.text) ?? 50;
    final s = int.tryParse(_paceSecsCtrl.text) ?? 0;

    final totalSecs = (h * 3600) + (m * 60) + s;
    if (dist <= 0 || totalSecs <= 0) {
      return {'pace': '0:00 /km', 'speed': '0.0 km/h', '5k': '--', '10k': '--', 'half': '--'};
    }

    final paceSecPerUnit = totalSecs / dist;
    final paceMin = paceSecPerUnit ~/ 60;
    final paceSec = (paceSecPerUnit % 60).round();
    final paceUnit = _paceIsKm ? 'km' : 'mi';
    final paceStr = '$paceMin:${paceSec.toString().padLeft(2, '0')} min/$paceUnit';

    final totalHours = totalSecs / 3600.0;
    final speed = dist / totalHours;
    final speedStr = '${speed.toStringAsFixed(1)} ${_paceIsKm ? "km/h" : "mph"}';

    // Forecasts based on km pace
    final secPerKm = _paceIsKm ? paceSecPerUnit : paceSecPerUnit / 1.60934;
    String formatSplit(double km) {
      final s = (km * secPerKm).round();
      final hh = s ~/ 3600;
      final mm = (s % 3600) ~/ 60;
      final ss = s % 60;
      if (hh > 0) return '${hh}h ${mm}m ${ss}s';
      return '${mm}m ${ss}s';
    }

    return {
      'pace': paceStr,
      'speed': speedStr,
      '5k': formatSplit(5.0),
      '10k': formatSplit(10.0),
      'half': formatSplit(21.0975),
      'full': formatSplit(42.195),
    };
  }

  // 4. Step to Distance
  Map<String, dynamic> _calcSteps() {
    final steps = int.tryParse(_stepCountCtrl.text) ?? 8000;
    final height = double.tryParse(_stepHeightCtrl.text) ?? 175;
    final weight = double.tryParse(_stepWeightCtrl.text) ?? 70;

    // Stride length formula: height in cm * 0.415 for male, 0.413 for female
    final strideCm = height * 0.414;
    final totalDistanceKm = (steps * strideCm) / 100000.0;
    final totalMiles = totalDistanceKm * 0.621371;

    // Calories: roughly 0.04 to 0.05 kcal per step based on body weight
    final calories = steps * 0.04 * (weight / 70.0);

    return {
      'km': totalDistanceKm.toStringAsFixed(2),
      'miles': totalMiles.toStringAsFixed(2),
      'calories': calories.round().toString(),
      'stride': strideCm.toStringAsFixed(1),
    };
  }

  // 5. Heart Rate Zones
  Map<String, dynamic> _calcHeartRateZones() {
    final age = int.tryParse(_hrAgeCtrl.text) ?? 28;
    final restHr = int.tryParse(_hrRestCtrl.text) ?? 65;

    // Tanaka Formula: Max HR = 208 - (0.7 * age)
    final maxHr = (208 - (0.7 * age)).round();
    final hrReserve = maxHr - restHr;

    // Karvonen formula: Target = Rest + % * HRR
    int getZoneBpm(double pct) => (restHr + (pct * hrReserve)).round();

    return {
      'maxHr': maxHr,
      'zone1': '${getZoneBpm(0.50)} - ${getZoneBpm(0.60)} bpm', // Warm up / Recovery
      'zone2': '${getZoneBpm(0.60)} - ${getZoneBpm(0.70)} bpm', // Fat Burn / Aerobic base
      'zone3': '${getZoneBpm(0.70)} - ${getZoneBpm(0.80)} bpm', // Cardio / Aerobic endurance
      'zone4': '${getZoneBpm(0.80)} - ${getZoneBpm(0.90)} bpm', // Anaerobic threshold
      'zone5': '${getZoneBpm(0.90)} - $maxHr bpm', // VO2 Max / Neuromuscular
    };
  }

  // 6. Interval Timer Logic
  void _startTimer() {
    if (_isTimerRunning) return;
    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timerSecondsRemaining > 1) {
        setState(() => _timerSecondsRemaining--);
      } else {
        PreferencesService().triggerHaptic();
        if (_isWorkPhase) {
          // Switch to rest phase
          setState(() {
            _isWorkPhase = false;
            _timerSecondsRemaining = _timerRestSec;
          });
        } else {
          // Finished rest, check set
          if (_timerCurrentSet < _timerSets) {
            setState(() {
              _timerCurrentSet++;
              _isWorkPhase = true;
              _timerSecondsRemaining = _timerWorkSec;
            });
          } else {
            // Done!
            _stopTimer();
            setState(() {
              _timerCurrentSet = 1;
              _isWorkPhase = true;
              _timerSecondsRemaining = _timerWorkSec;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🎉 Workout Completed! Fantastic job!')),
            );
          }
        }
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _timerCurrentSet = 1;
      _isWorkPhase = true;
      _timerSecondsRemaining = _timerWorkSec;
    });
  }

  // 7. Macros & Protein
  Map<String, dynamic> _calcMacros() {
    final weight = double.tryParse(_macroWeightCtrl.text) ?? 72;
    final height = double.tryParse(_macroHeightCtrl.text) ?? 175;
    final age = double.tryParse(_macroAgeCtrl.text) ?? 26;

    // Mifflin-St Jeor BMR
    double bmr = (10 * weight) + (6.25 * height) - (5 * age) + (_isMale ? 5 : -161);

    double activityMult = 1.55;
    if (_macroActivity.startsWith('Sedentary')) activityMult = 1.2;
    if (_macroActivity.startsWith('Light')) activityMult = 1.375;
    if (_macroActivity.startsWith('Moderate')) activityMult = 1.55;
    if (_macroActivity.startsWith('Very Active')) activityMult = 1.725;
    if (_macroActivity.startsWith('Extra Active')) activityMult = 1.9;

    double tdee = bmr * activityMult;

    // Goal adjustment
    double targetKcal = tdee;
    if (_macroGoal.contains('-500')) targetKcal -= 500;
    if (_macroGoal.contains('-250')) targetKcal -= 250;
    if (_macroGoal.contains('+250')) targetKcal += 250;
    if (_macroGoal.contains('+500')) targetKcal += 500;

    // Protein: 2.0g per kg of body weight
    final proteinGrams = (weight * 2.0).round();
    final proteinKcal = proteinGrams * 4;

    // Fat: 25% of total calories
    final fatKcal = targetKcal * 0.25;
    final fatGrams = (fatKcal / 9).round();

    // Carbs: remainder calories
    final carbKcal = max(0, targetKcal - proteinKcal - fatKcal);
    final carbGrams = (carbKcal / 4).round();

    return {
      'tdee': tdee.round(),
      'target': targetKcal.round(),
      'protein': proteinGrams,
      'fat': fatGrams,
      'carbs': carbGrams,
    };
  }

  // 8. Water Tracker
  int _targetWaterMl() {
    final weight = double.tryParse(_waterWeightCtrl.text) ?? 70;
    // Standard guideline: 35ml per kg body weight
    return (weight * 35).round();
  }

  void _addWater(int ml) {
    PreferencesService().triggerHaptic();
    final now = TimeOfDay.now();
    final timeStr = now.format(context);
    setState(() {
      _waterLoggedTodayMl += ml;
      _waterLogs.insert(0, '$ml ml ($timeStr)');
    });
  }

  void _resetWater() {
    PreferencesService().triggerHaptic();
    setState(() {
      _waterLoggedTodayMl = 0;
      _waterLogs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Health & Fitness Suite',
      category: ToolCategory.health,
      toolId: 'health_fitness_toolkit',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryChips(isDark),
          const SizedBox(height: 16),
          if (_activeTab == HealthTab.bodyFat) _buildBodyFatTab(isDark),
          if (_activeTab == HealthTab.whtr) _buildWhtrTab(isDark),
          if (_activeTab == HealthTab.pace) _buildRunningPaceTab(isDark),
          if (_activeTab == HealthTab.steps) _buildStepsTab(isDark),
          if (_activeTab == HealthTab.heartRate) _buildHeartRateTab(isDark),
          if (_activeTab == HealthTab.intervalTimer) _buildIntervalTimerTab(isDark),
          if (_activeTab == HealthTab.macros) _buildMacrosTab(isDark),
          if (_activeTab == HealthTab.waterTracker) _buildWaterTrackerTab(isDark),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: HealthTab.values.map((tab) {
          final isSelected = _activeTab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: Icon(
                tab.icon,
                size: 16,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              label: Text(tab.label),
              selected: isSelected,
              selectedColor: AppColors.catHealth,
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              onSelected: (_) {
                PreferencesService().triggerHaptic();
                setState(() => _activeTab = tab);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- TAB 1: BODY FAT ---
  Widget _buildBodyFatTab(bool isDark) {
    final res = _calcBodyFat();
    final bf = res['bf'] as double;
    final cat = res['category'] as String;
    final col = res['color'] as Color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Estimated Body Fat % (US Navy Method)',
          primaryResult: '${bf.toStringAsFixed(1)}%',
          subtitle: 'Category: $cat',
          accentColor: col,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.male_rounded),
                label: const Text('Male'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _isMale ? AppColors.catHealth.withValues(alpha: 0.15) : null,
                  side: BorderSide(color: _isMale ? AppColors.catHealth : AppColors.lightBorder),
                ),
                onPressed: () => setState(() => _isMale = true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.female_rounded),
                label: const Text('Female'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: !_isMale ? AppColors.catHealth.withValues(alpha: 0.15) : null,
                  side: BorderSide(color: !_isMale ? AppColors.catHealth : AppColors.lightBorder),
                ),
                onPressed: () => setState(() => _isMale = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Height (cm)', controller: _bfHeightCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'Neck (cm)', controller: _bfNeckCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Waist at navel (cm)', controller: _bfWaistCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            if (!_isMale) ...[
              const SizedBox(width: 10),
              Expanded(child: ModernTextField(label: 'Hip at widest (cm)', controller: _bfHipCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ],
        ),
      ],
    );
  }

  // --- TAB 2: WHtR ---
  Widget _buildWhtrTab(bool isDark) {
    final res = _calcWhtr();
    final ratio = res['ratio'] as double;
    final status = res['status'] as String;
    final col = res['color'] as Color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Waist-to-Height Ratio (WHtR)',
          primaryResult: ratio.toStringAsFixed(2),
          subtitle: status,
          accentColor: col,
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'Waist Circumference (cm)',
          controller: _whtrWaistCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        ModernTextField(
          label: 'Height (cm)',
          controller: _whtrHeightCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Health Guideline rule-of-thumb:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 4),
              Text('Keep your waist circumference to less than half your height (ratio < 0.50). Over 0.50 indicates increased abdominal visceral fat risk.'),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 3: RUNNING PACE ---
  Widget _buildRunningPaceTab(bool isDark) {
    final res = _calcRunningPace();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Pace & Speed',
          primaryResult: res['pace'] as String,
          subtitle: 'Average Speed: ${res['speed']}',
          accentColor: AppColors.catHealth,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ModernTextField(
                label: 'Distance',
                controller: _paceDistCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('KM')),
                  ButtonSegment(value: false, label: Text('MI')),
                ],
                selected: {_paceIsKm},
                onSelectionChanged: (set) => setState(() => _paceIsKm = set.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Hours', controller: _paceHoursCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Mins', controller: _paceMinsCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Secs', controller: _paceSecsCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Estimated Split Forecasts', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            _splitBadge('5K', res['5k'] as String, isDark),
            const SizedBox(width: 8),
            _splitBadge('10K', res['10k'] as String, isDark),
            const SizedBox(width: 8),
            _splitBadge('Half Marathon', res['half'] as String, isDark),
          ],
        ),
      ],
    );
  }

  Widget _splitBadge(String label, String val, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.catHealth.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.catHealth)),
          ],
        ),
      ),
    );
  }

  // --- TAB 4: STEPS TO DISTANCE ---
  Widget _buildStepsTab(bool isDark) {
    final res = _calcSteps();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Estimated Distance & Burn',
          primaryResult: '${res['km']} km',
          subtitle: '${res['miles']} miles • ${res['calories']} kcal burned',
          accentColor: AppColors.catHealth,
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'Total Step Count',
          controller: _stepCountCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Your Height (cm)', controller: _stepHeightCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'Your Weight (kg)', controller: _stepWeightCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        Text('Estimated stride length: ${res['stride']} cm per step', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // --- TAB 5: HEART RATE ZONES ---
  Widget _buildHeartRateTab(bool isDark) {
    final res = _calcHeartRateZones();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Max Heart Rate (Tanaka)',
          primaryResult: '${res['maxHr']} bpm',
          subtitle: 'Calculated using Karvonen formula with Resting HR',
          accentColor: AppColors.catHealth,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Age (Years)', controller: _hrAgeCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'Resting HR (BPM)', controller: _hrRestCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 16),
        _hrZoneTile('Zone 1 (50-60%)', 'Warm-Up & Active Recovery', res['zone1'] as String, Colors.blue),
        _hrZoneTile('Zone 2 (60-70%)', 'Fat Burn & Aerobic Base Building', res['zone2'] as String, AppColors.success),
        _hrZoneTile('Zone 3 (70-80%)', 'Cardio Endurance & Stamina', res['zone3'] as String, const Color(0xFF10B981)),
        _hrZoneTile('Zone 4 (80-90%)', 'Anaerobic & Lactate Threshold', res['zone4'] as String, const Color(0xFFF59E0B)),
        _hrZoneTile('Zone 5 (90-100%)', 'Maximum Effort & VO2 Max Sprints', res['zone5'] as String, AppColors.error),
      ],
    );
  }

  Widget _hrZoneTile(String title, String desc, String range, Color col) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: col)),
                Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(range, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // --- TAB 6: WORKOUT INTERVAL TIMER ---
  Widget _buildIntervalTimerTab(bool isDark) {
    final progress = _isWorkPhase
        ? (_timerSecondsRemaining / _timerWorkSec).clamp(0.0, 1.0)
        : (_timerSecondsRemaining / _timerRestSec).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                color: _isWorkPhase ? AppColors.catHealth : Colors.blue,
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isWorkPhase ? 'WORK' : 'REST',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: _isWorkPhase ? AppColors.catHealth : Colors.blue,
                      ),
                    ),
                    Text(
                      '${_timerSecondsRemaining}s',
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900),
                    ),
                    Text('Set $_timerCurrentSet of $_timerSets', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: Icon(_isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(_isTimerRunning ? 'Pause' : 'Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTimerRunning ? Colors.orange : AppColors.catHealth,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _isTimerRunning ? _pauseTimer : _startTimer,
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset'),
              onPressed: _stopTimer,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _timerWorkSec,
                decoration: InputDecoration(labelText: 'Work Interval', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: [15, 20, 30, 40, 45, 60].map((s) => DropdownMenuItem(value: s, child: Text('${s}s'))).toList(),
                onChanged: _isTimerRunning ? null : (v) => setState(() { _timerWorkSec = v ?? 30; if (_isWorkPhase) _timerSecondsRemaining = _timerWorkSec; }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _timerRestSec,
                decoration: InputDecoration(labelText: 'Rest Interval', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: [10, 15, 20, 30, 45].map((s) => DropdownMenuItem(value: s, child: Text('${s}s'))).toList(),
                onChanged: _isTimerRunning ? null : (v) => setState(() { _timerRestSec = v ?? 15; if (!_isWorkPhase) _timerSecondsRemaining = _timerRestSec; }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _timerSets,
                decoration: InputDecoration(labelText: 'Sets / Rounds', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: [3, 4, 5, 8, 10, 12].map((s) => DropdownMenuItem(value: s, child: Text('$s sets'))).toList(),
                onChanged: _isTimerRunning ? null : (v) => setState(() => _timerSets = v ?? 5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- TAB 7: MACROS & PROTEIN ---
  Widget _buildMacrosTab(bool isDark) {
    final res = _calcMacros();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Daily Calorie & Macro Target',
          primaryResult: '${res['target']} kcal / day',
          subtitle: 'Maintenance (TDEE): ${res['tdee']} kcal',
          accentColor: AppColors.catHealth,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _macroCard('Protein', '${res['protein']}g', '${res['protein'] * 4} kcal', Colors.redAccent, isDark),
            const SizedBox(width: 8),
            _macroCard('Carbs', '${res['carbs']}g', '${res['carbs'] * 4} kcal', Colors.blueAccent, isDark),
            const SizedBox(width: 8),
            _macroCard('Fats', '${res['fat']}g', '${res['fat'] * 9} kcal', Colors.amber, isDark),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Weight (kg)', controller: _macroWeightCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Height (cm)', controller: _macroHeightCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: ModernTextField(label: 'Age', controller: _macroAgeCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _macroActivity,
          decoration: InputDecoration(labelText: 'Activity Level', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          items: [
            'Sedentary (desk job, little exercise)',
            'Light (exercise 1-3 days/wk)',
            'Moderate (3-5 days/wk)',
            'Very Active (6-7 days/wk)',
            'Extra Active (physical job & athlete)',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _macroActivity = v ?? _macroActivity),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _macroGoal,
          decoration: InputDecoration(labelText: 'Fitness Goal', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          items: [
            'Fat Loss / Deficit (-500 kcal)',
            'Mild Cut (-250 kcal)',
            'Maintain Body Composition (0 kcal)',
            'Lean Muscle Gain (+250 kcal)',
            'Bulking Phase (+500 kcal)',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _macroGoal = v ?? _macroGoal),
        ),
      ],
    );
  }

  Widget _macroCard(String title, String grams, String kcal, Color col, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: col.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: col, fontSize: 13)),
            const SizedBox(height: 4),
            Text(grams, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(kcal, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // --- TAB 8: WATER TRACKER ---
  Widget _buildWaterTrackerTab(bool isDark) {
    final targetMl = _targetWaterMl();
    final pct = (targetMl > 0 ? (_waterLoggedTodayMl / targetMl) : 0.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Daily Hydration Progress',
          primaryResult: '$_waterLoggedTodayMl / $targetMl ml',
          subtitle: '${(pct * 100).toStringAsFixed(0)}% of your target reached',
          accentColor: Colors.blue,
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: pct,
          minHeight: 10,
          borderRadius: BorderRadius.circular(8),
          color: Colors.blue,
          backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _waterButton('+250 ml (Cup)', 250),
            const SizedBox(width: 8),
            _waterButton('+500 ml (Bottle)', 500),
            const SizedBox(width: 8),
            _waterButton('+750 ml (Flask)', 750),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ModernTextField(
                label: 'Weight (kg) to adjust target',
                controller: _waterWeightCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reset Today',
              onPressed: _resetWater,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Today\'s Drink Log', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_waterLogs.isEmpty)
          const Text('No drinks logged yet today.', style: TextStyle(color: Colors.grey, fontSize: 13))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _waterLogs.length,
            separatorBuilder: (_, index) => const SizedBox(height: 6),
            itemBuilder: (context, idx) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop_rounded, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(_waterLogs[idx], style: const TextStyle(fontSize: 13)),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _waterButton(String label, int ml) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => _addWater(ml),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ),
    );
  }
}
