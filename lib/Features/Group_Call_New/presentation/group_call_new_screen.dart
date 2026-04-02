import 'dart:async';
import 'dart:io';

import 'package:cu_app/Features/Chat/Presentation/chat_screen.dart';
import 'package:cu_app/Features/Group_Call_New/controller/call_logger.dart';
import 'package:cu_app/Features/Group_Call_New/controller/group_call_new_controller.dart';
import 'package:cu_app/Features/Group_Call_New/models/call_state.dart';
import 'package:cu_app/Features/Group_Call_New/presentation/overlay/call_overlay_widget.dart';
import 'package:cu_app/Features/Group_Call_New/presentation/widgets/call_controls_bar.dart';
import 'package:cu_app/Features/Group_Call_New/presentation/widgets/call_grid_view.dart';
import 'package:cu_app/Features/Group_Call_New/presentation/widgets/call_top_bar.dart';
import 'package:cu_app/Commons/app_strings.dart';
import 'package:cu_app/Features/Login/Controller/login_controller.dart';
import 'package:cu_app/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GroupCallNewScreen extends StatefulWidget {
  final String roomId;
  final String groupName;
  final bool isVideoCall;
  final bool isMeeting;

  const GroupCallNewScreen({
    super.key,
    required this.roomId,
    required this.groupName,
    required this.isVideoCall,
    this.isMeeting = false,
  });

  @override
  State<GroupCallNewScreen> createState() => _GroupCallNewScreenState();
}

class _GroupCallNewScreenState extends State<GroupCallNewScreen>
    with WidgetsBindingObserver {
  late final GroupCallNewController _controller;
  bool _isMovingToOverlay = false;
  bool _hasExited = false;
  bool _canRecord = false;
  Worker? _callActiveWorker;
  Worker? _callStateWorker;

  @override
  void initState() {
    super.initState();
    CallLogger.info('Screen', 'initState', {
      'roomId': widget.roomId,
      'groupName': widget.groupName,
      'isVideoCall': widget.isVideoCall,
    });

    _controller = Get.find<GroupCallNewController>();
    _controller.isInOverlayMode.value = false;
    WidgetsBinding.instance.addObserver(this);

    // Check if current user can record (SuperAdmin or admin)
    try {
      final loginCtrl = Get.find<LoginController>();
      final userType = loginCtrl.userModel.value.userType ?? '';
      _canRecord =
          userType == AdminCheck.superAdmin || userType == AdminCheck.admin;
    } catch (_) {
      _canRecord = false;
    }

    // Watch isCallActive — when call ends, exit screen immediately
    _callActiveWorker = ever<bool>(_controller.isCallActive, (isActive) {
      if (!isActive && !_isMovingToOverlay) {
        _exitScreen();
      }
    });

    // Watch callState — if it becomes error/left, exit screen
    _callStateWorker = ever<GroupCallState>(_controller.callState, (state) {
      if ((state == GroupCallState.left || state == GroupCallState.error) &&
          !_controller.isCallActive.value &&
          !_isMovingToOverlay) {
        _exitScreen();
      }
    });

    CallService.init();
    unawaited(CallService.startService());
    CallService.onEndCallRequested = () {
      _controller.leaveCall();
    };
  }

  /// Reliably exit the call screen using multiple strategies.
  void _exitScreen() {
    if (_hasExited) return;
    _hasExited = true;
    CallLogger.info('Screen', 'exitScreen');

    // Remove in-app PIP overlay
    try {
      NewCallOverlayManager().remove();
    } catch (_) {}

    // Use addPostFrameCallback to ensure we're not in a build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Strategy 1: Navigator.pop
      try {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          CallLogger.info('Screen', 'exitScreen:popped');
          return;
        }
      } catch (_) {}

      // Strategy 2: Get.back
      try {
        if (Get.currentRoute.contains('GroupCallNewScreen')) {
          Get.back();
          CallLogger.info('Screen', 'exitScreen:getBack');
          return;
        }
      } catch (_) {}

      // Strategy 3: Replace with chat screen
      try {
        Get.off(() => ChatScreen(groupId: widget.roomId));
        CallLogger.info('Screen', 'exitScreen:replaced');
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    CallLogger.info('Screen', 'lifecycle', {
      'state': state.name,
      'platform': Platform.isIOS ? 'iOS' : 'Android',
    });

    if (_controller.isInOverlayMode.value) return;

    // When returning from background, check if call was ended
    if (state == AppLifecycleState.resumed) {
      if (!_controller.isCallActive.value && !_isMovingToOverlay) {
        _exitScreen();
        return;
      }
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (Platform.isIOS) {
        // iOS: no system PIP — leave and end call when app goes to background
        CallLogger.info('Screen', 'iOS:appBackground:endCall');
        _controller.leaveCall();
      } else {
        // Android: use system PIP
        unawaited(CallService.enterSystemPip());
      }
    }
  }

  Future<void> _enterInAppOverlay() async {
    if (_controller.isInOverlayMode.value) return;

    CallLogger.info('Screen', '_enterInAppOverlay');
    _controller.isInOverlayMode.value = true;

    if (mounted) {
      setState(() => _isMovingToOverlay = true);
    }

    await Future.delayed(const Duration(milliseconds: 20));

    NewCallOverlayManager().show(
      roomId: widget.roomId,
      groupName: widget.groupName.isNotEmpty ? widget.groupName : 'Group Call',
      isVideoCall: widget.isVideoCall,
      isMeeting: widget.isMeeting,
    );

    if (!mounted) return;

    if (!Get.currentRoute.contains('ChatScreen')) {
      Get.off(() => ChatScreen(
            groupId: widget.roomId,
            isCallFloating: 1,
          ));
    }
  }

  @override
  void dispose() {
    CallLogger.info('Screen', 'dispose', {
      'isInOverlayMode': _controller.isInOverlayMode.value,
    });

    _callActiveWorker?.dispose();
    _callActiveWorker = null;
    _callStateWorker?.dispose();
    _callStateWorker = null;
    WidgetsBinding.instance.removeObserver(this);

    if (!_controller.isInOverlayMode.value) {
      CallService.onEndCallRequested = null;
      unawaited(CallService.stopService());
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Allow pop when call is not active (network end, error, etc.)
      final allowPop = !_controller.isCallActive.value;

      return PopScope(
        canPop: allowPop,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          // Only enter overlay if call is still active
          if (_controller.isCallActive.value) {
            await _enterInAppOverlay();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: _isMovingToOverlay
              ? const ColoredBox(color: Color(0xFF0F172A))
              : Column(
                  children: [
                    CallTopBar(
                      groupName: widget.groupName.isNotEmpty
                          ? widget.groupName
                          : 'Group Call',
                      isMeeting: widget.isMeeting,
                      canRecord: _canRecord,
                      onBack: _enterInAppOverlay,
                    ),
                    Expanded(
                      child: CallGridView(
                        onOverflowTap: () => _showParticipantsSheet(context),
                      ),
                    ),
                    CallControlsBar(
                      isVideoCall: widget.isVideoCall,
                      onEndCall: _controller.leaveCall,
                      onPip: () async {
                        if (Platform.isIOS) {
                          // iOS: always use in-app overlay PIP
                          await _enterInAppOverlay();
                        } else {
                          // Android: try system PIP, fallback to in-app
                          final success = await CallService.enterSystemPip();
                          if (!success && context.mounted) {
                            await _enterInAppOverlay();
                          }
                        }
                      },
                    ),
                  ],
                ),
        ),
      );
    });
  }

  void _showParticipantsSheet(BuildContext ctx) {
    final controller = Get.find<GroupCallNewController>();

    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Obx(() {
        final participants = controller.participants.values.toList();
        participants.sort((a, b) {
          if (a.isLocal) return -1;
          if (b.isLocal) return 1;
          return a.displayName.compareTo(b.displayName);
        });

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Participants (${participants.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: participants.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (_, i) {
                  final p = participants[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueGrey.shade700,
                      child: Text(
                        p.initials,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    title: Text(
                      p.isLocal ? '${p.displayName} (You)' : p.displayName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          p.audioEnabled ? Icons.mic : Icons.mic_off,
                          color: p.audioEnabled
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          p.videoEnabled ? Icons.videocam : Icons.videocam_off,
                          color: p.videoEnabled
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          size: 18,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      }),
    );
  }
}
