import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:flutter/material.dart';

// This widget displays an alert dialog to confirm the deletion of a member.
class DeleteMemberAlertDialog extends StatelessWidget {
  final VoidCallback onDelete;
  final bool isLoading;
  const DeleteMemberAlertDialog(
      {super.key, required this.onDelete, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AlertDialog(
      backgroundColor: colors.cardBg,
      title: Text(
        "Are you sure to remove the member?",
        style: TextStyle(color: colors.offlineStatus),
      ),
      content: isLoading
          ? const SizedBox(
              height: 48,
              child: Center(
                child: CircularProgressIndicator.adaptive(),
              ),
            )
          : null,
      actions: isLoading
          ? const <Widget>[]
          : <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: onDelete,
                child: Text(
                  'Delete',
                  style: TextStyle(color: colors.offlineStatus),
                ),
              ),
            ],
    );
  }
}
