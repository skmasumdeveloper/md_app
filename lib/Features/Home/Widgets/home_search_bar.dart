import 'package:cu_app/Widgets/custom_text_field.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import '../../../Commons/app_sizes.dart';
import '../../../Commons/app_theme_colors.dart';

// This widget provides a search bar for the home screen, allowing users to search for groups or contacts.
class HomeSearchBar extends StatelessWidget {
  final String? searchHint;

  const HomeSearchBar({Key? key, this.searchHint}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final TextEditingController searchController = TextEditingController();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.kDefaultPadding),
      decoration: BoxDecoration(
          color: colors.cardBg,
          border: Border.all(width: 1, color: colors.borderColor),
          boxShadow: [
            BoxShadow(
                offset: const Offset(7, 7),
                color: colors.shadowColor,
                blurRadius: 15),
            BoxShadow(
                offset: const Offset(-7, -7),
                color: colors.shimmerBase,
                blurRadius: 15)
          ],
          borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius * 3)),
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
              hintText: searchHint ?? 'Search groups...',
            ),
          )
        ],
      ),
    );
  }
}
