import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utility_tool/features/file_tools/archive_compare_service.dart';
import 'package:utility_tool/features/file_tools/file_zip_utils.dart';
import 'package:utility_tool/features/file_tools/media_tools_screen.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('ZIP creation', () {
    test('round trip keeps every file, including duplicate names', () {
      final zip = FileZipUtils.createZip([
        MapEntry('photo.jpg', _b('first')),
        MapEntry('photo.jpg', _b('second')),
        MapEntry('notes', _b('third')),
        MapEntry('notes', _b('fourth')),
      ]);
      final decoded = ZipDecoder().decodeBytes(zip);
      final byName = {for (final f in decoded.files) f.name: utf8.decode(f.content)};
      expect(byName, {
        'photo.jpg': 'first',
        'photo (2).jpg': 'second',
        'notes': 'third',
        'notes (2)': 'fourth',
      });
    });

    test('empty files survive the round trip', () {
      final zip = FileZipUtils.createZip([MapEntry('empty.txt', Uint8List(0))]);
      final decoded = ZipDecoder().decodeBytes(zip);
      expect(decoded.files.single.name, 'empty.txt');
      expect(decoded.files.single.content, isEmpty);
    });

    test('compression stats never divide by zero', () {
      expect(FileZipUtils.compressionSavingsPercent(0, 22), 0);
      expect(FileZipUtils.compressionSavingsPercent(1000, 250), closeTo(75, 1e-9));
      expect(FileZipUtils.compressionSavingsPercent(10, 120), lessThan(0));
    });
  });

  group('Path safety (zip-slip)', () {
    test('sanitizeEntryPath drops traversal, absolute and drive segments', () {
      expect(FileZipUtils.sanitizeEntryPath('../../etc/passwd'), 'etc/passwd');
      expect(FileZipUtils.sanitizeEntryPath('/abs/file.txt'), 'abs/file.txt');
      expect(FileZipUtils.sanitizeEntryPath(r'C:\Windows\..\evil.dll'), 'Windows/evil.dll');
      expect(FileZipUtils.sanitizeEntryPath('dir/./a.txt'), 'dir/a.txt');
      expect(FileZipUtils.sanitizeEntryPath('../'), '');
    });

    test('safeFileName returns a bare name for sharing', () {
      expect(FileZipUtils.safeFileName('docs/sub/report.pdf'), 'report.pdf');
      expect(FileZipUtils.safeFileName('../../x.txt'), 'x.txt');
      expect(FileZipUtils.safeFileName('a:b?.txt'), 'a_b_.txt');
      expect(FileZipUtils.safeFileName('dir/'), 'dir');
      expect(FileZipUtils.safeFileName('..'), 'file');
    });

    test('extractTar strips traversal from malicious entry names', () {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('../../evil.sh', _b('rm -rf')))
        ..addFile(ArchiveFile.bytes('ok/file.txt', _b('fine')));
      final tar = Uint8List.fromList(TarEncoder().encode(archive));
      final names = ArchiveCompareService.extractTar(tar).map((e) => e.name).toList();
      expect(names, ['evil.sh', 'ok/file.txt']);
    });

    test('createTar keeps duplicate-named entries', () {
      final tar = ArchiveCompareService.createTar([
        ArchiveEntry(name: 'a.txt', bytes: _b('1')),
        ArchiveEntry(name: 'a.txt', bytes: _b('2')),
      ]);
      final extracted = ArchiveCompareService.extractTar(tar);
      expect(extracted.map((e) => e.name), ['a.txt', 'a (2).txt']);
      expect(extracted.map((e) => utf8.decode(e.bytes)), ['1', '2']);
    });
  });

  group('Batch renamer', () {
    test('hidden files keep their name instead of becoming an extension', () {
      expect(FileZipUtils.computeRenamedName('.gitignore', 0, prefix: 'x_'), 'x_.gitignore');
    });

    test('Title Case capitalises space- and dash-separated words', () {
      expect(
        FileZipUtils.computeRenamedName('my holiday-photo.JPG', 0, caseMode: 'Title Case'),
        'My Holiday-Photo.JPG',
      );
    });

    test('numbering and find/replace', () {
      expect(
        FileZipUtils.computeRenamedName('IMG_1.png', 4, find: 'IMG', replace: 'Trip', addNumbering: true),
        'Trip_1_005.png',
      );
    });

    test('a name emptied by find/replace falls back to "file"', () {
      expect(FileZipUtils.computeRenamedName('abc.txt', 0, find: 'abc'), 'file.txt');
    });
  });

  group('JSON to CSV rows', () {
    test('array of objects uses a union header in first-seen order', () {
      final rows = FileZipUtils.jsonToCsvRows(jsonDecode('[{"a":1,"b":2},{"b":3,"c":null}]'));
      expect(rows, [
        ['a', 'b', 'c'],
        [1, 2, ''],
        ['', 3, ''],
      ]);
    });

    test('single object and nested values are handled', () {
      final rows = FileZipUtils.jsonToCsvRows(jsonDecode('{"id":1,"tags":["x","y"]}'));
      expect(rows, [
        ['id', 'tags'],
        [1, '["x","y"]'],
      ]);
    });

    test('non-object JSON is rejected instead of silently ignored', () {
      expect(() => FileZipUtils.jsonToCsvRows(jsonDecode('[1,2]')), throwsFormatException);
      expect(() => FileZipUtils.jsonToCsvRows(jsonDecode('"text"')), throwsFormatException);
    });
  });

  group('MIME detection', () {
    test('magic bytes win over a wrong extension', () {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]);
      expect(FileZipUtils.detectMimeType(png, 'TXT'), 'image/png');
      expect(FileZipUtils.detectMimeType(_b('%PDF-1.7'), 'bin'), 'application/pdf');
      expect(FileZipUtils.detectMimeType(Uint8List.fromList([0x1F, 0x8B, 8]), 'dat'), 'application/gzip');
    });

    test('ZIP-based office files use their extension; unknowns fall back', () {
      final zipSig = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0]);
      expect(FileZipUtils.detectMimeType(zipSig, 'DOCX'), contains('wordprocessingml'));
      expect(FileZipUtils.detectMimeType(zipSig, 'ZIP'), 'application/zip');
      expect(FileZipUtils.detectMimeType(Uint8List(0), 'FILE'), 'application/octet-stream');
      expect(FileZipUtils.detectMimeType(_b('a,b'), 'csv'), 'text/csv');
    });
  });

  group('Diff and RAR inspection fixes', () {
    test('equal-length but different binary files are not a 100% match', () {
      final a = Uint8List.fromList([0, 1, 2, 3]);
      final b = Uint8List.fromList([0, 9, 9, 3]);
      final diff = ArchiveCompareService.compareFileContents('a', a, 'b', b);
      expect(diff.isBinary, isTrue);
      expect(diff.similarityPercent, closeTo(50, 1e-9));
    });

    test('RAR5 archive flags are read from the vint main header', () {
      final rar5 = Uint8List(32);
      rar5.setAll(0, [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]);
      // CRC32 at 8..11, then header size, type 1 (main), header flags 0, archive flags.
      rar5.setAll(12, [0x03, 0x01, 0x00, 0x05]);
      final info = ArchiveCompareService.inspectRarArchive(rar5);
      expect(info.isSolid, isTrue);
      expect(info.isMultiVolume, isTrue);

      // A non-zero CRC byte at offset 10 used to be misread as the flags.
      final crcOnly = Uint8List(32)..setAll(0, [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]);
      crcOnly[10] = 0xFF;
      final info2 = ArchiveCompareService.inspectRarArchive(crcOnly);
      expect(info2.isSolid, isFalse);
      expect(info2.isMultiVolume, isFalse);
    });

    test('RAR4 encrypted-headers flag is reported', () {
      final rar4 = Uint8List(32)..setAll(0, [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00, 0, 0, 0x73, 0x80, 0x00]);
      expect(ArchiveCompareService.inspectRarArchive(rar4).isEncrypted, isTrue);
    });
  });

  group('Streamed hashing', () {
    test('hashStream matches one-shot digests however the bytes are chunked', () async {
      final data = Uint8List.fromList(List.generate(10000, (i) => (i * 31 + 7) % 256));
      final chunked = Stream<List<int>>.fromIterable([data.sublist(0, 1), data.sublist(1, 4097), data.sublist(4097)]);
      final h = await FileZipUtils.hashStream(chunked);
      expect(h['md5'], md5.convert(data).toString());
      expect(h['sha1'], sha1.convert(data).toString());
      expect(h['sha256'], sha256.convert(data).toString());
      expect(h['sha512'], sha512.convert(data).toString());
    });

    test('empty stream and a single algorithm work', () async {
      final h = await FileZipUtils.hashStream(const Stream<List<int>>.empty(), ['sha256']);
      expect(h.keys, ['sha256']);
      expect(h['sha256'], sha256.convert(const <int>[]).toString());
    });

    test('hashFileInBackground reads a file on another isolate', () async {
      final dir = Directory.systemTemp.createTempSync('hash_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/a.bin')..writeAsBytesSync(List.generate(200000, (i) => i % 251));
      final h = await FileZipUtils.hashFileInBackground(file.path, ['md5', 'sha256']);
      expect(h['md5'], md5.convert(file.readAsBytesSync()).toString());
      expect(h['sha256'], sha256.convert(file.readAsBytesSync()).toString());
    });

    test('readHead stops after the requested bytes', () async {
      var pulled = 0;
      Stream<List<int>> source() async* {
        for (var i = 0; i < 100; i++) {
          pulled++;
          yield List.filled(1000, i);
        }
      }

      final head = await FileZipUtils.readHead(source(), 2500);
      expect(head.length, 2500);
      expect(pulled, lessThan(10));
      expect(await FileZipUtils.readHead(Stream.value([1, 2, 3]), 16), [1, 2, 3]);
    });

    test('createZipInBackground gives the same entries as createZip', () async {
      final files = [MapEntry('a.txt', _b('alpha')), MapEntry('a.txt', _b('beta'))];
      final zip = await FileZipUtils.createZipInBackground(files);
      final names = ZipDecoder().decodeBytes(zip).files.map((f) => f.name).toList();
      expect(names, ['a.txt', 'a (2).txt']);
    });
  });

  group('WAV trimmer', () {
    // 16-bit mono ramp: sample i has value i, so a trimmed slice can be checked byte for byte.
    Uint8List wav({int rate = 1000, int channels = 1, int bits = 16, int frames = 3000, int format = 1, bool listChunk = false, int? declaredData}) {
      final blockAlign = channels * bits ~/ 8;
      final dataLen = frames * blockAlign;
      final b = BytesBuilder();
      void u32(int v) => b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
      void u16(int v) => b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
      b.add('RIFF'.codeUnits);
      u32(0); // patched below
      b.add('WAVE'.codeUnits);
      b.add('fmt '.codeUnits);
      u32(16);
      u16(format);
      u16(channels);
      u32(rate);
      u32(rate * blockAlign);
      u16(blockAlign);
      u16(bits);
      if (listChunk) {
        b.add('LIST'.codeUnits);
        u32(5);
        b.add([1, 2, 3, 4, 5, 0]); // odd-sized chunk plus its pad byte
      }
      b.add('data'.codeUnits);
      u32(declaredData ?? dataLen);
      final data = ByteData(dataLen);
      for (var i = 0; i < frames * channels; i++) {
        if (bits == 16) data.setInt16(i * 2, i % 30000, Endian.little);
      }
      b.add(data.buffer.asUint8List());
      final out = b.toBytes();
      ByteData.sublistView(out).setUint32(4, out.length - 8, Endian.little);
      return out;
    }

    test('parseWav reads format and exact duration', () {
      final info = parseWav(wav(rate: 8000, channels: 2, frames: 24000))!;
      expect(info.sampleRate, 8000);
      expect(info.channels, 2);
      expect(info.bitsPerSample, 16);
      expect(info.blockAlign, 4);
      expect(info.durationSeconds, 3.0);
    });

    test('parseWav skips extra chunks (odd sized, padded) before data', () {
      final info = parseWav(wav(listChunk: true))!;
      expect(info.durationSeconds, 3.0);
    });

    test('parseWav rejects non-WAV, compressed and header-less data', () {
      expect(parseWav(_b('not a wav file at all')), isNull);
      expect(parseWav(wav(format: 2)), isNull); // ADPCM has no sample-accurate frames
      expect(parseWav(Uint8List(5)), isNull);
      final noData = wav().sublist(0, 36); // RIFF + fmt only
      expect(parseWav(noData), isNull);
    });

    test('a data chunk that claims more than the file holds is clamped to what is there', () {
      final b = wav(frames: 1000, declaredData: 0xFFFFFFFF);
      final info = parseWav(b)!;
      expect(info.frames, 1000);
    });

    test('trimWav returns a valid WAV holding exactly the chosen seconds', () {
      final original = wav(); // 1000 Hz, 3 s, sample i = i
      final info = parseWav(original)!;
      final trimmed = trimWav(original, info, 1.0, 2.5);
      final out = parseWav(trimmed)!;
      expect(out.sampleRate, 1000);
      expect(out.durationSeconds, 1.5);
      expect(ByteData.sublistView(trimmed).getUint32(4, Endian.little), trimmed.length - 8);
      // First sample of the slice is sample 1000 of the source.
      expect(ByteData.sublistView(trimmed).getInt16(out.dataOffset, Endian.little), 1000);
      expect(ByteData.sublistView(trimmed).getInt16(out.dataOffset + (out.frames - 1) * 2, Endian.little), 2499);
    });

    test('trimWav clamps out-of-range times and keeps extra header chunks and RIFF padding valid', () {
      final original = wav(listChunk: true, frames: 1001, bits: 8);
      final info = parseWav(original)!;
      final trimmed = trimWav(original, info, -5, 99);
      final out = parseWav(trimmed)!;
      expect(out.frames, 1001);
      expect(trimmed.length.isEven, isTrue); // odd data length is padded
      expect(ByteData.sublistView(trimmed).getUint32(4, Endian.little), trimmed.length - 8);
      final empty = parseWav(trimWav(original, info, 2.0, 2.0));
      expect(empty!.frames, 0);
    });

    test('wavPeaks follows the loudness of the audio', () {
      final b = BytesBuilder();
      // 1 s silence then 1 s full-scale square wave, 16-bit mono at 1000 Hz.
      final raw = ByteData(4000);
      for (var i = 1000; i < 2000; i++) {
        raw.setInt16(i * 2, i.isEven ? 32767 : -32768, Endian.little);
      }
      final base = wav(frames: 2000);
      b.add(base.sublist(0, 44));
      b.add(raw.buffer.asUint8List());
      final bytes = b.toBytes();
      ByteData.sublistView(bytes).setUint32(40, 4000, Endian.little);
      final peaks = wavPeaks(bytes, parseWav(bytes)!, 4);
      expect(peaks[0], 0);
      expect(peaks[1], 0);
      expect(peaks[2], greaterThan(0.9));
      expect(peaks[3], greaterThan(0.9));
    });

    test('clock helpers parse and format times', () {
      expect(parseClock('90'), 90);
      expect(parseClock('1:30'), 90);
      expect(parseClock('1:02:03'), 3723);
      expect(parseClock('0:30.5'), 30.5);
      expect(parseClock('abc'), isNull);
      expect(parseClock('1:2:3:4'), isNull);
      expect(parseClock('-5'), isNull);
      expect(formatClock(75), '01:15');
      expect(formatClock(75.34, tenths: true), '01:15.3');
      expect(formatClock(3723), '1:02:03');
      expect(formatClock(-3), '00:00');
    });

    test('video size estimate is bitrate x time plus the audio track', () {
      // 100 s at 2000 kbps video + 128 kbps audio = 26.6 MB.
      expect(estimateVideoSizeMb(100, 2000), closeTo(26.6, 0.01));
      expect(estimateVideoSizeMb(0, 5000), 0);
    });

    test('withWavExtension swaps or adds the extension', () {
      expect(withWavExtension('song.mp3'), 'song.wav');
      expect(withWavExtension('take 1.WAV'), 'take 1.wav');
      expect(withWavExtension('noext'), 'noext.wav');
    });
  });
}
