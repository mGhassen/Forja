import 'package:flutter/material.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_metrics.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
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
    child: metrics.usesTvDensity
        ? _TvDialogTheme(child: child)
        : child,
  );
}

/// Leanback [AlertDialog] inherits Material titleLarge (~20) unless themed.
/// Apply shell type ladder + denser insets for every rehosted / in-shell dialog.
class _TvDialogTheme extends StatelessWidget {
  const _TvDialogTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final titleStyle = (base.textTheme.titleLarge ?? const TextStyle()).copyWith(
      fontSize: ShellTokens.tvTitleFontSize,
      fontWeight: FontWeight.w700,
      color: ForjaShellColors.textPrimary,
      height: 1.25,
    );
    final bodyStyle = (base.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontSize: ShellTokens.tvBodyFontSize,
      color: ForjaShellColors.textSecondary,
      height: 1.35,
    );
    final iconSize = ShellTokens.iconSizeTv;
    final control = ShellTokens.controlHeightTv;
    final iconTheme = (base.iconTheme).copyWith(size: iconSize);
    return Theme(
      data: base.copyWith(
        dialogTheme: DialogThemeData(
          backgroundColor: ForjaShellColors.cinematic.menuSurface,
          titleTextStyle: titleStyle,
          contentTextStyle: bodyStyle,
          insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          constraints: const BoxConstraints(maxWidth: 360),
        ),
        textTheme: base.textTheme.copyWith(
          titleLarge: titleStyle,
          titleMedium: titleStyle,
          bodyMedium: bodyStyle,
          bodyLarge: bodyStyle,
        ),
        // Icons without an explicit size inherit Material 24 — densify with chrome.
        iconTheme: iconTheme,
        primaryIconTheme: (base.primaryIconTheme).copyWith(size: iconSize),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            iconSize: iconSize,
            minimumSize: Size(control, control),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: base.iconButtonTheme.style?.foregroundColor
                    ?.resolve({}) ??
                const Color(0xFFF5F5F7),
          ),
        ),
      ),
      // Explicit wrap — Theme.iconTheme alone can stay null under MaterialApp.
      child: IconTheme(
        data: iconTheme,
        child: child,
      ),
    );
  }
}
