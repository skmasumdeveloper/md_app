import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// This is the main application widget that initializes Firebase messaging and handles incoming messages.
class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<StatefulWidget> createState() => _Application();
}

class _Application extends State<Application> {
  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'text') {}
  }

  @override
  void initState() {
    super.initState();
    setupInteractedMessage();
  }

  @override
  Widget build(BuildContext context) {
    return const Text("...");
  }
}
