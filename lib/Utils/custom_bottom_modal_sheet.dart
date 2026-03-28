import 'package:flutter/material.dart';

import '../Commons/app_sizes.dart';

// This widget provides a custom bottom sheet with a title and a child widget.
class CustomBottomSheet extends StatelessWidget {
  final Widget child;
  final String title;

  const CustomBottomSheet({Key? key, required this.child, required this.title})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return showCustomBottomSheet(context, title, child);
  }
}

showCustomBottomSheet(BuildContext context, String title, Widget child) {
  showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppSizes.cardCornerRadius),
            topRight: Radius.circular(AppSizes.cardCornerRadius)),
      ),
      context: context,
      builder: (context) {
        return child;
      });
}
