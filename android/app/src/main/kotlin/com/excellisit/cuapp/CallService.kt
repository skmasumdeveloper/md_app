package com.excellisit.cuapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class CallService : Service() {
    companion object {
        const val CHANNEL_ID = "cuapp_call_service"
        const val NOTIF_ID = 888
        const val ACTION_END_CALL = "com.excellisit.cuapp.ACTION_END_CALL"
        const val ACTION_MUTE_CALL = "com.excellisit.cuapp.ACTION_MUTE_CALL"
        const val ACTION_SPEAKER_CALL = "com.excellisit.cuapp.ACTION_SPEAKER_CALL"
        
        var isRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            when (intent.action) {
                ACTION_END_CALL -> {
                    // Send broadcast or use EventBus to tell Flutter to end call
                    val endIntent = Intent("CUAPP_EVENT")
                    endIntent.putExtra("action", "endCall")
                    sendBroadcast(endIntent)
                    stopSelf()
                    return START_NOT_STICKY
                }
                ACTION_MUTE_CALL -> {
                    val muteIntent = Intent("CUAPP_EVENT")
                    muteIntent.putExtra("action", "toggleMute")
                    sendBroadcast(muteIntent)
                }
                ACTION_SPEAKER_CALL -> {
                    val speakerIntent = Intent("CUAPP_EVENT")
                    speakerIntent.putExtra("action", "toggleSpeaker")
                    sendBroadcast(speakerIntent)
                }
            }
        }

        if (!isRunning) {
            isRunning = true
            startForegroundServiceCompat()
        }
        
        return START_STICKY
    }

    private fun startForegroundServiceCompat() {
        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val foregroundType = resolveForegroundType()
                startForeground(NOTIF_ID, notification, foregroundType)
            } else {
                startForeground(NOTIF_ID, notification)
            }
        } catch (se: SecurityException) {
            // Android 14+ enforces foreground service type + while-in-use permission checks.
            // Do not crash the app if the service cannot be elevated yet.
            stopSelf()
        } catch (e: Exception) {
            stopSelf()
        }
    }

    private fun resolveForegroundType(): Int {
        var type = 0

        val hasCamera = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        val hasMicrophone = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (hasCamera) {
            type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
        }
        if (hasMicrophone) {
            type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        }

        if (type == 0) {
            type = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        }

        return type
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        // Correct flags to restore existing activity without recreating
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)

        val endCallIntent = Intent(this, CallService::class.java).apply { action = ACTION_END_CALL }
        val endCallPendingIntent = PendingIntent.getService(this, 1, endCallIntent, PendingIntent.FLAG_IMMUTABLE)

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CU Call")
            .setContentText("Tap to return to call")
            .setSmallIcon(R.mipmap.ic_launcher) 
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
          //  .addAction(android.R.drawable.ic_menu_close_clear_cancel, "End Call", endCallPendingIntent)

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Call Service"
            val descriptionText = "Keeps call alive in background"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance)
            channel.description = descriptionText
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
