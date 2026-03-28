import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Commons/app_colors.dart';
import '../Commons/app_theme_colors.dart';

class ProgressDialog {
  static final RxDouble progress = 0.0.obs;

  static void show(BuildContext context) {
    if (Get.isDialogOpen != true) {
      final colors = context.appColors;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: colors.cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Container(
              padding: const EdgeInsets.all(20),
              width: 300,
              height: 260,
              child: Obx(() {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.download_rounded,
                        size: 40, color: AppColors.primary),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress.value,
                        minHeight: 10,
                        backgroundColor: colors.progressBg,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Downloading...",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.progressText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${(progress.value * 100).toStringAsFixed(0)}%",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                );
              }),
            ),
          );
        },
      );
    }
  }

  static void updateProgress(int received, int total) {
    if (total != -1) {
      progress.value = received / total;
    }
  }

  static void resetProgress() {
    progress.value = 0.0;
  }

  static void hideLoader(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
