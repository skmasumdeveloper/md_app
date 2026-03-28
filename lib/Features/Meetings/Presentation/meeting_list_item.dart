import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../Commons/app_colors.dart';
import '../../../Commons/app_images.dart';
import '../../../Commons/app_theme_colors.dart';
import '../../../Utils/invite_utils.dart';
import '../Model/meetings_list_model.dart';

class MeetingListItem extends StatelessWidget {
  final MeetingModel meeting;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool isProcessing;

  const MeetingListItem({
    super.key,
    required this.meeting,
    this.onTap,
    this.onAccept,
    this.onDecline,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    String time = '';
    try {
      final dt = DateTime.parse(meeting.meetingStartTime!).toLocal();
      time = DateFormat('hh:mm a').format(dt);
    } catch (_) {}

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.borderColor),
          boxShadow: [
            BoxShadow(
              color: colors.shadowColor,
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: meeting.groupImage != null &&
                      meeting.groupImage!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: meeting.groupImage!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 48,
                        height: 48,
                        color: colors.surfaceBg,
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 48,
                        height: 48,
                        color: colors.surfaceBg,
                        child: Icon(Icons.group, color: colors.textOnPrimary),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: meeting.isDeviceEvent == true
                          ? Colors.blueGrey
                          : AppColors.secondary,
                      child: meeting.isDeviceEvent == true
                          ? Center(
                              child: Image.asset(
                                AppImages.calendarIcon,
                                width: 24,
                                height: 24,
                                color: colors.textOnPrimary,
                              ),
                            )
                          : Icon(Icons.video_call, color: colors.textOnPrimary),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.groupName ?? 'Untitled',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Copy & Share: hide for device calendar events
                if (meeting.isDeviceEvent != true &&
                    meeting.link != null &&
                    meeting.link!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        size: 20, color: AppColors.secondary),
                    tooltip: 'Copy invite',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                    onPressed: () async {
                      await InviteUtils.copyInviteToClipboard(
                        context: Navigator.of(context).overlay!.context,
                        link: meeting.link ?? '',
                        pin: meeting.pin ?? '',
                        meetingStartTime: meeting.meetingStartTime,
                      );
                    },
                  ),
                // share button
                if (meeting.isDeviceEvent != true &&
                    meeting.link != null &&
                    meeting.link!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.share,
                        size: 20, color: AppColors.secondary),
                    tooltip: 'Share',
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
                // If the meeting is in the future show action area (buttons or status)
                if (meeting.isDeviceEvent != true && _isFutureMeeting()) ...[
                  const SizedBox(width: 8),
                  if (isProcessing)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (meeting.userAction == null) ...[
                    InkWell(
                      onTap: onAccept ??
                          () {
                            ScaffoldMessenger.of(
                                    Navigator.of(context).overlay!.context)
                                .showSnackBar(
                                    const SnackBar(content: Text('Accepted')));
                          },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Accept',
                          style: TextStyle(
                            color: colors.textOnPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onDecline ??
                          () {
                            ScaffoldMessenger.of(
                                    Navigator.of(context).overlay!.context)
                                .showSnackBar(
                                    const SnackBar(content: Text('Declined')));
                          },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Decline',
                          style: TextStyle(
                            color: colors.textOnPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Show accepted/rejected badge when userAction exists for future meeting
                    Builder(builder: (context) {
                      final action = (meeting.userAction?.action ?? '')
                          .toString()
                          .toLowerCase();
                      final bool accepted =
                          action == 'accept' || action == 'accepted';
                      final Color bg = accepted ? AppColors.green : AppColors.red;
                      final IconData icon =
                          accepted ? Icons.check_circle : Icons.cancel;
                      final String label = accepted ? 'ACCEPTED' : 'REJECTED';

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: bg.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: bg),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: bg, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                  color: bg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isFutureMeeting() {
    if (meeting.meetingStartTime == null) return false;
    try {
      final start = DateTime.parse(meeting.meetingStartTime!).toLocal();
      return start.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }
}
