import 'package:flutter/material.dart';

// This widget displays a count of messages in a circular badge format, typically used to indicate unread messages or notifications.
class MessageCountWidget extends StatelessWidget {
  final int messageCount;

  const MessageCountWidget({super.key, required this.messageCount});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 10, // Adjust size of the circle
      backgroundColor: Theme.of(context).primaryColor, // Set background to blue
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Text(
            '$messageCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16, // Adjust font size
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
