import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import '../../Home/Controller/socket_controller.dart';
import 'group_call.dart';

// This controller manages network connectivity and handles reconnection logic for group calls.
class NetworkController extends GetxController {
  RxBool isInternetConnected = true.obs;
  RxBool isBottomSheetOpen = false.obs;
  late final SocketController socketController;

  @override
  void onInit() {
    super.onInit();
    socketController = Get.put(SocketController());
    Connectivity().onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet)) {
        if (!isInternetConnected.value) {
          isInternetConnected(true);
          if (isBottomSheetOpen.value) {
            isBottomSheetOpen(false);
          }

          socketController.reconnectSocket();
        }
      } else if (result.contains(ConnectivityResult.none)) {
        if (isInternetConnected.value) {
          isInternetConnected(false);

          if (!isBottomSheetOpen.value) {
            isBottomSheetOpen(true);
          }
        }
      }
    });
  }

// This method shows a bottom sheet when there is no internet connection.
  void _showNoInternetBottomSheet() {
    Get.bottomSheet(
      Builder(builder: (context) {
        final colors = context.appColors;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.networkErrorBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 40, color: colors.networkErrorIcon),
              const SizedBox(height: 10),
              Text(
                "No Internet Connection",
                style: TextStyle(
                  color: colors.networkErrorText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please check your internet connection.",
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
      isDismissible: false,
      enableDrag: false,
    );
  }

// This method shows a retry popup dialog when the connection fails.
  void showRetryPopup() {
    if (Get.isDialogOpen == true) {
      return;
    }

    Get.dialog(
      Builder(builder: (context) {
        final colors = context.appColors;
        return AlertDialog(
          backgroundColor: colors.cardBg,
          title: Text("Network Disconnected",
              style: TextStyle(color: colors.textPrimary)),
          content: Text("Failed to connect. Please try again.",
              style: TextStyle(color: colors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () async {
                Get.back(); // Close current dialog

                Get.dialog(
                  Builder(builder: (ctx) {
                    final c = ctx.appColors;
                    return AlertDialog(
                      backgroundColor: c.cardBg,
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text("Connecting...",
                              style: TextStyle(color: c.textPrimary)),
                        ],
                      ),
                    );
                  }),
                  barrierDismissible: false,
                );

                final callController = Get.put(GroupcallController());
                final isMainSocketConnected =
                    socketController.isConnected.value;

                if (isInternetConnected.value == true &&
                    isMainSocketConnected == true) {
                  try {
                    callController.reCallConnect();
                    await Future.delayed(
                        const Duration(seconds: 3)); // Wait for connection

                    if (callController.isCallActive.value) {
                      Get.back(); // Close loading dialog - success!
                      return;
                    }
                  } catch (e) {}
                }

                Get.back(); // Close loading dialog
                showRetryPopup(); // Show retry dialog again
              },
              child: Text("Retry", style: TextStyle(color: colors.textPrimary)),
            ),
          ],
        );
      }),
      barrierDismissible: false,
    );
  }
}
