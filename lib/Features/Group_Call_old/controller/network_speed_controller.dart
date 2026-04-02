import 'dart:io';
import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class NetworkSpeedController {
  // Singleton pattern (optional)
  static final NetworkSpeedController _instance =
      NetworkSpeedController._internal();
  factory NetworkSpeedController() => _instance;
  NetworkSpeedController._internal();

  // Returns speed in Mbps (megabits per second)
  Future<double> checkInternetSpeed() async {
    final url = Uri.parse(dotenv.env['API_BASE_URL'] ??
        'https://google.com/'); // Use a reliable test file
    final stopwatch = Stopwatch()..start();
    int bytes = 0;

    try {
      final request = await HttpClient().getUrl(url);
      final response = await request.close();
      await for (var chunk in response) {
        bytes += chunk.length;
        if (bytes > 2 * 1024 * 1024)
          break; // Only download first 2MB for quick test
      }
      stopwatch.stop();
      final seconds = stopwatch.elapsedMilliseconds / 10000;
      final mbps = (bytes * 8) / (seconds * 1000 * 1000); // bits/sec to Mbps

      return mbps;
    } catch (_) {
      return 0.0;
    }
  }

  // Simple threshold check for video call (e.g., 1.5 Mbps minimum)
  Future<bool> isSpeedStable({double minMbps = 1.5}) async {
    final speed = await checkInternetSpeed();
    return speed >= minMbps;
  }
}
