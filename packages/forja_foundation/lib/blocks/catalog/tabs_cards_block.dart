import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/catalog/catalog_chrome.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Prebuilt My List-style screen: kind menu + status tabs + poster cards.
///
/// Composes [CatalogChipBar] ×2 + [CatalogCardsGrid].
///
/// ```json
/// {
///   "type": "tabsCards",
///   "props": {
///     "menuItems": [{ "id": "movie", "label": "Film" }],
///     "tabItems": [{ "id": "watching", "label": "Watching" }],
///     "selectedMenuId": "movie",
///     "selectedTabId": "watching",
///     "items": [{ "paint": { "type": "posterCard", "props": { … } } }]
///   }
/// }
/// ```
class TabsCardsBlock extends StatelessWidget {
  const TabsCardsBlock({
    super.key,
    this.menuItems = const [],
    this.tabItems = const [],
    this.selectedMenuId,
    this.selectedTabId,
    this.items = const [],
    this.cards,
    this.backgroundColor,
    this.emptyTitle = 'Your list is empty',
    this.emptyDescription,
    this.onMenuSelect,
    this.onTabSelect,
    this.onItemTap,
  });

  factory TabsCardsBlock.fromProps(
    Map<String, dynamic> props, {
    Widget? cards,
    ValueChanged<String>? onMenuSelect,
    ValueChanged<String>? onTabSelect,
    void Function(Map<String, dynamic> item)? onItemTap,
  }) {
    return TabsCardsBlock(
      menuItems: propsIdLabelList(props, 'menuItems'),
      tabItems: propsIdLabelList(props, 'tabItems'),
      selectedMenuId: propsString(props, 'selectedMenuId'),
      selectedTabId: propsString(props, 'selectedTabId') ??
          propsString(props, 'defaultTabId'),
      items: CatalogCardsGrid.itemsFromProps(props),
      cards: cards,
      backgroundColor: propsColor(props, 'backgroundColor'),
      emptyTitle: propsStringOr(props, 'emptyTitle', 'Your list is empty'),
      emptyDescription: propsString(props, 'emptyDescription'),
      onMenuSelect: onMenuSelect,
      onTabSelect: onTabSelect,
      onItemTap: onItemTap,
    );
  }

  final List<({String id, String label})> menuItems;
  final List<({String id, String label})> tabItems;
  final String? selectedMenuId;
  final String? selectedTabId;
  final List<Map<String, dynamic>> items;
  final Widget? cards;
  final Color? backgroundColor;
  final String emptyTitle;
  final String? emptyDescription;
  final ValueChanged<String>? onMenuSelect;
  final ValueChanged<String>? onTabSelect;
  final void Function(Map<String, dynamic> item)? onItemTap;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? ForjaShellColors.surfaceElevated;
    final menu = CatalogChipBar(
      items: menuItems,
      selectedId: selectedMenuId,
      onSelect: onMenuSelect,
    );
    final tabs = CatalogChipBar(
      items: tabItems,
      selectedId: selectedTabId ??
          (tabItems.isEmpty ? null : tabItems.first.id),
      onSelect: onTabSelect,
    );
    final grid = cards ??
        CatalogCardsGrid(
          items: items,
          onItemTap: onItemTap,
          emptyTitle: emptyTitle,
          emptyDescription: emptyDescription,
          cardKind: 'poster',
        );

    return ColoredBox(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          menu,
          tabs,
          Expanded(child: grid),
        ],
      ),
    );
  }
}
