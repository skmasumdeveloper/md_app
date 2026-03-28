import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Commons/platform_channels.dart';
import 'package:cu_app/Features/Home/Model/group_list_model.dart';
import 'package:cu_app/Features/Home/Repository/group_repo.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Features/Group_Call_Embeded/presentation/group_call_embeded_screen.dart';
import 'package:cu_app/services/call_service.dart';
import 'package:cu_app/services/embedded_call_overlay_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

class GroupCallEmbededController extends GetxController {
  final RxBool isCallActive = false.obs;
  final RxBool isAnyCallActive = false.obs;
  final RxBool isMicEnabled = true.obs;
  final RxBool isCameraEnabled = true.obs;
  final RxBool isSpeakerOn = true.obs;
  final RxBool isThisVideoCall = true.obs;
  final RxBool isInOverlayMode = false.obs;
  final RxBool isConnecting = false.obs;
  final RxString currentRoomId = ''.obs;
  final RxString callState = 'idle'.obs;
  final RxMap<String, bool> remoteAudioEnabled = <String, bool>{}.obs;
  final Rx<GroupModel> groupModel = GroupModel().obs;

  final GroupRepo _groupRepo = GroupRepo();

  WebViewController? _webViewController;
  Completer<void>? _pageReadyCompleter;
  Map<String, dynamic>? _pendingBootstrap;

  @override
  void onInit() {
    super.onInit();
    unawaited(configureAudioSession());
  }

  bool get isPageReady =>
      _pageReadyCompleter != null && _pageReadyCompleter!.isCompleted;

  WebViewController? get webViewController => _webViewController;

  void attachWebController(WebViewController controller) {
    _webViewController = controller;
    _pageReadyCompleter ??= Completer<void>();
  }

  Future<void> onPageReady() async {
    _pageReadyCompleter ??= Completer<void>();
    if (!_pageReadyCompleter!.isCompleted) {
      _pageReadyCompleter!.complete();
    }

    // Flush pending init message when page becomes ready.
    if (_pendingBootstrap != null) {
      final payload = _pendingBootstrap!;
      _pendingBootstrap = null;
      await _sendToWeb('bootstrap', payload);
    }
  }

  Future<void> outgoingCallEmit(String groupId,
      {required bool isVideoCall}) async {
    await _openCallScreen(
      roomId: groupId,
      isVideoCall: isVideoCall,
      isJoinFlow: false,
    );
  }

  Future<void> joinCall({
    required String roomId,
    required String userName,
    required String userFullName,
    required BuildContext context,
    bool isVideoCall = true,
  }) async {
    await _openCallScreen(
      roomId: roomId,
      isVideoCall: isVideoCall,
      isJoinFlow: true,
      explicitUserName: userName,
      explicitFullName: userFullName,
    );
  }

  Future<void> callReject(String groupId) async {
    await _sendToWeb('rejectCall', {'roomId': groupId});
    await leaveCall(roomId: groupId, userId: LocalStorage().getUserId());
  }

  Future<void> leaveCall(
      {required String roomId, required String userId}) async {
    if (roomId.isNotEmpty) {
      await _sendToWeb('leaveCall', {'roomId': roomId, 'userId': userId});
    }

    isCallActive.value = false;
    isAnyCallActive.value = false;
    isConnecting.value = false;
    isSpeakerOn.value = true;
    callState.value = 'left';
    currentRoomId.value = '';
    _pendingBootstrap = null;
    isInOverlayMode.value = false;
    remoteAudioEnabled.clear();

    EmbeddedCallOverlayManager().remove();

    await deactivateAudioSession();

    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}

    try {
      await CallService.stopService();
    } catch (_) {}

    await LocalStorage().setIsAnyCallActive(false);
    await LocalStorage().clearActiveCallRoomId();

    if (Get.currentRoute.contains('GroupCallEmbededScreen')) {
      Get.back();
    }
  }

  void reCallConnect() {
    _sendToWeb('reconnect', const {});
  }

  Future<void> toggleMic() async {
    isMicEnabled.value = !isMicEnabled.value;
    await _sendToWeb('toggleMic', {'enabled': isMicEnabled.value});
  }

  Future<void> toggleCamera() async {
    isCameraEnabled.value = !isCameraEnabled.value;
    await _sendToWeb('toggleCamera', {'enabled': isCameraEnabled.value});
  }

  Future<void> switchCamera() async {
    await _sendToWeb('switchCamera', const {});
  }

  Future<void> toggleSpeaker() async {
    isSpeakerOn.value = !isSpeakerOn.value;
    await setAudioToSpeaker(isSpeakerOn.value);
    await _sendToWeb('toggleSpeaker', {'enabled': isSpeakerOn.value});
  }

  Future<void> _openCallScreen({
    required String roomId,
    required bool isVideoCall,
    required bool isJoinFlow,
    String? explicitUserName,
    String? explicitFullName,
  }) async {
    if (isConnecting.value || isCallActive.value) {
      return;
    }

    isInOverlayMode.value = false;
    EmbeddedCallOverlayManager().remove();

    isConnecting.value = true;
    callState.value = 'preparing';

    try {
      final groupName = await _getGroupDetailsById(roomId, 'groupName');
      final participants = _buildParticipantDirectory();

      final granted = await _requestMediaPermission(isVideoCall: isVideoCall);
      if (!granted) {
        callState.value = 'permission_denied';
        isConnecting.value = false;
        Get.snackbar('Permission required',
            'Camera and microphone permissions are required to start the call.');
        return;
      }

      final userId = explicitUserName ?? LocalStorage().getUserId();
      final userFullName = explicitFullName ?? LocalStorage().getUserName();

      currentRoomId.value = roomId;
      isThisVideoCall.value = isVideoCall;
      isMicEnabled.value = true;
      isCameraEnabled.value = isVideoCall;
      isSpeakerOn.value = isVideoCall;
      isCallActive.value = true;
      isAnyCallActive.value = true;

      await activateAudioSession();
      await setAudioToSpeaker(isSpeakerOn.value);

      await LocalStorage().setIsAnyCallActive(true);
      await LocalStorage().setActiveCallRoomId(roomId);

      _pageReadyCompleter = Completer<void>();
      _pendingBootstrap = {
        'socketUrl': ApiPath.socketUrl,
        'roomId': roomId,
        'groupName': groupName,
        'userId': userId,
        'fullName': userFullName,
        'participants': participants,
        'callType': isVideoCall ? 'video' : 'audio',
        'joinEvent': 'BE-join-room',
        'leaveEvent': 'BE-leave-room',
        'isJoinFlow': isJoinFlow,
      };

      callState.value = 'opening_screen';
      isConnecting.value = false;

      Get.to(() => GroupCallEmbededScreen(
            roomId: roomId,
            groupName: groupName,
            isVideoCall: isVideoCall,
            isMeeting: groupModel.value.isTemp == true,
          ));
    } catch (e) {
      await deactivateAudioSession();
      callState.value = 'error';
      isConnecting.value = false;
      isCallActive.value = false;
      isAnyCallActive.value = false;
      Get.snackbar('Call Error', 'Failed to open embedded call: $e');
    }
  }

  Future<void> handleJsMessage(String rawMessage) async {
    try {
      final Map<String, dynamic> message =
          Map<String, dynamic>.from(jsonDecode(rawMessage) as Map);
      final type = message['type']?.toString() ?? '';
      final payload = message['payload'] is Map
          ? Map<String, dynamic>.from(message['payload'] as Map)
          : <String, dynamic>{};

      switch (type) {
        case 'ready':
          callState.value = 'web_ready';
          await onPageReady();
          break;
        case 'connected':
          callState.value = 'connected';
          isConnecting.value = false;
          break;
        case 'state':
          final state = payload['state']?.toString();
          if (state != null && state.isNotEmpty) {
            callState.value = state;
          }
          break;
        case 'mic':
          if (payload['enabled'] is bool) {
            isMicEnabled.value = payload['enabled'] as bool;
          }
          break;
        case 'camera':
          if (payload['enabled'] is bool) {
            isCameraEnabled.value = payload['enabled'] as bool;
          }
          break;
        case 'remote_audio':
          final userId = payload['userId']?.toString() ?? '';
          final enabled = payload['enabled'];
          if (userId.isNotEmpty && enabled is bool) {
            remoteAudioEnabled[userId] = enabled;
          }
          break;
        case 'ended':
          await leaveCall(
            roomId: currentRoomId.value,
            userId: LocalStorage().getUserId(),
          );
          break;
        case 'error':
          final msg =
              payload['message']?.toString() ?? 'Unknown web call error';
          callState.value = 'error';
          Get.snackbar('Call Error', msg);
          break;
        default:
          break;
      }
    } catch (_) {
      // Ignore non-JSON or malformed bridge messages.
    }
  }

  Future<void> _sendToWeb(String action, Map<String, dynamic> payload) async {
    final controller = _webViewController;
    if (controller == null) {
      return;
    }

    final completer = _pageReadyCompleter;
    if (completer == null || !completer.isCompleted) {
      return;
    }

    final envelope = jsonEncode({'action': action, 'payload': payload});
    final escaped = envelope
        .replaceAll(r'\\', r'\\\\')
        .replaceAll("'", r"\\'")
        .replaceAll('\n', r'\\n');

    await controller.runJavaScript(
      "window.CU_EMBEDDED && window.CU_EMBEDDED.receiveFromFlutter && window.CU_EMBEDDED.receiveFromFlutter('$escaped');",
    );
  }

  Future<bool> _requestMediaPermission({required bool isVideoCall}) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      return false;
    }

    if (isVideoCall) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        return false;
      }
    }

    return true;
  }

  Future<String> _getGroupDetailsById(String groupId, String field) async {
    try {
      final res = await _groupRepo.getGroupDetailsById(groupId: groupId);
      if (res.data != null) {
        groupModel.value = res.data!;
      }

      if (field == 'groupName') {
        final name = groupModel.value.groupName;
        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
    } catch (_) {}

    return 'Group Call';
  }

  Map<String, String> _buildParticipantDirectory() {
    final Map<String, String> participants = <String, String>{};

    final currentUsers = groupModel.value.currentUsers;
    if (currentUsers != null) {
      for (final user in currentUsers) {
        final id = user.sId ?? '';
        final name = user.name ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          participants[id] = name;
        }
      }
    }

    final localUserId = LocalStorage().getUserId();
    final localUserName = LocalStorage().getUserName();
    if (localUserId.isNotEmpty && localUserName.isNotEmpty) {
      participants[localUserId] = localUserName;
    }

    return participants;
  }

  Future<void> setSpeakerMode(bool speakerOn) async {
    try {
      await PlatformChannels.iosaudioplatform.invokeMethod('setSpeakerMode', {
        'speakerOn': speakerOn,
      });
    } catch (_) {}
  }

  Future<void> configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
    } catch (_) {}
  }

  Future<void> activateAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}
  }

  Future<void> deactivateAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
  }

  Future<void> setAudioToSpeaker([bool speakerOn = true]) async {
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (_) {}

    await setSpeakerMode(speakerOn);
  }
}
