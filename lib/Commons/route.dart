import 'package:flutter/cupertino.dart';

// This file contains the CustomPageRoute class which defines a custom page transition animation for navigation in the application.
class CustomPageRoute extends PageRouteBuilder {
  final Widget widget;

  CustomPageRoute({required this.widget})
      : super(pageBuilder: (BuildContext context, Animation<double> animation,
            Animation<double> secondaryAnimation) {
          return widget;
        }, transitionsBuilder: (BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.linear;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        });
}

// This extension provides custom navigation methods for the BuildContext.
extension CustomNavigator on BuildContext {
  Future<dynamic> push(Widget page) async {
    Navigator.of(this, rootNavigator: true)
        .push(CupertinoPageRoute(maintainState: true, builder: (_) => page));
  }

  //clear current navigation stack
  Future<dynamic> pushReplacement(Widget page) async {
    Navigator.of(this, rootNavigator: true).pushReplacement(
        CupertinoPageRoute(maintainState: true, builder: (_) => page));
  }

  //clear all the navigation history stack
  Future<dynamic> pushAndRemoveUntil(Widget page) async {
    Navigator.of(this, rootNavigator: true).pushAndRemoveUntil(
        CupertinoPageRoute(maintainState: true, builder: (_) => page),
        (route) => false);
  }

// This method pops the current page from the navigation stack.
  void pop(Widget page, [result]) async {
    return Navigator.of(this).pop(result);
  }
}
