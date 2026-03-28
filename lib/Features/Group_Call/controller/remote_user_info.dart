import 'package:flutter_webrtc/flutter_webrtc.dart';

// This class holds information about a remote user in a group call, including their video renderer, socket ID, original user ID, full name, and a unique connection ID.
class RemoteUserInfo {
  final RTCVideoRenderer renderer;
  final String socketId;
  final String originalUserId;
  final String userOrgFullName;
  final String connectionId; // Unique identifier for each connection

  RemoteUserInfo({
    required this.renderer,
    required this.socketId,
    required this.originalUserId,
    required this.userOrgFullName,
    required this.connectionId,
  });
}
