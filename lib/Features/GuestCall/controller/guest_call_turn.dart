import 'package:flutter_dotenv/flutter_dotenv.dart';

// TURN/STUN config for guest calls.
class GuestCallTurn {
  static Map<String, dynamic> getOptimalIceConfig() {
    final username = dotenv.env['TURN_USERNAME'];
    final credential = dotenv.env['TURN_CREDENTIAL'];

    return {
      'iceServers': [
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
      ],
      'sdpSemantics': dotenv.env['SDP_SEMANTICS'],
      'iceCandidatePoolSize': int.tryParse(dotenv.env['ICE_POOL_SIZE'] ?? '0'),
      'iceTransportPolicy': dotenv.env['ICE_POLICY'],
    };
  }
}
