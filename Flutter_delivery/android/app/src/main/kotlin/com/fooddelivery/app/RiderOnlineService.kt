package com.k9bharat.delivery

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Keeps the app's process alive for as long as the rider is online.
 *
 * This is the piece that separates our behaviour from Zomato/Swiggy/Uber, and it
 * fixes two things that were previously worked around rather than solved:
 *
 *  - GPS going stale. Android freezes a backgrounded process, so location updates
 *    stopped whenever the rider left the app on screen. The backend then treated
 *    them as stale and dropped them from dispatch, which meant no push, which meant
 *    nothing to wake the app to refresh the GPS — a loop the rider could not escape
 *    without reopening the app. The staleness window was widened to 45 minutes to
 *    paper over it; this addresses the cause.
 *
 *  - The overlay engine cold-starting on every order. With the process alive the
 *    Flutter engine stays warm, so the incoming-order UI has far less to do before
 *    it can paint.
 *
 * A foreground service is the ONLY supported way to ask Android not to reap a
 * process. The permanent notification is not decoration — it is the price Android
 * charges, and the contract that makes the guarantee hold.
 */
class RiderOnlineService : Service() {

    companion object {
        const val ACTION_START = "com.k9bharat.delivery.RIDER_ONLINE_START"
        const val ACTION_STOP = "com.k9bharat.delivery.RIDER_ONLINE_STOP"

        private const val CHANNEL_ID = "rider_online_channel"
        private const val NOTIFICATION_ID = 4711

        fun start(context: Context) {
            val intent = Intent(context, RiderOnlineService::class.java).setAction(ACTION_START)
            // startForegroundService obliges us to call startForeground() within
            // ~5s or Android kills the process with an ANR-style crash. onStartCommand
            // does it as its first act, before any other work.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, RiderOnlineService::class.java).setAction(ACTION_STOP)
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        // Never let this crash the app.
        //
        // startForeground() with type `location` throws when location permission is
        // not granted, and Android 12+ throws ForegroundServiceStartNotAllowedException
        // when a service is started from the background. Neither is caught by the
        // try/catch on the Dart side: that only wraps startForegroundService(), which
        // merely SCHEDULES this callback — the throw happens here, later, on the main
        // thread, and takes the whole process down.
        //
        // That is what crashed the app right after registration: the rider was
        // restored as online before they had ever granted location permission.
        //
        // Losing the keep-alive is a degradation. Crashing is not survivable, so on
        // any failure we stop cleanly and let the app carry on without it.
        return try {
            startForegroundCompat()

            // START_STICKY: if Android reclaims the process under memory pressure it
            // is recreated and onStartCommand runs again with a null intent — which
            // lands here and re-enters the foreground, restoring the guarantee
            // unattended.
            START_STICKY
        } catch (e: Exception) {
            stopSelf()
            // NOT sticky: a restart would hit the same missing permission and throw
            // again, turning one crash into a loop.
            START_NOT_STICKY
        }
    }

    private fun startForegroundCompat() {
        createChannel()

        val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            launch ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("You're online")
            .setContentText("Ready to receive new orders")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            // Silent and rankable-low: this is a persistent status, not an alert.
            // At default importance it would compete with the incoming-order alert
            // for the rider's attention every time the service restarts.
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setShowWhen(false)
            .build()

        // Android 10 wants the type; Android 14 rejects the call without it.
        // FOREGROUND_SERVICE_LOCATION is declared in the manifest, and the Dart
        // side only starts this once location permission has actually been granted
        // — starting a location-typed service without it throws.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Online status",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shown while you are online and available for orders"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }
}
