import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Features/Chat/Presentation/chat_screen.dart';
import 'package:cu_app/Features/Meetings/Model/meetings_list_model.dart';
import 'package:cu_app/Features/Meetings/Controller/meetings_list_controller.dart';
import 'package:cu_app/Utils/datetime_utils.dart';
import 'package:cu_app/Widgets/custom_app_bar.dart';
import 'package:cu_app/Widgets/custom_card.dart';
import 'package:cu_app/Widgets/rounded_corner_container.dart';
import 'package:cu_app/Widgets/toast_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../Commons/app_theme_colors.dart';
import '../../../Commons/loading_widget.dart';
import '../../../Widgets/delete_button.dart';
import '../../GroupInfo/Presentation/group_info_screen.dart';
import '../../Login/Controller/login_controller.dart';
import '../Controller/meeting_details_controller.dart';
import '../../../Utils/storage_service.dart';
import '../../../Utils/invite_utils.dart';
import 'edit_meeting_screen.dart';

// This screen displays the details of a meeting, including its title, description, start and end times, participants, and allows admins to edit or delete the meeting. It also shows the time remaining until the meeting starts or ends.
class MeetingDetailsScreen extends StatefulWidget {
  final MeetingModel meeting;

  const MeetingDetailsScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<MeetingDetailsScreen> createState() => _MeetingDetailsScreenState();
}

class _MeetingDetailsScreenState extends State<MeetingDetailsScreen> {
  Timer? _timer;
  Timer? _meetingCallDetailsTimer;
  RxString timeUntilMeeting = ''.obs;
  RxString meetingStatus = ''.obs;
  final meetingsController = Get.find<MeetingsListController>();
  final meetingDetailsController = Get.put(MeetingDetailsController());

  final userController = Get.put(LoginController());

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
    WidgetsBinding.instance.addPostFrameCallback((t) {
      meetingStatus.value = '';
      meetingsController.openedMeetingId.value = widget.meeting.sId!;

      if (widget.meeting.sId != null) {
        meetingsController.getMeetingCallDetails(widget.meeting.sId!);
        meetingDetailsController.getMeetingDetails(widget.meeting.sId!);
        _startTimer();
        _startMeetingCallDetailsTimer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _meetingCallDetailsTimer?.cancel();
    _meetingCallDetailsTimer = null;
    meetingsController.openedMeetingId.value = '';
    meetingsController.isMeRemovedFromMeeting.value = false;
    meetingDetailsController.meetingDetails.value = null;
    meetingStatus.value = '';
    timeUntilMeeting.value = '';
    super.dispose();
  }

  void _startTimer() {
    _updateTimeAndStatus();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeAndStatus();
    });
  }

  void _updateTimeAndStatus() {
    final now = DateTime.now();
    final startTime = _getDateTime(
        meetingDetailsController.meetingDetails.value?.meetingStartTime);
    final endTime = _getDateTime(
        meetingDetailsController.meetingDetails.value?.meetingEndTime);

    if (startTime == null) {
      meetingStatus.value = '';
      timeUntilMeeting.value = '';
      return;
    }

    if (now.isBefore(startTime)) {
      meetingStatus.value = 'UPCOMING';
      final difference = startTime.difference(now);
      timeUntilMeeting.value = _formatDuration(difference);
    } else if (endTime != null &&
        now.isAfter(startTime) &&
        now.isBefore(endTime)) {
      meetingStatus.value = 'ONGOING';
      final difference = endTime.difference(now);
      timeUntilMeeting.value = 'Ends ${_formatDuration(difference)}';
    } else if (endTime != null && now.isAfter(endTime)) {
      meetingStatus.value = 'ENDED';
      timeUntilMeeting.value = 'Meeting has ended';
    } else {
      meetingStatus.value = '';
      timeUntilMeeting.value = '';
    }
  }

  void _startMeetingCallDetailsTimer() {
    _meetingCallDetailsTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) {
      if (widget.meeting.sId != null) {
        meetingsController.getMeetingCallDetails(widget.meeting.sId!,
            isRefresh: false);
      }
    });
  }

  DateTime? _getDateTime(String? dateTimeString) {
    if (dateTimeString == null) return null;
    try {
      final localTimeString =
          DateTimeUtils.utcToLocal(dateTimeString, 'yyyy-MM-ddTHH:mm:ss.SSSZ');
      return DateTime.parse(localTimeString);
    } catch (e) {
      return null;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return 'in ${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return 'in ${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return 'in ${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'in ${duration.inSeconds} second${duration.inSeconds > 1 ? 's' : ''}';
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Not specified';
    try {
      final localTimeString =
          DateTimeUtils.utcToLocal(dateTimeString, 'yyyy-MM-ddTHH:mm:ss.SSSZ');
      final dateTime = DateTime.parse(localTimeString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'UPCOMING':
        return AppColors.green;
      case 'ONGOING':
        return AppColors.orange;
      case 'ENDED':
        return AppColors.red;
      default:
        return AppColors.primary;
    }
  }

  String _formatTimeAgo(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dateTime = DateTime.parse(
          DateTimeUtils.utcToLocal(dateTimeString, 'yyyy-MM-ddTHH:mm:ss.SSSZ'));
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surfaceBg,
      appBar: CustomAppBar(
        autoImplyLeading: true,
        title: 'Meeting Details',
        actions: [
          Obx(() {
            if (meetingDetailsController.isLoading.value) {
              return const SizedBox.shrink();
            }
            if (meetingStatus.value == '') {
              return const SizedBox.shrink();
            }
            if (meetingStatus.value == 'ONGOING' ||
                meetingStatus.value == 'ENDED') {
              return const SizedBox.shrink();
            }
            if (!isUserAdminOrSuperAdmin) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.edit, color: AppColors.white, size: 24),
              onPressed: () {
                final meetingGroupId = widget.meeting.sId ?? widget.meeting.id;
                if (meetingGroupId == null || meetingGroupId.isEmpty) {
                  TostWidget().errorToast(
                    title: "Error",
                    message: "Meeting ID not found",
                  );
                  return;
                }
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => EditMeetingScreen(
                    groupId: meetingGroupId,
                  ),
                ));
              },
            );
          }),
        ],
      ),
      body: RoundedCornerContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() {
                if (meetingDetailsController.isLoading.value) {
                  return const Center(
                    child: SizedBox.shrink(),
                  );
                }
                return CustomCard(
                  padding: const EdgeInsets.all(AppSizes.kDefaultPadding * 1.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                  AppSizes.cardCornerRadius * 2),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary.withOpacity(0.8),
                                  AppColors.primary,
                                ],
                              ),
                            ),
                            child: meetingDetailsController
                                        .meetingDetails.value?.groupImage !=
                                    null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        AppSizes.cardCornerRadius * 2),
                                    child: CachedNetworkImage(
                                      imageUrl: meetingDetailsController
                                              .meetingDetails
                                              .value
                                              ?.groupImage! ??
                                          '',
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          Icon(
                                        Icons.video_call,
                                        color: colors.textOnPrimary,
                                        size: 30,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.video_call,
                                    color: colors.textOnPrimary,
                                    size: 30,
                                  ),
                          ),
                          const SizedBox(width: AppSizes.kDefaultPadding),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Obx(() => Text(
                                      meetingDetailsController.meetingDetails
                                              .value?.groupName ??
                                          'Untitled Meeting',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary,
                                          ),
                                    )),
                                const SizedBox(height: 4),
                                Obx(() {
                                  final bool isDeviceEvent =
                                      meetingDetailsController.meetingDetails
                                                  .value?.isDeviceEvent ==
                                              true ||
                                          widget.meeting.isDeviceEvent == true;
                                  return meetingStatus.value.isEmpty
                                      ? const SizedBox.shrink()
                                      : Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(
                                                    meetingStatus.value),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                meetingStatus.value,
                                                style: TextStyle(
                                                  color: colors.textOnPrimary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),

                                            // copy/share invite buttons (hide for device calendar events)
                                            if (!isDeviceEvent) ...[
                                              const SizedBox(width: 12),
                                              GestureDetector(
                                                onTap: () async {
                                                  final meetingData =
                                                      meetingDetailsController
                                                          .meetingDetails.value;
                                                  await InviteUtils
                                                      .copyInviteToClipboard(
                                                    context: context,
                                                    link:
                                                        meetingData?.link ?? '',
                                                    pin: meetingData?.pin ?? '',
                                                    meetingStartTime:
                                                        meetingData
                                                            ?.meetingStartTime,
                                                  );
                                                },
                                                child: const Icon(
                                                  Icons.copy,
                                                  size: 20,
                                                  color: AppColors.primary,
                                                ),
                                              ),

                                              // share button
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () async {
                                                  final meetingData =
                                                      meetingDetailsController
                                                          .meetingDetails.value;
                                                  await InviteUtils.shareInvite(
                                                    link:
                                                        meetingData?.link ?? '',
                                                    pin: meetingData?.pin ?? '',
                                                    meetingStartTime:
                                                        meetingData
                                                            ?.meetingStartTime,
                                                  );
                                                },
                                                child: const Icon(
                                                  Icons.share,
                                                  size: 20,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (meetingDetailsController.meetingDetails.value
                              ?.groupDescription?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: AppSizes.kDefaultPadding),
                        Obx(() => Text(
                              meetingDetailsController.meetingDetails.value
                                      ?.groupDescription! ??
                                  '',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                  ),
                            )),
                      ],
                      const SizedBox(height: AppSizes.kDefaultPadding),
                      Obx(() => timeUntilMeeting.value.isEmpty ||
                              timeUntilMeeting.value == ''
                          ? const SizedBox.shrink()
                          : Container(
                              padding: const EdgeInsets.all(
                                  AppSizes.kDefaultPadding),
                              decoration: BoxDecoration(
                                color: meetingStatus.value == 'ONGOING'
                                    ? AppColors.orange.withOpacity(0.1)
                                    : AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: meetingStatus.value == 'ONGOING'
                                      ? AppColors.orange
                                      : AppColors.primary,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    meetingStatus.value == 'ONGOING'
                                        ? Icons.call_end
                                        : Icons.schedule,
                                    color: meetingStatus.value == 'ONGOING'
                                        ? AppColors.orange
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      timeUntilMeeting.value,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color:
                                                meetingStatus.value == 'ONGOING'
                                                    ? AppColors.orange
                                                    : AppColors.primary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 2),
              Obx(() => meetingDetailsController.isLoading.value
                  ? const Center(
                      child: SizedBox.shrink(),
                    )
                  : CustomCard(
                      padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'From',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    Obx(() => Text(
                                          _formatDateTime(
                                              meetingDetailsController
                                                  .meetingDetails
                                                  .value
                                                  ?.meetingStartTime),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w400,
                                              ),
                                        )),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSizes.kDefaultPadding),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'To',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    Obx(() => Text(
                                          _formatDateTime(
                                              meetingDetailsController
                                                  .meetingDetails
                                                  .value
                                                  ?.meetingEndTime),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w400,
                                              ),
                                        )),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
              const SizedBox(height: 2),
              Obx(() {
                if (!isUserAdminOrSuperAdmin) {
                  return const SizedBox.shrink();
                }
                if ((meetingStatus.value == 'ONGOING' ||
                    meetingStatus.value == 'ENDED')) {
                  return const SizedBox.shrink();
                }
                return meetingsController.isDeleteLoading.value ||
                        meetingDetailsController.isLoading.value
                    ? const Center(
                        child: CircularProgressIndicator.adaptive(),
                      )
                    : Center(
                        child: DeleteButton(
                          label: 'Cancel this meeting',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Delete Meeting'),
                                  content: const Text(
                                      'Are you sure you want to delete this meeting?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context)
                                            .pop(); // Close dialog
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await meetingsController
                                            .deleteMeeting(widget.meeting.sId!);
                                      },
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: AppColors.red),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      );
              }),

              // For non-admin users: show Accept / Decline buttons if meeting is UPCOMING and user has not acted
              Obx(() {
                // if (isUserAdminOrSuperAdmin) return const SizedBox.shrink();
                final bool isDeviceEvent = meetingDetailsController
                            .meetingDetails.value?.isDeviceEvent ==
                        true ||
                    widget.meeting.isDeviceEvent == true;
                if (isDeviceEvent) return const SizedBox.shrink();
                if (meetingStatus.value != 'UPCOMING')
                  return const SizedBox.shrink();

                final participantActions = meetingDetailsController
                    .meetingDetails.value?.participantActions;
                final userId = LocalStorage().getUserId();
                final hasActed =
                    participantActions?.any((pa) => pa.userId == userId) ==
                        true;
                if (hasActed) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: meetingDetailsController.isLoading.value
                            ? null
                            : () async {
                                await meetingDetailsController
                                    .acceptMeeting(widget.meeting.sId ?? '');
                              },
                        child: const Text(
                          'Accept',
                          style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: meetingDetailsController.isLoading.value
                            ? null
                            : () async {
                                final reasonController =
                                    TextEditingController();
                                await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Decline Meeting'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Reason (optional)'),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: reasonController,
                                          decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              hintText: 'Reason'),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('Cancel')),
                                      TextButton(
                                          onPressed: () async {
                                            Navigator.of(context).pop();
                                            await meetingDetailsController
                                                .declineMeeting(
                                                    widget.meeting.sId ?? '',
                                                    reason:
                                                        reasonController.text);
                                          },
                                          child: const Text('Decline',
                                              style: TextStyle(
                                                  color: AppColors.red)))
                                    ],
                                  ),
                                );
                              },
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              Obx(() {
                final callDetails = meetingsController.meetingCallDetails.value;
                final hasCallDetails = callDetails?.data?.hasCall == true;

                final currentUsers =
                    meetingDetailsController.meetingDetails.value?.currentUsers;

                if (meetingsController.isCallDetailsLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (currentUsers?.isNotEmpty != true) {
                  return const SizedBox.shrink();
                }

                return CustomCard(
                  padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            hasCallDetails
                                ? 'Participants (${(currentUsers!.length) - 1})'
                                : 'Participants (${(currentUsers!.length) - 1})',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                          ),
                          const Spacer(),
                          if (isUserAdminOrSuperAdmin &&
                              (meetingStatus.value != 'ENDED' &&
                                  meetingStatus.value != ''))
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              onPressed: () {
                                final meetingId = meetingDetailsController
                                        .meetingDetails.value?.sId ??
                                    widget.meeting.id;
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => GroupInfoScreen(
                                      groupId: meetingId.toString(),
                                      meetingStatus:
                                          meetingStatus.value.toLowerCase(),
                                      isAdmin: true,
                                      isMeeting: true),
                                ));
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.kDefaultPadding),
                      Obx(() {
                        final bool isDeviceEvent = meetingDetailsController
                                    .meetingDetails.value?.isDeviceEvent ==
                                true ||
                            widget.meeting.isDeviceEvent == true;
                        if (isDeviceEvent) return const SizedBox.shrink();

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: currentUsers.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSizes.kDefaultPadding),
                          itemBuilder: (context, index) {
                            final user = currentUsers[index];
                            if (user.userType == "SuperAdmin") {
                              return const SizedBox.shrink();
                            }

                            final joinedUser = hasCallDetails
                                ? callDetails?.data?.joinedUsers
                                    ?.firstWhereOrNull(
                                        (ju) => ju.user?.sId == user.sId)
                                : null;

                            // Participant action (accept/reject) for this user
                            ParticipantActions? pAction;
                            try {
                              final list = meetingDetailsController
                                  .meetingDetails.value?.participantActions;
                              if (list != null) {
                                for (var pa in list) {
                                  if (pa.userId == user.sId) {
                                    pAction = pa;
                                    break;
                                  }
                                }
                              }
                            } catch (_) {
                              pAction = null;
                            }

                            final actionType =
                                (pAction?.action ?? '').toLowerCase();

                            return Row(
                              children: [
                                // Avatar with colored border when accepted/rejected
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: actionType == 'accept'
                                          ? AppColors.green
                                          : actionType == 'reject'
                                              ? AppColors.red
                                              : Colors.transparent,
                                      width: actionType.isEmpty ? 0 : 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        AppSizes.cardCornerRadius * 10),
                                    child: CachedNetworkImage(
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      imageUrl: user.image ?? "",
                                      placeholder: (context, url) =>
                                          const CircleAvatar(
                                        radius: 24,
                                        backgroundColor: AppColors.shimmer,
                                      ),
                                      errorWidget: (context, url, error) =>
                                          CircleAvatar(
                                        radius: 24,
                                        backgroundColor: AppColors.shimmer,
                                        child: Text(
                                          user.name
                                                  ?.substring(0, 1)
                                                  .toUpperCase() ??
                                              '?',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: colors.textPrimary,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.kDefaultPadding),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name ?? 'Unknown User',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (hasCallDetails &&
                                          joinedUser != null) ...[
                                        if (joinedUser.joinedAt != null &&
                                            joinedUser.status == 'joined')
                                          Text(
                                            'Joined ${_formatTimeAgo(joinedUser.joinedAt)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.green,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        if (joinedUser.leftAt != null &&
                                            joinedUser.status == 'left')
                                          Text(
                                            'User Left',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.red,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                      ] else if (hasCallDetails)
                                        ...[],
                                    ],
                                  ),
                                ),

                                // Show accepted/rejected badge with tooltip when present
                                if (actionType.isNotEmpty)
                                  Tooltip(
                                    message:
                                        '${actionType == 'reject' ? 'Rejected' : 'Accepted'}\n${pAction?.actionDescription ?? ''}\n${pAction?.createdAt ?? ''}',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            actionType == 'reject'
                                                ? Icons.cancel
                                                : Icons.check_circle,
                                            color: actionType == 'reject'
                                                ? AppColors.red
                                                : AppColors.green,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            actionType == 'reject'
                                                ? 'REJECTED'
                                                : 'ACCEPTED',
                                            style: TextStyle(
                                                color: actionType == 'reject'
                                                    ? AppColors.red
                                                    : AppColors.green,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (user.userType?.contains('Admin') == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Admin',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      }),
                    ],
                  ),
                );
              }),
              const SizedBox(height: AppSizes.kDefaultPadding * 10),
            ],
          ),
        ),
      ),
      floatingActionButton: Obx(() => meetingStatus.value == 'ONGOING'
          ? FloatingActionButton.extended(
              onPressed: () async {
                showConnectingDialog(context, "Please wait...");
                await meetingDetailsController
                    .getMeetingDetails(widget.meeting.sId ?? "");
                hideConnectingDialog();

                if (!mounted) return;

                if (meetingDetailsController.isAllowForJoingMeeting.value) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      groupId: widget.meeting.sId.toString(),
                      isAdmin: false,
                      index: 1,
                      isAccepted: 1,
                      callType: 'video',
                    ),
                  ));
                } else {
                  TostWidget().errorToast(
                      title: "Not allow to join",
                      message: "You are removed from this meeting");
                  Navigator.of(context).pop();
                  meetingsController.getMeetingsList(isLoadingShow: false);
                }
              },
              backgroundColor: AppColors.green,
              icon: const Icon(Icons.video_call, color: AppColors.white),
              label: const Text(
                'Join Now',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : meetingStatus.value == 'UPCOMING'
              ? const FloatingActionButton.extended(
                  onPressed: null,
                  backgroundColor: AppColors.grey,
                  icon: Icon(Icons.schedule, color: AppColors.white),
                  label: Text(
                    'Not Started',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox()),
    );
  }
}
