import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Prebuilt page: full-width [header] over a two-column row ([side] | [body]).
///
/// IPTV catalog shape (and any hub that needs top chrome + category rail +
/// channel/grid body) — **not** an `iptv*` product type.
///
/// ```json
/// {
///   "type": "columnsHeader",
///   "props": { "sideWidth": 220, "sideOnLeading": true },
///   "children": [ /* header */, /* side */, /* body */ ]
/// }
/// ```
///
/// Or named maps: `header` / `side` / `body` on the node (painted by host).
class ColumnsHeaderBlock extends StatelessWidget {
  const ColumnsHeaderBlock({
    super.key,
    this.header,
    this.side,
    required this.body,
    this.sideWidth = 220,
    this.sideOnLeading = true,
    this.sideGap = 0,
    this.backgroundColor,
  });

  factory ColumnsHeaderBlock.fromProps(
    Map<String, dynamic> props, {
    Widget? header,
    Widget? side,
    required Widget body,
  }) {
    return ColumnsHeaderBlock(
      header: header,
      side: side,
      body: body,
      sideWidth: propsNumOr(props, 'sideWidth', 220),
      sideOnLeading: propsBool(props, 'sideOnLeading', true),
      sideGap: propsNumOr(props, 'sideGap', 0),
      backgroundColor: propsColor(props, 'backgroundColor'),
    );
  }

  final Widget? header;
  final Widget? side;
  final Widget body;
  final double sideWidth;
  final bool sideOnLeading;
  final double sideGap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? ForjaShellColors.surfaceElevated;
    final row = side == null
        ? body
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sideOnLeading) ...[
                SizedBox(width: sideWidth, child: side),
                if (sideGap > 0) SizedBox(width: sideGap),
              ],
              Expanded(child: body),
              if (!sideOnLeading) ...[
                if (sideGap > 0) SizedBox(width: sideGap),
                SizedBox(width: sideWidth, child: side),
              ],
            ],
          );

    return ColoredBox(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          Expanded(child: row),
        ],
      ),
    );
  }
}
