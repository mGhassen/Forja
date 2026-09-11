import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// macOS title-bar drag strip height (traffic lights float above the sidebar).
const double kMacTitleBarHeight = 34;

/// Horizontal space for the macOS traffic-light cluster (hidden title bar).
const double kMacLeadingInset = 78;

class DesktopWindowChrome {
  DesktopWindowChrome._();

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static double topInset(BuildContext context) {
    if (!isDesktop) return 0;
    if (Platform.isMacOS) return kMacTitleBarHeight;
    return kWindowCaptionHeight;
  }

  /// Left inset so panel chrome clears macOS traffic lights.
  static double leadingInset(BuildContext context) {
    if (!Platform.isMacOS) return 0;
    return kMacLeadingInset;
  }

  /// Wraps the main shell: hidden macOS title bar with drag strip, or a
  /// custom caption on Windows/Linux.
  static Widget wrapShell({required Widget child}) {
    if (!isDesktop) return child;

    return _DesktopShellFrame(child: child);
  }

  /// Drag + double-tap maximize strip for routes pushed above [wrapShell]
  /// (e.g. media details on the root navigator).
  static Widget overlayDragStrip() {
    if (!isDesktop) return const SizedBox.shrink();

    final height = Platform.isMacOS ? kMacTitleBarHeight : kWindowCaptionHeight;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: const DragToMoveArea(
        child: SizedBox.expand(),
      ),
    );
  }

  /// Wrap player / overlay chrome so drag + double-click maximize work on the
  /// title region (buttons as children still receive taps).
  static Widget wrapDragMove(Widget child) {
    if (!isDesktop) return child;
    return DragToMoveArea(child: child);
  }
}

class _DesktopShellFrame extends StatelessWidget {
  const _DesktopShellFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: MediaQuery.of(context).padding.copyWith(
            top: DesktopWindowChrome.topInset(context),
          ),
        ),
        child: Stack(
          children: [
            child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: kMacTitleBarHeight,
              child: DragToMoveArea(
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: kWindowCaptionHeight,
          child: WindowCaption(
            brightness: Brightness.dark,
            backgroundColor: AppTheme.current.bgDark,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
