part of 'group_call.dart';

extension GroupCallSocketExtension on GroupcallController {
  // This method initializes the socket connection.
  void _initializeSocket() {
    debugPrint('[Socket] _initializeSocket: setting up socket listeners');
    ever(socketController.socketID, (id) {
      debugPrint('[Socket] socketID changed: id=$id');
      if (id.isNotEmpty && socketController.socket != null) {
        socket = socketController.socket;
        isMainSocketConnected.value = true;
        _setupSocketListener();
      }
    });

    if (socketController.socketID.value.isNotEmpty &&
        socketController.socket != null) {
      socket = socketController.socket;
      isMainSocketConnected.value = true;
      _setupSocketListener();
    }
  }

  // This method sets up the socket listeners for various events.
  void _setupSocketListener() {
    debugPrint('[Socket] _setupSocketListener: registering all event handlers');

    // Listen for user leaving the room
    socket?.off("BE-leave-room");
    socket?.on("BE-leave-room", (data) {
      debugPrint('[Socket] BE-leave-room received: $data');
    });

    // Listen for incoming calls
    socket?.off("incomming_call");
    socket?.on("incomming_call", (data) async {
      debugPrint(
          '[Socket] incomming_call received: roomId=${data is Map ? data['roomId'] : data}');
      chatController.checkActiveCall(data['roomId']?.toString() ?? '');
      groupListController.getGroupList(isLoadingShow: false);
      callHistoryController.refreshCallHistory(isLoadingShow: false);

      if (data is! Map<String, dynamic>) {
        debugPrint('[Socket] incomming_call: data is not a Map, ignoring');
        return;
      }

      if (isCallActive.value) {
        final roomId = data['roomId']?.toString() ?? '';
        debugPrint(
            '[Socket] incomming_call: already in call, rejecting room=$roomId');
        if (roomId.isNotEmpty) {
          socket?.emit('BE-reject-call', {'roomId': roomId});
          socket?.emit(
              'call_disconnect', {'roomId': roomId, 'userId': socket?.id});
        }
        return;
      }

      if (!isCallActive.value) {}
    });

    // Listen for user joining the call — track presence only (no P2P peer creation).
    // Media is handled by MediaSoup SFU via MS-* events.
    socket?.off("FE-user-join");
    socket?.on("FE-user-join", (data) {
      debugPrint(
          '[Socket] FE-user-join received: type=${data.runtimeType} length=${data is List ? data.length : 'N/A'}');
      if (data is! List) {
        debugPrint('[Socket] FE-user-join: data is not a List, ignoring');
        return;
      }

      for (var user in data) {
        if (user is Map<String, dynamic>) {
          final socketUserId = user['userId']?.toString() ?? '';
          final info = user['info'] as Map<String, dynamic>?;
          final objectId = info?['userName']?.toString() ?? '';
          final fullName = info?['fullName']?.toString() ??
              info?['name']?.toString() ??
              'Unknown';

          debugPrint(
              '[Socket] FE-user-join: processing user socketId=$socketUserId objectId=$objectId fullName=$fullName');

          // Skip self — by socket.id AND by objectId (our MongoDB user ID)
          if (socketUserId == socket?.id) {
            debugPrint(
                '[Socket] FE-user-join: skipping self (socketId match)');
            continue;
          }
          final myObjectId = LocalStorage().getUserId();
          if (objectId == myObjectId) {
            debugPrint(
                '[Socket] FE-user-join: skipping self (objectId match)');
            continue;
          }
          if (objectId.isEmpty) {
            debugPrint(
                '[Socket] FE-user-join: skipping user with empty objectId');
            continue;
          }

          // Map socket.id <-> objectId
          _socketToUserMap[socketUserId] = objectId;
          _userToSocketMap[objectId] = socketUserId;

          // Track user info
          if (!_existingUserIds.contains(objectId)) {
            _existingUserIds.add(objectId);
            userInfoMap[objectId] = {
              'fullName': fullName,
              'userName': objectId,
            };
            final audioEnabled = info?['audio'];
            if (audioEnabled is bool) {
              userAudioEnabled[objectId] = audioEnabled;
            } else {
              userAudioEnabled[objectId] = true;
            }
            joinedUsers.add({
              'userId': socketUserId,
              'objectId': objectId,
              'info': info,
            });
            debugPrint(
                '[Socket] FE-user-join: NEW user added objectId=$objectId fullName=$fullName');
          } else {
            debugPrint(
                '[Socket] FE-user-join: user already tracked objectId=$objectId');
          }
        }
      }

      participantCount.value = _existingUserIds.length + 1; // +1 for self
      debugPrint(
          '[Socket] FE-user-join: participantCount=${participantCount.value} existingUserIds=${_existingUserIds.length}');
      userInfoMap.refresh();
      userAudioEnabled.refresh();
      joinedUsers.refresh();
    });

    // ── MediaSoup: Listen for new remote producers ──
    socket?.off("MS-new-producer");
    socket?.on("MS-new-producer", (data) async {
      debugPrint('[Socket] MS-new-producer received: raw=$data');
      if (data is! Map<String, dynamic>) {
        debugPrint(
            '[Socket] MS-new-producer: data is not a Map (type=${data.runtimeType}), ignoring');
        return;
      }

      final producerId = data['producerId']?.toString() ?? '';
      final remoteUserId = data['userId']?.toString() ?? '';
      final kind = data['kind']?.toString() ?? '';

      if (producerId.isEmpty || remoteUserId.isEmpty) {
        debugPrint(
            '[Socket] MS-new-producer: empty producerId or userId, ignoring');
        return;
      }
      // Skip our own producers
      if (remoteUserId == LocalStorage().getUserId()) {
        debugPrint(
            '[Socket] MS-new-producer: skipping own producer=$producerId');
        return;
      }
      if (_consumedProducerIds.contains(producerId)) {
        debugPrint(
            '[Socket] MS-new-producer: already consumed producer=$producerId');
        return;
      }

      debugPrint(
          '[Socket] MS-new-producer: producer=$producerId user=$remoteUserId kind=$kind recvTransport=${_recvTransport != null ? "ready" : "NOT READY"} device=${_msDevice != null ? "loaded" : "NOT LOADED"}');

      final roomId = currentRoomId.value;
      final localUserId = LocalStorage().getUserId();

      if (roomId.isNotEmpty && localUserId.isNotEmpty) {
        // If recv transport is not ready yet, queue the producer for later consumption
        if (_recvTransport == null || _msDevice == null) {
          debugPrint(
              '[Socket] MS-new-producer: QUEUING producer=$producerId (recv transport not ready)');
          _pendingProducers.add({
            'producerId': producerId,
            'userId': remoteUserId,
            'kind': kind,
          });
          return;
        }
        await consumeProducer(
            roomId, localUserId, producerId, remoteUserId, kind);
      } else {
        debugPrint(
            '[Socket] MS-new-producer: cannot consume - roomId=$roomId localUserId=$localUserId');
      }
    });

    // ── MediaSoup: Listen for producer closed (remote user stopped producing) ──
    socket?.off("MS-producer-closed");
    socket?.on("MS-producer-closed", (data) {
      debugPrint('[Socket] MS-producer-closed received: $data');
      if (data is! Map<String, dynamic>) return;

      final producerId = data['producerId']?.toString() ?? '';
      final remoteUserId = data['userId']?.toString() ?? '';
      final kind = data['kind']?.toString() ?? '';

      debugPrint(
          '[Socket] MS-producer-closed: producer=$producerId user=$remoteUserId kind=$kind');

      if (producerId.isEmpty) return;

      // Remove from consumed set so it can be re-consumed if producer restarts
      _consumedProducerIds.remove(producerId);

      // Find and close the consumer for this producer
      String? consumerIdToRemove;
      _consumers.forEach((consumerId, consumer) {
        if (consumer.producerId == producerId) {
          consumerIdToRemove = consumerId;
        }
      });

      if (consumerIdToRemove != null) {
        try {
          _consumers[consumerIdToRemove]?.close();
        } catch (e) {
          debugPrint(
              '[Socket] MS-producer-closed: error closing consumer: $e');
        }
        _consumers.remove(consumerIdToRemove);
        final userId = _consumerToUserMap.remove(consumerIdToRemove);
        debugPrint(
            '[Socket] MS-producer-closed: closed consumer=$consumerIdToRemove for user=$userId');

        // If this was a video producer closing, update the renderer
        if (kind == 'video' && userId != null && remoteStreams.containsKey(userId)) {
          final stream = remoteStreams[userId];
          if (stream != null) {
            for (var t in List.from(stream.getVideoTracks())) {
              try {
                stream.removeTrack(t);
              } catch (_) {}
            }
          }
          remoteRenderers.refresh();
          remoteStreams.refresh();
        }
      }
    });

    // Listen for user leaving the room
    socket?.off("FE-user-leave");
    socket?.on("FE-user-leave", (data) async {
      debugPrint('[Socket] FE-user-leave received: $data');
      if (data is Map<String, dynamic>) {
        final socketUserId = data['userId']?.toString() ?? '';
        final userName = data['userName']?.toString() ?? '';
        final roomId = data['roomId'];

        // Resolve objectId: prefer userName (which is the ObjectId), fallback to mapping
        final objectId = userName.isNotEmpty
            ? userName
            : resolveUserId(socketUserId);

        debugPrint(
            '[Socket] FE-user-leave: socketId=$socketUserId userName=$userName objectId=$objectId roomId=$roomId');

        if (objectId.isNotEmpty) {
          final bool active =
              data['joinUserCount']?['activeCall'] == true;
          debugPrint(
              '[Socket] FE-user-leave: activeCall=$active');
          if (!active &&
              roomId != null &&
              chatController.activeCallGroupId.value == roomId) {
            chatController.activeCallGroupId.value = "";
          }
          if (roomId != null && roomId == chatController.groupId.value) {
            chatController.isGroupCallActive.value = active;
          }

          for (var item in groupListController.groupList) {
            if (item.sId == roomId) {
              if (data['joinUserCount']?['activeCall'] == false) {
                item.groupCallStatus = "ended";
              }
            }
          }
          groupListController.groupList.refresh();

          try {
            removeConsumersForUser(objectId);
            _socketToUserMap.remove(socketUserId);
            _userToSocketMap.remove(objectId);

            // Recalculate participant count from source of truth
            participantCount.value = _existingUserIds.length + 1;
            debugPrint(
                '[Socket] FE-user-leave: removed user=$objectId participantCount=${participantCount.value}');

            remoteRenderers.refresh();
            joinedUsers.refresh();
            userInfoMap.refresh();

            setAudioToSpeaker(isSpeakerOn.value);
          } catch (e) {
            debugPrint('[Socket] FE-user-leave error: $e');
          }
        }
      }
    });

    // Listen for user leave events
    socket?.off("FE-leave");
    socket?.on("FE-leave", (data) {
      debugPrint('[Socket] FE-leave received: $data');
      if (data is Map<String, dynamic>) {
        final roomId = data['roomId'];
        final bool active =
            data['joinUserCount']?['activeCall'] == true;
        debugPrint(
            '[Socket] FE-leave: roomId=$roomId activeCall=$active');
        if (!active &&
            roomId != null &&
            chatController.activeCallGroupId.value == roomId) {
          chatController.activeCallGroupId.value = "";
        }
        if (roomId != null && roomId == chatController.groupId.value) {
          chatController.isGroupCallActive.value = active;
        }

        for (var item in groupListController.groupList) {
          if (item.sId == roomId) {
            if (data['joinUserCount']?['activeCall'] == false) {
              item.groupCallStatus = "ended";
            }
          }
        }
        groupListController.groupList.refresh();
      }
    });

    // Listen for user disconnect events
    socket?.off("FE-user-disconnected");
    socket?.on("FE-user-disconnected", (data) {
      debugPrint('[Socket] FE-user-disconnected received: $data');
      if (data is Map<String, dynamic>) {
        final socketUserId = data['userSocketId']?.toString() ?? '';
        final userName = data['userName']?.toString() ?? '';
        final roomId = data['roomId'];

        final objectId = userName.isNotEmpty
            ? userName
            : resolveUserId(socketUserId);

        debugPrint(
            '[Socket] FE-user-disconnected: socketId=$socketUserId objectId=$objectId roomId=$roomId currentRoom=${currentRoomId.value}');

        if (objectId.isNotEmpty && roomId != null) {
          try {
            if (roomId == currentRoomId.value) {
              removeConsumersForUser(objectId);
              _socketToUserMap.remove(socketUserId);
              _userToSocketMap.remove(objectId);

              // Recalculate participant count from source of truth
              participantCount.value = _existingUserIds.length + 1;
              debugPrint(
                  '[Socket] FE-user-disconnected: removed user=$objectId participantCount=${participantCount.value}');

              remoteRenderers.refresh();
              joinedUsers.refresh();
              userInfoMap.refresh();

              Future.delayed(const Duration(seconds: 3), () {
                chatController.checkActiveCall(currentRoomId.value);
                groupListController.getGroupList(isLoadingShow: false);
              });
              setAudioToSpeaker(isSpeakerOn.value);
            }
          } catch (e) {
            debugPrint('[Socket] FE-user-disconnected error: $e');
          }
        }
      }
    });

    // Listen for camera/audio toggle events
    socket?.off("FE-toggle-camera");
    socket?.on("FE-toggle-camera", (data) {
      debugPrint('[Socket] FE-toggle-camera received: $data');
      if (data is Map<String, dynamic>) {
        final socketUserId = data['userId']?.toString() ?? '';
        final switchTarget = data['switchTarget'];

        // Resolve to objectId
        final objectId = resolveUserId(socketUserId);

        debugPrint(
            '[Socket] FE-toggle-camera: socketId=$socketUserId objectId=$objectId switchTarget=$switchTarget');

        if (objectId.isNotEmpty && switchTarget == 'audio') {
          final provided =
              data['isEnabled'] ?? data['audio'] ?? data['enabled'];
          if (provided is bool) {
            userAudioEnabled[objectId] = provided;
          } else {
            final current = userAudioEnabled[objectId] ?? true;
            userAudioEnabled[objectId] = !current;
          }
          debugPrint(
              '[Socket] FE-toggle-camera: user=$objectId audio=${userAudioEnabled[objectId]}');
          userAudioEnabled.refresh();
        }
      }
    });

    // Listen for call ended events
    socket?.off("FE-call-ended");
    socket?.on("FE-call-ended", (data) async {
      debugPrint(
          '[Socket] FE-call-ended received for room: ${data is Map ? data['roomId'] : data}');
      try {
        await cleanupCall();
      } catch (_) {}

      try {
        final uuid = LocalStorage().getLatestCallUuid();
        if (uuid.isNotEmpty) {
          try {
            await FlutterCallkitIncoming.endCall(uuid);
          } catch (_) {
            try {
              await FlutterCallkitIncoming.endAllCalls();
            } catch (_) {}
          }
          await LocalStorage().clearLatestCallUuid();
        } else {
          try {
            final calls = await FlutterCallkitIncoming.activeCalls();
            if (calls is List && calls.isNotEmpty) {
              for (var c in calls) {
                final id = c['id'];
                try {
                  if (id != null) await FlutterCallkitIncoming.endCall(id);
                } catch (_) {}
              }
              await LocalStorage().clearLatestCallUuid();
            } else {
              await FlutterCallkitIncoming.endAllCalls();
            }
          } catch (_) {}
        }

        try {
          for (int attempt = 0; attempt < 5; attempt++) {
            final post = await FlutterCallkitIncoming.activeCalls();
            debugPrint(
                '[Socket] FE-call-ended post-end activeCalls (attempt ${attempt + 1}): $post');
            if (post is List && post.isNotEmpty) {
              for (var c in post) {
                final id = c['id'];
                try {
                  if (id != null) await FlutterCallkitIncoming.endCall(id);
                } catch (_) {}
              }
              await Future.delayed(const Duration(milliseconds: 700));
              continue;
            }
            break;
          }
        } catch (_) {}
      } catch (_) {}

      try {
        final session = await AudioSession.instance;
        await session.setActive(false);
      } catch (_) {}

      try {
        CallOverlayManager().remove();
        isInOverlayMode.value = false;
      } catch (_) {}

      try {
        await WakelockPlus.disable();
      } catch (_) {}

      Future.delayed(const Duration(seconds: 1), () {
        chatController.checkActiveCall(currentRoomId.value);
        groupListController.getGroupList(isLoadingShow: false);
        callHistoryController.refreshCallHistory(isLoadingShow: false);
      });

      try {
        await LocalStorage().clearLatestCallUuid();
      } catch (_) {}
    });

    debugPrint('[Socket] _setupSocketListener: all handlers registered');
  }
}
