import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ToolCategory {
  all('All Tools', Icons.apps_rounded, AppColors.primaryOrange),
  calculators('Calculators', Icons.calculate_outlined, AppColors.catMath),
  finance('Finance & Shopping', Icons.account_balance_wallet_outlined, AppColors.catFinance),
  dateAge('Date & Age', Icons.cake_outlined, AppColors.catDate),
  timeDuration('Time & Duration', Icons.schedule_outlined, AppColors.catTime),
  converters('Unit Converters', Icons.straighten_outlined, AppColors.catConverter),
  text('Text Utilities', Icons.text_fields_outlined, AppColors.catText),
  developer('Developer Tools', Icons.code_rounded, AppColors.catDev),
  everyday('Everyday Utilities', Icons.auto_awesome_outlined, AppColors.catEveryday),
  documents('PDF & Documents', Icons.picture_as_pdf_outlined, AppColors.catPdf);

  final String label;
  final IconData icon;
  final Color color;

  const ToolCategory(this.label, this.icon, this.color);
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
