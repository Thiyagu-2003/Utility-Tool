/// Comprehensive utility class for input validation, mathematical safety checks,
/// and error reporting across all calculation, finance, and conversion tools.
class ValidationResult<T> {
  final bool isValid;
  final String? errorMessage;
  final T? value;

  const ValidationResult.success(this.value)
      : isValid = true,
        errorMessage = null;

  const ValidationResult.failure(this.errorMessage)
      : isValid = false,
        value = null;

  bool get isFailure => !isValid;
}

class ValidationUtils {
  /// Validates that a string is non-null and not blank.
  static ValidationResult<String> validateNotEmpty(
    String? input, {
    String fieldName = 'Field',
  }) {
    if (input == null || input.trim().isEmpty) {
      return ValidationResult.failure('$fieldName cannot be empty');
    }
    return ValidationResult.success(input.trim());
  }

  /// Validates that an input is a valid double number, within optional range bounds.
  static ValidationResult<double> validateNumber(
    String? input, {
    String fieldName = 'Value',
    double? min,
    double? max,
    bool allowNegative = true,
    bool allowZero = true,
  }) {
    if (input == null || input.trim().isEmpty) {
      return ValidationResult.failure('$fieldName is required');
    }

    final sanitized = input.trim().replaceAll(',', '');
    final parsed = double.tryParse(sanitized);

    if (parsed == null) {
      return ValidationResult.failure('Please enter a valid numeric value for $fieldName');
    }

    if (!allowNegative && parsed < 0) {
      return ValidationResult.failure('$fieldName cannot be negative');
    }

    if (!allowZero && parsed == 0) {
      return ValidationResult.failure('$fieldName cannot be zero');
    }

    if (min != null && parsed < min) {
      return ValidationResult.failure('$fieldName must be at least $min');
    }

    if (max != null && parsed > max) {
      return ValidationResult.failure('$fieldName cannot exceed $max');
    }

    return ValidationResult.success(parsed);
  }

  /// Validates an input as a percentage between 0% and 100% (or custom max).
  static ValidationResult<double> validatePercentage(
    String? input, {
    String fieldName = 'Percentage',
    double max = 100.0,
  }) {
    return validateNumber(
      input,
      fieldName: fieldName,
      min: 0,
      max: max,
      allowNegative: false,
      allowZero: true,
    );
  }

  /// Validates an integer within optional range bounds.
  static ValidationResult<int> validateInteger(
    String? input, {
    String fieldName = 'Value',
    int? min,
    int? max,
    bool allowNegative = false,
  }) {
    if (input == null || input.trim().isEmpty) {
      return ValidationResult.failure('$fieldName is required');
    }

    final sanitized = input.trim().replaceAll(',', '');
    final parsed = int.tryParse(sanitized);

    if (parsed == null) {
      return ValidationResult.failure('Please enter a whole number for $fieldName');
    }

    if (!allowNegative && parsed < 0) {
      return ValidationResult.failure('$fieldName cannot be negative');
    }

    if (min != null && parsed < min) {
      return ValidationResult.failure('$fieldName must be at least $min');
    }

    if (max != null && parsed > max) {
      return ValidationResult.failure('$fieldName cannot exceed $max');
    }

    return ValidationResult.success(parsed);
  }

  /// Mathematical safety check: Prevents division by zero or near-zero epsilon.
  static ValidationResult<double> validateDivision(
    double numerator,
    double denominator, {
    String errorMessage = 'Division by zero is undefined',
    double epsilon = 1e-12,
  }) {
    if (denominator.abs() <= epsilon) {
      return ValidationResult.failure(errorMessage);
    }
    return ValidationResult.success(numerator / denominator);
  }

  /// Validates date sequence (start date before or equal to end date).
  static ValidationResult<Duration> validateDateRange(
    DateTime startDate,
    DateTime endDate, {
    String errorMessage = 'End date must be on or after start date',
  }) {
    if (endDate.isBefore(startDate)) {
      return ValidationResult.failure(errorMessage);
    }
    return ValidationResult.success(endDate.difference(startDate));
  }

  /// Safe double parsing without throwing exceptions.
  static double safeParseDouble(String? input, {double defaultValue = 0.0}) {
    if (input == null || input.trim().isEmpty) return defaultValue;
    final sanitized = input.trim().replaceAll(',', '');
    return double.tryParse(sanitized) ?? defaultValue;
  }

  /// Safe integer parsing without throwing exceptions.
  static int safeParseInt(String? input, {int defaultValue = 0}) {
    if (input == null || input.trim().isEmpty) return defaultValue;
    final sanitized = input.trim().replaceAll(',', '');
    return int.tryParse(sanitized) ?? defaultValue;
  }
}
