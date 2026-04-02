part of 'group_call.dart';

extension GroupCallMediaExtension on GroupcallController {
  // This method to get user media for the call.
  Future<MediaStream?> _getUserMedia({bool isVideoCall = true}) async {
    debugPrint(
        '[Media] _getUserMedia: isVideoCall=$isVideoCall');
    try {
      MediaStream? stream;

      try {
        Map<String, dynamic> constraints;
        if (isVideoCall) {
          constraints = {
            'audio': {
              'echoCancellation': true,
              'noiseSuppression': true,
              'autoGainControl': true,
            },
            'video': {
              'facingMode': 'user',
              'width': {'ideal': 320, 'max': 480},
              'height': {'ideal': 240, 'max': 360},
              'frameRate': {'ideal': 15, 'max': 20},
            }
          };
        } else {
          constraints = {
            'audio': {
              'echoCancellation': true,
              'noiseSuppression': true,
              'autoGainControl': true,
            },
            'video': false,
          };
        }
        debugPrint(
            '[Media] _getUserMedia: requesting with constraints video=${isVideoCall ? "ON" : "OFF"}');
        stream = await navigator.mediaDevices.getUserMedia(constraints);
        debugPrint(
            '[Media] _getUserMedia: ✓ got stream — audioTracks=${stream.getAudioTracks().length} videoTracks=${stream.getVideoTracks().length}');
      } catch (e) {
        debugPrint(
            '[Media] _getUserMedia: primary request failed ($e), trying audio-only fallback');
        try {
          stream = await navigator.mediaDevices.getUserMedia({
            'audio': {
              'echoCancellation': true,
              'noiseSuppression': true,
              'autoGainControl': true,
            },
            'video': false,
          });
          debugPrint(
              '[Media] _getUserMedia: ✓ fallback got audio-only stream');
        } catch (e2) {
          debugPrint(
              '[Media] _getUserMedia: ✗ fallback ALSO failed: $e2');
          rethrow;
        }
      }

      localStream = stream;
      localRenderer.srcObject = stream;

      isCameraEnabled.value = stream.getVideoTracks().isNotEmpty &&
          stream.getVideoTracks().first.enabled;
      isMicEnabled.value = stream.getAudioTracks().isNotEmpty &&
          stream.getAudioTracks().first.enabled;
      userAudioEnabled['local'] = isMicEnabled.value;

      debugPrint(
          '[Media] _getUserMedia: camera=${isCameraEnabled.value} mic=${isMicEnabled.value}');
      return stream;
    } catch (e) {
      debugPrint('[Media] _getUserMedia: EXCEPTION: $e');
      Get.snackbar(
        "Media Access Denied",
        "Could not access camera or microphone. Please check your permissions.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }

  // This method toggles the microphone state.
  void toggleMic() {
    debugPrint('[Media] toggleMic: current=${isMicEnabled.value}');
    if (localStream != null) {
      final audioTracks = localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = !track.enabled;
      }
      isMicEnabled.value = audioTracks.isNotEmpty && audioTracks[0].enabled;
      userAudioEnabled['local'] = isMicEnabled.value;
      userAudioEnabled.refresh();

      debugPrint('[Media] toggleMic: new state=${isMicEnabled.value}');

      // Also pause/resume MediaSoup audio producer
      if (_audioProducer != null) {
        try {
          if (isMicEnabled.value) {
            _audioProducer!.resume();
            debugPrint('[Media] toggleMic: audio producer resumed');
          } else {
            _audioProducer!.pause();
            debugPrint('[Media] toggleMic: audio producer paused');
          }
        } catch (e) {
          debugPrint('[Media] toggleMic: producer error: $e');
        }
      } else {
        debugPrint('[Media] toggleMic: no audio producer to pause/resume');
      }

      if (currentRoomId.value.isNotEmpty) {
        debugPrint('[Media] toggleMic: emitting BE-toggle-camera-audio');
        socket?.emit('BE-toggle-camera-audio',
            {'roomId': currentRoomId.value, 'switchTarget': 'audio'});
      }
    } else {
      debugPrint('[Media] toggleMic: no local stream');
    }
  }

  // This method toggles the camera state.
  void toggleCamera() {
    if (isScreenSharing.value) {
      debugPrint('[Media] toggleCamera: blocked — screen sharing active');
      return;
    }
    debugPrint('[Media] toggleCamera: current=${isCameraEnabled.value}');
    if (localStream != null) {
      final videoTracks = localStream!.getVideoTracks();
      for (var track in videoTracks) {
        track.enabled = !track.enabled;
      }
      isCameraEnabled.value = videoTracks.isNotEmpty && videoTracks[0].enabled;

      debugPrint('[Media] toggleCamera: new state=${isCameraEnabled.value}');

      // Also pause/resume MediaSoup video producer
      if (_videoProducer != null) {
        try {
          if (isCameraEnabled.value) {
            _videoProducer!.resume();
            debugPrint('[Media] toggleCamera: video producer resumed');
          } else {
            _videoProducer!.pause();
            debugPrint('[Media] toggleCamera: video producer paused');
          }
        } catch (e) {
          debugPrint('[Media] toggleCamera: producer error: $e');
        }
      } else {
        debugPrint('[Media] toggleCamera: no video producer to pause/resume');
      }

      if (currentRoomId.value.isNotEmpty) {
        debugPrint('[Media] toggleCamera: emitting BE-toggle-camera-audio');
        socket?.emit('BE-toggle-camera-audio',
            {'roomId': currentRoomId.value, 'switchTarget': 'video'});
      }
    } else {
      debugPrint('[Media] toggleCamera: no local stream');
    }
  }

  // This method switches the camera if available.
  Future<void> switchCamera() async {
    if (isScreenSharing.value) {
      debugPrint('[Media] switchCamera: blocked — screen sharing active');
      return;
    }
    debugPrint('[Media] switchCamera: switching...');
    if (localStream != null) {
      final videoTracks = localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final videoTrack = videoTracks.firstWhere(
          (track) => track.kind == 'video',
          orElse: () => videoTracks.first,
        );
        try {
          await Helper.switchCamera(videoTrack);
          debugPrint('[Media] switchCamera: ✓ camera switched');
        } catch (e) {
          debugPrint('[Media] switchCamera: FAILED: $e');
        }
      } else {
        debugPrint('[Media] switchCamera: no video tracks');
      }
    } else {
      debugPrint('[Media] switchCamera: no local stream');
    }
  }
}
