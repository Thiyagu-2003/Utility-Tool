import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../calculator/calculator_screen.dart' show evaluateCalculatorExpression;

enum MathTab {
  scientific('Scientific Calc', Icons.calculate_rounded),
  equations('Equation Solver', Icons.functions_rounded),
  primes('Prime Tools', Icons.filter_vintage_rounded),
  gcdLcm('GCD & LCM', Icons.alt_route_rounded),
  matrices('Matrix 2x2 / 3x3', Icons.grid_4x4_rounded),
  permComb('Perm & Comb', Icons.grain_rounded);

  final String label;
  final IconData icon;
  const MathTab(this.label, this.icon);
}

/// Trial-division primality test (callers keep the value below 10^12).
bool isPrimeInt(int val) {
  if (val < 2) return false;
  if (val == 2 || val == 3) return true;
  if (val % 2 == 0 || val % 3 == 0) return false;
  for (int i = 5; i <= val ~/ i; i += 6) {
    if (val % i == 0 || (i + 2 <= val ~/ (i + 2) && val % (i + 2) == 0)) return false;
  }
  return true;
}

/// Primes in [start, end] (either order, start clamped to 2). The span is capped
/// at [maxSpan] numbers so a huge range can't freeze the UI.
List<int> primesInRange(int start, int end, {int maxSpan = 200000}) {
  var lo = math.min(start, end), hi = math.max(start, end);
  if (lo < 2) lo = 2;
  if (lo > 1000000000000) return const [];
  if (hi > 1000000000000) hi = 1000000000000;
  if (hi - lo >= maxSpan) hi = lo + maxSpan - 1;
  return [for (var i = lo; i <= hi; i++) if (isPrimeInt(i)) i];
}

/// Compact number text: up to 4 decimals, no trailing zeros, never "-0".
String fmtNum(double v) {
  if (v.isNaN || v.isInfinite) return v.toString();
  final t = v.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
  return t == '-0' ? '0' : t;
}

List<double> matAdd(List<double> a, List<double> b) => [for (var i = 0; i < a.length; i++) a[i] + b[i]];
List<double> matSub(List<double> a, List<double> b) => [for (var i = 0; i < a.length; i++) a[i] - b[i]];

/// Row-major n x n product.
List<double> matMul(List<double> a, List<double> b, int n) => [
      for (var r = 0; r < n; r++)
        for (var c = 0; c < n; c++)
          [for (var k = 0; k < n; k++) a[r * n + k] * b[k * n + c]].fold(0.0, (x, y) => x + y),
    ];

String matToString(List<double> m, int n) =>
    [for (var r = 0; r < n; r++) '[${m.sublist(r * n, r * n + n).map(fmtNum).join(', ')}]'].join('\n');

class MathToolkitScreen extends StatefulWidget {
  final MathTab initialTab;

  const MathToolkitScreen({
    super.key,
    this.initialTab = MathTab.scientific,
  });

  @override
  State<MathToolkitScreen> createState() => _MathToolkitScreenState();
}

class _MathToolkitScreenState extends State<MathToolkitScreen> {
  late MathTab _activeTab;

  // 1. SCIENTIFIC CALCULATOR
  String _calcDisplay = '';
  String _calcResult = '0';
  bool _isRad = false;
  final List<String> _calcHistory = [];

  // 2. EQUATIONS
  int _equationType = 1; // 0 = Linear, 1 = Quadratic, 2 = 2x2 System
  final TextEditingController _eqACtrl = TextEditingController(text: '1');
  final TextEditingController _eqBCtrl = TextEditingController(text: '-5');
  final TextEditingController _eqCCtrl = TextEditingController(text: '6');
  final TextEditingController _sysA1Ctrl = TextEditingController(text: '2');
  final TextEditingController _sysB1Ctrl = TextEditingController(text: '3');
  final TextEditingController _sysC1Ctrl = TextEditingController(text: '8');
  final TextEditingController _sysA2Ctrl = TextEditingController(text: '5');
  final TextEditingController _sysB2Ctrl = TextEditingController(text: '-1');
  final TextEditingController _sysC2Ctrl = TextEditingController(text: '3');

  // 3. PRIMES
  final TextEditingController _primeInputCtrl = TextEditingController(text: '97');
  final TextEditingController _primeFromCtrl = TextEditingController(text: '1');
  final TextEditingController _primeToCtrl = TextEditingController(text: '100');

  // 4. GCD & LCM
  final TextEditingController _gcdInputCtrl = TextEditingController(text: '24, 36, 60');

  // 5. MATRICES
  int _matrixSize = 2;
  int _matrixOp = 0; // 0: A x B, 1: A + B, 2: A - B, 3: Det & Inv
  late List<TextEditingController> _matA2;
  late List<TextEditingController> _matB2;
  late List<TextEditingController> _matA3;
  late List<TextEditingController> _matB3;

  // 6. PERMUTATIONS & COMBINATIONS
  final TextEditingController _permNCtrl = TextEditingController(text: '10');
  final TextEditingController _permRCtrl = TextEditingController(text: '3');

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;

    _matA2 = List.generate(4, (i) => TextEditingController(text: i == 0 || i == 3 ? '2' : '1'));
    _matB2 = List.generate(4, (i) => TextEditingController(text: i == 0 || i == 3 ? '1' : '0'));
    _matA3 = List.generate(9, (i) => TextEditingController(text: (i + 1).toString()));
    _matB3 = List.generate(9, (i) => TextEditingController(text: (9 - i).toString()));
  }

  @override
  void dispose() {
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
    _primeFromCtrl.dispose();
    _primeToCtrl.dispose();
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

  double? _val(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    return (v != null && v.isFinite) ? v : null;
  }

  // --- SCIENTIFIC CALCULATOR LOGIC ---
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
        if (['sin', 'cos', 'tan', 'ln', 'log', 'sqrt'].contains(key)) {
          _calcDisplay += '$key(';
        } else if (key == 'π') {
          _calcDisplay += '3.141592653589793';
        } else if (key == 'e') {
          _calcDisplay += '2.718281828459045';
        } else if (key == '^') {
          _calcDisplay += '^';
        } else if (key == '×') {
          _calcDisplay += '*';
        } else if (key == '÷') {
          _calcDisplay += '/';
        } else {
          _calcDisplay += key;
        }
      }
    });
  }

  void _evalScientificExpr() {
    if (_calcDisplay.isEmpty) return;
    try {
      final eval = evaluateCalculatorExpression(_calcDisplay.replaceAll('log(', 'lg('), degrees: !_isRad);
      setState(() {
        if (eval.isNaN || eval.isInfinite) {
          _calcResult = 'Error';
        } else {
          _calcResult = (eval == eval.roundToDouble() && eval.abs() < 1e15) ? eval.toInt().toString() : eval.toStringAsFixed(4);
          _calcHistory.insert(0, '$_calcDisplay = $_calcResult');
          if (_calcHistory.length > 8) _calcHistory.removeLast();
        }
      });
    } catch (_) {
      setState(() => _calcResult = 'Error');
    }
  }

  // --- EQUATION SOLVER LOGIC ---
  Map<String, dynamic> _solveEquation() {
    const missing = {'title': 'Enter every coefficient', 'res': '--'};
    if (_equationType == 0) {
      final a = _val(_eqACtrl);
      final b = _val(_eqBCtrl);
      if (a == null || b == null) return missing;
      if (a == 0) {
        return {'title': 'Linear: ${fmtNum(a)}x + ${fmtNum(b)} = 0', 'res': b == 0 ? 'Infinitely many solutions' : 'No solution'};
      }
      final x = -b / a + 0.0;
      return {
        'title': 'Linear: ${fmtNum(a)}x + (${fmtNum(b)}) = 0',
        'res': 'x = ${fmtNum(x)}',
        'x1': fmtNum(x),
        'steps': 'Step: x = -b / a = -(${fmtNum(b)}) / ${fmtNum(a)} = ${fmtNum(x)}',
      };
    } else if (_equationType == 1) {
      final a = _val(_eqACtrl);
      final b = _val(_eqBCtrl);
      final c = _val(_eqCCtrl);
      if (a == null || b == null || c == null) return missing;

      if (a == 0) {
        if (b == 0) {
          return {'title': 'Not a quadratic (a = 0)', 'res': c == 0 ? 'Infinitely many solutions' : 'No solution'};
        }
        final x = -c / b + 0.0;
        return {
          'title': 'Linear (a = 0): ${fmtNum(b)}x + (${fmtNum(c)}) = 0',
          'res': 'x = ${fmtNum(x)}',
          'x1': fmtNum(x),
          'steps': 'Linear fallback: x = -c / b = -(${fmtNum(c)}) / ${fmtNum(b)}',
        };
      }

      final disc = (b * b) - (4 * a * c);
      if (!disc.isFinite) {
        return {'title': 'Quadratic calculation overflow', 'res': 'Overflow', 'steps': 'Numbers too large'};
      }
      String res;
      String steps = 'Discriminant Δ = b² - 4ac = (${fmtNum(b)})² - 4(${fmtNum(a)})(${fmtNum(c)}) = ${fmtNum(disc)}\n';
      String? root1;
      String? root2;

      if (disc > 0) {
        final x1 = (-b + math.sqrt(disc)) / (2 * a);
        final x2 = (-b - math.sqrt(disc)) / (2 * a);
        root1 = fmtNum(x1);
        root2 = fmtNum(x2);
        res = 'x₁ = $root1\nx₂ = $root2';
        steps += 'Two real roots: x = (-b ± √Δ) / 2a';
      } else if (disc == 0) {
        final x = -b / (2 * a) + 0.0;
        root1 = fmtNum(x);
        root2 = fmtNum(x);
        res = 'Double root: x = $root1';
        steps += 'One repeated real root: x = -b / 2a';
      } else {
        final real = -b / (2 * a) + 0.0;
        final imag = math.sqrt(-disc) / (2 * a.abs());
        final rStr = fmtNum(real);
        final iStr = fmtNum(imag);
        root1 = '$rStr + ${iStr}i';
        root2 = '$rStr - ${iStr}i';
        res = 'x₁ = $root1\nx₂ = $root2';
        steps += 'Two complex conjugate roots: Δ < 0';
      }

      return {
        'title': 'Quadratic: ${fmtNum(a)}x² + (${fmtNum(b)})x + (${fmtNum(c)}) = 0',
        'res': res,
        'steps': steps,
        'x1': root1,
        'x2': root2,
        'disc': fmtNum(disc),
      };
    } else {
      final a1 = _val(_sysA1Ctrl);
      final b1 = _val(_sysB1Ctrl);
      final c1 = _val(_sysC1Ctrl);
      final a2 = _val(_sysA2Ctrl);
      final b2 = _val(_sysB2Ctrl);
      final c2 = _val(_sysC2Ctrl);
      if (a1 == null || b1 == null || c1 == null || a2 == null || b2 == null || c2 == null) return missing;

      final d = (a1 * b2) - (a2 * b1);
      final dx = (c1 * b2) - (c2 * b1);
      final dy = (a1 * c2) - (a2 * c1);

      if (!d.isFinite || !dx.isFinite || !dy.isFinite) {
        return {'title': '2×2 Linear System', 'res': 'Overflow', 'steps': 'Determinant calculation overflow'};
      }

      if (d == 0) {
        final res = (dx == 0 && dy == 0) ? 'Infinitely many solutions (Dependent lines)' : 'No solution (Parallel lines)';
        return {'title': '2×2 Linear System', 'res': res, 'steps': 'Determinant D = 0'};
      }

      final x = dx / d + 0.0;
      final y = dy / d + 0.0;
      return {
        'title': '2×2 Linear System (Cramer\'s Rule)',
        'res': 'x = ${fmtNum(x)}\ny = ${fmtNum(y)}',
        'x1': fmtNum(x),
        'y1': fmtNum(y),
        'steps': 'Determinant D = ${fmtNum(d)}, Dx = ${fmtNum(dx)}, Dy = ${fmtNum(dy)}\nx = Dx/D, y = Dy/D',
      };
    }
  }

  // --- PRIMES LOGIC ---
  Map<String, dynamic> _computePrimes() {
    final n = int.tryParse(_primeInputCtrl.text.trim());
    final from = int.tryParse(_primeFromCtrl.text.trim());
    final to = int.tryParse(_primeToCtrl.text.trim());
    final range = (from == null || to == null) ? <int>[] : primesInRange(from, to);
    final rangeText = (from == null || to == null)
        ? 'Enter a whole-number range.'
        : '${range.length} primes between ${math.min(from, to)} and ${math.max(from, to)}'
            '${(from - to).abs() >= 200000 ? ' (first 200,000 numbers only)' : ''}: '
            '${range.take(60).join(', ')}${range.length > 60 ? ' ...' : ''}';

    if (n == null || n < 1) {
      return {'isPrime': false, 'factors': 'Enter a whole number of 1 or more', 'nextPrime': '--', 'prevPrime': '--', 'rangeText': rangeText, 'rangeList': range};
    }
    if (n > 1000000000000) {
      return {'isPrime': false, 'factors': 'Number too large (max 10^12)', 'nextPrime': '--', 'prevPrime': '--', 'rangeText': rangeText, 'rangeList': range};
    }

    final primeFlag = isPrimeInt(n);

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

    int nextP = n + 1;
    while (!isPrimeInt(nextP)) {
      nextP++;
    }

    int? prevP;
    if (n > 2) {
      int p = n - 1;
      while (p >= 2 && !isPrimeInt(p)) {
        p--;
      }
      if (p >= 2) prevP = p;
    }

    return {
      'isPrime': primeFlag,
      'factors': n == 1 ? '1 has no prime factors' : factorStr,
      'nextPrime': nextP.toString(),
      'prevPrime': prevP?.toString() ?? '--',
      'rangeText': rangeText,
      'rangeList': range,
    };
  }

  // --- GCD & LCM LOGIC ---
  Map<String, dynamic> _computeGcdLcm() {
    final raw = _gcdInputCtrl.text;
    final nums = raw
        .split(RegExp(r'[,;\s]+'))
        .map((s) => int.tryParse(s.trim())?.abs())
        .where((n) => n != null && n > 0)
        .cast<int>()
        .toList();

    if (nums.isEmpty) return {'gcd': '0', 'lcm': '0', 'desc': 'Enter non-zero integers separated by commas', 'nums': <int>[]};

    int gcdTwo(int a, int b) {
      while (b != 0) {
        final t = b;
        b = a % b;
        a = t;
      }
      return a;
    }

    int overallGcd = nums.first;
    BigInt overallLcm = BigInt.from(nums.first);

    for (int i = 1; i < nums.length; i++) {
      overallGcd = gcdTwo(overallGcd, nums[i]);
      final b = BigInt.from(nums[i]);
      overallLcm = overallLcm ~/ overallLcm.gcd(b) * b;
    }

    return {
      'gcd': overallGcd.toString(),
      'lcm': overallLcm.toString(),
      'desc': 'For numbers: ${nums.join(', ')}',
      'nums': nums,
    };
  }

  // --- MATRICES LOGIC ---
  Map<String, dynamic> _computeMatrix() {
    double cell(TextEditingController c) => _val(c) ?? 0.0;
    if (_matrixSize == 2) {
      final a = _matA2.map(cell).toList();
      final b = _matB2.map(cell).toList();

      final detA = (a[0] * a[3]) - (a[1] * a[2]);
      final detB = (b[0] * b[3]) - (b[1] * b[2]);

      String invA;
      if (detA.isFinite && detA.abs() > 1e-12) {
        invA = matToString([a[3] / detA, -a[1] / detA, -a[2] / detA, a[0] / detA], 2);
      } else {
        invA = 'Singular matrix (No inverse)';
      }

      return {
        'sum': matToString(matAdd(a, b), 2),
        'diff': matToString(matSub(a, b), 2),
        'prod': matToString(matMul(a, b, 2), 2),
        'detA': fmtNum(detA),
        'detB': fmtNum(detB),
        'invA': invA,
      };
    } else {
      final a = _matA3.map(cell).toList();
      final b = _matB3.map(cell).toList();

      final detA = (a[0] * ((a[4] * a[8]) - (a[5] * a[7]))) -
          (a[1] * ((a[3] * a[8]) - (a[5] * a[6]))) +
          (a[2] * ((a[3] * a[7]) - (a[4] * a[6])));

      final transA = [a[0], a[3], a[6], a[1], a[4], a[7], a[2], a[5], a[8]];

      String invA = 'Singular matrix (No inverse)';
      if (detA.isFinite && detA.abs() > 1e-12) {
        final adj = [
          a[4] * a[8] - a[5] * a[7], -(a[1] * a[8] - a[2] * a[7]), a[1] * a[5] - a[2] * a[4],
          -(a[3] * a[8] - a[5] * a[6]), a[0] * a[8] - a[2] * a[6], -(a[0] * a[5] - a[2] * a[3]),
          a[3] * a[7] - a[4] * a[6], -(a[0] * a[7] - a[1] * a[6]), a[0] * a[4] - a[1] * a[3],
        ];
        invA = matToString(adj.map((v) => v / detA).toList(), 3);
      }

      return {
        'sum': matToString(matAdd(a, b), 3),
        'diff': matToString(matSub(a, b), 3),
        'prod': matToString(matMul(a, b, 3), 3),
        'detA': fmtNum(detA),
        'transA': matToString(transA, 3),
        'invA': invA,
      };
    }
  }

  // --- PERMUTATIONS & COMBINATIONS LOGIC ---
  Map<String, dynamic> _computePermComb() {
    final n = int.tryParse(_permNCtrl.text.trim());
    final r = int.tryParse(_permRCtrl.text.trim());

    if (n == null || r == null || n < 0 || r < 0 || r > n || n > 1000) {
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
      title: 'Advanced Math Suite',
      category: ToolCategory.calculate,
      toolId: 'math_toolkit',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabChips(isDark),
          const SizedBox(height: 16),
          if (_activeTab == MathTab.scientific) _buildScientificTab(isDark),
          if (_activeTab == MathTab.equations) _buildEquationsTab(isDark),
          if (_activeTab == MathTab.primes) _buildPrimesTab(isDark),
          if (_activeTab == MathTab.gcdLcm) _buildGcdLcmTab(isDark),
          if (_activeTab == MathTab.matrices) _buildMatricesTab(isDark),
          if (_activeTab == MathTab.permComb) _buildPermCombTab(isDark),
        ],
      ),
    );
  }

  Widget _buildTabChips(bool isDark) {
    return FeatureTabSelector<MathTab>(
      tabs: MathTab.values
          .map((tab) => FeatureTabItem(value: tab, label: tab.label, icon: tab.icon))
          .toList(),
      activeTab: _activeTab,
      accentColor: AppColors.catMath,
      title: 'Advanced Math Suite',
      onTabSelected: (tab) {
        setState(() => _activeTab = tab);
      },
    );
  }

  // =========================================================================
  // TAB 1: SCIENTIFIC CALCULATOR UI (Ergonomic, modern keypad with clusters)
  // =========================================================================
  Widget _buildScientificTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display Screen
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _isRad = !_isRad),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Text(
                        _isRad ? 'RAD' : 'DEG',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.catMath,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _calcDisplay.isEmpty ? '0' : _calcDisplay,
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(
                _calcResult,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: AppColors.catMath,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Modern Ergonomic Keypad
        _buildKeypad(isDark),

        // Recent Calculations Strip
        if (_calcHistory.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface.withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history_rounded, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        const SizedBox(width: 5),
                        Text(
                          'Recent Calculations',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.grey.shade800),
                        ),
                      ],
                    ),
                    Text(
                      'Tap to reuse',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _calcHistory.take(4).map((h) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        final parts = h.split('=');
                        if (parts.isNotEmpty) {
                          setState(() {
                            _calcDisplay = parts.first.trim();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBackground : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Text(
                          h,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKeypad(bool isDark) {
    final keys = [
      ['sin', 'cos', 'tan', 'C', '⌫'],
      ['ln', 'log', 'sqrt', '(', ')'],
      ['^', '7', '8', '9', '÷'],
      ['π', '4', '5', '6', '×'],
      ['e', '1', '2', '3', '-'],
      ['0', '.', '=', '+', '%'],
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              children: row.map((k) {
                final isOp = ['÷', '×', '-', '+'].contains(k);
                final isEquals = k == '=';
                final isClear = k == 'C';
                final isBack = k == '⌫';
                final isNum = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.'].contains(k);

                Color bgColor;
                Color fgColor;
                Border? border;
                List<BoxShadow>? shadows;

                if (isEquals) {
                  bgColor = AppColors.catMath;
                  fgColor = Colors.white;
                  shadows = [
                    BoxShadow(
                      color: AppColors.catMath.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ];
                } else if (isClear) {
                  bgColor = isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2);
                  fgColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
                  border = Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA));
                } else if (isBack) {
                  bgColor = isDark ? const Color(0xFF452B14) : const Color(0xFFFEF3C7);
                  fgColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
                  border = Border.all(color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A));
                } else if (isOp) {
                  bgColor = isDark ? AppColors.catMath.withValues(alpha: 0.22) : const Color(0xFFDBEAFE);
                  fgColor = AppColors.catMath;
                  border = Border.all(color: AppColors.catMath.withValues(alpha: isDark ? 0.35 : 0.2));
                } else if (isNum) {
                  bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
                  fgColor = isDark ? Colors.white : const Color(0xFF0F172A);
                  border = Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
                } else {
                  // Scientific functions & constants
                  bgColor = isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9);
                  fgColor = isDark ? Colors.grey.shade300 : const Color(0xFF334155);
                  border = Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0));
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _onCalcKeyPress(k),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: border,
                          boxShadow: shadows,
                        ),
                        child: Center(
                          child: Text(
                            k == 'sqrt' ? '√' : k,
                            style: TextStyle(
                              fontSize: isNum || isOp || isEquals ? 16 : 12,
                              fontWeight: isEquals || isNum || isOp ? FontWeight.w800 : FontWeight.w600,
                              color: fgColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================================================================
  // TAB 2: EQUATION SOLVER UI (High contrast pill switch, math input builder)
  // =========================================================================
  Widget _buildEquationsTab(bool isDark) {
    final eq = _solveEquation();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Solution Result Card
        ResultCard(
          title: eq['title'] as String,
          primaryResult: eq['res'] as String,
          subtitle: eq['steps'] != null ? eq['steps'] as String : '',
          accentColor: AppColors.catMath,
        ),
        const SizedBox(height: 16),

        // Robust Pill Switcher (Fixes white-on-peach contrast & text wrapping)
        _buildEquationTypeSelector(isDark),
        const SizedBox(height: 16),

        if (_equationType == 0) ...[
          _buildEquationHeaderBanner('Linear Format: a·x + b = 0', isDark),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  label: 'Coefficient a',
                  controller: _eqACtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ModernTextField(
                  label: 'Constant b',
                  controller: _eqBCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ] else if (_equationType == 1) ...[
          _buildEquationHeaderBanner('Quadratic Format: a·x² + b·x + c = 0', isDark),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  label: 'a (x²)',
                  controller: _eqACtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ModernTextField(
                  label: 'b (x)',
                  controller: _eqBCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ModernTextField(
                  label: 'c (const)',
                  controller: _eqCCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ] else ...[
          _buildEquationHeaderBanner('System: a₁x + b₁y = c₁  AND  a₂x + b₂y = c₂', isDark),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Equation 1: a₁x + b₁y = c₁', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: ModernTextField(label: 'a₁', controller: _sysA1Ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 6),
                    Expanded(child: ModernTextField(label: 'b₁', controller: _sysB1Ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 6),
                    Expanded(child: ModernTextField(label: 'c₁', controller: _sysC1Ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Equation 2: a₂x + b₂y = c₂', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: ModernTextField(label: 'a₂', controller: _sysA2Ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 6),
                    Expanded(child: ModernTextField(label: 'b₂', controller: _sysB2Ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 6),
                    Expanded(child: ModernTextField(label: 'c₂', controller: _sysC2Ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEquationTypeSelector(bool isDark) {
    final types = [
      (0, 'Linear (1°)'),
      (1, 'Quadratic (2°)'),
      (2, 'System (2×2)'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: types.map((item) {
          final isSelected = _equationType == item.$1;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _equationType = item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF334155) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? AppColors.catMath
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEquationHeaderBanner(String formatText, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.catMath.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.catMath.withValues(alpha: isDark ? 0.3 : 0.15)),
      ),
      child: Text(
        formatText,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.catMath,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 3: PRIME TOOLS UI (Verified status, balanced navigation, chips grid)
  // =========================================================================
  Widget _buildPrimesTab(bool isDark) {
    final res = _computePrimes();
    final isP = res['isPrime'] as bool;
    final rangePrimes = res['rangeList'] as List<int>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primality Result Card
        ResultCard(
          title: 'Prime Status & Decomposition',
          primaryResult: isP ? 'PRIME NUMBER' : 'COMPOSITE NUMBER',
          subtitle: 'Prime Factors: ${res['factors']}',
          accentColor: isP ? AppColors.success : AppColors.catMath,
        ),
        const SizedBox(height: 16),

        // Input Field
        ModernTextField(
          label: 'Enter an Integer to Test',
          controller: _primeInputCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Balanced Prev & Next Prime Navigation Bar (No awkward dead space!)
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: res['prevPrime'] != '--'
                    ? () {
                        setState(() {
                          _primeInputCtrl.text = res['prevPrime'] as String;
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '← Prev Prime',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      Text(
                        res['prevPrime'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.darkBackground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: res['nextPrime'] != '--'
                    ? () {
                        setState(() {
                          _primeInputCtrl.text = res['nextPrime'] as String;
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Next Prime →',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      Text(
                        res['nextPrime'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: AppColors.catMath,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Prime Range Generator with Count Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Prime Number Generator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.catMath.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${rangePrimes.length} Primes Found',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.catMath),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: ModernTextField(
                label: 'From',
                controller: _primeFromCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ModernTextField(
                label: 'To',
                controller: _primeToCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Prime Number Chips (Replaces raw, unformatted text dump)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface.withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: rangePrimes.isEmpty
              ? Text(
                  res['rangeText'] as String,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...rangePrimes.take(50).map((p) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          setState(() {
                            _primeInputCtrl.text = p.toString();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBackground : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Text(
                            p.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: AppColors.catMath,
                            ),
                          ),
                        ),
                      );
                    }),
                    if (rangePrimes.length > 50)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.catMath.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+${rangePrimes.length - 50} more',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.catMath),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 4: GCD & LCM UI (Dual cards, presets, Euclidean steps)
  // =========================================================================
  Widget _buildGcdLcmTab(bool isDark) {
    final res = _computeGcdLcm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dual Metric Hero Cards (GCD vs LCM)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  children: [
                    const Text('GCD (HCF)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.catMath, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      res['gcd'] as String,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 2),
                    Text('Greatest Divisor', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  children: [
                    const Text('LCM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF9333EA), letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      res['lcm'] as String,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Color(0xFF9333EA)),
                    ),
                    const SizedBox(height: 2),
                    Text('Least Multiple', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        ModernTextField(
          label: 'Numbers (Comma separated)',
          controller: _gcdInputCtrl,
          hintText: 'e.g. 24, 36, 60',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),

        // Quick Preset Chips
        Row(
          children: [
            Text('Presets: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            Wrap(
              spacing: 6,
              children: ['12, 18', '24, 36, 60', '45, 75, 120'].map((p) {
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    setState(() {
                      _gcdInputCtrl.text = p;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Text(p, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Explanation Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface.withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Euclidean Decomposition Details',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.grey.shade800),
              ),
              const SizedBox(height: 4),
              Text(
                res['desc'] as String,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 5: MATRICES UI (Authentic mathematical brackets, operation toggles)
  // =========================================================================
  Widget _buildMatricesTab(bool isDark) {
    final res = _computeMatrix();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Matrix Size Selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _matrixSize = 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _matrixSize == 2 ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '2 × 2 Matrix',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _matrixSize == 2 ? AppColors.catMath : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _matrixSize = 3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _matrixSize == 3 ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '3 × 3 Matrix',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _matrixSize == 3 ? AppColors.catMath : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Matrix Inputs (with Mathematical Bracket styling)
        if (_matrixSize == 2) ...[
          Row(
            children: [
              Expanded(child: _matrixInputCard('Matrix A', _matA2, 2, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _matrixInputCard('Matrix B', _matB2, 2, isDark)),
            ],
          ),
        ] else ...[
          _matrixInputCard('Matrix A (3×3)', _matA3, 3, isDark),
          const SizedBox(height: 12),
          _matrixInputCard('Matrix B (3×3)', _matB3, 3, isDark),
        ],
        const SizedBox(height: 16),

        // Operation Switcher (A x B, A + B, A - B, Inv/Det)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              _matrixOpBtn(0, 'A × B', isDark),
              _matrixOpBtn(1, 'A + B', isDark),
              _matrixOpBtn(2, 'A − B', isDark),
              _matrixOpBtn(3, 'Det & Inv', isDark),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Result Card Formatted
        _buildMatrixResultDisplay(res, isDark),
      ],
    );
  }

  Widget _matrixOpBtn(int opIndex, String label, bool isDark) {
    final isSelected = _matrixOp == opIndex;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _matrixOp = opIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)] : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.catMath : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatrixResultDisplay(Map<String, dynamic> res, bool isDark) {
    String title;
    String primaryResult;
    String subtitle;

    if (_matrixOp == 0) {
      title = 'Matrix Product (A × B)';
      primaryResult = res['prod'] as String;
      subtitle = 'Det(A) = ${res['detA']}${res['detB'] != null ? ' • Det(B) = ${res['detB']}' : ''}';
    } else if (_matrixOp == 1) {
      title = 'Matrix Addition (A + B)';
      primaryResult = res['sum'] as String;
      subtitle = 'Corresponding elements added';
    } else if (_matrixOp == 2) {
      title = 'Matrix Subtraction (A − B)';
      primaryResult = res['diff'] as String;
      subtitle = 'Corresponding elements subtracted';
    } else {
      title = 'Determinant & Inverse of A';
      primaryResult = 'Det(A) = ${res['detA']}';
      subtitle = 'Inverse A⁻¹:\n${res['invA']}';
    }

    return ResultCard(
      title: title,
      primaryResult: primaryResult,
      subtitle: subtitle,
      accentColor: AppColors.catMath,
    );
  }

  Widget _matrixInputCard(String title, List<TextEditingController> ctrls, int size, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          // Bracketed Matrix Layout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.catMath.withValues(alpha: 0.6), width: 2.5),
                right: BorderSide(color: AppColors.catMath.withValues(alpha: 0.6), width: 2.5),
              ),
            ),
            child: GridView.builder(
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.catMath, width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 6: PERMUTATION & COMBINATION UI (Dual metric cards & concepts)
  // =========================================================================
  Widget _buildPermCombTab(bool isDark) {
    final res = _computePermComb();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dual Metric Hero Cards (nPr vs nCr)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  children: [
                    const Text('PERMUTATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.catMath, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      res['nPr'] as String,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 2),
                    Text('nPr (Order matters)', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  children: [
                    const Text('COMBINATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF9333EA), letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      res['nCr'] as String,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Color(0xFF9333EA)),
                    ),
                    const SizedBox(height: 2),
                    Text('nCr (Order ignores)', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Inputs for n and r
        Row(
          children: [
            Expanded(
              child: ModernTextField(
                label: 'Total Items (n)',
                controller: _permNCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ModernTextField(
                label: 'Chosen Items (r)',
                controller: _permRCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Formula & Concept Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface.withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Formulas & Properties',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              Text(
                '• P(n, r) = n! / (n - r)!\n  Sequences, rankings, passwords (e.g. ABC ≠ CBA)',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                '• C(n, r) = n! / (r! × (n - r)!)\n  Groups, selections, hand cards (e.g. {A, B} = {B, A})',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
