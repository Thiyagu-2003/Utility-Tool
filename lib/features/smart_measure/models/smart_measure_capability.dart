import 'package:flutter/foundation.dart';

/// Hardware capability profile for camera and AR-based measurements.
enum MeasurementTrackingEngine {
  /// Apple ARKit with LiDAR scene depth and mesh reconstruction.
  iosLidar('Apple LiDAR + ARKit', 'Millimeter-accurate direct time-of-flight depth sensing'),

  /// Apple ARKit 6DoF optical tracking and plane detection.
  iosArKit('Apple ARKit', 'Sub-centimeter 6DoF camera tracking and surface detection'),

  /// Google ARCore with Hardware Depth API enabled.
  androidDepthArCore('Google ARCore Depth', 'Dual-camera/ToF assisted depth sensing and plane detection'),

  /// Google ARCore optical 6DoF world tracking.
  androidArCore('Google ARCore', 'Camera feature-point tracking and horizontal/vertical plane estimation'),

  /// Calibrated manual image measurement (Desktop and devices without ARCore/ARKit).
  manualCalibration('Calibrated Scale Engine', 'Pixel-to-physical ratio calculation using a known reference object');

  final String title;
  final String description;
  const MeasurementTrackingEngine(this.title, this.description);
}

enum TrackingConfidence {
  high('High Confidence', 'Reliable surface lock and active depth sensing'),
  medium('Medium Confidence', 'Stable optical tracking; keep device steady'),
  low('Low Confidence', 'Insufficient feature points or rapid movement'),
  unavailable('Tracking Lost', 'Surface lost; point towards a textured, well-lit area');

  final String label;
  final String hint;
  const TrackingConfidence(this.label, this.hint);
}

class SmartMeasureCapability {
  final bool isARSupported;
  final bool isARInstalled;
  final bool hasDepthSensor;
  final bool hasLiDAR;
  final bool hasFlashlight;
  final bool hasMotionSensors;
  final String platform;
  final String deviceModel;
  final String manufacturer;
  final String sdkVersion;
  final String availabilityStatus;
  final MeasurementTrackingEngine preferredEngine;

  const SmartMeasureCapability({
    required this.isARSupported,
    required this.isARInstalled,
    required this.hasDepthSensor,
    required this.hasLiDAR,
    required this.hasFlashlight,
    required this.hasMotionSensors,
    required this.platform,
    required this.deviceModel,
    required this.manufacturer,
    required this.sdkVersion,
    required this.availabilityStatus,
    required this.preferredEngine,
  });

  /// Factory for desktop / non-AR fallback platforms.
  factory SmartMeasureCapability.fallback({
    required String platform,
    bool hasMotionSensors = false,
  }) {
    return SmartMeasureCapability(
      isARSupported: false,
      isARInstalled: false,
      hasDepthSensor: false,
      hasLiDAR: false,
      hasFlashlight: false,
      hasMotionSensors: hasMotionSensors,
      platform: platform,
      deviceModel: 'Desktop/Fallback Host',
      manufacturer: 'System Host',
      sdkVersion: defaultTargetPlatform.name,
      availabilityStatus: 'MANUAL_CALIBRATION_READY',
      preferredEngine: MeasurementTrackingEngine.manualCalibration,
    );
  }

  /// Parse from native channel response map.
  factory SmartMeasureCapability.fromNative(Map<String, dynamic> map, {bool hasMotionSensors = true}) {
    final bool isAR = map['isARSupported'] as bool? ?? false;
    final bool hasDepth = map['hasDepthSensor'] as bool? ?? false;
    final bool hasLidar = map['hasLiDAR'] as bool? ?? false;
    final String plat = map['platform'] as String? ?? (kIsWeb ? 'web' : defaultTargetPlatform.name);

    MeasurementTrackingEngine engine;
    if (plat == 'ios' && hasLidar) {
      engine = MeasurementTrackingEngine.iosLidar;
    } else if (plat == 'ios' && isAR) {
      engine = MeasurementTrackingEngine.iosArKit;
    } else if (plat == 'android' && isAR && hasDepth) {
      engine = MeasurementTrackingEngine.androidDepthArCore;
    } else if (plat == 'android' && isAR) {
      engine = MeasurementTrackingEngine.androidArCore;
    } else {
      engine = MeasurementTrackingEngine.manualCalibration;
    }

    return SmartMeasureCapability(
      isARSupported: isAR,
      isARInstalled: map['isARInstalled'] as bool? ?? false,
      hasDepthSensor: hasDepth,
      hasLiDAR: hasLidar,
      hasFlashlight: map['hasFlashlight'] as bool? ?? false,
      hasMotionSensors: hasMotionSensors,
      platform: plat,
      deviceModel: map['deviceModel'] as String? ?? 'Device',
      manufacturer: map['manufacturer'] as String? ?? 'Vendor',
      sdkVersion: map['sdkVersion']?.toString() ?? '1.0',
      availabilityStatus: map['availabilityStatus'] as String? ?? 'ACTIVE',
      preferredEngine: engine,
    );
  }

  bool get isDesktopPlatform =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  bool get canUseLiveAR => isARSupported && isARInstalled;
}
