import 'package:cu_app/Commons/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TostWidget {
  errorToast({String? title, String? message}) {
    return Get.snackbar(title ?? "Invalid!", message ?? "",
        backgroundColor: AppColors.orange,
        colorText: AppColors.white,
        snackPosition: SnackPosition.TOP,
        forwardAnimationCurve: Curves.easeInOutBack,
        dismissDirection: DismissDirection.up,
        shouldIconPulse: true,
        overlayBlur: 1,
        icon: const Icon(
          Icons.error,
          color: AppColors.white,
        ),
        margin: const EdgeInsets.only(left: 40, right: 40, bottom: 20));
  }

  successToast({String? title, String? message}) {
    return Get.snackbar(title ?? "Success", message ?? "",
        backgroundColor: AppColors.green,
        colorText: AppColors.white,
        snackPosition: SnackPosition.TOP,
        icon: const Icon(
          Icons.done,
          color: AppColors.white,
        ),
        forwardAnimationCurve: Curves.easeInOutBack,
        margin: const EdgeInsets.only(left: 40, right: 40, bottom: 20));
  }
}
