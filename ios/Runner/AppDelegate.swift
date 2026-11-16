import Flutter
import UIKit
import ARKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let smartMeasureChannel = FlutterMethodChannel(
        name: "com.utility.app/smart_measure_ar",
        binaryMessenger: controller.binaryMessenger
      )
      smartMeasureChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "checkCapabilities" {
          let isARSupported = ARWorldTrackingConfiguration.isSupported
          var hasLiDAR = false
          if #available(iOS 14.0, *) {
            hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
          }
          var hasFlash = false
          if let device = AVCaptureDevice.default(for: .video) {
            hasFlash = device.hasTorch
          }
          let data: [String: Any] = [
            "isARSupported": isARSupported,
            "isARInstalled": isARSupported,
            "availabilityStatus": isARSupported ? "SUPPORTED" : "UNSUPPORTED",
            "hasDepthSensor": hasLiDAR,
            "hasLiDAR": hasLiDAR,
            "hasFlashlight": hasFlash,
            "platform": "ios",
            "deviceModel": UIDevice.current.model,
            "manufacturer": "Apple",
            "sdkVersion": UIDevice.current.systemVersion
          ]
          result(data)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
