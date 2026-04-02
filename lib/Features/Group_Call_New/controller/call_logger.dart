import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Centralized logging for the Group Call New module.
/// All logs are prefixed with [GroupCallNew] for easy filtering.
class CallLogger {
  static const String _tag = 'GroupCallNew';

  static void info(String scope, String message, [Map<String, dynamic>? details]) {
    _print('INFO', scope, message, details);
  }

  static void warn(String scope, String message, [Map<String, dynamic>? details]) {
    _print('WARN', scope, message, details);
  }

  static void error(String scope, String message, [Map<String, dynamic>? details]) {
    _print('ERROR', scope, message, details);
  }

  static void debug(String scope, String message, [Map<String, dynamic>? details]) {
    if (kDebugMode) {
      _print('DEBUG', scope, message, details);
    }
  }

  static void _print(
      String level, String scope, String message, Map<String, dynamic>? details) {
    final detailStr = details != null ? _safeEncode(details) : '';
    debugPrint('[$_tag][$level][$scope] $message${detailStr.isNotEmpty ? ' | $detailStr' : ''}');
  }

  static String _safeEncode(Map<String, dynamic> data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }
}
