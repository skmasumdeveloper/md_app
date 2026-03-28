import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Features/Meetings/Controller/meetings_list_controller.dart';
import 'package:cu_app/Features/Meetings/Model/meetings_list_model.dart';
import 'package:cu_app/Features/Meetings/Presentation/create_meeting_screen.dart';
import 'package:cu_app/Features/Meetings/Presentation/meeting_details_screen.dart';
import 'package:cu_app/Widgets/custom_card.dart';
import 'package:cu_app/Widgets/custom_text_field.dart';
import 'package:cu_app/Widgets/rounded_corner_container.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../../Commons/app_images.dart';
import '../../../Commons/app_theme_colors.dart';
import '../../../Utils/datetime_utils.dart';
import '../../../Widgets/custom_smartrefresher_fotter.dart';
import '../../GuestMeetingManage/presentation/guest_meeting_list_screen.dart';
import '../../Login/Controller/login_controller.dart';
import '../Controller/meeting_details_controller.dart';
import '../../../Utils/invite_utils.dart';
import 'meeting_calendar_screen.dart';

// This screen displays a list of meetings, allowing users to search, filter, and view details of each meeting. It includes functionality for creating new meetings if the user has the appropriate permissions.
class MeetingsListScreen extends StatefulWidget {
  const MeetingsListScreen({super.key});

  @override
  State<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends State<MeetingsListScreen> {
  final meetingsController = Get.put(MeetingsListController());
  final searchController = TextEditingController();
  final userController = Get.put(LoginController());
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  final meetingDetailsController = Get.put(MeetingDetailsController());

  bool get isUserAdminOrSuperAdmin {
    return userController.userModel.value.userType != null &&
        userController.userModel.value.userType!.isNotEmpty &&
        (userController.userModel.value.userType!.contains(AdminCheck.admin) ||
            userController.userModel.value.userType!
                .contains(AdminCheck.superAdmin));
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      meetingsController.getMeetingsList().then((_) {
        meetingsController.refreshMeetingsList();
      });
    });
  }

  @override
  void dispose() {
    meetingsController.selectedTabIndex.value = 0; // Reset selected tab index
    meetingsController.searchText.value = "";
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          // IconButton(
          //   icon: const Icon(
          //     Icons.calendar_month_sharp,
          //     color: AppColors.white,
          //     size: 28,
          //   ),
          //   tooltip: 'Calendar View',
          //   onPressed: () {
          //     Get.to(() => const MeetingCalendarScreen());
          //   },
          // ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 30),
            child: SizedBox(
              width: 100,
              height: 100,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AppImages.appLogoWhite),
                    fit: BoxFit.contain,
                    opacity: 0.2,
                    filterQuality: FilterQuality.high,
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'Meetings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
      body: RoundedCornerContainer(
        child: Column(
          children: [
            _buildTopTabButtons(),
            const SizedBox(
              height: 5,
            ),
            _buildTopPageButtons(),
            const SizedBox(
              height: 5,
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.kDefaultPadding),
              margin: const EdgeInsets.symmetric(
                  horizontal: AppSizes.kDefaultPadding),
              decoration: BoxDecoration(
                  color: colors.surfaceBg,
                  border: Border.all(width: 1, color: colors.borderColor),
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
                      hintText: 'Search meetings...',
                      minLines: 1,
                      maxLines: 1,
                      onChanged: (value) async {
                        EasyDebounce.debounce(
                            'meetings-debounce', // <-- An ID for this particular debouncer
                            const Duration(
                                milliseconds: 200), // <-- The debounce duration
                            () async {
                          meetingsController.searchMeetings(value);
                        } // <-- The target method
                            );
                      },
                      isBorder: false,
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(
              height: AppSizes.kDefaultPadding,
            ),
            Expanded(
              child: Obx(() {
                if (meetingsController.isMeetingsListLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  );
                }

                if (meetingsController.meetingsList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(height: AppSizes.kDefaultPadding),
                        Text(
                          'No scheduled meetings',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: colors.textTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: AppSizes.kDefaultPadding / 2),
                        Text(
                          'Schedule your first meeting to get started',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textTertiary,
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                return SmartRefresher(
                  controller: _refreshController,
                  enablePullDown: true,
                  enablePullUp: true,
                  onRefresh: () async {
                    meetingsController.limit.value = 10;
                    meetingsController.getMeetingsList(isLoadingShow: true);
                    _refreshController.refreshCompleted();
                  },
                  onLoading: () async {
                    meetingsController.limit.value += 10;
                    meetingsController.getMeetingsList(isLoadingShow: false);
                    _refreshController.loadComplete();
                  },
                  footer: const CustomFooterWidget(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding,
                    ),
                    itemCount: meetingsController.meetingsList.length,
                    itemBuilder: (context, index) {
                      final meeting = meetingsController.meetingsList[index];
                      return _buildMeetingCard(context, meeting);
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // floatingActionButton: isUserAdminOrSuperAdmin
      //     ? FloatingActionButton.extended(
      //         heroTag: 'right_fab',
      //         onPressed: () {
      //           Get.to(() => const CreateMeetingScreen());
      //         },
      //         backgroundColor: AppColors.primary,
      //         icon: const Icon(Icons.add, color: AppColors.white),
      //         label: const Text('Create Meeting'),
      //       )
      //     : null,
    );
  }

  Widget _buildMeetingCard(BuildContext context, MeetingModel meeting) {
    final colors = context.appColors;
    // final createdDate = DateTime.parse(meeting.createdAt ?? DateTime.now().toString());
    // final timeAgo = _getTimeAgo(createdDate);
    final formattedTime = _formatTime(meeting.meetingStartTime);
    final meetingStatus =
        _meetingStatus(meeting.meetingStartTime, meeting.meetingEndTime);

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: CustomCard(
        onPressed: () {
          if (meeting.isDeviceEvent == true) {
            // TostWidget().errorToast(
            //     title: 'Not available',
            //     message:
            //         'Details are not available for device calendar events');
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MeetingDetailsScreen(meeting: meeting),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.kDefaultPadding,
            vertical: AppSizes.kDefaultPadding / 1.2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppSizes.cardCornerRadius * 2),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.8),
                          AppColors.primary,
                        ],
                      ),
                    ),
                    child: meeting.groupImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(
                                AppSizes.cardCornerRadius * 2),
                            child: CachedNetworkImage(
                              imageUrl: meeting.groupImage!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  _buildMeetingIcon(),
                              errorWidget: (context, url, error) =>
                                  _buildMeetingIcon(),
                            ),
                          )
                        : _buildMeetingIcon(),
                  ),
                  const SizedBox(width: AppSizes.kDefaultPadding),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                meeting.groupName ?? 'Untitled Meeting',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getMeetingStatusColor(meetingStatus),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                meetingStatus,
                                style: TextStyle(
                                  color: colors.textOnPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (meeting.groupDescription != null &&
                            meeting.groupDescription!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              meeting.groupDescription!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.textTertiary,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 20,
                              color: colors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedTime,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.textTertiary,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (meeting.currentUsers != null &&
                  meeting.currentUsers!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    memberWidget(meeting.currentUsers!),
                    const SizedBox(width: AppSizes.kDefaultPadding),
                    // Expanded(
                    //   child: Text(
                    //     '${(meeting.currentUsers!.length - 1)} participant${meeting.currentUsers!.length > 2 ? 's' : ''}',
                    //     style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    //           color: AppColors.grey,
                    //           fontWeight: FontWeight.w500,
                    //         ),
                    //   ),
                    // ),
                    Expanded(child: Container()),
                    // Copy & Share invite buttons
                    if (meeting.link != null && meeting.link!.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.copy,
                            size: 20, color: AppColors.primary),
                        tooltip: 'Copy invite',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                        onPressed: () async {
                          await InviteUtils.copyInviteToClipboard(
                            context: context,
                            link: meeting.link ?? '',
                            pin: meeting.pin ?? '',
                            meetingStartTime: meeting.meetingStartTime,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share,
                            size: 20, color: AppColors.primary),
                        tooltip: 'Share invite',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                        onPressed: () async {
                          await InviteUtils.shareInvite(
                            link: meeting.link ?? '',
                            pin: meeting.pin ?? '',
                            meetingStartTime: meeting.meetingStartTime,
                          );
                        },
                      ),
                    ],

                    if (meetingStatus == 'ONGOING')
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    MeetingDetailsScreen(meeting: meeting),
                              ),
                            );
                          } catch (e) {
                            debugPrint("Error opening meeting: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        label: const Text(
                          'Open',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (meetingStatus == 'UPCOMING')
                      ElevatedButton.icon(
                        onPressed: null, // Disabled button
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.grey,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(Icons.video_call, size: 16),
                        label: const Text(
                          'Not started',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingIcon() {
    return const Icon(
      Icons.video_call,
      color: AppColors.white,
      size: 28,
    );
  }

  Widget memberWidget(List<CurrentUsers> membersList) {
    final colors = context.appColors;
    final filteredMembers =
        membersList.where((member) => member.userType != "SuperAdmin").toList();

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
                            placeholder: (context, url) => const CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.shimmer,
                            ),
                            errorWidget: (context, url, error) => CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.shimmer,
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

  String _meetingStatus(String? startTime, String? endTime) {
    final localStartTime =
        DateTimeUtils.utcToLocal(startTime ?? '', 'yyyy-MM-ddTHH:mm:ss.SSSZ');
    final localEndTime = endTime != null
        ? DateTimeUtils.utcToLocal(endTime, 'yyyy-MM-ddTHH:mm:ss.SSSZ')
        : null;

    if (localStartTime == '' || localStartTime.isEmpty) return 'SCHEDULED';
    final now = DateTime.now();
    final meetingStartTime = DateTime.parse(localStartTime);
    final meetingEndTime =
        localEndTime != null ? DateTime.parse(localEndTime) : null;

    if (now.isBefore(meetingStartTime)) {
      return 'UPCOMING';
    } else if (meetingEndTime != null &&
        now.isAfter(meetingStartTime) &&
        now.isBefore(meetingEndTime)) {
      return 'ONGOING';
    } else if (meetingEndTime != null && now.isAfter(meetingEndTime)) {
      return 'ENDED';
    }
    return 'SCHEDULED';
  }

  Color _getMeetingStatusColor(String meetingStatus) {
    switch (meetingStatus) {
      case 'UPCOMING':
        return AppColors.green;
      case 'ONGOING':
        return AppColors.orange;
      case 'ENDED':
        return AppColors.red;
      default:
        return AppColors.green;
    }
  }

  String _formatTime(String? dateTime) {
    if (dateTime == null) return "";

    try {
      final setDateTime =
          DateTimeUtils.utcToLocal(dateTime, 'yyyy-MM-ddTHH:mm:ss.SSSZ');
      final date = DateTime.parse(setDateTime);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        final hour12 =
            date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
        return "Today at ${hour12.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}";
      } else {
        return "${DateFormat('dd/MM/yyyy').format(date)} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}";
      }
    } catch (e) {
      return "";
    }
  }

  Widget _buildTopTabButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildTabButton("Scheduled", 0),
        ),
        Expanded(
          child: _buildTabButton("Past", 1),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index) {
    final colors = context.appColors;
    return Obx(
      () => GestureDetector(
        onTap: meetingsController.isMeetingsListLoading.value
            ? null
            : () {
                meetingsController.selectedTabIndex.value = index;

                meetingsController.getMeetingsList(isLoadingShow: true);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: meetingsController.selectedTabIndex.value == index
                ? AppColors.primary
                : colors.surfaceBg,
            border: Border(
              top: BorderSide(
                color: meetingsController.selectedTabIndex.value == index
                    ? colors.textPrimary
                    : Colors.transparent,
                width: 0.25,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: meetingsController.selectedTabIndex.value == index
                  ? colors.textOnPrimary
                  : colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopPageButtons() {
    if (!isUserAdminOrSuperAdmin) return const SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Get.to(() => const CreateMeetingScreen());
          },
          // backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: AppColors.white),
          label: const Text('Create Meeting'),
        ),
        SizedBox(width: AppSizes.kDefaultPadding),
        // ElevatedButton.icon(
        //   onPressed: () {
        //     Get.to(() => GuestMeetingListScreen());
        //   },
        //   // backgroundColor: AppColors.primary,
        //   icon: const Icon(Icons.group, color: AppColors.white),
        //   label: const Text('Guest Meetings'),
        // ),
      ],
    );
  }
}
