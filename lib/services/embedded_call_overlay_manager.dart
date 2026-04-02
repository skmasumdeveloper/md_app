import 'dart:async';
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

  void _log(String stage, [Map<String, dynamic>? details]) {
    if (details == null || details.isEmpty) {
      debugPrint('[EmbeddedCall][Overlay][$stage]');
      return;
    }
    debugPrint('[EmbeddedCall][Overlay][$stage] $details');
  }

  void show({
    required String roomId,
    required String groupName,
    required bool isVideoCall,
    required bool isMeeting,
  }) {
    _log('show:start', {
      'roomId': roomId,
      'groupName': groupName,
      'isVideoCall': isVideoCall,
      'isMeeting': isMeeting,
      'alreadyActive': _overlayEntry != null,
    });

    if (_overlayEntry != null) {
      return;
    }

    _roomId = roomId;
    _groupName = groupName;
    _isVideoCall = isVideoCall;
    _isMeeting = isMeeting;

    final context = Get.overlayContext;
    if (context == null) {
      _log('show:skip', {'reason': 'no-overlay-context'});
      return;
    }

    WebViewController? webController;
    try {
      final controller = Get.find<GroupCallEmbededController>();
      webController = controller.webViewController;
      unawaited(controller.setCompactMode(true, force: true));
    } catch (_) {}

    _overlayEntry = OverlayEntry(
      builder: (_) => _EmbeddedFloatingCallWidget(
        roomId: roomId,
        groupName: groupName,
        isVideoCall: isVideoCall,
        isMeeting: isMeeting,
        webController: webController,
        onTap: restoreCall,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    isFloating.value = true;
    _log('show:inserted');

    CallService.setOverlayActive(true);
  }

  void remove() {
    _log('remove:start', {
      'isOverlayActive': _overlayEntry != null,
    });
    _overlayEntry?.remove();
    _overlayEntry = null;
    isFloating.value = false;

    try {
      final controller = Get.find<GroupCallEmbededController>();
      unawaited(controller.syncEmbeddedViewMode(force: true));
    } catch (_) {}

    CallService.setOverlayActive(false);
    _log('remove:end');
  }

  void restoreCall() {
    _log('restoreCall:start', {
      'roomId': _roomId,
      'groupName': _groupName,
    });

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
      unawaited(controller.setCompactMode(false, force: true));

      if (Get.currentRoute.contains('GroupCallEmbededScreen')) {
        return;
      }

      Get.to(() => GroupCallEmbededScreen(
            roomId: roomId,
            groupName: groupName,
            isVideoCall: isVideoCall,
            isMeeting: isMeeting,
          ));
      _log('restoreCall:navigate', {'roomId': roomId});
    } catch (_) {}
  }

  void endCallFromOverlay() {
    _log('endCallFromOverlay:start', {'roomId': _roomId});
    final roomId = _roomId;
    remove();

    if (roomId == null || roomId.isEmpty) {
      return;
    }

    try {
      final controller = Get.find<GroupCallEmbededController>();
      controller.isInOverlayMode.value = false;
      unawaited(controller.setCompactMode(false, force: true));
      controller.leaveCall(
        roomId: roomId,
        userId: LocalStorage().getUserId(),
      );
      _log('endCallFromOverlay:leaveCall', {'roomId': roomId});
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

  const _EmbeddedFloatingCallWidget({
    required this.roomId,
    required this.groupName,
    required this.isVideoCall,
    required this.isMeeting,
    required this.webController,
    required this.onTap,
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
    final overlayWidth = (screenWidth * 0.36).clamp(120.0, 180.0);
    final overlayHeight = (overlayWidth * 1.6).clamp(192.0, 288.0);

    if (screenWidth < 200 || screenHeight < 300) {
      return const SizedBox.shrink();
    }

    final maxX = math.max(0.0, screenWidth - overlayWidth - 8);
    final maxY = math.max(0.0, screenHeight - overlayHeight - 8);
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: overlayWidth,
            height: overlayHeight,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(10),
              child: _buildPreview(),
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
