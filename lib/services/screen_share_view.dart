import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// A widget that renders an incoming screen share track correctly:
/// - No mirroring
/// - No stretching or cropping
/// - Correct aspect ratio (ObjectFit.contain)
/// - Displays exactly what the sender sees
///
/// Usage:
///   ScreenShareView(renderer: remoteRenderers[userId]!)
class ScreenShareView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final String? label;

  const ScreenShareView({
    super.key,
    required this.renderer,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              mirror: false, // NEVER mirror screen share
              filterQuality: FilterQuality.medium,
            ),
          ),
          if (label != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.screen_share,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A widget that renders the LOCAL screen share preview (what the sharer sees).
/// Same rules: no mirror, contain fit, correct aspect ratio.
class ScreenSharePreview extends StatelessWidget {
  final RTCVideoRenderer renderer;

  const ScreenSharePreview({
    super.key,
    required this.renderer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.blueAccent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            Positioned.fill(
              child: RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                mirror: false, // Screen share is NEVER mirrored
                filterQuality: FilterQuality.medium,
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.screen_share, color: Colors.white, size: 10),
                    SizedBox(width: 4),
                    Text(
                      'You are sharing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
