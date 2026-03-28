// ignore_for_file: unused_local_variable

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Features/AddMembers/Controller/group_create_controller.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Features/GroupInfo/ChangeGroupDescription/Presentation/chnage_group_description.dart';
import 'package:cu_app/Widgets/custom_app_bar.dart';
import 'package:cu_app/Widgets/custom_card.dart';
import 'package:cu_app/Widgets/custom_divider.dart';
import 'package:cu_app/Widgets/participants_card.dart';
import 'package:cu_app/Widgets/rounded_corner_container.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Commons/app_images.dart';
import '../../../Utils/custom_bottom_modal_sheet.dart';
import '../../../Widgets/image_popup.dart';
import '../../../Widgets/shimmer_for_text.dart';
import '../../AddMembers/Presentation/add_members_screen.dart';
import '../../AddMembers/Widgets/delete_widget_alert.dart';
import '../../Meetings/Controller/meetings_list_controller.dart';
import '../../Meetings/Controller/meeting_details_controller.dart';
import '../../Meetings/Model/meetings_list_model.dart';
import '../../Meetings/Presentation/meeting_details_screen.dart';
import '../Model/image_picker_model.dart';

// This screen displays detailed information about a group, including its members, description, and options to edit the group.
class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final bool? isAdmin;
  final bool isMeeting;
  final String? meetingStatus;

  const GroupInfoScreen(
      {super.key,
      required this.groupId,
      this.isAdmin,
      required this.isMeeting,
      this.meetingStatus});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final chatController = Get.put(ChatController());
  final memberController = Get.put(MemeberlistController());
  final meetingDetailsController = Get.put(MeetingDetailsController());

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      chatController.getGroupDetailsById(groupId: widget.groupId);

      final users = chatController.groupModel.value.currentUsers;
      if (users != null && users.isNotEmpty) {
        for (var element in users) {
          memberController.memberId.add(element.sId?.toString() ?? '');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: CustomAppBar(
        title: '${widget.isMeeting == true ? "Meeting" : "Group"} Info',
        actions: [
          IconButton(
              onPressed: () {
                context.push(ChangeGroupDescription(
                  groupId: widget.groupId,
                  isMeeting: widget.isMeeting,
                ));
              },
              icon: const Icon(
                Icons.edit,
                color: AppColors.white,
              ))
        ],
      ),
      body: RoundedCornerContainer(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.kDefaultPadding * 2),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        InkWell(
                          onTap: () {
                            if (chatController.groupModel.value.groupImage !=
                                    null &&
                                chatController
                                    .groupModel.value.groupImage!.isNotEmpty) {
                              Get.to(
                                  () => FullScreenImageViewer(
                                        imageUrl: chatController
                                                .groupModel.value.groupImage ??
                                            "",
                                        lableText: chatController
                                                .groupModel.value.groupName ??
                                            "",
                                      ),
                                  transition: Transition
                                      .circularReveal, // Optional: Customize the animation
                                  duration: const Duration(milliseconds: 700));
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                AppSizes.cardCornerRadius * 10),
                            child: Obx(() => CachedNetworkImage(
                                  width: 106,
                                  height: 106,
                                  fit: BoxFit.cover,
                                  imageUrl: chatController
                                          .groupModel.value.groupImage ??
                                      "",
                                  placeholder: (context, url) => CircleAvatar(
                                    radius: 66,
                                    backgroundColor: colors.borderColor,
                                  ),
                                  errorWidget: (context, url, error) =>
                                      CircleAvatar(
                                    radius: 66,
                                    backgroundColor: colors.borderColor,
                                    child: Obx(
                                      () => Text(
                                        chatController
                                            .groupModel.value.groupName
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineLarge!
                                            .copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                )),
                          ),
                        ),
                        Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: () {
                                showCustomBottomSheet(
                                    context,
                                    '',
                                    SizedBox(
                                      height: 150,
                                      child: ListView.builder(
                                          shrinkWrap: true,
                                          padding: const EdgeInsets.all(
                                              AppSizes.kDefaultPadding),
                                          itemCount: imagePickerList.length,
                                          scrollDirection: Axis.horizontal,
                                          itemBuilder: (context, index) {
                                            return GestureDetector(
                                              onTap: () {
                                                switch (index) {
                                                  case 0:
                                                    chatController.pickImage(
                                                        imageSource:
                                                            ImageSource.gallery,
                                                        groupId: widget.groupId,
                                                        context: context);

                                                    break;
                                                  case 1:
                                                    chatController.pickImage(
                                                        imageSource:
                                                            ImageSource.camera,
                                                        groupId: widget.groupId,
                                                        context: context);

                                                    break;
                                                }
                                                Navigator.pop(context);
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    left: AppSizes
                                                            .kDefaultPadding *
                                                        2),
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      width: 60,
                                                      height: 60,
                                                      padding: const EdgeInsets
                                                          .all(AppSizes
                                                              .kDefaultPadding),
                                                      decoration: BoxDecoration(
                                                          border: Border.all(
                                                              width: 1,
                                                              color: colors
                                                                  .borderColor),
                                                          color: colors.cardBg,
                                                          shape:
                                                              BoxShape.circle),
                                                      child:
                                                          imagePickerList[index]
                                                              .icon,
                                                    ),
                                                    const SizedBox(
                                                      height: AppSizes
                                                              .kDefaultPadding /
                                                          2,
                                                    ),
                                                    Text(
                                                      '${imagePickerList[index].title}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                    ));
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                padding: const EdgeInsets.all(
                                    AppSizes.kDefaultPadding / 1.3),
                                decoration: BoxDecoration(
                                    border: Border.all(
                                        width: 1, color: colors.borderColor),
                                    color: colors.cardBg,
                                    shape: BoxShape.circle),
                                child: Obx(() => chatController
                                        .isUpdateLoading.value
                                    ? const Center(
                                        child:
                                            CircularProgressIndicator.adaptive(
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : Image.asset(
                                        AppImages.cameraIcon,
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.contain,
                                      )),
                              ),
                            ))
                      ],
                    ),
                    const SizedBox(
                      height: AppSizes.kDefaultPadding,
                    ),
                    Obx(() => chatController.isDetailsLaoding.value
                        ? ShimmerEffectForTexTWidget(
                            textName: "Loading...",
                            baseColor: colors.shimmerBase,
                            highlightColor: colors.shimmerHighlight,
                          )
                        : Text(
                            chatController.groupModel.value.groupName ?? "",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(color: colors.headerBg),
                          )),
                    const SizedBox(
                      height: AppSizes.kDefaultPadding / 2,
                    ),
                    Obx(() => Text(
                          '${(chatController.groupModel.value.currentUsers?.length ?? 0) - 1} People',
                          style: Theme.of(context).textTheme.bodySmall,
                        )),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: CustomCard(
                  margin: const EdgeInsets.all(AppSizes.kDefaultPadding),
                  padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.isMeeting == true ? "Meeting" : "Group"} Description',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .copyWith(color: colors.headerBg),
                      ),
                      const SizedBox(
                        height: AppSizes.kDefaultPadding,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Obx(() => Text(
                                  chatController
                                          .groupModel.value.groupDescription ??
                                      "",
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .copyWith(color: colors.textPrimary),
                                )),
                          ),
                          const Icon(
                            EvaIcons.arrowIosForward,
                            size: 24,
                            color: AppColors.primary,
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Obx(() {
                          final filteredUsers = chatController
                                  .groupModel.value.currentUsers
                                  ?.where(
                                      (user) => user.userType != 'SuperAdmin')
                                  .toList() ??
                              [];
                          return Text(
                            '${filteredUsers.length} Participants',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .copyWith(color: colors.headerBg),
                          );
                        }),
                        widget.isAdmin == true
                            ? InkWell(
                                onTap: () {
                                  Navigator.of(context)
                                      .push<bool>(MaterialPageRoute(
                                    builder: (_) => AddMembersScreen(
                                      groupId: widget.groupId,
                                      isCameFromHomeScreen: false,
                                      existingMembersList: const [],
                                      isMeeting: widget.isMeeting,
                                    ),
                                  ))
                                      .then((updated) async {
                                    if (updated == true) {
                                      await chatController.getGroupDetailsById(
                                          groupId: widget.groupId,
                                          isShowLoading: false);
                                      if (widget.isMeeting == true) {
                                        await meetingDetailsController
                                            .getMeetingDetails(widget.groupId,
                                                isLoadingShow: false);
                                        final meetingsController =
                                            Get.put(MeetingsListController());
                                        meetingsController.getMeetingsList(
                                            isLoadingShow: false);
                                        await meetingsController
                                            .getMeetingCallDetails(
                                                widget.groupId);
                                      }
                                    }
                                  });
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppColors.buttonGradientColor),
                                  child: const Icon(
                                    EvaIcons.plus,
                                    size: 18,
                                    color: AppColors.white,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink()
                      ],
                    ),
                  ),
                  CustomCard(
                    margin: const EdgeInsets.all(AppSizes.kDefaultPadding),
                    padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                    child: Obx(() {
                      final filteredUsers = chatController
                              .groupModel.value.currentUsers
                              ?.where((user) => user.userType != 'SuperAdmin')
                              .toList() ??
                          [];

                      return filteredUsers.isNotEmpty
                          ? ListView.separated(
                              itemCount: filteredUsers.length,
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, index) {
                                var item = filteredUsers[index];

                                return ParticipantsCardWidget(
                                    member: item,
                                    creatorId: item.sId,
                                    userType: item.userType ?? "",
                                    meetingStatus: widget.meetingStatus,
                                    onDeleteButtonPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return Obx(() =>
                                              DeleteMemberAlertDialog(
                                                isLoading: memberController
                                                    .isDeleteWaiting.value,
                                                onDelete: () async {
                                                  final deleted =
                                                      await memberController
                                                          .deleteUserFromGroup(
                                                              groupId: widget
                                                                  .groupId,
                                                              userId: item.sId
                                                                  .toString(),
                                                              userName:
                                                                  item.name ??
                                                                      "");
                                                  if (deleted == true) {
                                                    Navigator.pop(context);
                                                    await chatController
                                                        .getGroupDetailsById(
                                                            groupId:
                                                                widget.groupId,
                                                            isShowLoading:
                                                                false);
                                                    if (widget.isMeeting ==
                                                        true) {
                                                      await meetingDetailsController
                                                          .getMeetingDetails(
                                                              widget.groupId,
                                                              isLoadingShow:
                                                                  false);
                                                      final meetingsController =
                                                          Get.put(
                                                              MeetingsListController());
                                                      meetingsController
                                                          .getMeetingsList(
                                                              isLoadingShow:
                                                                  false);
                                                      await meetingsController
                                                          .getMeetingCallDetails(
                                                              widget.groupId);
                                                    }
                                                  }
                                                },
                                              ));
                                        },
                                      );
                                    });
                              },
                              separatorBuilder:
                                  (BuildContext context, int index) {
                                return const Padding(
                                  padding: EdgeInsets.only(left: 42),
                                  child: CustomDivider(),
                                );
                              },
                            )
                          : const SizedBox.shrink();
                    }),
                  ),
                ],
              ),
              const SizedBox(
                height: AppSizes.kDefaultPadding,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
