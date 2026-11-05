package com.example.propcare_track

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Best-effort restart of the tracking service after a reboot.
 *
 * Newer Android versions may refuse a location foreground service started from
 * BOOT_COMPLETED; in that case the app's resume hook restarts tracking as soon
 * as the employee opens PropCare Track. Records already written stay queued.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs = context.getSharedPreferences(TrackingService.PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(TrackingService.KEY_TRACKING, false)) return
        val sessionId = prefs.getString(TrackingService.KEY_SESSION_ID, null) ?: return

        val service = Intent(context, TrackingService::class.java).apply {
            action = TrackingService.ACTION_START
            putExtra(TrackingService.KEY_SESSION_ID, sessionId)
            putExtra(
                TrackingService.KEY_EMPLOYEE_ID,
                prefs.getString(TrackingService.KEY_EMPLOYEE_ID, ""),
            )
            putExtra(
                TrackingService.KEY_PLATFORM,
                prefs.getString(TrackingService.KEY_PLATFORM, "android"),
            )
            putExtra(TrackingService.KEY_INTERVAL, prefs.getLong(TrackingService.KEY_INTERVAL, 12_000L))
            putExtra(
                TrackingService.KEY_DISTANCE_FILTER,
                prefs.getFloat(TrackingService.KEY_DISTANCE_FILTER, 5f),
            )
            putExtra(
                TrackingService.KEY_STATIONARY_RADIUS,
                prefs.getFloat(TrackingService.KEY_STATIONARY_RADIUS, 30f).toDouble(),
            )
            putExtra(
                TrackingService.KEY_STATIONARY_SECONDS,
                prefs.getLong(TrackingService.KEY_STATIONARY_SECONDS, 20L),
            )
        }
        try {
            ContextCompat.startForegroundService(context, service)
        } catch (_: Exception) {
            // App resume will restart tracking.
        }
    }
}
