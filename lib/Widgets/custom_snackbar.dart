import 'package:flutter/material.dart';

import '../Commons/app_sizes.dart';

// This widget provides a custom snackbar that displays messages with a specific background and content color.
class CustomSnackBar extends StatelessWidget {
  final String content;
  final Color backgroundColor;
  final Color contentColor;

  const CustomSnackBar(
      {Key? key,
      required this.content,
      required this.backgroundColor,
      required this.contentColor})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SnackBar(
      duration: const Duration(milliseconds: 3000),
      backgroundColor: backgroundColor,
      content: Text(
        content,
        style: TextStyle(
            color: contentColor,
            fontWeight: FontWeight.w500,
            fontSize: AppSizes.bodyText1),
      ),
    );
  }
}
