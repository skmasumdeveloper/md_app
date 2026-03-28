import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/app_images.dart';
import 'package:cu_app/Commons/app_sizes.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Commons/app_colors.dart';
import '../../../Commons/app_theme_colors.dart';
import '../../../Utils/animation_loader.dart';
import '../../../Utils/custom_bottom_modal_sheet.dart';
import '../../../Widgets/custom_divider.dart';
import '../../../Widgets/custom_text_field.dart';
import '../../GroupInfo/Model/image_picker_model.dart';

// This widget allows users to send messages in a chat, including text, images, and files. It also supports replying to previous messages.
class SendMessageWidget extends StatefulWidget {
  final TextEditingController msgController;
  final ScrollController scrollController;
  final String groupId;
  final FocusNode? focusNode;

  const SendMessageWidget(
      {super.key,
      required this.msgController,
      required this.scrollController,
      required this.groupId,
      this.focusNode});

  @override
  State<SendMessageWidget> createState() => _SendMessageWidgetState();
}

class _SendMessageWidgetState extends State<SendMessageWidget> {
  final chatController = Get.put(ChatController());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((t) {
      chatController.getGroupDetailsById(groupId: widget.groupId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: Stack(
        children: [
          const CustomDivider(),
          Padding(
            padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.kDefaultPadding),
                    decoration: BoxDecoration(
                      color: colors.scaffoldBg,
                      border: Border.all(color: colors.borderColor),
                      borderRadius:
                          BorderRadius.circular(AppSizes.cardCornerRadius),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child: Column(
                          children: [
                            chatController.isReply.value == true
                                ? Container(
                                    height: 100,
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width,
                                    ),
                                    decoration: BoxDecoration(
                                        color: colors.surfaceBg,
                                        borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(
                                                AppSizes.cardCornerRadius),
                                            bottomRight: Radius.circular(
                                                AppSizes.cardCornerRadius))),
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Flexible(
                                                  flex: 1,
                                                  child: Text(
                                                    chatController
                                                        .replyOf['sender'],
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium!
                                                        .copyWith(
                                                            color: AppColors
                                                                .primary,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height:
                                                      AppSizes.kDefaultPadding /
                                                          8,
                                                ),
                                                chatController.replyOf[
                                                            'msgType'] ==
                                                        "image"
                                                    ? CachedNetworkImage(
                                                        imageUrl: chatController
                                                            .replyOf['msg'],
                                                        height: 40,
                                                      )
                                                    : Flexible(
                                                        flex: 1,
                                                        child: Text(
                                                          chatController
                                                              .replyOf['msg'],
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyMedium!
                                                              .copyWith(
                                                                  color: colors
                                                                      .textSecondary),
                                                        ),
                                                      ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                            onPressed: () {
                                              chatController.isRelayFunction(
                                                  isRep: false);
                                              FocusScope.of(context).unfocus();
                                            },
                                            icon: Icon(
                                              Icons.close,
                                              size: 24,
                                              color: colors.textSecondary,
                                            ))
                                      ],
                                    ),
                                  )
                                : const SizedBox(),
                            chatController.isReply.value == true
                                ? const CustomDivider()
                                : const SizedBox(),
                            CustomTextField(
                              controller: widget.msgController,
                              focusNode: widget.focusNode,
                              hintText: 'Type a message',
                              maxLines: 4,
                              isReplying: chatController.isReply.value,
                              keyboardType: TextInputType.multiline,
                              minLines: 1,
                              onChanged: (value) {
                                chatController.mentionMember(value!);
                                return;
                              },
                              isBorder: false,
                              replyMessage: const {},
                            ),
                          ],
                        )),
                        InkWell(
                          onTap: () {
                            showCustomBottomSheet(
                                context,
                                '',
                                Container(
                                  decoration: BoxDecoration(
                                      color: colors.scaffoldBg,
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20))),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        height: 150,
                                        color: colors.scaffoldBg,
                                        child: ListView.builder(
                                            shrinkWrap: true,
                                            padding: const EdgeInsets.all(
                                                AppSizes.kDefaultPadding),
                                            itemCount: chatPickerList.length,
                                            scrollDirection: Axis.horizontal,
                                            itemBuilder: (context, index) {
                                              return GestureDetector(
                                                onTap: () async {
                                                  var ownId = LocalStorage()
                                                      .getUserId();

                                                  List<String> userIds =
                                                      chatController.groupModel
                                                          .value.currentUsers!
                                                          .map((user) =>
                                                              user.sId!)
                                                          .where((userId) =>
                                                              userId != ownId)
                                                          .toList();

                                                  switch (index) {
                                                    case 0:
                                                      chatController.pickFile(
                                                          replyOff:
                                                              chatController
                                                                  .replyOf
                                                                  .value,
                                                          groupId:
                                                              widget.groupId,
                                                          receiverId: userIds,
                                                          context: context);

                                                      break;
                                                    case 1:
                                                      chatController
                                                          .pickMultipleMediaForSendSms(
                                                              groupId: widget
                                                                  .groupId,
                                                              receiverId:
                                                                  userIds,
                                                              replyOff:
                                                                  chatController
                                                                      .replyOf
                                                                      .value,
                                                              context: context);

                                                      break;
                                                    case 2:
                                                      chatController
                                                          .pickImageFromCameraSendSms(
                                                              imageSource: ImageSource
                                                                  .camera,
                                                              groupId: widget
                                                                  .groupId,
                                                              receiverId:
                                                                  userIds,
                                                              replyoff:
                                                                  chatController
                                                                      .replyOf
                                                                      .value,
                                                              context: context);

                                                      break;
                                                    case 3:
                                                      chatController
                                                          .pickVideoFromCameraAndSendMsg(
                                                              replyOff:
                                                                  chatController
                                                                      .replyOf
                                                                      .value,
                                                              groupId: widget
                                                                  .groupId,
                                                              receiverId:
                                                                  userIds);
                                                  }
                                                  Navigator.pop(context);
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .only(
                                                      left: AppSizes
                                                              .kDefaultPadding *
                                                          2),
                                                  child: Column(
                                                    children: [
                                                      Container(
                                                        width: 60,
                                                        height: 60,
                                                        padding: const EdgeInsets
                                                            .all(AppSizes
                                                                .kDefaultPadding),
                                                        decoration: BoxDecoration(
                                                            border: Border.all(
                                                                width: 1,
                                                                color: colors
                                                                    .borderColor),
                                                            color:
                                                                colors.cardBg,
                                                            shape: BoxShape
                                                                .circle),
                                                        child: chatPickerList[
                                                                index]
                                                            .icon,
                                                      ),
                                                      const SizedBox(
                                                        height: AppSizes
                                                                .kDefaultPadding /
                                                            2,
                                                      ),
                                                      Text(
                                                        '${chatPickerList[index].title}',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                      ),
                                    ],
                                  ),
                                ));
                          },
                          child: const Icon(
                            EvaIcons.attach,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  width: AppSizes.kDefaultPadding,
                ),
                Obx(() => chatController.isSendSmsLoading.value
                    ? Container(
                        width: 36,
                        height: 36,
                        padding:
                            const EdgeInsets.all(AppSizes.kDefaultPadding / 2),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.buttonGradientColor),
                        child: Center(
                          child: AnimatedLoader(
                            size: 30,
                            color: colors.textOnPrimary,
                            // animationStyle:
                            //     LoaderAnimationStyle.flipLoader,
                            animationStyle: LoaderAnimationStyle.bouncingDots,
                            itemCount: 3,
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: () async {
                          if (widget.msgController.text.isNotEmpty) {
                            chatController.msgText.value =
                                widget.msgController.text.toString();

                            var ownId = LocalStorage().getUserId();
                            List<String>? userIds = chatController
                                .groupModel.value.currentUsers!
                                .map((user) => user.sId!)
                                .where((userId) => userId != ownId)
                                .toList();
                            await chatController.sendMsg(
                                replyOf: chatController.isReply.value == true
                                    ? chatController.replyOf
                                    : null,
                                msg: chatController.msgText.value,
                                reciverId: userIds,
                                groupId: widget.groupId,
                                msgType: "text");
                            chatController.isRelayFunction(
                              isRep: false,
                            );
                            widget.msgController.clear();
                          } else {}
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          padding: const EdgeInsets.all(
                              AppSizes.kDefaultPadding / 2),
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.buttonGradientColor),
                          child: Image(
                            image: const AssetImage(AppImages.sendIcon),
                            width: 20,
                            height: 20,
                            color: colors.textOnPrimary,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ))
              ],
            ),
          ),
        ],
      ),
    );
  }
}
