import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Features/AddMembers/Controller/group_create_controller.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Features/CreateNewGroup/Presentation/create_new_group_screen.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Widgets/custom_app_bar.dart';
import 'package:cu_app/Widgets/custom_floating_action_button.dart';
import 'package:cu_app/Widgets/image_popup.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../../Widgets/custom_smartrefresher_fotter.dart';
import '../../../Widgets/custom_text_field.dart';
import '../../../Widgets/shimmer_effetct.dart';

// This screen allows users to add members to a group or create a new group by selecting participants from a list.
class AddMembersScreen extends StatefulWidget {
  final String? groupId;
  final bool isCameFromHomeScreen;
  final List<dynamic>? existingMembersList;
  final bool isMeeting;

  const AddMembersScreen(
      {super.key,
      this.groupId,
      required this.isCameFromHomeScreen,
      this.existingMembersList,
      this.isMeeting = false});

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final TextEditingController searchController = TextEditingController();
  final memberListController = Get.put(MemeberlistController());
  final chatController = Get.put(ChatController());

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    memberListController.limit.value = 20;
    memberListController.page.value = 1;
    memberListController.hasMore.value = true;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      memberListController.isMemberListLoading(true);
      memberListController.searchText.value = "";
      memberListController.memberId.clear();
      memberListController.updateMemberId.clear();
      memberListController.updtaeMemberName.clear();
      memberListController.memberSelectedList.clear();
      memberListController.memberList.clear();
      if (widget.isCameFromHomeScreen) {
        memberListController.setExcludedMembers([]);
        memberListController.getMemberList();
      } else if (widget.groupId != null && widget.groupId!.isNotEmpty) {
        chatController.getGroupDetailsById(groupId: widget.groupId!).then((_) {
          final users = chatController.groupModel.value.currentUsers ?? [];
          final excludedIds =
              users.map((user) => user.sId).whereType<String>().toList();
          memberListController.setExcludedMembers(excludedIds);
          memberListController.getMemberList();
        });
      } else {
        memberListController.setExcludedMembers([]);
        memberListController.getMemberList();
      }
    });
    widget.groupId!.isNotEmpty
        ? null
        : memberListController.dataClearAfterAdd();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
        appBar: CustomAppBar(
          title: 'Add Participants',
          actions: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.kDefaultPadding + 6),
              child: Obx(() => Text(
                    '${memberListController.memberId.length} / ${memberListController.memberList.value.length}',
                    style: const TextStyle(color: AppColors.white),
                  )),
            )
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
              gradient: AppColors.appBarBottomGradientColor),
          child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: colors.scaffoldBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(
                    20,
                  ),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.kDefaultPadding),
                    margin: const EdgeInsets.all(AppSizes.kDefaultPadding),
                    decoration: BoxDecoration(
                        color: colors.surfaceBg,
                        borderRadius:
                            BorderRadius.circular(AppSizes.cardCornerRadius)),
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
                            hintText: 'Search participants...',
                            isBorder: false,
                            onChanged: (val) {
                              memberListController.searchText.value =
                                  val.toString();
                              EasyDebounce.debounce(
                                  'add-member-list', // <-- An ID for this particular debouncer
                                  const Duration(
                                      milliseconds:
                                          200), // <-- The debounce duration
                                  () async {
                                await memberListController.getMemberList();
                              } // <-- The target method
                                  );

                              return;
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      child: Obx(() => memberListController
                              .isMemberListLoading.value
                          ? const ShimmerEffectLaoder(
                              numberOfWidget: 20,
                            )
                          : memberListController.memberList.value.isNotEmpty
                              ? SmartRefresher(
                                  controller: _refreshController,
                                  enablePullDown: false,
                                  enablePullUp: true,
                                  onLoading: () async {
                                    if (!memberListController.hasMore.value) {
                                      _refreshController.loadNoData();
                                      return;
                                    }
                                    memberListController.page.value += 1;
                                    await memberListController.getMemberList(
                                        isLoaderShowing: false);
                                    _refreshController.loadComplete();
                                  },
                                  footer: const CustomFooterWidget(),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount:
                                        memberListController.memberList.length,
                                    padding: const EdgeInsets.only(
                                        bottom: AppSizes.kDefaultPadding * 9),
                                    itemBuilder: (context, index) {
                                      //for search members
                                      var data = memberListController
                                          .memberList[index];
                                      return Obx(() => Row(
                                            children: [
                                              const SizedBox(
                                                width: 20,
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  if (data.image != null &&
                                                      data.image!.isNotEmpty) {
                                                    Get.to(
                                                        () =>
                                                            FullScreenImageViewer(
                                                              lableText:
                                                                  data.name ??
                                                                      "",
                                                              imageUrl:
                                                                  data.image ??
                                                                      "",
                                                            ),
                                                        transition: Transition
                                                            .circularReveal, // Optional: Customize the animation
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    700));
                                                  }
                                                },
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius
                                                      .circular(AppSizes
                                                              .cardCornerRadius *
                                                          10),
                                                  child: CachedNetworkImage(
                                                    width: 30,
                                                    height: 30,
                                                    fit: BoxFit.cover,
                                                    imageUrl: data.image ?? "",
                                                    placeholder:
                                                        (context, url) =>
                                                            CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor:
                                                          colors.shimmerBase,
                                                    ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor:
                                                          colors.shimmerBase,
                                                      child: Text(
                                                        data.name!
                                                            .substring(0, 1),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge!
                                                            .copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppSizes.kDefaultPadding,
                                              ),
                                              Expanded(
                                                child: CheckboxListTile(
                                                    contentPadding:
                                                        const EdgeInsets.only(
                                                            right: 20),
                                                    title: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                data.name ?? "",
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodyLarge!,
                                                              ),
                                                              const SizedBox(
                                                                width: 5,
                                                              ),
                                                              Text(
                                                                data.email ??
                                                                    "",
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodyMedium,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    controlAffinity:
                                                        ListTileControlAffinity
                                                            .trailing,
                                                    value: data
                                                                .sId
                                                                .toString() ==
                                                            LocalStorage()
                                                                .getUserId()
                                                                .toString()
                                                        ? memberListController
                                                            .isUserChecked.value
                                                        : memberListController
                                                            .memberId.value
                                                            .contains(data.sId),
                                                    onChanged: (value) {
                                                      memberListController
                                                          .checkBoxTrueFalse(
                                                              value,
                                                              data.sId!,
                                                              data,
                                                              widget.groupId!);
                                                    }),
                                              ),
                                            ],
                                          ));
                                    },
                                  ),
                                )
                              : const Center(
                                  child: Text("No Participants found"),
                                )),
                    ),
                  ),
                ],
              )),
        ),
        floatingActionButton: Obx(
          () => memberListController.memberId.isNotEmpty
              ? memberListController.addingGroup.value
                  ? const Center(
                      child: CircularProgressIndicator.adaptive(),
                    )
                  : CustomFloatingActionButton(
                      onPressed: () {
                        if (widget.isCameFromHomeScreen == true) {
                          context.push(const CreateNewGroupScreen());
                        } else {
                          memberListController.addGroupMember(
                              groupId: widget.groupId!,
                              userId: memberListController.updateMemberId,
                              userName: memberListController.updtaeMemberName,
                              context: context,
                              isMeeting: widget.isMeeting);
                        }
                      },
                      iconData: EvaIcons.arrowForwardOutline,
                    )
              : const SizedBox(),
        ));
  }
}
