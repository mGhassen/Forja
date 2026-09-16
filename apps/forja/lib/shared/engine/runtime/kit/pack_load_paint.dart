import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/actions/category_bar/category_bar_action_host.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_feed.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/catalog/category_circle_meta.dart';
import 'package:forja_foundation/widgets/catalog/home_loading_skeleton.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/feedback/catalog_loading_ticker.dart';


/// Runs an opaque pack [action], merges envelope fields into [fallbackSpec],
/// then builds via [builder] (caller paints — no paint_tree import).
class PackLoadedPaint extends StatefulWidget {
  const PackLoadedPaint({
    super.key,
    required this.pluginId,
    required this.action,
    required this.params,
    required this.fallbackSpec,
    required this.builder,
    this.packSourceUrl,
    this.tabId,
  });

  final String pluginId;
  final String? packSourceUrl;
  final String? tabId;
  final String action;
  final Map<String, dynamic> params;
  final Map<String, dynamic> fallbackSpec;
  final Widget Function(BuildContext context, Map<String, dynamic> merged)
      builder;

  /// Soft memo — in-flight futures + resolved envelopes (sync paint on remount).
  static final Map<String, Future<MetaEnvelope>> _memo = {};
  static final Map<String, MetaEnvelope> _resolved = {};

  /// Drop soft feed memos so portal switch cannot sync-paint a stale grid.
  static void clearMemosForPlugin(String pluginId) {
    final id = pluginId.trim();
    if (id.isEmpty) return;
    final prefix = '$id|';
    _memo.removeWhere((k, _) => k.startsWith(prefix));
    _resolved.removeWhere((k, _) => k.startsWith(prefix));
  }

  @override
  State<PackLoadedPaint> createState() => _PackLoadedPaintState();
}

class _PackLoadedPaintState extends State<PackLoadedPaint> {
  Future<MetaEnvelope>? _inFlight;
  MetaEnvelope? _envelope;
  String _scopeEpoch = '';
  String _catalogSection = '';
  int _appliedRefreshEpoch = 0;
  int _appliedHoldEpoch = 0;
  /// When set, skip auto-_bind until [PackChromeScope.refreshEpoch] advances past it.
  int? _holdAtRefreshEpoch;
  int _bindGen = 0;

  String _catalogSectionOf() {
    final menu = (widget.fallbackSpec['catalogMenu'] ?? '').toString().trim();
    if (menu.isEmpty) return '';
    return (LayoutScope.maybeOf(context)?.selectedId(menu) ?? '').trim();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final section = _catalogSectionOf();
    final epoch = _selectionEpoch();
    final chrome = PackChromeScope.maybeOf(context);
    final refreshEpoch = chrome?.refreshEpoch ?? 0;
    final holdEpoch = chrome?.catalogHoldEpoch ?? 0;
    final refreshBumped = refreshEpoch > _appliedRefreshEpoch;

    // Soft-keep Live paint under Movies/Series selection looks like a dead shelf.
    if (_catalogSection.isNotEmpty && section != _catalogSection) {
      _envelope = null;
      _lastPaintedWidget = null;
      // Invalidate post-frame Live kind publishes scheduled before this flip.
      _bindGen++;
    }

    // Portal click — wipe grid immediately; do not fetch until refresh bumps.
    if (holdEpoch > _appliedHoldEpoch) {
      _appliedHoldEpoch = holdEpoch;
      _envelope = null;
      _lastPaintedWidget = null;
      _inFlight = null;
      _bindGen++;
      _holdAtRefreshEpoch = refreshEpoch;
    }

    // Portal switch / Refresh — drop old grid so CatalogLoadingTicker shows.
    // Any refresh bump also releases a portal hold (including clear+bump same frame).
    if (refreshBumped) {
      _envelope = null;
      _lastPaintedWidget = null;
      _holdAtRefreshEpoch = null;
    }
    _catalogSection = section;

    final held = _holdAtRefreshEpoch != null &&
        refreshEpoch <= _holdAtRefreshEpoch!;

    // Only rebind on epoch change. `_envelope == null` alone used to restart the
    // in-flight Movies/Series feed when clearing the category bar notified
    // PackChromeScope — duplicate flutter_js → timeout → "did not answer".
    if (epoch != _scopeEpoch) {
      _scopeEpoch = epoch;
      if (!held) _bind();
    } else if (_envelope == null && _inFlight == null && !held) {
      _bind();
    }
  }

  @override
  void didUpdateWidget(covariant PackLoadedPaint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pluginId != widget.pluginId ||
        oldWidget.action != widget.action ||
        oldWidget.packSourceUrl != widget.packSourceUrl ||
        oldWidget.tabId != widget.tabId ||
        !_mapEquals(oldWidget.params, widget.params) ||
        oldWidget.fallbackSpec['statusTab'] !=
            widget.fallbackSpec['statusTab'] ||
        oldWidget.fallbackSpec['kindMenu'] != widget.fallbackSpec['kindMenu'] ||
        oldWidget.fallbackSpec['catalogMenu'] !=
            widget.fallbackSpec['catalogMenu'] ||
        oldWidget.fallbackSpec['sortMenu'] != widget.fallbackSpec['sortMenu'] ||
        oldWidget.fallbackSpec['horizonMenu'] !=
            widget.fallbackSpec['horizonMenu']) {
      _scopeEpoch = _selectionEpoch();
      _bind();
    }
  }

  String _selectionEpoch() {
    final chrome = PackChromeScope.maybeOf(context);
    return [
      packChromeSelectionEpoch(
        context,
        listSpec: widget.fallbackSpec,
        tabId: widget.tabId,
      ),
      // Top-bar / vertical filters — not in packChromeSelectionEpoch alone.
      catalogChromeFilterEpoch(widget.tabId),
      '${chrome?.refreshEpoch ?? 0}',
      // Do NOT hash pageFeedFuture identity — a reused/replaced Future for the
      // same refreshEpoch must not remount rails (flash skeletons on tab show).
    ].join('|');
  }

  void _bind() {
    final gen = ++_bindGen;
    final future = _run();
    final key = _lastRunKey;
    if (key != null) {
      final cached = PackLoadedPaint._resolved[key];
      if (cached != null) {
        // Sync hit — paint this frame. FutureBuilder would flash waiting.
        _envelope = cached;
        _inFlight = null;
        return;
      }
    }
    _inFlight = future;
    future.then((env) {
      if (!mounted || gen != _bindGen) return;
      setState(() {
        _envelope = env;
        _inFlight = null;
      });
    });
  }

  String? _lastRunKey;
  Map<String, dynamic> _lastFeedParams = const {};

  /// Memo hits return a resolved envelope via [_resolved] for sync paint.
  Future<MetaEnvelope> _run() {
    _lastRunKey = null;
    // Warm Live lists in background — never block catalog paint on SharedPrefs.
    if (widget.action == 'feed' || widget.action == 'rail') {
      unawaited(
        CategoryBarActionHost.liveListFeedParams(preferTabId: widget.tabId),
      );
    }
    if (!mounted) {
      return Future.value(
        const MetaEnvelope(ok: false, action: 'feed', data: {}),
      );
    }
    final chrome = PackChromeScope.maybeOf(context);
    final params = packChromeFeedParams(
      context,
      baseParams: widget.params,
      listSpec: widget.fallbackSpec,
      tabId: widget.tabId,
      pluginId: widget.pluginId,
    );
    // Epoch bump always rebinds. Pack `force` (skip disk cache) only when the
    // bump asked for network — portal switch soft-bumps so iptv.catalog hits.
    final refreshEpoch = chrome?.refreshEpoch ?? 0;
    final epochBumped = refreshEpoch > _appliedRefreshEpoch;
    final forceNetwork = chrome?.refreshForceNetwork ?? true;
    final force = (epochBumped && forceNetwork) ||
        params['force'] == true ||
        widget.params['force'] == true;
    if (epochBumped) {
      _appliedRefreshEpoch = refreshEpoch;
    }
    final runParams = force
        ? <String, dynamic>{...params, 'force': true}
        : params;
    _lastFeedParams = Map<String, dynamic>.from(runParams);
    final rail =
        (runParams['rail'] ?? widget.params['rail'] ?? '').toString().trim();
    final feedFuture = chrome?.pageFeedFuture;
    if (!force &&
        feedFuture != null &&
        widget.action == 'rail' &&
        chrome!.isPageFeedRail(rail) &&
        packRailParamsAreFeedShared(runParams)) {
      final key = [
        widget.pluginId,
        'pageFeed',
        rail,
        widget.packSourceUrl ?? '',
        _scopeEpoch,
      ].join('|');
      _lastRunKey = key;
      final resolved = PackLoadedPaint._resolved[key];
      if (resolved != null) return Future.value(resolved);
      final hit = PackLoadedPaint._memo[key];
      if (hit != null) {
        return hit.then((env) {
          PackLoadedPaint._resolved[key] = env;
          return env;
        });
      }
      final future = feedFuture.then((rails) {
        final items = rails[rail] ?? const <dynamic>[];
        final env = MetaEnvelope(
          ok: true,
          action: 'rail',
          data: {'items': items},
        );
        PackLoadedPaint._resolved[key] = env;
        return env;
      });
      PackLoadedPaint._memo[key] = future;
      return future;
    }
    final key = [
      widget.pluginId,
      widget.action,
      widget.packSourceUrl ?? '',
      _scopeEpoch,
      _stableParamsKey(runParams),
    ].join('|');
    _lastRunKey = key;
    if (!force) {
      final resolved = PackLoadedPaint._resolved[key];
      if (resolved != null) return Future.value(resolved);
      final hit = PackLoadedPaint._memo[key];
      if (hit != null) {
        return hit.then((env) {
          PackLoadedPaint._resolved[key] = env;
          return env;
        });
      }
    } else {
      PackLoadedPaint._resolved.remove(key);
      PackLoadedPaint._memo.remove(key);
    }
    final future = packOpaqueRun(
      pluginId: widget.pluginId,
      action: widget.action,
      params: runParams,
      packSourceUrl: widget.packSourceUrl,
      forceRefresh: force,
    ).then((env) {
      PackLoadedPaint._resolved[key] = env;
      return env;
    });
    PackLoadedPaint._memo[key] = future;
    if (PackLoadedPaint._memo.length > 48) {
      final drop = PackLoadedPaint._memo.keys.first;
      PackLoadedPaint._memo.remove(drop);
      PackLoadedPaint._resolved.remove(drop);
    }
    if (PackLoadedPaint._resolved.length > 48) {
      PackLoadedPaint._resolved.remove(PackLoadedPaint._resolved.keys.first);
    }
    return future;
  }

  String _stableParamsKey(Map<String, dynamic> params) {
    final keys = params.keys.toList()..sort();
    return [
      for (final k in keys)
        if (k != 'force' && k != 'refresh') '$k=${params[k]}',
    ].join('&');
  }

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final env = _envelope;
    if (env == null) {
      // Soft-keep only for non-portal soft reloads. Portal clear/hold always
      // shows the loading ticker (last paint already dropped).
      if (_inFlight != null &&
          _lastPaintedWidget != null &&
          _holdAtRefreshEpoch == null) {
        return _lastPaintedWidget!;
      }
      return _sectionLoadingSkeleton();
    }
    if (!env.ok) {
      if (_lastPaintedWidget != null) return _lastPaintedWidget!;
      final msg = env.error?.message.trim();
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          (msg != null && msg.isNotEmpty)
              ? msg
              : 'Could not load this section.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ForjaShellColors.textSecondary),
        ),
      );
    }
    final data = env.data ?? const <String, dynamic>{};
    final merged = Map<String, dynamic>.from(widget.fallbackSpec);
    if (data['items'] is List) merged['items'] = data['items'];
    if (data['widgets'] is List) merged['widgets'] = data['widgets'];
    if (data['paint'] is Map) merged['paint'] = data['paint'];
    if (data['heading'] != null) merged['heading'] = data['heading'];
    if (data['kinds'] is List) merged['kinds'] = data['kinds'];
    if (data['categories'] is List) {
      merged['categories'] = data['categories'];
    }
    if (data['seedPoster'] != null) {
      merged['seedPoster'] = data['seedPoster'];
    }
    if (data.containsKey('canShuffle')) {
      merged['canShuffle'] = data['canShuffle'];
    }
    final pageSize = catalogRailPageSizeFrom(data) ??
        catalogRailPageSizeFrom(widget.fallbackSpec) ??
        kMetaRailPageSizeFallback;
    final items = data['items'];
    final itemCount = items is List ? items.length : 0;
    if (data.containsKey('hasMore')) {
      merged['hasMore'] = data['hasMore'];
    } else if (itemCount > 0) {
      // Feed map strips paging — assume more when the first page is full.
      merged['hasMore'] = itemCount >= pageSize;
    }
    merged['pageSize'] = pageSize;
    final maxPages = catalogRailMaxPagesFrom(data) ??
        catalogRailMaxPagesFrom(widget.fallbackSpec);
    if (maxPages != null) merged['maxPages'] = maxPages;
    // Opaque next-page handle (not `load` — that would re-enter PackLoadedPaint).
    // Use the chrome-merged params from the paint that produced this envelope
    // (section/category/sort) — widget.params alone drops IPTV Movies paging.
    if (widget.action.trim().isNotEmpty) {
      final pageParams = Map<String, dynamic>.from(
        _lastFeedParams.isNotEmpty ? _lastFeedParams : widget.params,
      );
      pageParams.remove('force');
      pageParams.remove('refresh');
      if (maxPages != null) pageParams['maxPages'] = maxPages;
      merged['pageLoad'] = {
        'action': widget.action,
        'params': pageParams,
      };
    }
    merged.remove('load');
    _publishDynamicKinds(context, merged);
    final painted = widget.builder(context, merged);
    _lastPaintedWidget = painted;
    return painted;
  }

  /// Last successful paint — keep on screen while a soft reload runs.
  Widget? _lastPaintedWidget;

  void _publishDynamicKinds(BuildContext context, Map<String, dynamic> merged) {
    final chrome = PackChromeScope.maybeOf(context);
    if (chrome == null) return;
    final barId = (merged['kindMenu'] ?? '').toString().trim();
    if (barId.isEmpty) return;

    // Prefer pack-declared kinds (IPTV portal groups, Live Sports moods).
    // Do not invent an "All" row — packs that want it declare it in layout
    // items; the category bar merges layout seed + dynamic kinds.
    final declared = merged['kinds'] ?? merged['categories'];
    if (declared is List && declared.isNotEmpty) {
      final items = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final raw in declared) {
        if (raw is! Map) continue;
        final id = (raw['id'] ?? raw['category_id'] ?? '').toString().trim();
        if (id.isEmpty || id == 'all' || !seen.add(id)) continue;
        final label = (raw['label'] ?? raw['name'] ?? raw['category_name'] ?? id)
            .toString()
            .trim();
        items.add({
          'id': id,
          'label': catalogKitCategoryLabel(id, label: label),
        });
      }
      if (items.isNotEmpty) {
        _scheduleDynamicBarPublish(context, chrome, barId, items);
        return;
      }
    }

    final raw = merged['items'];
    if (raw is! List) return;
    final kinds = <String>[];
    final labels = <String, String>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final item = Map<String, dynamic>.from(e);
      final kind = _dynamicKindOf(item);
      if (kind.isEmpty || kind == 'all' || kind == 'live_match') continue;
      if (!kinds.contains(kind)) kinds.add(kind);
      final cn = (item['categoryName'] ??
              item['category'] ??
              (item['paint'] is Map && (item['paint'] as Map)['props'] is Map
                  ? ((item['paint'] as Map)['props'] as Map)['categoryLabel']
                  : null) ??
              '')
          .toString()
          .trim();
      if (cn.isNotEmpty) labels.putIfAbsent(kind, () => cn);
    }
    if (kinds.isEmpty) return;
    final items = <Map<String, dynamic>>[
      for (final id in kinds)
        {
          'id': id,
          'label': catalogKitCategoryLabel(id, label: labels[id]),
        },
    ];
    _scheduleDynamicBarPublish(context, chrome, barId, items);
  }

  /// Drop stale Live kinds after Movies/Series already cleared the rail.
  void _scheduleDynamicBarPublish(
    BuildContext context,
    PackChromeScope chrome,
    String barId,
    List<Map<String, dynamic>> items,
  ) {
    final section = _catalogSectionOf();
    final gen = _bindGen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || gen != _bindGen) return;
      if (_catalogSectionOf() != section) return;
      chrome.onDynamicBarItems(barId, items);
    });
  }

  String _dynamicKindOf(Map<String, dynamic> item) {
    final props = item['paint'] is Map && (item['paint'] as Map)['props'] is Map
        ? Map<String, dynamic>.from((item['paint'] as Map)['props'] as Map)
        : const <String, dynamic>{};
    for (final key in [
      item['categoryId'],
      item['kind'],
      item['category'],
      item['sport'],
      props['kind'],
      props['categoryId'],
      if (item['meta'] is Map) (item['meta'] as Map)['kind'],
      if (item['meta'] is Map) (item['meta'] as Map)['categoryId'],
    ]) {
      final v = (key ?? '').toString().trim();
      if (v.isNotEmpty && v != 'iptv' && v != 'movie' && v != 'tv') return v;
    }
    return '';
  }

  /// Finite-height light skeleton — CatalogBody mounts this in a sliver.
  Widget _sectionLoadingSkeleton() {
    final type = (widget.fallbackSpec['type'] ?? '').toString().toLowerCase();
    if (type.contains('hero')) {
      return homeCinematicHeroShimmer(height: 420);
    }
    if (type.contains('list') || type == 'kit.list') {
      final ticker = _listLoadingTickerCopy();
      if (ticker != null) {
        return CatalogLoadingTicker(title: ticker.$1, detail: ticker.$2);
      }
      return homeLoadingShimmer(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              for (var r = 0; r < 3; r++) ...[
                if (r > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    for (var c = 0; c < 4; c++) ...[
                      if (c > 0) const SizedBox(width: 12),
                      homeCardSkeleton(width: 160, height: 100),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }
    final cardW = InteractivePosterCard.cardWidth(context);
    final cardH = InteractivePosterCard.cardHeight(context);
    if (type == 'because' || type.contains('because')) {
      return homeLoadingShimmer(
        homeBecauseRowSkeleton(
          topPadding: 12,
          itemCount: 5,
          cardWidth: cardW,
          cardHeight: cardH,
        ),
      );
    }
    return homeLoadingShimmer(
      homePosterRowSkeleton(
        topPadding: 12,
        titleWidth: 140,
        itemCount: 5,
        cardWidth: cardW,
        cardHeight: cardH,
      ),
    );
  }

  /// Pack-owned ticker copy (`loading` map / `loadingTitle`). Null → card skeleton.
  (String, String)? _listLoadingTickerCopy() {
    final spec = widget.fallbackSpec;
    final catalogMenu = (spec['catalogMenu'] ?? '').toString().trim();
    var section = '';
    if (catalogMenu.isNotEmpty) {
      section =
          (LayoutScope.maybeOf(context)?.selectedId(catalogMenu) ?? '').trim();
      if (section.isEmpty) section = 'live';
    }

    final loading = spec['loading'];
    if (loading is Map) {
      final keyed = loading[section] ?? loading['default'] ?? loading['*'];
      if (keyed is Map) {
        final title = (keyed['title'] ?? '').toString().trim();
        final detail = (keyed['detail'] ?? '').toString().trim();
        if (title.isNotEmpty) {
          return (
            title,
            detail.isEmpty ? 'Fetching catalog…' : detail,
          );
        }
      }
    }

    final title = (spec['loadingTitle'] ?? '').toString().trim();
    if (title.isEmpty) return null;
    final detail = (spec['loadingDetail'] ?? '').toString().trim();
    return (title, detail.isEmpty ? 'Fetching catalog…' : detail);
  }
}
