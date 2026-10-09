import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart';

class QuickCalcResult {
  final String expression;
  final String result;
  final String? subtitle;
  final bool isConversion;

  QuickCalcResult({
    required this.expression,
    required this.result,
    this.subtitle,
    this.isConversion = false,
  });
}

class SearchCalculatorService {
  static final NumberFormat _formatter = NumberFormat('#,##0.######');

  static QuickCalcResult? evaluate(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // 1. Percentage shortcut: e.g. "15% of 2500" or "18% of 500"
    final percentRegex = RegExp(r'^(\d+(?:\.\d+)?)\s*(?:%|percent)\s*(?:of)\s*(\d+(?:\.\d+)?)$');
    final pMatch = percentRegex.firstMatch(clean);
    if (pMatch != null) {
      final p = double.tryParse(pMatch.group(1)!) ?? 0;
      final val = double.tryParse(pMatch.group(2)!) ?? 0;
      final res = (p / 100) * val;
      return QuickCalcResult(
        expression: '$p% of ${_formatter.format(val)}',
        result: _formatter.format(res),
        subtitle: 'Remainder: ${_formatter.format(val - res)} (${(100 - p).toStringAsFixed(1)}%)',
      );
    }

    // 2. Unit conversion shortcut: e.g. "5 km to m", "10 kg to g", "50 c to f"
    final convRegex = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-z]+)\s*(?:to|in)\s*([a-z]+)$');
    final cMatch = convRegex.firstMatch(clean);
    if (cMatch != null) {
      final amount = double.tryParse(cMatch.group(1)!) ?? 0;
      final fromUnit = cMatch.group(2)!;
      final toUnit = cMatch.group(3)!;
      final converted = _tryQuickUnitConvert(amount, fromUnit, toUnit);
      if (converted != null) {
        return converted;
      }
    }

    // 3. Mathematical expression: contains math operator like +, -, *, /, x, ^, sqrt, %
    final hasMathChars = RegExp(r'[\d][\s]*[\+\-\*\/\^x÷×%][\s]*[\d]').hasMatch(clean) ||
        clean.startsWith('sqrt(') ||
        clean.contains('sin(') ||
        clean.contains('cos(');

    if (hasMathChars) {
      try {
        String parsed = clean
            .replaceAll('×', '*')
            .replaceAll('x', '*')
            .replaceAll('÷', '/')
            .replaceAll('%', '*0.01');

        final parser = GrammarParser();
        final exp = parser.parse(parsed);
        final cm = ContextModel();
        final eval = exp.evaluate(EvaluationType.REAL, cm);

        if (eval is num && !eval.isNaN && !eval.isInfinite) {
          final resStr = _formatter.format(eval);
          return QuickCalcResult(
            expression: query.trim(),
            result: resStr,
            subtitle: 'Evaluated instantly via math engine',
          );
        }
      } catch (_) {
        // Not a valid math expression, ignore gracefully
      }
    }

    return null;
  }

  static QuickCalcResult? _tryQuickUnitConvert(double val, String from, String to) {
    // Length
    final lengthFactors = {
      'm': 1.0,
      'meter': 1.0,
      'meters': 1.0,
      'km': 1000.0,
      'kilometer': 1000.0,
      'cm': 0.01,
      'centimeter': 0.01,
      'mm': 0.001,
      'millimeter': 0.001,
      'mi': 1609.344,
      'mile': 1609.344,
      'miles': 1609.344,
      'ft': 0.3048,
      'foot': 0.3048,
      'feet': 0.3048,
      'in': 0.0254,
      'inch': 0.0254,
      'inches': 0.0254,
    };

    if (lengthFactors.containsKey(from) && lengthFactors.containsKey(to)) {
      final meters = val * lengthFactors[from]!;
      final res = meters / lengthFactors[to]!;
      return QuickCalcResult(
        expression: '$val $from ➔ $to',
        result: '${_formatter.format(res)} $to',
        isConversion: true,
      );
    }

    // Mass
    final massFactors = {
      'kg': 1.0,
      'kilogram': 1.0,
      'kilograms': 1.0,
      'g': 0.001,
      'gram': 0.001,
      'grams': 0.001,
      'mg': 0.000001,
      'lb': 0.453592,
      'lbs': 0.453592,
      'pound': 0.453592,
      'pounds': 0.453592,
      'oz': 0.0283495,
      'ounce': 0.0283495,
    };

    if (massFactors.containsKey(from) && massFactors.containsKey(to)) {
      final kg = val * massFactors[from]!;
      final res = kg / massFactors[to]!;
      return QuickCalcResult(
        expression: '$val $from ➔ $to',
        result: '${_formatter.format(res)} $to',
        isConversion: true,
      );
    }

    // Data
    final dataFactors = {
      'b': 1.0,
      'byte': 1.0,
      'kb': 1024.0,
      'mb': 1048576.0,
      'gb': 1073741824.0,
      'tb': 1099511627776.0,
    };

    if (dataFactors.containsKey(from) && dataFactors.containsKey(to)) {
      final b = val * dataFactors[from]!;
      final res = b / dataFactors[to]!;
      return QuickCalcResult(
        expression: '$val $from ➔ $to',
        result: '${_formatter.format(res)} $to',
        isConversion: true,
      );
    }

    // Temperature (C to F, F to C)
    if ((from == 'c' || from == 'celsius') && (to == 'f' || to == 'fahrenheit')) {
      final f = (val * 9 / 5) + 32;
      return QuickCalcResult(
        expression: '$val°C ➔ °F',
        result: '${_formatter.format(f)}°F',
        isConversion: true,
      );
    }
    if ((from == 'f' || from == 'fahrenheit') && (to == 'c' || to == 'celsius')) {
      final c = (val - 32) * 5 / 9;
      return QuickCalcResult(
        expression: '$val°F ➔ °C',
        result: '${_formatter.format(c)}°C',
        isConversion: true,
      );
    }

    // Currency (Offline baseline reference e.g. USD, INR, EUR, GBP, JPY)
    final currencyRatesToUsd = {
      'usd': 1.0,
      'inr': 0.01156, // ~86.5 INR per USD
      'eur': 1.08,
      'gbp': 1.28,
      'jpy': 0.0067,
      'cad': 0.73,
      'aud': 0.65,
    };
    if (currencyRatesToUsd.containsKey(from) && currencyRatesToUsd.containsKey(to)) {
      final inUsd = val * currencyRatesToUsd[from]!;
      final res = inUsd / currencyRatesToUsd[to]!;
      return QuickCalcResult(
        expression: '$val ${from.toUpperCase()} ➔ ${to.toUpperCase()}',
        result: '${_formatter.format(res)} ${to.toUpperCase()}',
        subtitle: 'Approximate offline baseline conversion',
        isConversion: true,
      );
    }

    return null;
  }
}
