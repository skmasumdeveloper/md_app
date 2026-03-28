import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Controls the app theme mode (light, dark, system) with persistence via GetStorage.
class ThemeController extends GetxController {
  static const _storageKey = 'themeMode';
  final _storage = GetStorage();

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    _loadThemeMode();
  }

  void _loadThemeMode() {
    final stored = _storage.read<String>(_storageKey);
    switch (stored) {
      case 'light':
        themeMode.value = ThemeMode.light;
        break;
      case 'dark':
        themeMode.value = ThemeMode.dark;
        break;
      default:
        themeMode.value = ThemeMode.system;
    }
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    switch (mode) {
      case ThemeMode.light:
        _storage.write(_storageKey, 'light');
        break;
      case ThemeMode.dark:
        _storage.write(_storageKey, 'dark');
        break;
      case ThemeMode.system:
        _storage.write(_storageKey, 'system');
        break;
    }
    Get.forceAppUpdate();
  }

  String get currentLabel {
    switch (themeMode.value) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  IconData get currentIcon {
    switch (themeMode.value) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}
