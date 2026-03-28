import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_sizes.dart';
import 'app_theme_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false,
      dividerColor: AppColors.grey,
      brightness: Brightness.light,
      cardColor: AppThemeColors.light.cardBg,
      primaryColor: AppColors.primary,
      hintColor: AppColors.darkGrey,
      dialogBackgroundColor: AppThemeColors.light.cardBg,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: AppSizes.elevation5, backgroundColor: AppColors.primary),
      appBarTheme: AppBarTheme(
        iconTheme: const IconThemeData(
          size: AppSizes.appBarIconSize,
          color: AppColors.primary,
        ),
        backgroundColor: AppThemeColors.light.cardBg,
        elevation: AppSizes.elevation0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppThemeColors.light.textPrimary,
          fontSize: AppSizes.bodyText1,
          fontWeight: FontWeight.w500,
        ),
        foregroundColor: AppThemeColors.light.textPrimary,
      ),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: AppColors.primary.withOpacity(0.7)),
      checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppSizes.kDefaultPadding * 5))),
      scaffoldBackgroundColor: AppThemeColors.light.scaffoldBg,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      tabBarTheme: TabBarThemeData(
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        labelColor: AppThemeColors.light.textOnPrimary,
        indicatorSize: TabBarIndicatorSize.tab,
        unselectedLabelColor: AppColors.lightGrey,
        indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.primary)),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
            color: AppThemeColors.light.textPrimary,
            fontSize: AppSizes.headline1,
            fontWeight: FontWeight.w700),
        displayMedium: TextStyle(
            color: AppThemeColors.light.textPrimary,
            fontSize: AppSizes.headline2,
            fontWeight: FontWeight.w700),
        displaySmall: TextStyle(
            color: AppThemeColors.light.textPrimary,
            fontSize: AppSizes.headline3,
            fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(
            color: AppThemeColors.light.textPrimary,
            fontSize: AppSizes.headline4,
            fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(
            color: AppThemeColors.light.textPrimary,
            fontSize: AppSizes.headline5,
            fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            color: AppThemeColors.light.textPrimary,
            fontSize: AppSizes.headline6,
            fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(
            color: AppThemeColors.light.textPrimary,
            fontSize: AppSizes.bodyText1,
            fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(
            color: AppThemeColors.light.textSecondary,
            fontSize: AppSizes.bodyText2,
            fontWeight: FontWeight.w400),
        bodySmall: TextStyle(
            color: AppThemeColors.light.textSecondary,
            fontSize: AppSizes.caption,
            fontWeight: FontWeight.w400),
        labelLarge: TextStyle(
            color: AppThemeColors.light.textOnPrimary,
            fontSize: AppSizes.button,
            fontWeight: FontWeight.w600),
      ),
      colorScheme: ColorScheme.fromSwatch(
              primarySwatch: AppColors.generateMaterialColor(AppColors.primary))
          .copyWith(surface: AppThemeColors.light.cardBg),
      extensions: const <ThemeExtension<dynamic>>[
        AppThemeColors.light,
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: false,
      dividerColor: AppThemeColors.dark.dividerColor,
      brightness: Brightness.dark,
      cardColor: AppThemeColors.dark.cardBg,
      primaryColor: AppColors.primary,
      hintColor: AppThemeColors.dark.textTertiary,
      dialogBackgroundColor: AppThemeColors.dark.cardBg,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: AppSizes.elevation5, backgroundColor: AppColors.primary),
      appBarTheme: AppBarTheme(
        iconTheme: const IconThemeData(
          size: AppSizes.appBarIconSize,
          color: AppColors.primary,
        ),
        backgroundColor: AppThemeColors.dark.cardBg,
        elevation: AppSizes.elevation0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppThemeColors.dark.textPrimary,
          fontSize: AppSizes.bodyText1,
          fontWeight: FontWeight.w500,
        ),
        foregroundColor: AppThemeColors.dark.textPrimary,
      ),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: AppColors.primary.withOpacity(0.7)),
      checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppSizes.kDefaultPadding * 5))),
      scaffoldBackgroundColor: AppThemeColors.dark.scaffoldBg,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      tabBarTheme: TabBarThemeData(
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        labelColor: AppThemeColors.dark.textOnPrimary,
        indicatorSize: TabBarIndicatorSize.tab,
        unselectedLabelColor: AppThemeColors.dark.textTertiary,
        indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.primary)),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
            color: AppThemeColors.dark.textPrimary,
            fontSize: AppSizes.headline1,
            fontWeight: FontWeight.w700),
        displayMedium: TextStyle(
            color: AppThemeColors.dark.textPrimary,
            fontSize: AppSizes.headline2,
            fontWeight: FontWeight.w700),
        displaySmall: TextStyle(
            color: AppThemeColors.dark.textPrimary,
            fontSize: AppSizes.headline3,
            fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(
            color: AppThemeColors.dark.textPrimary,
            fontSize: AppSizes.headline4,
            fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(
            color: AppThemeColors.dark.textPrimary,
            fontSize: AppSizes.headline5,
            fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            color: AppThemeColors.dark.textPrimary,
            fontSize: AppSizes.headline6,
            fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(
            color: AppThemeColors.dark.textPrimary,
            fontSize: AppSizes.bodyText1,
            fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(
            color: AppThemeColors.dark.textSecondary,
            fontSize: AppSizes.bodyText2,
            fontWeight: FontWeight.w400),
        bodySmall: TextStyle(
            color: AppThemeColors.dark.textSecondary,
            fontSize: AppSizes.caption,
            fontWeight: FontWeight.w400),
        labelLarge: TextStyle(
            color: AppThemeColors.dark.textOnPrimary,
            fontSize: AppSizes.button,
            fontWeight: FontWeight.w600),
      ),
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppThemeColors.dark.cardBg,
        onPrimary: AppThemeColors.dark.textOnPrimary,
        onSurface: AppThemeColors.dark.textPrimary,
        onSecondary: AppThemeColors.dark.textOnPrimary,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppThemeColors.dark,
      ],
    );
  }
}
