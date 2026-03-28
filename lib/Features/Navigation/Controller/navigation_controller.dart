import 'package:get/get.dart';

import '../../../Commons/app_strings.dart';
import '../../Login/Controller/login_controller.dart';
import '../../Meetings/Controller/meetings_list_controller.dart';

// This controller manages the navigation state of the application, including the selected tab index and unread meetings count.
class NavigationController extends GetxController {
  RxInt selectedIndex = 0.obs;
  RxBool meetingsUnread = false.obs;
  RxInt meetingsCount = 0.obs;
  final userController = Get.put(LoginController());
  final meetingListController = Get.put(MeetingsListController());

  @override
  void onInit() {
    super.onInit();
    checkMeetingsList();
  }

  // This method checks the meetings list and updates the unread count based on the current meetings.
  void checkMeetingsList() {
    meetingListController.getMeetingsList(isLoadingShow: false);
    // Listen for changes in meetings list to update unread count
    meetingListController.meetingsList.listen((list) {
      meetingsCount.value = list.length;
      meetingsUnread.value = list.any((meeting) {
        if (meeting.isTemp == true) {
          DateTime endTime = DateTime.parse(meeting.meetingEndTime!);
          return endTime.isAfter(DateTime.now());
        }
        return false;
      });
    });
  }

// This method checks if the user is an admin or super admin based on their user type.
  bool get isUserAdminOrSuperAdmin {
    return userController.userModel.value.userType != null &&
        userController.userModel.value.userType!.isNotEmpty &&
        (userController.userModel.value.userType!.contains(AdminCheck.admin) ||
            userController.userModel.value.userType!
                .contains(AdminCheck.superAdmin));
  }

// This method changes the selected tab index.
  void changeTabIndex(int index) {
    selectedIndex.value = index;
    if (index == (isUserAdminOrSuperAdmin ? 3 : 2)) {
      // Reset meetings unread count when navigating to Meetings tab
      meetingsUnread.value = false;
    }
  }
}
