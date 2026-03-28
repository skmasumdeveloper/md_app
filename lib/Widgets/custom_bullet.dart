import 'package:flutter/cupertino.dart';

import '../Commons/app_colors.dart';

// This widget provides a customizable bullet point, typically used in lists or as indicators.
class CustomBullet extends StatelessWidget {
  final Color? bgColor;
  final double? width;
  final double? height;

  const CustomBullet({Key? key, this.bgColor, this.width, this.height})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? 10,
      height: height ?? 10,
      decoration: BoxDecoration(
          color: bgColor ?? AppColors.primary, shape: BoxShape.circle),
    );
  }
}
