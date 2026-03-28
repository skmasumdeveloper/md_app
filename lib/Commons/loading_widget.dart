import 'package:flutter/material.dart';

BuildContext? _dialogContext;

// Function to show a loading dialog with a message
void showConnectingDialog(BuildContext context, String? title) {
  if (_dialogContext != null) return; // Dialog already shown

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      _dialogContext = ctx;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title ?? "Please wait, connecting the call...",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Function to hide the loading dialog
void hideConnectingDialog() {
  if (_dialogContext != null) {
    Navigator.of(_dialogContext!).pop();
    _dialogContext = null;
  }
}
