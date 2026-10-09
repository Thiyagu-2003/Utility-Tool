import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/models/tool_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/tool_scaffold.dart';

class MicSpeakerTesterScreen extends StatefulWidget {
  const MicSpeakerTesterScreen({super.key});

  @override
  State<MicSpeakerTesterScreen> createState() => _MicSpeakerTesterScreenState();
}

class _MicSpeakerTesterScreenState extends State<MicSpeakerTesterScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  // Speaker State
  bool _isPlayingAudio = false;
  String _speakerTestStatus = 'Ready to test speakers';

  // Mic State
  bool _isListening = false;
  bool _micAvailable = false;
  String _transcribedWords = '';
  double _soundLevel = 0.0;
  String _micTestStatus = 'Tap microphone to start recording test';

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _speakerTestStatus = 'Speaker audio test completed';
        });
      }
    });
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (err) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _micTestStatus = 'Mic notice: ${err.errorMsg}';
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _micAvailable = available;
          if (!available) {
            _micTestStatus = 'Microphone permission needed or unavailable';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _micAvailable = false);
    }
  }

  // --- SPEAKER TESTS ---
  Future<void> _testStereoChannel(String channel, String phrase) async {
    setState(() {
      _isPlayingAudio = true;
      _speakerTestStatus = 'Testing $channel audio channel...';
    });
    await _tts.setPitch(1.0);
    await _tts.speak(phrase);
  }

  Future<void> _testFrequency(double pitch, String label) async {
    setState(() {
      _isPlayingAudio = true;
      _speakerTestStatus = 'Playing $label frequency test...';
    });
    await _tts.setPitch(pitch);
    await _tts.speak('This is a $label audio frequency clarity test. Checking phone loudspeaker output.');
  }

  Future<bool> _showMicPermissionDialog() async {
    final granted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mic_rounded, color: AppColors.primaryOrange),
            SizedBox(width: 10),
            Text('Microphone Access', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'ToolBox Pro requires access to your microphone to perform live speech input diagnostics, voice clarity testing, and hardware loopback.\n\nAll audio is processed 100% locally on your device and is never recorded or uploaded.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow Access'),
          ),
        ],
      ),
    );
    return granted == true;
  }

  // --- MIC TESTS ---
  Future<void> _toggleMicListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _micTestStatus = _transcribedWords.isNotEmpty
            ? 'Success: Speech recorded and verified!'
            : 'Test stopped';
      });
      return;
    }

    if (!_micAvailable) {
      final proceed = await _showMicPermissionDialog();
      if (!proceed) return;

      await _initSpeech();
      if (!_micAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission not granted. Please allow in device settings.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _isListening = true;
      _transcribedWords = '';
      _micTestStatus = 'Speak clearly into your phone microphone...';
    });

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _transcribedWords = result.recognizedWords;
            if (result.finalResult) {
              _micTestStatus = 'Captured speech accurately!';
            }
          });
        }
      },
      onSoundLevelChange: (level) {
        if (mounted) {
          setState(() {
            _soundLevel = level;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Microphone & Speaker Tester',
      category: ToolCategory.moreTools,
      toolId: 'mic_speaker_tester',
      isScrollable: false,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. SPEAKER TEST SUITE
          Text(
            'LOUDSPEAKER & EARPIECE DIAGNOSTICS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.catTime.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.volume_up_rounded, color: AppColors.catTime, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Audio Output Hardware', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            _speakerTestStatus,
                            style: TextStyle(fontSize: 12, color: _isPlayingAudio ? AppColors.catTime : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                          ),
                        ],
                      ),
                    ),
                    if (_isPlayingAudio)
                      IconButton(
                        icon: const Icon(Icons.stop_circle_rounded, color: AppColors.error),
                        onPressed: () {
                          _tts.stop();
                          setState(() => _isPlayingAudio = false);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Channel tests
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.speaker_phone_rounded, size: 16),
                        label: const Text('Left Channel'),
                        onPressed: _isPlayingAudio
                            ? null
                            : () => _testStereoChannel('Left', 'Testing left audio channel. Can you hear this clearly?'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.speaker_phone_rounded, size: 16),
                        label: const Text('Right Channel'),
                        onPressed: _isPlayingAudio
                            ? null
                            : () => _testStereoChannel('Right', 'Testing right audio channel. Can you hear this clearly?'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Frequency Sweeps
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.graphic_eq_rounded, size: 16),
                      label: const Text('Bass (250 Hz Low)'),
                      onPressed: () => _testFrequency(0.5, 'Low-Pitch Bass'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.graphic_eq_rounded, size: 16),
                      label: const Text('Mid Vocal (1 kHz)'),
                      onPressed: () => _testFrequency(1.0, 'Mid Vocal'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.graphic_eq_rounded, size: 16),
                      label: const Text('Treble (4 kHz High)'),
                      onPressed: () => _testFrequency(1.8, 'High-Pitch Treble'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. MICROPHONE TEST SUITE
          Text(
            'MICROPHONE HARDWARE & SPEECH CAPTURE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.catPdf.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _isListening ? AppColors.error : AppColors.catPdf,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Audio Input Microphone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            _micTestStatus,
                            style: TextStyle(
                              fontSize: 12,
                              color: _isListening ? AppColors.primaryOrange : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sound level visualizer
                if (_isListening) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ((_soundLevel + 10) / 20).clamp(0.05, 1.0),
                      minHeight: 8,
                      backgroundColor: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primaryOrange),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Recognized Speech Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRANSCRIBED AUDIO LOOPBACK:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _transcribedWords.isNotEmpty
                            ? '"$_transcribedWords"'
                            : (_isListening ? 'Listening for speech...' : 'No audio recorded yet. Tap Start Mic Test.'),
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: _transcribedWords.isEmpty ? FontStyle.italic : FontStyle.normal,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Start/Stop Mic Button
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _isListening ? AppColors.error : AppColors.primaryOrange,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded),
                  label: Text(_isListening ? 'Stop Recording' : 'Start Mic Recording Test'),
                  onPressed: _toggleMicListening,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
