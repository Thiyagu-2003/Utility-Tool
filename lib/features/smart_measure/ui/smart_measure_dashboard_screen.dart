import 'package:flutter/material.dart';
import '../../../core/models/tool_model.dart';
import '../../../shared/widgets/tool_scaffold.dart';
import '../models/smart_measure_capability.dart';
import '../models/measurement_types.dart';
import '../services/ar_platform_bridge.dart';
import 'ar_measurement_screen.dart';
import 'mode_screens/object_dimension_screen.dart';
import 'mode_screens/room_measurement_screen.dart';
import 'mode_screens/person_height_screen.dart';
import 'mode_screens/angle_measurement_screen.dart';
import 'mode_screens/digital_level_screen.dart';
import 'mode_screens/manual_image_measurement_screen.dart';
import 'history/measurement_history_screen.dart';

class SmartMeasureDashboardScreen extends StatefulWidget {
  const SmartMeasureDashboardScreen({super.key});

  @override
  State<SmartMeasureDashboardScreen> createState() => _SmartMeasureDashboardScreenState();
}

class _SmartMeasureDashboardScreenState extends State<SmartMeasureDashboardScreen> {
  SmartMeasureCapability? _capability;

  @override
  void initState() {
    super.initState();
    _loadDeviceCapability();
  }

  Future<void> _loadDeviceCapability() async {
    final cap = await ARPlatformBridge().checkCapabilities();
    if (mounted) {
      setState(() {
        _capability = cap;
      });
    }
  }

  void _openTool(SmartMeasureToolType tool) {
    Widget destination;

    switch (tool) {
      case SmartMeasureToolType.quickMeasure:
      case SmartMeasureToolType.pointToPoint:
      case SmartMeasureToolType.length:
      case SmartMeasureToolType.width:
      case SmartMeasureToolType.distance:
      case SmartMeasureToolType.area:
      case SmartMeasureToolType.surface:
        destination = ARMeasurementScreen(initialTool: tool);
        break;
      case SmartMeasureToolType.objectDimension:
        destination = const ObjectDimensionScreen();
        break;
      case SmartMeasureToolType.room:
        destination = const RoomMeasurementScreen();
        break;
      case SmartMeasureToolType.height:
      case SmartMeasureToolType.personHeight:
        destination = const PersonHeightScreen();
        break;
      case SmartMeasureToolType.angle:
        destination = const AngleMeasurementScreen();
        break;
      case SmartMeasureToolType.levelTool:
        destination = const DigitalLevelScreen();
        break;
      case SmartMeasureToolType.manualImage:
        destination = const ManualImageMeasurementScreen();
        break;
      case SmartMeasureToolType.history:
        destination = const MeasurementHistoryScreen();
        break;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
  }

  void _showCapabilityAuditDialog() {
    if (_capability == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.perm_device_information_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Hardware Inspection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AuditRow('Tracking Engine', _capability!.preferredEngine.title),
            _AuditRow('Description', _capability!.preferredEngine.description),
            _AuditRow('Platform Host', _capability!.platform.toUpperCase()),
            _AuditRow('Device Model', _capability!.deviceModel),
            _AuditRow('ARCore / ARKit', _capability!.isARSupported ? 'Supported' : 'Fallback Mode'),
            _AuditRow('Depth Sensor / LiDAR', _capability!.hasLiDAR ? 'Apple LiDAR Active' : (_capability!.hasDepthSensor ? 'Hardware Depth API' : 'Optical Estimation')),
            _AuditRow('Motion Sensors', _capability!.hasMotionSensors ? 'Active (Gyro/Accel)' : 'Not detected'),
            _AuditRow('Flashlight / Torch', _capability!.hasFlashlight ? 'Available' : 'Unavailable'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: const Text(
                'Notice: Smart Measure dynamically matches measurement algorithms to verified hardware capabilities to ensure maximum physical accuracy without simulated values.',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Smart Measure',
      category: ToolCategory.deviceTests,
      toolId: 'smart_measure',
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded),
          tooltip: 'Measurement History',
          onPressed: () => _openTool(SmartMeasureToolType.history),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hardware Capability Banner
            _buildCapabilityBanner(theme, isDark),
            const SizedBox(height: 20),

            // 2. Section Heading
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Measurement Tools',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '15 Tools Available',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Grid of the 15 Tools
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.98,
              ),
              itemCount: SmartMeasureToolType.values.length,
              itemBuilder: (context, i) {
                final tool = SmartMeasureToolType.values[i];
                return _buildToolCard(tool, theme, isDark);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityBanner(ThemeData theme, bool isDark) {
    final engine = _capability?.preferredEngine ?? MeasurementTrackingEngine.manualCalibration;

    return GestureDetector(
      onTap: _showCapabilityAuditDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.radar_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'HARDWARE READY',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _capability?.platform.toUpperCase() ?? 'DEVICE',
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    engine.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    engine.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(SmartMeasureToolType tool, ThemeData theme, bool isDark) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openTool(tool),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tool.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(tool.icon, color: tool.color, size: 24),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey.shade400),
                ],
              ),
              const Spacer(),
              Text(
                tool.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                tool.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  final String label;
  final String value;
  const _AuditRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
