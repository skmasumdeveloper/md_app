import 'package:flutter/material.dart';

/// ThemeExtension holding all app-specific semantic colors.
/// Access via: `context.appColors` (see extension below).
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  // Backgrounds
  final Color scaffoldBg;
  final Color cardBg;
  final Color surfaceBg;
  final Color textFieldBg;
  final Color headerBg;
  final Color loginBg;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnPrimary;
  final Color textOnHeader;

  // Borders & Dividers
  final Color borderColor;
  final Color dividerColor;

  // Shimmer
  final Color shimmerBase;
  final Color shimmerHighlight;

  // Semantic
  final Color successBg;
  final Color errorText;
  final Color onlineStatus;
  final Color offlineStatus;
  final Color idleStatus;

  // Overlay & Shadow
  final Color shadowColor;
  final Color barrierColor;
  final Color toastBg;
  final Color toastText;
  final Color toastSubtext;

  // Icons
  final Color iconDefault;
  final Color iconSecondary;

  // Network error
  final Color networkErrorBg;
  final Color networkErrorIcon;
  final Color networkErrorText;

  // Progress
  final Color progressBg;
  final Color progressText;

  const AppThemeColors({
    required this.scaffoldBg,
    required this.cardBg,
    required this.surfaceBg,
    required this.textFieldBg,
    required this.headerBg,
    required this.loginBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnPrimary,
    required this.textOnHeader,
    required this.borderColor,
    required this.dividerColor,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.successBg,
    required this.errorText,
    required this.onlineStatus,
    required this.offlineStatus,
    required this.idleStatus,
    required this.shadowColor,
    required this.barrierColor,
    required this.toastBg,
    required this.toastText,
    required this.toastSubtext,
    required this.iconDefault,
    required this.iconSecondary,
    required this.networkErrorBg,
    required this.networkErrorIcon,
    required this.networkErrorText,
    required this.progressBg,
    required this.progressText,
  });

  static const light = AppThemeColors(
    scaffoldBg: Color(0xFFFEF5F0),
    cardBg: Color(0xFFFFFFFF),
    surfaceBg: Color(0xFFF0F2F5),
    textFieldBg: Color(0xFFFFF3F0),
    headerBg: Color(0xFFDE3A00),
    loginBg: Color(0xFFFAF6F0),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF464646),
    textTertiary: Color(0xFF989696),
    textOnPrimary: Color(0xFFFFFFFF),
    textOnHeader: Color(0xFFFFFFFF),
    borderColor: Color.fromARGB(255, 236, 184, 157),
    dividerColor: Color.fromARGB(255, 236, 184, 157),
    shimmerBase: Color(0xFFE0E0E0),
    shimmerHighlight: Color(0xFFF5F5F5),
    successBg: Color(0xffd9fad4),
    errorText: Color(0xFF963636),
    onlineStatus: Color(0xFF4CAF50),
    offlineStatus: Color(0xFFF44336),
    idleStatus: Color(0xFFFF9800),
    shadowColor: Color(0x1A000000),
    barrierColor: Color(0x33000000),
    toastBg: Color(0xF2FFFFFF),
    toastText: Color(0xFF000000),
    toastSubtext: Color(0xB3000000),
    iconDefault: Color(0xFF464646),
    iconSecondary: Color(0xFF989696),
    networkErrorBg: Color(0xFFFFCDD2),
    networkErrorIcon: Color(0xFFC62828),
    networkErrorText: Color(0xFFC62828),
    progressBg: Color(0xFFE0E0E0),
    progressText: Color(0xFF424242),
  );

  static const dark = AppThemeColors(
    scaffoldBg: Color(0xFF121212),
    cardBg: Color(0xFF1E1E1E),
    surfaceBg: Color(0xFF2C2C2C),
    textFieldBg: Color(0xFF2C2C2C),
    headerBg: Color(0xFFDE3A00),
    loginBg: Color(0xFF121212),
    textPrimary: Color(0xFFE0E0E0),
    textSecondary: Color(0xFFBDBDBD),
    textTertiary: Color(0xFF9E9E9E),
    textOnPrimary: Color(0xFFFFFFFF),
    textOnHeader: Color(0xFFFFFFFF),
    borderColor: Color(0xFF3A3A3A),
    dividerColor: Color(0xFF3A3A3A),
    shimmerBase: Color(0xFF2C2C2C),
    shimmerHighlight: Color(0xFF3A3A3A),
    successBg: Color(0xFF1B3A1B),
    errorText: Color(0xFFEF9A9A),
    onlineStatus: Color(0xFF66BB6A),
    offlineStatus: Color(0xFFEF5350),
    idleStatus: Color(0xFFFFA726),
    shadowColor: Color(0x40000000),
    barrierColor: Color(0x66000000),
    toastBg: Color(0xF22C2C2C),
    toastText: Color(0xFFE0E0E0),
    toastSubtext: Color(0xB3E0E0E0),
    iconDefault: Color(0xFFBDBDBD),
    iconSecondary: Color(0xFF9E9E9E),
    networkErrorBg: Color(0xFF4A1C1C),
    networkErrorIcon: Color(0xFFEF9A9A),
    networkErrorText: Color(0xFFEF9A9A),
    progressBg: Color(0xFF3A3A3A),
    progressText: Color(0xFFBDBDBD),
  );

  @override
  AppThemeColors copyWith({
    Color? scaffoldBg,
    Color? cardBg,
    Color? surfaceBg,
    Color? textFieldBg,
    Color? headerBg,
    Color? loginBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnPrimary,
    Color? textOnHeader,
    Color? borderColor,
    Color? dividerColor,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? successBg,
    Color? errorText,
    Color? onlineStatus,
    Color? offlineStatus,
    Color? idleStatus,
    Color? shadowColor,
    Color? barrierColor,
    Color? toastBg,
    Color? toastText,
    Color? toastSubtext,
    Color? iconDefault,
    Color? iconSecondary,
    Color? networkErrorBg,
    Color? networkErrorIcon,
    Color? networkErrorText,
    Color? progressBg,
    Color? progressText,
  }) {
    return AppThemeColors(
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      cardBg: cardBg ?? this.cardBg,
      surfaceBg: surfaceBg ?? this.surfaceBg,
      textFieldBg: textFieldBg ?? this.textFieldBg,
      headerBg: headerBg ?? this.headerBg,
      loginBg: loginBg ?? this.loginBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      textOnHeader: textOnHeader ?? this.textOnHeader,
      borderColor: borderColor ?? this.borderColor,
      dividerColor: dividerColor ?? this.dividerColor,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      successBg: successBg ?? this.successBg,
      errorText: errorText ?? this.errorText,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      offlineStatus: offlineStatus ?? this.offlineStatus,
      idleStatus: idleStatus ?? this.idleStatus,
      shadowColor: shadowColor ?? this.shadowColor,
      barrierColor: barrierColor ?? this.barrierColor,
      toastBg: toastBg ?? this.toastBg,
      toastText: toastText ?? this.toastText,
      toastSubtext: toastSubtext ?? this.toastSubtext,
      iconDefault: iconDefault ?? this.iconDefault,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      networkErrorBg: networkErrorBg ?? this.networkErrorBg,
      networkErrorIcon: networkErrorIcon ?? this.networkErrorIcon,
      networkErrorText: networkErrorText ?? this.networkErrorText,
      progressBg: progressBg ?? this.progressBg,
      progressText: progressText ?? this.progressText,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      surfaceBg: Color.lerp(surfaceBg, other.surfaceBg, t)!,
      textFieldBg: Color.lerp(textFieldBg, other.textFieldBg, t)!,
      headerBg: Color.lerp(headerBg, other.headerBg, t)!,
      loginBg: Color.lerp(loginBg, other.loginBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      textOnHeader: Color.lerp(textOnHeader, other.textOnHeader, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      onlineStatus: Color.lerp(onlineStatus, other.onlineStatus, t)!,
      offlineStatus: Color.lerp(offlineStatus, other.offlineStatus, t)!,
      idleStatus: Color.lerp(idleStatus, other.idleStatus, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      barrierColor: Color.lerp(barrierColor, other.barrierColor, t)!,
      toastBg: Color.lerp(toastBg, other.toastBg, t)!,
      toastText: Color.lerp(toastText, other.toastText, t)!,
      toastSubtext: Color.lerp(toastSubtext, other.toastSubtext, t)!,
      iconDefault: Color.lerp(iconDefault, other.iconDefault, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      networkErrorBg: Color.lerp(networkErrorBg, other.networkErrorBg, t)!,
      networkErrorIcon: Color.lerp(networkErrorIcon, other.networkErrorIcon, t)!,
      networkErrorText: Color.lerp(networkErrorText, other.networkErrorText, t)!,
      progressBg: Color.lerp(progressBg, other.progressBg, t)!,
      progressText: Color.lerp(progressText, other.progressText, t)!,
    );
  }
}

/// Convenience extension to access [AppThemeColors] from BuildContext.
extension AppThemeContext on BuildContext {
  AppThemeColors get appColors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
