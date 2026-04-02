import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'call_logger.dart';

/// Manages local media: camera, microphone, permissions, and adaptive quality.
class MediaManager {
  static const String _scope = 'MediaMgr';

  MediaStream? _localStream;
  RTCVideoRenderer? _localRenderer;
  bool _isFrontCamera = true;

  MediaStream? get localStream => _localStream;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  bool get isFrontCamera => _isFrontCamera;

  /// Request camera and microphone permissions.
  Future<bool> requestPermissions({required bool isVideoCall}) async {
    CallLogger.info(_scope, 'requestPermissions', {'isVideoCall': isVideoCall});

    final permissions = <Permission>[
      Permission.microphone,
      if (isVideoCall) Permission.camera,
    ];

    for (final permission in permissions) {
      final status = await permission.status;
      if (status.isGranted) continue;

      final result = await permission.request();
      CallLogger.info(_scope, 'requestPermissions:result', {
        'permission': permission.toString(),
        'granted': result.isGranted,
      });

      if (!result.isGranted) return false;
    }

    return true;
  }

  /// Initialize local media stream (camera + mic).
  Future<MediaStream?> initLocalMedia({required bool isVideoCall}) async {
    CallLogger.info(
        _scope, 'initLocalMedia:start', {'isVideoCall': isVideoCall});

    try {
      // Try preferred constraints first
      _localStream = await _getUserMedia(isVideoCall: isVideoCall);

      if (_localStream == null) {
        CallLogger.error(_scope, 'initLocalMedia:failed-all-attempts');
        return null;
      }

      // Initialize renderer
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
      _localRenderer!.srcObject = _localStream;

      CallLogger.info(_scope, 'initLocalMedia:success', {
        'audioTracks': _localStream!.getAudioTracks().length,
        'videoTracks': _localStream!.getVideoTracks().length,
      });

      return _localStream;
    } catch (e) {
      CallLogger.error(_scope, 'initLocalMedia:error', {'error': e.toString()});
      return null;
    }
  }

  /// Get user media with fallback chain.
  Future<MediaStream?> _getUserMedia({required bool isVideoCall}) async {
    // Attempt 1: Full constraints — PORTRAIT orientation (height > width)
    // This ensures both Android and iOS produce portrait-oriented frames,
    // preventing rotation issues when video goes through mediasoup SFU.
    try {
      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': isVideoCall
            ? {
                'facingMode': 'user',
                'width': {'ideal': 480, 'max': 720},
                'height': {'ideal': 640, 'max': 960},
                'frameRate': {'ideal': 15, 'max': 24},
              }
            : false,
      };

      CallLogger.info(_scope, 'getUserMedia:attempt1');
      return await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      CallLogger.warn(
          _scope, 'getUserMedia:attempt1:failed', {'error': e.toString()});
    }

    // Attempt 2: Simpler video constraints — still portrait
    if (isVideoCall) {
      try {
        CallLogger.info(_scope, 'getUserMedia:attempt2');
        return await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 480},
            'height': {'ideal': 640},
          },
        });
      } catch (e) {
        CallLogger.warn(
            _scope, 'getUserMedia:attempt2:failed', {'error': e.toString()});
      }
    }

    // Attempt 3: Audio only
    try {
      CallLogger.info(_scope, 'getUserMedia:attempt3:audio-only');
      return await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
    } catch (e) {
      CallLogger.error(
          _scope, 'getUserMedia:attempt3:failed', {'error': e.toString()});
      return null;
    }
  }

  /// Switch between front and back camera.
  Future<MediaStreamTrack?> switchCamera() async {
    CallLogger.info(_scope, 'switchCamera', {'currentFront': _isFrontCamera});

    final videoTracks = _localStream?.getVideoTracks();
    if (videoTracks == null || videoTracks.isEmpty) {
      CallLogger.warn(_scope, 'switchCamera:no-video-tracks');
      return null;
    }

    try {
      // On mobile, use Helper.switchCamera for efficient switching
      if (Platform.isAndroid || Platform.isIOS) {
        final result = await Helper.switchCamera(videoTracks.first);
        _isFrontCamera = !_isFrontCamera;
        CallLogger.info(_scope, 'switchCamera:success', {
          'isFrontCamera': _isFrontCamera,
          'result': result,
        });
        return videoTracks.first;
      }

      // Fallback: get new stream with opposite facing mode
      _isFrontCamera = !_isFrontCamera;
      final newStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': _isFrontCamera ? 'user' : 'environment',
        },
      });

      final newTrack = newStream.getVideoTracks().first;
      await _localStream!.removeTrack(videoTracks.first);
      await _localStream!.addTrack(newTrack);

      if (_localRenderer != null) {
        _localRenderer!.srcObject = _localStream;
      }

      CallLogger.info(_scope, 'switchCamera:success:fallback', {
        'isFrontCamera': _isFrontCamera,
      });
      return newTrack;
    } catch (e) {
      CallLogger.error(_scope, 'switchCamera:error', {'error': e.toString()});
      _isFrontCamera = !_isFrontCamera; // revert
      return null;
    }
  }

  /// Enable or disable the audio track.
  void setAudioEnabled(bool enabled) {
    final audioTracks = _localStream?.getAudioTracks();
    if (audioTracks != null) {
      for (final track in audioTracks) {
        track.enabled = enabled;
      }
    }
    CallLogger.info(_scope, 'setAudioEnabled', {'enabled': enabled});
  }

  /// Enable or disable the video track.
  void setVideoEnabled(bool enabled) {
    final videoTracks = _localStream?.getVideoTracks();
    if (videoTracks != null) {
      for (final track in videoTracks) {
        track.enabled = enabled;
      }
    }
    CallLogger.info(_scope, 'setVideoEnabled', {'enabled': enabled});
  }

  /// Get the first audio track.
  MediaStreamTrack? get audioTrack {
    final tracks = _localStream?.getAudioTracks();
    return (tracks != null && tracks.isNotEmpty) ? tracks.first : null;
  }

  /// Get the first video track.
  MediaStreamTrack? get videoTrack {
    final tracks = _localStream?.getVideoTracks();
    return (tracks != null && tracks.isNotEmpty) ? tracks.first : null;
  }

  /// Dispose all local media resources.
  Future<void> dispose() async {
    CallLogger.info(_scope, 'dispose:start');
    try {
      _localRenderer?.srcObject = null;
      await _localRenderer?.dispose();
    } catch (_) {}
    try {
      final tracks = _localStream?.getTracks();
      if (tracks != null) {
        for (final track in tracks) {
          track.stop();
        }
      }
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;
    _localRenderer = null;
    _isFrontCamera = true;
    CallLogger.info(_scope, 'dispose:done');
  }
}
