package com.urbanparking.india

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val screenCaptureChannel =
        "com.urbanparking.india/screen_capture_guard"
    private val locationDiagnosticsChannel =
        "com.urbanparking.india/location_diagnostics"

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            locationDiagnosticsChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "snapshot" -> result.success(locationDiagnosticsSnapshot())
                "lastKnownBest" -> result.success(lastKnownBestLocation())
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

    private fun locationDiagnosticsSnapshot(): Map<String, Any?> {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val gpsEnabled = isProviderEnabled(locationManager, LocationManager.GPS_PROVIDER)
        val networkEnabled = isProviderEnabled(locationManager, LocationManager.NETWORK_PROVIDER)
        val passiveEnabled = isProviderEnabled(locationManager, LocationManager.PASSIVE_PROVIDER)
        val locationEnabled =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                locationManager.isLocationEnabled
            } else {
                gpsEnabled || networkEnabled
            }

        return mapOf(
            "androidSdk" to Build.VERSION.SDK_INT,
            "coarseLocationGranted" to isPermissionGranted(Manifest.permission.ACCESS_COARSE_LOCATION),
            "fineLocationGranted" to isPermissionGranted(Manifest.permission.ACCESS_FINE_LOCATION),
            "gpsProviderEnabled" to gpsEnabled,
            "networkProviderEnabled" to networkEnabled,
            "passiveProviderEnabled" to passiveEnabled,
            "locationEnabled" to locationEnabled,
        )
    }

    private fun isProviderEnabled(
        locationManager: LocationManager,
        provider: String,
    ): Boolean {
        return try {
            locationManager.isProviderEnabled(provider)
        } catch (_: Exception) {
            false
        }
    }

    private fun isPermissionGranted(permission: String): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun lastKnownBestLocation(): Map<String, Any?>? {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val candidates = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
        ).mapNotNull { provider ->
            try {
                if (!isProviderEnabled(locationManager, provider)) {
                    null
                } else {
                    locationManager.getLastKnownLocation(provider)
                }
            } catch (_: SecurityException) {
                null
            } catch (_: Exception) {
                null
            }
        }

        val best = candidates.maxWithOrNull(
            compareBy<Location> { it.time }
                .thenByDescending { if (it.hasAccuracy()) -it.accuracy else Float.NEGATIVE_INFINITY },
        ) ?: return null

        return mapOf(
            "accuracy" to if (best.hasAccuracy()) best.accuracy.toDouble() else null,
            "isMocked" to isMocked(best),
            "latitude" to best.latitude,
            "longitude" to best.longitude,
            "provider" to best.provider,
            "timestampMs" to best.time,
        )
    }

    private fun isMocked(location: Location): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            location.isMock
        } else {
            @Suppress("DEPRECATION")
            location.isFromMockProvider
        }
    }
}
