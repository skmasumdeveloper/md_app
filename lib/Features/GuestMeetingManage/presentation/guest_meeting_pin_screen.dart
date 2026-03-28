import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../Commons/app_colors.dart';
import '../../../Commons/app_sizes.dart';
import '../../../Commons/app_theme_colors.dart';
import '../../../Widgets/custom_card.dart';
import '../../../Widgets/custom_text_field.dart';
import '../../../Widgets/rounded_corner_container.dart';
import '../../../Widgets/toast_widget.dart';
import '../../GuestCall/presentation/guest_video_call_screen.dart';
import '../controller/guest_meeting_controller.dart';
import '../model/guest_meeting_model.dart';

class GuestMeetingPinScreen extends StatefulWidget {
  GuestMeetingPinScreen({Key? key}) : super(key: key);

  @override
  _GuestMeetingPinScreenState createState() => _GuestMeetingPinScreenState();
}

class _GuestMeetingPinScreenState extends State<GuestMeetingPinScreen> {
  final controller =
      Get.put(GuestMeetingController(autoFetchList: false), tag: 'guestPin');

  Timer? _timer;
  Duration _timeToStart = Duration.zero;
  bool _canJoin = false;
  bool _isExpired = false;
  String _statusLabel = 'Scheduled';
  Color _statusColorValue = AppColors.orange;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateStateForMeeting() {
    final meeting = controller.pinMeeting.value;
    if (meeting == null) {
      setState(() {
        _timeToStart = Duration.zero;
        _canJoin = false;
        _isExpired = false;
        _statusLabel = 'Scheduled';
        _statusColorValue = AppColors.orange;
      });
      _timer?.cancel();
      return;
    }

    DateTime? start;
    DateTime? end;
    try {
      start = DateTime.parse(meeting.startTime!).toLocal();
      end = DateTime.parse(meeting.endTime!).toLocal();
    } catch (_) {
      start = null;
      end = null;
    }

    final now = DateTime.now();
    final expired = end != null && now.isAfter(end);
    final canJoin =
        start != null && end != null && now.isAfter(start) && now.isBefore(end);

    Duration timeToStart = Duration.zero;
    String statusLabel = 'Scheduled';
    Color statusColor = AppColors.orange;

    if (start != null) {
      if (now.isBefore(start)) {
        timeToStart = start.difference(now);
        statusLabel = 'Starts soon';
        statusColor = AppColors.orange;
      } else if (expired) {
        timeToStart = Duration.zero;
        statusLabel = 'Ended';
        statusColor = AppColors.red;
      } else {
        timeToStart = Duration.zero;
        statusLabel = 'In progress';
        statusColor = AppColors.green;
      }
    }

    setState(() {
      _timeToStart = timeToStart;
      _canJoin = canJoin;
      _isExpired = expired;
      _statusLabel = statusLabel;
      _statusColorValue = statusColor;
    });

    if (expired) {
      _timer?.cancel();
    }
  }

  void _ensureTimerRunning() {
    if (_timer == null || !_timer!.isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateStateForMeeting();
      });
    }
  }

  void _joinGuestCall(GuestMeeting meeting) {
    final roomId = meeting.id ?? '';
    if (roomId.isEmpty) {
      TostWidget().errorToast(title: 'Error', message: 'Meeting id missing');
      return;
    }

    final matchedGuest = controller.pinMatchedGuest.value;
    Get.to(() => GuestVideoCallScreen(
          roomId: roomId,
          guestName: (matchedGuest?.name ?? '').trim().isNotEmpty
              ? matchedGuest!.name!
              : 'Guest',
          guestEmail: (matchedGuest?.email ?? '').trim(),
          meetingTitle: meeting.topic ?? 'Guest Meeting',
          isVideoCall: true,
        ));
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '0s';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0 || parts.isNotEmpty) parts.add('${hours}h');
    parts.add('${minutes}m');
    parts.add('${seconds}s');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surfaceBg,
      body: RoundedCornerContainer(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
            child: Obx(() {
              final meeting = controller.pinMeeting.value;

              if (meeting != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateStateForMeeting();
                  _ensureTimerRunning();
                });
              } else {
                _timer?.cancel();
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: CustomCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: AppColors.themeGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Join a Meeting',
                            style: TextStyle(
                                color: colors.textOnPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Enter your meeting PIN and guest email.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textTertiary)),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: controller.pinController,
                        hintText: 'Enter Meeting PIN',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      CustomTextField(
                        controller: controller.pinEmailController,
                        hintText: 'Enter Guest Email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      Obx(() {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSizes.dimen16),
                          ),
                          onPressed: controller.isPinLoading.value
                              ? null
                              : () async {
                                  final ok =
                                      await controller.fetchGuestMeetingByPin();
                                  if (!ok) return;
                                },
                          child: controller.isPinLoading.value
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text('Verify Details',
                                  style: TextStyle(color: colors.textOnPrimary)),
                        );
                      }),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Back to Home'),
                      ),
                      if (meeting != null) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text('Meeting Details',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colors.textPrimary,
                                )),
                        const SizedBox(height: 12),
                        _MeetingDetailsCard(
                          meeting: meeting,
                          matchedGuest: controller.pinMatchedGuest.value,
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _statusColorValue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(_statusLabel,
                                    style: TextStyle(color: colors.textPrimary)),
                              ],
                            ),
                            if (!_canJoin &&
                                !_isExpired &&
                                _timeToStart > Duration.zero)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                    'Starts in: ${_formatDuration(_timeToStart)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: colors.textTertiary)),
                              ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _canJoin
                                    ? AppColors.primary
                                    : colors.borderColor,
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppSizes.dimen16),
                              ),
                              onPressed: _canJoin
                                  ? () => _joinGuestCall(meeting)
                                  : null,
                              child: Text(
                                _canJoin ? 'Join Meeting' : 'Join',
                                style: TextStyle(color: colors.textOnPrimary),
                              ),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _MeetingDetailsCard extends StatelessWidget {
  final GuestMeeting meeting;
  final GuestParticipant? matchedGuest;

  const _MeetingDetailsCard(
      {required this.meeting, required this.matchedGuest});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    String start = '-';
    String end = '-';
    try {
      final st = DateTime.parse(meeting.startTime!).toLocal();
      final en = DateTime.parse(meeting.endTime!).toLocal();
      start = DateFormat('dd/MM/yyyy hh:mm a').format(st);
      end = DateFormat('dd/MM/yyyy hh:mm a').format(en);
    } catch (_) {}

    return CustomCard(
      padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meeting.topic ?? '-',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                  )),
          const SizedBox(height: 6),
          Text(meeting.description ?? '-',
              style: TextStyle(color: colors.textPrimary)),
          const SizedBox(height: 10),
          Text('Guest: ${matchedGuest?.name ?? '-'}',
              style: TextStyle(color: colors.textPrimary)),
          Text('Email: ${matchedGuest?.email ?? '-'}',
              style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 10),
          Text('Start: $start',
              style: TextStyle(color: colors.textPrimary)),
          Text('End: $end',
              style: TextStyle(color: colors.textPrimary)),
        ],
      ),
    );
  }
}
