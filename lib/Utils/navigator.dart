import 'package:flutter/material.dart';

// This function navigates to a specified route using the provided context.

doNavigator({required Widget route, required BuildContext context}) {
  Navigator.push(context, MaterialPageRoute(builder: (context) => route));
}

doNavigateWithPushName({required Widget route, required BuildContext context}) {
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => route));
}

backFromPrevious({required BuildContext context}) {
  Navigator.pop(context);
}

doNavigateWithReplacement(
    {required Widget route, required BuildContext context}) {
  Navigator.pushAndRemoveUntil(
      context, MaterialPageRoute(builder: (_) => route), (route) => false);
}

backFromPreviousScreen({required BuildContext context}) {
  return Navigator.pop(context);
}
