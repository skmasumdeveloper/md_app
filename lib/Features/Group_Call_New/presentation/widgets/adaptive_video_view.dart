import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Video view wrapper that uses RTCVideoViewObjectFitCover for proper display.
/// With portrait camera constraints (height > width), no rotation transform
/// is needed — the frames are already portrait-oriented from the source.
class AdaptiveVideoView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool mirror;
  final bool isLocal;

  const AdaptiveVideoView({
    super.key,
    required this.renderer,
    this.mirror = false,
    this.isLocal = false,
  });

  @override
  Widget build(BuildContext context) {
    return RTCVideoView(
      renderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      mirror: mirror,
      filterQuality: FilterQuality.medium,
    );
  }
}
