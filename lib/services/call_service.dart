import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Platform bridge for the native Android CallService and system PiP.
///
/// Handles:
/// - Starting/stopping the Android foreground service (keeps WebRTC alive)
/// - Entering Android system PiP (when user presses Home)
/// - Receiving PiP state changes from native
/// - Receiving notification action callbacks (End Call, etc.)
///
/// In-app PiP (floating overlay) is handled by [CallOverlayManager].
/// iOS support will be added later.
class CallService {
  static const MethodChannel _channel = MethodChannel('cuapp/call_service');

  static void _log(String stage, [Map<String, dynamic>? details]) {
    if (details == null || details.isEmpty) {
      debugPrint('[CallService][$stage]');
      return;
    }
    debugPrint('[CallService][$stage] $details');
  }

  /// True when the Android system PiP mode is active (app shrunk to corner).
  static final RxBool isSystemPipActive = false.obs;

  /// Callback fired when the user taps "End Call" from the notification.
  /// Set this in GroupcallController or VideoCallScreen to wire up the action.
  static VoidCallback? onEndCallRequested;

  static Future<void> init() async {
    _log('init');
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    _log('methodCall', {
      'method': call.method,
      'arguments': call.arguments?.toString() ?? '',
    });

    switch (call.method) {
      case 'onPipStateChanged':
        isSystemPipActive.value = call.arguments as bool;
        _log('onPipStateChanged',
            {'isSystemPipActive': isSystemPipActive.value});
        break;
      case 'onCallAction':
        final action = call.arguments as String;
        _handleCallAction(action);
        break;
    }
  }

  static void _handleCallAction(String action) {
    _log('onCallAction', {'action': action});
    if (action == 'endCall') {
      onEndCallRequested?.call();
    }
  }

  /// Start the Android foreground service to keep the call alive in background.
  static Future<void> startService() async {
    _log('startService:invoke');
    try {
      await _channel.invokeMethod('startCallService');
      _log('startService:success');
    } catch (e) {
      _log('startService:error', {'error': e.toString()});
      // Service start may fail on some devices — non-fatal
    }
  }

  /// Stop the foreground service.
  static Future<void> stopService() async {
    _log('stopService:invoke');
    try {
      await _channel.invokeMethod('stopCallService');
      _log('stopService:success');
    } catch (e) {
      _log('stopService:error', {'error': e.toString()});
      // Non-fatal
    }
  }

  /// Request Android system PiP mode (used when leaving the app via Home).
  /// Request system PiP mode. Returns true if the call succeeded.
  static Future<bool> enterSystemPip() async {
    _log('enterSystemPip:invoke');
    try {
      final res = await _channel.invokeMethod<bool>('enterPip');
      _log('enterSystemPip:result', {'success': res == true});
      return res == true;
    } catch (e) {
      _log('enterSystemPip:error', {'error': e.toString()});
      // PiP may not be supported on all devices or platforms
      return false;
    }
  }

  /// Tell the native side whether the in-app overlay is active.
  /// When active, pressing Home should NOT enter system PiP (it would
  /// shrink the chat screen instead of the call UI).
  static Future<void> setOverlayActive(bool active) async {
    _log('setOverlayActive:invoke', {'active': active});
    try {
      await _channel.invokeMethod('setOverlayActive', active);
      _log('setOverlayActive:success', {'active': active});
    } catch (_) {}
  }

  /// Tell the native side whether screen sharing is active.
  /// When active, entering system PiP is blocked because the PiP transition
  /// stops the MediaProjection, which tears down WebRTC and crashes the app.
  static Future<void> setScreenSharing(bool active) async {
    _log('setScreenSharing:invoke', {'active': active});
    try {
      await _channel.invokeMethod('setScreenSharing', active);
      _log('setScreenSharing:success', {'active': active});
    } catch (_) {}
  }
}
