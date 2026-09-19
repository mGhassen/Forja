import 'package:flutter/material.dart';

import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Shared green thumb chrome — matches Live TV / Providers lists.
abstract final class ForjaScrollbarStyle {
  static const double thickness = 3;
  static const Radius radius = Radius.circular(2);
  static const double mainAxisMargin = 6;
  static const double crossAxisMargin = 2;

  static Color get thumbColor =>
      ForjaShellColors.brandGreen.withValues(alpha: 0.55);
  static Color get trackColor => Colors.white.withValues(alpha: 0.08);

  /// Themes Material [Scrollbar] (settings, dialogs) to the same green.
  static ScrollbarThemeData get theme => ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(thickness),
        radius: radius,
        crossAxisMargin: crossAxisMargin,
        mainAxisMargin: mainAxisMargin,
        thumbColor: WidgetStatePropertyAll(thumbColor),
        trackColor: WidgetStatePropertyAll(trackColor),
        trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      );
}

/// Desktop Material auto-scrollbar paints grey `onSurface` thumbs by default.
/// Replace with the green RawScrollbar so every scrollable matches Providers.
class ForjaScrollBehavior extends MaterialScrollBehavior {
  const ForjaScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        switch (getPlatform(context)) {
          case TargetPlatform.linux:
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
            assert(details.controller != null);
            return RawScrollbar(
              controller: details.controller,
              thickness: ForjaScrollbarStyle.thickness,
              radius: ForjaScrollbarStyle.radius,
              mainAxisMargin: ForjaScrollbarStyle.mainAxisMargin,
              crossAxisMargin: ForjaScrollbarStyle.crossAxisMargin,
              thumbColor: ForjaScrollbarStyle.thumbColor,
              trackColor: ForjaScrollbarStyle.trackColor,
              trackBorderColor: Colors.transparent,
              child: child,
            );
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
            return child;
        }
    }
  }
}

/// Under an explicit [Scrollbar] / [RawScrollbar], kill the inherited auto thumb
/// so desktop does not paint two bars.
Widget forjaSuppressAutoScrollbar({
  required BuildContext context,
  required Widget child,
}) {
  return ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: child,
  );
}
