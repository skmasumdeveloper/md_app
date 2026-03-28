import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../Commons/app_theme_colors.dart';

class ShimmerEffectForTexTWidget extends StatelessWidget {
  final String textName;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerEffectForTexTWidget(
      {super.key, required this.textName, this.baseColor, this.highlightColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Shimmer.fromColors(
      baseColor: baseColor ?? colors.shimmerBase,
      highlightColor: highlightColor ?? colors.shimmerHighlight,
      child: Text(
        textName,
        style: TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}
