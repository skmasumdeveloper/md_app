import 'package:flutter/material.dart';

import '../Commons/app_theme_colors.dart';

class ProfileAvatar extends StatelessWidget {
  final String imageUrl;
  final String noImageLabel;

  const ProfileAvatar(
      {super.key, required this.imageUrl, required this.noImageLabel});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return imageUrl != ''
        ? Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
                color: colors.surfaceBg,
                image: DecorationImage(
                    fit: BoxFit.cover,
                    image: NetworkImage(
                      imageUrl,
                    )),
                shape: BoxShape.circle),
          )
        : Container(
            width: 35,
            height: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: colors.surfaceBg, shape: BoxShape.circle),
            child: Text(
              noImageLabel,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          );
  }
}
