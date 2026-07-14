import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_scope.dart';
import 'package:forja/shared/design/src/shell_profile.dart';

/// Layout constants for the Settings category hub (RFC-033).
abstract final class SettingsTokens {
  /// Below this width (or always on TV), use list → push instead of sidebar.
  static const double splitMinWidth = 900;

  static const double sidebarWidth = 260;
  static const double detailMaxWidth = 720;
  static const double categoryTileRadius = 10;
  static const double groupRadius = 12;
  static const double rowMinHeight = 56;
  static const double groupSpacing = 24;
  static const double pagePadding = 20;
  static const double groupLabelSize = 11;
  static const double categoryTitleSize = 15;
  static const double pageTitleSize = 22;

  /// True when Settings should show the split sidebar layout.
  static bool useSplitLayout(BuildContext context) {
    final scope = ShellScope.maybeOf(context);
    if (scope != null && scope.profile == ShellProfile.tv) return false;
    return MediaQuery.sizeOf(context).width >= splitMinWidth;
  }
}
