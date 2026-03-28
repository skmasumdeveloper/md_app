import 'dart:async';
import 'dart:convert';

import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Features/Group_Call_Embeded/presentation/group_call_embeded_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

class GroupCallEmbededController extends GetxController {
  final RxBool isCallActive = false.obs;
  final RxBool isAnyCallActive = false.obs;
  final RxBool isMicEnabled = true.obs;
  final RxBool isCameraEnabled = true.obs;
  final RxBool isThisVideoCall = true.obs;
  final RxBool isConnecting = false.obs;
  final RxString currentRoomId = ''.obs;
  final RxString callState = 'idle'.obs;

  WebViewController? _webViewController;
  Completer<void>? _pageReadyCompleter;
  Map<String, dynamic>? _pendingBootstrap;

  bool get isPageReady =>
      _pageReadyCompleter != null && _pageReadyCompleter!.isCompleted;

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
    await _sendToWeb('leaveCall', {'roomId': roomId, 'userId': userId});

    isCallActive.value = false;
    isAnyCallActive.value = false;
    isConnecting.value = false;
    callState.value = 'left';
    currentRoomId.value = '';

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
    await _sendToWeb('toggleSpeaker', const {});
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

    isConnecting.value = true;
    callState.value = 'preparing';

    try {
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
      isCallActive.value = true;
      isAnyCallActive.value = true;

      await LocalStorage().setIsAnyCallActive(true);
      await LocalStorage().setActiveCallRoomId(roomId);

      _pageReadyCompleter = Completer<void>();
      _pendingBootstrap = {
        'socketUrl': ApiPath.socketUrl,
        'roomId': roomId,
        'userId': userId,
        'fullName': userFullName,
        'callType': isVideoCall ? 'video' : 'audio',
        'joinEvent': 'BE-join-room',
        'leaveEvent': 'BE-leave-room',
        'isJoinFlow': isJoinFlow,
      };

      callState.value = 'opening_screen';
      isConnecting.value = false;

      Get.to(() => GroupCallEmbededScreen(
            roomId: roomId,
            groupName: 'Group Call',
            isVideoCall: isVideoCall,
          ));
    } catch (e) {
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
}
