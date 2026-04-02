import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:cu_app/services/call_service.dart';
import 'package:cu_app/services/call_overlay_manager.dart';
import 'package:cu_app/Features/Group_Call_old/controller/group_call.dart';
import 'package:cu_app/Features/Chat/Presentation/chat_screen.dart';
import 'package:cu_app/Features/Home/Controller/socket_controller.dart';
import 'package:cu_app/Features/Chat/Controller/chat_controller.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Utils/datetime_utils.dart';

import '../../Home/Widgets/blinking_icon_circle.dart';

part 'video_call_grid.dart';
part 'video_call_meeting.dart';
part 'video_call_screen_share.dart';

// This screen displays the video/audio call interface for a group call, control audio/video settings, and manage the call.
class GroupVideoCallScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupImage;
  final MediaStream localStream;
  final bool isVideoCall;

  const GroupVideoCallScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupImage,
    required this.localStream,
    required this.isVideoCall,
  });

  @override
  State<GroupVideoCallScreen> createState() => _GroupVideoCallScreenState();
}

class _GroupVideoCallScreenState extends State<GroupVideoCallScreen>
    with WidgetsBindingObserver {
  final socketController = Get.put(SocketController());
  final groupcallController = Get.find<GroupcallController>();
  final ChatController chatController =
      Get.put<ChatController>(ChatController());

  Timer? _meetingTimeTimer;
  RxString dynamicMeetingTimeText = ''.obs;

  @override
  void initState() {
    groupcallController.isCallActive.value = true;
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);

    // Initialize native call service (foreground service + method channel)
    CallService.init();

    // Wire notification action callbacks (avoids circular imports)
    CallService.onEndCallRequested = () {
      groupcallController.leaveCall(
        roomId: widget.groupId,
        userId: LocalStorage().getUserId(),
      );
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      groupcallController.isCallActive.value = true;

      CallService.startService();

      groupcallController.currentRoomId.value = widget.groupId;
      groupcallController.setAudioToSpeaker(true);
      socketController.isAnyCallFloat.value = false;

      _startMeetingEndTimerIfNeeded();

      _startMeetingTimeUpdates();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On Android, a native hook automatically enters PiP when the user
    // hits Home.  iOS has no such hook, so we proactively request PiP when
    // the app is backgrounded.  Flutter side will treat a failure as a
    // no-op and fall back to the in‑app overlay.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      CallService.enterSystemPip();
    }

    // Screen sharing stays alive in background via ScreenCaptureService
    // foreground service (FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION).
    // Do NOT stop screen sharing here — it must survive backgrounding.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _meetingTimeTimer?.cancel();

    // Only fully stop the call if NOT going to in-app overlay mode.
    // When going to overlay, the call should keep running.
    if (!groupcallController.isInOverlayMode.value) {
      // Stop screen sharing before leaving
      if (groupcallController.isScreenSharing.value) {
        groupcallController.stopScreenShare();
      }
      CallService.stopService();
      CallService.onEndCallRequested = null;
      groupcallController.isCallActive.value = false;
      groupcallController.isIncomingCallScreenOpen.value = false;
      groupcallController.isAnyCallActive.value = false;
      WakelockPlus.disable();
      groupcallController.stopMeetingEndTimer();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    socketController.updateBuildContext(context);
    groupcallController.updateBuildContext(context);

    // We use Obx to react to PiP state changes from Native side/CallService
    final colors = context.appColors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Back gesture / button: enter in-app overlay mode
        groupcallController.isInOverlayMode.value = true;
        CallOverlayManager().show(
          groupId: widget.groupId,
          groupName: widget.groupName,
          groupImage: widget.groupImage,
          isVideoCall: widget.isVideoCall,
        );
        Get.off(() => ChatScreen(
              groupId: widget.groupId,
              isCallFloating: 1,
            ));
      },
      child: Obx(() {
        final isPip = CallService.isSystemPipActive.value;
        return Scaffold(
          resizeToAvoidBottomInset: !isPip,
          backgroundColor: AppColors.hedingColor,
          appBar: isPip
              ? null
              : AppBar(
                  backgroundColor: AppColors.hedingColor,
                  title: Obx(() => Text(
                        '${widget.groupName}${groupcallController.groupModel.value.isTemp == true ? ' (Meeting)' : ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )),
                  centerTitle: true,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () async {
                      // Back arrow: enter in-app overlay mode
                      groupcallController.isInOverlayMode.value = true;
                      CallOverlayManager().show(
                        groupId: widget.groupId,
                        groupName: widget.groupName,
                        groupImage: widget.groupImage,
                        isVideoCall: widget.isVideoCall,
                      );
                      Get.off(() => ChatScreen(
                            groupId: widget.groupId,
                            isCallFloating: 1,
                          ));
                    },
                  ),
                  actions: [
                    Obx(() => Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: (socketController.isConnected.value &&
                                  socketController.socketID.isNotEmpty)
                              ? BlinkingIconCircle(
                                  icon: Icons.circle,
                                  iconColor: colors.onlineStatus,
                                  blinkColor: colors.onlineStatus,
                                  iconSize: 10,
                                  beatDuration:
                                      const Duration(milliseconds: 10000),
                                )
                              : BlinkingIconCircle(
                                  icon: Icons.circle,
                                  iconColor: colors.offlineStatus,
                                  blinkColor: colors.offlineStatus,
                                  iconSize: 10,
                                  beatDuration:
                                      const Duration(milliseconds: 10000),
                                ),
                        )),
                  ],
                ),
          body: SafeArea(
            child: Column(
              children: [
                if (!isPip)
                  Obx(() => groupcallController.groupModel.value.isTemp ==
                              true &&
                          groupcallController.groupModel.value.meetingEndTime !=
                              null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          color: Colors.blueAccent.withOpacity(0.9),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Obx(() => Text(
                                      dynamicMeetingTimeText.value,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox()),
                // Screen share active banner
                //  buildScreenShareBanner(),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Obx(() {
                      return _buildVideoGrid();
                    }),
                  ),
                ),
                if (!isPip)
                  Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Obx(() => FloatingActionButton(
                                  heroTag: 'call_action_mic',
                                  mini: true,
                                  backgroundColor:
                                      groupcallController.isMicEnabled.value
                                          ? AppColors.primary
                                          : Colors.red,
                                  onPressed: groupcallController.toggleMic,
                                  child: Icon(
                                    groupcallController.isMicEnabled.value
                                        ? Icons.mic
                                        : Icons.mic_off,
                                    color: Colors.white,
                                  ),
                                )),
                            if (widget.isVideoCall)
                              Obx(() => FloatingActionButton(
                                    heroTag: 'call_action_camera',
                                    mini: true,
                                    backgroundColor: groupcallController
                                            .isCameraEnabled.value
                                        ? AppColors.primary
                                        : Colors.red,
                                    onPressed: groupcallController.toggleCamera,
                                    child: Icon(
                                      groupcallController.isCameraEnabled.value
                                          ? Icons.videocam
                                          : Icons.videocam_off,
                                      color: Colors.white,
                                    ),
                                  )),
                            if (widget.isVideoCall)
                              FloatingActionButton(
                                heroTag: 'call_action_switch_camera',
                                mini: true,
                                backgroundColor: AppColors.primary,
                                onPressed: groupcallController.switchCamera,
                                child: const Icon(Icons.cameraswitch,
                                    color: Colors.white),
                              ),
                            FloatingActionButton(
                              heroTag: 'call_action_end_call',
                              backgroundColor: Colors.red,
                              onPressed: () async {
                                await groupcallController.leaveCall(
                                    roomId: widget.groupId,
                                    userId: LocalStorage().getUserId());
                              },
                              child: const Icon(Icons.call_end,
                                  color: Colors.white),
                            ),
                            // Obx(() => FloatingActionButton(
                            //       heroTag: 'call_action_screen_share',
                            //       mini: true,
                            //       backgroundColor:
                            //           groupcallController.isScreenSharing.value
                            //               ? Colors.blueAccent
                            //               : AppColors.primary,
                            //       onPressed: () =>
                            //           groupcallController.toggleScreenShare(),
                            //       child: Icon(
                            //         groupcallController.isScreenSharing.value
                            //             ? Icons.stop_screen_share
                            //             : Icons.screen_share,
                            //         color: Colors.white,
                            //       ),
                            //     )),
                            Obx(
                              () => FloatingActionButton(
                                heroTag: 'call_action_speaker',
                                mini: true,
                                backgroundColor:
                                    groupcallController.isSpeakerOn.value
                                        ? AppColors.primary
                                        : Colors.lightBlue,
                                onPressed: groupcallController.toggleSpeaker,
                                child: Icon(
                                  groupcallController.isSpeakerOn.value
                                      ? Icons.volume_up
                                      : Icons.phone_in_talk,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            FloatingActionButton(
                              heroTag: 'call_action_picture_in_picture',
                              mini: true,
                              backgroundColor: AppColors.primary,
                              onPressed: () async {
                                // try system PiP first; on failure fall back to overlay
                                final success =
                                    await CallService.enterSystemPip();
                                if (!success) {
                                  groupcallController.isInOverlayMode.value =
                                      true;
                                  CallOverlayManager().show(
                                    groupId: widget.groupId,
                                    groupName: widget.groupName,
                                    groupImage: widget.groupImage,
                                    isVideoCall: widget.isVideoCall,
                                  );
                                  Get.off(() => ChatScreen(
                                        groupId: widget.groupId,
                                        isCallFloating: 1,
                                      ));
                                }
                              },
                              child: const Icon(
                                Icons.picture_in_picture_alt,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
