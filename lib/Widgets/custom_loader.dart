import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../Commons/app_colors.dart';

// This widget provides a customizable loading indicator that adapts to the platform (Android or iOS).
class CustomLoader extends StatelessWidget {
  const CustomLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: Platform.isAndroid
                ? const AndroidLoadingDialog()
                : const IosLoadingIndicator()));
  }
}

class AndroidLoadingDialog extends StatelessWidget {
  const AndroidLoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(
      color: AppColors.primary,
    );
  }
}

class IosLoadingIndicator extends StatelessWidget {
  const IosLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoActivityIndicator();
  }
}
