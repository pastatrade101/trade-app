import 'package:flutter/material.dart';

class AppToast {
  static void success(BuildContext context, String message) {
    _show(context, message, background: Colors.green.shade600);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, background: Colors.red.shade600);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, background: Colors.blueGrey.shade600);
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color background,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
