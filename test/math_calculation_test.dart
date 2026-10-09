import 'package:flutter_test/flutter_test.dart';
import 'package:utility_tool/core/services/search_calculator_service.dart';
import 'package:utility_tool/core/utils/validation_utils.dart';

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
}
