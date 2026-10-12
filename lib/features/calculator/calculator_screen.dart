import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';

/// Evaluates a calculator display expression (×, ÷, %, π, e, lg, √, !).
/// Throws on malformed input; undefined results come back as NaN/Infinity.
double evaluateCalculatorExpression(String expression, {bool degrees = false}) {
  var exp = expression
      .replaceAll(',', '') // grouping separators from formatted results
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('%', '*(0.01)')
      .replaceAll('π', '(pi)')
      .replaceAll('e', '(e)')
      .replaceAll('lg(', 'log(10,');
  // Auto-close any brackets the user left open, e.g. "sqrt(9".
  final open = '('.allMatches(exp).length - ')'.allMatches(exp).length;
  if (open > 0) exp += ')' * open;
  exp = _wrapSignedExponents(exp);
  final parsed = GrammarParser(const ParserOptions(implicitMultiplication: true)).parse(exp);
  return _CalculatorEvaluator(degrees).evaluate(parsed).toDouble() + 0.0;
}

/// The grammar rejects `2^-1`; rewrite a signed exponent as `2^(-1)`.
String _wrapSignedExponents(String s) {
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i++];
    out.write(c);
    if (c != '^' || i >= s.length || (s[i] != '-' && s[i] != '+')) continue;
    final j = i + 1;
    var k = j;
    int closing(int open) {
      var depth = 0;
      for (var m = open; m < s.length; m++) {
        if (s[m] == '(') depth++;
        if (s[m] == ')' && --depth == 0) return m + 1;
      }
      return s.length;
    }
    if (k < s.length && s[k] == '(') {
      k = closing(k);
    } else {
      while (k < s.length && RegExp(r'[0-9.]').hasMatch(s[k])) {
        k++;
      }
      if (k == j) {
        while (k < s.length && RegExp(r'[a-z]').hasMatch(s[k])) {
          k++;
        }
        if (k > j && k < s.length && s[k] == '(') k = closing(k);
      }
    }
    if (k == j) continue; // nothing to wrap; let the parser report it
    out.write('(${s.substring(i, k)})');
    i = k;
  }
  return out.toString();
}

class _CalculatorEvaluator extends RealEvaluator {
  _CalculatorEvaluator(this.degrees) : super(ContextModel(), true);

  final bool degrees;

  void _toRadians() {
    if (!degrees) return;
    final (val,) = pop1();
    push1(val / 180 * math.pi);
  }

  @override
  void visitSin(Sin func) {
    _toRadians();
    super.visitSin(func);
  }

  @override
  void visitCos(Cos func) {
    _toRadians();
    super.visitCos(func);
  }

  @override
  void visitTan(Tan func) {
    _toRadians();
    super.visitTan(func);
  }

  @override
  void visitFactorial(Factorial func) {
    final (val,) = pop1();
    // n! is only defined here for non-negative integers; 171! overflows a double.
    if (val < 0 || val != val.truncateToDouble()) {
      push1(double.nan);
    } else if (val > 170) {
      push1(double.infinity);
    } else {
      push1(val);
      super.visitFactorial(func);
    }
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = '';
  String _previewResult = '0';
  bool _isScientific = false;
  bool _isDegreeMode = true;
  final NumberFormat _formatter = NumberFormat('#,##0.########');

  void _onButtonPressed(String value) {
    PreferencesService().triggerHaptic();

    setState(() {
      if (value == 'AC') {
        _expression = '';
        _previewResult = '0';
      } else if (value == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _calculatePreview();
        }
      } else if (value == '=') {
        _evaluateFinal();
      } else if (value == '⇄') {
        _isScientific = !_isScientific;
      } else if (value == 'deg' || value == 'rad') {
        _isDegreeMode = !_isDegreeMode;
        _calculatePreview();
      } else if (value == '1/x') {
        if (_expression.isNotEmpty) {
          _expression = '1/($_expression)';
          _calculatePreview();
        }
      } else if (value == 'x!') {
        _appendOperator('!');
        _calculatePreview();
      } else if (value == '√') {
        _expression += 'sqrt(';
        _calculatePreview();
      } else if (value == '.') {
        final last = _expression.isEmpty ? '' : _expression[_expression.length - 1];
        _expression += RegExp(r'[0-9]').hasMatch(last) ? '.' : '0.';
        _calculatePreview();
      } else if (value == 'x^y') {
        if (_expression.isNotEmpty) _expression += '^';
      } else if (['sin', 'cos', 'tan', 'ln', 'lg'].contains(value)) {
        if (value == 'lg') {
          _expression += 'lg(';
        } else {
          _expression += '$value(';
        }
        _calculatePreview();
      } else {
        _expression += value;
        _calculatePreview();
      }
    });
  }

  void _appendOperator(String op) {
    if (_expression.isNotEmpty) {
      final lastChar = _expression[_expression.length - 1];
      if (['+', '-', '×', '÷', '%'].contains(lastChar)) {
        _expression = _expression.substring(0, _expression.length - 1) + op;
      } else {
        _expression += op;
      }
    }
  }

  void _calculatePreview() {
    if (_expression.isEmpty) {
      _previewResult = '0';
      return;
    }

    try {
      final eval = evaluateCalculatorExpression(_expression, degrees: _isDegreeMode);

      if (eval.isNaN || eval.isInfinite) {
        _previewResult = 'Error';
      } else {
        _previewResult = _formatter.format(eval);
      }
    } catch (_) {
      // Expression incomplete while typing
    }
  }

  void _evaluateFinal() {
    if (_expression.isEmpty) return;
    try {
      final eval = evaluateCalculatorExpression(_expression, degrees: _isDegreeMode);

      if (eval.isNaN || eval.isInfinite) {
        setState(() {
          _previewResult = 'Error';
        });
      } else {
        final resultStr = _formatter.format(eval);
        PreferencesService().addCalculationRecord(
          toolTitle: 'Calculator',
          expression: _expression,
          result: resultStr,
        );
        setState(() {
          _expression = resultStr;
          _previewResult = '';
        });
      }
    } catch (_) {
      setState(() {
        _previewResult = 'Format error';
      });
    }
  }

  void _showHistoryModal() {
    PreferencesService().triggerHaptic();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final history = PreferencesService().calculationHistory;

        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (history.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.error),
                      label: const Text('Clear', style: TextStyle(color: AppColors.error)),
                      onPressed: () {
                        PreferencesService().clearHistory();
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const Divider(),
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.darkTextMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text('No recent calculations'),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = history[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            title: Text(
                              item.expression,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            subtitle: Text(
                              item.result,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                            ),
                            trailing: Text(
                              DateFormat('HH:mm').format(item.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _expression = item.result;
                                _calculatePreview();
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeypadButton({
    required String text,
    Color? textColor,
    Color? bgColor,
    bool isAccent = false,
    bool isOperator = false,
    bool isSpecial = false,
    VoidCallback? onTap,
    Widget? customChild,
    int flex = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color resolvedBg;
    if (bgColor != null) {
      resolvedBg = bgColor;
    } else if (isAccent) {
      resolvedBg = AppColors.primaryOrange;
    } else if (isOperator) {
      resolvedBg = isDark
          ? AppColors.primaryOrange.withValues(alpha: 0.12)
          : AppColors.primaryOrange.withValues(alpha: 0.08);
    } else {
      resolvedBg = isDark ? AppColors.darkSurface : AppColors.lightCardHover;
    }

    Color resolvedText;
    if (textColor != null) {
      resolvedText = textColor;
    } else if (isAccent) {
      resolvedText = Colors.white;
    } else if (isOperator || isSpecial) {
      resolvedText = AppColors.primaryOrange;
    } else {
      resolvedText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    }

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3.5),
        child: Material(
          color: resolvedBg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap ?? () => _onButtonPressed(text),
            child: Container(
              height: _isScientific ? 50 : 62,
              alignment: Alignment.center,
              child: customChild ??
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: _isScientific ? 16 : 22,
                      fontWeight: isAccent || isOperator ? FontWeight.bold : FontWeight.w600,
                      color: resolvedText,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // History
                  IconButton(
                    tooltip: 'History',
                    icon: Icon(
                      Icons.history_rounded,
                      size: 22,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    onPressed: _showHistoryModal,
                  ),
                  // Mode indicator
                  if (_isScientific)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _isDegreeMode ? 'DEG' : 'RAD',
                        style: const TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  // Scientific toggle
                  IconButton(
                    tooltip: _isScientific ? 'Basic mode' : 'Scientific mode',
                    icon: Icon(
                      _isScientific ? Icons.calculate_rounded : Icons.science_outlined,
                      color: AppColors.primaryOrange,
                      size: 22,
                    ),
                    onPressed: () {
                      PreferencesService().triggerHaptic();
                      setState(() {
                        _isScientific = !_isScientific;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Display Area
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                alignment: Alignment.bottomRight,
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Expression
                      SelectableText(
                        _expression.isEmpty ? '0' : _expression,
                        style: TextStyle(
                          fontSize: _expression.length > 14 ? 30 : 44,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 6),
                      // Preview
                      if (_previewResult.isNotEmpty && _previewResult != '0')
                        Text(
                          '= $_previewResult',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryOrange.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.right,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Thin separator
            Container(
              height: 0.5,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),

            // Keypad
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
              child: Column(
                children: [
                  // Scientific rows
                  if (_isScientific) ...[
                    Row(
                      children: [
                        _buildKeypadButton(
                          text: _isDegreeMode ? 'deg' : 'rad',
                          isSpecial: true,
                        ),
                        _buildKeypadButton(text: 'sin'),
                        _buildKeypadButton(text: 'cos'),
                        _buildKeypadButton(text: 'tan'),
                        _buildKeypadButton(text: 'π'),
                      ],
                    ),
                    Row(
                      children: [
                        _buildKeypadButton(text: 'x^y'),
                        _buildKeypadButton(text: 'lg'),
                        _buildKeypadButton(text: 'ln'),
                        _buildKeypadButton(text: '('),
                        _buildKeypadButton(text: ')'),
                      ],
                    ),
                    Row(
                      children: [
                        _buildKeypadButton(text: '√'),
                        _buildKeypadButton(text: 'x!'),
                        _buildKeypadButton(text: '1/x'),
                        _buildKeypadButton(text: 'e'),
                        _buildKeypadButton(text: '%', isSpecial: true),
                      ],
                    ),
                  ],

                  // Main keypad
                  Row(
                    children: [
                      _buildKeypadButton(text: 'AC', isSpecial: true),
                      _buildKeypadButton(
                        text: '⌫',
                        isSpecial: true,
                        customChild: Icon(
                          Icons.backspace_outlined,
                          size: 20,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      if (!_isScientific)
                        _buildKeypadButton(text: '%', isSpecial: true),
                      _buildKeypadButton(text: '÷', isOperator: true),
                    ],
                  ),
                  Row(
                    children: [
                      _buildKeypadButton(text: '7'),
                      _buildKeypadButton(text: '8'),
                      _buildKeypadButton(text: '9'),
                      _buildKeypadButton(text: '×', isOperator: true),
                    ],
                  ),
                  Row(
                    children: [
                      _buildKeypadButton(text: '4'),
                      _buildKeypadButton(text: '5'),
                      _buildKeypadButton(text: '6'),
                      _buildKeypadButton(text: '-', isOperator: true),
                    ],
                  ),
                  Row(
                    children: [
                      _buildKeypadButton(text: '1'),
                      _buildKeypadButton(text: '2'),
                      _buildKeypadButton(text: '3'),
                      _buildKeypadButton(text: '+', isOperator: true),
                    ],
                  ),
                  Row(
                    children: [
                      _buildKeypadButton(
                        text: '⇄',
                        isSpecial: true,
                        customChild: Icon(
                          _isScientific ? Icons.unfold_less_rounded : Icons.science_outlined,
                          color: AppColors.primaryOrange,
                          size: 20,
                        ),
                      ),
                      _buildKeypadButton(text: '0'),
                      _buildKeypadButton(text: '.'),
                      _buildKeypadButton(text: '=', isAccent: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
