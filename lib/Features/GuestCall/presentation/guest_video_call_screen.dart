import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';

import 'package:cu_app/services/call_service.dart';

import '../controller/guest_call_controller.dart';
import 'package:cu_app/services/call_overlay_manager.dart';

class GuestVideoCallScreen extends StatefulWidget {
  final String roomId;
  final String guestName;
  final String guestEmail;
  final String meetingTitle;
  final bool isVideoCall;

  const GuestVideoCallScreen({
    super.key,
    required this.roomId,
    required this.guestName,
    required this.guestEmail,
    required this.meetingTitle,
    this.isVideoCall = true,
  });

  @override
  State<GuestVideoCallScreen> createState() => _GuestVideoCallScreenState();
}

class _GuestVideoCallScreenState extends State<GuestVideoCallScreen>
    with WidgetsBindingObserver {
  late final GuestCallController controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      GuestCallController(
        roomId: widget.roomId,
        guestName: widget.guestName,
        guestEmail: widget.guestEmail,
        isVideoCall: widget.isVideoCall,
      ),
      tag: 'guest_call_${widget.roomId}',
    );

    CallService.init();
    CallService.onEndCallRequested = () async {
      await controller.leaveCall();
      if (Navigator.of(context).canPop()) {
        Get.back();
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.startCall();
      await CallService.startService();
    });
  }

  @override
  void dispose() {
    // Stop screen sharing before cleanup
    if (controller.isScreenSharing.value) {
      controller.stopScreenShare();
    }
    CallService.stopService();
    CallService.onEndCallRequested = null;
    controller.leaveCall();
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<bool> _handleBack() async {
    await CallService.enterSystemPip();
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      CallService.enterSystemPip();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.black,
        onEndDrawerChanged: (isOpen) {
          controller.setChatOpen(isOpen);
          if (isOpen) {
            _scrollChatToBottom();
          }
        },
        endDrawer: _buildChatDrawer(),
        body: Stack(
          children: [
            Positioned.fill(
              child: Obx(() {
                if (controller.isConnecting.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.white),
                  );
                }

                return _buildVideoGrid();
              }),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildAppBar(),
            ),
            // Screen share active banner
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Obx(() {
                if (!controller.isScreenSharing.value) {
                  return const SizedBox.shrink();
                }
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.screen_share,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'You are sharing your screen',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => controller.stopScreenShare(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Stop',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Center(child: _buildControls()),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildChatDrawer() {
    final colors = context.appColors;
    return Drawer(
      backgroundColor: colors.cardBg,
      width: 320,
      child: SafeArea(
        child: AnimatedPadding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadowColor,
                      blurRadius: 6,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'In-call Messages',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _scaffoldKey.currentState?.closeEndDrawer();
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (controller.isChatLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator.adaptive(),
                    );
                  }

                  final messages = controller.chatMessages;
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: colors.textTertiary),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollChatToBottom();
                  });

                  return ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msgColors = context.appColors;
                      final item = messages[index];
                      final isLocal = item['isLocal'] == true;
                      final content = item['content']?.toString() ?? '';
                      final senderName =
                          item['senderName']?.toString() ?? 'Guest';
                      final time = _formatTime(item['timestamp']?.toString());

                      return Align(
                        alignment: isLocal
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(maxWidth: 240),
                          decoration: BoxDecoration(
                            color: isLocal
                                ? AppColors.primary
                                : msgColors.textFieldBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: isLocal
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!isLocal)
                                Text(
                                  senderName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: msgColors.textSecondary,
                                  ),
                                ),
                              Text(
                                content,
                                style: TextStyle(
                                  color: isLocal
                                      ? Colors.white
                                      : msgColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isLocal
                                      ? Colors.white70
                                      : msgColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: colors.surfaceBg,
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadowColor,
                      blurRadius: 6,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: colors.textTertiary),
                          filled: true,
                          fillColor: colors.textFieldBg,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    await controller.sendChatMessage(text);
    _messageController.clear();
    _scrollChatToBottom();
  }

  void _scrollChatToBottom() {
    if (!_chatScrollController.hasClients) return;
    _chatScrollController.animateTo(
      _chatScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool _isMuted(bool isLocal, String userId) {
    if (isLocal) {
      return !controller.isMicEnabled.value;
    }
    return !(controller.userAudioEnabled[userId] ?? true);
  }

  String _displayName(bool isLocal, String userId) {
    if (isLocal) return 'You';
    return controller.userDisplayName[userId] ?? 'Guest';
  }

  Widget _buildVideoGrid() {
    final allRenderers = {
      'local': controller.localRenderer,
      ...controller.remoteRenderers,
    };
    final entries = allRenderers.entries.toList();

    if (entries.length == 1) {
      final entry = entries.first;
      return _buildVideoTile(
        entry.value,
        true,
        entry.key,
        isMini: false,
        isMuted: _isMuted(true, entry.key),
      );
    }

    if (entries.length == 2) {
      final localEntry = entries.firstWhere(
        (entry) => entry.key == 'local',
        orElse: () => entries.first,
      );
      final remoteEntry = entries.firstWhere(
        (entry) => entry.key != 'local',
        orElse: () => entries.last,
      );

      return Stack(
        children: [
          Positioned.fill(
            child: _buildVideoTile(
              remoteEntry.value,
              false,
              remoteEntry.key,
              isMini: false,
              isMuted: _isMuted(false, remoteEntry.key),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 120,
            width: 130,
            height: 200,
            child: _buildVideoTile(
              localEntry.value,
              true,
              localEntry.key,
              isMini: true,
              isMuted: _isMuted(true, localEntry.key),
            ),
          ),
        ],
      );
    }

    int crossAxisCount;
    if (entries.length <= 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return GridView.builder(
      key: ValueKey('guest-grid-${entries.length}'),
      padding: const EdgeInsets.fromLTRB(4, 100, 4, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 3 / 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isLocal = entry.key == 'local';
        return _buildVideoTile(
          entry.value,
          isLocal,
          entry.key,
          isMini: false,
          isMuted: _isMuted(isLocal, entry.key),
        );
      },
    );
  }

  Widget _buildVideoTile(RTCVideoRenderer renderer, bool isLocal, String userId,
      {required bool isMini, required bool isMuted}) {
    final stream = renderer.srcObject;
    final hasVideo = stream?.getVideoTracks().isNotEmpty ?? false;
    final label = _displayName(isLocal, userId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(isMini ? 10 : 0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isMini ? 10 : 0),
        child: Stack(
          children: [
            if (hasVideo)
              RTCVideoView(
                renderer,
                mirror: isLocal && !controller.isScreenSharing.value,
                objectFit: isLocal && !controller.isScreenSharing.value
                    ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
                    : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      color: Colors.white,
                      size: isMini ? 32 : 44,
                    ),
                    const SizedBox(height: 8),
                    Text(label, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            if (isMuted)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _handleBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.meetingTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Obx(() {
                    final unread = controller.unreadMessages.value;
                    return IconButton(
                      onPressed: () {
                        _scaffoldKey.currentState?.openEndDrawer();
                      },
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              color: Colors.white),
                          if (unread > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unread > 99 ? '99+' : unread.toString(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Obx(() {
                    return _buildControlButton(
                      onPressed: controller.toggleMic,
                      icon: controller.isMicEnabled.value
                          ? Icons.mic
                          : Icons.mic_off,
                      isActive: controller.isMicEnabled.value,
                      defaultColor: Colors.white,
                    );
                  }),
                  Obx(() {
                    return _buildControlButton(
                      onPressed: controller.isVideoCall
                          ? controller.toggleCamera
                          : null,
                      icon: controller.isCameraEnabled.value
                          ? Icons.videocam
                          : Icons.videocam_off,
                      isActive: controller.isCameraEnabled.value,
                      defaultColor:
                          controller.isVideoCall ? Colors.white : Colors.grey,
                    );
                  }),
                  _buildControlButton(
                    onPressed: controller.switchCamera,
                    icon: Icons.cameraswitch,
                    isActive: false,
                    defaultColor: Colors.white,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: FloatingActionButton(
                      heroTag: 'end_call_btn',
                      mini: false,
                      backgroundColor: Colors.redAccent,
                      elevation: 0,
                      onPressed: () async {
                        await controller.leaveCall();
                        Get.back();
                      },
                      child: const Icon(Icons.call_end,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  Obx(() {
                    return _buildControlButton(
                      onPressed: controller.toggleSpeaker,
                      icon: controller.isSpeakerOn.value
                          ? Icons.volume_up
                          : Icons.volume_off,
                      isActive: controller.isSpeakerOn.value,
                      defaultColor: Colors.white,
                    );
                  }),
                  Obx(() {
                    return _buildControlButton(
                      onPressed: () => controller.toggleScreenShare(),
                      icon: controller.isScreenSharing.value
                          ? Icons.stop_screen_share
                          : Icons.screen_share_outlined,
                      isActive: controller.isScreenSharing.value,
                      defaultColor: controller.isScreenSharing.value
                          ? Colors.blueAccent
                          : Colors.white,
                    );
                  }),
                  _buildControlButton(
                    onPressed: () async {
                      final success = await CallService.enterSystemPip();
                      if (!success) {
                        // fallback to in-app overlay if system pip not available
                        controller.isInOverlayMode.value = true;
                        CallOverlayManager().show(
                          groupId: controller.roomId,
                          groupName: controller.guestName,
                          groupImage: '',
                          isVideoCall: controller.isVideoCall,
                        );
                      }
                    },
                    icon: Icons.picture_in_picture_alt,
                    isActive: false,
                    defaultColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    bool isActive = true,
    Color defaultColor = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: defaultColor, size: 24),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          highlightColor: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }
}
