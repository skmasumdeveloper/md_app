import 'dart:math' as math;

import 'package:cu_app/Features/Group_Call_Embeded/controller/group_call_embeded_controller.dart';
import 'package:cu_app/Features/Group_Call_Embeded/presentation/group_call_embeded_screen.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EmbeddedCallOverlayManager {
  static final EmbeddedCallOverlayManager _instance =
      EmbeddedCallOverlayManager._internal();

  factory EmbeddedCallOverlayManager() => _instance;

  EmbeddedCallOverlayManager._internal();

  OverlayEntry? _overlayEntry;

  static final RxBool isFloating = false.obs;

  String? _roomId;
  String? _groupName;
  bool? _isVideoCall;
  bool? _isMeeting;

  bool get isOverlayActive => _overlayEntry != null;

  void show({
    required String roomId,
    required String groupName,
    required bool isVideoCall,
    required bool isMeeting,
  }) {
    if (_overlayEntry != null) {
      return;
    }

    _roomId = roomId;
    _groupName = groupName;
    _isVideoCall = isVideoCall;
    _isMeeting = isMeeting;

    final context = Get.overlayContext;
    if (context == null) {
      return;
    }

    WebViewController? webController;
    try {
      webController = Get.find<GroupCallEmbededController>().webViewController;
    } catch (_) {}

    _overlayEntry = OverlayEntry(
      builder: (_) => _EmbeddedFloatingCallWidget(
        roomId: roomId,
        groupName: groupName,
        isVideoCall: isVideoCall,
        isMeeting: isMeeting,
        webController: webController,
        onTap: restoreCall,
        onEndCall: endCallFromOverlay,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    isFloating.value = true;

    CallService.setOverlayActive(true);
  }

  void remove() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    isFloating.value = false;

    CallService.setOverlayActive(false);
  }

  void restoreCall() {
    final roomId = _roomId;
    if (roomId == null || roomId.isEmpty) {
      remove();
      return;
    }

    final groupName =
        (_groupName ?? '').isNotEmpty ? _groupName! : 'Group Call';
    final isVideoCall = _isVideoCall ?? true;
    final isMeeting = _isMeeting ?? false;

    remove();

    try {
      final controller = Get.find<GroupCallEmbededController>();
      controller.isInOverlayMode.value = false;

      if (Get.currentRoute.contains('GroupCallEmbededScreen')) {
        return;
      }

      Get.to(() => GroupCallEmbededScreen(
            roomId: roomId,
            groupName: groupName,
            isVideoCall: isVideoCall,
            isMeeting: isMeeting,
          ));
    } catch (_) {}
  }

  void endCallFromOverlay() {
    final roomId = _roomId;
    remove();

    if (roomId == null || roomId.isEmpty) {
      return;
    }

    try {
      final controller = Get.find<GroupCallEmbededController>();
      controller.isInOverlayMode.value = false;
      controller.leaveCall(
        roomId: roomId,
        userId: LocalStorage().getUserId(),
      );
    } catch (_) {}
  }
}

class _EmbeddedFloatingCallWidget extends StatefulWidget {
  final String roomId;
  final String groupName;
  final bool isVideoCall;
  final bool isMeeting;
  final WebViewController? webController;
  final VoidCallback onTap;
  final VoidCallback onEndCall;

  const _EmbeddedFloatingCallWidget({
    required this.roomId,
    required this.groupName,
    required this.isVideoCall,
    required this.isMeeting,
    required this.webController,
    required this.onTap,
    required this.onEndCall,
  });

  @override
  State<_EmbeddedFloatingCallWidget> createState() =>
      _EmbeddedFloatingCallWidgetState();
}

class _EmbeddedFloatingCallWidgetState
    extends State<_EmbeddedFloatingCallWidget> {
  double _x = 20;
  double _y = 120;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (screenWidth < 200 || screenHeight < 300) {
      return const SizedBox.shrink();
    }

    final maxX = math.max(0.0, screenWidth - 170);
    final maxY = math.max(0.0, screenHeight - 250);
    _x = _x.clamp(0.0, maxX);
    _y = _y.clamp(0.0, maxY);

    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _x = (_x + details.delta.dx).clamp(0.0, maxX);
            _y = (_y + details.delta.dy).clamp(0.0, maxY);
          });
        },
        onTap: widget.onTap,
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 160,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF0EA5E9),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(child: _buildPreview()),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: widget.onEndCall,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.isMeeting
                                ? '${widget.groupName} (Meeting)'
                                : widget.groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          const Text(
                            'Tap to expand',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
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

  Widget _buildPreview() {
    if (widget.webController != null) {
      return IgnorePointer(
        child: WebViewWidget(controller: widget.webController!),
      );
    }

    return Container(
      color: const Color(0xFF020617),
      child: Center(
        child: Icon(
          widget.isVideoCall ? Icons.videocam : Icons.call,
          size: 42,
          color: Colors.white,
        ),
      ),
    );
  }
}
