import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';

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
      } else if (value == '√') {
        _expression += 'sqrt(';
        _calculatePreview();
      } else if (value == 'π') {
        _expression += '3.14159265';
        _calculatePreview();
      } else if (value == 'e') {
        _expression += '2.71828182';
        _calculatePreview();
      } else if (value == 'x^y') {
        _expression += '^';
      } else if (['sin', 'cos', 'tan', 'ln', 'lg'].contains(value)) {
        if (value == 'lg') {
          _expression += 'log(';
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
      String parsedExp = _expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('%', '*0.01');

      // Handle deg/rad for trig
      if (_isDegreeMode) {
        // approximate degree parsing or direct math evaluation
      }

      Parser p = Parser();
      Expression exp = p.parse(parsedExp);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

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
      String parsedExp = _expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('%', '*0.01');

      Parser p = Parser();
      Expression exp = p.parse(parsedExp);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Calculation History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.darkTextMuted.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text('No recent calculations'),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = history[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            title: Text(
                              item.expression,
                              style: const TextStyle(fontSize: 14, color: AppColors.darkTextSecondary),
                            ),
                            subtitle: Text(
                              item.result,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                            ),
                            trailing: Text(
                              DateFormat('HH:mm').format(item.timestamp),
                              style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
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
    bool isSpecial = false,
    VoidCallback? onTap,
    Widget? customChild,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color resolvedBg = bgColor ?? (isDark ? AppColors.darkSurface : AppColors.lightCardHover);
    if (isAccent) {
      resolvedBg = AppColors.primaryOrange;
    }

    Color resolvedText = textColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    if (isAccent) {
      resolvedText = Colors.white;
    } else if (isSpecial) {
      resolvedText = AppColors.primaryOrange;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: resolvedBg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap ?? () => _onButtonPressed(text),
            child: Container(
              height: _isScientific ? 52 : 64,
              alignment: Alignment.center,
              child: customChild ??
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: _isScientific ? 18 : 24,
                      fontWeight: isAccent || isSpecial ? FontWeight.bold : FontWeight.w600,
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

    return Column(
      children: [
        // Top Toolbar (History, Mode Indicator)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'History',
                icon: const Icon(Icons.history_rounded, size: 24),
                onPressed: _showHistoryModal,
              ),
              if (_isScientific)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
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
              IconButton(
                tooltip: _isScientific ? 'Switch to Basic' : 'Switch to Scientific',
                icon: Icon(
                  _isScientific ? Icons.calculate_rounded : Icons.science_outlined,
                  color: AppColors.primaryOrange,
                  size: 24,
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

        // Display Area (Spacious & Modern)
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            alignment: Alignment.bottomRight,
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    _expression.isEmpty ? '0' : _expression,
                    style: TextStyle(
                      fontSize: _expression.length > 12 ? 32 : 46,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  if (_previewResult.isNotEmpty && _previewResult != '0')
                    Text(
                      _previewResult,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryOrange.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.right,
                    ),
                ],
              ),
            ),
          ),
        ),

        const Divider(height: 1),

        // Keypad Section
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                if (_isScientific) ...[
                  Row(
                    children: [
                      _buildKeypadButton(text: _isDegreeMode ? 'deg' : 'rad', isSpecial: true),
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

                // Main Keypad Rows
                Row(
                  children: [
                    _buildKeypadButton(text: 'AC', isSpecial: true),
                    _buildKeypadButton(
                      text: '⌫',
                      isSpecial: true,
                      customChild: const Icon(Icons.backspace_outlined, size: 22, color: AppColors.primaryOrange),
                    ),
                    if (!_isScientific) _buildKeypadButton(text: '%', isSpecial: true),
                    _buildKeypadButton(text: '÷', isSpecial: true),
                  ],
                ),
                Row(
                  children: [
                    _buildKeypadButton(text: '7'),
                    _buildKeypadButton(text: '8'),
                    _buildKeypadButton(text: '9'),
                    _buildKeypadButton(text: '×', isSpecial: true),
                  ],
                ),
                Row(
                  children: [
                    _buildKeypadButton(text: '4'),
                    _buildKeypadButton(text: '5'),
                    _buildKeypadButton(text: '6'),
                    _buildKeypadButton(text: '-', isSpecial: true),
                  ],
                ),
                Row(
                  children: [
                    _buildKeypadButton(text: '1'),
                    _buildKeypadButton(text: '2'),
                    _buildKeypadButton(text: '3'),
                    _buildKeypadButton(text: '+', isSpecial: true),
                  ],
                ),
                Row(
                  children: [
                    _buildKeypadButton(
                      text: '⇄',
                      isSpecial: true,
                      customChild: Icon(
                        _isScientific ? Icons.unfold_less_rounded : Icons.tune_rounded,
                        color: AppColors.primaryOrange,
                        size: 22,
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
        ),
      ],
    );
  }
}
