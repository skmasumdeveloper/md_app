import 'package:cu_app/Features/Meetings/Model/meetings_list_model.dart';
import 'package:cu_app/Features/Meetings/Repository/meetings_repo.dart';
import 'package:cu_app/Features/Meetings/Model/meeting_call_details_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../../../Widgets/toast_widget.dart';
import '../../Home/Controller/socket_controller.dart';

// This controller manages the list of meetings, including fetching, searching, and deleting meetings, as well as handling meeting call details.
class MeetingsListController extends GetxController {
  final _meetingsRepo = MeetingsRepo();
  RxList<MeetingModel> meetingsList = <MeetingModel>[].obs;
  RxBool isMeetingsListLoading = false.obs;
  RxBool isCallDetailsLoaded = false.obs;
  RxInt limit = 10.obs;
  RxString searchText = "".obs;
  RxInt selectedTabIndex = 0.obs;
  RxBool isMeRemovedFromMeeting = false.obs;
  RxString openedMeetingId = "".obs;

  Timer? _refreshTimer;
  List<Timer> _meetingTimers = [];
  bool _isDisposed = false; // Add disposal flag

  Rx<MeetingGroupCallDetails?> meetingCallDetails =
      Rx<MeetingGroupCallDetails?>(null);
  RxBool isCallDetailsLoading = false.obs;

  // This method initializes the controller and fetches the meetings list.
  Future<void> getMeetingsList({bool isLoadingShow = true}) async {
    try {
      isLoadingShow
          ? isMeetingsListLoading(true)
          : isMeetingsListLoading(false);
      var res = await _meetingsRepo.getMeetingsList(
          searchQuery: searchText.value, offset: 0, limit: limit.value);
      RxList<MeetingModel> listData = <MeetingModel>[].obs;

      if (res.data!.success == true) {
        listData.value = res.data!.meetingModel!;

        if (selectedTabIndex.value == 0) {
          listData = listData
              .where((meeting) {
                if (meeting.meetingEndTime != null) {
                  DateTime endTime = DateTime.parse(meeting.meetingEndTime!);
                  return endTime.isAfter(DateTime.now());
                }
                return false;
              })
              .toList()
              .obs;
        } else if (selectedTabIndex.value == 1) {
          listData = listData
              .where((meeting) {
                if (meeting.meetingEndTime != null) {
                  DateTime endTime = DateTime.parse(meeting.meetingEndTime!);
                  return endTime.isBefore(DateTime.now());
                }
                return false;
              })
              .toList()
              .obs;
        }

        meetingsList.clear();
        meetingsList.addAll(listData);
        isMeetingsListLoading(false);
      } else {
        meetingsList.value = [];
        isMeetingsListLoading(false);
      }
    } catch (e) {
      isMeetingsListLoading(false);
    }
  }

  // This method handles the search functionality for meetings.
  void searchMeetings(String query) {
    searchText.value = query;
    getMeetingsList(isLoadingShow: true);
  }

  // This method get the meeting call details by its ID.
  Future<void> getMeetingCallDetails(String meetingId,
      {bool isRefresh = true}) async {
    try {
      isRefresh ? isCallDetailsLoading(true) : null;
      var res = await _meetingsRepo.getMeetingCallDetails(id: meetingId);
      if (res.data?.success == true) {
        if (openedMeetingId.value == meetingId) {
          meetingCallDetails.value = res.data;
        } else {
          meetingCallDetails.value = null;
        }
      } else {
        meetingCallDetails.value = null;
      }
    } catch (e) {
      meetingCallDetails.value = null;
    } finally {
      isCallDetailsLoading(false);
    }
  }

  // This method refreshes the meetings list and schedules the next refresh.
  void refreshMeetingsList() {
    if (_isDisposed) return; // Early return if disposed

    meetingsList.refresh();
    _scheduleNextRefresh();
  }

  // This method schedules the next refresh of the meetings list based on the meeting times.
  void _scheduleNextRefresh() {
    if (_isDisposed) return;

    _cancelAllTimers();

    final now = DateTime.now();
    List<DateTime> refreshTimes = [];

    for (var meeting in meetingsList) {
      if (meeting.meetingStartTime != null) {
        try {
          final startTime = DateTime.parse(meeting.meetingStartTime!);

          final beforeStart = startTime.subtract(const Duration(seconds: 10));
          if (beforeStart.isAfter(now)) {
            refreshTimes.add(beforeStart);
          }

          if (startTime.isAfter(now)) {
            refreshTimes.add(startTime);
          }

          final afterStart = startTime.add(const Duration(seconds: 10));
          if (afterStart.isAfter(now)) {
            refreshTimes.add(afterStart);
          }

          if (meeting.meetingEndTime != null) {
            final endTime = DateTime.parse(meeting.meetingEndTime!);
            if (endTime.isAfter(now)) {
              refreshTimes.add(endTime);
            }
          }
        } catch (e) {
          debugPrint("Error parsing meeting time: $e");
        }
      }
    }

    refreshTimes = refreshTimes.toSet().toList()..sort();

    for (var refreshTime in refreshTimes) {
      if (_isDisposed) break; // Check disposal state

      final delay = refreshTime.difference(now);
      if (delay.isNegative) continue;

      final timer = Timer(delay, () {
        if (!_isDisposed) {
          refreshMeetingsList();
        }
      });
      _meetingTimers.add(timer);
    }

    if (!_isDisposed) {
      _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        refreshMeetingsList();
      });
    }
  }

// This method cancels all timers to prevent memory leaks.
  void _cancelAllTimers() {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    for (var timer in List.from(_meetingTimers)) {
      timer.cancel();
    }
    _meetingTimers.clear();
  }

  RxBool isDeleteLoading = false.obs;

  // This method deletes a meeting by its ID and updates the meetings list.
  Future<void> deleteMeeting(String meetingId) async {
    isDeleteLoading(true);
    final socketController = Get.put(SocketController(), permanent: true);
    try {
      final res = await _meetingsRepo.deleteMeeting(id: meetingId);
      if (res.data!['success'] == true) {
        socketController.socket!
            .emit("deleteGroup", res.data!['data']['deleteGroupResult']);
        meetingsList.removeWhere((meeting) => meeting.sId == meetingId);
        isDeleteLoading(false);

        Get.back();
        Get.back();
        TostWidget().successToast(
            title: "Success", message: "Meeting deleted successfully");
      } else {}
    } catch (e) {
    } finally {
      isDeleteLoading(false);
    }
  }

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {
    _isDisposed = true; // Set disposal flag first
    _cancelAllTimers(); // Then cancel all timers
    isCallDetailsLoaded.value = false;
    meetingCallDetails.value = null;
    selectedTabIndex.value = 0;
    searchText.value = "";

    super.onClose();
  }
}
