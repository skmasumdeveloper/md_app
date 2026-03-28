import 'package:flutter/material.dart';

// This service provides navigation functionality throughout the application, allowing for easy route management.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;

  static Future<T?> push<T>(Route<T> route) {
    return navigatorKey.currentState!.push(route);
  }

  static void pop<T>([T? result]) {
    navigatorKey.currentState!.pop(result);
  }

  // Add more navigation methods as needed
}
