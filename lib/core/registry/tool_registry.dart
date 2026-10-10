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
import '../../features/image_tools/image_toolkit_screen.dart';
import '../../features/qr_barcode/qr_barcode_toolkit_screen.dart';
import '../../features/file_tools/file_zip_toolkit_screen.dart';
import '../../features/ocr_tools/ocr_toolkit_screen.dart';
import '../../features/health/health_calculator_screen.dart';
import '../../features/security/password_generator_screen.dart';
import '../../features/kitchen/kitchen_converter_screen.dart';
import '../../features/education/gpa_calculator_screen.dart';
import '../../features/health/health_fitness_toolkit_screen.dart';
import '../../features/education/academic_toolkit_screen.dart';
import '../../features/home/home_travel_toolkit_screen.dart';
import '../../features/image_tools/collage_maker_screen.dart';
import '../../features/text_tools/text_diff_cleaner_screen.dart';
import '../../features/text_tools/markdown_editor_screen.dart';
import '../../features/dev_tools/xml_yaml_formatter_screen.dart';
import '../../features/file_tools/media_tools_screen.dart';
import '../../features/device_tools/device_hardware_toolkit_screen.dart';
import '../../features/device_tools/battery_display_info_screen.dart';
import '../../features/device_tools/mic_speaker_tester_screen.dart';
import '../../features/device_tools/touchscreen_test_screen.dart';
import '../../features/device_tools/screen_color_test_screen.dart';
import '../../features/device_tools/vibration_tester_screen.dart';
import '../../features/device_tools/sound_level_estimator_screen.dart';
import '../../features/everyday_tools/qr_contact_share_screen.dart';
import '../../features/image_tools/photo_editor_screen.dart';
import '../../features/documents/office_pdf_toolkit_screen.dart';
import '../../features/productivity/productivity_toolkit_screen.dart';
import '../../features/file_tools/archive_preview_toolkit_screen.dart';

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
    ToolItem(
      id: 'productivity_toolkit',
      title: 'Productivity & Organization Suite',
      description: 'Notes with categories, calendar & events, subscriptions, bills, work-hours tracker & to-do checklists',
      category: ToolCategory.dateTime,
      icon: Icons.task_alt_rounded,
      keywords: ['productivity', 'notes', 'calendar', 'events', 'reminders', 'subscription', 'bill', 'due date', 'work hours', 'timesheet', 'todo', 'checklist', 'tasks', 'organization'],
      builder: (_) => const ProductivityToolkitScreen(),
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
      id: 'health_fitness_toolkit',
      title: 'Health & Fitness Suite',
      description: 'Body-fat %, WHtR, running pace, step-to-distance, HR zones, interval timer, macros & water tracker',
      category: ToolCategory.health,
      icon: Icons.fitness_center_rounded,
      keywords: ['health', 'fitness', 'body fat', 'navy', 'whtr', 'waist', 'running', 'pace', 'speed', 'steps', 'heart rate', 'hr zones', 'hiit', 'tabata', 'timer', 'macros', 'protein', 'water', 'hydration'],
      builder: (_) => const HealthFitnessToolkitScreen(),
    ),
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
      id: 'academic_toolkit',
      title: 'Academic & Education Suite',
      description: 'Marks percentage, exam targets, attendance eligibility, scientific calc, equations, primes, GCD/LCM, matrix & permutations',
      category: ToolCategory.education,
      icon: Icons.school_rounded,
      keywords: ['marks', 'grade', 'exam', 'attendance', 'scientific', 'calculator', 'equation', 'quadratic', 'prime', 'factorization', 'gcd', 'lcm', 'matrix', 'permutation', 'combination', 'math', 'education'],
      builder: (_) => const AcademicToolkitScreen(),
    ),
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
      id: 'home_travel_toolkit',
      title: 'Home, Construction & Travel Suite',
      description: 'Fuel cost, EV charging, paint, tile & flooring, concrete, land units, water tank, appliance power, trip splitter & download time',
      category: ToolCategory.homeTravel,
      icon: Icons.holiday_village_rounded,
      keywords: ['fuel', 'mileage', 'trip', 'ev', 'charging', 'paint', 'tile', 'flooring', 'concrete', 'cement', 'land', 'acre', 'cent', 'hectare', 'water tank', 'appliance', 'electricity', 'split', 'download', 'home', 'travel'],
      builder: (_) => const HomeTravelToolkitScreen(),
    ),
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
      title: 'Advanced PDF Toolkit',
      description: 'Merge, split, organize, compress, protect, PDF to images, sign/stamp, forms & PDF to text',
      category: ToolCategory.filesText,
      icon: Icons.picture_as_pdf_rounded,
      keywords: ['pdf', 'merge', 'split', 'compress', 'encrypt', 'password', 'sign', 'stamp', 'forms', 'ocr', 'images to pdf', 'text to pdf'],
      builder: (_) => const PdfToolkitScreen(),
    ),
    ToolItem(
      id: 'office_doc_pdf_suite',
      title: 'Office & Advanced PDF Suite',
      description: 'Word/Excel/PPT to PDF, PDF to Word/Excel/PPT, Searchable OCR, metadata editor, extract pages, bookmarks & compare',
      category: ToolCategory.filesText,
      icon: Icons.snippet_folder_rounded,
      keywords: ['word', 'docx', 'excel', 'xlsx', 'csv', 'powerpoint', 'pptx', 'ocr', 'metadata', 'bookmarks', 'flatten', 'compare', 'extract', 'pdf'],
      builder: (_) => const OfficePdfToolkitScreen(),
    ),
    ToolItem(
      id: 'image_toolkit',
      title: 'Image Toolkit',
      description: 'Compress, resize/crop, format convert, rotate/flip, combine, Base64, EXIF & passport photos',
      category: ToolCategory.filesText,
      icon: Icons.photo_size_select_actual_rounded,
      keywords: ['image', 'photo', 'compress', 'resize', 'crop', 'jpg', 'png', 'webp', 'rotate', 'flip', 'combine', 'base64', 'exif', 'watermark', 'passport'],
      builder: (_) => const ImageToolkitScreen(),
    ),
    ToolItem(
      id: 'photo_editor_studio',
      title: 'Photo Studio & Editor',
      description: 'Remove background, change BG color, adjustments, filters, censor blur, annotate & text/logo watermark',
      category: ToolCategory.filesText,
      icon: Icons.auto_fix_high_rounded,
      keywords: ['photo', 'editor', 'remove bg', 'background', 'filter', 'blur', 'censor', 'draw', 'annotate', 'logo', 'watermark', 'brightness', 'contrast'],
      builder: (_) => const PhotoEditorScreen(),
    ),
    ToolItem(
      id: 'image_collage_maker',
      title: 'Image Collage Maker',
      description: 'Combine multiple photos into customized photo grid collages',
      category: ToolCategory.filesText,
      icon: Icons.grid_view_rounded,
      keywords: ['collage', 'photo', 'grid', 'combine', 'stitch', 'images', 'layout'],
      builder: (_) => const CollageMakerScreen(),
    ),
    ToolItem(
      id: 'file_zip_toolkit',
      title: 'File & ZIP Suite',
      description: 'Create ZIP (compress all), extract archives, batch rename, size analyzer, hash checksums & duplicate finder',
      category: ToolCategory.filesText,
      icon: Icons.folder_zip_rounded,
      keywords: ['zip', 'rar', 'archive', 'extract', 'compress', 'compress all', 'unzip', 'rename', 'hash', 'md5', 'sha256', 'duplicate', 'csv', 'json', 'files'],
      builder: (_) => const FileZipToolkitScreen(),
    ),
    ToolItem(
      id: 'archive_compare_toolkit',
      title: 'Archive, Diff & Preview Studio',
      description: 'TAR & GZIP archiver, 7z & RAR explorer, folder comparison, visual file diff & universal previewer',
      category: ToolCategory.filesText,
      icon: Icons.archive_rounded,
      keywords: ['tar', 'gzip', 'gz', '7z', 'rar', 'archive', 'extract', 'compress all', 'unrar', 'folder compare', 'diff', 'compare', 'file preview', 'hex dump'],
      builder: (_) => const ArchivePreviewToolkitScreen(),
    ),
    ToolItem(
      id: 'ocr_toolkit',
      title: 'OCR & Voice Studio',
      description: 'Extract photo & document text, image tables to CSV, contact extractor, TTS & voice dictation',
      category: ToolCategory.filesText,
      icon: Icons.document_scanner_rounded,
      keywords: ['ocr', 'text', 'photo', 'scanner', 'table', 'csv', 'email', 'phone', 'tts', 'speech', 'voice', 'dictation'],
      builder: (_) => const OcrToolkitScreen(),
    ),
    ToolItem(
      id: 'text_diff_cleaner',
      title: 'Text Diff & Cleaner',
      description: 'Line-by-line difference comparison and duplicate line remover',
      category: ToolCategory.filesText,
      icon: Icons.difference_rounded,
      keywords: ['diff', 'compare', 'difference', 'duplicate', 'remove duplicate', 'dedupe', 'sort', 'lines', 'text'],
      builder: (_) => const TextDiffCleanerScreen(),
    ),
    ToolItem(
      id: 'markdown_editor',
      title: 'Markdown Editor & Preview',
      description: 'Edit, preview, and export rich formatted Markdown documents',
      category: ToolCategory.filesText,
      icon: Icons.edit_note_rounded,
      keywords: ['markdown', 'md', 'editor', 'preview', 'document', 'rich text', 'formatting'],
      builder: (_) => const MarkdownEditorScreen(),
    ),
    ToolItem(
      id: 'media_tools',
      title: 'Audio & Video Studio',
      description: 'Audio trimmer, visual waveform cutter, video compressor & trimmer',
      category: ToolCategory.filesText,
      icon: Icons.movie_creation_rounded,
      keywords: ['audio', 'music', 'sound', 'trim', 'cutter', 'waveform', 'video', 'compress', 'video trimmer', 'bitrate'],
      builder: (_) => const MediaToolsScreen(),
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
      id: 'qr_barcode_toolkit',
      title: 'QR & Barcode Suite',
      description: 'Live camera & image scanner, Wi-Fi QR, contact cards, barcodes, bulk sheets & scan history',
      category: ToolCategory.developer,
      icon: Icons.qr_code_scanner_rounded,
      keywords: ['qr', 'barcode', 'scan', 'scanner', 'camera', 'wifi', 'vcard', 'contact', 'code128', 'ean13', 'bulk', 'history', 'generator'],
      builder: (_) => const QrBarcodeToolkitScreen(),
    ),
    ToolItem(
      id: 'xml_yaml_formatter',
      title: 'XML & YAML Formatter',
      description: 'Prettify, validate, format, and minify XML and YAML data',
      category: ToolCategory.developer,
      icon: Icons.code_rounded,
      keywords: ['xml', 'yaml', 'format', 'prettify', 'minify', 'validate', 'json', 'developer'],
      builder: (_) => const XmlYamlFormatterScreen(),
    ),
    ToolItem(
      id: 'device_hardware_toolkit',
      title: 'Device & Hardware Studio',
      description: 'Device information viewer, digital compass, spirit level & live sensor tester',
      category: ToolCategory.developer,
      icon: Icons.perm_device_information_rounded,
      keywords: ['device', 'hardware', 'specs', 'system', 'compass', 'level', 'spirit level', 'sensor', 'accelerometer', 'gyroscope', 'magnetometer', 'shake'],
      builder: (_) => const DeviceHardwareToolkitScreen(),
    ),
    ToolItem(
      id: 'compass_level',
      title: 'Compass & Spirit Level',
      description: 'Digital magnetic compass and 2D surface bubble spirit level',
      category: ToolCategory.moreTools,
      icon: Icons.explore_rounded,
      customColor: const Color(0xFF0284C7),
      keywords: ['compass', 'spirit level', 'bubble', 'inclinometer', 'heading', 'degrees', 'tilt', 'pitch', 'roll', 'north'],
      builder: (_) => const DeviceHardwareToolkitScreen(),
    ),
    ToolItem(
      id: 'sensor_tester',
      title: 'Sensor Tester',
      description: 'Real-time diagnostic tester for Accelerometer, Gyroscope, and Magnetometer',
      category: ToolCategory.developer,
      icon: Icons.sensors_rounded,
      keywords: ['sensor', 'tester', 'diagnostic', 'accelerometer', 'gyroscope', 'magnetometer', 'shake', 'g-force'],
      builder: (_) => const DeviceHardwareToolkitScreen(),
    ),
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
      customColor: const Color(0xFF8B5CF6),
      keywords: ['random', 'dice', 'coin', 'flip', 'toss', 'roll', 'decision', 'utilities'],
      builder: (_) => const RandomUtilitiesScreen(),
    ),
    ToolItem(
      id: 'battery_health',
      title: 'Battery Health & Specs',
      description: 'Live charge percentage, health status, voltage, temp & power saver',
      category: ToolCategory.moreTools,
      icon: Icons.battery_charging_full_rounded,
      customColor: const Color(0xFF10B981),
      keywords: ['battery', 'health', 'charge', 'power', 'charging', 'voltage', 'saver'],
      builder: (_) => const BatteryDisplayInfoScreen(initialTabIndex: 0),
    ),
    ToolItem(
      id: 'mic_speaker_tester',
      title: 'Mic & Speaker Tester',
      description: 'Loudspeaker stereo channel audio test, frequency pitch & microphone loopback',
      category: ToolCategory.moreTools,
      icon: Icons.volume_up_rounded,
      customColor: const Color(0xFFF43F5E),
      keywords: ['mic', 'microphone', 'speaker', 'audio', 'sound', 'stereo', 'sound test', 'earpiece'],
      builder: (_) => const MicSpeakerTesterScreen(),
    ),
    ToolItem(
      id: 'touchscreen_test',
      title: 'Touchscreen Digitizer Test',
      description: '160-cell digitizer screen coverage grid test & multi-touch pointer tracker',
      category: ToolCategory.moreTools,
      icon: Icons.touch_app_rounded,
      customColor: const Color(0xFF3B82F6),
      keywords: ['touch', 'touchscreen', 'digitizer', 'multitouch', 'screen test', 'dead zone', 'fingers'],
      builder: (_) => const TouchscreenTestScreen(),
    ),
    ToolItem(
      id: 'screen_color_test',
      title: 'Screen Color & Pixel Test',
      description: 'Fullscreen dead pixel audit, OLED burn-in check, and RGB pure color patterns',
      category: ToolCategory.moreTools,
      icon: Icons.palette_rounded,
      customColor: const Color(0xFFD946EF),
      keywords: ['screen', 'display', 'color', 'pixel', 'dead pixel', 'stuck pixel', 'oled', 'lcd', 'burn in', 'backlight bleed'],
      builder: (_) => const ScreenColorTestScreen(),
    ),
    ToolItem(
      id: 'vibration_tester',
      title: 'Vibration & Haptics Tester',
      description: 'Tactile motor impacts, continuous rhythms, SOS Morse & animated ripple wave',
      category: ToolCategory.moreTools,
      icon: Icons.vibration_rounded,
      customColor: const Color(0xFFF59E0B),
      keywords: ['vibrate', 'vibration', 'haptic', 'motor', 'buzz', 'rumble', 'shake', 'sos'],
      builder: (_) => const VibrationTesterScreen(),
    ),
    ToolItem(
      id: 'display_refresh_rate',
      title: 'Screen Refresh Rate & Specs',
      description: 'Hardware refresh rate (60/90/120 Hz), live render FPS & screen resolution',
      category: ToolCategory.moreTools,
      icon: Icons.speed_rounded,
      customColor: const Color(0xFF06B6D4),
      keywords: ['refresh rate', 'hz', 'fps', 'display', 'resolution', 'dpr', 'screen', 'smooth'],
      builder: (_) => const BatteryDisplayInfoScreen(initialTabIndex: 1),
    ),
    ToolItem(
      id: 'sound_level_estimator',
      title: 'Sound-Level (dB) Estimator',
      description: 'Real-time decibel meter, min/avg/peak sound levels & noise safety scale',
      category: ToolCategory.moreTools,
      icon: Icons.graphic_eq_rounded,
      customColor: const Color(0xFF14B8A6),
      keywords: ['sound', 'noise', 'decibel', 'db', 'spl', 'sound level', 'meter', 'microphone'],
      builder: (_) => const SoundLevelEstimatorScreen(),
    ),
    ToolItem(
      id: 'qr_contact_share',
      title: 'QR Contact & vCard Share',
      description: 'Instant vCard 3.0 & MeCard QR generation for effortless contact sharing',
      category: ToolCategory.filesText,
      icon: Icons.contact_page_rounded,
      keywords: ['qr', 'contact', 'vcard', 'mecard', 'share', 'business card', 'phone', 'address'],
      builder: (_) => const QrContactShareScreen(),
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
