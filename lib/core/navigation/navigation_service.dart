import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> popToHome() async {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Pop everything until the first route (dashboard)
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  static Future<dynamic> navigateTo(Widget page) {
    return navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (context) => page),
    );
  }
}

