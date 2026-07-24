import 'package:flutter/material.dart';

/// Layout constants for the Settings category hub (RFC-033).
abstract final class SettingsTokens {
  /// Below this width, use list → push instead of sidebar.
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
  /// Desktop / wide and Android TV (1080p+) use the same hub chrome.
  static bool useSplitLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= splitMinWidth;
  }
}
