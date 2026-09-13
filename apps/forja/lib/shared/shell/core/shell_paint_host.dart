import 'package:flutter/material.dart';
import 'package:forja/shared/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shared/shell/core/forja_shell_metrics.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

ShellPaintFocusableTap? _registeredFocusableTap;
ShellPaintTvRowWrap? _registeredTvRow;
Widget Function(Widget child)? _registeredHorizontalWrap;
bool Function(ScrollNotification notification)? _registeredAbsorbHorizontal;
bool Function(KeyEvent event)? _registeredIsActivateKey;

/// Called once from host focus bootstrap so [ShellScope] can mount paint
/// without an import cycle on `shell_focusable_tap.dart`.
void registerShellPaintHostAdapters({
  required ShellPaintFocusableTap focusableTap,
  required ShellPaintTvRowWrap wrapTvRow,
  required Widget Function(Widget child) wrapHorizontalScroller,
  required bool Function(ScrollNotification notification) absorbHorizontalScroll,
  required bool Function(KeyEvent event) isActivateKey,
}) {
  _registeredFocusableTap = focusableTap;
  _registeredTvRow = wrapTvRow;
  _registeredHorizontalWrap = wrapHorizontalScroller;
  _registeredAbsorbHorizontal = absorbHorizontalScroll;
  _registeredIsActivateKey = isActivateKey;
}

/// Maps foundation paint focus requests onto host TV/focus chrome.
Widget shellPaintHostScope({
  required ShellInputPolicy inputPolicy,
  required ShellMetrics metrics,
  required Widget child,
}) {
  return ShellPaintScope(
    useTvFocus: inputPolicy.useFocusableMoodChips,
    scaleOnHover: inputPolicy.scaleOnHover,
    usesTvDensity: metrics.usesTvDensity,
    focusStyled: (context, {required focused}) =>
        inputPolicy.focusStyled(context, focused: focused),
    isActivateKey: _registeredIsActivateKey,
    absorbHorizontalScroll: _registeredAbsorbHorizontal,
    wrapHorizontalScroller: _registeredHorizontalWrap,
    wrapTvRow: _registeredTvRow,
    focusableTapBuilder: _registeredFocusableTap,
    child: child,
  );
}
