import 'package:flutter/material.dart';
import '../Commons/app_sizes.dart';

ScaffoldMessengerState customSnackBar(
  BuildContext context,
  String msg,
) {
  return ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: AppSizes.elevation0,
          content: Text(
            msg,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: Colors.white),
          )),
    );
}
