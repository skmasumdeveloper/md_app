import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IOSLogger {
  static const MethodChannel _channel =
      MethodChannel('com.excellisit.cuapp/ioslogs');

  /// Start listening for iOS native logs
  static void startListening() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == "nativeLog") {
        final message = call.arguments as String?;
        if (message != null) {
          // Print to Flutter console
          // (you can also send to any logger plugin if you use one)
          debugPrint("📱 iOS LOG → $message");
        }
      }
      return null;
    });
  }
}
