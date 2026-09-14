import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/catalog/catalog_chrome.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Prebuilt Live Sports-style screen: top chrome + kind chips + event grid.
///
/// Composes [CatalogTopChrome], [CatalogChipBar], [CatalogCardsGrid].
///
/// ```json
/// {
///   "type": "topBody",
///   "props": {
///     "actions": […],
///     "kindItems": [{ "id": "all", "label": "All" }],
///     "selectedKindId": "all",
///     "cardKind": "event",
///     "items": [{ "paint": { "type": "eventCard", "props": { … } } }]
///   }
/// }
/// ```
class TopBodyBlock extends StatelessWidget {
  const TopBodyBlock({
    super.key,
    this.actions = const [],
    this.actionSelections = const {},
    this.kindItems = const [],
    this.selectedKindId,
    this.items = const [],
    this.grid,
    this.kindsBar,
    this.cardKind = 'event',
    this.backgroundColor,
    this.title,
    this.emptyTitle = 'No matches',
    this.emptyDescription,
    this.onActionSelect,
    this.onKindSelect,
    this.onItemTap,
  });

  factory TopBodyBlock.fromProps(
    Map<String, dynamic> props, {
    Widget? grid,
    Widget? kindsBar,
    Map<String, String> actionSelections = const {},
    void Function(String actionId, String value)? onActionSelect,
    ValueChanged<String>? onKindSelect,
    void Function(Map<String, dynamic> item)? onItemTap,
  }) {
    return TopBodyBlock(
      actions: propsActionMaps(props),
      actionSelections: actionSelections,
      kindItems: propsIdLabelList(props, 'kindItems'),
      selectedKindId: propsString(props, 'selectedKindId') ??
          propsString(props, 'defaultKindId'),
      items: CatalogCardsGrid.itemsFromProps(props),
      grid: grid,
      kindsBar: kindsBar,
      cardKind: propsStringOr(props, 'cardKind', 'event'),
      backgroundColor: propsColor(props, 'backgroundColor'),
      title: propsString(props, 'title'),
      emptyTitle: propsStringOr(props, 'emptyTitle', 'No matches'),
      emptyDescription: propsString(props, 'emptyDescription'),
      onActionSelect: onActionSelect,
      onKindSelect: onKindSelect,
      onItemTap: onItemTap,
    );
  }

  final List<Map<String, dynamic>> actions;
  final Map<String, String> actionSelections;
  final List<({String id, String label})> kindItems;
  final String? selectedKindId;
  final List<Map<String, dynamic>> items;
  final Widget? grid;

  /// Host mood-circle strip (e.g. Live Sports `kindIcons`). Wins over [kindItems].
  final Widget? kindsBar;
  final String cardKind;
  final Color? backgroundColor;
  final String? title;
  final String emptyTitle;
  final String? emptyDescription;
  final void Function(String actionId, String value)? onActionSelect;
  final ValueChanged<String>? onKindSelect;
  final void Function(Map<String, dynamic> item)? onItemTap;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? ForjaShellColors.surfaceElevated;
    final top = CatalogTopChrome(
      actions: actions,
      selections: actionSelections,
      onSelect: onActionSelect,
      title: title,
    );
    final kinds = kindsBar ??
        CatalogChipBar(
          items: kindItems,
          selectedId: selectedKindId ??
              (kindItems.isEmpty ? null : kindItems.first.id),
          onSelect: onKindSelect,
        );
    final body = grid ??
        CatalogCardsGrid(
          items: items,
          onItemTap: onItemTap,
          emptyTitle: emptyTitle,
          emptyDescription: emptyDescription,
          cardKind: cardKind,
        );

    return ColoredBox(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          top,
          kinds,
          Expanded(child: body),
        ],
      ),
    );
  }
}
