import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Prebuilt page: [top] chrome over a body that is itself [bodyTop] + [grid].
///
/// Live Sports shape (catalog top → kind strip → schedule grid) — **not** a
/// `liveSports*` product type.
///
/// ```
/// ┌──────── top (topBar) ─────────┐
/// ├────── bodyTop (kinds) ────────┤
/// │                               │
/// │         grid (schedule)       │
/// │                               │
/// └───────────────────────────────┘
/// ```
///
/// ```json
/// {
///   "type": "topBody",
///   "props": {},
///   "children": [ /* top */, /* bodyTop */, /* grid */ ]
/// }
/// ```
///
/// Named maps also work: `top` / `bodyTop` / `grid`.
class TopBodyBlock extends StatelessWidget {
  const TopBodyBlock({
    super.key,
    this.top,
    this.bodyTop,
    required this.grid,
    this.backgroundColor,
  });

  factory TopBodyBlock.fromProps(
    Map<String, dynamic> props, {
    Widget? top,
    Widget? bodyTop,
    required Widget grid,
  }) {
    return TopBodyBlock(
      top: top,
      bodyTop: bodyTop,
      grid: grid,
      backgroundColor: propsColor(props, 'backgroundColor'),
    );
  }

  final Widget? top;
  final Widget? bodyTop;
  final Widget grid;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? ForjaShellColors.surfaceElevated;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?bodyTop,
        Expanded(child: grid),
      ],
    );

    return ColoredBox(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?top,
          Expanded(child: body),
        ],
      ),
    );
  }
}
