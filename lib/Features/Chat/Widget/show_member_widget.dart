import 'package:cu_app/Commons/app_sizes.dart';
import '../../../Commons/app_theme_colors.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:flutter/material.dart';

// This widget displays a list of members in a chat, allowing users to tag members in messages.
class TagMemberWidget extends StatelessWidget {
  const TagMemberWidget({super.key, required this.chatController});

  final ChatController chatController;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      height: 200,
      margin: const EdgeInsets.only(left: 5, right: 40),
      decoration: BoxDecoration(
          color: colors.surfaceBg,
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(AppSizes.cardCornerRadius),
              bottomRight: Radius.circular(AppSizes.cardCornerRadius))),
      padding: const EdgeInsets.only(left: 20),
      child: ListView.builder(
          itemCount: chatController.groupModel.value.currentUsers!.length,
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return ListTile(
              onTap: () {
                chatController.addNameInMsgText(
                    mentionname: chatController
                            .groupModel.value.currentUsers![index].name ??
                        "");
                chatController.isMemberSuggestion(false);
              },
              contentPadding: EdgeInsets.zero,
              title: Text(
                chatController.groupModel.value.currentUsers![index].name ?? "",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }),
    );
  }
}
