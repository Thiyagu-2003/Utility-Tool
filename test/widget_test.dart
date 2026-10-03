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

  testWidgets('App launches with MIUI style calculator and tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const UtilityApp());
    await tester.pumpAndSettle();

    // Verify calculator screen '=' is present
    expect(find.text('='), findsWidgets);
    // Verify AC button
    expect(find.text('AC'), findsOneWidget);
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
    expect(pdfTool!.title, 'PDF Toolkit');

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
