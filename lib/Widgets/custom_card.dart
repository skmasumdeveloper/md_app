import 'package:flutter/material.dart';

import '../Commons/app_sizes.dart';
import '../Commons/app_theme_colors.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onPressed;

  const CustomCard(
      {super.key,
      required this.child,
      this.padding,
      this.margin,
      this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: padding ?? EdgeInsets.zero,
        margin:
            margin ?? const EdgeInsets.only(bottom: AppSizes.kDefaultPadding),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
            border: Border.all(color: colors.borderColor, width: 1),
            color: colors.cardBg,
            boxShadow: [
              BoxShadow(
                offset: const Offset(-2, -2),
                blurRadius: 2,
                color: colors.shadowColor,
              ),
              BoxShadow(
                offset: const Offset(2, 2),
                blurRadius: 2,
                color: colors.shadowColor,
              ),
            ]),
        child: child,
      ),
    );
  }
}
