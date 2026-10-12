import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/core/utils/vcard_utils.dart';
import 'package:utility_tool/features/device_tools/device_hardware_toolkit_screen.dart';

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
      expect(batteryTool!.title, contains('Battery Status'));

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

  group('compassHeadingDegrees', () {
    test('flat device matches atan2(-mx, my) at the four cardinal directions', () {
      const g = 9.81;
      expect(compassHeadingDegrees(0, 0, g, 0, 30, -40), closeTo(0, 0.01));
      expect(compassHeadingDegrees(0, 0, g, -30, 0, -40), closeTo(90, 0.01));
      expect(compassHeadingDegrees(0, 0, g, 0, -30, -40), closeTo(180, 0.01));
      expect(compassHeadingDegrees(0, 0, g, 30, 0, -40), closeTo(270, 0.01));
    });

    test('heading stays correct when the phone is tilted (pitch and roll)', () {
      // Device axes in world ENU coordinates after yaw (bearing), pitch and roll.
      List<double> rot(List<double> v, List<double> axis, double ang) {
        // Rodrigues rotation of v about unit axis.
        final c = math.cos(ang), s = math.sin(ang);
        final dot = v[0] * axis[0] + v[1] * axis[1] + v[2] * axis[2];
        final cross = [
          axis[1] * v[2] - axis[2] * v[1],
          axis[2] * v[0] - axis[0] * v[2],
          axis[0] * v[1] - axis[1] * v[0],
        ];
        return [for (var i = 0; i < 3; i++) v[i] * c + cross[i] * s + axis[i] * dot * (1 - c)];
      }

      double dot3(List<double> a, List<double> b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

      for (final bearing in [0.0, 37.0, 90.0, 181.0, 275.0, 359.0]) {
        for (final pitch in [0.0, 25.0, -40.0]) {
          for (final roll in [0.0, 30.0, -35.0]) {
            const up = [0.0, 0.0, 1.0];
            var ex = [1.0, 0.0, 0.0], ey = [0.0, 1.0, 0.0], ez = [0.0, 0.0, 1.0];
            final yaw = -bearing * math.pi / 180;
            ex = rot(ex, up, yaw);
            ey = rot(ey, up, yaw);
            final p = pitch * math.pi / 180;
            final ey2 = rot(ey, ex, p), ez2 = rot(ez, ex, p);
            final r = roll * math.pi / 180;
            final ex3 = rot(ex, ey2, r), ez3 = rot(ez2, ey2, r);
            final axes = [ex3, ey2, ez3];

            const earth = [0.0, 20.0, -45.0]; // 20 uT north, 45 uT down
            final a = [for (final ax in axes) dot3(up, ax) * 9.81];
            final m = [for (final ax in axes) dot3(earth, ax)];

            final heading = compassHeadingDegrees(a[0], a[1], a[2], m[0], m[1], m[2])!;
            var diff = (heading - bearing).abs() % 360;
            if (diff > 180) diff = 360 - diff;
            expect(diff, lessThan(0.01), reason: 'bearing $bearing pitch $pitch roll $roll got $heading');
          }
        }
      }
    });

    test('returns null for free fall or an empty magnetic reading', () {
      expect(compassHeadingDegrees(0, 0, 0, 0, 30, -40), isNull);
      expect(compassHeadingDegrees(0, 0, 9.81, 0, 0, 0), isNull);
    });
  });
}
