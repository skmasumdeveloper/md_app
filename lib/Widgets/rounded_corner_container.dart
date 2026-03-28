import 'package:flutter/material.dart';

import '../Commons/app_colors.dart';
import '../Commons/app_theme_colors.dart';

class RoundedCornerContainer extends StatelessWidget {
  final Widget child;
  final Color? bgColor;
  final double? radius;
  final Gradient? gradient;
  const RoundedCornerContainer(
      {super.key,
      required this.child,
      this.bgColor,
      this.radius,
      this.gradient});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration:
          const BoxDecoration(gradient: AppColors.appBarBottomGradientColor),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: bgColor ?? colors.scaffoldBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(
              radius ?? 20,
            ),
            topRight: Radius.circular(radius ?? 20),
          ),
        ),
        child: child,
      ),
    );
  }
}
