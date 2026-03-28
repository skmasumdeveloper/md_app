import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlatformChannels {
  static final MethodChannel iosaudioplatform = MethodChannel(
      dotenv.env['IOS_AUDIO_METHOD_CHANNEL'] ?? 'fallback_channel');

  static final MethodChannel iosnavigationplatform = MethodChannel(
      dotenv.env['IOS_NAVIGATION_METHOD_CHANNEL'] ??
          'fallback_navigation_channel');

  // Android screen capture service control
  static final MethodChannel screenCapture =
      MethodChannel('cuapp/screen_capture');

  /// Callback fired when the native ScreenCaptureService is destroyed
  /// (e.g. user taps "Stop sharing" in the system notification / cast dialog).
  static VoidCallback? onScreenShareStopped;

  /// Call once (e.g. at app startup) to set up the method call handler
  /// that receives events from the native screen capture channel.
  static void initScreenCaptureListener() {
    screenCapture.setMethodCallHandler((call) async {
      if (call.method == 'onScreenShareStopped') {
        debugPrint('[PlatformChannels] onScreenShareStopped received');
        onScreenShareStopped?.call();
      }
    });
  }

  static Future<bool> startScreenCaptureService() async {
    if (!Platform.isAndroid) return true;
    try {
      final res =
          await screenCapture.invokeMethod<bool>('startScreenCaptureService');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopScreenCaptureService() async {
    if (!Platform.isAndroid) return true;
    try {
      final res =
          await screenCapture.invokeMethod<bool>('stopScreenCaptureService');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  /// Check whether the native ScreenCaptureService foreground service is
  /// still running. Used by the polling timer to distinguish between
  /// "MediaProjection paused" (single-app share, user left the shared app)
  /// and "MediaProjection dead" (user actually stopped sharing).
  static Future<bool> isScreenCaptureServiceRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      final res =
          await screenCapture.invokeMethod<bool>('isScreenCaptureRunning');
      return res == true;
    } catch (e) {
      return false;
    }
  }
}
