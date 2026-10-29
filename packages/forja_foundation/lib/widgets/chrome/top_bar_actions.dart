import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/tokens/mobile_chrome_tokens.dart';

/// Layout widget [`kit.topBar`] action strip paint (Zone A).
///
/// Host resolves pack actions / Riverpod / hooks and passes chip widgets.
class TopBarActions extends StatelessWidget {
  const TopBarActions({
    super.key,
    required this.leading,
    this.trailing = const [],
    this.center,
    this.centerBelow = false,
    this.wrapRow,
    this.height,
    this.padding,
    this.gap = ShellTokens.topBarActionsGap,
  });

  final List<Widget> leading;
  final List<Widget> trailing;

  /// Optional centered overlay (e.g. catalog scrape progress) — not focusable.
  final Widget? center;

  /// Paint [center] under the strip instead of over it, so it never covers
  /// actions (phone: thin progress bar below the chips).
  final bool centerBelow;
  final Widget Function(Widget child)? wrapRow;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (leading.isEmpty && trailing.isEmpty && center == null) {
      return const SizedBox.shrink();
    }

    final leadingGroup = [
      for (var i = 0; i < leading.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        leading[i],
      ],
    ];
    final trailingGroup = [
      for (var i = 0; i < trailing.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        trailing[i],
      ],
    ];
    // Phone strips scroll sideways when they overflow; TV / desktop keep the
    // fixed Row + Spacer (and any caller-provided flex children).
    final hasFlexChild =
        !ShellPaintScope.usesMobileDensityOf(context) ||
        [...leading, ...trailing].any((w) => w is Flexible);
    final strip = SizedBox(
      height: height ?? ShellTokens.topBarActionsHeight,
      child: hasFlexChild
          ? Row(children: [...leadingGroup, const Spacer(), ...trailingGroup])
          // Leading start, trailing end when they fit; a narrow screen
          // scrolls the strip sideways instead of clipping actions.
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: leadingGroup,
                      ),
                      if (trailingGroup.isNotEmpty) SizedBox(width: gap),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: trailingGroup,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );

    final body = center == null
        ? strip
        : centerBelow
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              strip,
              const SizedBox(height: MobileChromeTokens.topBarProgressGap),
              IgnorePointer(child: center!),
            ],
          )
        : Stack(
            alignment: Alignment.center,
            children: [
              strip,
              // Progress is informational — don't steal taps from Search / View.
              IgnorePointer(child: center!),
            ],
          );

    final row = Padding(
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            ShellTokens.compactChromeLeadingInset(context),
            ShellTokens.topBarActionsPadV,
            ShellTokens.bodyHorizontalPadding,
            ShellTokens.topBarActionsPadV,
          ),
      child: body,
    );

    final wrap = wrapRow;
    final wrapped = wrap == null ? row : wrap(row);
    // Top-of-hub strip: clear the status bar when the host leaves the top
    // system inset in place (edge-to-edge phones). Zero on TV and desktop,
    // and under any ancestor that already consumed the inset.
    final safeTop = MediaQuery.paddingOf(context).top;
    if (safeTop <= 0) return wrapped;
    return Padding(
      padding: EdgeInsets.only(top: safeTop),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: wrapped,
      ),
    );
  }
}
