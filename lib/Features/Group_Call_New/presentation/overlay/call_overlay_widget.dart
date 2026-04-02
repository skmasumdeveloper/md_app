import 'dart:async';
import 'package:cu_app/Features/Group_Call_New/controller/call_logger.dart';
import 'package:cu_app/Features/Group_Call_New/controller/group_call_new_controller.dart';
import 'package:cu_app/Features/Group_Call_New/presentation/group_call_new_screen.dart';
import 'package:cu_app/services/call_service.dart';
import 'package:cu_app/Features/Group_Call_New/presentation/widgets/adaptive_video_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Singleton manager for the floating in-app PIP overlay.
class NewCallOverlayManager {
  static final NewCallOverlayManager _instance =
      NewCallOverlayManager._internal();
  factory NewCallOverlayManager() => _instance;
  NewCallOverlayManager._internal();

  OverlayEntry? _overlayEntry;
  String _roomId = '';
  String _groupName = '';
  bool _isVideoCall = true;
  bool _isMeeting = false;

  bool get isShowing => _overlayEntry != null;

  /// Show the floating call overlay.
  void show({
    required String roomId,
    required String groupName,
    required bool isVideoCall,
    bool isMeeting = false,
  }) {
    CallLogger.info('Overlay', 'show', {'roomId': roomId});

    _roomId = roomId;
    _groupName = groupName;
    _isVideoCall = isVideoCall;
    _isMeeting = isMeeting;

    remove();

    final overlay = _getOverlay();
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (_) => _FloatingCallWidget(
        onTap: restoreCall,
        onEndCall: endCallFromOverlay,
      ),
    );
    overlay.insert(_overlayEntry!);
    unawaited(CallService.setOverlayActive(true));
  }

  /// Remove the floating overlay.
  void remove() {
    if (_overlayEntry != null) {
      CallLogger.info('Overlay', 'remove');
      _overlayEntry!.remove();
      _overlayEntry = null;
      unawaited(CallService.setOverlayActive(false));
    }
  }

  /// Restore the full call screen from the overlay.
  void restoreCall() {
    CallLogger.info('Overlay', 'restoreCall');

    if (!Get.isRegistered<GroupCallNewController>()) return;
    final controller = Get.find<GroupCallNewController>();
    controller.isInOverlayMode.value = false;

    remove();

    Get.to(() => GroupCallNewScreen(
          roomId: _roomId,
          groupName: _groupName,
          isVideoCall: _isVideoCall,
          isMeeting: _isMeeting,
        ));
  }

  /// End the call from the overlay.
  void endCallFromOverlay() {
    CallLogger.info('Overlay', 'endCallFromOverlay');

    if (!Get.isRegistered<GroupCallNewController>()) return;
    final controller = Get.find<GroupCallNewController>();
    remove();
    controller.leaveCall();
  }

  OverlayState? _getOverlay() {
    try {
      return Overlay.of(Get.overlayContext!);
    } catch (_) {
      return null;
    }
  }
}

/// The draggable floating call widget shown as in-app PIP.
class _FloatingCallWidget extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onEndCall;

  const _FloatingCallWidget({
    required this.onTap,
    required this.onEndCall,
  });

  @override
  State<_FloatingCallWidget> createState() => _FloatingCallWidgetState();
}

class _FloatingCallWidgetState extends State<_FloatingCallWidget> {
  double _x = 20;
  double _y = 100;
  static const double _width = 130;
  static const double _height = 185;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (details) {
          setState(() {
            _x = (_x + details.delta.dx).clamp(0, screenSize.width - _width);
            _y = (_y + details.delta.dy)
                .clamp(0, screenSize.height - _height - 50);
          });
        },
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(14),
          color: Colors.transparent,
          child: Container(
            width: _width,
            height: _height,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF0EA5E9),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Show local video or call icon
                  _PipContent(),

                  // End call button
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: widget.onEndCall,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
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

                  // Expand icon
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.open_in_full,
                        color: Colors.white70,
                        size: 12,
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
}

/// Content shown inside the PIP widget.
class _PipContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<GroupCallNewController>()) {
      return _callIcon();
    }

    final controller = Get.find<GroupCallNewController>();

    return Obx(() {
      // Try to show first remote participant's video
      final remoteParticipants = controller.participants.values
          .where((p) => !p.isLocal && p.hasActiveVideo)
          .toList();

      if (remoteParticipants.isNotEmpty) {
        final remote = remoteParticipants.first;
        if (remote.renderer != null) {
          return AdaptiveVideoView(
            renderer: remote.renderer!,
            isLocal: false,
          );
        }
      }

      // Fall back to local video
      final local = controller.localParticipant;
      if (local != null && local.hasActiveVideo && local.renderer != null) {
        return AdaptiveVideoView(
          renderer: local.renderer!,
          mirror: true,
          isLocal: true,
        );
      }

      return _callIcon();
    });
  }

  Widget _callIcon() {
    return Container(
      color: const Color(0xFF1E293B),
      child: const Center(
        child: Icon(
          Icons.phone_in_talk,
          color: Colors.white54,
          size: 32,
        ),
      ),
    );
  }
}
