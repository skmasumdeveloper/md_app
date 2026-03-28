import 'dart:math';

import 'package:flutter/material.dart';

/// This class defines the colors used throughout the application.
class AppColors {
  static const primary = Color(0xFF1DA678); // Changed to green
  static const secondary = Color(0xFF5F8F6F); // Changed to green
  static const gradientOne = Color(0xFF1DA678);
  static const gradientTwo = Color(0xFF5F8F6F);
  static const white = Color(0xFFFFFFFF);
  static const scaffold = Color(0xFFFEF5F0);
  static const bg = Color(0xFFF0F2F5);
  static const black = Color(0xFF000000);
  static const darkGrey = Color(0xFF464646);
  static const lightGrey = Color.fromARGB(255, 236, 184, 157);
  static const grey = Color(0xFF989696);
  static const shimmer = Color(0xFFF3F3F3);
  static const textFieldBg = Color(0xFFFFF3F0);
  static const transparent = Color(0x00FFFFFF);
  static const orange = Color(0xF7F27C41);
  static const receiverChatBubble = Color(0xFFDAC4BF);
  static const red = Color(0xF7D33E3E);
  static const error = Color(0xFF963636);
  static const green = Color(0xFF1DA678);
  static const blue = Color(0xFFFF8A00);
  static const facebook = Color(0xFF3b5998);
  static const twitter = Color(0xFF00ACEE);
  static const instagram = Color(0xFF833AB4);
  static const youtube = Color(0xFFc4302b);
  static const statusBackground = Color(0xffd9fad4);
  static const successSnackBarBackground = Color(0xff6c9d67);
  // static const hedingColor = primary;
  static const hedingColor = gradientOne;
  static const textColorSecondary = Color(0xFF074560);
  static const chatHighlightColor = Color.fromARGB(255, 65, 65, 189);
  static const loginBgColor = Color(0xFFFAF6F0);
  static const buttonGradientColor = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, secondary]);
  static const buttonGradientColorwelcome = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [orange, orange]);

  /// Gradient used for all AppBar flexibleSpace backgrounds (same in light & dark).
  static const appBarGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [primary, gradientOne, gradientTwo, secondary]);
  // body gap color behind rounded corners on screens with appBarGradient — matches the mid-bottom of the gradient so the transition looks seamless.

  /// Solid color for the body gap behind rounded corners — matches the
  /// mid-bottom of [appBarGradient] so the transition looks seamless.
  static const appBarBottomGradientColor = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [primary, gradientOne, gradientTwo, secondary]);

  static const themeGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.25, 0.5, 0.75, 1.0],
      colors: [primary, gradientOne, gradientTwo, secondary]);

  static MaterialColor generateMaterialColor(Color color) {
    return MaterialColor(color.value, {
      50: tintColor(color, 0.9),
      100: tintColor(color, 0.8),
      200: tintColor(color, 0.6),
      300: tintColor(color, 0.4),
      400: tintColor(color, 0.2),
      500: color,
      600: shadeColor(color, 0.1),
      700: shadeColor(color, 0.2),
      800: shadeColor(color, 0.3),
      900: shadeColor(color, 0.4),
    });
  }

  static int tintValue(int value, double factor) =>
      max(0, min((value + ((255 - value) * factor)).round(), 255));

  static Color tintColor(Color color, double factor) => Color.fromRGBO(
      tintValue(color.red, factor),
      tintValue(color.green, factor),
      tintValue(color.blue, factor),
      1);

  static int shadeValue(int value, double factor) =>
      max(0, min(value - (value * factor).round(), 255));

  static Color shadeColor(Color color, double factor) => Color.fromRGBO(
      shadeValue(color.red, factor),
      shadeValue(color.green, factor),
      shadeValue(color.blue, factor),
      1);
}
