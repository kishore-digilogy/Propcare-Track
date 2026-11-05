package com.example.propcare_track

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Wires the `propcare/tracking` MethodChannel and `propcare/tracking_events`
 * EventChannel to [TrackingService] and [TrackingQueue].
 */
class TrackingBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "propcare/tracking"
        private const val EVENT_CHANNEL = "propcare/tracking_events"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val prefs: SharedPreferences =
        context.getSharedPreferences(TrackingService.PREFS, Context.MODE_PRIVATE)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var sink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    init {
        eventChannel.setStreamHandler(this)
        methodChannel.setMethodCallHandler(::onMethodCall)
        registerReceiver()
    }

    private fun registerReceiver() {
        if (receiver != null) return
        val listener = object : BroadcastReceiver() {
            override fun onReceive(source: Context?, intent: Intent?) {
                if (intent?.action != TrackingService.ACTION_EVENT) return
                val payload = intent.getStringExtra(TrackingService.EXTRA_EVENT) ?: return
                val map = try {
                    TrackingQueue.toMap(JSONObject(payload))
                } catch (_: Exception) {
                    null
                } ?: return
                mainHandler.post { sink?.success(map) }
            }
        }
        receiver = listener
        try {
            ContextCompat.registerReceiver(
                context,
                listener,
                IntentFilter(TrackingService.ACTION_EVENT),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
        } catch (_: Exception) {
            receiver = null
        }
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        receiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (_: Exception) {
                // Already detached.
            }
        }
        receiver = null
        sink = null
    }

    // ── EventChannel ─────────────────────────────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        events?.success(
            mapOf(
                "type" to "status",
                "tracking" to TrackingService.isTracking(context),
                "sessionId" to prefs.getString(TrackingService.KEY_SESSION_ID, null),
            )
        )
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // ── MethodChannel ────────────────────────────────────────────────────────

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startTracking" -> startTracking(call, result)
            "stopTracking" -> stopTracking(result)
            "isTracking" -> result.success(TrackingService.isTracking(context))
            "getStatus" -> result.success(status())
            "getPendingRecords" -> result.success(TrackingQueue.pending(context))
            "ackPendingRecords" -> ack(call, result)
            "getBatteryLevel" -> result.success(TrackingService.batteryLevel(context))
            else -> result.notImplemented()
        }
    }

    private fun startTracking(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = call.argument<String>("sessionId") ?: ""
        if (sessionId.isEmpty()) {
            result.error("invalid_config", "A tracking session id is required.", null)
            return
        }
        val intent = Intent(context, TrackingService::class.java).apply {
            action = TrackingService.ACTION_START
            putExtra(TrackingService.KEY_SESSION_ID, sessionId)
            putExtra(TrackingService.KEY_EMPLOYEE_ID, call.argument<String>("employeeId") ?: "")
            putExtra(TrackingService.KEY_PLATFORM, call.argument<String>("platform") ?: "android")
            putExtra(
                TrackingService.KEY_INTERVAL,
                (call.argument<Any>("intervalMs") as? Number)?.toLong() ?: 12_000L,
            )
            putExtra(
                TrackingService.KEY_DISTANCE_FILTER,
                (call.argument<Any>("distanceFilterMeters") as? Number)?.toFloat() ?: 5f,
            )
            putExtra(
                TrackingService.KEY_STATIONARY_RADIUS,
                (call.argument<Any>("stationaryRadiusMeters") as? Number)?.toDouble() ?: 30.0,
            )
            putExtra(
                TrackingService.KEY_STATIONARY_SECONDS,
                (call.argument<Any>("stationarySeconds") as? Number)?.toLong() ?: 20L,
            )
        }
        try {
            ContextCompat.startForegroundService(context, intent)
            result.success(true)
        } catch (error: Exception) {
            result.error("start_failed", error.message ?: "Unable to start tracking.", null)
        }
    }

    private fun stopTracking(result: MethodChannel.Result) {
        try {
            context.stopService(Intent(context, TrackingService::class.java))
            prefs.edit().putBoolean(TrackingService.KEY_TRACKING, false).apply()
            result.success(true)
        } catch (error: Exception) {
            result.error("stop_failed", error.message ?: "Unable to stop tracking.", null)
        }
    }

    private fun ack(call: MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<List<Any?>>("ids") ?: emptyList()
        val ids = raw.mapNotNull { it?.toString() }.toSet()
        try {
            TrackingQueue.ack(context, ids)
            result.success(true)
        } catch (error: Exception) {
            result.error("ack_failed", error.message ?: "Unable to acknowledge records.", null)
        }
    }

    private fun status(): Map<String, Any?> = mapOf(
        "tracking" to TrackingService.isTracking(context),
        "sessionId" to prefs.getString(TrackingService.KEY_SESSION_ID, null),
        "employeeId" to prefs.getString(TrackingService.KEY_EMPLOYEE_ID, null),
        "lastFixAt" to prefs.getLong(TrackingService.KEY_LAST_FIX_AT, 0L),
        "provider" to prefs.getString(TrackingService.KEY_PROVIDER, null),
        "queueSize" to TrackingQueue.size(context),
    )
}
