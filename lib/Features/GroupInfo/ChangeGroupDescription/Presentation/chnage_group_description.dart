import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Widgets/custom_app_bar.dart';
import 'package:cu_app/Widgets/custom_text_field.dart';
import 'package:cu_app/Widgets/rounded_corner_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../Widgets/full_button.dart';
import '../../../AddMembers/Controller/group_create_controller.dart';
import '../../../Chat/Controller/chat_controller.dart';
import '../../../Meetings/Controller/meetings_list_controller.dart';

// This screen allows users to change the description of a group or meeting.
class ChangeGroupDescription extends StatefulWidget {
  final String groupId;
  final bool isMeeting;

  const ChangeGroupDescription(
      {super.key, required this.groupId, required this.isMeeting});

  @override
  State<ChangeGroupDescription> createState() => _ChangeGroupDescriptionState();
}

class _ChangeGroupDescriptionState extends State<ChangeGroupDescription> {
  final TextEditingController descController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final chatController = Get.put(ChatController());
  final memberController = Get.put(MemeberlistController());

  @override
  void initState() {
    //descController.text = widget.groupId['group_description'];
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getDetails();
    });
  }

// This method retrieves the group or meeting details to populate the description field.
  getDetails() async {
    await Future.delayed(const Duration(milliseconds: 200), () {
      chatController.setControllerValue();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Form(
      key: _formKey,
      child: Scaffold(
        backgroundColor: colors.scaffoldBg,
        appBar: CustomAppBar(
          title:
              '${widget.isMeeting == true ? "Meeting" : "Group"} Description',
        ),
        body: RoundedCornerContainer(
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 10,
                      ),
                      Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: colors.cardBg),
                        padding: const EdgeInsets.only(
                            top: 20, bottom: 20, right: 10, left: 10),
                        child: Obx(() => CustomTextField(
                              controller: chatController.titleController.value,
                              maxLines: 1,
                              labelText: "Upate Title",
                            )),
                      ),
                      const SizedBox(
                        height: 30,
                      ),
                      Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: colors.cardBg),
                        padding: const EdgeInsets.only(
                            top: 20, bottom: 20, right: 10, left: 10),
                        child: Obx(() => CustomTextField(
                              controller:
                                  chatController.descriptionController.value,
                              maxLines: 1,
                              labelText: "Update Description",
                            )),
                      ),
                    ],
                  ),
                ),
                Obx(() => chatController.isUpdateLoading.value
                    ? const Center(
                        child: CircularProgressIndicator.adaptive(),
                      )
                    : FullButton(
                        label: 'Ok'.toUpperCase(),
                        onPressed: () async {
                          chatController.updateGroup(
                              context: context,
                              groupId: widget.groupId,
                              groupName: chatController
                                  .titleController.value.text
                                  .toString(),
                              groupDes: chatController
                                  .descriptionController.value.text,
                              groupImage: null);
                          if (widget.isMeeting == true) {
                            final meetingsController =
                                Get.put(MeetingsListController());
                            await meetingsController.getMeetingsList(
                                isLoadingShow: false);
                            await meetingsController
                                .getMeetingCallDetails(widget.groupId);
                          }
                        })),
                Container(
                  alignment: Alignment.center,
                  child: TextButton(
                      style: TextButton.styleFrom(
                          maximumSize:
                              const Size.fromHeight(AppSizes.buttonHeight)),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Cancel',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      )),
                ),
                const SizedBox(
                  height: 20,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
