import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Commons/platform_channels.dart';
import 'package:cu_app/Widgets/toast_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' hide navigator;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'guest_call_turn.dart';
import '../../../services/screen_share_service.dart';

class GuestCallController extends GetxController {
  static const bool _debugLogs = true;
  static GuestCallController? activeInstance;
  GuestCallController({
    required this.roomId,
    required this.guestName,
    required this.guestEmail,
    required this.isVideoCall,
  });

  final String roomId;
  final String guestName;
  final String guestEmail;
  final bool isVideoCall;

  IO.Socket? socket;
  final RxString socketId = ''.obs;
  final RxBool isSocketConnected = false.obs;
  final RxBool isConnecting = false.obs;
  final RxBool isCallActive = false.obs;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RxMap<String, RTCVideoRenderer> remoteRenderers =
      <String, RTCVideoRenderer>{}.obs;
  final Map<String, RTCPeerConnection> peerConnections = {};
  final Map<String, MediaStream> remoteStreams = {};

  final RxBool isMicEnabled = true.obs;
  final RxBool isCameraEnabled = true.obs;
  final RxBool isSpeakerOn = true.obs;
  // when user switches to in-app overlay (floating mini video)
  RxBool isInOverlayMode = false.obs;

  // ── Screen Share ──────────────────────────────────────────────────────
  final ScreenShareService screenShareService = ScreenShareService();
  RxBool get isScreenSharing => screenShareService.isScreenSharing;

  /// Track which remote user is sharing their screen (userId or null).
  final RxnString remoteScreenSharingUserId = RxnString(null);

  final RxList<Map<String, dynamic>> chatMessages =
      <Map<String, dynamic>>[].obs;
  final RxInt unreadMessages = 0.obs;
  final RxBool isChatOpen = false.obs;
  final RxBool isChatLoading = false.obs;
  final List<Map<String, dynamic>> _pendingLocalMessages = [];
  final ApiClient _apiClient = ApiClient();
  bool _guestMessagesLoaded = false;

  final RxMap<String, bool> userAudioEnabled = <String, bool>{}.obs;
  final RxMap<String, String> userDisplayName = <String, String>{}.obs;
  final RxList<Map<String, dynamic>> joinedUsers = <Map<String, dynamic>>[].obs;
  final Set<String> _existingUserIds = {};
  final List<Map<String, dynamic>> _userQueue = [];
  final RxBool _isProcessingQueue = false.obs;
  Completer<bool>? _joinCheckCompleter;
  String? _lastOfferTargetId;
  Timer? _connectRetryTimer;

  MediaStream? localStream;

  @override
  void onInit() {
    super.onInit();
    activeInstance = this;
    isSpeakerOn.value = isVideoCall;
  }

  @override
  void onClose() {
    if (identical(activeInstance, this)) {
      activeInstance = null;
    }
    cleanupCall();
    super.onClose();
  }

  Future<void> startCall() async {
    if (isConnecting.value || isCallActive.value) return;
    if (roomId.isEmpty) {
      TostWidget().errorToast(title: 'Error', message: 'Invalid meeting id');
      return;
    }

    if (_debugLogs) {
      debugPrint('[GuestCall] startCall roomId=$roomId');
    }

    isConnecting(true);

    await _initializeRenderers();
    await configureAudioSession();
    await _getUserMedia(isVideoCall: isVideoCall);
    await setAudioToSpeaker(isSpeakerOn.value);

    if (localStream == null) {
      if (_debugLogs) {
        debugPrint('[GuestCall] localStream not ready');
      }
      isConnecting(false);
      return;
    }

    // Allow local preview to render even while socket connects.
    isConnecting(false);

    if (_debugLogs) {
      debugPrint('[GuestCall] localStream ready, connect socket');
    }

    _connectSocket();
  }

  void _connectSocket() {
    if (socket != null) return;

    socket = IO.io(ApiPath.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 20,
      'reconnectionDelay': 2000,
      'timeout': 8000,
      'forceNew': true,
      'multiplex': false,
    });

    socket?.on('connect', (_) {
      socketId.value = socket?.id ?? '';
      isSocketConnected(true);
      if (_debugLogs) {
        debugPrint('[GuestCall] socket connected id=${socket?.id}');
      }
      _connectRetryTimer?.cancel();
      _setupSocketListeners();
      _checkUserAndJoin();
    });

    socket?.on('disconnect', (_) {
      isSocketConnected(false);
      if (_debugLogs) {
        debugPrint('[GuestCall] socket disconnected');
      }
    });

    socket?.on('connect_error', (_) {
      isSocketConnected(false);
      isConnecting(false);
      if (_debugLogs) {
        debugPrint('[GuestCall] socket connect_error');
      }
      TostWidget().errorToast(
          title: 'Error', message: 'Could not connect to call server');
    });

    socket?.connect();

    _connectRetryTimer?.cancel();
    _connectRetryTimer = Timer(const Duration(seconds: 3), () {
      if (!(socket?.connected ?? false)) {
        if (_debugLogs) {
          debugPrint('[GuestCall] socket retry connect');
        }
        socket?.connect();
      }
    });
  }

  void _setupSocketListeners() {
    socket?.off('FE-user-join');
    socket?.on('FE-user-join', (data) {
      if (_debugLogs) {
        debugPrint('[GuestCall] FE-user-join: $data');
      }
      if (data is! List) return;

      final newUsers = <Map<String, dynamic>>[];
      for (final user in data) {
        if (user is Map<String, dynamic>) {
          final userId = user['userId']?.toString() ?? '';
          if (userId.isEmpty || userId == socket?.id) continue;
          if (_existingUserIds.contains(userId)) continue;
          if (_userQueue.any((qUser) => qUser['userId'] == userId)) continue;

          final hasInfo = user['info'] != null;
          if (hasInfo) {
            // New joiner with info → I'm an existing user, create offer
            newUsers.add(Map<String, dynamic>.from(user));
          } else {
            // Existing member without info → I just joined, they will call me
            // Track them but do NOT create an offer (avoids WebRTC glare)
            _existingUserIds.add(userId);
            if (_debugLogs) {
              debugPrint(
                  '[GuestCall] tracked existing user=$userId (no info), waiting for FE-receive-call');
            }
          }
        }
      }

      if (newUsers.isNotEmpty) {
        _userQueue.addAll(newUsers);
        _processUserQueue();
      }
    });

    socket?.off('FE-receive-call');
    socket?.on('FE-receive-call', (data) {
      if (_debugLogs) {
        debugPrint('[GuestCall] FE-receive-call: $data');
      }
      if (data is Map<String, dynamic>) {
        final signal = data['signal'];
        final from = data['from'];
        final callerInfo = data['info'];
        if (from != null && signal != null) {
          _addPeer(from, signal, callerInfo);
        }
      }
    });

    socket?.off('FE-call-accepted');
    socket?.on('FE-call-accepted', (data) async {
      if (_debugLogs) {
        debugPrint('[GuestCall] FE-call-accepted: $data');
        debugPrint('[GuestCall] peer keys: ${peerConnections.keys.toList()}');
      }
      if (data is! Map<String, dynamic>) return;

      final signal = data['signal'];
      final answerId =
          (data['answerId'] ?? data['from'] ?? data['userId'])?.toString();
      if (answerId == null || signal is! Map<String, dynamic>) return;

      final sdp = signal['sdp'] as String?;
      final type = signal['type'] as String?;
      if (sdp == null || sdp.isEmpty || type != 'answer') return;

      final targetId = peerConnections.containsKey(answerId)
          ? answerId
          : (_lastOfferTargetId != null &&
                  peerConnections.containsKey(_lastOfferTargetId)
              ? _lastOfferTargetId!
              : (peerConnections.isNotEmpty
                  ? peerConnections.keys.first
                  : null));

      bool applied = false;

      if (targetId != null && peerConnections.containsKey(targetId)) {
        try {
          await peerConnections[targetId]
              ?.setRemoteDescription(RTCSessionDescription(sdp, type));
          applied = true;
        } catch (_) {}
      }

      if (!applied) {
        for (final entry in peerConnections.entries) {
          try {
            final remoteDesc = await entry.value.getRemoteDescription();
            if (remoteDesc != null) continue;
            await entry.value
                .setRemoteDescription(RTCSessionDescription(sdp, type));
            applied = true;
            break;
          } catch (_) {}
        }
      }

      if (applied) {
        setAudioToSpeaker(isSpeakerOn.value);
        final watchId = targetId ??
            (peerConnections.isNotEmpty ? peerConnections.keys.first : null);
        if (watchId != null) {
          Future.delayed(const Duration(seconds: 4), () {
            final pc = peerConnections[watchId];
            if (pc == null) return;
            final ice = pc.iceConnectionState;
            final hasStream = remoteStreams.containsKey(watchId);
            final connected =
                ice == RTCIceConnectionState.RTCIceConnectionStateConnected ||
                    ice == RTCIceConnectionState.RTCIceConnectionStateCompleted;
            if (!connected && !hasStream) {
              _handleConnectionFailure(watchId, pc);
            }
          });
        }
      }
    });

    socket?.off('FE-guest-disconnected');
    socket?.on('FE-guest-disconnected', (data) {
      if (_debugLogs) {
        debugPrint('[GuestCall] FE-guest-disconnected: $data');
      }
      if (data is! Map<String, dynamic>) return;
      final userId = data['userSocketId']?.toString();
      final room = data['roomId']?.toString();
      if (userId == null || room == null) return;
      if (room != roomId) return;

      _existingUserIds.remove(userId);
      joinedUsers.removeWhere((u) => u['userId'] == userId);
      _removePeer(userId);
    });

    socket?.off('FE-user-leave');
    socket?.on('FE-user-leave', (data) {
      if (data is! Map<String, dynamic>) return;
      final userId = (data['userId'] ?? data['userSocketId'] ?? data['leaver'])
          ?.toString();
      if (userId == null || userId.isEmpty) return;
      _existingUserIds.remove(userId);
      joinedUsers.removeWhere((u) => u['userId'] == userId);
      _removePeer(userId);
    });

    socket?.off('FE-user-disconnected');
    socket?.on('FE-user-disconnected', (data) {
      if (data is! Map<String, dynamic>) return;
      final userId =
          (data['userId'] ?? data['userSocketId'] ?? data['socketId'])
              ?.toString();
      if (userId == null || userId.isEmpty) return;
      _existingUserIds.remove(userId);
      joinedUsers.removeWhere((u) => u['userId'] == userId);
      _removePeer(userId);
    });

    socket?.off('FE-error-user-exist');
    socket?.on('FE-error-user-exist', (data) {
      if (_debugLogs) {
        debugPrint('[GuestCall] FE-error-user-exist: $data');
      }
      final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
      final error = payload['error'] == true;

      if (_joinCheckCompleter != null && !_joinCheckCompleter!.isCompleted) {
        _joinCheckCompleter!.complete(!error);
      }

      if (error) {
        isConnecting(false);
        isCallActive(false);
        TostWidget().errorToast(
            title: 'Error', message: 'User already in this meeting');
      }
    });

    // Optional: align with group call audio toggle events if server emits them
    socket?.off('FE-toggle-camera');
    socket?.on('FE-toggle-camera', (data) {
      if (data is! Map<String, dynamic>) return;
      final userId = data['userId']?.toString();
      if (userId == null || userId.isEmpty) return;
      if (data['switchTarget'] != 'audio') return;

      final provided = data['isEnabled'] ?? data['audio'] ?? data['enabled'];
      if (provided is bool) {
        userAudioEnabled[userId] = provided;
      } else {
        final current = userAudioEnabled[userId] ?? true;
        userAudioEnabled[userId] = !current;
      }
      userAudioEnabled.refresh();
    });

    socket?.off('message');
    socket?.on('message', (data) {
      _handleIncomingMessage(data);
    });
  }

  String _currentUserId() {
    if (guestEmail.isNotEmpty) return guestEmail;
    if (guestName.isNotEmpty) return guestName;
    return socket?.id ?? 'guest';
  }

  String _currentDisplayName() {
    if (guestName.isNotEmpty) return guestName;
    if (guestEmail.isNotEmpty) return guestEmail;
    return 'Guest';
  }

  void setChatOpen(bool isOpen) {
    isChatOpen.value = isOpen;
    if (isOpen) {
      unreadMessages.value = 0;
      _loadGuestMessagesIfNeeded();
      _emitReadForLatest();
    }
  }

  Future<void> sendChatMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (socket == null) return;

    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final localMessage = <String, dynamic>{
      'id': tempId,
      'senderId': _currentUserId(),
      'senderName': _currentDisplayName(),
      'content': trimmed,
      'timestamp': DateTime.now().toIso8601String(),
      'isLocal': true,
    };
    chatMessages.add(localMessage);
    _pendingLocalMessages.add(localMessage);

    final persisted = await _persistGuestMessage(trimmed, 'text');
    if (persisted != null) {
      _applyPersistedMessage(persisted, tempId);
      socket?.emit('message', {
        '_id': persisted['_id']?.toString(),
        'meetingId': roomId,
        'isGuestMeeting': true,
        'senderId': _currentUserId(),
        'time': persisted['createdAt']?.toString() ??
            DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _loadGuestMessagesIfNeeded({bool force = false}) async {
    if (_guestMessagesLoaded && !force) return;
    if (roomId.isEmpty) return;

    isChatLoading.value = true;
    final res = await _apiClient.getRequest<Map<String, dynamic>>(
      endPoint: EndPoints.getGuestMessages,
      queryParameters: {
        'meetingId': roomId,
        'limit': 20,
      },
      fromJson: (data) => data,
    );

    if (res.errorMessage == null && res.data != null) {
      final history = _extractGuestMessages(res.data!);
      _mergeChatHistory(history);
      _guestMessagesLoaded = true;
    }

    isChatLoading.value = false;
  }

  List<Map<String, dynamic>> _extractGuestMessages(
      Map<String, dynamic> payload) {
    dynamic raw = payload['data'] ?? payload['messages'] ?? payload['result'];
    if (raw is Map<String, dynamic>) {
      raw = raw['messages'] ?? raw['items'] ?? raw['data'];
    }
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_normalizeGuestMessage)
        .toList();
  }

  Map<String, dynamic> _normalizeGuestMessage(Map<String, dynamic> payload) {
    final content =
        payload['message'] ?? payload['content'] ?? payload['text'] ?? '';
    final senderId =
        payload['senderId']?.toString() ?? payload['sender']?.toString() ?? '';
    final senderName = payload['senderName']?.toString() ??
        payload['sender']?.toString() ??
        'Guest';
    final timestamp = payload['timestamp']?.toString() ??
        payload['createdAt']?.toString() ??
        payload['time']?.toString() ??
        DateTime.now().toIso8601String();

    return <String, dynamic>{
      'id': payload['_id']?.toString() ??
          payload['id']?.toString() ??
          'msg-${DateTime.now().microsecondsSinceEpoch}',
      'senderId': senderId,
      'senderName': senderName,
      'content': content.toString(),
      'timestamp': timestamp,
      'isLocal': senderId == _currentUserId(),
    };
  }

  void _mergeChatHistory(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return;
    final existingIds = chatMessages
        .map((message) => message['id']?.toString())
        .whereType<String>()
        .toSet();
    final newMessages = history
        .where((message) =>
            message['id'] != null &&
            !existingIds.contains(message['id'].toString()))
        .toList();
    if (newMessages.isEmpty) return;

    final combined = [...chatMessages, ...newMessages];
    combined.sort((a, b) {
      final aTime = _parseTimestamp(a['timestamp']?.toString());
      final bTime = _parseTimestamp(b['timestamp']?.toString());
      return aTime.compareTo(bTime);
    });
    chatMessages.assignAll(combined);
  }

  DateTime _parseTimestamp(String? value) {
    if (value == null || value.isEmpty)
      return DateTime.fromMillisecondsSinceEpoch(0);
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    final millis = int.tryParse(value);
    if (millis != null) {
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<Map<String, dynamic>?> _persistGuestMessage(
      String text, String messageType) async {
    final res = await _apiClient.postRequest<Map<String, dynamic>>(
      endPoint: EndPoints.addGuestMessage,
      reqModel: {
        'meetingId': roomId,
        'sender': guestEmail.isNotEmpty ? guestEmail : guestName,
        'senderId': _currentUserId(),
        'senderName': _currentDisplayName(),
        'content': text,
        'type': messageType,
      },
      fromJosn: (data) => data,
    );
    if (res.errorMessage != null || res.data == null) return null;
    final data = res.data?['data'];
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    return null;
  }

  void _applyPersistedMessage(Map<String, dynamic> payload, String tempId) {
    final normalized = _normalizeGuestMessage(payload);
    final messageId = normalized['id']?.toString();
    final tempIndex = chatMessages.indexWhere((m) => m['id'] == tempId);
    if (tempIndex != -1) {
      chatMessages[tempIndex] = normalized;
      chatMessages.refresh();
    } else if (messageId != null && !_messageIdExists(messageId)) {
      chatMessages.add(normalized);
    }
    _pendingLocalMessages.removeWhere((m) => m['id'] == tempId);
  }

  void _handleIncomingMessage(dynamic data) {
    final payload = _extractMessagePayload(data);
    if (payload == null) return;

    final content = payload['message'] ?? payload['content'];
    if (content == null || content.toString().trim().isEmpty) return;

    final senderId =
        payload['senderId']?.toString() ?? payload['sender']?.toString() ?? '';
    final senderName = payload['senderName']?.toString() ??
        payload['sender']?.toString() ??
        'Guest';
    final messageId = payload['_id']?.toString() ?? payload['id']?.toString();
    final timestamp = payload['timestamp']?.toString() ??
        payload['createdAt']?.toString() ??
        DateTime.now().toIso8601String();

    final normalized = <String, dynamic>{
      'id': messageId ??
          'msg-${DateTime.now().microsecondsSinceEpoch.toString()}',
      'senderId': senderId,
      'senderName': senderName,
      'content': content.toString(),
      'timestamp': timestamp,
      'isLocal': senderId == _currentUserId(),
    };

    if (messageId != null && _messageIdExists(messageId)) {
      return;
    }

    if (normalized['isLocal'] == true) {
      final pendingIndex = _pendingLocalMessages
          .indexWhere((m) => m['content']?.toString() == normalized['content']);
      if (pendingIndex != -1) {
        final pending = _pendingLocalMessages.removeAt(pendingIndex);
        chatMessages.removeWhere((m) => m['id'] == pending['id']);
      }
    }

    chatMessages.add(normalized);

    final msgId = payload['_id']?.toString();
    if (msgId != null && msgId.isNotEmpty) {
      _emitDeliver(msgId, payload['allRecipients']);
      if (normalized['isLocal'] == true) return;
      if (isChatOpen.value) {
        _emitRead(msgId);
      } else {
        unreadMessages.value += 1;
      }
    } else if (!isChatOpen.value && normalized['isLocal'] != true) {
      unreadMessages.value += 1;
    }
  }

  bool _messageIdExists(String messageId) {
    return chatMessages.any((message) => message['id'] == messageId);
  }

  Map<String, dynamic>? _extractMessagePayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return inner;
      if (inner is Map && inner['data'] is Map<String, dynamic>) {
        return inner['data'] as Map<String, dynamic>;
      }
      return data;
    }
    return null;
  }

  void _emitDeliver(String msgId, dynamic allRecipients) {
    final reciverId = <dynamic>[];
    if (allRecipients is List) {
      reciverId.addAll(allRecipients);
    }
    socket?.emit('deliver', {
      'msgId': msgId,
      'userId': _currentUserId(),
      'receiverId': reciverId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _emitRead(String msgId) {
    socket?.emit('read', {
      'msgId': msgId,
      'userId': _currentUserId(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _emitReadForLatest() {
    if (chatMessages.isEmpty) return;
    final last = chatMessages.last;
    if (last['isLocal'] == true) return;
    final msgId = last['id']?.toString();
    if (msgId == null || msgId.isEmpty) return;
    if (msgId.startsWith('local-')) return;
    _emitRead(msgId);
  }

  Future<void> _checkUserAndJoin() async {
    if (socket == null) return;

    final userName = guestEmail.isNotEmpty ? guestEmail : guestName;
    if (userName.isEmpty) {
      _joinRoom();
      return;
    }

    _joinCheckCompleter?.complete(true);
    _joinCheckCompleter = Completer<bool>();

    socket?.emit('BE-check-user', {
      'roomId': roomId,
      'userName': userName,
      'callType': isVideoCall ? 'video' : 'audio',
    });

    if (_debugLogs) {
      debugPrint('[GuestCall] BE-check-user roomId=$roomId userName=$userName');
    }

    final ok = await _joinCheckCompleter!.future
        .timeout(const Duration(seconds: 2), onTimeout: () => true);

    if (ok) {
      _joinRoom();
    }
  }

  void _joinRoom() {
    if (socket == null || localStream == null) return;

    isCallActive(true);
    // keep UI ready; local preview is already shown
    WakelockPlus.enable();

    if (_debugLogs) {
      debugPrint('[GuestCall] BE-join-guest-room roomId=$roomId');
    }

    socket?.emit('BE-join-guest-room', {
      'roomId': roomId,
      'callType': isVideoCall ? 'video' : 'audio',
      'userName': guestEmail.isNotEmpty ? guestEmail : guestName,
      'fullName': guestName.isNotEmpty ? guestName : 'Guest',
      'guestName': guestName,
      'guestEmail': guestEmail,
      'video': isVideoCall ? isCameraEnabled.value : false,
      'audio': isMicEnabled.value,
      'hasRealDevices': false,
      'constraints': {
        'audio': isMicEnabled.value,
        'video': isVideoCall ? isCameraEnabled.value : false,
      }
    });
  }

  Future<void> leaveCall() async {
    if (!isCallActive.value) {
      await cleanupCall();
      return;
    }

    isCallActive(false);
    isConnecting(false);

    final leaver = guestEmail.isNotEmpty ? guestEmail : guestName;
    socket?.emit('BE-leave-guest-room', {
      'roomId': roomId,
      'leaver': leaver.isNotEmpty ? leaver : 'guest',
    });

    await cleanupCall();
  }

  Future<void> cleanupCall() async {
    try {
      // Stop screen sharing first if active
      try {
        await screenShareService.dispose();
      } catch (_) {}

      _connectRetryTimer?.cancel();
      for (final pc in peerConnections.values) {
        try {
          pc.close();
        } catch (_) {}
      }
      peerConnections.clear();

      _existingUserIds.clear();
      _userQueue.clear();
      joinedUsers.clear();
      userAudioEnabled.clear();
      userDisplayName.clear();
      chatMessages.clear();
      unreadMessages.value = 0;
      isChatOpen.value = false;
      isChatLoading.value = false;
      _pendingLocalMessages.clear();
      _guestMessagesLoaded = false;

      for (final renderer in remoteRenderers.values) {
        try {
          renderer.srcObject = null;
          renderer.dispose();
        } catch (_) {}
      }
      remoteRenderers.clear();
      remoteStreams.clear();

      try {
        localRenderer.srcObject = null;
        await localRenderer.dispose();
      } catch (_) {}

      if (localStream != null) {
        for (final track in localStream!.getTracks()) {
          try {
            track.stop();
          } catch (_) {}
        }
        try {
          await localStream!.dispose();
        } catch (_) {}
      }
      localStream = null;

      try {
        await WakelockPlus.disable();
      } catch (_) {}

      try {
        socket?.clearListeners();
        socket?.disconnect();
        socket?.dispose();
      } catch (_) {}
      socket = null;
      if (identical(activeInstance, this)) {
        activeInstance = null;
      }
    } catch (_) {}
  }

  Future<void> _initializeRenderers() async {
    await localRenderer.initialize();
  }

  Future<MediaStream?> _getUserMedia({bool isVideoCall = true}) async {
    try {
      MediaStream stream;
      Map<String, dynamic> constraints;

      if (isVideoCall) {
        constraints = {
          'audio': true,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 480, 'max': 640},
            'height': {'ideal': 360, 'max': 480},
            'frameRate': {'ideal': 12, 'max': 15},
          }
        };
      } else {
        constraints = {
          'audio': true,
          'video': false,
        };
      }

      stream = await navigator.mediaDevices.getUserMedia(constraints);
      localStream = stream;
      localRenderer.srcObject = stream;

      final videoTracks = stream.getVideoTracks();
      final audioTracks = stream.getAudioTracks();

      isCameraEnabled.value =
          videoTracks.isNotEmpty && videoTracks.first.enabled;
      isMicEnabled.value = audioTracks.isNotEmpty && audioTracks.first.enabled;

      userAudioEnabled['local'] = isMicEnabled.value;
      userAudioEnabled.refresh();

      return stream;
    } catch (e) {
      TostWidget().errorToast(
          title: 'Media Access Denied',
          message: 'Could not access camera or microphone');
      return null;
    }
  }

  void toggleMic() {
    if (localStream == null) return;
    final audioTracks = localStream!.getAudioTracks();
    for (final track in audioTracks) {
      track.enabled = !track.enabled;
    }
    isMicEnabled.value = audioTracks.isNotEmpty && audioTracks.first.enabled;
    userAudioEnabled['local'] = isMicEnabled.value;
    userAudioEnabled.refresh();

    socket?.emit('BE-toggle-camera-audio', {
      'roomId': roomId,
      'userId': socket?.id,
      'switchTarget': 'audio',
      'enabled': isMicEnabled.value,
    });
  }

  void toggleCamera() {
    // Do not toggle the camera while screen sharing — it would disable the
    // screen-capture track on the WebRTC senders.
    if (isScreenSharing.value) return;
    if (localStream == null) return;
    final videoTracks = localStream!.getVideoTracks();
    for (final track in videoTracks) {
      track.enabled = !track.enabled;
    }
    isCameraEnabled.value = videoTracks.isNotEmpty && videoTracks.first.enabled;

    socket?.emit('BE-toggle-camera-audio', {
      'roomId': roomId,
      'userId': socket?.id,
      'switchTarget': 'video',
      'enabled': isCameraEnabled.value,
    });
  }

  Future<void> switchCamera() async {
    // Switching the camera is meaningless during screen sharing.
    if (isScreenSharing.value) return;
    if (localStream == null) return;
    final videoTracks = localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
    }
  }

  Future<void> setSpeakerMode(bool speakerOn) async {
    try {
      await PlatformChannels.iosaudioplatform.invokeMethod('setSpeakerMode', {
        'speakerOn': speakerOn,
      });
    } catch (_) {}
  }

  Future<void> configureAudioSession() async {
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
  }

  Future<void> setAudioToSpeaker([bool speakerOn = true]) async {
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
      await setSpeakerMode(speakerOn);
    } catch (_) {}
  }

  void toggleSpeaker() async {
    isSpeakerOn.value = !isSpeakerOn.value;
    await setAudioToSpeaker(isSpeakerOn.value);
  }

  /// Start screen sharing — replaces video track on all peers.
  Future<bool> startScreenShare() async {
    // return await screenShareService.startScreenShare(
    //   localStream: localStream,
    //   peerConnections: peerConnections,
    //   localRenderer: localRenderer,
    //   isVideoCall: isVideoCall,
    // );
    return false;
  }

  /// Stop screen sharing — restores camera track.
  Future<void> stopScreenShare() async {
    // await screenShareService.stopScreenShare(
    //   localStream: localStream,
    //   peerConnections: peerConnections,
    //   localRenderer: localRenderer,
    //   isVideoCall: isVideoCall,
    // );
    return;
  }

  /// Toggle screen share on/off.
  Future<void> toggleScreenShare() async {
    if (isScreenSharing.value) {
      await stopScreenShare();
    } else {
      await startScreenShare();
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String userId,
      {bool initiator = false}) async {
    if (localStream == null) {
      await _getUserMedia(isVideoCall: isVideoCall);
    }

    final config = GuestCallTurn.getOptimalIceConfig();
    final pc = await createPeerConnection(config);
    peerConnections[userId] = pc;

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        pc.addTrack(track, localStream!);
      }
      setAudioToSpeaker(isSpeakerOn.value);
    }

    pc.onIceCandidate = (candidate) {};

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _handleConnectionFailure(userId, pc);
      }
    };

    pc.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _handleConnectionFailure(userId, pc);
      }
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _handleRemoteStream(userId, event.streams[0]);
      } else {
        final existing = remoteStreams[userId];
        if (existing != null) {
          existing.addTrack(event.track);
          _handleRemoteStream(userId, existing);
        }
      }
    };

    pc.createDataChannel('chat', RTCDataChannelInit());

    if (initiator) {
      await _createOffer(userId, pc);
    }

    return pc;
  }

  Future<void> _handleConnectionFailure(
      String userId, RTCPeerConnection pc) async {
    if (!peerConnections.containsKey(userId)) return;

    try {
      try {
        final senders = await pc.getSenders();
        for (final sender in senders) {
          pc.removeTrack(sender);
        }
        pc.close();
      } catch (_) {}

      peerConnections.remove(userId);

      await Future.delayed(const Duration(milliseconds: 1500));

      if (!_existingUserIds.contains(userId)) return;
      await _createPeerConnection(userId, initiator: true);
    } catch (_) {}
  }

  Future<void> _createOffer(String userId, RTCPeerConnection pc) async {
    try {
      _lastOfferTargetId = userId;
      if (_debugLogs) {
        debugPrint('[GuestCall] createOffer userId=$userId');
      }
      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': isVideoCall,
      });

      await pc.setLocalDescription(offer);

      final completer = Completer<void>();
      pc.onIceGatheringState = (state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          if (!completer.isCompleted) completer.complete();
        }
      };

      await Future.any([
        completer.future,
        Future.delayed(const Duration(seconds: 4), () {
          if (!completer.isCompleted) completer.complete();
        })
      ]);

      pc.onIceGatheringState = null;

      final completeOffer = await pc.getLocalDescription();
      if (completeOffer == null) return;

      socket?.emit('BE-call-user', {
        'userToCall': userId,
        'from': socket?.id,
        'signal': {
          'type': completeOffer.type,
          'sdp': completeOffer.sdp,
        },
        'info': {
          'userName': guestEmail.isNotEmpty ? guestEmail : guestName,
          'fullName': guestName.isNotEmpty ? guestName : 'Guest',
          'video': isCameraEnabled.value,
          'audio': isMicEnabled.value,
          'mobileSDP': {},
        }
      });
      if (_debugLogs) {
        debugPrint('[GuestCall] BE-call-user to=$userId from=${socket?.id}');
      }
    } catch (_) {
      _handleConnectionFailure(userId, pc);
    }
  }

  Future<void> _addPeer(
      String callerId, dynamic incomingSignal, dynamic callerInfo) async {
    try {
      if (_debugLogs) {
        debugPrint('[GuestCall] addPeer from=$callerId');
      }
      _existingUserIds.add(callerId);
      if (callerInfo is Map) {
        final userName = callerInfo['userName']?.toString() ?? '';
        final fullName = callerInfo['fullName']?.toString() ?? 'Guest';
        userDisplayName[callerId] = fullName.isNotEmpty ? fullName : 'Guest';

        final audioEnabled = callerInfo['audio'];
        if (audioEnabled is bool) {
          userAudioEnabled[callerId] = audioEnabled;
        } else {
          userAudioEnabled[callerId] = true;
        }

        if (!joinedUsers.any((u) => u['userId'] == callerId)) {
          joinedUsers.add({
            'userId': callerId,
            'info': {'userName': userName, 'fullName': fullName}
          });
        }
      } else {
        userDisplayName[callerId] = 'Guest';
        userAudioEnabled[callerId] = true;
        if (!joinedUsers.any((u) => u['userId'] == callerId)) {
          joinedUsers.add({'userId': callerId});
        }
      }

      // Close any existing PC to avoid WebRTC glare (both sides as offerer)
      if (peerConnections.containsKey(callerId)) {
        if (_debugLogs) {
          debugPrint('[GuestCall] closing existing PC for $callerId (glare)');
        }
        try {
          peerConnections[callerId]?.close();
        } catch (_) {}
        peerConnections.remove(callerId);
        remoteStreams.remove(callerId);
      }

      await _createPeerConnection(callerId);
      final pc = peerConnections[callerId]!;

      if (localStream == null) {
        await _getUserMedia(isVideoCall: isVideoCall);
        // Add tracks to PC if media was obtained late
        if (localStream != null) {
          for (final track in localStream!.getTracks()) {
            pc.addTrack(track, localStream!);
          }
        }
      }

      try {
        await pc.setRemoteDescription(RTCSessionDescription(
            incomingSignal['sdp'], incomingSignal['type']));
      } catch (e) {
        if (_debugLogs) {
          debugPrint('[GuestCall] setRemoteDescription failed: $e');
        }
        return;
      }

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      // Wait for ICE gathering to complete (matches _createOffer behaviour)
      final iceCompleter = Completer<void>();
      pc.onIceGatheringState = (state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          if (!iceCompleter.isCompleted) iceCompleter.complete();
        }
      };

      await Future.any([
        iceCompleter.future,
        Future.delayed(const Duration(seconds: 4), () {
          if (!iceCompleter.isCompleted) iceCompleter.complete();
        })
      ]);

      pc.onIceGatheringState = null;

      final completeAnswer = await pc.getLocalDescription();
      if (completeAnswer == null) return;

      socket?.emit('BE-accept-call', {
        'signal': {
          'type': completeAnswer.type,
          'sdp': completeAnswer.sdp,
        },
        'to': callerId,
      });

      if (_debugLogs) {
        debugPrint('[GuestCall] BE-accept-call sent to=$callerId');
      }

      setAudioToSpeaker(isSpeakerOn.value);
    } catch (e) {
      if (_debugLogs) {
        debugPrint('[GuestCall] _addPeer error: $e');
      }
    }
  }

  void _processUserQueue() async {
    if (_isProcessingQueue.value) return;
    _isProcessingQueue.value = true;

    while (_userQueue.isNotEmpty) {
      final user = _userQueue.removeAt(0);
      await _setupNewPeer(user);
    }

    _isProcessingQueue.value = false;
  }

  Future<void> _setupNewPeer(Map<String, dynamic> user) async {
    final userId = user['userId']?.toString() ?? '';
    final userInfo = user['info'] as Map<String, dynamic>?;
    if (userId.isEmpty || userId == socket?.id) return;

    try {
      _existingUserIds.add(userId);
      final fullName = userInfo?['fullName']?.toString() ?? 'Guest';
      userDisplayName[userId] = fullName.isNotEmpty ? fullName : 'Guest';
      if (!joinedUsers.any((u) => u['userId'] == userId)) {
        joinedUsers.add(user);
      }

      final audioEnabled = userInfo?['audio'];
      if (audioEnabled is bool) {
        userAudioEnabled[userId] = audioEnabled;
      } else {
        userAudioEnabled[userId] = true;
      }

      await _createPeerConnection(userId, initiator: true);

      userAudioEnabled.refresh();
      userDisplayName.refresh();
      joinedUsers.refresh();
    } catch (_) {
      _existingUserIds.remove(userId);
      userDisplayName.remove(userId);
      joinedUsers.removeWhere((u) => u['userId'] == userId);
    }
  }

  void _handleRemoteStream(String userId, MediaStream stream) async {
    try {
      if (_debugLogs) {
        debugPrint('[GuestCall] remote stream userId=$userId');
      }
      if (!remoteRenderers.containsKey(userId)) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        remoteRenderers[userId] = renderer;
      }

      final renderer = remoteRenderers[userId]!;
      remoteStreams[userId] = stream;
      renderer.srcObject = stream;
      remoteRenderers.refresh();
    } catch (_) {}
  }

  Future<void> _removePeer(String userId) async {
    final pc = peerConnections[userId];
    final renderer = remoteRenderers[userId];

    if (pc != null) {
      try {
        pc.onIceCandidate = null;
        pc.onConnectionState = null;
        pc.onIceConnectionState = null;
        pc.onTrack = null;
        pc.close();
      } catch (_) {}
      peerConnections.remove(userId);
    }

    if (renderer != null) {
      try {
        renderer.srcObject = null;
        renderer.dispose();
      } catch (_) {}
      remoteRenderers.remove(userId);
      remoteStreams.remove(userId);
      userDisplayName.remove(userId);
      remoteRenderers.refresh();
    }
  }
}
