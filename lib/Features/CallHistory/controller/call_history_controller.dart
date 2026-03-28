// import 'dart:developer';
// import 'package:cu_app/Widgets/toast_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/call_history_model.dart';
import '../repo/call_history_repo.dart';

// This controller handles the logic for fetching and managing call history in the application.
class CallHistoryController extends GetxController {
  final CallHistoryRepo _callHistoryRepo = CallHistoryRepo();

  var isLoading = true.obs;
  final RxList<GroupCallHistoryList> callHistoryList =
      <GroupCallHistoryList>[].obs;
  RxBool isCallListLoading = false.obs;
  RxInt limit = 20.obs;
  RxString searchText = "".obs;

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {
    callHistoryList.clear();
    super.onClose();
  }

// This method fetches the call history from the repository and updates the state.
  Future<void> fetchCallHistory({bool isLoadingShow = true}) async {
    try {
      isLoading.value =
          isLoadingShow ? isCallListLoading(true) : isCallListLoading(false);
      final response = await _callHistoryRepo.getCallHistory(
          searchQuery: searchText.value, offset: 0, limit: limit.value);

      if (response.errorMessage != null) {
        isCallListLoading(false);
        return;
      }

      if (response.data?.success == true && response.data?.data != null) {
        callHistoryList.assignAll(response.data!.data!);
        isCallListLoading(false);
      } else {
        isCallListLoading(false);
      }
    } finally {
      isLoading.value = false;
      isCallListLoading(false);
    }
  }

// This method filters the call history based on the search query.
  Future<void> refreshCallHistory({bool isLoadingShow = true}) async {
    try {
      isLoading.value = isLoadingShow;
      await fetchCallHistory(isLoadingShow: isLoadingShow);
    } catch (e) {
      debugPrint("Error refreshing call history: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
