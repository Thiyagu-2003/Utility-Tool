import 'dart:io';
import 'dart:typed_data';

/// Pure-Dart ISO BMFF / MP4 audio extractor.
///
/// Extracts the `soun` (AAC/MP4A) audio track from an MP4 file into a valid,
/// fast-start `.m4a` file (`ftyp` + `moov` + `mdat`) without loading the full
/// video into memory.
class Mp4AudioExtractor {
  /// Extracts the audio track from [inputMp4Path] and writes a standalone M4A
  /// file to [outputM4aPath]. Throws [FormatException] if no audio track or
  /// valid MP4 structure is found.
  static Future<void> extractM4a({
    required String inputMp4Path,
    required String outputM4aPath,
  }) async {
    final raf = await File(inputMp4Path).open(mode: FileMode.read);
    try {
      final fileLen = await raf.length();
      var pos = 0;
      Uint8List? moovPayload;

      while (pos + 8 <= fileLen) {
        await raf.setPosition(pos);
        final header = await raf.read(8);
        if (header.length < 8) break;
        final bd = ByteData.sublistView(header);
        var boxSize = bd.getUint32(0);
        final boxType = _ascii4(header, 4);
        var headerLen = 8;

        if (boxSize == 1) {
          final ext = await raf.read(8);
          if (ext.length < 8) break;
          boxSize = ByteData.sublistView(ext).getUint64(0);
          headerLen = 16;
        } else if (boxSize == 0) {
          boxSize = fileLen - pos;
        }
        if (boxSize < headerLen || pos + boxSize > fileLen) break;

        if (boxType == 'moov') {
          moovPayload = await raf.read(boxSize - headerLen);
          break;
        }
        pos += boxSize;
      }

      if (moovPayload == null) {
        throw const FormatException('MP4 movie metadata (moov) not found.');
      }

      final moovChildren = _parseBoxes(moovPayload, 0, moovPayload.length);
      final mvhdBox = moovChildren.firstWhere(
        (b) => b.type == 'mvhd',
        orElse: () => throw const FormatException('MP4 mvhd header missing.'),
      );

      _ParsedBox? audioTrak;
      for (final child in moovChildren) {
        if (child.type != 'trak') continue;
        if (_isAudioTrak(child.payload)) {
          audioTrak = child;
          break;
        }
      }
      if (audioTrak == null) {
        throw const FormatException('No AAC/audio track found in MP4 file.');
      }

      // Parse audio trak chunk offsets & sample sizes to know every audio chunk
      // span in the source MP4.
      final audioChunks = _extractAudioChunkSpans(audioTrak.payload);
      if (audioChunks.isEmpty) {
        throw const FormatException('Audio track contains no media chunks.');
      }

      var totalAudioPayloadBytes = 0;
      for (final c in audioChunks) {
        totalAudioPayloadBytes += c.length;
      }

      final ftypBox = _buildM4aFtypBox();

      // Calculate exact size of the new moov box before writing so we know
      // the exact byte offset where mdat payload begins.
      final dummyMoov = _rebuildMoovWithPatchedOffsets(
        mvhdRawBox: mvhdBox.fullBox,
        audioTrakPayload: audioTrak.payload,
        newChunkOffsets: List<int>.filled(audioChunks.length, 0),
        use64BitOffsets: false,
      );

      final mdatOffset = ftypBox.length + dummyMoov.length;
      final firstChunkNewOffset = mdatOffset + 8; // 8-byte mdat header
      final maxNewOffset = firstChunkNewOffset + totalAudioPayloadBytes;
      final use64Bit = maxNewOffset > 0xFFFFFFFF;

      // If switching from stco (32-bit) to co64 (64-bit), recompute moov size.
      var moovSize = dummyMoov.length;
      if (use64Bit) {
        final probe64 = _rebuildMoovWithPatchedOffsets(
          mvhdRawBox: mvhdBox.fullBox,
          audioTrakPayload: audioTrak.payload,
          newChunkOffsets: List<int>.filled(audioChunks.length, 0),
          use64BitOffsets: true,
        );
        moovSize = probe64.length;
      }

      final actualMdatPayloadStart = ftypBox.length + moovSize + 8;
      final newOffsets = <int>[];
      var cursor = actualMdatPayloadStart;
      for (final chunk in audioChunks) {
        newOffsets.add(cursor);
        cursor += chunk.length;
      }

      final finalMoov = _rebuildMoovWithPatchedOffsets(
        mvhdRawBox: mvhdBox.fullBox,
        audioTrakPayload: audioTrak.payload,
        newChunkOffsets: newOffsets,
        use64BitOffsets: use64Bit,
      );
      assert(finalMoov.length == moovSize);

      final outFile = File(outputM4aPath);
      final out = outFile.openWrite();
      try {
        out.add(ftypBox);
        out.add(finalMoov);

        // Write mdat header (supports >4 GiB if needed, though normal M4A is 32-bit).
        final mdatSize = 8 + totalAudioPayloadBytes;
        final mdatHeader = ByteData(8)
          ..setUint32(0, mdatSize)
          ..setUint8(4, 0x6D) // 'm'
          ..setUint8(5, 0x64) // 'd'
          ..setUint8(6, 0x61) // 'a'
          ..setUint8(7, 0x74); // 't'
        out.add(mdatHeader.buffer.asUint8List());

        for (final chunk in audioChunks) {
          await raf.setPosition(chunk.offset);
          final data = await raf.read(chunk.length);
          if (data.length != chunk.length) {
            throw const FormatException('Unexpected EOF while reading audio chunk.');
          }
          out.add(data);
        }
        await out.flush();
      } finally {
        await out.close();
      }
    } finally {
      await raf.close();
    }
  }

  static bool _isAudioTrak(Uint8List trakPayload) {
    final boxes = _parseBoxes(trakPayload, 0, trakPayload.length);
    for (final b in boxes) {
      if (b.type == 'mdia') {
        final mdiaBoxes = _parseBoxes(b.payload, 0, b.payload.length);
        for (final mb in mdiaBoxes) {
          if (mb.type == 'hdlr' && mb.payload.length >= 12) {
            // hdlr full box: version(1)+flags(3)+pre_defined(4)+handler_type(4)
            final handler = _ascii4(mb.payload, 8);
            if (handler == 'soun') return true;
          }
        }
      }
    }
    return false;
  }

  static List<_ChunkSpan> _extractAudioChunkSpans(Uint8List trakPayload) {
    final stbl = _findStblPayload(trakPayload);
    if (stbl == null) return const [];

    final stblBoxes = _parseBoxes(stbl, 0, stbl.length);
    Uint8List? stscPayload;
    Uint8List? stszPayload;
    Uint8List? stcoPayload;
    Uint8List? co64Payload;

    for (final b in stblBoxes) {
      switch (b.type) {
        case 'stsc':
          stscPayload = b.payload;
          break;
        case 'stsz':
          stszPayload = b.payload;
          break;
        case 'stco':
          stcoPayload = b.payload;
          break;
        case 'co64':
          co64Payload = b.payload;
          break;
      }
    }

    if (stscPayload == null || stszPayload == null) {
      throw const FormatException('MP4 audio sample tables (stsc/stsz) missing.');
    }

    // Parse chunk offsets (stco or co64).
    final chunkOffsets = <int>[];
    if (stcoPayload != null && stcoPayload.length >= 8) {
      final bd = ByteData.sublistView(stcoPayload);
      final count = bd.getUint32(4);
      for (var i = 0; i < count && 8 + i * 4 + 4 <= stcoPayload.length; i++) {
        chunkOffsets.add(bd.getUint32(8 + i * 4));
      }
    } else if (co64Payload != null && co64Payload.length >= 8) {
      final bd = ByteData.sublistView(co64Payload);
      final count = bd.getUint32(4);
      for (var i = 0; i < count && 8 + i * 8 + 8 <= co64Payload.length; i++) {
        chunkOffsets.add(bd.getUint64(8 + i * 8));
      }
    }
    if (chunkOffsets.isEmpty) return const [];

    // Parse sample sizes (stsz): version+flags(4), sample_size(4), sample_count(4).
    if (stszPayload.length < 12) return const [];
    final stszBd = ByteData.sublistView(stszPayload);
    final uniformSize = stszBd.getUint32(4);
    final sampleCount = stszBd.getUint32(8);

    // Parse sample-to-chunk (stsc): version+flags(4), entry_count(4), entries(12 each).
    if (stscPayload.length < 8) return const [];
    final stscBd = ByteData.sublistView(stscPayload);
    final entryCount = stscBd.getUint32(4);
    final stscEntries = <({int firstChunk, int samplesPerChunk})>[];
    for (var i = 0; i < entryCount && 8 + i * 12 + 12 <= stscPayload.length; i++) {
      final base = 8 + i * 12;
      stscEntries.add((
        firstChunk: stscBd.getUint32(base),
        samplesPerChunk: stscBd.getUint32(base + 4),
      ));
    }
    if (stscEntries.isEmpty) return const [];

    final spans = <_ChunkSpan>[];
    var sampleIdx = 0;
    var stscIdx = 0;

    for (var chunkIdx = 0; chunkIdx < chunkOffsets.length; chunkIdx++) {
      final oneBasedChunk = chunkIdx + 1;
      while (stscIdx + 1 < stscEntries.length &&
          oneBasedChunk >= stscEntries[stscIdx + 1].firstChunk) {
        stscIdx++;
      }
      final samplesInChunk = stscEntries[stscIdx].samplesPerChunk;
      var chunkBytes = 0;
      for (var s = 0; s < samplesInChunk && sampleIdx < sampleCount; s++) {
        if (uniformSize > 0) {
          chunkBytes += uniformSize;
        } else if (12 + sampleIdx * 4 + 4 <= stszPayload.length) {
          chunkBytes += stszBd.getUint32(12 + sampleIdx * 4);
        }
        sampleIdx++;
      }
      spans.add(_ChunkSpan(offset: chunkOffsets[chunkIdx], length: chunkBytes));
    }

    return spans;
  }

  static Uint8List? _findStblPayload(Uint8List trakPayload) {
    for (final b in _parseBoxes(trakPayload, 0, trakPayload.length)) {
      if (b.type == 'mdia') {
        for (final mb in _parseBoxes(b.payload, 0, b.payload.length)) {
          if (mb.type == 'minf') {
            for (final mib in _parseBoxes(mb.payload, 0, mb.payload.length)) {
              if (mib.type == 'stbl') return mib.payload;
            }
          }
        }
      }
    }
    return null;
  }

  static Uint8List _rebuildMoovWithPatchedOffsets({
    required Uint8List mvhdRawBox,
    required Uint8List audioTrakPayload,
    required List<int> newChunkOffsets,
    required bool use64BitOffsets,
  }) {
    final patchedTrakPayload = _patchTrakOffsets(
      audioTrakPayload,
      newChunkOffsets,
      use64BitOffsets,
    );
    final patchedTrakBox = _wrapBox('trak', patchedTrakPayload);

    final moovBody = BytesBuilder(copy: false)
      ..add(mvhdRawBox)
      ..add(patchedTrakBox);
    return _wrapBox('moov', moovBody.toBytes());
  }

  static Uint8List _patchTrakOffsets(
    Uint8List trakPayload,
    List<int> newChunkOffsets,
    bool use64BitOffsets,
  ) {
    final out = BytesBuilder(copy: false);
    for (final b in _parseBoxes(trakPayload, 0, trakPayload.length)) {
      if (b.type == 'mdia') {
        out.add(
          _wrapBox(
            'mdia',
            _patchMdiaOffsets(b.payload, newChunkOffsets, use64BitOffsets),
          ),
        );
      } else {
        out.add(b.fullBox);
      }
    }
    return out.toBytes();
  }

  static Uint8List _patchMdiaOffsets(
    Uint8List mdiaPayload,
    List<int> newChunkOffsets,
    bool use64BitOffsets,
  ) {
    final out = BytesBuilder(copy: false);
    for (final b in _parseBoxes(mdiaPayload, 0, mdiaPayload.length)) {
      if (b.type == 'minf') {
        out.add(
          _wrapBox(
            'minf',
            _patchMinfOffsets(b.payload, newChunkOffsets, use64BitOffsets),
          ),
        );
      } else {
        out.add(b.fullBox);
      }
    }
    return out.toBytes();
  }

  static Uint8List _patchMinfOffsets(
    Uint8List minfPayload,
    List<int> newChunkOffsets,
    bool use64BitOffsets,
  ) {
    final out = BytesBuilder(copy: false);
    for (final b in _parseBoxes(minfPayload, 0, minfPayload.length)) {
      if (b.type == 'stbl') {
        out.add(
          _wrapBox(
            'stbl',
            _patchStblOffsets(b.payload, newChunkOffsets, use64BitOffsets),
          ),
        );
      } else {
        out.add(b.fullBox);
      }
    }
    return out.toBytes();
  }

  static Uint8List _patchStblOffsets(
    Uint8List stblPayload,
    List<int> newChunkOffsets,
    bool use64BitOffsets,
  ) {
    final out = BytesBuilder(copy: false);
    for (final b in _parseBoxes(stblPayload, 0, stblPayload.length)) {
      if (b.type == 'stco' || b.type == 'co64') {
        if (use64BitOffsets) {
          final payload = ByteData(8 + newChunkOffsets.length * 8)
            ..setUint32(0, 0) // version + flags
            ..setUint32(4, newChunkOffsets.length);
          for (var i = 0; i < newChunkOffsets.length; i++) {
            payload.setUint64(8 + i * 8, newChunkOffsets[i]);
          }
          out.add(_wrapBox('co64', payload.buffer.asUint8List()));
        } else {
          final payload = ByteData(8 + newChunkOffsets.length * 4)
            ..setUint32(0, 0) // version + flags
            ..setUint32(4, newChunkOffsets.length);
          for (var i = 0; i < newChunkOffsets.length; i++) {
            payload.setUint32(8 + i * 4, newChunkOffsets[i]);
          }
          out.add(_wrapBox('stco', payload.buffer.asUint8List()));
        }
      } else {
        out.add(b.fullBox);
      }
    }
    return out.toBytes();
  }

  static Uint8List _buildM4aFtypBox() {
    // ftyp: major='M4A ', minor=0, compat=['M4A ', 'mp42', 'isom', '\0\0\0\0']
    final bytes = Uint8List.fromList([
      0x00, 0x00, 0x00, 0x20, // size = 32
      0x66, 0x74, 0x79, 0x70, // 'ftyp'
      0x4D, 0x34, 0x41, 0x20, // 'M4A '
      0x00, 0x00, 0x00, 0x00, // minor_version = 0
      0x4D, 0x34, 0x41, 0x20, // 'M4A '
      0x6D, 0x70, 0x34, 0x32, // 'mp42'
      0x69, 0x73, 0x6F, 0x6D, // 'isom'
      0x00, 0x00, 0x00, 0x00,
    ]);
    return bytes;
  }

  static Uint8List _wrapBox(String type, Uint8List payload) {
    final total = 8 + payload.length;
    final out = Uint8List(total);
    final bd = ByteData.sublistView(out);
    bd.setUint32(0, total);
    out[4] = type.codeUnitAt(0);
    out[5] = type.codeUnitAt(1);
    out[6] = type.codeUnitAt(2);
    out[7] = type.codeUnitAt(3);
    out.setRange(8, total, payload);
    return out;
  }

  static List<_ParsedBox> _parseBoxes(Uint8List data, int start, int end) {
    final boxes = <_ParsedBox>[];
    var offset = start;
    final bd = ByteData.sublistView(data);
    while (offset + 8 <= end) {
      var size = bd.getUint32(offset);
      final type = _ascii4(data, offset + 4);
      var headerLen = 8;
      if (size == 1) {
        if (offset + 16 > end) break;
        size = bd.getUint64(offset + 8);
        headerLen = 16;
      } else if (size == 0) {
        size = end - offset;
      }
      if (size < headerLen || offset + size > end) break;
      boxes.add(
        _ParsedBox(
          type: type,
          fullBox: data.sublist(offset, offset + size),
          payload: data.sublist(offset + headerLen, offset + size),
        ),
      );
      offset += size;
    }
    return boxes;
  }

  static String _ascii4(Uint8List bytes, int offset) => String.fromCharCodes(
    [bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3]],
  );
}

class _ParsedBox {
  final String type;
  final Uint8List fullBox;
  final Uint8List payload;

  const _ParsedBox({
    required this.type,
    required this.fullBox,
    required this.payload,
  });
}

class _ChunkSpan {
  final int offset;
  final int length;

  const _ChunkSpan({required this.offset, required this.length});
}
