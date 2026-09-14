import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Prebuilt page: filter chrome ([menu] + [tabs]) over an expand [cards] grid.
///
/// My List shape (kind menu → status tabs → poster grid) — **not** a
/// `myList*` product type.
///
/// ```
/// ┌──── menu (kinds, optional) ───┐
/// ├──── tabs (status) ────────────┤
/// │                               │
/// │         cards (grid)          │
/// │                               │
/// └───────────────────────────────┘
/// ```
///
/// ```json
/// {
///   "type": "tabsCards",
///   "children": [ /* menu? */, /* tabs */, /* cards */ ]
/// }
/// ```
///
/// Named maps: `menu` / `tabs` / `cards` (or `grid`).
class TabsCardsBlock extends StatelessWidget {
  const TabsCardsBlock({
    super.key,
    this.menu,
    this.tabs,
    required this.cards,
    this.backgroundColor,
  });

  factory TabsCardsBlock.fromProps(
    Map<String, dynamic> props, {
    Widget? menu,
    Widget? tabs,
    required Widget cards,
  }) {
    return TabsCardsBlock(
      menu: menu,
      tabs: tabs,
      cards: cards,
      backgroundColor: propsColor(props, 'backgroundColor'),
    );
  }

  final Widget? menu;
  final Widget? tabs;
  final Widget cards;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? ForjaShellColors.surfaceElevated;
    return ColoredBox(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?menu,
          ?tabs,
          Expanded(child: cards),
        ],
      ),
    );
  }
}
