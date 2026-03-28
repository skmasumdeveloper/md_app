import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../Commons/app_colors.dart';
import '../../../Commons/app_sizes.dart';
import '../../../Models/user.dart';
import '../../../Widgets/custom_divider.dart';

// This widget displays a card for each member in the list, showing their profile picture, name, and email.
class MemberCardWidget extends StatelessWidget {
  final User member;
  final bool? isSelected;

  MemberCardWidget({
    super.key,
    required this.member,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppSizes.cardCornerRadius * 10),
                child: CachedNetworkImage(
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                  imageUrl: member.profilePicture ?? '',
                  placeholder: (context, url) => const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.shimmer,
                  ),
                  errorWidget: (context, url, error) => CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.shimmer,
                    child: Text(
                      member.name?.substring(0, 1) ?? '',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: AppSizes.kDefaultPadding,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name ?? '',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      member.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 56),
          child: CustomDivider(),
        )
      ],
    );
  }
}
