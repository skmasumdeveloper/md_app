import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Widgets/toast_widget.dart';
import '../../Home/Controller/socket_controller.dart';
import '../Model/meetings_list_model.dart';
import '../Repository/edit_meeting_repo.dart';
import '../Repository/meetings_repo.dart';
import 'meeting_details_controller.dart';
import 'meetings_list_controller.dart';

class EditMeetingController extends GetxController {
  // Define your controller properties and methods here
  // edit groupName, groupDes, meetingStartTime, meetingEndTime
  final _editMeetingRepo = EditMeetingRepo();
  final _meetingsRepo = MeetingsRepo();
  Rx<MeetingModel?> meetingDetails = Rx<MeetingModel?>(null);
  RxBool isLoading = false.obs;

  final meetingDetailsController = Get.put(MeetingDetailsController());
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

  // Loading states
  RxBool isMemberListLoading = false.obs;
  RxBool isCreatingMeeting = false.obs;

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

  // This method retrieves the details of a specific meeting by its ID and checks if the user is allowed to join.
  Future<void> getMeetingDetails(String meetingId) async {
    try {
      isLoading(true);
      var res = await _meetingsRepo.getMeetingGroupDetails(
        groupId: meetingId,
      );
      meetingDetails.value = res.data!;

      // set the form fields with existing meeting details
      meetingTitleController.text = meetingDetails.value!.groupName ?? '';
      descriptionController.text = meetingDetails.value!.groupDescription ?? '';

      // set the date and time from the meeting details response example from UTC to local time
      // Meeting UTC Start Time: 2025-08-08T10:15:00.000Z
      // Meeting UTC End Time: 2025-08-08T10:30:00.000Z
      if (meetingDetails.value!.meetingStartTime != null) {
        final startDateTime =
            DateTime.parse(meetingDetails.value!.meetingStartTime!).toLocal();
        selectedStartDate.value = startDateTime;
        selectedStartTime.value = TimeOfDay(
          hour: startDateTime.hour,
          minute: startDateTime.minute,
        );
      }

      if (meetingDetails.value!.meetingEndTime != null) {
        final endDateTime =
            DateTime.parse(meetingDetails.value!.meetingEndTime!).toLocal();
        selectedEndDate.value = endDateTime;
        selectedEndTime.value = TimeOfDay(
          hour: endDateTime.hour,
          minute: endDateTime.minute,
        );
      }

      // now update // Selected hour, minute, and AM/PM
      if (selectedStartTime.value != null) {
        selectedHour.value = selectedStartTime.value!.hour % 12;
        selectedMinute.value = selectedStartTime.value!.minute;
        selectedAmPm.value = selectedStartTime.value!.hour >= 12 ? 'PM' : 'AM';
      }

      // update selectedDurationMinutes to the difference between start and end time in minutes
      if (selectedStartDate.value != null && selectedEndDate.value != null) {
        final startDateTime = DateTime(
          selectedStartDate.value!.year,
          selectedStartDate.value!.month,
          selectedStartDate.value!.day,
          selectedStartTime.value!.hour,
          selectedStartTime.value!.minute,
        );
        final endDateTime = DateTime(
          selectedEndDate.value!.year,
          selectedEndDate.value!.month,
          selectedEndDate.value!.day,
          selectedEndTime.value!.hour,
          selectedEndTime.value!.minute,
        );
        selectedDurationMinutes.value =
            endDateTime.difference(startDateTime).inMinutes;
      } else {
        selectedDurationMinutes.value = 15; // Default to 15 minutes if not set
      }
    } catch (e) {
    } finally {
      isLoading(false);
    }
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

  // Helper method to get hour after next hour
  TimeOfDay _getHourAfterNext() {
    final now = DateTime.now();
    final nextNextHour = now.hour + 2;
    return TimeOfDay(hour: nextNextHour % 24, minute: 0);
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

  // UTC to local time conversion
  String convertToLocalTime(String utcTime) {
    final dateTime = DateTime.parse(utcTime);
    final localDateTime = dateTime.toLocal();
    return localDateTime.toIso8601String();
  }

  // This method edits an existing meeting by sending a request to the API with the updated meeting details.

  RxBool isUpdateLoading = false.obs;
  // This method updates the group details, including name, description, and image.
  updateGroup({required BuildContext context}) async {
    try {
      final socketController = Get.find<SocketController>();
      isUpdateLoading(true);

      final startDateTime = DateTime(
        selectedStartDate.value!.year,
        selectedStartDate.value!.month,
        selectedStartDate.value!.day,
        selectedStartTime.value!.hour,
        selectedStartTime.value!.minute,
      );

      final endDateTime =
          startDateTime.add(Duration(minutes: selectedDurationMinutes.value));

      var res = await _editMeetingRepo.editScheduledMeeting(
        groupDes: descriptionController.text,
        groupId: meetingDetails.value!.sId!,
        groupName: meetingTitleController.text,
        meetingStartTime: _convertToUTC(startDateTime),
        meetingEndTime: _convertToUTC(endDateTime),
      );
      if (res.data!['success'] == true) {
        final meetingsListController = Get.put(MeetingsListController());
        Map<String, dynamic> reqModeSocket = {"data": res.data!['data']};
        socketController.socket!.emit("update-group", reqModeSocket);
        await meetingsListController.getMeetingsList(isLoadingShow: false);
        await meetingDetailsController.getMeetingDetails(
          meetingDetails.value!.sId!,
        );
        // getMeetingDetails(
        //   meetingDetails.value!.sId!,
        // );
        TostWidget()
            .successToast(title: "Success", message: res.data!['message']);
        isUpdateLoading(false);
        meetingDetails.refresh();
        Navigator.pop(context);
      } else {
        TostWidget()
            .errorToast(title: "Error", message: res.data!['error']['message']);
        isUpdateLoading(false);
      }
    } catch (e) {
      isUpdateLoading(false);
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
