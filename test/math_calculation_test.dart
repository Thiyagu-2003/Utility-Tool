import 'package:flutter_test/flutter_test.dart';
import 'package:utility_tool/core/services/search_calculator_service.dart';
import 'package:utility_tool/core/utils/validation_utils.dart';
import 'package:utility_tool/features/education/academic_toolkit_screen.dart';
import 'package:utility_tool/features/calculator/calculator_screen.dart';

void main() {
  group('SearchCalculatorService Universal Shortcuts Tests', () {
    test('Percentage shortcuts evaluate accurately', () {
      final res1 = SearchCalculatorService.evaluate('15% of 2500');
      expect(res1, isNotNull);
      expect(res1!.result, '375');
      expect(res1.isConversion, isFalse);
      expect(res1.subtitle, contains('Remainder: 2,125'));

      final res2 = SearchCalculatorService.evaluate('20% of 100');
      expect(res2, isNotNull);
      expect(res2!.result, '20');

      final res3 = SearchCalculatorService.evaluate('50 percent of 80');
      expect(res3, isNotNull);
      expect(res3!.result, '40');
    });

    test('Unit conversion shortcuts evaluate accurately', () {
      final resKm = SearchCalculatorService.evaluate('5 km to m');
      expect(resKm, isNotNull);
      expect(resKm!.result, '5,000 m');
      expect(resKm.isConversion, isTrue);

      final resKg = SearchCalculatorService.evaluate('10 kg to g');
      expect(resKg, isNotNull);
      expect(resKg!.result, '10,000 g');

      final resTemp = SearchCalculatorService.evaluate('100 c to f');
      expect(resTemp, isNotNull);
      expect(resTemp!.result, '212°F');

      final resCurrency = SearchCalculatorService.evaluate('100 usd to inr');
      expect(resCurrency, isNotNull);
      expect(resCurrency!.result, contains('INR'));
    });

    test('Math expression shortcuts evaluate accurately', () {
      final resMult = SearchCalculatorService.evaluate('25 * 40');
      expect(resMult, isNotNull);
      expect(resMult!.result, '1,000');

      final resDiv = SearchCalculatorService.evaluate('100 / 4');
      expect(resDiv, isNotNull);
      expect(resDiv!.result, '25');

      final resPow = SearchCalculatorService.evaluate('2 ^ 8');
      expect(resPow, isNotNull);
      expect(resPow!.result, '256');

      final resSqrt = SearchCalculatorService.evaluate('sqrt(144)');
      expect(resSqrt, isNotNull);
      expect(resSqrt!.result, '12');

      final resOrder = SearchCalculatorService.evaluate('50 + 25 * 2');
      expect(resOrder, isNotNull);
      expect(resOrder!.result, '100');
    });

    test('Empty and non-math queries return null', () {
      expect(SearchCalculatorService.evaluate(''), isNull);
      expect(SearchCalculatorService.evaluate('   '), isNull);
      expect(SearchCalculatorService.evaluate('just some random text'), isNull);
    });
  });

  group('ValidationUtils Safety & Input Checks Tests', () {
    test('validateNotEmpty correctly checks input presence', () {
      expect(ValidationUtils.validateNotEmpty('hello').isValid, isTrue);
      expect(ValidationUtils.validateNotEmpty('   ').isValid, isFalse);
      expect(ValidationUtils.validateNotEmpty(null).isValid, isFalse);
    });

    test('validateNumber checks validity and numeric ranges', () {
      final valid = ValidationUtils.validateNumber('123.45');
      expect(valid.isValid, isTrue);
      expect(valid.value, 123.45);

      final withComma = ValidationUtils.validateNumber('1,250.50');
      expect(withComma.isValid, isTrue);
      expect(withComma.value, 1250.50);

      final invalid = ValidationUtils.validateNumber('abc');
      expect(invalid.isValid, isFalse);

      final outOfMin = ValidationUtils.validateNumber('5', min: 10);
      expect(outOfMin.isValid, isFalse);

      final outOfMax = ValidationUtils.validateNumber('150', max: 100);
      expect(outOfMax.isValid, isFalse);

      final negativeDisallowed = ValidationUtils.validateNumber('-10', allowNegative: false);
      expect(negativeDisallowed.isValid, isFalse);

      final zeroDisallowed = ValidationUtils.validateNumber('0', allowZero: false);
      expect(zeroDisallowed.isValid, isFalse);
    });

    test('validatePercentage enforces valid percentage range', () {
      expect(ValidationUtils.validatePercentage('18').isValid, isTrue);
      expect(ValidationUtils.validatePercentage('0').isValid, isTrue);
      expect(ValidationUtils.validatePercentage('100').isValid, isTrue);
      expect(ValidationUtils.validatePercentage('-5').isValid, isFalse);
      expect(ValidationUtils.validatePercentage('150').isValid, isFalse);
    });

    test('validateDivision prevents division by zero without crashing', () {
      final safeDiv = ValidationUtils.validateDivision(100, 4);
      expect(safeDiv.isValid, isTrue);
      expect(safeDiv.value, 25.0);

      final zeroDiv = ValidationUtils.validateDivision(100, 0);
      expect(zeroDiv.isValid, isFalse);
      expect(zeroDiv.errorMessage, contains('Division by zero'));
    });

    test('validateDateRange prevents inverted date selections', () {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 10);
      expect(ValidationUtils.validateDateRange(start, end).isValid, isTrue);
      expect(ValidationUtils.validateDateRange(end, start).isValid, isFalse);
    });

    test('safe parsing helpers return fallback defaults on error', () {
      expect(ValidationUtils.safeParseDouble('42.5'), 42.5);
      expect(ValidationUtils.safeParseDouble('invalid', defaultValue: 10.0), 10.0);
      expect(ValidationUtils.safeParseInt('99'), 99);
      expect(ValidationUtils.safeParseInt('not an int', defaultValue: 5), 5);
    });
  });

  group('Academic toolkit helpers', () {
    test('attendance plan uses exact percent maths', () {
      // 42/60 = 70% exactly meets 70%: nothing can be skipped.
      expect(attendancePlan(42, 60, 70), (canSkip: 0, mustAttend: null));
      // 48/60 = 80%: can still skip floor(4800/75) - 60 = 4 classes at 75%.
      expect(attendancePlan(48, 60, 75).canSkip, 4);
      // 42/60 needs (75*60-4200)/25 = 12 straight classes to reach 75%.
      expect(attendancePlan(42, 60, 75).mustAttend, 12);
      // 100% required after a miss can never be reached.
      expect(attendancePlan(59, 60, 100), (canSkip: null, mustAttend: null));
    });

    test('primes in a range', () {
      expect(primesInRange(1, 30), [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]);
      expect(primesInRange(30, 20), [23, 29]);
      expect(primesInRange(-5, 3), [2, 3]);
      expect(isPrimeInt(1000000007), isTrue);
      expect(isPrimeInt(1), isFalse);
    });

    test('matrix helpers', () {
      expect(matMul([1, 2, 3, 4], [5, 6, 7, 8], 2), [19, 22, 43, 50]);
      expect(matAdd([1, 2], [3, 4]), [4, 6]);
      expect(matSub([1, 2], [3, 4]), [-2, -2]);
      expect(matToString([1, 2.5, 0.125, -0.0], 2), '[1, 2.5]\n[0.125, 0]');
      final id = matMul([1, 0, 0, 0, 1, 0, 0, 0, 1], [2, 3, 4, 5, 6, 7, 8, 9, 10], 3);
      expect(id, [2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('fmtNum trims zeros and never prints -0', () {
      expect(fmtNum(2.0), '2');
      expect(fmtNum(-0.00001), '0');
      expect(fmtNum(1.23456789), '1.2346');
    });

    test('degree mode is honoured by the shared evaluator', () {
      expect(evaluateCalculatorExpression('sin(30)', degrees: true), closeTo(0.5, 1e-12));
      expect(evaluateCalculatorExpression('sin(30)').abs(), isNot(closeTo(0.5, 1e-3)));
    });
  });
}
