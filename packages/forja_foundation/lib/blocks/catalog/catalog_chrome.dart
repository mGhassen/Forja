import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/action_chip.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja_foundation/widgets/chrome/top_bar_actions.dart';
import 'package:forja_foundation/widgets/chrome/view_button_group.dart';
import 'package:forja_foundation/widgets/chrome/widget_shelf.dart';

export 'package:forja_foundation/blocks/catalog/catalog_cards_grid.dart';

/// Optional double from pack action / props maps (`height`, `fontSize`, …).
double? propsOptDouble(Map m, String key) {
  final v = m[key];
  return v is num ? v.toDouble() : null;
}

/// `{ id, label }` rows from pack JSON lists.
List<({String id, String label})> propsIdLabelList(
  Map<String, dynamic> props,
  String key,
) {
  final v = props[key];
  if (v is! List) return const [];
  final out = <({String id, String label})>[];
  for (final raw in v) {
    if (raw is! Map) continue;
    final id = (raw['id'] ?? '').toString().trim();
    if (id.isEmpty) continue;
    final label = (raw['label'] ?? raw['title'] ?? id).toString().trim();
    out.add((id: id, label: label.isEmpty ? id : label));
  }
  return out;
}

/// Nested action groups: `{ id, label, default?, trailing?, items? }`.
List<Map<String, dynamic>> propsActionMaps(Map<String, dynamic> props) {
  final v = props['actions'];
  if (v is! List) return const [];
  return [
    for (final raw in v)
      if (raw is Map) Map<String, dynamic>.from(raw),
  ];
}

/// Horizontal chip strip used by catalog page blocks.
class CatalogChipBar extends StatelessWidget {
  const CatalogChipBar({
    super.key,
    required this.items,
    this.selectedId,
    this.onSelect,
    this.padding = const EdgeInsets.fromLTRB(12, ShellTokens.topBarActionsGap, 12, ShellTokens.topBarActionsGap),
  });

  final List<({String id, String label})> items;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: ShellTokens.topBarActionsGap),
              ForjaShellChip(
                label: items[i].label,
                selected: selectedId == items[i].id,
                onTap: onSelect == null ? null : () => onSelect!(items[i].id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pack action / item `icon` token → Material icon.
IconData? catalogChromeActionIcon(Map<String, dynamic> action) {
  final name = (action['icon'] ?? '').toString().trim().toLowerCase();
  return catalogChromeIconToken(name);
}

IconData? catalogChromeIconToken(String name) {
  return switch (name.trim().toLowerCase()) {
    'refresh' => Icons.refresh_rounded,
    'search' => Icons.search_rounded,
    'filter' || 'catalog' || 'sort' => Icons.filter_list_rounded,
    'schedule' || 'time' || 'horizon' => Icons.schedule_rounded,
    'view' || 'list' => Icons.view_list_rounded,
    'cards' || 'grid' => Icons.grid_view_rounded,
    'timeline' => Icons.view_timeline_rounded,
    'guide' || 'epg' || 'table' => Icons.table_chart_outlined,
    'live_tv' || 'tv' => Icons.live_tv_rounded,
    'movie' || 'movies' || 'film' => Icons.movie_rounded,
    'video_library' || 'series' || 'library' => Icons.video_library_rounded,
    'portals' || 'inbox' => Icons.inbox_outlined,
    'dns' => Icons.dns_outlined,
    _ => null,
  };
}

Color? _parseHexColor(Object? raw) {
  final s = (raw ?? '').toString().trim();
  if (s.isEmpty) return null;
  var hex = s.startsWith('#') ? s.substring(1) : s;
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(value);
}

List<Color> _itemGradientColors(Map<String, dynamic> item) {
  final raw = item['colors'] ?? item['gradient'] ?? item['accent'];
  if (raw is! List) return const [];
  final out = <Color>[];
  for (final e in raw) {
    final c = _parseHexColor(e);
    if (c != null) out.add(c);
  }
  return out;
}

List<Map<String, dynamic>> _actionItemMaps(Map<String, dynamic> action) {
  final v = action['items'];
  if (v is! List) return const [];
  return [
    for (final raw in v)
      if (raw is Map) Map<String, dynamic>.from(raw),
  ];
}

/// Top action chrome — pack `actions[]` as shelf / view group / chips.
class CatalogTopChrome extends StatefulWidget {
  const CatalogTopChrome({
    super.key,
    required this.actions,
    this.selections = const {},
    this.selectionLabels = const {},
    this.onSelect,
    this.title,
    this.actionSlots = const {},
    this.center,
    this.height,
    this.padding,
    this.gap,
  });

  final List<Map<String, dynamic>> actions;
  final Map<String, String> selections;

  /// Optional display labels keyed by action id (dynamic catalog / schedule).
  final Map<String, String> selectionLabels;
  final void Function(String actionId, String value)? onSelect;
  final String? title;

  /// Host-painted overrides keyed by action id (e.g. portals → [PortalsChip]).
  final Map<String, Widget> actionSlots;

  /// Optional center overlay (feed scrape progress / updated label).
  final Widget? center;

  /// Pack `height` / `pad` — omit → [TopBarActions] ShellTokens defaults.
  final double? height;
  final EdgeInsetsGeometry? padding;

  /// Pack `gap` between leading/trailing chips — omit → 8.
  final double? gap;

  @override
  State<CatalogTopChrome> createState() => _CatalogTopChromeState();
}

class _CatalogTopChromeState extends State<CatalogTopChrome> {
  bool _shelfExpanded = false;

  static bool _isTrailing(Map<String, dynamic> action) {
    if (action['trailing'] == true) return true;
    final slot = (action['slot'] ?? '').toString().trim().toLowerCase();
    return slot == 'trailing' || slot == 'end' || slot == 'right';
  }

  static String _verb(Map<String, dynamic> action) {
    final a = (action['action'] ?? '').toString().trim().toLowerCase();
    if (a.isNotEmpty) return a;
    return (action['id'] ?? '').toString().trim().toLowerCase();
  }

  static String _style(Map<String, dynamic> action) =>
      (action['style'] ?? action['paint'] ?? '').toString().trim().toLowerCase();

  static bool _expandOnHover(Map<String, dynamic> action) =>
      action['expandOnHover'] == true || action['collapse'] == true;

  static String _selectedLabel(
    Map<String, dynamic> action,
    Map<String, String> selections,
    Map<String, String> selectionLabels,
  ) {
    final actionId = (action['id'] ?? '').toString();
    final override = (selectionLabels[actionId] ?? '').trim();
    if (override.isNotEmpty) return override;
    final nested = propsIdLabelList(action, 'items');
    final selected = (selections[actionId] ??
            (action['default'] ?? (nested.isEmpty ? '' : nested.first.id))
                .toString())
        .trim();
    if (nested.isEmpty) {
      return (action['label'] ?? actionId).toString();
    }
    for (final e in nested) {
      if (e.id == selected) return e.label;
    }
    return nested.first.label;
  }

  static bool _isSelectedMenu(
    Map<String, dynamic> action,
    Map<String, String> selections,
  ) {
    final actionId = (action['id'] ?? '').toString();
    final def = (action['default'] ?? '').toString().trim();
    final selected = (selections[actionId] ?? def).trim();
    if (selected.isEmpty) return false;
    if (def.isNotEmpty) return selected != def;
    return selected != 'all';
  }

  static IconData _viewItemIcon(String id, String? token) {
    final fromToken = catalogChromeIconToken(token ?? '');
    if (fromToken != null) return fromToken;
    // Pack must pass `icon` on view items; generic fallback only.
    return Icons.grid_view_rounded;
  }

  void _onShelfExpandChanged(bool expanded) {
    if (_shelfExpanded == expanded) return;
    setState(() => _shelfExpanded = expanded);
  }

  Widget? _buildShelf(Map<String, dynamic> action, String actionId) {
    final maps = _actionItemMaps(action);
    if (maps.isEmpty) return null;
    final selected = (widget.selections[actionId] ??
            (action['default'] ?? maps.first['id'] ?? '').toString())
        .trim();
    final allowReload = action['reload'] == true;
    final expandOnHover = _expandOnHover(action);
    return WidgetShelf(
      key: ValueKey('shelf-$actionId'),
      selectedId: selected.isEmpty ? null : selected,
      expandOnHover: expandOnHover,
      onExpandChanged: expandOnHover ? _onShelfExpandChanged : null,
      onSelect: widget.onSelect == null
          ? (_) {}
          : (id) => widget.onSelect!(actionId, id),
      onReload: !allowReload || widget.onSelect == null
          ? null
          : (id) => widget.onSelect!(actionId, '__reload__:$id'),
      height: propsOptDouble(action, 'height') ?? ShellTokens.widgetShelfHeight,
      radius: propsOptDouble(action, 'radius') ?? ShellTokens.widgetShelfRadius,
      fontSize: propsOptDouble(action, 'fontSize') ?? ShellTokens.widgetShelfFontSize,
      iconSize: propsOptDouble(action, 'iconSize') ?? ShellTokens.widgetShelfIconSize,
      pad: propsOptDouble(action, 'pad') ?? ShellTokens.widgetShelfGap,
      items: [
        for (final m in maps)
          WidgetShelfItem(
            id: (m['id'] ?? '').toString(),
            label: (m['label'] ?? m['title'] ?? m['id'] ?? '').toString(),
            icon: catalogChromeIconToken((m['icon'] ?? '').toString()),
            gradientColors: _itemGradientColors(m),
          ),
      ],
    );
  }

  Widget? _buildViewGroup(Map<String, dynamic> action, String actionId) {
    final maps = _actionItemMaps(action);
    if (maps.isEmpty) return null;
    final selected = (widget.selections[actionId] ??
            (action['default'] ?? maps.first['id'] ?? '').toString())
        .trim();
    return ViewButtonGroup(
      selectedId: selected.isEmpty ? null : selected,
      onSelect: widget.onSelect == null
          ? (_) {}
          : (id) => widget.onSelect!(actionId, id),
      height: propsOptDouble(action, 'height'),
      iconSize: propsOptDouble(action, 'iconSize'),
      dividerHeight: propsOptDouble(action, 'dividerHeight'),
      items: [
        for (final m in maps)
          ViewButtonItem(
            id: (m['id'] ?? '').toString(),
            label: (m['label'] ?? m['title'] ?? '').toString(),
            icon: _viewItemIcon(
              (m['id'] ?? '').toString(),
              (m['icon'] ?? '').toString(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) {
      final t = widget.title?.trim() ?? '';
      if (t.isEmpty) return const SizedBox(height: 8);
      return SizedBox(
        height: ShellTokens.topBarTitleHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ShellTokens.compactChromeLeadingInset(context),
            ),
            child: Text(
              t,
              style: const TextStyle(
                color: ForjaShellColors.textPrimary,
                fontSize: ShellTokens.topBarTitleFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    final leading = <Widget>[];
    final trailing = <Widget>[];
    Widget? expandShelf;
    for (final action in widget.actions) {
      final actionId = (action['id'] ?? '').toString().trim();
      if (actionId.isEmpty) continue;
      final bucket = _isTrailing(action) ? trailing : leading;
      final slot = widget.actionSlots[actionId];
      if (slot != null) {
        bucket.add(slot);
        continue;
      }
      final verb = _verb(action);
      final style = _style(action);
      final icon = catalogChromeActionIcon(action);
      final nested = propsIdLabelList(action, 'items');
      final isView = actionId == 'view' || verb == 'view';
      final isShelf = style == 'shelf' || style == 'segment';
      final isViewGroup = isView &&
          nested.isNotEmpty &&
          (style == 'group' ||
              style == 'toggle' ||
              style == 'buttons' ||
              style.isEmpty);
      final isIconOnly = nested.isEmpty &&
          (actionId == 'search' ||
              actionId == 'refresh' ||
              verb == 'eventsearch' ||
              verb == 'refresh' ||
              verb == 'search');
      // Sort / filter menus stay icon-only (old IPTV: filter next to search).
      final isSortIcon = nested.isNotEmpty &&
          (actionId == 'sort' ||
              verb == 'sort' ||
              style == 'icon' ||
              style == 'iconOnly');

      if (isShelf && nested.isNotEmpty) {
        final shelf = _buildShelf(action, actionId);
        if (shelf != null) {
          if (_expandOnHover(action)) expandShelf = shelf;
          bucket.add(shelf);
          continue;
        }
      }

      if (isViewGroup) {
        final group = _buildViewGroup(action, actionId);
        if (group != null) {
          bucket.add(group);
          continue;
        }
      }

      if (isIconOnly || isSortIcon) {
        bucket.add(
          ForjaActionChip(
            label: (action['label'] ?? actionId).toString(),
            icon: icon ??
                (verb == 'search' || verb == 'eventsearch'
                    ? Icons.search_rounded
                    : isSortIcon
                        ? Icons.filter_list_rounded
                        : Icons.refresh_rounded),
            iconOnly: true,
            selected: isSortIcon && _isSelectedMenu(action, widget.selections),
            height: propsOptDouble(action, 'height') ?? ShellTokens.actionChipHeight,
            radius: propsOptDouble(action, 'radius') ?? ShellTokens.actionChipRadius,
            maxWidth: propsOptDouble(action, 'maxWidth') ?? ShellTokens.actionChipMaxWidth,
            fontSize: propsOptDouble(action, 'fontSize') ?? ShellTokens.actionChipFontSize,
            iconSize: propsOptDouble(action, 'iconSize'),
            gap: propsOptDouble(action, 'gap') ?? ShellTokens.actionChipGap,
            onTap: widget.onSelect == null
                ? () {}
                : () => widget.onSelect!(
                      actionId,
                      nested.isEmpty ? actionId : '__open__',
                    ),
          ),
        );
        continue;
      }

      if (nested.isNotEmpty) {
        bucket.add(
          ForjaActionChip(
            label: _selectedLabel(
              action,
              widget.selections,
              widget.selectionLabels,
            ),
            icon: icon,
            selected: _isSelectedMenu(action, widget.selections),
            height: propsOptDouble(action, 'height') ?? ShellTokens.actionChipHeight,
            radius: propsOptDouble(action, 'radius') ?? ShellTokens.actionChipRadius,
            maxWidth: propsOptDouble(action, 'maxWidth') ?? ShellTokens.actionChipMaxWidth,
            fontSize: propsOptDouble(action, 'fontSize') ?? ShellTokens.actionChipFontSize,
            iconSize: propsOptDouble(action, 'iconSize'),
            gap: propsOptDouble(action, 'gap') ?? ShellTokens.actionChipGap,
            onTap: widget.onSelect == null
                ? () {}
                // Host opens the real Catalog / Schedule sheet (not a flat fallback).
                : () => widget.onSelect!(actionId, '__open__'),
          ),
        );
        continue;
      }

      bucket.add(
        ForjaActionChip(
          label: (action['label'] ?? actionId).toString(),
          icon: icon,
          selected: false,
          height: propsOptDouble(action, 'height') ?? ShellTokens.actionChipHeight,
          radius: propsOptDouble(action, 'radius') ?? ShellTokens.actionChipRadius,
          maxWidth: propsOptDouble(action, 'maxWidth') ?? ShellTokens.actionChipMaxWidth,
          fontSize: propsOptDouble(action, 'fontSize') ?? ShellTokens.actionChipFontSize,
          iconSize: propsOptDouble(action, 'iconSize'),
          gap: propsOptDouble(action, 'gap') ?? ShellTokens.actionChipGap,
          onTap: widget.onSelect == null
              ? () {}
              : () => widget.onSelect!(actionId, actionId),
        ),
      );
    }

    final shelfOnly = expandShelf;
    final hideSiblings = _shelfExpanded && shelfOnly != null;
    return TopBarActions(
      leading: hideSiblings ? [shelfOnly] : leading,
      trailing: hideSiblings ? const [] : trailing,
      center: hideSiblings ? null : widget.center,
      height: widget.height,
      gap: widget.gap ?? ShellTokens.topBarActionsGap,
      padding: widget.padding ??
          EdgeInsets.fromLTRB(
            ShellTokens.compactChromeLeadingInset(context),
            ShellTokens.tabHeaderTopPadding,
            ShellTokens.bodyHorizontalPadding,
            4,
          ),
    );
  }
}

