import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Features/Home/Widgets/message_count.dart';
import 'package:cu_app/Widgets/custom_divider.dart';
import 'package:flutter/material.dart';

import 'blinking_icon_circle.dart';

// This widget displays a chat card for the home screen, showing group details, last message, and other relevant information.
class HomeChatCard extends StatelessWidget {
  final String groupName;
  final String? groupDesc;
  String sentTime;
  final String? lastMsg;
  final int? unseenMsgCount;
  final String? imageUrl;
  final VoidCallback onPressed, onPictureTap;
  final String groupId;
  final Widget child;
  final String? sendBy;
  final String? messageType;
  final int? messageCount;
  final String? callStatus;

  HomeChatCard(
      {super.key,
      required this.groupId,
      required this.groupName,
      required this.child,
      required this.sentTime,
      this.sendBy = '',
      required this.onPressed,
      this.groupDesc = '',
      this.imageUrl = '',
      this.lastMsg = '',
      this.unseenMsgCount,
      this.messageType,
      this.messageCount,
      this.callStatus,
      required this.onPictureTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onPictureTap,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppSizes.cardCornerRadius * 10),
                  child: CachedNetworkImage(
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    imageUrl: imageUrl ?? "",
                    placeholder: (context, url) => const CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.shimmer,
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                      child: Text(
                        groupName.substring(0, 1).toString().toUpperCase(),
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding),
                  child: InkWell(
                    onTap: onPressed,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      groupName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  callStatus != null && callStatus!.isNotEmpty
                                      ? callStatus == 'active'
                                          ? Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 30.0),
                                              child: BlinkingIconCircle(
                                                icon: Icons
                                                    .radio_button_checked, // Icon to show
                                                iconColor: AppColors
                                                    .orange, // Icon color
                                                blinkColor: AppColors
                                                    .orange, // Blinking circle color
                                                iconSize: 10.0, // Icon size
                                                beatDuration: Duration(
                                                    milliseconds:
                                                        1200), // Blinking beat
                                              ),
                                            )
                                          : const SizedBox()
                                      : const SizedBox(),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  sentTime,
                                  maxLines: 1,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textColorSecondary),
                                ),
                                const SizedBox(
                                  height: 5,
                                ),
                                messageCount! > 0
                                    ? MessageCountWidget(
                                        messageCount: messageCount ?? 0,
                                      )
                                    : const SizedBox(),
                                const SizedBox(
                                  height: 5,
                                ),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: AppSizes.kDefaultPadding / 3),
                        lastMsg!.isEmpty && sendBy!.isEmpty
                            ? const SizedBox()
                            : Row(children: [
                                Text("$sendBy : ",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.hedingColor)),
                                messageType == 'text' ||
                                        messageType == "created" ||
                                        messageType == "added" ||
                                        messageType == "removed"
                                    ? Expanded(
                                        child: Text(
                                          lastMsg ?? "",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .copyWith(
                                                  color: AppColors.hedingColor),
                                        ),
                                      )
                                    : messageType == 'video'
                                        ? const Icon(
                                            Icons.movie_outlined,
                                            size: 13,
                                          )
                                        : messageType == 'doc'
                                            ? const Icon(
                                                Icons.description,
                                                size: 13,
                                              )
                                            : messageType == "image"
                                                ? const Icon(
                                                    Icons.image_outlined,
                                                    size: 13,
                                                  )
                                                : const SizedBox.shrink(),
                              ]),
                        const SizedBox(
                          height: AppSizes.kDefaultPadding / 2,
                        ),
                        child
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 0),
          child: CustomDivider(),
        )
      ],
    );
  }
}
