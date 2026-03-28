part of 'group_call.dart';

extension GroupCallRenderersExtension on GroupcallController {
  // This method starts a timer to check for trackless renderers.
  void _startTracklessCheckTimer() {
    debugPrint(
        '[Renderers] _startTracklessCheckTimer: starting 15s periodic timer');
    _trackCheckTimer?.cancel();
    _trackCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkForTracklessRenderers();
    });
  }

  // Check for renderers without active tracks.
  // IMPORTANT: This should NEVER remove user presence (_existingUserIds, joinedUsers, etc).
  // Users should only be removed from the UI via FE-user-leave socket events.
  // This timer only cleans up stale renderers to free resources.
  void _checkForTracklessRenderers() async {
    if (remoteRenderers.isEmpty) return;

    // Don't run during recovery
    if (_isRestartingIce) {
      debugPrint(
          '[Renderers] _checkForTracklessRenderers: skipping — recovery in progress');
      return;
    }

    final now = DateTime.now();

    for (final entry in remoteRenderers.entries) {
      final userId = entry.key;
      final renderer = entry.value;
      final stream = renderer.srcObject;
      bool hasActiveTracks = false;

      if (stream != null) {
        try {
          final hasAudio =
              stream.getAudioTracks().any((track) => track.enabled);
          final hasVideo =
              stream.getVideoTracks().any((track) => track.enabled);
          hasActiveTracks = hasAudio || hasVideo;
        } catch (e) {
          // Track might be disposed — treat as no active tracks
        }
      }

      // Check if there are any consumers for this user
      final hasConsumers = _consumerToUserMap.values.contains(userId);

      if (!hasActiveTracks && !hasConsumers) {
        if (!_tracklessUsers.containsKey(userId)) {
          _tracklessUsers[userId] = now;
          debugPrint(
              '[Renderers] user=$userId has no active tracks — monitoring');
        }
      } else {
        if (_tracklessUsers.containsKey(userId)) {
          debugPrint('[Renderers] user=$userId recovered tracks');
          _tracklessUsers.remove(userId);
        }
      }
    }

    // Don't remove users — just log. Users are only removed via FE-user-leave.
    _tracklessUsers.removeWhere((userId, startTime) {
      if (now.difference(startTime).inSeconds >= 30) {
        debugPrint(
            '[Renderers] user=$userId trackless for >30s — user is likely still in call but media dropped. NOT removing.');
        return true; // Remove from tracking map but don't remove user
      }
      return false;
    });
  }

  // This method initializes renderers for local streams.
  Future<void> _initializeRenderers() async {
    debugPrint(
        '[Renderers] _initializeRenderers: initializing local renderer');
    await localRenderer.initialize();
    debugPrint('[Renderers] _initializeRenderers: ✓ local renderer ready');
  }
}
