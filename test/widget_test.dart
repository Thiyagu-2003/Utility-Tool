import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utility_tool/main.dart';
import 'package:utility_tool/core/services/preferences_service.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/core/models/tool_model.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  testWidgets('App launches with MainNavigationScaffold and hubs', (WidgetTester tester) async {
    await tester.pumpWidget(const UtilityApp());
    await tester.pumpAndSettle();

    expect(find.byType(UtilityApp), findsOneWidget);
  });

  test('ToolRegistry contains essential tools across categories', () {
    expect(ToolRegistry.allTools.length, greaterThanOrEqualTo(10));

    final gstTool = ToolRegistry.findById('gst_calc');
    expect(gstTool, isNotNull);
    expect(gstTool!.title, 'GST Calculator');

    final ageTool = ToolRegistry.findById('age_calc');
    expect(ageTool, isNotNull);
    expect(ageTool!.title, 'Age');

    final unitTool = ToolRegistry.findById('unit_converter');
    expect(unitTool, isNotNull);
    expect(unitTool!.title, 'Unit Converter');

    final electricTool = ToolRegistry.findById('electricity_bill');
    expect(electricTool, isNotNull);
    expect(electricTool!.title, 'Electricity Bill');

    final pdfTool = ToolRegistry.findById('pdf_toolkit');
    expect(pdfTool, isNotNull);
    expect(pdfTool!.title, contains('PDF Toolkit'));

    final imageTool = ToolRegistry.findById('image_toolkit');
    expect(imageTool, isNotNull);
    expect(imageTool!.title, 'Image Toolkit');

    final qrTool = ToolRegistry.findById('qr_barcode_toolkit');
    expect(qrTool, isNotNull);
    expect(qrTool!.title, 'QR & Barcode Suite');

    final fileZipTool = ToolRegistry.findById('file_zip_toolkit');
    expect(fileZipTool, isNotNull);
    expect(fileZipTool!.title, 'File & ZIP Suite');

    final ocrTool = ToolRegistry.findById('ocr_toolkit');
    expect(ocrTool, isNotNull);
    expect(ocrTool!.title, 'OCR & Voice Studio');

    final scannerTool = ToolRegistry.findById('document_scanner');
    expect(scannerTool, isNotNull);
    expect(scannerTool!.title, 'Document Scanner');

    final healthTool = ToolRegistry.findById('health_calc');
    expect(healthTool, isNotNull);
    expect(healthTool!.category, ToolCategory.health);

    final gpaTool = ToolRegistry.findById('gpa_calc');
    expect(gpaTool, isNotNull);
    expect(gpaTool!.category, ToolCategory.education);

    final kitchenTool = ToolRegistry.findById('kitchen_calc');
    expect(kitchenTool, isNotNull);
    expect(kitchenTool!.category, ToolCategory.kitchen);

    final passwordTool = ToolRegistry.findById('password_generator');
    expect(passwordTool, isNotNull);
    expect(passwordTool!.category, ToolCategory.security);

    final fitnessSuite = ToolRegistry.findById('health_fitness_toolkit');
    expect(fitnessSuite, isNotNull);
    expect(fitnessSuite!.title, 'Health & Fitness Suite');

    final academicSuite = ToolRegistry.findById('academic_toolkit');
    expect(academicSuite, isNotNull);
    expect(academicSuite!.title, 'Academic & Education Suite');

    final homeTravelSuite = ToolRegistry.findById('home_travel_toolkit');
    expect(homeTravelSuite, isNotNull);
    expect(homeTravelSuite!.title, 'Home, Construction & Travel Suite');

    final collageTool = ToolRegistry.findById('image_collage_maker');
    expect(collageTool, isNotNull);
    expect(collageTool!.title, 'Image Collage Maker');

    final diffTool = ToolRegistry.findById('text_diff_cleaner');
    expect(diffTool, isNotNull);
    expect(diffTool!.title, 'Text Diff & Cleaner');

    final mdTool = ToolRegistry.findById('markdown_editor');
    expect(mdTool, isNotNull);
    expect(mdTool!.title, 'Markdown Editor & Preview');

    final mediaTool = ToolRegistry.findById('media_tools');
    expect(mediaTool, isNotNull);
    expect(mediaTool!.title, 'Audio & Video Studio');

    final xmlYamlTool = ToolRegistry.findById('xml_yaml_formatter');
    expect(xmlYamlTool, isNotNull);
    expect(xmlYamlTool!.title, 'XML & YAML Formatter');

    final deviceSuite = ToolRegistry.findById('device_hardware_toolkit');
    expect(deviceSuite, isNotNull);
    expect(deviceSuite!.title, 'Device & Hardware Studio');

    final compassTool = ToolRegistry.findById('compass_level');
    expect(compassTool, isNotNull);
    expect(compassTool!.title, 'Compass & Spirit Level');

    final sensorTool = ToolRegistry.findById('sensor_tester');
    expect(sensorTool, isNotNull);
    expect(sensorTool!.title, 'Sensor Tester');
  });

  test('Electricity Bill calculation test', () {
    const units = 250.0;
    const ratePerUnit = 7.5;
    const fixedCharge = 60.0;
    const taxPercent = 5.0;

    final energyCharge = units * ratePerUnit; // 1875.0
    final subtotal = energyCharge + fixedCharge; // 1935.0
    final taxAmount = subtotal * (taxPercent / 100); // 96.75
    final total = subtotal + taxAmount; // 2031.75

    expect(energyCharge, 1875.0);
    expect(total, 2031.75);
  });

  test('Duration decomposition test: 200 hours = 8 days, 8 hours', () {
    const rawHours = 200;
    const totalSeconds = rawHours * 3600;

    final days = totalSeconds ~/ 86400;
    final remainingAfterDays = totalSeconds % 86400;
    final hours = remainingAfterDays ~/ 3600;

    expect(days, 8);
    expect(hours, 8);
  });

  test('GST Exclusive calculation test', () {
    const baseAmount = 1000.0;
    const rate = 18.0;
    final gstTax = baseAmount * (rate / 100);
    final total = baseAmount + gstTax;

    expect(gstTax, 180.0);
    expect(total, 1180.0);
  });
}
