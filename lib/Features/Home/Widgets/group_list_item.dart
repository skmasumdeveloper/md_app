import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Models/group.dart';
import 'package:cu_app/Models/message.dart';
import 'package:flutter/material.dart';
import '../../../Commons/app_colors.dart';
import '../../../Commons/app_sizes.dart';
import '../../../Utils/app_helper.dart';
import '../../../Widgets/custom_divider.dart';

// This widget displays a list item for a group, showing the group's profile picture, name, and description.
class GroupListItem extends StatefulWidget {
  final Group groupsModel;

  const GroupListItem({super.key, required this.groupsModel});

  @override
  State<GroupListItem> createState() => _GroupListItemState();
}

class _GroupListItemState extends State<GroupListItem> {
  Message? message;

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
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  imageUrl: widget.groupsModel.profilePicture ?? '',
                  placeholder: (context, url) => const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.shimmer,
                  ),
                  errorWidget: (context, url, error) => CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.shimmer,
                    child: Text(
                      widget.groupsModel.name!
                          .substring(0, 1)
                          .toString()
                          .toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              widget.groupsModel.name ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            AppHelper.getStringTimeFromTimestamp(
                                widget.groupsModel.time!),
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(
                                    fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: AppSizes.kDefaultPadding / 3,
                      ),
                      Text(
                        widget.groupsModel.groupDescription!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 74),
          child: CustomDivider(),
        )
      ],
    );
  }
}
