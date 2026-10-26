import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';
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
  for (int i = 5; i * i <= val; i += 6) {
    if (val % i == 0 || val % (i + 2) == 0) return false;
  }
  return true;
}

/// Primes in [start, end] (either order, start clamped to 2). The span is capped
/// at [maxSpan] numbers so a huge range can't freeze the UI.
List<int> primesInRange(int start, int end, {int maxSpan = 200000}) {
  var lo = math.min(start, end), hi = math.max(start, end);
  if (lo < 2) lo = 2;
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

  double? _val(TextEditingController c) => double.tryParse(c.text.trim());

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
          _calcDisplay += 'pi';
        } else if (key == 'e') {
          _calcDisplay += 'e';
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
          'title': 'Not a quadratic (a = 0): ${fmtNum(b)}x + (${fmtNum(c)}) = 0',
          'res': 'x = ${fmtNum(x)}',
          'steps': 'Linear: x = -c / b = -(${fmtNum(c)}) / ${fmtNum(b)}',
        };
      }

      final disc = (b * b) - (4 * a * c);
      String res;
      String steps = 'Discriminant Δ = b² - 4ac = (${fmtNum(b)})² - 4(${fmtNum(a)})(${fmtNum(c)}) = ${fmtNum(disc)}\n';

      if (disc > 0) {
        final x1 = (-b + math.sqrt(disc)) / (2 * a);
        final x2 = (-b - math.sqrt(disc)) / (2 * a);
        res = 'x₁ = ${fmtNum(x1)}\nx₂ = ${fmtNum(x2)}';
        steps += 'Two real roots: x = (-b ± √Δ) / 2a';
      } else if (disc == 0) {
        final x = -b / (2 * a) + 0.0;
        res = 'x = ${fmtNum(x)} (Double Root)';
        steps += 'Single real root: x = -b / 2a';
      } else {
        final realPart = -b / (2 * a) + 0.0;
        final imagPart = math.sqrt(-disc) / (2 * a);
        res = 'x₁ = ${fmtNum(realPart)} + ${fmtNum(imagPart.abs())}i\n'
            'x₂ = ${fmtNum(realPart)} - ${fmtNum(imagPart.abs())}i';
        steps += 'Two complex conjugate roots: Δ < 0';
      }

      return {'title': 'Quadratic: ${fmtNum(a)}x² + (${fmtNum(b)})x + (${fmtNum(c)}) = 0', 'res': res, 'steps': steps};
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

      if (d == 0) {
        final res = (dx == 0 && dy == 0) ? 'Infinitely many solutions (Dependent lines)' : 'No solution (Parallel lines)';
        return {'title': '2×2 Linear System', 'res': res, 'steps': 'Determinant D = 0'};
      }

      final x = dx / d + 0.0;
      final y = dy / d + 0.0;
      return {
        'title': '2×2 Linear System (Cramer\'s Rule)',
        'res': 'x = ${fmtNum(x)}\ny = ${fmtNum(y)}',
        'steps': 'Determinant D = ${fmtNum(d)}, Dx = ${fmtNum(dx)}, Dy = ${fmtNum(dy)}\nx = Dx/D, y = Dy/D',
      };
    }
  }

  // --- PRIMES & FACTORIZATION LOGIC ---
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
      return {'isPrime': false, 'factors': 'Enter a whole number of 1 or more', 'nextPrime': '--', 'rangeText': rangeText};
    }
    if (n > 1000000000000) {
      return {'isPrime': false, 'factors': 'Number too large (max 10^12)', 'nextPrime': '--', 'rangeText': rangeText};
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

    return {
      'isPrime': primeFlag,
      'factors': n == 1 ? '1 has no prime factors' : factorStr,
      'nextPrime': nextP.toString(),
      'rangeText': rangeText,
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

    if (nums.isEmpty) return {'gcd': '0', 'lcm': '0', 'desc': 'Enter non-zero integers separated by commas'};

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
      'desc': 'For set: {${nums.join(', ')}}',
    };
  }

  // --- MATRIX CALCULATOR LOGIC ---
  Map<String, dynamic> _computeMatrix() {
    double cell(TextEditingController c) => _val(c) ?? 0.0;
    if (_matrixSize == 2) {
      final a = _matA2.map(cell).toList();
      final b = _matB2.map(cell).toList();

      final detA = (a[0] * a[3]) - (a[1] * a[2]);
      final detB = (b[0] * b[3]) - (b[1] * b[2]);

      String invA;
      if (detA != 0) {
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
      if (detA != 0) {
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

  // --- PERMUTATION & COMBINATION LOGIC ---
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: MathTab.values.map((tab) {
          final isSelected = _activeTab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              avatar: Icon(tab.icon, size: 16, color: isSelected ? Colors.white : AppColors.catMath),
              label: Text(tab.label),
              selected: isSelected,
              onSelected: (_) {
                PreferencesService().triggerHaptic();
                setState(() => _activeTab = tab);
              },
              selectedColor: AppColors.catMath,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- TAB 1: SCIENTIFIC CALCULATOR UI ---
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
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.catMath),
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
                          ? AppColors.catMath
                          : isOp
                              ? const Color(0xFF2563EB).withValues(alpha: 0.18)
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

  // --- TAB 2: EQUATIONS UI ---
  Widget _buildEquationsTab(bool isDark) {
    final eq = _solveEquation();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: eq['title'] as String,
          primaryResult: eq['res'] as String,
          subtitle: eq['steps'] != null ? eq['steps'] as String : '',
          accentColor: AppColors.catMath,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Linear')),
              ButtonSegment(value: 1, label: Text('Quadratic')),
              ButtonSegment(value: 2, label: Text('System')),
            ],
            selected: {_equationType},
            onSelectionChanged: (set) => setState(() => _equationType = set.first),
          ),
        ),
        const SizedBox(height: 16),
        if (_equationType == 0) ...[
          const Text('Linear Equation format: a·x + b = 0', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'Coefficient a', controller: _eqACtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: ModernTextField(label: 'Constant b', controller: _eqBCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
            ],
          ),
        ] else if (_equationType == 1) ...[
          const Text('Quadratic format: a·x² + b·x + c = 0', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'a', controller: _eqACtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ModernTextField(label: 'b', controller: _eqBCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ModernTextField(label: 'c', controller: _eqCCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
            ],
          ),
        ] else ...[
          const Text('System: a₁·x + b₁·y = c₁  AND  a₂·x + b₂·y = c₂', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ModernTextField(label: 'a₁', controller: _sysA1Ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 6),
              Expanded(child: ModernTextField(label: 'b₁', controller: _sysB1Ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 6),
              Expanded(child: ModernTextField(label: 'c₁', controller: _sysC1Ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
            ],
          ),
          const SizedBox(height: 8),
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
      ],
    );
  }

  // --- TAB 3: PRIMES UI ---
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
          accentColor: isP ? AppColors.success : AppColors.catMath,
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Prime Number Generator (range)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'From', controller: _primeFromCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'To', controller: _primeToCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 10),
        Text(res['rangeText'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // --- TAB 4: GCD & LCM UI ---
  Widget _buildGcdLcmTab(bool isDark) {
    final res = _computeGcdLcm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'GCD (HCF) and LCM',
          primaryResult: 'GCD: ${res['gcd']} • LCM: ${res['lcm']}',
          subtitle: res['desc'] as String,
          accentColor: AppColors.catMath,
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

  // --- TAB 5: MATRICES UI ---
  Widget _buildMatricesTab(bool isDark) {
    final res = _computeMatrix();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 2, label: Text('2 × 2')),
              ButtonSegment(value: 3, label: Text('3 × 3')),
            ],
            selected: {_matrixSize},
            onSelectionChanged: (set) => setState(() => _matrixSize = set.first),
          ),
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
            accentColor: AppColors.catMath,
          ),
          const SizedBox(height: 12),
          _monoBlock('A + B:\n${res['sum']}\n\nA − B:\n${res['diff']}\n\nA⁻¹ (Inverse of A):\n${res['invA']}'),
        ] else ...[
          _matrixInputCard('Matrix A (3×3)', _matA3, 3),
          const SizedBox(height: 10),
          _matrixInputCard('Matrix B (3×3)', _matB3, 3),
          const SizedBox(height: 16),
          ResultCard(
            title: 'Matrix A × B (Multiplication)',
            primaryResult: res['prod'] as String,
            subtitle: 'Det(A) = ${res['detA']}',
            accentColor: AppColors.catMath,
          ),
          const SizedBox(height: 12),
          _monoBlock('A + B:\n${res['sum']}\n\nA − B:\n${res['diff']}\n\nTranspose Aᵀ:\n${res['transA']}\n\nA⁻¹ (Inverse of A):\n${res['invA']}'),
        ],
      ],
    );
  }

  Widget _monoBlock(String text) => SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12));

  Widget _matrixInputCard(String title, List<TextEditingController> ctrls, int size) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.catMath.withValues(alpha: 0.3)),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 6: PERMUTATION & COMBINATION UI ---
  Widget _buildPermCombTab(bool isDark) {
    final res = _computePermComb();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Permutations & Combinations',
          primaryResult: 'nPr = ${res['nPr']} • nCr = ${res['nCr']}',
          subtitle: res['valid'] as bool ? 'P = ${res['formulaP']}' : 'Invalid n or r (ensure 1000 ≥ n ≥ r ≥ 0)',
          accentColor: AppColors.catMath,
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
