import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';

import '../Commons/app_sizes.dart';
import '../Commons/app_theme_colors.dart';
import 'custom_text_field.dart';

class CustomSearchbar extends StatefulWidget {
  const CustomSearchbar({super.key});

  @override
  State<CustomSearchbar> createState() => _CustomSearchbarState();
}

class _CustomSearchbarState extends State<CustomSearchbar> {
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.kDefaultPadding),
      margin: const EdgeInsets.all(AppSizes.kDefaultPadding),
      decoration: BoxDecoration(
          color: colors.surfaceBg,
          border: Border.all(width: 1, color: colors.surfaceBg),
          borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius)),
      child: Row(
        children: [
          Icon(
            EvaIcons.searchOutline,
            size: 22,
            color: colors.iconSecondary,
          ),
          const SizedBox(
            width: AppSizes.kDefaultPadding,
          ),
          Expanded(
            child: CustomTextField(
              controller: searchController,
              hintText: 'Search groups...',
              minLines: 1,
              maxLines: 1,
              onChanged: (value) {
                return;
              },
              isBorder: false,
            ),
          )
        ],
      ),
    );
  }
}
