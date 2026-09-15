import 'package:flutter/material.dart';
import 'package:forja_foundation/components/empty.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/catalog/event_card.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/chrome/logo_menu_rail.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';

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

/// Top action chrome — leading + trailing chip groups from pack `actions[]`.
class CatalogTopChrome extends StatelessWidget {
  const CatalogTopChrome({
    super.key,
    required this.actions,
    this.selections = const {},
    this.onSelect,
    this.title,
    this.actionSlots = const {},
  });

  final List<Map<String, dynamic>> actions;
  final Map<String, String> selections;
  final void Function(String actionId, String value)? onSelect;
  final String? title;

  /// Host-painted overrides keyed by action id (e.g. portals → [PortalsChip]).
  final Map<String, Widget> actionSlots;

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
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
      final slot = actionSlots[actionId];
      if (slot != null) {
        (action['trailing'] == true ? trailing : leading).add(slot);
        continue;
      }
      final label = (action['label'] ?? actionId).toString();
      final isTrailing = action['trailing'] == true;
      final nested = propsIdLabelList(action, 'items');
      final icon = catalogChromeActionIcon(action);
      final verb =
          (action['action'] ?? actionId).toString().trim().toLowerCase();
      late final Widget chip;
      if (nested.isEmpty) {
        final iconOnly = icon != null &&
            (actionId == 'search' ||
                actionId == 'refresh' ||
                actionId == 'portals' ||
                verb == 'eventsearch' ||
                verb == 'portals' ||
                verb == 'refresh' ||
                verb == 'search');
        chip = ForjaShellChip(
          label: iconOnly ? '' : label,
          icon: icon,
          selected: false,
          onTap: onSelect == null
              ? null
              : () => onSelect!(actionId, actionId),
        );
      } else if (actionId == 'view' || verb == 'view') {
        // Shelf view: every option as its own icon (grid / list / …).
        final selected = selections[actionId] ??
            (action['default'] ?? nested.first.id).toString();
        chip = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < nested.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              ForjaShellChip(
                label: '',
                icon: _viewItemIcon(nested[i].id),
                selected: selected == nested[i].id,
                onTap: onSelect == null
                    ? null
                    : () => onSelect!(actionId, nested[i].id),
              ),
            ],
          ],
        );
      } else {
        // Segment menus (Live / Movies / Series): paint every option.
        final selected = selections[actionId] ??
            (action['default'] ?? nested.first.id).toString();
        chip = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < nested.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              ForjaShellChip(
                label: nested[i].label,
                selected: selected == nested[i].id,
                onTap: onSelect == null
                    ? null
                    : () => onSelect!(actionId, nested[i].id),
              ),
            ],
          ],
        );
      }
      (isTrailing ? trailing : leading).add(chip);
    }

    return Material(
      color: ForjaShellColors.surfaceElevated,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (var i = 0; i < leading.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                leading[i],
              ],
              const Spacer(),
              for (var i = 0; i < trailing.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                trailing[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _viewItemIcon(String id) {
  return switch (id.trim().toLowerCase()) {
    'cards' || 'grid' => Icons.grid_view_rounded,
    'list' => Icons.view_list_rounded,
    'timeline' || 'schedule' => Icons.view_timeline_outlined,
    _ => Icons.view_module_rounded,
  };
}

/// Poster / event card grid from pack `items[]` paint props.
class CatalogCardsGrid extends StatelessWidget {
  const CatalogCardsGrid({
    super.key,
    required this.items,
    this.onItemTap,
    this.emptyTitle = 'Nothing here',
    this.emptyDescription,
    this.cardKind = 'poster',
  });

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item)? onItemTap;
  final String emptyTitle;
  final String? emptyDescription;
  final String cardKind;

  static List<Map<String, dynamic>> itemsFromProps(Map<String, dynamic> props) {
    final v = props['items'];
    if (v is! List) return const [];
    return [
      for (final raw in v)
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Empty(
        title: emptyTitle,
        description: emptyDescription,
        icon: Icons.inbox_outlined,
      );
    }

    final event = cardKind == 'event' || cardKind == 'eventCard';
    if (event) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          final paint = item['paint'];
          final props = paint is Map && paint['props'] is Map
              ? Map<String, dynamic>.from(paint['props'] as Map)
              : (item['props'] is Map
                  ? Map<String, dynamic>.from(item['props'] as Map)
                  : item);
          return Align(
            alignment: Alignment.centerLeft,
            child: EventCard(
              title: (props['title'] ?? '').toString(),
              posterUrl:
                  (props['posterUrl'] ?? props['imageUrl'] ?? '').toString(),
              homeTeam: props['homeTeam']?.toString(),
              awayTeam: props['awayTeam']?.toString(),
              homeBadgeUrl: (props['homeBadgeUrl'] ?? '').toString(),
              awayBadgeUrl: (props['awayBadgeUrl'] ?? '').toString(),
              categoryLabel: (props['categoryLabel'] ?? '').toString(),
              scheduleLabel: (props['scheduleLabel'] ?? '').toString(),
              timeLabel: (props['timeLabel'] ?? '').toString(),
              viewers:
                  props['viewers'] is num ? (props['viewers'] as num).toInt() : 0,
              live: props['live'] == true,
              width: props['width'] is num
                  ? (props['width'] as num).toDouble()
                  : 220,
              height: props['height'] is num
                  ? (props['height'] as num).toDouble()
                  : 124,
              onTap: onItemTap == null ? null : () => onItemTap!(item),
            ),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final paint = item['paint'];
        final props = paint is Map && paint['props'] is Map
            ? Map<String, dynamic>.from(paint['props'] as Map)
            : (item['props'] is Map
                ? Map<String, dynamic>.from(item['props'] as Map)
                : item);
        return InteractivePosterCard(
          imageUrl: (props['imageUrl'] ?? props['posterUrl'] ?? '').toString(),
          title: (props['title'] ?? '').toString(),
          subtitle: props['subtitle']?.toString(),
          rating: props['rating'] is num
              ? (props['rating'] as num).toDouble()
              : null,
          onTap: () => onItemTap?.call(item),
          aspect: PosterAspect.portrait,
          width: 140,
        );
      },
    );
  }
}

/// Side category rail built from id/label items.
class CatalogSideRail extends StatelessWidget {
  const CatalogSideRail({
    super.key,
    required this.items,
    required this.selectedId,
    this.onSelect,
    this.width = 220,
  });

  final List<({String id, String label})> items;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(
        width: width,
        child: const Empty(title: 'No categories', size: EmptySize.sm),
      );
    }
    return ColoredBox(
      color: ForjaShellColors.surfaceElevated,
      child: LogoMenuRail(
        width: width,
        selectedId: selectedId,
        onSelect: onSelect ?? (_) {},
        items: [
          for (final item in items)
            LogoMenuItem(id: item.id, label: item.label),
        ],
      ),
    );
  }
}
