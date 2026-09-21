import 'package:flutter/material.dart';

import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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

/// Desktop + Android TV Material auto-scrollbar paints grey `onSurface` thumbs
/// by default. Replace with the green [RawScrollbar] so every scrollable matches
/// Providers / Live TV.
class ForjaScrollBehavior extends MaterialScrollBehavior {
  const ForjaScrollBehavior();

  static bool _androidTvScrollbars(BuildContext context) {
    if (ShellTokens.isAndroidTvDevice) return true;
    if (ShellPaintScope.usesTvDensityOf(context)) return true;
    return ShellTokens.isTvLayout(context);
  }

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
            return _greenScrollbar(
              controller: details.controller!,
              child: child,
            );
          case TargetPlatform.android:
            if (!_androidTvScrollbars(context)) return child;
            assert(details.controller != null);
            return _greenScrollbar(
              controller: details.controller!,
              // Leanback: keep the thumb visible so D-pad position is obvious.
              thumbVisibility: true,
              trackVisibility: true,
              interactive: false,
              child: child,
            );
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
            return child;
        }
    }
  }

  static Widget _greenScrollbar({
    required ScrollController controller,
    required Widget child,
    bool? thumbVisibility,
    bool? trackVisibility,
    bool interactive = true,
  }) {
    return RawScrollbar(
      controller: controller,
      thickness: ForjaScrollbarStyle.thickness,
      radius: ForjaScrollbarStyle.radius,
      mainAxisMargin: ForjaScrollbarStyle.mainAxisMargin,
      crossAxisMargin: ForjaScrollbarStyle.crossAxisMargin,
      thumbColor: ForjaScrollbarStyle.thumbColor,
      trackColor: ForjaScrollbarStyle.trackColor,
      trackBorderColor: Colors.transparent,
      thumbVisibility: thumbVisibility,
      trackVisibility: trackVisibility,
      interactive: interactive,
      child: child,
    );
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
