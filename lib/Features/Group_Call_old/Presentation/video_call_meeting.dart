part of 'video_call_screen.dart';

extension GroupVideoCallMeetingExtension on _GroupVideoCallScreenState {
  // This method starts the meeting end timer if the group is temporary and has a meeting end time set.
  void _startMeetingEndTimerIfNeeded() {
    groupcallController
        .getGroupDetailsById(widget.groupId, 'groupName')
        .then((_) {
      if (groupcallController.groupModel.value.isTemp == true) {
        groupcallController.startMeetingEndTimer(widget.groupId);
      }
    });
  }

  // This method starts a timer to update the meeting time text every second.
  void _startMeetingTimeUpdates() {
    _updateMeetingTimeText();

    _meetingTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateMeetingTimeText();
    });
  }

  // This method updates the dynamic meeting time text based on the group's meeting end time.
  void _updateMeetingTimeText() {
    if (groupcallController.groupModel.value.isTemp == true &&
        groupcallController.groupModel.value.meetingEndTime != null &&
        groupcallController.groupModel.value.meetingEndTime!.isNotEmpty) {
      dynamicMeetingTimeText.value = _getMeetingTimeText();
    } else {
      dynamicMeetingTimeText.value = 'Scheduled Meeting';
    }
  }

  String _getMeetingTimeText() {
    if (groupcallController.groupModel.value.meetingEndTime == null ||
        groupcallController.groupModel.value.meetingEndTime!.isEmpty) {
      return 'Scheduled Meeting';
    }

    try {
      final endTime = DateTime.parse(DateTimeUtils.utcToLocal(
          groupcallController.groupModel.value.meetingEndTime!,
          'yyyy-MM-ddTHH:mm:ss.SSSZ'));
      final now = DateTime.now();

      if (endTime.isAfter(now)) {
        final timeLeft = endTime.difference(now);

        if (timeLeft.inDays > 0) {
          return 'Meeting ends in ${timeLeft.inDays}d ${timeLeft.inHours % 24}h ${timeLeft.inMinutes % 60}m';
        } else if (timeLeft.inHours > 0) {
          return 'Meeting ends in ${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m ${timeLeft.inSeconds % 60}s';
        } else if (timeLeft.inMinutes > 0) {
          return 'Meeting ends in ${timeLeft.inMinutes}m ${timeLeft.inSeconds % 60}s';
        } else if (timeLeft.inSeconds > 0) {
          return 'Meeting ends in ${timeLeft.inSeconds}s';
        } else {
          groupcallController.leaveCall(
              roomId: widget.groupId, userId: LocalStorage().getUserId());
          return 'Meeting time has ended 11';
        }
      } else {
        groupcallController.leaveCall(
            roomId: widget.groupId, userId: LocalStorage().getUserId());
        return 'Meeting time has ended 22';
      }
    } catch (e) {
      return 'Scheduled Meeting';
    }
  }
}
