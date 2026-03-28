import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/Commons/app_sizes.dart';
import 'package:cu_app/Widgets/custom_app_bar.dart';
import 'package:cu_app/Widgets/custom_divider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Chat/Widget/sender_tile.dart';

// This screen displays detailed information about a specific message, including who read it and who it was delivered to.
class MessageInfoScreen extends StatefulWidget {
  final Map<String, dynamic> chatMap;

  const MessageInfoScreen({super.key, required this.chatMap});

  @override
  State<MessageInfoScreen> createState() => _MessageInfoScreenState();
}

class _MessageInfoScreenState extends State<MessageInfoScreen> {
  List readByList = [];
  List deliveredToList = [];
  List chatMembersList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatMembersList = widget.chatMap['members'];
      for (var i = 0; i < chatMembersList.length; i++) {
        if (chatMembersList[i]['isSeen'] == true) {
          readByList.add(chatMembersList[i]);
        }
        if (chatMembersList[i]['isDelivered'] == true) {
          deliveredToList.add(chatMembersList[i]);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Message Info',
      ),
      body: ListView(
        children: [
          SenderTile(
            isDelivered: false.obs,
            index: 1,
            message: widget.chatMap['message'],
            messageType: widget.chatMap['type'],
            sentTime: '',
            groupCreatedBy: '',
            read: '',
            isSeen: false.obs,
          ),
          const SizedBox(
            height: AppSizes.kDefaultPadding,
          ),
          const CustomDivider(),
          Container(
            color: AppColors.shimmer,
            padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
            child: Row(
              children: [
                const Icon(
                  Icons.done_all,
                  size: 20,
                  color: AppColors.grey,
                ),
                const SizedBox(
                  width: AppSizes.kDefaultPadding,
                ),
                Text(
                  'Delivered To'.toUpperCase(),
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              ],
            ),
          ),
          const CustomDivider(),
          SizedBox(
              child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: AppSizes.kDefaultPadding / 2),
            itemCount: deliveredToList.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.kDefaultPadding,
                    vertical: AppSizes.kDefaultPadding / 3),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.shimmer,
                      foregroundImage: NetworkImage(
                          deliveredToList[index]['profile_picture'].toString()),
                    ),
                    const SizedBox(
                      width: AppSizes.kDefaultPadding,
                    ),
                    Text(
                      deliveredToList[index]['name'],
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (BuildContext context, int index) {
              return const Padding(
                padding: EdgeInsets.only(left: 64),
                child: CustomDivider(),
              );
            },
          )),
          const CustomDivider(),
          Container(
            color: AppColors.shimmer,
            padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
            child: Row(
              children: [
                const Icon(
                  Icons.done_all,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(
                  width: AppSizes.kDefaultPadding,
                ),
                Text(
                  'Read By'.toUpperCase(),
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              ],
            ),
          ),
          const CustomDivider(),
          SizedBox(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: AppSizes.kDefaultPadding / 2),
              itemCount: readByList.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding,
                      vertical: AppSizes.kDefaultPadding / 3),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.shimmer,
                        foregroundImage: NetworkImage(
                            readByList[index]['profile_picture'].toString()),
                      ),
                      const SizedBox(
                        width: AppSizes.kDefaultPadding,
                      ),
                      Text(
                        readByList[index]['name'],
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .copyWith(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (BuildContext context, int index) {
                return const Padding(
                  padding: EdgeInsets.only(left: 64),
                  child: CustomDivider(),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
