import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:utility_tool/core/models/tool_model.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/features/file_tools/archive_compare_service.dart';

void main() {
  group('Archive Creation & Extraction Tests', () {
    test('createTar and extractTar roundtrip produces matching files', () {
      final entries = [
        ArchiveEntry(
          name: 'notes.txt',
          size: 19,
          bytes: Uint8List.fromList(utf8.encode('Hello TAR Archiver!')),
        ),
        ArchiveEntry(
          name: 'config/app.json',
          size: 26,
          bytes: Uint8List.fromList(utf8.encode('{"version": "1.0.86"}')),
        ),
      ];

      final tarBytes = ArchiveCompareService.createTar(entries);
      expect(tarBytes.isNotEmpty, isTrue);

      final extracted = ArchiveCompareService.extractTar(tarBytes);
      expect(extracted.length, 2);
      expect(extracted[0].name, 'notes.txt');
      expect(utf8.decode(extracted[0].bytes), 'Hello TAR Archiver!');
      expect(extracted[1].name, 'config/app.json');
      expect(utf8.decode(extracted[1].bytes), '{"version": "1.0.86"}');
    });

    test('compressGzip and decompressGzip preserves byte data', () {
      final original = Uint8List.fromList(utf8.encode('This is sample data to be compressed with GZIP.'));
      final compressed = ArchiveCompareService.compressGzip(original);

      expect(compressed.length, greaterThan(0));
      // First two bytes of GZIP format are 0x1F, 0x8B
      expect(compressed[0], 0x1F);
      expect(compressed[1], 0x8B);

      final decompressed = ArchiveCompareService.decompressGzip(compressed);
      expect(decompressed, equals(original));
      expect(utf8.decode(decompressed), 'This is sample data to be compressed with GZIP.');
    });

    test('createTarGz and extractTarGz roundtrip works smoothly', () {
      final entries = [
        ArchiveEntry(
          name: 'server.log',
          size: 32,
          bytes: Uint8List.fromList(utf8.encode('2026-10-10 INFO: System healthy')),
        ),
      ];

      final tarGzBytes = ArchiveCompareService.createTarGz(entries);
      expect(tarGzBytes[0], 0x1F);
      expect(tarGzBytes[1], 0x8B);

      final extracted = ArchiveCompareService.extractTarGz(tarGzBytes);
      expect(extracted.length, 1);
      expect(extracted.first.name, 'server.log');
      expect(utf8.decode(extracted.first.bytes), '2026-10-10 INFO: System healthy');
    });
  });

  group('7z Archive Inspector Tests', () {
    test('inspect7zArchive detects invalid small files', () {
      final tooSmall = Uint8List(10);
      final info = ArchiveCompareService.inspect7zArchive(tooSmall);
      expect(info.isValid7z, isFalse);
      expect(info.status.contains('too small'), isTrue);
    });

    test('inspect7zArchive detects invalid signature', () {
      final randomBytes = Uint8List(40);
      final info = ArchiveCompareService.inspect7zArchive(randomBytes);
      expect(info.isValid7z, isFalse);
      expect(info.status.contains('Invalid signature'), isTrue);
    });

    test('inspect7zArchive successfully recognizes valid 7z signature and header', () {
      final valid7z = Uint8List(64);
      // Signature: 0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C
      valid7z[0] = 0x37;
      valid7z[1] = 0x7A;
      valid7z[2] = 0xBC;
      valid7z[3] = 0xAF;
      valid7z[4] = 0x27;
      valid7z[5] = 0x1C;
      // Version 0.4
      valid7z[6] = 0;
      valid7z[7] = 4;
      // StartHeaderCRC
      valid7z[8] = 0xAA;
      valid7z[9] = 0xBB;
      valid7z[10] = 0xCC;
      valid7z[11] = 0xDD;

      final info = ArchiveCompareService.inspect7zArchive(valid7z);
      expect(info.isValid7z, isTrue);
      expect(info.majorVersion, 0);
      expect(info.minorVersion, 4);
      expect(info.metadata.containsKey('StartHeaderCRC'), isTrue);
      expect(info.metadata['SignatureHex'], '37 7A BC AF 27 1C');
    });
  });

  group('Folder Comparison Tests', () {
    test('compareFolders identifies identical, modified, and unique files', () {
      final folderA = [
        ArchiveEntry(name: 'same.txt', size: 10, bytes: Uint8List.fromList([1, 2, 3])),
        ArchiveEntry(name: 'changed.txt', size: 10, bytes: Uint8List.fromList([1, 2, 3])),
        ArchiveEntry(name: 'only_in_a.txt', size: 5, bytes: Uint8List.fromList([5, 5])),
      ];

      final folderB = [
        ArchiveEntry(name: 'same.txt', size: 10, bytes: Uint8List.fromList([1, 2, 3])),
        ArchiveEntry(name: 'changed.txt', size: 15, bytes: Uint8List.fromList([1, 2, 3, 4])),
        ArchiveEntry(name: 'only_in_b.txt', size: 8, bytes: Uint8List.fromList([8, 8])),
      ];

      final result = ArchiveCompareService.compareFolders(folderA, folderB);

      expect(result.identicalCount, 1);
      expect(result.modifiedCount, 1);
      expect(result.onlyInACount, 1);
      expect(result.onlyInBCount, 1);
      expect(result.totalA, 3);
      expect(result.totalB, 3);
      expect(result.similarityPercent, closeTo(25.0, 0.1));
    });
  });

  group('File Content Diff Tests', () {
    test('compareFileContents accurately detects line modifications, additions and deletions', () {
      final textA = 'Line 1: Alpha\nLine 2: Beta\nLine 3: Gamma';
      final textB = 'Line 1: Alpha\nLine 2: Beta Modified\nLine 3: Gamma\nLine 4: Delta';

      final bytesA = Uint8List.fromList(utf8.encode(textA));
      final bytesB = Uint8List.fromList(utf8.encode(textB));

      final diff = ArchiveCompareService.compareFileContents('a.txt', bytesA, 'b.txt', bytesB);

      expect(diff.isBinary, isFalse);
      expect(diff.totalLinesA, 3);
      expect(diff.totalLinesB, 4);
      expect(diff.unchanged, greaterThanOrEqualTo(2));
      expect(diff.similarityPercent, greaterThan(40.0));
    });

    test('compareFileContents handles binary files', () {
      final bytesA = Uint8List.fromList([0, 1, 2, 3, 4, 0]);
      final bytesB = Uint8List.fromList([0, 1, 2, 3, 4, 0]);

      final diff = ArchiveCompareService.compareFileContents('a.bin', bytesA, 'b.bin', bytesB);
      expect(diff.isBinary, isTrue);
      expect(diff.similarityPercent, 100.0);
    });
  });

  group('File Preview & Hex Dump Tests', () {
    test('detectFileType categorizes formats correctly', () {
      expect(ArchiveCompareService.detectFileType('image.png', Uint8List(10)), PreviewFileType.image);
      expect(ArchiveCompareService.detectFileType('doc.pdf', Uint8List(10)), PreviewFileType.pdf);
      expect(ArchiveCompareService.detectFileType('guide.md', Uint8List(10)), PreviewFileType.markdown);
      expect(ArchiveCompareService.detectFileType('script.dart', Uint8List(10)), PreviewFileType.textCode);
      expect(ArchiveCompareService.detectFileType('track.mp3', Uint8List(10)), PreviewFileType.audio);
    });

    test('generateHexDump outputs formatted 16-byte hex rows with ASCII column', () {
      final sample = Uint8List.fromList(utf8.encode('Hello World 1234'));
      final hexRows = ArchiveCompareService.generateHexDump(sample);

      expect(hexRows.isNotEmpty, isTrue);
      expect(hexRows.first.contains('00000000'), isTrue);
      expect(hexRows.first.contains('48 65 6C 6C 6F'), isTrue); // 'Hello'
      expect(hexRows.first.contains('Hello World 1234'), isTrue);
    });
  });

  group('ToolRegistry Verification for Archive Suite', () {
    test('Archive, Diff & Preview Studio is registered in ToolRegistry', () {
      final tool = ToolRegistry.allTools.firstWhere(
        (t) => t.id == 'archive_compare_toolkit',
        orElse: () => throw Exception('archive_compare_toolkit not found in ToolRegistry'),
      );

      expect(tool.title, 'Archive, Diff & Preview Studio');
      expect(tool.category, ToolCategory.filesText);
      expect(tool.keywords.contains('tar'), isTrue);
      expect(tool.keywords.contains('gzip'), isTrue);
      expect(tool.keywords.contains('7z'), isTrue);
      expect(tool.keywords.contains('diff'), isTrue);
      expect(tool.keywords.contains('folder compare'), isTrue);
      expect(tool.keywords.contains('file preview'), isTrue);
    });
  });
}
