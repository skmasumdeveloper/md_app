import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../Commons/app_theme_colors.dart';

class ShimmerEffectLaoder extends StatelessWidget {
  final int numberOfWidget;
  const ShimmerEffectLaoder({super.key, required this.numberOfWidget});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      direction: ShimmerDirection.ttb,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 20),
        itemCount: numberOfWidget,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ListTile(
              trailing: const Text(""),
              leading: CircleAvatar(
                radius: 30,
                backgroundColor: colors.cardBg,
              ),
              title: Container(
                width: double.infinity,
                height: 40.0,
                color: colors.cardBg,
              ),
            ),
          );
        },
      ),
    );
  }
}
