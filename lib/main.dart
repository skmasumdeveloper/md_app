// ignore_for_file: unused_local_variable, unused_field

import 'dart:async';
import 'dart:convert';

import 'package:cu_app/Commons/app_strings.dart';
import 'package:cu_app/Features/Group_Call_Embeded/controller/group_call_embeded_controller.dart';
import 'package:cu_app/Features/Group_Call_Embeded/group_call_embeded_config.dart';
import 'package:cu_app/Features/Group_Call_New/controller/group_call_new_controller.dart';
import 'package:cu_app/Features/Group_Call_New/group_call_new_config.dart';
import 'package:cu_app/Features/Group_Call_old/controller/group_call.dart';

import 'package:cu_app/Utils/dismis_keyboard.dart';
import 'package:cu_app/global_bloc.dart';
import 'package:cu_app/pushNotificationService.dart';
import 'package:cu_app/services/navigation_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_inapp_notifications/flutter_inapp_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cu_app/Features/Meetings/Model/calendar_event_model.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'Commons/platform_channels.dart';
import 'Commons/theme.dart';
import 'Commons/theme_controller.dart';
import 'Features/Chat/Presentation/chat_screen.dart';
import 'Features/Home/Controller/group_list_controller.dart';
import 'Features/Home/Controller/socket_controller.dart';
import 'Features/Splash/Presentation/splash_screen.dart';
import 'Utils/app_preference.dart';
import 'background/background_socket_controller.dart';
import 'callkit_incoming.dart';
import 'firebase_options.dart';
import 'package:uuid/uuid.dart';

import 'main_network_controller.dart';
import 'Utils/deep_link_service.dart';
import 'services/ios_logger.dart';
import 'services/system_pip_view.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

// This is used for handling background messages in the application. It initializes Firebase, sets up push notifications, and runs the app.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await GetStorage.init();
  } catch (e) {
    debugPrint('GetStorage init failed in background: $e');
  }

  if (message.data['msgType'] == 'incomming_call' ||
      message.data['msgType'] == 'incoming_call') {
    // Initialize dotenv for background isolate
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint('Failed to load .env in background: $e');
    }
    showCallkitIncoming(message.data, const Uuid().v4());
  } else if (message.data['msgType'] == 'incomming_call_ended' ||
      message.data['msgType'] == 'incoming_call_ended') {
    FlutterCallkitIncoming.endAllCalls();
  } else {
    var ownId = GetStorage().read("userId") ?? "";

    final bgSocket = BackgroundSocketController();
    // await bgSocket.initSocket();

    try {
      List<String> receiverId = List<String>.from(
          jsonDecode(message.data['allrecipants']) as List<dynamic>);
      receiverId.removeWhere((id) => id == ownId);

      bgSocket.emitDelivery(
        msgId: message.data['msgId'],
        userId: ownId,
        receiverId: receiverId,
      );
    } catch (e) {
      debugPrint('Error emitting delivery: $e');
    }
  }
}

// This method configures the notification settings for the app.
Future<void> notificationConfig(Uuid uuid) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // get permissions
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

// Save fcm token
  final fcmToken = await FirebaseMessaging.instance.getToken();
  AppPreference().saveFirebaseToken(token: fcmToken ?? "");

  // save apple device token
  final pushKitToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
  AppPreference().saveApplePushToken(token: pushKitToken ?? "");

  // handle fcm
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService().setupInteractedMessage(uuid);

  await FlutterCallkitIncoming.requestNotificationPermission({
    "rationaleMessagePermission":
        "Notification permission is required to show calls.",
    "postNotificationMessageRequired":
        "Please allow notification permission from settings."
  });

  await FlutterCallkitIncoming.requestFullIntentPermission();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await GetStorage.init();
  // initialize timezone database used for device calendar TZDateTime conversions
  try {
    tzdata.initializeTimeZones();
    // set local timezone for TZDateTime (best-effort)
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      // Set local TZ using the IANA identifier returned by the plugin
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // ignore if timezone read fails
    }
  } catch (_) {}

  NativeCallHandler.initChannel();
  PlatformChannels.initScreenCaptureListener();
  WakelockPlus.enable();
  final noScreenshot = NoScreenshot.instance;
  await noScreenshot.screenshotOff();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  IOSLogger.startListening();
  // Initialize Hive for calendar storage
  await Hive.initFlutter();
  Hive.registerAdapter(CalendarEventModelAdapter());
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final Uuid _uuid;
  String? _currentUuid;
  String textEvents = "";

  /// Cached call data from the last accepted CallKit event (iOS fallback).
  Map<String, dynamic>? _lastAcceptedCallData;

  late final FirebaseMessaging _firebaseMessaging;
  final groupListController = Get.put(GroupListController());

  @override
  void initState() {
    super.initState();
    _uuid = const Uuid();
    textEvents = "";

    notificationConfig(_uuid);
    WidgetsBinding.instance.addObserver(this);
    listenerEvent(onEvent);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (GroupCallNewConfig.enabled) {
        Get.put(GroupCallNewController());
      } else if (!GroupCallEmbededConfig.enabled) {
        Get.put(GroupcallController());
      }
      _getupToken();

      // initialize deep link handling
      try {
        DeepLinkService().init();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 800));
      checkAndNavigationCallingPage();
    });
  }

  // This method retrieves the FCM and Apple PushKit tokens and logs them.
  void _getupToken() async {
    final fcmToken = await AppPreference().getFirebaseToken();
    final applePushToken = await AppPreference().getApplePushToken();
    print('FCM Token: $fcmToken');
    print('Apple PushKit Token: $applePushToken');
  }

  // This method handles the events from CallKit.
  void onEvent(CallEvent event) {
    if (!mounted) return;
    setState(() {
      textEvents += '---\n${event.toString()}\n';
    });
  }

  // This method listens for CallKit events and executes the callback function.
  Future<void> listenerEvent(void Function(CallEvent) callback) async {
    try {
      FlutterCallkitIncoming.onEvent.listen((event) async {
        if (event == null) return;
        groupListController.getGroupList(isLoadingShow: false);
        switch (event.event) {
          case Event.actionCallIncoming:
            //  received an incoming call
            break;
          case Event.actionCallStart:
            //  started an outgoing call
            //  show screen calling in Flutter
            break;
          case Event.actionCallAccept:
            //  accepted an incoming call
            //  Cache the call data from the event for iOS fallback
            try {
              final body = event.body;
              if (body is Map) {
                _lastAcceptedCallData = Map<String, dynamic>.from(body);
                debugPrint(
                    '[CallKit] actionCallAccept cached data: $_lastAcceptedCallData');
              }
            } catch (_) {}
            Future.delayed(const Duration(milliseconds: 350), () {
              checkAndNavigationCallingPage();
            });

            break;
          case Event.actionCallDecline:
            //  declined an incoming call
            // await requestHttp("ACTION_CALL_DECLINE_FROM_DART");
            break;
          case Event.actionCallEnded:
            //  ended an incoming/outgoing call
            // await FlutterCallkitIncoming.endAllCalls();
            break;
          case Event.actionCallTimeout:
            //  missed an incoming call
            // await FlutterCallkitIncoming.endAllCalls();
            break;
          case Event.actionCallCallback:
            //  only Android - click action `Call back` from missed call notification
            break;
          case Event.actionCallToggleHold:
            //  only iOS
            break;
          case Event.actionCallToggleMute:
            //  only iOS
            break;
          case Event.actionCallToggleDmtf:
            //  only iOS
            break;
          case Event.actionCallToggleGroup:
            //  only iOS
            break;
          case Event.actionCallToggleAudioSession:
            //  only iOS
            break;
          case Event.actionDidUpdateDevicePushTokenVoip:
            //  only iOS
            break;
          case Event.actionCallCustom:
            break;
        }
        callback(event);
      });
    } on Exception catch (e) {
      debugPrint('Error listening to CallKit events: $e');
    }
  }

  // This method retrieves the current call from CallKit.
  Future<dynamic> getCurrentCall() async {
    //check current call from pushkit if possible
    var calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List) {
      if (calls.isNotEmpty) {
        _currentUuid = calls[0]['id'];
        return calls[0];
      } else {
        _currentUuid = "";
        return null;
      }
    }
  }

  // This method checks if there is an active call and navigates to the call screen if necessary.
  Future<void> checkAndNavigationCallingPage() async {
    try {
      var currentCall = await getCurrentCall();

      // iOS fallback: if getCurrentCall returns null but we have cached data
      // from the CallKit accept event, use that instead.
      if (currentCall == null && _lastAcceptedCallData != null) {
        debugPrint('[CallKit] Using cached accept data as fallback');
        currentCall = {
          'accepted': true,
          'extra': _lastAcceptedCallData!['extra'] ?? _lastAcceptedCallData,
          'id': _lastAcceptedCallData!['id'] ?? '',
        };
      }

      if (currentCall != null) {
        final extra = currentCall['extra'];
        if (extra == null || extra is! Map) {
          debugPrint('[CallKit] No extra data in call, skipping');
          _lastAcceptedCallData = null;
          await FlutterCallkitIncoming.endAllCalls();
          return;
        }
        final callType = extra['callType'];
        if (currentCall['accepted'] == true) {
          Future.delayed(const Duration(milliseconds: 2000), () async {
            final currentRoute = Get.currentRoute;
            final isOnChatScreen = Get.isRegistered<ChatScreen>() ||
                currentRoute.contains('ChatScreen');

            if (isOnChatScreen) {
              final GroupcallController? groupcallController =
                  Get.isRegistered<GroupcallController>()
                      ? Get.find<GroupcallController>()
                      : (GroupCallEmbededConfig.enabled ||
                              GroupCallNewConfig.enabled
                          ? null
                          : Get.put(GroupcallController()));
              Future.delayed(const Duration(seconds: 1), () {
                GroupCallEmbededController? embeddedController;
                if (GroupCallEmbededConfig.enabled) {
                  embeddedController =
                      Get.isRegistered<GroupCallEmbededController>()
                          ? Get.find<GroupCallEmbededController>()
                          : Get.put(GroupCallEmbededController());
                }

                GroupCallNewController? newCallController;
                if (GroupCallNewConfig.enabled) {
                  newCallController = Get.isRegistered<GroupCallNewController>()
                      ? Get.find<GroupCallNewController>()
                      : Get.put(GroupCallNewController());
                }

                // guard against duplicated navigation
                if ((groupcallController?.isCallActive.value == true) ||
                    (embeddedController?.isCallActive.value == true) ||
                    (newCallController?.isCallActive.value == true) ||
                    (groupcallController?.isNavigatingToCall == true) ||
                    Get.currentRoute.contains('GroupVideoCallScreen') ||
                    Get.currentRoute.contains('GroupCallEmbededScreen') ||
                    Get.currentRoute.contains('GroupCallNewScreen')) {
                  return;
                }

                final localUserId =
                    (GetStorage().read('userId') ?? '').toString();
                final localUserName =
                    (GetStorage().read('userName') ?? '').toString();

                if (GroupCallNewConfig.enabled && newCallController != null) {
                  unawaited(newCallController.joinCall(
                    roomId: currentCall['extra']['groupId'],
                    userName: localUserId,
                    userFullName: localUserName,
                    context: context,
                    isVideoCall: callType == 'video' ? true : false,
                  ));
                } else if (GroupCallEmbededConfig.enabled &&
                    embeddedController != null) {
                  unawaited(embeddedController.joinCall(
                    roomId: currentCall['extra']['groupId'],
                    userName: localUserId,
                    userFullName: localUserName,
                    context: context,
                    isVideoCall: callType == 'video' ? true : false,
                  ));
                } else if (groupcallController != null) {
                  groupcallController.outgoingCallEmit(
                    currentCall['extra']['groupId'],
                    isVideoCall: callType == 'video' ? true : false,
                  );
                }
              });
            } else {
              Get.off(
                () => ChatScreen(
                  groupId: currentCall['extra']['groupId'],
                  index: 0,
                  isAccepted: 1,
                  callType: callType,
                ),
              );
            }

            // End the call in CallKit UI and clear cached data
            _lastAcceptedCallData = null;
            await FlutterCallkitIncoming.endCall(currentCall['id']);
          });
        } else {
          _lastAcceptedCallData = null;
          await FlutterCallkitIncoming.endAllCalls();
        }
      } else {
        await FlutterCallkitIncoming.endAllCalls();
      }
    } finally {}
  }

  // This method listens for app lifecycle changes and handles them accordingly.
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      //Check call when open app from background
      checkAndNavigationCallingPage();
      final socketController = Get.put(SocketController());
      socketController.reconnectSocket();
    }

    if (state == AppLifecycleState.paused) {}

    if (state == AppLifecycleState.detached) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose of any resources or listeners if needed
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Get.put(MainNetworkController(screenName: 'MyApp'));
    final themeController = Get.put(ThemeController());

    return DismissKeyBoard(
      child: OverlaySupport.global(
        child: GlobalBloc(
          child: Obx(() => GetMaterialApp(
                navigatorKey: NavigationService.navigatorKey,
                debugShowCheckedModeBanner: false,
                title: AppStrings.appName,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeController.themeMode.value,
                home: const SplashScreen(),
                builder: (context, child) {
                  // InAppNotifications wraps the child
                  final notificationsBuilder = InAppNotifications.init();
                  final withNotifications =
                      notificationsBuilder(context, child);
                  // SystemPipOverlay renders video on top when system PiP is active
                  return SystemPipOverlay(child: withNotifications);
                },
              )),
        ),
      ),
    );
  }
}

// This class handles native calls and provides methods to navigate to specific screens based on the call type.
class NativeCallHandler {
  static void initChannel() {
    PlatformChannels.iosnavigationplatform
        .setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'goToVideoCall':
          final args = Map<String, dynamic>.from(call.arguments);
          // Navigate to video call screen with arguments using GetX
          Get.off(
            () => ChatScreen(
              groupId: args['groupId'],
              index: 0,
              isAccepted: 1,
              callType: args['callType'],
            ),
          );
          break;
        case 'groupListRefresh':
          // Refresh the group list
          Get.find<GroupListController>().getGroupList(isLoadingShow: false);
          break;
      }
    });
  }
}
