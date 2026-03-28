import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cu_app/Features/Chat/Model/chat_list_model.dart';
import 'package:cu_app/Features/Chat/Repo/chat_repo.dart';
import 'package:cu_app/Features/Chat/Widget/docs_video.dart';
import 'package:cu_app/Features/Home/Controller/socket_controller.dart';
import 'package:cu_app/Features/Home/Model/group_list_model.dart';
import 'package:cu_app/Features/Home/Repository/group_repo.dart';
import 'package:cu_app/Features/Login/Controller/login_controller.dart';
import 'package:cu_app/Utils/open_any_file.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Widgets/toast_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../Utils/datetime_utils.dart';
import '../../Home/Controller/group_list_controller.dart';
import '../../Home/Presentation/home_screen.dart';
import '../Widget/confirmation_bottom_sheet_video.dart';
import '../Widget/picture_shoiwing_bottomsheet.dart';

// This controller handles the logic for managing chat functionalities, including sending messages, fetching chat history, and handling group details.
class ChatController extends GetxController {
  final GroupRepo _groupRepo = GroupRepo();
  final _chatRepo = ChatRepo();
  RxBool isReply = false.obs;
  RxInt selectedIndex = (-1).obs;
  RxBool isMemberSuggestion = false.obs;
  final msgController = TextEditingController().obs;
  RxInt timeStamps = (-1).obs;
  RxBool isSendWidgetShow = true.obs;
  RxBool isChatScreen = false.obs;

  // A key per message to enable precise scrolling
  final Map<String, GlobalKey> messageKeys = {};

  GlobalKey getMessageKey(String id) {
    return messageKeys.putIfAbsent(id, () => GlobalKey());
  }

  // This method returns the display name for a group
  // For direct groups (isDirect = true with 2 users), it shows the opposite user's name
  // For regular groups, it shows the group name
  String getGroupDisplayName({
    required GroupModel group,
    String? defaultGroupName,
  }) {
    if (group.isDirect == true &&
        group.currentUsers != null &&
        group.currentUsers!.length == 2) {
      final currentUserId = LocalStorage().getUserId();
      final otherUser = group.currentUsers!
          .firstWhereOrNull((user) => user.sId != currentUserId);
      if (otherUser != null &&
          otherUser.name != null &&
          otherUser.name!.isNotEmpty) {
        return otherUser.name!;
      }
    }
    return defaultGroupName ?? group.groupName ?? '';
  }

  void isShowing(
    bool isShowing,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isShowing == true) {
        isSendWidgetShow.value = false;
      } else {
        isSendWidgetShow.value = true;
      }
    });
  }

  final RxMap<String, dynamic> replyOf = <String, dynamic>{
    "msgId": '',
    "sender": '',
    "msg": '',
    "msgType": '',
  }.obs;
  var chatMap = <AsyncSnapshot>{}.obs;
  var groupModel = GroupModel().obs;
  var descriptionController = TextEditingController().obs;
  var titleController = TextEditingController().obs;
  RxList<ChatModel> chatList = <ChatModel>[].obs;
  RxString groupId = "".obs;
  RxInt limit = 100.obs;
  RxBool isChatLoading = false.obs;
  RxBool isGroupCallActive = false.obs;
  RxBool isGroupCallVideo = true.obs;
  RxString activeCallGroupId = "".obs;
  RxBool isMeetingGroup = false.obs;
  RxBool isMeetingEnded = false.obs;

  var userInfoData = <String, dynamic>{}.obs;

  // This method adds a mentioned name to the message input field.
  void addNameInMsgText({String? mentionname}) {
    msgController.value.text = msgController.value.text + mentionname!;
    msgController.value.selection = TextSelection.fromPosition(
        TextPosition(offset: msgController.value.text.length));
  }

  // This method initializes the chat controller and sets up the group ID.
  Future<void> getAllChatByGroupId(
      {required String groupId, bool isShowLoading = true}) async {
    try {
      isShowLoading ? isChatLoading(true) : null;
      final timestamp = timeStamps.value == -1 ? null : timeStamps.value;
      Map<String, dynamic> reqModel = {
        "id": groupId,
        "timestamp": timestamp,
        "offset": 0,
        "limit": limit.value
      };

      var res = await _chatRepo.getChatListApi(reqModel: reqModel);
      debugPrint(
          'getAllChatByGroupId response: status=${res.statusCode} error=${res.errorMessage} success=${res.data?.success}');

      if (res.data != null && res.data!.success == true) {
        // Deduplicate fetched chat list by sId to avoid duplicates when a socket message
        // may have already been added before the history fetch completed
        final fetched = res.data!.chat ?? [];
        final seen = <String>{};
        final unique = <ChatModel>[];
        for (var c in fetched) {
          if (c.sId != null && !seen.contains(c.sId)) {
            unique.add(c);
            seen.add(c.sId!);
          }
        }
        chatList.value = unique;
        chatList.refresh();
        checkActiveCall(groupId);
      } else {
        chatList.value = [];
        // Show server message when available to aid debugging
        if (res.data?.message != null && res.data!.message!.isNotEmpty) {
          TostWidget().errorToast(title: 'Error', message: res.data!.message!);
        } else if (res.errorMessage != null) {
          TostWidget().errorToast(title: 'Error', message: res.errorMessage!);
        }
      }
    } catch (e, st) {
      debugPrint('Error in getAllChatByGroupId: $e\n$st');
      TostWidget().errorToast(title: 'Error', message: e.toString());
      chatList.value = [];
    } finally {
      isShowLoading ? isChatLoading(false) : null;
    }
  }

  RxBool isCheckingActiveCall = false.obs;
  // This method checks if there is an active call in the group.
  Future<void> checkActiveCall(String theGroupId,
      {bool isShowLoading = false}) async {
    try {
      if (theGroupId.isEmpty) {
        return;
      }
      isShowLoading ? isCheckingActiveCall(true) : null;
      var res = await _groupRepo.checkActiveCall(groupId: theGroupId);
      if (res.data!['success'] == true) {
        final bool active = res.data!['data']['activeCall'] == true;
        if (active) {
          activeCallGroupId.value = theGroupId;
        } else if (activeCallGroupId.value == theGroupId) {
          activeCallGroupId.value = "";
        }

        if (theGroupId == groupId.value) {
          isGroupCallActive.value = active;
          if (active) {
            isGroupCallVideo.value =
                res.data!['data']['callType'] == "video" ? true : false;
          }
        }
      } else {
        if (theGroupId == groupId.value) {
          isGroupCallActive.value = false;
        }
        if (activeCallGroupId.value == theGroupId) {
          activeCallGroupId.value = "";
        }
      }
    } catch (e) {
      if (theGroupId == groupId.value) {
        isGroupCallActive.value = false;
      }
      if (activeCallGroupId.value == theGroupId) {
        activeCallGroupId.value = "";
      }
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        isCheckingActiveCall(false);
      });
    }
  }

  // This method picks an image from the gallery and updates the image file and path.
  Future<void> pickImage(
      {required ImageSource imageSource,
      required String groupId,
      required BuildContext context}) async {
    try {
      final selected =
          await ImagePicker().pickImage(imageQuality: 50, source: imageSource);
      if (selected != null) {
        File groupImages = File(selected.path);

        updateGroup(
            groupId: groupId,
            groupDes: descriptionController.value.text.toString(),
            groupName: titleController.value.text.toString(),
            groupImage: groupImages,
            context: context);
      } else {}
    } on Exception {}
  }

  isRelayFunction(
      {required bool isRep,
      String? msg,
      String? senderName,
      String? msgId,
      String? msgType}) {
    replyOf['msgId'] = msgId;
    replyOf['sender'] = senderName;
    replyOf['msg'] = msg;
    replyOf['msgType'] = msgType;
    isReply(isRep);
  }

  setControllerValue() {
    titleController.value.text = groupModel.value.groupName != null
        ? groupModel.value.groupName.toString()
        : "";
    descriptionController.value.text = groupModel.value.groupDescription ?? "";
  }

// This method checks if a member is mentioned in the message input field and updates the suggestion state accordingly.
  void mentionMember(String value) {
    if (value != '') {
      if (value[value.length - 1] == '@') {
        isMemberSuggestion(true);
      } else if (value.isNotEmpty && value[value.length - 1] != '@') {
        isMemberSuggestion(false);
      } else if (value.isNotEmpty || value[value.length] != '@') {
        isMemberSuggestion(false);
      } else {
        isMemberSuggestion(false);
      }
    } else {
      isMemberSuggestion(false);
    }
  }

  RxBool isDetailsLaoding = false.obs;
  // This method retrieves the group details by its ID and updates the group model.
  getGroupDetailsById(
      {required String groupId,
      int? timeStamp,
      bool isShowLoading = true}) async {
    try {
      isShowLoading ? isDetailsLaoding(true) : null;
      if (isShowLoading) {
        groupModel.value = GroupModel();
      }
      var res = await _groupRepo.getGroupDetailsById(
        groupId: groupId,
      );
      groupModel.value = res.data!;
      isMeetingGroup.value = groupModel.value.isTemp ?? false;
      if (isMeetingGroup.value) {
        checkIsMeetingEnded(
            groupModel.value.meetingEndTime ?? "", isMeetingGroup.value);
      }
      getPersonalInfoGroupDetailsById();
      isDetailsLaoding(false);
    } catch (e) {
      if (isShowLoading) {
        groupModel.value = GroupModel();
      }
      isDetailsLaoding(false);
    }
  }

// This method checks if a meeting has ended based on the end time and group status.
  checkIsMeetingEnded(String meetingEndTime, bool isMeetingGroup) async {
    try {
      var endTime =
          DateTimeUtils.utcToLocal(meetingEndTime, "yyyy-MM-ddTHH:mm:ssZ");
      if (endTime.isNotEmpty && isMeetingGroup) {
        isMeetingEnded.value = DateTime.parse(endTime).isBefore(DateTime.now());
        isSendWidgetShow.value =
            !isMeetingEnded.value; // Hide send widget if meeting ended
      } else {
        isMeetingEnded.value = false;
        isSendWidgetShow.value = true;
      }
    } catch (e) {
      isMeetingEnded.value = false;
      isSendWidgetShow.value = true; // Show send widget on error
    }
  }

  RxBool isUpdateLoading = false.obs;

  RxBool isDeleteGroupLoading = false.obs;

  /// Delete group by id (admin endpoint)
  Future<void> deleteGroupById(
      {required String groupId, required BuildContext context}) async {
    try {
      isDeleteGroupLoading(true);
      final res = await _groupRepo.deleteGroupById(groupId: groupId);
      if (res.data != null && res.data!['success'] == true) {
        TostWidget().successToast(
            title: 'Success', message: res.data!['message'] ?? 'Group deleted');
        final groupListController = Get.put(GroupListController());
        await groupListController.getGroupList(isLoadingShow: false);

        // Navigate back to home
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const HomeScreen(
                isDeleteNavigation: true,
                isFromChat: false,
              ),
            ),
            (route) => false);
      } else {
        final err = res.data != null && res.data!['message'] != null
            ? res.data!['message']
            : res.errorMessage ?? 'Failed to delete group';
        TostWidget().errorToast(title: 'Error', message: err.toString());
      }
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
    } finally {
      isDeleteGroupLoading(false);
    }
  }

  // This method updates the group details, including name, description, and image.
  updateGroup(
      {required String groupId,
      required String groupName,
      File? groupImage,
      required String groupDes,
      required BuildContext context}) async {
    try {
      final socketController = Get.find<SocketController>();
      isUpdateLoading(true);
      var res = await _groupRepo.updateGroupDetails(
          groupDes: groupDes,
          groupId: groupId,
          groupName: groupName,
          groupImage: groupImage);
      if (res.data!['success'] == true) {
        final groupListController = Get.put(GroupListController());
        Map<String, dynamic> reqModeSocket = {"data": res.data!['data']};
        socketController.socket!.emit("update-group", reqModeSocket);
        await groupListController.getGroupList(isLoadingShow: false);
        await getGroupDetailsById(groupId: groupId);
        TostWidget()
            .successToast(title: "Success", message: res.data!['message']);
        isUpdateLoading(false);

        Navigator.pop(context);
      } else {
        TostWidget()
            .errorToast(title: "Error", message: res.data!['error']['message']);
        isUpdateLoading(false);
      }
    } catch (e) {
      isUpdateLoading(false);
    }
  }

  RxBool isSendSmsLoading = false.obs;
  RxString msgText = "demo".obs;
  // This method sends a message to the group, handling different message types and file attachments.
  sendMsg({
    required String groupId,
    required String msgType,
    required String msg,
    File? file,
    Map<String, dynamic>? replyOf,
    required List<String> reciverId,
  }) async {
    String? instantMessageId; // Move declaration to method scope
    try {
      isSendSmsLoading(true);

      final socketController = Get.isRegistered<SocketController>()
          ? Get.find<SocketController>()
          : Get.put(SocketController());
      final userController = Get.put(LoginController());

      var res = await _chatRepo.sendMessage(
          replyOf: replyOf,
          groupId: groupId,
          message: msg,
          file: file,
          messageType: msgType,
          senderName: userController.userModel.value.name ?? "");
      Map<String, dynamic> reqModeSocket = {
        "replyOf": replyOf,
        "_id": res.data!['data']['data']['id'],
        "receiverId": reciverId,
        "senderId": LocalStorage().getUserId(),
        "time": DateFormat('hh:mm a').format(DateTime.now()),
      };
      socketController.socket!.emit("message", reqModeSocket);

      if (msgType == "text" && instantMessageId != '') {
        socketController.tempMessageMapping[res.data!['data']['data']['id']] =
            "temp_$instantMessageId";
      }

      isRelayFunction(
        isRep: false,
      );
      isSendSmsLoading(false);
      msgText.value = "";
    } catch (e) {
      if (msgType == "text" && instantMessageId != '') {
        chatList
            .removeWhere((element) => element.sId == "temp_$instantMessageId");
        chatList.refresh();
      }
      isSendSmsLoading(false);
    }
  }

// This method picks an image from the camera and sends it as a message.
  Future<void> pickImageFromCameraSendSms(
      {required ImageSource imageSource,
      required String groupId,
      Map<String, dynamic>? replyoff,
      required List<String> receiverId,
      required BuildContext context}) async {
    try {
      final selected =
          await ImagePicker().pickImage(imageQuality: 50, source: imageSource);
      if (selected != null) {
        File groupImages = File(selected.path);

        await sendMsg(
            msg: "text",
            groupId: groupId,
            replyOf: isReply.value == true ? replyoff : null,
            file: groupImages,
            msgType: "image",
            reciverId: receiverId);
        selectedImages.clear();
      } else {}
    } on Exception catch (e) {
      debugPrint("Error picking image from camera: $e");
    }
  }

  RxList<File> selectedImages = <File>[].obs;
  // This method picks multiple media files from the gallery and sends them as messages.
  Future<void> pickMultipleMediaForSendSms({
    required String groupId,
    required List<String> receiverId,
    required Map<String, dynamic>? replyOff,
    required BuildContext context,
  }) async {
    try {
      final selected = await ImagePicker().pickMultipleMedia(
        imageQuality: 50,
      );

      for (var selectedFile in selected) {
        File mediaFile = File(selectedFile.path);
        selectedImages.add(mediaFile);
      }
      if (selectedImages.value.isNotEmpty) {
        pictureBottomSheet(Get.context!, selectedImages, () async {
          for (var mediaFile in selectedImages) {
            String extension = mediaFile.path.split(".").last.toLowerCase();

            String messageType = "image"; // default to image

            if (extension == "mp4" ||
                extension == "mov" ||
                extension == "avi" ||
                extension == "mkv" ||
                extension == "webm" ||
                extension == "3gp" ||
                extension == "flv" ||
                extension == "wmv" ||
                extension == "m4v" ||
                extension == "mpg" ||
                extension == "mpeg" ||
                extension == "m2v" ||
                extension == "3g2" ||
                extension == "asf" ||
                extension == "rm" ||
                extension == "rmvb" ||
                extension == "vob" ||
                extension == "ts" ||
                extension == "mts" ||
                extension == "m2ts" ||
                extension == "divx" ||
                extension == "xvid" ||
                extension == "ogv" ||
                extension == "f4v" ||
                extension == "mxf") {
              messageType = "video";
            }

            await sendMsg(
              msg: "text",
              replyOf: isReply.value == true ? replyOff : null,
              groupId: groupId,
              file: mediaFile,
              msgType: messageType,
              reciverId: receiverId,
            );
          }

          selectedImages.clear();
        });
      }
    } on Exception catch (e) {
      debugPrint("Error picking multiple media: $e");
    }
  }

  Rx<File?> videoFile = Rx<File?>(null);
// This method picks a video from the camera and sends it as a message.
  Future pickVideoFromCameraAndSendMsg(
      {required String groupId,
      required List<String> receiverId,
      required Map<String, dynamic> replyOff}) async {
    try {
      final video = await ImagePicker().pickVideo(
          source: ImageSource.camera, maxDuration: const Duration(seconds: 30));
      if (video == null) return;
      File videoFileRaw = File(video.path);
      videoFile.value = videoFileRaw;
      if (videoFile.value != null) {
        videoBottomSheet(Get.context!, videoFile.value!, () async {
          await sendMsg(
              msg: "text",
              groupId: groupId,
              replyOf: isReply.value == true ? replyOff : null,
              file: videoFile.value,
              msgType: "video",
              reciverId: receiverId);
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Error picking video from camera: $e");
    }
  }

// This method shows a confirmation dialog before deleting a user.
  Future<void> pickFile(
      {required String groupId,
      required List<String> receiverId,
      required Map<String, dynamic> replyOff,
      required BuildContext context}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
    );
    if (result != null) {
      videoFile.value = null;
      PlatformFile file = result.files.first;
      File files = File(file.path.toString());
      videoFile.value = files;
      String extension = files.path.split(".").last;

      if (extension == "pdf" || extension == "doc" || extension == "docx") {
        docsModelBottomSheet(Get.context!, files, () async {
          await sendMsg(
              msg: "text",
              groupId: groupId,
              file: files,
              msgType: "doc",
              reciverId: receiverId,
              replyOf: isReply.value == true ? replyOff : null);
        });
      } else if (extension == "mp4" ||
          extension == "mov" ||
          extension == "avi" ||
          extension == "mkv" ||
          extension == "webm") {
        videoBottomSheet(Get.context!, files, () async {
          await sendMsg(
              msg: "text",
              groupId: groupId,
              file: files,
              msgType: "video",
              reciverId: receiverId,
              replyOf: isReply.value == true ? replyOff : null);
        });
      } else {
        docsModelBottomSheet(Get.context!, files, () async {
          await sendMsg(
              msg: "text",
              groupId: groupId,
              file: files,
              msgType: "doc",
              reciverId: receiverId,
              replyOf: isReply.value == true ? replyOff : null);
        });
      }
    } else {}
  }

// This method shows a dialog to confirm the deletion of a member.
  openFileAfterDownload(
      String message, String fileName, BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Downloading File...'),
              ],
            ),
          );
        },
      );

      await openPDF(fileUrl: message, fileName: fileName);

      Navigator.pop(context);
    } catch (e) {
      Navigator.pop(context);
    }
  }

// Add this new property for scroll control
  final GlobalKey<SliverAnimatedListState> listKey =
      GlobalKey<SliverAnimatedListState>();
  final ScrollController scrollController = ScrollController();
  RxBool isScrollingToMessage = false.obs;

  double estimateTextHeight(String text, double maxWidth) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 16.0, // Match your chat bubble text style
        ),
      ),
      maxLines: null,

      /// Specifies the text direction as left-to-right (LTR).
      ///
      /// This property determines the reading direction and layout orientation
      /// for text content. LTR is used for languages that are read from left
      /// to right, such as English, Spanish, French, and most European languages.
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return textPainter.size.height;
  }

  // getEstimatedItemHeight
  double getEstimatedItemHeight(int index) {
    final chat = chatList[index];
    double baseHeight =
        80.0; // Adjust based on padding, sender name, timestamp, etc.
    String? type = chat.messageType;
    if (type == 'text') {
      double textHeight = estimateTextHeight(chat.message ?? '',
          300.0); // Adjust maxWidth to match your message bubble width
      return baseHeight + textHeight;
    } else if (type == 'image') {
      return baseHeight + 200.0;
    } else if (type == 'video') {
      return baseHeight + 180.0;
    }
    return baseHeight + 80.0; // Fallback for other types like doc
  }

  // Add this new method to scroll to a specific message
  Future<void> scrollToMessage(String messageId) async {
    try {
      isScrollingToMessage.value = true;

      // First, check if the message is already in the current chat list
      int messageIndex = chatList.indexWhere((chat) => chat.sId == messageId);
      //  print('Message index: $messageIndex');

      if (messageIndex != -1) {
        // Message found in current list, scroll to it
        await _scrollToIndex(messageIndex);
      } else {
        // Message not found, need to load more data
        await _loadMessageWithPagination(messageId);
      }
    } catch (e) {
      // print('Error scrolling to message: $e');
      // TostWidget().errorToast(title: "Error", message: "Message not found");
      //   Navigator.pop(Get.context!);
    } finally {
      isScrollingToMessage.value = false;
      //  Navigator.pop(Get.context!);
    }
  }

  Future<void> _scrollToIndex(int index) async {
    if (scrollController.hasClients) {
      final int reversedIndex = chatList.length - 1 - index;
      final GlobalKey targetKey = getMessageKey(chatList[index].sId!);

      // Calculate target offset by summing estimated heights of previous items
      double targetOffset = 0.0;
      for (int i = 0; i < reversedIndex; i++) {
        final int itemIndex = chatList.length - 1 - i;
        targetOffset += getEstimatedItemHeight(itemIndex);
      }

      // Animate to the calculated position
      await scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      await _highlightMessage(index);

      // force to visible message with center
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // After animation, fine-tune with ensureVisible to center the message
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final BuildContext? context = targetKey.currentContext;
        if (context != null) {
          await Scrollable.ensureVisible(
            context,
            alignment: 0.5, // Center in the viewport
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          await _highlightMessage(index);
        } else {
          // print('Target context not available after initial scroll');
          // Optionally, add retry logic here if needed
        }
      });
    }
  }

  // Helper method to load more messages until the target is found
  Future<void> _loadMessageWithPagination(String messageId) async {
    const int maxAttempts = 100; // Prevent infinite loading
    int attempts = 0;

    final scaffold = ScaffoldMessenger.of(Get.context!);
    scaffold.showSnackBar(
      SnackBar(
        content: const Text('Finding message...'),
        duration: const Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(bottom: 60, left: 20, right: 20),
      ),
    );

    while (attempts < maxAttempts) {
      // Increase limit to load more messages
      limit.value += 200;

      // Fetch more messages
      await getAllChatByGroupId(groupId: groupId.value, isShowLoading: false);

      // Check if message is now in the list
      int messageIndex = chatList.indexWhere((chat) => chat.sId == messageId);

      if (messageIndex != -1) {
        // Message found, scroll to it
        await _scrollToIndex(messageIndex);

        return;
      }

      attempts++;

      // If we didn't get any new messages, break the loop
      if (chatList.length < limit.value) {
        break;
      }
    }

    // Message not found after loading more data
    // TostWidget()
    //     .errorToast(title: "Error", message: "Message not found or too old");
  }

  // Optional: Add highlight effect to the target message
  Future<void> _highlightMessage(int index) async {
    // Set highlight to true
    chatList[index].isHighlighted?.value = true;
    chatList.refresh();

    // Remove highlight after 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    chatList[index].isHighlighted?.value = false;
    chatList.refresh();
  }

  // deleteMessage
  Future<void> deleteMessage(String messageId) async {
    // Find the message in the chat list
    int messageIndex = chatList.indexWhere((chat) => chat.sId == messageId);

    if (messageIndex != -1) {
      // Remove the message from the chat list
      chatList.removeAt(messageIndex);
      chatList.refresh();

      // delete from api
      final res = await _chatRepo.deleteMessage(reqModel: {
        "messageId": messageId,
      });
      var ownId = LocalStorage().getUserId();
      List<String>? receiverIds = groupModel.value.currentUsers!
          .map((user) => user.sId!)
          .where((userId) => userId != ownId)
          .toList();

      final socketController = Get.isRegistered<SocketController>()
          ? Get.find<SocketController>()
          : Get.put(SocketController());

      // emit socket
      socketController.socket!.emit("deleteMessage", {
        "groupId": groupId.value,
        "userId": ownId,
        "receiverId": receiverIds,
        "deleteMsg": messageId,
      });

      if (res.errorMessage != null) {
        TostWidget().errorToast(title: "Error", message: res.errorMessage);
      }

      // Show a snackbar or any other feedback
      TostWidget().successToast(title: "Success", message: "Message deleted");
    } else {
      // Message not found
      TostWidget().errorToast(title: "Error", message: "Message not found");
    }
  }

  getPersonalInfoGroupDetailsById() async {
    try {
      var directUser = groupModel.value.currentUsers!
          .firstWhere((user) => user.sId != LocalStorage().getUserId());
      userInfoData.value = {
        "name": directUser.name ?? "",
        "email": directUser.email ?? "",
        "phone": directUser.phone ?? "",
        "profilePic": directUser.image ?? "",
        "userId": directUser.sId ?? "",
        "userType": directUser.userType ?? "",
      };
    } catch (e) {
      userInfoData.value = {};
    }
  }

  // refresh chat messages
  Future<void> fetchChatMessages(
      {required String groupId, bool isLoadingShow = true}) async {
    try {
      isLoadingShow ? isChatLoading(true) : null;
      Map<String, dynamic> reqModel = {
        "id": groupId,
        "timestamp": timeStamps.value,
        "offset": 0,
        "limit": limit.value
      };
      var res = await _chatRepo.getChatListApi(reqModel: reqModel);
      if (res.data!.success == true) {
        chatList.value = res.data!.chat!;
        chatList.refresh();
        isChatLoading(false);
      } else {
        chatList.value = [];
      }
    } catch (e) {
      chatList.value = [];
      isChatLoading(false);
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    chatList.clear();

    isReply.value = false;
    isMemberSuggestion.value = false;

    msgController.value.dispose();
    descriptionController.value.dispose();
    titleController.value.dispose();

    super.onClose();
  }
}
