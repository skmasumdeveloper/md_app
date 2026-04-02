import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Features/Group_Call_New/models/call_participant.dart';
import 'package:cu_app/Features/Group_Call_New/models/call_state.dart';
import 'package:cu_app/Features/Group_Call_New/presentation/group_call_new_screen.dart';
import 'package:cu_app/Features/Group_Call_New/presentation/overlay/call_overlay_widget.dart';
import 'package:cu_app/Features/Group_Call_old/controller/group_call_turn.dart';
import 'package:cu_app/Features/Home/Model/group_list_model.dart';
import 'package:cu_app/Features/Home/Repository/group_repo.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:get/get.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';

import 'audio_manager.dart';
import 'call_logger.dart';
import 'call_recovery_manager.dart';
import 'call_socket_manager.dart';
import 'media_manager.dart';
import 'mediasoup_manager.dart';
import 'screen_recording_manager.dart';

/// Main controller for the new native group call module.
/// Orchestrates socket signaling, mediasoup, media, audio, and recovery.
class GroupCallNewController extends GetxController {
  static const String _scope = 'Controller';

  // ─── Managers ──────────────────────────────────────────────────────
  final CallSocketManager _socketMgr = CallSocketManager();
  final MediasoupManager _mediasoupMgr = MediasoupManager();
  final MediaManager _mediaMgr = MediaManager();
  final AudioManager _audioMgr = AudioManager();
  final CallRecoveryManager _recoveryMgr = CallRecoveryManager();
  late final ScreenRecordingManager recordingMgr;
  final GroupRepo _groupRepo = GroupRepo();

  // ─── Observable State ──────────────────────────────────────────────
  final Rx<GroupCallState> callState = GroupCallState.idle.obs;
  final RxBool isCallActive = false.obs;
  final RxBool isAnyCallActive = false.obs;
  final RxBool isMicEnabled = true.obs;
  final RxBool isCameraEnabled = true.obs;
  final RxBool isSpeakerOn = true.obs;
  final RxBool isThisVideoCall = true.obs;
  final RxBool isInOverlayMode = false.obs;
  final Rx<AudioOutputRoute> audioRoute = AudioOutputRoute.speaker.obs;
  final RxString currentRoomId = ''.obs;
  final Rx<GroupModel> groupModel = GroupModel().obs;

  /// All participants (including local). Keyed by userId.
  final RxMap<String, CallParticipant> participants =
      <String, CallParticipant>{}.obs;

  /// Participant directory: userId -> display name.
  final Map<String, String> _participantDirectory = {};

  // ─── Internal State ────────────────────────────────────────────────
  String _userId = '';
  String _userFullName = '';
  int _startToken = 0;
  bool _isStarting = false;
  Completer<void>? _socketConnectCompleter;

  // ─── Network Monitoring ────────────────────────────────────────────
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  List<ConnectivityResult>? _lastConnectivity;

  /// Reason for call end (shown as popup on chat screen).
  final RxnString callEndReason = RxnString(null);

  // ─── Getters ───────────────────────────────────────────────────────
  MediaManager get mediaMgr => _mediaMgr;
  String get localUserId => _userId;
  CallParticipant? get localParticipant => participants[_userId];

  @override
  void onInit() {
    super.onInit();
    CallLogger.info(_scope, 'onInit');
    recordingMgr = ScreenRecordingManager(_socketMgr);
    unawaited(_audioMgr.configure());
  }

  @override
  void onClose() {
    CallLogger.info(_scope, 'onClose');
    _cleanup();
    super.onClose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════

  /// Start an outgoing call.
  Future<void> outgoingCallEmit(String groupId,
      {required bool isVideoCall}) async {
    CallLogger.info(_scope, 'outgoingCallEmit', {
      'groupId': groupId,
      'isVideoCall': isVideoCall,
    });
    await _openCallScreen(
      roomId: groupId,
      isVideoCall: isVideoCall,
      isJoinFlow: false,
    );
  }

  /// Join an incoming call.
  Future<void> joinCall({
    required String roomId,
    required String userName,
    required String userFullName,
    required BuildContext context,
    bool isVideoCall = true,
  }) async {
    CallLogger.info(_scope, 'joinCall', {
      'roomId': roomId,
      'isVideoCall': isVideoCall,
    });
    await _openCallScreen(
      roomId: roomId,
      isVideoCall: isVideoCall,
      isJoinFlow: true,
      explicitUserName: userName,
      explicitFullName: userFullName,
    );
  }

  /// Leave the current call.
  Future<void> leaveCall() async {
    final roomId = currentRoomId.value;
    CallLogger.info(_scope, 'leaveCall', {'roomId': roomId});

    if (roomId.isNotEmpty && _userId.isNotEmpty) {
      _socketMgr.leaveRoom(roomId: roomId, leaver: _userId);
    }

    await _cleanup();
    _navigateAwayFromCallScreen();
  }

  /// Reject an incoming call.
  Future<void> callReject(String groupId) async {
    CallLogger.info(_scope, 'callReject', {'groupId': groupId});
    _socketMgr.rejectCall(roomId: groupId);
    await leaveCall();
  }

  /// Toggle microphone.
  void toggleMic() {
    isMicEnabled.value = !isMicEnabled.value;
    CallLogger.info(_scope, 'toggleMic', {'enabled': isMicEnabled.value});

    _mediaMgr.setAudioEnabled(isMicEnabled.value);
    if (isMicEnabled.value) {
      _mediasoupMgr.resumeAudioProducer();
    } else {
      _mediasoupMgr.pauseAudioProducer();
    }

    _socketMgr.toggleCameraAudio(
      roomId: currentRoomId.value,
      switchTarget: 'audio',
    );
  }

  /// Toggle camera.
  void toggleCamera() {
    isCameraEnabled.value = !isCameraEnabled.value;
    CallLogger.info(_scope, 'toggleCamera', {'enabled': isCameraEnabled.value});

    _mediaMgr.setVideoEnabled(isCameraEnabled.value);
    if (isCameraEnabled.value) {
      _mediasoupMgr.resumeVideoProducer();
    } else {
      _mediasoupMgr.pauseVideoProducer();
    }

    // Update local participant
    final local = participants[_userId];
    if (local != null) {
      local.videoEnabled = isCameraEnabled.value;
      participants.refresh();
    }

    _socketMgr.toggleCameraAudio(
      roomId: currentRoomId.value,
      switchTarget: 'video',
    );
  }

  /// Switch front/back camera.
  Future<void> switchCamera() async {
    CallLogger.info(_scope, 'switchCamera');
    final newTrack = await _mediaMgr.switchCamera();
    if (newTrack != null) {
      await _mediasoupMgr.replaceVideoTrack(newTrack);
    }
  }

  /// Toggle speaker/earpiece.
  Future<void> toggleSpeaker() async {
    isSpeakerOn.value = !isSpeakerOn.value;
    CallLogger.info(_scope, 'toggleSpeaker', {'speakerOn': isSpeakerOn.value});
    await _audioMgr.toggleSpeaker(isSpeakerOn.value);
    audioRoute.value = isSpeakerOn.value
        ? AudioOutputRoute.speaker
        : AudioOutputRoute.earpiece;
  }

  /// Cycle audio output route.
  Future<void> cycleAudioOutput() async {
    final newRoute = await _audioMgr.cycleOutput();
    audioRoute.value = newRoute;
    isSpeakerOn.value = newRoute == AudioOutputRoute.speaker;
    CallLogger.info(_scope, 'cycleAudioOutput', {'route': newRoute.name});
  }

  /// Manual reconnect trigger.
  void reconnect() {
    CallLogger.info(_scope, 'reconnect:manual');
    _recoveryMgr.scheduleFullRecovery('manual-reconnect', delay: Duration.zero);
  }

  // ═══════════════════════════════════════════════════════════════════
  // CALL SETUP FLOW
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _openCallScreen({
    required String roomId,
    required bool isVideoCall,
    required bool isJoinFlow,
    String? explicitUserName,
    String? explicitFullName,
  }) async {
    if (_isStarting || isCallActive.value) {
      CallLogger.warn(_scope, '_openCallScreen:skipped:already-active');
      return;
    }

    _isStarting = true;
    callState.value = GroupCallState.preparing;

    try {
      // Check internet connectivity before anything else
      final connectivity = await Connectivity().checkConnectivity();
      final hasInternet = connectivity.any((r) => r != ConnectivityResult.none);
      if (!hasInternet) {
        callState.value = GroupCallState.error;
        _isStarting = false;
        Get.snackbar(
          'No Internet',
          'Please check your internet connection and try again.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade800,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Get group details
      final groupName = await _getGroupDetailsById(roomId);
      _buildParticipantDirectory();

      // Request permissions
      final granted =
          await _mediaMgr.requestPermissions(isVideoCall: isVideoCall);
      if (!granted) {
        callState.value = GroupCallState.error;
        _isStarting = false;
        Get.snackbar(
            'Permission Required',
            isVideoCall
                ? 'Camera and microphone permissions are required.'
                : 'Microphone permission is required.');
        return;
      }

      // Set state
      _userId = explicitUserName ?? LocalStorage().getUserId();
      _userFullName = explicitFullName ?? LocalStorage().getUserName();
      currentRoomId.value = roomId;
      isThisVideoCall.value = isVideoCall;
      isMicEnabled.value = true;
      isCameraEnabled.value = isVideoCall;
      isSpeakerOn.value = isVideoCall;
      isCallActive.value = true;
      isAnyCallActive.value = true;
      isInOverlayMode.value = false;

      // Audio session
      await _audioMgr.activate();
      await _audioMgr.toggleSpeaker(isSpeakerOn.value);

      // Persist call state
      await LocalStorage().setIsAnyCallActive(true);
      await LocalStorage().setActiveCallRoomId(roomId);

      _isStarting = false;

      // Start network monitoring BEFORE navigating
      await _startNetworkMonitoring();

      // Navigate to call screen
      Get.to(() => GroupCallNewScreen(
            roomId: roomId,
            groupName: groupName,
            isVideoCall: isVideoCall,
            isMeeting: groupModel.value.isTemp == true,
          ));

      // Start call flow after navigation
      unawaited(_startCall(roomId: roomId, isVideoCall: isVideoCall));
    } catch (e) {
      CallLogger.error(
          _scope, '_openCallScreen:error', {'error': e.toString()});
      callState.value = GroupCallState.error;
      _isStarting = false;
      isCallActive.value = false;
      isAnyCallActive.value = false;
      await _audioMgr.deactivate();
      Get.snackbar('Call Error', 'Failed to start call: $e');
    }
  }

  /// Main call initialization flow following CALL_FEATURES_GUIDE.md exactly.
  Future<void> _startCall({
    required String roomId,
    required bool isVideoCall,
  }) async {
    final token = ++_startToken;
    CallLogger.info(_scope, '_startCall:begin', {
      'roomId': roomId,
      'token': token,
    });

    callState.value = GroupCallState.connecting;

    try {
      // 0. Pre-check connectivity
      try {
        final connectivity = await Connectivity().checkConnectivity();
        final hasNet = connectivity.any((r) => r != ConnectivityResult.none);
        if (!hasNet) {
          throw Exception('No internet connection');
        }
      } catch (e) {
        if (e.toString().contains('No internet')) rethrow;
      }
      if (_isStale(token)) return;

      // 1. Initialize local media
      CallLogger.info(_scope, '_startCall:initMedia');
      final localStream =
          await _mediaMgr.initLocalMedia(isVideoCall: isVideoCall);
      if (_isStale(token) || localStream == null) return;

      // Add local participant
      final localParticipant = CallParticipant(
        userId: _userId,
        displayName: _userFullName,
        isLocal: true,
        audioEnabled: true,
        videoEnabled: isVideoCall,
        renderer: _mediaMgr.localRenderer,
        stream: localStream,
        isVideoRendering: isVideoCall,
      );
      participants[_userId] = localParticipant;
      participants.refresh();

      // 2. Connect socket
      CallLogger.info(_scope, '_startCall:connectSocket');
      _setupSocketCallbacks();
      _socketMgr.connect(
        socketUrl: ApiPath.mediasoupSocketUrl,
        userId: _userId,
      );

      // Wait for socket connection
      await _waitForSocketConnection(token);
      if (_isStale(token)) return;

      // 3. Join room: BE-join-room
      CallLogger.info(_scope, '_startCall:joinRoom');
      final joinRes = await _socketMgr.joinRoom(
        roomId: roomId,
        userName: _userId,
        fullName: _userFullName,
        callType: isVideoCall ? 'video' : 'audio',
        video: isVideoCall,
        audio: true,
      );
      if (_isStale(token)) return;
      if (joinRes['ok'] != true) {
        throw Exception('BE-join-room failed: ${joinRes['error']}');
      }

      // 4. Get RTP capabilities: MS-get-rtp-capabilities
      CallLogger.info(_scope, '_startCall:getRtpCapabilities');
      final rtpRes = await _socketMgr.getRtpCapabilities(roomId: roomId);
      if (_isStale(token)) return;
      if (rtpRes['ok'] != true) {
        throw Exception('MS-get-rtp-capabilities failed');
      }

      // 5. Load mediasoup device
      CallLogger.info(_scope, '_startCall:loadDevice');
      await _mediasoupMgr.loadDevice(
        Map<String, dynamic>.from(rtpRes['rtpCapabilities'] as Map),
      );
      if (_isStale(token)) return;

      // 6. Get ICE servers: MS-get-ice-servers
      CallLogger.info(_scope, '_startCall:getIceServers');
      final iceRes = await _socketMgr.getIceServers();
      final iceServers = _buildIceServerList(iceRes);

      // 7. Create send transport: MS-create-transport(send)
      CallLogger.info(_scope, '_startCall:createSendTransport');
      await _createTransport('send', roomId, iceServers, token);
      if (_isStale(token)) return;

      // 8. Create recv transport: MS-create-transport(recv)
      CallLogger.info(_scope, '_startCall:createRecvTransport');
      await _createTransport('recv', roomId, iceServers, token);
      if (_isStale(token)) return;

      // 9. Setup recovery manager
      _setupRecoveryCallbacks();

      // 10. Produce audio
      CallLogger.info(_scope, '_startCall:produceAudio');
      final audioTrack = _mediaMgr.audioTrack;
      if (audioTrack != null) {
        await _mediasoupMgr.produceAudio(audioTrack, localStream);
      }
      if (_isStale(token)) return;

      // 11. Produce video (if video call)
      if (isVideoCall) {
        CallLogger.info(_scope, '_startCall:produceVideo');
        final videoTrack = _mediaMgr.videoTrack;
        if (videoTrack != null) {
          await _mediasoupMgr.produceVideo(videoTrack, localStream);
        }
        if (_isStale(token)) return;
      }

      // 12. Get existing producers and consume: MS-get-producers
      CallLogger.info(_scope, '_startCall:getProducers');
      await _consumeExistingProducers(roomId, token);
      if (_isStale(token)) return;

      // Done!
      callState.value = GroupCallState.connected;
      CallLogger.info(_scope, '_startCall:connected');

      // Start polling for ongoing recording status (every 5s)
      recordingMgr.startPolling(roomId);
    } catch (e) {
      if (_isStale(token)) return;
      CallLogger.error(_scope, '_startCall:error', {'error': e.toString()});
      callState.value = GroupCallState.error;
      Get.snackbar('Call Error', 'Failed to connect: ${e.toString()}');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // TRANSPORT CREATION
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _createTransport(
    String direction,
    String roomId,
    List<Map<String, dynamic>> iceServers,
    int token,
  ) async {
    final res = await _socketMgr.createTransport(
      roomId: roomId,
      userId: _userId,
      direction: direction,
    );

    if (res['ok'] != true) {
      throw Exception('MS-create-transport($direction) failed');
    }

    final transportId = res['id'] as String;
    final iceParams = Map<String, dynamic>.from(res['iceParameters'] as Map);
    final iceCandidates = res['iceCandidates'] as List;
    final dtlsParams = Map<String, dynamic>.from(res['dtlsParameters'] as Map);

    if (direction == 'send') {
      _mediasoupMgr.onSendTransportConnect = ({
        required transportId,
        required dtlsParameters,
      }) async {
        CallLogger.info(_scope, 'sendTransport:connect:signal');
        await _socketMgr.connectTransport(
          roomId: roomId,
          userId: _userId,
          transportId: transportId,
          dtlsParameters: dtlsParameters.toMap(),
        );
      };

      _mediasoupMgr.onSendTransportProduce = ({
        required transportId,
        required kind,
        required rtpParameters,
      }) async {
        CallLogger.info(_scope, 'sendTransport:produce:signal', {'kind': kind});
        final res = await _socketMgr.produce(
          roomId: roomId,
          userId: _userId,
          transportId: transportId,
          kind: kind,
          rtpParameters: rtpParameters.toMap(),
        );
        return res['id'] as String? ?? '';
      };

      await _mediasoupMgr.createSendTransport(
        id: transportId,
        iceParameters: iceParams,
        iceCandidates: iceCandidates,
        dtlsParameters: dtlsParams,
        iceServers: iceServers,
      );
    } else {
      _mediasoupMgr.onRecvTransportConnect = ({
        required transportId,
        required dtlsParameters,
      }) async {
        CallLogger.info(_scope, 'recvTransport:connect:signal');
        await _socketMgr.connectTransport(
          roomId: roomId,
          userId: _userId,
          transportId: transportId,
          dtlsParameters: dtlsParameters.toMap(),
        );
      };

      await _mediasoupMgr.createRecvTransport(
        id: transportId,
        iceParameters: iceParams,
        iceCandidates: iceCandidates,
        dtlsParameters: dtlsParams,
        iceServers: iceServers,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONSUMING REMOTE PRODUCERS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _consumeExistingProducers(String roomId, int token) async {
    final res = await _socketMgr.getProducers(
      roomId: roomId,
      userId: _userId,
    );

    if (res['ok'] != true) {
      CallLogger.warn(_scope, 'getProducers:failed', {'res': res});
      return;
    }

    final producers = res['producers'] as List? ?? [];
    CallLogger.info(_scope, 'consumeExisting', {'count': producers.length});

    for (final p in producers) {
      if (_isStale(token)) return;
      final producer = Map<String, dynamic>.from(p as Map);
      await _consumeProducer(
        producerId: producer['producerId'] as String,
        userId: producer['userId'] as String,
        kind: producer['kind'] as String,
      );
    }
  }

  /// Debounce timer for refreshing existing renderers after new consumers.
  Timer? _rendererRefreshTimer;

  Future<void> _consumeProducer({
    required String producerId,
    required String userId,
    required String kind,
  }) async {
    final roomId = currentRoomId.value;
    final rtpCaps = _mediasoupMgr.rtpCapabilities;
    if (rtpCaps == null) {
      CallLogger.warn(_scope, '_consumeProducer:no-rtp-caps');
      return;
    }

    CallLogger.info(_scope, '_consumeProducer', {
      'producerId': producerId,
      'userId': userId,
      'kind': kind,
    });

    // MS-consume — get consumer params from server
    final res = await _socketMgr.consumeProducer(
      roomId: roomId,
      userId: _userId,
      producerId: producerId,
      rtpCapabilities: rtpCaps.toMap(),
    );

    if (res['ok'] != true) {
      CallLogger.warn(_scope, '_consumeProducer:server-rejected', {
        'error': res['error'],
      });
      return;
    }

    final consumerId = res['id'] as String;
    final rtpParams = Map<String, dynamic>.from(res['rtpParameters'] as Map);

    // Consume via mediasoup recv transport (serialized queue)
    final consumer = await _mediasoupMgr.consume(
      consumerId: consumerId,
      producerId: producerId,
      peerId: userId,
      kind: kind,
      rtpParameters: rtpParams,
    );

    if (consumer == null) return;

    // Attach consumer to participant
    await _attachConsumerToParticipant(userId, kind, consumer);

    // MS-resume-consumer (consumers start paused on server)
    _socketMgr.resumeConsumer(
      roomId: roomId,
      userId: _userId,
      consumerId: consumerId,
    );

    // MS-set-preferred-layers (video only)
    if (kind == 'video') {
      _socketMgr.setPreferredLayers(
        roomId: roomId,
        userId: _userId,
        consumerId: consumerId,
        spatialLayer: 0,
        temporalLayer: 0,
      );

      // Schedule a debounced refresh of ALL existing remote renderers.
      // When a new user joins, we receive audio + video producers rapidly.
      // Each consume() triggers SDP renegotiation on the recv PeerConnection,
      // which can freeze existing video decoders. They need keyframes to recover.
      // We debounce to run ONCE after all the new user's producers are consumed.
      _scheduleRendererRefresh();
    }
  }

  /// Schedule a debounced refresh of all existing remote renderers.
  /// This runs 300ms after the last video consume to ensure SDP renegotiation
  /// has settled, then requests keyframes and reattaches all renderers.
  void _scheduleRendererRefresh() {
    _rendererRefreshTimer?.cancel();
    _rendererRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_refreshAllRemoteRenderers());
    });
  }

  /// Force-refresh all existing remote video renderers.
  /// Called after SDP renegotiation (new consumer added) to recover frozen decoders.
  ///
  /// This follows the same pattern as the web client's forceReattachAllRemoteVideos():
  /// 1. Request keyframes for all video consumers via MS-resume-consumer
  /// 2. Detach and reattach each renderer's srcObject
  Future<void> _refreshAllRemoteRenderers() async {
    final roomId = currentRoomId.value;

    final remoteVideoParticipants = participants.entries
        .where((e) => !e.value.isLocal && e.value.videoConsumer != null)
        .toList();

    if (remoteVideoParticipants.isEmpty) return;

    CallLogger.info(_scope, '_refreshAllRemoteRenderers', {
      'count': remoteVideoParticipants.length,
    });

    for (final entry in remoteVideoParticipants) {
      final participant = entry.value;
      final videoConsumer = participant.videoConsumer;
      if (videoConsumer == null) continue;

      // 1. Request keyframe from server by re-sending resume
      _socketMgr.resumeConsumer(
        roomId: roomId,
        userId: _userId,
        consumerId: videoConsumer.id,
      );

      // 2. Reattach renderer to force native video surface refresh
      if (participant.renderer != null && participant.stream != null) {
        final stream = participant.stream!;
        participant.renderer!.srcObject = null;
        await Future.delayed(const Duration(milliseconds: 80));
        participant.renderer!.srcObject = stream;

        CallLogger.info(_scope, '_refreshRenderer', {
          'userId': entry.key,
          'streamId': stream.id,
          'videoTracks': stream.getVideoTracks().length,
        });
      }
    }

    participants.refresh();
  }

  Future<void> _attachConsumerToParticipant(
    String userId,
    String kind,
    Consumer consumer,
  ) async {
    CallLogger.info(_scope, '_attachConsumer', {
      'userId': userId,
      'kind': kind,
      'consumerId': consumer.id,
      'trackId': consumer.track.id,
    });

    // Ensure participant exists with initialized renderer
    if (!participants.containsKey(userId)) {
      final displayName = _participantDirectory[userId] ?? 'User';
      final renderer = RTCVideoRenderer();
      await renderer.initialize();

      participants[userId] = CallParticipant(
        userId: userId,
        displayName: displayName,
        audioEnabled: true,
        videoEnabled: false,
        renderer: renderer,
      );
    }

    final participant = participants[userId]!;

    if (kind == 'audio') {
      participant.audioConsumer = consumer;
      participant.audioEnabled = true;
    } else {
      participant.videoConsumer = consumer;
      participant.videoEnabled = true;
      participant.isVideoRendering = true;

      // Use the consumer's own MediaStream directly.
      // The mediasoup-client library manages this stream internally and keeps
      // it in sync with the recv PeerConnection's track lifecycle.
      MediaStream videoStream = consumer.stream;

      // Verify the stream has the video track. If not, create one from the track.
      if (videoStream.getVideoTracks().isEmpty) {
        CallLogger.warn(_scope, '_attachConsumer:emptyStream:creating', {
          'userId': userId,
        });
        videoStream = await createLocalMediaStream('remote_video_$userId');
        await videoStream.addTrack(consumer.track);
      }

      participant.stream = videoStream;

      // Ensure renderer is initialized
      if (participant.renderer == null) {
        participant.renderer = RTCVideoRenderer();
        await participant.renderer!.initialize();
      }

      // Attach stream to renderer
      participant.renderer!.srcObject = videoStream;

      CallLogger.info(_scope, '_attachConsumer:rendererAttached', {
        'userId': userId,
        'streamId': videoStream.id,
        'videoTracks': videoStream.getVideoTracks().length,
      });
    }

    participant.isReconnecting = false;
    participants.refresh();
  }

  // ═══════════════════════════════════════════════════════════════════
  // SOCKET EVENT CALLBACKS
  // ═══════════════════════════════════════════════════════════════════

  void _setupSocketCallbacks() {
    _socketMgr.onConnected = () {
      CallLogger.info(_scope, 'socket:connected');
      if (_socketConnectCompleter != null &&
          !_socketConnectCompleter!.isCompleted) {
        _socketConnectCompleter!.complete();
      }
    };

    _socketMgr.onDisconnected = (reason) {
      CallLogger.warn(_scope, 'socket:disconnected', {'reason': reason});
      if (isCallActive.value) {
        // Mark all remote participants as reconnecting (show blur)
        for (final entry in participants.entries) {
          if (!entry.value.isLocal) {
            entry.value.isReconnecting = true;
          }
        }
        participants.refresh();
        callState.value = GroupCallState.reconnecting;
        _recoveryMgr.scheduleFullRecovery('socket-disconnect');
      }
    };

    _socketMgr.onReconnected = () {
      CallLogger.info(_scope, 'socket:reconnected');
      if (isCallActive.value) {
        _recoveryMgr.scheduleFullRecovery('socket-reconnect',
            delay: Duration.zero);
      }
    };

    _socketMgr.onConnectError = () {
      CallLogger.error(_scope, 'socket:connectError');
    };

    _socketMgr.onUserJoin = (users) {
      CallLogger.info(_scope, 'onUserJoin', {'count': users.length});
      for (final u in users) {
        final data = Map<String, dynamic>.from(u as Map);
        final socketId = data['userId']?.toString() ?? '';
        final info = data['info'] is Map
            ? Map<String, dynamic>.from(data['info'] as Map)
            : <String, dynamic>{};
        final oderId = info['userName']?.toString() ?? socketId;
        final displayName = info['fullName']?.toString() ??
            info['name']?.toString() ??
            _participantDirectory[oderId] ??
            'User';
        final hasVideo = info['video'] == true;
        final hasAudio = info['audio'] != false;

        if (oderId == _userId) continue; // skip self

        _ensureParticipant(
          userId: oderId,
          socketId: socketId,
          displayName: displayName,
          audioEnabled: hasAudio,
          videoEnabled: hasVideo,
        );
      }
    };

    _socketMgr.onUserLeave = (data) {
      final oderId =
          data['userName']?.toString() ?? data['userId']?.toString() ?? '';
      CallLogger.info(_scope, 'onUserLeave', {'userId': oderId});
      _removeParticipant(oderId);
    };

    _socketMgr.onUserDisconnected = (data) {
      final oderId =
          data['userName']?.toString() ?? data['userId']?.toString() ?? '';
      CallLogger.info(_scope, 'onUserDisconnected', {'userId': oderId});
      // Don't remove - mark as reconnecting (blur effect)
      final participant = participants[oderId];
      if (participant != null) {
        participant.isReconnecting = true;
        participants.refresh();
      }
    };

    _socketMgr.onToggleCamera = (data) {
      final oderId =
          data['userName']?.toString() ?? data['userId']?.toString() ?? '';
      final target = data['switchTarget']?.toString() ?? '';
      CallLogger.info(_scope, 'onToggleCamera', {
        'userId': oderId,
        'target': target,
      });

      final participant = participants[oderId];
      if (participant != null) {
        if (target == 'audio') {
          participant.audioEnabled = !participant.audioEnabled;
        } else if (target == 'video') {
          participant.videoEnabled = !participant.videoEnabled;
        }
        participants.refresh();
      }
    };

    _socketMgr.onCallEnded = () {
      CallLogger.info(_scope, 'onCallEnded');
      leaveCall();
    };

    _socketMgr.onNewProducer = (data) {
      final producerId = data['producerId']?.toString() ?? '';
      final userId = data['userId']?.toString() ?? '';
      final kind = data['kind']?.toString() ?? '';
      CallLogger.info(_scope, 'onNewProducer', {
        'producerId': producerId,
        'userId': userId,
        'kind': kind,
      });
      if (producerId.isNotEmpty && userId.isNotEmpty) {
        unawaited(_consumeProducer(
          producerId: producerId,
          userId: userId,
          kind: kind,
        ));
      }
    };

    // --- Screen recording events ---
    _socketMgr.onRecordingStarted = (data) {
      recordingMgr.onRecordingStarted(data);
    };
    _socketMgr.onRecordingStopped = (data) {
      recordingMgr.onRecordingStopped(data);
    };
    _socketMgr.onRecordingError = (data) {
      recordingMgr.onRecordingError(data);
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // RECOVERY CALLBACKS
  // ═══════════════════════════════════════════════════════════════════

  void _setupRecoveryCallbacks() {
    _mediasoupMgr.onConnectionStateChange = (direction, state) {
      _recoveryMgr.onTransportStateChange(direction, state);
    };

    _recoveryMgr.onIceRestart = (direction) async {
      CallLogger.info(_scope, 'recovery:iceRestart', {'direction': direction});
      final transport = direction == 'send'
          ? _mediasoupMgr.sendTransport
          : _mediasoupMgr.recvTransport;
      if (transport == null) return;

      final res = await _socketMgr.restartIce(
        roomId: currentRoomId.value,
        userId: _userId,
        transportId: transport.id,
      );

      if (res['ok'] == true && res['iceParameters'] != null) {
        final iceParams = IceParameters.fromMap(
            Map<String, dynamic>.from(res['iceParameters'] as Map));
        _mediasoupMgr.restartIce(direction, iceParams);
      }
    };

    _recoveryMgr.onFullRecovery = (reason) async {
      CallLogger.info(_scope, 'recovery:full', {'reason': reason});
      callState.value = GroupCallState.reconnecting;

      final roomId = currentRoomId.value;
      final isVideoCall = isThisVideoCall.value;

      // 1. Close old mediasoup (transports, producers, consumers)
      _mediasoupMgr.dispose();

      // 2. Dispose old remote participant renderers (keep local)
      for (final entry in participants.entries.toList()) {
        if (!entry.value.isLocal) {
          entry.value.isReconnecting = true;
        }
      }
      participants.refresh();

      // 3. Always re-init local media — old tracks are dead after transport close
      await _mediaMgr.dispose();
      final localStream =
          await _mediaMgr.initLocalMedia(isVideoCall: isVideoCall);
      if (localStream == null) {
        throw Exception('Failed to re-init local media');
      }

      // Update local participant with fresh renderer/stream
      final localParticipant = participants[_userId];
      if (localParticipant != null) {
        localParticipant.renderer = _mediaMgr.localRenderer;
        localParticipant.stream = localStream;
        localParticipant.isVideoRendering = isVideoCall;
        participants.refresh();
      }

      // 4. Re-join the room (new socket ID after reconnect)
      CallLogger.info(_scope, 'recovery:rejoinRoom');
      final joinRes = await _socketMgr.joinRoom(
        roomId: roomId,
        userName: _userId,
        fullName: _userFullName,
        callType: isVideoCall ? 'video' : 'audio',
        video: isVideoCall,
        audio: true,
      );
      if (joinRes['ok'] != true) {
        throw Exception('RE-join room failed: ${joinRes['error']}');
      }

      // 5. Re-init mediasoup device
      final rtpRes = await _socketMgr.getRtpCapabilities(roomId: roomId);
      if (rtpRes['ok'] != true) throw Exception('RTP capabilities failed');

      await _mediasoupMgr.loadDevice(
          Map<String, dynamic>.from(rtpRes['rtpCapabilities'] as Map));

      final iceRes = await _socketMgr.getIceServers();
      final iceServers = _buildIceServerList(iceRes);

      // 6. Create fresh transports
      await _createTransport('send', roomId, iceServers, _startToken);
      await _createTransport('recv', roomId, iceServers, _startToken);
      _setupRecoveryCallbacks();

      // 7. Produce with fresh tracks
      final audioTrack = _mediaMgr.audioTrack;
      if (audioTrack != null) {
        await _mediasoupMgr.produceAudio(audioTrack, localStream);
        if (!isMicEnabled.value) {
          _mediasoupMgr.pauseAudioProducer();
        }
      }

      if (isVideoCall) {
        final videoTrack = _mediaMgr.videoTrack;
        if (videoTrack != null) {
          await _mediasoupMgr.produceVideo(videoTrack, localStream);
          if (!isCameraEnabled.value) {
            _mediasoupMgr.pauseVideoProducer();
          }
        }
      }

      // 8. Re-consume all remote producers
      await _consumeExistingProducers(roomId, _startToken);

      // 9. Mark all participants as not reconnecting
      for (final p in participants.values) {
        p.isReconnecting = false;
      }
      participants.refresh();

      callState.value = GroupCallState.connected;
      CallLogger.info(_scope, 'recovery:complete');
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // NETWORK MONITORING
  // ═══════════════════════════════════════════════════════════════════

  Timer? _networkPollTimer;
  bool _isEndingDueToNetwork = false;

  Future<void> _startNetworkMonitoring() async {
    _connectivitySub?.cancel();
    _networkPollTimer?.cancel();
    _isEndingDueToNetwork = false;
    callEndReason.value = null;

    // Capture initial connectivity state
    try {
      _lastConnectivity = await Connectivity().checkConnectivity();
      CallLogger.info(_scope, 'networkMonitoring:initial', {
        'connectivity':
            _lastConnectivity?.map((r) => r.name).toList().toString(),
      });
    } catch (e) {
      CallLogger.warn(
          _scope, 'networkMonitoring:initialCheckFailed', {'error': '$e'});
    }

    // Stream-based listener for connectivity changes
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);

    // Periodic poll as backup (every 3s) — catches changes missed in PIP/background
    _networkPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!isCallActive.value || _isEndingDueToNetwork) return;
      try {
        final current = await Connectivity().checkConnectivity();
        _handleConnectivityChange(current);
      } catch (_) {}
    });

    CallLogger.info(_scope, 'networkMonitoring:started');
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (!isCallActive.value || _isEndingDueToNetwork) return;

    CallLogger.info(_scope, 'connectivity:changed', {
      'results': results.map((r) => r.name).toList().toString(),
      'previous': _lastConnectivity?.map((r) => r.name).toList().toString(),
    });

    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    final hadConnection = _lastConnectivity == null ||
        _lastConnectivity!.any((r) => r != ConnectivityResult.none);

    // Case 1: Internet disconnected
    if (!hasConnection) {
      if (hadConnection) {
        CallLogger.warn(_scope, 'connectivity:lost');
        _endCallDueToNetwork('Internet disconnected. Call ended.');
      }
      _lastConnectivity = results;
      return;
    }

    // Case 2: Network type changed (wifi <-> mobile)
    if (_lastConnectivity != null && hadConnection) {
      final prevTypes =
          _lastConnectivity!.where((r) => r != ConnectivityResult.none).toSet();
      final newTypes =
          results.where((r) => r != ConnectivityResult.none).toSet();

      if (prevTypes.isNotEmpty &&
          newTypes.isNotEmpty &&
          !prevTypes.any((t) => newTypes.contains(t))) {
        CallLogger.warn(_scope, 'connectivity:networkSwitch', {
          'from': prevTypes.map((r) => r.name).toList().toString(),
          'to': newTypes.map((r) => r.name).toList().toString(),
        });
        _endCallDueToNetwork(
            'Network changed (${_networkName(prevTypes.first)} → ${_networkName(newTypes.first)}). Call ended.');
        _lastConnectivity = results;
        return;
      }
    }

    _lastConnectivity = results;
  }

  void _stopNetworkMonitoring() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _networkPollTimer?.cancel();
    _networkPollTimer = null;
    _lastConnectivity = null;
    _isEndingDueToNetwork = false;
    CallLogger.info(_scope, 'networkMonitoring:stopped');
  }

  String _networkName(ConnectivityResult r) {
    switch (r) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      default:
        return r.name;
    }
  }

  Future<void> _endCallDueToNetwork(String reason) async {
    if (_isEndingDueToNetwork) return; // prevent double-end
    _isEndingDueToNetwork = true;

    CallLogger.warn(_scope, 'endCallDueToNetwork', {'reason': reason});
    callEndReason.value = reason;

    // Invalidate the start token so any in-progress _startCall aborts
    _startToken++;

    _stopNetworkMonitoring();

    final roomId = currentRoomId.value;
    if (roomId.isNotEmpty && _userId.isNotEmpty) {
      try {
        _socketMgr.leaveRoom(roomId: roomId, leaver: _userId);
      } catch (_) {}
    }

    await _cleanup();
    _navigateAwayFromCallScreen();

    // Show the disconnect dialog after navigation settles.
    // Using Get.dialog ensures it works regardless of which screen is visible.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (callEndReason.value != null && callEndReason.value!.isNotEmpty) {
        final msg = callEndReason.value!;
        callEndReason.value = null;
        Get.dialog(
          AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.wifi_off, color: Colors.red, size: 36),
            title: const Text('Call Disconnected'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
          barrierDismissible: true,
        );
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  /// Navigate away from the call screen, handling all states:
  /// full screen, in-app PIP overlay, system PIP.
  ///
  /// The screen itself watches [isCallActive] and auto-pops when it goes false.
  /// This method handles the overlay removal as a safety net.
  void _navigateAwayFromCallScreen() {
    // Remove in-app PIP overlay if showing
    try {
      NewCallOverlayManager().remove();
    } catch (_) {}

    // Safety net: if the screen's worker didn't fire (e.g. already disposed),
    // try to pop from here as well.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (Get.currentRoute.contains('GroupCallNewScreen')) {
          Get.back();
        }
      } catch (e) {
        CallLogger.warn(_scope, '_navigateAway:fallback', {'error': '$e'});
      }
    });
  }

  Future<void> _ensureParticipant({
    required String userId,
    required String socketId,
    required String displayName,
    required bool audioEnabled,
    required bool videoEnabled,
  }) async {
    if (participants.containsKey(userId)) {
      final p = participants[userId]!;
      p.socketId = socketId;
      p.audioEnabled = audioEnabled;
      p.videoEnabled = videoEnabled;
      p.isReconnecting = false;
      participants.refresh();
      return;
    }

    final renderer = RTCVideoRenderer();
    await renderer.initialize();

    participants[userId] = CallParticipant(
      userId: userId,
      displayName: displayName,
      socketId: socketId,
      audioEnabled: audioEnabled,
      videoEnabled: videoEnabled,
      renderer: renderer,
    );
    participants.refresh();
  }

  Future<void> _removeParticipant(String oderId) async {
    final participant = participants.remove(oderId);
    if (participant != null) {
      // Remove consumers from mediasoup manager
      if (participant.audioConsumer != null) {
        _mediasoupMgr.removeConsumer(participant.audioConsumer!.producerId);
      }
      if (participant.videoConsumer != null) {
        _mediasoupMgr.removeConsumer(participant.videoConsumer!.producerId);
      }
      await participant.dispose();
      participants.refresh();
    }
  }

  Future<void> _waitForSocketConnection(int token) async {
    if (_socketMgr.isConnected) return;

    _socketConnectCompleter = Completer<void>();
    try {
      await _socketConnectCompleter!.future
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Socket connection timeout');
    } finally {
      _socketConnectCompleter = null;
    }

    if (_isStale(token) || !_socketMgr.isConnected) {
      throw Exception('Socket connection failed');
    }
  }

  bool _isStale(int token) => token != _startToken || !isCallActive.value;

  List<Map<String, dynamic>> _buildIceServerList(Map<String, dynamic> iceRes) {
    if (iceRes['ok'] == true && iceRes['iceServers'] is List) {
      return (iceRes['iceServers'] as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
    }
    // Fallback to .env ICE servers
    final config = GroupCallTurn.getOptimalIceConfig();
    final rawServers = config['iceServers'];
    if (rawServers is List) {
      return rawServers
          .whereType<Map>()
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
    }
    return [];
  }

  Future<String> _getGroupDetailsById(String groupId) async {
    try {
      final res = await _groupRepo.getGroupDetailsById(groupId: groupId);
      if (res.data != null) {
        groupModel.value = res.data!;
      }
      final name = groupModel.value.groupName;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return 'Group Call';
  }

  void _buildParticipantDirectory() {
    _participantDirectory.clear();
    final currentUsers = groupModel.value.currentUsers;
    if (currentUsers != null) {
      for (final user in currentUsers) {
        final id = user.sId ?? '';
        final name = user.name ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          _participantDirectory[id] = name;
        }
      }
    }
    final localId = LocalStorage().getUserId();
    final localName = LocalStorage().getUserName();
    if (localId.isNotEmpty && localName.isNotEmpty) {
      _participantDirectory[localId] = localName;
    }
  }

  Future<void> _cleanup() async {
    CallLogger.info(_scope, '_cleanup:start');

    isCallActive.value = false;
    isAnyCallActive.value = false;
    callState.value = GroupCallState.left;
    currentRoomId.value = '';
    isInOverlayMode.value = false;
    _isStarting = false;
    _socketConnectCompleter = null;
    _rendererRefreshTimer?.cancel();
    _rendererRefreshTimer = null;

    _stopNetworkMonitoring();
    recordingMgr.dispose();
    _recoveryMgr.dispose();

    // IMPORTANT: Dispose in correct order to prevent errors:
    // 1. First, clear all socket callbacks so no events fire during cleanup
    _socketMgr.onConnected = null;
    _socketMgr.onDisconnected = null;
    _socketMgr.onReconnected = null;
    _socketMgr.onConnectError = null;
    _socketMgr.onUserJoin = null;
    _socketMgr.onUserLeave = null;
    _socketMgr.onUserDisconnected = null;
    _socketMgr.onToggleCamera = null;
    _socketMgr.onCallEnded = null;
    _socketMgr.onNewProducer = null;
    _socketMgr.onRecordingStarted = null;
    _socketMgr.onRecordingStopped = null;
    _socketMgr.onRecordingError = null;

    // 2. Dispose mediasoup BEFORE disconnecting socket
    //    (prevents "PeerConnection is closed" errors)
    try {
      _mediasoupMgr.dispose();
    } catch (e) {
      CallLogger.warn(_scope, '_cleanup:mediasoup:error', {'error': '$e'});
    }

    // 3. Dispose all participant renderers
    for (final p in participants.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    participants.clear();

    // 4. Now disconnect socket
    _socketMgr.disconnect();

    // 5. Dispose local media
    try {
      await _mediaMgr.dispose();
    } catch (_) {}

    await _audioMgr.deactivate();
    _participantDirectory.clear();

    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}

    try {
      await CallService.stopService();
    } catch (_) {}

    await LocalStorage().setIsAnyCallActive(false);
    await LocalStorage().clearActiveCallRoomId();

    CallLogger.info(_scope, '_cleanup:done');
  }
}
