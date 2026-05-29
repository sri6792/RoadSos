package com.example.roadsos

import android.media.AudioManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.roadsos/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val audioManager =
                    getSystemService(Context.AUDIO_SERVICE) as AudioManager

                when (call.method) {
                    "muteBeep" -> {
                        // Mute the notification/system stream that STT beeps on
                        audioManager.adjustStreamVolume(
                            AudioManager.STREAM_NOTIFICATION,
                            AudioManager.ADJUST_MUTE,
                            0
                        )
                        audioManager.adjustStreamVolume(
                            AudioManager.STREAM_SYSTEM,
                            AudioManager.ADJUST_MUTE,
                            0
                        )
                        result.success(null)
                    }
                    "unmuteBeep" -> {
                        audioManager.adjustStreamVolume(
                            AudioManager.STREAM_NOTIFICATION,
                            AudioManager.ADJUST_UNMUTE,
                            0
                        )
                        audioManager.adjustStreamVolume(
                            AudioManager.STREAM_SYSTEM,
                            AudioManager.ADJUST_UNMUTE,
                            0
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}