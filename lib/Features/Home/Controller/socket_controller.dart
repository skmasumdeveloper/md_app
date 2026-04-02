// ignore_for_file: unused_local_variable, unrelated_type_equality_checks

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Features/Group_Call_Embeded/controller/group_call_embeded_controller.dart';
import 'package:cu_app/Features/Group_Call_Embeded/group_call_embeded_config.dart';
import 'package:cu_app/Features/Group_Call_New/controller/group_call_new_controller.dart';
import 'package:cu_app/Features/Group_Call_old/controller/group_call.dart';
import 'package:cu_app/Features/Home/Controller/group_list_controller.dart';
import 'package:cu_app/Features/Login/Controller/login_controller.dart';
import 'package:cu_app/Features/Login/Presentation/login_screen.dart';
import 'package:cu_app/Features/Meetings/Controller/meeting_details_controller.dart';
import 'package:cu_app/Utils/navigator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../../Utils/storage_service.dart';
import '../../AddMembers/Controller/group_create_controller.dart';
import '../../Chat/Controller/chat_info_controller.dart';
import '../../Chat/Model/chat_list_model.dart';
import '../../Meetings/Controller/meetings_list_controller.dart';
import '../../Navigation/Controller/navigation_controller.dart';
import '../Model/group_list_model.dart';
import '../Presentation/home_screen.dart';

// This controller manages the socket connection for real-time communication in the application, handling events such as message delivery, read receipts, group updates, and user management.
class SocketController extends GetxController {
  BuildContext? context;
  IO.Socket? socket;
  RxString socketID = "".obs;
  List<Map<String, dynamic>> mesages = [];
  final chatController = Get.put(ChatController());
  final groupListController = Get.put(GroupListController());
  final loginController = Get.put(LoginController());
  final memberListController = Get.put(MemeberlistController());
  final meetingsListController = Get.put(MeetingsListController());
  final navigationController = Get.put(NavigationController());
  final meetingDetailsController = Get.put(MeetingDetailsController());
  RxBool isConnected = true.obs; // Observable for connection state
  final connectivity = Connectivity(); // Connectivity instance
  RxString msgId = "".obs;
  RxBool isAnyCallFloat = true.obs;
  late Timer pingTimer;
  String _lastJoinSelfSocketId = "";

  Map<String, String> tempMessageMapping = {};

  updateBuildContext(BuildContext context1) {
    context = context1;
  }

// This method initializes the socket connection and sets up event listeners for various socket events.
  socketConnection() {
    try {
      String userId = LocalStorage().getUserId().toString();

      // Don't initialize socket if userId is empty (not logged in)
      if (userId.isEmpty || userId == "null") {
        print('Cannot initialize socket: userId is empty');
        return;
      }

      // Disconnect existing socket if any
      if (socket != null) {
        try {
          socket?.clearListeners();
          socket?.disconnect();
          socket?.dispose();
        } catch (e) {
          print('Error disposing old socket: $e');
        }
      }

      socket = IO.io(ApiPath.socketUrl, <String, dynamic>{
        "transports": ["websocket"],
        "autoConnect": false,
        "reconnection": true,
        "reconnectionAttempts": 10,
        "reconnectionDelay": 2000,
        "timeout": 20000,
      });

      // Set up socket event listeners on connection
      socket!.on('connect', (_) {
        String socketId = socket!.id ?? "";

        print('socket connected, id ${socketId}');

        socketID.value = socketId;
        if (_lastJoinSelfSocketId != socketId) {
          socket?.emit("joinSelf", userId);
          _lastJoinSelfSocketId = socketId;
          debugPrint(
              '[Socket] connect: emitted joinSelf for socketId=$socketId');
        } else {
          debugPrint(
              '[Socket] connect: skip duplicate joinSelf for socketId=$socketId');
        }
        isConnected.value = true; // Mark as connected
        socketID.value = socketId;

        // Refresh group list after socket connects to get latest data
        groupListController.getGroupList(isLoadingShow: false);

        // Refresh chat messages and check active call if on chat screen
        try {
          if (Get.isRegistered<ChatController>()) {
            final chatCtrl = Get.find<ChatController>();
            if (chatCtrl.isChatScreen.value &&
                chatCtrl.groupId.value.isNotEmpty) {
              chatCtrl.getAllChatByGroupId(
                groupId: chatCtrl.groupId.value,
                isShowLoading: false,
              );
              chatCtrl.checkActiveCall(
                chatCtrl.groupId.value,
                isShowLoading: false,
              );
            }
          }
        } catch (_) {}

        if (socketId.isNotEmpty) {
          // Check if the new native group call module is active
          final isNewCallActive =
              Get.isRegistered<GroupCallNewController>() &&
                  Get.find<GroupCallNewController>()
                          .isAnyCallActive
                          .value ==
                      true;
          if (isNewCallActive) {
            try {
              Get.find<GroupCallNewController>().reconnect();
            } catch (_) {}
            debugPrint(
                '[Socket] connect: skip native reCallConnect (new call module active)');
            return;
          }

          final isEmbeddedCallActive = GroupCallEmbededConfig.enabled &&
              ((Get.isRegistered<GroupCallEmbededController>() &&
                      Get.find<GroupCallEmbededController>()
                              .isAnyCallActive
                              .value ==
                          true) ||
                  Get.currentRoute.contains('GroupCallEmbededScreen'));

          if (isEmbeddedCallActive) {
            try {
              Get.find<GroupCallEmbededController>().reCallConnect();
            } catch (_) {}
            debugPrint(
                '[Socket] connect: skip native reCallConnect (embedded call mode active)');
            return;
          }

          final callController = Get.put(GroupcallController());
          final storedRoomId = LocalStorage().getActiveCallRoomId();
          if (callController.isAnyCallActive.value == true &&
              (callController.currentRoomId.value.isNotEmpty ||
                  storedRoomId.isNotEmpty)) {
            if (callController.currentRoomId.value.isEmpty &&
                storedRoomId.isNotEmpty) {
              callController.currentRoomId.value = storedRoomId;
            }
            if (callController.isCallFlowBusy) {
              debugPrint(
                  '[Socket] connect: skip reCallConnect (call flow busy)');
            } else if (callController.isReconnectingCall) {
              debugPrint(
                  '[Socket] connect: skip reCallConnect (already reconnecting)');
            } else if (callController.isInitializingMediasoup) {
              debugPrint(
                  '[Socket] connect: skip reCallConnect (mediasoup init in progress)');
            } else {
              debugPrint(
                  '[Socket] connect: triggering reCallConnect room=${callController.currentRoomId.value}');
              callController.reCallConnect();
            }
          }
        } else {}
      });

      // Handle socket disconnection
      socket!.on('disconnect', (reason) {
        debugPrint(
            '[Socket] disconnected: reason=$reason connected=${socket?.connected == true} id=${socket?.id}');
        if (reason == 'transport close') {
          debugPrint(
              '[Socket] disconnected via transport close (usually local client teardown/reconnect).');
        }
        isConnected.value = false; // Mark as disconnected
      });
      // Handle socket connection errors
      socket!.on('error', (data) {
        isConnected.value = false; // Mark as disconnected
        Get.snackbar(
          "Error",
          "An error occurred with the socket connection. Please check your network.",
          snackPosition: SnackPosition.BOTTOM,
        );
      });

      // Handle socket reconnection attempts
      socket!.on('reconnect_attempt', (attempt) {});

      // socket event for receiving messages
      // Data example:
      // {
      //   "data": {
      //     "_id": "6981a271c869de1018b3091e",
      //     "groupId": "697b72a682d9808142acc4b1",
      //     "senderId": "6980abe461a8fec18ea2e405",
      //     "senderName": "testusert2",
      //     "message": "abcd",
      //     "messageType": "text",
      //     "forwarded": false,
      //     "allRecipients": [
      //       "697a10ef1debca50f7649a87",
      //       "697a10881debca50f7546820",
      //       "65e5c0c90b8812a91aa88ec1",
      //       "697c4cbda52796ec1f27fdc9",
      //       "697c4cb4a52796ec1f27fdc2",
      //       "6980abe461a8fec18ea2e405"
      //     ],
      //     "deliveredTo": [
      //       {
      //         "user": "6980abe461a8fec18ea2e405",
      //         "timestamp": "2026-02-03T07:23:29.327Z",
      //         "_id": "6981a271c869de1018b3091f",
      //         "id": "6981a271c869de1018b3091f"
      //       },
      //       {
      //         "user": "65e5c0c90b8812a91aa88ec1",
      //         "timestamp": "2026-02-03T07:23:29.327Z",
      //         "_id": "6981a271c869de1018b30920",
      //         "id": "6981a271c869de1018b30920"
      //       }
      //     ],
      //     "readBy": [
      //       {
      //         "user": {
      //           "_id": "6980abe461a8fec18ea2e405",
      //           "name": "testusert2"
      //         },
      //         "timestamp": "2026-02-03T07:23:29.327Z",
      //         "_id": "6981a271c869de1018b30921",
      //         "id": "6981a271c869de1018b30921"
      //       },
      //       {
      //         "user": {
      //           "_id": "65e5c0c90b8812a91aa88ec1",
      //           "name": "Cpscom Admin",
      //           "image": "https://cuapp.excellisit.net/uploads/1769090514470-1766490492034_lo_1.webp"
      //         },
      //         "timestamp": "2026-02-03T07:23:29.327Z",
      //         "_id": "6981a271c869de1018b30922",
      //         "id": "6981a271c869de1018b30922"
      //       }
      //     ],
      //     "readByAll": false,
      //     "deliveredToAll": false,
      //     "deletedBy": [
      //     ],
      //     "serial_key": 9312,
      //     "timestamp": "2026-02-03T07:23:29.654Z",
      //     "createdAt": "2026-02-03T07:23:29.655Z",
      //     "updatedAt": "2026-02-03T07:23:29.655Z",
      //     "__v": 0,
      //     "id": "6981a271c869de1018b3091e",
      //     "senderDataAll": {
      //       "_id": "6980abe461a8fec18ea2e405",
      //       "sl": 306,
      //       "name": "testusert2",
      //       "email": "testusert2@yopmail.com",
      //       "phone": "0000000000",
      //       "connectedDevices": [
      //       ],
      //       "userType": "user",
      //       "added_member_by": [
      //         "697a10881debca50f7546820",
      //         "65e5c0c90b8812a91aa88ec1"
      //       ],
      //       "accountStatus": "Active",
      //       "isActiveInCall": false,
      //       "applePushUnique": "",
      //       "createdAt": "2026-02-02T13:51:32.893Z",
      //       "serial_key": 295,
      //       "__v": 0,
      //       "webPushToken": "{\"endpoint\":\"https://fcm.googleapis.com/fcm/send/fomvsh-OVZo:APA91bEMV1iNg8l1WZ0mo1SENJuyYzJ_CY2NnYib2XUz_Q88_8jeYwrNPj5Kia56ExiyV2U-iIigt-19nVjcO1d0d6pIYR0V39pBEoUMtpNdThsb_wpXfNAqN-yuGD8hZYP94XdWa1FX\",\"expirationTime\":null,\"keys\":{\"p256dh\":\"BBY83Q7Hm6hNYKbOIKo25yRqqe0S8FMpfvqm3we5hnD8HcN04nLZHhtlgCKF14KRJ1s8pLvW0zGjMP9Il-lzJd0\",\"auth\":\"Hkll80SSluWTa0fVmJQBUg\"}}"
      //     }
      //   }
      // }
      socket?.on('message', (data) {
        debugPrint("socketEvent - message : ${jsonEncode(data)}");
        if ((data['data']['messageType'] == "removed") ||
            (data['data']['messageType'] == "added")) {
          groupListController.getGroupList(isLoadingShow: false);

          chatController.getGroupDetailsById(
              groupId: chatController.groupId.value,
              isShowLoading: false,
              timeStamp: chatController.timeStamps.value);
          List<dynamic> currentUser =
              data['data']['allRecipients'] as List<dynamic>;
          hideTextArea(currentUser, data['data']['groupId']);
          meetingsListController.getMeetingsList(isLoadingShow: false);
          navigationController.checkMeetingsList();
          meetingDetailsController.getMeetingDetails(
            data['data']['groupId'] ?? "",
            isUserRemoved: true,
          );
          return;
        } else {}
        var ownId = LocalStorage().getUserId();
        List<String> reciverId = List<String>.from(data['data']
            ['allRecipients']); // Creating a copy of the original list
        reciverId.removeWhere(
            (id) => id == ownId); // Remove the user id from the new list
        socket?.emit("deliver", {
          "msgId": data['data']['_id'],
          "userId": LocalStorage().getUserId().toString(),
          "timestamp": DateTime.now().millisecondsSinceEpoch,
          "receiverId": reciverId
        });

        // Find if the group exists in the list
        bool groupFound = false;
        for (int i = 0; i < groupListController.groupList.length; i++) {
          if (data['data']['groupId'] == groupListController.groupList[i].sId) {
            groupFound = true;
            if (data['data']['_id'] !=
                groupListController.groupList[i].lastMessage?.sId) {
              if (data['data']['senderId'] !=
                  LocalStorage().getUserId().toString()) {
                groupListController.groupList[i].unreadCount =
                    (groupListController.groupList[i].unreadCount ?? 0) + 1;

                groupListController.groupList[i].lastMessage = LastMessage(
                  sId: data['data']['_id'],
                  groupId: data['data']['groupId'],
                  senderId: SenderId(
                      id: data['data']['senderId'],
                      name: data['data']['senderName']),
                  senderName: data['data']['senderName'],
                  message: data['data']['message'],
                  messageType: data['data']['messageType'],
                  timestamp: data['data']['timestamp'],
                  createdAt: data['data']['createdAt'],
                );
              }
            }
          }
        }

        // If group not found in list, refresh the entire group list
        if (!groupFound && groupListController.groupList.isNotEmpty) {
          print(
              'Message received for group not in list, refreshing group list');
          groupListController.getGroupList(isLoadingShow: false);
        } else if (groupListController.groupList.isEmpty) {
          // If list is empty (e.g., just after login), fetch it
          print('Group list is empty, fetching group list');
          groupListController.getGroupList(isLoadingShow: false);
        }

        groupListController.groupList.refresh();

        groupListController.groupList.sort((a, b) {
          final aTimestamp = a.lastMessage?.timestamp;
          final bTimestamp = b.lastMessage?.timestamp;

          if (bTimestamp != null && aTimestamp != null) {
            return DateTime.parse(bTimestamp.toString()).compareTo(
              DateTime.parse(aTimestamp.toString()),
            );
          } else if (bTimestamp != null) {
            return 1;
          } else if (aTimestamp != null) {
            return -1;
          } else {
            return 0;
          }
        });
        groupListController.groupList.refresh();
        if (chatController.groupId.value == data['data']['groupId']) {
          String realMessageId = data['data']['_id'];

          if (tempMessageMapping.containsKey(realMessageId)) {
            String tempMessageId = tempMessageMapping[realMessageId]!;

            int tempMessageIndex = chatController.chatList
                .indexWhere((chat) => chat.sId == tempMessageId);

            if (tempMessageIndex != -1) {
              ChatModel updatedMessage = ChatModel.fromJson(data['data']);
              chatController.chatList[tempMessageIndex] = updatedMessage;
              chatController.chatList.refresh();

              tempMessageMapping.remove(realMessageId);
            } else {
              // Only add if message id not already present
              bool exists = chatController.chatList
                  .any((chat) => chat.sId == realMessageId);
              if (!exists) {
                chatController.chatList.add(ChatModel.fromJson(data['data']));
              }
            }
          } else {
            // Only add if message id not already present
            bool exists = chatController.chatList
                .any((chat) => chat.sId == realMessageId);
            if (!exists) {
              chatController.chatList.add(ChatModel.fromJson(data['data']));
            }
          }

          for (var element in chatController.chatList) {}
          chatController.chatList.refresh();
          String messageId = data['data']['_id'];

          socket?.emit("read", {
            "msgId": data['data']['_id'],
            "userId": LocalStorage().getUserId().toString(),
            "timestamp": DateTime.now().millisecondsSinceEpoch,
            "receiverId": reciverId
          });
        }

        if (data['data']['senderId'] !=
            LocalStorage().getUserId().toString()) {}
      });

      // socket event for message delivery
      // Data example:
      // {
      //   "msgId": "6981a2f9c869de1018b30af5",
      //   "deliveredTo": [
      //     {
      //       "user": {
      //         "_id": "697a10881debca50f7546820",
      //         "name": "Masum Admin"
      //       },
      //       "timestamp": "2026-02-03T07:25:45.196Z",
      //       "_id": "6981a2f9c869de1018b30af6",
      //       "id": "6981a2f9c869de1018b30af6"
      //     },
      //     {
      //       "user": {
      //         "_id": "65e5c0c90b8812a91aa88ec1",
      //         "name": "Cpscom Admin",
      //         "image": "https://cuapp.excellisit.net/uploads/1769090514470-1766490492034_lo_1.webp"
      //       },
      //       "timestamp": "2026-02-03T07:25:45.196Z",
      //       "_id": "6981a2f9c869de1018b30af7",
      //       "id": "6981a2f9c869de1018b30af7"
      //     },
      //     {
      //       "user": {
      //         "_id": "6980abe461a8fec18ea2e405",
      //         "name": "testusert2"
      //       },
      //       "timestamp": "2026-02-03T07:25:47.006Z",
      //       "_id": "6981a2fbc869de1018b30b0d",
      //       "id": "6981a2fbc869de1018b30b0d"
      //     }
      //   ]
      // }
      socket?.on("deliver", (data) {
        debugPrint("socketEvent - deliver: ${jsonEncode(data)}");
        final chatInfo = Get.put(ChatInfoController());
        chatInfo.chatInfo(msgId: msgId.value, isRefresh: false);
        if (data['deliverData'] == null) {
          for (int i = 0; i < chatController.chatList.length; i++) {
            if (chatController.chatList[i].sId == data['msgId'].toString()) {
              for (var element in (data['deliveredTo'] as List)) {
                if (chatController.chatList[i].deliveredTo!.length !=
                    chatController.chatList[i].allRecipients!.length) {
                  if (chatController.chatList[i].deliveredTo!
                      .every((e) => e.user != element['user']['_id'])) {
                    chatController.chatList[i].deliveredTo!
                        .add(ChatDeliveredTo(user: element['user']['_id']));
                    chatController.chatList.refresh();
                  }
                }
              }
              chatController.chatList.refresh();
            }
          }
        } else {
          final String userId = data['deliverData']['user'];
          final String timestamp = data['deliverData']['timestamp'].toString();

          for (int i = 0; i < chatController.chatList.length; i++) {
            var message = chatController.chatList[i];

            List<ChatDeliveredTo> deliveredList = message.deliveredTo ?? [];

            bool isAlreadyDelivered =
                deliveredList.any((item) => item.user == userId);

            if (!isAlreadyDelivered &&
                deliveredList.length != (message.allRecipients?.length ?? 0)) {
              deliveredList.add(ChatDeliveredTo(
                user: userId,
                timestamp: timestamp,
              ));
              message.deliveredTo = deliveredList; // update list back to object
            }
          }

          chatController.chatList.refresh();
        }
      });

      // socket event for read receipts
      // Data example:
      // {
      //   "msgId": "6981a2f9c869de1018b30af5",
      //   "readData": [
      //     {
      //       "user": {
      //         "_id": "697a10881debca50f7546820",
      //         "name": "Masum Admin"
      //       },
      //       "timestamp": "2026-02-03T07:25:45.196Z",
      //       "_id": "6981a2f9c869de1018b30af8",
      //       "id": "6981a2f9c869de1018b30af8"
      //     },
      //     {
      //       "user": {
      //         "_id": "65e5c0c90b8812a91aa88ec1",
      //         "name": "Cpscom Admin",
      //         "image": "https://cuapp.excellisit.net/uploads/1769090514470-1766490492034_lo_1.webp"
      //       },
      //       "timestamp": "2026-02-03T07:25:45.196Z",
      //       "_id": "6981a2f9c869de1018b30af9",
      //       "id": "6981a2f9c869de1018b30af9"
      //     },
      //     {
      //       "user": {
      //         "_id": "6980abe461a8fec18ea2e405",
      //         "name": "testusert2"
      //       },
      //       "timestamp": "2026-02-03T07:25:47.006Z",
      //       "_id": "6981a2fbc869de1018b30b0f",
      //       "id": "6981a2fbc869de1018b30b0f"
      //     }
      //   ]
      // }
      socket?.on("read", (data) {
        final chatInfo = Get.put(ChatInfoController());
        debugPrint("socketEvent - read: ${jsonEncode(data)}");
        if (data['msgId'] != null) {
          for (int i = 0; i < chatController.chatList.length; i++) {
            if (chatController.chatList[i].sId == data['msgId'].toString()) {
              chatController.chatList[i].readBy = (data['readData'] as List)
                  .map((e) => ChatReadBy.fromJson(e))
                  .toList();
              chatController.chatList.refresh();
              chatInfo.chatInfo(
                  msgId: data['msgId'].toString(), isRefresh: false);
            }
          }
        } else {
          for (int i = 0; i < chatController.chatList.length; i++) {
            final String userId = data['readData']['user'];
            final String timestamp = data['readData']['timestamp'].toString();

            List<ChatReadBy> readByList =
                chatController.chatList[i].readBy ?? [];

            bool isAlreadyRead =
                readByList.any((item) => item.user?.sId == userId);

            if (!isAlreadyRead) {
              readByList.add(ChatReadBy(
                user: User(sId: userId),
                timestamp: timestamp,
              ));

              chatController.chatList[i].readBy = readByList;
            }

            chatController.chatList.refresh();
          }
        }
      });

      // socket event for new group creation
      socket?.on("newgroup", (data) {
        debugPrint("socketEvent - newgroup: ${jsonEncode(data)}");
        meetingsListController.getMeetingsList(isLoadingShow: false);
        navigationController.checkMeetingsList();
        groupListController.getGroupList(isLoadingShow: false);
      });

      // socket event for user updates
      socket?.on("updated-User", (data) {
        debugPrint("socketEvent - updated-User: ${jsonEncode(data)}");
        loginController.getUserProfile(isrefresh: false);
        memberListController.getMemberList(
            isLoaderShowing: false,
            searchQuery: memberListController.searchText.value);
        meetingsListController.getMeetingsList(isLoadingShow: false);
        navigationController.checkMeetingsList();
        chatController.getGroupDetailsById(
            groupId: chatController.groupId.value,
            isShowLoading: false,
            timeStamp: chatController.timeStamps.value);
      });

      // socket event for group updates
      socket?.on("update-group", (data) {
        debugPrint("socketEvent - update-group: ${jsonEncode(data)}");
        meetingsListController.getMeetingsList(isLoadingShow: false);
        meetingDetailsController.getMeetingDetails(data['data']['data']['_id'],
            isLoadingShow: false);
        navigationController.checkMeetingsList();
      });

      // socket event for user updates
      socket?.on("user_upadate", (data) {
        debugPrint("socketEvent - user_upadate: ${jsonEncode(data)}");
        meetingsListController.getMeetingsList(isLoadingShow: false);
        navigationController.checkMeetingsList();
      });

      // socket event for group updates
      // Data example:
      // {
      //   "data": {
      //     "success": true,
      //     "message": "User added successfully",
      //     "data": {
      //       "_id": "6981a529186f000eb3b26972",
      //       "groupName": "rryewryw",
      //       "groupDescription": "rywfhshs",
      //       "currentUsers": [
      //         "6980abe461a8fec18ea2e405",
      //         "697a10ef1debca50f7649a87",
      //         "697a10881debca50f7546820",
      //         "65e5c0c90b8812a91aa88ec1",
      //         "697c4cc4a52796ec1f27fdd0"
      //       ],
      //       "admins": [
      //         "697a10881debca50f7546820",
      //         "65e5c0c90b8812a91aa88ec1"
      //       ],
      //       "isTemp": false,
      //       "isDirect": false,
      //       "createdBy": "697a10881debca50f7546820",
      //       "link": "https://cuapp.excellisit.net/messages?pin=887339&groupId=6981a529186f000eb3b26972",
      //       "pin": "887339",
      //       "meetingStartTime": null,
      //       "meetingEndTime": null,
      //       "createdByTimeZone": "UTC",
      //       "googleEventId": null,
      //       "serial_key": 512,
      //       "previousUsers": [
      //       ],
      //       "createdAt": "2026-02-03T07:35:05.948Z",
      //       "updatedAt": "2026-02-03T07:49:45.071Z",
      //       "__v": 1,
      //       "id": "6981a529186f000eb3b26972"
      //     }
      //   }
      // }
      socket?.on("updated", (data) {
        debugPrint("socketEvent - updated: ${jsonEncode(data)}");
        final chatController = Get.put(ChatController());
        groupListController.getGroupList(isLoadingShow: false);
        chatController.getGroupDetailsById(
            groupId: chatController.groupId.value,
            isShowLoading: false,
            timeStamp: chatController.timeStamps.value);
        List<dynamic> currentUser =
            data['data']['data']['currentUsers'] as List<dynamic>;
        hideTextArea(currentUser, data['data']['data']['_id']);

        meetingsListController.getMeetingsList(isLoadingShow: false);
        meetingDetailsController.getMeetingDetails(data['data']['data']['_id'],
            isLoadingShow: false);
        navigationController.checkMeetingsList();
      });

      // socket event for group deletion (server uses "delete-Group")
      // Data example:
      // {
      //   "data": {
      //     "_id": "6981a529186f000eb3b26972",
      //     "groupName": "changedGroup name test",
      //     "groupDescription": "rywfhshs",
      //     "currentUsers": [
      //       "6980abe461a8fec18ea2e405",
      //       "697a10ef1debca50f7649a87",
      //       "697a10881debca50f7546820",
      //       "65e5c0c90b8812a91aa88ec1",
      //       "697c4cc4a52796ec1f27fdd0"
      //     ],
      //     "admins": [
      //       "697a10881debca50f7546820",
      //       "65e5c0c90b8812a91aa88ec1"
      //     ],
      //     "isTemp": false,
      //     "isDirect": false,
      //     "createdBy": "697a10881debca50f7546820",
      //     "link": "https://cuapp.excellisit.net/messages?pin=887339&groupId=6981a529186f000eb3b26972",
      //     "pin": "887339",
      //     "meetingStartTime": null,
      //     "meetingEndTime": null,
      //     "createdByTimeZone": "UTC",
      //     "googleEventId": null,
      //     "serial_key": 512,
      //     "previousUsers": [
      //     ],
      //     "createdAt": "2026-02-03T07:35:05.948Z",
      //     "updatedAt": "2026-02-03T07:52:28.376Z",
      //     "__v": 1,
      //     "id": "6981a529186f000eb3b26972"
      //   }
      // }
      socket?.on("delete-Group", (data) {
        debugPrint("socketEvent - delete-Group: ${jsonEncode(data)}");
        groupListController.getGroupList(isLoadingShow: false);
        meetingsListController.getMeetingsList(isLoadingShow: false);
        navigationController.checkMeetingsList();
        meetingDetailsController.getMeetingDetails(
          data['data']['_id'] ?? "",
          isUserRemoved: true,
        );
        if (chatController.groupId.value == data['data']['_id']) {
          doNavigateWithReplacement(
              route: const HomeScreen(
                isDeleteNavigation: true,
              ),
              context: Get.context!);
        }
      });

      // socket event for group deletion (alternate event name used by web: "deleteGroup")
      socket?.on("deleteGroup", (data) {
        debugPrint("socketEvent - deleteGroup: ${jsonEncode(data)}");
        try {
          // data is expected to be the deleted group object
          final groupData = data is Map
              ? data
              : (data is List && data.isNotEmpty ? data[1] : null);
          final String groupId =
              (groupData?['_id'] ?? groupData?['id'] ?? '').toString();

          groupListController.getGroupList(isLoadingShow: false);
          meetingsListController.getMeetingsList(isLoadingShow: false);
          navigationController.checkMeetingsList();

          meetingDetailsController.getMeetingDetails(groupId,
              isUserRemoved: true);

          final List<dynamic> currentUsers =
              (groupData?['currentUsers'] is List)
                  ? (groupData['currentUsers'] as List<dynamic>)
                  : <dynamic>[];

          final String myId = LocalStorage().getUserId();

          final bool amAffected = (chatController.groupId.value == groupId) ||
              currentUsers.contains(myId);

          if (amAffected && Get.context != null) {
            doNavigateWithReplacement(
                route: const HomeScreen(isDeleteNavigation: true),
                context: Get.context!);
          }
        } catch (e) {
          debugPrint('Error handling deleteGroup socket event: $e');
        }
      });

      // socket event for user deletion
      socket?.on("deleted-User", (data) async {
        debugPrint("socketEvent - deleted-User: ${jsonEncode(data)}");
        groupListController.getGroupList(isLoadingShow: false);
        if (data['data']['_id'] == LocalStorage().getUserId()) {
          final isLoggedOut = await loginController.logout();
          if (isLoggedOut == true) {
            loginController.emailController.value.clear();
            loginController.passwordController.value.clear();
            loginController.isPasswordVisible(true);
            Get.delete<SocketController>();
            socket?.clearListeners();
            socket?.destroy();
            socket?.dispose();
            socket?.disconnect();
            socket?.io.disconnect();
            socket?.io.close();
            socket = null; // Ensure the socket is nullified
            LocalStorage().deleteAllLocalData();
            Get.delete<NavigationController>();
            Get.delete<GroupcallController>();
            doNavigateWithReplacement(
                route: const LoginScreen(), context: Get.context!);
          }
        }

        meetingsListController.getMeetingsList(isLoadingShow: false);
        navigationController.checkMeetingsList();
      });

      // socket event for user addition/removal
      socket?.on("addremoveuser", (data) {
        debugPrint("socketEvent - addremoveuser: ${jsonEncode(data)}");
        groupListController.getGroupList(isLoadingShow: false);
        meetingsListController.getMeetingsList(isLoadingShow: false);
        navigationController.checkMeetingsList();
        meetingDetailsController.getMeetingDetails(
          data['data']['groupId'] ?? "",
        );
      });

      // socket event for user addition/removal
      // Data example:
      // {
      //   "data": {
      //     "_id": "697b72a682d9808142acc4b1",
      //     "groupName": "21211212G",
      //     "groupDescription": "test",
      //     "currentUsers": [
      //       "697a10ef1debca50f7649a87",
      //       "697a10881debca50f7546820",
      //       "65e5c0c90b8812a91aa88ec1",
      //       "6980abe461a8fec18ea2e405"
      //     ],
      //     "admins": [
      //       "697a10881debca50f7546820",
      //       "65e5c0c90b8812a91aa88ec1"
      //     ],
      //     "isTemp": false,
      //     "isDirect": false,
      //     "createdBy": "697a10881debca50f7546820",
      //     "link": "https://cuapp.excellisit.net/messages?pin=896071&groupId=697b72a682d9808142acc4b1",
      //     "pin": "896071",
      //     "meetingStartTime": null,
      //     "meetingEndTime": null,
      //     "createdByTimeZone": "UTC",
      //     "googleEventId": null,
      //     "previousUsers": [
      //     ],
      //     "createdAt": "2026-01-29T14:45:58.804Z",
      //     "updatedAt": "2026-02-03T09:30:32.148Z",
      //     "__v": 13,
      //     "serial_key": 497,
      //     "groupImage": "https://cuapp.excellisit.net/uploads/1770109727328-scaled_38f2faf3-e868-414f-a223-17531b4571bf4507602190904582913.jpg",
      //     "id": "697b72a682d9808142acc4b1"
      //   }
      // }
      socket?.on("addremoveuser2", (data) {
        debugPrint("socketEvent - addremoveuser2: ${jsonEncode(data)}");
        groupListController.getGroupList(isLoadingShow: false);
        meetingsListController.getMeetingsList(isLoadingShow: false);
        navigationController.checkMeetingsList();
      });

      // socket event for meeting creation
      // Data example:
      // {
      //   "data": {
      //     "groupName": "4342",
      //     "groupDescription": "4464623",
      //     "currentUsers": [
      //       "697a10ef1debca50f7649a87",
      //       "6980abe461a8fec18ea2e405",
      //       "6981bc52186f000eb3b2fed7",
      //       "697a10881debca50f7546820",
      //       "65e5c0c90b8812a91aa88ec1"
      //     ],
      //     "admins": [
      //       "697a10881debca50f7546820",
      //       "65e5c0c90b8812a91aa88ec1"
      //     ],
      //     "isTemp": true,
      //     "isDirect": false,
      //     "createdBy": "697a10881debca50f7546820",
      //     "link": "https://cuapp.excellisit.net/messages?pin=735731&groupId=6981bd23186f000eb3b2feea",
      //     "pin": "735731",
      //     "meetingStartTime": "2026-02-03T09:20:00.000Z",
      //     "meetingEndTime": "2026-02-03T09:35:00.000Z",
      //     "createdByTimeZone": "UTC",
      //     "googleEventId": null,
      //     "serial_key": 512,
      //     "_id": "6981bd23186f000eb3b2feea",
      //     "previousUsers": [
      //     ],
      //     "createdAt": "2026-02-03T09:17:23.723Z",
      //     "updatedAt": "2026-02-03T09:17:23.723Z",
      //     "__v": 0,
      //     "id": "6981bd23186f000eb3b2feea"
      //   }
      // }
      socket?.on("meeting_created", (data) {
        debugPrint("socketEvent - meeting_created: ${jsonEncode(data)}");
        List<dynamic> currentUser =
            data['data']['currentUsers'] as List<dynamic>;

        if (currentUser.contains(LocalStorage().getUserId().toString())) {
          meetingsListController.getMeetingsList(isLoadingShow: false);
          navigationController.checkMeetingsList();
        }
      });

      // on delete message get from another user so delete that message from my chats
      // Data example:
      // {
      //   "data": {
      //     "groupId": "697b72a682d9808142acc4b1",
      //     "userId": "697a10881debca50f7546820",
      //     "receiverId": [
      //       "697a10ef1debca50f7649a87",
      //       "697a10881debca50f7546820",
      //       "65e5c0c90b8812a91aa88ec1",
      //       "697c4cb4a52796ec1f27fdc2",
      //       "6980abe461a8fec18ea2e405",
      //       "697c4caca52796ec1f27fdbb"
      //     ],
      //     "deleteMsg": "6981bddf186f000eb3b3011b"
      //   }
      // }
      socket?.on("delete-message", (data) {
        debugPrint("socketEvent - delete-message: ${jsonEncode(data)}");
        String ownId = LocalStorage().getUserId();
        if (data['data']['userId'] != ownId) {
          if (chatController.groupId.value == data['data']['groupId']) {
            chatController.chatList
                .removeWhere((msg) => msg.sId == data['data']['deleteMsg']);
            chatController.chatList.refresh();
          }
        }

        // refresh/remove the message also from group list
        groupListController.getGroupList(isLoadingShow: false);
      });

      socket?.onError((data) {
        String payload;
        try {
          payload = jsonEncode(data);
        } catch (_) {
          payload = data.toString();
        }
        debugPrint("socketEvent - error: $payload");
      });
    } catch (e) {
      debugPrint("Socket connection error: $e");
    }
  }

// This method reconnects the socket if it is disconnected or not initialized.
  void reconnectSocket() {
    if (socket == null) {
      socketConnection();
    } else if (!(socket?.connected ?? false)) {
      socket?.connect();
    }
  }

// This method monitors the connectivity status and reconnects the socket when the internet is back.
  void monitorConnectivity(bool isFirstTime) {
    connectivity.onConnectivityChanged.listen((result) {
      if (!isFirstTime) {
        if (result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet) {
          reconnectSocket(); // Reconnect socket when internet is back
          groupListController.getGroupList(isLoadingShow: false);
          chatController.getAllChatByGroupId(
              groupId: chatController.groupId.value, isShowLoading: false);
        }
      } else {
        isFirstTime = false;
      }
    });
  }

// This method initializes the socket connection and starts monitoring connectivity.
  socketInitialization() {
    monitorConnectivity(true);
    startPing();
  }

  @override
  void onInit() {
    super.onInit();
    socketInitialization();
  }

  @override
  void onClose() {
    socket?.disconnect();
    socket?.dispose();

    pingTimer.cancel();
    super.onClose();
  }

// This method hides the text area if the current user is not part of the group.
  void hideTextArea(List<dynamic> currentUser, String groupIdFromSocket) {
    if (chatController.groupId.value == groupIdFromSocket &&
        !(currentUser.contains(LocalStorage().getUserId()))) {
      doNavigateWithReplacement(
          route: const HomeScreen(
            isDeleteNavigation: true,
          ),
          context: Get.context!);
    } else {
      null;
    }
  }

// This method starts a periodic ping to the socket server to check if the connection alive.
  void startPing() {
    pingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (socket != null && socket!.connected) {
        socket!.emit('ping', {'userId': LocalStorage().getUserId()});
      } else {
        reconnectSocket();
      }
    });
  }
}
