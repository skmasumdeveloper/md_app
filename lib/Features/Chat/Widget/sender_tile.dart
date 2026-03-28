import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/commons.dart';
import '../../../Commons/app_theme_colors.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Features/Chat/Model/chat_list_model.dart';
import 'package:cu_app/Features/Chat/Widget/sender_reply_widget.dart';
import 'package:cu_app/Utils/generate_thumbnail.dart';
import 'package:cu_app/Widgets/video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:get/get.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../Utils/check_emojii.dart';
import '../../../Utils/check_website.dart';
import '../../../Utils/downloader_file.dart';
import '../../../Utils/progress_dialog.dart';
import 'show_image_widget.dart';

// This widget represents a chat message tile for the sender, displaying the message content, time sent, and delivery status. It also supports swiping actions for replying or deleting messages.
class SenderTile extends StatefulWidget {
  final String message;
  final String messageType;
  final String sentTime;
  final String groupCreatedBy;
  final String read;
  final VoidCallback? onTap;
  late RxBool isSeen = false.obs;
  late RxBool isDelivered = false.obs;
  final String? fileName;
  final void Function(DragUpdateDetails d)? onLeftSwipe;
  final ReplyOf? replyOf;
  final int index;
  final RxBool isHighlighted;

  SenderTile({
    super.key,
    required this.message,
    required this.messageType,
    this.fileName,
    required this.sentTime,
    required this.groupCreatedBy,
    required this.read,
    required this.index,
    required this.isSeen,
    required this.isDelivered,
    this.onTap,
    this.onLeftSwipe,
    this.replyOf,
    RxBool? isHighlighted,
  }) : isHighlighted = isHighlighted ?? false.obs; // Initialize if null

  @override
  State<SenderTile> createState() => _SenderTileState();
}

class _SenderTileState extends State<SenderTile> {
  final chatController = Get.put(ChatController());
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(
          right: AppSizes.kDefaultPadding, top: AppSizes.kDefaultPadding),
      child: SwipeTo(
        onLeftSwipe: widget.onLeftSwipe,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.sentTime,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(fontSize: 12),
                  ),
                  const SizedBox(
                    width: AppSizes.kDefaultPadding / 2,
                  ),
                  Obx(() => widget.isDelivered.value == true
                      ? Icon(
                          Icons.done_all_rounded,
                          size: 16,
                          color: widget.isSeen.value == true
                              ? AppColors.primary
                              : colors.iconSecondary,
                        )
                      : Icon(
                          Icons.check,
                          size: 16,
                          color: colors.iconSecondary,
                        ))
                ],
              ),
            ),
            widget.replyOf != null
                ? SenderMsgReplyWidget(
                    replyOfmsgId: widget.replyOf?.msgId ?? "",
                    replyMsg: widget.replyOf?.msg ?? "",
                    senderName: widget.replyOf?.sender ?? "",
                    messageType: widget.replyOf?.msgType ?? "",
                  )
                : const SizedBox(),
            Obx(
              () => ChatBubble(
                clipper: ChatBubbleClipper3(type: BubbleType.sendBubble),
                backGroundColor: widget.isHighlighted.value
                    ? AppColors.receiverChatBubble
                    : AppColors.primary,
                alignment: Alignment.topRight,
                elevation: 0,
                margin:
                    const EdgeInsets.only(top: AppSizes.kDefaultPadding / 4),
                child: Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65),
                    child: widget.messageType == 'image'
                        ? GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ShowImage(imageUrl: widget.message)));
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  AppSizes.cardCornerRadius),
                              child: CachedNetworkImage(
                                imageUrl: widget.message,
                                height: 200,
                                width: 250,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                    child:
                                        CircularProgressIndicator.adaptive()),
                                errorWidget: (context, url, error) =>
                                    const Center(
                                        child: CircularProgressIndicator
                                            .adaptive()),
                              ),
                            ),
                          )
                        : widget.messageType == 'text'
                            ? CheckWebsite().isWebsite(widget.message) ||
                                    widget.message.contains("@")
                                ? Linkify(
                                    onOpen: (link) async {
                                      if (!await launchUrl(
                                          Uri.parse(link.url))) {
                                        throw Exception(
                                            'Could not launch ${link.url}');
                                      }
                                    },
                                    text: widget.message,
                                    options:
                                        const LinkifyOptions(humanize: false),
                                    linkStyle: TextStyle(
                                      color: colors.textOnPrimary,
                                      decoration: TextDecoration.underline,
                                    ),
                                    style: TextStyle(
                                      color: colors.textOnPrimary,
                                      fontSize:
                                          isOnlyEmoji(widget.message) ? 40 : 15,
                                    ),
                                  )
                                : Linkify(
                                    onOpen: (link) async {
                                      if (!await launchUrl(
                                          Uri.parse(link.url))) {
                                        throw Exception(
                                            'Could not launch ${link.url}');
                                      }
                                    },
                                    text: widget.message,
                                    options:
                                        const LinkifyOptions(humanize: false),
                                    linkStyle: TextStyle(
                                      color: colors.textOnPrimary,
                                      decoration: TextDecoration.underline,
                                    ),
                                    style: TextStyle(
                                      color: colors.textOnPrimary,
                                      fontSize:
                                          isOnlyEmoji(widget.message) ? 40 : 15,
                                    ),
                                  )
                            // : Text(widget.message,
                            //     style: TextStyle(
                            //         color: AppColors.white,
                            //         fontSize: isOnlyEmoji(widget.message)
                            //             ? 40
                            //             : 15))
                            : widget.messageType == 'doc'
                                ? InkWell(
                                    onTap: () async {
                                      ProgressDialog.show(Get.context!);
                                      await downloadAndOpenFile(
                                          widget.message, widget.fileName ?? "",
                                          (received, total) {
                                        ProgressDialog.updateProgress(
                                            received, total);
                                      }, false);
                                      ProgressDialog.resetProgress();

                                      ProgressDialog.hideLoader(context);
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          AppSizes.cardCornerRadius),
                                      child: Container(
                                        constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.45,
                                            maxHeight: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.30),
                                        child: SizedBox(
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.30,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.45,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.cloud_download,
                                                size: 40,
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 10,
                                                    left: 10,
                                                    right: 10),
                                                child: Text(
                                                  widget.fileName ?? "",
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 18),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : widget.messageType == "video"
                                    ? GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  VideoMessage(
                                                videoUrl: widget.message,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          alignment: Alignment.center,
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.8,
                                            maxHeight: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.5,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                                AppSizes.cardCornerRadius),
                                            child: Stack(
                                              alignment: Alignment
                                                  .center, // Center the play icon
                                              children: [
                                                FutureBuilder<String?>(
                                                  future: generateThumbnail(
                                                      widget.message),
                                                  builder: (context, snapshot) {
                                                    if (snapshot
                                                            .connectionState ==
                                                        ConnectionState
                                                            .waiting) {
                                                      return const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      );
                                                    } else if (snapshot
                                                            .hasError ||
                                                        snapshot.data == null) {
                                                      return Center(
                                                        child: Icon(
                                                          Icons.broken_image,
                                                          size: 40,
                                                          color: colors
                                                              .iconSecondary,
                                                        ),
                                                      );
                                                    } else {
                                                      return Image.file(
                                                        File(snapshot.data!),
                                                        fit: BoxFit.cover,
                                                        height: 200,
                                                        width: 250,
                                                      );
                                                    }
                                                  },
                                                ),
                                                Icon(
                                                  Icons.play_circle_fill,
                                                  color: colors.textOnPrimary,
                                                  size: 50,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
