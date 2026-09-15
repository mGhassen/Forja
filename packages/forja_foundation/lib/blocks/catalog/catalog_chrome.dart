import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/action_chip.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja_foundation/widgets/chrome/top_bar_actions.dart';

export 'package:forja_foundation/blocks/catalog/catalog_cards_grid.dart';

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
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
              if (i > 0) const SizedBox(width: 8),
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

/// Pack action `icon` token → Material icon (refresh / search / view / …).
IconData? catalogChromeActionIcon(Map<String, dynamic> action) {
  final name = (action['icon'] ?? '').toString().trim().toLowerCase();
  return switch (name) {
    'refresh' => Icons.refresh_rounded,
    'search' => Icons.search_rounded,
    'filter' || 'catalog' => Icons.filter_list_rounded,
    'schedule' || 'time' || 'horizon' => Icons.schedule_rounded,
    'view' || 'list' => Icons.view_list_rounded,
    'cards' || 'grid' => Icons.grid_view_rounded,
    'live_tv' || 'tv' => Icons.live_tv_rounded,
    'portals' || 'inbox' => Icons.inbox_outlined,
    'dns' => Icons.dns_outlined,
    _ => null,
  };
}

/// Top action chrome — pack `actions[]` as themed [ForjaActionChip]s
/// (one control per action: menu opens a sheet; view cycles; not expanded pills).
class CatalogTopChrome extends StatelessWidget {
  const CatalogTopChrome({
    super.key,
    required this.actions,
    this.selections = const {},
    this.selectionLabels = const {},
    this.onSelect,
    this.title,
    this.actionSlots = const {},
    this.center,
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

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      final t = title?.trim() ?? '';
      if (t.isEmpty) return const SizedBox(height: 8);
      return SizedBox(
        height: 48,
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
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    final leading = <Widget>[];
    final trailing = <Widget>[];
    for (final action in actions) {
      final actionId = (action['id'] ?? '').toString().trim();
      if (actionId.isEmpty) continue;
      final bucket = _isTrailing(action) ? trailing : leading;
      final slot = actionSlots[actionId];
      if (slot != null) {
        bucket.add(slot);
        continue;
      }
      final verb = _verb(action);
      final icon = catalogChromeActionIcon(action);
      final nested = propsIdLabelList(action, 'items');
      final isView = actionId == 'view' || verb == 'view';
      final isIconOnly = nested.isEmpty &&
          (actionId == 'search' ||
              actionId == 'refresh' ||
              verb == 'eventsearch' ||
              verb == 'refresh' ||
              verb == 'search');

      if (isView && nested.isNotEmpty) {
        final cur = (selections[actionId] ??
                (action['default'] ?? nested.first.id).toString())
            .trim()
            .toLowerCase();
        final cycle = [for (final e in nested) e.id.toLowerCase()];
        final idx = cycle.indexOf(cur);
        final current = idx < 0 ? cycle.first : cycle[idx];
        final next = cycle[(cycle.indexOf(current) + 1) % cycle.length];
        final (viewIcon, viewLabel) = switch (current) {
          'timeline' || 'schedule' => (
              Icons.view_timeline_rounded,
              'Timeline view',
            ),
          'list' => (Icons.view_list_rounded, 'List view'),
          'grid' => (Icons.grid_on_rounded, 'Grid view'),
          _ => (Icons.grid_view_rounded, 'Cards view'),
        };
        bucket.add(
          ForjaActionChip(
            label: viewLabel,
            icon: viewIcon,
            iconOnly: true,
            selected: false,
            onTap: onSelect == null ? () {} : () => onSelect!(actionId, next),
          ),
        );
        continue;
      }

      if (isIconOnly) {
        bucket.add(
          ForjaActionChip(
            label: (action['label'] ?? actionId).toString(),
            icon: icon ??
                (verb == 'search' || verb == 'eventsearch'
                    ? Icons.search_rounded
                    : Icons.refresh_rounded),
            iconOnly: true,
            selected: false,
            onTap: onSelect == null
                ? () {}
                : () => onSelect!(actionId, actionId),
          ),
        );
        continue;
      }

      if (nested.isNotEmpty) {
        bucket.add(
          ForjaActionChip(
            label: _selectedLabel(action, selections, selectionLabels),
            icon: icon,
            selected: _isSelectedMenu(action, selections),
            onTap: onSelect == null
                ? () {}
                // Host opens the real Catalog / Schedule sheet (not a flat fallback).
                : () => onSelect!(actionId, '__open__'),
          ),
        );
        continue;
      }

      bucket.add(
        ForjaActionChip(
          label: (action['label'] ?? actionId).toString(),
          icon: icon,
          selected: false,
          onTap: onSelect == null
              ? () {}
              : () => onSelect!(actionId, actionId),
        ),
      );
    }

    return TopBarActions(
      leading: leading,
      trailing: trailing,
      center: center,
      padding: EdgeInsets.fromLTRB(
        ShellTokens.compactChromeLeadingInset(context),
        ShellTokens.tabHeaderTopPadding,
        ShellTokens.bodyHorizontalPadding,
        4,
      ),
    );
  }
}
