import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Commons/platform_channels.dart';
import 'package:cu_app/Features/Group_Call_old/controller/group_call_turn.dart';
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
  static const bool _verboseLogs = true;

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
  Worker? _systemPipWorker;
  String _desiredViewMode = 'normal';
  String _lastSentViewMode = '';
  final Map<String, Map<String, dynamic>> _queuedWebActions =
      <String, Map<String, dynamic>>{};

  void _log(String stage, [Map<String, dynamic>? details]) {
    if (!_verboseLogs) {
      return;
    }

    if (details == null || details.isEmpty) {
      debugPrint('[EmbeddedCall][Flutter][$stage]');
      return;
    }

    try {
      debugPrint('[EmbeddedCall][Flutter][$stage] ${jsonEncode(details)}');
    } catch (_) {
      debugPrint('[EmbeddedCall][Flutter][$stage] $details');
    }
  }

  @override
  void onInit() {
    super.onInit();
    _log('onInit');
    unawaited(configureAudioSession());

    _systemPipWorker = ever<bool>(CallService.isSystemPipActive, (_) {
      unawaited(syncEmbeddedViewMode());
    });
  }

  @override
  void onClose() {
    _log('onClose');
    _systemPipWorker?.dispose();
    _systemPipWorker = null;
    super.onClose();
  }

  bool get isPageReady =>
      _pageReadyCompleter != null && _pageReadyCompleter!.isCompleted;

  WebViewController? get webViewController => _webViewController;

  void attachWebController(WebViewController controller) {
    _log('attachWebController', {
      'controllerChanged': !identical(_webViewController, controller),
    });

    if (!identical(_webViewController, controller)) {
      _lastSentViewMode = '';
    }
    _webViewController = controller;
    _pageReadyCompleter ??= Completer<void>();
  }

  Future<void> onPageReady() async {
    _log('onPageReady', {
      'hasPendingBootstrap': _pendingBootstrap != null,
    });

    _pageReadyCompleter ??= Completer<void>();
    if (!_pageReadyCompleter!.isCompleted) {
      _pageReadyCompleter!.complete();
    }

    // Flush pending init message when page becomes ready.
    if (_pendingBootstrap != null) {
      final payload = _pendingBootstrap!;
      _pendingBootstrap = null;
      await _sendToWeb('bootstrap', payload);
      await syncEmbeddedViewMode(force: true);
    }

    await _flushQueuedWebActions();
  }

  Future<void> setCompactMode(bool enabled, {bool force = false}) async {
    _log('setCompactMode', {'enabled': enabled, 'force': force});
    _desiredViewMode = enabled ? 'pip' : 'normal';
    await syncEmbeddedViewMode(force: force);
  }

  Future<void> syncEmbeddedViewMode({bool force = false}) async {
    final bool shouldUseCompact = _desiredViewMode == 'pip' ||
        isInOverlayMode.value ||
        CallService.isSystemPipActive.value;
    final String mode = shouldUseCompact ? 'pip' : 'normal';

    _log('syncEmbeddedViewMode', {
      'force': force,
      'shouldUseCompact': shouldUseCompact,
      'mode': mode,
      'pendingBootstrap': _pendingBootstrap != null,
      'pageReady': isPageReady,
    });

    if (_pendingBootstrap != null) {
      _pendingBootstrap!['viewMode'] = mode;
    }

    if (!force && _lastSentViewMode == mode) {
      return;
    }

    _lastSentViewMode = mode;
    await _sendToWeb('setViewMode', {'mode': mode});
  }

  Future<void> outgoingCallEmit(String groupId,
      {required bool isVideoCall}) async {
    _log('outgoingCallEmit', {
      'groupId': groupId,
      'isVideoCall': isVideoCall,
    });

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
    _log('joinCall', {
      'roomId': roomId,
      'isVideoCall': isVideoCall,
      'userName': userName,
      'userFullName': userFullName,
    });

    await _openCallScreen(
      roomId: roomId,
      isVideoCall: isVideoCall,
      isJoinFlow: true,
      explicitUserName: userName,
      explicitFullName: userFullName,
    );
  }

  Future<void> callReject(String groupId) async {
    _log('callReject', {'groupId': groupId});
    await _sendToWeb('rejectCall', {'roomId': groupId});
    await leaveCall(roomId: groupId, userId: LocalStorage().getUserId());
  }

  Future<void> leaveCall(
      {required String roomId, required String userId}) async {
    _log('leaveCall:start', {
      'roomId': roomId,
      'userId': userId,
      'currentRoute': Get.currentRoute,
      'isCallActive': isCallActive.value,
      'isAnyCallActive': isAnyCallActive.value,
    });

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
    _desiredViewMode = 'normal';
    _lastSentViewMode = '';
    _queuedWebActions.clear();
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

    _webViewController = null;
    _pageReadyCompleter = null;

    if (Get.currentRoute.contains('GroupCallEmbededScreen')) {
      Get.back();
    }

    _log('leaveCall:end', {
      'roomId': roomId,
      'isCallActive': isCallActive.value,
      'isAnyCallActive': isAnyCallActive.value,
      'callState': callState.value,
    });
  }

  void reCallConnect() {
    _log('reCallConnect', {
      'hasWebController': _webViewController != null,
      'pageReady': isPageReady,
      'roomId': currentRoomId.value,
    });
    _sendToWeb('reconnect', const {});
  }

  Future<void> toggleMic() async {
    _log('toggleMic', {'nextEnabled': !isMicEnabled.value});
    isMicEnabled.value = !isMicEnabled.value;
    await _sendToWeb('toggleMic', {'enabled': isMicEnabled.value});
  }

  Future<void> toggleCamera() async {
    _log('toggleCamera', {'nextEnabled': !isCameraEnabled.value});
    isCameraEnabled.value = !isCameraEnabled.value;
    await _sendToWeb('toggleCamera', {'enabled': isCameraEnabled.value});
  }

  Future<void> switchCamera() async {
    _log('switchCamera');
    await _sendToWeb('switchCamera', const {});
  }

  Future<void> toggleSpeaker() async {
    _log('toggleSpeaker', {'nextEnabled': !isSpeakerOn.value});
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
    _log('_openCallScreen:start', {
      'roomId': roomId,
      'isVideoCall': isVideoCall,
      'isJoinFlow': isJoinFlow,
      'isConnecting': isConnecting.value,
      'isCallActive': isCallActive.value,
    });

    if (isConnecting.value || isCallActive.value) {
      _log('_openCallScreen:skipped', {
        'reason': 'already-connecting-or-active',
      });
      return;
    }

    isInOverlayMode.value = false;
    _desiredViewMode = 'normal';
    _lastSentViewMode = '';
    _queuedWebActions.clear();
    EmbeddedCallOverlayManager().remove();

    isConnecting.value = true;
    callState.value = 'preparing';

    try {
      final groupName = await _getGroupDetailsById(roomId, 'groupName');
      final participants = _buildParticipantDirectory();

      _log('_openCallScreen:details', {
        'groupName': groupName,
        'participantCount': participants.length,
      });

      final granted = await _requestMediaPermission(isVideoCall: isVideoCall);
      if (!granted) {
        callState.value = 'permission_denied';
        isConnecting.value = false;
        final permissionMessage = isVideoCall
            ? 'Camera and microphone permissions are required to start the call.'
            : 'Microphone permission is required to start the call.';
        Get.snackbar('Permission required', permissionMessage);
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

      final embeddedIceFallback = _buildEmbeddedIceFallback();
      final constraints = <String, dynamic>{
        'audio': true,
        'video': isVideoCall,
      };

      _pageReadyCompleter = Completer<void>();
      _pendingBootstrap = {
        'socketUrl': ApiPath.mediasoupSocketUrl,
        'roomId': roomId,
        'groupName': groupName,
        'userId': userId,
        'fullName': userFullName,
        'callerName': userFullName,
        'groupImage': '',
        'participants': participants,
        'callType': isVideoCall ? 'video' : 'audio',
        'constraints': constraints,
        'fallbackIceServers': embeddedIceFallback['iceServers'],
        'fallbackIceTransportPolicy': embeddedIceFallback['iceTransportPolicy'],
        'joinEvent': 'BE-join-room',
        'leaveEvent': 'BE-leave-room',
        'isJoinFlow': isJoinFlow,
        'viewMode': 'normal',
      };

      _log('_openCallScreen:bootstrap-ready', {
        'roomId': roomId,
        'groupName': groupName,
        'userId': userId,
        'isVideoCall': isVideoCall,
      });

      callState.value = 'opening_screen';
      isConnecting.value = false;

      Get.to(() => GroupCallEmbededScreen(
            roomId: roomId,
            groupName: groupName,
            isVideoCall: isVideoCall,
            isMeeting: groupModel.value.isTemp == true,
          ));

      _log('_openCallScreen:navigate', {
        'route': 'GroupCallEmbededScreen',
        'roomId': roomId,
      });
    } catch (e) {
      _log('_openCallScreen:error', {'error': e.toString()});
      await deactivateAudioSession();
      callState.value = 'error';
      isConnecting.value = false;
      isCallActive.value = false;
      isAnyCallActive.value = false;
      Get.snackbar('Call Error', 'Failed to open embedded call: $e');
    }
  }

  Future<void> handleJsMessage(String rawMessage) async {
    if (_verboseLogs) {
      debugPrint('[EmbeddedCall][Bridge][raw] $rawMessage');
    }

    try {
      final Map<String, dynamic> message =
          Map<String, dynamic>.from(jsonDecode(rawMessage) as Map);
      final type = message['type']?.toString() ?? '';
      final payload = message['payload'] is Map
          ? Map<String, dynamic>.from(message['payload'] as Map)
          : <String, dynamic>{};

      switch (type) {
        case 'ready':
          _log('handleJsMessage:ready');
          callState.value = 'web_ready';
          await onPageReady();
          break;
        case 'connected':
          _log('handleJsMessage:connected', payload);
          callState.value = 'connected';
          isConnecting.value = false;
          break;
        case 'state':
          _log('handleJsMessage:state', payload);
          final state = payload['state']?.toString();
          if (state != null && state.isNotEmpty) {
            callState.value = state;
          }
          break;
        case 'mic':
          _log('handleJsMessage:mic', payload);
          if (payload['enabled'] is bool) {
            isMicEnabled.value = payload['enabled'] as bool;
          }
          break;
        case 'camera':
          _log('handleJsMessage:camera', payload);
          if (payload['enabled'] is bool) {
            isCameraEnabled.value = payload['enabled'] as bool;
          }
          break;
        case 'remote_audio':
          _log('handleJsMessage:remote_audio', payload);
          final userId = payload['userId']?.toString() ?? '';
          final enabled = payload['enabled'];
          if (userId.isNotEmpty && enabled is bool) {
            remoteAudioEnabled[userId] = enabled;
          }
          break;
        case 'log':
          final level = payload['level']?.toString() ?? 'debug';
          final scope = payload['scope']?.toString() ?? 'web';
          final message = payload['message']?.toString() ?? 'log';
          final details = payload['details']?.toString() ?? '';
          debugPrint(
              '[EmbeddedCall][Web][$level][$scope] $message ${details.isNotEmpty ? '| $details' : ''}');
          break;
        case 'ended':
          _log('handleJsMessage:ended', payload);
          await leaveCall(
            roomId: currentRoomId.value,
            userId: LocalStorage().getUserId(),
          );
          break;
        case 'error':
          _log('handleJsMessage:error', payload);
          final msg =
              payload['message']?.toString() ?? 'Unknown web call error';
          callState.value = 'error';
          Get.snackbar('Call Error', msg);
          break;
        default:
          _log('handleJsMessage:unknown', {
            'type': type,
            'payload': payload,
          });
          break;
      }
    } catch (e) {
      _log('handleJsMessage:parse-error', {
        'error': e.toString(),
      });
      // Ignore non-JSON or malformed bridge messages.
    }
  }

  Future<void> _sendToWeb(String action, Map<String, dynamic> payload) async {
    _log('_sendToWeb:attempt', {
      'action': action,
      'payload': payload,
      'hasController': _webViewController != null,
      'pageReady': isPageReady,
    });

    final controller = _webViewController;
    if (controller == null) {
      _queueActionIfNeeded(action, payload, reason: 'no-controller');
      _log('_sendToWeb:skip', {
        'action': action,
        'reason': 'no-controller',
      });
      return;
    }

    final completer = _pageReadyCompleter;
    if (completer == null || !completer.isCompleted) {
      _queueActionIfNeeded(action, payload, reason: 'page-not-ready');
      _log('_sendToWeb:skip', {
        'action': action,
        'reason': 'page-not-ready',
      });
      return;
    }

    final envelope = jsonEncode({'action': action, 'payload': payload});
    final escaped = envelope
        .replaceAll(r'\\', r'\\\\')
        .replaceAll("'", r"\\'")
        .replaceAll('\n', r'\\n');

    try {
      await controller.runJavaScript(
        "window.CU_EMBEDDED && window.CU_EMBEDDED.receiveFromFlutter && window.CU_EMBEDDED.receiveFromFlutter('$escaped');",
      );
    } catch (e) {
      _queueActionIfNeeded(action, payload, reason: 'run-javascript-error');
      _log('_sendToWeb:error', {
        'action': action,
        'error': e.toString(),
      });
      return;
    }

    _log('_sendToWeb:sent', {'action': action});
  }

  bool _isQueueableAction(String action) {
    switch (action) {
      case 'toggleMic':
      case 'toggleCamera':
      case 'toggleSpeaker':
      case 'switchCamera':
      case 'setViewMode':
      case 'reconnect':
        return true;
      default:
        return false;
    }
  }

  void _queueActionIfNeeded(String action, Map<String, dynamic> payload,
      {required String reason}) {
    if (!_isQueueableAction(action)) {
      return;
    }

    _queuedWebActions[action] = Map<String, dynamic>.from(payload);
    _log('_sendToWeb:queued', {
      'action': action,
      'reason': reason,
      'queuedCount': _queuedWebActions.length,
    });
  }

  Future<void> _flushQueuedWebActions() async {
    if (_queuedWebActions.isEmpty) {
      return;
    }

    final entries = _queuedWebActions.entries
        .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value)))
        .toList();
    _queuedWebActions.clear();

    _log('_flushQueuedWebActions', {
      'count': entries.length,
      'actions': entries.map((e) => e.key).toList(),
    });

    for (final entry in entries) {
      await _sendToWeb(entry.key, entry.value);
    }
  }

  Future<bool> _requestMediaPermission({required bool isVideoCall}) async {
    final requiredPermissions = <Permission>[
      Permission.microphone,
      if (isVideoCall) Permission.camera,
    ];

    for (final permission in requiredPermissions) {
      final currentStatus = await permission.status;
      _log('_requestMediaPermission:before', {
        'permission': permission.toString(),
        'status': currentStatus.toString(),
      });

      if (currentStatus.isGranted) {
        continue;
      }

      final requestedStatus = await permission.request();
      _log('_requestMediaPermission:after', {
        'permission': permission.toString(),
        'status': requestedStatus.toString(),
      });

      if (!requestedStatus.isGranted) {
        return false;
      }
    }

    return true;
  }

  Map<String, dynamic> _buildEmbeddedIceFallback() {
    final config = GroupCallTurn.getOptimalIceConfig();
    final rawServers = config['iceServers'];
    final List<Map<String, dynamic>> iceServers = <Map<String, dynamic>>[];

    if (rawServers is List) {
      for (final raw in rawServers) {
        if (raw is! Map) {
          continue;
        }

        final urlsValue = raw['urls'];
        final List<String> urls;
        if (urlsValue is List) {
          urls = urlsValue
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        } else if (urlsValue != null) {
          final single = urlsValue.toString().trim();
          urls = single.isEmpty ? <String>[] : <String>[single];
        } else {
          urls = <String>[];
        }

        if (urls.isEmpty) {
          continue;
        }

        final username = raw['username']?.toString().trim() ?? '';
        final credential = raw['credential']?.toString().trim() ?? '';

        final server = <String, dynamic>{
          'urls': urls.length == 1 ? urls.first : urls,
        };

        if (username.isNotEmpty) {
          server['username'] = username;
        }
        if (credential.isNotEmpty) {
          server['credential'] = credential;
        }

        iceServers.add(server);
      }
    }

    final rawPolicy =
        (config['iceTransportPolicy'] ?? 'all').toString().toLowerCase();
    final policy = rawPolicy == 'relay' ? 'relay' : 'all';

    _log('embedded-ice-fallback', {
      'serverCount': iceServers.length,
      'policy': policy,
    });

    return <String, dynamic>{
      'iceServers': iceServers,
      'iceTransportPolicy': policy,
    };
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
