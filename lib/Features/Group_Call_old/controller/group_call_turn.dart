import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// This class provides the configuration for TURN/STUN servers used in group calls.
class GroupCallTurn {
  static bool get useStunTurn {
    final raw = (dotenv.env['USE_STUN_TURN'] ?? 'true').trim().toLowerCase();
    return raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on';
  }

  static Map<String, dynamic> getOptimalIceConfig() {
    final username = dotenv.env['TURN_USERNAME'];
    final credential = dotenv.env['TURN_CREDENTIAL'];
    final shouldUseStunTurn = useStunTurn;

    debugPrint('[TURN] Loading ICE config from .env:');
    debugPrint('[TURN]   USE_STUN_TURN=$shouldUseStunTurn');
    debugPrint('[TURN]   STUN_URL=${dotenv.env['STUN_URL']}');
    debugPrint('[TURN]   TURN_URL_1=${dotenv.env['TURN_URL_1']}');
    debugPrint('[TURN]   TURN_URL_UDP=${dotenv.env['TURN_URL_UDP']}');
    debugPrint('[TURN]   TURN_URL_TCP=${dotenv.env['TURN_URL_TCP']}');
    debugPrint('[TURN]   TURN_URL_2=${dotenv.env['TURN_URL_2']}');
    debugPrint('[TURN]   TURN_URL_443_UDP=${dotenv.env['TURN_URL_443_UDP']}');
    debugPrint('[TURN]   TURN_URL_443_TCP=${dotenv.env['TURN_URL_443_TCP']}');
    debugPrint('[TURN]   TURN_USERNAME=${username != null ? "(set)" : "NULL"}');
    debugPrint(
        '[TURN]   TURN_CREDENTIAL=${credential != null ? "(set)" : "NULL"}');
    debugPrint(
        '[TURN]   MEDIASOUP_ANNOUNCED_IP=${dotenv.env['MEDIASOUP_ANNOUNCED_IP']}');

    final iceServers = shouldUseStunTurn
        ? [
            {
              'urls': dotenv.env['STUN_URL'],
            },
            {
              'urls': dotenv.env['TURN_URL_1'],
              'username': username,
              'credential': credential,
            },
            {
              'urls': dotenv.env['TURN_URL_UDP'],
              'username': username,
              'credential': credential,
            },
            {
              'urls': dotenv.env['TURN_URL_TCP'],
              'username': username,
              'credential': credential,
            },
            {
              'urls': dotenv.env['TURN_URL_2'],
              'username': username,
              'credential': credential,
            },
            {
              'urls': dotenv.env['TURN_URL_443_UDP'],
              'username': username,
              'credential': credential,
            },
            {
              'urls': dotenv.env['TURN_URL_443_TCP'],
              'username': username,
              'credential': credential,
            },
          ]
        : <Map<String, dynamic>>[];

    return {
      'iceServers': iceServers,
      'sdpSemantics': dotenv.env['SDP_SEMANTICS'],
      'iceCandidatePoolSize': int.tryParse(dotenv.env['ICE_POOL_SIZE'] ?? '0'),
      'iceTransportPolicy': dotenv.env['ICE_POLICY'],
      'mediasoupAnnouncedIp': dotenv.env['MEDIASOUP_ANNOUNCED_IP'],
    };
  }

  /// Get the MediaSoup SFU announced IP.
  static String? get announcedIp => dotenv.env['MEDIASOUP_ANNOUNCED_IP'];
}
