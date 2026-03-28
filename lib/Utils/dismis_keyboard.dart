import 'package:flutter/material.dart';

// This widget dismisses the keyboard when tapping outside of a focused text field.
class DismissKeyBoard extends StatelessWidget {
  final Widget child;
  const DismissKeyBoard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if ((!currentFocus.hasPrimaryFocus &&
            currentFocus.focusedChild != null)) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: child,
    );
  }
}
