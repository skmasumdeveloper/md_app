import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'call_logger.dart';

/// Handles all Socket.IO signaling for the group call.
/// Follows exact backend event contract: BE-*, FE-*, MS-* events.
class CallSocketManager {
  static const String _scope = 'SocketMgr';

  io.Socket? _socket;
  bool _isConnected = false;
  bool _isStopping = false;

  /// Event callbacks set by the controller.
  void Function()? onConnected;
  void Function(String reason)? onDisconnected;
  void Function()? onReconnected;
  void Function()? onConnectError;
  void Function(List<dynamic> users)? onUserJoin;
  void Function(Map<String, dynamic> data)? onUserLeave;
  void Function(Map<String, dynamic> data)? onUserDisconnected;
  void Function(Map<String, dynamic> data)? onToggleCamera;
  void Function()? onCallEnded;
  void Function(Map<String, dynamic> data)? onNewProducer;
  void Function(Map<String, dynamic> data)? onRecordingStarted;
  void Function(Map<String, dynamic> data)? onRecordingStopped;
  void Function(Map<String, dynamic> data)? onRecordingError;

  bool get isConnected => _isConnected;
  io.Socket? get socket => _socket;

  /// Connect to the signaling server.
  void connect({
    required String socketUrl,
    required String userId,
  }) {
    CallLogger.info(_scope, 'connect:start', {'url': socketUrl});
    _isStopping = false;

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(40)
          .setReconnectionDelay(900)
          .setReconnectionDelayMax(5000)
          .setTimeout(20000)
          .build(),
    );

    _socket!.onConnect((_) {
      CallLogger.info(_scope, 'connected');
      _isConnected = true;
      _socket!.emit('joinSelf', userId);
      onConnected?.call();
    });

    _socket!.on('reconnect', (_) {
      CallLogger.info(_scope, 'reconnected');
      _isConnected = true;
      _socket!.emit('joinSelf', userId);
      onReconnected?.call();
    });

    _socket!.onDisconnect((reason) {
      CallLogger.warn(_scope, 'disconnected', {'reason': reason.toString()});
      _isConnected = false;
      if (!_isStopping) {
        onDisconnected?.call(reason.toString());
      }
    });

    _socket!.onConnectError((_) {
      CallLogger.error(_scope, 'connect_error');
      if (!_isStopping) {
        onConnectError?.call();
      }
    });

    // --- Presence / UX events ---
    _socket!.on('FE-user-join', (data) {
      CallLogger.info(_scope, 'FE-user-join', {'data': data.toString()});
      if (data is List) {
        onUserJoin?.call(data);
      }
    });

    _socket!.on('FE-user-leave', (data) {
      CallLogger.info(_scope, 'FE-user-leave', {'data': data.toString()});
      final map = _toMap(data);
      if (map != null) {
        onUserLeave?.call(map);
      }
    });

    _socket!.on('FE-user-disconnected', (data) {
      CallLogger.info(
          _scope, 'FE-user-disconnected', {'data': data.toString()});
      final map = _toMap(data);
      if (map != null) {
        onUserDisconnected?.call(map);
      }
    });

    _socket!.on('FE-toggle-camera', (data) {
      CallLogger.info(_scope, 'FE-toggle-camera', {'data': data.toString()});
      final map = _toMap(data);
      if (map != null) {
        onToggleCamera?.call(map);
      }
    });

    _socket!.on('FE-call-ended', (_) {
      CallLogger.info(_scope, 'FE-call-ended');
      onCallEnded?.call();
    });

    // --- Mediasoup events ---
    _socket!.on('MS-new-producer', (data) {
      CallLogger.info(_scope, 'MS-new-producer', {'data': data.toString()});
      final map = _toMap(data);
      if (map != null) {
        onNewProducer?.call(map);
      }
    });

    // --- Screen recording events ---
    _socket!.on('FE-screen-recording-started', (data) {
      CallLogger.info(
          _scope, 'FE-screen-recording-started', {'data': data.toString()});
      final map = _toMap(data);
      if (map != null) {
        onRecordingStarted?.call(map);
      }
    });

    _socket!.on('FE-screen-recording-stopped', (data) {
      CallLogger.info(
          _scope, 'FE-screen-recording-stopped', {'data': data.toString()});
      final map = _toMap(data);
      if (map != null) {
        onRecordingStopped?.call(map);
      }
    });

    _socket!.on('FE-screen-recording-error', (data) {
      CallLogger.info(
          _scope, 'FE-screen-recording-error', {'data': data.toString()});
      final map = _toMap(data);
      if (map != null) {
        onRecordingError?.call(map);
      }
    });

    _socket!.connect();
  }

  // ─── Emit helpers with ACK ────────────────────────────────────────────

  /// Emit with ACK and return the response map.
  Future<Map<String, dynamic>> emitAck(
      String event, Map<String, dynamic> payload,
      {Duration timeout = const Duration(seconds: 15)}) async {
    if (_socket == null || !_isConnected) {
      CallLogger.warn(_scope, 'emitAck:not-connected', {'event': event});
      return {'ok': false, 'error': 'not-connected'};
    }

    CallLogger.debug(_scope, 'emitAck:emit', {'event': event});

    final completer = Completer<Map<String, dynamic>>();

    _socket!.emitWithAck(event, payload, ack: (response) {
      final map = _toMap(response);
      CallLogger.debug(
          _scope, 'emitAck:response', {'event': event, 'response': map});
      if (!completer.isCompleted) {
        completer.complete(map ?? {'ok': false, 'error': 'invalid-response'});
      }
    });

    return completer.future.timeout(timeout, onTimeout: () {
      CallLogger.warn(_scope, 'emitAck:timeout', {'event': event});
      return {'ok': false, 'error': 'timeout'};
    });
  }

  /// Emit without expecting ACK.
  void emit(String event, [dynamic payload]) {
    if (_socket == null) {
      CallLogger.warn(_scope, 'emit:no-socket', {'event': event});
      return;
    }
    CallLogger.debug(_scope, 'emit', {'event': event});
    if (payload != null) {
      _socket!.emit(event, payload);
    } else {
      _socket!.emit(event);
    }
  }

  // ─── Signaling room events ───────────────────────────────────────────

  /// BE-join-room
  Future<Map<String, dynamic>> joinRoom({
    required String roomId,
    required String userName,
    required String fullName,
    required String callType,
    required bool video,
    required bool audio,
  }) async {
    return emitAck('BE-join-room', {
      'roomId': roomId,
      'userName': userName,
      'fullName': fullName,
      'callType': callType,
      'video': video,
      'audio': audio,
      'mobileSDP': {},
    });
  }

  /// BE-leave-room
  void leaveRoom({required String roomId, required String leaver}) {
    emit('BE-leave-room', {'roomId': roomId, 'leaver': leaver});
    CallLogger.info(
        _scope, 'leaveRoom', {'roomId': roomId, 'leaver': leaver});
  }

  /// BE-toggle-camera-audio
  void toggleCameraAudio(
      {required String roomId, required String switchTarget}) {
    emit('BE-toggle-camera-audio', {
      'roomId': roomId,
      'switchTarget': switchTarget,
    });
  }

  /// BE-reject-call
  void rejectCall({required String roomId}) {
    emit('BE-reject-call', {'roomId': roomId});
  }

  // ─── Mediasoup signaling ─────────────────────────────────────────────

  /// MS-get-rtp-capabilities
  Future<Map<String, dynamic>> getRtpCapabilities(
      {required String roomId}) async {
    return emitAck('MS-get-rtp-capabilities', {'roomId': roomId});
  }

  /// MS-get-ice-servers
  Future<Map<String, dynamic>> getIceServers() async {
    return emitAck('MS-get-ice-servers', {});
  }

  /// MS-create-transport
  Future<Map<String, dynamic>> createTransport({
    required String roomId,
    required String userId,
    required String direction,
  }) async {
    return emitAck('MS-create-transport', {
      'roomId': roomId,
      'userId': userId,
      'direction': direction,
    });
  }

  /// MS-connect-transport
  Future<Map<String, dynamic>> connectTransport({
    required String roomId,
    required String userId,
    required String transportId,
    required Map<String, dynamic> dtlsParameters,
  }) async {
    return emitAck('MS-connect-transport', {
      'roomId': roomId,
      'userId': userId,
      'transportId': transportId,
      'dtlsParameters': dtlsParameters,
    });
  }

  /// MS-produce
  Future<Map<String, dynamic>> produce({
    required String roomId,
    required String userId,
    required String transportId,
    required String kind,
    required Map<String, dynamic> rtpParameters,
  }) async {
    return emitAck('MS-produce', {
      'roomId': roomId,
      'userId': userId,
      'transportId': transportId,
      'kind': kind,
      'rtpParameters': rtpParameters,
    });
  }

  /// MS-get-producers
  Future<Map<String, dynamic>> getProducers({
    required String roomId,
    required String userId,
  }) async {
    return emitAck('MS-get-producers', {
      'roomId': roomId,
      'userId': userId,
    });
  }

  /// MS-consume
  Future<Map<String, dynamic>> consumeProducer({
    required String roomId,
    required String userId,
    required String producerId,
    required Map<String, dynamic> rtpCapabilities,
  }) async {
    return emitAck('MS-consume', {
      'roomId': roomId,
      'userId': userId,
      'producerId': producerId,
      'rtpCapabilities': rtpCapabilities,
    });
  }

  /// MS-resume-consumer
  void resumeConsumer({
    required String roomId,
    required String userId,
    required String consumerId,
  }) {
    emit('MS-resume-consumer', {
      'roomId': roomId,
      'userId': userId,
      'consumerId': consumerId,
    });
  }

  /// MS-set-preferred-layers
  void setPreferredLayers({
    required String roomId,
    required String userId,
    required String consumerId,
    int spatialLayer = 0,
    int temporalLayer = 0,
  }) {
    emit('MS-set-preferred-layers', {
      'roomId': roomId,
      'userId': userId,
      'consumerId': consumerId,
      'spatialLayer': spatialLayer,
      'temporalLayer': temporalLayer,
    });
  }

  /// MS-restart-ice
  Future<Map<String, dynamic>> restartIce({
    required String roomId,
    required String userId,
    required String transportId,
  }) async {
    return emitAck('MS-restart-ice', {
      'roomId': roomId,
      'userId': userId,
      'transportId': transportId,
    });
  }

  // ─── Utility ─────────────────────────────────────────────────────────

  Map<String, dynamic>? _toMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Disconnect and cleanup the socket.
  void disconnect() {
    CallLogger.info(_scope, 'disconnect');
    _isStopping = true;
    _isConnected = false;

    onConnected = null;
    onDisconnected = null;
    onReconnected = null;
    onConnectError = null;
    onUserJoin = null;
    onUserLeave = null;
    onUserDisconnected = null;
    onToggleCamera = null;
    onCallEnded = null;
    onNewProducer = null;
    onRecordingStarted = null;
    onRecordingStopped = null;
    onRecordingError = null;

    try {
      _socket?.clearListeners();
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }
}
