import 'package:cu_app/Commons/app_icons.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Features/Home/Presentation/home_screen.dart';
import 'package:cu_app/Utils/app_preference.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:flutter/material.dart';

import '../../Welcome/Presentation/welcome_screen.dart';

// This screen serves as the initial splash screen of the application, displaying the app logo and navigating to the home or welcome screen based on user authentication status.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AppPreference preference = AppPreference();
  String token = "";

  @override
  void initState() {
    _init();
    super.initState();
  }

  Future<void> _init() async {
    // Small delay helps ensure storage is ready on cold start / CallKit launch
    await Future.delayed(const Duration(milliseconds: 80));
    getUserTokenData();
    if (!mounted) return;
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => token.isNotEmpty
                ? const HomeScreen(
                    isDeleteNavigation: false,
                  )
                : const WelcomeScreen()));
  }

  getUserTokenData() {
    var userToken = LocalStorage().getUserToken();
    setState(() {
      token = userToken;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AppIcons.appLogo,
              width: 90,
              height: 90,
            ),
            const SizedBox(
              height: AppSizes.kDefaultPadding,
            ),
          ],
        ),
      ),
    );
  }
}
