import 'dart:async';
import 'dart:io';

import 'package:cu_app/Features/Group_Call_Embeded/controller/group_call_embeded_controller.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class GroupCallEmbededScreen extends StatefulWidget {
  final String roomId;
  final String groupName;
  final bool isVideoCall;
  final bool isMeeting;

  const GroupCallEmbededScreen({
    super.key,
    required this.roomId,
    required this.groupName,
    required this.isVideoCall,
    this.isMeeting = false,
  });

  @override
  State<GroupCallEmbededScreen> createState() => _GroupCallEmbededScreenState();
}

class _GroupCallEmbededScreenState extends State<GroupCallEmbededScreen>
    with WidgetsBindingObserver {
  late final GroupCallEmbededController _controller;
  late final WebViewController _web;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(GroupCallEmbededController());
    WidgetsBinding.instance.addObserver(this);

    CallService.init();
    unawaited(CallService.startService());
    CallService.onEndCallRequested = () {
      _controller.leaveCall(
        roomId: widget.roomId,
        userId: LocalStorage().getUserId(),
      );
    };

    final params = PlatformWebViewControllerCreationParams();
    _web = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF070B14))
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) {
          _controller.handleJsMessage(msg.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _controller.onPageReady();
          },
        ),
      )
      ..loadFlutterAsset('assets/group_call_embeded/index.html');

    if (Platform.isAndroid && _web.platform is AndroidWebViewController) {
      final androidController = _web.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setOnPlatformPermissionRequest(
        (request) {
          request.grant();
        },
      );
    }

    _controller.attachWebController(_web);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(CallService.enterSystemPip());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CallService.onEndCallRequested = null;
    unawaited(CallService.stopService());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) async {
        await _controller.leaveCall(
          roomId: widget.roomId,
          userId: LocalStorage().getUserId(),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF070B14),
          title: Text(widget.isMeeting
              ? '${widget.groupName.isNotEmpty ? widget.groupName : 'Group Call'} (Meeting)'
              : (widget.groupName.isNotEmpty
                  ? widget.groupName
                  : 'Group Call')),
          centerTitle: true,
          actions: [
            Obx(() => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Text(
                      _controller.callState.value,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                )),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: WebViewWidget(controller: _web),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF111827), Color(0xFF0F172A)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Obx(() => _ActionButton(
                          icon: _controller.isMicEnabled.value
                              ? Icons.mic
                              : Icons.mic_off,
                          active: _controller.isMicEnabled.value,
                          onTap: _controller.toggleMic,
                        )),
                    if (widget.isVideoCall)
                      Obx(() => _ActionButton(
                            icon: _controller.isCameraEnabled.value
                                ? Icons.videocam
                                : Icons.videocam_off,
                            active: _controller.isCameraEnabled.value,
                            onTap: _controller.toggleCamera,
                          )),
                    if (widget.isVideoCall)
                      _ActionButton(
                        icon: Icons.cameraswitch,
                        active: true,
                        onTap: _controller.switchCamera,
                      ),
                    Obx(() => _ActionButton(
                          icon: _controller.isSpeakerOn.value
                              ? Icons.volume_up
                              : Icons.phone_in_talk,
                          active: _controller.isSpeakerOn.value,
                          onTap: _controller.toggleSpeaker,
                        )),
                    _ActionButton(
                      icon: Icons.picture_in_picture_alt,
                      active: true,
                      onTap: () async {
                        final success = await CallService.enterSystemPip();
                        if (!success && context.mounted) {
                          Get.snackbar(
                            'PiP unavailable',
                            'System PiP is not available on this device.',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        }
                      },
                    ),
                    _ActionButton(
                      icon: Icons.call_end,
                      active: false,
                      danger: true,
                      onTap: () => _controller.leaveCall(
                        roomId: widget.roomId,
                        userId: LocalStorage().getUserId(),
                      ),
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool danger;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.active,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: danger
              ? const Color(0xFFE53935)
              : (active ? const Color(0xFF0EA5E9) : const Color(0xFF334155)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
