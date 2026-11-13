package com.example.freshbasket

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "freshbasket/device"
    private val requestCode = 7412
    private var pendingLocation: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "currentLocation" -> getLocation(result)
                "openExternalUrl" -> {
                    val url = call.argument<String>("url")
                    if (url == null) result.error("invalid_url", "URL is required", null)
                    else try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("open_url_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasLocationPermission(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
        checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun getLocation(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            if (pendingLocation != null) {
                result.error("location_busy", "A location permission request is already in progress", null)
                return
            }
            pendingLocation = result
            requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), requestCode)
            return
        }
        requestOneLocation(result)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != this.requestCode) return
        val result = pendingLocation
        pendingLocation = null
        if (result == null) return
        if (hasLocationPermission()) requestOneLocation(result)
        else result.error("location_denied", "Location permission was denied", null)
    }

    @Suppress("MissingPermission")
    private fun requestOneLocation(result: MethodChannel.Result) {
        val manager = getSystemService(LOCATION_SERVICE) as LocationManager
        val hasFine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val provider = when {
            hasFine && manager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> {
                result.error("location_disabled", "Turn on device location to share your position", null)
                return
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            manager.getCurrentLocation(provider, null, mainExecutor) { location ->
                if (location == null) result.error("location_unavailable", "Could not get the current device location", null)
                else result.success(location.toMap())
            }
        } else {
            try {
                manager.requestSingleUpdate(provider, object : LocationListener {
                    override fun onLocationChanged(location: Location) { result.success(location.toMap()) }
                    @Deprecated("Deprecated by Android") override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                }, Looper.getMainLooper())
            } catch (error: Exception) {
                result.error("location_unavailable", error.message, null)
            }
        }
    }

    private fun Location.toMap() = mapOf("latitude" to latitude, "longitude" to longitude)
}
