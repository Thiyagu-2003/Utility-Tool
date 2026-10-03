import 'package:flutter/material.dart';

enum ToolCategory {
  all(
    'All Tools',
    Icons.apps_rounded,
    Color(0xFFFF6D00),
    'Explore all features in one place',
  ),
  calculate(
    'Calculate',
    Icons.calculate_outlined,
    Color(0xFF3B82F6),
    'Calculator, percentage, average & math',
  ),
  convert(
    'Convert',
    Icons.sync_alt_rounded,
    Color(0xFF06B6D4),
    'Length, mass, temp, volume & speed',
  ),
  dateTime(
    'Date & Time',
    Icons.schedule_rounded,
    Color(0xFF6366F1),
    'Age, date difference & duration breakdown',
  ),
  finance(
    'Finance',
    Icons.account_balance_wallet_outlined,
    Color(0xFF10B981),
    'GST, Loan EMI, currency, discount & interest',
  ),
  health(
    'Health',
    Icons.favorite_outline_rounded,
    Color(0xFFEF4444),
    'BMI, calorie needs & ideal weight',
  ),
  education(
    'Education',
    Icons.school_outlined,
    Color(0xFF8B5CF6),
    'GPA, grade points & percentage calculator',
  ),
  homeTravel(
    'Home & Travel',
    Icons.home_outlined,
    Color(0xFFF59E0B),
    'Electricity bill, trip cost & utilities',
  ),
  filesText(
    'Files & Text',
    Icons.description_outlined,
    Color(0xFFE11D48),
    'PDF toolkit, document scanner & text tools',
  ),
  developer(
    'Developer',
    Icons.code_rounded,
    Color(0xFFEC4899),
    'JSON formatter, Base64, UUID & color codes',
  ),
  security(
    'Security',
    Icons.shield_outlined,
    Color(0xFF14B8A6),
    'Password generator, signature pad & hashes',
  ),
  kitchen(
    'Kitchen',
    Icons.restaurant_outlined,
    Color(0xFFF97316),
    'Cooking conversions & recipe portion scaler',
  ),
  moreTools(
    'More Tools',
    Icons.tune_rounded,
    Color(0xFF64748B),
    'Randomizer, dice roller & coin toss',
  );

  final String label;
  final IconData icon;
  final Color color;
  final String description;

  const ToolCategory(this.label, this.icon, this.color, this.description);

  // Backward-compatible category aliases
  static const ToolCategory calculators = calculate;
  static const ToolCategory converters = convert;
  static const ToolCategory dateAge = dateTime;
  static const ToolCategory timeDuration = dateTime;
  static const ToolCategory text = filesText;
  static const ToolCategory documents = filesText;
  static const ToolCategory everyday = moreTools;
}

class ToolItem {
  final String id;
  final String title;
  final String description;
  final ToolCategory category;
  final IconData icon;
  final Color? customColor;
  final List<String> keywords;
  final WidgetBuilder builder;

  const ToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    this.customColor,
    required this.keywords,
    required this.builder,
  });

  Color get color => customColor ?? category.color;
}
