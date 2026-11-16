package com.utility.app.utility_tool

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.google.ar.core.ArCoreApk
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_VIBRATOR = "com.utility.app/vibrator"
    private val CHANNEL_SMART_MEASURE_AR = "com.utility.app/smart_measure_ar"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_VIBRATOR).setMethodCallHandler { call, result ->
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            if (vibrator == null || !vibrator.hasVibrator()) {
                result.success(false)
                return@setMethodCallHandler
            }

            when (call.method) {
                "vibrate" -> {
                    val duration = (call.argument<Number>("duration")?.toLong() ?: 100L)
                    val amplitude = (call.argument<Int>("amplitude") ?: VibrationEffect.DEFAULT_AMPLITUDE)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val safeAmp = if (amplitude in 1..255) amplitude else VibrationEffect.DEFAULT_AMPLITUDE
                        vibrator.vibrate(VibrationEffect.createOneShot(duration, safeAmp))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(duration)
                    }
                    result.success(true)
                }
                "vibratePattern" -> {
                    val rawTimings = call.argument<List<Number>>("timings") ?: listOf(0, 100)
                    val timings = rawTimings.map { it.toLong() }.toLongArray()
                    val repeat = call.argument<Int>("repeat") ?: -1

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createWaveform(timings, repeat))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(timings, repeat)
                    }
                    result.success(true)
                }
                "cancel" -> {
                    vibrator.cancel()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Smart Measure AR Channel for device capabilities and AR session queries
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SMART_MEASURE_AR).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkCapabilities" -> {
                    try {
                        val arAvailability = ArCoreApk.getInstance().checkAvailability(this)
                        val isSupported = arAvailability.isSupported
                        val isInstalled = arAvailability == ArCoreApk.Availability.SUPPORTED_INSTALLED

                        var hasDepth = false
                        var hasFlash = false

                        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager
                        if (cameraManager != null) {
                            for (id in cameraManager.cameraIdList) {
                                val chars = cameraManager.getCameraCharacteristics(id)
                                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                                if (facing == CameraCharacteristics.LENS_FACING_BACK) {
                                    val flashAvail = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
                                    if (flashAvail) hasFlash = true

                                    val caps = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                                    if (caps != null) {
                                        for (cap in caps) {
                                            if (cap == CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_DEPTH_OUTPUT) {
                                                hasDepth = true
                                                break
                                            }
                                        }
                                    }
                                    break
                                }
                            }
                        }

                        val data = mapOf(
                            "isARSupported" to isSupported,
                            "isARInstalled" to isInstalled,
                            "availabilityStatus" to arAvailability.name,
                            "hasDepthSensor" to hasDepth,
                            "hasFlashlight" to hasFlash,
                            "platform" to "android",
                            "deviceModel" to Build.MODEL,
                            "manufacturer" to Build.MANUFACTURER,
                            "sdkVersion" to Build.VERSION.SDK_INT
                        )
                        result.success(data)
                    } catch (e: Exception) {
                        result.success(
                            mapOf(
                                "isARSupported" to false,
                                "isARInstalled" to false,
                                "availabilityStatus" to "ERROR: ${e.message}",
                                "hasDepthSensor" to false,
                                "hasFlashlight" to false,
                                "platform" to "android",
                                "deviceModel" to Build.MODEL,
                                "manufacturer" to Build.MANUFACTURER,
                                "sdkVersion" to Build.VERSION.SDK_INT
                            )
                        )
                    }
                }
                "requestInstallARCore" -> {
                    try {
                        val installStatus = ArCoreApk.getInstance().requestInstall(this, true)
                        result.success(installStatus.name)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
