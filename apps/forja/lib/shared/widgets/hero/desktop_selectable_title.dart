import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

bool shellDesktopTextSelect(BuildContext context) {
  final profile =
      ShellScope.maybeOf(context)?.profile ?? resolveShellProfile(context);
  return profile == ShellProfile.desktop;
}

/// Desktop-only selection wrapper for title text.
Widget wrapDesktopSelectableTitle(BuildContext context, Widget child) {
  if (!shellDesktopTextSelect(context)) return child;
  return SelectionArea(child: child);
}

/// Decorative title layers that must not join the selection.
Widget desktopTitleSelectionGhost(Widget child) =>
    SelectionContainer.disabled(child: child);
