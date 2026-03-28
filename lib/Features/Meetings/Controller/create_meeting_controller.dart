import 'package:cu_app/Features/AddMembers/Model/members_model.dart';
import 'package:cu_app/Features/AddMembers/Repo/member_repo.dart';
import 'package:cu_app/Features/Meetings/Model/create_meeting_model.dart';
import 'package:cu_app/Features/Meetings/Repository/create_meeting_repo.dart';
import 'package:cu_app/Widgets/toast_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Home/Controller/socket_controller.dart';
import 'meetings_list_controller.dart';

// This controller handles the logic for creating a new meeting, including selecting members, setting date and time, and submitting the meeting details.
class CreateMeetingController extends GetxController {
  final _createMeetingRepo = CreateMeetingRepo();
  final _memberRepo = MemberlistRepo();

  // Form controllers
  final meetingTitleController = TextEditingController();
  final descriptionController = TextEditingController();

  // Date and time
  Rx<DateTime?> selectedStartDate = Rx<DateTime?>(null);
  Rx<TimeOfDay?> selectedStartTime = Rx<TimeOfDay?>(null);
  Rx<DateTime?> selectedEndDate = Rx<DateTime?>(null);
  Rx<TimeOfDay?> selectedEndTime = Rx<TimeOfDay?>(null);

  // Meeting duration
  RxInt selectedDurationMinutes = 15.obs; // Default 15 minutes
  final List<int> durationOptions = [15, 30, 45, 60, 75, 90, 105, 120];

  // Hour and minute options for time input
  final List<int> hourOptions = List.generate(12, (index) => index + 1); // 1-12
  final List<int> minuteOptions = [0, 15, 30, 45];
  final List<String> amPmOptions = ['AM', 'PM'];

  // Selected hour, minute, and AM/PM
  RxInt selectedHour = 1.obs;
  RxInt selectedMinute = 15.obs;
  RxString selectedAmPm = 'AM'.obs;

  // Member selection
  RxList<MemberListMdoel> memberList = <MemberListMdoel>[].obs;
  RxList<String> selectedMemberIds = <String>[].obs;
  RxList<MemberListMdoel> selectedMembers = <MemberListMdoel>[].obs;

  // Loading states
  RxBool isMemberListLoading = false.obs;
  RxBool isCreatingMeeting = false.obs;

  // Pagination
  RxInt page = 1.obs;
  RxBool hasMore = true.obs;

  // Search
  RxString searchText = "".obs;
  RxInt limit = 20.obs;

  // meetings controller
  final meetingsController = Get.put(MeetingsListController());

  @override
  void onInit() {
    super.onInit();
    getMemberList();
    _setDefaultDateTime();
  }

  // Set default start and end date/time
  void _setDefaultDateTime() {
    final now = DateTime.now();

    // Set today's date
    selectedStartDate.value = now;

    // Set start time to next 15 minutes in 12-hour format
    final nextMinutes = ((now.minute / 15).ceil() * 15) % 60;
    final hourAdjustment = (now.minute + 15) >= 60 ? 1 : 0;
    final next24Hour = (now.hour + hourAdjustment) % 24;

    // Convert to 12-hour format
    final next12Hour =
        next24Hour == 0 ? 12 : (next24Hour > 12 ? next24Hour - 12 : next24Hour);
    final nextAmPm = next24Hour >= 12 ? 'PM' : 'AM';

    selectedHour.value = next12Hour;
    selectedMinute.value = nextMinutes;
    selectedAmPm.value = nextAmPm;

    // Update the TimeOfDay based on selected hour, minute, and AM/PM
    selectedStartTime.value = _convertTo24HourTimeOfDay();

    // Auto-calculate end date/time based on default duration
    _calculateEndDateTime();
  }

  // Convert 12-hour format to 24-hour TimeOfDay
  TimeOfDay _convertTo24HourTimeOfDay() {
    int hour24 = selectedHour.value;

    if (selectedAmPm.value == 'AM' && selectedHour.value == 12) {
      hour24 = 0;
    } else if (selectedAmPm.value == 'PM' && selectedHour.value != 12) {
      hour24 = selectedHour.value + 12;
    }

    return TimeOfDay(hour: hour24, minute: selectedMinute.value);
  }

  // Calculate end date/time based on start date/time and selected duration
  void _calculateEndDateTime() {
    if (selectedStartDate.value != null && selectedStartTime.value != null) {
      final startDateTime = DateTime(
        selectedStartDate.value!.year,
        selectedStartDate.value!.month,
        selectedStartDate.value!.day,
        selectedStartTime.value!.hour,
        selectedStartTime.value!.minute,
      );

      final endDateTime =
          startDateTime.add(Duration(minutes: selectedDurationMinutes.value));

      selectedEndDate.value = endDateTime;
      selectedEndTime.value = TimeOfDay(
        hour: endDateTime.hour,
        minute: endDateTime.minute,
      );
    }
  }

  // Update duration and recalculate end time
  void updateDuration(int minutes) {
    selectedDurationMinutes.value = minutes;
    _calculateEndDateTime();
  }

  String get formattedDuration {
    final hours = selectedDurationMinutes.value ~/ 60;
    final minutes = selectedDurationMinutes.value % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  // Local time to UTC conversion
  String _convertToUTC(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }

  // Fetch member list from the repository
  Future<void> getMemberList({bool isLoadingShow = true}) async {
    try {
      if (isLoadingShow) isMemberListLoading(true);

      final currentPage = page.value;
      var res = await _memberRepo.getMemberList(
        searchQuery: searchText.value,
        page: currentPage,
        limit: limit.value,
      );

      if (res.data?.success == true) {
        final fetched = res.data?.memberList ?? [];
        if (currentPage == 1) {
          hasMore.value = fetched.length >= limit.value;
        } else if (fetched.isEmpty || fetched.length < limit.value) {
          hasMore(false);
        }
        if (currentPage == 1) {
          memberList.value = fetched;
        } else {
          if (fetched.isEmpty) {
            hasMore(false);
          } else {
            memberList.addAll(fetched);
            memberList.refresh();
          }
        }
      } else {
        if (currentPage == 1) memberList.value = [];
      }

      isMemberListLoading(false);
    } catch (e) {
      if (page.value == 1) memberList.value = [];
      isMemberListLoading(false);
    }
  }

  /// Load next page if available
  Future<void> loadMoreMembers() async {
    if (isMemberListLoading.value || !hasMore.value) return;
    page.value += 1;
    await getMemberList(isLoadingShow: true);
  }

  // Toggle member selection
  void toggleMemberSelection(MemberListMdoel member) {
    if (selectedMemberIds.contains(member.sId)) {
      selectedMemberIds.remove(member.sId);
      selectedMembers.remove(member);
    } else {
      selectedMemberIds.add(member.sId!);
      selectedMembers.add(member);
    }
  }

  bool isMemberSelected(String memberId) {
    return selectedMemberIds.contains(memberId);
  }

  // Update hour and recalculate start time
  void updateHour(int hour) {
    selectedHour.value = hour;
    _updateStartTime();
  }

  // Update minute and recalculate start time
  void updateMinute(int minute) {
    selectedMinute.value = minute;
    _updateStartTime();
  }

  // Update AM/PM and recalculate start time
  void updateAmPm(String amPm) {
    selectedAmPm.value = amPm;
    _updateStartTime();
  }

  // Update start time based on selected hour, minute, and AM/PM
  void _updateStartTime() {
    if (selectedStartDate.value != null) {
      selectedStartTime.value = _convertTo24HourTimeOfDay();
      _validateAndSetStartTime();
    }
  }

  // Validate selected time and recalculate end time
  void _validateAndSetStartTime() {
    if (selectedStartDate.value != null) {
      final now = DateTime.now();
      final timeOfDay = _convertTo24HourTimeOfDay();
      final selectedDateTime = DateTime(
        selectedStartDate.value!.year,
        selectedStartDate.value!.month,
        selectedStartDate.value!.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      // Check if selected datetime is in the past (if today)
      final isToday = selectedStartDate.value!.year == now.year &&
          selectedStartDate.value!.month == now.month &&
          selectedStartDate.value!.day == now.day;

      if (isToday && selectedDateTime.isBefore(now)) {
        TostWidget().errorToast(
          title: "Invalid Time",
          message: "You can't select a past time",
        );
        // Reset to next valid time
        final nextHour = (now.hour + 1) % 24;
        final next12Hour =
            nextHour == 0 ? 12 : (nextHour > 12 ? nextHour - 12 : nextHour);
        final nextAmPm = nextHour >= 12 ? 'PM' : 'AM';

        selectedHour.value = next12Hour;
        selectedMinute.value = 0;
        selectedAmPm.value = nextAmPm;
        selectedStartTime.value = _convertTo24HourTimeOfDay();
      }

      _calculateEndDateTime();
    }
  }

  // Select start date only
  Future<void> selectStartDate(BuildContext context) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: selectedStartDate.value ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date != null) {
      selectedStartDate.value = date;
      _validateAndSetStartTime();
    }
  }

  String get formattedStartDate {
    if (selectedStartDate.value == null) {
      return 'Select date';
    }

    final date = selectedStartDate.value!;
    return '${date.day}/${date.month}/${date.year}';
  }

  String get formattedSelectedTime {
    return '${selectedHour.value.toString().padLeft(2, '0')}:${selectedMinute.value.toString().padLeft(2, '0')} ${selectedAmPm.value}';
  }

  // Helper method to get next hour
  TimeOfDay _getNextHour() {
    final now = DateTime.now();
    final nextHour = now.hour + 1;
    return TimeOfDay(hour: nextHour % 24, minute: 0);
  }

  Future<void> selectStartDateTime(BuildContext context) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: selectedStartDate.value ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date != null) {
      selectedStartDate.value = date;

      final pickedTime = await showTimePicker(
        context: context,
        initialTime: selectedStartTime.value ?? _getNextHour(),
      );

      if (pickedTime != null) {
        // Round minutes to the nearest 1-minute interval
        int roundedMinute = (pickedTime.minute / 1).round() * 1;
        int roundedHour = pickedTime.hour;

        // Adjust hour if rounding pushes minute to 60
        if (roundedMinute == 60) {
          roundedMinute = 0;
          roundedHour = (roundedHour + 1) % 24;
        }

        final roundedTime = TimeOfDay(hour: roundedHour, minute: roundedMinute);

        // Check if selected datetime is in the past (if today)
        final isToday = date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;

        final selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          roundedTime.hour,
          roundedTime.minute,
        );

        if (isToday && selectedDateTime.isBefore(now)) {
          TostWidget().errorToast(
            title: "Invalid Time",
            message: "You can't select a past time",
          );
          return;
        }

        // Valid time
        selectedStartTime.value = roundedTime;

        // Auto-calculate end time based on duration
        _calculateEndDateTime();
      }
    }
  }

  String get formattedStartDateTime {
    if (selectedStartDate.value == null || selectedStartTime.value == null) {
      return 'Select start date & time';
    }

    final date = selectedStartDate.value!;
    final time = selectedStartTime.value!;
    final dateTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${time.format(Get.context!)}';
  }

  bool get isFormValid {
    return meetingTitleController.text.isNotEmpty &&
        selectedStartDate.value != null &&
        selectedStartTime.value != null;
  }

  // Check if meeting start time is in the past
  bool get isMeetingStartTimeValid {
    if (selectedStartDate.value == null || selectedStartTime.value == null) {
      return false;
    }

    final now = DateTime.now();
    final meetingStartDateTime = DateTime(
      selectedStartDate.value!.year,
      selectedStartDate.value!.month,
      selectedStartDate.value!.day,
      selectedStartTime.value!.hour,
      selectedStartTime.value!.minute,
    );

    return meetingStartDateTime.isAfter(now);
  }

  // Validate form and meeting time before proceeding
  bool validateFormAndTime() {
    if (!isFormValid) {
      TostWidget().errorToast(
        title: "Error",
        message: "Please fill all required fields",
      );
      return false;
    }

    if (!isMeetingStartTimeValid) {
      TostWidget().errorToast(
        title: "Invalid Meeting Time",
        message:
            "Meeting start time cannot be in the past. Please select a future time.",
      );
      return false;
    }

    return true;
  }

  // Create a new meeting
  Future<void> createMeeting(BuildContext context) async {
    final socketController = Get.find<SocketController>();
    if (!isFormValid) {
      TostWidget().errorToast(
        title: "Error",
        message: "Please fill all required fields",
      );
      return;
    }

    if (selectedMemberIds.isEmpty) {
      TostWidget().errorToast(
        title: "Error",
        message: "Please select at least one participant",
      );
      return;
    }

    try {
      isCreatingMeeting(true);

      final startDateTime = DateTime(
        selectedStartDate.value!.year,
        selectedStartDate.value!.month,
        selectedStartDate.value!.day,
        selectedStartTime.value!.hour,
        selectedStartTime.value!.minute,
      );

      final endDateTime =
          startDateTime.add(Duration(minutes: selectedDurationMinutes.value));

      final request = CreateMeetingRequest(
        groupName: meetingTitleController.text,
        groupDescription: descriptionController.text.isEmpty
            ? null
            : descriptionController.text,
        meetingStartTime: _convertToUTC(startDateTime),
        meetingEndTime: _convertToUTC(endDateTime),
        createdByTimeZone: DateTime.now().timeZoneName,
        users: selectedMemberIds,
        isTemp: true,
      );

      final response =
          await _createMeetingRepo.createScheduledMeeting(request: request);

      if (response.data?.success == true) {
        await meetingsController.getMeetingsList();
        TostWidget().successToast(
          title: "Success",
          message: "Meeting created successfully",
        );

        Map<String, dynamic> reqModeSocket = {
          "currentUsers": response.data!.data!.currentUsers,
          "_id": response.data!.data!.id
        };

        socketController.socket!.emit("meeting_created", reqModeSocket);
        socketController.socket!.emit("creategroup", reqModeSocket);
        getMemberList(isLoadingShow: false);
        // Clear form
        clearForm();

        // Navigate back
        Navigator.of(context).pop();
        Navigator.of(context).pop();
        meetingsController.getMeetingsList();
      } else {
        TostWidget().errorToast(
          title: "Error",
          message: response.data?.message ?? "Failed to create meeting",
        );
      }

      isCreatingMeeting(false);
    } catch (e) {
      isCreatingMeeting(false);
      TostWidget().errorToast(
        title: "Error",
        message: "Failed to create meeting: $e",
      );
    }
  }

  // Clear form fields
  void clearForm() {
    meetingTitleController.clear();
    descriptionController.clear();
    selectedStartDate.value = null;
    selectedStartTime.value = null;
    selectedEndDate.value = null;
    selectedEndTime.value = null;
    selectedMemberIds.clear();
    selectedMembers.clear();
    searchText.value = "";
    selectedDurationMinutes.value = 15; // Reset to default
    selectedHour.value = 1;
    selectedMinute.value = 15;
    selectedAmPm.value = 'AM';
  }

  @override
  void onClose() {
    meetingTitleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}
