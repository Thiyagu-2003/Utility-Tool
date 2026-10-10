import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/vibration_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/tool_scaffold.dart';

class VibrationTesterScreen extends StatefulWidget {
  const VibrationTesterScreen({super.key});

  @override
  State<VibrationTesterScreen> createState() => _VibrationTesterScreenState();
}

class _VibrationTesterScreenState extends State<VibrationTesterScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _patternTimer;
  String? _activePatternName;
  int _totalVibrationsTriggered = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _patternTimer?.cancel();
    VibrationService.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _triggerSingle(String name, Future<void> Function() action) {
    _stopPattern();
    action();
    _playWave();
    setState(() {
      _totalVibrationsTriggered++;
    });
  }

  void _playWave() {
    _animController.forward(from: 0.0);
  }

  void _stopPattern() {
    _patternTimer?.cancel();
    _patternTimer = null;
    VibrationService.cancel();
    if (_activePatternName != null) {
      setState(() => _activePatternName = null);
    }
  }

  void _startHeartbeatPattern() {
    _stopPattern();
    setState(() => _activePatternName = 'Heartbeat (Lub-Dub)');

    int step = 0;
    _patternTimer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      step = (step + 1) % 6;
      if (step == 0) {
        VibrationService.mediumImpact();
        _playWave();
      } else if (step == 1) {
        VibrationService.heavyImpact();
        _playWave();
      }
      setState(() => _totalVibrationsTriggered++);
    });
  }

  void _startSosPattern() {
    _stopPattern();
    setState(() => _activePatternName = 'SOS Emergency Morse Code');

    // SOS Morse sequence: 3 dots (S), 3 dashes (O), 3 dots (S)
    // Represented in pulses: true = vibrate, false = pause
    // Dot = 150ms ON, Dash = 380ms ON
    final List<Map<String, dynamic>> pulses = [
      // S: dot, dot, dot
      {'on': true, 'dur': 140},
      {'on': false, 'dur': 120},
      {'on': true, 'dur': 140},
      {'on': false, 'dur': 120},
      {'on': true, 'dur': 140},
      {'on': false, 'dur': 280}, // inter-letter pause

      // O: dash, dash, dash
      {'on': true, 'dur': 380},
      {'on': false, 'dur': 140},
      {'on': true, 'dur': 380},
      {'on': false, 'dur': 140},
      {'on': true, 'dur': 380},
      {'on': false, 'dur': 280}, // inter-letter pause

      // S: dot, dot, dot
      {'on': true, 'dur': 140},
      {'on': false, 'dur': 120},
      {'on': true, 'dur': 140},
      {'on': false, 'dur': 120},
      {'on': true, 'dur': 140},
      {'on': false, 'dur': 850}, // repeat pause
    ];

    int index = 0;
    void runNextPulse() {
      if (_activePatternName != 'SOS Emergency Morse Code' || !mounted) return;
      final current = pulses[index];
      final isVibe = current['on'] as bool;
      final dur = current['dur'] as int;

      if (isVibe) {
        VibrationService.vibrate(durationMs: dur);
        _playWave();
        setState(() => _totalVibrationsTriggered++);
      }

      index = (index + 1) % pulses.length;
      _patternTimer = Timer(Duration(milliseconds: dur), runNextPulse);
    }

    runNextPulse();
  }

  void _startRapidPulsePattern() {
    _stopPattern();
    setState(() => _activePatternName = 'Rapid Pulse (10 Hz)');

    _patternTimer = Timer.periodic(const Duration(milliseconds: 110), (timer) {
      VibrationService.lightImpact();
      _playWave();
      setState(() => _totalVibrationsTriggered++);
    });
  }

  void _startRumblePattern() {
    _stopPattern();
    setState(() => _activePatternName = 'Gaming Rumble');

    _patternTimer = Timer.periodic(const Duration(milliseconds: 140), (timer) {
      VibrationService.vibrate(durationMs: 120);
      _playWave();
      setState(() => _totalVibrationsTriggered++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Vibration & Haptics Tester',
      category: ToolCategory.moreTools,
      toolId: 'vibration_tester',
      isScrollable: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // Visual Ripple Wave Canvas
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    final scale = 1.0 + (_animController.value * 0.4);
                    final opacity = (1.0 - _animController.value).clamp(0.0, 1.0);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryOrange.withValues(alpha: opacity * 0.35),
                            ),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryOrange,
                                AppColors.primaryOrangeLight,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.vibration_rounded, color: Colors.white, size: 38),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  _activePatternName ?? 'Tap any mode below to test haptics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _activePatternName != null
                        ? AppColors.primaryOrange
                        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trigger count: $_totalVibrationsTriggered • Hardware Motor: Active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                if (_activePatternName != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      foregroundColor: AppColors.error,
                      backgroundColor: AppColors.error.withValues(alpha: 0.12),
                    ),
                    icon: const Icon(Icons.stop_circle_rounded, size: 18),
                    label: const Text('Stop Continuous Pattern', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _stopPattern,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Standard Haptic Impact Types
          Text(
            'STANDARD HAPTIC FEEDBACK ENGINES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildHapticCard('Light Impact', Icons.touch_app_rounded, () {
                  _triggerSingle('Light Impact', VibrationService.lightImpact);
                }, isDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHapticCard('Medium Impact', Icons.pan_tool_alt_rounded, () {
                  _triggerSingle('Medium Impact', VibrationService.mediumImpact);
                }, isDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildHapticCard('Heavy Impact', Icons.front_hand_rounded, () {
                  _triggerSingle('Heavy Impact', VibrationService.heavyImpact);
                }, isDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHapticCard('Selection Click', Icons.radio_button_checked_rounded, () {
                  _triggerSingle('Selection Click', VibrationService.selectionClick);
                }, isDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildHapticCard('Standard Motor Vibrate (350ms)', Icons.vibration_rounded, () {
            _triggerSingle('Standard Vibrate', () => VibrationService.vibrate(durationMs: 350));
          }, isDark, fullWidth: true),

          const SizedBox(height: 24),

          // Continuous Rhythm Patterns
          Text(
            'CONTINUOUS RHYTHMIC PATTERNS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),

          _buildPatternTile(
            title: 'Heartbeat Rhythm',
            subtitle: 'Simulates realistic two-pulse cardiac rhythm (Lub-Dub)',
            icon: Icons.favorite_rounded,
            color: AppColors.catHealth,
            onTap: _startHeartbeatPattern,
            isDark: isDark,
          ),

          // Custom High-Contrast SOS Morse Code Card
          _buildSosMorseCard(isDark),

          _buildPatternTile(
            title: 'Rapid Pulse Ticker',
            subtitle: 'Fast 10 Hz tactile bursts for motor frequency test',
            icon: Icons.speed_rounded,
            color: AppColors.catTime,
            onTap: _startRapidPulsePattern,
            isDark: isDark,
          ),

          _buildPatternTile(
            title: 'Gaming Rumble',
            subtitle: 'Simulates console controller action haptics and rumble',
            icon: Icons.sports_esports_rounded,
            color: AppColors.catConverter,
            onTap: _startRumblePattern,
            isDark: isDark,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHapticCard(String label, IconData icon, VoidCallback onTap, bool isDark, {bool fullWidth = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisAlignment: fullWidth ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: AppColors.primaryOrange),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSosMorseCard(bool isDark) {
    final isRunning = _activePatternName == 'SOS Emergency Morse Code';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRunning ? AppColors.warning : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isRunning ? 2.0 : 1.0,
        ),
        boxShadow: isRunning
            ? [
                BoxShadow(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SOS Emergency Morse Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Universal Maritime & Emergency Distress Signal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: isRunning ? AppColors.error.withValues(alpha: 0.15) : AppColors.warning.withValues(alpha: 0.15),
                    foregroundColor: isRunning ? AppColors.error : AppColors.warning,
                  ),
                  icon: Icon(isRunning ? Icons.stop_circle_rounded : Icons.play_arrow_rounded, size: 24),
                  onPressed: isRunning ? _stopPattern : _startSosPattern,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // High-Contrast Clear Morse Code Visual Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFFDE68A),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MORSE PATTERN:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFFB45309),
                        ),
                      ),
                      Text(
                        '· · ·   — — —   · · ·',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '3 Short Dots (S) • 3 Long Dashes (O) • 3 Short Dots (S)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final isRunning = _activePatternName?.startsWith(title.split(' ').first) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRunning ? color : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isRunning ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
        ),
        trailing: isRunning
            ? IconButton(
                icon: const Icon(Icons.stop_circle_rounded, color: AppColors.error),
                onPressed: _stopPattern,
              )
            : IconButton(
                icon: const Icon(Icons.play_circle_outline_rounded),
                onPressed: onTap,
              ),
      ),
    );
  }
}
