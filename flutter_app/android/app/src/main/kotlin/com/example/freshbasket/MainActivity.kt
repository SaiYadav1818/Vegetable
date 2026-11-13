package com.example.freshbasket

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.provider.OpenableColumns
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Notification
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "freshbasket/device"
    private val notificationChannelName = "freshbasket/notifications"
    private val orderNotificationChannelId = "freshbasket_orders"
    private val requestCode = 7412
    private val imagePickerRequestCode = 7413
    private var pendingLocation: MethodChannel.Result? = null
    private var pendingImage: MethodChannel.Result? = null
    private var notificationChannel: MethodChannel? = null
    private var pendingNotification: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannelName).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "showNotification" -> {
                        val title = call.argument<String>("title") ?: "FreshBasket"
                        val body = call.argument<String>("body") ?: "You have an order update."
                        val data = call.argument<Map<String, String>>("data") ?: emptyMap()
                        showLocalNotification(title, body, data)
                        result.success(null)
                    }
                    "consumeInitialNotification" -> {
                        result.success(pendingNotification)
                        pendingNotification = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        deliverNotificationIntent(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "currentLocation" -> getLocation(result)
                "pickProductImage" -> pickProductImage(result)
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deliverNotificationIntent(intent)
    }

    private fun showLocalNotification(title: String, body: String, data: Map<String, String>) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(orderNotificationChannelId, getString(R.string.freshbasket_notification_channel), NotificationManager.IMPORTANCE_DEFAULT))
        }
        val orderId = data["orderId"].orEmpty()
        val notificationId = data["notificationId"]?.hashCode() ?: System.currentTimeMillis().toInt()
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_order_id", orderId)
            putExtra("notification_event_type", data["eventType"].orEmpty())
        }
        val pending = PendingIntent.getActivity(this, notificationId, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, orderNotificationChannelId) else Notification.Builder(this)
        val notification: Notification = builder.setSmallIcon(applicationInfo.icon).setContentTitle(title).setContentText(body)
            .setContentIntent(pending).setAutoCancel(true).build()
        manager.notify(notificationId, notification)
    }

    private fun deliverNotificationIntent(intent: Intent?) {
        val orderId = intent?.getStringExtra("notification_order_id") ?: return
        if (orderId.isBlank()) return
        val payload = mapOf("orderId" to orderId, "eventType" to (intent.getStringExtra("notification_event_type") ?: ""))
        val channel = notificationChannel
        if (channel == null) pendingNotification = payload else channel.invokeMethod("notificationOpened", payload)
        intent.removeExtra("notification_order_id")
        intent.removeExtra("notification_event_type")
    }

    private fun pickProductImage(result: MethodChannel.Result) {
        if (pendingImage != null) {
            result.error("picker_busy", "Image picker is already open", null)
            return
        }
        pendingImage = result
        try {
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "image/*"
                addCategory(Intent.CATEGORY_OPENABLE)
            }
            startActivityForResult(Intent.createChooser(intent, "Choose product image"), imagePickerRequestCode)
        } catch (error: Exception) {
            pendingImage = null
            result.error("picker_unavailable", error.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != imagePickerRequestCode) return
        val result = pendingImage
        pendingImage = null
        if (result == null) return
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val name = contentResolver.query(uri, null, null, null, null)?.use { cursor: Cursor ->
                val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (column >= 0 && cursor.moveToFirst()) cursor.getString(column) else null
            } ?: "product-image.jpg"
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw IllegalStateException("Could not read selected image")
            result.success(mapOf("bytes" to bytes, "fileName" to name, "mimeType" to contentResolver.getType(uri)))
        } catch (error: Exception) {
            result.error("image_read_failed", error.message, null)
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
