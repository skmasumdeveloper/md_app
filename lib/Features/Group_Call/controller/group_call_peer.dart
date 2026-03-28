part of 'group_call.dart';

extension GroupCallPeerExtension on GroupcallController {
  /// Initialize MediaSoup SFU: create device, transports, produce local media,
  /// consume existing producers. This replaces the old P2P peer creation.
  Future<void> initializeMediasoup() async {
    final roomId = currentRoomId.value;
    final userId = LocalStorage().getUserId();

    if (socket == null || roomId.isEmpty || userId.isEmpty) {
      debugPrint(
          '[MediaSoup] Cannot initialize: missing socket=${socket != null} room=${roomId.isNotEmpty} user=${userId.isNotEmpty}');
      return;
    }

    if (_mediasoupInitialized) {
      debugPrint('[MediaSoup] Already initialized, skipping');
      return;
    }

    if (_isInitializingMediasoup) {
      debugPrint('[MediaSoup] Initialization already in progress, skipping');
      return;
    }

    _isInitializingMediasoup = true;

    try {
      debugPrint(
          '[MediaSoup] ═══════════════════════════════════════════════════');
      debugPrint(
          '[MediaSoup] Starting initialization for room=$roomId user=$userId');
      debugPrint(
          '[MediaSoup] ═══════════════════════════════════════════════════');

      // ── Step 1: Get router RTP capabilities ──
      debugPrint('[MediaSoup] Step 1/6: Getting RTP capabilities...');
      final rtpCapsResponse = await socketEmitWithAck(
        'MS-get-rtp-capabilities',
        {'roomId': roomId},
      );

      if (rtpCapsResponse == null || rtpCapsResponse['ok'] != true) {
        debugPrint(
            '[MediaSoup] ✗ FAILED to get RTP capabilities: response=$rtpCapsResponse type=${rtpCapsResponse.runtimeType} socketConnected=${socket?.connected == true} socketId=${socket?.id} room=$roomId user=$userId');
        return;
      }

      final rtpCapabilities = RtpCapabilities.fromMap(
        Map<String, dynamic>.from(rtpCapsResponse['rtpCapabilities']),
      );
      debugPrint(
          '[MediaSoup] ✓ Step 1 complete: Got RTP capabilities (codecs=${(rtpCapsResponse['rtpCapabilities']['codecs'] as List?)?.length ?? 0})');

      // ── Step 2: Create & load device ──
      debugPrint('[MediaSoup] Step 2/6: Creating and loading device...');
      _msDevice = Device();
      await _msDevice!.load(routerRtpCapabilities: rtpCapabilities);
      debugPrint(
          '[MediaSoup] ✓ Step 2 complete: Device loaded, canProduceAudio=${_msDevice!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeAudio)}, canProduceVideo=${_msDevice!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeVideo)}');

      // Match web client behavior: fetch ICE servers/policy from backend.
      // Some backend handlers expect this event without payload; if it fails,
      // we fall back to app/env ICE config for the rest of this app session.
      if (!_skipBackendIceServerFetch) {
        await _loadBackendIceConfig(roomId, userId);
      } else {
        debugPrint(
            '[MediaSoup] Skipping backend ICE fetch for this session (using app config fallback)');
      }

      // ── Step 3: Create send transport ──
      debugPrint('[MediaSoup] Step 3/6: Creating send transport...');
      await _createSendTransport(roomId, userId);
      if (_sendTransport == null) {
        debugPrint('[MediaSoup] ✗ FAILED to create send transport, aborting');
        return;
      }
      debugPrint(
          '[MediaSoup] ✓ Step 3 complete: Send transport created id=${_sendTransport!.id}');

      // ── Step 4: Create recv transport ──
      debugPrint('[MediaSoup] Step 4/6: Creating recv transport...');
      await _createRecvTransport(roomId, userId);
      if (_recvTransport == null) {
        debugPrint('[MediaSoup] ✗ FAILED to create recv transport, aborting');
        return;
      }
      debugPrint(
          '[MediaSoup] ✓ Step 4 complete: Recv transport created id=${_recvTransport!.id}');

      // ── Step 5: Produce local tracks ──
      debugPrint(
          '[MediaSoup] Step 5/6: Producing local tracks (localStream=${localStream != null}, audioTracks=${localStream?.getAudioTracks().length ?? 0}, videoTracks=${localStream?.getVideoTracks().length ?? 0}, isVideoCall=${isThisVideoCall.value})...');
      await _produceLocalTracksWithRetry();
      debugPrint(
          '[MediaSoup] ✓ Step 5 complete: audioProducer=${_audioProducer != null}, videoProducer=${_videoProducer != null}');

      // ── Step 6: Consume existing producers (after recv transport is ready)
      debugPrint('[MediaSoup] Step 6/6: Consuming existing producers...');
      await _consumeExistingProducers(roomId, userId);

      // ── Drain pending producers that arrived during initialization ──
      if (_pendingProducers.isNotEmpty) {
        debugPrint(
            '[MediaSoup] Draining ${_pendingProducers.length} pending producers queued during init');
        final pending = List<Map<String, String>>.from(_pendingProducers);
        _pendingProducers.clear();
        for (var p in pending) {
          final pId = p['producerId'] ?? '';
          final pUserId = p['userId'] ?? '';
          final pKind = p['kind'] ?? '';
          if (pId.isNotEmpty &&
              pUserId.isNotEmpty &&
              !_consumedProducerIds.contains(pId)) {
            debugPrint(
                '[MediaSoup] Consuming pending producer=$pId user=$pUserId kind=$pKind');
            await consumeProducer(roomId, userId, pId, pUserId, pKind);
          }
        }
      }

      _mediasoupInitialized = true;

      // Start trackless renderer cleanup timer
      _startTracklessCheckTimer();

      // Start keepalive to prevent ICE from going idle/disconnected
      _startKeepAlive();

      debugPrint(
          '[MediaSoup] ═══════════════════════════════════════════════════');
      debugPrint(
          '[MediaSoup] ✓ Initialization COMPLETE — consumers=${_consumers.length} remoteRenderers=${remoteRenderers.length}');
      debugPrint(
          '[MediaSoup] ═══════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('[MediaSoup] ✗ initializeMediasoup EXCEPTION: $e');
      debugPrint('[MediaSoup] Stack trace: $stackTrace');
    } finally {
      _isInitializingMediasoup = false;
    }
  }

  /// Start a periodic signaling keepalive.
  ///
  /// We intentionally avoid periodic transport.getState()/getStats polling
  /// here because aggressive polling can amplify native WebRTC churn on some
  /// devices. Transport recovery is handled by connectionstatechange events
  /// plus explicit ICE restart logic.
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!isCallActive.value || _isRestartingIce) return;

      // Socket-level keepalive
      try {
        final roomId = currentRoomId.value;
        if (roomId.isNotEmpty && socket != null && socket!.connected == true) {
          socket!.emit('keepalive', {'roomId': roomId});
        }
      } catch (_) {}
    });
    debugPrint('[KeepAlive] started (6s interval, signaling only)');
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    debugPrint('[KeepAlive] stopped');
  }

  /// Attempt ICE-only recovery without full mediasoup re-initialization.
  /// This is lighter than a complete teardown/rebuild and avoids disrupting
  /// already established producers/consumers when the connection can recover.
  Future<void> _attemptIceRestart({String target = 'recv'}) async {
    if (!_mediasoupInitialized || _isRestartingIce) return;
    if (!isCallActive.value) return;
    _isRestartingIce = true;

    debugPrint('[MediaSoup] ═══ ICE RESTART RECOVERY ($target) ═══');

    try {
      // // 1. Preserve user presence (so we don't lose track of who's in the call)
      // final savedUserIds = Set<String>.from(_existingUserIds);
      // final savedUserInfo = Map<String, Map<String, dynamic>>.from(userInfoMap);
      // final savedUserAudio = Map<String, bool>.from(userAudioEnabled);
      // final savedJoined = List<Map<String, dynamic>>.from(joinedUsers);
      // final savedSocketToUser = Map<String, String>.from(_socketToUserMap);
      // final savedUserToSocket = Map<String, String>.from(_userToSocketMap);

      // debugPrint(
      //     '[MediaSoup] Recovery: preserving ${savedUserIds.length} users, tearing down mediasoup...');

      // // 2. Full teardown — nukes everything including renderers
      // await cleanupMediasoup();

      // // Detach and dispose all remote renderers
      // for (final renderer in remoteRenderers.values) {
      //   try {
      //     renderer.srcObject = null;
      //   } catch (_) {}
      //   try {
      //     renderer.dispose();
      //   } catch (_) {}
      // }
      // remoteRenderers.clear();
      // remoteStreams.clear();
      // activeRenderers.clear();

      // // 3. Restore user presence
      // _existingUserIds.addAll(savedUserIds);
      // userInfoMap.addAll(savedUserInfo);
      // userAudioEnabled.addAll(savedUserAudio);
      // joinedUsers.addAll(savedJoined);
      // _socketToUserMap.addAll(savedSocketToUser);
      // _userToSocketMap.addAll(savedUserToSocket);
      // participantCount.value = _existingUserIds.length + 1;

      // // 4. Re-initialize MediaSoup from scratch (same as initial call setup)
      // //    This creates fresh device, transports, producers, consumers,
      // //    renderers, and streams — all with pristine native textures.
      // debugPrint(
      //     '[MediaSoup] Recovery: re-initializing mediasoup from scratch...');
      // await initializeMediasoup();

      // // 5. Force renderer refresh after UI has time to rebuild RTCVideoViews.
      // //    The sync srcObject setter in _handleConsumerTrack fires the native
      // //    call but the Flutter texture may not be attached to a Surface yet.
      // //    This delayed re-poke ensures the texture is live.
      // Future.delayed(const Duration(milliseconds: 800), () {
      //   for (final uid in remoteRenderers.keys.toList()) {
      //     final renderer = remoteRenderers[uid];
      //     final stream = remoteStreams[uid];
      //     if (renderer != null && stream != null) {
      //       try {
      //         renderer.srcObject = null;
      //       } catch (_) {}
      //       renderer.srcObject = stream;
      //     }
      //   }
      //   remoteRenderers.refresh();
      //   debugPrint(
      //       '[MediaSoup] Recovery: re-poked ${remoteRenderers.length} renderers');
      // });

      // Cancel pending timers so recovery is not retriggered mid-restart.
      _iceRestartDebounce?.cancel();
      _iceRestartDebounce = null;
      _sendIceRestartDebounce?.cancel();
      _sendIceRestartDebounce = null;

      final roomId = currentRoomId.value;
      final userId = LocalStorage().getUserId();
      if (roomId.isEmpty || userId.isEmpty) {
        debugPrint(
            '[MediaSoup] ICE restart skipped: missing roomId/userId (room=${roomId.isNotEmpty} user=${userId.isNotEmpty})');
        return;
      }

      // Prevent restart storms when state flaps quickly.
      final now = DateTime.now();
      if (_lastIceRestartAt != null &&
          now.difference(_lastIceRestartAt!) < const Duration(seconds: 4)) {
        debugPrint(
            '[MediaSoup] ICE restart skipped: cooldown active (${now.difference(_lastIceRestartAt!).inMilliseconds}ms since last attempt)');
        return;
      }
      _lastIceRestartAt = now;

      // Escalate if ICE keeps flapping in a short window.
      if (_iceRestartWindowStart == null ||
          now.difference(_iceRestartWindowStart!) >
              const Duration(seconds: 20)) {
        _iceRestartWindowStart = now;
        _iceRestartBurstCount = 0;
      }
      _iceRestartBurstCount += 1;
      if (_iceRestartBurstCount >= 5) {
        debugPrint(
            '[MediaSoup] ICE is flapping (>=5 restarts in 20s) — escalating to full call reconnect');
        _iceRestartBurstCount = 0;
        _iceRestartWindowStart = null;
        Future.microtask(() => reCallConnect());
        return;
      }

      final recvTransport = _recvTransport;
      final sendTransport = _sendTransport;

      var restartRecv = target == 'recv' || target == 'both';
      var restartSend = target == 'send' || target == 'both';

      // If the other transport is also unhealthy, restart both to avoid
      // half-recovered state loops.
      final recvState = recvTransport?.connectionState;
      final sendState = sendTransport?.connectionState;
      final recvUnhealthy =
          recvState == 'disconnected' || recvState == 'failed';
      final sendUnhealthy =
          sendState == 'disconnected' || sendState == 'failed';

      if (restartRecv && sendUnhealthy && sendTransport != null) {
        restartSend = true;
      }
      if (restartSend && recvUnhealthy && recvTransport != null) {
        restartRecv = true;
      }

      if ((restartRecv && recvTransport == null) &&
          (restartSend && sendTransport == null)) {
        debugPrint(
            '[MediaSoup] ICE restart skipped: selected transport(s) unavailable (target=$target)');
        return;
      }

      var recvRestarted = false;
      var sendRestarted = false;

      if (restartRecv && recvTransport != null) {
        recvRestarted = await _restartTransportIceWithServer(
          transport: recvTransport,
          transportId: recvTransport.id,
          roomId: roomId,
          userId: userId,
          direction: 'recv',
        );
      }

      if (restartSend && sendTransport != null) {
        sendRestarted = await _restartTransportIceWithServer(
          transport: sendTransport,
          transportId: sendTransport.id,
          roomId: roomId,
          userId: userId,
          direction: 'send',
        );
      }

      await Future.delayed(const Duration(milliseconds: 300));

      _forceReattachRemoteRenderers();
      unawaited(setAudioToSpeaker(isSpeakerOn.value));

      debugPrint(
          '[MediaSoup] ✓ ICE restart COMPLETE — recvRestarted=$recvRestarted sendRestarted=$sendRestarted consumers=${_consumers.length} renderers=${remoteRenderers.length}');
    } catch (e, stackTrace) {
      debugPrint('[MediaSoup] ICE restart EXCEPTION: $e');
      debugPrint('[MediaSoup] Stack trace: $stackTrace');
    } finally {
      _isRestartingIce = false;
    }
  }

  /// Match web client ICE restart flow:
  /// 1) Ask server to restart ICE for this transport.
  /// 2) Apply returned iceParameters to local transport.restartIce().
  Future<bool> _restartTransportIceWithServer({
    required Transport transport,
    required String transportId,
    required String roomId,
    required String userId,
    required String direction,
  }) async {
    try {
      debugPrint(
          '[MediaSoup] Attempting $direction transport ICE restart via server: transportId=$transportId');

      final response = await socketEmitWithAck(
          'MS-restart-ice',
          {
            'roomId': roomId,
            'userId': userId,
            'transportId': transportId,
          },
          timeout: const Duration(seconds: 4));

      if (response is! Map || response['ok'] != true) {
        debugPrint(
            '[MediaSoup] $direction ICE restart failed: bad ack response=$response');
        final fallback =
            direction == 'recv' ? _recvIceParameters : _sendIceParameters;
        if (fallback != null) {
          transport.restartIce(fallback);
          debugPrint(
              '[MediaSoup] $direction ICE restart fallback applied using cached iceParameters: transportId=$transportId');
          return true;
        }
        return false;
      }

      final rawIceParameters = response['iceParameters'];
      if (rawIceParameters is! Map) {
        debugPrint(
            '[MediaSoup] $direction ICE restart failed: missing iceParameters in response=$response');
        final fallback =
            direction == 'recv' ? _recvIceParameters : _sendIceParameters;
        if (fallback != null) {
          transport.restartIce(fallback);
          debugPrint(
              '[MediaSoup] $direction ICE restart fallback applied using cached iceParameters: transportId=$transportId');
          return true;
        }
        return false;
      }

      final iceParameters =
          IceParameters.fromMap(Map<String, dynamic>.from(rawIceParameters));

      transport.restartIce(iceParameters);

      // Keep latest params cached for logs/debug and fallback diagnostics.
      if (direction == 'recv') {
        _recvIceParameters = iceParameters;
      } else if (direction == 'send') {
        _sendIceParameters = iceParameters;
      }

      debugPrint(
          '[MediaSoup] $direction ICE restart applied successfully: transportId=$transportId');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[MediaSoup] $direction ICE restart exception: $e');
      debugPrint('[MediaSoup] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Build the list of RTCIceServer objects from the app's TURN/STUN config.
  List<RTCIceServer> _buildIceServers() {
    try {
      if (!GroupCallTurn.useStunTurn) {
        debugPrint(
            '[MediaSoup] _buildIceServers: STUN/TURN disabled by USE_STUN_TURN env flag');
        return <RTCIceServer>[];
      }

      final config = GroupCallTurn.getOptimalIceConfig();
      final servers = config['iceServers'] as List? ?? [];
      final result = <RTCIceServer>[];

      // Always include Google's public STUN server as a fallback for NAT traversal
      result.add(RTCIceServer(
        urls: ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
        username: '',
        credentialType: RTCIceCredentialType.password,
      ));

      for (var s in servers) {
        if (s is Map) {
          final urlValue = s['urls'];
          if (urlValue == null) continue;
          final urls = urlValue is List
              ? List<String>.from(urlValue)
              : [urlValue.toString()];
          result.add(RTCIceServer(
            urls: urls,
            username: s['username']?.toString() ?? '',
            credential: s['credential']?.toString(),
            credentialType: RTCIceCredentialType.password,
          ));
        }
      }
      debugPrint(
          '[MediaSoup] _buildIceServers: built ${result.length} ICE servers');
      return result;
    } catch (e) {
      debugPrint('[MediaSoup] _buildIceServers: error: $e');
      return [
        RTCIceServer(
          urls: ['stun:stun.l.google.com:19302'],
          username: '',
          credentialType: RTCIceCredentialType.password,
        )
      ];
    }
  }

  Future<void> _loadBackendIceConfig(String roomId, String userId) async {
    _runtimeIceServers = null;
    _runtimeIceTransportPolicy = null;

    try {
      // Web client emits this without payload; mirror that exactly.
      final response = await socketEmitWithAckNoData('MS-get-ice-servers');

      if (response is! Map || response['ok'] != true) {
        debugPrint(
            '[MediaSoup] _loadBackendIceConfig: backend ICE config unavailable, using app config');
        // If this event keeps failing, avoid triggering backend instability
        // repeatedly during the same app run.
        _skipBackendIceServerFetch = true;
        debugPrint(
            '[MediaSoup] _loadBackendIceConfig: disabling backend ICE fetch for this session');
        return;
      }

      final rawServers = response['iceServers'] as List? ?? <dynamic>[];
      final parsedServers = <RTCIceServer>[];

      for (final s in rawServers) {
        if (s is! Map) continue;
        final urlValue = s['urls'];
        if (urlValue == null) continue;

        final urls = urlValue is List
            ? List<String>.from(urlValue.map((e) => e.toString()))
            : <String>[urlValue.toString()];

        parsedServers.add(RTCIceServer(
          urls: urls,
          username: s['username']?.toString() ?? '',
          credential: s['credential']?.toString(),
          credentialType: RTCIceCredentialType.password,
        ));
      }

      final rawPolicy =
          (response['iceTransportPolicy'] ?? '').toString().toLowerCase();
      final parsedPolicy = rawPolicy == 'relay'
          ? RTCIceTransportPolicy.relay
          : RTCIceTransportPolicy.all;

      _runtimeIceServers = parsedServers;
      _runtimeIceTransportPolicy = parsedPolicy;

      debugPrint(
          '[MediaSoup] _loadBackendIceConfig: using backend ICE config servers=${parsedServers.length} policy=$rawPolicy');
    } catch (e) {
      debugPrint(
          '[MediaSoup] _loadBackendIceConfig: failed ($e), using app config');
      _skipBackendIceServerFetch = true;
      debugPrint(
          '[MediaSoup] _loadBackendIceConfig: disabling backend ICE fetch for this session');
    }
  }

  List<RTCIceServer> _resolveIceServers() {
    if (_runtimeIceServers != null) {
      return List<RTCIceServer>.from(_runtimeIceServers!);
    }
    return _buildIceServers();
  }

  RTCIceTransportPolicy _resolveIceTransportPolicy() {
    if (_runtimeIceTransportPolicy != null) {
      return _runtimeIceTransportPolicy!;
    }
    final config = GroupCallTurn.getOptimalIceConfig();
    final raw = (config['iceTransportPolicy'] ?? '').toString().toLowerCase();
    if (raw == 'relay') return RTCIceTransportPolicy.relay;
    return RTCIceTransportPolicy.all;
  }

  /// Create the send transport for producing local media.
  Future<void> _createSendTransport(String roomId, String userId) async {
    debugPrint('[MediaSoup] _createSendTransport: requesting from server...');
    final sendInfo = await socketEmitWithAck(
      'MS-create-transport',
      {'roomId': roomId, 'userId': userId, 'direction': 'send'},
    );
    if (sendInfo == null || sendInfo['ok'] != true) {
      debugPrint('[MediaSoup] _createSendTransport: FAILED response=$sendInfo');
      return;
    }

    _sendIceParameters = IceParameters.fromMap(
        Map<String, dynamic>.from(sendInfo['iceParameters']));

    // Log full server ICE candidate details
    final iceCandidates = sendInfo['iceCandidates'] as List? ?? [];
    debugPrint('[MediaSoup] _createSendTransport: id=${sendInfo['id']}');
    debugPrint(
        '[MediaSoup] _createSendTransport: iceLite=${sendInfo['iceParameters']?['iceLite']}');
    for (var i = 0; i < iceCandidates.length; i++) {
      final c = iceCandidates[i];
      debugPrint(
          '[MediaSoup] _createSendTransport: ICE candidate [$i] ${c['protocol']}://${c['ip'] ?? c['address']}:${c['port']} type=${c['type']} foundation=${c['foundation']}');
    }

    final iceServers = _resolveIceServers();
    final policy = _resolveIceTransportPolicy();
    debugPrint(
        '[MediaSoup] _createSendTransport: using ${iceServers.length} ICE servers (policy=$policy)');

    _sendTransport = _msDevice!.createSendTransport(
      id: sendInfo['id'],
      iceParameters: IceParameters.fromMap(
          Map<String, dynamic>.from(sendInfo['iceParameters'])),
      iceCandidates: List<IceCandidate>.from(
        (sendInfo['iceCandidates'] as List)
            .map((c) => IceCandidate.fromMap(Map<String, dynamic>.from(c))),
      ),
      dtlsParameters: DtlsParameters.fromMap(
          Map<String, dynamic>.from(sendInfo['dtlsParameters'])),
      sctpParameters: sendInfo['sctpParameters'] != null
          ? SctpParameters.fromMap(
              Map<String, dynamic>.from(sendInfo['sctpParameters']))
          : null,
      iceServers: iceServers,
      iceTransportPolicy: policy,
      producerCallback: (Producer producer) {
        debugPrint(
            '[MediaSoup] ★ Producer callback: id=${producer.id}, kind=${producer.kind}');
        if (producer.kind == 'audio') {
          _audioProducer = producer;
          _audioProduceRequested = true;
          debugPrint('[MediaSoup] ★ Audio producer stored: ${producer.id}');
        } else if (producer.kind == 'video') {
          _videoProducer = producer;
          _videoProduceRequested = true;
          debugPrint('[MediaSoup] ★ Video producer stored: ${producer.id}');
        }
      },
    );

    // Handle DTLS connect
    _sendTransport!.on('connect', (Map data) {
      debugPrint('[MediaSoup] sendTransport ➜ connect event (DTLS handshake)');
      socketEmitWithAck('MS-connect-transport', {
        'roomId': roomId,
        'userId': userId,
        'transportId': _sendTransport!.id,
        'dtlsParameters': data['dtlsParameters'].toMap(),
      }).then((response) {
        debugPrint(
            '[MediaSoup] sendTransport ✓ DTLS connected (response=$response)');
        data['callback']();
      }).catchError((error) {
        debugPrint('[MediaSoup] sendTransport ✗ DTLS connect FAILED: $error');
        data['errback'](error);
      });
    });

    // Handle produce request — server returns the producer ID
    _sendTransport!.on('produce', (Map data) async {
      try {
        debugPrint(
            '[MediaSoup] sendTransport ➜ produce event kind=${data['kind']}');
        final response = await socketEmitWithAck('MS-produce', {
          'roomId': roomId,
          'userId': userId,
          'transportId': _sendTransport!.id,
          'kind': data['kind'],
          'rtpParameters': data['rtpParameters'].toMap(),
        });

        if (response != null &&
            response['ok'] == true &&
            response['id'] != null) {
          debugPrint(
              '[MediaSoup] sendTransport ✓ produce success: producerId=${response['id']} kind=${data['kind']}');
          data['callback'](response['id']);
        } else {
          debugPrint(
              '[MediaSoup] sendTransport ✗ produce FAILED: response=$response');
          _markProduceRequestFailed(data['kind']?.toString());
          _safeErrback(data, Exception('produce failed'));
        }
      } catch (error) {
        debugPrint('[MediaSoup] sendTransport ✗ produce EXCEPTION: $error');
        _markProduceRequestFailed(data['kind']?.toString());
        _safeErrback(data, error);
      }
    });

    _sendTransport!.on('connectionstatechange', (Map data) {
      final state = data['connectionState'] ?? data['state'];
      debugPrint('[MediaSoup] sendTransport connectionstatechange: $state');
      if (state == 'failed') {
        debugPrint(
            '[MediaSoup] ✗✗✗ sendTransport ICE FAILED — remote users may not see our video ✗✗✗');
        _sendIceRestartDebounce?.cancel();
        _sendIceRestartDebounce = Timer(const Duration(seconds: 1), () {
          if (!isCallActive.value || _isRestartingIce) return;
          if (socket == null || socket!.connected != true) return;
          final currentState = _sendTransport?.connectionState;
          if (currentState == 'connected') return;
          debugPrint(
              '[MediaSoup] sendTransport failed — triggering ICE restart (target=both)');
          _attemptIceRestart(target: 'both');
        });
      } else if (state == 'connected') {
        debugPrint('[MediaSoup] ✓✓✓ sendTransport ICE CONNECTED ✓✓✓');
        _sendIceRestartDebounce?.cancel();
        _sendIceRestartDebounce = null;
        _iceRestartBurstCount = 0;
        _iceRestartWindowStart = null;
      } else if (state == 'disconnected') {
        debugPrint(
            '[MediaSoup] ⚠ sendTransport ICE DISCONNECTED — waiting for recovery or failure');
        _sendIceRestartDebounce?.cancel();
        _sendIceRestartDebounce = Timer(const Duration(milliseconds: 8000), () {
          if (!isCallActive.value || _isRestartingIce) return;
          if (socket == null || socket!.connected != true) return;
          final currentState = _sendTransport?.connectionState;
          if (currentState == 'connected') {
            debugPrint(
                '[MediaSoup] sendTransport recovered before restart timer fired');
            return;
          }
          debugPrint(
              '[MediaSoup] sendTransport stayed disconnected — triggering ICE restart (target=both)');
          _attemptIceRestart(target: 'both');
        });
      }
    });
  }

  Future<void> _produceLocalTracksWithRetry({int maxAttempts = 3}) async {
    if (_isProducingLocalTracks || _hasProducedLocalTracks) {
      debugPrint(
          '[MediaSoup] _produceLocalTracksWithRetry: skipping (producing=$_isProducingLocalTracks produced=$_hasProducedLocalTracks)');
      return;
    }

    _isProducingLocalTracks = true;

    try {
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        debugPrint(
            '[MediaSoup] _produceLocalTracks attempt $attempt/$maxAttempts');
        await _produceLocalTracks();

        await Future.delayed(Duration(milliseconds: 200 + (attempt * 100)));

        final hasAudioTrack = localStream?.getAudioTracks().isNotEmpty ?? false;
        final hasVideoTrack = localStream?.getVideoTracks().isNotEmpty ?? false;

        final audioReady = !hasAudioTrack || _audioProducer != null;
        final videoReady =
            !isThisVideoCall.value || !hasVideoTrack || _videoProducer != null;

        debugPrint(
            '[MediaSoup] Produce check: hasAudio=$hasAudioTrack audioReady=$audioReady hasVideo=$hasVideoTrack videoReady=$videoReady audioProducer=${_audioProducer?.id} videoProducer=${_videoProducer?.id}');

        if (audioReady && videoReady) {
          _hasProducedLocalTracks = true;
          debugPrint(
              '[MediaSoup] ✓ Local tracks produced successfully on attempt $attempt');
          return;
        }

        debugPrint(
            '[MediaSoup] ⚠ Local produce attempt $attempt not ready yet');

        // Allow a clean retry for tracks whose callbacks never completed.
        if (!audioReady) {
          _audioProduceRequested = false;
        }
        if (!videoReady) {
          _videoProduceRequested = false;
        }
      }

      debugPrint(
          '[MediaSoup] ✗ Failed to produce local tracks after $maxAttempts attempts');
    } finally {
      _isProducingLocalTracks = false;
    }
  }

  /// Create the recv transport for consuming remote media.
  Future<void> _createRecvTransport(String roomId, String userId) async {
    debugPrint('[MediaSoup] _createRecvTransport: requesting from server...');
    final recvInfo = await socketEmitWithAck(
      'MS-create-transport',
      {'roomId': roomId, 'userId': userId, 'direction': 'recv'},
    );
    if (recvInfo == null || recvInfo['ok'] != true) {
      debugPrint('[MediaSoup] _createRecvTransport: FAILED response=$recvInfo');
      return;
    }

    _recvIceParameters = IceParameters.fromMap(
        Map<String, dynamic>.from(recvInfo['iceParameters']));

    // Log full server ICE candidate details
    final iceCandidates = recvInfo['iceCandidates'] as List? ?? [];
    debugPrint('[MediaSoup] _createRecvTransport: id=${recvInfo['id']}');
    debugPrint(
        '[MediaSoup] _createRecvTransport: iceLite=${recvInfo['iceParameters']?['iceLite']}');
    for (var i = 0; i < iceCandidates.length; i++) {
      final c = iceCandidates[i];
      debugPrint(
          '[MediaSoup] _createRecvTransport: ICE candidate [$i] ${c['protocol']}://${c['ip'] ?? c['address']}:${c['port']} type=${c['type']}');
    }

    _consumeChain = Future.value();
    String lastConnectionState = 'new';

    final recvIceServers = _resolveIceServers();
    final policy = _resolveIceTransportPolicy();
    debugPrint(
        '[MediaSoup] _createRecvTransport: using ${recvIceServers.length} ICE servers (policy=$policy)');

    _recvTransport = _msDevice!.createRecvTransport(
      id: recvInfo['id'],
      iceParameters: IceParameters.fromMap(
          Map<String, dynamic>.from(recvInfo['iceParameters'])),
      iceCandidates: List<IceCandidate>.from(
        (recvInfo['iceCandidates'] as List)
            .map((c) => IceCandidate.fromMap(Map<String, dynamic>.from(c))),
      ),
      dtlsParameters: DtlsParameters.fromMap(
          Map<String, dynamic>.from(recvInfo['dtlsParameters'])),
      sctpParameters: recvInfo['sctpParameters'] != null
          ? SctpParameters.fromMap(
              Map<String, dynamic>.from(recvInfo['sctpParameters']))
          : null,
      iceServers: recvIceServers,
      iceTransportPolicy: policy,
      consumerCallback: (Consumer consumer, [dynamic accept]) {
        debugPrint(
            '[MediaSoup] ★ Consumer callback: id=${consumer.id}, kind=${consumer.kind}, peerId=${consumer.peerId}, producerId=${consumer.producerId}');

        final remoteUserId = consumer.peerId ?? '';
        _consumers[consumer.id] = consumer;
        _consumerToUserMap[consumer.id] = remoteUserId;

        debugPrint(
            '[MediaSoup] ★ Consumer stored: total consumers=${_consumers.length}');

        _handleConsumerTrack(remoteUserId, consumer, consumer.kind ?? 'audio');

        if (accept != null) {
          debugPrint('[MediaSoup] ★ Calling accept() for consumer');
          accept();
        }
      },
    );

    // Handle DTLS connect
    _recvTransport!.on('connect', (Map data) {
      debugPrint('[MediaSoup] recvTransport ➜ connect event (DTLS handshake)');
      socketEmitWithAck('MS-connect-transport', {
        'roomId': roomId,
        'userId': userId,
        'transportId': _recvTransport!.id,
        'dtlsParameters': data['dtlsParameters'].toMap(),
      }).then((response) {
        debugPrint(
            '[MediaSoup] recvTransport ✓ DTLS connected (response=$response)');
        data['callback']();
      }).catchError((error) {
        debugPrint('[MediaSoup] recvTransport ✗ DTLS connect FAILED: $error');
        data['errback'](error);
      });
    });

    _recvTransport!.on('connectionstatechange', (Map data) {
      final state = data['connectionState'] ?? data['state'];
      debugPrint('[MediaSoup] recvTransport connectionstatechange: $state');
      final wasPreviouslyDisconnected = lastConnectionState == 'disconnected' ||
          lastConnectionState == 'failed';
      lastConnectionState = state?.toString() ?? 'unknown';

      if (state == 'failed') {
        debugPrint('[MediaSoup] ✗✗✗ recvTransport ICE FAILED ✗✗✗');
        _iceRestartDebounce?.cancel();
        _iceRestartDebounce = Timer(const Duration(seconds: 1), () {
          if (!isCallActive.value || _isRestartingIce) return;
          if (socket == null || socket!.connected != true) return;
          final currentState = _recvTransport?.connectionState;
          if (currentState == 'connected') return;
          debugPrint(
              '[MediaSoup] recvTransport failed — triggering ICE restart (target=both)');
          _attemptIceRestart(target: 'both');
        });
      } else if (state == 'connected') {
        debugPrint('[MediaSoup] ✓✓✓ recvTransport ICE CONNECTED ✓✓✓');
        // Cancel any pending recovery — connection restored on its own
        _iceRestartDebounce?.cancel();
        _iceRestartDebounce = null;
        _iceRestartBurstCount = 0;
        _iceRestartWindowStart = null;

        // On true reconnect (after disconnected/failed), fully rebuild
        // remote consumers from server state and force multi-pass reattach.
        if (wasPreviouslyDisconnected) {
          unawaited(_recoverRemoteMediaAfterRecvReconnect(roomId, userId));
        } else {
          _forceReattachRemoteRenderers();
          debugPrint(
              '[MediaSoup] recvTransport connected — refreshed ${remoteRenderers.length} renderers');
        }
      } else if (state == 'disconnected') {
        debugPrint(
            '[MediaSoup] ⚠ recvTransport ICE DISCONNECTED — scheduling recovery in 3s if not restored');
        // Match web behavior: brief grace period before attempting ICE restart.
        _iceRestartDebounce?.cancel();
        _iceRestartDebounce = Timer(const Duration(milliseconds: 8000), () {
          if (!isCallActive.value || _isRestartingIce) return;
          if (socket == null || socket!.connected != true) return;
          final currentState = _recvTransport?.connectionState;
          if (currentState == 'connected') {
            debugPrint(
                '[MediaSoup] recvTransport recovered before restart timer fired');
            return;
          }
          debugPrint(
              '[MediaSoup] recvTransport stayed disconnected — triggering ICE restart (target=both)');
          _attemptIceRestart(target: 'both');
        });
      }
    });
  }

  Future<void> _recoverRemoteMediaAfterRecvReconnect(
    String roomId,
    String userId,
  ) async {
    if (!isCallActive.value) return;
    if (_recvTransport == null || socket == null) return;

    debugPrint(
        '[MediaSoup] Reconnect recovery: rebuilding remote consumers/renderers...');

    try {
      // Close stale consumers so fresh tracks are negotiated after reconnect.
      for (final entry in _consumers.entries.toList()) {
        try {
          entry.value.close();
        } catch (_) {}
      }
      _consumers.clear();
      _consumerToUserMap.clear();
      _consumedProducerIds.clear();
      _consumeChain = Future.value();

      // Remove old tracks from remote streams to avoid stale frozen tracks.
      for (final stream in remoteStreams.values) {
        final oldAudio = List.from(stream.getAudioTracks());
        final oldVideo = List.from(stream.getVideoTracks());
        for (final t in oldAudio) {
          try {
            stream.removeTrack(t);
          } catch (_) {}
        }
        for (final t in oldVideo) {
          try {
            stream.removeTrack(t);
          } catch (_) {}
        }
      }

      // Re-consume all currently active producers from server snapshot.
      final response = await socketEmitWithAck('MS-get-producers', {
        'roomId': roomId,
        'userId': userId,
      });

      if (response == null || response['ok'] != true) {
        debugPrint(
            '[MediaSoup] Reconnect recovery: MS-get-producers failed response=$response');
        _forceReattachRemoteRenderers();
        return;
      }

      final producers = (response['producers'] as List?) ?? [];
      debugPrint(
          '[MediaSoup] Reconnect recovery: found ${producers.length} producers to re-consume');

      for (final p in producers) {
        final producerId = p['producerId']?.toString() ?? '';
        final remoteUserId = p['userId']?.toString() ?? '';
        final kind = p['kind']?.toString() ?? '';

        if (producerId.isEmpty || remoteUserId.isEmpty) continue;
        if (remoteUserId == userId) continue;

        await consumeProducer(roomId, userId, producerId, remoteUserId, kind);
      }

      // Multi-pass renderer reattach helps native texture/audio pipeline wake up.
      _forceReattachRemoteRenderers();
      Future.delayed(const Duration(milliseconds: 250), () {
        _forceReattachRemoteRenderers();
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        _forceReattachRemoteRenderers();
      });

      // Re-assert current audio route after media graph rebuild.
      unawaited(setAudioToSpeaker(isSpeakerOn.value));

      debugPrint(
          '[MediaSoup] Reconnect recovery complete: consumers=${_consumers.length}, renderers=${remoteRenderers.length}');
    } catch (e, stackTrace) {
      debugPrint('[MediaSoup] Reconnect recovery EXCEPTION: $e');
      debugPrint('[MediaSoup] Stack trace: $stackTrace');
      _forceReattachRemoteRenderers();
    }
  }

  void _forceReattachRemoteRenderers() {
    for (final uid in remoteStreams.keys.toList()) {
      final renderer = remoteRenderers[uid];
      final stream = remoteStreams[uid];
      if (renderer == null || stream == null) continue;

      try {
        renderer.srcObject = null;
      } catch (_) {}
      renderer.srcObject = stream;
      activeRenderers.add(uid);
    }

    remoteRenderers.refresh();
    remoteStreams.refresh();
  }

  /// Produce local audio and video tracks on the send transport.
  ///
  /// We intentionally produce in sequence (audio first, then video), matching
  /// the web client behavior and avoiding parallel renegotiation races.
  Future<void> _produceLocalTracks() async {
    if (_sendTransport == null ||
        localStream == null ||
        _hasProducedLocalTracks) {
      debugPrint(
          '[MediaSoup] _produceLocalTracks: cannot produce — sendTransport=${_sendTransport != null} localStream=${localStream != null} alreadyProduced=$_hasProducedLocalTracks');
      return;
    }

    // Produce audio
    final audioTracks = localStream!.getAudioTracks();
    debugPrint(
        '[MediaSoup] _produceLocalTracks: audioTracks=${audioTracks.length} audioProducer=${_audioProducer?.id} audioRequested=$_audioProduceRequested');
    if (audioTracks.isNotEmpty &&
        _audioProducer == null &&
        !_audioProduceRequested) {
      try {
        _audioProduceRequested = true;
        debugPrint(
            '[MediaSoup] _produceLocalTracks: calling produce() for audio track=${audioTracks.first.id}');
        _sendTransport!.produce(
          track: audioTracks.first,
          stream: localStream!,
          source: 'mic',
          stopTracks: false,
        );
        debugPrint('[MediaSoup] Audio produce() called successfully');

        // Give the produce callback time to return producer id before
        // attempting video produce on the same transport.
        await _waitForProducer(
            kind: 'audio', timeout: const Duration(seconds: 6));
      } catch (e) {
        _audioProduceRequested = false;
        debugPrint('[MediaSoup] ✗ Audio produce error: $e');
      }
    }

    // Produce video (only for video calls)
    final videoTracks = localStream!.getVideoTracks();
    debugPrint(
        '[MediaSoup] _produceLocalTracks: videoTracks=${videoTracks.length} isVideoCall=${isThisVideoCall.value} videoProducer=${_videoProducer?.id} videoRequested=$_videoProduceRequested');
    if (videoTracks.isNotEmpty &&
        isThisVideoCall.value &&
        _videoProducer == null &&
        !_videoProduceRequested) {
      try {
        _videoProduceRequested = true;
        debugPrint(
            '[MediaSoup] _produceLocalTracks: calling produce() for video track=${videoTracks.first.id}');
        _sendTransport!.produce(
          track: videoTracks.first,
          stream: localStream!,
          source: 'webcam',
          stopTracks: false,
        );
        debugPrint('[MediaSoup] Video produce() called successfully');

        await _waitForProducer(
            kind: 'video', timeout: const Duration(seconds: 6));
      } catch (e) {
        _videoProduceRequested = false;
        debugPrint('[MediaSoup] ✗ Video produce error: $e');
      }
    }
  }

  Future<void> _waitForProducer({
    required String kind,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final started = DateTime.now();
    while (DateTime.now().difference(started) < timeout) {
      if (kind == 'audio' && _audioProducer != null) return;
      if (kind == 'video' && _videoProducer != null) return;
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  void _markProduceRequestFailed(String? kind) {
    debugPrint('[MediaSoup] _markProduceRequestFailed: kind=$kind');
    if (kind == 'audio') {
      _audioProduceRequested = false;
    } else if (kind == 'video') {
      _videoProduceRequested = false;
    }
  }

  void _safeErrback(Map data, Object error) {
    try {
      final errback = data['errback'];
      if (errback is Function) {
        errback(error);
      }
    } catch (e) {
      debugPrint('[MediaSoup] errback threw: $e');
    }
  }

  /// Consume all existing producers in the room.
  Future<void> _consumeExistingProducers(String roomId, String userId) async {
    debugPrint(
        '[MediaSoup] _consumeExistingProducers: fetching for room=$roomId');
    try {
      final response = await socketEmitWithAck('MS-get-producers', {
        'roomId': roomId,
        'userId': userId,
      });

      if (response == null || response['ok'] != true) {
        debugPrint(
            '[MediaSoup] _consumeExistingProducers: MS-get-producers FAILED response=$response');
        return;
      }

      final producers = (response['producers'] as List?) ?? [];
      debugPrint(
          '[MediaSoup] _consumeExistingProducers: found ${producers.length} existing producers');

      for (var i = 0; i < producers.length; i++) {
        final p = producers[i];
        final producerId = p['producerId']?.toString() ?? '';
        final remoteUserId = p['userId']?.toString() ?? '';
        final kind = p['kind']?.toString() ?? '';

        debugPrint(
            '[MediaSoup] _consumeExistingProducers: [${i + 1}/${producers.length}] producer=$producerId user=$remoteUserId kind=$kind');

        if (producerId.isEmpty || remoteUserId.isEmpty) continue;
        if (_consumedProducerIds.contains(producerId)) continue;

        // consumeProducer is serialized via _consumeChain — each consume
        // waits for ICE ready + settle time before the next one starts.
        await consumeProducer(roomId, userId, producerId, remoteUserId, kind);
      }

      debugPrint(
          '[MediaSoup] _consumeExistingProducers: done — total consumers=${_consumers.length}');
    } catch (e, stackTrace) {
      debugPrint('[MediaSoup] _consumeExistingProducers EXCEPTION: $e');
      debugPrint('[MediaSoup] Stack trace: $stackTrace');
    }
  }

  /// Consume a single remote producer. Serialized via [_consumeChain] so only
  /// one SDP renegotiation runs at a time — prevents ICE disconnects caused by
  /// rapid-fire consume() calls.
  Future<void> consumeProducer(
    String roomId,
    String localUserId,
    String producerId,
    String remoteUserId,
    String kind,
  ) {
    // Chain onto the previous consume to serialize PeerConnection renegotiations
    final previous = _consumeChain ?? Future.value();
    final current = previous.then((_) => _doConsumeProducer(
        roomId, localUserId, producerId, remoteUserId, kind));
    _consumeChain = current.catchError((_) {});
    return current;
  }

  Future<void> _doConsumeProducer(
    String roomId,
    String localUserId,
    String producerId,
    String remoteUserId,
    String kind,
  ) async {
    debugPrint(
        '[MediaSoup] consumeProducer: producer=$producerId user=$remoteUserId kind=$kind');

    if (_consumedProducerIds.contains(producerId)) {
      debugPrint(
          '[MediaSoup] consumeProducer: already consumed $producerId, skipping');
      return;
    }
    _consumedProducerIds.add(producerId);

    try {
      if (_msDevice == null || _recvTransport == null) {
        debugPrint(
            '[MediaSoup] consumeProducer: CANNOT consume — device=${_msDevice != null} recvTransport=${_recvTransport != null}');
        _consumedProducerIds.remove(producerId);
        return;
      }

      debugPrint(
          '[MediaSoup] consumeProducer: sending MS-consume to server...');

      final response = await socketEmitWithAck('MS-consume', {
        'roomId': roomId,
        'userId': localUserId,
        'producerId': producerId,
        'rtpCapabilities': _msDevice!.rtpCapabilities.toMap(),
      });

      if (response == null || response['ok'] != true) {
        debugPrint(
            '[MediaSoup] consumeProducer: MS-consume FAILED response=$response');
        _consumedProducerIds.remove(producerId);
        return;
      }

      debugPrint(
          '[MediaSoup] consumeProducer: MS-consume response OK — consumerId=${response['id']} kind=${response['kind']} type=${response['type']}');

      final rtpKind = kind == 'video'
          ? RTCRtpMediaType.RTCRtpMediaTypeVideo
          : RTCRtpMediaType.RTCRtpMediaTypeAudio;

      // consume() triggers an SDP renegotiation on the PeerConnection.
      // The Consumer arrives via consumerCallback.
      // Matching web client: NO waiting for ICE connected, NO resume-consumer.
      // The server creates consumers with paused:false — no resume needed.
      _recvTransport!.consume(
        id: response['id'],
        producerId: response['producerId'],
        peerId: remoteUserId,
        kind: rtpKind,
        rtpParameters: RtpParameters.fromMap(
          Map<String, dynamic>.from(response['rtpParameters']),
        ),
      );

      debugPrint(
          '[MediaSoup] consumeProducer: consume() called for producer=$producerId');

      // Fire-and-forget resume (server creates unpaused, but resume is harmless)
      socketEmitWithAck('MS-resume-consumer', {
        'roomId': roomId,
        'userId': localUserId,
        'consumerId': response['id'],
      }).then((r) {
        debugPrint('[MediaSoup] consumeProducer: resume-consumer response=$r');
      }).catchError((_) {});

      setAudioToSpeaker(isSpeakerOn.value);
    } catch (e, stackTrace) {
      debugPrint('[MediaSoup] consumeProducer EXCEPTION: $e');
      debugPrint('[MediaSoup] Stack trace: $stackTrace');
      _consumedProducerIds.remove(producerId);
    }
  }

  /// Handle a consumer's track — create/update MediaStream and renderer for
  /// the remote user. Called from consumerCallback.
  Future<void> _handleConsumerTrack(
    String userId,
    Consumer consumer,
    String kind,
  ) async {
    debugPrint(
        '[MediaSoup] _handleConsumerTrack: userId=$userId kind=$kind consumerId=${consumer.id}');
    try {
      final track = consumer.track;
      debugPrint(
          '[MediaSoup] _handleConsumerTrack: track id=${track.id} kind=${track.kind} enabled=${track.enabled}');

      // Ensure user is tracked in _existingUserIds — during ICE recovery,
      // _existingUserIds is preserved but renderers/streams are cleared.
      // Without this, participantCount (based on _existingUserIds) would be wrong.
      _existingUserIds.add(userId);

      MediaStream stream;
      if (remoteStreams.containsKey(userId)) {
        stream = remoteStreams[userId]!;
        debugPrint(
            '[MediaSoup] _handleConsumerTrack: using existing stream for user=$userId');
        if (kind == 'video') {
          final existingVideoTracks = List.from(stream.getVideoTracks());
          debugPrint(
              '[MediaSoup] _handleConsumerTrack: removing ${existingVideoTracks.length} existing video tracks');
          for (var t in existingVideoTracks) {
            try {
              stream.removeTrack(t);
            } catch (_) {}
          }
        } else if (kind == 'audio') {
          final existingAudioTracks = List.from(stream.getAudioTracks());
          debugPrint(
              '[MediaSoup] _handleConsumerTrack: removing ${existingAudioTracks.length} existing audio tracks');
          for (var t in existingAudioTracks) {
            try {
              stream.removeTrack(t);
            } catch (_) {}
          }
        }
      } else {
        debugPrint(
            '[MediaSoup] _handleConsumerTrack: creating new MediaStream for user=$userId');
        stream = await createLocalMediaStream('remote_$userId');
      }

      stream.addTrack(track);
      remoteStreams[userId] = stream;
      debugPrint(
          '[MediaSoup] _handleConsumerTrack: stream now has audio=${stream.getAudioTracks().length} video=${stream.getVideoTracks().length}');

      if (!remoteRenderers.containsKey(userId)) {
        debugPrint(
            '[MediaSoup] _handleConsumerTrack: creating new RTCVideoRenderer for user=$userId');
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        remoteRenderers[userId] = renderer;
      }

      final renderer = remoteRenderers[userId]!;

      final hasVideo = stream.getVideoTracks().isNotEmpty;
      if (!hasVideo ||
          activeRenderers.length < maxActiveRenderers ||
          activeRenderers.contains(userId)) {
        // Matching web client: sync assignment, no await, fire-and-forget.
        // null→stream forces native layer to re-read tracks (reference
        // equality check). Platform channel calls are FIFO-ordered on native
        // thread, so null always processes before stream.
        try {
          renderer.srcObject = null;
        } catch (_) {}
        renderer.srcObject = stream;
        activeRenderers.add(userId);
        debugPrint(
            '[MediaSoup] _handleConsumerTrack: renderer attached for user=$userId (activeRenderers=${activeRenderers.length})');
      } else {
        try {
          if (renderer.srcObject != null) renderer.srcObject = null;
        } catch (_) {}
        activeRenderers.remove(userId);
        debugPrint(
            '[MediaSoup] _handleConsumerTrack: renderer NOT attached (maxActive=$maxActiveRenderers reached)');
      }

      if (reconnectingPeers.containsKey(userId)) {
        reconnectingPeers[userId] = false;
        reconnectingPeers.refresh();
      }

      remoteRenderers.refresh();
      remoteStreams.refresh();
      // Use _existingUserIds as single source of truth for participant count
      // (consistent with FE-user-join and removeConsumersForUser)
      participantCount.value = _existingUserIds.length + 1;

      debugPrint(
          '[MediaSoup] ✓ _handleConsumerTrack DONE: user=$userId kind=$kind participants=${participantCount.value} remoteRenderers=${remoteRenderers.length}');
    } catch (e, stackTrace) {
      debugPrint('[MediaSoup] _handleConsumerTrack EXCEPTION: $e');
      debugPrint('[MediaSoup] Stack trace: $stackTrace');
    }
  }

  /// Remove all consumers and renderers for a specific remote user.
  void removeConsumersForUser(String userId) {
    debugPrint('[MediaSoup] removeConsumersForUser: userId=$userId');
    final toRemove = <String>[];
    _consumerToUserMap.forEach((consumerId, uid) {
      if (uid == userId) {
        toRemove.add(consumerId);
      }
    });
    debugPrint(
        '[MediaSoup] removeConsumersForUser: closing ${toRemove.length} consumers');
    for (var consumerId in toRemove) {
      try {
        _consumers[consumerId]?.close();
      } catch (e) {
        debugPrint(
            '[MediaSoup] removeConsumersForUser: error closing consumer=$consumerId: $e');
      }
      _consumers.remove(consumerId);
      _consumerToUserMap.remove(consumerId);
    }

    // Detach renderer — dispose it so Android releases the native surface
    final renderer = remoteRenderers[userId];
    if (renderer != null) {
      try {
        renderer.srcObject = null;
      } catch (_) {}
      try {
        renderer.dispose();
      } catch (_) {}
    }
    remoteRenderers.remove(userId);

    // Remove stream reference — do NOT call stream.dispose() or track.stop().
    // The consumer.close() above already disposed native tracks. Calling
    // stream.dispose() on already-disposed tracks throws
    // "MediaStreamTrack has been disposed" which corrupts internal state.
    remoteStreams.remove(userId);
    activeRenderers.remove(userId);
    userInfoMap.remove(userId);
    userAudioEnabled.remove(userId);
    _existingUserIds.remove(userId);
    joinedUsers.removeWhere((u) => u['objectId'] == userId);

    Future.microtask(() {
      remoteRenderers.refresh();
      joinedUsers.refresh();
      participantCount.value = _existingUserIds.length + 1;
    });

    debugPrint(
        '[MediaSoup] removeConsumersForUser: DONE user=$userId remaining consumers=${_consumers.length} renderers=${remoteRenderers.length}');
  }

  /// Cleanup all MediaSoup resources (device, transports, producers, consumers).
  /// Order matters: close producers/consumers first, then transports.
  /// Transport.close() destroys the PeerConnection — anything after that will crash.
  Future<void> cleanupMediasoup() async {
    debugPrint(
        '[MediaSoup] cleanupMediasoup: starting — producers: audio=${_audioProducer?.id} video=${_videoProducer?.id} consumers=${_consumers.length}');

    // 1. Close producers first (they reference the send transport's PC)
    try {
      _audioProducer?.close();
    } catch (e) {
      debugPrint(
          '[MediaSoup] cleanupMediasoup: error closing audio producer: $e');
    }
    _audioProducer = null;

    try {
      _videoProducer?.close();
    } catch (e) {
      debugPrint(
          '[MediaSoup] cleanupMediasoup: error closing video producer: $e');
    }
    _videoProducer = null;

    // 2. Close consumers (they reference the recv transport's PC)
    for (final entry in _consumers.entries) {
      try {
        entry.value.close();
      } catch (e) {
        debugPrint(
            '[MediaSoup] cleanupMediasoup: error closing consumer ${entry.key}: $e');
      }
    }
    _consumers.clear();

    // 3. Grab references then null them BEFORE closing.
    // This prevents race conditions where queued FlexQueue tasks
    // (like stopSending) try to use the PC after transport.close() destroys it.
    final sendT = _sendTransport;
    final recvT = _recvTransport;
    _sendTransport = null;
    _recvTransport = null;
    _sendIceParameters = null;
    _recvIceParameters = null;
    _msDevice = null;

    // 4. Now close transports (destroys PeerConnections)
    try {
      sendT?.close();
    } catch (e) {
      debugPrint(
          '[MediaSoup] cleanupMediasoup: error closing send transport: $e');
    }

    try {
      recvT?.close();
    } catch (e) {
      debugPrint(
          '[MediaSoup] cleanupMediasoup: error closing recv transport: $e');
    }
    _consumerToUserMap.clear();
    _consumedProducerIds.clear();
    _socketToUserMap.clear();
    _userToSocketMap.clear();
    _pendingProducers.clear();
    _runtimeIceServers = null;
    _runtimeIceTransportPolicy = null;
    _mediasoupInitialized = false;
    _isProducingLocalTracks = false;
    _hasProducedLocalTracks = false;
    _audioProduceRequested = false;
    _videoProduceRequested = false;
    _isRestartingIce = false;
    _iceRestartDebounce?.cancel();
    _iceRestartDebounce = null;
    _sendIceRestartDebounce?.cancel();
    _sendIceRestartDebounce = null;
    _lastIceRestartAt = null;
    _iceRestartWindowStart = null;
    _iceRestartBurstCount = 0;
    _consumeChain = null;
    _stopKeepAlive();

    debugPrint('[MediaSoup] cleanupMediasoup: ALL resources cleaned');
  }
}
