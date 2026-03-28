part of 'video_call_screen.dart';

extension GroupVideoCallScreenShareExtension on _GroupVideoCallScreenState {
  /// Builds a banner indicating screen sharing is active.
  Widget buildScreenShareBanner() {
    return Obx(() {
      if (!groupcallController.isScreenSharing.value) {
        return const SizedBox.shrink();
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.blueAccent.withOpacity(0.9),
        child: Row(
          children: [
            const Icon(Icons.screen_share, color: Colors.white, size: 16),
            const SizedBox(width: 8),
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
            TextButton(
              onPressed: () => groupcallController.stopScreenShare(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(0, 0),
              ),
              child: const Text(
                'Stop',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
