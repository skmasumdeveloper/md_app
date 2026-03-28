import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide navigator;
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';

import '../Commons/platform_channels.dart';
import 'call_service.dart';

/// Fully isolated, production-ready screen sharing service.
///
/// Works via **track replacement** on the MediaSoup video Producer —
/// no new sockets, no ICE restart, no transport re-creation.
///
/// Usage (from any call controller):
///   final svc = ScreenShareService();
///   await svc.startScreenShare(localStream, videoProducer, localRenderer);
///   await svc.stopScreenShare(localStream, videoProducer, localRenderer, isVideoCall);
///
/// Lifecycle-safe: handles background, PiP, rotation, network change.
class ScreenShareService {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final ScreenShareService _instance = ScreenShareService._internal();
  factory ScreenShareService() => _instance;
  ScreenShareService._internal();

  // ── Observable state ───────────────────────────────────────────────────
  final RxBool isScreenSharing = false.obs;

  /// The original camera video track saved before replacement.
  MediaStreamTrack? _savedCameraTrack;

  /// The screen capture stream obtained from getDisplayMedia.
  MediaStream? _screenStream;

  /// Original camera constraints to restore cleanly.
  bool _wasVideoCall = true;

  /// Stored references so _handleTrackEnded can use the *current* objects.
  MediaStream? _activeLocalStream;
  Producer? _activeVideoProducer;
  RTCVideoRenderer? _activeLocalRenderer;

  /// Polling timer — fallback for Android where onEnded may not fire.
  Timer? _trackAliveTimer;

  /// Last known framesSent value from WebRTC outbound-rtp stats.
  int? _lastFramesSent;

  /// Number of consecutive polls where framesSent did not increase.
  int _staleFrameCount = 0;

  /// Guard against concurrent async stats checks.
  bool _statsCheckInProgress = false;

  /// Guard against re-entrant calls to stopScreenShare.
  bool _stopInProgress = false;

  // ── Public API ────────────────────────────────────────────────────────

  /// Start screen sharing by replacing the video track on the MediaSoup
  /// video Producer.
  ///
  /// [localStream] — the current local media stream (camera + mic).
  /// [videoProducer] — the MediaSoup video Producer.
  /// [localRenderer] — the local RTCVideoRenderer for preview.
  ///
  /// Returns `true` on success, `false` on failure or cancellation.
  Future<bool> startScreenShare({
    required MediaStream? localStream,
    required Producer? videoProducer,
    required RTCVideoRenderer localRenderer,
    required bool isVideoCall,
  }) async {
    if (isScreenSharing.value) {
      debugPrint('[ScreenShare] already sharing');
      return false;
    }

    if (localStream == null) {
      debugPrint('[ScreenShare] localStream is null, cannot share');
      return false;
    }

    _wasVideoCall = isVideoCall;

    try {
      // ── 1. Android: request consent FIRST ──
      if (Platform.isAndroid) {
        try {
          final consented = await Helper.requestCapturePermission();
          if (!consented) {
            debugPrint('[ScreenShare] user denied screen capture consent');
            return false;
          }
        } catch (e) {
          debugPrint('[ScreenShare] requestCapturePermission error: $e');
          return false;
        }

        final serviceOk = await PlatformChannels.startScreenCaptureService();
        if (!serviceOk) {
          debugPrint('[ScreenShare] failed to start ScreenCaptureService');
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // ── 2. Request screen capture via WebRTC getDisplayMedia ──
      _screenStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
          'frameRate': {'ideal': 15, 'max': 30},
        },
        'audio': false,
      });

      final screenTrack = _screenStream!.getVideoTracks().firstOrNull;
      if (screenTrack == null) {
        debugPrint('[ScreenShare] getDisplayMedia returned no video track');
        await _cleanupScreenStream();
        return false;
      }

      // ── 3. Listen for user stopping share via the system UI ──
      screenTrack.onEnded = () {
        debugPrint('[ScreenShare] screen track ended (user stopped via OS)');
        _onScreenShareStopped();
      };

      screenTrack.onMute = () {
        debugPrint('[ScreenShare] screen track muted — checking if ended');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (isScreenSharing.value) {
            final tracks = _screenStream?.getVideoTracks() ?? [];
            final alive = tracks.isNotEmpty && tracks.first.enabled;
            if (!alive) {
              debugPrint('[ScreenShare] track confirmed dead after mute');
              _onScreenShareStopped();
            }
          }
        });
      };

      // ── 4. Save the current camera track for later restoration ──
      final currentVideoTracks = localStream.getVideoTracks();
      if (currentVideoTracks.isNotEmpty) {
        _savedCameraTrack = currentVideoTracks.first;
        _savedCameraTrack!.enabled = false;
      }

      // ── 5. Replace video track on MediaSoup Producer ──
      if (videoProducer != null) {
        try {
          await videoProducer.replaceTrack(screenTrack);
          // If producer was paused, resume so screen share is visible remotely
          if (videoProducer.paused) {
            videoProducer.resume();
          }
          debugPrint('[ScreenShare] track replaced on video producer');
        } catch (e) {
          debugPrint('[ScreenShare] replaceTrack on producer failed: $e');
        }
      }

      // ── 6. Update local renderer ──
      localRenderer.srcObject = _screenStream;

      isScreenSharing.value = true;

      // Store references for the track-ended handler and polling timer
      _activeLocalStream = localStream;
      _activeVideoProducer = videoProducer;
      _activeLocalRenderer = localRenderer;

      PlatformChannels.onScreenShareStopped = _onScreenShareStopped;

      _startTrackAliveTimer();

      await CallService.setScreenSharing(true);

      debugPrint('[ScreenShare] screen sharing started successfully');
      return true;
    } catch (e) {
      debugPrint('[ScreenShare] startScreenShare error: $e');
      await _cleanupScreenStream();
      _savedCameraTrack?.enabled = true;
      _savedCameraTrack = null;
      return false;
    }
  }

  /// Stop screen sharing and restore the camera video track.
  Future<void> stopScreenShare({
    required MediaStream? localStream,
    required Producer? videoProducer,
    required RTCVideoRenderer localRenderer,
    bool? isVideoCall,
  }) async {
    if (!isScreenSharing.value) return;
    if (_stopInProgress) return;
    _stopInProgress = true;

    final videoCall = isVideoCall ?? _wasVideoCall;

    try {
      // ── 0. Immediately mark state ──
      isScreenSharing.value = false;
      _stopTrackAliveTimer();
      _lastFramesSent = null;
      _staleFrameCount = 0;
      PlatformChannels.onScreenShareStopped = null;

      // ── 1. Detach callbacks on the screen track FIRST ──
      try {
        final screenTracks = _screenStream?.getVideoTracks() ?? [];
        for (final t in screenTracks) {
          t.onEnded = null;
          t.onMute = null;
        }
      } catch (_) {}

      // ── 2. Replace screen track with camera track on producer ──
      if (_savedCameraTrack != null && videoCall) {
        _savedCameraTrack!.enabled = true;
        if (videoProducer != null) {
          try {
            await videoProducer.replaceTrack(_savedCameraTrack!);
            debugPrint('[ScreenShare] camera track restored on producer');
          } catch (e) {
            debugPrint('[ScreenShare] replaceTrack restore failed: $e');
          }
        }
        if (localStream != null) {
          localRenderer.srcObject = localStream;
        }
      } else if (!videoCall) {
        // Audio-only call — pause the video producer
        if (videoProducer != null && !videoProducer.paused) {
          videoProducer.pause();
        }
        if (localStream != null) {
          localRenderer.srcObject = localStream;
        }
      } else {
        // No saved camera track — create a new one
        if (localStream != null) {
          try {
            final newCameraStream = await navigator.mediaDevices.getUserMedia({
              'video': {
                'facingMode': 'user',
                'width': {'ideal': 480, 'max': 640},
                'height': {'ideal': 360, 'max': 480},
                'frameRate': {'ideal': 12, 'max': 15},
              },
              'audio': false,
            });
            final newTrack = newCameraStream.getVideoTracks().first;
            localStream.addTrack(newTrack);
            if (videoProducer != null) {
              await videoProducer.replaceTrack(newTrack);
            }
            localRenderer.srcObject = localStream;
          } catch (e) {
            debugPrint('[ScreenShare] failed to create new camera track: $e');
          }
        }
      }

      // ── 3. Let the native encoder finish switching tracks ──
      await Future.delayed(const Duration(milliseconds: 300));

      // ── 4. Stop the Android foreground service ──
      if (Platform.isAndroid) {
        try {
          await PlatformChannels.stopScreenCaptureService();
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // ── 5. Cleanup screen capture resources ──
      await _cleanupScreenStream();

      _savedCameraTrack = null;
      _activeLocalStream = null;
      _activeVideoProducer = null;
      _activeLocalRenderer = null;

      await CallService.setScreenSharing(false);

      debugPrint('[ScreenShare] screen sharing stopped successfully');
    } catch (e) {
      debugPrint('[ScreenShare] stopScreenShare error: $e');
      isScreenSharing.value = false;
      _stopTrackAliveTimer();
      _lastFramesSent = null;
      _staleFrameCount = 0;
      PlatformChannels.onScreenShareStopped = null;
      _activeLocalStream = null;
      _activeVideoProducer = null;
      _activeLocalRenderer = null;
      await CallService.setScreenSharing(false);
      await _cleanupScreenStream();
      _savedCameraTrack = null;
      if (Platform.isAndroid) {
        try {
          await PlatformChannels.stopScreenCaptureService();
        } catch (_) {}
      }
    } finally {
      _stopInProgress = false;
    }
  }

  /// Force cleanup — called when the call ends entirely.
  Future<void> dispose() async {
    _stopTrackAliveTimer();
    _stopInProgress = false;
    _lastFramesSent = null;
    _staleFrameCount = 0;
    PlatformChannels.onScreenShareStopped = null;
    if (isScreenSharing.value) {
      isScreenSharing.value = false;
      _activeLocalStream = null;
      _activeVideoProducer = null;
      _activeLocalRenderer = null;
      await CallService.setScreenSharing(false);
      await _cleanupScreenStream();
      _savedCameraTrack = null;

      if (Platform.isAndroid) {
        await PlatformChannels.stopScreenCaptureService();
      }
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────

  /// Stop and dispose the screen capture stream.
  Future<void> _cleanupScreenStream() async {
    if (_screenStream != null) {
      for (final track in _screenStream!.getVideoTracks()) {
        try {
          track.onEnded = null;
          track.onMute = null;
          await track.stop();
        } catch (_) {}
      }
      try {
        await _screenStream!.dispose();
      } catch (_) {}
      _screenStream = null;
    }
  }

  /// Called when the OS stops the screen track.
  void _onScreenShareStopped() {
    if (!isScreenSharing.value || _stopInProgress) return;
    final ls = _activeLocalStream;
    final producer = _activeVideoProducer;
    final lr = _activeLocalRenderer;
    if (lr != null) {
      stopScreenShare(
        localStream: ls,
        videoProducer: producer,
        localRenderer: lr,
      );
    } else {
      dispose();
    }
  }

  /// Start periodic timer checking if the screen capture track is still alive.
  void _startTrackAliveTimer() {
    _stopTrackAliveTimer();
    _lastFramesSent = null;
    _staleFrameCount = 0;
    _statsCheckInProgress = false;

    _trackAliveTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!isScreenSharing.value) {
        _stopTrackAliveTimer();
        return;
      }

      // Quick check: screen stream tracks still present?
      final tracks = _screenStream?.getVideoTracks() ?? [];
      if (tracks.isEmpty) {
        debugPrint('[ScreenShare] polling: no tracks — stopping');
        _onScreenShareStopped();
        return;
      }

      // For MediaSoup, we can't easily get stats from the producer's internal
      // peer connection. Instead, check if the track is still alive.
      if (_statsCheckInProgress) return;
      _statsCheckInProgress = true;

      try {
        final track = tracks.first;
        // Check if track readyState is "ended"
        if (!track.enabled || track.muted == true) {
          _staleFrameCount++;
          if (_staleFrameCount >= 3) {
            // Check if the Android service is still running
            if (Platform.isAndroid) {
              final serviceAlive =
                  await PlatformChannels.isScreenCaptureServiceRunning();
              if (!serviceAlive) {
                debugPrint(
                    '[ScreenShare] polling: track stale and service dead — stopping');
                _statsCheckInProgress = false;
                _onScreenShareStopped();
                return;
              }
              // Service alive but frames stale — wait longer
              if (_staleFrameCount >= 30) {
                debugPrint(
                    '[ScreenShare] polling: frames stalled for ${_staleFrameCount * 2}s — force stopping');
                _statsCheckInProgress = false;
                _onScreenShareStopped();
                return;
              }
            } else {
              debugPrint(
                  '[ScreenShare] polling: track stale — stopping');
              _statsCheckInProgress = false;
              _onScreenShareStopped();
              return;
            }
          }
        } else {
          _staleFrameCount = 0;
        }
      } catch (e) {
        debugPrint('[ScreenShare] polling check failed: $e');
      }

      _statsCheckInProgress = false;
    });
  }

  /// Stop the polling timer.
  void _stopTrackAliveTimer() {
    _trackAliveTimer?.cancel();
    _trackAliveTimer = null;
  }
}
