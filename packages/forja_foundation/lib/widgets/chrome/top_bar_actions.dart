import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Layout widget [`kit.topBar`] action strip paint (Zone A).
///
/// Host resolves pack actions / Riverpod / hooks and passes chip widgets.
class TopBarActions extends StatelessWidget {
  const TopBarActions({
    super.key,
    required this.leading,
    this.trailing = const [],
    this.center,
    this.wrapRow,
    this.height,
    this.padding,
  });

  final List<Widget> leading;
  final List<Widget> trailing;

  /// Optional centered overlay (e.g. catalog scrape progress) — not focusable.
  final Widget? center;
  final Widget Function(Widget child)? wrapRow;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (leading.isEmpty && trailing.isEmpty && center == null) {
      return const SizedBox.shrink();
    }

    final strip = SizedBox(
      height: height ?? 40,
      child: Row(
        children: [
          for (var i = 0; i < leading.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            leading[i],
          ],
          const Spacer(),
          for (var i = 0; i < trailing.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            trailing[i],
          ],
        ],
      ),
    );

    final body = center == null
        ? strip
        : Stack(
            alignment: Alignment.center,
            children: [
              strip,
              // Progress is informational — don't steal taps from Search / View.
              IgnorePointer(child: center!),
            ],
          );

    final row = Padding(
      padding: padding ??
          EdgeInsets.fromLTRB(
            ShellTokens.compactChromeLeadingInset(context),
            8,
            ShellTokens.bodyHorizontalPadding,
            8,
          ),
      child: body,
    );

    final wrap = wrapRow;
    return wrap == null ? row : wrap(row);
  }
}
