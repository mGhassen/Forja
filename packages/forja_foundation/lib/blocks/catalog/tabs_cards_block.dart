import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Prebuilt page: filter chrome ([menu] + [tabs]) over an expand [cards] grid.
///
/// My List shape (kind underline menu → status tabs → poster grid) — **not** a
/// `myList*` product type. Host paints real menu/tabs children; this block only
/// stacks them.
///
/// ```
/// ┌──── menu (kinds, optional) ───┐
/// ├──── tabs (status) ────────────┤
/// │                               │
/// │         cards (grid)          │
/// │                               │
/// └───────────────────────────────┘
/// ```
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
    final bg = backgroundColor ?? ForjaShellColors.bgDark;
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
