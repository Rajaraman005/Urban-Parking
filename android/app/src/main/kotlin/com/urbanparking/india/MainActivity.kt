package com.urbanparking.india

import android.graphics.Color
import android.os.Bundle
import android.view.View
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyStatusBarColor()
    }

    override fun onResume() {
        super.onResume()
        applyStatusBarColor()
    }

    private fun applyStatusBarColor() {
        window.statusBarColor = Color.rgb(130, 241, 38)
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            window.decorView.systemUiVisibility or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
    }
}
