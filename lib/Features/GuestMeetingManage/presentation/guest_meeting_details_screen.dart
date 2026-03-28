import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../Commons/app_colors.dart';
import '../../../Commons/app_sizes.dart';
import '../../../Commons/app_theme_colors.dart';
import '../../../Widgets/custom_app_bar.dart';
import '../../../Widgets/custom_card.dart';
import '../../../Widgets/rounded_corner_container.dart';
import '../../../Widgets/toast_widget.dart';
import '../../../Utils/storage_service.dart';
import '../../GuestCall/presentation/guest_video_call_screen.dart';
import '../controller/guest_meeting_controller.dart';
import '../model/guest_meeting_model.dart';
import '../../../Utils/invite_utils.dart';
import 'guest_meeting_edit_screen.dart';

class GuestMeetingDetailsScreen extends StatefulWidget {
  final GuestMeeting meeting;
  GuestMeetingDetailsScreen({Key? key, required this.meeting})
      : super(key: key);

  @override
  _GuestMeetingDetailsScreenState createState() =>
      _GuestMeetingDetailsScreenState();
}

class _GuestMeetingDetailsScreenState extends State<GuestMeetingDetailsScreen> {
  final controller = Get.find<GuestMeetingController>();
  Timer? _timer;

  // Use a mutable local meeting so we can update UI after edits
  late GuestMeeting _meeting;

  DateTime? _startTime;
  DateTime? _endTime;
  String _start = '';
  String _end = '';

  Duration _timeToStart = Duration.zero;
  bool _canJoin = false;
  bool _isExpired = false;
  bool _isFuture = false;
  String _statusLabel = 'Scheduled';
  Color _statusColorValue = AppColors.orange;

  @override
  void initState() {
    super.initState();
    _meeting = widget.meeting;
    _initTimes();
    _startTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.getGuestMeetings(isLoadingShow: false);
    });
  }

  void _initTimes() {
    try {
      if (_meeting.startTime != null) {
        _startTime = DateTime.parse(_meeting.startTime!).toLocal();
        _start = DateFormat('dd/MM/yyyy hh:mm a').format(_startTime!);
      }
      if (_meeting.endTime != null) {
        _endTime = DateTime.parse(_meeting.endTime!).toLocal();
        _end = DateFormat('dd/MM/yyyy hh:mm a').format(_endTime!);
      }
    } catch (_) {}

    _updateStateForTime();
  }

  void _updateStateForTime() {
    final now = DateTime.now();

    _isExpired = _endTime != null && now.isAfter(_endTime!);
    _canJoin = _startTime != null &&
        _endTime != null &&
        now.isAfter(_startTime!) &&
        now.isBefore(_endTime!);
    _isFuture = _startTime != null && now.isBefore(_startTime!);

    if (_startTime != null) {
      if (now.isBefore(_startTime!)) {
        _timeToStart = _startTime!.difference(now);
        _statusLabel = 'Starts soon';
        _statusColorValue = AppColors.orange;
      } else if (_isExpired) {
        _timeToStart = Duration.zero;
        _statusLabel = 'Ended';
        _statusColorValue = AppColors.red;
      } else {
        _timeToStart = Duration.zero;
        _statusLabel = 'In progress';
        _statusColorValue = AppColors.green;
      }
    } else {
      _timeToStart = Duration.zero;
      _statusLabel = 'Scheduled';
      _statusColorValue = AppColors.orange;
    }

    setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateStateForTime();
      if (_isExpired) {
        _timer?.cancel();
      }
    });
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

  void _joinGuestCall() {
    final roomId = _meeting.id ?? '';
    if (roomId.isEmpty) {
      TostWidget().errorToast(title: 'Error', message: 'Meeting id missing');
      return;
    }

    final userId = LocalStorage().getUserId();
    final userName = LocalStorage().getUserName();
    final isAuthUser = userId.isNotEmpty;
    final defaultGuest =
        _meeting.guests.isNotEmpty ? _meeting.guests.first : null;
    final joinName = isAuthUser
        ? (userName.isNotEmpty ? userName : 'User')
        : (defaultGuest?.name ?? 'Guest');
    final joinUserName = isAuthUser ? userId : (defaultGuest?.email ?? '');

    Get.to(() => GuestVideoCallScreen(
          roomId: roomId,
          guestName: joinName,
          guestEmail: joinUserName,
          meetingTitle: _meeting.topic ?? 'Guest Meeting',
          isVideoCall: true,
        ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final canJoin = _canJoin;

    return Scaffold(
      backgroundColor: colors.surfaceBg,
      appBar: CustomAppBar(
        title: 'Meeting Details',
        actions: [
          if (_isFuture)
            IconButton(
              icon: Icon(Icons.edit, color: colors.textOnPrimary),
              onPressed: () async {
                controller.populateFormForEdit(_meeting);
                final res = await Get.to(
                  () => GuestMeetingEditScreen(meeting: _meeting),
                );
                if (res != null) {
                  TostWidget().successToast(
                      title: 'Success', message: 'Guest meeting updated');
                  if (res is GuestMeeting) {
                    _meeting = res;
                    _initTimes();
                  } else {
                    await controller.getGuestMeetings(isLoadingShow: true);
                    final updated = controller.guestMeetings.firstWhere(
                        (e) => e.id == _meeting.id,
                        orElse: () => _meeting);
                    _meeting = updated;
                    _initTimes();
                  }
                  setState(() {});
                }
              },
            )
        ],
      ),
      body: RoundedCornerContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomCard(
                padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MEETING NAME',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.orange)),
                    const SizedBox(height: 6),
                    Text(_meeting.topic ?? '-',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: colors.textPrimary,
                            )),
                  ],
                ),
              ),
              CustomCard(
                padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AGENDA / DESCRIPTION',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.orange)),
                    const SizedBox(height: 6),
                    Text(_meeting.description ?? '-',
                        style: TextStyle(color: colors.textPrimary)),
                  ],
                ),
              ),
              CustomCard(
                padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GUEST PARTICIPANTS (${_meeting.guests.length})',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.orange)),
                    const SizedBox(height: 8),
                    if (_meeting.guests.isEmpty)
                      Text('-', style: TextStyle(color: colors.textSecondary))
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _meeting.guests.map((guest) {
                          final avatarText =
                              (guest.name ?? '').trim().isNotEmpty
                                  ? guest.name!.trim()[0].toUpperCase()
                                  : 'G';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: colors.borderColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.orange,
                                  child: Text(
                                    avatarText,
                                    style: TextStyle(
                                        color: colors.textOnPrimary,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(guest.name ?? '-',
                                        style: TextStyle(color: colors.textPrimary)),
                                    Text(
                                      guest.email ?? '-',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: colors.textTertiary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              CustomCard(
                padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('START TIME',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colors.textTertiary)),
                          const SizedBox(height: 6),
                          Text(_start.isEmpty ? '-' : _start.split(' ')[0],
                              style: TextStyle(color: colors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(
                            _start.isEmpty ? '-' : _start.split(' ')[1],
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: colors.dividerColor,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('END TIME',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colors.textTertiary)),
                          const SizedBox(height: 6),
                          Text(_end.isEmpty ? '-' : _end.split(' ')[0],
                              style: TextStyle(color: colors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(
                            _end.isEmpty ? '-' : _end.split(' ')[1],
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.red),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              CustomCard(
                padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        _startTime != null &&
                        DateTime.now().isBefore(_startTime!))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                            'Starts in: ${_formatDuration(_timeToStart)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.textTertiary)),
                      ),
                  ],
                ),
              ),
              CustomCard(
                padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_meeting.meetingLink ?? '-',
                        style: TextStyle(color: colors.textPrimary))),
                    if (!_isExpired) ...[
                      IconButton(
                        icon: const Icon(Icons.copy, color: AppColors.primary),
                        tooltip: 'Copy invite',
                        onPressed: () async {
                          await InviteUtils.copyInviteToClipboard(
                            context: context,
                            link: _meeting.meetingLink ?? '',
                            pin: _meeting.pin,
                            meetingStartTime: _meeting.startTime,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: AppColors.primary),
                        tooltip: 'Share invite',
                        onPressed: () async {
                          await InviteUtils.shareInvite(
                            link: _meeting.meetingLink ?? '',
                            pin: _meeting.pin,
                            meetingStartTime: _meeting.startTime,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (!_isExpired)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canJoin ? AppColors.primary : colors.borderColor,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.dimen16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: canJoin ? _joinGuestCall : null,
                    child: Text(
                      canJoin ? 'JOIN MEETING' : 'JOIN',
                      style: TextStyle(color: colors.textOnPrimary),
                    ),
                  ),
                )
              else
                Center(
                  child: Text('Meeting ended',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.red)),
                )
            ],
          ),
        ),
      ),
    );
  }
}
