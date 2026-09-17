import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/runtime/actions/category_bar/category_bar_action_host.dart';
import 'package:forja/shared/engine/runtime/actions/schedule/live_schedule_progressive.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_feed.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/components/mood_circle.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/catalog/category_circle_meta.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';
import 'package:forja_foundation/widgets/catalog/home_loading_skeleton.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/feedback/catalog_loading_ticker.dart';

/// Reserved loading slot for one pack layout node (structure-stable).
({Widget placeholder, double height}) kitSectionLoadingSlot(
  BuildContext context,
  Map<String, dynamic> spec, {
  bool compact = false,
  bool pageBottomBleed = false,
  bool shimmer = true,
}) {
  final type = LayoutTypes.normalize((spec['type'] ?? '').toString(), spec);
  final title = (spec['title'] ?? '').toString().trim();
  final size = MediaQuery.sizeOf(context);
  // TV is full-bleed regardless of logical width (720p ATV ≈ 960dp < 1000).
  final screenCompact = !cinematicHeroIsFullBleed(
    width: size.width,
    tvDensity: catalogUsesTvDensity(context),
  );

  if (type == LayoutTypes.hero) {
    final heroH = homeCinematicHeroBodyHeight(
      screenHeight: size.height,
      compact: screenCompact,
      pageBottomBleed: pageBottomBleed,
    );
    return (
      placeholder: homeCinematicHeroShimmer(height: heroH),
      height: heroH,
    );
  }

  if (type == LayoutTypes.list) {
    final ticker = kitListLoadingTickerCopy(context, spec);
    if (ticker != null) {
      return (
        placeholder: CatalogLoadingTicker(title: ticker.$1, detail: ticker.$2),
        height: 160,
      );
    }
    const cardW = 160.0;
    const cardH = 100.0;
    final grid = homeLoadingShimmer(
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
                    homeCardSkeleton(width: cardW, height: cardH),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
    return (placeholder: grid, height: 8 + 3 * cardH + 2 * 12 + 24);
  }

  final cardW = InteractivePosterCard.cardWidth(context);
  final cardH = InteractivePosterCard.cardHeight(context);

  if (type == LayoutTypes.because) {
    return (
      placeholder: catalogBecauseRowSkeleton(
        context: context,
        compact: compact,
        cardWidth: cardW,
        cardHeight: cardH,
        shimmer: shimmer,
      ),
      height: catalogBecauseRowSkeletonHeight(
        context: context,
        cardHeight: cardH,
        compact: compact,
      ),
    );
  }

  if (type == LayoutTypes.continueWatching) {
    return (
      placeholder: catalogContinueRowSkeleton(
        context: context,
        compact: compact,
        title: title.isEmpty ? 'Continue Watching' : title,
        shimmer: shimmer,
      ),
      height: catalogContinueRowSkeletonHeight(
        context: context,
        compact: compact,
      ),
    );
  }

  if (type == LayoutTypes.mood) {
    final chipH = MoodCircleLayout.desktop.rowHeight;
    return (
      placeholder: catalogMoodRowSkeleton(
        context: context,
        title: title.isEmpty ? null : title,
        compact: compact,
        chipRowHeight: chipH,
        resultsCardHeight: cardH,
        resultsCardWidth: cardW,
        shimmer: shimmer,
      ),
      height: catalogMoodRowSkeletonHeight(
        context: context,
        compact: compact,
        chipRowHeight: chipH,
        resultsCardHeight: cardH,
      ),
    );
  }

  // rail / ranked / row / default poster section
  final titleBarW =
      title.isEmpty ? 140.0 : title.length * 10.0;
  final titleBarClamped =
      titleBarW < 80 ? 80.0 : (titleBarW > 220 ? 220.0 : titleBarW);
  return (
    placeholder: catalogPosterRowSkeleton(
      context: context,
      title: title.isEmpty ? null : title,
      titleWidth: titleBarClamped,
      compact: compact,
      cardWidth: cardW,
      cardHeight: cardH,
      shimmer: shimmer,
    ),
    height: catalogPosterRowSkeletonHeight(
      context: context,
      cardHeight: cardH,
      compact: compact,
    ),
  );
}

/// Pack-owned ticker copy (`loading` map / `loadingTitle`). Null → card skeleton.
(String, String)? kitListLoadingTickerCopy(
  BuildContext context,
  Map<String, dynamic> spec,
) {
  final catalogMenu = (spec['catalogMenu'] ?? '').toString().trim();
  var section = '';
  if (catalogMenu.isNotEmpty) {
    section =
        (LayoutScope.maybeOf(context)?.selectedId(catalogMenu) ?? '').trim();
    if (section.isEmpty) section = 'all';
  }

  final loading = spec['loading'];
  if (loading is Map) {
    final keyed = loading[section] ?? loading['default'] ?? loading['*'];
    if (keyed is Map) {
      final t = (keyed['title'] ?? '').toString().trim();
      final detail = (keyed['detail'] ?? '').toString().trim();
      if (t.isNotEmpty) {
        return (t, detail.isEmpty ? 'Fetching catalog…' : detail);
      }
    }
  }

  final t = (spec['loadingTitle'] ?? '').toString().trim();
  if (t.isEmpty) return null;
  final detail = (spec['loadingDetail'] ?? '').toString().trim();
  return (t, detail.isEmpty ? 'Fetching catalog…' : detail);
}

/// Bubbles from [PackLoadedPaint] → composition roots (`columnsHeader`).
/// When [cover] is true, hide the category rail so the ticker / empty fills
/// the whole body under the top bar (pre-kit IPTV behavior).
class PackCompositionCoverNotification extends Notification {
  PackCompositionCoverNotification({required this.cover});

  final bool cover;
}

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
  StreamSubscription<MetaEnvelope>? _progressiveSub;

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
      _progressiveSub?.cancel();
      _progressiveSub = null;
      _envelope = null;
      _lastPaintedWidget = null;
      _inFlight = null;
      _bindGen++;
      _holdAtRefreshEpoch = refreshEpoch;
    }

    // Portal switch / Refresh — drop old grid so CatalogLoadingTicker shows.
    // Any refresh bump also releases a portal hold (including clear+bump same frame).
    if (refreshBumped) {
      _progressiveSub?.cancel();
      _progressiveSub = null;
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

  @override
  void dispose() {
    _progressiveSub?.cancel();
    super.dispose();
  }

  void _bind() {
    final gen = ++_bindGen;
    _progressiveSub?.cancel();
    _progressiveSub = null;
    final future = _run();
    if (future == null) return;
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

  bool _wantsProgressiveCatalogs(Map<String, dynamic> params) {
    if (widget.action.trim() != 'feed') return false;
    return params['progressiveCatalogs'] == true ||
        widget.params['progressiveCatalogs'] == true;
  }

  void _setScheduleBusy({required bool busy, String? label}) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(liveScheduleFeedBusyProvider(widget.pluginId).notifier).state =
          (busy: busy, label: label);
    } catch (_) {}
  }

  /// Progressive catalog fan-out — paints after each scrape (issue 278).
  /// Returns null so [_bind] does not await a one-shot future.
  Future<MetaEnvelope>? _bindProgressive({
    required int gen,
    required Map<String, dynamic> runParams,
    required bool force,
    required String key,
  }) {
    _lastRunKey = key;
    if (!force) {
      final resolved = PackLoadedPaint._resolved[key];
      if (resolved != null) {
        _envelope = resolved;
        _inFlight = null;
        return null;
      }
    } else {
      PackLoadedPaint._resolved.remove(key);
      PackLoadedPaint._memo.remove(key);
    }

    _inFlight = Future.value(
      const MetaEnvelope(ok: false, action: 'feed', data: {}),
    );

    final completer = Completer<MetaEnvelope>();
    MetaEnvelope? last;
    var paintedOnce = false;
    _progressiveSub = loadLiveScheduleProgressive(
      hubPluginId: widget.pluginId,
      packSourceUrl: widget.packSourceUrl,
      feedParams: runParams,
      forceRefresh: force,
      setBusy: _setScheduleBusy,
    ).listen(
      (env) {
        if (!mounted || gen != _bindGen) return;
        last = env;
        PackLoadedPaint._resolved[key] = env;
        paintedOnce = true;
        setState(() {
          _envelope = env;
        });
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[PackLoadedPaint] progressive feed: $e\n$st');
        if (!completer.isCompleted) {
          completer.complete(
            MetaEnvelope.failure(
              MetaErrorCode.upstream,
              message: '${widget.pluginId} progressive feed failed',
              action: widget.action,
            ),
          );
        }
        if (!mounted || gen != _bindGen) return;
        _setScheduleBusy(busy: false, label: null);
        setState(() => _inFlight = null);
      },
      onDone: () {
        final env = last ??
            const MetaEnvelope(ok: true, action: 'feed', data: {'items': []});
        PackLoadedPaint._resolved[key] = env;
        if (!completer.isCompleted) completer.complete(env);
        if (!mounted || gen != _bindGen) return;
        setState(() {
          if (!paintedOnce) _envelope = env;
          _inFlight = null;
        });
      },
      cancelOnError: false,
    );
    PackLoadedPaint._memo[key] = completer.future;
    return null;
  }

  /// Memo hits return a resolved envelope via [_resolved] for sync paint.
  /// Null when a progressive stream was started instead.
  Future<MetaEnvelope>? _run() {
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

    if (_wantsProgressiveCatalogs(runParams)) {
      final gen = _bindGen;
      return _bindProgressive(
        gen: gen,
        runParams: runParams,
        force: force,
        key: key,
      );
    }

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
        _syncCompositionCover(false);
        return _lastPaintedWidget!;
      }
      _syncCompositionCover(true);
      return _sectionLoadingSkeleton();
    }
    if (!env.ok) {
      if (_lastPaintedWidget != null) {
        _syncCompositionCover(false);
        return _lastPaintedWidget!;
      }
      _syncCompositionCover(true);
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
    if (data['emptyTitle'] != null) {
      merged['emptyTitle'] = data['emptyTitle'];
    }
    if (data['emptyDescription'] != null) {
      merged['emptyDescription'] = data['emptyDescription'];
    }
    if (data['emptyAction'] != null) {
      merged['emptyAction'] = data['emptyAction'];
    }
    if (data.containsKey('coverBody')) {
      merged['coverBody'] = data['coverBody'];
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
    _syncCompositionCover(_specWantsCompositionCover(merged));
    final painted = widget.builder(context, merged);
    _lastPaintedWidget = painted;
    return painted;
  }

  /// Last successful paint — keep on screen while a soft reload runs.
  Widget? _lastPaintedWidget;

  bool? _lastCover;
  void _syncCompositionCover(bool cover) {
    final kindMenu = (widget.fallbackSpec['kindMenu'] ?? '').toString().trim();
    final catalogMenu =
        (widget.fallbackSpec['catalogMenu'] ?? '').toString().trim();
    // Only IPTV-style composition lists (cats + grid) — not Home rails.
    if (kindMenu.isEmpty && catalogMenu.isEmpty) return;
    if (_lastCover == cover) return;
    _lastCover = cover;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastCover != cover) return;
      PackCompositionCoverNotification(cover: cover).dispatch(context);
    });
  }

  bool _specWantsCompositionCover(Map<String, dynamic> spec) {
    // Pack opts in (no-portal empty). Do not infer from layout emptyAction —
    // that would hide categories on a filtered-empty group.
    return spec['coverBody'] == true;
  }

  void _publishDynamicKinds(BuildContext context, Map<String, dynamic> merged) {
    final chrome = PackChromeScope.maybeOf(context);
    if (chrome == null) return;
    final barId = (merged['kindMenu'] ?? '').toString().trim();
    if (barId.isEmpty) return;

    // Prefer pack-declared kinds (IPTV portal groups, Live Sports moods).
    // Do not invent an "All" row — packs that want it declare it in layout
    // items; the category bar merges layout seed + dynamic kinds.
    final declared = merged['kinds'] ?? merged['categories'];
    if (declared is List) {
      if (declared.isEmpty) {
        _scheduleDynamicBarPublish(context, chrome, barId, const []);
        return;
      }
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
      _scheduleDynamicBarPublish(context, chrome, barId, const []);
      return;
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
    final compact = widget.fallbackSpec['compactTop'] == true;
    final bleed = (widget.fallbackSpec['bleed'] ?? '').toString().trim();
    final slot = kitSectionLoadingSlot(
      context,
      widget.fallbackSpec,
      compact: compact,
      pageBottomBleed: bleed.isNotEmpty,
      shimmer: true,
    );
    return slot.placeholder;
  }
}
