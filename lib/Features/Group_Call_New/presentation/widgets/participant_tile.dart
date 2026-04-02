import 'dart:ui';
import 'package:flutter/material.dart';

import '../../models/call_participant.dart';
import 'adaptive_video_view.dart';

/// A single participant video tile with avatar fallback, mute indicator,
/// name badge, and reconnecting blur overlay.
class ParticipantTile extends StatelessWidget {
  final CallParticipant participant;
  final bool isMini;
  final bool showBadges;
  final VoidCallback? onTap;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isMini = false,
    this.showBadges = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isMini ? 12 : 8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(isMini ? 12 : 8),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video or Avatar
              if (participant.hasActiveVideo)
                AdaptiveVideoView(
                  renderer: participant.renderer!,
                  mirror: participant.isLocal,
                  isLocal: participant.isLocal,
                )
              else
                _AvatarPlaceholder(
                  initials: participant.initials,
                  displayName: participant.displayName,
                  isMini: isMini,
                  showCameraOff:
                      !participant.videoEnabled && !participant.isReconnecting,
                ),

              // Reconnecting blur overlay
              if (participant.isReconnecting)
                Positioned.fill(
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              ),
                              if (!isMini) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Reconnecting...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Audio muted indicator (top-right)
              if (!participant.audioEnabled && showBadges && !isMini)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.mic_off,
                      color: Colors.redAccent,
                      size: 14,
                    ),
                  ),
                ),

              // Name badge (bottom, only in grid mode - not mini, not dual fullscreen)
              if (showBadges && !isMini)
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      participant.isLocal ? 'You' : participant.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar placeholder with initials and camera-off indicator.
class _AvatarPlaceholder extends StatelessWidget {
  final String initials;
  final String displayName;
  final bool isMini;
  final bool showCameraOff;

  const _AvatarPlaceholder({
    required this.initials,
    required this.displayName,
    this.isMini = false,
    this.showCameraOff = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar circle
            Container(
              width: isMini ? 40 : 72,
              height: isMini ? 40 : 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blueGrey.shade500,
                    Colors.blueGrey.shade700,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMini ? 16 : 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Camera off indicator below avatar
            if (showCameraOff && !isMini) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off, color: Colors.white54, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Camera off',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
