import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../Commons/app_colors.dart';
import '../../controller/group_call_new_controller.dart';
import '../../models/call_state.dart';

/// Bottom control bar with mute, video, speaker, PIP, and end call buttons.
class CallControlsBar extends StatelessWidget {
  final bool isVideoCall;
  final VoidCallback onEndCall;
  final VoidCallback onPip;

  const CallControlsBar({
    super.key,
    required this.isVideoCall,
    required this.onEndCall,
    required this.onPip,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GroupCallNewController>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF0F172A)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mic toggle
            Obx(() => _ControlButton(
                  icon: controller.isMicEnabled.value
                      ? Icons.mic
                      : Icons.mic_off,
                  active: controller.isMicEnabled.value,
                  label: controller.isMicEnabled.value ? 'Mute' : 'Unmute',
                  onTap: controller.toggleMic,
                )),

            // Camera toggle (video calls only)
            if (isVideoCall)
              Obx(() => _ControlButton(
                    icon: controller.isCameraEnabled.value
                        ? Icons.videocam
                        : Icons.videocam_off,
                    active: controller.isCameraEnabled.value,
                    label: 'Camera',
                    onTap: controller.toggleCamera,
                  )),

            // Switch camera (video calls only)
            if (isVideoCall)
              _ControlButton(
                icon: Icons.cameraswitch,
                active: true,
                label: 'Flip',
                onTap: controller.switchCamera,
              ),

            // Speaker / audio route
            Obx(() {
              final route = controller.audioRoute.value;
              IconData icon;
              String label;
              switch (route) {
                case AudioOutputRoute.speaker:
                  icon = Icons.volume_up;
                  label = 'Speaker';
                  break;
                case AudioOutputRoute.earpiece:
                  icon = Icons.phone_in_talk;
                  label = 'Earpiece';
                  break;
                case AudioOutputRoute.bluetooth:
                  icon = Icons.bluetooth_audio;
                  label = 'Bluetooth';
                  break;
              }
              return _ControlButton(
                icon: icon,
                active: route == AudioOutputRoute.speaker,
                label: label,
                onTap: controller.toggleSpeaker,
                onLongPress: controller.cycleAudioOutput,
              );
            }),

            // PIP
            _ControlButton(
              icon: Icons.picture_in_picture_alt,
              active: true,
              label: 'PiP',
              onTap: onPip,
            ),

            // End call
            _ControlButton(
              icon: Icons.call_end,
              active: false,
              danger: true,
              label: 'End',
              onTap: onEndCall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool danger;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ControlButton({
    required this.icon,
    required this.active,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: danger
                  ? const Color(0xFFE53935)
                  : (active ? AppColors.primary : const Color(0xFF334155)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: danger ? const Color(0xFFE53935) : Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
