import 'package:flutter/material.dart';

/// Desktop hybrid: hide D-pad focus chrome while the pointer is in use.
class ShellKeyboardFocusScope extends InheritedNotifier<ValueNotifier<bool>> {
  const ShellKeyboardFocusScope({
    required ValueNotifier<bool> visibility,
    required super.child,
    super.key,
  }) : super(notifier: visibility);

  static bool chromeVisibleOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ShellKeyboardFocusScope>();
    return scope?.notifier?.value ?? false;
  }
}
