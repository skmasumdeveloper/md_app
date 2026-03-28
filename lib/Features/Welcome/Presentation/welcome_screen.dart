import 'dart:async';
import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/Commons/app_images.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Features/Login/Presentation/login_screen.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AppImages.loginBack),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Image.asset(
              AppImages.appLogo,
              // width: 120,
              height: 120,
            ),
            const SizedBox(height: 10),
            Text(
              'Connecting Your Team',
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
            ),
            const Spacer(flex: 2),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: LinearProgressIndicator(
                color: AppColors.secondary,
                backgroundColor: colors.cardBg.withOpacity(0.54),
                minHeight: 4,
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
