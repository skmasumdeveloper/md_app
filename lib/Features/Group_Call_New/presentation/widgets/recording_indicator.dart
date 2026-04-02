import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/group_call_new_controller.dart';

/// Recording button for admins and live indicator for all users.
/// - Not recording + admin: "Start REC" button
/// - Not recording + non-admin: nothing
/// - Recording + started by me: blinking dot + "Recording" + "Stop"
/// - Recording + started by others: blinking dot + "Recording" (view-only)
class RecordingIndicator extends StatelessWidget {
  final bool canRecord;

  const RecordingIndicator({
    super.key,
    required this.canRecord,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GroupCallNewController>();
    final recording = controller.recordingMgr;

    return Obx(() {
      final isRecording = recording.isRecording.value;
      final error = recording.errorMessage.value;
      final localUserId = controller.localUserId;
      final isMyRecording = recording.isStartedByUser(localUserId);

      // Show error snackbar
      if (error.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
          Get.rawSnackbar(
            message: error,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.shade800,
            margin: const EdgeInsets.all(12),
            borderRadius: 12,
            duration: const Duration(seconds: 3),
          );
          recording.errorMessage.value = '';
        });
      }

      if (isRecording) {
        return _RecordingLiveBadge(
          canStop: isMyRecording,
          onStop: () {
            recording.stopRecording(
              roomId: controller.currentRoomId.value,
              userId: localUserId,
            );
          },
        );
      }

      // Not recording — show "Start REC" for admins only
      if (canRecord) {
        return _StartRecordButton(
          onTap: () {
            recording.startRecording(
              roomId: controller.currentRoomId.value,
              userId: localUserId,
            );
          },
        );
      }

      return const SizedBox.shrink();
    });
  }
}

/// Live recording indicator — blinking red dot + "Recording" text.
/// Only the user who started it sees the "Stop" button.
class _RecordingLiveBadge extends StatefulWidget {
  final bool canStop;
  final VoidCallback onStop;

  const _RecordingLiveBadge({
    required this.canStop,
    required this.onStop,
  });

  @override
  State<_RecordingLiveBadge> createState() => _RecordingLiveBadgeState();
}

class _RecordingLiveBadgeState extends State<_RecordingLiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.canStop ? widget.onStop : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade900.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Blinking red dot
            FadeTransition(
              opacity: _blinkController,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // "Recording" text
            const Text(
              'Recording',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Stop button — only for the creator
            if (widget.canStop) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
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
            ],
          ],
        ),
      ),
    );
  }
}

/// "Start REC" button for admins when not recording.
class _StartRecordButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StartRecordButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Start REC',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
