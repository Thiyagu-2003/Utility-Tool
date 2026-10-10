import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum HardwareTab {
  deviceInfo('Device Info', Icons.perm_device_information_rounded),
  compassLevel('Compass & Level', Icons.explore_rounded),
  sensorTester('Sensor Tester', Icons.sensors_rounded);

  final String label;
  final IconData icon;
  const HardwareTab(this.label, this.icon);
}

class DeviceHardwareToolkitScreen extends StatefulWidget {
  const DeviceHardwareToolkitScreen({super.key});

  @override
  State<DeviceHardwareToolkitScreen> createState() => _DeviceHardwareToolkitScreenState();
}

class _DeviceHardwareToolkitScreenState extends State<DeviceHardwareToolkitScreen> {
  HardwareTab _activeTab = HardwareTab.deviceInfo;

  // 1. DEVICE INFO STATE
  Map<String, String> _deviceInfoMap = {};
  bool _isLoadingInfo = true;

  // 2. SENSOR STREAMS STATE
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  double _accelX = 0, _accelY = 0, _accelZ = 9.8;
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;
  double _magX = 0, _magY = 30, _magZ = -15;

  // COMPASS & LEVEL STATE
  bool _isLevelMode = false;
  double _calibRoll = 0.0;
  double _calibPitch = 0.0;
  int _shakeCount = 0;
  DateTime _lastShakeTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _initSensors();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
    super.dispose();
  }

  // --- SENSORS SETUP ---
  void _initSensors() {
    try {
      _accelSub = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        setState(() {
          _accelX = event.x;
          _accelY = event.y;
          _accelZ = event.z;
        });
        _detectShake(event.x, event.y, event.z);
      }, onError: (_) {});

      _gyroSub = gyroscopeEventStream().listen((event) {
        if (!mounted) return;
        setState(() {
          _gyroX = event.x;
          _gyroY = event.y;
          _gyroZ = event.z;
        });
      }, onError: (_) {});

      _magSub = magnetometerEventStream().listen((event) {
        if (!mounted) return;
        setState(() {
          _magX = event.x;
          _magY = event.y;
          _magZ = event.z;
        });
      }, onError: (_) {});
    } catch (_) {
      // Fallback for desktop/simulators without physical sensors
    }
  }

  void _detectShake(double x, double y, double z) {
    final g = math.sqrt(x * x + y * y + z * z) / 9.8;
    if (g > 2.2) {
      final now = DateTime.now();
      if (now.difference(_lastShakeTime).inMilliseconds > 450) {
        _lastShakeTime = now;
        PreferencesService().triggerHaptic();
        setState(() => _shakeCount++);
      }
    }
  }

  // --- DEVICE INFO LOADER ---
  Future<void> _loadDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final Map<String, String> info = {};

    try {
      if (Platform.isAndroid) {
        final a = await deviceInfo.androidInfo;
        info['Brand'] = a.brand.toUpperCase();
        info['Model'] = a.model;
        info['Device Name'] = a.device;
        info['Android Version'] = 'Android ${a.version.release} (API ${a.version.sdkInt})';
        info['Security Patch'] = a.version.securityPatch ?? 'N/A';
        info['Manufacturer'] = a.manufacturer;
        info['Hardware'] = a.hardware;
        info['Board'] = a.board;
        info['Supported ABIs'] = a.supportedAbis.join(', ');
        info['Is Physical Device'] = a.isPhysicalDevice ? 'Yes' : 'Emulator / Virtual';
        info['Build ID'] = a.id;
      } else if (Platform.isIOS) {
        final i = await deviceInfo.iosInfo;
        info['Model'] = i.model;
        info['Name'] = i.name;
        info['System Name'] = i.systemName;
        info['iOS Version'] = i.systemVersion;
        info['Localized Model'] = i.localizedModel;
        info['Identifier'] = i.identifierForVendor ?? 'N/A';
        info['Is Physical Device'] = i.isPhysicalDevice ? 'Yes' : 'Simulator';
      } else if (Platform.isWindows) {
        final w = await deviceInfo.windowsInfo;
        info['Computer Name'] = w.computerName;
        info['OS Edition'] = w.productName;
        info['Build Number'] = '${w.buildNumber}.${w.buildLab}';
        info['Processor Count'] = '${w.numberOfCores} Cores';
        info['System Memory'] = '${(w.systemMemoryInMegabytes / 1024).toStringAsFixed(1)} GB RAM';
        info['Platform'] = 'Windows x64 / ARM64';
      } else {
        info['Platform'] = Platform.operatingSystem;
        info['OS Version'] = Platform.operatingSystemVersion;
      }
    } catch (e) {
      info['Error'] = 'Could not read hardware parameters: $e';
    }

    if (mounted) {
      setState(() {
        _deviceInfoMap = info;
        _isLoadingInfo = false;
      });
    }
  }

  Future<void> _exportSpecs() async {
    PreferencesService().triggerHaptic();
    final buffer = StringBuffer('=== Device Specifications Report ===\n');
    buffer.writeln('Generated by ToolBox Pro Device Studio\nDate: ${DateTime.now()}\n');
    _deviceInfoMap.forEach((k, v) => buffer.writeln('$k: $v'));

    await Printing.sharePdf(
      bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
      filename: 'Device_Specs_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
  }

  // --- COMPASS CALCULATIONS ---
  double _calculateHeading() {
    // Heading in radians: atan2(-magX, magY)
    double heading = math.atan2(-_magX, _magY) * (180.0 / math.pi);
    if (heading < 0) heading += 360.0;
    return heading;
  }

  String _headingToCardinal(double deg) {
    const cardinals = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    final idx = ((deg + 11.25) % 360) ~/ 22.5;
    return cardinals[idx % 16];
  }

  // --- SPIRIT LEVEL CALCULATIONS ---
  // Pitch (X tilt angle in degrees) & Roll (Y tilt angle in degrees)
  double _calculatePitch() {
    final g = math.sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ);
    if (g == 0) return 0;
    final rad = math.asin((_accelY / g).clamp(-1.0, 1.0));
    return (rad * (180.0 / math.pi)) - _calibPitch;
  }

  double _calculateRoll() {
    final g = math.sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ);
    if (g == 0) return 0;
    final rad = math.asin((_accelX / g).clamp(-1.0, 1.0));
    return (rad * (180.0 / math.pi)) - _calibRoll;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Device & Hardware Studio',
      category: ToolCategory.developer,
      toolId: 'device_hardware_toolkit',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabChips(isDark),
          const SizedBox(height: 16),
          if (_activeTab == HardwareTab.deviceInfo) _buildDeviceInfoTab(isDark),
          if (_activeTab == HardwareTab.compassLevel) _buildCompassLevelTab(isDark),
          if (_activeTab == HardwareTab.sensorTester) _buildSensorTesterTab(isDark),
        ],
      ),
    );
  }

  Widget _buildTabChips(bool isDark) {
    return FeatureTabSelector<HardwareTab>(
      tabs: HardwareTab.values
          .map((tab) => FeatureTabItem(value: tab, label: tab.label, icon: tab.icon))
          .toList(),
      activeTab: _activeTab,
      accentColor: AppColors.catDev,
      title: 'Hardware & Diagnostics',
      onTabSelected: (tab) => setState(() => _activeTab = tab),
    );
  }

  // --- TAB 1: DEVICE INFO VIEWER ---
  Widget _buildDeviceInfoTab(bool isDark) {
    final mq = MediaQuery.of(context);
    final res = '${mq.size.width.toInt()} × ${mq.size.height.toInt()} pt';
    final dpr = '${mq.devicePixelRatio.toStringAsFixed(2)}x DPR';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'System Specifications',
          primaryResult: _deviceInfoMap['Model'] ?? _deviceInfoMap['Computer Name'] ?? 'Hardware Node',
          subtitle: '${_deviceInfoMap['Android Version'] ?? _deviceInfoMap['OS Edition'] ?? Platform.operatingSystem} • $dpr',
          accentColor: AppColors.catDev,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Export Full Specs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catDev,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _exportSpecs,
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                setState(() => _isLoadingInfo = true);
                _loadDeviceInfo();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Display Section
        _infoSectionHeader('Display & Screen Metrics'),
        _specRow('Physical Resolution', '${(mq.size.width * mq.devicePixelRatio).toInt()} × ${(mq.size.height * mq.devicePixelRatio).toInt()} px', isDark),
        _specRow('Logical Resolution', res, isDark),
        _specRow('Pixel Ratio (DPR)', dpr, isDark),
        _specRow('Orientation', mq.orientation == Orientation.portrait ? 'Portrait' : 'Landscape', isDark),

        const SizedBox(height: 16),
        _infoSectionHeader('Hardware & Platform Details'),
        if (_isLoadingInfo)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else
          ..._deviceInfoMap.entries.map((e) => _specRow(e.key, e.value, isDark)),
      ],
    );
  }

  Widget _infoSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _specRow(String key, String val, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.catDev, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: val));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$key copied!')));
            },
          ),
        ],
      ),
    );
  }

  // --- TAB 2: COMPASS & SPIRIT LEVEL ---
  Widget _buildCompassLevelTab(bool isDark) {
    final heading = _calculateHeading();
    final cardinal = _headingToCardinal(heading);
    final pitch = _calculatePitch();
    final roll = _calculateRoll();
    final isLevel = (pitch.abs() <= 0.6 && roll.abs() <= 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Digital Compass'), icon: Icon(Icons.explore_rounded)),
            ButtonSegment(value: true, label: Text('Spirit Level'), icon: Icon(Icons.line_weight_rounded)),
          ],
          selected: {_isLevelMode},
          onSelectionChanged: (set) => setState(() => _isLevelMode = set.first),
        ),
        const SizedBox(height: 16),
        if (!_isLevelMode) ...[
          // COMPASS VIEW
          ResultCard(
            title: 'Magnetic Compass Heading',
            primaryResult: '${heading.toStringAsFixed(0)}° $cardinal',
            subtitle: 'Pitch: ${pitch.toStringAsFixed(1)}° • Roll: ${roll.toStringAsFixed(1)}°',
            accentColor: AppColors.catDev,
          ),
          const SizedBox(height: 20),
          // Rotating Compass Rose
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border.all(color: AppColors.catDev.withValues(alpha: 0.4), width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.catDev.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -(heading * (math.pi / 180.0)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Cardinal markers
                      const Positioned(top: 14, child: Text('N', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 18))),
                      const Positioned(bottom: 14, child: Text('S', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      const Positioned(right: 16, child: Text('E', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      const Positioned(left: 16, child: Text('W', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      // Tick marks
                      ...List.generate(12, (i) {
                        return Transform.rotate(
                          angle: i * (math.pi / 6),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 2,
                              height: i % 3 == 0 ? 12 : 6,
                              color: i == 0 ? Colors.red : Colors.grey,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                // Center pointer needle
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 4, height: 40, color: Colors.red),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.catDev),
                    ),
                    Container(width: 4, height: 40, color: isDark ? Colors.white70 : Colors.black87),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Magnetic field vector: ${_magX.toStringAsFixed(1)}X, ${_magY.toStringAsFixed(1)}Y, ${_magZ.toStringAsFixed(1)}Z μT',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ] else ...[
          // SPIRIT LEVEL VIEW
          ResultCard(
            title: 'Surface Inclinometer',
            primaryResult: isLevel ? 'PERFECTLY LEVEL (0.0°)' : 'PITCH: ${pitch.toStringAsFixed(1)}° • ROLL: ${roll.toStringAsFixed(1)}°',
            subtitle: isLevel ? 'Surface is balanced within ±0.5°' : 'Tilt detected on surface plane',
            accentColor: isLevel ? AppColors.success : AppColors.catDev,
          ),
          const SizedBox(height: 20),
          // 2D Circular Bubble Level
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border.all(color: isLevel ? AppColors.success : AppColors.catDev, width: 3),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Inner concentric target circles
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isLevel ? AppColors.success : Colors.grey.withValues(alpha: 0.5), width: 1.5),
                  ),
                ),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
                  ),
                ),
                // Crosshairs
                Container(width: 1, height: 240, color: Colors.grey.withValues(alpha: 0.3)),
                Container(width: 240, height: 1, color: Colors.grey.withValues(alpha: 0.3)),
                // Floating Bubble
                Transform.translate(
                  offset: Offset(
                    (roll * 4.0).clamp(-85.0, 85.0),
                    (pitch * 4.0).clamp(-85.0, 85.0),
                  ),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isLevel ? AppColors.success : AppColors.catDev).withValues(alpha: 0.75),
                      boxShadow: [
                        BoxShadow(
                          color: (isLevel ? AppColors.success : AppColors.catDev).withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Calibrate Zero Level'),
                onPressed: () {
                  PreferencesService().triggerHaptic();
                  final g = math.sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ);
                  if (g > 0) {
                    setState(() {
                      _calibPitch = (math.asin((_accelY / g).clamp(-1.0, 1.0)) * (180.0 / math.pi));
                      _calibRoll = (math.asin((_accelX / g).clamp(-1.0, 1.0)) * (180.0 / math.pi));
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Level calibrated to current plane!')));
                  }
                },
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => setState(() {
                  _calibPitch = 0.0;
                  _calibRoll = 0.0;
                }),
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // --- TAB 3: SENSOR TESTER ---
  Widget _buildSensorTesterTab(bool isDark) {
    final gTotal = math.sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ) / 9.80665;
    final gyroTotalDeg = math.sqrt(_gyroX * _gyroX + _gyroY * _gyroY + _gyroZ * _gyroZ) * (180.0 / math.pi);
    final magTotal = math.sqrt(_magX * _magX + _magY * _magY + _magZ * _magZ);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Sensor Diagnostics & Status',
          primaryResult: 'ACCEL: ${gTotal.toStringAsFixed(2)}G',
          subtitle: 'Gyro: ${gyroTotalDeg.toStringAsFixed(1)}°/s • Mag: ${magTotal.toStringAsFixed(1)} μT',
          accentColor: AppColors.catDev,
        ),
        const SizedBox(height: 16),
        // Interactive Shake Test
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.catDev.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Shake Motion Sensor Test', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Vigorously shake device to test accelerometer: $_shakeCount shakes', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => setState(() => _shakeCount = 0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Accelerometer
        _sensorCard(
          '3-Axis Accelerometer (m/s²)',
          Icons.speed_rounded,
          'X: ${_accelX.toStringAsFixed(2)} | Y: ${_accelY.toStringAsFixed(2)} | Z: ${_accelZ.toStringAsFixed(2)}',
          _accelX / 19.6,
          _accelY / 19.6,
          _accelZ / 19.6,
          Colors.blue,
          isDark,
        ),
        const SizedBox(height: 12),
        // Gyroscope
        _sensorCard(
          '3-Axis Gyroscope (rad/s)',
          Icons.rotate_right_rounded,
          'X: ${_gyroX.toStringAsFixed(3)} | Y: ${_gyroY.toStringAsFixed(3)} | Z: ${_gyroZ.toStringAsFixed(3)}',
          _gyroX / 10.0,
          _gyroY / 10.0,
          _gyroZ / 10.0,
          Colors.orange,
          isDark,
        ),
        const SizedBox(height: 12),
        // Magnetometer
        _sensorCard(
          '3-Axis Magnetometer (μT)',
          Icons.explore_rounded,
          'X: ${_magX.toStringAsFixed(1)} | Y: ${_magY.toStringAsFixed(1)} | Z: ${_magZ.toStringAsFixed(1)}',
          _magX / 100.0,
          _magY / 100.0,
          _magZ / 100.0,
          Colors.purple,
          isDark,
        ),
      ],
    );
  }

  Widget _sensorCard(
    String title,
    IconData icon,
    String vals,
    double xFrac,
    double yFrac,
    double zFrac,
    Color col,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: col),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: col, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(vals, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 10),
          _axisBar('X', xFrac, col),
          const SizedBox(height: 4),
          _axisBar('Y', yFrac, col),
          const SizedBox(height: 4),
          _axisBar('Z', zFrac, col),
        ],
      ),
    );
  }

  Widget _axisBar(String label, double frac, Color col) {
    final clamped = ((frac + 1.0) / 2.0).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(width: 16, child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
        Expanded(
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 5,
            borderRadius: BorderRadius.circular(4),
            color: col,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}
