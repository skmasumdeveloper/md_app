import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Commons/theme_controller.dart';
import 'package:cu_app/Features/Login/Controller/login_controller.dart';
import 'package:cu_app/Features/MyProfile/Presentation/my_profile_screen.dart';
import 'package:cu_app/Widgets/custom_divider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Commons/app_images.dart';
import '../../../Utils/safe_cached_image.dart';
import '../../../Utils/storage_service.dart';
import '../../../Widgets/custom_confirmation_dialog.dart';
import '../../Group_Call_old/controller/group_call.dart';
import '../../Home/Controller/socket_controller.dart';
import '../../Login/Presentation/login_screen.dart';
import '../../Navigation/Controller/navigation_controller.dart';
import '../../SoftwareLicencesScreen/Presentation/licenses_screen.dart';

// This screen provides the settings options for the user, including profile settings, software licenses, and logout functionality.
class SettingsScreen extends StatelessWidget {
  SettingsScreen({super.key});

  final loginController = Get.put(LoginController());
  final socketController = Get.put(SocketController());

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
          child: Padding(
            padding: const EdgeInsets.only(top: 30),
            child: SizedBox(
              width: 100,
              height: 100,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AppImages.appLogoWhite),
                    fit: BoxFit.contain,
                    opacity: 0.2,
                    filterQuality: FilterQuality.high,
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.appBarBottomGradientColor),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: colors.scaffoldBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
            child: Column(
              children: [
                _buildProfileSection(context),
                const SizedBox(height: AppSizes.kDefaultPadding * 2),
                _buildSettingsList(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Obx(
        () => Row(
          children: [
            ClipOval(
              child: SafeCachedImage(
                imageUrl: loginController.userModel.value.image,
                width: 60,
                height: 60,
                placeholder:
                    CircleAvatar(radius: 30, backgroundColor: colors.surfaceBg),
                errorWidget: CircleAvatar(
                  radius: 30,
                  backgroundColor: colors.surfaceBg,
                  child: Text(loginController.userModel.value.name
                      .toString()[0]
                      .toUpperCase()),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.kDefaultPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loginController.userModel.value.name ?? "User",
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loginController.userModel.value.email ?? "",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .copyWith(color: colors.textTertiary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loginController.statusController.value.isEmpty
                        ? "Available"
                        : loginController.statusController.value,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    final colors = context.appColors;
    final themeController = Get.find<ThemeController>();
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            context: context,
            icon: Icons.person_outline,
            title: 'Profile Settings',
            subtitle: 'Edit your profile information',
            onTap: () {
              context.push(const MyProfileScreen());
            },
          ),
          const CustomDivider(),
          Obx(() => _buildSettingsItem(
                context: context,
                icon: themeController.currentIcon,
                title: 'Appearance',
                subtitle: '${themeController.currentLabel} mode',
                onTap: () {
                  _showThemeModeDialog(context);
                },
              )),
          const CustomDivider(),
          _buildSettingsItem(
            context: context,
            icon: Icons.info_outline,
            title: 'Software Licenses',
            subtitle: 'View licenses',
            onTap: () {
              context.push(const LicenseScreen());
            },
          ),
          const CustomDivider(),
          _buildSettingsItem(
            context: context,
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            onTap: () {
              _showLogoutDialog(context);
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colors = context.appColors;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.kDefaultPadding, vertical: 8),
      leading: Icon(
        icon,
        color: isDestructive ? colors.offlineStatus : AppColors.primary,
        size: 24,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            fontWeight: FontWeight.w500,
            color: isDestructive ? colors.offlineStatus : colors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context)
            .textTheme
            .bodySmall!
            .copyWith(color: colors.textTertiary),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: colors.textTertiary,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  void _showThemeModeDialog(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Obx(() => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Appearance'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildThemeOption(
                    dialogContext,
                    icon: Icons.brightness_auto,
                    title: 'System',
                    subtitle: 'Follow system setting',
                    isSelected:
                        themeController.themeMode.value == ThemeMode.system,
                    onTap: () => themeController.setThemeMode(ThemeMode.system),
                  ),
                  _buildThemeOption(
                    dialogContext,
                    icon: Icons.light_mode,
                    title: 'Light',
                    subtitle: 'Always use light theme',
                    isSelected:
                        themeController.themeMode.value == ThemeMode.light,
                    onTap: () => themeController.setThemeMode(ThemeMode.light),
                  ),
                  _buildThemeOption(
                    dialogContext,
                    icon: Icons.dark_mode,
                    title: 'Dark',
                    subtitle: 'Always use dark theme',
                    isSelected:
                        themeController.themeMode.value == ThemeMode.dark,
                    onTap: () => themeController.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Done',
                    style: Theme.of(dialogContext)
                        .textTheme
                        .bodyMedium!
                        .copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ));
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon,
          color:
              isSelected ? AppColors.primary : context.appColors.iconSecondary),
      title: Text(title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: context.appColors.textPrimary,
          )),
      subtitle: Text(subtitle,
          style: TextStyle(
            fontSize: 12,
            color: context.appColors.textTertiary,
          )),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _showLogoutDialog(BuildContext context) async {
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return Obx(() => ConfirmationDialog(
              title: 'Logout?',
              body: 'Are you sure you want to logout?',
              positiveButtonLabel:
                  loginController.isLoading.value ? "Loading..." : 'Logout',
              negativeButtonLabel: 'Cancel',
              onPressedPositiveButton: () async {
                final isLoggedOut = await loginController.logout();
                if (isLoggedOut == true) {
                  loginController.emailController.value.clear();
                  loginController.passwordController.value.clear();
                  loginController.isPasswordVisible(true);

                  final socketController = Get.isRegistered<SocketController>()
                      ? Get.find<SocketController>()
                      : null;

                  if (socketController != null) {
                    try {
                      socketController.socket?.clearListeners();
                      socketController.socket?.disconnect();
                      socketController.socket?.dispose();
                      socketController.socket?.destroy();
                      socketController.socket?.io.close();
                      socketController.socket = null;
                    } catch (e) {
                      debugPrint("Socket disconnect error: $e");
                    }
                    Get.delete<SocketController>(force: true);
                  }
                  LocalStorage().deleteAllLocalData();

                  Get.delete<NavigationController>();
                  Get.delete<GroupcallController>();

                  Get.deleteAll(force: true);

                  context.pushAndRemoveUntil(const LoginScreen());
                }
              }));
        });
  }
}
