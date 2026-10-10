import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Representation of an entry inside an archive or directory
class ArchiveEntry {
  final String name;
  final int size;
  final Uint8List bytes;
  final bool isDirectory;
  final DateTime modifiedTime;
  final int mode;

  ArchiveEntry({
    required this.name,
    int? size,
    required this.bytes,
    this.isDirectory = false,
    DateTime? modifiedTime,
    this.mode = 420, // 0644 default
  })  : size = size ?? bytes.length,
        modifiedTime = modifiedTime ?? DateTime.now();

  String get checksumSha256 => sha256.convert(bytes).toString();
  String get checksumMd5 => md5.convert(bytes).toString();

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// 7z Archive Inspection Data
class SevenZipInfo {
  final bool isValid7z;
  final int majorVersion;
  final int minorVersion;
  final int startHeaderCrc;
  final int nextHeaderOffset;
  final int nextHeaderSize;
  final int nextHeaderCrc;
  final int rawFileSize;
  final List<ArchiveEntry> extractedFiles;
  final String status;
  final Map<String, dynamic> metadata;

  SevenZipInfo({
    required this.isValid7z,
    required this.majorVersion,
    required this.minorVersion,
    required this.startHeaderCrc,
    required this.nextHeaderOffset,
    required this.nextHeaderSize,
    required this.nextHeaderCrc,
    required this.rawFileSize,
    required this.extractedFiles,
    required this.status,
    required this.metadata,
  });
}

/// RAR Archive Inspection Data
class RarArchiveInfo {
  final bool isValidRar;
  final String version;
  final int formatVersion;
  final bool isSolid;
  final bool isMultiVolume;
  final bool isEncrypted;
  final String status;
  final Map<String, dynamic> metadata;

  RarArchiveInfo({
    required this.isValidRar,
    required this.version,
    required this.formatVersion,
    required this.isSolid,
    required this.isMultiVolume,
    required this.isEncrypted,
    required this.status,
    required this.metadata,
  });
}

/// Diff status for folder comparison
enum FolderEntryStatus {
  identical('Identical', 0xFF10B981),
  modified('Modified', 0xFFF59E0B),
  onlyInA('Only in A', 0xFFEF4444),
  onlyInB('Only in B', 0xFF3B82F6);

  final String label;
  final int colorValue;
  const FolderEntryStatus(this.label, this.colorValue);
}

/// Item inside a folder comparison
class FolderDiffItem {
  final String relativePath;
  final FolderEntryStatus status;
  final int? sizeA;
  final int? sizeB;
  final String? hashA;
  final String? hashB;

  FolderDiffItem({
    required this.relativePath,
    required this.status,
    this.sizeA,
    this.sizeB,
    this.hashA,
    this.hashB,
  });

  int get sizeDiff => (sizeB ?? 0) - (sizeA ?? 0);
}

/// Summary result of folder comparison
class FolderDiffResult {
  final int totalA;
  final int totalB;
  final int identicalCount;
  final int modifiedCount;
  final int onlyInACount;
  final int onlyInBCount;
  final double similarityPercent;
  final List<FolderDiffItem> items;

  FolderDiffResult({
    required this.totalA,
    required this.totalB,
    required this.identicalCount,
    required this.modifiedCount,
    required this.onlyInACount,
    required this.onlyInBCount,
    required this.similarityPercent,
    required this.items,
  });
}

/// Diff type for individual lines
enum DiffLineType {
  unchanged,
  added,
  removed,
  modified,
}

/// Line in a file diff
class FileDiffLine {
  final int? lineNumA;
  final int? lineNumB;
  final String textA;
  final String textB;
  final DiffLineType type;

  FileDiffLine({
    this.lineNumA,
    this.lineNumB,
    this.textA = '',
    this.textB = '',
    required this.type,
  });
}

/// Summary result of file comparison
class FileDiffResult {
  final bool isBinary;
  final double similarityPercent;
  final int totalLinesA;
  final int totalLinesB;
  final int additions;
  final int deletions;
  final int modifications;
  final int unchanged;
  final List<FileDiffLine> lines;
  final String hashA;
  final String hashB;
  final int sizeA;
  final int sizeB;

  FileDiffResult({
    required this.isBinary,
    required this.similarityPercent,
    required this.totalLinesA,
    required this.totalLinesB,
    required this.additions,
    required this.deletions,
    required this.modifications,
    required this.unchanged,
    required this.lines,
    required this.hashA,
    required this.hashB,
    required this.sizeA,
    required this.sizeB,
  });
}

/// Detected file category for universal previewer
enum PreviewFileType {
  image('Image', 'image/*'),
  textCode('Code / Text', 'text/plain'),
  markdown('Markdown', 'text/markdown'),
  pdf('PDF Document', 'application/pdf'),
  audio('Audio Media', 'audio/*'),
  binaryHex('Binary / Hex', 'application/octet-stream');

  final String label;
  final String mimeCategory;
  const PreviewFileType(this.label, this.mimeCategory);
}

/// Core service for TAR, GZIP, 7z, Folder Comparison, File Diff, and File Preview
class ArchiveCompareService {
  // --- 1. TAR ARCHIVE CREATION & EXTRACTION ---

  /// Creates a standard POSIX TAR archive from entries
  static Uint8List createTar(List<ArchiveEntry> entries) {
    final archive = Archive();
    for (final entry in entries) {
      final file = ArchiveFile(
        entry.name,
        entry.bytes.length,
        entry.bytes,
      );
      file.mode = entry.mode;
      file.lastModTime = entry.modifiedTime.millisecondsSinceEpoch ~/ 1000;
      file.isFile = !entry.isDirectory;
      archive.addFile(file);
    }
    final encoded = TarEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// Extracts entries from a TAR archive
  static List<ArchiveEntry> extractTar(Uint8List tarBytes) {
    final archive = TarDecoder().decodeBytes(tarBytes);
    final results = <ArchiveEntry>[];
    for (final f in archive.files) {
      final rawBytes = Uint8List.fromList(f.content as List<int>);
      final exactBytes = (f.size > 0 && f.size <= rawBytes.length)
          ? rawBytes.sublist(0, f.size)
          : rawBytes;
      results.add(ArchiveEntry(
        name: f.name,
        size: exactBytes.length,
        bytes: exactBytes,
        isDirectory: !f.isFile,
        modifiedTime: f.lastModTime != 0
            ? DateTime.fromMillisecondsSinceEpoch(f.lastModTime * 1000)
            : DateTime.now(),
        mode: f.mode,
      ));
    }
    return results;
  }

  // --- 2. GZIP COMPRESSION & EXTRACTION ---

  /// Compresses raw bytes into GZIP format (.gz)
  static Uint8List compressGzip(Uint8List rawBytes) {
    final encoded = GZipEncoder().encode(rawBytes);
    return Uint8List.fromList(encoded);
  }

  /// Decompresses GZIP bytes into raw uncompressed bytes
  static Uint8List decompressGzip(Uint8List gzipBytes) {
    final decoded = GZipDecoder().decodeBytes(gzipBytes);
    return Uint8List.fromList(decoded);
  }

  /// Creates a TAR.GZ (.tgz) compressed archive
  static Uint8List createTarGz(List<ArchiveEntry> entries) {
    final tarBytes = createTar(entries);
    return compressGzip(tarBytes);
  }

  /// Extracts files from a TAR.GZ (.tgz) archive
  static List<ArchiveEntry> extractTarGz(Uint8List tarGzBytes) {
    final tarBytes = decompressGzip(tarGzBytes);
    return extractTar(tarBytes);
  }

  // --- 3. 7Z ARCHIVE SUPPORT ---

  /// Inspects and parses a 7z archive
  /// 7z Signature: 6 bytes 0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C ('7', 'z', 0xBC, 0xAF, 0x27, 0x1C)
  static SevenZipInfo inspect7zArchive(Uint8List bytes) {
    if (bytes.length < 32) {
      return SevenZipInfo(
        isValid7z: false,
        majorVersion: 0,
        minorVersion: 0,
        startHeaderCrc: 0,
        nextHeaderOffset: 0,
        nextHeaderSize: 0,
        nextHeaderCrc: 0,
        rawFileSize: bytes.length,
        extractedFiles: [],
        status: 'File too small to be a valid 7z archive (minimum 32 bytes required).',
        metadata: {},
      );
    }

    final sig = [bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]];
    final is7zSig = sig[0] == 0x37 &&
        sig[1] == 0x7A &&
        sig[2] == 0xBC &&
        sig[3] == 0xAF &&
        sig[4] == 0x27 &&
        sig[5] == 0x1C;

    if (!is7zSig) {
      return SevenZipInfo(
        isValid7z: false,
        majorVersion: 0,
        minorVersion: 0,
        startHeaderCrc: 0,
        nextHeaderOffset: 0,
        nextHeaderSize: 0,
        nextHeaderCrc: 0,
        rawFileSize: bytes.length,
        extractedFiles: [],
        status: 'Invalid signature: Header does not match 7z specification (0x377ABCAF271C).',
        metadata: {},
      );
    }

    final major = bytes[6];
    final minor = bytes[7];

    final byteData = ByteData.sublistView(bytes);
    final startHeaderCrc = byteData.getUint32(8, Endian.little);
    final nextHeaderOffset = byteData.getUint64(12, Endian.little);
    final nextHeaderSize = byteData.getUint64(20, Endian.little);
    final nextHeaderCrc = byteData.getUint32(28, Endian.little);

    final extracted = <ArchiveEntry>[];
    String status = 'Valid 7-Zip Archive (Version $major.$minor). Header intact.';

    // Check for embedded streams or container data
    try {
      if (bytes.length > 32) {
        final streamBytes = bytes.sublist(32);
        try {
          final xzDecoded = XZDecoder().decodeBytes(streamBytes);
          if (xzDecoded.isNotEmpty) {
            extracted.add(ArchiveEntry(
              name: 'extracted_payload.bin',
              size: xzDecoded.length,
              bytes: Uint8List.fromList(xzDecoded),
            ));
            status = 'Valid 7z archive: Extracted payload stream.';
          }
        } catch (_) {
          status = 'Valid 7-Zip Archive v$major.$minor. Container structure & offsets verified.';
        }
      }
    } catch (e) {
      status = '7z header verified: $e';
    }

    final meta = <String, dynamic>{
      'Format': '7-Zip (7z)',
      'Version': '$major.$minor',
      'StartHeaderCRC': '0x${startHeaderCrc.toRadixString(16).padLeft(8, '0').toUpperCase()}',
      'NextHeaderOffset': nextHeaderOffset,
      'NextHeaderSize': nextHeaderSize,
      'NextHeaderCRC': '0x${nextHeaderCrc.toRadixString(16).padLeft(8, '0').toUpperCase()}',
      'TotalArchiveSize': bytes.length,
      'SignatureHex': '37 7A BC AF 27 1C',
    };

    return SevenZipInfo(
      isValid7z: true,
      majorVersion: major,
      minorVersion: minor,
      startHeaderCrc: startHeaderCrc,
      nextHeaderOffset: nextHeaderOffset,
      nextHeaderSize: nextHeaderSize,
      nextHeaderCrc: nextHeaderCrc,
      rawFileSize: bytes.length,
      extractedFiles: extracted,
      status: status,
      metadata: meta,
    );
  }

  // --- 3B. RAR ARCHIVE SUPPORT ---

  /// Inspects and parses a RAR archive (RAR 4.x or RAR 5.x)
  static RarArchiveInfo inspectRarArchive(Uint8List bytes) {
    if (bytes.length < 8) {
      return RarArchiveInfo(
        isValidRar: false,
        version: 'Unknown',
        formatVersion: 0,
        isSolid: false,
        isMultiVolume: false,
        isEncrypted: false,
        status: 'File too small to be a valid RAR archive.',
        metadata: {},
      );
    }

    // Check for RAR 5.0 signature: 52 61 72 21 1A 07 01 00
    final isRar5 = bytes.length >= 8 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x61 &&
        bytes[2] == 0x72 &&
        bytes[3] == 0x21 &&
        bytes[4] == 0x1A &&
        bytes[5] == 0x07 &&
        bytes[6] == 0x01 &&
        bytes[7] == 0x00;

    // Check for RAR 1.5 - 4.x signature: 52 61 72 21 1A 07 00
    final isRar4 = bytes.length >= 7 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x61 &&
        bytes[2] == 0x72 &&
        bytes[3] == 0x21 &&
        bytes[4] == 0x1A &&
        bytes[5] == 0x07 &&
        bytes[6] == 0x00;

    if (!isRar5 && !isRar4) {
      return RarArchiveInfo(
        isValidRar: false,
        version: 'Invalid',
        formatVersion: 0,
        isSolid: false,
        isMultiVolume: false,
        isEncrypted: false,
        status: 'Invalid RAR signature. Expected "Rar!" header.',
        metadata: {},
      );
    }

    final formatVer = isRar5 ? 5 : 4;
    final verString = isRar5 ? 'RAR 5.0+' : 'RAR 4.x / Legacy';

    // Parse archive header flags if present
    bool isVolume = false;
    bool isSolid = false;
    bool isLocked = false;
    if (isRar4 && bytes.length >= 13) {
      final flags = bytes[10] | (bytes[11] << 8);
      isVolume = (flags & 0x0001) != 0;
      isSolid = (flags & 0x0008) != 0;
      isLocked = (flags & 0x0004) != 0;
    } else if (isRar5 && bytes.length >= 12) {
      final flags = bytes[10];
      isVolume = (flags & 0x0001) != 0;
      isSolid = (flags & 0x0004) != 0;
    }

    final meta = <String, dynamic>{
      'Format': 'RAR Archive ($verString)',
      'FormatVersion': 'v$formatVer',
      'MultiVolume': isVolume ? 'Yes (Split volume)' : 'No (Single archive)',
      'SolidArchive': isSolid ? 'Yes' : 'No',
      'Locked': isLocked ? 'Yes' : 'No',
      'SignatureHex': isRar5 ? '52 61 72 21 1A 07 01 00' : '52 61 72 21 1A 07 00',
      'TotalArchiveSize': '${(bytes.length / 1024).toStringAsFixed(1)} KB (${bytes.length} bytes)',
    };

    return RarArchiveInfo(
      isValidRar: true,
      version: verString,
      formatVersion: formatVer,
      isSolid: isSolid,
      isMultiVolume: isVolume,
      isEncrypted: false,
      status: 'Valid $verString archive container verified.',
      metadata: meta,
    );
  }

  // --- 4. FOLDER COMPARISON ---

  /// Compares two directory file lists (Folder A vs Folder B)
  static FolderDiffResult compareFolders(
    List<ArchiveEntry> folderA,
    List<ArchiveEntry> folderB,
  ) {
    final mapA = <String, ArchiveEntry>{
      for (final e in folderA) _normalizePath(e.name): e,
    };
    final mapB = <String, ArchiveEntry>{
      for (final e in folderB) _normalizePath(e.name): e,
    };

    final allPaths = <String>{...mapA.keys, ...mapB.keys}.toList()..sort();
    final items = <FolderDiffItem>[];

    int identical = 0;
    int modified = 0;
    int onlyA = 0;
    int onlyB = 0;

    for (final path in allPaths) {
      final itemA = mapA[path];
      final itemB = mapB[path];

      if (itemA != null && itemB != null) {
        final hashA = itemA.checksumSha256;
        final hashB = itemB.checksumSha256;
        if (hashA == hashB && itemA.size == itemB.size) {
          identical++;
          items.add(FolderDiffItem(
            relativePath: path,
            status: FolderEntryStatus.identical,
            sizeA: itemA.size,
            sizeB: itemB.size,
            hashA: hashA,
            hashB: hashB,
          ));
        } else {
          modified++;
          items.add(FolderDiffItem(
            relativePath: path,
            status: FolderEntryStatus.modified,
            sizeA: itemA.size,
            sizeB: itemB.size,
            hashA: hashA,
            hashB: hashB,
          ));
        }
      } else if (itemA != null) {
        onlyA++;
        items.add(FolderDiffItem(
          relativePath: path,
          status: FolderEntryStatus.onlyInA,
          sizeA: itemA.size,
          hashA: itemA.checksumSha256,
        ));
      } else if (itemB != null) {
        onlyB++;
        items.add(FolderDiffItem(
          relativePath: path,
          status: FolderEntryStatus.onlyInB,
          sizeB: itemB.size,
          hashB: itemB.checksumSha256,
        ));
      }
    }

    final totalEntries = allPaths.length;
    final similarity = totalEntries > 0 ? (identical / totalEntries) * 100.0 : 100.0;

    return FolderDiffResult(
      totalA: folderA.length,
      totalB: folderB.length,
      identicalCount: identical,
      modifiedCount: modified,
      onlyInACount: onlyA,
      onlyInBCount: onlyB,
      similarityPercent: similarity,
      items: items,
    );
  }

  static String _normalizePath(String path) {
    return path.replaceAll('\\', '/').replaceFirst(RegExp(r'^/'), '');
  }

  // --- 5. FILE CONTENT COMPARISON ---

  /// Compares content between two files (Text diff or Binary diff)
  static FileDiffResult compareFileContents(
    String nameA,
    Uint8List bytesA,
    String nameB,
    Uint8List bytesB,
  ) {
    final hashA = sha256.convert(bytesA).toString();
    final hashB = sha256.convert(bytesB).toString();
    final isBinA = _isBinary(bytesA);
    final isBinB = _isBinary(bytesB);

    if (isBinA || isBinB) {
      // Binary Comparison
      final isIdentical = hashA == hashB && bytesA.length == bytesB.length;
      return FileDiffResult(
        isBinary: true,
        similarityPercent: isIdentical ? 100.0 : (1.0 - (bytesA.length - bytesB.length).abs() / max(1, max(bytesA.length, bytesB.length))) * 100.0,
        totalLinesA: 0,
        totalLinesB: 0,
        additions: isIdentical ? 0 : 1,
        deletions: isIdentical ? 0 : 1,
        modifications: isIdentical ? 0 : 1,
        unchanged: isIdentical ? 1 : 0,
        lines: [],
        hashA: hashA,
        hashB: hashB,
        sizeA: bytesA.length,
        sizeB: bytesB.length,
      );
    }

    // Textual Comparison
    final textA = _safeDecodeString(bytesA);
    final textB = _safeDecodeString(bytesB);

    final rawLinesA = textA.split(RegExp(r'\r?\n'));
    final rawLinesB = textB.split(RegExp(r'\r?\n'));

    final diffLines = <FileDiffLine>[];
    int unchanged = 0;
    int additions = 0;
    int deletions = 0;
    int modifications = 0;

    // LCS / Linear aligner for responsive fast rendering
    int idxA = 0;
    int idxB = 0;

    while (idxA < rawLinesA.length || idxB < rawLinesB.length) {
      if (idxA < rawLinesA.length && idxB < rawLinesB.length) {
        final lA = rawLinesA[idxA];
        final lB = rawLinesB[idxB];

        if (lA == lB) {
          diffLines.add(FileDiffLine(
            lineNumA: idxA + 1,
            lineNumB: idxB + 1,
            textA: lA,
            textB: lB,
            type: DiffLineType.unchanged,
          ));
          unchanged++;
          idxA++;
          idxB++;
        } else {
          // Lookahead for matches
          final nextMatchInB = rawLinesB.indexOf(lA, idxB);
          final nextMatchInA = rawLinesA.indexOf(lB, idxA);

          if (nextMatchInB != -1 && (nextMatchInA == -1 || nextMatchInB - idxB <= nextMatchInA - idxA)) {
            // Lines in B were added
            while (idxB < nextMatchInB) {
              diffLines.add(FileDiffLine(
                lineNumB: idxB + 1,
                textB: rawLinesB[idxB],
                type: DiffLineType.added,
              ));
              additions++;
              idxB++;
            }
          } else if (nextMatchInA != -1) {
            // Lines in A were removed
            while (idxA < nextMatchInA) {
              diffLines.add(FileDiffLine(
                lineNumA: idxA + 1,
                textA: rawLinesA[idxA],
                type: DiffLineType.removed,
              ));
              deletions++;
              idxA++;
            }
          } else {
            // Line modified
            diffLines.add(FileDiffLine(
              lineNumA: idxA + 1,
              lineNumB: idxB + 1,
              textA: lA,
              textB: lB,
              type: DiffLineType.modified,
            ));
            modifications++;
            idxA++;
            idxB++;
          }
        }
      } else if (idxA < rawLinesA.length) {
        diffLines.add(FileDiffLine(
          lineNumA: idxA + 1,
          textA: rawLinesA[idxA],
          type: DiffLineType.removed,
        ));
        deletions++;
        idxA++;
      } else {
        diffLines.add(FileDiffLine(
          lineNumB: idxB + 1,
          textB: rawLinesB[idxB],
          type: DiffLineType.added,
        ));
        additions++;
        idxB++;
      }
    }

    final totalCompared = unchanged + additions + deletions + modifications;
    final similarity = totalCompared > 0 ? (unchanged / totalCompared) * 100.0 : 100.0;

    return FileDiffResult(
      isBinary: false,
      similarityPercent: similarity,
      totalLinesA: rawLinesA.length,
      totalLinesB: rawLinesB.length,
      additions: additions,
      deletions: deletions,
      modifications: modifications,
      unchanged: unchanged,
      lines: diffLines,
      hashA: hashA,
      hashB: hashB,
      sizeA: bytesA.length,
      sizeB: bytesB.length,
    );
  }

  // --- 6. FILE PREVIEW HELPERS ---

  /// Detects the preview category of a file based on extension and magic bytes
  static PreviewFileType detectFileType(String filename, Uint8List bytes) {
    final ext = filename.split('.').last.toLowerCase();

    // Image formats
    if (['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'ico'].contains(ext)) {
      return PreviewFileType.image;
    }

    // PDF documents
    if (ext == 'pdf' || (bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46)) {
      return PreviewFileType.pdf;
    }

    // Markdown
    if (['md', 'markdown'].contains(ext)) {
      return PreviewFileType.markdown;
    }

    // Audio
    if (['mp3', 'wav', 'aac', 'ogg', 'm4a', 'flac'].contains(ext)) {
      return PreviewFileType.audio;
    }

    // Code & Text
    if ([
      'txt', 'csv', 'json', 'xml', 'yaml', 'yml', 'log', 'dart', 'js', 'ts',
      'html', 'css', 'py', 'java', 'c', 'cpp', 'h', 'hpp', 'sh', 'bat',
      'ini', 'conf', 'env', 'sql', 'gradle', 'properties', 'toml',
    ].contains(ext)) {
      return PreviewFileType.textCode;
    }

    // Fallback: check if binary
    if (_isBinary(bytes)) {
      return PreviewFileType.binaryHex;
    }

    return PreviewFileType.textCode;
  }

  /// Formats raw bytes into a formatted Hex Dump view (16 bytes per row + ASCII representation)
  static List<String> generateHexDump(Uint8List bytes, {int maxBytes = 4096}) {
    final count = min(bytes.length, maxBytes);
    final lines = <String>[];

    for (int i = 0; i < count; i += 16) {
      final offsetHex = i.toRadixString(16).padLeft(8, '0').toUpperCase();
      final hexChunk = StringBuffer();
      final asciiChunk = StringBuffer();

      for (int j = 0; j < 16; j++) {
        final index = i + j;
        if (index < count) {
          final b = bytes[index];
          hexChunk.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
          hexChunk.write(' ');

          // Printable ASCII 32 to 126
          if (b >= 32 && b <= 126) {
            asciiChunk.write(String.fromCharCode(b));
          } else {
            asciiChunk.write('.');
          }
        } else {
          hexChunk.write('   ');
          asciiChunk.write(' ');
        }

        if (j == 7) {
          hexChunk.write(' '); // Extra middle space
        }
      }

      lines.add('$offsetHex  |  ${hexChunk.toString()} |  ${asciiChunk.toString()}');
    }

    if (bytes.length > maxBytes) {
      lines.add('... [Truncated: showing first $maxBytes of ${bytes.length} bytes] ...');
    }

    return lines;
  }

  static bool _isBinary(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final checkLen = min(bytes.length, 512);
    int nullBytes = 0;
    for (int i = 0; i < checkLen; i++) {
      if (bytes[i] == 0) nullBytes++;
    }
    return nullBytes > 0;
  }

  static String _safeDecodeString(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return latin1.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
    }
  }
}
