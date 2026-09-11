import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/chrome/section_title.dart';

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
    this.rowHeight = 120,
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
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final chips = chipStrip ??
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                padding ?? EdgeInsets.symmetric(horizontal: theme.spaceLg),
            itemCount: children.length,
            separatorBuilder: (_, _) => SizedBox(width: theme.spaceMd),
            itemBuilder: (_, i) => children[i],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: titlePadding ?? EdgeInsets.zero,
            child: titleStyle != null
                ? Text(title!, style: titleStyle)
                : SectionTitle(title!),
          ),
        chips,
        if (results != null) ...[
          SizedBox(height: theme.spaceMd),
          results!,
        ],
      ],
    );
  }
}
