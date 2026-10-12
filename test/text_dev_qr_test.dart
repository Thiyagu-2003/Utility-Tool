import 'dart:convert';
import 'dart:math' as math;

import 'package:barcode_widget/barcode_widget.dart' as bc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utility_tool/core/utils/validation_utils.dart';
import 'package:utility_tool/core/utils/vcard_utils.dart';
import 'package:utility_tool/features/dev_tools/dev_tools_screen.dart';
import 'package:utility_tool/features/qr_barcode/qr_barcode_toolkit_screen.dart';
import 'package:utility_tool/features/security/password_generator_screen.dart';
import 'package:utility_tool/features/text_tools/text_analyzer_screen.dart';
import 'package:utility_tool/features/text_tools/text_diff_cleaner_screen.dart';
import 'package:utility_tool/features/ocr_tools/ocr_toolkit_screen.dart';
import 'package:utility_tool/features/dev_tools/xml_yaml_formatter_screen.dart';

void main() {
  group('Text transforms', () {
    test('title case handles newlines and tabs', () {
      expect(toTitleCase('hello WORLD\nfoo\tbar'), 'Hello World\nFoo\tBar');
    });

    test('slug collapses separators and trims hyphens', () {
      expect(toSlug('  Hello,   World -- Again! '), 'hello-world-again');
      expect(toSlug('!!!'), '');
    });

    test('reverse keeps surrogate pairs intact', () {
      expect(reverseText('ab😀'), '😀ba');
    });
  });

  group('Line diff', () {
    String render(List<DiffLine> d) => d
        .map((l) => '${l.type == DiffType.added ? '+' : l.type == DiffType.removed ? '-' : ' '}${l.text}')
        .join('|');

    test('moved line yields a minimal diff', () {
      final d = computeLineDiff('A\nB\nC', 'A\nC\nB');
      expect(d.where((l) => l.type == DiffType.unchanged).length, 2);
      expect(d.where((l) => l.type != DiffType.unchanged).length, 2);
    });

    test('replacement and append', () {
      expect(render(computeLineDiff('A\nB\nC', 'A\nX\nC\nD')), ' A|-B|+X| C|+D');
    });

    test('empty inputs have no lines', () {
      expect(computeLineDiff('', ''), isEmpty);
      expect(render(computeLineDiff('', 'A')), '+A');
      expect(render(computeLineDiff('A', '')), '-A');
    });

    test('line numbers are tracked', () {
      final d = computeLineDiff('A\nB', 'B');
      expect(d.first.origLineNum, 1);
      expect(d.last.origLineNum, 2);
      expect(d.last.modLineNum, 1);
    });
  });

  group('Developer tools', () {
    test('Base64 decode accepts URL-safe alphabet, no padding and whitespace', () {
      expect(utf8.decode(decodeBase64Lenient('SGVsbG8')), 'Hello');
      expect(utf8.decode(decodeBase64Lenient('SGVs\nbG8=')), 'Hello');
      expect(decodeBase64Lenient('-_8'), [0xfb, 0xff]);
    });

    test('Base64 decode rejects invalid input with FormatException', () {
      expect(() => decodeBase64Lenient('abc!'), throwsFormatException);
    });

    test('hex colour parsing supports #RGB, #RRGGBB and #RRGGBBAA', () {
      expect(parseHexColor('#F60'), const Color(0xFFFF6600));
      expect(parseHexColor('ff6d00'), const Color(0xFFFF6D00));
      expect(parseHexColor('#FF000080'), const Color(0x80FF0000));
      expect(parseHexColor('#F008'), const Color(0x88FF0000));
      expect(parseHexColor('#GGGGGG'), isNull);
      expect(parseHexColor('#12345'), isNull);
      expect(parseHexColor(''), isNull);
    });
  });

  group('QR payloads', () {
    test('Wi-Fi special characters are escaped', () {
      expect(
        buildWifiQrPayload(ssid: r'My;Net,"1":\', password: ' p;w ', security: 'WPA', hidden: true),
        r'WIFI:T:WPA;S:My\;Net\,\"1\"\:\\;P: p\;w ;H:true;;',
      );
    });

    test('open network omits the password', () {
      expect(buildWifiQrPayload(ssid: 'Cafe', password: 'ignored', security: 'nopass'), 'WIFI:T:nopass;S:Cafe;;');
    });

    test('EAN-13 checksum is validated', () {
      final ean = bc.Barcode.ean13();
      expect(ean.isValid('4006381333931'), isTrue);
      expect(ean.isValid('4006381333932'), isFalse);
      expect(ean.isValid('ABC'), isFalse);
    });
  });

  group('vCard / MeCard escaping', () {
    test('vCard text values escape backslash, comma, semicolon and newline (RFC 2426)', () {
      final v = VCardUtils.generateVCard(const ContactInfo(
        firstName: 'Ann;e',
        lastName: r'O\Brien',
        organization: 'Acme, Inc',
        note: 'line1\nline2',
      ));
      expect(v, contains(r'N:O\\Brien;Ann\;e;;;'));
      expect(v, contains(r'ORG:Acme\, Inc'));
      expect(v, contains(r'NOTE:line1\nline2'));
      expect(v.split('\n').where((l) => l.startsWith('line2')), isEmpty);
    });

    test('MeCard values escape reserved characters', () {
      final m = VCardUtils.generateMeCard(const ContactInfo(firstName: 'A:B', organization: 'X;Y'));
      expect(m, contains(r'N:A\:B;'));
      expect(m, contains(r'ORG:X\;Y;'));
    });
  });

  group('Password generator', () {
    test('includes every selected set and has the requested length', () {
      for (var i = 0; i < 50; i++) {
        final p = generateSecurePassword(6, ['ABC', 'abc', '123', '!@#'], random: math.Random(i));
        expect(p.length, 6);
        expect(p, matches(RegExp('[ABC]')));
        expect(p, matches(RegExp('[abc]')));
        expect(p, matches(RegExp('[123]')));
        expect(p, matches(RegExp('[!@#]')));
      }
    });

    test('empty pool or length yields empty password', () {
      expect(generateSecurePassword(10, []), '');
      expect(generateSecurePassword(0, ['abc']), '');
    });

    test('strength is based on entropy, not length alone', () {
      // 16 digits ~ 53 bits: not "Very Strong".
      expect(passwordEntropyBits(16, 10), closeTo(53.15, 0.01));
      expect(passwordStrengthLabel(passwordEntropyBits(16, 10)), 'Moderate');
      expect(passwordStrengthLabel(passwordEntropyBits(16, 88)), 'Very Strong');
      expect(passwordEntropyBits(10, 0), 0);
    });
  });

  group('ValidationUtils non-finite input', () {
    test('Infinity and NaN are rejected', () {
      expect(ValidationUtils.validateNumber('Infinity').isValid, isFalse);
      expect(ValidationUtils.validateNumber('NaN').isValid, isFalse);
      expect(ValidationUtils.safeParseDouble('NaN', defaultValue: 1), 1);
    });
  });

  group('OCR entity extraction and table CSV', () {
    test('phone numbers never span a line break', () {
      final e = extractEntities('Qty 2400\n1599 total');
      expect(e.phones, isEmpty);
      expect(extractEntities('Call +1 (555) 234-5678 now').phones, ['+1 (555) 234-5678']);
    });

    test('trailing punctuation is not part of a URL', () {
      final e = extractEntities('See https://example.com/a, or (https://b.org/x).');
      expect(e.urls, ['https://example.com/a', 'https://b.org/x']);
    });

    test('emails, dates and amounts are found once each', () {
      final e = extractEntities('a@b.com a@b.com paid \$4,850.00 on 12/04/2026');
      expect(e.emails, ['a@b.com']);
      expect(e.amounts, [r'$4,850.00']);
      expect(e.dates, ['12/04/2026']);
    });

    test('pipe, tab and wide-space tables become CSV with quoting', () {
      expect(textToCsv('Item | Qty\nPen, blue | 2'), 'Item,Qty\n"Pen, blue",2');
      expect(textToCsv('a\tb'), 'a,b');
      expect(textToCsv('just words'), startsWith('No tabular structure'));
    });
  });

  group('Colour conversion', () {
    test('colorToHex writes #RRGGBB and optional alpha', () {
      expect(colorToHex(const Color(0xFFFF6D00)), '#FF6D00');
      expect(colorToHex(const Color(0x80FF0000), withAlpha: true), '#FF000080');
    });

    test('colorFromRgb rejects out-of-range channels', () {
      expect(colorFromRgb(255, 109, 0), const Color(0xFFFF6D00));
      expect(colorFromRgb(256, 0, 0), isNull);
      expect(colorFromRgb(0, -1, 0), isNull);
    });

    test('RGB to hex and back round-trips', () {
      final c = colorFromRgb(18, 52, 86)!;
      expect(parseHexColor(colorToHex(c)), c);
    });
  });

  group('YAML structural check', () {
    test('accepts common valid documents', () {
      expect(validateYamlLite('server:\n  port: 8080\n  host: "0.0.0.0"\n  tags: [a, b]\nlist:\n  - name: x\n    id: 1\n  - name: y\n'), isNull);
      expect(validateYamlLite('msg: |\n  a: b\n  a: c\nnext: 1'), isNull); // block scalar text is not keys
      expect(validateYamlLite("title: Don't stop # comment\nitems:\n- a\n- b"), isNull);
    });

    test('flags duplicate keys, tabs, bad dedent and missing colon', () {
      expect(validateYamlLite('a: 1\na: 2'), contains('duplicate key "a"'));
      expect(validateYamlLite('a:\n\tb: 1'), contains('tab'));
      expect(validateYamlLite('a:\n    b: 1\n  c: 2'), contains('inconsistent indentation'));
      expect(validateYamlLite('a: 1\njust text'), contains('":"'));
      expect(validateYamlLite('a: 1\n  b: 2'), contains('not allowed here'));
    });

    test('flags unterminated quotes and unclosed brackets', () {
      expect(validateYamlLite('a: "oops'), contains('unterminated'));
      expect(validateYamlLite('a: [1, 2'), contains('Unclosed'));
    });
  });

  group('Diff size guard', () {
    test('huge unrelated texts fall back to replace-all instead of an n*m table', () {
      final a = List.generate(3000, (i) => 'a$i').join('\n');
      final b = List.generate(3000, (i) => 'b$i').join('\n');
      final d = computeLineDiff(a, b);
      expect(d.where((l) => l.type == DiffType.removed).length, 3000);
      expect(d.where((l) => l.type == DiffType.added).length, 3000);
    });
  });
}
