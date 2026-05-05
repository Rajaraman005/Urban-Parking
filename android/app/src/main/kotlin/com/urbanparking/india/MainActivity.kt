package com.urbanparking.india

import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val screenCaptureChannel =
        "com.urbanparking.india/screen_capture_guard"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyStatusBarColor()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenCaptureChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    setSecureFlag(enabled)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        applyStatusBarColor()
    }

    private fun setSecureFlag(enabled: Boolean) {
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun applyStatusBarColor() {
        window.statusBarColor = Color.rgb(130, 241, 38)
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            window.decorView.systemUiVisibility or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
    }
}
