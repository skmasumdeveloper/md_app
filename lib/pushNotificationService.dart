// ignore_for_file: unused_local_variable, file_names

import 'dart:io';

import 'package:cu_app/callkit_incoming.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_inapp_notifications/flutter_inapp_notifications.dart';
import 'package:uuid/uuid.dart';

import '/Features/Chat/Controller/chat_controller.dart';
import '/Features/Chat/Presentation/chat_screen.dart';
import '/Features/Home/Controller/group_list_controller.dart';
import '/Features/Home/Controller/socket_controller.dart';
import '/Utils/navigator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import 'services/navigation_service.dart';

// This service handles push notifications, including incoming calls and chat messages.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final chatController = Get.put(ChatController());
  final socketController = Get.put(SocketController());
  final groupListController = Get.put(GroupListController());
  String? _currentUuid;
  bool _isInitialized = false;
  BuildContext? context;

  // This method for interacting with incoming messages and setting up listeners.
  Future<void> setupInteractedMessage(Uuid appuuid) async {
    if (_isInitialized) return;
    _isInitialized = true;
    await enableIOSNotifications();
    await registerNotificationListeners();
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handlePushNotification(message);
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        _handlePushNotification(message);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      _currentUuid = appuuid.v4();
      if (message.data['msgType'] == 'incomming_call') {
        showCallkitIncoming(message.data, _currentUuid!);
      } else if (message.data['msgType'] == 'incomming_call_ended') {
        FlutterCallkitIncoming.endAllCalls();
      } else if ((message.data['msgType'] == 'meeting_created' ||
              message.data['msgType'] == 'text') &&
          chatController.groupId.value != message.data['grp']) {
        InAppNotifications.show(
            title: message.data['title'] ?? 'New Message',
            leading: Image.asset(
              "assets/icons/app-logo.png",
              width: 15,
              height: 15,
              fit: BoxFit.contain,
            ),
            duration: const Duration(seconds: 5),
            description: message.data['body'] ?? 'No Message',
            onTap: () {
              if (NavigationService.navigatorKey.currentContext != null) {
                if (chatController.isGroupCallActive.value == false) {
                  Navigator.of(NavigationService.navigatorKey.currentContext!)
                      .push(MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      groupId: message.data['grp'],
                      index: 0,
                    ),
                  ));
                }
              } else {}
            });
        // and refresh group list
        groupListController.refreshGroupList();
      } else {}

      // if message is text and in same chat then only refresh chat data
      if (message.data['msgType'] == 'text' &&
          chatController.groupId.value == message.data['grp']) {
        chatController.fetchChatMessages(
            groupId: chatController.groupId.value, isLoadingShow: false);
        print("Chat refreshed from push notification");
      }
    });
  }

  // This method handle push notifications for incoming messages.
  void _handlePushNotification(RemoteMessage message) {
    int ind = -1;
    for (int i = 0; i < groupListController.groupList.length; i++) {
      if (groupListController.groupList[i].sId.toString() ==
          message.data['grp']) {
        ind = i;
        groupListController.groupList[i].unreadCount = 0;
        groupListController.groupList.refresh();
      }
    }

    chatController.timeStamps.value = DateTime.now().millisecondsSinceEpoch;

    if (message.data['msgType'] == 'text' ||
        message.data['msgType'] == 'meeting_created') {
      Future.delayed(const Duration(milliseconds: 2000), () {
        doNavigator(
          route: ChatScreen(
            groupId: message.data['grp'],
            index: ind,
          ),
          context: Get.context!,
        );
      });
    } else {}
  }

  // This method handle foreground notifications.
  void handleForegroundNotification(RemoteMessage message) async {
    if (message.data.containsKey('call_type') &&
        message.data['call_type'] == 'video') {
      final roomId = message.data['roomId'];
      final groupId =
          message.data['groupId'] ?? roomId; // Use roomId as fallback
      final groupName = message.data['groupName'] ?? 'Group Call';
      final groupImage = message.data['groupImage'];

      final Map<String, dynamic> callData = {
        'roomId': roomId,
        'groupName': groupName,
        'groupImage': groupImage,
      };

      if (chatController.groupId.value == groupId) {
        return; // The in-chat alert will be shown by the listener in ChatScreen
      }

      if (roomId != null) {}
      return;
    }

    AndroidNotificationChannel channel = androidNotificationChannel();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final String title = message.data['title'] ?? '';
    final String body = message.data['body'] ?? '';

    if (Platform.isAndroid || Platform.isIOS) {}
  }

  Future<void> enableIOSNotifications() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: true,
    );
  }

  // This method registers notification listeners for incoming messages.
  Future<void> registerNotificationListeners() async {
    AndroidNotificationChannel channel = androidNotificationChannel();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iOSSettings);

    await flutterLocalNotificationsPlugin.initialize(initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null && response.payload!.isNotEmpty) {
        final groupId = response.payload!;

        int ind = -1;
        for (int i = 0; i < groupListController.groupList.length; i++) {
          if (groupListController.groupList[i].sId.toString() == groupId) {
            ind = i;
            groupListController.groupList[i].unreadCount = 0;
            groupListController.groupList.refresh();
            break;
          }
        }

        chatController.timeStamps.value = DateTime.now().millisecondsSinceEpoch;

        final context = NavigationService.navigatorKey.currentContext;

        if (context != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                groupId: groupId,
                index: ind,
              ),
            ),
          );
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final newContext = NavigationService.navigatorKey.currentContext;
            if (newContext != null) {
              Navigator.of(newContext).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    groupId: groupId,
                    index: ind,
                  ),
                ),
              );
            }
          });
        }
      }
    });
  }

  // This method setup the Android notification channel.
  AndroidNotificationChannel androidNotificationChannel() {
    return const AndroidNotificationChannel(
        'high_importance_channel', 'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
        playSound: true,
        showBadge: false);
  }

  String bodyMessage(String messageType, String body) {
    switch (messageType) {
      case "text":
        return body;
      case "image":
        return "Image 🏞️ ";
      case "audio":
        return "Audio 🎵";
      case "video":
        return "Video 🎬";
      case "doc":
        return "Docs 📄";
      case "call":
        return "Incoming group video call";
      case "meeting_created":
        return "Meeting scheduled";
      default:
        return body;
    }
  }

  // This method clears the FCM token.
  Future<void> clearFcmToken() async {
    await FirebaseMessaging.instance.deleteToken();
  }
}
