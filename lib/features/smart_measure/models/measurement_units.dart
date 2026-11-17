/// Unit types supported by Smart Measure.
enum DistanceUnit {
  millimeter('mm', 'Millimeter', 0.001),
  centimeter('cm', 'Centimeter', 0.01),
  meter('m', 'Meter', 1.0),
  kilometer('km', 'Kilometer', 1000.0),
  inch('in', 'Inch', 0.0254),
  foot('ft', 'Foot', 0.3048),
  yard('yd', 'Yard', 0.9144);

  final String symbol;
  final String label;

  /// Multiplier to convert to meters (1 unit = X meters)
  final double toMetersFactor;

  const DistanceUnit(this.symbol, this.label, this.toMetersFactor);

  /// Convert a value from meters to this unit.
  double fromMeters(double meters) => meters / toMetersFactor;

  /// Convert a value in this unit to meters.
  double toMeters(double value) => value * toMetersFactor;

  /// Convert a value from this unit to another unit.
  double convertTo(double value, DistanceUnit targetUnit) {
    final inMeters = toMeters(value);
    return targetUnit.fromMeters(inMeters);
  }

  /// Measure-app style label: precision suited to the unit, so 0.42 m never shows as "0 m".
  String formatMeasurement(double meters) {
    final v = fromMeters(meters).abs();
    final decimals = switch (this) {
      DistanceUnit.millimeter => 0,
      DistanceUnit.centimeter || DistanceUnit.inch => v < 10 ? 1 : 0,
      DistanceUnit.kilometer => 3,
      _ => 2, // m, ft, yd
    };
    return formatMeters(meters, decimals: decimals);
  }

  /// Format a meter value into a readable string with unit symbol.
  String formatMeters(double meters, {int decimals = 2}) {
    final converted = fromMeters(meters);
    if (converted.abs() < 0.0001 && converted != 0) {
      return '< 0.01 $symbol';
    }
    return '${converted.toStringAsFixed(decimals)} $symbol';
  }
}

enum AreaUnit {
  sqMillimeter('mm²', 'Square Millimeter', 0.000001),
  sqCentimeter('cm²', 'Square Centimeter', 0.0001),
  sqMeter('m²', 'Square Meter', 1.0),
  sqFoot('ft²', 'Square Foot', 0.092903),
  sqYard('yd²', 'Square Yard', 0.836127);

  final String symbol;
  final String label;
  final double toSqMetersFactor;

  const AreaUnit(this.symbol, this.label, this.toSqMetersFactor);

  double fromSqMeters(double sqMeters) => sqMeters / toSqMetersFactor;
  double toSqMeters(double value) => value * toSqMetersFactor;

  String formatSqMeters(double sqMeters, {int decimals = 2}) {
    final converted = fromSqMeters(sqMeters);
    return '${converted.toStringAsFixed(decimals)} $symbol';
  }
}

enum AngleUnit {
  degree('°', 'Degrees'),
  radian('rad', 'Radians');

  final String symbol;
  final String label;
  const AngleUnit(this.symbol, this.label);

  String formatDegrees(double degrees, {int decimals = 1}) {
    if (this == degree) {
      return '${degrees.toStringAsFixed(decimals)}°';
    } else {
      final rad = degrees * (3.141592653589793 / 180.0);
      return '${rad.toStringAsFixed(decimals + 1)} rad';
    }
  }
}
