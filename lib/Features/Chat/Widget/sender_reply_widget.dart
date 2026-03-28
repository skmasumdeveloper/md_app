import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/Commons/app_sizes.dart';
import '../../../Commons/app_theme_colors.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// This widget displays a reply message in the chat, showing the sender's name and the content of the replied message.
class SenderMsgReplyWidget extends StatelessWidget {
  const SenderMsgReplyWidget(
      {super.key,
      required this.replyOfmsgId,
      required this.replyMsg,
      required this.senderName,
      required this.messageType});

  final String replyOfmsgId, replyMsg, messageType;
  final String senderName;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final chatController = Get.find<ChatController>();

    return GestureDetector(
      onTap: () async {
        print("Scrolling to message ID: $replyOfmsgId");

        // Use the new scroll to message function
        await chatController.scrollToMessage(replyOfmsgId);
      },
      child: Container(
        height: 100,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width / 2,
        ),
        decoration: BoxDecoration(
            color: colors.surfaceBg,
            borderRadius: BorderRadius.only(
                topRight: Radius.circular(AppSizes.cardCornerRadius),
                bottomRight: Radius.circular(AppSizes.cardCornerRadius))),
        child: Row(
          children: [
            const SizedBox(
              width: AppSizes.kDefaultPadding / 4,
            ),
            Container(
              height: 54,
              width: 2,
              color: AppColors.primary,
            ),
            const SizedBox(
              width: AppSizes.kDefaultPadding / 2,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 1,
                      child: Text(
                        senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(
                      height: AppSizes.kDefaultPadding / 8,
                    ),
                    messageType == "image"
                        ? CachedNetworkImage(
                            imageUrl: replyMsg,
                            height: 40,
                            fit: BoxFit.contain,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator.adaptive(),
                            errorWidget: (context, url, error) =>
                                const CircularProgressIndicator.adaptive(),
                          )
                        : Flexible(
                            flex: 1,
                            child: Text(
                              replyMsg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(color: colors.textSecondary),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
