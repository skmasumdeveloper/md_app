part of 'group_call.dart';

extension GroupCallMeetingExtension on GroupcallController {
  // This method starts a timer to handle meeting end logic.
  void startMeetingEndTimer(String groupId) {
    _meetingEndTimer?.cancel();

    if (groupModel.value.isTemp == true &&
        groupModel.value.meetingEndTime != null &&
        groupModel.value.meetingEndTime!.isNotEmpty) {
      try {
        final endTime = DateTime.parse(groupModel.value.meetingEndTime!);
        final now = DateTime.now();

        if (endTime.isAfter(now)) {
          final timeUntilEnd = endTime.difference(now);

          _meetingEndTimer = Timer(timeUntilEnd, () {
            _handleMeetingEnd(groupId);
          });
        } else {
          _handleMeetingEnd(groupId);
        }
      } catch (e) {}
    }
  }

  // This method handles the meeting end logic.
  void _handleMeetingEnd(String groupId) async {
    if (currentRoomId.value == groupId &&
        isCallActive.value &&
        !isMeetingEnded.value) {
      isMeetingEnded.value = true;

      await leaveCall(
        roomId: groupId,
        userId: LocalStorage().getUserId(),
      );

      Get.dialog(
        AlertDialog(
          title: const Text(
            'Meeting Ended',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: const Text(
            'The meeting time has ended.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Get.back();
                Get.back();
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    }
  }

  // This method stops the meeting end timer.
  void stopMeetingEndTimer() {
    _meetingEndTimer?.cancel();
    _meetingEndTimer = null;
    isMeetingEnded.value = false;
  }
}
