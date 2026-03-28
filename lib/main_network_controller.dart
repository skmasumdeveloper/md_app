import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MainNetworkController extends GetxController {
  final String screenName;
  MainNetworkController({required this.screenName});

  RxBool isInternetConnected = true.obs;
  RxBool isBottomSheetOpen = false.obs;

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
        }
      } else if (result.contains(ConnectivityResult.none)) {
        if (isInternetConnected.value) {
          isInternetConnected(false);

          if (!isBottomSheetOpen.value) {
            isBottomSheetOpen(true);
            _showNoInternetBottomSheet();
          }
        }
      }
    });
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
