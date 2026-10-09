package com.utility.app.utility_tool

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.utility.app/vibrator"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
    }
}
