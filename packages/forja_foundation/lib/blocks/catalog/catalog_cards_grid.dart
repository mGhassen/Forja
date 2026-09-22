import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/components/empty.dart';
import 'package:forja_foundation/components/vertical_menu.dart';
import 'package:forja_foundation/tokens/event_card_tokens.dart';
import 'package:forja_foundation/tokens/channel_card_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/catalog_channel_card.dart';
import 'package:forja_foundation/widgets/catalog/catalog_epg_guide.dart';
import 'package:forja_foundation/widgets/catalog/event_card.dart';
import 'package:forja_foundation/widgets/catalog/event_dense_tile.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/chrome/catalog_dense_list.dart';
import 'package:forja_foundation/widgets/chrome/catalog_poster_grid.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/feedback/card_play_overlay.dart';
import 'package:forja_foundation/widgets/focus/list_letter_jump_scope.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:forja_foundation/widgets/guide/guide_epg_programme.dart';

/// Props map from a pack list `items[]` entry (`paint.props` or flat).
///
/// Canonical paint keys: `title`, `imageUrl`, `id`, `streamId`, …
/// Alias → canonical mapping happens here once so widgets do not invent fields.
Map<String, dynamic> catalogItemProps(Map<String, dynamic> item) {
  Map<String, dynamic> raw;
  final paint = item['paint'];
  if (paint is Map && paint['props'] is Map) {
    raw = Map<String, dynamic>.from(paint['props'] as Map);
  } else if (item['props'] is Map) {
    raw = Map<String, dynamic>.from(item['props'] as Map);
  } else {
    raw = Map<String, dynamic>.from(item);
  }
  final title =
      (raw['title'] ?? raw['name'] ?? item['name'] ?? item['title'] ?? '')
          .toString()
          .trim();
  final imageUrl =
      (raw['imageUrl'] ??
              raw['posterUrl'] ??
              raw['poster'] ??
              raw['logo'] ??
              item['poster'] ??
              item['logo'] ??
              '')
          .toString()
          .trim();
  if (title.isNotEmpty) raw['title'] = title;
  if (imageUrl.isNotEmpty) raw['imageUrl'] = imageUrl;
  final id = (raw['id'] ?? item['id'] ?? '').toString().trim();
  if (id.isNotEmpty) raw['id'] = id;
  final streamId =
      (raw['streamId'] ??
              item['streamId'] ??
              (item['open'] is Map ? item['open']['streamId'] : null) ??
              '')
          .toString()
          .trim();
  if (streamId.isNotEmpty) raw['streamId'] = streamId;

  // Home / My List flat rows — same card chrome as painted posters.
  if (raw['rating'] is! num) {
    final vote = raw['voteAverage'] ?? item['voteAverage'] ?? item['rating'];
    if (vote is num && vote > 0) raw['rating'] = vote.toDouble();
  }
  final subtitle = (raw['subtitle'] ?? '').toString().trim();
  if (subtitle.isEmpty) {
    final release =
        (raw['releaseInfo'] ??
                item['releaseInfo'] ??
                raw['releaseDate'] ??
                item['releaseDate'] ??
                raw['year'] ??
                item['year'] ??
                '')
            .toString()
            .trim();
    final year = release.contains('-')
        ? release.split('-').first
        : (release.length >= 4 ? release.substring(0, 4) : release);
    final kind =
        (raw['mediaType'] ??
                raw['type'] ??
                raw['kind'] ??
                item['mediaType'] ??
                item['type'] ??
                item['kind'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();
    final typeLabel = switch (kind) {
      'tv' || 'series' || 'shows' => 'TV',
      'movie' || 'movies' => 'FILM',
      'anime' => 'ANIME',
      'asian_drama' || 'drama' => 'DRAMA',
      _ => null,
    };
    final parts = <String>[
      if (year.isNotEmpty) year,
      if (typeLabel != null) typeLabel,
    ];
    if (parts.isNotEmpty) raw['subtitle'] = parts.join(' • ');
  }
  // Flat rows only — when paint.props exists, omit means omit (no meta.badge re-inject).
  if (!(paint is Map && paint['props'] is Map)) {
    final badge = (raw['badge'] ?? item['badge'] ?? '').toString().trim();
    if (badge.isNotEmpty) raw['badge'] = badge;
  }

  return raw;
}

/// Poster / event / dense list from pack `items[]` — pre-wipe density + hover.
class CatalogCardsGrid extends StatelessWidget {
  const CatalogCardsGrid({
    super.key,
    required this.items,
    this.onItemTap,
    this.emptyTitle = 'Nothing here',
    this.emptyDescription,
    this.emptyAction,
    this.cardKind = 'poster',
    this.selectedItemId,
    this.gap,
    this.pad,
    this.cardWidth,
    this.itemAccessory,
    this.itemHealth,
    this.itemHealthListenable,
    this.onItemInteractiveActive,
    this.loadEpgProgrammes,
    this.landEpoch,
    this.onHoldJumpToCategory,
    this.preferCategoryFocusOnLand = true,
    /// Read live at land epoch (static host flag may change without rebuild).
    this.preferCategoryFocusNow,
    this.onRequestFocusAt,
    this.onArmFocusMemory,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,

    /// IPTV Live: ↑ from top row left half → shelf; right half → portals chip.
    this.onUpEdgeLeftHalf,
    this.onUpEdgeRightHalf,
    this.onScrollIntoViewChanged,
  });

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item)? onItemTap;
  final String emptyTitle;
  final String? emptyDescription;

  /// Optional CTA under the empty copy (e.g. Open portal).
  final Widget? emptyAction;

  /// `poster` · `event`/`cards` · `dense`/`list` · `channel` · `channelList` · `guide`/`epg`
  final String cardKind;
  final String? selectedItemId;

  /// Grid spacing. Null → ShellTokens / TV defaults.
  final double? gap;

  /// Horizontal inset for event/poster grids. Null → catalog density pad.
  final double? pad;

  /// Poster grid min cell width (desktop) — cells stretch to fill the row.
  /// Null → [InteractivePosterCard.cardWidth]. Ignored for channel / event grids.
  final double? cardWidth;

  /// Optional corner control (e.g. live favorite star). [active] = hover/focus.
  final Widget? Function(
    BuildContext context,
    Map<String, dynamic> item, {
    required bool active,
  })?
  itemAccessory;

  /// Live channel stream health (`null` unknown).
  final bool? Function(Map<String, dynamic> item)? itemHealth;

  /// Per-channel health listenable (preferred over [itemHealth] for grids).
  final ValueListenable<bool?>? Function(Map<String, dynamic> item)?
  itemHealthListenable;

  /// Hover/focus dwell for host URL probe (live channels).
  final void Function(Map<String, dynamic> item, {required bool active})?
  onItemInteractiveActive;

  /// Lazy EPG table fetch for [cardKind] `guide` / `epg`.
  final Future<List<GuideEpgProgramme>> Function(Map<String, dynamic> item)?
  loadEpgProgrammes;

  /// Bumped by host to scroll/focus [selectedItemId] (after player / hydrate).
  final ValueListenable<int>? landEpoch;

  /// Favorites / Already watched: hold OK ~1s → jump to portal category.
  final void Function(Map<String, dynamic> item)? onHoldJumpToCategory;

  /// When landing a restored channel, keep D-pad on category rail (arm memory).
  final bool preferCategoryFocusOnLand;

  /// Live read at land epoch — host static may flip without rebuilding this widget.
  final bool Function()? preferCategoryFocusNow;

  /// Pack `focusLeft` / `focusRight` (e.g. IPTV → cats, Live Sports → Providers).
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  /// Pack `focusUp` — first list row / first grid row (Live Sports → kind).
  final VoidCallback? onUpEdge;

  /// IPTV Live: ↑ from top-row left half → shelf (catalog).
  final VoidCallback? onUpEdgeLeftHalf;

  /// IPTV Live: ↑ from top-row right half → portals chip.
  final VoidCallback? onUpEdgeRightHalf;

  /// Host focuses TV item after scroll (lazy grid).
  final ValueChanged<int>? onRequestFocusAt;

  /// Host arms D-pad memory without stealing category focus.
  final ValueChanged<int>? onArmFocusMemory;

  /// Host registers scroll-into-view for lazy TV restore (shelf / chrome ↓).
  /// Called with the scroller on mount; `null` on dispose.
  final ValueChanged<void Function(int)?>? onScrollIntoViewChanged;

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
      cardKind == 'event' || cardKind == 'eventCard' || cardKind == 'cards';

  bool get _channel =>
      cardKind == 'channel' ||
      cardKind == 'liveChannel' ||
      cardKind == 'channelList';

  bool get _guide => cardKind == 'guide' || cardKind == 'epg';

  bool get _forceChannelList => cardKind == 'channelList';

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Empty(
        title: emptyTitle,
        description: emptyDescription,
        icon: Icons.inbox_outlined,
        action: emptyAction,
      );
    }

    if (_guide) return _epgGuide(context);
    if (_dense) return _denseList(context);
    if (_event) return _eventGrid(context);
    if (_channel) return _channelGrid(context);
    return _posterGrid(context);
  }

  /// Pack `focusLeft` — only column 0 (or every row in a 1-col list).
  VoidCallback? _gridOnLeftEdge(int index, int columns) {
    if (onLeftEdge == null || columns <= 0) return null;
    if (index % columns != 0) return null;
    return onLeftEdge;
  }

  /// Pack `focusRight` — last column of a row, or last item overall.
  VoidCallback? _gridOnRightEdge(int index, int columns) {
    if (onRightEdge == null || columns <= 0) return null;
    final lastCol = index % columns >= columns - 1;
    final lastItem = index >= items.length - 1;
    if (!lastCol && !lastItem) return null;
    return onRightEdge;
  }

  /// ↑ from top row: left half → shelf, right half → portals (when split set).
  VoidCallback? _gridOnUpEdge(int index, int columns) {
    final left = onUpEdgeLeftHalf;
    final right = onUpEdgeRightHalf;
    if (left == null && right == null) return onUpEdge;
    if (columns <= 0) return onUpEdge ?? left ?? right;
    final col = index % columns;
    final half = (columns / 2).ceil();
    if (col < half) return left ?? onUpEdge ?? right;
    return right ?? onUpEdge ?? left;
  }

  Widget _epgGuide(BuildContext context) {
    final channels = <CatalogEpgChannel>[
      for (final item in items)
        CatalogEpgChannel(
          id: _itemId(item),
          title: _itemTitle(item),
          imageUrl: _itemImage(item),
          programmes: CatalogChannelCard.programmesFromRaw(
            item['programmes'] ?? catalogItemProps(item)['programmes'],
          ),
          payload: item,
        ),
    ];
    return CatalogEpgGuide(
      channels: channels,
      highlightChannelId: selectedItemId,
      emptyTitle: emptyTitle,
      loadProgrammes: loadEpgProgrammes == null
          ? null
          : (ch) {
              final item = ch.payload;
              if (item is! Map<String, dynamic>) {
                return Future.value(const <GuideEpgProgramme>[]);
              }
              return loadEpgProgrammes!(item);
            },
      accessoryBuilder: itemAccessory == null
          ? null
          : (ch, {required active}) {
              final item = ch.payload;
              if (item is! Map<String, dynamic>) return null;
              return itemAccessory!(context, item, active: active);
            },
      onChannelTap: (ch) {
        final item = ch.payload;
        if (item is Map<String, dynamic>) onItemTap?.call(item);
      },
    );
  }

  static String _itemId(Map<String, dynamic> item) {
    final props = catalogItemProps(item);
    for (final key in [props['streamId'], props['id']]) {
      final v = (key ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  static String _itemTitle(Map<String, dynamic> item) =>
      (catalogItemProps(item)['title'] ?? '').toString();

  static String _itemImage(Map<String, dynamic> item) =>
      (catalogItemProps(item)['imageUrl'] ?? '').toString();

  Widget _channelGrid(BuildContext context) {
    return _ChannelLetterJumpGrid(
      items: items,
      selectedItemId: selectedItemId,
      gap: gap,
      pad: pad,
      forceList: _forceChannelList,
      itemAccessory: itemAccessory,
      itemHealth: itemHealth,
      itemHealthListenable: itemHealthListenable,
      onItemInteractiveActive: onItemInteractiveActive,
      loadEpgProgrammes: loadEpgProgrammes,
      onItemTap: onItemTap,
      landEpoch: landEpoch,
      onHoldJumpToCategory: onHoldJumpToCategory,
      preferCategoryFocusOnLand: preferCategoryFocusOnLand,
      preferCategoryFocusNow: preferCategoryFocusNow,
      onRequestFocusAt: onRequestFocusAt,
      onArmFocusMemory: onArmFocusMemory,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
      onUpEdge: onUpEdge,
      onUpEdgeLeftHalf: onUpEdgeLeftHalf,
      onUpEdgeRightHalf: onUpEdgeRightHalf,
      onScrollIntoViewChanged: onScrollIntoViewChanged,
    );
  }

  Widget _denseList(BuildContext context) {
    final inset = pad ?? ShellTokens.compactChromeLeadingInset(context);
    final trail = pad ?? ShellTokens.bodyHorizontalPadding;
    return _OwnedScrollHost(
      onScrollIntoViewChanged: onScrollIntoViewChanged,
      scrollToIndex: (scroll, index) {
        if (!scroll.hasClients || index < 0) return;
        const rowH = 56.0;
        const topPad = 4.0;
        final target = (topPad + index * rowH).clamp(
          0.0,
          scroll.position.maxScrollExtent,
        );
        if ((scroll.offset - target).abs() < 0.5) return;
        scroll.jumpTo(target);
      },
      builder: (context, controller) => CatalogDenseList(
        controller: controller,
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
            startsAt: (props['startsAt'] ?? props['timeLabel'] ?? '')
                .toString(),
            badge: (props['categoryLabel'] ?? props['badge'] ?? '').toString(),
          );
          final viewers = props['viewers'] is num
              ? (props['viewers'] as num).toInt()
              : 0;
          return _HoverDenseTile(
            title: title,
            meta: meta,
            airing: live,
            viewers: viewers,
            selected:
                selectedItemId != null &&
                selectedItemId!.isNotEmpty &&
                selectedItemId == id,
            listIndex: i,
            onLeftEdge: onLeftEdge,
            onRightEdge: onRightEdge,
            onUpEdge: i == 0 ? onUpEdge : null,
            onTap: onItemTap == null ? null : () => onItemTap!(item),
          );
        },
      ),
    );
  }

  Widget _eventGrid(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final minW = InteractiveEventCard.cardWidth(context);
    final minH = InteractiveEventCard.cardHeight(context);
    final gap = this.gap ?? ShellTokens.chromeScale(14.0, tv: tv);
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
        return _OwnedScrollHost(
          onScrollIntoViewChanged: onScrollIntoViewChanged,
          scrollToIndex: (scroll, index) {
            if (!scroll.hasClients || index < 0) return;
            final cols = layout.columns.clamp(1, 999);
            final row = index ~/ cols;
            final rowExtent = layout.cardH + layout.gap;
            final target = (layout.topPad + row * rowExtent).clamp(
              0.0,
              scroll.position.maxScrollExtent,
            );
            if ((scroll.offset - target).abs() < 0.5) return;
            scroll.jumpTo(target);
          },
          builder: (context, controller) => CatalogPosterGrid(
            controller: controller,
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
                selected:
                    selectedItemId != null &&
                    selectedItemId!.isNotEmpty &&
                    selectedItemId == id,
                gridIndex: i,
                gridColumns: layout.columns,
                onLeftEdge: _gridOnLeftEdge(i, layout.columns),
                onRightEdge: _gridOnRightEdge(i, layout.columns),
                onUpEdge: i < layout.columns
                    ? _gridOnUpEdge(i, layout.columns)
                    : null,
                onTap: onItemTap == null ? null : () => onItemTap!(item),
              );
            },
          ),
        );
      },
    );
  }

  Widget _posterGrid(BuildContext context) {
    final landscape = _catalogGridIsLandscape(items);
    final aspect = landscape ? PosterAspect.landscape : PosterAspect.portrait;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final overrideW = cardWidth;
    final double cardW;
    final double cardH;
    if (overrideW != null && overrideW > 0) {
      cardW = overrideW;
      cardH = landscape
          ? (overrideW * 9 / 16).roundToDouble()
          : (overrideW * ShellTokens.posterCardAspectRatio).roundToDouble();
    } else {
      cardW = InteractivePosterCard.cardWidth(context, aspect: aspect);
      cardH = InteractivePosterCard.cardHeight(context, aspect: aspect);
    }
    final gap =
        this.gap ??
        (tv ? ShellTokens.tvPosterCardRowGap : ShellTokens.posterCardRowGap);
    // Beside category rail — same pads as Live channels (not ☰ chrome inset).
    final leading = pad ?? ShellTokens.catalogSplitGridLeadingPad;
    final trailing = pad ?? ShellTokens.catalogSplitGridTrailingPad;

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
            final itemLandscape = aspectRaw == 'landscape' || landscape;
            final badge = (props['badge'] ?? '').toString();
            final subtitle = (props['subtitle'] ?? '').toString();
            return InteractivePosterCard(
              imageUrl:
                  (props['imageUrl'] ??
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
              listPinBuilder: itemAccessory == null
                  ? null
                  : ({required bool active}) =>
                        itemAccessory!(context, item, active: active),
              onTap: () => onItemTap?.call(item),
              aspect: itemLandscape
                  ? PosterAspect.landscape
                  : PosterAspect.portrait,
              width: layout.cardW,
              height: layout.cardH,
              gridIndex: i,
              gridColumns: layout.columns,
              onLeftEdge: _gridOnLeftEdge(i, layout.columns),
              onRightEdge: _gridOnRightEdge(i, layout.columns),
              onUpEdge: i < layout.columns
                  ? _gridOnUpEdge(i, layout.columns)
                  : null,
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

/// Owns a [ScrollController] and offers scroll-into-view to the host.
class _OwnedScrollHost extends StatefulWidget {
  const _OwnedScrollHost({
    required this.builder,
    required this.scrollToIndex,
    this.onScrollIntoViewChanged,
  });

  final Widget Function(BuildContext context, ScrollController controller)
  builder;
  final void Function(ScrollController scroll, int index) scrollToIndex;
  final ValueChanged<void Function(int)?>? onScrollIntoViewChanged;

  @override
  State<_OwnedScrollHost> createState() => _OwnedScrollHostState();
}

class _OwnedScrollHostState extends State<_OwnedScrollHost> {
  final ScrollController _scroll = ScrollController();

  void _scrollTo(int index) => widget.scrollToIndex(_scroll, index);

  void _offer() => widget.onScrollIntoViewChanged?.call(_scrollTo);

  @override
  void initState() {
    super.initState();
    _offer();
  }

  @override
  void didUpdateWidget(covariant _OwnedScrollHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.onScrollIntoViewChanged,
      widget.onScrollIntoViewChanged,
    )) {
      oldWidget.onScrollIntoViewChanged?.call(null);
      _offer();
    }
  }

  @override
  void dispose() {
    widget.onScrollIntoViewChanged?.call(null);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _scroll);
}

/// Channel cards + type-to-jump. Competes with category rail via last hover
/// ([ListLetterJumpScope] active ownership).
class _ChannelLetterJumpGrid extends StatefulWidget {
  const _ChannelLetterJumpGrid({
    required this.items,
    this.selectedItemId,
    this.gap,
    this.pad,
    this.forceList = false,
    this.itemAccessory,
    this.itemHealth,
    this.itemHealthListenable,
    this.onItemInteractiveActive,
    this.loadEpgProgrammes,
    this.onItemTap,
    this.landEpoch,
    this.onHoldJumpToCategory,
    this.preferCategoryFocusOnLand = true,
    this.preferCategoryFocusNow,
    this.onRequestFocusAt,
    this.onArmFocusMemory,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onUpEdgeLeftHalf,
    this.onUpEdgeRightHalf,
    this.onScrollIntoViewChanged,
  });

  final List<Map<String, dynamic>> items;
  final String? selectedItemId;
  final double? gap;
  final double? pad;

  /// IPTV View → List (and Sources-style rows) — always list, never cards grid.
  final bool forceList;
  final Widget? Function(
    BuildContext context,
    Map<String, dynamic> item, {
    required bool active,
  })?
  itemAccessory;
  final bool? Function(Map<String, dynamic> item)? itemHealth;
  final ValueListenable<bool?>? Function(Map<String, dynamic> item)?
  itemHealthListenable;
  final void Function(Map<String, dynamic> item, {required bool active})?
  onItemInteractiveActive;
  final Future<List<GuideEpgProgramme>> Function(Map<String, dynamic> item)?
  loadEpgProgrammes;
  final void Function(Map<String, dynamic> item)? onItemTap;
  final ValueListenable<int>? landEpoch;
  final void Function(Map<String, dynamic> item)? onHoldJumpToCategory;
  final bool preferCategoryFocusOnLand;
  final bool Function()? preferCategoryFocusNow;
  final ValueChanged<int>? onRequestFocusAt;
  final ValueChanged<int>? onArmFocusMemory;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onUpEdgeLeftHalf;
  final VoidCallback? onUpEdgeRightHalf;
  final ValueChanged<void Function(int)?>? onScrollIntoViewChanged;

  @override
  State<_ChannelLetterJumpGrid> createState() => _ChannelLetterJumpGridState();
}

class _ChannelLetterJumpGridState extends State<_ChannelLetterJumpGrid> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  CatalogPosterGridLayout? _layout;

  /// Same role as category [selectedId] — letter-jump selection chrome + anchor.
  int _selectedIndex = -1;

  Timer? _logoSettleTimer;
  bool _allowNewLogos = false;
  final Set<String> _revealedLogoIds = <String>{};
  static const _logoSettleDelay = Duration(milliseconds: 500);

  bool get _leanbackOnly =>
      ShellPaintScope.usesTvDensityOf(context) &&
      !ShellPaintScope.scaleOnHoverOf(context);

  bool get _compactList {
    if (widget.forceList) return true;
    if (_leanbackOnly || ShellPaintScope.usesTvDensityOf(context)) {
      return false;
    }
    return MediaQuery.sizeOf(context).width < 720;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.landEpoch?.addListener(_onLandEpoch);
    _offerScrollIntoView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_leanbackOnly) {
        _bumpChannelLogoSettle();
      } else {
        setState(() => _allowNewLogos = true);
      }
      _landSelected(preferCategoryFocus: _preferCategoryFocusLive);
    });
  }

  @override
  void dispose() {
    widget.onScrollIntoViewChanged?.call(null);
    widget.landEpoch?.removeListener(_onLandEpoch);
    _logoSettleTimer?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  bool get _preferCategoryFocusLive =>
      widget.preferCategoryFocusNow?.call() ?? widget.preferCategoryFocusOnLand;

  void _offerScrollIntoView() {
    widget.onScrollIntoViewChanged?.call(_scrollToIndex);
  }

  @override
  void didUpdateWidget(covariant _ChannelLetterJumpGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.landEpoch, widget.landEpoch)) {
      oldWidget.landEpoch?.removeListener(_onLandEpoch);
      widget.landEpoch?.addListener(_onLandEpoch);
    }
    if (!identical(oldWidget.items, widget.items)) {
      _selectedIndex = -1;
      _itemKeys.clear();
      _revealedLogoIds.clear();
      if (_leanbackOnly) {
        _allowNewLogos = false;
        _bumpChannelLogoSettle(hide: true);
      }
    }
    if (oldWidget.selectedItemId != widget.selectedItemId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _landSelected(preferCategoryFocus: _preferCategoryFocusLive);
      });
    }
    if (!identical(
      oldWidget.onScrollIntoViewChanged,
      widget.onScrollIntoViewChanged,
    )) {
      oldWidget.onScrollIntoViewChanged?.call(null);
      _offerScrollIntoView();
    }
  }

  void _onLandEpoch() {
    _landSelected(preferCategoryFocus: _preferCategoryFocusLive);
  }

  void _onScroll() {
    if (!_leanbackOnly) return;
    _bumpChannelLogoSettle(hide: true);
  }

  void _revealChannelLogo(String channelId) {
    final id = channelId.trim();
    if (id.isEmpty || _revealedLogoIds.contains(id)) return;
    setState(() => _revealedLogoIds.add(id));
  }

  void _bumpChannelLogoSettle({bool hide = false}) {
    if (!_leanbackOnly) return;
    _logoSettleTimer?.cancel();
    if (hide) {
      _allowNewLogos = false;
    }
    _logoSettleTimer = Timer(_logoSettleDelay, () {
      if (!mounted) return;
      setState(() {
        _allowNewLogos = true;
      });
    });
  }

  bool _showChannelLogo(String channelId) {
    if (!_leanbackOnly) return true;
    final id = channelId.trim();
    return _revealedLogoIds.contains(id) || _allowNewLogos;
  }

  String _titleAt(int i) {
    final item = widget.items[i];
    final t = CatalogCardsGrid._itemTitle(item).trim();
    return t.isEmpty ? CatalogCardsGrid._itemId(item) : t;
  }

  int _indexOfSelected() {
    final sel = (widget.selectedItemId ?? '').trim();
    if (sel.isEmpty) return -1;
    for (var i = 0; i < widget.items.length; i++) {
      if (CatalogCardsGrid._itemId(widget.items[i]) == sel) return i;
    }
    return -1;
  }

  int _letterJumpAnchor() {
    if (_selectedIndex >= 0 && _selectedIndex < widget.items.length) {
      return _selectedIndex;
    }
    return _indexOfSelected();
  }

  void _letterJump(int index) {
    if (index < 0 || index >= widget.items.length) return;
    setState(() => _selectedIndex = index);
    _scrollAndMaybeFocus(index, focus: false);
  }

  /// Focus / hover may fire while the grid is still building (e.g. after tap
  /// rebuild). Selection setState must not run in that window.
  void _onChannelInteractiveActive(
    int i,
    Map<String, dynamic> item, {
    required bool active,
  }) {
    // Host health probe is setState-free — keep it synchronous.
    widget.onItemInteractiveActive?.call(item, active: active);

    void applySelection() {
      if (!mounted) return;
      if (active) {
        if (_selectedIndex != i) {
          setState(() => _selectedIndex = i);
        }
        // Keep category → landing on this tile (not a stale play highlight).
        widget.onArmFocusMemory?.call(i);
      } else if (_selectedIndex == i) {
        // TV: leaving the tile (e.g. → Portals) must drop play chrome;
        // letter-jump still sets _selectedIndex without focus.
        setState(() => _selectedIndex = -1);
      }
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      applySelection();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => applySelection());
    }
  }

  void _landSelected({required bool preferCategoryFocus}) {
    final idx = _indexOfSelected();
    if (idx < 0) return;
    if (preferCategoryFocus) {
      // Scroll to last-played but leave focus on cats — no channel chrome.
      if (_selectedIndex != -1) setState(() => _selectedIndex = -1);
      _scrollToIndex(idx);
      widget.onArmFocusMemory?.call(idx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToIndex(idx);
        widget.onArmFocusMemory?.call(idx);
      });
      return;
    }
    setState(() => _selectedIndex = idx);
    _scrollAndMaybeFocus(idx, focus: true);
  }

  void _scrollAndMaybeFocus(int index, {required bool focus}) {
    if (index < 0 || index >= widget.items.length) return;
    var tries = 0;
    var scrolledFor = -1;
    void attempt() {
      if (!mounted) return;
      if (scrolledFor != index) {
        _scrollToIndex(index);
        scrolledFor = index;
        tries++;
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      final ctx = _itemKeys[index]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.15, duration: Duration.zero);
      }
      if (!focus || !ShellPaintScope.useTvFocusOf(context)) return;
      final focused = widget.onRequestFocusAt != null;
      if (focused) {
        widget.onRequestFocusAt!(index);
      }
      tries++;
      if (tries < 24) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      }
    }

    attempt();
    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  void _scrollToIndex(int index) {
    if (!_scroll.hasClients || index < 0) return;
    if (_compactList) {
      const rowH = 56.0;
      const topPad = 4.0;
      final target = (topPad + index * rowH).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      if ((_scroll.offset - target).abs() < 0.5) return;
      _scroll.jumpTo(target);
      return;
    }
    final layout = _layout;
    if (layout == null) return;
    final cols = layout.columns.clamp(1, 999);
    final row = index ~/ cols;
    final rowExtent = layout.cardH + layout.gap;
    final target = (layout.topPad + row * rowExtent).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if ((_scroll.offset - target).abs() < 0.5) return;
    _scroll.jumpTo(target);
  }

  /// ↑ from top row: left half of the **viewport** → shelf, right → portals.
  VoidCallback? _channelGridOnUpEdge(int index, int columns) {
    final left = widget.onUpEdgeLeftHalf;
    final right = widget.onUpEdgeRightHalf;
    if (left == null && right == null) return widget.onUpEdge;
    if (left == null) return right;
    if (right == null) return left;
    return () {
      final key = _itemKeys[index];
      final tileCtx = key?.currentContext;
      final gridBox = context.findRenderObject();
      if (tileCtx != null && gridBox is RenderBox && gridBox.hasSize) {
        final tileBox = tileCtx.findRenderObject();
        if (tileBox is RenderBox && tileBox.hasSize) {
          final tileCenter = tileBox.localToGlobal(
            Offset(tileBox.size.width / 2, 0),
          );
          final gridOrigin = gridBox.localToGlobal(Offset.zero);
          final localX = tileCenter.dx - gridOrigin.dx;
          if (localX < gridBox.size.width / 2) {
            left();
          } else {
            right();
          }
          return;
        }
      }
      if (columns <= 0) {
        left();
        return;
      }
      final col = index % columns;
      final half = (columns / 2).ceil();
      if (col < half) {
        left();
      } else {
        right();
      }
    };
  }

  Widget _buildChannelTile(BuildContext context, int i, {required bool list}) {
    final item = widget.items[i];
    final props = catalogItemProps(item);
    final title = CatalogCardsGrid._itemTitle(item);
    final image = CatalogCardsGrid._itemImage(item);
    final programmes = CatalogChannelCard.programmesFromRaw(
      props['programmes'] ?? item['programmes'],
    );
    final id = CatalogCardsGrid._itemId(item);
    final key = _itemKeys.putIfAbsent(i, GlobalKey.new);
    final panelSelected =
        widget.selectedItemId != null &&
        widget.selectedItemId!.isNotEmpty &&
        widget.selectedItemId == id;
    final layout = _layout;
    final cols = list ? 1 : (layout?.columns ?? 1);
    VoidCallback? leftEdge;
    VoidCallback? rightEdge;
    VoidCallback? upEdge;
    if (list) {
      leftEdge = widget.onLeftEdge;
      rightEdge = widget.onRightEdge;
      // Single-column list: still split by viewport half (shelf vs Portals).
      if (i == 0) {
        upEdge = _channelGridOnUpEdge(i, 1);
      }
    } else if (cols > 0) {
      if (widget.onLeftEdge != null && i % cols == 0) {
        leftEdge = widget.onLeftEdge;
      }
      final lastCol = i % cols >= cols - 1;
      final lastItem = i >= widget.items.length - 1;
      if (widget.onRightEdge != null && (lastCol || lastItem)) {
        rightEdge = widget.onRightEdge;
      }
      if (i < cols) {
        upEdge = _channelGridOnUpEdge(i, cols);
      }
    }
    return KeyedSubtree(
      key: key,
      child: CatalogChannelCard(
        title: title,
        imageUrl: image,
        programmes: programmes,
        loadProgrammes: widget.loadEpgProgrammes == null
            ? null
            : () => widget.loadEpgProgrammes!(item),
        health: widget.itemHealth?.call(item),
        healthListenable: widget.itemHealthListenable?.call(item),
        // Sticky last-played id stays for land/scroll; paint is single-chrome
        // (focus / hover / letter-jump emphasize only).
        highlighted: panelSelected,
        emphasize: i == _selectedIndex,
        showLogo: _showChannelLogo(id),
        listLayout: list,
        width: list ? null : layout?.cardW,
        height: list
            ? ChannelCardTokens.listRowHeightOf(
                ShellPaintScope.usesTvDensityOf(context),
              )
            : layout?.cardH,
        gridIndex: i,
        gridColumns: cols,
        onLeftEdge: leftEdge,
        onRightEdge: rightEdge,
        onUpEdge: upEdge,
        onHoldJumpToCategory: widget.onHoldJumpToCategory == null
            ? null
            : () => widget.onHoldJumpToCategory!(item),
        onTap: widget.onItemTap == null
            ? null
            : () {
                setState(() => _selectedIndex = i);
                widget.onItemTap!(item);
              },
        onInteractiveActive: (active) {
          _onChannelInteractiveActive(i, item, active: active);
        },
        onTvFocusGained: _leanbackOnly
            ? () {
                _revealChannelLogo(id);
                _bumpChannelLogoSettle();
              }
            : null,
        favoriteBuilder: widget.itemAccessory == null
            ? null
            : ({required bool active}) =>
                  widget.itemAccessory!(context, item, active: active),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Iso desktop: same square channel tiles + packing on TV (not poster cells).
    final list = _compactList;
    final cardW = CatalogChannelCard.cardWidth(context);
    final cardH = CatalogChannelCard.cardHeight(context);
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final gap = widget.gap ??
        ShellTokens.chromeScale(10.0, tv: tv);
    final leading = widget.pad ?? ShellTokens.catalogSplitGridLeadingPad;
    final trailing = widget.pad ?? ShellTokens.catalogSplitGridTrailingPad;

    Widget body;
    if (list) {
      body = ListView.separated(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(leading, 4, trailing, 12),
        itemCount: widget.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, i) => _buildChannelTile(context, i, list: true),
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          final layout = CatalogPosterGridLayout.channelCards(
            maxWidth: constraints.maxWidth,
            minW: cardW,
            minH: cardH,
            gap: gap,
            leading: leading,
            trailing: trailing,
          );
          _layout = layout;

          return CatalogPosterGrid(
            layout: layout,
            controller: _scroll,
            useAspectRatio: false,
            itemCount: widget.items.length,
            itemBuilder: (context, i) =>
                _buildChannelTile(context, i, list: false),
          );
        },
      );
    }

    body = ListLetterJumpScope(
      enabled: !_leanbackOnly && widget.items.isNotEmpty,
      itemCount: widget.items.length,
      anchorIndex: _letterJumpAnchor(),
      labelAt: _titleAt,
      onJump: _letterJump,
      child: body,
    );
    return LiveTvScrollbar(controller: _scroll, child: body);
  }
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
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
  });

  final Map<String, dynamic> props;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool selected;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;

  static double cardWidth(BuildContext context) {
    final base = catalogContinueCardWidth(context, wide: true);
    return base * EventCardTokens.desktopWidthScale;
  }

  static double cardHeight(BuildContext context) {
    final base = catalogContinueCardHeight(context, wide: true);
    final tv = ShellPaintScope.usesTvDensityOf(context);
    return (base * EventCardTokens.desktopHeightScale).clamp(
      ShellTokens.chromeScale(EventCardTokens.desktopHeightMin, tv: tv),
      ShellTokens.chromeScale(EventCardTokens.desktopHeightMax, tv: tv),
    );
  }

  @override
  State<InteractiveEventCard> createState() => _InteractiveEventCardState();
}

class _InteractiveEventCardState extends State<InteractiveEventCard> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool h) {
    if (_hoveredN.value == h) return;
    _hoveredN.value = h;
  }

  Widget _buildPaint(bool hovered) {
    final props = widget.props;
    final live = props['live'] == true;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final active =
        ShellPaintScope.interactiveActive(
          context,
          hovered: hovered,
          focused: _focused,
        ) ||
        widget.selected;
    final radius = EventCardTokens.radiusOf(context);
    final playDia = EventCardTokens.playOverlaySizeOf(context);
    final playIcon = EventCardTokens.playIconSizeOf(context);

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
      width: widget.width,
      height: widget.height,
      tvDensity: tv,
      borderRadius: radius,
      titleFontSize: EventCardTokens.titleFontSizeOf(context),
      metaFontSize: EventCardTokens.metaFontSizeOf(context),
      badgeFontSize: EventCardTokens.badgeFontSizeOf(context),
      playOverlaySize: playDia,
      padV: EventCardTokens.padVOf(context),
      playOverlay: live
          ? ShellCardPlayOverlay(
              active: active,
              visible: true,
              diameter: playDia,
              iconSize: playIcon,
            )
          : null,
    );

    return paint;
  }

  @override
  Widget build(BuildContext context) {
    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: EventCardTokens.radiusOf(context),
      motion: ForjaMotionPreset.fillOnly,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      tvZone: ShellPaintTvZone.grid,
      tvItemIndex: widget.gridIndex,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onUpEdge: widget.onUpEdge,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: _setHovered,
      child: ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) => _buildPaint(_hoveredN.value),
      ),
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
    this.listIndex,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onTap,
  });

  final String title;
  final String meta;
  final bool airing;
  final int viewers;
  final bool selected;
  final int? listIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onTap;

  @override
  State<_HoverDenseTile> createState() => _HoverDenseTileState();
}

class _HoverDenseTileState extends State<_HoverDenseTile> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  Widget _buildTile(bool hovered) => EventDenseTile(
    title: widget.title,
    meta: widget.meta,
    airing: widget.airing,
    viewers: widget.viewers,
    selected: widget.selected,
    hovered: hovered,
    focused: _focused,
    onTap: null,
  );

  @override
  Widget build(BuildContext context) {
    final painted = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _buildTile(_hoveredN.value),
    );
    if (!ShellPaintScope.useTvFocusOf(context)) {
      return MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: painted,
        ),
      );
    }
    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      motion: ForjaMotionPreset.fillOnly,
      showFocusFill: false,
      showFocusBorder: false,
      listIndex: widget.listIndex,
      tvItemIndex: widget.listIndex,
      tvZone: ShellPaintTvZone.row,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onUpEdge: widget.onUpEdge,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: _setHovered,
      child: painted,
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
    this.width,
  });

  final List<({String id, String label})> items;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final railW = width ?? catalogSideRailWidth(context);
    if (items.isEmpty) {
      return SizedBox(
        width: railW,
        child: const Empty(title: 'No categories', size: EmptySize.sm),
      );
    }
    return ColoredBox(
      color: ForjaShellColors.bgDark,
      child: SizedBox(
        width: railW,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(
            vertical: ShellTokens.categoryRailListPadV,
          ),
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
