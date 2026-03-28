import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Features/Chat/Controller/report_controller.dart';
import 'package:cu_app/Features/Chat/Model/chat_list_model.dart';
import 'package:cu_app/Features/Chat/Widget/receiver_tile.dart';
import 'package:cu_app/Features/Chat/Widget/sender_tile.dart';
import 'package:cu_app/Features/Group_Call_Embeded/controller/group_call_embeded_controller.dart';
import 'package:cu_app/Features/Group_Call_Embeded/group_call_embeded_config.dart';
import 'package:cu_app/Features/Group_Call/controller/group_call.dart';
import 'package:cu_app/Features/GroupInfo/Presentation/group_info_screen.dart';
import 'package:cu_app/Features/Home/Controller/group_list_controller.dart';
import 'package:cu_app/Features/Home/Controller/socket_controller.dart';
import 'package:cu_app/Features/Home/Presentation/home_screen.dart';
import 'package:cu_app/Features/Login/Controller/login_controller.dart';
import 'package:cu_app/Utils/navigator.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Widgets/image_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';
import '../../../Utils/datetime_utils.dart';
import '../../../Widgets/custom_smartrefresher_fotter.dart';
import '../../../Commons/app_theme_colors.dart';
import '../Widget/send_message_widget.dart';
import '../Widget/show_member_widget.dart';
import '../Widget/personal_info.dart';
import 'chat_info_list.dart';

// This screen displays the chat interface for a specific group, allowing users to send messages, view group details, and manage group calls.
class ChatScreen extends StatefulWidget {
  final bool? isAdmin;
  final String groupId;
  final int? index;
  final int? isAccepted;
  final String? callType;
  final int? isCallFloating;

  const ChatScreen(
      {super.key,
      this.isAdmin,
      required this.groupId,
      this.index,
      this.isAccepted,
      this.callType,
      this.isCallFloating = 0});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
//  final ScrollController _scrollController = ScrollController();
  final chatController = Get.put(ChatController());
  final groupListController = Get.put(GroupListController());
  final socketController = Get.put(SocketController());
  final reportController = Get.put(ReportController());
  final loginController = Get.put(LoginController());

  final groupcallController = Get.put(GroupcallController());
  final groupCallEmbededController = Get.put(GroupCallEmbededController());

  void _startPreferredGroupCall({required bool isVideoCall}) {
    if (GroupCallEmbededConfig.enabled) {
      groupCallEmbededController.outgoingCallEmit(
        widget.groupId,
        isVideoCall: isVideoCall,
      );
      return;
    }

    groupcallController.outgoingCallEmit(
      widget.groupId,
      isVideoCall: isVideoCall,
    );
  }

// This method formats the UTC time to the local timezone.
  String getLocaLTimeXone(String utcTime) {
    String timeZone = Intl.getCurrentLocale();

    DateFormat localDateFormat = DateFormat('h:mm a', timeZone);

    String localTime = localDateFormat.format(DateTime.parse(utcTime));
    return localTime;
  }

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      chatController.groupId.value = widget.groupId;
      chatController.isChatScreen.value = true;
      chatController.limit.value = 100;
      chatController.getGroupDetailsById(
          groupId: widget.groupId, timeStamp: chatController.timeStamps.value);
      chatController.checkActiveCall(widget.groupId);
      chatController.msgController.value.clear();
      chatController.isMemberSuggestion.value = false;
      widget.isCallFloating == 1 ? null : chatController.chatList.clear();
      chatController
          .getAllChatByGroupId(
              groupId: widget.groupId,
              isShowLoading: widget.isCallFloating == 1 ? false : true)
          .then((value) {
        final currentUsers = chatController.groupModel.value.currentUsers;
        final List<String> reciverId =
            (currentUsers != null && currentUsers.isNotEmpty)
                ? currentUsers
                    .map((user) => user.sId ?? '')
                    .where((s) => s.isNotEmpty)
                    .toList()
                : <String>[];

        // Only emit if socket exists; allow empty receiver list if group info isn't available yet
        if (socketController.socket != null) {
          socketController.socket!.emit("read", {
            "groupId": widget.groupId,
            "userId": LocalStorage().getUserId().toString(),
            "timestamp": chatController.timeStamps.value,
            "receiverId": reciverId
          });
        }

        socketController.socket?.off("FE-call-ended");
        socketController.socket?.on("FE-call-ended", (data) {
          if (data['roomId'] == widget.groupId) {
            if (groupcallController.isIncomingCallScreenOpen.value &&
                mounted) {}

            chatController.checkActiveCall(widget.groupId);

            groupListController.getGroupList(isLoadingShow: false);
          }
        });
      });

      chatController.groupId.value = widget.groupId;

      if (widget.isAccepted == 1) {
        if (groupcallController.isIncomingCallScreenOpen.value && mounted) {}

        Future.delayed(const Duration(seconds: 1), () {
          // avoid duplicate outgoing call emit if already navigating or call is active
          if (groupcallController.isCallActive.value ||
              groupcallController.isNavigatingToCall ||
              Get.currentRoute.contains('GroupVideoCallScreen') ||
              Get.currentRoute.contains('GroupCallEmbededScreen')) {
            return;
          }

          _startPreferredGroupCall(
            isVideoCall: widget.callType == 'video' ? true : false,
          );
        });
      }
    });
  }

  @override
  dispose() {
    super.dispose();
    WidgetsBinding.instance.addPostFrameCallback((t) {
      chatController.isChatScreen.value = false;
      chatController.msgController.value.clear();
      chatController.isMemberSuggestion.value = false;
      widget.isCallFloating == 1 ? null : chatController.chatList.clear();
      chatController.groupId.value = "";
      if (widget.index != null && widget.index! >= 0) {
        groupListController.groupList[widget.index!].unreadCount = 0;
        groupListController.groupList.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    socketController.updateBuildContext(context);
    groupcallController.updateBuildContext(context);
    final colors = context.appColors;
    return WillPopScope(
        onWillPop: () async {
          chatController.groupId.value = "";
          groupListController.groupList[widget.index!].unreadCount = 0;
          groupListController.groupList.refresh();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const HomeScreen(
                isDeleteNavigation: false,
                isFromChat: true,
              ),
            ),
            (route) => false,
          );
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leadingWidth: 80,
            flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppColors.appBarGradient),
            ),
            title: Obx(
              () => chatController.isDetailsLaoding.value == false
                  ? Text(
                      chatController.getGroupDisplayName(
                          group: chatController.groupModel.value,
                          defaultGroupName:
                              chatController.groupModel.value.groupName),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(color: AppColors.white),
                    )
                  : Shimmer.fromColors(
                      baseColor: colors.shimmerBase,
                      highlightColor: colors.shimmerHighlight,
                      child: Text(
                        'Loading...',
                        style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: colors.textTertiary),
                      ),
                    ),
            ),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const HomeScreen(
                          isDeleteNavigation: false,
                          isFromChat: true,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Icon(
                    Icons.arrow_back,
                    size: 30,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(
                  width: 20,
                ),
                InkWell(
                  onTap: () {
                    if (chatController.groupModel.value.groupImage != null) {
                      Get.to(
                          () => FullScreenImageViewer(
                                imageUrl: chatController
                                    .groupModel.value.groupImage
                                    .toString(),
                                lableText: chatController.getGroupDisplayName(
                                    group: chatController.groupModel.value,
                                    defaultGroupName: chatController
                                        .groupModel.value.groupName),
                              ),
                          transition: Transition
                              .circularReveal, // Optional: Customize the animation
                          duration: const Duration(milliseconds: 700));
                    }
                  },
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppSizes.cardCornerRadius * 10),
                    child: Obx(() => CachedNetworkImage(
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                          imageUrl:
                              chatController.groupModel.value.groupImage ?? "",
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: colors.shimmerBase,
                            highlightColor: colors.shimmerHighlight,
                            child: const CircleAvatar(
                              radius: 50.0,
                            ),
                          ),
                          errorWidget: (context, url, error) => CircleAvatar(
                            radius: 16,
                            backgroundColor: colors.surfaceBg,
                            child: Text(
                              chatController
                                      .getGroupDisplayName(
                                          group:
                                              chatController.groupModel.value,
                                          defaultGroupName: chatController
                                              .groupModel.value.groupName)
                                      .isNotEmpty
                                  ? chatController
                                      .getGroupDisplayName(
                                          group:
                                              chatController.groupModel.value,
                                          defaultGroupName: chatController
                                              .groupModel.value.groupName)
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : "",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        )),
                  ),
                ),
              ],
            ),
            actions: [
              Obx(
                () {
                  if (chatController.isCheckingActiveCall.value) {
                    return Center(
                      child: const CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (chatController.isDetailsLaoding.value) {
                    return const SizedBox.shrink();
                  }

                  if (chatController.groupModel.value.isTemp == true) {
                    if (chatController.groupModel.value.meetingStartTime ==
                            null ||
                        chatController.groupModel.value.meetingEndTime ==
                            null) {
                      return const SizedBox.shrink();
                    } else {
                      DateTime now = DateTime.now();
                      DateTime startTime = DateTime.parse(
                          DateTimeUtils.utcToLocal(
                              chatController.groupModel.value.meetingStartTime!,
                              'yyyy-MM-ddTHH:mm:ssZ'));
                      DateTime endTime = DateTime.parse(
                          DateTimeUtils.utcToLocal(
                              chatController.groupModel.value.meetingEndTime!,
                              'yyyy-MM-ddTHH:mm:ssZ'));

                      if (now.isAfter(startTime) && now.isBefore(endTime)) {
                        return Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.fromLTRB(8, 2, 16, 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: AppColors.blue,
                          ),
                          child: TextButton.icon(
                            icon: Icon(
                              chatController.isGroupCallVideo.value
                                  ? Icons.videocam
                                  : Icons.call,
                              color: colors.textOnPrimary,
                              size: 26,
                            ),
                            label: Text(
                              'Join Meeting',
                              style: TextStyle(
                                  color: colors.textOnPrimary, fontSize: 12),
                            ),
                            onPressed: () {
                              _startPreferredGroupCall(isVideoCall: true);
                            },
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }
                  }

                  if (widget.isCallFloating == 1) {
                    return const SizedBox.shrink();
                  }

                  if (chatController.isGroupCallActive.value &&
                      chatController.activeCallGroupId.value ==
                          widget.groupId) {
                    return Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.fromLTRB(8, 2, 16, 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.blue,
                      ),
                      child: TextButton.icon(
                        icon: Icon(
                          chatController.isGroupCallVideo.value
                              ? Icons.videocam
                              : Icons.call,
                          color: colors.textOnPrimary,
                          size: 26,
                        ),
                        label: Text(
                          'Join Call',
                          style: TextStyle(
                              color: colors.textOnPrimary, fontSize: 12),
                        ),
                        onPressed: () {
                          _startPreferredGroupCall(
                            isVideoCall: chatController.isGroupCallVideo.value,
                          );
                        },
                      ),
                    );
                  }

                  return Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.call,
                          color: AppColors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          _startPreferredGroupCall(isVideoCall: false);
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.videocam,
                          color: AppColors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          _startPreferredGroupCall(isVideoCall: true);
                        },
                      ),
                    ],
                  );
                },
              ),
              Obx(
                () {
                  if (chatController.groupModel.value.isTemp == false &&
                      widget.isCallFloating == 0) {
                    return PopupMenuButton(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      color: colors.scaffoldBg,
                      position: PopupMenuPosition.under,
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.white,
                        size: 24,
                      ),
                      itemBuilder: (context) => [
                        if (chatController.groupModel.value.isDirect != true)
                          PopupMenuItem(
                              value: 1,
                              child: Text(
                                'Group Info',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(color: colors.textPrimary),
                              )),
                        if (chatController.groupModel.value.isDirect != true)
                          PopupMenuItem(
                              value: 2,
                              child: Text(
                                'Report Group',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(color: colors.textPrimary),
                              )),
                        if (chatController.groupModel.value.isDirect == true)
                          PopupMenuItem(
                              value: 3,
                              child: Text(
                                'Personal Info',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(color: colors.textPrimary),
                              )),
                        // Show delete action only when group is not a direct chat and current user is the creator
                        if (chatController.groupModel.value.isDirect != true &&
                            (chatController.groupModel.value.createdBy ?? '') ==
                                LocalStorage().getUserId())
                          PopupMenuItem(
                              value: 4,
                              child: Text(
                                'Delete Group',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(color: colors.textPrimary),
                              )),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 1:
                            context.push(GroupInfoScreen(
                              groupId: widget.groupId.toString(),
                              isAdmin: widget.isAdmin,
                              isMeeting: false,
                            ));
                            break;
                          case 2:
                            _showReportDialog(
                                isLoading:
                                    reportController.isGroupReportLoading,
                                title: "Report Group",
                                context: context,
                                textEditingController: reportController
                                    .groupReportController.value,
                                onTap: () async {
                                  await reportController.groupReport(
                                      groupId: widget.groupId,
                                      context: context);
                                });
                            break;
                          case 3:
                            // chatController.getPersonalInfoGroupDetailsById(
                            //     groupId: widget.groupId);
                            _showPersonalInfoDialog(
                              context: context,
                              userInfoData: chatController.userInfoData.value,
                            );
                            break;
                          case 4:
                            _showDeleteGroupDialog(
                                context: context,
                                isLoading: chatController.isDeleteGroupLoading,
                                onDeleteTap: () async {
                                  await chatController.deleteGroupById(
                                      groupId: widget.groupId,
                                      context: context);
                                });
                            break;
                        }
                      },
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
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
              child: Container(
                padding: const EdgeInsets.all(1),
                child: Column(
                  children: [
                    Obx(() {
                      if (chatController.isDetailsLaoding.value == true) {
                        return const SizedBox.shrink();
                      }
                      if (chatController.groupModel.value.isTemp == true) {
                        return Container(
                          padding:
                              const EdgeInsets.all(AppSizes.kDefaultPadding),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: colors.headerBg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  'Meeting Details',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(
                                        color: colors.textOnHeader,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  chatController
                                          .groupModel.value.groupDescription ??
                                      "",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(
                                        color: colors.textOnHeader,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'From',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(
                                          color: colors.textOnHeader,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateTimeUtils.utcToLocal(
                                        chatController.groupModel.value
                                                .meetingStartTime ??
                                            "",
                                        'MMM dd, yyyy • hh:mm a'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(
                                          color: colors.textOnHeader,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'To',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(
                                          color: colors.textOnHeader,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateTimeUtils.utcToLocal(
                                        chatController.groupModel.value
                                                .meetingEndTime ??
                                            "",
                                        'MMM dd, yyyy • hh:mm a'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(
                                          color: colors.textOnHeader,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                    Expanded(
                        child: Column(
                      children: [
                        Expanded(
                            child: Obx(
                          () => chatController.isChatLoading.value
                              ? const Center(
                                  child: CircularProgressIndicator.adaptive(),
                                )
                              : chatController.chatList.isNotEmpty
                                  ? SmartRefresher(
                                      controller: _refreshController,
                                      enablePullDown: false,
                                      enablePullUp: true,
                                      onRefresh: () async {
                                        _refreshController.refreshCompleted();
                                      },
                                      onLoading: () async {
                                        chatController.limit.value += 100;
                                        chatController.getAllChatByGroupId(
                                            groupId: widget.groupId,
                                            isShowLoading: false);
                                        _refreshController.loadComplete();
                                      },
                                      footer: const CustomFooterWidget(),
                                      child: ListView.builder(
                                          itemCount:
                                              chatController.chatList.length,
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          controller:
                                              chatController.scrollController,
                                          shrinkWrap: true,
                                          reverse: true,
                                          padding: const EdgeInsets.only(
                                              bottom:
                                                  AppSizes.kDefaultPadding * 2),
                                          itemBuilder: (context, index) {
                                            var item = chatController
                                                .chatList.reversed
                                                .toList()[index];

                                            // final messageKey =
                                            //     chatController.getMessageKey(
                                            //         item.sId.toString());

                                            // Build unique recipient, delivered, and read sets
                                            final recipientsSet =
                                                (item.allRecipients ?? [])
                                                    .map((e) => e.toString())
                                                    .toSet();

                                            final deliveredSet =
                                                (item.deliveredTo ?? [])
                                                    .map((d) => d.user)
                                                    .whereType<String>()
                                                    .toSet();

                                            final readSet = (item.readBy ?? [])
                                                .map((r) => r.user?.sId)
                                                .whereType<String>()
                                                .toSet();

                                            // Reading implies delivered; count unique users only
                                            final deliveredUnion =
                                                deliveredSet.union(readSet);

                                            // Only count recipients, avoid over-count when backend returns extras
                                            final deliveredCount =
                                                deliveredUnion
                                                    .intersection(recipientsSet)
                                                    .length;
                                            final seenCount = readSet
                                                .intersection(recipientsSet)
                                                .length;
                                            final recipientsCount =
                                                recipientsSet.length;

                                            return item.senderId.toString() ==
                                                    LocalStorage()
                                                        .getUserId()
                                                        .toString()
                                                ? Container(
                                                    key: ValueKey(
                                                        item.sId.toString()),
                                                    child: InkWell(
                                                        onTap: () {
                                                          chatController
                                                              .selectedIndex
                                                              .value = index;
                                                        },
                                                        child: item
                                                                        .messageType ==
                                                                    "created" ||
                                                                item.messageType ==
                                                                    "removed" ||
                                                                item.messageType ==
                                                                    "added" ||
                                                                item.messageType ==
                                                                    "callEnd"
                                                            ? Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            20,
                                                                        right:
                                                                            20,
                                                                        bottom:
                                                                            20),
                                                                child: Center(
                                                                  child:
                                                                      InkWell(
                                                                    onTap:
                                                                        () {},
                                                                    child: Text(
                                                                      "${item.message ?? ''}",
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: TextStyle(
                                                                          color: colors
                                                                              .textTertiary,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                  ),
                                                                ),
                                                              )
                                                            : InkWell(
                                                                onTap: () {},
                                                                onLongPress:
                                                                    () {
                                                                  FocusScopeNode
                                                                      currentFocus =
                                                                      FocusScope.of(
                                                                          context);
                                                                  if ((!currentFocus
                                                                          .hasPrimaryFocus &&
                                                                      currentFocus
                                                                              .focusedChild !=
                                                                          null)) {
                                                                    FocusManager
                                                                        .instance
                                                                        .primaryFocus
                                                                        ?.unfocus();
                                                                  }
                                                                  _showBottomSheet(
                                                                      from:
                                                                          "sender",
                                                                      context,
                                                                      chatdata:
                                                                          item,
                                                                      item.sId
                                                                          .toString(),
                                                                      handleReply:
                                                                          () {
                                                                    backFromPrevious(
                                                                        context:
                                                                            context);
                                                                    chatController.isRelayFunction(
                                                                        isRep:
                                                                            true,
                                                                        msgId: item
                                                                            .sId,
                                                                        msgType:
                                                                            item
                                                                                .messageType,
                                                                        msg: item
                                                                            .message,
                                                                        senderName:
                                                                            item.senderName);
                                                                  });
                                                                },
                                                                child:
                                                                    SenderTile(
                                                                  // key: messageKey,
                                                                  isDelivered:
                                                                      (deliveredCount ==
                                                                              recipientsCount)
                                                                          .obs,
                                                                  isSeen: (seenCount ==
                                                                          recipientsCount)
                                                                      .obs,
                                                                  index: index,
                                                                  fileName:
                                                                      item.fileName ??
                                                                          "",
                                                                  message:
                                                                      '${item.message ?? ""}',
                                                                  isHighlighted:
                                                                      item.isHighlighted,
                                                                  messageType: item
                                                                      .messageType
                                                                      .toString(),
                                                                  sentTime: DateFormat(
                                                                          'MM/dd/yyyy HH:mm')
                                                                      .format(DateTime.parse(item.timestamp ??
                                                                              "")
                                                                          .toLocal()),
                                                                  groupCreatedBy:
                                                                      "",
                                                                  read: "value",
                                                                  onLeftSwipe:
                                                                      (DragUpdateDetails
                                                                          d) {
                                                                    chatController.isRelayFunction(
                                                                        isRep:
                                                                            true,
                                                                        msgId: item
                                                                            .sId,
                                                                        msgType:
                                                                            item
                                                                                .messageType,
                                                                        msg: item
                                                                            .message,
                                                                        senderName:
                                                                            item.senderName);
                                                                  },
                                                                  replyOf: item
                                                                      .replyOf,
                                                                ),
                                                              )),
                                                  )
                                                : item.messageType ==
                                                            "created" ||
                                                        item.messageType ==
                                                            "removed" ||
                                                        item.messageType ==
                                                            "added" ||
                                                        item.messageType ==
                                                            "callEnd"
                                                    ? Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 20,
                                                                right: 20,
                                                                bottom: 20),
                                                        child: Center(
                                                          child: InkWell(
                                                            onTap: () {},
                                                            child: Text(
                                                              "${item.message ?? ''}",
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: const TextStyle(
                                                                  color:
                                                                      AppColors
                                                                          .grey,
                                                                  fontSize: 12),
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : InkWell(
                                                        onLongPress: () {
                                                          FocusScopeNode
                                                              currentFocus =
                                                              FocusScope.of(
                                                                  context);
                                                          if ((!currentFocus
                                                                  .hasPrimaryFocus &&
                                                              currentFocus
                                                                      .focusedChild !=
                                                                  null)) {
                                                            FocusManager
                                                                .instance
                                                                .primaryFocus
                                                                ?.unfocus();
                                                          }
                                                          _showBottomSheet(
                                                              from: "reciver",
                                                              chatdata: item,
                                                              context,
                                                              item.sId
                                                                  .toString(),
                                                              handleReply: () {
                                                            backFromPrevious(
                                                                context:
                                                                    context);
                                                            chatController.isRelayFunction(
                                                                isRep: true,
                                                                msgId: item.sId,
                                                                msgType: item
                                                                    .messageType,
                                                                msg: item
                                                                    .message,
                                                                senderName: item
                                                                    .senderName);
                                                          });
                                                        },
                                                        onTap: () {
                                                          chatController
                                                              .selectedIndex
                                                              .value = index;
                                                        },
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 15),
                                                          child: ReceiverTile(
                                                            // key: messageKey,
                                                            index: index,
                                                            replyOf:
                                                                item.replyOf,
                                                            fileName:
                                                                item.fileName ??
                                                                    "",
                                                            chatController:
                                                                chatController,
                                                            onSwipedMessage:
                                                                (DragUpdateDetails
                                                                    d) {
                                                              chatController.isRelayFunction(
                                                                  isRep: true,
                                                                  msgId:
                                                                      item.sId,
                                                                  msgType: item
                                                                      .messageType,
                                                                  msg: item
                                                                      .message,
                                                                  senderName: item
                                                                      .senderName);
                                                            },
                                                            message:
                                                                item.message ??
                                                                    "",
                                                            messageType:
                                                                item.messageType ??
                                                                    "",
                                                            isHighlighted: item
                                                                .isHighlighted,
                                                            sentTime: DateFormat(
                                                                    'MM/dd/yyyy HH:mm')
                                                                .format(DateTime.parse(
                                                                        item.timestamp ??
                                                                            "")
                                                                    .toLocal()),
                                                            sentByName:
                                                                item.senderName ??
                                                                    "",
                                                            sentByImageUrl: item
                                                                    .senderDataAll
                                                                    ?.image ??
                                                                "",
                                                            groupCreatedBy:
                                                                "Pandey",
                                                          ),
                                                        ),
                                                      );
                                          }),
                                    )
                                  : const SizedBox.shrink(),
                        )),
                      ],
                    )),
                    Obx(() => chatController.isMemberSuggestion.value
                        ? TagMemberWidget(chatController: chatController)
                        : const SizedBox()),
                    Obx(() => chatController.isReply.value
                        ? chatController.isSendWidgetShow.value
                            ? SendMessageWidget(
                                groupId: widget.groupId,
                                msgController:
                                    chatController.msgController.value,
                                scrollController:
                                    chatController.scrollController,
                              )
                            : const SizedBox()
                        : chatController.isSendWidgetShow.value
                            ? SendMessageWidget(
                                groupId: widget.groupId,
                                msgController:
                                    chatController.msgController.value,
                                scrollController:
                                    chatController.scrollController,
                              )
                            : const SizedBox())
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  void _showPersonalInfoDialog(
      {required BuildContext context,
      required Map<String, dynamic> userInfoData}) {
    final String name = (userInfoData['name'] ?? 'No Name').toString();
    final String email = (userInfoData['email'] ?? 'No Email').toString();
    final String mobile =
        (userInfoData['mobile'] ?? userInfoData['phone'] ?? 'N/A').toString();
    final String image = (userInfoData['profilePic'] ?? '').toString();
    final String userType = (userInfoData['userType'] ?? 'user').toString();

    print("User Type dhhafjlhfsahksl: $userType");

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return PersonalInfoDialog(
          name: name,
          email: email,
          mobile: mobile,
          image: image,
          userType: userType,
        );
      },
    );
  }

  void _showReportDialog(
      {required BuildContext context,
      required TextEditingController textEditingController,
      required VoidCallback onTap,
      required String title,
      required RxBool isLoading}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: TextField(
            controller: textEditingController,
            maxLines: 3,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), hintText: "Enter your issue"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            Obx(
              () => TextButton(
                onPressed: onTap,
                child: isLoading.value
                    ? const CircularProgressIndicator.adaptive()
                    : const Text('Submit'),
              ),
            )
          ],
        );
      },
    );
  }

  void _showDeleteGroupDialog(
      {required BuildContext context,
      required RxBool isLoading,
      required VoidCallback onDeleteTap}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Group'),
          content: const Text(
              'Are you sure you want to delete this group? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            Obx(
              () => TextButton(
                onPressed: () {
                  onDeleteTap();
                },
                child: isLoading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            )
          ],
        );
      },
    );
  }

  void _showBottomSheet(BuildContext context, String msgId,
      {VoidCallback? handleReply,
      required String from,
      // VoidCallback? deleteMessage,
      required ChatModel chatdata}) {
    final colors = context.appColors;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: colors.scaffoldBg,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.primary),
                title: Text(
                  'Delete',
                  style: TextStyle(fontSize: 16, color: colors.textPrimary),
                ),
                onTap: () {
                  chatController.deleteMessage(chatdata.sId);
                  // snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message deleted'),
                      duration: Duration(milliseconds: 500),
                    ),
                  );
                  backFromPrevious(context: context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: AppColors.primary),
                title: Text(
                  'Copy',
                  style: TextStyle(fontSize: 16, color: colors.textPrimary),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: chatdata.message));
                  // snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied'),
                      duration: Duration(milliseconds: 500),
                    ),
                  );
                  backFromPrevious(context: context);
                },
              ),
              ListTile(
                  leading: const Icon(Icons.reply, color: AppColors.primary),
                  title: Text(
                    'Reply',
                    style: TextStyle(fontSize: 16, color: colors.textPrimary),
                  ),
                  onTap: handleReply),
              from == "sender"
                  ? ListTile(
                      leading: const Icon(Icons.info, color: Colors.orange),
                      title: const Text(
                        'Info',
                        style: TextStyle(fontSize: 16, color: Colors.orange),
                      ),
                      onTap: () {
                        backFromPrevious(context: context);
                        doNavigator(
                            route: ChatInfoListScreen(
                              chatModel: chatdata,
                            ),
                            context: context);
                      })
                  : const SizedBox(),
              from == "reciver"
                  ? ListTile(
                      leading: const Icon(Icons.report, color: Colors.red),
                      title: const Text(
                        'Report Message',
                        style: TextStyle(fontSize: 16, color: Colors.red),
                      ),
                      onTap: () {
                        backFromPrevious(context: context);
                        _showReportDialog(
                          context: context,
                          textEditingController:
                              reportController.messageReportController.value,
                          onTap: () {
                            reportController.messageReport(
                              messageId: msgId,
                              groupId: widget.groupId,
                              context: context,
                            );
                          },
                          title: "Report Message",
                          isLoading: false.obs,
                        );
                      },
                    )
                  : const SizedBox(),
            ],
          ),
        );
      },
    );
  }
}
