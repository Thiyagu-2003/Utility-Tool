import 'package:flutter/material.dart';
import '../models/tool_model.dart';
import '../../features/date_time/age_calculator_screen.dart';
import '../../features/date_time/date_difference_screen.dart';
import '../../features/date_time/duration_converter_screen.dart';
import '../../features/converters/unit_converter_screen.dart';
import '../../features/finance/gst_calculator_screen.dart';
import '../../features/finance/loan_emi_calculator_screen.dart';
import '../../features/finance/discount_calculator_screen.dart';
import '../../features/finance/currency_converter_screen.dart';
import '../../features/finance/interest_calculator_screen.dart';
import '../../features/finance/tip_split_screen.dart';
import '../../features/math/percentage_calculator_screen.dart';
import '../../features/text_tools/text_analyzer_screen.dart';
import '../../features/dev_tools/dev_tools_screen.dart';
import '../../features/everyday/random_utilities_screen.dart';
import '../../features/finance/electricity_bill_screen.dart';
import '../../features/documents/pdf_toolkit_screen.dart';
import '../../features/documents/document_scanner_screen.dart';
import '../../features/health/health_calculator_screen.dart';
import '../../features/security/password_generator_screen.dart';
import '../../features/kitchen/kitchen_converter_screen.dart';
import '../../features/education/gpa_calculator_screen.dart';

class ToolRegistry {
  static final List<ToolItem> allTools = [
    // 1. Calculate
    ToolItem(
      id: 'percentage_calc',
      title: 'Percentage Calculator',
      description: 'Find percentages, ratios & percentage change',
      category: ToolCategory.calculate,
      icon: Icons.percent_rounded,
      keywords: ['percentage', 'ratio', 'fraction', 'discount', 'increase', 'decrease', 'calculate'],
      builder: (_) => const PercentageCalculatorScreen(),
    ),

    // 2. Convert
    ToolItem(
      id: 'unit_converter',
      title: 'Unit Converter',
      description: 'Length, Mass, Temperature, Area, Volume, Speed, Data',
      category: ToolCategory.convert,
      icon: Icons.sync_alt_rounded,
      keywords: ['unit', 'converter', 'length', 'mass', 'weight', 'temperature', 'area', 'volume', 'speed', 'data'],
      builder: (_) => const UnitConverterScreen(),
    ),

    // 3. Date & Time
    ToolItem(
      id: 'age_calc',
      title: 'Age',
      description: 'Exact years, months, days & next birthday countdown',
      category: ToolCategory.dateTime,
      icon: Icons.cake_rounded,
      keywords: ['age', 'birthday', 'birthdate', 'years', 'months', 'days', 'born', 'date'],
      builder: (_) => const AgeCalculatorScreen(),
    ),
    ToolItem(
      id: 'date_diff',
      title: 'Date Difference',
      description: 'Calendar days & business working days between dates',
      category: ToolCategory.dateTime,
      icon: Icons.date_range_rounded,
      keywords: ['date', 'difference', 'days', 'weeks', 'working days', 'business days', 'calendar'],
      builder: (_) => const DateDifferenceScreen(),
    ),
    ToolItem(
      id: 'duration_converter',
      title: 'Duration Converter',
      description: 'Hours to days, minutes & seconds breakdown',
      category: ToolCategory.dateTime,
      icon: Icons.hourglass_bottom_rounded,
      keywords: ['duration', 'hours', 'days', 'minutes', 'seconds', 'converter', 'time'],
      builder: (_) => const DurationConverterScreen(),
    ),

    // 4. Finance
    ToolItem(
      id: 'gst_calc',
      title: 'GST Calculator',
      description: 'Exclusive & Inclusive GST with CGST and SGST',
      category: ToolCategory.finance,
      icon: Icons.receipt_long_rounded,
      keywords: ['gst', 'tax', 'vat', 'inclusive', 'exclusive', 'invoice', 'cgst', 'sgst'],
      builder: (_) => const GstCalculatorScreen(),
    ),
    ToolItem(
      id: 'loan_emi_calc',
      title: 'Loan EMI Calculator',
      description: 'Monthly EMI, interest breakdown & amortization schedule',
      category: ToolCategory.finance,
      icon: Icons.account_balance_rounded,
      keywords: ['loan', 'emi', 'mortgage', 'interest', 'bank', 'tenure', 'finance'],
      builder: (_) => const LoanEmiCalculatorScreen(),
    ),
    ToolItem(
      id: 'discount_calc',
      title: 'Discount Calculator',
      description: 'Final price, multi-tier promo codes & savings',
      category: ToolCategory.finance,
      icon: Icons.local_offer_rounded,
      keywords: ['discount', 'shopping', 'sale', 'save', 'offer', 'price'],
      builder: (_) => const DiscountCalculatorScreen(),
    ),
    ToolItem(
      id: 'currency_converter',
      title: 'Currency Converter',
      description: 'Live & offline rates: USD, INR, EUR, GBP, AED, JPY',
      category: ToolCategory.finance,
      icon: Icons.currency_exchange_rounded,
      keywords: ['currency', 'exchange', 'forex', 'usd', 'inr', 'eur', 'gbp', 'aed', 'money'],
      builder: (_) => const CurrencyConverterScreen(),
    ),
    ToolItem(
      id: 'interest_calc',
      title: 'Interest Calculator',
      description: 'Simple & compound interest with compounding frequencies',
      category: ToolCategory.finance,
      icon: Icons.trending_up_rounded,
      keywords: ['interest', 'compound', 'simple', 'investment', 'fd', 'rd', 'growth', 'roi'],
      builder: (_) => const InterestCalculatorScreen(),
    ),
    ToolItem(
      id: 'tip_split_calc',
      title: 'Tip & Split Bill',
      description: 'Calculate restaurant tips & split bills among people',
      category: ToolCategory.finance,
      icon: Icons.group_rounded,
      keywords: ['tip', 'split', 'bill', 'restaurant', 'dinner', 'people', 'food'],
      builder: (_) => const TipSplitScreen(),
    ),

    // 5. Health
    ToolItem(
      id: 'health_calc',
      title: 'Health & Fitness Calculator',
      description: 'BMI, BMR, ideal body weight & daily calorie requirements',
      category: ToolCategory.health,
      icon: Icons.favorite_outline_rounded,
      keywords: ['bmi', 'bmr', 'calories', 'health', 'fitness', 'weight', 'height', 'diet'],
      builder: (_) => const HealthCalculatorScreen(),
    ),

    // 6. Education
    ToolItem(
      id: 'gpa_calc',
      title: 'GPA & CGPA Calculator',
      description: 'Course grade points, weighted credits & percentage scale',
      category: ToolCategory.education,
      icon: Icons.school_outlined,
      keywords: ['gpa', 'cgpa', 'grade', 'education', 'school', 'college', 'exam', 'marks', 'percentage'],
      builder: (_) => const GpaCalculatorScreen(),
    ),

    // 7. Home & Travel
    ToolItem(
      id: 'electricity_bill',
      title: 'Electricity Bill',
      description: 'Estimate monthly power cost by units or home appliances',
      category: ToolCategory.homeTravel,
      icon: Icons.bolt_rounded,
      keywords: ['electricity', 'bill', 'power', 'kwh', 'units', 'energy', 'appliances', 'watt', 'current', 'home', 'travel'],
      builder: (_) => const ElectricityBillScreen(),
    ),

    // 8. Files & Text
    ToolItem(
      id: 'pdf_toolkit',
      title: 'PDF Toolkit',
      description: 'Images to PDF, Text to PDF, Watermark & Page numbers',
      category: ToolCategory.filesText,
      icon: Icons.picture_as_pdf_rounded,
      keywords: ['pdf', 'images to pdf', 'convert', 'merge', 'split', 'watermark', 'pages', 'document', 'text to pdf'],
      builder: (_) => const PdfToolkitScreen(),
    ),
    ToolItem(
      id: 'document_scanner',
      title: 'Document Scanner',
      description: 'Camera document scans, B&W filters, ID card & Signature pad',
      category: ToolCategory.filesText,
      icon: Icons.document_scanner_rounded,
      keywords: ['scanner', 'scan', 'document', 'id card', 'signature', 'filter', 'grayscale', 'receipt'],
      builder: (_) => const DocumentScannerScreen(),
    ),
    ToolItem(
      id: 'text_analyzer',
      title: 'Text & Words Analyzer',
      description: 'Word count, character count & case transformation tools',
      category: ToolCategory.filesText,
      icon: Icons.text_fields_rounded,
      keywords: ['text', 'words', 'characters', 'uppercase', 'lowercase', 'titlecase', 'slug'],
      builder: (_) => const TextAnalyzerScreen(),
    ),

    // 9. Developer
    ToolItem(
      id: 'dev_tools',
      title: 'Developer Suite',
      description: 'JSON Formatter, Base64, UUID, Color codes & URL Encoder',
      category: ToolCategory.developer,
      icon: Icons.code_rounded,
      keywords: ['json', 'formatter', 'validator', 'base64', 'url', 'uuid', 'color', 'hex', 'rgb', 'developer'],
      builder: (_) => const DevToolsScreen(),
    ),

    // 10. Security
    ToolItem(
      id: 'password_generator',
      title: 'Password & Security Generator',
      description: 'High-entropy passwords, symbol toggles & strength audit',
      category: ToolCategory.security,
      icon: Icons.shield_outlined,
      keywords: ['password', 'generator', 'security', 'hash', 'entropy', 'pin', 'strong password'],
      builder: (_) => const PasswordGeneratorScreen(),
    ),

    // 11. Kitchen
    ToolItem(
      id: 'kitchen_calc',
      title: 'Kitchen & Recipe Tools',
      description: 'Cooking volume conversions & dynamic recipe yield scaler',
      category: ToolCategory.kitchen,
      icon: Icons.restaurant_outlined,
      keywords: ['kitchen', 'cooking', 'recipe', 'cup', 'tablespoon', 'teaspoon', 'flour', 'servings'],
      builder: (_) => const KitchenConverterScreen(),
    ),

    // 12. More Tools
    ToolItem(
      id: 'random_utilities',
      title: 'Randomizer & Dice Roll',
      description: 'Random numbers, 6-sided dice roller & fair coin toss',
      category: ToolCategory.moreTools,
      icon: Icons.tune_rounded,
      keywords: ['random', 'dice', 'coin', 'flip', 'toss', 'roll', 'decision', 'utilities'],
      builder: (_) => const RandomUtilitiesScreen(),
    ),
  ];

  static ToolItem? findById(String id) {
    try {
      return allTools.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<ToolItem> getByCategory(ToolCategory category) {
    if (category == ToolCategory.all) return allTools;
    return allTools.where((t) => t.category == category).toList();
  }

  static List<ToolItem> searchTools(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return allTools;

    return allTools.where((t) {
      if (t.title.toLowerCase().contains(clean)) return true;
      if (t.description.toLowerCase().contains(clean)) return true;
      if (t.keywords.any((k) => k.toLowerCase().contains(clean))) return true;
      return false;
    }).toList();
  }
}
