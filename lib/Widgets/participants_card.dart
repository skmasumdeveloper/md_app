import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Features/Home/Model/group_list_model.dart';
import 'package:cu_app/Features/Login/Controller/login_controller.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Widgets/image_popup.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Commons/app_colors.dart';
import '../Commons/app_sizes.dart';
import '../Commons/app_theme_colors.dart';

// This widget displays a card for each participant in a meeting, showing their name, and user type.
class ParticipantsCardWidget extends StatelessWidget {
  final CurrentUsers member;
  final String? creatorId;
  final VoidCallback onDeleteButtonPressed;

  final String? userType;
  final String? meetingStatus;

  const ParticipantsCardWidget({
    super.key,
    required this.onDeleteButtonPressed,
    required this.member,
    this.creatorId,
    this.userType,
    this.meetingStatus,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final loginController = Get.put(LoginController());
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: 0,
      trailing: userType == "SuperAdmin" || userType == "admin"
          ? Text(userType ?? "")
          : loginController.userModel.value.userType == "admin" ||
                  loginController.userModel.value.userType == "SuperAdmin"
              ? meetingStatus != null &&
                      meetingStatus!.toLowerCase() == 'ongoing'
                  ? const SizedBox()
                  : IconButton(
                      onPressed: onDeleteButtonPressed,
                      icon: Icon(
                        Icons.delete,
                        color: colors.offlineStatus,
                      ))
              : userType == "SuperAdmin" ||
                      userType == "user" &&
                          !member.sId
                              .toString()
                              .contains(LocalStorage().getUserId().toString())
                  ? Text(userType ?? "")
                  : const InkWell(
                      child: Text(
                        "My Self",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
      leading: InkWell(
        onTap: () {
          if (member.image != null) {
            Get.to(
                () => FullScreenImageViewer(
                      imageUrl: member.image ?? "",
                      lableText: member.name ?? "",
                    ),
                transition: Transition
                    .circularReveal, // Optional: Customize the animation
                duration: const Duration(milliseconds: 700));
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius * 10),
          child: CachedNetworkImage(
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            imageUrl: member.image ?? "",
            placeholder: (context, url) => CircleAvatar(
              radius: 28,
              backgroundColor: colors.surfaceBg,
            ),
            errorWidget: (context, url, error) => CircleAvatar(
              radius: 28,
              backgroundColor: colors.surfaceBg,
              child: Text(
                member.name!.substring(0, 1),
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge!
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
      title: Text(
        member.name ?? "",
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: AppColors.hedingColor, fontWeight: FontWeight.w500),
      ),
    );
  }
}
