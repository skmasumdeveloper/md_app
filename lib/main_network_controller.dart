import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Features/Group_Call_New/controller/group_call_new_controller.dart';
import 'package:cu_app/Features/Home/Controller/group_list_controller.dart';
import 'package:cu_app/Features/Home/Controller/socket_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MainNetworkController extends GetxController {
  final String screenName;
  MainNetworkController({required this.screenName});

  RxBool isInternetConnected = true.obs;
  RxBool isBottomSheetOpen = false.obs;

  /// Check if a new group call is active — call screen handles its own network.
  bool get _isNewCallScreenActive {
    try {
      if (Get.isRegistered<GroupCallNewController>()) {
        final c = Get.find<GroupCallNewController>();
        if (c.isCallActive.value || c.isAnyCallActive.value) return true;
      }
      if (Get.currentRoute.contains('GroupCallNewScreen')) return true;
    } catch (_) {}
    return false;
  }

  @override
  void onInit() {
    super.onInit();

    Connectivity().onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet)) {
        if (!isInternetConnected.value) {
          isInternetConnected(true);
          if (isBottomSheetOpen.value) {
            if (Get.isBottomSheetOpen == true) {
              Get.back();
            }
            isBottomSheetOpen(false);
          }
          // Refresh app data when internet comes back
          _refreshOnReconnect();
        }
      } else if (result.contains(ConnectivityResult.none)) {
        if (isInternetConnected.value) {
          isInternetConnected(false);

          // Don't show "No Internet" bottom sheet during a call —
          // the call module handles its own network-based call ending.
          if (_isNewCallScreenActive) return;

          if (!isBottomSheetOpen.value) {
            isBottomSheetOpen(true);
            _showNoInternetBottomSheet();
          }
        }
      }
    });
  }

  /// Refresh groups, chats, socket, and active call state when internet comes back.
  void _refreshOnReconnect() {
    debugPrint('[NetworkController] Internet reconnected — refreshing app data');

    // Reconnect socket
    try {
      if (Get.isRegistered<SocketController>()) {
        Get.find<SocketController>().reconnectSocket();
      }
    } catch (_) {}

    // Refresh group list
    try {
      if (Get.isRegistered<GroupListController>()) {
        Get.find<GroupListController>().getGroupList(isLoadingShow: false);
      }
    } catch (_) {}

    // Refresh chat messages and check active call if on chat screen
    try {
      if (Get.isRegistered<ChatController>()) {
        final chatCtrl = Get.find<ChatController>();
        if (chatCtrl.isChatScreen.value && chatCtrl.groupId.value.isNotEmpty) {
          chatCtrl.getAllChatByGroupId(
            groupId: chatCtrl.groupId.value,
            isShowLoading: false,
          );
          chatCtrl.checkActiveCall(
            chatCtrl.groupId.value,
            isShowLoading: false,
          );
        }
      }
    } catch (_) {}
  }

  void _showNoInternetBottomSheet() {
    final isDark = Get.isDarkMode;
    Get.bottomSheet(
      WillPopScope(
        onWillPop: () async => false,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF4A1C1C) : Colors.red.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off,
                  size: 40,
                  color: isDark
                      ? const Color(0xFFEF9A9A)
                      : Colors.red.shade800),
              const SizedBox(height: 10),
              Text(
                "No Internet Connection",
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFEF9A9A)
                      : Colors.red.shade800,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please check your internet connection.",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFFBDBDBD) : null,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      isDismissible: false,
      enableDrag: false,
    ).whenComplete(() {
      isBottomSheetOpen(false);
    });
  }
}
