import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
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
  /// (e.g. players, media details on the root navigator).
  ///
  /// Windows/Linux: these routes cover the shell caption, so the strip also
  /// paints minimize / maximize / close while windowed and [showCaption].
  /// Place it last in the stack so gradients above it do not eat the clicks.
  static Widget overlayDragStrip({bool showCaption = true}) {
    if (!isDesktop) return const SizedBox.shrink();

    if (Platform.isMacOS) {
      return const Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: kMacTitleBarHeight,
        child: DragToMoveArea(
          child: SizedBox.expand(),
        ),
      );
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: kWindowCaptionHeight,
      child: _OverlayWindowCaption(visible: showCaption),
    );
  }

  /// Wrap player / overlay chrome so drag + double-click maximize work on the
  /// title region (buttons as children still receive taps).
  static Widget wrapDragMove(Widget child) {
    if (!isDesktop) return child;
    return DragToMoveArea(child: child);
  }
}

/// Drag strip plus a fading window caption, hidden in OS fullscreen.
class _OverlayWindowCaption extends StatefulWidget {
  const _OverlayWindowCaption({required this.visible});

  final bool visible;

  @override
  State<_OverlayWindowCaption> createState() => _OverlayWindowCaptionState();
}

class _OverlayWindowCaptionState extends State<_OverlayWindowCaption>
    with WindowListener {
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_syncFullscreen());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncFullscreen() async {
    final full = await windowManager.isFullScreen();
    if (!mounted || full == _fullscreen) return;
    setState(() => _fullscreen = full);
  }

  @override
  void onWindowEnterFullScreen() => setState(() => _fullscreen = true);

  @override
  void onWindowLeaveFullScreen() => setState(() => _fullscreen = false);

  @override
  Widget build(BuildContext context) {
    final show = widget.visible && !_fullscreen;
    return Stack(
      fit: StackFit.expand,
      children: [
        const DragToMoveArea(child: SizedBox.expand()),
        AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: ShellTokens.playerChromeFade,
          child: IgnorePointer(
            ignoring: !show,
            child: const WindowCaption(
              brightness: Brightness.dark,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
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
