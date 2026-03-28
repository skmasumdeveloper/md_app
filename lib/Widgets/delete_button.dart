import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';

import '../Commons/app_colors.dart';
import '../Commons/app_sizes.dart';
import '../Commons/app_theme_colors.dart';

class DeleteButton extends StatelessWidget {
  final String? label;
  final VoidCallback onPressed;

  const DeleteButton({super.key, this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSizes.kDefaultPadding),
        color: colors.cardBg,
        height: AppSizes.buttonHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              EvaIcons.trash2Outline,
              color: AppColors.red,
              size: 18,
            ),
            const SizedBox(
              width: AppSizes.kDefaultPadding,
            ),
            Text(
              label ?? 'Delete Group',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: AppColors.red, fontWeight: FontWeight.w500),
            )
          ],
        ),
      ),
    );
  }
}
