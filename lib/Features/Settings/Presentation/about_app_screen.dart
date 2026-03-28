import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Widgets/custom_divider.dart';
import 'package:flutter/material.dart';

// This screen displays information about the application, including its name, version, and other details.
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        title: Text(
          'About App',
          style: Theme.of(context)
              .textTheme
              .headlineSmall!
              .copyWith(color: AppColors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
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
                _buildAppInfoSection(context, colors),
                const SizedBox(height: AppSizes.kDefaultPadding * 2),
                _buildAppDetailsSection(context, colors),
                const SizedBox(height: AppSizes.kDefaultPadding * 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppInfoSection(BuildContext context, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.kDefaultPadding * 2),
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: AppSizes.kDefaultPadding),
          Text(
            AppStrings.appName,
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Modern Group Chat Application',
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: AppSizes.kDefaultPadding),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Version 1.0.10',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppDetailsSection(BuildContext context, AppThemeColors colors) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
            child: Text(
              'App Information',
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
          ),
          const CustomDivider(),
          _buildInfoItem(
            context: context,
            colors: colors,
            title: 'Developer',
            value: 'Excellis IT',
          ),
          const CustomDivider(),
          _buildInfoItem(
            context: context,
            colors: colors,
            title: 'Platform',
            value: 'Flutter',
          ),
          const CustomDivider(),
          _buildInfoItem(
            context: context,
            colors: colors,
            title: 'Build Number',
            value: '19',
          ),
          const CustomDivider(),
          _buildInfoItem(
            context: context,
            colors: colors,
            title: 'Release Date',
            value: 'December 2024',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required BuildContext context,
    required AppThemeColors colors,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.kDefaultPadding, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: colors.textTertiary),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w500, color: colors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalItem({
    required BuildContext context,
    required AppThemeColors colors,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.kDefaultPadding, vertical: 8),
      leading: Icon(
        icon,
        color: AppColors.primary,
        size: 24,
      ),
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .bodyMedium!
            .copyWith(fontWeight: FontWeight.w500, color: colors.textPrimary),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: colors.textTertiary,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Coming Soon'),
          content:
              const Text('This feature is coming soon in the next update.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
