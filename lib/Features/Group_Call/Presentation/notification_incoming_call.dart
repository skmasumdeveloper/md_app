import 'package:flutter/material.dart';

import 'package:cu_app/Commons/app_theme_colors.dart';

// This screen displays an incoming call notification with options to accept or decline the call.
class NotificationIncomingCallScreen extends StatelessWidget {
  final String callerName;
  const NotificationIncomingCallScreen({super.key, required this.callerName});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.blueGrey.shade900,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Incoming Call',
                      style: TextStyle(color: Colors.white70, fontSize: 24)),
                  const SizedBox(height: 16),
                  Text(callerName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Positioned(
              bottom: 80,
              left: 60,
              child: Column(
                children: [
                  RawMaterialButton(
                    onPressed: () {},
                    fillColor: colors.onlineStatus,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(24),
                    child:
                        const Icon(Icons.call, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 8),
                  const Text('Accept', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            Positioned(
              bottom: 80,
              right: 60,
              child: Column(
                children: [
                  RawMaterialButton(
                    onPressed: () {
                      Navigator.pop(
                          context); // simply close incoming call screen
                    },
                    fillColor: Colors.red,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(24),
                    child: const Icon(Icons.call_end,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 8),
                  const Text('Decline', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
