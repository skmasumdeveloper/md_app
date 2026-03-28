// import 'dart:developer';
import 'package:cu_app/Features/AllMembers/model/all_members_model.dart';
import 'package:cu_app/Features/AllMembers/repo/all_members_repo.dart';
import 'package:cu_app/Features/Home/Model/group_list_model.dart';
import 'package:cu_app/Features/Chat/Repo/chat_repo.dart';
import 'package:cu_app/Features/Chat/Presentation/chat_screen.dart';
import 'package:cu_app/Features/Home/Controller/socket_controller.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Widgets/toast_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cu_app/Features/EditMember/presentation/edit_member_screen.dart';

// This controller handles the logic for fetching and managing all members in the application.
class AllMembersController extends GetxController {
  final AllMembersRepo _allMembersRepo = AllMembersRepo();

//  final RxBool isLoading = false.obs;
  final RxList<MemberData> membersList = <MemberData>[].obs;
  final RxList<MemberData> filteredMembersList = <MemberData>[].obs;
  RxBool isListLoading = false.obs;
  final RxString searchQuery = ''.obs;
  RxInt limit = 20.obs;
  RxString searchText = "".obs;

// This method fetches all members from the repository and updates the state.
  Future<void> getAllMembers({bool isLoadingShow = true}) async {
    try {
      isLoadingShow ? isListLoading(true) : isListLoading(false);

      final response = await _allMembersRepo.getAllMembers(
          searchQuery: searchText.value, offset: 0, limit: limit.value);
      print('all members: ${response}');

      if (response.data?.success == true && response.data?.data?.data != null) {
        membersList.assignAll(response.data!.data!.data!);
        filteredMembersList.assignAll(response.data!.data!.data!);
      } else {
        TostWidget().errorToast(
          title: "Error",
          message: response.errorMessage ?? "Failed to fetch members",
        );
      }
    } catch (e) {
      TostWidget().errorToast(
        title: "Error",
        message: "An error occurred while fetching members",
      );
    } finally {
      isListLoading.value = false;
    }
  }

// This method filters the members list based on the search query.
  // void searchMembers(String query) {
  //   searchQuery.value = query;
  //   if (query.isEmpty) {
  //     filteredMembersList.assignAll(membersList);
  //   } else {
  //     filteredMembersList.assignAll(
  //       membersList
  //           .where((member) =>
  //               member.name?.toLowerCase().contains(query.toLowerCase()) ==
  //                   true ||
  //               member.email?.toLowerCase().contains(query.toLowerCase()) ==
  //                   true)
  //           .toList(),
  //     );
  //   }
  // }

// This method formats the date and time for display.
  String formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('MMMM dd, yyyy\nh:mm a').format(dateTime);
    } catch (e) {
      return '';
    }
  }

// This method returns a color based on the member's status.
  Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return const Color(0xFF4CAF50);
      case 'inactive':
        return const Color(0xFFF44336);
      case 'pending':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

// This method navigates to the EditMemberScreen to edit a member's details.
  void editMember(MemberData member) {
    Get.to(
      () => const EditMemberScreen(),
      arguments: member,
    );
  }

// This method deletes a member from the list.
  void deleteMember(MemberData member) {
    Get.dialog(
      AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${member.name}?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              deleteUser(member.sId!);

              Get.back();
              TostWidget().successToast(
                title: "Success",
                message: "User deleted successfully",
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF44336)),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFFFFFFF))),
          ),
        ],
      ),
    );
  }

// This method deletes a user by their ID and updates the members list.
  Future<void> deleteUser(String userId) async {
    try {
      isListLoading.value = true;
      final response = await _allMembersRepo.deleteMember(userId);

      if (response.data?.success == true) {
        membersList.removeWhere((member) => member.sId == userId);
        filteredMembersList.removeWhere((member) => member.sId == userId);
      } else {
        TostWidget().errorToast(
          title: "Error",
          message: response.errorMessage ?? "Failed to delete member",
        );
      }
    } catch (e) {
      TostWidget().errorToast(
        title: "Error",
        message: "An error occurred while deleting the member",
      );
    } finally {
      isListLoading.value = false;
    }
  }

// This method initiates a direct chat with the selected member.
  void directChat(MemberData member) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );
      var response = await _allMembersRepo.createDirectChat(member.sId ?? "");

      if (response.statusCode == 200 && response.data != null) {
        var groupData = response.data!;
        var groupId = groupData.sId ?? "";

        print('send message response isNew : ${response.data!.isNew}');

        var isNewChat = response.data!.isNew ?? false;

        if (groupId.isNotEmpty) {
          // Send Hi message
          var chatRepo = ChatRepo();
          var myId = LocalStorage().getUserId();
          var myName = LocalStorage().getUserName();

          if (isNewChat) {
            // Avoid sending duplicate initial "Hi" if server already created it
            final existingLastMsg =
                groupData.lastMessage?.message?.trim().toLowerCase() ?? '';
            if (existingLastMsg != 'hi') {
              // API Call
              var sendRes = await chatRepo.sendMessage(
                  groupId: groupId,
                  senderName: myName,
                  message: "Hi",
                  messageType: "text",
                  replyOf: null);

              if (sendRes.statusCode == 200 || sendRes.statusCode == 201) {
                // Emit Socket
                try {
                  final socketController = Get.isRegistered<SocketController>()
                      ? Get.find<SocketController>()
                      : Get.put(SocketController());

                  // Calculate receivers
                  List<String> receiverId = (groupData.currentUsers ?? [])
                      .map((u) => u.sId!)
                      .where((id) => id != myId)
                      .toList();

                  Map<String, dynamic> reqModeSocket = {
                    "replyOf": null,
                    "_id": sendRes.data!['data']['data']['id'],
                    "receiverId": receiverId,
                    "senderId": myId,
                    "time": DateFormat('hh:mm a').format(DateTime.now()),
                  };
                  socketController.socket?.emit("message", reqModeSocket);
                } catch (e) {
                  print("Socket error: $e");
                }
              }
            } else {
              // Server already created initial message; skip sending another
              print('Skipping sending duplicate initial Hi message');
            }
          }

          Get.back(); // Close Loader
          // Navigate
          Get.to(() => ChatScreen(groupId: groupId));
        } else {
          Get.back();
        }
      } else {
        Get.back();
        TostWidget().errorToast(
            title: "Error",
            message: response.errorMessage ?? "Failed to create chat");
      }
    } catch (e) {
      Get.back();
      TostWidget()
          .errorToast(title: "Error", message: "Something went wrong $e");
    }
  }

// This method refreshes the members list by fetching all members again.
  void refreshMembers() {
    getAllMembers();
  }

  @override
  void onClose() {
    membersList.clear();
    filteredMembersList.clear();
    searchQuery.value = '';
    searchText.value = '';
    super.onClose();
  }
}
