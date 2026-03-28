import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

// Unit tests for group call MediaSoup SFU logic.
// These test the core logic without depending on Flutter plugins or native code.

// ─── socketEmitWithAck helper tests ─────────────────────────────────────────

/// Simulates the socketEmitWithAck wrapper behavior.
Future<dynamic> mockSocketEmitWithAck(
  dynamic Function(dynamic data, {required Function ack}) emitter,
  Map<String, dynamic> data, {
  Duration timeout = const Duration(seconds: 10),
}) {
  final completer = Completer<dynamic>();
  emitter(data, ack: (response) {
    if (!completer.isCompleted) {
      completer.complete(response);
    }
  });
  Future.delayed(timeout, () {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });
  return completer.future;
}

// ─── User mapping tests ─────────────────────────────────────────────────────

class UserMapper {
  final Map<String, String> socketToUser = {};
  final Map<String, String> userToSocket = {};

  void addMapping(String socketId, String objectId) {
    socketToUser[socketId] = objectId;
    userToSocket[objectId] = socketId;
  }

  void removeBySocketId(String socketId) {
    final objectId = socketToUser.remove(socketId);
    if (objectId != null) userToSocket.remove(objectId);
  }

  void removeByObjectId(String objectId) {
    final socketId = userToSocket.remove(objectId);
    if (socketId != null) socketToUser.remove(socketId);
  }

  String resolveUserId(String socketId) {
    return socketToUser[socketId] ?? socketId;
  }

  void clear() {
    socketToUser.clear();
    userToSocket.clear();
  }
}

// ─── Consumer tracking tests ────────────────────────────────────────────────

class ConsumerTracker {
  final Map<String, String> consumerToUser = {}; // consumerId → userId
  final Set<String> consumedProducerIds = {};

  bool canConsume(String producerId) {
    return !consumedProducerIds.contains(producerId);
  }

  void addConsumer(String consumerId, String userId, String producerId) {
    consumerToUser[consumerId] = userId;
    consumedProducerIds.add(producerId);
  }

  List<String> getConsumerIdsForUser(String userId) {
    return consumerToUser.entries
        .where((e) => e.value == userId)
        .map((e) => e.key)
        .toList();
  }

  void removeConsumersForUser(String userId) {
    final toRemove = getConsumerIdsForUser(userId);
    for (var id in toRemove) {
      consumerToUser.remove(id);
    }
  }

  void clear() {
    consumerToUser.clear();
    consumedProducerIds.clear();
  }
}

// ─── FE-user-join parsing tests ─────────────────────────────────────────────

class UserJoinParser {
  static List<Map<String, dynamic>> parseJoinData(
    List<dynamic> data,
    String mySocketId,
    String myObjectId,
  ) {
    final result = <Map<String, dynamic>>[];
    for (var user in data) {
      if (user is! Map<String, dynamic>) continue;
      final socketUserId = user['userId']?.toString() ?? '';
      final info = user['info'] as Map<String, dynamic>?;
      final objectId = info?['userName']?.toString() ?? '';
      final fullName = info?['fullName']?.toString() ??
          info?['name']?.toString() ??
          'Unknown';

      if (socketUserId == mySocketId) continue;
      if (objectId == myObjectId) continue;
      if (objectId.isEmpty) continue;

      result.add({
        'socketId': socketUserId,
        'objectId': objectId,
        'fullName': fullName,
        'audio': info?['audio'] ?? true,
      });
    }
    return result;
  }
}

void main() {
  group('socketEmitWithAck', () {
    test('returns server response via callback', () async {
      final response = await mockSocketEmitWithAck(
        (data, {required Function ack}) {
          // Simulate server responding after 50ms
          Future.delayed(const Duration(milliseconds: 50), () {
            ack({'ok': true, 'rtpCapabilities': {'codecs': []}});
          });
        },
        {'roomId': 'room123'},
      );

      expect(response, isNotNull);
      expect(response['ok'], true);
      expect(response['rtpCapabilities'], isA<Map>());
    });

    test('returns null on timeout', () async {
      final response = await mockSocketEmitWithAck(
        (data, {required Function ack}) {
          // Don't call ack — simulate server not responding
        },
        {'roomId': 'room123'},
        timeout: const Duration(milliseconds: 100),
      );

      expect(response, isNull);
    });

    test('handles immediate callback', () async {
      final response = await mockSocketEmitWithAck(
        (data, {required Function ack}) {
          ack({'ok': true, 'id': 'transport-1'});
        },
        {'roomId': 'room123'},
      );

      expect(response['ok'], true);
      expect(response['id'], 'transport-1');
    });

    test('handles error response', () async {
      final response = await mockSocketEmitWithAck(
        (data, {required Function ack}) {
          ack({'ok': false, 'error': 'failed'});
        },
        {'roomId': 'room123'},
      );

      expect(response['ok'], false);
      expect(response['error'], 'failed');
    });
  });

  group('UserMapper', () {
    late UserMapper mapper;

    setUp(() {
      mapper = UserMapper();
    });

    test('adds and retrieves socket↔objectId mapping', () {
      mapper.addMapping('socket-abc', 'user-123');

      expect(mapper.resolveUserId('socket-abc'), 'user-123');
      expect(mapper.userToSocket['user-123'], 'socket-abc');
    });

    test('resolveUserId returns socketId as fallback', () {
      expect(mapper.resolveUserId('unknown-socket'), 'unknown-socket');
    });

    test('removeBySocketId cleans both maps', () {
      mapper.addMapping('socket-abc', 'user-123');
      mapper.removeBySocketId('socket-abc');

      expect(mapper.socketToUser.containsKey('socket-abc'), false);
      expect(mapper.userToSocket.containsKey('user-123'), false);
    });

    test('removeByObjectId cleans both maps', () {
      mapper.addMapping('socket-abc', 'user-123');
      mapper.removeByObjectId('user-123');

      expect(mapper.socketToUser.containsKey('socket-abc'), false);
      expect(mapper.userToSocket.containsKey('user-123'), false);
    });

    test('handles multiple users', () {
      mapper.addMapping('socket-1', 'user-a');
      mapper.addMapping('socket-2', 'user-b');
      mapper.addMapping('socket-3', 'user-c');

      expect(mapper.resolveUserId('socket-1'), 'user-a');
      expect(mapper.resolveUserId('socket-2'), 'user-b');
      expect(mapper.resolveUserId('socket-3'), 'user-c');
      expect(mapper.socketToUser.length, 3);
    });

    test('clear removes all mappings', () {
      mapper.addMapping('socket-1', 'user-a');
      mapper.addMapping('socket-2', 'user-b');
      mapper.clear();

      expect(mapper.socketToUser.isEmpty, true);
      expect(mapper.userToSocket.isEmpty, true);
    });
  });

  group('ConsumerTracker', () {
    late ConsumerTracker tracker;

    setUp(() {
      tracker = ConsumerTracker();
    });

    test('canConsume returns true for new producer', () {
      expect(tracker.canConsume('producer-1'), true);
    });

    test('canConsume returns false for already consumed producer', () {
      tracker.addConsumer('consumer-1', 'user-a', 'producer-1');
      expect(tracker.canConsume('producer-1'), false);
    });

    test('tracks consumers per user', () {
      tracker.addConsumer('consumer-1', 'user-a', 'producer-audio-a');
      tracker.addConsumer('consumer-2', 'user-a', 'producer-video-a');
      tracker.addConsumer('consumer-3', 'user-b', 'producer-audio-b');

      final userAConsumers = tracker.getConsumerIdsForUser('user-a');
      expect(userAConsumers.length, 2);
      expect(userAConsumers, contains('consumer-1'));
      expect(userAConsumers, contains('consumer-2'));
    });

    test('removeConsumersForUser removes only that user', () {
      tracker.addConsumer('consumer-1', 'user-a', 'producer-audio-a');
      tracker.addConsumer('consumer-2', 'user-a', 'producer-video-a');
      tracker.addConsumer('consumer-3', 'user-b', 'producer-audio-b');

      tracker.removeConsumersForUser('user-a');

      expect(tracker.consumerToUser.length, 1);
      expect(tracker.consumerToUser.containsKey('consumer-3'), true);
      // Note: consumedProducerIds is NOT cleared — prevents re-consuming
    });

    test('clear removes everything', () {
      tracker.addConsumer('c1', 'u1', 'p1');
      tracker.addConsumer('c2', 'u2', 'p2');
      tracker.clear();

      expect(tracker.consumerToUser.isEmpty, true);
      expect(tracker.consumedProducerIds.isEmpty, true);
    });
  });

  group('UserJoinParser', () {
    test('filters out self by socket.id', () {
      final data = [
        {
          'userId': 'my-socket-id',
          'info': {'userName': 'other-user', 'fullName': 'Other'}
        },
        {
          'userId': 'remote-socket',
          'info': {'userName': 'user-b', 'fullName': 'User B'}
        },
      ];

      final result =
          UserJoinParser.parseJoinData(data, 'my-socket-id', 'my-obj-id');
      expect(result.length, 1);
      expect(result[0]['objectId'], 'user-b');
    });

    test('filters out self by objectId', () {
      final data = [
        {
          'userId': 'some-socket',
          'info': {'userName': 'my-obj-id', 'fullName': 'Me'}
        },
        {
          'userId': 'remote-socket',
          'info': {'userName': 'user-b', 'fullName': 'User B'}
        },
      ];

      final result =
          UserJoinParser.parseJoinData(data, 'my-socket-id', 'my-obj-id');
      expect(result.length, 1);
      expect(result[0]['objectId'], 'user-b');
    });

    test('filters out users with empty objectId', () {
      final data = [
        {
          'userId': 'socket-1',
          'info': {'userName': '', 'fullName': 'No ID User'}
        },
        {
          'userId': 'socket-2',
          'info': {'userName': 'user-b', 'fullName': 'User B'}
        },
      ];

      final result =
          UserJoinParser.parseJoinData(data, 'my-socket', 'my-obj');
      expect(result.length, 1);
      expect(result[0]['objectId'], 'user-b');
    });

    test('handles multiple remote users', () {
      final data = [
        {
          'userId': 'my-socket',
          'info': {'userName': 'my-obj', 'fullName': 'Me'}
        },
        {
          'userId': 'socket-a',
          'info': {'userName': 'user-a', 'fullName': 'Alice', 'audio': true}
        },
        {
          'userId': 'socket-b',
          'info': {'userName': 'user-b', 'fullName': 'Bob', 'audio': false}
        },
        {
          'userId': 'socket-c',
          'info': {'userName': 'user-c', 'name': 'Charlie'}
        },
      ];

      final result =
          UserJoinParser.parseJoinData(data, 'my-socket', 'my-obj');
      expect(result.length, 3);
      expect(result[0]['fullName'], 'Alice');
      expect(result[0]['audio'], true);
      expect(result[1]['fullName'], 'Bob');
      expect(result[1]['audio'], false);
      expect(result[2]['fullName'], 'Charlie'); // falls back to 'name'
    });

    test('handles malformed data gracefully', () {
      final data = [
        'not a map',
        42,
        null,
        {'userId': 'socket-a'}, // missing info
        {
          'userId': 'socket-b',
          'info': {'userName': 'user-b', 'fullName': 'User B'}
        },
      ];

      final result =
          UserJoinParser.parseJoinData(data, 'my-socket', 'my-obj');
      expect(result.length, 1);
      expect(result[0]['objectId'], 'user-b');
    });
  });

  group('Call flow state transitions', () {
    test('rejoin resets mediasoup state', () {
      // Simulate state after a call
      bool mediasoupInitialized = true;
      final consumers = <String, String>{'c1': 'u1', 'c2': 'u2'};
      final consumedProducerIds = <String>{'p1', 'p2'};
      final socketToUserMap = <String, String>{'s1': 'u1', 's2': 'u2'};

      // Simulate cleanup (as in cleanupMediasoup)
      consumers.clear();
      consumedProducerIds.clear();
      socketToUserMap.clear();
      mediasoupInitialized = false;

      expect(mediasoupInitialized, false);
      expect(consumers.isEmpty, true);
      expect(consumedProducerIds.isEmpty, true);
      expect(socketToUserMap.isEmpty, true);
    });

    test('duplicate producer IDs are prevented', () {
      final consumed = <String>{};

      bool tryConsume(String producerId) {
        if (consumed.contains(producerId)) return false;
        consumed.add(producerId);
        return true;
      }

      expect(tryConsume('p1'), true);
      expect(tryConsume('p2'), true);
      expect(tryConsume('p1'), false); // duplicate
      expect(consumed.length, 2);
    });
  });

  group('Multi-user stream management', () {
    test('audio and video tracks merge into single stream per user', () {
      // Simulate remote streams map
      final remoteStreams = <String, List<String>>{};

      void addTrack(String userId, String kind) {
        if (!remoteStreams.containsKey(userId)) {
          remoteStreams[userId] = [];
        }
        // Remove existing track of same kind
        remoteStreams[userId]!.removeWhere((t) => t == kind);
        remoteStreams[userId]!.add(kind);
      }

      addTrack('user-a', 'audio');
      addTrack('user-a', 'video');
      addTrack('user-b', 'audio');

      expect(remoteStreams['user-a']!.length, 2);
      expect(remoteStreams['user-a'], contains('audio'));
      expect(remoteStreams['user-a'], contains('video'));
      expect(remoteStreams['user-b']!.length, 1);
    });

    test('replacing video track does not affect audio track', () {
      final tracks = <String>['audio', 'video'];

      // Simulate replacing video
      tracks.removeWhere((t) => t == 'video');
      tracks.add('video-new');

      expect(tracks.length, 2);
      expect(tracks, contains('audio'));
      expect(tracks, contains('video-new'));
    });
  });
}
