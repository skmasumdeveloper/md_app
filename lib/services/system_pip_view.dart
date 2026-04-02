import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:cu_app/Features/Group_Call_Embeded/controller/group_call_embeded_controller.dart';
import 'package:cu_app/Features/Group_Call_New/controller/group_call_new_controller.dart';
import 'package:cu_app/Features/Group_Call_old/controller/group_call.dart';
import 'package:cu_app/Features/GuestCall/controller/guest_call_controller.dart';
import 'package:cu_app/services/call_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A full-screen overlay that renders the video call content when Android
/// system PiP is active.
///
/// Wrap this around your [GetMaterialApp] (via the builder) so that no
/// matter which Flutter route is visible, the PiP window always shows
/// the ongoing video call instead of chat or other screens.
///
/// When PiP is exited (user taps to expand), this widget becomes invisible
/// and the underlying route is shown normally.
class SystemPipOverlay extends StatelessWidget {
  final Widget child;

  const SystemPipOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Normal app content (always in the tree to preserve state)
        child,

        // When system PiP is active, cover everything with video content
        Obx(() {
          if (!CallService.isSystemPipActive.value) {
            return const SizedBox.shrink();
          }
          return Positioned.fill(
            child: _PipVideoContent(),
          );
        }),
      ],
    );
  }
}

/// Minimal video view shown inside the Android system PiP window.
class _PipVideoContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    try {
      final groupController = Get.isRegistered<GroupcallController>()
          ? Get.find<GroupcallController>()
          : null;
      if (groupController != null && groupController.isCallActive.value) {
        debugPrint("[PipFeature] Rendering Group Call PiP");
        return _buildGroupPip(groupController);
      }

      final guestController = GuestCallController.activeInstance ??
          (Get.isRegistered<GuestCallController>()
              ? Get.find<GuestCallController>()
              : null);
      if (guestController != null && guestController.isCallActive.value) {
        debugPrint("[PipFeature] Rendering Guest Call PiP");
        return _buildGuestPip(guestController);
      }

      final embeddedController = Get.isRegistered<GroupCallEmbededController>()
          ? Get.find<GroupCallEmbededController>()
          : null;
      if (embeddedController != null && embeddedController.isCallActive.value) {
        unawaited(embeddedController.setCompactMode(true));

        return _buildEmbeddedPipSurface(embeddedController);
      }

      // New native group call PiP
      final newCallController = Get.isRegistered<GroupCallNewController>()
          ? Get.find<GroupCallNewController>()
          : null;
      if (newCallController != null && newCallController.isCallActive.value) {
        debugPrint("[PipFeature] Rendering New Group Call PiP");
        return _buildNewCallPip(newCallController);
      }

      debugPrint("[PipFeature] No active call found for PiP");
      return _callEndedView();
    } catch (e) {
      debugPrint("[PipFeature] Error rendering PiP: $e");
      return _callEndedView();
    }
  }

  Widget _buildGroupPip(GroupcallController controller) {
    // Always show the remote peer's video in PiP, even when screen sharing.
    // When the user is sharing their screen, they want to see the other
    // person, not a tiny preview of their own shared screen.
    if (controller.remoteRenderers.isNotEmpty) {
      final firstRemote = controller.remoteRenderers.values.first;
      return Container(
        color: Colors.black,
        child: RTCVideoView(
          firstRemote,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    if (controller.localStream != null) {
      return Container(
        color: Colors.black,
        child: RTCVideoView(
          controller.localRenderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    return _audioCallView();
  }

  Widget _buildGuestPip(GuestCallController controller) {
    // Always show the remote peer's video in PiP, even when screen sharing.
    if (controller.remoteRenderers.isNotEmpty) {
      final firstRemote = controller.remoteRenderers.values.first;
      return Container(
        color: Colors.black,
        child: RTCVideoView(
          firstRemote,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    if (controller.localStream != null) {
      return Container(
        color: Colors.black,
        child: RTCVideoView(
          controller.localRenderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    return _audioCallView();
  }

  Widget _audioCallView() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.call, color: Colors.green, size: 48),
      ),
    );
  }

  Widget _buildEmbeddedPipSurface(GroupCallEmbededController controller) {
    final webController = controller.webViewController;
    if (webController != null) {
      return Container(
        color: Colors.black,
        child: WebViewWidget(controller: webController),
      );
    }

    return _audioCallView();
  }

  Widget _buildNewCallPip(GroupCallNewController controller) {
    // Show first remote participant's video, or local video fallback
    final remoteWithVideo = controller.participants.values
        .where((p) => !p.isLocal && p.hasActiveVideo && p.renderer != null)
        .toList();

    if (remoteWithVideo.isNotEmpty) {
      return Container(
        color: Colors.black,
        child: RTCVideoView(
          remoteWithVideo.first.renderer!,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    final local = controller.localParticipant;
    if (local != null && local.hasActiveVideo && local.renderer != null) {
      return Container(
        color: Colors.black,
        child: RTCVideoView(
          local.renderer!,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    return _audioCallView();
  }

  Widget _callEndedView() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.call_end, color: Colors.red, size: 48),
      ),
    );
  }
}
