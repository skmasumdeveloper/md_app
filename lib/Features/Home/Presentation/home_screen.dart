import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Features/Home/Controller/group_list_controller.dart';
import 'package:cu_app/Features/Home/Controller/socket_controller.dart';
import 'package:cu_app/Features/Home/Model/group_list_model.dart';
import 'package:cu_app/Features/Home/Widgets/home_chat_card.dart';
import 'package:cu_app/Widgets/custom_divider.dart';
import 'package:cu_app/Widgets/image_popup.dart';
import 'package:cu_app/services/call_overlay_manager.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import '../../../Commons/app_theme_colors.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../../Features/Navigation/Presentation/main_navigation_screen.dart';
import '../../../Widgets/custom_smartrefresher_fotter.dart';
import '../../../Widgets/custom_text_field.dart';
import '../../../Widgets/responsive.dart';
import '../../../Widgets/shimmer_effetct.dart';
import '../../Chat/Presentation/chat_screen.dart';
import '../../Group_Call/Presentation/video_call_screen.dart';
import '../../Group_Call/controller/group_call.dart';
import '../../Login/Controller/login_controller.dart';
import 'package:cu_app/Utils/storage_service.dart';

// This screen is the main home screen of the application, displaying the chat list and handling navigation.
class HomeScreen extends StatefulWidget {
  final bool isDeleteNavigation;
  final bool isFromChat;
  const HomeScreen(
      {super.key, required this.isDeleteNavigation, this.isFromChat = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final socketController = Get.put(SocketController());
  final loginController = Get.put(LoginController());
  final groupcallController = Get.put(GroupcallController());
  final chatController = Get.put(ChatController());

  @override
  void dispose() {
    super.dispose();
    chatController.groupId.value = "";
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Socket auto-connects via SocketController.onInit()
      // Just ensure it's connected
      socketController.reconnectSocket();
      loginController.getUserProfile().then((value) {
        updatePushToken();
      });

      chatController.groupId.value = "";
    });
  }

  bool commingFromChat = false;

// This method updates the push token in the user's profile.
  void updatePushToken() async {
    loginController.updateUserDetails(
        status: loginController.statusController.value);
  }

  @override
  Widget build(BuildContext context) {
    // Don't call socketConnection() in build - it will cause multiple connections
    socketController.updateBuildContext(context);
    groupcallController.updateBuildContext(context);

    return MainNavigationScreen(
      isDeleteNavigation: widget.isDeleteNavigation,
      isFromChat: widget.isFromChat,
    );
  }
}

class BuildChatList extends StatefulWidget {
  final bool isAdmin;
  final bool isDeleteNavigation;
  final bool isFromChat;

  const BuildChatList(
      {super.key,
      required this.isAdmin,
      required this.isDeleteNavigation,
      this.isFromChat = false});

  @override
  State<BuildChatList> createState() => _BuildChatListState();
}

class _BuildChatListState extends State<BuildChatList> {
  final TextEditingController searchController = TextEditingController();
  final groupListController = Get.put(GroupListController());
  final loginController = Get.put(LoginController());
  final chatController = Get.put(ChatController());
  final socketController = Get.put(SocketController());
  final groupcallController = Get.put(GroupcallController());

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      groupListController.limit.value = 20;
      callAfterDelay();
      if (widget.isDeleteNavigation == false) {}
    });

    super.initState();
  }

// This method is called after a delay to refresh the group list and user profile.
  callAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 200), () {
      loginController.getUserProfile();
      groupListController.getGroupList(
          isLoadingShow: widget.isFromChat
              ? false
              : widget.isDeleteNavigation == true
                  ? false
                  : true);
      socketController.reconnectSocket();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // final isAnyActiveCall = groupcallController.isAnyCallActive;

    return Column(
      children: [
        const SizedBox(
          height: 10,
        ),
        // _buildActiveCallBar(context),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSizes.kDefaultPadding),
          margin:
              const EdgeInsets.symmetric(horizontal: AppSizes.kDefaultPadding),
          decoration: BoxDecoration(
              color: colors.surfaceBg,
              border: Border.all(width: 1, color: colors.borderColor),
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
                  onChanged: (value) async {
                    groupListController.searchText.value = value.toString();
                    EasyDebounce.debounce(
                        'group-debounce', // <-- An ID for this particular debouncer
                        const Duration(
                            milliseconds: 200), // <-- The debounce duration
                        () async {
                      await groupListController.getGroupList();
                    } // <-- The target method
                        );
                  },
                  isBorder: false,
                ),
              )
            ],
          ),
        ),
        Responsive.isMobile(context) ? const SizedBox() : const CustomDivider(),
        Expanded(
          child: Obx(
            () => (groupListController.isGroupLiastLoading.value ||
                    (!groupListController.hasLoadedOnce.value &&
                        groupListController.groupList.isEmpty))
                ? const ShimmerEffectLaoder(
                    numberOfWidget: 20,
                  )
                : groupListController.groupList.isNotEmpty
                    ? SmartRefresher(
                        controller: _refreshController,
                        enablePullDown: true,
                        enablePullUp: true,
                        onRefresh: () async {
                          groupListController.limit.value = 20;
                          groupListController.getGroupList(isLoadingShow: true);
                          _refreshController.refreshCompleted();
                        },
                        onLoading: () async {
                          groupListController.limit.value += 20;
                          groupListController.getGroupList(
                              isLoadingShow: false);
                          _refreshController.loadComplete();
                        },
                        footer: const CustomFooterWidget(),
                        child: ListView.builder(
                          itemCount: groupListController.groupList.value.length,
                          itemBuilder: (context, index) {
                            var item =
                                groupListController.groupList.value[index];
                            return HomeChatCard(
                              onPictureTap: () {
                                if (item.groupImage != null &&
                                    item.groupImage != "undefined") {
                                  Get.to(
                                      () => FullScreenImageViewer(
                                            imageUrl: item.groupImage ?? "",
                                            lableText: item.groupName ?? "",
                                          ),
                                      transition: Transition
                                          .circularReveal, // Optional: Customize the animation
                                      duration:
                                          const Duration(milliseconds: 700));
                                }
                              },
                              messageCount: item.unreadCount,
                              callStatus: item.groupCallStatus ?? "ended",
                              groupId: item.sId.toString(),
                              onPressed: () {
                                chatController.isShowing(false);
                                chatController.timeStamps.value =
                                    DateTime.now().millisecondsSinceEpoch;

                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                          groupId: item.sId.toString(),
                                          isAdmin: widget.isAdmin,
                                          index: index,
                                        )));
                                groupListController
                                    .groupList[index].unreadCount = 0;
                                groupListController.groupList.refresh();
                              },
                              groupName: chatController.getGroupDisplayName(
                                  group: item,
                                  defaultGroupName: item.groupName),
                              groupDesc: item.createdAt ?? "",
                              sentTime: item.lastMessage != null &&
                                      item.lastMessage!.createdAt!.isNotEmpty
                                  ? DateFormat('hh:mm a').format(DateTime.parse(
                                          item.lastMessage?.timestamp ?? "")
                                      .toLocal())
                                  : "",
                              sendBy: item.lastMessage != null
                                  ? item.lastMessage!.senderName ?? ""
                                  : "",
                              lastMsg: item.lastMessage != null
                                  ? item.lastMessage?.message ?? ""
                                  : "",
                              imageUrl: item.groupImage ?? "",
                              messageType: item.lastMessage != null
                                  ? item.lastMessage?.messageType ?? ""
                                  : "",
                              child: memberWidget(item.currentUsers ?? [],
                                  isDirect: item.isDirect ?? false),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Text("No group found"),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCallBar(BuildContext context) {
    final colors = context.appColors;
    return Obx(() {
      final hasActiveCall = groupcallController.isCallActive.value ||
          groupcallController.isAnyCallActive.value;
      final roomId = groupcallController.currentRoomId.value;
      final activeGroup = groupListController.groupList
          .firstWhereOrNull((group) => group.sId.toString() == roomId);
      String activeGroupName = 'Active call';

      if (activeGroup != null) {
        if (activeGroup.isDirect == true && activeGroup.currentUsers != null) {
          final otherUser = activeGroup.currentUsers!.firstWhereOrNull(
              (user) => user.sId != LocalStorage().getUserId());
          if (otherUser != null && otherUser.name != null) {
            activeGroupName = otherUser.name!;
          } else if (activeGroup.groupName != null) {
            activeGroupName = activeGroup.groupName!;
          }
        } else if (activeGroup.groupName != null) {
          activeGroupName = activeGroup.groupName!;
        }
      }

      if (!hasActiveCall ||
          roomId.isEmpty ||
          groupcallController.localStream == null) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.kDefaultPadding,
          vertical: 6,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.95),
              AppColors.primary.withOpacity(0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.cardBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeGroupName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.textOnPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active call',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textOnPrimary.withOpacity(0.9),
                        ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.cardBg,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () async {
                  if (CallOverlayManager.isFloating.value) {
                    CallOverlayManager().restoreCall();
                    return;
                  }

                  if (groupcallController.localStream == null) {
                    Get.snackbar(
                      'Call connecting',
                      'Please wait while the call reconnects.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                    // groupcallController.outgoingCallEmit(roomId,
                    //     isVideoCall: groupcallController.isThisVideoCall.value);
                    Get.off(
                      () => ChatScreen(
                        groupId: roomId,
                        index: 0,
                        isAccepted: 1,
                        callType: groupcallController.isThisVideoCall.value
                            ? "video"
                            : "audio",
                      ),
                    );
                    print('call connecting');
                    return;
                  }

                  final groupName = await groupcallController
                      .getGroupDetailsById(roomId, 'groupName');
                  final groupImage = await groupcallController
                      .getGroupDetailsById(roomId, 'groupImage');

                  if (!mounted) return;
                  print(
                      'Navigating to GroupVideoCallScreen for roomId: $roomId');
                  Get.to(() => GroupVideoCallScreen(
                        groupId: roomId,
                        groupName: groupName,
                        groupImage: groupImage,
                        localStream: groupcallController.localStream!,
                        isVideoCall: groupcallController.isThisVideoCall.value,
                      ));
                },
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.red,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                splashRadius: 18,
              ),
            ),
            const SizedBox(width: 10),
            // Container(
            //   width: 36,
            //   height: 36,
            //   decoration: const BoxDecoration(
            //     color: Colors.white,
            //     shape: BoxShape.circle,
            //   ),
            //   child: IconButton(
            //     onPressed: () async {
            //       await groupcallController.leaveCall(
            //         roomId: roomId,
            //         userId: LocalStorage().getUserId(),
            //       );
            //     },
            //     icon: const Icon(
            //       Icons.call_end,
            //       color: Colors.red,
            //       size: 18,
            //     ),
            //     padding: EdgeInsets.zero,
            //     splashRadius: 18,
            //   ),
            // ),
          ],
        ),
      );
    });
  }

  Widget memberWidget(List<CurrentUsers> membersList, {bool isDirect = false}) {
    final colors = context.appColors;
    final filteredMembers =
        membersList.where((member) => member.name != "Cpscom Admin").toList();

    if (isDirect) {
      return SizedBox(
        height: 5,
      );
    }

    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ListView.builder(
              itemCount:
                  filteredMembers.length < 3 ? filteredMembers.length : 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Align(
                      widthFactor: 0.3,
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: colors.cardBg,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                              AppSizes.cardCornerRadius * 10),
                          child: CachedNetworkImage(
                            width: 26,
                            height: 26,
                            fit: BoxFit.cover,
                            imageUrl: filteredMembers[index].image ?? "",
                            placeholder: (context, url) => CircleAvatar(
                              radius: 26,
                              backgroundColor: colors.shimmerBase,
                            ),
                            errorWidget: (context, url, error) => CircleAvatar(
                              radius: 26,
                              backgroundColor: colors.shimmerBase,
                              child: Text(
                                filteredMembers[index]
                                    .name
                                    .toString()[0]
                                    .toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
          filteredMembers.length > 3
              ? Align(
                  widthFactor: 0.6,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.borderColor,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: colors.cardBg,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: FittedBox(
                          child: Text(
                            '+${filteredMembers.length - 3}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(color: colors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox()
        ],
      ),
    );
  }
}
