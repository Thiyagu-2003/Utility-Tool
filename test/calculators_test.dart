import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:utility_tool/features/calculator/calculator_screen.dart';
import 'package:utility_tool/features/date_time/age_calculator_screen.dart';
import 'package:utility_tool/features/everyday/random_utilities_screen.dart';
import 'package:utility_tool/features/converters/unit_converter_screen.dart';
import 'package:utility_tool/features/finance/loan_emi_calculator_screen.dart';
import 'package:utility_tool/features/health/health_calculator_screen.dart';
import 'package:utility_tool/features/kitchen/kitchen_converter_screen.dart';
import 'package:utility_tool/features/education/gpa_calculator_screen.dart';
import 'package:utility_tool/features/home/home_travel_toolkit_screen.dart';

void main() {
  group('evaluateCalculatorExpression', () {
    double eval(String e, {bool deg = false}) => evaluateCalculatorExpression(e, degrees: deg);

    test('operator precedence and display symbols', () {
      expect(eval('2+3×4'), 14);
      expect(eval('10÷4'), 2.5);
      expect(eval('2^3^2'), 512);
    });

    test('grouped results from a previous answer still parse', () {
      expect(eval('1,234+1'), 1235);
    });

    test('percent', () {
      expect(eval('50%'), closeTo(0.5, 1e-12));
      expect(eval('200×10%'), closeTo(20, 1e-9));
    });

    test('constants and implicit multiplication', () {
      expect(eval('2π'), closeTo(2 * math.pi, 1e-12));
      expect(eval('2(3+1)'), 8);
      expect(eval('e'), closeTo(math.e, 1e-12));
      expect(eval('2sqrt(9)'), 6);
    });

    test('degree and radian trig', () {
      expect(eval('sin(30)', deg: true), closeTo(0.5, 1e-12));
      expect(eval('cos(180)', deg: true), closeTo(-1, 1e-12));
      expect(eval('sin(180)', deg: true), 0);
      expect(eval('sin(π/2)'), closeTo(1, 1e-12));
      expect(eval('tan(90)', deg: true).isNaN, isTrue);
    });

    test('lg is base 10, ln is natural', () {
      expect(eval('lg(1000)'), closeTo(3, 1e-12));
      expect(eval('ln(e)'), closeTo(1, 1e-12));
    });

    test('unclosed brackets are auto-closed', () {
      expect(eval('sqrt(16'), 4);
      expect(eval('2×(3+4'), 14);
    });

    test('factorial only for non-negative integers', () {
      expect(eval('5!'), 120);
      expect(eval('0!'), 1);
      expect(eval('2.5!').isNaN, isTrue);
      expect(eval('(0-3)!').isNaN, isTrue);
      expect(eval('171!').isInfinite, isTrue);
    });

    test('1/x of zero is not finite', () {
      expect(eval('1/(0)').isFinite, isFalse);
    });

    test('malformed input throws instead of returning a value', () {
      expect(() => eval('5+×'), throwsA(anything));
    });
  });

  group('calculateAgeParts', () {
    test('month-end birthday never yields negative days', () {
      final r = calculateAgeParts(DateTime(2023, 1, 31), DateTime(2023, 3, 1));
      expect((r.years, r.months, r.days), (0, 1, 1));
    });

    test('plain borrow across months', () {
      final r = calculateAgeParts(DateTime(2000, 5, 20), DateTime(2024, 3, 10));
      expect((r.years, r.months, r.days), (23, 9, 19));
    });

    test('leap-day birth and exact birthday', () {
      final leap = calculateAgeParts(DateTime(2000, 2, 29), DateTime(2004, 2, 29));
      expect((leap.years, leap.months, leap.days), (4, 0, 0));
      final same = calculateAgeParts(DateTime(1990, 7, 4), DateTime(2020, 7, 4, 18, 30));
      expect((same.years, same.months, same.days), (30, 0, 0));
    });
  });

  group('randomIntInRange', () {
    test('handles reversed, equal and wider-than-2^32 ranges', () {
      final rng = math.Random(1);
      for (var i = 0; i < 200; i++) {
        final v = randomIntInRange(rng, 10, 1);
        expect(v, inInclusiveRange(1, 10));
      }
      expect(randomIntInRange(rng, 7, 7), 7);
      final big = randomIntInRange(rng, 0, 10000000000);
      expect(big, inInclusiveRange(0, 10000000000));
    });
  });

  group('calculator signed exponents', () {
    test('2^-1 and 2^+3 parse', () {
      expect(evaluateCalculatorExpression('2^-1'), 0.5);
      expect(evaluateCalculatorExpression('2^+3'), 8);
      expect(evaluateCalculatorExpression('2^-(1+1)'), 0.25);
      expect(evaluateCalculatorExpression('4^-sqrt(4)'), closeTo(0.0625, 1e-12));
      expect(evaluateCalculatorExpression('2^-1+1'), 1.5);
    });
  });

  group('formatUnitValue', () {
    test('plain, tiny, huge and non-finite values', () {
      expect(formatUnitValue(1234.5), '1,234.5');
      expect(formatUnitValue(0), '0');
      expect(formatUnitValue(8.88e-16), '8.88e-16');
      expect(formatUnitValue(1.125899906842624e15), '1.1259e15');
      expect(formatUnitValue(double.infinity), '∞');
      expect(formatUnitValue(double.nan), 'NaN');
    });
  });

  group('amortization schedule', () {
    test('principal paid sums to the loan and the balance ends at zero', () {
      final years = amortizationByYear(principal: 1000000, annualRate: 8.5, months: 180);
      expect(years.length, 15);
      expect(years.fold<double>(0, (s, y) => s + y.principalPaid), closeTo(1000000, 0.5));
      expect(years.last.balance, 0);
      expect(years.first.interestPaid, greaterThan(years.last.interestPaid));
    });

    test('partial last year and zero-interest loans', () {
      final y = amortizationByYear(principal: 1200, annualRate: 0, months: 18);
      expect(y.length, 2);
      expect(y.first.principalPaid, closeTo(800, 1e-9));
      expect(y.last.principalPaid, closeTo(400, 1e-9));
      expect(amortizationByYear(principal: 0, annualRate: 5, months: 12), isEmpty);
    });
  });

  group('ideal body weight formulas', () {
    test('5 ft is the base weight and each extra inch adds the increment', () {
      final m = idealWeightFormulas(152.4, male: true);
      expect(m.devine, closeTo(50, 1e-9));
      expect(m.robinson, closeTo(52, 1e-9));
      expect(m.miller, closeTo(56.2, 1e-9));
      expect(m.hamwi, closeTo(48, 1e-9));
      final f = idealWeightFormulas(152.4 + 2.54 * 10, male: false); // 5 ft 10 in
      expect(f.devine, closeTo(45.5 + 23, 1e-9));
      expect(f.hamwi, closeTo(45.5 + 22, 1e-9));
    });

    test('never negative for very short heights', () {
      expect(idealWeightFormulas(30, male: false).devine, 0);
    });
  });

  group('kitchen and land maths', () {
    test('cup to tbsp is 16 and ml is exact', () {
      expect(convertKitchenVolume(1, 'cup', 'tbsp'), closeTo(16, 0.01));
      expect(convertKitchenVolume(1, 'liter', 'ml'), 1000);
    });

    test('blank or non-positive servings mean no scaling', () {
      expect(recipeScaleFactor(2, 4), 2);
      expect(recipeScaleFactor(2, null), 1);
      expect(recipeScaleFactor(0, 4), 1);
      expect(recipeScaleFactor(2, 0), 1);
    });

    test('regional bigha values convert via square feet', () {
      expect(landToSqFt(1, 'Bigha: West Bengal / Assam (14,400)'), 14400);
      expect(landToSqFt(1, 'Bigha: UP east / Bihar / Rajasthan pucca (27,225)'), 27225);
      expect(landToSqFt(1, 'Bigha (varies by state, 27,000)'), 27000);
      expect(landToSqFt(1, 'Acres'), 43560);
    });
  });

  group('GPA', () {
    test('credit-weighted average on the 10-point scale', () {
      final c = [
        CourseRecord(name: 'a', credits: 4, grade: 'A'),
        CourseRecord(name: 'b', credits: 2, grade: 'O'),
      ];
      expect(calculateGpa(c), closeTo((4 * 8 + 2 * 10) / 6, 1e-12));
      expect(calculateGpa([]), 0);
    });
  });
}
