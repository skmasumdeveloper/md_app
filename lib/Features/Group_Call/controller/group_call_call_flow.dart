part of 'group_call.dart';

extension GroupCallCallFlowExtension on GroupcallController {
  // This method emits an outgoing call to the group.
  void outgoingCallEmit(String groupId, {required bool isVideoCall}) async {
    if (_isCallFlowBusy) {
      debugPrint(
          '[CallFlow] outgoingCallEmit: skipped (call flow already in progress)');
      return;
    }
    _isCallFlowBusy = true;

    try {
      debugPrint(
          '[CallFlow] outgoingCallEmit: groupId=$groupId isVideo=$isVideoCall');
      // show non-modal connecting overlay (safer than modal dialog)
      _showCallConnectingOverlay();

      await Future.delayed(const Duration(milliseconds: 200));

      bool storedCallStatus = await LocalStorage().getIsAnyCallActive();
      isAnyCallActive.value = storedCallStatus;
      callHistoryController.refreshCallHistory(isLoadingShow: false);

      if (isAnyCallActive.value) {
        await leaveCall(
            roomId: currentRoomId.value, userId: LocalStorage().getUserId());
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      await Future.delayed(const Duration(milliseconds: 500));
      currentRoomId.value = groupId;
      isCallActive.value = true;
      isAnyCallActive.value = true;
      await LocalStorage().setIsAnyCallActive(true);
      await LocalStorage().setActiveCallRoomId(groupId);
      isThisVideoCall.value = isVideoCall;
      isSpeakerOn.value = isThisVideoCall.value;

      final groupName = await getGroupDetailsById(groupId, 'groupName');
      final groupImage = "";

      final userName = LocalStorage().getUserId();
      final userFullName = LocalStorage().getUserName();

      try {
        await _getUserMedia(isVideoCall: isVideoCall);

        if (localStream != null) {
          debugPrint(
              '[CallFlow] outgoingCallEmit: localStream ready, emitting BE-join-room');
          socket?.emit("BE-join-room", {
            "userName": userName,
            "roomId": groupId,
            "callerName": userFullName,
            "fullName": userFullName,
            "groupName": groupName,
            "groupImage": groupImage,
            "callType": isVideoCall ? "video" : "audio",
            "constraints": {
              "audio": isMicEnabled.value,
              "video": isVideoCall ? isCameraEnabled.value : false
            }
          });

          // Activate audio session BEFORE MediaSoup produce — critical on iOS.
          await activateAudioSession();

          // Navigate to call screen IMMEDIATELY so user sees local video
          // with "Connecting to others..." instead of the chat screen.
          // MediaSoup init happens in background on the call screen.
          try {
            if (_isCallDialogShown == true) {
              _hideCallConnectingOverlay();
            }
          } catch (e) {}

          if (_isNavigatingToCall) return;
          _isNavigatingToCall = true;
          try {
            final currentRoute = Get.currentRoute;
            if (!currentRoute.contains('GroupVideoCallScreen')) {
              // Don't await — Get.to blocks until screen is popped
              Get.to(() => GroupVideoCallScreen(
                    groupId: groupId,
                    groupName: groupName,
                    groupImage: groupImage,
                    localStream: localStream!,
                    isVideoCall: isVideoCall,
                  ));
            }
          } catch (e) {
          } finally {
            Future.delayed(const Duration(milliseconds: 300), () {
              _isNavigatingToCall = false;
            });
          }

          // Initialize MediaSoup SFU in background — user already sees call screen
          await Future.delayed(const Duration(milliseconds: 300));
          await initializeMediasoup();
        } else {
          Get.snackbar("Error", "Could not access camera or microphone");
          isCallActive.value = false;
          currentRoomId.value = "";
        }
      } catch (e) {
        Get.snackbar("Error", "Failed to start video call: ${e.toString()}");
        isCallActive.value = false;
        currentRoomId.value = "";
      }

      await Future.delayed(const Duration(milliseconds: 500));
      startMeetingEndTimer(groupId);
    } finally {
      _isCallFlowBusy = false;
    }
  }

  // This method joins an existing call.
  Future<void> joinCall(
      {required String roomId,
      required String userName,
      required String userFullName,
      required BuildContext context,
      bool isVideoCall = true}) async {
    if (_isCallFlowBusy) {
      debugPrint(
          '[CallFlow] joinCall: skipped (call flow already in progress)');
      return;
    }
    _isCallFlowBusy = true;

    debugPrint(
        '[CallFlow] joinCall: room=$roomId user=$userName isVideo=$isVideoCall');
    try {
      currentRoomId.value = roomId;
      isCallActive.value = true;
      isAnyCallActive.value = true;
      isThisVideoCall.value = isVideoCall;
      isSpeakerOn.value = isVideoCall;
      await LocalStorage().setIsAnyCallActive(true);
      await LocalStorage().setActiveCallRoomId(roomId);

      final groupName = await getGroupDetailsById(roomId, 'groupName');
      debugPrint('[CallFlow] joinCall: groupName=$groupName');

      await _getUserMedia(isVideoCall: isVideoCall);

      if (localStream == null) {
        debugPrint('[CallFlow] joinCall: FAILED - no local stream');
        Get.snackbar("Error", "Could not access camera or microphone");
        return;
      }

      debugPrint('[CallFlow] joinCall: emitting BE-join-room');
      socket?.emit('BE-join-room', {
        'roomId': roomId,
        'userName': userName,
        'fullName': userFullName,
        'callerName': userFullName,
        'groupName': groupName,
        'groupImage': '',
        'callType': isVideoCall ? 'video' : 'audio',
        'constraints': {
          'audio': isMicEnabled.value,
          'video': isVideoCall ? isCameraEnabled.value : false
        }
      });

      // Activate audio session BEFORE MediaSoup produce
      await activateAudioSession();

      // Navigate to call screen IMMEDIATELY — init mediasoup in background
      debugPrint('[CallFlow] joinCall: navigating to GroupVideoCallScreen');
      Get.off(() => GroupVideoCallScreen(
            groupId: roomId,
            groupName: groupName,
            groupImage: '',
            localStream: localStream!,
            isVideoCall: isVideoCall,
          ));

      // Initialize MediaSoup SFU in background — user already sees call screen
      await Future.delayed(const Duration(milliseconds: 300));
      await initializeMediasoup();
    } catch (e) {
      debugPrint('[CallFlow] joinCall ERROR: $e');
      Get.snackbar("Error", "Failed to join call: ${e.toString()}");
      isCallActive.value = false;
      currentRoomId.value = "";
    } finally {
      _isCallFlowBusy = false;
    }
  }

  // This method leaves the call and cleans up resources.
  Future<void> leaveCall(
      {required String roomId, required String userId}) async {
    try {
      debugPrint('leaveCall: room:$roomId user:$userId');
      isCallActive.value = false;
      isAnyCallActive.value = false;

      stopMeetingEndTimer();

      socket?.emit('BE-leave-room', {'roomId': roomId, 'leaver': userId});
      try {
        socket
            ?.emit('call_disconnect', {'roomId': roomId, 'userId': socket?.id});
      } catch (_) {}

      await cleanupCall();

      // ensure native/OS call UI is closed and audio session/wakelock are released
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
              try {
                await FlutterCallkitIncoming.endAllCalls();
              } catch (_) {}
            }
          } catch (_) {
            try {
              await FlutterCallkitIncoming.endAllCalls();
            } catch (_) {}
          }
        }

        try {
          for (int attempt = 0; attempt < 5; attempt++) {
            final post = await FlutterCallkitIncoming.activeCalls();
            debugPrint('post-end activeCalls (attempt ${attempt + 1}): $post');
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
      } catch (e) {}

      try {
        final session = await AudioSession.instance;
        await session.setActive(false);
      } catch (e) {}

      try {
        await WakelockPlus.disable();
      } catch (e) {}

      // hide connecting overlay if visible
      try {
        if (_isCallDialogShown == true) _hideCallConnectingOverlay();
      } catch (e) {}

      // stop in-app PiP overlay if active
      try {
        CallOverlayManager().remove();
      } catch (e) {}

      await LocalStorage().setIsAnyCallActive(false);
      await LocalStorage().clearActiveCallRoomId();

      chatController.checkActiveCall(currentRoomId.value, isShowLoading: true);

      groupListController.getGroupList(isLoadingShow: false);

      try {
        await LocalStorage().clearLatestCallUuid();
      } catch (_) {}
    } catch (e) {
      await cleanupCall();
    } finally {
      currentRoomId.value = "";
      participantCount.value = 0;

      try {
        await LocalStorage().clearLatestCallUuid();
      } catch (_) {}
      try {
        await LocalStorage().clearActiveCallRoomId();
      } catch (_) {}

      // Stop foreground service
      try {
        await CallService.stopService();
      } catch (_) {}

      // Navigate back only if we're on the VideoCallScreen (not in overlay mode)
      final wasOverlay = isInOverlayMode.value;
      isInOverlayMode.value = false;
      if (!wasOverlay) {
        Get.back();
      }
    }
  }

  // This method to reconnect the call if it was disconnected.
  void reCallConnect() async {
    final now = DateTime.now();
    if (_isCallFlowBusy) {
      debugPrint(
          '[CallFlow] reCallConnect: skipped (another call flow is running)');
      return;
    }
    if (_isReconnectingCall) {
      debugPrint(
          '[CallFlow] reCallConnect: skipped (reconnect already in progress)');
      return;
    }
    if (_isInitializingMediasoup) {
      debugPrint(
          '[CallFlow] reCallConnect: skipped (mediasoup initialization in progress)');
      return;
    }

    if (_lastReconnectAttemptAt != null &&
        now.difference(_lastReconnectAttemptAt!) < const Duration(seconds: 8)) {
      debugPrint(
          '[CallFlow] reCallConnect: skipped by cooldown (${now.difference(_lastReconnectAttemptAt!).inMilliseconds}ms since last attempt)');
      return;
    }

    final active = await LocalStorage().getIsAnyCallActive();
    final storedRoom = LocalStorage().getActiveCallRoomId();
    if (!active || (currentRoomId.value.isEmpty && storedRoom.isEmpty)) {
      debugPrint(
          '[CallFlow] reCallConnect: skipped (no active call state to recover)');
      return;
    }

    _isReconnectingCall = true;
    _isCallFlowBusy = true;
    _lastReconnectAttemptAt = now;
    debugPrint('[CallFlow] reCallConnect: starting reconnection');
    final currentRoom = currentRoomId.value;
    final wasVideoCall = isThisVideoCall.value;

    try {
      final socketReady = await _waitForSocketReady(
        timeout: const Duration(seconds: 12),
      );
      if (!socketReady) {
        debugPrint('[CallFlow] reCallConnect: aborting (socket not connected)');
        return;
      }

      await cleanupCall();
      await Future.delayed(const Duration(milliseconds: 200));

      socket?.emit('BE-leave-room',
          {'roomId': currentRoom, 'leaver': LocalStorage().getUserId()});

      await Future.delayed(const Duration(seconds: 2));

      bool storedCallStatus = await LocalStorage().getIsAnyCallActive();
      isAnyCallActive.value = storedCallStatus;
      callHistoryController.refreshCallHistory(isLoadingShow: false);

      await Future.delayed(const Duration(milliseconds: 500));
      currentRoomId.value = currentRoom;
      isCallActive.value = true;
      isAnyCallActive.value = true;
      await LocalStorage().setIsAnyCallActive(true);
      await LocalStorage().setActiveCallRoomId(currentRoom);
      isThisVideoCall.value = wasVideoCall;
      isSpeakerOn.value = isThisVideoCall.value;

      final groupName = await getGroupDetailsById(currentRoom, 'groupName');
      final groupImage = "";

      final userName = LocalStorage().getUserId();
      final userFullName = LocalStorage().getUserName();

      try {
        await _getUserMedia(isVideoCall: wasVideoCall);

        if (localStream != null) {
          socket?.emit("BE-join-room", {
            "userName": userName,
            "roomId": currentRoom,
            "callerName": userFullName,
            "fullName": userFullName,
            "groupName": groupName,
            "groupImage": groupImage,
            "callType": wasVideoCall ? "video" : "audio",
            "constraints": {
              "audio": isMicEnabled.value,
              "video": wasVideoCall ? isCameraEnabled.value : false
            }
          });

          // Activate audio session BEFORE MediaSoup produce
          await activateAudioSession();

          // Re-initialize MediaSoup SFU (cleanupCall already reset _mediasoupInitialized)
          await Future.delayed(const Duration(milliseconds: 500));
          await initializeMediasoup();
        } else {
          Get.snackbar("Error", "Could not access camera or microphone");
          isCallActive.value = false;
          currentRoomId.value = "";
        }
      } catch (e) {
        Get.snackbar("Error", "Failed to start video call: ${e.toString()}");
        isCallActive.value = false;
        currentRoomId.value = "";
      }
    } finally {
      _isReconnectingCall = false;
      _isCallFlowBusy = false;
      debugPrint('[CallFlow] reCallConnect: finished');
    }
  }

  // This method rejects an incoming call for a specific group.
  void callReject(String groupId) async {
    debugPrint('[CallFlow] callReject: groupId=$groupId');
    socket?.emit('BE-reject-call', {'roomId': groupId});
    socket?.emit('call_disconnect', {'roomId': groupId, 'userId': socket?.id});

    await cleanupCall();

    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {}

    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {}

    try {
      CallOverlayManager().remove();
      isInOverlayMode.value = false;
    } catch (_) {}

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    try {
      await CallService.stopService();
    } catch (_) {}

    isCallActive.value = false;
    currentRoomId.value = "";
    isAnyCallActive.value = false;
    await LocalStorage().setIsAnyCallActive(false);
    await LocalStorage().clearActiveCallRoomId();
  }

  // This method cleans up all call resources.
  Future<void> cleanupCall() async {
    debugPrint('cleanupCall: starting cleanup');

    // Stop screen sharing first if active
    try {
      await screenShareService.dispose();
    } catch (_) {}

    // stop trackless timer early
    try {
      _trackCheckTimer?.cancel();
      _trackCheckTimer = null;
    } catch (_) {}

    // ── Cleanup MediaSoup SFU resources ──
    await cleanupMediasoup();

    // ── Cleanup local media ──
    if (localStream != null) {
      try {
        localRenderer.srcObject = null;
      } catch (_) {}
      for (var track in List.from(localStream!.getTracks())) {
        try {
          await track.stop();
        } catch (_) {}
      }
      try {
        await localStream?.dispose();
      } catch (_) {}
      localStream = null;
    }

    // Detach and dispose remote renderers — do NOT dispose remote streams/tracks.
    // cleanupMediasoup() already closed consumers which disposed native tracks.
    // Calling stream.dispose() again throws "MediaStreamTrack has been disposed".
    for (final renderer in remoteRenderers.values) {
      try {
        renderer.srcObject = null;
      } catch (_) {}
      try {
        renderer.dispose();
      } catch (_) {}
    }
    remoteRenderers.clear();
    remoteStreams.clear();
    activeRenderers.clear();
    userInfoMap.clear();
    userAudioEnabled.clear();
    joinedUsers.clear();
    _existingUserIds.clear();
    reconnectingPeers.clear();
    participantCount.value = 0;

    debugPrint('cleanupCall: completed');
  }
}
