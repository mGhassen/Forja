import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/components/empty.dart';
import 'package:forja_foundation/components/vertical_menu.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/event_card.dart';
import 'package:forja_foundation/widgets/catalog/event_dense_tile.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/chrome/catalog_dense_list.dart';
import 'package:forja_foundation/widgets/chrome/catalog_poster_grid.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/feedback/card_play_overlay.dart';

/// Props map from a pack list `items[]` entry (`paint.props` or flat).
Map<String, dynamic> catalogItemProps(Map<String, dynamic> item) {
  final paint = item['paint'];
  if (paint is Map && paint['props'] is Map) {
    return Map<String, dynamic>.from(paint['props'] as Map);
  }
  if (item['props'] is Map) {
    return Map<String, dynamic>.from(item['props'] as Map);
  }
  return Map<String, dynamic>.from(item);
}

/// Poster / event / dense list from pack `items[]` — pre-wipe density + hover.
class CatalogCardsGrid extends StatelessWidget {
  const CatalogCardsGrid({
    super.key,
    required this.items,
    this.onItemTap,
    this.emptyTitle = 'Nothing here',
    this.emptyDescription,
    this.cardKind = 'poster',
    this.selectedItemId,
    this.gap,
    this.pad,
  });

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item)? onItemTap;
  final String emptyTitle;
  final String? emptyDescription;

  /// `poster` · `event`/`cards` · `dense`/`list`
  final String cardKind;
  final String? selectedItemId;

  /// Grid spacing. Null → ShellTokens / TV defaults.
  final double? gap;

  /// Horizontal inset for event/poster grids. Null → catalog density pad.
  final double? pad;

  static List<Map<String, dynamic>> itemsFromProps(Map<String, dynamic> props) {
    final v = props['items'];
    if (v is! List) return const [];
    return [
      for (final raw in v)
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
  }

  bool get _dense =>
      cardKind == 'dense' || cardKind == 'list' || cardKind == 'timeline';

  bool get _event =>
      cardKind == 'event' ||
      cardKind == 'eventCard' ||
      cardKind == 'cards';

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Empty(
        title: emptyTitle,
        description: emptyDescription,
        icon: Icons.inbox_outlined,
      );
    }

    if (_dense) return _denseList(context);
    if (_event) return _eventGrid(context);
    return _posterGrid(context);
  }

  Widget _denseList(BuildContext context) {
    final inset = pad ?? ShellTokens.compactChromeLeadingInset(context);
    final trail = pad ?? ShellTokens.bodyHorizontalPadding;
    return CatalogDenseList(
      itemCount: items.length,
      leading: inset,
      trailing: trail,
      itemBuilder: (context, i) {
        final item = items[i];
        final props = catalogItemProps(item);
        final id = (item['id'] ?? props['id'] ?? '').toString();
        final live = props['live'] == true || props['airing'] == true;
        final title = (props['title'] ?? '').toString();
        final meta = eventDenseMetaLine(
          airing: live,
          startsAt: (props['startsAt'] ?? props['timeLabel'] ?? '').toString(),
          badge: (props['categoryLabel'] ?? props['badge'] ?? '').toString(),
        );
        final viewers =
            props['viewers'] is num ? (props['viewers'] as num).toInt() : 0;
        return _HoverDenseTile(
          title: title,
          meta: meta,
          airing: live,
          viewers: viewers,
          selected: selectedItemId != null &&
              selectedItemId!.isNotEmpty &&
              selectedItemId == id,
          onTap: onItemTap == null ? null : () => onItemTap!(item),
        );
      },
    );
  }

  Widget _eventGrid(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final minW = InteractiveEventCard.cardWidth(context);
    final minH = InteractiveEventCard.cardHeight(context);
    final gap = this.gap ??
        (tv ? ShellTokens.tvPosterCardRowGap : 14.0).clamp(8.0, 12.0);
    final pad = this.pad ?? catalogSectionHorizontalPadding(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = CatalogPosterGridLayout.eventCards(
          maxWidth: constraints.maxWidth,
          minW: minW,
          minH: minH,
          gap: gap,
          pad: pad,
        );
        return CatalogPosterGrid(
          layout: layout,
          itemCount: items.length,
          useAspectRatio: false,
          itemBuilder: (context, i) {
            final item = items[i];
            final props = catalogItemProps(item);
            final id = (item['id'] ?? props['id'] ?? '').toString();
            return InteractiveEventCard(
              props: props,
              width: layout.cardW,
              height: layout.cardH,
              selected: selectedItemId != null &&
                  selectedItemId!.isNotEmpty &&
                  selectedItemId == id,
              gridIndex: i,
              gridColumns: layout.columns,
              onTap: onItemTap == null ? null : () => onItemTap!(item),
            );
          },
        );
      },
    );
  }

  Widget _posterGrid(BuildContext context) {
    final landscape = _catalogGridIsLandscape(items);
    final aspect =
        landscape ? PosterAspect.landscape : PosterAspect.portrait;
    final cardW = InteractivePosterCard.cardWidth(context, aspect: aspect);
    final cardH = InteractivePosterCard.cardHeight(context, aspect: aspect);
    final gap = this.gap ??
        (ShellPaintScope.usesTvDensityOf(context)
            ? ShellTokens.tvPosterCardRowGap
            : ShellTokens.posterCardRowGap);
    final leading = pad ?? ShellTokens.compactChromeLeadingInset(context);
    final trailing = pad ?? ShellTokens.bodyHorizontalPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = CatalogPosterGridLayout.poster(
          maxWidth: constraints.maxWidth,
          cardW: cardW,
          cardH: cardH,
          gap: gap,
          leading: leading,
          trailing: trailing,
        );
        return CatalogPosterGrid(
          layout: layout,
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final props = catalogItemProps(item);
            final aspectRaw = (props['aspect'] ?? '').toString().toLowerCase();
            final itemLandscape =
                aspectRaw == 'landscape' || landscape;
            final badge = (props['badge'] ?? '').toString();
            final subtitle = (props['subtitle'] ?? '').toString();
            return InteractivePosterCard(
              imageUrl: (props['imageUrl'] ??
                      props['posterUrl'] ??
                      props['logoUrl'] ??
                      '')
                  .toString(),
              title: (props['title'] ?? '').toString(),
              subtitle: subtitle.isEmpty ? null : subtitle,
              rating: props['rating'] is num
                  ? (props['rating'] as num).toDouble()
                  : null,
              badge: badge.isEmpty ? null : badge,
              onTap: () => onItemTap?.call(item),
              aspect: itemLandscape
                  ? PosterAspect.landscape
                  : PosterAspect.portrait,
              width: layout.cardW,
              height: layout.cardH,
              gridIndex: i,
              gridColumns: layout.columns,
            );
          },
        );
      },
    );
  }
}

bool _catalogGridIsLandscape(List<Map<String, dynamic>> items) {
  for (final item in items.take(12)) {
    final props = catalogItemProps(item);
    if ((props['aspect'] ?? '').toString().toLowerCase() == 'landscape') {
      return true;
    }
  }
  return false;
}

/// Event card with hover/focus active chrome + live play overlay.
class InteractiveEventCard extends StatefulWidget {
  const InteractiveEventCard({
    super.key,
    required this.props,
    required this.width,
    required this.height,
    this.onTap,
    this.selected = false,
    this.gridIndex,
    this.gridColumns,
  });

  final Map<String, dynamic> props;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool selected;
  final int? gridIndex;
  final int? gridColumns;

  static const widthScale = 1.15;
  static const heightScale = 1.32;

  static double cardWidth(BuildContext context) {
    final base = catalogContinueCardWidth(context, wide: true);
    if (ShellPaintScope.usesTvDensityOf(context)) return base;
    return base * widthScale;
  }

  static double cardHeight(BuildContext context) {
    final base = catalogContinueCardHeight(context, wide: true);
    if (ShellPaintScope.usesTvDensityOf(context)) {
      return base +
          InteractivePosterCard.scaled(context, 40).clamp(32.0, 48.0);
    }
    return (base * heightScale).clamp(190.0, 230.0);
  }

  @override
  State<InteractiveEventCard> createState() => _InteractiveEventCardState();
}

class _InteractiveEventCardState extends State<InteractiveEventCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final props = widget.props;
    final live = props['live'] == true;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final active = ShellPaintScope.interactiveActive(
          context,
          hovered: _hovered,
          focused: _focused,
        ) ||
        widget.selected;
    final radius = tv
        ? InteractivePosterCard.cardBorderRadius(context)
        : 14.0;

    final paint = EventCard(
      title: (props['title'] ?? '').toString(),
      posterUrl: (props['posterUrl'] ?? props['imageUrl'] ?? '').toString(),
      homeTeam: props['homeTeam']?.toString(),
      awayTeam: props['awayTeam']?.toString(),
      homeBadgeUrl: (props['homeBadgeUrl'] ?? '').toString(),
      awayBadgeUrl: (props['awayBadgeUrl'] ?? '').toString(),
      categoryLabel: (props['categoryLabel'] ?? '').toString(),
      scheduleLabel: (props['scheduleLabel'] ?? '').toString(),
      timeLabel: (props['timeLabel'] ?? '').toString(),
      viewers: props['viewers'] is num ? (props['viewers'] as num).toInt() : 0,
      live: live,
      selected: widget.selected,
      active: active,
      tvDensity: tv,
      width: widget.width,
      height: widget.height,
      borderRadius: radius,
      playOverlay: live
          ? ShellCardPlayOverlay(
              active: tv ? true : active,
              visible: true,
              diameter: tv ? 28 : 48,
              iconSize: tv ? 16 : 28,
            )
          : null,
    );

    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: radius,
      scaleOnFocus: 1.0,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      tvZone: ShellPaintTvZone.grid,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: paint,
    );
  }
}

class _HoverDenseTile extends StatefulWidget {
  const _HoverDenseTile({
    required this.title,
    required this.meta,
    required this.airing,
    required this.viewers,
    required this.selected,
    this.onTap,
  });

  final String title;
  final String meta;
  final bool airing;
  final int viewers;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_HoverDenseTile> createState() => _HoverDenseTileState();
}

class _HoverDenseTileState extends State<_HoverDenseTile> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tile = EventDenseTile(
      title: widget.title,
      meta: widget.meta,
      airing: widget.airing,
      viewers: widget.viewers,
      selected: widget.selected,
      hovered: _hovered,
      focused: _focused,
      onTap: null,
    );
    if (!ShellPaintScope.useTvFocusOf(context)) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: tile,
        ),
      );
    }
    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      scaleOnFocus: 1.0,
      showFocusFill: false,
      showFocusBorder: false,
      tvZone: ShellPaintTvZone.row,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: tile,
    );
  }
}

/// Side category rail — selected + hover green rail (IPTV cats).
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
      color: ForjaShellColors.bgDark,
      child: SizedBox(
        width: width,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final selected = item.id == selectedId;
            return VerticalMenu.item(
              key: ValueKey(item.id),
              label: item.label,
              selected: selected,
              accentHover: true,
              onTap: onSelect == null ? null : () => onSelect!(item.id),
            );
          },
        ),
      ),
    );
  }
}
