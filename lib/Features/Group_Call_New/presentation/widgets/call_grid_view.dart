import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/group_call_new_controller.dart';
import '../../models/call_participant.dart';
import 'participant_tile.dart';

/// Dynamic grid layout for call participants.
/// - 1 participant (self only): full screen local view
/// - 2 participants: local mini overlay on remote full screen (WhatsApp style)
/// - 3-4 participants: 2x2 grid
/// - 5+ participants: 2x2 grid + overflow badge with "+N more"
class CallGridView extends StatelessWidget {
  final VoidCallback? onOverflowTap;

  const CallGridView({super.key, this.onOverflowTap});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GroupCallNewController>();

    return Obx(() {
      final allParticipants = controller.participants.values.toList();
      allParticipants.sort((a, b) {
        if (a.isLocal) return -1;
        if (b.isLocal) return 1;
        return a.joinedAt.compareTo(b.joinedAt);
      });

      final count = allParticipants.length;

      if (count == 0) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        );
      }

      if (count == 1) {
        return _buildSingleView(allParticipants.first);
      }

      if (count == 2) {
        return _buildDualView(allParticipants);
      }

      // 3+ participants: grid view
      return _buildGridView(allParticipants);
    });
  }

  /// Single participant (waiting for others).
  Widget _buildSingleView(CallParticipant participant) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ParticipantTile(participant: participant),
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Waiting for others to join...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Two participants: remote full screen + local mini overlay (WhatsApp style).
  Widget _buildDualView(List<CallParticipant> participants) {
    final local = participants.firstWhere((p) => p.isLocal,
        orElse: () => participants.first);
    final remote = participants.firstWhere((p) => !p.isLocal,
        orElse: () => participants.last);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Remote full screen (badges hidden - we show them separately)
        ParticipantTile(participant: remote, showBadges: false),

        // Remote name badge (bottom-left, beside the mini tile)
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  remote.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!remote.audioEnabled) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.mic_off, color: Colors.redAccent, size: 14),
                ],
              ],
            ),
          ),
        ),

        // Local mini overlay (bottom-right)
        Positioned(
          bottom: 12,
          right: 12,
          width: 100,
          height: 140,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ParticipantTile(
              participant: local,
              isMini: true,
            ),
          ),
        ),
      ],
    );
  }

  /// Grid view for 3+ participants (2x2 max visible + overflow).
  Widget _buildGridView(List<CallParticipant> allParticipants) {
    const maxVisible = 4;
    final visible = allParticipants.take(maxVisible).toList();
    final overflowCount = allParticipants.length - maxVisible;

    return LayoutBuilder(builder: (context, constraints) {
      final totalWidth = constraints.maxWidth;
      final totalHeight = constraints.maxHeight;
      const gap = 4.0;

      // Calculate grid dimensions
      final int columns = visible.length <= 2 ? 1 : 2;
      final int rows = (visible.length / columns).ceil();

      final tileWidth = (totalWidth - gap * (columns - 1)) / columns;
      final tileHeight = (totalHeight - gap * (rows - 1)) / rows;

      return Padding(
        padding: const EdgeInsets.all(2),
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(visible.length, (index) {
            final participant = visible[index];
            return SizedBox(
              width: tileWidth - 2, // account for outer padding
              height: tileHeight - 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ParticipantTile(participant: participant),

                  // Overflow badge on last tile
                  if (overflowCount > 0 && index == visible.length - 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onOverflowTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '+$overflowCount more',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      );
    });
  }
}
