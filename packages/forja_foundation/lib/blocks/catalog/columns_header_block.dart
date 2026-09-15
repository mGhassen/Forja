import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/catalog/catalog_chrome.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Prebuilt IPTV-style catalog screen: top chrome + side categories + card grid.
///
/// Composes [CatalogTopChrome], [CatalogSideRail], [CatalogCardsGrid] — not an
/// empty slot shell.
///
/// ```json
/// {
///   "type": "columnsHeader",
///   "props": {
///     "sideWidth": 220,
///     "actions": [{ "id": "catalog", "label": "Section", "items": […] }],
///     "sideItems": [{ "id": "all", "label": "All" }],
///     "selectedSideId": "all",
///     "items": [{ "paint": { "type": "posterCard", "props": { … } } }]
///   }
/// }
/// ```
class ColumnsHeaderBlock extends StatelessWidget {
  const ColumnsHeaderBlock({
    super.key,
    this.actions = const [],
    this.actionSelections = const {},
    this.actionSlots = const {},
    this.sideItems = const [],
    this.selectedSideId,
    this.items = const [],
    this.body,
    this.sideWidth = 220,
    this.sideOnLeading = true,
    this.sideGap = 0,
    this.backgroundColor,
    this.title,
    this.emptyTitle = 'No channels',
    this.emptyDescription,
    this.onActionSelect,
    this.onSideSelect,
    this.onItemTap,
  });

  factory ColumnsHeaderBlock.fromProps(
    Map<String, dynamic> props, {
    Widget? body,
    Map<String, String> actionSelections = const {},
    Map<String, Widget> actionSlots = const {},
    void Function(String actionId, String value)? onActionSelect,
    ValueChanged<String>? onSideSelect,
    void Function(Map<String, dynamic> item)? onItemTap,
  }) {
    return ColumnsHeaderBlock(
      actions: propsActionMaps(props),
      actionSelections: actionSelections,
      actionSlots: actionSlots,
      sideItems: propsIdLabelList(props, 'sideItems'),
      selectedSideId: propsString(props, 'selectedSideId') ??
          propsString(props, 'defaultSideId'),
      items: CatalogCardsGrid.itemsFromProps(props),
      body: body,
      sideWidth: propsNumOr(props, 'sideWidth', 220),
      sideOnLeading: propsBool(props, 'sideOnLeading', true),
      sideGap: propsNumOr(props, 'sideGap', 0),
      backgroundColor: propsColor(props, 'backgroundColor'),
      title: propsString(props, 'title'),
      emptyTitle: propsStringOr(props, 'emptyTitle', 'No channels'),
      emptyDescription: propsString(props, 'emptyDescription'),
      onActionSelect: onActionSelect,
      onSideSelect: onSideSelect,
      onItemTap: onItemTap,
    );
  }

  final List<Map<String, dynamic>> actions;
  final Map<String, String> actionSelections;
  final Map<String, Widget> actionSlots;
  final List<({String id, String label})> sideItems;
  final String? selectedSideId;
  final List<Map<String, dynamic>> items;
  /// Host-fed grid (e.g. live feed). When set, replaces [items] grid.
  final Widget? body;
  final double sideWidth;
  final bool sideOnLeading;
  final double sideGap;
  final Color? backgroundColor;
  final String? title;
  final String emptyTitle;
  final String? emptyDescription;
  final void Function(String actionId, String value)? onActionSelect;
  final ValueChanged<String>? onSideSelect;
  final void Function(Map<String, dynamic> item)? onItemTap;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? ForjaShellColors.surfaceElevated;
    final header = CatalogTopChrome(
      actions: actions,
      selections: actionSelections,
      actionSlots: actionSlots,
      onSelect: onActionSelect,
      title: title,
    );
    final side = CatalogSideRail(
      items: sideItems,
      selectedId: selectedSideId ??
          (sideItems.isEmpty ? null : sideItems.first.id),
      onSelect: onSideSelect,
      width: sideWidth,
    );
    final grid = body ??
        CatalogCardsGrid(
          items: items,
          onItemTap: onItemTap,
          emptyTitle: emptyTitle,
          emptyDescription: emptyDescription,
          cardKind: 'poster',
        );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sideOnLeading) ...[
          SizedBox(width: sideWidth, child: side),
          if (sideGap > 0) SizedBox(width: sideGap),
        ],
        Expanded(child: grid),
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
          header,
          Expanded(child: row),
        ],
      ),
    );
  }
}
