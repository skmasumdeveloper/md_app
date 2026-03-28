import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/route.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Features/Chat/Model/chat_list_model.dart';
import 'package:cu_app/Features/Chat/Widget/sender_reply_widget.dart';
import 'package:cu_app/Utils/check_website.dart';
import 'package:cu_app/Widgets/video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:get/get.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../Commons/app_colors.dart';
import '../../../Commons/app_sizes.dart';
import '../../../Commons/app_theme_colors.dart';
import '../../../Utils/check_emojii.dart';
import '../../../Utils/downloader_file.dart';
import '../../../Utils/generate_thumbnail.dart';
import '../../../Utils/progress_dialog.dart';
import '../../../Widgets/image_popup.dart';
import 'show_image_widget.dart';

// This widget represents a chat message tile for the receiver, displaying the message content, sender's name, and time sent. It also supports swiping actions for replying or deleting messages.
class ReceiverTile extends StatefulWidget {
  final String message;
  final String messageType;
  final String sentTime;
  final String sentByName;
  final String sentByImageUrl;
  final String groupCreatedBy;
  final void Function(DragUpdateDetails d)? onSwipedMessage;
  final ChatController chatController;
  final String fileName;
  final ReplyOf? replyOf;
  final int index;
  final RxBool isHighlighted;

  ReceiverTile({
    super.key,
    required this.replyOf,
    required this.message,
    required this.messageType,
    required this.sentTime,
    required this.fileName,
    required this.sentByName,
    this.sentByImageUrl = '',
    required this.groupCreatedBy,
    required this.onSwipedMessage,
    required this.chatController,
    required this.index,
    RxBool? isHighlighted,
  }) : isHighlighted = isHighlighted ?? false.obs; // Initialize if null

  @override
  State<ReceiverTile> createState() => _ReceiverTileState();
}

class _ReceiverTileState extends State<ReceiverTile> {
  final chatController = Get.put(ChatController());
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SwipeTo(
      onRightSwipe: widget.onSwipedMessage,
      child: Container(
          child: widget.messageType == 'notify'
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: AppSizes.kDefaultPadding),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.kDefaultPadding,
                          vertical: AppSizes.kDefaultPadding / 2),
                      decoration: BoxDecoration(
                          border:
                              Border.all(width: 1, color: colors.borderColor),
                          borderRadius: BorderRadius.circular(
                              AppSizes.cardCornerRadius / 2),
                          color: colors.shimmerBase),
                      child: Text(
                        '${widget.groupCreatedBy} ${widget.message}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          if (widget.sentByImageUrl.isNotEmpty) {
                            Get.to(
                                () => FullScreenImageViewer(
                                      lableText: widget.sentByName,
                                      imageUrl: widget.sentByImageUrl,
                                    ),
                                transition: Transition
                                    .circularReveal, // Optional: Customize the animation
                                duration: const Duration(milliseconds: 700));
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                              AppSizes.cardCornerRadius * 3),
                          child: CachedNetworkImage(
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                              imageUrl: widget.sentByImageUrl,
                              placeholder: (context, url) => CircleAvatar(
                                    radius: 16,
                                    backgroundColor: colors.surfaceBg,
                                  ),
                              errorWidget: (context, url, error) =>
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: colors.surfaceBg,
                                    child: Text(
                                      widget.sentByName
                                          .substring(0, 1)
                                          .toString()
                                          .toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                  )),
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.sentByName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                              ),
                              Text(
                                ', ${widget.sentTime}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                          widget.replyOf != null
                              ? SenderMsgReplyWidget(
                                  replyOfmsgId: widget.replyOf?.msgId ?? "",
                                  messageType: widget.replyOf?.msgType ?? "",
                                  replyMsg: widget.replyOf?.msg ?? "",
                                  senderName: widget.replyOf?.sender ?? "",
                                )
                              : SizedBox.fromSize(),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSizes.kDefaultPadding * 2,
                            ),
                            child: Obx(
                              () => ChatBubble(
                                clipper: ChatBubbleClipper3(
                                    type: BubbleType.receiverBubble),
                                backGroundColor: widget.isHighlighted.value
                                    ? AppColors.primary
                                    : AppColors.receiverChatBubble,
                                alignment: Alignment.topLeft,
                                elevation: 0,
                                margin: const EdgeInsets.only(
                                    top: AppSizes.kDefaultPadding / 4),
                                child: Container(
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.65),
                                  child: widget.messageType == 'image'
                                      ? GestureDetector(
                                          onTap: () {
                                            context.push(ShowImage(
                                                imageUrl: widget.message));
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                                AppSizes.cardCornerRadius),
                                            child: CachedNetworkImage(
                                              imageUrl: widget.message,
                                              height: 200,
                                              width: 250,
                                              fit: BoxFit.contain,
                                              placeholder: (context, url) =>
                                                  const Center(
                                                      child:
                                                          CircularProgressIndicator
                                                              .adaptive()),
                                              errorWidget: (context, url,
                                                      error) =>
                                                  const Center(
                                                      child:
                                                          CircularProgressIndicator
                                                              .adaptive()),
                                            ),
                                          ),
                                        )
                                      : widget.messageType == 'text'
                                          ? CheckWebsite().isWebsite(
                                                      widget.message) ||
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
                                                  options: const LinkifyOptions(
                                                      humanize: false),
                                                  // linkColor: Colors.blue,
                                                  linkStyle: const TextStyle(
                                                    color: AppColors
                                                        .textColorSecondary,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                  style: TextStyle(
                                                    color: AppColors
                                                        .textColorSecondary,
                                                    fontSize: isOnlyEmoji(
                                                            widget.message)
                                                        ? 40
                                                        : 15,
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
                                                  options: const LinkifyOptions(
                                                      humanize: false),
                                                  linkStyle: const TextStyle(
                                                    color: AppColors
                                                        .textColorSecondary,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                  style: TextStyle(
                                                    color: AppColors
                                                        .textColorSecondary,
                                                    fontSize: isOnlyEmoji(
                                                            widget.message)
                                                        ? 40
                                                        : 15,
                                                  ),
                                                )
                                          // Text(
                                          //     widget.message,
                                          //     style: TextStyle(
                                          //         color: AppColors
                                          //             .textColorSecondary,
                                          //         fontSize: isOnlyEmoji(
                                          //                 widget.message)
                                          //             ? 40
                                          //             : 15),
                                          //   )
                                          : widget.messageType == 'doc'
                                              ? InkWell(
                                                  onTap: () async {
                                                    ProgressDialog.show(
                                                        Get.context!);
                                                    await downloadAndOpenFile(
                                                        widget.message,
                                                        widget.fileName,
                                                        (received, total) {
                                                      ProgressDialog
                                                          .updateProgress(
                                                              received, total);
                                                    }, false);
                                                    ProgressDialog
                                                        .resetProgress();

                                                    ProgressDialog.hideLoader(
                                                        context);
                                                  },
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius
                                                        .circular(AppSizes
                                                            .cardCornerRadius),
                                                    child: Container(
                                                      constraints: BoxConstraints(
                                                          maxWidth: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.45,
                                                          maxHeight:
                                                              MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width *
                                                                  0.40),
                                                      child: SizedBox(
                                                        height: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.40,
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.45,
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .download_for_offline,
                                                              size: 35,
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      top: 10,
                                                                      left: 10,
                                                                      right:
                                                                          10),
                                                              child: Text(
                                                                widget.fileName,
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            18),
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
                                                              videoUrl: widget
                                                                  .message,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      child: Container(
                                                        alignment:
                                                            Alignment.center,
                                                        constraints:
                                                            BoxConstraints(
                                                          maxWidth: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.8,
                                                          maxHeight:
                                                              MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width *
                                                                  0.5,
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius
                                                              .circular(AppSizes
                                                                  .cardCornerRadius),
                                                          child: Stack(
                                                            alignment: Alignment
                                                                .center, // Center the play icon
                                                            children: [
                                                              FutureBuilder<
                                                                  String?>(
                                                                future: generateThumbnail(
                                                                    widget
                                                                        .message),
                                                                builder: (context,
                                                                    snapshot) {
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
                                                                      snapshot.data ==
                                                                          null) {
                                                                    return Center(
                                                                      child:
                                                                          Icon(
                                                                        Icons
                                                                            .broken_image,
                                                                        size:
                                                                            40,
                                                                        color: colors
                                                                            .iconSecondary,
                                                                      ),
                                                                    );
                                                                  } else {
                                                                    return Image
                                                                        .file(
                                                                      File(snapshot
                                                                          .data!),
                                                                      fit: BoxFit
                                                                          .cover,
                                                                      height:
                                                                          200,
                                                                      width:
                                                                          250,
                                                                    );
                                                                  }
                                                                },
                                                              ),
                                                              Icon(
                                                                Icons
                                                                    .play_circle_fill,
                                                                color: colors
                                                                    .textOnPrimary,
                                                                size: 50,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : const SizedBox(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                )),
    );
  }
}
