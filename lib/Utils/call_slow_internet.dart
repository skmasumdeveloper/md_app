import 'package:flutter/material.dart';

// This function shows a dialog when the internet connection is slow, prompting the user to check their connection before retrying the call.
Future<void> showSlowInternetDialog({
  required BuildContext context,
  required String groupId,
  required bool isVideoCall,
  required Function(String groupId, {required bool isVideoCall})
      outgoingCallEmit,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false, // Prevent closing the dialog by tapping outside
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text("Couldn't place call"),
        content: Text(
          "Make sure you have a stable internet connection and try again.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Just close dialog
            },
            child: const Text("Ok"),
          ),
        ],
      );
    },
  );
}
