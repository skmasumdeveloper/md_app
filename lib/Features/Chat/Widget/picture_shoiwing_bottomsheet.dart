import 'dart:io';

import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Commons/app_theme_colors.dart';
import '../../../Widgets/custom_video_player.dart';
import '../../../Widgets/full_button.dart';

// This function displays a bottom sheet for media preview, allowing users to view and send selected media files.
void pictureBottomSheet(
  BuildContext context,
  List<File> mediaFiles,
  Future<void> Function() onUploadComplete,
) {
  final PageController pageController = PageController();
  final chatController = Get.put(ChatController());
  ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(0);

  // Helper function to check if file is video
  bool isVideoFile(File file) {
    String extension = file.path.split(".").last.toLowerCase();
    return ["mp4", "mov", "avi", "mkv", "webm", "3gp"].contains(extension);
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
    ),
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final colors = context.appColors;
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20.0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Media Preview',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (mediaFiles.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No media selected',
                        style:
                            TextStyle(fontSize: 16, color: colors.textTertiary),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: currentIndexNotifier,
                      builder: (context, currentIndex, child) {
                        return PageView.builder(
                          controller: pageController,
                          onPageChanged: (index) {
                            currentIndexNotifier.value = index;
                          },
                          itemCount: mediaFiles.length,
                          itemBuilder: (context, index) {
                            if (index >= mediaFiles.length) return Container();

                            final file = mediaFiles[index];
                            if (isVideoFile(file)) {
                              return Container(
                                margin: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  border: Border.all(color: colors.borderColor),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color:
                                            colors.textPrimary.withOpacity(0.6),
                                        //  shape: BoxShape.circle,
                                      ),
                                      child: CustomVideoPlayer(file: file),
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: colors.textPrimary
                                              .withOpacity(0.8),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'VIDEO',
                                          style: TextStyle(
                                            color: colors.textOnPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return Container(
                                margin: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  border: Border.all(color: colors.borderColor),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    file,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: colors.surfaceBg,
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 50,
                                          color: colors.iconSecondary,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                if (mediaFiles.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 60,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ValueListenableBuilder<int>(
                        valueListenable: currentIndexNotifier,
                        builder: (context, currentIndex, child) {
                          return Row(
                            children: List.generate(mediaFiles.length, (index) {
                              final file = mediaFiles[index];
                              return Stack(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      currentIndexNotifier.value = index;
                                      pageController.animateToPage(
                                        index,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: currentIndex == index
                                              ? Colors.blue
                                              : colors.borderColor,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      height: 50,
                                      width: 50,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: isVideoFile(file)
                                            ? Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Container(
                                                    color: colors.textPrimary
                                                        .withOpacity(0.1),
                                                    child: Icon(
                                                      Icons.videocam,
                                                      color:
                                                          colors.iconSecondary,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: 2,
                                                    right: 2,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              2),
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.play_arrow,
                                                        color: colors
                                                            .textOnPrimary,
                                                        size: 10,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Image.file(
                                                file,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    color: colors.surfaceBg,
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      size: 20,
                                                      color:
                                                          colors.iconSecondary,
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          mediaFiles.removeAt(index);
                                          // Update current index after removal
                                          if (mediaFiles.isEmpty) {
                                            currentIndexNotifier.value = 0;
                                          } else if (currentIndexNotifier
                                                  .value >=
                                              mediaFiles.length) {
                                            currentIndexNotifier.value =
                                                mediaFiles.length - 1;
                                            pageController.animateToPage(
                                              currentIndexNotifier.value,
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: colors.textOnPrimary,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Obx(() => chatController.isSendSmsLoading.value
                    ? const Center(
                        child: CircularProgressIndicator.adaptive(),
                      )
                    : FullButton(
                        label: mediaFiles.isEmpty
                            ? 'No Media Selected'
                            : 'Send Media (${mediaFiles.length})',
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
