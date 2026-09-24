import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/kit_list_status_button.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shared/engine/store/list_follow.dart';
import 'package:forja/shell/core/forja_shell_layout.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/blocks/catalog/catalog_cards_grid.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/event_card_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/event_card.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/chrome/horizontal_scroller.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_section_title.dart';

/// Shared pack-item → foundation card paint. Rails + kit.list tiles.
abstract final class PackPaintArtifact {
  PackPaintArtifact._();

  /// First-seen rail order per tab (stable across rebuilds) so ↓ follows
  /// paint order instead of every rail sharing the same sortOrder.
  static final Map<String, int> _sortByRailKey = {};
  static int _sortSeq = 100;

  /// Monotonic sortOrder for a tab+rowId — continue / mood / because / rails.
  static int stableSortOrder(String tabId, String rowId) {
    final key = '$tabId\u0000$rowId';
    return _sortByRailKey.putIfAbsent(key, () {
      _sortSeq += 1;
      return _sortSeq;
    });
  }

  /// Drop cached orders for [tabId] so [reserveHubFocusRowOrder] can rebuild.
  static void clearStableSortOrdersForTab(String tabId) {
    if (tabId.isEmpty) return;
    final prefix = '$tabId\u0000';
    _sortByRailKey.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// Assign sortOrder in **layout widget order** before async rails paint.
  ///
  /// Without this, Mood/Continue reserve sync while Featured (bleed load) is
  /// still pending — Featured gets a later number, so ↑ from Featured lands on
  /// Mood and ↓ from Popular jumps to a late genre rail.
  static void reserveHubFocusRowOrder(String tabId, List<String> rowIds) {
    if (tabId.isEmpty || rowIds.isEmpty) return;
    clearStableSortOrdersForTab(tabId);
    for (final raw in rowIds) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      stableSortOrder(tabId, id);
    }
  }

  @visibleForTesting
  static void clearStableSortOrdersForTest() {
    _sortByRailKey.clear();
    _sortSeq = 100;
  }

  static Map<String, dynamic> propsOf(Map<String, dynamic> item) {
    final paint = item['paint'];
    if (paint is Map) {
      final props = paint['props'];
      if (props is Map) return Map<String, dynamic>.from(props);
    }
    final props = item['props'];
    if (props is Map) return Map<String, dynamic>.from(props);
    // Flat feed rows (My List before hubPaintPoster) — same aliases as grid.
    return catalogItemProps(item);
  }

  static VoidCallback? openTap(
    BuildContext context, {
    required String pluginId,
    required Map<String, dynamic> props,
    Object? open,
    Object? meta,
  }) {
    final item = metaItemOf(props: props, open: open, meta: meta);
    if (item == null) return null;
    if (item.id.isEmpty && item.open == null) return null;
    return () => openMetaItem(context, pluginId: pluginId, item: item);
  }

  /// Resolve pack item meta for open / list-follow.
  static MetaItem? metaItemOf({
    required Map<String, dynamic> props,
    Object? open,
    Object? meta,
  }) {
    final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : null;
    if (metaMap != null) {
      if (metaMap['open'] == null && open is Map) {
        metaMap['open'] = open;
      }
      if ((metaMap['name'] ?? '').toString().trim().isEmpty) {
        final title = (props['title'] ?? '').toString().trim();
        if (title.isNotEmpty) metaMap['name'] = title;
      }
      if ((metaMap['poster'] ?? '').toString().trim().isEmpty) {
        final poster =
            (props['imageUrl'] ?? props['posterUrl'] ?? '').toString().trim();
        if (poster.isNotEmpty) metaMap['poster'] = poster;
      }
      if (metaMap['rating'] == null && props['rating'] is num) {
        metaMap['rating'] = props['rating'];
      }
      if ((metaMap['releaseInfo'] ?? '').toString().trim().isEmpty) {
        final sub = (props['subtitle'] ?? props['year'] ?? '').toString().trim();
        if (sub.isNotEmpty) metaMap['releaseInfo'] = sub;
      }
      return MetaItem.fromJson(metaMap);
    }
    final openMap = open is Map ? Map<String, dynamic>.from(open) : null;
    if (openMap == null) return null;
    // Never use open.surface as MetaItem.type (e.g. stremio) — that is the
    // host route, not movie/tv. Prefer mediaType from open extras / paint.
    final mediaTypeRaw = (openMap['mediaType'] ?? props['mediaType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final metaType = mediaTypeRaw == 'series'
        ? 'tv'
        : (mediaTypeRaw == 'tv' ||
                mediaTypeRaw == 'movie' ||
                mediaTypeRaw == 'collections'
            ? mediaTypeRaw
            : 'movie');
    final release = (props['year'] ?? props['subtitle'] ?? '').toString().trim();
    return MetaItem(
      id: (openMap['id'] ?? '').toString(),
      type: metaType,
      name: (props['title'] ?? '').toString(),
      poster: (props['imageUrl'] ?? props['posterUrl'] ?? '').toString(),
      background:
          (props['backdropUrl'] ?? props['backgroundUrl'] ?? '').toString(),
      description: (props['overview'] ?? props['description'] ?? '').toString(),
      rating: props['rating'] is num ? (props['rating'] as num).toDouble() : null,
      releaseInfo: release.length >= 4 ? release.substring(0, 4) : release,
      tmdbMediaType: metaType == 'tv' || metaType == 'movie' ? metaType : null,
      open: MetaOpen.fromJson(openMap),
    );
  }

  /// My List pin for poster cards — leanback TV hides via [KitListStatusButton].
  static Widget? listPinFor({
    required BuildContext context,
    required String pluginId,
    required Map<String, dynamic> props,
    Object? open,
    Object? meta,
    double? cardWidth,
  }) {
    final w = cardWidth ??
        InteractivePosterCard.cardWidth(
          context,
          aspect: (props['aspect'] ?? '').toString() == 'landscape'
              ? PosterAspect.landscape
              : PosterAspect.portrait,
        );
    if (w < 85) return null;
    final item = metaItemOf(props: props, open: open, meta: meta);
    if (item == null) return null;
    final target = ListFollowTarget.fromMeta(pluginId: pluginId, meta: item);
    if (target == null) return null;
    return KitListStatusButton.follow(
      followTarget: target,
      excludeFromTvTraversal: true,
      iconSize: InteractivePosterCard.scaled(context, 18).clamp(12.0, 18.0),
    );
  }

  /// Mount a single `paint: { type, props }` artifact.
  static Widget fromPaint(
    BuildContext context, {
    required String pluginId,
    required Map<String, dynamic> paint,
    Object? open,
    Object? meta,
    int? listIndex,
    int? fallbackRank,
    String? fallbackAspect,
  }) {
    final type = (paint['type'] ?? '').toString().trim();
    final propsRaw = paint['props'];
    final props = propsRaw is Map
        ? Map<String, dynamic>.from(propsRaw)
        : <String, dynamic>{};
    final resolvedOpen = open ?? props['open'];
    final resolvedMeta = meta ?? props['meta'];
    final onTap = openTap(
      context,
      pluginId: pluginId,
      props: props,
      open: resolvedOpen,
      meta: resolvedMeta,
    );

    switch (type) {
      case 'posterCard':
      case 'poster':
        final rank = props['rank'] is num
            ? (props['rank'] as num).toInt()
            : fallbackRank;
        final aspectRaw =
            (props['aspect'] ?? fallbackAspect ?? '').toString();
        final aspect = aspectRaw == 'landscape'
            ? PosterAspect.landscape
            : PosterAspect.portrait;
        final width = packLength(context, props['width']);
        final motion = ForjaMotionTheme.presetFromName(
          props['motion']?.toString(),
        );
        final hover = packDouble(props['hoverScale']);
        final focus = packDouble(props['focusScale']);
        // durationMs reserved for motion theme; focusableTap uses preset duration.
        return InteractivePosterCard(
          imageUrl: (props['imageUrl'] ?? props['posterUrl'] ?? '').toString(),
          title: (props['title'] ?? '').toString(),
          subtitle: props['subtitle']?.toString(),
          rating: props['rating'] is num
              ? (props['rating'] as num).toDouble()
              : null,
          rank: rank,
          badge: props['badge']?.toString(),
          listPin: listPinFor(
            context: context,
            pluginId: pluginId,
            props: props,
            open: resolvedOpen,
            meta: resolvedMeta,
            cardWidth: width,
          ),
          listIndex: listIndex,
          onTap: onTap ?? () {},
          aspect: aspect,
          width: width,
          height: packLength(context, props['height']),
          borderRadius:
              packLength(context, props['borderRadius'] ?? props['radius']),
          titleFontSize: packLength(context, props['titleFontSize']),
          metaFontSize: packLength(context, props['metaFontSize']),
          motion: motion,
          scaleOnFocus: focus ?? hover,
        );
      case 'eventCard':
      case 'event':
        final tv = packBool(props['tvDensity']) == true ||
            ShellPaintScope.usesTvDensityOf(context);
        final scale = tv ? ShellTokens.tvChromeScale : 1.0;
        final w = packLength(context, props['width']) ??
            EventCardTokens.paintFallbackWidth * scale;
        final h = packLength(context, props['height']) ??
            EventCardTokens.paintFallbackHeight * scale;
        return EventCard(
          title: (props['title'] ?? '').toString(),
          posterUrl: (props['posterUrl'] ?? props['imageUrl'] ?? '').toString(),
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
          width: w,
          height: h,
          tvDensity: tv,
          borderRadius:
              packLength(context, props['borderRadius'] ?? props['radius']) ??
                  EventCardTokens.radiusOf(context),
          titleFontSize: packLength(context, props['titleFontSize']) ??
              EventCardTokens.titleFontSizeOf(context),
          metaFontSize: packLength(context, props['metaFontSize']) ??
              EventCardTokens.metaFontSizeOf(context),
          badgeFontSize: packLength(context, props['badgeFontSize']) ??
              EventCardTokens.badgeFontSizeOf(context),
          playOverlaySize: packLength(context, props['playOverlaySize']) ??
              EventCardTokens.playOverlaySizeOf(context),
          padV: packLength(context, props['padV']) ??
              EventCardTokens.padVOf(context),
          onTap: onTap,
        );
      default:
        if (props.isEmpty) return const SizedBox.shrink();
        final label = (props['title'] ?? type).toString();
        if (label.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            label,
            style: TextStyle(color: ForjaShellColors.textSecondary),
          ),
        );
    }
  }

  /// Horizontal rail/ranked row from paint-ready `items[]`.
  ///
  /// Pack visual overrides (omit → ShellTokens / catalog density):
  /// `gap`, `rankedGap`, `pad`, `titlePad` (`{ top, bottom }` or number for both).
  /// [compactTop] — hero-bleed / Because-style title inset (pre-cutover).
  ///
  /// With `pageLoad` (from PackLoadedPaint), pages 2+ append via
  /// [HorizontalScroller.onApproachingEnd] (same `_fetchRailPage` contract).
  static Widget posterRow(
    BuildContext context, {
    required Map<String, dynamic> node,
    required String pluginId,
    String? packSourceUrl,
    bool compactTop = false,
  }) {
    return _PackPosterRail(
      node: node,
      pluginId: pluginId,
      packSourceUrl: packSourceUrl,
      compactTop: compactTop,
    );
  }

  static String paintItemKey(Map<String, dynamic> item) {
    final meta = item['meta'];
    if (meta is Map) {
      final id = (meta['id'] ?? '').toString().trim();
      if (id.isNotEmpty) return id;
    }
    final open = item['open'];
    if (open is Map) {
      final id = (open['id'] ?? '').toString().trim();
      if (id.isNotEmpty) return id;
    }
    final props = propsOf(item);
    return '${props['title']}|${props['imageUrl'] ?? props['posterUrl']}';
  }

  static double? packDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  /// Desktop px length from pack JSON → TV × [ShellTokens.tvChromeScale].
  ///
  /// Packs author desktop baselines. Interactive pack chrome (pads, fonts,
  /// buttons, panel widths) uses the milder leanback chrome scale — not the
  /// poster spatial ratio (~0.37), which would crush focus targets. Catalog
  /// poster widths still come from [ShellTokens.posterCardWidthTv]. Fractions /
  /// multipliers stay on [packDouble] (aspect, hoverScale, heightFraction, …).
  static double? packLength(BuildContext context, Object? raw) {
    final v = packDouble(raw);
    if (v == null) return null;
    return ShellTokens.chromeScale(
      v,
      tv: ShellPaintScope.usesTvDensityOf(context),
    );
  }

  static bool? packBool(Object? raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    final s = raw.toString().trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
  }

  static int? packInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString().trim());
  }

  /// Pack `pad` / `padding`: number → horizontal (keeps [fallback] vertical);
  /// `{ l|left, t|top, r|right, b|bottom }` map; null → [fallback].
  ///
  /// Pack-provided edges are desktop px (scaled on TV). [fallback] is already
  /// density-resolved by the caller — do not re-scale it.
  static EdgeInsets packPad(
    Object? raw, {
    required EdgeInsets fallback,
    BuildContext? context,
  }) {
    if (raw == null) return fallback;
    final tv = context != null && ShellPaintScope.usesTvDensityOf(context);
    double scale(double v) => ShellTokens.chromeScale(v, tv: tv);
    if (raw is num) {
      final h = scale(raw.toDouble());
      return EdgeInsets.fromLTRB(h, fallback.top, h, fallback.bottom);
    }
    if (raw is Map) {
      return EdgeInsets.fromLTRB(
        packDouble(raw['l'] ?? raw['left']) != null
            ? scale(packDouble(raw['l'] ?? raw['left'])!)
            : fallback.left,
        packDouble(raw['t'] ?? raw['top']) != null
            ? scale(packDouble(raw['t'] ?? raw['top'])!)
            : fallback.top,
        packDouble(raw['r'] ?? raw['right']) != null
            ? scale(packDouble(raw['r'] ?? raw['right'])!)
            : fallback.right,
        packDouble(raw['b'] ?? raw['bottom']) != null
            ? scale(packDouble(raw['b'] ?? raw['bottom'])!)
            : fallback.bottom,
      );
    }
    return fallback;
  }

  /// Pack `titlePad`: number → both edges; `{ top, bottom }` map; null → density defaults.
  /// Pack-provided values are desktop px (scaled on TV).
  static ({double top, double bottom}) titlePadInsets(
    Object? raw,
    BuildContext context, {
    double? defaultTop,
    double? defaultBottom,
  }) {
    final top0 = defaultTop ?? catalogSectionTitleTop(context);
    final bottom0 = defaultBottom ?? catalogSectionBottomGap(context);
    if (raw == null) return (top: top0, bottom: bottom0);
    if (raw is num) {
      final v = packLength(context, raw)!;
      return (top: v, bottom: v);
    }
    if (raw is Map) {
      return (
        top: packLength(context, raw['top']) ?? top0,
        bottom: packLength(context, raw['bottom']) ?? bottom0,
      );
    }
    return (top: top0, bottom: bottom0);
  }
}

/// Thin-painter poster rail — page 1 from paint; more pages on scroll approach.
class _PackPosterRail extends StatefulWidget {
  const _PackPosterRail({
    required this.node,
    required this.pluginId,
    this.packSourceUrl,
    this.compactTop = false,
  });

  final Map<String, dynamic> node;
  final String pluginId;
  final String? packSourceUrl;
  final bool compactTop;

  @override
  State<_PackPosterRail> createState() => _PackPosterRailState();
}

class _PackPosterRailState extends State<_PackPosterRail> {
  late List<Map<String, dynamic>> _items;
  late int _page;
  late bool _hasMore;
  late int _pageSize;
  late int _maxPages;
  int _loadGen = 0;
  bool _loadingMore = false;
  String _reloadToken = '';

  Map<String, dynamic> get node => widget.node;

  @override
  void initState() {
    super.initState();
    _resetFromNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabId = LayoutScope.maybeOf(context)?.tabId ??
        TvFocusGraph.tabIdOf(context);
    final token = catalogChromeFilterEpoch(tabId);
    if (_reloadToken.isEmpty) {
      _reloadToken = token;
      return;
    }
    if (token != _reloadToken) {
      _reloadToken = token;
      setState(_resetFromNode);
    }
  }

  @override
  void didUpdateWidget(covariant _PackPosterRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pluginId != widget.pluginId ||
        oldWidget.packSourceUrl != widget.packSourceUrl ||
        !_samePage1(oldWidget.node, widget.node) ||
        oldWidget.node['hasMore'] != widget.node['hasMore'] ||
        oldWidget.node['pageSize'] != widget.node['pageSize'] ||
        oldWidget.node['maxPages'] != widget.node['maxPages']) {
      _resetFromNode();
    }
  }

  void _resetFromNode() {
    _loadGen++;
    _loadingMore = false;
    _items = _page1Items(node);
    _page = 1;
    _pageSize = catalogRailPageSizeFrom(node) ?? kMetaRailPageSizeFallback;
    _maxPages =
        catalogRailMaxPagesFrom(node) ?? kMetaRailMaxPagesFallback;
    final pageLoad = packLoadSpec(node['pageLoad']);
    _hasMore = pageLoad != null &&
        _page < _maxPages &&
        (catalogRailHasMoreFrom(node) ??
            (_items.isNotEmpty && _items.length >= _pageSize));
  }

  static bool _samePage1(Map<String, dynamic> a, Map<String, dynamic> b) {
    final ai = a['items'];
    final bi = b['items'];
    if (identical(ai, bi)) return true;
    if (ai is! List || bi is! List || ai.length != bi.length) return false;
    for (var i = 0; i < ai.length; i++) {
      final ak = ai[i] is Map
          ? PackPaintArtifact.paintItemKey(Map<String, dynamic>.from(ai[i] as Map))
          : '$i';
      final bk = bi[i] is Map
          ? PackPaintArtifact.paintItemKey(Map<String, dynamic>.from(bi[i] as Map))
          : '$i';
      if (ak != bk) return false;
    }
    return true;
  }

  static List<Map<String, dynamic>> _page1Items(Map<String, dynamic> node) {
    final raw = node['items'];
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final it in raw) {
      if (it is Map) out.add(Map<String, dynamic>.from(it));
    }
    return out;
  }

  List<Map<String, dynamic>> _merge(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> batch,
  ) {
    final seen = {for (final i in current) PackPaintArtifact.paintItemKey(i)};
    final out = [...current];
    for (final i in batch) {
      if (seen.add(PackPaintArtifact.paintItemKey(i))) out.add(i);
    }
    return out;
  }

  void _onApproachingEnd() {
    final pageLoad = packLoadSpec(node['pageLoad']);
    if (pageLoad == null || !_hasMore || _loadingMore) return;
    if (_page >= _maxPages) return;
    unawaited(_loadPage(_page + 1, pageLoad: pageLoad));
  }

  Future<void> _loadPage(
    int page, {
    required ({String action, Map<String, dynamic> params}) pageLoad,
  }) async {
    if (_loadingMore || !_hasMore || page > _maxPages) return;
    setState(() => _loadingMore = true);
    final gen = _loadGen;
    final tabId = LayoutScope.maybeOf(context)?.tabId ??
        TvFocusGraph.tabIdOf(context);
    try {
      final params = <String, dynamic>{
        ...pageLoad.params,
        'page': page,
        'maxPages': _maxPages,
      };
      for (final key in ['limit', 'pageSize', 'perPage']) {
        final v = node[key];
        if (v != null) params.putIfAbsent(key, () => v);
      }
      final envelope = await packOpaqueRun(
        pluginId: widget.pluginId,
        packSourceUrl: widget.packSourceUrl,
        action: pageLoad.action,
        params: catalogParamsWithFilters(
          params,
          filters: catalogChromeFilters(
            tabId: tabId,
            pluginId: widget.pluginId,
          ),
        ),
      );
      if (!mounted || gen != _loadGen) return;
      if (!envelope.ok) {
        setState(() {
          _loadingMore = false;
          _hasMore = false;
        });
        return;
      }
      final data = envelope.data ?? const <String, dynamic>{};
      final raw = data['items'];
      final batch = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final it in raw) {
          if (it is Map) batch.add(Map<String, dynamic>.from(it));
        }
      }
      final resolvedSize = catalogRailPageSizeFrom(data) ?? _pageSize;
      setState(() {
        _items = _merge(_items, batch);
        _page = page;
        _pageSize = resolvedSize;
        _loadingMore = false;
        _hasMore = page < _maxPages &&
            (catalogRailHasMoreFrom(data) ?? (batch.length >= resolvedSize));
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  Widget _cardAt(
    BuildContext context,
    Map<String, dynamic> item,
    int i, {
    required bool ranked,
    required String aspectFallback,
    required String? tabId,
    required String rowId,
    double? itemWidth,
    double? itemHeight,
  }) {
    final paint = item['paint'];
    if (paint is Map) {
      final paintMap = Map<String, dynamic>.from(paint);
      if (itemWidth != null || itemHeight != null) {
        final p = Map<String, dynamic>.from(
          paintMap['props'] is Map
              ? Map<String, dynamic>.from(paintMap['props'] as Map)
              : PackPaintArtifact.propsOf(item),
        );
        if (itemWidth != null) p.putIfAbsent('width', () => itemWidth);
        if (itemHeight != null) p.putIfAbsent('height', () => itemHeight);
        paintMap['props'] = p;
      }
      return PackPaintArtifact.fromPaint(
        context,
        pluginId: widget.pluginId,
        paint: paintMap,
        open: item['open'] ?? paint['open'],
        meta: item['meta'] ?? paint['meta'],
        listIndex: i,
        fallbackRank: ranked ? i + 1 : null,
        fallbackAspect: aspectFallback,
      );
    }
    final props = PackPaintArtifact.propsOf(item);
    if (itemWidth != null) props['width'] = itemWidth;
    if (itemHeight != null) props['height'] = itemHeight;
    return PackPaintArtifact.fromPaint(
      context,
      pluginId: widget.pluginId,
      paint: {
        'type': 'posterCard',
        'props': props,
      },
      open: item['open'],
      meta: item['meta'],
      listIndex: i,
      fallbackRank: ranked ? i + 1 : null,
      fallbackAspect: aspectFallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (node['title'] ?? node['label'] ?? '').toString();
    final ranked = (node['type'] ?? '').toString() == 'ranked' ||
        (node['style'] ?? '').toString() == 'numbered';
    final aspectFallback = (node['aspect'] ?? '').toString();
    final rowId = (node['id'] ?? node['rail'] ?? 'rail').toString();
    final tabId = LayoutScope.maybeOf(context)?.tabId ??
        TvFocusGraph.tabIdOf(context);
    final focusUp = LayoutScope.maybeOf(context)
        ?.resolveFocusEdge((node['focusUp'] ?? '').toString());
    final focusDown = LayoutScope.maybeOf(context)
        ?.resolveFocusEdge((node['focusDown'] ?? '').toString(), down: true);
    // Unique vertical order — shared sortOrder 100 made ↓ trap on the first
    // poster rail (_nextRow needs strictly greater sortOrder). Prefer pack
    // sortOrder; else first-seen paint order for this tab+rowId.
    final explicitSort = PackPaintArtifact.packInt(node['sortOrder']);
    final sortOrder =
        explicitSort ?? PackPaintArtifact.stableSortOrder(tabId, rowId);
    final defaultPad = catalogSectionHorizontalPadding(context);
    final pad =
        PackPaintArtifact.packLength(context, node['pad']) ?? defaultPad;
    final useCompact = widget.compactTop || node['compactTop'] == true;
    final titlePad = PackPaintArtifact.titlePadInsets(
      node['titlePad'],
      context,
      defaultTop: catalogSectionTitleTop(context, compact: useCompact),
      defaultBottom: catalogSectionBottomGap(context),
    );
    final defaultGap = shellPosterCardRowGap(context);
    final gap =
        PackPaintArtifact.packLength(context, node['gap']) ?? defaultGap;
    final rankedGap =
        PackPaintArtifact.packLength(context, node['rankedGap']) ?? gap;
    final aspect = aspectFallback == 'landscape'
        ? PosterAspect.landscape
        : PosterAspect.portrait;
    // Raw desktop px — [fromPaint] applies TV scale once.
    final itemWidth = PackPaintArtifact.packDouble(node['itemWidth']);
    final itemHeight = PackPaintArtifact.packDouble(
      node['itemHeight'] ?? node['height'],
    );
    final cardH = PackPaintArtifact.packLength(
          context,
          node['itemHeight'] ?? node['height'],
        ) ??
        InteractivePosterCard.cardHeight(context, aspect: aspect);
    final sep = ranked ? rankedGap : gap;
    final pageLoad = packLoadSpec(node['pageLoad']);
    final canPage = pageLoad != null && _hasMore;

    if (_items.isEmpty) {
      // Empty catalog rails hide entirely (title-only rows look broken).
      return const SizedBox.shrink();
    }

    final cards = <Widget>[
      for (var i = 0; i < _items.length; i++)
        _cardAt(
          context,
          _items[i],
          i,
          ranked: ranked,
          aspectFallback: aspectFallback,
          tabId: tabId,
          rowId: rowId,
          itemWidth: itemWidth,
          itemHeight: itemHeight,
        ),
    ];

    return TvKitRow(
      tabId: tabId,
      rowId: rowId,
      sortOrder: sortOrder,
      itemCount: cards.length,
      onFocusUp: focusUp,
      onFocusDown: focusDown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title.isNotEmpty)
            ShellSectionTitle(
              title: title,
              fontSize:
                  PackPaintArtifact.packLength(context, node['titleFontSize']),
              padding: EdgeInsetsDirectional.only(
                start: pad,
                top: titlePad.top,
                end: pad,
                bottom: titlePad.bottom,
              ),
            ),
          HorizontalScroller(
            height: cardH,
            padding: EdgeInsets.symmetric(horizontal: pad),
            itemCount: cards.length,
            onApproachingEnd: canPage ? _onApproachingEnd : null,
            separatorBuilder: (_, _) => SizedBox(width: sep),
            itemBuilder: (_, i) => cards[i],
          ),
        ],
      ),
    );
  }
}
