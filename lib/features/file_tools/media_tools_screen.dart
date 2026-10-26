import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/share_utils.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';
import 'file_zip_utils.dart';
import '../ocr_tools/ocr_toolkit_screen.dart';

enum MediaTab {
  audio('WAV Audio Trimmer', Icons.music_note_rounded),
  video('Video Size Planner', Icons.videocam_rounded);

  final String label;
  final IconData icon;
  const MediaTab(this.label, this.icon);
}

// ===================== PURE HELPERS (tested in test/file_zip_test.dart) =====================

/// Layout of a PCM / float WAV file, read from its RIFF header.
class WavInfo {
  final int formatTag; // 1 = PCM, 3 = IEEE float
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final int blockAlign; // bytes per sample frame (all channels)
  final int dataOffset; // first byte of audio data
  final int dataLength; // bytes of audio data actually present

  const WavInfo({
    required this.formatTag,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.blockAlign,
    required this.dataOffset,
    required this.dataLength,
  });

  int get frames => dataLength ~/ blockAlign;
  double get durationSeconds => frames / sampleRate;
}

/// Parses a RIFF/WAVE header. Returns null for anything that is not a readable WAV
/// (wrong magic, no fmt/data chunk, zero sample rate or frame size).
WavInfo? parseWav(Uint8List b) {
  if (b.length < 12) return null;
  String tag(int o) => String.fromCharCodes(b.sublist(o, o + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
  final data = ByteData.sublistView(b);

  int? formatTag, channels, sampleRate, bits, blockAlign;
  var pos = 12;
  while (pos + 8 <= b.length) {
    final id = tag(pos);
    final size = data.getUint32(pos + 4, Endian.little);
    final body = pos + 8;
    if (id == 'fmt ' && size >= 16 && body + 16 <= b.length) {
      formatTag = data.getUint16(body, Endian.little);
      // WAVE_FORMAT_EXTENSIBLE keeps the real format code in the sub-format GUID.
      if (formatTag == 0xFFFE && size >= 26 && body + 26 <= b.length) {
        formatTag = data.getUint16(body + 24, Endian.little);
      }
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      blockAlign = data.getUint16(body + 12, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      if (formatTag == null || channels == null || sampleRate == null || bits == null || blockAlign == null) return null;
      if (channels < 1 || sampleRate < 1 || blockAlign < 1) return null;
      // Compressed WAVs (ADPCM, MP3-in-WAV...) have no sample-accurate frames to cut.
      if (formatTag != 1 && formatTag != 3) return null;
      // Streamed files may declare 0 / 0xFFFFFFFF; trust what is really there.
      final available = b.length - body;
      final length = (size == 0 || size > available) ? available : size;
      return WavInfo(
        formatTag: formatTag,
        channels: channels,
        sampleRate: sampleRate,
        bitsPerSample: bits,
        blockAlign: blockAlign,
        dataOffset: body,
        dataLength: length - length % blockAlign,
      );
    }
    pos = body + size + (size.isOdd ? 1 : 0);
  }
  return null;
}

/// Cuts [startSec]..[endSec] out of a WAV and returns a new, valid WAV file. All header
/// chunks before the audio (fmt, LIST, ...) are kept; the RIFF and data sizes are rewritten.
Uint8List trimWav(Uint8List b, WavInfo info, double startSec, double endSec) {
  final from = (startSec * info.sampleRate).floor().clamp(0, info.frames);
  final to = (endSec * info.sampleRate).ceil().clamp(from, info.frames);
  final start = info.dataOffset + from * info.blockAlign;
  final end = info.dataOffset + to * info.blockAlign;
  final length = end - start;
  final pad = length.isOdd ? 1 : 0;

  final headerLen = info.dataOffset - 8; // everything up to the 'data' chunk header
  final out = Uint8List(headerLen + 8 + length + pad);
  out.setRange(0, headerLen, b);
  out.setRange(headerLen, headerLen + 4, 'data'.codeUnits);
  final view = ByteData.sublistView(out);
  view.setUint32(headerLen + 4, length, Endian.little);
  out.setRange(headerLen + 8, headerLen + 8 + length, b, start);
  view.setUint32(4, out.length - 8, Endian.little);
  return out;
}

/// [buckets] loudness values in 0..1 (peak of channel 1) for drawing a real waveform.
List<double> wavPeaks(Uint8List b, WavInfo info, int buckets) {
  if (info.frames == 0 || buckets < 1) return List.filled(max(buckets, 0), 0);
  final bytesPer = info.bitsPerSample ~/ 8;
  final data = ByteData.sublistView(b);
  double sample(int frame) {
    final o = info.dataOffset + frame * info.blockAlign;
    if (o + bytesPer > b.length) return 0;
    if (info.formatTag == 3) {
      if (bytesPer == 4) return data.getFloat32(o, Endian.little).abs();
      if (bytesPer == 8) return data.getFloat64(o, Endian.little).abs();
      return 0;
    }
    switch (bytesPer) {
      case 1:
        return ((b[o] - 128) / 128).abs();
      case 2:
        return (data.getInt16(o, Endian.little) / 32768).abs();
      case 3:
        var v = b[o] | (b[o + 1] << 8) | (b[o + 2] << 16);
        if (v & 0x800000 != 0) v -= 0x1000000;
        return (v / 8388608).abs();
      case 4:
        return (data.getInt32(o, Endian.little) / 2147483648).abs();
    }
    return 0;
  }

  final peaks = <double>[];
  for (var i = 0; i < buckets; i++) {
    final a = info.frames * i ~/ buckets;
    final z = max(a + 1, info.frames * (i + 1) ~/ buckets);
    final step = max(1, (z - a) ~/ 200); // at most ~200 probes per bar
    var peak = 0.0;
    for (var f = a; f < z; f += step) {
      peak = max(peak, sample(f));
    }
    peaks.add(peak.clamp(0.0, 1.0));
  }
  return peaks;
}

/// Parses "90", "1:30", "1:02:03" or "1:30.5" into seconds; null if it isn't a time.
double? parseClock(String text) {
  final parts = text.trim().split(':');
  if (parts.isEmpty || parts.length > 3) return null;
  var total = 0.0;
  for (final p in parts) {
    final v = double.tryParse(p.trim());
    if (v == null || v < 0) return null;
    total = total * 60 + v;
  }
  return total;
}

/// mm:ss (or h:mm:ss from one hour), optionally with tenths of a second.
String formatClock(double secs, {bool tenths = false}) {
  final total = max(0.0, secs);
  final whole = total.floor();
  final h = whole ~/ 3600;
  final m = (whole % 3600) ~/ 60;
  final s = whole % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  final frac = tenths ? '.${((total - whole) * 10).floor()}' : '';
  return h > 0 ? '$h:$mm:$ss$frac' : '$mm:$ss$frac';
}

/// Size in MB of [seconds] of video at [videoKbps] plus an audio track at [audioKbps].
double estimateVideoSizeMb(double seconds, int videoKbps, {int audioKbps = 128}) =>
    seconds * (videoKbps + audioKbps) / 8000;

// ===================== SCREEN =====================

class MediaToolsScreen extends StatefulWidget {
  const MediaToolsScreen({super.key});

  @override
  State<MediaToolsScreen> createState() => _MediaToolsScreenState();
}

class _MediaToolsScreenState extends State<MediaToolsScreen> {
  static const _maxWavBytes = 200 * 1024 * 1024;
  static const _audioKbps = 128;

  MediaTab _activeTab = MediaTab.audio;

  // 1. WAV TRIMMER STATE
  String? _wavName;
  Uint8List? _wavBytes;
  WavInfo? _wavInfo;
  List<double> _wavPeaks = const [];
  RangeValues _audioTrimRange = const RangeValues(0, 0);

  // 2. VIDEO SIZE PLANNER STATE
  String? _videoName;
  int? _videoSizeBytes;
  final TextEditingController _videoLengthController = TextEditingController();
  double _videoDurationSecs = 0;
  String _videoResolution = '1080p (FHD)';
  int _targetBitrateKbps = 5000;
  RangeValues _videoTrimRange = const RangeValues(0, 0);

  @override
  void dispose() {
    _videoLengthController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _pickAudioFile() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['wav']);
      if (file == null) return;
      final size = file.lengthSync() ?? await file.length() ?? 0;
      if (size > _maxWavBytes) {
        _showToast('That WAV is ${(size / (1024 * 1024)).round()} MB; the limit is ${_maxWavBytes ~/ (1024 * 1024)} MB.');
        return;
      }
      final bytes = await file.readAsBytes();
      final info = parseWav(bytes);
      if (info == null || info.frames == 0) {
        _showToast('${file.name} is not an uncompressed (PCM) WAV file.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _wavName = file.name;
        _wavBytes = bytes;
        _wavInfo = info;
        _wavPeaks = wavPeaks(bytes, info, 40);
        _audioTrimRange = RangeValues(0, info.durationSeconds);
      });
    } catch (e) {
      _showToast('Pick file: $e');
    }
  }

  Future<void> _exportAudioSegment() async {
    final info = _wavInfo;
    final bytes = _wavBytes;
    if (info == null || bytes == null) return;
    PreferencesService().triggerHaptic();
    try {
      final trimmed = trimWav(bytes, info, _audioTrimRange.start, _audioTrimRange.end);
      await shareFileBytes(trimmed, 'Trimmed_${withWavExtension(_wavName!)}');
    } catch (e) {
      _showToast('Export failed: $e');
    }
  }

  Future<void> _pickVideoFile() async {
    PreferencesService().triggerHaptic();
    try {
      final file = await FilePicker.pickFile(type: FileType.video);
      if (file == null) return;
      final size = file.lengthSync() ?? await file.length();
      if (!mounted) return;
      setState(() {
        _videoName = file.name;
        _videoSizeBytes = size; // the real size; the video itself is never read
      });
    } catch (e) {
      _showToast('Pick file: $e');
    }
  }

  void _onVideoLengthChanged(String text) {
    final secs = parseClock(text) ?? 0;
    setState(() {
      _videoDurationSecs = secs;
      _videoTrimRange = RangeValues(0, secs);
    });
  }

  Future<void> _exportVideoPlan() async {
    PreferencesService().triggerHaptic();
    final trimDuration = _videoTrimRange.end - _videoTrimRange.start;
    final targetMb = estimateVideoSizeMb(trimDuration, _targetBitrateKbps, audioKbps: _audioKbps);
    final originalMb = _videoSizeBytes == null ? null : _videoSizeBytes! / (1024 * 1024);
    final info = '''Video compression and trim PLAN (no video file was changed)
File: ${_videoName ?? 'not selected'}
Original size: ${originalMb == null ? 'unknown' : '${originalMb.toStringAsFixed(1)} MB'}
Video length (entered by you): ${formatClock(_videoDurationSecs)}
Resolution target: $_videoResolution
Video bitrate target: $_targetBitrateKbps kbps (+ $_audioKbps kbps audio)
Keep from ${formatClock(_videoTrimRange.start)} to ${formatClock(_videoTrimRange.end)} (${formatClock(trimDuration)})
Estimated size: ~${targetMb.toStringAsFixed(1)} MB
Use this plan in a video editor or converter: ToolBox Pro cannot re-encode video.
''';
    try {
      await shareFileBytes(Uint8List.fromList(utf8.encode(info)), 'Video_Plan_${FileZipUtils.safeFileName(_videoName ?? 'video')}.txt');
    } catch (e) {
      _showToast('Export failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Audio & Video Studio',
      category: ToolCategory.media,
      toolId: 'media_tools',
      onReset: () {
        setState(() {
          _wavName = null;
          _wavBytes = null;
          _wavInfo = null;
          _wavPeaks = const [];
          _audioTrimRange = const RangeValues(0, 0);
          _videoName = null;
          _videoSizeBytes = null;
          _videoLengthController.clear();
          _videoDurationSecs = 0;
          _videoResolution = '1080p (FHD)';
          _targetBitrateKbps = 5000;
          _videoTrimRange = const RangeValues(0, 0);
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              PreferencesService().triggerHaptic();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const OcrToolkitScreen(initialTab: OcrTab.textToSpeech),
              ));
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  ToolCategory.media.color.withValues(alpha: 0.15),
                  ToolCategory.media.color.withValues(alpha: 0.05),
                ]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ToolCategory.media.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.record_voice_over_rounded, color: ToolCategory.media.color, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Looking for Voice & Speech? Open Voice Studio (Text to Speech playback & Microphone dictation)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: ToolCategory.media.color),
                ],
              ),
            ),
          ),
          _buildSegmentChips(isDark),
          const SizedBox(height: 16),
          if (_activeTab == MediaTab.audio) _buildAudioTab(isDark),
          if (_activeTab == MediaTab.video) _buildVideoTab(isDark),
        ],
      ),
    );
  }

  Widget _buildSegmentChips(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MediaTab.values.map((tab) {
        final isSelected = _activeTab == tab;
        return ChoiceChip(
          showCheckmark: false,
          avatar: Icon(tab.icon, size: 16, color: isSelected ? Colors.white : null),
          label: Text(tab.label, style: isSelected ? const TextStyle(color: Colors.white) : null),
          selected: isSelected,
          selectedColor: AppColors.catPdf,
          onSelected: (_) {
            PreferencesService().triggerHaptic();
            setState(() => _activeTab = tab);
          },
        );
      }).toList(),
    );
  }

  Widget _notice(bool isDark, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.catPdf.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.catPdf.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.catPdf),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }

  Widget _grey(String text) => Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey));

  // --- TAB 1: WAV TRIMMER ---
  Widget _buildAudioTab(bool isDark) {
    final info = _wavInfo;
    final clipDuration = _audioTrimRange.end - _audioTrimRange.start;
    final outBytes = info == null ? 0 : (clipDuration * info.sampleRate).ceil() * info.blockAlign + info.dataOffset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _notice(isDark, 'Cuts a real .wav file and saves a new .wav. Other audio formats (MP3, AAC, M4A...) '
            'cannot be cut without an audio codec, so they are not supported here.'),
        const SizedBox(height: 16),
        ResultCard(
          title: 'Trimmed Audio Length',
          primaryResult: info == null ? 'Pick a WAV file' : formatClock(clipDuration, tenths: true),
          subtitle: info == null
              ? 'Start and end are read from the real file'
              : 'Start: ${formatClock(_audioTrimRange.start, tenths: true)} • End: ${formatClock(_audioTrimRange.end, tenths: true)}',
          accentColor: AppColors.catPdf,
          breakdowns: info == null
              ? null
              : [
                  BreakdownItem(label: 'Original', value: formatClock(info.durationSeconds, tenths: true)),
                  BreakdownItem(label: 'Format', value: '${info.sampleRate} Hz • ${info.channels} ch • ${info.bitsPerSample}-bit'),
                  BreakdownItem(label: 'Output size', value: '${(outBytes / 1024).toStringAsFixed(0)} KB'),
                ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.audio_file_rounded),
          label: Text(_wavName == null ? 'Select WAV File' : 'Change: $_wavName', maxLines: 1, overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _pickAudioFile,
        ),
        if (info != null) ...[
          const SizedBox(height: 20),
          const Text('Waveform', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_wavPeaks.length, (i) {
                final pos = (i + 0.5) / _wavPeaks.length * info.durationSeconds;
                final inRange = pos >= _audioTrimRange.start && pos <= _audioTrimRange.end;
                return Container(
                  width: 4,
                  height: 4 + _wavPeaks[i] * 54,
                  decoration: BoxDecoration(
                    color: inRange ? AppColors.catPdf : Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          RangeSlider(
            values: _audioTrimRange,
            min: 0,
            max: info.durationSeconds,
            labels: RangeLabels(formatClock(_audioTrimRange.start, tenths: true), formatClock(_audioTrimRange.end, tenths: true)),
            activeColor: AppColors.catPdf,
            onChanged: (val) => setState(() => _audioTrimRange = val),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _grey('00:00'),
              _grey('${formatClock(info.durationSeconds, tenths: true)} total'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.cut_rounded),
              label: const Text('Trim & Share WAV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catPdf,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: clipDuration > 0 ? _exportAudioSegment : null,
            ),
          ),
        ],
      ],
    );
  }

  // --- TAB 2: VIDEO SIZE PLANNER ---
  Widget _buildVideoTab(bool isDark) {
    final hasLength = _videoDurationSecs > 0;
    final trimDuration = _videoTrimRange.end - _videoTrimRange.start;
    final estimatedMb = estimateVideoSizeMb(trimDuration, _targetBitrateKbps, audioKbps: _audioKbps);
    final originalMb = _videoSizeBytes == null ? null : _videoSizeBytes! / (1024 * 1024);
    final pctSaved = originalMb != null && originalMb > 0 ? (1 - estimatedMb / originalMb) * 100 : null;
    final currentKbps = originalMb != null && hasLength ? originalMb * 8 * 1024 / _videoDurationSecs : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _notice(isDark, 'This is a planner, not a converter: it does not read, trim or re-encode the video. '
            'It estimates the size a trimmed, lower-bitrate copy would have, and exports that plan as a text file. '
            'The file size is read from your video; the length is what you type.'),
        const SizedBox(height: 16),
        ResultCard(
          title: 'Estimated Size After Re-encoding',
          primaryResult: hasLength
              ? '~${estimatedMb.toStringAsFixed(1)} MB${pctSaved == null ? '' : ' (${pctSaved >= 0 ? '${pctSaved.toStringAsFixed(0)}% smaller' : '${(-pctSaved).toStringAsFixed(0)}% larger'})'}'
              : 'Enter the video length',
          subtitle: hasLength
              ? 'Original: ${originalMb == null ? 'select a file' : '${originalMb.toStringAsFixed(1)} MB'} • Kept: ${formatClock(trimDuration)}'
              : 'Needed to estimate; the app cannot read it from the video',
          accentColor: AppColors.catPdf,
          breakdowns: [
            if (currentKbps != null) BreakdownItem(label: 'Current average bitrate', value: '${currentKbps.round()} kbps'),
            BreakdownItem(label: 'Target', value: '$_targetBitrateKbps kbps + $_audioKbps kbps audio'),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.video_file_rounded),
          label: Text(_videoName == null ? 'Select Video File' : 'Selected: $_videoName', maxLines: 1, overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catPdf,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _pickVideoFile,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _videoLengthController,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            labelText: 'Video length (mm:ss or h:mm:ss)',
            hintText: '3:25',
            prefixIcon: const Icon(Icons.timer_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: _onVideoLengthChanged,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _videoResolution,
          decoration: InputDecoration(labelText: 'Resolution Preset', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          items: ['480p (SD - Smallest)', '720p (HD - Balanced)', '1080p (FHD)', 'Keep Original']
              .map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _videoResolution = v;
                if (v.contains('480p')) _targetBitrateKbps = 1200;
                if (v.contains('720p')) _targetBitrateKbps = 2500;
                if (v.contains('1080p')) _targetBitrateKbps = 5000;
              });
            }
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          isExpanded: true,
          // initialValue is read once, and the resolution preset above changes the bitrate.
          key: ValueKey(_targetBitrateKbps),
          initialValue: _targetBitrateKbps,
          decoration: InputDecoration(labelText: 'Video bitrate', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          // Must contain every preset bitrate (1080p sets 5000) or the dropdown asserts.
          items: [800, 1200, 1800, 2500, 4000, 5000, 6000].map((b) => DropdownMenuItem(value: b, child: Text('$b kbps'))).toList(),
          onChanged: (b) => setState(() => _targetBitrateKbps = b ?? _targetBitrateKbps),
        ),
        if (hasLength) ...[
          const SizedBox(height: 16),
          const Text('Part to keep', style: TextStyle(fontWeight: FontWeight.bold)),
          RangeSlider(
            values: _videoTrimRange,
            min: 0,
            max: _videoDurationSecs,
            labels: RangeLabels(formatClock(_videoTrimRange.start), formatClock(_videoTrimRange.end)),
            activeColor: AppColors.catPdf,
            onChanged: (v) => setState(() => _videoTrimRange = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _grey('Start: ${formatClock(_videoTrimRange.start)}'),
              _grey('End: ${formatClock(_videoTrimRange.end)}'),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const Text('Export Plan (.txt)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catPdf,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _exportVideoPlan,
          ),
        ],
      ],
    );
  }
}

/// "song.mp3" -> "song.wav" (any other extension is replaced; no extension gets one).
String withWavExtension(String name) {
  final dot = name.lastIndexOf('.');
  return '${dot > 0 ? name.substring(0, dot) : name}.wav';
}
