part of 'group_call.dart';

extension GroupCallUtilsExtension on GroupcallController {
  updateBuildContext(BuildContext context1) {
    context = context1;
  }

  void logMemoryUsage() {
    final memory = ProcessInfo.currentRss / 1024 / 1024; // MB
    debugPrint('[Utils] Memory usage: ${memory.toStringAsFixed(1)} MB');
  }

  Future<bool> _waitForSocketReady({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final endAt = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endAt)) {
      final activeSocket = socketController.socket ?? socket;
      if (activeSocket != null && activeSocket.connected) {
        socket = activeSocket;
        isMainSocketConnected.value = true;
        return true;
      }

      try {
        socketController.reconnectSocket();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 250));
    }

    return false;
  }

  // Helper: emit a socket event and return the server's ack response as a Future.
  // socket_io_client's emitWithAck does not return a Future, so we wrap it.
  Future<dynamic> socketEmitWithAck(String event, Map<String, dynamic> data,
      {Duration timeout = const Duration(seconds: 15)}) async {
    debugPrint(
        '[Socket] ➜ emitWithAck: event=$event data_keys=${data.keys.toList()}');

    final isMediasoupEvent = event.startsWith('MS-');
    final maxAttempts = isMediasoupEvent ? 2 : 1;
    final effectiveTimeout = isMediasoupEvent && timeout.inSeconds < 20
        ? const Duration(seconds: 20)
        : timeout;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final ready = await _waitForSocketReady(
        timeout: const Duration(seconds: 8),
      );
      if (!ready) {
        debugPrint(
            '[Socket] ✗ emitWithAck FAILED: socket not connected for event=$event attempt=$attempt/$maxAttempts');
        if (attempt == maxAttempts) return null;
        continue;
      }

      final activeSocket = socketController.socket ?? socket;
      if (activeSocket == null) {
        debugPrint(
            '[Socket] ✗ emitWithAck FAILED: active socket is null for event=$event attempt=$attempt/$maxAttempts');
        if (attempt == maxAttempts) return null;
        continue;
      }

      final completer = Completer<dynamic>();

      activeSocket.emitWithAck(event, data, ack: (response) {
        if (!completer.isCompleted) {
          final normalized = _normalizeAckResponse(response);
          debugPrint(
              '[Socket] ✓ ack received: event=$event raw_type=${response.runtimeType} normalized_ok=${normalized is Map ? normalized['ok'] : 'N/A'} attempt=$attempt/$maxAttempts');
          completer.complete(normalized);
        }
      });

      final result = await Future.any<dynamic>([
        completer.future,
        Future.delayed(effectiveTimeout, () => null),
      ]);

      if (result != null) {
        return result;
      }

      debugPrint(
          '[Socket] ✗ emitWithAck TIMEOUT for event=$event (${effectiveTimeout.inSeconds}s) attempt=$attempt/$maxAttempts');

      if (attempt < maxAttempts) {
        await _waitForSocketReady(timeout: const Duration(seconds: 10));
      }
    }

    return null;
  }

  // Helper variant for events where server expects only ack callback (no payload).
  Future<dynamic> socketEmitWithAckNoData(String event,
      {Duration timeout = const Duration(seconds: 15)}) async {
    debugPrint('[Socket] ➜ emitWithAck(no-data): event=$event');

    final isMediasoupEvent = event.startsWith('MS-');
    final maxAttempts = isMediasoupEvent ? 2 : 1;
    final effectiveTimeout = isMediasoupEvent && timeout.inSeconds < 20
        ? const Duration(seconds: 20)
        : timeout;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final ready = await _waitForSocketReady(
        timeout: const Duration(seconds: 8),
      );
      if (!ready) {
        debugPrint(
            '[Socket] ✗ emitWithAck(no-data) FAILED: socket not connected for event=$event attempt=$attempt/$maxAttempts');
        if (attempt == maxAttempts) return null;
        continue;
      }

      final activeSocket = socketController.socket ?? socket;
      if (activeSocket == null) {
        debugPrint(
            '[Socket] ✗ emitWithAck(no-data) FAILED: active socket is null for event=$event attempt=$attempt/$maxAttempts');
        if (attempt == maxAttempts) return null;
        continue;
      }

      final completer = Completer<dynamic>();

      activeSocket.emitWithAck(event, const <String, dynamic>{},
          ack: (response) {
        if (!completer.isCompleted) {
          final normalized = _normalizeAckResponse(response);
          debugPrint(
              '[Socket] ✓ ack(no-data) received: event=$event raw_type=${response.runtimeType} normalized_ok=${normalized is Map ? normalized['ok'] : 'N/A'} attempt=$attempt/$maxAttempts');
          completer.complete(normalized);
        }
      });

      final result = await Future.any<dynamic>([
        completer.future,
        Future.delayed(effectiveTimeout, () => null),
      ]);

      if (result != null) {
        return result;
      }

      debugPrint(
          '[Socket] ✗ emitWithAck(no-data) TIMEOUT for event=$event (${effectiveTimeout.inSeconds}s) attempt=$attempt/$maxAttempts');

      if (attempt < maxAttempts) {
        await _waitForSocketReady(timeout: const Duration(seconds: 10));
      }
    }

    return null;
  }

  /// Normalize socket.io ack response.
  /// socket_io_client 3.x can wrap the ack data in a List — unwrap it.
  dynamic _normalizeAckResponse(dynamic response) {
    if (response is List && response.isNotEmpty) {
      debugPrint(
          '[Socket] Normalizing List ack response (length=${response.length}) to ${response.first.runtimeType}');
      return response.first;
    }
    return response;
  }

  // This method checks if the call is active for a specific group.
  Future<bool> checkCallActiveCall(String groupId) async {
    return isCallActive.value && currentRoomId.value == groupId;
  }

  // This method logs the current connection states for debugging.
  void logConnectionStates() {
    debugPrint('[Utils] ═══ Connection State Dump ═══');
    debugPrint('[Utils] MediaSoup initialized: $_mediasoupInitialized');
    debugPrint('[Utils] Device: ${_msDevice != null ? "loaded" : "null"}');
    debugPrint(
        '[Utils] Send transport: ${_sendTransport != null ? _sendTransport!.id : "null"}');
    debugPrint(
        '[Utils] Recv transport: ${_recvTransport != null ? _recvTransport!.id : "null"}');
    debugPrint(
        '[Utils] Audio producer: ${_audioProducer != null ? _audioProducer!.id : "null"}');
    debugPrint(
        '[Utils] Video producer: ${_videoProducer != null ? _videoProducer!.id : "null"}');
    debugPrint('[Utils] Active consumers: ${_consumers.length}');
    debugPrint('[Utils] Consumer->User map: $_consumerToUserMap');
    debugPrint('[Utils] Consumed producer IDs: $_consumedProducerIds');
    debugPrint('[Utils] Remote renderers: ${remoteRenderers.length}');
    debugPrint('[Utils] Remote streams: ${remoteStreams.length}');
    debugPrint('[Utils] Active renderers: ${activeRenderers.length}');
    debugPrint('[Utils] Existing user IDs: $_existingUserIds');
    debugPrint('[Utils] Socket->User map: $_socketToUserMap');
    debugPrint('[Utils] Pending producers: ${_pendingProducers.length}');
    debugPrint('[Utils] Participant count: ${participantCount.value}');
    debugPrint('[Utils] ═══════════════════════════════');
  }

  // This method retrieves the full name of a user by their ID.
  String getUserFullName(String userId) {
    if (userId == 'local') {
      return 'You';
    }

    if (groupModel.value.currentUsers != null) {
      final user = groupModel.value.currentUsers!
          .firstWhereOrNull((u) => u.sId == userId);
      if (user != null && user.name != null && user.name!.isNotEmpty) {
        return user.name!;
      }
    }

    final fullName = userInfoMap[userId]?['fullName'];
    if (fullName != null && fullName.toString().isNotEmpty) {
      return fullName.toString();
    }

    return 'User ${userId.substring(0, math.min(6, userId.length))}...';
  }

  // This method retrieves the group details by ID.
  Future<String> getGroupDetailsById(String groupId, String field) async {
    try {
      var res = await _groupRepo.getGroupDetailsById(
        groupId: groupId,
      );
      groupModel.value = res.data!;
      if (field == 'groupName') {
        return groupModel.value.groupName ?? '';
      } else if (field == 'groupImage') {
        return groupModel.value.groupImage ?? '';
      }
    } catch (e) {}
    return 'Unknown Group';
  }

  // This method logs participant information for debugging.
  void logParticipantInfo() {
    debugPrint('[Utils] ═══ Participant Info Dump ═══');
    debugPrint('[Utils] Participant count: ${participantCount.value}');
    debugPrint('[Utils] Joined users: ${joinedUsers.length}');
    for (var u in joinedUsers) {
      debugPrint(
          '[Utils]   - objectId=${u['objectId']} socketId=${u['userId']}');
    }
    debugPrint('[Utils] User info map:');
    userInfoMap.forEach((k, v) {
      debugPrint('[Utils]   - $k: $v');
    });
    debugPrint('[Utils] User audio enabled:');
    userAudioEnabled.forEach((k, v) {
      debugPrint('[Utils]   - $k: $v');
    });
    debugPrint('[Utils] ═════════════════════════════');
  }
}
