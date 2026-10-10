import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum AcademicTab {
  marks('Marks & Grade', Icons.grade_rounded),
  examNeeded('Exam Needed', Icons.checklist_rounded),
  attendance('Attendance', Icons.event_available_rounded),
  scientific('Scientific Calc', Icons.calculate_rounded),
  equations('Equation Solver', Icons.functions_rounded),
  primes('Prime Tools', Icons.filter_vintage_rounded),
  gcdLcm('GCD & LCM', Icons.alt_route_rounded),
  matrices('Matrix 2x2 / 3x3', Icons.grid_4x4_rounded),
  permComb('Perm & Comb', Icons.grain_rounded);

  final String label;
  final IconData icon;
  const AcademicTab(this.label, this.icon);
}

class SubjectMark {
  String name;
  double maxMark;
  double scored;
  SubjectMark({required this.name, required this.maxMark, required this.scored});
}

class AcademicToolkitScreen extends StatefulWidget {
  const AcademicToolkitScreen({super.key});

  @override
  State<AcademicToolkitScreen> createState() => _AcademicToolkitScreenState();
}

class _AcademicToolkitScreenState extends State<AcademicToolkitScreen> {
  AcademicTab _activeTab = AcademicTab.marks;

  // 1. MARKS PERCENTAGE
  final List<SubjectMark> _subjects = [
    SubjectMark(name: 'Mathematics', maxMark: 100, scored: 88),
    SubjectMark(name: 'Physics', maxMark: 100, scored: 82),
    SubjectMark(name: 'Chemistry', maxMark: 100, scored: 79),
    SubjectMark(name: 'Computer Science', maxMark: 100, scored: 94),
    SubjectMark(name: 'English', maxMark: 100, scored: 85),
  ];

  // 2. EXAM SCORE NEEDED
  final _examCurrentCtrl = TextEditingController(text: '78');
  final _examTargetCtrl = TextEditingController(text: '85');
  final _examWeightCtrl = TextEditingController(text: '30');

  // 3. ATTENDANCE ELIGIBILITY
  final _attTotalCtrl = TextEditingController(text: '60');
  final _attAttendedCtrl = TextEditingController(text: '42');
  final _attRequiredCtrl = TextEditingController(text: '75');

  // 4. SCIENTIFIC CALCULATOR
  String _calcDisplay = '';
  String _calcResult = '0';
  bool _isRad = false;
  final List<String> _calcHistory = [];

  // 5. EQUATION SOLVER
  int _equationType = 1; // 0: Linear ax+b=0, 1: Quadratic ax^2+bx+c=0, 2: 2x2 Linear System
  final _eqACtrl = TextEditingController(text: '1');
  final _eqBCtrl = TextEditingController(text: '-5');
  final _eqCCtrl = TextEditingController(text: '6');
  // 2x2 System:
  // a1 x + b1 y = c1
  // a2 x + b2 y = c2
  final _sysA1Ctrl = TextEditingController(text: '2');
  final _sysB1Ctrl = TextEditingController(text: '3');
  final _sysC1Ctrl = TextEditingController(text: '8');
  final _sysA2Ctrl = TextEditingController(text: '1');
  final _sysB2Ctrl = TextEditingController(text: '-1');
  final _sysC2Ctrl = TextEditingController(text: '-1');

  // 6. PRIME & FACTORIZATION
  final _primeInputCtrl = TextEditingController(text: '360');

  // 7. GCD & LCM
  final _gcdInputCtrl = TextEditingController(text: '48, 72, 120');

  // 8. MATRIX CALCULATOR
  int _matrixSize = 2; // 2 or 3
  // 2x2 matrices
  final List<TextEditingController> _matA2 = List.generate(4, (i) => TextEditingController(text: '${i + 1}'));
  final List<TextEditingController> _matB2 = List.generate(4, (i) => TextEditingController(text: '${4 - i}'));
  // 3x3 matrices
  final List<TextEditingController> _matA3 = List.generate(9, (i) => TextEditingController(text: '${i + 1}'));
  final List<TextEditingController> _matB3 = List.generate(9, (i) => TextEditingController(text: '${9 - i}'));

  // 9. PERMUTATION & COMBINATION
  final _permNCtrl = TextEditingController(text: '8');
  final _permRCtrl = TextEditingController(text: '3');

  @override
  void dispose() {
    _examCurrentCtrl.dispose();
    _examTargetCtrl.dispose();
    _examWeightCtrl.dispose();
    _attTotalCtrl.dispose();
    _attAttendedCtrl.dispose();
    _attRequiredCtrl.dispose();
    _eqACtrl.dispose();
    _eqBCtrl.dispose();
    _eqCCtrl.dispose();
    _sysA1Ctrl.dispose();
    _sysB1Ctrl.dispose();
    _sysC1Ctrl.dispose();
    _sysA2Ctrl.dispose();
    _sysB2Ctrl.dispose();
    _sysC2Ctrl.dispose();
    _primeInputCtrl.dispose();
    _gcdInputCtrl.dispose();
    for (final c in _matA2) {
      c.dispose();
    }
    for (final c in _matB2) {
      c.dispose();
    }
    for (final c in _matA3) {
      c.dispose();
    }
    for (final c in _matB3) {
      c.dispose();
    }
    _permNCtrl.dispose();
    _permRCtrl.dispose();
    super.dispose();
  }

  // --- CALCULATION HELPERS ---

  // 1. Marks
  Map<String, dynamic> _computeMarks() {
    double totalMax = 0;
    double totalScored = 0;
    for (final s in _subjects) {
      totalMax += s.maxMark;
      totalScored += s.scored;
    }

    final pct = totalMax > 0 ? (totalScored / totalMax) * 100 : 0.0;
    String grade = 'F';
    Color color = AppColors.error;

    if (pct >= 90) {
      grade = 'A+ (Outstanding)';
      color = AppColors.success;
    } else if (pct >= 80) {
      grade = 'A (Excellent)';
      color = const Color(0xFF10B981);
    } else if (pct >= 70) {
      grade = 'B+ (Very Good)';
      color = Colors.blue;
    } else if (pct >= 60) {
      grade = 'B (Good)';
      color = const Color(0xFF6366F1);
    } else if (pct >= 50) {
      grade = 'C (Above Average)';
      color = const Color(0xFFF59E0B);
    } else if (pct >= 40) {
      grade = 'D (Pass)';
      color = Colors.orange;
    }

    return {
      'scored': totalScored.toStringAsFixed(1),
      'max': totalMax.toStringAsFixed(1),
      'pct': pct.toStringAsFixed(2),
      'grade': grade,
      'color': color,
    };
  }

  // 2. Exam Score Needed
  Map<String, dynamic> _computeExamNeeded() {
    final cur = double.tryParse(_examCurrentCtrl.text) ?? 78;
    final target = double.tryParse(_examTargetCtrl.text) ?? 85;
    final w = (double.tryParse(_examWeightCtrl.text) ?? 30) / 100.0;

    if (w <= 0 || w >= 1.0) {
      return {'needed': '0.0%', 'desc': 'Invalid weight (must be 1-99%)', 'color': AppColors.error};
    }

    // Target = Current*(1-w) + Final*w
    // Final = (Target - Current*(1-w)) / w
    final needed = (target - (cur * (1.0 - w))) / w;
    String desc;
    Color color;

    if (needed <= 0) {
      desc = 'You already locked in your target grade! 🎉';
      color = AppColors.success;
    } else if (needed <= 100) {
      desc = 'Attainable score needed on final exam';
      color = needed > 85 ? const Color(0xFFF59E0B) : AppColors.success;
    } else {
      desc = 'Exceeds 100%. Target mathematically out of reach unless extra credit is offered.';
      color = AppColors.error;
    }

    return {'needed': '${needed.toStringAsFixed(1)}%', 'desc': desc, 'color': color};
  }

  // 3. Attendance
  Map<String, dynamic> _computeAttendance() {
    final total = int.tryParse(_attTotalCtrl.text) ?? 60;
    final attended = int.tryParse(_attAttendedCtrl.text) ?? 42;
    final req = double.tryParse(_attRequiredCtrl.text) ?? 75;

    if (total <= 0 || attended < 0 || attended > total) {
      return {'pct': '0%', 'status': 'Invalid attendance inputs', 'color': AppColors.error, 'action': '--'};
    }

    final curPct = (attended / total) * 100.0;
    String action;
    Color color;

    if (curPct >= req) {
      // How many classes can be safely skipped?
      // (attended) / (total + x) >= req / 100
      // total + x <= attended / (req/100)
      final maxTotal = (attended / (req / 100.0)).floor();
      final canBunk = math.max(0, maxTotal - total);
      action = canBunk > 0
          ? 'You can safely skip up to $canBunk upcoming classes and maintain ≥ $req%.'
          : 'You are at the border. You cannot skip any classes.';
      color = AppColors.success;
    } else {
      // How many more classes needed consecutively?
      // (attended + x) / (total + x) >= req/100
      // attended + x >= (req/100)*total + (req/100)*x
      // x * (1 - req/100) >= (req/100)*total - attended
      final reqFrac = req / 100.0;
      final numerator = (reqFrac * total) - attended;
      final denominator = 1.0 - reqFrac;
      final needToAttend = (numerator / denominator).ceil();
      action = 'You must attend the next $needToAttend classes consecutively without absence to reach $req%.';
      color = AppColors.error;
    }

    return {
      'pct': '${curPct.toStringAsFixed(1)}%',
      'status': curPct >= req ? 'ELIGIBLE' : 'SHORTAGE / NOT ELIGIBLE',
      'color': color,
      'action': action,
    };
  }

  // 4. Scientific Calculator Logic
  void _onCalcKeyPress(String key) {
    PreferencesService().triggerHaptic();
    setState(() {
      if (key == 'C') {
        _calcDisplay = '';
        _calcResult = '0';
      } else if (key == '⌫') {
        if (_calcDisplay.isNotEmpty) {
          _calcDisplay = _calcDisplay.substring(0, _calcDisplay.length - 1);
        }
      } else if (key == '=') {
        _evalScientificExpr();
      } else {
        _calcDisplay += key;
      }
    });
  }

  void _evalScientificExpr() {
    if (_calcDisplay.isEmpty) return;
    try {
      String expr = _calcDisplay
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('π', '${math.pi}')
          .replaceAll('e', '${math.e}');

      ExpressionParser p = GrammarParser();
      Expression exp = p.parse(expr);
      double eval = exp.evaluate(EvaluationType.REAL, ContextModel());

      setState(() {
        if (eval.isNaN || eval.isInfinite) {
          _calcResult = 'Error';
        } else {
          _calcResult = (eval == eval.roundToDouble()) ? eval.toInt().toString() : eval.toStringAsFixed(4);
          _calcHistory.insert(0, '$_calcDisplay = $_calcResult');
          if (_calcHistory.length > 8) _calcHistory.removeLast();
        }
      });
    } catch (e) {
      setState(() => _calcResult = 'Error');
    }
  }

  // 5. Equation Solver
  Map<String, dynamic> _solveEquation() {
    if (_equationType == 0) {
      // Linear: ax + b = 0 => x = -b / a
      final a = double.tryParse(_eqACtrl.text) ?? 1;
      final b = double.tryParse(_eqBCtrl.text) ?? -5;
      if (a == 0) {
        return {'title': 'Linear: $a x + $b = 0', 'res': b == 0 ? 'Infinitely many solutions' : 'No solution'};
      }
      final x = -b / a;
      return {
        'title': 'Linear: ${a}x + ($b) = 0',
        'res': 'x = ${x.toStringAsFixed(4)}',
        'steps': 'Step: x = -b / a = -($b) / $a = ${x.toStringAsFixed(4)}',
      };
    } else if (_equationType == 1) {
      // Quadratic: ax^2 + bx + c = 0
      final a = double.tryParse(_eqACtrl.text) ?? 1;
      final b = double.tryParse(_eqBCtrl.text) ?? -5;
      final c = double.tryParse(_eqCCtrl.text) ?? 6;

      if (a == 0) return {'title': 'Not a quadratic (a = 0)', 'res': 'a cannot be 0'};

      final disc = (b * b) - (4 * a * c);
      String res;
      String steps = 'Discriminant Δ = b² - 4ac = ($b)² - 4($a)($c) = ${disc.toStringAsFixed(2)}\n';

      if (disc > 0) {
        final x1 = (-b + math.sqrt(disc)) / (2 * a);
        final x2 = (-b - math.sqrt(disc)) / (2 * a);
        res = 'x₁ = ${x1.toStringAsFixed(4)}\nx₂ = ${x2.toStringAsFixed(4)}';
        steps += 'Two real roots: x = (-b ± √Δ) / 2a';
      } else if (disc == 0) {
        final x = -b / (2 * a);
        res = 'x = ${x.toStringAsFixed(4)} (Double Root)';
        steps += 'Single real root: x = -b / 2a';
      } else {
        final realPart = -b / (2 * a);
        final imagPart = math.sqrt(-disc) / (2 * a);
        res = 'x₁ = ${realPart.toStringAsFixed(3)} + ${imagPart.abs().toStringAsFixed(3)}i\n'
            'x₂ = ${realPart.toStringAsFixed(3)} - ${imagPart.abs().toStringAsFixed(3)}i';
        steps += 'Two complex conjugate roots: Δ < 0';
      }

      return {'title': 'Quadratic: ${a}x² + ($b)x + ($c) = 0', 'res': res, 'steps': steps};
    } else {
      // 2x2 System
      final a1 = double.tryParse(_sysA1Ctrl.text) ?? 2;
      final b1 = double.tryParse(_sysB1Ctrl.text) ?? 3;
      final c1 = double.tryParse(_sysC1Ctrl.text) ?? 8;
      final a2 = double.tryParse(_sysA2Ctrl.text) ?? 1;
      final b2 = double.tryParse(_sysB2Ctrl.text) ?? -1;
      final c2 = double.tryParse(_sysC2Ctrl.text) ?? -1;

      final d = (a1 * b2) - (a2 * b1);
      final dx = (c1 * b2) - (c2 * b1);
      final dy = (a1 * c2) - (a2 * c1);

      if (d == 0) {
        final res = (dx == 0 && dy == 0) ? 'Infinitely many solutions (Dependent lines)' : 'No solution (Parallel lines)';
        return {'title': '2×2 Linear System', 'res': res, 'steps': 'Determinant D = 0'};
      }

      final x = dx / d;
      final y = dy / d;
      return {
        'title': '2×2 Linear System (Cramer\'s Rule)',
        'res': 'x = ${x.toStringAsFixed(4)}\ny = ${y.toStringAsFixed(4)}',
        'steps': 'Determinant D = $d, Dx = $dx, Dy = $dy\nx = Dx/D, y = Dy/D',
      };
    }
  }

  // 6. Primes & Factorization
  Map<String, dynamic> _computePrimes() {
    final n = int.tryParse(_primeInputCtrl.text) ?? 360;
    if (n < 1) return {'isPrime': false, 'factors': 'N/A', 'nextPrime': '2', 'primesList': ''};

    bool isPrime(int val) {
      if (val < 2) return false;
      if (val == 2 || val == 3) return true;
      if (val % 2 == 0 || val % 3 == 0) return false;
      for (int i = 5; i * i <= val; i += 6) {
        if (val % i == 0 || val % (i + 2) == 0) return false;
      }
      return true;
    }

    final primeFlag = isPrime(n);

    // Factors
    int temp = n;
    final Map<int, int> factorMap = {};
    for (int d = 2; d * d <= temp; d++) {
      while (temp % d == 0) {
        factorMap[d] = (factorMap[d] ?? 0) + 1;
        temp ~/= d;
      }
    }
    if (temp > 1) factorMap[temp] = (factorMap[temp] ?? 0) + 1;

    final factorStr = factorMap.entries.map((e) => e.value > 1 ? '${e.key}^${e.value}' : '${e.key}').join(' × ');

    // Next prime
    int nextP = n + 1;
    while (!isPrime(nextP)) {
      nextP++;
    }

    // Primes up to n (capped at 100 primes)
    final List<int> pList = [];
    for (int i = 2; i <= math.min(n, 500); i++) {
      if (isPrime(i)) pList.add(i);
    }

    return {
      'isPrime': primeFlag,
      'factors': factorStr.isNotEmpty ? factorStr : '$n is prime',
      'nextPrime': nextP.toString(),
      'primesCount': pList.length,
      'primesSample': pList.take(25).join(', ') + (pList.length > 25 ? '...' : ''),
    };
  }

  // 7. GCD & LCM
  Map<String, dynamic> _computeGcdLcm() {
    final raw = _gcdInputCtrl.text;
    final nums = raw
        .split(RegExp(r'[, ]+'))
        .map((s) => int.tryParse(s.trim()))
        .where((n) => n != null && n > 0)
        .cast<int>()
        .toList();

    if (nums.isEmpty) return {'gcd': '0', 'lcm': '0', 'desc': 'Enter positive integers separated by commas'};

    int gcdTwo(int a, int b) {
      while (b != 0) {
        final t = b;
        b = a % b;
        a = t;
      }
      return a;
    }

    int lcmTwo(int a, int b) {
      if (a == 0 || b == 0) return 0;
      return (a ~/ gcdTwo(a, b)) * b;
    }

    int overallGcd = nums.first;
    int overallLcm = nums.first;

    for (int i = 1; i < nums.length; i++) {
      overallGcd = gcdTwo(overallGcd, nums[i]);
      overallLcm = lcmTwo(overallLcm, nums[i]);
    }

    return {
      'gcd': overallGcd.toString(),
      'lcm': overallLcm.toString(),
      'desc': 'For set: {${nums.join(', ')}}',
    };
  }

  // 8. Matrix Calculator
  Map<String, dynamic> _computeMatrix() {
    if (_matrixSize == 2) {
      final a = _matA2.map((c) => double.tryParse(c.text) ?? 0.0).toList();
      final b = _matB2.map((c) => double.tryParse(c.text) ?? 0.0).toList();

      // a0 a1    b0 b1
      // a2 a3    b2 b3
      final sum = [a[0] + b[0], a[1] + b[1], a[2] + b[2], a[3] + b[3]];
      final diff = [a[0] - b[0], a[1] - b[1], a[2] - b[2], a[3] - b[3]];
      final prod = [
        (a[0] * b[0]) + (a[1] * b[2]),
        (a[0] * b[1]) + (a[1] * b[3]),
        (a[2] * b[0]) + (a[3] * b[2]),
        (a[2] * b[1]) + (a[3] * b[3]),
      ];
      final detA = (a[0] * a[3]) - (a[1] * a[2]);
      final detB = (b[0] * b[3]) - (b[1] * b[2]);

      String invA;
      if (detA != 0) {
        invA = '[${(a[3] / detA).toStringAsFixed(2)}, ${(-a[1] / detA).toStringAsFixed(2)}]\n'
            '[${(-a[2] / detA).toStringAsFixed(2)}, ${(a[0] / detA).toStringAsFixed(2)}]';
      } else {
        invA = 'Singular matrix (No inverse)';
      }

      String fmt(List<double> m) => '[${m[0].toStringAsFixed(1)}, ${m[1].toStringAsFixed(1)}]\n[${m[2].toStringAsFixed(1)}, ${m[3].toStringAsFixed(1)}]';

      return {
        'sum': fmt(sum),
        'diff': fmt(diff),
        'prod': fmt(prod),
        'detA': detA.toStringAsFixed(2),
        'detB': detB.toStringAsFixed(2),
        'invA': invA,
      };
    } else {
      final a = _matA3.map((c) => double.tryParse(c.text) ?? 0.0).toList();
      // det of 3x3
      // a0 a1 a2
      // a3 a4 a5
      // a6 a7 a8
      final detA = (a[0] * ((a[4] * a[8]) - (a[5] * a[7]))) -
          (a[1] * ((a[3] * a[8]) - (a[5] * a[6]))) +
          (a[2] * ((a[3] * a[7]) - (a[4] * a[6])));

      final transA = [a[0], a[3], a[6], a[1], a[4], a[7], a[2], a[5], a[8]];
      String fmt3(List<double> m) =>
          '[${m[0]}, ${m[1]}, ${m[2]}]\n[${m[3]}, ${m[4]}, ${m[5]}]\n[${m[6]}, ${m[7]}, ${m[8]}]';

      return {
        'detA': detA.toStringAsFixed(2),
        'transA': fmt3(transA),
      };
    }
  }

  // 9. Permutation & Combination
  Map<String, dynamic> _computePermComb() {
    final n = int.tryParse(_permNCtrl.text) ?? 8;
    final r = int.tryParse(_permRCtrl.text) ?? 3;

    if (n < 0 || r < 0 || r > n) {
      return {'nPr': '0', 'nCr': '0', 'valid': false};
    }

    BigInt fact(int val) {
      BigInt res = BigInt.one;
      for (int i = 2; i <= val; i++) {
        res *= BigInt.from(i);
      }
      return res;
    }

    final nFact = fact(n);
    final nMinusRFact = fact(n - r);
    final rFact = fact(r);

    final nPr = nFact ~/ nMinusRFact;
    final nCr = nPr ~/ rFact;

    return {
      'nPr': nPr.toString(),
      'nCr': nCr.toString(),
      'valid': true,
      'formulaP': '$n! / ($n - $r)! = $n! / ${n - r}!',
      'formulaC': '$n! / ($r! × ($n - $r)!)',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Academic & Education Suite',
      category: ToolCategory.education,
      toolId: 'academic_toolkit',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabChips(isDark),
          const SizedBox(height: 16),
          if (_activeTab == AcademicTab.marks) _buildMarksTab(isDark),
          if (_activeTab == AcademicTab.examNeeded) _buildExamNeededTab(isDark),
          if (_activeTab == AcademicTab.attendance) _buildAttendanceTab(isDark),
          if (_activeTab == AcademicTab.scientific) _buildScientificTab(isDark),
          if (_activeTab == AcademicTab.equations) _buildEquationsTab(isDark),
          if (_activeTab == AcademicTab.primes) _buildPrimesTab(isDark),
          if (_activeTab == AcademicTab.gcdLcm) _buildGcdLcmTab(isDark),
          if (_activeTab == AcademicTab.matrices) _buildMatricesTab(isDark),
          if (_activeTab == AcademicTab.permComb) _buildPermCombTab(isDark),
        ],
      ),
    );
  }

  Widget _buildTabChips(bool isDark) {
    return FeatureTabSelector<AcademicTab>(
      tabs: AcademicTab.values
          .map((tab) => FeatureTabItem(value: tab, label: tab.label, icon: tab.icon))
          .toList(),
      activeTab: _activeTab,
      accentColor: AppColors.catEducation,
      title: 'Academic & Math Toolkit',
      onTabSelected: (tab) => setState(() => _activeTab = tab),
    );
  }

  // --- TAB 1: MARKS PERCENTAGE ---
  Widget _buildMarksTab(bool isDark) {
    final res = _computeMarks();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Total Scored & Grade',
          primaryResult: '${res['pct']}%',
          subtitle: '${res['scored']} / ${res['max']} marks • Grade: ${res['grade']}',
          accentColor: res['color'] as Color,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subjects & Scores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Subject'),
              onPressed: () {
                setState(() {
                  _subjects.add(SubjectMark(name: 'Subject ${_subjects.length + 1}', maxMark: 100, scored: 80));
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _subjects.length,
          separatorBuilder: (_, index) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final s = _subjects[idx];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: BorderSide.none == BorderSide.none ? Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder) : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: s.name,
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Subject'),
                      onChanged: (v) => s.name = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 65,
                    child: TextFormField(
                      initialValue: s.scored.toInt().toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(isDense: true, labelText: 'Score'),
                      onChanged: (v) => setState(() => s.scored = double.tryParse(v) ?? 0),
                    ),
                  ),
                  const Text(' / '),
                  SizedBox(
                    width: 65,
                    child: TextFormField(
                      initialValue: s.maxMark.toInt().toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(isDense: true, labelText: 'Max'),
                      onChanged: (v) => setState(() => s.maxMark = double.tryParse(v) ?? 100),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                    onPressed: _subjects.length > 1
                        ? () => setState(() => _subjects.removeAt(idx))
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // --- TAB 2: EXAM SCORE NEEDED ---
  Widget _buildExamNeededTab(bool isDark) {
    final res = _computeExamNeeded();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Minimum Final Exam Score Needed',
          primaryResult: res['needed'] as String,
          subtitle: res['desc'] as String,
          accentColor: res['color'] as Color,
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'Current Grade (%)',
          controller: _examCurrentCtrl,
          keyboardType: TextInputType.number,
          hintText: 'e.g. 78',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        ModernTextField(
          label: 'Target Desired Final Grade (%)',
          controller: _examTargetCtrl,
          keyboardType: TextInputType.number,
          hintText: 'e.g. 85',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        ModernTextField(
          label: 'Final Exam Weight (%)',
          controller: _examWeightCtrl,
          keyboardType: TextInputType.number,
          hintText: 'e.g. 30 (means final is 30% of total grade)',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // --- TAB 3: ATTENDANCE ELIGIBILITY ---
  Widget _buildAttendanceTab(bool isDark) {
    final res = _computeAttendance();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Current Attendance Status',
          primaryResult: res['pct'] as String,
          subtitle: res['status'] as String,
          accentColor: res['color'] as Color,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (res['color'] as Color).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: (res['color'] as Color).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: res['color'] as Color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(res['action'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Total Classes Held', controller: _attTotalCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'Classes Attended', controller: _attAttendedCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        ModernTextField(
          label: 'Required Minimum Attendance (%)',
          controller: _attRequiredCtrl,
          keyboardType: TextInputType.number,
          hintText: 'e.g. 75',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // --- TAB 4: SCIENTIFIC CALCULATOR ---
  Widget _buildScientificTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(50, 30),
                    ),
                    onPressed: () => setState(() => _isRad = !_isRad),
                    child: Text(_isRad ? 'RAD' : 'DEG', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  Text(
                    _calcDisplay.isEmpty ? '0' : _calcDisplay,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _calcResult,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.catEducation),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildKeypad(),
        if (_calcHistory.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Recent Calculations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          ..._calcHistory.take(4).map((h) => Text(h, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      ],
    );
  }

  Widget _buildKeypad() {
    final keys = [
      ['sin', 'cos', 'tan', 'C', '⌫'],
      ['ln', 'log', 'sqrt', '(', ')'],
      ['^', '7', '8', '9', '÷'],
      ['π', '4', '5', '6', '×'],
      ['e', '1', '2', '3', '-'],
      ['0', '.', '=', '+', '%'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Row(
            children: row.map((k) {
              final isOp = ['÷', '×', '-', '+', '='].contains(k);
              final isSpecial = ['C', '⌫', 'sin', 'cos', 'tan', 'ln', 'log', 'sqrt', '^', '(', ')', 'π', 'e'].contains(k);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: k == '='
                          ? AppColors.catEducation
                          : isOp
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.18)
                              : isSpecial
                                  ? Colors.grey.withValues(alpha: 0.18)
                                  : null,
                      foregroundColor: k == '=' ? Colors.white : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _onCalcKeyPress(k),
                    child: Text(k, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  // --- TAB 5: EQUATION SOLVER ---
  Widget _buildEquationsTab(bool isDark) {
    final eq = _solveEquation();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: eq['title'] as String,
          primaryResult: eq['res'] as String,
          subtitle: eq['steps'] != null ? eq['steps'] as String : '',
          accentColor: AppColors.catEducation,
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Linear')),
            ButtonSegment(value: 1, label: Text('Quadratic')),
            ButtonSegment(value: 2, label: Text('2x2 System')),
          ],
          selected: {_equationType},
          onSelectionChanged: (set) => setState(() => _equationType = set.first),
        ),
        const SizedBox(height: 16),
        if (_equationType == 0) ...[
          const Text('Linear Equation format: a·x + b = 0', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'Coefficient a', controller: _eqACtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: ModernTextField(label: 'Constant b', controller: _eqBCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
        ] else if (_equationType == 1) ...[
          const Text('Quadratic format: a·x² + b·x + c = 0', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'a', controller: _eqACtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ModernTextField(label: 'b', controller: _eqBCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ModernTextField(label: 'c', controller: _eqCCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
        ] else ...[
          const Text('System: a₁·x + b₁·y = c₁  AND  a₂·x + b₂·y = c₂', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'a₁', controller: _sysA1Ctrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 6),
              Expanded(child: ModernTextField(label: 'b₁', controller: _sysB1Ctrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 6),
              Expanded(child: ModernTextField(label: 'c₁', controller: _sysC1Ctrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'a₂', controller: _sysA2Ctrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 6),
              Expanded(child: ModernTextField(label: 'b₂', controller: _sysB2Ctrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 6),
              Expanded(child: ModernTextField(label: 'c₂', controller: _sysC2Ctrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
        ],
      ],
    );
  }

  // --- TAB 6: PRIMES & FACTORIZATION ---
  Widget _buildPrimesTab(bool isDark) {
    final res = _computePrimes();
    final isP = res['isPrime'] as bool;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Prime Status & Decomposition',
          primaryResult: isP ? 'PRIME NUMBER' : 'COMPOSITE NUMBER',
          subtitle: 'Prime Factors: ${res['factors']}',
          accentColor: isP ? AppColors.success : AppColors.catEducation,
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'Enter an Integer to Test',
          controller: _primeInputCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Next Prime: ${res['nextPrime']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Prime numbers up to input: ${res['primesSample']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 7: GCD & LCM ---
  Widget _buildGcdLcmTab(bool isDark) {
    final res = _computeGcdLcm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'GCD (HCF) and LCM',
          primaryResult: 'GCD: ${res['gcd']} • LCM: ${res['lcm']}',
          subtitle: res['desc'] as String,
          accentColor: AppColors.catEducation,
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'Numbers (Comma separated)',
          controller: _gcdInputCtrl,
          hintText: 'e.g. 24, 36, 60',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // --- TAB 8: MATRICES ---
  Widget _buildMatricesTab(bool isDark) {
    final res = _computeMatrix();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 2, label: Text('2 × 2 Matrix')),
            ButtonSegment(value: 3, label: Text('3 × 3 Matrix')),
          ],
          selected: {_matrixSize},
          onSelectionChanged: (set) => setState(() => _matrixSize = set.first),
        ),
        const SizedBox(height: 16),
        if (_matrixSize == 2) ...[
          Row(
            children: [
              Expanded(child: _matrixInputCard('Matrix A', _matA2, 2)),
              const SizedBox(width: 10),
              Expanded(child: _matrixInputCard('Matrix B', _matB2, 2)),
            ],
          ),
          const SizedBox(height: 16),
          ResultCard(
            title: 'Matrix A × B (Multiplication)',
            primaryResult: res['prod'] as String,
            subtitle: 'Det(A) = ${res['detA']} • Det(B) = ${res['detB']}',
            accentColor: AppColors.catEducation,
          ),
          const SizedBox(height: 12),
          Text('A⁻¹ (Inverse of A):\n${res['invA']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ] else ...[
          _matrixInputCard('Matrix A (3×3)', _matA3, 3),
          const SizedBox(height: 16),
          ResultCard(
            title: 'Determinant & Transpose of A',
            primaryResult: 'Det(A) = ${res['detA']}',
            subtitle: 'Transpose Aᵀ:\n${res['transA']}',
            accentColor: AppColors.catEducation,
          ),
        ],
      ],
    );
  }

  Widget _matrixInputCard(String title, List<TextEditingController> ctrls, int size) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.catEducation.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: size,
              childAspectRatio: 1.5,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: size * size,
            itemBuilder: (_, i) => TextFormField(
              controller: ctrls[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 9: PERMUTATION & COMBINATION ---
  Widget _buildPermCombTab(bool isDark) {
    final res = _computePermComb();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Permutations & Combinations',
          primaryResult: 'nPr = ${res['nPr']} • nCr = ${res['nCr']}',
          subtitle: res['valid'] as bool ? 'P = ${res['formulaP']}' : 'Invalid n or r (ensure n ≥ r ≥ 0)',
          accentColor: AppColors.catEducation,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Total Items (n)', controller: _permNCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'Sample / Chosen (r)', controller: _permRCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
      ],
    );
  }
}
