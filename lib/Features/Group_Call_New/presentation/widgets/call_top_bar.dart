import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/group_call_new_controller.dart';
import '../../models/call_state.dart';
import 'recording_indicator.dart';

/// Top bar showing group name, call duration/status, recording indicator, and participant count.
class CallTopBar extends StatelessWidget {
  final String groupName;
  final bool isMeeting;
  final bool canRecord;
  final VoidCallback onBack;

  const CallTopBar({
    super.key,
    required this.groupName,
    required this.isMeeting,
    required this.onBack,
    this.canRecord = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GroupCallNewController>();

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 4,
        right: 12,
        bottom: 6,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMeeting ? '$groupName (Meeting)' : groupName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Obx(() {
                  final state = controller.callState.value;
                  final count = controller.participants.length;
                  String statusText;
                  Color statusColor;

                  switch (state) {
                    case GroupCallState.connecting:
                      statusText = 'Connecting...';
                      statusColor = Colors.amber;
                      break;
                    case GroupCallState.reconnecting:
                      statusText = 'Reconnecting...';
                      statusColor = Colors.amber;
                      break;
                    case GroupCallState.connected:
                      statusText = '$count participant${count != 1 ? 's' : ''}';
                      statusColor = Colors.greenAccent;
                      break;
                    case GroupCallState.error:
                      statusText = 'Connection error';
                      statusColor = Colors.redAccent;
                      break;
                    default:
                      statusText = 'Preparing...';
                      statusColor = Colors.white54;
                  }

                  return Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),

          // Recording indicator
          RecordingIndicator(canRecord: canRecord),
          const SizedBox(width: 8),

          // Participants count badge
          Obx(() {
            final count = controller.participants.length;
            return GestureDetector(
              onTap: () => _showParticipantsSheet(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showParticipantsSheet(BuildContext context) {
    final controller = Get.find<GroupCallNewController>();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Obx(() {
        final list = controller.participants.values.toList();
        list.sort((a, b) {
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
                'Participants (${list.length})',
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
                itemCount: list.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (_, i) {
                  final p = list[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueGrey.shade700,
                      child: Text(
                        p.initials,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
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
                          p.videoEnabled
                              ? Icons.videocam
                              : Icons.videocam_off,
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
