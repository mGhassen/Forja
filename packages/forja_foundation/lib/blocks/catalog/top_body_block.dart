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
    this.actionSelectionLabels = const {},
    this.actionSlots = const {},
    this.center,
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
    this.wrapBody,
    this.onDownEdge,
    this.wrapChrome,
  });

  factory TopBodyBlock.fromProps(
    Map<String, dynamic> props, {
    Widget? grid,
    Widget? kindsBar,
    Map<String, String> actionSelections = const {},
    Map<String, String> actionSelectionLabels = const {},
    Map<String, Widget> actionSlots = const {},
    Widget? center,
    List<Map<String, dynamic>>? actions,
    void Function(String actionId, String value)? onActionSelect,
    ValueChanged<String>? onKindSelect,
    void Function(Map<String, dynamic> item)? onItemTap,
    Widget Function(Widget body)? wrapBody,
    VoidCallback? onDownEdge,
    Widget Function(Widget child)? wrapChrome,
  }) {
    return TopBodyBlock(
      actions: actions ?? propsActionMaps(props),
      actionSelections: actionSelections,
      actionSelectionLabels: actionSelectionLabels,
      actionSlots: actionSlots,
      center: center,
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
      wrapBody: wrapBody,
      onDownEdge: onDownEdge,
      wrapChrome: wrapChrome,
    );
  }

  final List<Map<String, dynamic>> actions;
  final Map<String, String> actionSelections;
  final Map<String, String> actionSelectionLabels;
  final Map<String, Widget> actionSlots;

  /// Optional center overlay (live schedule scrape progress).
  final Widget? center;
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

  /// Host wrap below the top bar (e.g. Portals panel over kinds + schedule).
  final Widget Function(Widget body)? wrapBody;

  /// Pack top-bar `focusDown` (TV).
  final VoidCallback? onDownEdge;

  /// Host wraps the top chrome strip in a TV row.
  final Widget Function(Widget child)? wrapChrome;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? ForjaShellColors.bgDark;
    final top = CatalogTopChrome(
      actions: actions,
      selections: actionSelections,
      selectionLabels: actionSelectionLabels,
      actionSlots: actionSlots,
      center: center,
      onSelect: onActionSelect,
      title: title,
      onDownEdge: onDownEdge,
      wrapRow: wrapChrome,
    );
    final kinds = kindsBar ??
        CatalogChipBar(
          items: kindItems,
          selectedId: selectedKindId ??
              (kindItems.isEmpty ? null : kindItems.first.id),
          onSelect: onKindSelect,
        );
    final gridBody = grid ??
        CatalogCardsGrid(
          items: items,
          onItemTap: onItemTap,
          emptyTitle: emptyTitle,
          emptyDescription: emptyDescription,
          cardKind: cardKind,
        );

    Widget below = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        kinds,
        Expanded(child: gridBody),
      ],
    );
    final wrap = wrapBody;
    if (wrap != null) below = wrap(below);

    return ColoredBox(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          top,
          Expanded(child: below),
        ],
      ),
    );
  }
}
