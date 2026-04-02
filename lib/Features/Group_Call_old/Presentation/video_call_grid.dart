part of 'video_call_screen.dart';

extension GroupVideoCallGridExtension on _GroupVideoCallScreenState {
  Widget _buildVideoGrid() {
    final allRenderers = {
      'local': groupcallController.localRenderer,
      ...groupcallController.remoteRenderers,
    };

    final totalLimit = math.min(
        allRenderers.length, groupcallController.maxActiveRenderers + 6);
    final limitedRenderers = allRenderers.entries.take(totalLimit).toList();

    if (limitedRenderers.length == 1 && limitedRenderers.first.key == 'local') {
      final localEntry = limitedRenderers.first;

      return Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildVideoItem(
                  true,
                  localEntry.value,
                  localEntry.value.srcObject
                          ?.getVideoTracks()
                          .any((track) => track.enabled) ??
                      false,
                  localEntry.value.srcObject != null,
                  localEntry.key,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Connecting to others...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Waiting for others to join the call',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (limitedRenderers.length == 2) {
      final localEntry =
          limitedRenderers.firstWhere((entry) => entry.key == 'local');
      final remoteEntry =
          limitedRenderers.firstWhere((entry) => entry.key != 'local');

      // Use fallback stream (same as grid layout) so video survives
      // brief srcObject gaps during recovery / re-attach.
      final remoteStream = remoteEntry.value.srcObject ??
          groupcallController.remoteStreams[remoteEntry.key];
      final remoteHasVideo =
          remoteStream?.getVideoTracks().any((track) => track.enabled) ??
              false;
      final remoteHasStream =
          remoteStream != null && remoteStream.getTracks().isNotEmpty;

      return Stack(
        children: [
          _buildFullScreenVideoItem(false, remoteEntry.value, remoteHasVideo,
              remoteHasStream, remoteEntry.key),
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.35,
              height: MediaQuery.of(context).size.width * 0.50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildVideoItem(
                    true,
                    localEntry.value,
                    localEntry.value.srcObject
                            ?.getVideoTracks()
                            .any((track) => track.enabled) ??
                        false,
                    localEntry.value.srcObject != null,
                    localEntry.key),
              ),
            ),
          ),
        ],
      );
    }

    int crossAxisCount;
    if (limitedRenderers.length <= 1) {
      crossAxisCount = 1;
    } else if (limitedRenderers.length <= 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 3 / 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      physics: const BouncingScrollPhysics(),
      scrollDirection: Axis.vertical,
      itemCount: limitedRenderers.length,
      itemBuilder: (context, index) {
        final entry = limitedRenderers[index];
        final isLocal = entry.key == 'local';
        final renderer = entry.value;
        final userId = entry.key;

        final stream =
            renderer.srcObject ?? groupcallController.remoteStreams[userId];
        final hasVideoTrack =
            stream?.getVideoTracks().any((track) => track.enabled) ?? false;
        final hasStream = stream != null && stream.getTracks().isNotEmpty;

        return KeyedSubtree(
          key: ValueKey('video-item-$userId'),
          child: _buildVideoItem(
              isLocal, renderer, hasVideoTrack, hasStream, userId),
        );
      },
    );
  }

  Widget _buildFullScreenVideoItem(bool isLocal, RTCVideoRenderer renderer,
      bool hasVideoTrack, bool hasStream, String userId) {
    final audioEnabled = isLocal
        ? groupcallController.isMicEnabled.value
        : (groupcallController.userAudioEnabled[userId] ??
            (renderer.srcObject
                    ?.getAudioTracks()
                    .any((track) => track.enabled && !(track.muted ?? false)) ??
                false));
    // Never mirror screen share — neither local (when sharing) nor remote
    final shouldMirror = isLocal && !groupcallController.isScreenSharing.value;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black87,
      child: Stack(
        children: [
          Center(
            child: hasStream
                ? hasVideoTrack
                    ? RTCVideoView(
                        renderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                        mirror: shouldMirror,
                        filterQuality: FilterQuality.low,
                      )
                    : _buildPlaceholder(isLocal, userId, "Audio only")
                : _buildPlaceholder(isLocal, userId, "Connecting..."),
          ),
          if (hasStream && !audioEnabled)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.mic_off,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoItem(bool isLocal, RTCVideoRenderer renderer,
      bool hasVideoTrack, bool hasStream, String userId) {
    final audioEnabled = isLocal
        ? groupcallController.isMicEnabled.value
        : (groupcallController.userAudioEnabled[userId] ??
            (renderer.srcObject
                    ?.getAudioTracks()
                    .any((track) => track.enabled && !(track.muted ?? false)) ??
                false));

    // Never mirror screen share — neither local (when sharing) nor remote
    final shouldMirror = isLocal && !groupcallController.isScreenSharing.value;

    return GestureDetector(
      onTap: () {
        groupcallController.promoteRenderer(userId);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: Colors.black87,
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: hasStream
                      ? (hasVideoTrack
                          ? RTCVideoView(
                              renderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitContain,
                              mirror: shouldMirror,
                              filterQuality: FilterQuality.low,
                            )
                          : _buildPlaceholder(isLocal, userId, "Audio only"))
                      : (groupcallController.remoteStreams[userId] != null
                          ? _buildPlaceholder(
                              isLocal,
                              userId,
                              "Video paused to save resources",
                            )
                          : _buildPlaceholder(
                              isLocal, userId, "Connecting...")),
                ),
              ),
              if (hasStream && !hasVideoTrack)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Audio only',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              if (hasStream && !audioEnabled)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.mic_off,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isLocal
                        ? 'You'
                        : groupcallController.getUserFullName(userId),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (!hasStream && !isLocal)
                const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      backgroundColor: Colors.black45,
                    ),
                  ),
                ),
              if (!isLocal &&
                  groupcallController.reconnectingPeers.containsKey(userId) &&
                  groupcallController.reconnectingPeers[userId] == true)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Reconnecting...',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isLocal, String userId, [String? message]) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.videocam_off,
          color: Colors.white54,
          size: 40,
        ),
        const SizedBox(height: 8),
        Text(
          message ?? (isLocal ? 'Your camera is off' : 'No video available'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      ],
    );
  }
}
