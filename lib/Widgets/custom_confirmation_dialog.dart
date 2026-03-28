import 'package:flutter/material.dart';

import '../Commons/app_theme_colors.dart';

enum ViewDialogsAction { Confirm, Cancel }

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String body;
  final String? negativeButtonLabel;
  final String? positiveButtonLabel;
  final VoidCallback onPressedPositiveButton;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.body,
    required this.onPressedPositiveButton,
    this.negativeButtonLabel = 'Cancel',
    this.positiveButtonLabel = 'Confirm',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AlertDialog(
      backgroundColor: colors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(title, style: TextStyle(color: colors.textPrimary)),
      content: Text(body, style: TextStyle(color: colors.textSecondary)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(ViewDialogsAction.Cancel),
          child: Text(
            negativeButtonLabel!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TextButton(
          onPressed: onPressedPositiveButton,
          child: Text(
            positiveButtonLabel!,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
