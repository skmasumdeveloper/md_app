//import 'dart:developer';
import 'dart:io';
import 'package:cu_app/Features/AddMembers/Model/members_model.dart';
import 'package:cu_app/Features/AddMembers/Repo/member_repo.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Features/Home/Controller/group_list_controller.dart';
import 'package:cu_app/Features/Home/Controller/socket_controller.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Widgets/toast_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../Meetings/Controller/meetings_list_controller.dart';
import '../../Meetings/Model/meetings_list_model.dart';
import '../../Meetings/Presentation/meeting_details_screen.dart';

// This controller handles the logic for managing members in a group, including adding and removing members, creating groups, and handling member selection.
class MemeberlistController extends GetxController {
  var grpNameController = TextEditingController().obs;
  var grpDescController = TextEditingController().obs;
  final memebrListRepo = MemberlistRepo();
  final groupListController = Get.put(GroupListController());
  RxBool isUserChecked = true.obs;

  RxList<MemberListMdoel> memberList = <MemberListMdoel>[].obs;
  RxList<String> memberId = <String>[].obs;
  RxList<MemberListMdoel> memberSelectedList = <MemberListMdoel>[].obs;
  RxSet<String> excludedMemberIds = <String>{}.obs;

  RxBool isMemberListLoading = false.obs;
  RxInt limit = 20.obs;
  RxInt page = 1.obs;
  RxBool hasMore = true.obs;
  RxString searchText = "".obs;
  RxString images = "".obs;
  Rx<File?> imageFile = Rx<File?>(null);

// This method to pick an image from the gallery or camera.
  Future<void> pickImage({required ImageSource imageSource}) async {
    try {
      final image = await ImagePicker().pickImage(
        source: imageSource,
        maxHeight: 512,
        maxWidth: 512,
        imageQuality: 75,
      );
      if (image == null) return;
      var fileImage = File(image.path);
      imageFile.value = fileImage;
      images.value = fileImage.path;
    } on PlatformException catch (e) {
      debugPrint("Failed to pick image: $e");
    }
  }

  RxList<String> updateMemberId = <String>[].obs;
  RxList<String> updtaeMemberName = <String>[].obs;
  checkBoxTrueFalse(
      dynamic v, String id, MemberListMdoel mmberListModel, String groupId) {
    if (v != null && v) {
      memberId.add(id);
      memberSelectedList.add(mmberListModel);
      groupId.isNotEmpty ? updateMemberId.add(id) : null;
      groupId.isNotEmpty
          ? updtaeMemberName.add(mmberListModel.name ?? "")
          : null;
    } else {
      memberId.remove(id);
      memberSelectedList.remove(mmberListModel);
      groupId.isNotEmpty ? updateMemberId.remove(id) : null;
      groupId.isNotEmpty ? updtaeMemberName.remove(mmberListModel.name) : null;
    }
  }

// This method fetches the list of members for a group.
  getMemberList({bool isLoaderShowing = true, String? searchQuery}) async {
    try {
      isLoaderShowing ? isMemberListLoading(true) : null;
      final currentPage = page.value;
      var res = await memebrListRepo.getMemberList(
          searchQuery: searchText.value, page: currentPage, limit: limit.value);
      if (res.data!.success == true) {
        final filteredList = (res.data!.memberList ?? [])
            .where((member) => !excludedMemberIds.contains(member.sId))
            .toList();
        if (currentPage == 1) {
          memberList.value = filteredList;
        } else {
          if (filteredList.isEmpty) {
            hasMore(false);
          } else {
            memberList.addAll(filteredList);
            memberList.refresh();
          }
        }
        isMemberListLoading(false);
      } else {
        if (currentPage == 1) memberList.value = [];
        isMemberListLoading(false);
      }
    } catch (e) {
      if (page.value == 1) memberList.value = [];
      isMemberListLoading(false);
    }
  }

  void setExcludedMembers(List<String> ids) {
    excludedMemberIds.value = ids.toSet();
  }

  RxBool isDeleteWaiting = false.obs;
  // This method deletes a user from the group.
  Future<bool> deleteUserFromGroup(
      {required String groupId,
      required String userId,
      required String userName}) async {
    if (isDeleteWaiting.value) return false;
    final socketController = Get.find<SocketController>();
    final chatController = Get.put(ChatController());
    try {
      Map<String, dynamic> reqModel = {"groupId": groupId, "userId": userId};
      isDeleteWaiting(true);
      var res = await memebrListRepo.deleteMemberFromGroup(reqModel: reqModel);
      if (res.data != null && res.data!['success'] == true) {
        socketController.socket!.emit("addremoveuser", res.data!['data']);
        socketController.socket!.emit("update-group", res.data!['data']);
        final ownId = LocalStorage().getUserId();
        final userIds = (chatController.groupModel.value.currentUsers ?? [])
            .map((user) => user.sId)
            .whereType<String>()
            .where((id) => id != ownId)
            .toList();
        if (userIds.isNotEmpty) {
          await chatController.sendMsg(
              replyOf: chatController.isReply.value == true
                  ? chatController.replyOf
                  : null,
              msg: "$userName has been removed from the group.",
              reciverId: userIds,
              groupId: groupId,
              msgType: "removed");
        }
        TostWidget().successToast(
            title: "Success", message: "Member removed successfully");
        isDeleteWaiting(false);
        return true;
      } else {
        final errorMessage =
            (res.data?['message']?.toString().trim().isNotEmpty ?? false)
                ? res.data!['message'].toString()
                : "Failed to remove member";
        TostWidget().errorToast(title: "Error", message: errorMessage);
        isDeleteWaiting(false);
        return false;
      }
    } catch (e) {
      TostWidget()
          .errorToast(title: "Error", message: "Failed to remove member");
      isDeleteWaiting(false);
      return false;
    }
  }

  RxBool addingGroup = false.obs;
  // This method adds a member to the group.
  Future<void> addGroupMember(
      {required String groupId,
      required List<String> userId,
      required List<String> userName,
      bool isMeeting = false,
      required BuildContext context}) async {
    final chatController = Get.put(ChatController());
    try {
      final socketController = Get.find<SocketController>();
      Map<String, dynamic> reqModel = {"groupId": groupId, "userId": userId};
      addingGroup(true);
      var res = await memebrListRepo.addMemberInGroup(reqModel: reqModel);
      if (res.data!['success'] == true) {
        TostWidget()
            .successToast(title: "Success", message: res.data!['message']);
        socketController.socket!.emit("addremoveuser", res.data!['data']);
        socketController.socket!.emit("update-group", res.data!['data']);
        var ownId = LocalStorage().getUserId();
        List<String>? userIds = chatController.groupModel.value.currentUsers!
            .map((user) => user.sId!)
            .where((userId) => userId != ownId)
            .toList();
        for (int i = 0; i < userName.length; i++) {
          await chatController.sendMsg(
              replyOf: chatController.isReply.value == true
                  ? chatController.replyOf
                  : null,
              msg: "${userName[i]} has joined the group.",
              reciverId: userIds,
              groupId: groupId,
              msgType: "added");
        }
        await chatController.getGroupDetailsById(groupId: groupId);

        if (isMeeting == true) {
          final meetingsController = Get.put(MeetingsListController());
          await meetingsController.getMeetingCallDetails(groupId);
          meetingsController.getMeetingsList(isLoadingShow: false);

          final MeetingModel? meeting = meetingsController.meetingsList
              .firstWhereOrNull((m) => m.sId == groupId);

          Navigator.pop(context, true);
          addingGroup(false);
          updateMemberId.clear();
          updtaeMemberName.clear();
        } else {
          Navigator.pop(context, true);
          addingGroup(false);
          updateMemberId.clear();
          updtaeMemberName.clear();
        }
      } else {
        addingGroup(false);
        updateMemberId.clear();
      }
    } catch (e) {
      addingGroup(false);
      updateMemberId.clear();
    }
  }

  RxBool isGroupCreateLoading = false.obs;
// This method creates a new group with the selected members.
  createGroup(BuildContext context) async {
    final socketController = Get.find<SocketController>();
    // var userId = LocalStorage().getUserId();
    RxList<String> userIds = memberId;
    userIds.value = userIds.toSet().toList();

    try {
      isGroupCreateLoading(true);
      var res = await memebrListRepo.createNewGroup(
          groupName: grpNameController.value.text,
          memberId: memberId,
          groupDescription: grpDescController.value.text,
          file: images.value.isNotEmpty ? File(images.value) : null);

      if (res.data!['success'] == true) {
        TostWidget()
            .successToast(title: "Success", message: res.data!['message']);
        Map<String, dynamic> reqModeSocket = {
          "currentUsers": res.data!['data']['currentUsers'],
          "_id": res.data!['data']['_id']
        };

        socketController.socket!.emit("creategroup", reqModeSocket);

        isGroupCreateLoading(false);
        dataClearAfterAdd();

        Navigator.pop(context);
        Navigator.pop(context);
        Navigator.pop(context);
      } else {
        TostWidget().errorToast(title: "Error", message: res.data!['message']);
        isGroupCreateLoading(false);
      }
    } catch (e) {
      TostWidget().errorToast(title: "Error", message: e.toString());
      isGroupCreateLoading(false);
    }
  }

// This method clears the form fields after adding a group.
  dataClearAfterAdd() {
    grpNameController.value.clear();
    grpDescController.value.clear();
    memberId.clear();
    memberSelectedList.clear();
    imageFile.value = null;
    images.value = "";
  }
}
