import 'package:flutter_test/flutter_test.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/core/utils/vcard_utils.dart';

void main() {
  group('VCardUtils QR Contact Generation Tests', () {
    test('generateVCard generates RFC 2426 compliant vCard 3.0', () {
      const contact = ContactInfo(
        firstName: 'Elena',
        lastName: 'Rostova',
        organization: 'CyberCore Inc',
        jobTitle: 'Security Lead',
        phoneMobile: '+1 555 123 4567',
        phoneWork: '+1 555 987 6543',
        email: 'elena@cybercore.io',
        address: '100 Innovation Way, Suite 400',
        website: 'cybercore.io',
        note: 'Lead cryptographic architect',
      );

      final vcard = VCardUtils.generateVCard(contact);

      expect(vcard, contains('BEGIN:VCARD'));
      expect(vcard, contains('VERSION:3.0'));
      expect(vcard, contains('N:Rostova;Elena;;;'));
      expect(vcard, contains('FN:Elena Rostova'));
      expect(vcard, contains('ORG:CyberCore Inc'));
      expect(vcard, contains('TITLE:Security Lead'));
      expect(vcard, contains('TEL;TYPE=CELL:+1 555 123 4567'));
      expect(vcard, contains('TEL;TYPE=WORK:+1 555 987 6543'));
      expect(vcard, contains('EMAIL;TYPE=INTERNET:elena@cybercore.io'));
      expect(vcard, contains('URL:https://cybercore.io'));
      expect(vcard, contains('NOTE:Lead cryptographic architect'));
      expect(vcard, contains('END:VCARD'));
    });

    test('generateMeCard generates valid NTT DoCoMo format', () {
      const contact = ContactInfo(
        firstName: 'John',
        lastName: 'Doe',
        organization: 'Acme',
        phoneMobile: '1234567890',
        email: 'john@acme.com',
      );

      final mecard = VCardUtils.generateMeCard(contact);

      expect(mecard, startsWith('MECARD:'));
      expect(mecard, contains('N:Doe,John;'));
      expect(mecard, contains('ORG:Acme;'));
      expect(mecard, contains('TEL:1234567890;'));
      expect(mecard, contains('EMAIL:john@acme.com;'));
      expect(mecard, endsWith(';'));
    });

    test('ContactInfo helper methods behave correctly', () {
      const empty = ContactInfo();
      expect(empty.isEmpty, isTrue);
      expect(empty.displayName, 'Contact');

      const onlyCompany = ContactInfo(organization: 'Google');
      expect(onlyCompany.isEmpty, isFalse);
      expect(onlyCompany.displayName, 'Google');

      const withName = ContactInfo(firstName: 'Alice', lastName: 'Smith');
      expect(withName.displayName, 'Alice Smith');
    });
  });

  group('Device & Everyday Utilities Registry Verification', () {
    test('All 8 requested device utilities are registered in ToolRegistry', () {
      final batteryTool = ToolRegistry.findById('battery_health');
      expect(batteryTool, isNotNull);
      expect(batteryTool!.title, contains('Battery Health'));

      final micSpeakerTool = ToolRegistry.findById('mic_speaker_tester');
      expect(micSpeakerTool, isNotNull);
      expect(micSpeakerTool!.title, contains('Mic & Speaker'));

      final touchTool = ToolRegistry.findById('touchscreen_test');
      expect(touchTool, isNotNull);
      expect(touchTool!.title, contains('Touchscreen'));

      final colorTool = ToolRegistry.findById('screen_color_test');
      expect(colorTool, isNotNull);
      expect(colorTool!.title, contains('Screen Color'));

      final vibrationTool = ToolRegistry.findById('vibration_tester');
      expect(vibrationTool, isNotNull);
      expect(vibrationTool!.title, contains('Vibration'));

      final refreshRateTool = ToolRegistry.findById('display_refresh_rate');
      expect(refreshRateTool, isNotNull);
      expect(refreshRateTool!.title, contains('Refresh Rate'));

      final soundTool = ToolRegistry.findById('sound_level_estimator');
      expect(soundTool, isNotNull);
      expect(soundTool!.title, contains('Sound-Level'));

      final qrContactTool = ToolRegistry.findById('qr_contact_share');
      expect(qrContactTool, isNotNull);
      expect(qrContactTool!.title, contains('QR Contact'));
    });
  });
}
