import 'package:flutter/material.dart';

enum ToolCategory {
  all(
    'All Tools',
    Icons.apps_rounded,
    Color(0xFFEA580C),
    'Explore all features in one place',
  ),
  calculate(
    'Percentage Calculation',
    Icons.percent_rounded,
    Color(0xFF2563EB),
    'Percent of, ratio & percentage change',
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
  pdfDocuments(
    'PDF & Documents',
    Icons.picture_as_pdf_outlined,
    Color(0xFFDC2626),
    'PDF toolkit, office files & document scanner',
  ),
  imagePhoto(
    'Image & Photo',
    Icons.photo_library_outlined,
    Color(0xFFDB2777),
    'Resize, compress, edit & collage images',
  ),
  compression(
    'Compression & Archives',
    Icons.folder_zip_outlined,
    Color(0xFF65A30D),
    'ZIP, TAR, GZIP, 7z, compare & preview',
  ),
  textTools(
    'Text & Writing',
    Icons.text_fields_rounded,
    Color(0xFF0369A1),
    'Text analyzer, diff, markdown & OCR',
  ),
  media(
    'Audio & Video',
    Icons.perm_media_outlined,
    Color(0xFF9333EA),
    'Audio & video conversion and editing',
  ),
  qrBarcode(
    'QR & Barcode',
    Icons.qr_code_2_rounded,
    Color(0xFF334155),
    'Scan, generate & share contacts via QR',
  ),
  developer(
    'Developer',
    Icons.code_rounded,
    Color(0xFF4F46E5),
    'JSON, XML, YAML, Base64, URL tools',
  ),
  deviceTests(
    'Device & Hardware',
    Icons.phone_android_rounded,
    Color(0xFF57534E),
    'Sensors, screen, battery, mic & speaker tests',
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
    'Slate, randomizer & everyday extras',
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
  static const ToolCategory text = textTools;
  static const ToolCategory documents = pdfDocuments;
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
