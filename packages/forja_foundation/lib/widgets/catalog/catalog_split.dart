import 'package:flutter/material.dart';

/// Presentational sidebar + body split — widgets / callbacks only.
///
/// Host owns selection, filters, and body content. No catalog policy.
class CatalogSplit extends StatelessWidget {
  const CatalogSplit({
    super.key,
    required this.sidebar,
    required this.body,
    this.sidebarWidth = 220,
    this.sidebarLeading = true,
    this.divider,
    this.onSidebarTapOutside,
  });

  final Widget sidebar;
  final Widget body;
  final double sidebarWidth;
  final bool sidebarLeading;

  /// Optional hairline between sidebar and body.
  final Widget? divider;

  /// Optional dismiss / focus callback when the body area is tapped.
  final VoidCallback? onSidebarTapOutside;

  @override
  Widget build(BuildContext context) {
    final side = SizedBox(width: sidebarWidth, child: sidebar);
    final main = onSidebarTapOutside == null
        ? Expanded(child: body)
        : Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onSidebarTapOutside,
              child: body,
            ),
          );
    final mid = divider ??
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: Color(0xFF2A2A2A),
        );

    final children = <Widget>[
      side,
      mid,
      main,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sidebarLeading ? children : children.reversed.toList(),
    );
  }
}
