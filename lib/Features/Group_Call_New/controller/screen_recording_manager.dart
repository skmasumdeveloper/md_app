import 'dart:async';

import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:get/get.dart';

import 'call_logger.dart';
import 'call_socket_manager.dart';

/// Manages server-side call recording state.
/// Recording happens entirely on the server — client only emits
/// start/stop events and shows the indicator.
/// Polls the API every 5 seconds to stay in sync.
class ScreenRecordingManager {
  static const String _scope = 'RecordingMgr';

  final CallSocketManager _socketMgr;
  Timer? _pollTimer;
  // ignore: unused_field
  String _currentGroupId = '';

  // ─── Observable State ──────────────────────────────────────────
  final RxBool isRecording = false.obs;
  final RxString recordingId = ''.obs;

  /// The userId who started the recording — only this user can stop it.
  final RxString startedBy = ''.obs;
  final RxString errorMessage = ''.obs;

  ScreenRecordingManager(this._socketMgr);

  /// Whether the given userId is the one who started the current recording.
  bool isStartedByUser(String userId) =>
      isRecording.value && startedBy.value == userId;

  // ─── API: Check ongoing recording ─────────────────────────────

  /// Start polling for ongoing recording status every 5 seconds.
  void startPolling(String groupId) {
    _currentGroupId = groupId;
    stopPolling();
    // Initial check
    unawaited(checkOngoingRecording(groupId));
    // Then every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(checkOngoingRecording(groupId));
    });
    CallLogger.info(_scope, 'startPolling', {'groupId': groupId});
  }

  /// Stop polling.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Check if there's an ongoing recording for this group.
  /// Sets state accordingly so the UI shows the correct indicator.
  Future<void> checkOngoingRecording(String groupId) async {
    try {
      final apiClient = ApiClient();
      final response = await apiClient.getRequest(
        endPoint: EndPoints.ongoingRecording,
        queryParameters: {'groupId': groupId},
        fromJson: (json) => json,
      );

      if (response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        final data = responseData['data'] is Map
            ? Map<String, dynamic>.from(responseData['data'] as Map)
            : responseData;
        final isOngoing = data['isRecording'] == true;

        if (isOngoing && data['recording'] != null) {
          final recording = Map<String, dynamic>.from(data['recording'] as Map);
          isRecording.value = true;
          recordingId.value = recording['_id']?.toString() ?? '';
          startedBy.value = recording['startedBy']?.toString() ?? '';
          errorMessage.value = '';
          CallLogger.info(_scope, 'checkOngoingRecording:active', {
            'recordingId': recordingId.value,
            'startedBy': startedBy.value,
          });
        } else {
          isRecording.value = false;
          recordingId.value = '';
          startedBy.value = '';
          CallLogger.info(_scope, 'checkOngoingRecording:none');
        }
      }
    } catch (e) {
      CallLogger.warn(_scope, 'checkOngoingRecording:error', {
        'error': e.toString(),
      });
      // Don't block the call flow — just log and continue
    }
  }

  // ─── Socket Event Handlers (called by controller) ──────────────

  void onRecordingStarted(Map<String, dynamic> data) {
    CallLogger.info(_scope, 'onRecordingStarted', data);
    isRecording.value = true;
    recordingId.value = data['recordingId']?.toString() ?? '';
    startedBy.value = data['startedBy']?.toString() ?? '';
    errorMessage.value = '';
  }

  void onRecordingStopped(Map<String, dynamic> data) {
    CallLogger.info(_scope, 'onRecordingStopped', data);
    isRecording.value = false;
    startedBy.value = '';
    recordingId.value = '';
  }

  void onRecordingError(Map<String, dynamic> data) {
    final msg = data['message']?.toString() ?? 'Recording error';
    CallLogger.error(_scope, 'onRecordingError', {'message': msg});
    errorMessage.value = msg;
    isRecording.value = false;
    startedBy.value = '';
    recordingId.value = '';
  }

  // ─── Actions ───────────────────────────────────────────────────

  /// Start recording (admin/superadmin only).
  void startRecording({required String roomId, required String userId}) {
    CallLogger.info(_scope, 'startRecording', {
      'roomId': roomId,
      'userId': userId,
    });
    errorMessage.value = '';
    _socketMgr.emit('BE-start-screen-recording', {
      'roomId': roomId,
      'userId': userId,
    });
  }

  /// Stop recording — only the user who started it can stop.
  void stopRecording({required String roomId, required String userId}) {
    CallLogger.info(_scope, 'stopRecording', {
      'roomId': roomId,
      'userId': userId,
    });
    _socketMgr.emit('BE-stop-screen-recording', {
      'roomId': roomId,
      'userId': userId,
    });
  }

  /// Reset all state.
  void dispose() {
    stopPolling();
    _currentGroupId = '';
    isRecording.value = false;
    recordingId.value = '';
    startedBy.value = '';
    errorMessage.value = '';
    CallLogger.info(_scope, 'dispose');
  }
}
