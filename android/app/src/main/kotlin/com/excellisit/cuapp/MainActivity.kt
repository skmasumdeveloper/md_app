package com.excellisit.cuapp

import android.app.PictureInPictureParams
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.Rational
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val SCREEN_CAPTURE_CHANNEL = "cuapp/screen_capture"
    private val CALL_CHANNEL = "cuapp/call_service"

    private var callChannel: MethodChannel? = null
    private var screenCaptureChannel: MethodChannel? = null
    private var isOverlayActive = false
    private var isScreenSharing = false

    private val eventReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.getStringExtra("action")
            if (action == "screenShareStopped") {
                // ScreenCaptureService was destroyed (user stopped via notification)
                Log.d("MainActivity", "eventReceiver: screenShareStopped")
                isScreenSharing = false
                try {
                    screenCaptureChannel?.invokeMethod("onScreenShareStopped", null)
                } catch (e: Exception) {
                    Log.w("MainActivity", "Failed to notify Flutter of screen share stop: ${e.message}")
                }
            } else if (action != null) {
                callChannel?.invokeMethod("onCallAction", action)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val filter = IntentFilter("CUAPP_EVENT")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(eventReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(eventReceiver, filter)
            }
        }
    }

    override fun onDestroy() {
        // Reset screen sharing flag to avoid stale state on re-creation
        isScreenSharing = false
        super.onDestroy()
        try {
            unregisterReceiver(eventReceiver)
        } catch (e: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Screen capture service channel — starts/stops ScreenCaptureService
        // with FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION.
        //
        // Flow (Android 14+):
        //   Dart calls Helper.requestCapturePermission()  → user approves consent
        //   → project_media app-op is set
        //   → Dart calls startScreenCaptureService        → service starts FGS
        //   → Dart calls getDisplayMedia()                → plugin reuses cached
        //     consent data and calls getMediaProjection() → works because FGS is
        //     already running.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CAPTURE_CHANNEL).also { ch ->
            screenCaptureChannel = ch
            ch.setMethodCallHandler { call, result ->
             when (call.method) {
                "startScreenCaptureService" -> {
                     try {
                         startScreenCaptureService()
                         result.success(true)
                     } catch (e: Exception) {
                         Log.e("MainActivity", "startScreenCaptureService: ${e.message}")
                         result.success(false)
                     }
                }
                "stopScreenCaptureService" -> {
                    stopScreenCaptureService()
                    result.success(true)
                }
                "isScreenCaptureRunning" -> {
                    result.success(ScreenCaptureService.isRunning)
                }
                else -> result.notImplemented()
             }
        }
        }

        callChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
        callChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCallService" -> {
                    startCallService()
                    result.success(true)
                }
                "stopCallService" -> {
                    stopCallService()
                    result.success(true)
                }
                "enterPip" -> {
                    if (isScreenSharing) {
                        Log.d("MainActivity", "enterPip: blocked — screen sharing active")
                        result.success(false)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val builder = PictureInPictureParams.Builder()
                            val aspectRatio = Rational(9, 16)
                            builder.setAspectRatio(aspectRatio)
                            enterPictureInPictureMode(builder.build())
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PIP_ERROR", e.message, null)
                        }
                    } else {
                        result.error("PIP_UNSUPPORTED", "PiP not supported", null)
                    }
                }
                "setOverlayActive" -> {
                    isOverlayActive = call.arguments as Boolean
                    result.success(true)
                }
                "setScreenSharing" -> {
                    isScreenSharing = call.arguments as Boolean
                    Log.d("MainActivity", "setScreenSharing: $isScreenSharing")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startCallService() {
        try {
            val intent = Intent(this, CallService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {}
    }

    private fun stopCallService() {
         try {
            val intent = Intent(this, CallService::class.java)
            stopService(intent)
        } catch (e: Exception) {}
    }

    private fun startScreenCaptureService() {
        val intent = Intent(this, ScreenCaptureService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopScreenCaptureService() {
        try {
            val intent = Intent(this, ScreenCaptureService::class.java)
            stopService(intent)
        } catch (e: Exception) {
            Log.e("MainActivity", "stopScreenCaptureService failed: ${e.message}")
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        tryEnterPip()
    }

    override fun finish() {
        // When a call is active, do NOT destroy the activity — move to background
        // instead. Destroying the activity detaches the Flutter engine, but WebRTC
        // ImageReader callbacks still fire on the main Handler and crash with
        // "FlutterJNI is not attached to native".
        if (CallService.isRunning) {
            Log.d("MainActivity", "finish(): call active — moveTaskToBack instead")
            moveTaskToBack(true)
            return
        }
        super.finish()
    }
    
    private fun tryEnterPip() {
        // Do NOT enter system PiP while screen sharing is active.
        // Entering PiP stops the MediaProjection, which tears down WebRTC
        // connections and detaches FlutterJNI — causing a fatal crash when
        // pending ImageReader callbacks fire on the main thread.
        if (isScreenSharing) {
            Log.d("MainActivity", "tryEnterPip: blocked — screen sharing active")
            return
        }
        if (CallService.isRunning) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    val builder = PictureInPictureParams.Builder()
                    val aspectRatio = Rational(9, 16)
                    builder.setAspectRatio(aspectRatio)
                    enterPictureInPictureMode(builder.build())
                } catch (e: Exception) {
                    Log.e("MainActivity", "tryEnterPip failed: ${e.message}")
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        try {
            callChannel?.invokeMethod("onPipStateChanged", isInPictureInPictureMode)
        } catch (e: Exception) {
            // FlutterJNI may already be detached if the engine was torn down
            // during a PiP transition (e.g. screen share teardown). Swallow
            // the error to prevent a fatal crash.
            Log.w("MainActivity", "onPipStateChanged: FlutterJNI not attached, ignoring: ${e.message}")
        }
    }
}
