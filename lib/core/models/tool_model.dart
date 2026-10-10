import 'package:flutter/material.dart';

enum ToolCategory {
  all(
    'All Tools',
    Icons.apps_rounded,
    Color(0xFFEA580C),
    'Explore all features in one place',
  ),
  calculate(
    'Calculate',
    Icons.calculate_outlined,
    Color(0xFF2563EB),
    'Calculator, percentage, average',
  ),
  convert(
    'Convert',
    Icons.swap_horiz_rounded,
    Color(0xFF0891B2),
    'Length, mass, temp, volume',
  ),
  dateTime(
    'Date & Time',
    Icons.schedule_rounded,
    Color(0xFF7C3AED),
    'Age, date difference & duration',
  ),
  finance(
    'Finance',
    Icons.account_balance_wallet_outlined,
    Color(0xFF16A34A),
    'GST, Loan EMI, currency, discount',
  ),
  health(
    'Health',
    Icons.favorite_outline_rounded,
    Color(0xFFE11D48),
    'BMI, calorie needs & ideal weight',
  ),
  education(
    'Education',
    Icons.school_outlined,
    Color(0xFFC026D3),
    'GPA, grade points & percentage',
  ),
  homeTravel(
    'Home & Travel',
    Icons.home_outlined,
    Color(0xFFCA8A04),
    'Electricity bill, trip cost & utilities',
  ),
  filesText(
    'Files & Text',
    Icons.description_outlined,
    Color(0xFFEA580C),
    'PDF toolkit, document scanner, text tools',
  ),
  developer(
    'Developer',
    Icons.code_rounded,
    Color(0xFF4F46E5),
    'JSON formatter, Base64, URL tools',
  ),
  security(
    'Security',
    Icons.shield_outlined,
    Color(0xFF0D9488),
    'Password generator, signature check',
  ),
  kitchen(
    'Kitchen',
    Icons.restaurant_outlined,
    Color(0xFF92400E),
    'Cooking conversions & recipes',
  ),
  moreTools(
    'More Tools',
    Icons.tune_rounded,
    Color(0xFF475569),
    'Sensors, hardware diagnostics',
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
