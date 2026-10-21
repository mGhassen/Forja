import 'package:flutter/material.dart';
import 'package:forja_foundation/components/crossfade_swap.dart';
import 'package:forja_foundation/components/mood_circle.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_section_title.dart';

/// Horizontal mood section — wraps host-built strips or [children] chips.
///
/// Zone A paint only. Host supplies TV focus / selection into [chipStrip] or
/// [children]; optional [results] sits under the chip row.
class MoodSection extends StatelessWidget {
  const MoodSection({
    super.key,
    this.title,
    this.titlePadding,
    this.titleStyle,
    this.children = const [],
    this.chipStrip,
    this.results,
    this.padding,
    this.rowHeight,
    this.gap,
    this.revealIncludesTitle = false,
  });

  final String? title;
  final EdgeInsetsGeometry? titlePadding;
  final TextStyle? titleStyle;
  final List<Widget> children;

  /// Prebuilt chip row (TV strips, FittedBox, etc.). When set, [children] is
  /// ignored for the chip area.
  final Widget? chipStrip;

  /// Optional results rail under chips (host [KitSection], etc.).
  final Widget? results;

  final EdgeInsetsGeometry? padding;

  /// Chip row height — omit → [MoodCircleLayout.desktop.rowHeight].
  final double? rowHeight;

  /// Chip separator gap — omit → theme `spaceMd`.
  final double? gap;

  /// Wrap [title] + chip row in [ShellPaintEnsureVisibleExtent] so a focus
  /// reveal (TV D-pad) scrolls the whole header into view instead of pinning
  /// the focused chip flush to the viewport edge with its title cut off.
  /// Leave false when [chipStrip] scrolls horizontally — the extent sits
  /// outside that scroller and would skip its horizontal reveal.
  final bool revealIncludesTitle;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final resolvedRowHeight =
        rowHeight ?? MoodCircleLayout.desktop.rowHeight;
    final chips = chipStrip ??
        SizedBox(
          height: resolvedRowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                padding ?? EdgeInsets.symmetric(horizontal: theme.spaceLg),
            itemCount: children.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: gap ?? theme.spaceMd),
            itemBuilder: (_, i) => children[i],
          ),
        );

    Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: titlePadding ?? EdgeInsets.zero,
            child: titleStyle != null
                ? CrossfadeSwap(
                    child: Text(
                      title!,
                      key: ValueKey(title),
                      style: titleStyle,
                    ),
                  )
                : ShellSectionTitle(
                    title: title!,
                    // Outer [titlePadding] owns insets — don't double ShellSectionTitle defaults.
                    padding: EdgeInsets.zero,
                  ),
          ),
        chips,
      ],
    );
    if (revealIncludesTitle) {
      header = ShellPaintEnsureVisibleExtent(child: header);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        if (results != null) ...[
          SizedBox(height: theme.spaceMd),
          results!,
        ],
      ],
    );
  }
}
