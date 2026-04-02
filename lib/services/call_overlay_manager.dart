import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:cu_app/Features/Group_Call_old/controller/group_call.dart';
import 'package:cu_app/Features/Group_Call_old/Presentation/video_call_screen.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/services/call_service.dart';

/// Manages a floating draggable mini-call widget (in-app PiP overlay).
///
/// This overlay sits above all Flutter routes, allowing the user to
/// chat or browse the app while a call continues in the background.
///
/// Usage:
///   CallOverlayManager().show(groupId: ..., groupName: ..., ...);
///   CallOverlayManager().remove();
///
/// Platform note:
///   This handles in-app PiP. Android system PiP (Home button)
///   is handled separately in MainActivity.kt / CallService.
///   On iOS, a similar overlay approach will work natively.
class CallOverlayManager {
  static final CallOverlayManager _instance = CallOverlayManager._internal();
  factory CallOverlayManager() => _instance;
  CallOverlayManager._internal();

  OverlayEntry? _overlayEntry;
  bool get isOverlayActive => _overlayEntry != null;

  /// Observable flag so other widgets can react to overlay state
  static final RxBool isFloating = false.obs;

  // Store call info for restoration
  String? _groupId;
  String? _groupName;
  String? _groupImage;
  bool? _isVideoCall;

  /// Show the floating call overlay above all routes
  void show({
    required String groupId,
    required String groupName,
    required String groupImage,
    required bool isVideoCall,
  }) {
    if (_overlayEntry != null) return; // Already showing

    _groupId = groupId;
    _groupName = groupName;
    _groupImage = groupImage;
    _isVideoCall = isVideoCall;

    final ctx = Get.overlayContext;
    if (ctx == null) return;

    _overlayEntry = OverlayEntry(
      builder: (_) => _FloatingCallWidget(
        groupId: groupId,
        groupName: groupName,
        isVideoCall: isVideoCall,
        onTap: () => restoreCall(),
        onEndCall: () => endCallFromOverlay(),
      ),
    );

    Overlay.of(ctx).insert(_overlayEntry!);
    isFloating.value = true;

    // Tell native side: do NOT enter system PiP while overlay is showing
    // (system PiP would shrink the chat screen, not the call)
    CallService.setOverlayActive(true);
  }

  /// Remove the overlay without ending the call
  void remove() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    isFloating.value = false;

    // Re-enable system PiP on native side
    CallService.setOverlayActive(false);
  }

  /// Tap on overlay → expand back to full call screen
  void restoreCall() {
    final gId = _groupId;
    final gName = _groupName ?? '';
    final gImage = _groupImage ?? '';
    final isVideo = _isVideoCall ?? true;

    remove();

    if (gId == null) return;

    try {
      final controller = Get.find<GroupcallController>();
      controller.isInOverlayMode.value = false;

      if (controller.localStream == null) {
        // Stream was lost — can't restore, end call
        endCallFromOverlay();
        return;
      }

      Get.to(() => GroupVideoCallScreen(
            groupId: gId,
            groupName: gName,
            groupImage: gImage,
            localStream: controller.localStream!,
            isVideoCall: isVideo,
          ));
    } catch (e) {
      debugPrint('CallOverlayManager.restoreCall error: $e');
    }
  }

  /// End call from the overlay X button
  void endCallFromOverlay() {
    final gId = _groupId;
    remove();

    if (gId == null) return;

    try {
      final controller = Get.find<GroupcallController>();
      controller.isInOverlayMode.value = false;
      controller.leaveCall(
        roomId: gId,
        userId: LocalStorage().getUserId(),
      );
    } catch (e) {
      debugPrint('CallOverlayManager.endCallFromOverlay error: $e');
    }
  }
}

/// The actual floating mini-call widget that hovers above all screens.
class _FloatingCallWidget extends StatefulWidget {
  final String groupId;
  final String groupName;
  final bool isVideoCall;
  final VoidCallback onTap;
  final VoidCallback onEndCall;

  const _FloatingCallWidget({
    required this.groupId,
    required this.groupName,
    required this.isVideoCall,
    required this.onTap,
    required this.onEndCall,
  });

  @override
  State<_FloatingCallWidget> createState() => _FloatingCallWidgetState();
}

class _FloatingCallWidgetState extends State<_FloatingCallWidget> {
  double _xPos = 20;
  double _yPos = 100;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // When Android system PiP is active the entire Flutter surface shrinks
    // to ~100-200 px.  The floating overlay makes no sense there and the
    // clamp math would crash (min > max).  Hide it.
    if (screenWidth < 200 || screenHeight < 300) {
      return const SizedBox.shrink();
    }

    // Ensure clamp upper-bound is never negative (safety net)
    final maxX = math.max(0.0, screenWidth - 130);
    final maxY = math.max(0.0, screenHeight - 200);
    _xPos = _xPos.clamp(0.0, maxX);
    _yPos = _yPos.clamp(0.0, maxY);

    return Positioned(
      left: _xPos,
      top: _yPos,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _xPos += details.delta.dx;
            _yPos += details.delta.dy;
            final sw = MediaQuery.of(context).size.width;
            final sh = MediaQuery.of(context).size.height;
            _xPos = _xPos.clamp(0.0, math.max(0.0, sw - 130));
            _yPos = _yPos.clamp(0.0, math.max(0.0, sh - 200));
          });
        },
        onTap: widget.onTap,
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 120,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // Video or placeholder
                  Positioned.fill(child: _buildVideoContent()),

                  // End call button (top right)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: widget.onEndCall,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),

                  // "Tap to expand" hint + group name (bottom)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'Tap to expand',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    try {
      final controller = Get.find<GroupcallController>();

      if (widget.isVideoCall || controller.isScreenSharing.value) {
        // Always show remote video in floating overlay, even when screen
        // sharing. The user wants to see the other person in the overlay.
        if (controller.remoteRenderers.isNotEmpty) {
          final firstRemoteRenderer = controller.remoteRenderers.values.first;
          return RTCVideoView(
            firstRemoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          );
        } else {
          return RTCVideoView(
            controller.localRenderer,
            mirror: true,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          );
        }
      }
    } catch (e) {
      debugPrint('_FloatingCallWidget._buildVideoContent error: $e');
    }

    // Audio call or error fallback
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call, color: Colors.green, size: 30),
            SizedBox(height: 4),
            Text(
              'Call Active',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
