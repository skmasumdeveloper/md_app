import 'dart:async';
import 'dart:io';

import 'package:cu_app/Features/Chat/Presentation/chat_screen.dart';
import 'package:cu_app/Features/Group_Call_Embeded/controller/group_call_embeded_controller.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/services/call_service.dart';
import 'package:cu_app/services/embedded_call_overlay_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../Commons/app_colors.dart';
import '../../../Commons/app_images.dart';

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
  bool _isMovingToOverlay = false;

  void _showRecordingComingSoon() {
    if (!mounted || Get.context == null) {
      return;
    }

    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    Get.rawSnackbar(
      snackStyle: SnackStyle.FLOATING,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFFD2DD90),
      borderRadius: 12,
      margin: const EdgeInsets.all(12),
      messageText: const Row(
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.black87, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Screen recording is coming soon.',
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 2),
    );
  }

  void _log(String stage, [Map<String, dynamic>? details]) {
    if (details == null || details.isEmpty) {
      debugPrint('[EmbeddedCall][Screen][$stage]');
      return;
    }
    debugPrint('[EmbeddedCall][Screen][$stage] $details');
  }

  @override
  void initState() {
    super.initState();
    _log('initState', {
      'roomId': widget.roomId,
      'groupName': widget.groupName,
      'isVideoCall': widget.isVideoCall,
      'isMeeting': widget.isMeeting,
    });

    _controller = Get.put(GroupCallEmbededController());
    _controller.isInOverlayMode.value = false;
    unawaited(_controller.setCompactMode(false, force: true));
    WidgetsBinding.instance.addObserver(this);

    CallService.init();
    unawaited(CallService.startService());
    CallService.onEndCallRequested = () {
      _controller.leaveCall(
        roomId: widget.roomId,
        userId: LocalStorage().getUserId(),
      );
    };

    final existingWebController = _controller.webViewController;
    if (existingWebController != null && _controller.isCallActive.value) {
      _log('reuse-existing-webview', {
        'isCallActive': _controller.isCallActive.value,
      });
      _web = existingWebController;
    } else {
      _log('create-new-webview');

      late final PlatformWebViewControllerCreationParams params;
      if (Platform.isIOS) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

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
            onPageStarted: (url) {
              _log('onPageStarted', {'url': url});
            },
            onPageFinished: (_) {
              _log('onPageFinished');
              _controller.onPageReady();
            },
            onWebResourceError: (error) {
              _log('onWebResourceError', {
                'errorCode': error.errorCode,
                'description': error.description,
                'isForMainFrame': error.isForMainFrame,
                'errorType': error.errorType?.name ?? 'unknown',
              });
            },
            onNavigationRequest: (request) {
              _log('onNavigationRequest', {
                'url': request.url,
                'isMainFrame': request.isMainFrame,
              });
              return NavigationDecision.navigate;
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
    }

    _controller.attachWebController(_web);
  }

  Future<void> _enterInAppOverlay() async {
    _log('_enterInAppOverlay:start', {
      'isInOverlayMode': _controller.isInOverlayMode.value,
    });

    if (_controller.isInOverlayMode.value) {
      return;
    }

    _controller.isInOverlayMode.value = true;
    await _controller.setCompactMode(true, force: true);

    if (mounted) {
      setState(() {
        _isMovingToOverlay = true;
      });
    }

    await Future.delayed(const Duration(milliseconds: 20));

    EmbeddedCallOverlayManager().show(
      roomId: widget.roomId,
      groupName: widget.groupName.isNotEmpty ? widget.groupName : 'Group Call',
      isVideoCall: widget.isVideoCall,
      isMeeting: widget.isMeeting,
    );

    if (!mounted) {
      return;
    }

    if (!Get.currentRoute.contains('ChatScreen')) {
      Get.off(() => ChatScreen(
            groupId: widget.roomId,
            isCallFloating: 1,
          ));
    }

    _log('_enterInAppOverlay:end');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('didChangeAppLifecycleState', {
      'state': state.name,
      'isInOverlayMode': _controller.isInOverlayMode.value,
    });

    if (_controller.isInOverlayMode.value) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_controller.setCompactMode(true));
      unawaited(CallService.enterSystemPip());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_controller.setCompactMode(false));
    }
  }

  @override
  void dispose() {
    _log('dispose', {
      'isInOverlayMode': _controller.isInOverlayMode.value,
      'isMovingToOverlay': _isMovingToOverlay,
    });

    WidgetsBinding.instance.removeObserver(this);

    if (!_controller.isInOverlayMode.value) {
      CallService.onEndCallRequested = null;
      unawaited(CallService.stopService());
      unawaited(_controller.setCompactMode(false));
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }

        await _enterInAppOverlay();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _enterInAppOverlay(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _showRecordingComingSoon,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: Color.fromARGB(255, 46, 46, 46),
                        size: 10,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Start REC',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
            child: Padding(
              padding: const EdgeInsets.only(top: 30),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(AppImages.appLogoWhite),
                      fit: BoxFit.contain,
                      opacity: 0.2,
                      filterQuality: FilterQuality.high,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: Text(widget.isMeeting
              ? '${widget.groupName.isNotEmpty ? widget.groupName : 'Group Call'} (Meeting)'
              : (widget.groupName.isNotEmpty
                  ? widget.groupName
                  : 'Group Call')),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Obx(() {
                  final hideWebView =
                      _isMovingToOverlay || CallService.isSystemPipActive.value;

                  if (hideWebView) {
                    return const ColoredBox(color: Color(0xFF070B14));
                  }

                  return WebViewWidget(controller: _web);
                }),
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
                        await _controller.setCompactMode(true);
                        final success = await CallService.enterSystemPip();
                        if (!success && context.mounted) {
                          await _enterInAppOverlay();
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
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: danger
              ? const Color(0xFFE53935)
              : (active ? AppColors.primary : const Color(0xFF334155)),
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
