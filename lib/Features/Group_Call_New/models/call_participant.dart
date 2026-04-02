import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';

/// Represents a single participant in a group call.
class CallParticipant {
  final String oderId;
  final String odisplayName;
  String socketId;
  bool audioEnabled;
  bool videoEnabled;
  bool isLocal;

  /// WebRTC renderer for displaying the participant's video.
  RTCVideoRenderer? renderer;

  /// Mediasoup consumers for this participant's audio/video.
  Consumer? audioConsumer;
  Consumer? videoConsumer;

  /// The combined media stream holding consumed tracks.
  MediaStream? stream;

  /// Whether this participant's video is currently rendering frames.
  bool isVideoRendering;

  /// Whether this participant is in a reconnecting/recovering state.
  bool isReconnecting;

  /// Timestamp of when this participant joined.
  final DateTime joinedAt;

  CallParticipant({
    required String userId,
    required String displayName,
    this.socketId = '',
    this.audioEnabled = true,
    this.videoEnabled = true,
    this.isLocal = false,
    this.renderer,
    this.audioConsumer,
    this.videoConsumer,
    this.stream,
    this.isVideoRendering = false,
    this.isReconnecting = false,
    DateTime? joinedAt,
  })  : oderId = userId,
        odisplayName = displayName,
        joinedAt = joinedAt ?? DateTime.now();

  String get odisplay =>
      odisplayName.isNotEmpty ? odisplayName : 'User ${oderId.substring(0, 4)}';

  String get userId => oderId;
  String get displayName => odisplay;

  /// Get initials for avatar fallback.
  String get initials {
    final parts = odisplayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Whether this participant has an active video stream to display.
  bool get hasActiveVideo {
    if (!videoEnabled || renderer == null || isReconnecting) return false;
    if (stream == null) return false;
    // Verify the stream actually has a live video track
    final videoTracks = stream!.getVideoTracks();
    return videoTracks.isNotEmpty && videoTracks.first.enabled != false;
  }

  /// Dispose renderer and close consumers.
  /// Note: stream is owned by the consumer, don't dispose it separately.
  Future<void> dispose() async {
    try {
      renderer?.srcObject = null;
    } catch (_) {}
    try {
      audioConsumer?.close();
    } catch (_) {}
    try {
      videoConsumer?.close();
    } catch (_) {}
    try {
      await renderer?.dispose();
    } catch (_) {}
    renderer = null;
    audioConsumer = null;
    videoConsumer = null;
    stream = null;
  }
}
