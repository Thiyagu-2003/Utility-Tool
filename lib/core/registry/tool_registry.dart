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

class ToolRegistry {
  static final List<ToolItem> allTools = [
    // Calculators
    ToolItem(
      id: 'percentage_calc',
      title: 'Percentage',
      description: 'Find percentages, ratios & % change',
      category: ToolCategory.calculators,
      icon: Icons.percent_rounded,
      keywords: ['percentage', 'ratio', 'fraction', 'discount', 'increase', 'decrease'],
      builder: (_) => const PercentageCalculatorScreen(),
    ),

    // Finance & Shopping
    ToolItem(
      id: 'electricity_bill',
      title: 'Electricity Bill',
      description: 'Estimate power costs by units or appliances',
      category: ToolCategory.finance,
      icon: Icons.bolt_rounded,
      keywords: ['electricity', 'bill', 'power', 'kwh', 'units', 'energy', 'appliances', 'watt', 'current'],
      builder: (_) => const ElectricityBillScreen(),
    ),
    ToolItem(
      id: 'gst_calc',
      title: 'GST Calculator',
      description: 'Exclusive & Inclusive GST with CGST/SGST',
      category: ToolCategory.finance,
      icon: Icons.receipt_long_rounded,
      keywords: ['gst', 'tax', 'vat', 'inclusive', 'exclusive', 'invoice', 'cgst', 'sgst'],
      builder: (_) => const GstCalculatorScreen(),
    ),
    ToolItem(
      id: 'loan_emi_calc',
      title: 'Loan EMI',
      description: 'Monthly EMI, interest share & amortization',
      category: ToolCategory.finance,
      icon: Icons.account_balance_rounded,
      keywords: ['loan', 'emi', 'mortgage', 'interest', 'bank', 'tenure'],
      builder: (_) => const LoanEmiCalculatorScreen(),
    ),
    ToolItem(
      id: 'discount_calc',
      title: 'Discount',
      description: 'Final price, multi-tier promo & savings',
      category: ToolCategory.finance,
      icon: Icons.local_offer_rounded,
      keywords: ['discount', 'shopping', 'sale', 'save', 'offer', 'price'],
      builder: (_) => const DiscountCalculatorScreen(),
    ),
    ToolItem(
      id: 'currency_converter',
      title: 'Currency',
      description: 'Live & offline rates: USD, INR, EUR, GBP, AED',
      category: ToolCategory.finance,
      icon: Icons.currency_exchange_rounded,
      keywords: ['currency', 'exchange', 'forex', 'usd', 'inr', 'eur', 'gbp', 'aed', 'money'],
      builder: (_) => const CurrencyConverterScreen(),
    ),
    ToolItem(
      id: 'interest_calc',
      title: 'Interest',
      description: 'Simple & compound interest with compounding',
      category: ToolCategory.finance,
      icon: Icons.trending_up_rounded,
      keywords: ['interest', 'compound', 'simple', 'investment', 'fd', 'rd', 'growth', 'roi'],
      builder: (_) => const InterestCalculatorScreen(),
    ),
    ToolItem(
      id: 'tip_split_calc',
      title: 'Tip & Split',
      description: 'Calculate tips & split bills among friends',
      category: ToolCategory.finance,
      icon: Icons.group_rounded,
      keywords: ['tip', 'split', 'bill', 'restaurant', 'dinner', 'people'],
      builder: (_) => const TipSplitScreen(),
    ),

    // Date & Age
    ToolItem(
      id: 'age_calc',
      title: 'Age',
      description: 'Exact years, months, days & next birthday',
      category: ToolCategory.dateAge,
      icon: Icons.cake_rounded,
      keywords: ['age', 'birthday', 'birthdate', 'years', 'months', 'days', 'born'],
      builder: (_) => const AgeCalculatorScreen(),
    ),
    ToolItem(
      id: 'date_diff',
      title: 'Date Difference',
      description: 'Calendar days & working business days',
      category: ToolCategory.dateAge,
      icon: Icons.date_range_rounded,
      keywords: ['date', 'difference', 'days', 'weeks', 'working days', 'business days'],
      builder: (_) => const DateDifferenceScreen(),
    ),

    // Time & Duration
    ToolItem(
      id: 'duration_converter',
      title: 'Duration Converter',
      description: 'Hours to days, minutes & seconds breakdown',
      category: ToolCategory.timeDuration,
      icon: Icons.hourglass_bottom_rounded,
      keywords: ['duration', 'hours', 'days', 'minutes', 'seconds', 'converter', 'time'],
      builder: (_) => const DurationConverterScreen(),
    ),

    // Converters
    ToolItem(
      id: 'unit_converter',
      title: 'Unit Converter',
      description: 'Length, Mass, Temp, Area, Volume, Speed, Data',
      category: ToolCategory.converters,
      icon: Icons.straighten_rounded,
      keywords: ['unit', 'converter', 'length', 'mass', 'weight', 'temperature', 'area', 'volume', 'speed', 'data'],
      builder: (_) => const UnitConverterScreen(),
    ),

    // Text Tools
    ToolItem(
      id: 'text_analyzer',
      title: 'Text & Words',
      description: 'Word count, character count & case transformers',
      category: ToolCategory.text,
      icon: Icons.text_fields_rounded,
      keywords: ['text', 'words', 'characters', 'uppercase', 'lowercase', 'titlecase', 'slug'],
      builder: (_) => const TextAnalyzerScreen(),
    ),

    // Developer Tools
    ToolItem(
      id: 'dev_tools',
      title: 'Developer Suite',
      description: 'JSON Formatter, Base64, UUID, Color codes',
      category: ToolCategory.developer,
      icon: Icons.terminal_rounded,
      keywords: ['json', 'formatter', 'validator', 'base64', 'url', 'uuid', 'color', 'hex', 'rgb'],
      builder: (_) => const DevToolsScreen(),
    ),

    // Everyday Utilities
    ToolItem(
      id: 'random_utilities',
      title: 'Random & Dice',
      description: 'Random numbers, dice roller & coin toss',
      category: ToolCategory.everyday,
      icon: Icons.casino_rounded,
      keywords: ['random', 'dice', 'coin', 'flip', 'toss', 'roll', 'decision'],
      builder: (_) => const RandomUtilitiesScreen(),
    ),

    // PDF & Documents
    ToolItem(
      id: 'pdf_toolkit',
      title: 'PDF Toolkit',
      description: 'Images to PDF, Text to PDF, Watermark & Page numbers',
      category: ToolCategory.documents,
      icon: Icons.picture_as_pdf_rounded,
      keywords: ['pdf', 'images to pdf', 'convert', 'merge', 'split', 'watermark', 'pages', 'document', 'text to pdf'],
      builder: (_) => const PdfToolkitScreen(),
    ),
    ToolItem(
      id: 'document_scanner',
      title: 'Document Scanner',
      description: 'Multi-page scans, B&W filters, ID card & Signature pad',
      category: ToolCategory.documents,
      icon: Icons.document_scanner_rounded,
      keywords: ['scanner', 'scan', 'document', 'id card', 'signature', 'filter', 'grayscale', 'receipt'],
      builder: (_) => const DocumentScannerScreen(),
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
