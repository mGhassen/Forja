import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/components/empty.dart';
import 'package:forja_foundation/components/vertical_menu.dart';
import 'package:forja_foundation/tokens/event_card_tokens.dart';
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
  final title = (raw['title'] ?? raw['name'] ?? item['name'] ?? item['title'] ?? '')
      .toString()
      .trim();
  final imageUrl = (raw['imageUrl'] ??
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
  final streamId = (raw['streamId'] ??
          item['streamId'] ??
          (item['open'] is Map ? item['open']['streamId'] : null) ??
          '')
      .toString()
      .trim();
  if (streamId.isNotEmpty) raw['streamId'] = streamId;
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
    this.itemAccessory,
    this.itemHealth,
    this.itemHealthListenable,
    this.onItemInteractiveActive,
    this.loadEpgProgrammes,
    this.tvTabId,
    this.tvRowId,
    this.landEpoch,
    this.onHoldJumpToCategory,
    this.preferCategoryFocusOnLand = true,
    this.onRequestFocusAt,
    this.onArmFocusMemory,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item)? onItemTap;
  final String emptyTitle;
  final String? emptyDescription;

  /// Optional CTA under the empty copy (e.g. Open portal).
  final Widget? emptyAction;

  /// `poster` · `event`/`cards` · `dense`/`list` · `channel` · `guide`/`epg`
  final String cardKind;
  final String? selectedItemId;

  /// Grid spacing. Null → ShellTokens / TV defaults.
  final double? gap;

  /// Horizontal inset for event/poster grids. Null → catalog density pad.
  final double? pad;

  /// Optional corner control (e.g. live favorite star). [active] = hover/focus.
  final Widget? Function(
    BuildContext context,
    Map<String, dynamic> item, {
    required bool active,
  })? itemAccessory;

  /// Live channel stream health (`null` unknown).
  final bool? Function(Map<String, dynamic> item)? itemHealth;

  /// Per-channel health listenable (preferred over [itemHealth] for grids).
  final ValueListenable<bool?>? Function(Map<String, dynamic> item)?
      itemHealthListenable;

  /// Hover/focus dwell for host URL probe (live channels).
  final void Function(
    Map<String, dynamic> item, {
    required bool active,
  })? onItemInteractiveActive;

  /// Lazy EPG table fetch for [cardKind] `guide` / `epg`.
  final Future<List<GuideEpgProgramme>> Function(Map<String, dynamic> item)?
      loadEpgProgrammes;

  /// TV focus graph tab / row for Live channel grid (pack `items`).
  final String? tvTabId;
  final String? tvRowId;

  /// Bumped by host to scroll/focus [selectedItemId] (after player / hydrate).
  final ValueListenable<int>? landEpoch;

  /// Favorites / Already watched: hold OK ~1s → jump to portal category.
  final void Function(Map<String, dynamic> item)? onHoldJumpToCategory;

  /// When landing a restored channel, keep D-pad on category rail (arm memory).
  final bool preferCategoryFocusOnLand;

  /// Pack `focusLeft` / `focusRight` (e.g. IPTV → cats, Live Sports → Providers).
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  /// Host focuses TV item after scroll (lazy grid).
  final ValueChanged<int>? onRequestFocusAt;

  /// Host arms D-pad memory without stealing category focus.
  final ValueChanged<int>? onArmFocusMemory;

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

  bool get _channel =>
      cardKind == 'channel' || cardKind == 'liveChannel';

  bool get _guide => cardKind == 'guide' || cardKind == 'epg';

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      Widget empty = Empty(
        title: emptyTitle,
        description: emptyDescription,
        icon: Icons.inbox_outlined,
        action: emptyAction,
      );
      final tab = (tvTabId ?? '').trim();
      final row = (tvRowId ?? '').trim();
      // No-portal / empty catalog CTA must register so nav enter can land.
      if (emptyAction != null &&
          tab.isNotEmpty &&
          row.isNotEmpty &&
          ShellPaintScope.useTvFocusOf(context)) {
        empty = ShellPaintScope.tvRow(
          context: context,
          tabId: tab,
          rowId: row,
          sortOrder: 2,
          itemCount: 1,
          child: empty,
        );
      }
      return empty;
    }

    if (_guide) return _epgGuide(context);
    if (_dense) return _denseList(context);
    if (_event) return _eventGrid(context);
    if (_channel) return _channelGrid(context);
    return _posterGrid(context);
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
      itemAccessory: itemAccessory,
      itemHealth: itemHealth,
      itemHealthListenable: itemHealthListenable,
      onItemInteractiveActive: onItemInteractiveActive,
      loadEpgProgrammes: loadEpgProgrammes,
      onItemTap: onItemTap,
      tvTabId: tvTabId,
      tvRowId: tvRowId,
      landEpoch: landEpoch,
      onHoldJumpToCategory: onHoldJumpToCategory,
      preferCategoryFocusOnLand: preferCategoryFocusOnLand,
      onRequestFocusAt: onRequestFocusAt,
      onArmFocusMemory: onArmFocusMemory,
    );
  }

  Widget _denseList(BuildContext context) {
    final inset = pad ?? ShellTokens.compactChromeLeadingInset(context);
    final trail = pad ?? ShellTokens.bodyHorizontalPadding;
    final tab = (tvTabId ?? '').trim();
    final row = (tvRowId ?? '').trim();
    Widget body = CatalogDenseList(
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
          listIndex: i,
          tvTabId: tab.isEmpty ? null : tab,
          tvRowId: row.isEmpty ? null : row,
          onLeftEdge: onLeftEdge,
          onRightEdge: onRightEdge,
          onTap: onItemTap == null ? null : () => onItemTap!(item),
        );
      },
    );
    if (tab.isNotEmpty &&
        row.isNotEmpty &&
        items.isNotEmpty &&
        ShellPaintScope.useTvFocusOf(context)) {
      body = ShellPaintScope.tvRow(
        context: context,
        tabId: tab,
        rowId: row,
        sortOrder: 2,
        itemCount: items.length,
        axis: ShellPaintTvRowAxis.vertical,
        child: body,
      );
    }
    return body;
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

/// Channel cards + type-to-jump. Competes with category rail via last hover
/// ([ListLetterJumpScope] active ownership).
class _ChannelLetterJumpGrid extends StatefulWidget {
  const _ChannelLetterJumpGrid({
    required this.items,
    this.selectedItemId,
    this.gap,
    this.pad,
    this.itemAccessory,
    this.itemHealth,
    this.itemHealthListenable,
    this.onItemInteractiveActive,
    this.loadEpgProgrammes,
    this.onItemTap,
    this.tvTabId,
    this.tvRowId,
    this.landEpoch,
    this.onHoldJumpToCategory,
    this.preferCategoryFocusOnLand = true,
    this.onRequestFocusAt,
    this.onArmFocusMemory,
  });

  final List<Map<String, dynamic>> items;
  final String? selectedItemId;
  final double? gap;
  final double? pad;
  final Widget? Function(
    BuildContext context,
    Map<String, dynamic> item, {
    required bool active,
  })? itemAccessory;
  final bool? Function(Map<String, dynamic> item)? itemHealth;
  final ValueListenable<bool?>? Function(Map<String, dynamic> item)?
      itemHealthListenable;
  final void Function(
    Map<String, dynamic> item, {
    required bool active,
  })? onItemInteractiveActive;
  final Future<List<GuideEpgProgramme>> Function(Map<String, dynamic> item)?
      loadEpgProgrammes;
  final void Function(Map<String, dynamic> item)? onItemTap;
  final String? tvTabId;
  final String? tvRowId;
  final ValueListenable<int>? landEpoch;
  final void Function(Map<String, dynamic> item)? onHoldJumpToCategory;
  final bool preferCategoryFocusOnLand;
  final ValueChanged<int>? onRequestFocusAt;
  final ValueChanged<int>? onArmFocusMemory;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_leanbackOnly) {
        _bumpChannelLogoSettle();
      } else {
        setState(() => _allowNewLogos = true);
      }
      _landSelected(preferCategoryFocus: widget.preferCategoryFocusOnLand);
    });
  }

  @override
  void dispose() {
    widget.landEpoch?.removeListener(_onLandEpoch);
    _logoSettleTimer?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
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
        _landSelected(preferCategoryFocus: widget.preferCategoryFocusOnLand);
      });
    }
  }

  void _onLandEpoch() {
    _landSelected(preferCategoryFocus: widget.preferCategoryFocusOnLand);
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

  void _landSelected({required bool preferCategoryFocus}) {
    final idx = _indexOfSelected();
    if (idx < 0) return;
    setState(() => _selectedIndex = idx);
    if (preferCategoryFocus) {
      _scrollToIndex(idx);
      widget.onArmFocusMemory?.call(idx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToIndex(idx);
        widget.onArmFocusMemory?.call(idx);
      });
      return;
    }
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
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.15,
          duration: Duration.zero,
        );
      }
      if (!focus || !_leanbackOnly) return;
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
    final panelSelected = widget.selectedItemId != null &&
        widget.selectedItemId!.isNotEmpty &&
        widget.selectedItemId == id;
    final layout = _layout;
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
        highlighted: panelSelected || i == _selectedIndex,
        showLogo: _showChannelLogo(id),
        listLayout: list,
        width: list ? null : layout?.cardW,
        height: list ? 56 : layout?.cardH,
        gridIndex: i,
        gridColumns: list ? 1 : layout?.columns,
        tvTabId: widget.tvTabId,
        tvRowId: widget.tvRowId,
        onHoldJumpToCategory: widget.onHoldJumpToCategory == null
            ? null
            : () => widget.onHoldJumpToCategory!(item),
        onTap: widget.onItemTap == null
            ? null
            : () {
                setState(() => _selectedIndex = i);
                widget.onItemTap!(item);
              },
        onInteractiveActive: widget.onItemInteractiveActive == null
            ? null
            : (active) => widget.onItemInteractiveActive!(
                  item,
                  active: active,
                ),
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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final list = _compactList;
    final cardW = CatalogChannelCard.cardWidth(context);
    final cardH = CatalogChannelCard.cardHeight(context);
    final gap = widget.gap ?? (tv ? ShellTokens.tvPosterCardRowGap : 10.0);
    final leading = widget.pad ?? 8.0;
    final trailing = widget.pad ?? 12.0;
    final tab = (widget.tvTabId ?? '').trim();
    final rowId = (widget.tvRowId ?? '').trim();

    Widget body;
    if (list) {
      body = CatalogDenseList(
        controller: _scroll,
        itemCount: widget.items.length,
        leading: leading,
        trailing: trailing,
        itemBuilder: (context, i) => _buildChannelTile(context, i, list: true),
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          final layout = tv
              ? CatalogPosterGridLayout.poster(
                  maxWidth: constraints.maxWidth,
                  cardW: cardW,
                  cardH: cardH,
                  gap: gap,
                  leading: leading,
                  trailing: trailing,
                )
              : CatalogPosterGridLayout.channelCards(
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

    if (tab.isNotEmpty &&
        rowId.isNotEmpty &&
        ShellPaintScope.useTvFocusOf(context)) {
      body = ShellPaintScope.tvRow(
        context: context,
        tabId: tab,
        rowId: rowId,
        sortOrder: 2,
        itemCount: widget.items.length,
        axis: list
            ? ShellPaintTvRowAxis.vertical
            : ShellPaintTvRowAxis.horizontal,
        child: body,
      );
    }
    return body;
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
        : EventCardTokens.radius;

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
              diameter: tv
                  ? EventCardTokens.playIconSize
                  : EventCardTokens.playOverlaySize,
              iconSize: tv
                  ? EventCardTokens.playIconSizeTv
                  : EventCardTokens.playIconSize,
            )
          : null,
    );

    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: radius,
      motion: ForjaMotionPreset.fillOnly,
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
    this.listIndex,
    this.tvTabId,
    this.tvRowId,
    this.onLeftEdge,
    this.onRightEdge,
    this.onTap,
  });

  final String title;
  final String meta;
  final bool airing;
  final int viewers;
  final bool selected;
  final int? listIndex;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
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
      motion: ForjaMotionPreset.fillOnly,
      showFocusFill: false,
      showFocusBorder: false,
      listIndex: widget.listIndex,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.listIndex,
      tvZone: ShellPaintTvZone.row,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
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
    this.width = ShellTokens.categoryRailWidth,
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
          padding: const EdgeInsets.symmetric(vertical: ShellTokens.categoryRailListPadV),
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
