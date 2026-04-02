import 'dart:async';
import 'dart:collection';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';
import 'package:mediasfu_mediasoup_client/src/handlers/handler_interface.dart';

import 'call_logger.dart';

/// Callback types for transport events that need socket signaling.
typedef OnTransportConnect = Future<void> Function({
  required String transportId,
  required DtlsParameters dtlsParameters,
});

typedef OnTransportProduce = Future<String> Function({
  required String transportId,
  required String kind,
  required RtpParameters rtpParameters,
  required Map<String, dynamic> appData,
});

typedef OnTransportConnectionStateChange = void Function(
    String direction, String state);

/// Manages all mediasoup-client operations: Device, Transports, Producers, Consumers.
///
/// CRITICAL: All consume operations are serialized via a queue to prevent
/// concurrent consume calls from corrupting the single consumerCallback.
class MediasoupManager {
  static const String _scope = 'MediasoupMgr';

  Device? _device;
  Transport? _sendTransport;
  Transport? _recvTransport;
  Producer? _audioProducer;
  Producer? _videoProducer;

  /// All active consumers keyed by producerId.
  final Map<String, Consumer> _consumers = {};

  /// Track which producerIds we have already consumed.
  final Set<String> _consumedProducerIds = {};

  /// Single completer for the current produce operation (serialized by caller).
  Completer<Producer>? _producerCompleter;

  /// Single completer for the current consume operation (serialized by queue).
  Completer<Consumer>? _consumerCompleter;

  /// Queue for serializing consume operations — prevents concurrent callback corruption.
  final Queue<_ConsumeRequest> _consumeQueue = Queue();
  bool _isProcessingConsumeQueue = false;

  /// Callbacks set by the controller.
  OnTransportConnect? onSendTransportConnect;
  OnTransportConnect? onRecvTransportConnect;
  OnTransportProduce? onSendTransportProduce;
  OnTransportConnectionStateChange? onConnectionStateChange;

  Device? get device => _device;
  Transport? get sendTransport => _sendTransport;
  Transport? get recvTransport => _recvTransport;
  Producer? get audioProducer => _audioProducer;
  Producer? get videoProducer => _videoProducer;
  Map<String, Consumer> get consumers => _consumers;

  bool get isDeviceLoaded => _device != null && _device!.loaded;

  /// Load the mediasoup Device with router RTP capabilities.
  Future<void> loadDevice(Map<String, dynamic> routerRtpCapabilities) async {
    CallLogger.info(_scope, 'loadDevice:start');
    Device? initialDevice;
    try {
      initialDevice = await _buildLoadedDevice(routerRtpCapabilities);
      _device = initialDevice;

      final hasRouterH264 =
          _hasCodec(routerRtpCapabilities, mimeType: 'video/H264');
      final initialHasH264 = _hasCodec(initialDevice.rtpCapabilities.toMap(),
          mimeType: 'video/H264');

      if (hasRouterH264 && !initialHasH264) {
        CallLogger.warn(_scope, 'loadDevice:h264-missing-after-initial-load');

        final nativeCaps = await _getNativeRtpCapabilitiesMap();
        final preferredH264Params = _extractPreferredH264Parameters(nativeCaps);

        if (preferredH264Params.isNotEmpty) {
          final patchedCaps = _patchRouterH264Parameters(
            routerRtpCapabilities,
            preferredH264Params,
          );

          if (patchedCaps != null) {
            try {
              final fallbackDevice = await _buildLoadedDevice(patchedCaps);
              _device = fallbackDevice;

              final fallbackHasH264 = _hasCodec(
                fallbackDevice.rtpCapabilities.toMap(),
                mimeType: 'video/H264',
              );

              CallLogger.info(_scope, 'loadDevice:h264-compat-fallback:done', {
                'hasH264': fallbackHasH264,
              });
            } catch (e) {
              _device = initialDevice;
              CallLogger.warn(
                  _scope, 'loadDevice:h264-compat-fallback:failed', {
                'error': e.toString(),
              });
            }
          } else {
            CallLogger.warn(
                _scope, 'loadDevice:h264-compat-fallback:unchanged');
          }
        } else {
          CallLogger.warn(
              _scope, 'loadDevice:h264-compat-fallback:no-native-hint');
        }
      }

      final loadedCaps = _device?.rtpCapabilities.toMap();
      CallLogger.info(_scope, 'loadDevice:success', {
        'videoCodecs': _listVideoCodecs(loadedCaps).join(','),
      });
    } catch (e) {
      CallLogger.error(_scope, 'loadDevice:failed', {'error': e.toString()});
      _device = null;
      rethrow;
    }
  }

  Future<Device> _buildLoadedDevice(
      Map<String, dynamic> routerRtpCapabilities) async {
    final device = Device();
    await device.load(
      routerRtpCapabilities: RtpCapabilities.fromMap(routerRtpCapabilities),
    );
    return device;
  }

  Future<Map<String, dynamic>?> _getNativeRtpCapabilitiesMap() async {
    final handler = HandlerInterface.handlerFactory();
    try {
      final nativeCaps = await handler.getNativeRtpCapabilities();
      return nativeCaps.toMap();
    } catch (e) {
      CallLogger.warn(_scope, 'loadDevice:nativeCaps:failed', {
        'error': e.toString(),
      });
      return null;
    } finally {
      try {
        await handler.close();
      } catch (_) {}
    }
  }

  Map<String, dynamic> _extractPreferredH264Parameters(
      Map<String, dynamic>? nativeCaps) {
    if (nativeCaps == null) {
      return const <String, dynamic>{};
    }

    final codecs = nativeCaps['codecs'] as List? ?? const [];
    Map<String, dynamic>? bestParams;
    var bestScore = -1;

    for (final codecRaw in codecs) {
      if (codecRaw is! Map) continue;

      final codec = Map<String, dynamic>.from(codecRaw);
      final mimeType = codec['mimeType']?.toString().toLowerCase();
      if (mimeType != 'video/h264') continue;

      final params = codec['parameters'] is Map
          ? Map<String, dynamic>.from(codec['parameters'] as Map)
          : <String, dynamic>{};

      var score = 0;
      if (params['profile-level-id'] != null) score += 2;
      if (params['packetization-mode'] != null) score += 1;

      if (score > bestScore) {
        bestScore = score;
        bestParams = params;
      }
    }

    if (bestParams == null) {
      return const <String, dynamic>{};
    }

    return <String, dynamic>{
      if (bestParams['profile-level-id'] != null)
        'profile-level-id': bestParams['profile-level-id'],
      if (bestParams['packetization-mode'] != null)
        'packetization-mode': bestParams['packetization-mode'],
      'level-asymmetry-allowed': bestParams['level-asymmetry-allowed'] ?? 1,
    };
  }

  Map<String, dynamic>? _patchRouterH264Parameters(
    Map<String, dynamic> routerRtpCapabilities,
    Map<String, dynamic> h264Params,
  ) {
    final codecs = routerRtpCapabilities['codecs'] as List?;
    if (codecs == null || codecs.isEmpty) {
      return null;
    }

    var changed = false;
    final patchedCodecs = <dynamic>[];

    for (final codecRaw in codecs) {
      if (codecRaw is! Map) {
        patchedCodecs.add(codecRaw);
        continue;
      }

      final codec = Map<String, dynamic>.from(codecRaw);
      final mimeType = codec['mimeType']?.toString().toLowerCase();

      if (mimeType != 'video/h264') {
        patchedCodecs.add(codec);
        continue;
      }

      final params = codec['parameters'] is Map
          ? Map<String, dynamic>.from(codec['parameters'] as Map)
          : <String, dynamic>{};

      h264Params.forEach((key, value) {
        if (value == null) return;
        if (params[key]?.toString() != value.toString()) {
          params[key] = value;
          changed = true;
        }
      });

      codec['parameters'] = params;
      patchedCodecs.add(codec);
    }

    if (!changed) {
      return null;
    }

    final patchedCaps = Map<String, dynamic>.from(routerRtpCapabilities);
    patchedCaps['codecs'] = patchedCodecs;
    return patchedCaps;
  }

  bool _hasCodec(
    Map<String, dynamic>? capabilities, {
    required String mimeType,
  }) {
    if (capabilities == null) {
      return false;
    }

    final codecs = capabilities['codecs'] as List? ?? const [];
    final target = mimeType.toLowerCase();

    for (final codecRaw in codecs) {
      if (codecRaw is! Map) continue;
      final codec = Map<String, dynamic>.from(codecRaw);
      if (codec['mimeType']?.toString().toLowerCase() == target) {
        return true;
      }
    }

    return false;
  }

  List<String> _listVideoCodecs(Map<String, dynamic>? capabilities) {
    if (capabilities == null) {
      return const <String>[];
    }

    final codecs = capabilities['codecs'] as List? ?? const [];
    final videoCodecs = <String>[];

    for (final codecRaw in codecs) {
      if (codecRaw is! Map) continue;

      final codec = Map<String, dynamic>.from(codecRaw);
      final mimeType = codec['mimeType']?.toString().toLowerCase() ?? '';
      if (mimeType.startsWith('video/')) {
        videoCodecs.add(mimeType.replaceFirst('video/', ''));
      }
    }

    return videoCodecs;
  }

  /// Build RTCIceServer list from maps.
  List<RTCIceServer> _buildIceServers(List<Map<String, dynamic>> servers) {
    return servers.map((s) {
      final urls = s['urls'];
      final urlList = urls is List
          ? urls.map((u) => u.toString()).toList()
          : [urls.toString()];
      return RTCIceServer(
        urls: urlList,
        username: s['username']?.toString() ?? '',
        credential: s['credential']?.toString(),
        credentialType: RTCIceCredentialType.password,
      );
    }).toList();
  }

  /// Create the send transport using server-provided params.
  Future<void> createSendTransport({
    required String id,
    required Map<String, dynamic> iceParameters,
    required List<dynamic> iceCandidates,
    required Map<String, dynamic> dtlsParameters,
    required List<Map<String, dynamic>> iceServers,
    String? iceTransportPolicy,
  }) async {
    CallLogger.info(_scope, 'createSendTransport:start', {'id': id});

    _sendTransport = _device!.createSendTransport(
      id: id,
      iceParameters: IceParameters.fromMap(iceParameters),
      iceCandidates: iceCandidates
          .map((c) => IceCandidate.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      dtlsParameters: DtlsParameters.fromMap(dtlsParameters),
      iceServers: _buildIceServers(iceServers),
      producerCallback: (Producer producer) {
        CallLogger.info(_scope, 'producerCallback', {
          'producerId': producer.id,
          'kind': producer.kind,
        });
        if (_producerCompleter != null && !_producerCompleter!.isCompleted) {
          _producerCompleter!.complete(producer);
        }
        _producerCompleter = null;
      },
    );

    _sendTransport!.on('connect', (Map data) async {
      CallLogger.info(_scope, 'sendTransport:connect');
      final cb = data['callback'] as Function?;
      final errback = data['errback'] as Function?;
      try {
        await onSendTransportConnect?.call(
          transportId: _sendTransport!.id,
          dtlsParameters: data['dtlsParameters'] as DtlsParameters,
        );
        cb?.call();
      } catch (e) {
        CallLogger.error(
            _scope, 'sendTransport:connect:error', {'error': e.toString()});
        errback?.call(e);
      }
    });

    _sendTransport!.on('produce', (Map data) async {
      CallLogger.info(_scope, 'sendTransport:produce', {'kind': data['kind']});
      final cb = data['callback'] as Function?;
      final errback = data['errback'] as Function?;
      try {
        final appData = data['appData'] is Map
            ? Map<String, dynamic>.from(data['appData'] as Map)
            : const <String, dynamic>{};

        final producerId = await onSendTransportProduce?.call(
          transportId: _sendTransport!.id,
          kind: data['kind'] as String,
          rtpParameters: data['rtpParameters'] as RtpParameters,
          appData: appData,
        );
        cb?.call(producerId);
      } catch (e) {
        CallLogger.error(
            _scope, 'sendTransport:produce:error', {'error': e.toString()});
        errback?.call(e);
      }
    });

    _sendTransport!.on('connectionstatechange', (Map data) {
      final state = data['connectionState']?.toString() ?? 'unknown';
      CallLogger.info(
          _scope, 'sendTransport:connectionStateChange', {'state': state});
      onConnectionStateChange?.call('send', state);
    });

    CallLogger.info(_scope, 'createSendTransport:done', {'id': id});
  }

  /// Create the recv transport using server-provided params.
  Future<void> createRecvTransport({
    required String id,
    required Map<String, dynamic> iceParameters,
    required List<dynamic> iceCandidates,
    required Map<String, dynamic> dtlsParameters,
    required List<Map<String, dynamic>> iceServers,
    String? iceTransportPolicy,
  }) async {
    CallLogger.info(_scope, 'createRecvTransport:start', {'id': id});

    _recvTransport = _device!.createRecvTransport(
      id: id,
      iceParameters: IceParameters.fromMap(iceParameters),
      iceCandidates: iceCandidates
          .map((c) => IceCandidate.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      dtlsParameters: DtlsParameters.fromMap(dtlsParameters),
      iceServers: _buildIceServers(iceServers),
      consumerCallback: (Consumer consumer, [dynamic accept]) {
        CallLogger.info(_scope, 'consumerCallback:received', {
          'consumerId': consumer.id,
          'producerId': consumer.producerId,
          'kind': consumer.kind,
        });
        if (accept != null) {
          accept();
        }
        // Complete the current consume operation
        if (_consumerCompleter != null && !_consumerCompleter!.isCompleted) {
          _consumerCompleter!.complete(consumer);
        } else {
          CallLogger.warn(_scope, 'consumerCallback:no-completer', {
            'consumerId': consumer.id,
          });
        }
      },
    );

    _recvTransport!.on('connect', (Map data) async {
      CallLogger.info(_scope, 'recvTransport:connect');
      final cb = data['callback'] as Function?;
      final errback = data['errback'] as Function?;
      try {
        await onRecvTransportConnect?.call(
          transportId: _recvTransport!.id,
          dtlsParameters: data['dtlsParameters'] as DtlsParameters,
        );
        cb?.call();
      } catch (e) {
        CallLogger.error(
            _scope, 'recvTransport:connect:error', {'error': e.toString()});
        errback?.call(e);
      }
    });

    _recvTransport!.on('connectionstatechange', (Map data) {
      final state = data['connectionState']?.toString() ?? 'unknown';
      CallLogger.info(
          _scope, 'recvTransport:connectionStateChange', {'state': state});
      onConnectionStateChange?.call('recv', state);
    });

    CallLogger.info(_scope, 'createRecvTransport:done', {'id': id});
  }

  /// Produce a local audio track.
  Future<Producer?> produceAudio(
      MediaStreamTrack track, MediaStream stream) async {
    if (_sendTransport == null) {
      CallLogger.warn(_scope, 'produceAudio:no-send-transport');
      return null;
    }
    CallLogger.info(_scope, 'produceAudio:start');
    try {
      _producerCompleter = Completer<Producer>();

      _sendTransport!.produce(
        track: track,
        codecOptions: ProducerCodecOptions(opusStereo: 1, opusDtx: 1),
        stream: stream,
        source: 'mic',
      );

      _audioProducer =
          await _producerCompleter!.future.timeout(const Duration(seconds: 15));
      CallLogger.info(_scope, 'produceAudio:success', {
        'producerId': _audioProducer!.id,
      });
      return _audioProducer;
    } catch (e) {
      CallLogger.error(_scope, 'produceAudio:failed', {'error': e.toString()});
      _producerCompleter = null;
      return null;
    }
  }

  /// Produce a local video track with adaptive encoding.
  Future<Producer?> produceVideo(
      MediaStreamTrack track, MediaStream stream) async {
    if (_sendTransport == null) {
      CallLogger.warn(_scope, 'produceVideo:no-send-transport');
      return null;
    }
    CallLogger.info(_scope, 'produceVideo:start');
    try {
      _producerCompleter = Completer<Producer>();
      final appData = _buildVideoAppData(track);

      _sendTransport!.produce(
        track: track,
        encodings: [
          RtpEncodingParameters(
            maxBitrate: 500000,
            maxFramerate: 15,
            scalabilityMode: 'L1T1',
          ),
        ],
        stream: stream,
        source: 'webcam',
        appData: appData,
      );

      _videoProducer =
          await _producerCompleter!.future.timeout(const Duration(seconds: 15));
      CallLogger.info(_scope, 'produceVideo:success', {
        'producerId': _videoProducer!.id,
        'appData': appData.toString(),
      });
      return _videoProducer;
    } catch (e) {
      CallLogger.error(_scope, 'produceVideo:failed', {'error': e.toString()});
      _producerCompleter = null;
      return null;
    }
  }

  /// Build producer appData for cross-platform interoperability.
  ///
  /// Backend/web flows rely on width/height metadata for portrait handling
  /// and recorder layout decisions.
  Map<String, dynamic> _buildVideoAppData(MediaStreamTrack track) {
    Map<String, dynamic> settings = const <String, dynamic>{};
    try {
      settings = track.getSettings();
    } catch (_) {}

    final width = _toPositiveInt(settings['width']) ??
        _toPositiveInt(settings['frameWidth']) ??
        _toPositiveInt(settings['videoWidth']) ??
        480;
    final height = _toPositiveInt(settings['height']) ??
        _toPositiveInt(settings['frameHeight']) ??
        _toPositiveInt(settings['videoHeight']) ??
        640;
    final rotation = _extractNormalizedRotation(settings);

    return <String, dynamic>{
      'width': width,
      'height': height,
      'rotation': rotation,
    };
  }

  int _extractNormalizedRotation(Map<String, dynamic> settings) {
    final directRotation = _toInt(settings['rotation']) ??
        _toInt(settings['videoRotation']) ??
        _toInt(settings['cameraRotation']) ??
        _toInt(settings['orientationDegrees']) ??
        _toInt(settings['screenOrientationAngle']);

    if (directRotation != null) {
      return _normalizeRightAngleRotation(directRotation);
    }

    final orientationText = (settings['orientation']?.toString() ??
            settings['screenOrientation']?.toString() ??
            settings['deviceOrientation']?.toString() ??
            '')
        .toLowerCase()
        .replaceAll(' ', '');

    if (orientationText.contains('portrait') &&
        orientationText.contains('upside')) {
      return 180;
    }
    if (orientationText.contains('portrait')) {
      return 0;
    }
    if (orientationText.contains('landscape') &&
        orientationText.contains('right')) {
      return 270;
    }
    if (orientationText.contains('landscape')) {
      return 90;
    }

    return 0;
  }

  int _normalizeRightAngleRotation(int value) {
    final normalized = ((value % 360) + 360) % 360;

    if (normalized >= 315 || normalized < 45) return 0;
    if (normalized < 135) return 90;
    if (normalized < 225) return 180;
    return 270;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  int? _toPositiveInt(dynamic value) {
    if (value is int) {
      return value > 0 ? value : null;
    }
    if (value is double) {
      final rounded = value.round();
      return rounded > 0 ? rounded : null;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      return (parsed != null && parsed > 0) ? parsed : null;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONSUME — serialized via queue to prevent concurrent callback issues
  // ═══════════════════════════════════════════════════════════════════

  /// Queue a consume request. Returns the Consumer when done.
  /// All consume calls go through this queue to ensure only one
  /// recvTransport.consume() is in-flight at a time.
  Future<Consumer?> consume({
    required String consumerId,
    required String producerId,
    required String peerId,
    required String kind,
    required Map<String, dynamic> rtpParameters,
  }) async {
    if (_recvTransport == null) {
      CallLogger.warn(_scope, 'consume:no-recv-transport');
      return null;
    }

    if (_consumedProducerIds.contains(producerId)) {
      CallLogger.warn(
          _scope, 'consume:already-consumed', {'producerId': producerId});
      return _consumers[producerId];
    }

    final request = _ConsumeRequest(
      consumerId: consumerId,
      producerId: producerId,
      peerId: peerId,
      kind: kind,
      rtpParameters: rtpParameters,
      completer: Completer<Consumer?>(),
    );

    _consumeQueue.add(request);
    CallLogger.info(_scope, 'consume:queued', {
      'producerId': producerId,
      'kind': kind,
      'queueLength': _consumeQueue.length,
    });

    _processConsumeQueue();
    return request.completer.future;
  }

  /// Process the consume queue one at a time.
  Future<void> _processConsumeQueue() async {
    if (_isProcessingConsumeQueue) return;
    _isProcessingConsumeQueue = true;

    while (_consumeQueue.isNotEmpty) {
      final request = _consumeQueue.removeFirst();

      try {
        final consumer = await _executeConsume(request);
        if (!request.completer.isCompleted) {
          request.completer.complete(consumer);
        }
      } catch (e) {
        CallLogger.error(_scope, 'consume:queue:error', {
          'producerId': request.producerId,
          'error': e.toString(),
        });
        if (!request.completer.isCompleted) {
          request.completer.complete(null);
        }
      }

      // Small delay between consume operations to let the transport settle
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _isProcessingConsumeQueue = false;
  }

  /// Execute a single consume operation with its own completer.
  Future<Consumer?> _executeConsume(_ConsumeRequest request) async {
    if (_recvTransport == null) return null;

    if (_consumedProducerIds.contains(request.producerId)) {
      return _consumers[request.producerId];
    }

    CallLogger.info(_scope, 'consume:execute', {
      'producerId': request.producerId,
      'kind': request.kind,
    });

    _consumerCompleter = Completer<Consumer>();
    final primaryCodec =
        _extractPrimaryMediaCodecMimeType(request.rtpParameters);

    final mediaType = request.kind == 'audio'
        ? RTCRtpMediaType.RTCRtpMediaTypeAudio
        : RTCRtpMediaType.RTCRtpMediaTypeVideo;

    try {
      _recvTransport!.consume(
        id: request.consumerId,
        producerId: request.producerId,
        peerId: request.peerId,
        kind: mediaType,
        rtpParameters: RtpParameters.fromMap(request.rtpParameters),
      );
    } catch (e) {
      _consumerCompleter = null;
      CallLogger.warn(_scope, 'consume:execute:transport-rejected', {
        'producerId': request.producerId,
        'kind': request.kind,
        'codec': primaryCodec ?? 'unknown',
        'error': e.toString(),
      });
      return null;
    }

    final consumer =
        await _consumerCompleter!.future.timeout(const Duration(seconds: 15));

    _consumers[request.producerId] = consumer;
    _consumedProducerIds.add(request.producerId);

    CallLogger.info(_scope, 'consume:execute:success', {
      'consumerId': consumer.id,
      'producerId': request.producerId,
      'kind': request.kind,
    });

    return consumer;
  }

  String? _extractPrimaryMediaCodecMimeType(
      Map<String, dynamic> rtpParameters) {
    final codecs = rtpParameters['codecs'] as List? ?? const [];
    for (final codecRaw in codecs) {
      if (codecRaw is! Map) continue;
      final codec = Map<String, dynamic>.from(codecRaw);
      final mimeType = codec['mimeType']?.toString();
      if (mimeType == null || mimeType.isEmpty) continue;

      final lower = mimeType.toLowerCase();
      if (lower.endsWith('/rtx') ||
          lower.endsWith('/red') ||
          lower.endsWith('/ulpfec') ||
          lower.endsWith('/flexfec-03')) {
        continue;
      }
      return mimeType;
    }
    return null;
  }

  /// Pause the audio producer (mute).
  void pauseAudioProducer() {
    if (_audioProducer != null && !_audioProducer!.paused) {
      _audioProducer!.pause();
      CallLogger.info(_scope, 'pauseAudioProducer');
    }
  }

  /// Resume the audio producer (unmute).
  void resumeAudioProducer() {
    if (_audioProducer != null && _audioProducer!.paused) {
      _audioProducer!.resume();
      CallLogger.info(_scope, 'resumeAudioProducer');
    }
  }

  /// Pause the video producer (camera off).
  void pauseVideoProducer() {
    if (_videoProducer != null && !_videoProducer!.paused) {
      _videoProducer!.pause();
      CallLogger.info(_scope, 'pauseVideoProducer');
    }
  }

  /// Resume the video producer (camera on).
  void resumeVideoProducer() {
    if (_videoProducer != null && _videoProducer!.paused) {
      _videoProducer!.resume();
      CallLogger.info(_scope, 'resumeVideoProducer');
    }
  }

  /// Replace the video producer's track (e.g. camera switch).
  Future<void> replaceVideoTrack(MediaStreamTrack newTrack) async {
    if (_videoProducer == null) {
      CallLogger.warn(_scope, 'replaceVideoTrack:no-producer');
      return;
    }
    CallLogger.info(_scope, 'replaceVideoTrack');
    await _videoProducer!.replaceTrack(newTrack);
  }

  /// Restart ICE on a transport.
  void restartIce(String direction, IceParameters iceParameters) {
    CallLogger.info(_scope, 'restartIce', {'direction': direction});
    final transport = direction == 'send' ? _sendTransport : _recvTransport;
    if (transport == null) {
      CallLogger.warn(
          _scope, 'restartIce:no-transport', {'direction': direction});
      return;
    }
    transport.restartIce(iceParameters);
    CallLogger.info(_scope, 'restartIce:done', {'direction': direction});
  }

  /// Remove a consumer by producerId.
  void removeConsumer(String producerId) {
    final consumer = _consumers.remove(producerId);
    _consumedProducerIds.remove(producerId);
    if (consumer != null) {
      try {
        consumer.close();
      } catch (_) {}
      CallLogger.info(_scope, 'removeConsumer', {'producerId': producerId});
    }
  }

  /// Get the RTP capabilities of the loaded device.
  RtpCapabilities? get rtpCapabilities => _device?.rtpCapabilities;

  /// Close all consumers without closing transports.
  void closeAllConsumers() {
    CallLogger.info(_scope, 'closeAllConsumers', {'count': _consumers.length});
    for (final consumer in _consumers.values) {
      try {
        consumer.close();
      } catch (_) {}
    }
    _consumers.clear();
    _consumedProducerIds.clear();
    _consumeQueue.clear();
    _isProcessingConsumeQueue = false;
  }

  /// Full cleanup: close producers, transports, device.
  void dispose() {
    CallLogger.info(_scope, 'dispose:start');

    try {
      _audioProducer?.close();
    } catch (_) {}
    try {
      _videoProducer?.close();
    } catch (_) {}

    closeAllConsumers();

    try {
      _sendTransport?.close();
    } catch (_) {}
    try {
      _recvTransport?.close();
    } catch (_) {}

    _audioProducer = null;
    _videoProducer = null;
    _sendTransport = null;
    _recvTransport = null;
    _device = null;
    _producerCompleter = null;
    _consumerCompleter = null;

    onSendTransportConnect = null;
    onRecvTransportConnect = null;
    onSendTransportProduce = null;
    onConnectionStateChange = null;

    CallLogger.info(_scope, 'dispose:done');
  }
}

/// Internal request object for the consume queue.
class _ConsumeRequest {
  final String consumerId;
  final String producerId;
  final String peerId;
  final String kind;
  final Map<String, dynamic> rtpParameters;
  final Completer<Consumer?> completer;

  _ConsumeRequest({
    required this.consumerId,
    required this.producerId,
    required this.peerId,
    required this.kind,
    required this.rtpParameters,
    required this.completer,
  });
}
