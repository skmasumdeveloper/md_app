import 'package:get/get.dart';

import '../../../Widgets/toast_widget.dart';
import '../Model/meetings_list_model.dart';

import '../../../Utils/storage_service.dart';
import '../Repository/meetings_repo.dart';
import 'meetings_list_controller.dart';

// This controller handles the logic for displaying meeting details, including fetching meeting information and checking user permissions.
class MeetingDetailsController extends GetxController {
  final _meetingsRepo = MeetingsRepo();
  Rx<MeetingModel?> meetingDetails = Rx<MeetingModel?>(null);
  RxBool isLoading = false.obs;
  RxBool isAllowForJoingMeeting = false.obs;
  final meetingListController = Get.put(MeetingsListController());

  // This method retrieves the details of a specific meeting by its ID and checks if the user is allowed to join.
  Future<void> getMeetingDetails(String meetingId,
      {bool isUserRemoved = false, bool isLoadingShow = true}) async {
    try {
      isLoadingShow ? isLoading(true) : isLoading(false);
      var res = await _meetingsRepo.getMeetingGroupDetails(
        groupId: meetingId,
      );

      if (res.data == null) {
        isAllowForJoingMeeting.value = false;
      }

      meetingDetails.value = res.data!;
      final currentUsers = res.data?.currentUsers ?? [];
      final isUserInMeeting = currentUsers.any((user) =>
          LocalStorage().getUserId().toString() == user.sId?.toString());

      isAllowForJoingMeeting.value = isUserInMeeting;
      if (!isUserInMeeting &&
          isUserRemoved &&
          meetingListController.openedMeetingId.value == meetingId) {
        Get.back();
      }
    } catch (e) {
      isAllowForJoingMeeting.value = false;
    } finally {
      isLoading(false);
    }
  }

  // Accept the meeting for current user and refresh meeting details
  Future<void> acceptMeeting(String meetingId) async {
    try {
      isLoading(true);
      final userId = LocalStorage().getUserId();
      final res = await _meetingsRepo.groupAction(
          groupId: meetingId, action: 'accept', userId: userId);
      if (res.data != null) {
        // Refresh meeting details to get updated participantActions
        await getMeetingDetails(meetingId, isLoadingShow: true);
        TostWidget()
            .successToast(title: 'Success', message: 'Meeting accepted');
      } else {
        TostWidget().errorToast(title: 'Error', message: res.errorMessage);
      }
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
    } finally {
      isLoading(false);
    }
  }

  // Decline the meeting with an optional reason and refresh meeting details
  Future<void> declineMeeting(String meetingId, {String reason = ''}) async {
    try {
      isLoading(true);
      final userId = LocalStorage().getUserId();
      final res = await _meetingsRepo.groupAction(
          groupId: meetingId,
          action: 'reject',
          userId: userId,
          actionDescription: reason);
      if (res.data != null) {
        await getMeetingDetails(meetingId, isLoadingShow: true);
        TostWidget()
            .successToast(title: 'Success', message: 'Meeting rejected');
      } else {
        TostWidget().errorToast(title: 'Error', message: res.errorMessage);
      }
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
    } finally {
      isLoading(false);
    }
  }
}
