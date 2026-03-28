// ignore_for_file: prefer_const_constructors

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cu_app/Utils/storage_service.dart';

// This function shows an incoming call notification using the CallKit package.
Future<void> showCallkitIncoming(Map<String, dynamic> data, String uuid) async {
  // Safe access to dotenv with fallbacks
  String appName = 'CU';
  String appLogo = '';

  // print('call data: $data');

  // data have callType: video/audio
  String callType = data['callType'] ?? 'video';

  try {
    appName = dotenv.env['APP_NAME'] ?? 'CU';
    appLogo = dotenv.env['APP_LOGO_LINK'] ?? '';
  } catch (e) {
    // dotenv not initialized, use fallback values
    print('dotenv not available, using fallback values: $e');
  }

  CallKitParams callKitParams = CallKitParams(
    id: uuid,
    nameCaller: data['body'] ?? 'Incoming Call',
    appName: appName,
    avatar: appLogo, // optional
    handle: callType == 'video' ? 'videoCall' : 'audioCall',
    type: callType == 'video' ? 1 : 0, // 0: audio, 1: video
    duration: 30000,
    textAccept: 'Accept',
    textDecline: 'Decline',
    missedCallNotification: const NotificationParams(
      showNotification: false,
      isShowCallback: false,
      subtitle: 'Missed call',
      callbackText: 'Call back',
    ),
    callingNotification: const NotificationParams(
      showNotification: false,
      isShowCallback: false,
      subtitle: 'Calling...',
      callbackText: 'Hang Up',
    ),
    extra: <String, dynamic>{
      'groupId': data['grp'],
      'callType': callType,
    },
    headers: <String, dynamic>{'apiKey': appName},
    android: const AndroidParams(
        isCustomNotification: true,
        ringtonePath: 'ringtone', // or your custom ringtone
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: "Incoming Call",
        missedCallNotificationChannelName: "Missed Call",
        isShowCallID: false),
    ios: IOSParams(
      handleType: 'generic',
      ringtonePath: 'system_ringtone_default',
      supportsVideo: callType == 'video' ? true : false,
      audioSessionActive: false,
      supportsDTMF: false,
      supportsHolding: false,
      supportsGrouping: false,
      supportsUngrouping: false,
      configureAudioSession: false,
    ),
  );

  await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);

  // persist the uuid so the app can end this exact call later
  try {
    await LocalStorage().setLatestCallUuid(uuid);
  } catch (_) {}
}
