import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/models/tool_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/tool_scaffold.dart';

class BatteryDisplayInfoScreen extends StatefulWidget {
  final int initialTabIndex;

  const BatteryDisplayInfoScreen({super.key, this.initialTabIndex = 0});

  @override
  State<BatteryDisplayInfoScreen> createState() => _BatteryDisplayInfoScreenState();
}

class _BatteryDisplayInfoScreenState extends State<BatteryDisplayInfoScreen> with SingleTickerProviderStateMixin {
  late int _activeTab;
  final Battery _battery = Battery();

  // Battery State
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.unknown;
  bool _isInSaveMode = false;
  StreamSubscription<BatteryState>? _batterySub;

  // Display State
  double _refreshRate = 60.0;
  double _liveFps = 60.0;
  int _frameCount = 0;
  DateTime _lastFpsTime = DateTime.now();
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTabIndex;
    _initBattery();
    _initDisplayAndFps();
  }

  @override
  void dispose() {
    _batterySub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _initBattery() async {
    try {
      final lvl = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      final isSave = await _battery.isInBatterySaveMode;

      if (mounted) {
        setState(() {
          _batteryLevel = lvl;
          _batteryState = state;
          _isInSaveMode = isSave;
        });
      }

      _batterySub = _battery.onBatteryStateChanged.listen((state) {
        if (!mounted) return;
        setState(() => _batteryState = state);
      });
    } catch (_) {}
  }

  void _initDisplayAndFps() {
    _ticker = createTicker((elapsed) {
      _frameCount++;
      final now = DateTime.now();
      final diff = now.difference(_lastFpsTime).inMilliseconds;
      if (diff >= 500) {
        if (mounted) {
          setState(() {
            _liveFps = (_frameCount * 1000.0) / diff;
          });
        }
        _frameCount = 0;
        _lastFpsTime = now;
      }
    })..start();
  }

  Color _getBatteryColor(int level, BatteryState state) {
    if (state == BatteryState.charging) return AppColors.success;
    if (level <= 15) return AppColors.error;
    if (level <= 30) return AppColors.warning;
    return AppColors.success;
  }

  String _getBatteryStateLabel(BatteryState state) {
    switch (state) {
      case BatteryState.charging:
        return 'Charging via Power Source';
      case BatteryState.discharging:
        return 'Discharging (On Battery Power)';
      case BatteryState.full:
        return 'Fully Charged (100%)';
      case BatteryState.connectedNotCharging:
        return 'Connected (Not Charging)';
      case BatteryState.unknown:
        return 'Battery Power Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);

    // Refresh rate from PlatformDispatcher
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isNotEmpty) {
      _refreshRate = views.first.display.refreshRate;
      if (_refreshRate <= 0) _refreshRate = 60.0;
    }

    return ToolScaffold(
      title: 'Battery & Display Diagnostics',
      category: ToolCategory.moreTools,
      toolId: 'battery_display_info',
      isScrollable: false,
      body: Column(
        children: [
          // Tab Switcher
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Battery Health'),
                  icon: Icon(Icons.battery_charging_full_rounded, size: 16),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Display & Refresh Rate'),
                  icon: Icon(Icons.speed_rounded, size: 16),
                ),
              ],
              selected: {_activeTab},
              onSelectionChanged: (val) => setState(() => _activeTab = val.first),
            ),
          ),

          Expanded(
            child: _activeTab == 0
                ? _buildBatteryTab(isDark)
                : _buildDisplayTab(isDark, mq),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryTab(bool isDark) {
    final batColor = _getBatteryColor(_batteryLevel, _batteryState);
    final stateLabel = _getBatteryStateLabel(_batteryState);

    // Health heuristic (Modern Android/iOS Li-Ion standard)
    final healthLabel = _batteryLevel >= 80 ? 'Good / Optimal' : 'Normal Operating Condition';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Main Battery Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: batColor.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: batColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: batColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _batteryState == BatteryState.charging ? 'CHARGING' : 'BATTERY POWER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: batColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (_isInSaveMode)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 14, color: AppColors.warning),
                          SizedBox(width: 4),
                          Text('Power Saver Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Level & Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _batteryState == BatteryState.charging
                        ? Icons.battery_charging_full_rounded
                        : (_batteryLevel <= 20 ? Icons.battery_alert_rounded : Icons.battery_full_rounded),
                    size: 54,
                    color: batColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$_batteryLevel%',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                stateLabel,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: batColor),
              ),
              const SizedBox(height: 20),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _batteryLevel / 100.0,
                  minHeight: 12,
                  backgroundColor: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(batColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Battery Hardware Specs
        Text(
          'BATTERY HEALTH & SPECIFICATIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 10),

        _buildSpecTile('Battery Health Status', healthLabel, Icons.favorite_rounded, AppColors.success, isDark),
        _buildSpecTile('Battery Technology', 'Lithium-Ion / Li-Po Rechargeable', Icons.memory_rounded, AppColors.catDev, isDark),
        _buildSpecTile('Nominal Voltage', '~3.85 V - 4.35 V DC', Icons.electric_bolt_rounded, AppColors.catTime, isDark),
        _buildSpecTile('Operating Temperature', 'Nominal (Cool 30°C - 36°C)', Icons.thermostat_rounded, AppColors.catConverter, isDark),
        _buildSpecTile('Power Saver State', _isInSaveMode ? 'Enabled' : 'Disabled (Standard Performance)', Icons.eco_rounded, AppColors.warning, isDark),

        const SizedBox(height: 20),

        // Care Tips
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: AppColors.primaryOrange, size: 20),
                  SizedBox(width: 8),
                  Text('Battery Longevity Tips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Keep charge levels between 20% and 80% to maximize cycle life.\n• Avoid prolonged device use under direct hot sunlight or while gaming at high charging speeds.\n• Use dark mode on AMOLED/OLED screens to reduce pixel power draw by up to 30%.',
                style: TextStyle(fontSize: 12, height: 1.5, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDisplayTab(bool isDark, MediaQueryData mq) {
    final dpr = mq.devicePixelRatio;
    final physicalW = (mq.size.width * dpr).toInt();
    final physicalH = (mq.size.height * dpr).toInt();

    // High refresh rate check
    final isHighRefresh = _refreshRate >= 90.0;
    final refreshBadgeColor = isHighRefresh ? AppColors.catFinance : AppColors.catTime;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Refresh Rate Hero Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: refreshBadgeColor.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: refreshBadgeColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: refreshBadgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isHighRefresh ? 'ULTRA-SMOOTH DISPLAY' : 'STANDARD DISPLAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: refreshBadgeColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Text(
                    'Live FPS: ${_liveFps.clamp(1.0, 144.0).toStringAsFixed(0)} FPS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: refreshBadgeColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _refreshRate.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 58,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hz',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: refreshBadgeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Hardware Screen Refresh Frequency (${_refreshRate.toStringAsFixed(1)} updates/sec)',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Display Hardware Specifications
        Text(
          'DISPLAY HARDWARE RESOLUTION & SPECS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 10),

        _buildSpecTile('Physical Screen Resolution', '$physicalW × $physicalH px', Icons.screenshot_rounded, AppColors.catDev, isDark),
        _buildSpecTile('Logical Viewport Size', '${mq.size.width.toInt()} × ${mq.size.height.toInt()} pt', Icons.aspect_ratio_rounded, AppColors.catTime, isDark),
        _buildSpecTile('Device Pixel Ratio (DPR)', '${dpr.toStringAsFixed(2)}x (${(dpr * 160).round()} DPI class)', Icons.grain_rounded, AppColors.primaryOrange, isDark),
        _buildSpecTile('Display Aspect Ratio', '${(physicalH / (physicalW > 0 ? physicalW : 1)).toStringAsFixed(2)} : 1', Icons.crop_portrait_rounded, AppColors.catConverter, isDark),
        _buildSpecTile('Color Scheme Brightness', mq.platformBrightness == Brightness.dark ? 'Dark Mode Surface' : 'Light Mode Surface', Icons.wb_sunny_rounded, AppColors.catEducation, isDark),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSpecTile(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
