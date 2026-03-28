package com.excellisit.cuapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import android.util.Log

/**
 * Foreground service with [ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION].
 *
 * On Android 14+ (API 34) the `project_media` app-op must be set **before**
 * [startForeground] is called. This means the user must have already approved
 * the screen-capture consent dialog (`createScreenCaptureIntent()`) before the
 * service is started. [MainActivity.onActivityResult] ensures this ordering.
 *
 * When the system stops the MediaProjection (user taps "Stop sharing" in the
 * system notification / cast bar), the foreground-service type becomes invalid.
 * On Android 14+ the system itself will force-stop this service shortly after,
 * which triggers [onDestroy] and our broadcast.  On older versions we use a
 * periodic [Handler] check: if a [stopSelf] was requested by Flutter (via
 * [stopScreenCaptureService]) the handler detects the flag change and
 * self-terminates.  Additionally the Flutter-side polling timer cross-checks
 * via WebRTC stats (framesSent stalls) as the ultimate fallback.
 */
class ScreenCaptureService : Service() {
    private val CHANNEL_ID = "cuapp_screen_capture"

    companion object {
        /** Thread-safe flag checked from the main thread after posting service start. */
        @Volatile
        var isRunning = false
        private const val NOTIF_ID = 12345
    }

    private val handler = Handler(Looper.getMainLooper())

    /// Periodic watchdog that checks every 3 s whether the foreground service
    /// type is still valid.  If re-asserting startForeground throws, the
    /// MediaProjection was revoked and we self-stop. This primarily helps on
    /// Android 10-13 where the system does NOT auto-kill the service.
    private val watchdogRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    // Re-assert the foreground notification — this is a no-op
                    // if the projection is still alive, but throws
                    // ForegroundServiceStartNotAllowedException or
                    // SecurityException when the projection was revoked.
                    startForeground(
                        NOTIF_ID,
                        buildNotification(),
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                    )
                } catch (e: Exception) {
                    Log.d("ScreenCaptureService", "Watchdog: foreground type revoked — self-stopping ($e)")
                    stopSelf()
                    return
                }
            }
            handler.postDelayed(this, 3000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Screen Capture"
            val descriptionText = "Service for media projection (screen capture)"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CU")
            .setContentText("Sharing your screen")
            .setSmallIcon(this.applicationInfo.icon)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (isRunning) return START_STICKY

        try {
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIF_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            } else {
                startForeground(NOTIF_ID, notification)
            }
            // ✅ Only mark running AFTER startForeground succeeds
            isRunning = true
            Log.d("ScreenCaptureService", "Foreground service started successfully")

            // Start the watchdog that detects MediaProjection revocation
            handler.postDelayed(watchdogRunnable, 3000)
        } catch (e: Exception) {
            Log.e("ScreenCaptureService", "Failed to start foreground service: ${e.message}")
            // Cannot run as foreground — stop self immediately
            isRunning = false
            stopSelf()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(watchdogRunnable)
        val wasRunning = isRunning
        isRunning = false
        Log.d("ScreenCaptureService", "Screen capture service stopped (wasRunning=$wasRunning)")

        // Notify Flutter that the screen capture was stopped (e.g. user tapped
        // "Stop sharing" in the system notification / cast dialog).
        if (wasRunning) {
            try {
                val intent = Intent("CUAPP_EVENT")
                intent.putExtra("action", "screenShareStopped")
                sendBroadcast(intent)
            } catch (e: Exception) {
                Log.e("ScreenCaptureService", "Failed to send screenShareStopped: ${e.message}")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
