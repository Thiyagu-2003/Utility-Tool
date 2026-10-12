import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Pure helpers behind the File & ZIP Suite, kept out of the widget so they
/// can be unit tested.
class FileZipUtils {
  /// Normalises an archive entry path so it can never escape an output
  /// directory (zip-slip): backslashes become '/', and empty, '.', '..' and
  /// drive-letter segments are dropped. Returns '' if nothing usable is left.
  static String sanitizeEntryPath(String name) {
    final parts = name
        .replaceAll('\\', '/')
        .split('/')
        .where((s) => s.isNotEmpty && s != '.' && s != '..' && !RegExp(r'^[A-Za-z]:$').hasMatch(s));
    return parts.join('/');
  }

  /// A single safe file name (no directories, no reserved characters).
  static String safeFileName(String name, {String fallback = 'file'}) {
    final base = sanitizeEntryPath(name).split('/').last.replaceAll(RegExp(r'[:*?"<>|\x00-\x1F]'), '_').trim();
    return base.isEmpty ? fallback : base;
  }

  /// Returns [name], or `name (2).ext`, `name (3).ext`… if it is already in
  /// [taken]. The returned name is added to [taken].
  static String uniqueName(String name, Set<String> taken) {
    var candidate = name;
    var n = 2;
    while (taken.contains(candidate)) {
      final slash = name.lastIndexOf('/');
      final dot = name.lastIndexOf('.');
      candidate = dot > slash + 1
          ? '${name.substring(0, dot)} ($n)${name.substring(dot)}'
          : '$name ($n)';
      n++;
    }
    taken.add(candidate);
    return candidate;
  }

  /// Builds a ZIP from (name, bytes) pairs. Duplicate names are renamed
  /// instead of silently overwriting each other (Archive.add replaces).
  static Uint8List createZip(List<MapEntry<String, Uint8List>> files) {
    final archive = Archive();
    final taken = <String>{};
    for (final f in files) {
      final name = uniqueName(safeFileName(f.key), taken);
      archive.addFile(ArchiveFile.bytes(name, f.value));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static const hashAlgorithms = ['md5', 'sha1', 'sha256', 'sha512'];

  /// Hex digests of a byte stream, computed chunk by chunk in a single pass so
  /// a large file is never held in memory. [algorithms] picks from
  /// [hashAlgorithms].
  static Future<Map<String, String>> hashStream(
    Stream<List<int>> chunks, [
    List<String> algorithms = hashAlgorithms,
  ]) async {
    const hashes = {'md5': md5, 'sha1': sha1, 'sha256': sha256, 'sha512': sha512};
    final sinks = {for (final a in algorithms) a: _DigestSink()};
    final inputs = [for (final a in algorithms) hashes[a]!.startChunkedConversion(sinks[a]!)];
    await for (final chunk in chunks) {
      for (final input in inputs) {
        input.add(chunk);
      }
    }
    for (final input in inputs) {
      input.close();
    }
    return {for (final a in algorithms) a: sinks[a]!.digest.toString()};
  }

  /// The first [count] bytes of [chunks] (fewer if the stream is shorter); the rest is never read.
  static Future<Uint8List> readHead(Stream<List<int>> chunks, int count) async {
    final out = BytesBuilder(copy: false);
    await for (final chunk in chunks) {
      out.add(chunk);
      if (out.length >= count) break;
    }
    final all = out.takeBytes();
    return all.length <= count ? all : Uint8List.sublistView(all, 0, count);
  }

  // The background helpers below are static on purpose: an isolate closure created
  // inside a State/instance method can capture `this` and then fail to send.

  /// [createZip] on a background isolate, so deflating many MB doesn't freeze the UI.
  static Future<Uint8List> createZipInBackground(List<MapEntry<String, Uint8List>> files) =>
      Isolate.run(() => createZip(files));

  /// [hashStream] over the file at [path], read and hashed on a background isolate.
  static Future<Map<String, String>> hashFileInBackground(String path, [List<String> algorithms = hashAlgorithms]) =>
      Isolate.run(() => hashStream(File(path).openRead(), algorithms));

  /// Percentage of space saved; 0 when the original is empty. Negative when
  /// the output grew (common for tiny or already-compressed inputs).
  static double compressionSavingsPercent(int originalBytes, int compressedBytes) {
    if (originalBytes <= 0) return 0;
    return (1 - compressedBytes / originalBytes) * 100;
  }

  static const renameCaseModes = ['Keep Original', 'lowercase', 'UPPERCASE', 'Title Case'];

  /// Batch-rename rule: find/replace, prefix/suffix, optional _NNN numbering
  /// and case change on the base name; the extension is kept as is.
  static String computeRenamedName(
    String origName,
    int index, {
    String prefix = '',
    String suffix = '',
    String find = '',
    String replace = '',
    String caseMode = 'Keep Original',
    bool addNumbering = false,
  }) {
    var nameWithoutExt = origName;
    var ext = '';
    final lastDot = origName.lastIndexOf('.');
    // A leading dot (".gitignore") is a hidden file, not an extension.
    if (lastDot > 0) {
      nameWithoutExt = origName.substring(0, lastDot);
      ext = origName.substring(lastDot);
    }

    var result = nameWithoutExt;
    if (find.isNotEmpty) result = result.replaceAll(find, replace);
    result = '$prefix$result$suffix';
    if (addNumbering) result = '${result}_${(index + 1).toString().padLeft(3, '0')}';

    if (caseMode == 'lowercase') {
      result = result.toLowerCase();
    } else if (caseMode == 'UPPERCASE') {
      result = result.toUpperCase();
    } else if (caseMode == 'Title Case') {
      result = result.replaceAllMapped(
        RegExp(r'[^\s_\-.]+'),
        (m) => '${m[0]![0].toUpperCase()}${m[0]!.substring(1).toLowerCase()}',
      );
    }

    if (result.trim().isEmpty) result = 'file';
    return '$result$ext';
  }

  /// Converts decoded JSON (an array of objects, or a single object) into CSV
  /// rows with a union header. Nested values are written as JSON text.
  static List<List<dynamic>> jsonToCsvRows(dynamic decoded) {
    final List<dynamic> items = decoded is Map ? [decoded] : (decoded is List ? decoded : throw const FormatException('Expected a JSON array of objects'));
    final maps = items.whereType<Map>().toList();
    if (maps.isEmpty) throw const FormatException('Expected a JSON array of objects');

    final headers = <String>[];
    for (final m in maps) {
      for (final k in m.keys) {
        final key = k.toString();
        if (!headers.contains(key)) headers.add(key);
      }
    }
    return [
      headers,
      for (final m in maps)
        headers.map((k) {
          final v = m[k];
          if (v == null) return '';
          if (v is Map || v is List) return jsonEncode(v);
          return v;
        }).toList(),
    ];
  }

  /// MIME type from magic bytes first, falling back to the extension.
  static String detectMimeType(Uint8List bytes, String extension) {
    bool starts(List<int> sig, [int offset = 0]) {
      if (bytes.length < offset + sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (bytes[offset + i] != sig[i]) return false;
      }
      return true;
    }

    final ext = extension.toLowerCase();
    const officeZip = {
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'apk': 'application/vnd.android.package-archive',
      'jar': 'application/java-archive',
      'epub': 'application/epub+zip',
    };

    if (starts([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'image/png';
    if (starts([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (starts([0x47, 0x49, 0x46, 0x38])) return 'image/gif';
    if (starts([0x52, 0x49, 0x46, 0x46]) && starts([0x57, 0x45, 0x42, 0x50], 8)) return 'image/webp';
    if (starts([0x52, 0x49, 0x46, 0x46]) && starts([0x57, 0x41, 0x56, 0x45], 8)) return 'audio/wav';
    if (starts([0x42, 0x4D])) return 'image/bmp';
    if (starts([0x25, 0x50, 0x44, 0x46])) return 'application/pdf';
    if (starts([0x50, 0x4B, 0x03, 0x04]) || starts([0x50, 0x4B, 0x05, 0x06])) {
      return officeZip[ext] ?? 'application/zip';
    }
    if (starts([0x1F, 0x8B])) return 'application/gzip';
    if (starts([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])) return 'application/x-7z-compressed';
    if (starts([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07])) return 'application/vnd.rar';
    if (starts([0x49, 0x44, 0x33]) || starts([0xFF, 0xFB]) || starts([0xFF, 0xF3]) || starts([0xFF, 0xF2])) return 'audio/mpeg';
    if (starts([0x4F, 0x67, 0x67, 0x53])) return 'audio/ogg';
    if (starts([0x66, 0x4C, 0x61, 0x43])) return 'audio/flac';
    if (starts([0x66, 0x74, 0x79, 0x70], 4)) return ext == 'm4a' ? 'audio/mp4' : 'video/mp4';

    const byExt = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
      'pdf': 'application/pdf',
      'zip': 'application/zip',
      'csv': 'text/csv',
      'json': 'application/json',
      'txt': 'text/plain',
      'md': 'text/markdown',
      'html': 'text/html',
      'htm': 'text/html',
      'xml': 'application/xml',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
    };
    return byExt[ext] ?? officeZip[ext] ?? 'application/octet-stream';
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest digest;
  @override
  void add(Digest data) => digest = data;
  @override
  void close() {}
}
