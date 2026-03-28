// ignore_for_file: unused_local_variable, unnecessary_null_comparison

import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Features/Home/Controller/socket_controller.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide navigator;
import 'package:cu_app/services/call_overlay_manager.dart';
import 'package:cu_app/services/call_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';
import 'package:mediasfu_mediasoup_client/src/handlers/handler_interface.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:math' as math;
import '../../../Commons/platform_channels.dart';
import '../../CallHistory/controller/call_history_controller.dart';
import '../../Home/Controller/group_list_controller.dart';
import '../../Home/Model/group_list_model.dart';
import '../../Home/Repository/group_repo.dart';
import '../Presentation/video_call_screen.dart';
import 'network_controller.dart';
import 'group_call_turn.dart';
import '../../../services/screen_share_service.dart';

part 'group_call_audio.dart';
part 'group_call_call_flow.dart';
part 'group_call_media.dart';
part 'group_call_meeting.dart';
part 'group_call_peer.dart';
part 'group_call_renderers.dart';
part 'group_call_socket.dart';
part 'group_call_utils.dart';

// This controller manages group calls using MediaSoup SFU architecture.
// Media flows through the server (not P2P): each client has a send transport
// (to produce local audio/video) and a recv transport (to consume remote media).
class GroupcallController extends GetxController {
  BuildContext? context;
  RxString socketId = "".obs;
  late final SocketController socketController;
  late final ChatController chatController;
  IO.Socket? socket;
  final GroupRepo _groupRepo = GroupRepo();
  final groupListController = Get.put(GroupListController());
  final callHistoryController = Get.put(CallHistoryController());
  final networkController = Get.put(NetworkController());

  var groupModel = GroupModel().obs;

  final RxList<Map<String, dynamic>> joinedUsers = <Map<String, dynamic>>[].obs;
  final Set<String> _existingUserIds = {}; // Track existing userIds (ObjectIds)

  final RxMap<String, Map<String, dynamic>> userInfoMap =
      <String, Map<String, dynamic>>{}.obs;
  final RxMap<String, bool> userAudioEnabled = <String, bool>{}.obs;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RxMap<String, RTCVideoRenderer> remoteRenderers =
      <String, RTCVideoRenderer>{}.obs;
  MediaStream? localStream;

  final RxBool isMicEnabled = true.obs;
  final RxBool isCameraEnabled = true.obs;
  final RxBool isCallActive = false.obs;
  final RxString currentRoomId = "".obs;
  final RxInt participantCount = 0.obs;
  final RxBool isActiveCallInGroup = false.obs;
  RxBool isIncomingCallScreenOpen = false.obs;
  RxBool isThisVideoCall = true.obs;
  RxBool isSpeakerOn = true.obs;
  RxBool isAnyCallActive = false.obs;
  RxBool isMeetingGroup = false.obs;
  RxBool isMainSocketConnected = false.obs;
  final RxMap<String, bool> reconnectingPeers = <String, bool>{}.obs;
  RxBool isInOverlayMode = false.obs;

  final RxMap<String, DateTime> _tracklessUsers = <String, DateTime>{}.obs;
  Timer? _trackCheckTimer;

  // Keep references to remote streams (so we can attach/detach without losing them)
  final RxMap<String, MediaStream> remoteStreams = <String, MediaStream>{}.obs;

  // Active renderer management: limit how many remote video decoders are attached
  final RxSet<String> activeRenderers = <String>{}.obs;
  int maxActiveRenderers =
      9; // configurable, lowered on poor network or many participants

  Timer? _meetingEndTimer;
  RxBool isMeetingEnded = false.obs;

  // ── Screen Share ──────────────────────────────────────────────────
  final ScreenShareService screenShareService = ScreenShareService();
  RxBool get isScreenSharing => screenShareService.isScreenSharing;

  /// Track which remote user is sharing their screen (userId or null).
  final RxnString remoteScreenSharingUserId = RxnString(null);

  // ── MediaSoup SFU State ─────────────────────────────────────────
  Device? _msDevice;
  Transport? _sendTransport;
  Transport? _recvTransport;
  IceParameters? _sendIceParameters;
  IceParameters? _recvIceParameters;
  Producer? _audioProducer;
  Producer? _videoProducer;
  final Map<String, Consumer> _consumers = {}; // consumerId → Consumer
  final Map<String, String> _consumerToUserMap =
      {}; // consumerId → userId(ObjectId)
  final Set<String> _consumedProducerIds = {}; // track consumed producerIds

  // Runtime ICE config fetched from backend (kept aligned with web client).
  List<RTCIceServer>? _runtimeIceServers;
  RTCIceTransportPolicy? _runtimeIceTransportPolicy;

  // Maps between socket.id and user ObjectId
  final Map<String, String> _socketToUserMap = {}; // socket.id → ObjectId
  final Map<String, String> _userToSocketMap = {}; // ObjectId → socket.id

  bool _mediasoupInitialized = false;
  bool _isRestartingIce = false;
  Timer? _iceRestartDebounce;
  Timer? _sendIceRestartDebounce;
  DateTime? _lastIceRestartAt;
  DateTime? _iceRestartWindowStart;
  int _iceRestartBurstCount = 0;
  Timer? _keepAliveTimer;
  bool _isProducingLocalTracks = false;
  bool _hasProducedLocalTracks = false;
  bool _audioProduceRequested = false;
  bool _videoProduceRequested = false;
  bool _isInitializingMediasoup = false;
  bool _isReconnectingCall = false;
  bool _isCallFlowBusy = false;
  bool _skipBackendIceServerFetch = false;
  DateTime? _lastReconnectAttemptAt;

  bool get isInitializingMediasoup => _isInitializingMediasoup;
  bool get isReconnectingCall => _isReconnectingCall;
  bool get isCallFlowBusy => _isCallFlowBusy;
  bool get skipBackendIceServerFetch => _skipBackendIceServerFetch;

  // Serializes consume calls so only one SDP renegotiation runs at a time.
  Future<void>? _consumeChain;

  // Queue for producers that arrive via MS-new-producer before recv transport is ready.
  // These are retried after mediasoup initialization completes.
  final List<Map<String, String>> _pendingProducers = [];

  // navigation guard to avoid duplicated navigation to the call screen
  bool _isNavigatingToCall = false;
  bool get isNavigatingToCall => _isNavigatingToCall;

  // internal dialog state to avoid accidental route pops
  // overlay entry for non-modal 'connecting' indicator
  OverlayEntry? _callOverlayEntry;

  bool _isCallDialogShown = false;

  void _showCallConnectingOverlay() {
    try {
      if (_callOverlayEntry != null) return;

      final ctx = Get.overlayContext;
      if (ctx == null) return;

      _callOverlayEntry = OverlayEntry(
        builder: (_) => Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFD32F2F),
                        Color(0xFFFF6F00),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(height: 28),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "Connecting your call…",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Please stay on this screen",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      Overlay.of(ctx).insert(_callOverlayEntry!);
      _isCallDialogShown = true;
    } catch (e) {}
  }

  void _hideCallConnectingOverlay() {
    try {
      _callOverlayEntry?.remove();
      _callOverlayEntry = null;
      _isCallDialogShown = false;
    } catch (e) {}
  }

  @override
  void onInit() {
    super.onInit();
    try {
      socketController = Get.find<SocketController>();
    } catch (e) {
      socketController = Get.put(SocketController());
    }
    try {
      chatController = Get.find<ChatController>();
    } catch (e) {
      chatController = Get.put(ChatController());
    }
    configureAudioSession();
    _initializeRenderers();
    _initializeSocket();

    Future.microtask(_restoreActiveCallState);

    // periodically adapt quality when participant count or network changes
    ever(participantCount, (_) => _adaptQualityToNetwork());
  }

  Future<void> _restoreActiveCallState() async {
    try {
      final storedActive = await LocalStorage().getIsAnyCallActive();
      final storedRoomId = LocalStorage().getActiveCallRoomId();

      if (!storedActive || storedRoomId.isEmpty) {
        isAnyCallActive.value = false;
        currentRoomId.value = "";
        await LocalStorage().setIsAnyCallActive(false);
        await LocalStorage().clearActiveCallRoomId();
        return;
      }

      bool hasNativeCall = false;
      try {
        final calls = await FlutterCallkitIncoming.activeCalls();
        hasNativeCall = calls is List && calls.isNotEmpty;
      } catch (_) {}

      bool serverActive = false;
      bool serverChecked = false;
      try {
        final res = await _groupRepo.checkActiveCall(groupId: storedRoomId);
        if (res.data?['success'] == true) {
          serverChecked = true;
          serverActive = res.data?['data']?['activeCall'] == true;
        }
      } catch (_) {}

      if (serverChecked && !serverActive) {
        isAnyCallActive.value = false;
        currentRoomId.value = "";
        await LocalStorage().setIsAnyCallActive(false);
        await LocalStorage().clearActiveCallRoomId();
        try {
          await FlutterCallkitIncoming.endAllCalls();
        } catch (_) {}
        return;
      }

      if (serverActive || (!serverChecked && hasNativeCall)) {
        isAnyCallActive.value = true;
        currentRoomId.value = storedRoomId;
      } else {
        isAnyCallActive.value = false;
        currentRoomId.value = "";
        await LocalStorage().setIsAnyCallActive(false);
        await LocalStorage().clearActiveCallRoomId();
      }
    } catch (_) {}
  }

  // Activate an individual renderer so it will be attached (decoded)
  void promoteRenderer(String userId) {
    if (!remoteRenderers.containsKey(userId)) return;
    activeRenderers.add(userId);

    final renderer = remoteRenderers[userId];
    final stream = remoteStreams[userId];
    if (renderer != null && stream != null) {
      renderer.srcObject = stream;
      remoteRenderers.refresh();
    }

    if (activeRenderers.length > maxActiveRenderers) {
      final toRemove = activeRenderers.firstWhere((id) => id != 'local',
          orElse: () => activeRenderers.first);
      if (toRemove != userId) {
        _deactivateRenderer(toRemove);
      }
    }
  }

  void _deactivateRenderer(String userId) {
    if (!remoteRenderers.containsKey(userId)) return;
    final renderer = remoteRenderers[userId];
    try {
      if (renderer != null) renderer.srcObject = null;
    } catch (_) {}
    activeRenderers.remove(userId);
    remoteRenderers.refresh();
  }

  Timer? _qualityDebounce;

  Future<void> _adaptQualityToNetwork() async {
    if (isScreenSharing.value) return;
    try {
      _qualityDebounce?.cancel();
      _qualityDebounce = Timer(const Duration(seconds: 2), () async {
        final count = participantCount.value;
        if (count >= 12) {
          maxActiveRenderers = 4;
        } else if (count >= 6) {
          maxActiveRenderers = 6;
        } else {
          maxActiveRenderers = 9;
        }

        if (count >= 8) {
          await _ensureLowerCapture();
        } else {
          await _ensureDefaultCapture();
        }

        if (activeRenderers.length > maxActiveRenderers) {
          final toDrop = activeRenderers.length - maxActiveRenderers;
          final dropped = <String>[];
          for (var id in activeRenderers) {
            if (id == 'local') continue;
            if (dropped.length >= toDrop) break;
            dropped.add(id);
          }
          for (var d in dropped) {
            _deactivateRenderer(d);
          }
        }
      });
    } catch (e) {}
  }

  bool _usingLowCapture = false;

  Future<void> _ensureLowerCapture() async {
    if (_usingLowCapture) return;
    _usingLowCapture = true;
    await _replaceLocalVideoTrack(width: 320, height: 240, frameRate: 8);
  }

  Future<void> _ensureDefaultCapture() async {
    if (!_usingLowCapture) return;
    _usingLowCapture = false;
    await _replaceLocalVideoTrack(width: 480, height: 360, frameRate: 12);
  }

  // Replace local video track with new constraints — also updates MediaSoup producer
  Future<void> _replaceLocalVideoTrack(
      {required int width, required int height, required int frameRate}) async {
    if (isScreenSharing.value) return;
    try {
      if (localStream == null) return;
      final videoTracks =
          List<MediaStreamTrack>.from(localStream!.getVideoTracks());
      if (videoTracks.isEmpty) return;

      final newStream = await navigator.mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': width, 'max': width},
          'height': {'ideal': height, 'max': height},
          'frameRate': {'ideal': frameRate, 'max': frameRate},
        },
        'audio': false,
      });

      final newTrack = newStream.getVideoTracks().first;

      // Replace on MediaSoup video producer
      if (_videoProducer != null) {
        try {
          await _videoProducer!.replaceTrack(newTrack);
        } catch (_) {}
      }

      // swap local stream tracks
      for (var track in videoTracks) {
        try {
          try {
            localStream!.removeTrack(track);
          } catch (_) {}
          await track.stop();
        } catch (_) {}
      }
      localStream!.addTrack(newTrack);
      localRenderer.srcObject = localStream;
    } catch (e) {}
  }

  // Safely stop and remove local camera video tracks
  Future<void> _safeStopAndRemoveCameraTracks() async {
    try {
      debugPrint(
          '[GroupCall] _safeStopAndRemoveCameraTracks: detaching renderer');
      try {
        localRenderer.srcObject = null;
      } catch (_) {}

      final cameraVideoTracks =
          List<MediaStreamTrack>.from(localStream?.getVideoTracks() ?? []);

      for (var t in cameraVideoTracks) {
        try {
          try {
            await localStream?.removeTrack(t);
          } catch (e) {
            debugPrint(
                '[GroupCall] _safeStop removeTrack error: ${e.toString()}');
          }
          try {
            await t.stop();
          } catch (e) {
            debugPrint(
                '[GroupCall] _safeStop track.stop error: ${e.toString()}');
          }
        } catch (e) {
          debugPrint('[GroupCall] _safeStop inner error: ${e.toString()}');
        }
      }

      await Future.delayed(const Duration(milliseconds: 400));
    } catch (e) {
      debugPrint(
          '[GroupCall] _safeStopAndRemoveCameraTracks failed: ${e.toString()}');
    }
  }

  /// Start screen sharing — replaces video track on MediaSoup producer.
  Future<bool> startScreenShare() async {
    return await screenShareService.startScreenShare(
      localStream: localStream,
      videoProducer: _videoProducer,
      localRenderer: localRenderer,
      isVideoCall: isThisVideoCall.value,
    );
  }

  /// Stop screen sharing — restores camera track.
  Future<void> stopScreenShare() async {
    await screenShareService.stopScreenShare(
      localStream: localStream,
      videoProducer: _videoProducer,
      localRenderer: localRenderer,
      isVideoCall: isThisVideoCall.value,
    );
  }

  /// Toggle screen share on/off.
  Future<void> toggleScreenShare() async {
    if (isScreenSharing.value) {
      await stopScreenShare();
    } else {
      await startScreenShare();
    }
  }

  /// Resolve a userId (ObjectId) from a socket.id, using our mapping.
  String resolveUserId(String socketId) {
    return _socketToUserMap[socketId] ?? socketId;
  }

  @override
  void onClose() async {
    if (isCallActive.value) {
      await cleanupCall();
    }
    localRenderer.dispose();
    remoteRenderers.values.forEach((renderer) => renderer.dispose());
    remoteStreams.clear();
    activeRenderers.clear();
    _trackCheckTimer?.cancel();
    _tracklessUsers.clear();
    _meetingEndTimer?.cancel();
    super.onClose();
  }
}
