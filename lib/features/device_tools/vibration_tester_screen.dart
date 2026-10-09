import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
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
    _animController.dispose();
    super.dispose();
  }

  void _triggerSingle(String name, VoidCallback action) {
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
    if (_activePatternName != null) {
      setState(() => _activePatternName = null);
    }
  }

  void _startHeartbeatPattern() {
    _stopPattern();
    setState(() => _activePatternName = 'Heartbeat (Lub-Dub)');

    int step = 0;
    _patternTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      step = (step + 1) % 6;
      if (step == 0) {
        HapticFeedback.mediumImpact();
        _playWave();
      } else if (step == 1) {
        HapticFeedback.heavyImpact();
        _playWave();
      }
      setState(() => _totalVibrationsTriggered++);
    });
  }

  void _startSosPattern() {
    _stopPattern();
    setState(() => _activePatternName = 'SOS Morse Code (... --- ...)');

    // SOS pattern: 3 shorts, 3 longs, 3 shorts
    const sequence = [
      true, false, true, false, true, false, // S: ...
      false,
      true, true, false, true, true, false, true, true, false, // O: ---
      false,
      true, false, true, false, true, false, // S: ...
      false, false, false, // rest
    ];

    int idx = 0;
    _patternTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (idx < sequence.length && sequence[idx]) {
        HapticFeedback.heavyImpact();
        _playWave();
        setState(() => _totalVibrationsTriggered++);
      }
      idx = (idx + 1) % sequence.length;
    });
  }

  void _startRapidPulsePattern() {
    _stopPattern();
    setState(() => _activePatternName = 'Rapid Pulse (10 Hz)');

    _patternTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      HapticFeedback.lightImpact();
      _playWave();
      setState(() => _totalVibrationsTriggered++);
    });
  }

  void _startRumblePattern() {
    _stopPattern();
    setState(() => _activePatternName = 'Gaming Rumble');

    _patternTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      HapticFeedback.vibrate();
      _playWave();
      setState(() => _totalVibrationsTriggered++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = PreferencesService();

    return ToolScaffold(
      title: 'Vibration & Haptics Tester',
      category: ToolCategory.moreTools,
      toolId: 'vibration_tester',
      isScrollable: false,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Visual Ripple Wave Canvas
          Container(
            padding: const EdgeInsets.all(24),
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
                  'Trigger count: $_totalVibrationsTriggered • System Haptics: ${prefs.hapticEnabled ? "Enabled" : "Disabled in Settings"}',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
                if (_activePatternName != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.stop_circle_rounded, size: 18),
                    label: const Text('Stop Continuous Pattern'),
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
                  _triggerSingle('Light Impact', HapticFeedback.lightImpact);
                }, isDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHapticCard('Medium Impact', Icons.pan_tool_alt_rounded, () {
                  _triggerSingle('Medium Impact', HapticFeedback.mediumImpact);
                }, isDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildHapticCard('Heavy Impact', Icons.front_hand_rounded, () {
                  _triggerSingle('Heavy Impact', HapticFeedback.heavyImpact);
                }, isDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHapticCard('Selection Click', Icons.radio_button_checked_rounded, () {
                  _triggerSingle('Selection Click', HapticFeedback.selectionClick);
                }, isDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildHapticCard('Standard Motor Vibrate', Icons.vibration_rounded, () {
            _triggerSingle('Standard Vibrate', HapticFeedback.vibrate);
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

          _buildPatternTile('Heartbeat Rhythm', 'Simulates realistic two-pulse cardiac rhythm', Icons.favorite_rounded, AppColors.catHealth, _startHeartbeatPattern, isDark),
          _buildPatternTile('SOS Emergency Morse Code', 'International distress code (... --- ...)', Icons.warning_amber_rounded, AppColors.warning, _startSosPattern, isDark),
          _buildPatternTile('Rapid Pulse Ticker', 'Fast 10 Hz tactile bursts for motor frequency test', Icons.speed_rounded, AppColors.catTime, _startRapidPulsePattern, isDark),
          _buildPatternTile('Gaming Rumble', 'Simulates console controller action haptics', Icons.sports_esports_rounded, AppColors.catConverter, _startRumblePattern, isDark),

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

  Widget _buildPatternTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    final isRunning = _activePatternName?.startsWith(title.split(' ').first) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isRunning ? color : (isDark ? AppColors.darkBorder : AppColors.lightBorder), width: isRunning ? 1.5 : 1.0),
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
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
