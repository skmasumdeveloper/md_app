import 'dart:io';

import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Commons/app_theme_colors.dart';
import '../../../Widgets/custom_video_player.dart';
import '../../../Widgets/full_button.dart';

// This function displays a bottom sheet for video confirmation, allowing users to preview and send a video.
void videoBottomSheet(
  BuildContext context,
  File video,
  Future<void> Function() onUploadComplete,
) {
  final chatController = Get.put(ChatController());

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
    ),
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final colors = context.appColors;
          return Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20.0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  'Video Preview',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: CustomVideoPlayer(
                    file: chatController.videoFile.value ?? File(""),
                  ),
                ),
                const SizedBox(height: 10),
                Obx(() => chatController.isSendSmsLoading.value
                    ? const Center(
                        child: CircularProgressIndicator.adaptive(),
                      )
                    : FullButton(
                        label: 'Send Video',
                        onPressed: () async {
                          await onUploadComplete();
                          Navigator.pop(context);
                        })),
              ],
            ),
          );
        },
      );
    },
  );
}
