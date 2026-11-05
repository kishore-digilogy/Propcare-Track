package com.example.propcare_track

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.util.UUID
import kotlin.math.abs
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Foreground location service.
 *
 * It owns the native 20-second stationary rule so stops are detected even when
 * the Flutter isolate is suspended. Records are appended to [TrackingQueue]
 * first and broadcast second, so losing the UI never loses a fix.
 */
class TrackingService : Service(), LocationListener {
    companion object {
        const val ACTION_START = "com.example.propcare_track.START_TRACKING"
        const val ACTION_STOP = "com.example.propcare_track.STOP_TRACKING"
        const val ACTION_EVENT = "com.example.propcare_track.TRACKING_EVENT"
        const val EXTRA_EVENT = "event"

        const val PREFS = "propcare_tracking"
        const val KEY_TRACKING = "tracking"
        const val KEY_SESSION_ID = "sessionId"
        const val KEY_EMPLOYEE_ID = "employeeId"
        const val KEY_PLATFORM = "platform"
        const val KEY_INTERVAL = "intervalMs"
        const val KEY_DISTANCE_FILTER = "distanceFilterMeters"
        const val KEY_STATIONARY_RADIUS = "stationaryRadiusMeters"
        const val KEY_STATIONARY_SECONDS = "stationarySeconds"
        const val KEY_STARTED_AT = "startedAt"
        const val KEY_LAST_FIX_AT = "lastFixAt"
        const val KEY_PROVIDER = "provider"
        const val KEY_STATE = "stationaryState"

        private const val CHANNEL_ID = "propcare_tracking"
        private const val NOTIFICATION_ID = 4711
        private const val MAX_ACCURACY = 80.0
        private const val BREAK_HYSTERESIS = 1.6

        fun isTracking(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_TRACKING, false)

        fun batteryLevel(context: Context): Int {
            try {
                val manager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                val capacity = manager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
                if (capacity in 1..100) return capacity
            } catch (_: Exception) {
                // Fall through to the sticky broadcast.
            }
            return try {
                val intent = context.registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
                if (level >= 0 && scale > 0) level * 100 / scale else 0
            } catch (_: Exception) {
                0
            }
        }
    }

    private lateinit var prefs: SharedPreferences
    private lateinit var locationManager: LocationManager

    private var sessionId = ""
    private var employeeId = ""
    private var platform = "android"
    private var intervalMs = 12_000L
    private var distanceFilter = 5f
    private var stationaryRadius = 30.0
    private var stationarySeconds = 20L

    private var anchorLat = Double.NaN
    private var anchorLng = Double.NaN
    private var anchorSince = 0L
    private var lastInsideAt = 0L

    private var activeId: String? = null
    private var activeStartAt = 0L
    private var activeLat = 0.0
    private var activeLng = 0.0
    private var activeAccuracy = 0.0

    private var lastEmittedAt = 0L
    private var lastEmittedLat = 0.0
    private var lastEmittedLng = 0.0
    private var updatesRegistered = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private val stationaryHeartbeatRunnable = object : Runnable {
        override fun run() {
            checkStationaryHeartbeat()
            if (updatesRegistered) {
                mainHandler.postDelayed(this, 3_000L)
            }
        }
    }

    private fun checkStationaryHeartbeat() {
        if (anchorLat.isNaN() || anchorSince <= 0) return
        val now = System.currentTimeMillis()
        if (now < anchorSince) return

        val heldMs = now - anchorSince
        if (heldMs >= stationarySeconds * 1_000) {
            if (activeId == null) {
                activeId = UUID.randomUUID().toString()
                activeStartAt = anchorSince
                activeLat = anchorLat
                activeLng = anchorLng
                activeAccuracy = if (activeAccuracy > 0) activeAccuracy else 5.0
                emitStationary("stationary_started", now, null, 0, "active")
            } else if (activeStartAt > 0) {
                val duration = ((now - activeStartAt) / 1_000).toInt().coerceIn(0, 86400)
                emitStationary("stationary_updated", now, now, duration, "active")
            }
            persistState()
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        createChannel()
        restoreState()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        val starting = intent?.action == ACTION_START || intent == null
        if (starting) {
            readConfig(intent)
            prefs.edit()
                .putBoolean(KEY_TRACKING, true)
                .putString(KEY_SESSION_ID, sessionId)
                .putString(KEY_EMPLOYEE_ID, employeeId)
                .apply()
            startForegroundCompat()
            startUpdates()
            broadcast(JSONObject().put("type", "status").put("tracking", true).put("sessionId", sessionId))
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopUpdates()
        prefs.edit().putBoolean(KEY_TRACKING, false).apply()
        broadcast(JSONObject().put("type", "status").put("tracking", false))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Config ───────────────────────────────────────────────────────────────

    private fun readConfig(intent: Intent?) {
        sessionId = intent?.getStringExtra(KEY_SESSION_ID)
            ?: prefs.getString(KEY_SESSION_ID, null)
            ?: ""
        employeeId = intent?.getStringExtra(KEY_EMPLOYEE_ID)
            ?: prefs.getString(KEY_EMPLOYEE_ID, null)
            ?: ""
        platform = intent?.getStringExtra(KEY_PLATFORM)
            ?: prefs.getString(KEY_PLATFORM, null)
            ?: "android"
        intervalMs = intent?.getLongExtra(KEY_INTERVAL, 0L)?.takeIf { it > 0 }
            ?: prefs.getLong(KEY_INTERVAL, 12_000L)
        distanceFilter = intent?.getFloatExtra(KEY_DISTANCE_FILTER, -1f)?.takeIf { it >= 0 }
            ?: prefs.getFloat(KEY_DISTANCE_FILTER, 5f)
        stationaryRadius = intent?.getDoubleExtra(KEY_STATIONARY_RADIUS, -1.0)?.takeIf { it > 0 }
            ?: prefs.getFloat(KEY_STATIONARY_RADIUS, 30f).toDouble()
        stationarySeconds = intent?.getLongExtra(KEY_STATIONARY_SECONDS, 0L)?.takeIf { it > 0 }
            ?: prefs.getLong(KEY_STATIONARY_SECONDS, 20L)

        prefs.edit()
            .putString(KEY_SESSION_ID, sessionId)
            .putString(KEY_EMPLOYEE_ID, employeeId)
            .putString(KEY_PLATFORM, platform)
            .putLong(KEY_INTERVAL, intervalMs)
            .putFloat(KEY_DISTANCE_FILTER, distanceFilter)
            .putFloat(KEY_STATIONARY_RADIUS, stationaryRadius.toFloat())
            .putLong(KEY_STATIONARY_SECONDS, stationarySeconds)
            .putLong(KEY_STARTED_AT, prefs.getLong(KEY_STARTED_AT, System.currentTimeMillis()))
            .apply()
    }

    // ── Location updates ─────────────────────────────────────────────────────

    private fun startUpdates() {
        if (updatesRegistered) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            broadcast(
                JSONObject()
                    .put("type", "error")
                    .put("message", "Location permission is missing, so background tracking cannot run.")
            )
            return
        }
        try {
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                intervalMs,
                distanceFilter,
                this,
                Looper.getMainLooper(),
            )
            if (locationManager.allProviders.contains(LocationManager.NETWORK_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    intervalMs * 2,
                    distanceFilter * 2,
                    this,
                    Looper.getMainLooper(),
                )
            }
            updatesRegistered = true
            mainHandler.removeCallbacks(stationaryHeartbeatRunnable)
            mainHandler.postDelayed(stationaryHeartbeatRunnable, 3_000L)

            // Seed with the last known fix so the map is not empty on resume.
            val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            var best: Location? = null
            for (provider in providers) {
                val candidate = try {
                    locationManager.getLastKnownLocation(provider)
                } catch (_: Exception) {
                    null
                }
                if (candidate != null && (best == null || candidate.time > best.time)) best = candidate
            }
            best?.let { handleLocation(it) }
        } catch (error: SecurityException) {
            broadcast(
                JSONObject()
                    .put("type", "error")
                    .put("message", "Background location permission was revoked.")
            )
        } catch (error: Exception) {
            broadcast(
                JSONObject()
                    .put("type", "error")
                    .put("message", error.message ?: "Unable to start location updates.")
            )
        }
    }

    private fun stopUpdates() {
        mainHandler.removeCallbacks(stationaryHeartbeatRunnable)
        if (!updatesRegistered) return
        try {
            locationManager.removeUpdates(this)
        } catch (_: Exception) {
            // Nothing to remove.
        }
        val now = System.currentTimeMillis()
        if (activeId != null) {
            val end = if (lastInsideAt > 0) lastInsideAt else now
            val duration = ((end - activeStartAt) / 1_000).toInt().coerceAtLeast(0)
            emitStationary("stationary_completed", now, end, duration, "completed")
            activeId = null
        } else if (!anchorLat.isNaN() && anchorSince > 0) {
            val heldMs = now - anchorSince
            if (heldMs >= stationarySeconds * 1_000) {
                activeId = UUID.randomUUID().toString()
                activeStartAt = anchorSince
                activeLat = anchorLat
                activeLng = anchorLng
                activeAccuracy = if (activeAccuracy > 0) activeAccuracy else 5.0
                val duration = (heldMs / 1_000).toInt().coerceAtLeast(20)
                emitStationary("stationary_completed", now, now, duration, "completed")
                activeId = null
            }
        }
        persistState()
        updatesRegistered = false
    }

    override fun onLocationChanged(location: Location) = handleLocation(location)

    override fun onProviderEnabled(provider: String) {}

    override fun onProviderDisabled(provider: String) {
        broadcast(
            JSONObject()
                .put("type", "error")
                .put("message", "$provider was turned off. Tracking will continue with the remaining provider.")
        )
    }

    @Deprecated("Deprecated in Android")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    private fun handleLocation(location: Location) {
        val now = if (location.time > 0) location.time else System.currentTimeMillis()
        val lat = location.latitude
        val lng = location.longitude

        // Two providers can report the same fix. Keep the stream clean.
        if (lastEmittedAt > 0 && abs(now - lastEmittedAt) < 1_500 &&
            distanceBetween(lastEmittedLat, lastEmittedLng, lat, lng) < 2
        ) {
            return
        }
        lastEmittedAt = now
        lastEmittedLat = lat
        lastEmittedLng = lng

        handleStationary(location, now)

        val stationary = activeId != null ||
            (location.hasSpeed() && location.speed < 0.5f)

        val record = JSONObject()
            .put("type", "location")
            .put("id", UUID.randomUUID().toString())
            .put("employeeId", employeeId)
            .put("sessionId", sessionId)
            .put("latitude", lat)
            .put("longitude", lng)
            .put("accuracy", location.accuracy.toDouble())
            .put("speed", if (location.hasSpeed()) location.speed.toDouble() else JSONObject.NULL)
            .put("bearing", if (location.hasBearing()) location.bearing.toDouble() else JSONObject.NULL)
            .put("battery", batteryLevel(this))
            .put("platform", "android")
            .put("movementStatus", if (stationary) "stationary" else "moving")
            .put("recordedAt", now)
            .put("source", "native")

        TrackingQueue.append(this, record)
        broadcast(record)
        prefs.edit().putLong(KEY_LAST_FIX_AT, now).putString(KEY_PROVIDER, location.provider).apply()
    }

    // ── Stationary state machine (mirror of StationaryDetector in Dart) ──────

    private fun handleStationary(location: Location, now: Long) {
        if (location.accuracy > MAX_ACCURACY) return

        if (anchorLat.isNaN()) {
            setAnchor(location, now)
            persistState()
            return
        }
        if (now < anchorSince) return

        val distance = distanceBetween(anchorLat, anchorLng, location.latitude, location.longitude)
        val breakDistance = stationaryRadius * BREAK_HYSTERESIS

        if (distance <= breakDistance) {
            lastInsideAt = now
            if (activeId == null && now - anchorSince >= stationarySeconds * 1_000) {
                activeId = UUID.randomUUID().toString()
                activeStartAt = anchorSince
                activeLat = anchorLat
                activeLng = anchorLng
                activeAccuracy = location.accuracy.toDouble()
                emitStationary("stationary_started", now, null, 0, "active")
            } else if (activeId != null) {
                val duration = ((now - activeStartAt) / 1_000).toInt().coerceAtLeast(0)
                emitStationary("stationary_updated", now, now, duration, "active")
            }
        } else {
            val end = if (lastInsideAt > 0) lastInsideAt else now
            val heldMs = end - anchorSince
            if (activeId != null) {
                val duration = ((end - activeStartAt) / 1_000).toInt().coerceAtLeast(0)
                emitStationary("stationary_completed", now, end, duration, "completed")
                activeId = null
            } else if (heldMs >= stationarySeconds * 1_000) {
                activeId = UUID.randomUUID().toString()
                activeStartAt = anchorSince
                activeLat = anchorLat
                activeLng = anchorLng
                activeAccuracy = location.accuracy.toDouble()
                val duration = (heldMs / 1_000).toInt().coerceAtLeast(20)
                emitStationary("stationary_completed", now, end, duration, "completed")
                activeId = null
            }
            setAnchor(location, now)
        }
        persistState()
    }

    private fun setAnchor(location: Location, now: Long) {
        anchorLat = location.latitude
        anchorLng = location.longitude
        anchorSince = now
        lastInsideAt = now
    }

    private fun emitStationary(
        type: String,
        now: Long,
        endAt: Long?,
        duration: Int,
        status: String,
    ) {
        val id = activeId ?: return
        // Never emit a hold with uninitialized or zero coordinates.
        if (abs(activeLat) < 0.0001 && abs(activeLng) < 0.0001) return
        val event = JSONObject()
            .put("type", type)
            .put("id", id)
            .put("employeeId", employeeId)
            .put("sessionId", sessionId)
            .put("latitude", activeLat)
            .put("longitude", activeLng)
            .put("startAt", activeStartAt)
            .put("durationSeconds", duration)
            .put("accuracy", activeAccuracy)
            .put("battery", batteryLevel(this))
            .put("status", status)
            .put("radiusMeters", stationaryRadius)
            .put("recordedAt", now)
            .put("source", "native")
        if (endAt != null) event.put("endAt", endAt)

        TrackingQueue.append(this, event)
        broadcast(event)
    }

    // ── Persistence so a process restart keeps the current stop ─────────────

    private fun persistState() {
        val state = JSONObject()
            .put("anchorLat", anchorLat)
            .put("anchorLng", anchorLng)
            .put("anchorSince", anchorSince)
            .put("lastInsideAt", lastInsideAt)
            .put("activeId", activeId ?: JSONObject.NULL)
            .put("activeStartAt", activeStartAt)
            .put("activeLat", activeLat)
            .put("activeLng", activeLng)
            .put("activeAccuracy", activeAccuracy)
        prefs.edit().putString(KEY_STATE, state.toString()).apply()
    }

    private fun restoreState() {
        val raw = prefs.getString(KEY_STATE, null) ?: return
        try {
            val state = JSONObject(raw)
            anchorLat = state.optDouble("anchorLat", Double.NaN)
            anchorLng = state.optDouble("anchorLng", Double.NaN)
            anchorSince = state.optLong("anchorSince", 0L)
            lastInsideAt = state.optLong("lastInsideAt", 0L)
            activeId = state.optString("activeId", "").takeIf { it.isNotEmpty() }
            activeStartAt = state.optLong("activeStartAt", 0L)
            activeLat = state.optDouble("activeLat", Double.NaN)
            activeLng = state.optDouble("activeLng", Double.NaN)
            activeAccuracy = state.optDouble("activeAccuracy", 0.0)
            // If active coordinates are invalid, discard the active hold entirely.
            if (activeId != null && (activeLat.isNaN() || activeLng.isNaN() ||
                    (kotlin.math.abs(activeLat) < 0.0001 && kotlin.math.abs(activeLng) < 0.0001))) {
                activeId = null
                activeStartAt = 0L
                activeLat = 0.0
                activeLng = 0.0
            }
        } catch (_: Exception) {
            // Corrupt state is not worth crashing over.
        }
    }

    // ── Notification / broadcast ─────────────────────────────────────────────

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Field tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps PropCare Track recording your route during the work day."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun startForegroundCompat() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val launch = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PropCare Track")
            .setContentText("Field tracking is active · route being recorded")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun broadcast(event: JSONObject) {
        try {
            val intent = Intent(ACTION_EVENT)
                .setPackage(packageName)
                .putExtra(EXTRA_EVENT, event.toString())
            sendBroadcast(intent)
        } catch (_: Exception) {
            // The record is already queued; the live UI will catch up on drain.
        }
    }

    private fun distanceBetween(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
        val earthRadius = 6_371_000.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLng = Math.toRadians(lng2 - lng1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * earthRadius * asin(min(1.0, sqrt(a)))
    }
}
