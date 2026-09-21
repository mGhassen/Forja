import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/portals/guide/portal_channel_guide_open.dart';
import 'package:forja/shared/engine/runtime/kit/focus_edge.dart';
import 'package:forja/shared/engine/runtime/kit/hub_page_focus.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_feed.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/engine/runtime/kit/paint_tree.dart';
import 'package:forja/shared/engine/runtime/kit/row_prefetch.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja/shared/engine/runtime/nav/feed_chrome.dart';
import 'package:forja/shared/engine/store/list_providers.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/chrome/vertical_filters_rail.dart';
import 'package:forja/shell/core/forja_shell_layout.dart';
import 'package:forja/shell/routing/shell_tab_refresh.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/blocks/catalog/catalog_body_block.dart';
import 'package:forja_foundation/widgets/catalog/home_loading_skeleton.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/feedback/error_retry_panel.dart';

/// Hub tab mount — validate pack page JSON and paint. No product field mappers.
///
/// Page action comes from pack [nav.page.action] (opaque). Default empty → error.
class PackLayoutPainter extends StatefulWidget {
  const PackLayoutPainter({
    super.key,
    required this.pluginId,
    this.tabId,
    this.packSourceUrl,
    this.pageAction,
    this.pageParams,
  });

  final String pluginId;
  final String? tabId;
  final String? packSourceUrl;

  /// Opaque pack action that returns the page tree (`pages` / `widgets`).
  final String? pageAction;
  final Map<String, dynamic>? pageParams;

  @override
  State<PackLayoutPainter> createState() => _PackLayoutPainterState();
}

class _PackLayoutPainterState extends State<PackLayoutPainter>
    with AutomaticKeepAliveClientMixin, ShellTabRefresh<PackLayoutPainter> {
  List<Map<String, dynamic>> _widgets = const [];
  final Map<String, String> _layoutSelections = {};
  String _eventQuery = '';
  int _refreshEpoch = 0;
  bool _refreshForceNetwork = true;
  bool _refreshKeepPainted = false;
  int _catalogHoldEpoch = 0;
  String _viewStyle = '';
  final Map<String, List<Map<String, dynamic>>> _dynamicBarItems = {};
  final ValueNotifier<Map<String, dynamic>?> _selectedListItem =
      ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<Set<String>> _searchHitKinds =
      ValueNotifier<Set<String>>(const {});
  /// Category selected before opening Search (restored on clear).
  String? _categoryBeforeSearch;
  bool _layoutRtl = false;
  String? _error;
  bool _loading = true;
  final ScrollController _scroll = ScrollController();

  Set<String> _eagerLoadKeys = const {};
  Set<String> _pageFeedRailIds = const {};
  Future<Map<String, List<dynamic>>>? _pageFeedFuture;
  /// Sync rails for [PackChromeScope.pageFeedRails] — avoids microtask skeleton.
  Map<String, List<dynamic>>? _pageFeedRails;
  MetaError? _pageFeedError;
  String _sectionStructureSig = '';
  Listenable? _filterListenable;
  final KitRowPrefetchLane _rowPrefetch = KitRowPrefetchLane();
  HubPageFocus _pageFocus = HubPageFocus.empty;
  String? _tvBoundKey;
  bool _listStyleHydrateStarted = false;

  String get _pageKey => widget.tabId?.trim() ?? '';

  String get _pageAction {
    final fromWidget = widget.pageAction?.trim() ?? '';
    if (fromWidget.isNotEmpty) return fromWidget;
    final fromNav = PluginNavRegistry.pageActionForTab(_pageKey);
    if (fromNav != null && fromNav.isNotEmpty) return fromNav;
    return '';
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_publishScroll);
    PluginRegistry.hubFeedEpoch.addListener(_onHubFeedEpoch);
    listFeedEpochListenable.addListener(_onListFeedEpoch);
    // Sync shell from EngineCache when boot prefetch / prior visit warmed layout.
    final warmed = _tryApplyCachedLayout();
    unawaited(_loadPage(keepPainted: warmed));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listStyleHydrateStarted) return;
    _listStyleHydrateStarted = true;
    unawaited(_hydrateListStyle());
  }

  String get _chromeKey =>
      kitChromeKey(pluginId: widget.pluginId, tabId: _pageKey);

  /// Paint-only view (`list` / `cards` / `guide` / `epg`). List/Cards also
  /// hydrate from disk; guide/epg stay session-only.
  void _applyViewStyle(String style) {
    final v = style.trim().toLowerCase();
    if (v != 'list' &&
        v != 'cards' &&
        v != 'guide' &&
        v != 'epg') {
      return;
    }
    if (_viewStyle == v && _layoutSelections['view'] == v) return;
    void apply() {
      _viewStyle = v;
      _layoutSelections['view'] = v;
    }
    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _applyListStyle(String style) {
    final v = style.trim().toLowerCase();
    if (v != 'list' && v != 'cards') return;
    _applyViewStyle(v);
  }

  Future<void> _hydrateListStyle() async {
    final key = _chromeKey;
    if (key.isEmpty || !mounted) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await applyPersistedKitListStyle(
        container: container,
        chromeKey: key,
        apply: _applyListStyle,
      );
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant PackLayoutPainter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pluginId != widget.pluginId ||
        oldWidget.tabId != widget.tabId ||
        oldWidget.packSourceUrl != widget.packSourceUrl ||
        oldWidget.pageAction != widget.pageAction) {
      _viewStyle = '';
      unawaited(_loadPage(force: true));
      unawaited(_hydrateListStyle());
    }
  }

  @override
  void dispose() {
    _filterListenable?.removeListener(_onChromeFiltersChanged);
    PluginRegistry.hubFeedEpoch.removeListener(_onHubFeedEpoch);
    listFeedEpochListenable.removeListener(_onListFeedEpoch);
    _scroll.removeListener(_publishScroll);
    _scroll.dispose();
    _selectedListItem.dispose();
    _searchHitKinds.dispose();
    final tab = widget.tabId?.trim();
    if (tab != null && tab.isNotEmpty) {
      VerticalFiltersRegistry.unregister(tab);
      ShellBus.hubScrollOffsetFor(tab).value = 0;
      // Drop tab TV defaults — hero may have merged defaultFocus into the same id.
      TvHeroActions.unbind(tab);
      ShellTvFocusCoordinator.setTabPageScroll(tab, null);
    }
    super.dispose();
  }

  void _bindHubTvDefaults(String tab) {
    if (tab.isEmpty) return;
    final key = '$tab|${_pageFocus.signature}';
    if (_tvBoundKey == key) return;
    _tvBoundKey = key;
    bindHubPageFocus(tab, _pageFocus);
    // Hero CTA merges defaultFocus via TvHeroActions.bind (no enter overwrite).
    TvHeroActions.bind(tab, heroReveal: _revealHeroScroll);
    ShellTvFocusCoordinator.setTabPageScroll(tab, _nudgeHubPageScroll);
  }

  /// One catalog-row step — mounts below-fold slivers / LazyViewportGate for ↓.
  bool _nudgeHubPageScroll({required bool down}) {
    if (!_scroll.hasClients) return false;
    final pos = _scroll.position;
    if (!pos.hasPixels || !pos.hasContentDimensions) return false;
    // Title pad + poster height + section gap — enough to reveal the next rail.
    final step = catalogSectionTitleTop(context) +
        shellPosterCardHeight(context) +
        ShellTokens.homeRowSpacing +
        48;
    final target = down
        ? (pos.pixels + step).clamp(0.0, pos.maxScrollExtent)
        : (pos.pixels - step).clamp(0.0, pos.maxScrollExtent);
    if ((target - pos.pixels).abs() < 1.0) return false;
    // Instant jump — animated scroll leaves D-pad focus clipped mid-tween.
    pos.jumpTo(target);
    return true;
  }

  void _revealHeroScroll() {
    if (!_scroll.hasClients) return;
    unawaited(
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _rebindChromeFilters() {
    _filterListenable?.removeListener(_onChromeFiltersChanged);
    _filterListenable = catalogChromeFilterListenable(_pageKey);
    _filterListenable?.addListener(_onChromeFiltersChanged);
  }

  void _onChromeFiltersChanged() {
    if (!mounted || _pageFeedRailIds.isEmpty) return;
    setState(() {
      _pageFeedError = null;
      _pageFeedRails = _peekPageFeedRails();
      _pageFeedFuture = _pageFeedRails != null
          ? Future<Map<String, List<dynamic>>>.value(_pageFeedRails!)
          : _bindPageFeed(forceRefresh: false);
    });
  }

  void _onHubFeedEpoch() {
    if (!mounted) return;
    if (!PluginRegistry.hubFeedEpochTouches(widget.pluginId)) return;
    // Soft: keep painted rails while scripts refresh. Must bump refreshEpoch
    // so PackLoadedPaint rebinds — layout-only soft reload left Home on a
    // stale/empty page-feed slice (Popular title, no hero) after Reload packs.
    PackLoadedPaint.clearMemosForPlugin(widget.pluginId);
    setState(() {
      _refreshEpoch++;
      _refreshForceNetwork = true;
      _refreshKeepPainted = true;
      if (_pageFeedRailIds.isNotEmpty) {
        _pageFeedRails = null;
        _pageFeedError = null;
        _pageFeedFuture = _bindPageFeed(forceRefresh: true);
      }
    });
    unawaited(_loadPage(force: true, keepPainted: true));
  }

  /// Bookmark / Simkl list write — only hubs with a status-tab list (My List).
  /// Soft: keep painted grid; swap items when the new feed lands.
  void _onListFeedEpoch() {
    if (!mounted || !_layoutHasStatusTab()) return;
    setState(() {
      _refreshEpoch++;
      _refreshForceNetwork = true;
      _refreshKeepPainted = true;
      if (_pageFeedRailIds.isNotEmpty) {
        _pageFeedRails = null;
        _pageFeedError = null;
        _pageFeedFuture = _bindPageFeed(forceRefresh: true);
      }
    });
  }

  bool _layoutHasStatusTab() {
    var found = false;
    walkLayoutWidgets(_widgets, (spec) {
      if (found) return;
      final type = LayoutTypes.normalize((spec['type'] ?? '').toString(), spec);
      if (type != LayoutTypes.list) return;
      if ((spec['statusTab'] ?? '').toString().trim().isNotEmpty) {
        found = true;
      }
    });
    return found;
  }

  void _publishScroll() {
    if (_pageKey.isEmpty) return;
    ShellBus.hubScrollOffsetFor(_pageKey).value =
        _scroll.hasClients ? _scroll.offset : 0;
  }

  @override
  Future<void> onShellTabRefresh({required bool force}) =>
      _loadPage(force: force);

  Map<String, dynamic> _pageRunParams() => <String, dynamic>{
        ...?widget.pageParams,
        ...?PluginNavRegistry.pageParamsForTab(_pageKey),
        'page': _pageKey,
      };

  /// Sync-apply pack page tree from EngineCache. Returns true when structure painted.
  bool _tryApplyCachedLayout() {
    final action = _pageAction;
    if (action.isEmpty) return false;
    final env = MetaRuntime.instance.peekCached(
      pluginId: widget.pluginId,
      action: action,
      params: _pageRunParams(),
      packSourceUrl: widget.packSourceUrl,
    );
    if (env == null || !env.ok || env.data == null) return false;
    if (validateLayoutData(env.data) != null) return false;
    // initState — mutate fields without setState.
    _applyLayoutData(
      env.data!,
      forceFeed: false,
      reuseFeed: true,
      notify: false,
    );
    return true;
  }

  void _applyLayoutData(
    Map<String, dynamic> data, {
    required bool forceFeed,
    required bool reuseFeed,
    bool notify = true,
  }) {
    final pages = data['pages'];
    var widgets = <Map<String, dynamic>>[];
    Map<String, dynamic>? pageMap;
    if (pages is Map && pages.isNotEmpty) {
      final page = pages[_pageKey] ?? pages.values.first;
      if (page is Map) {
        pageMap = Map<String, dynamic>.from(page);
        final raw = pageMap['widgets'];
        if (raw is List) {
          widgets = [
            for (final w in raw)
              if (w is Map) Map<String, dynamic>.from(w),
          ];
        }
      }
    } else {
      final raw = data['widgets'];
      if (raw is List) {
        widgets = [
          for (final w in raw)
            if (w is Map) Map<String, dynamic>.from(w),
        ];
      }
    }

    // First-paint only (hero → Continue). Do NOT union page feedRails —
    // packs put later rails (e.g. new_releases) in feed for batching while
    // still wanting LazyViewportGate until scrolled into view.
    final eager = _firstPaintEagerKeys(widgets);
    final feedIds = _feedRailIdsForPage(pageMap, widgets);
    Future<Map<String, List<dynamic>>>? feedFuture;
    Map<String, List<dynamic>>? feedRails;
    MetaError? feedError;
    if (feedIds.isNotEmpty) {
      // Reuse in-flight / completed page feed when layout soft-reloads so
      // PackLoadedPaint does not remount every rail (skeleton flash).
      if (reuseFeed &&
          !forceFeed &&
          _pageFeedFuture != null &&
          setEquals(feedIds, _pageFeedRailIds)) {
        feedFuture = _pageFeedFuture;
        feedRails = _pageFeedRails;
        feedError = _pageFeedError;
      } else if (!forceFeed) {
        // Sync EngineCache hit — rails must paint this frame (Future.value
        // alone still schedules .then as a microtask → shimmer flash).
        feedRails = _peekPageFeedRails();
        feedError = null;
        feedFuture = feedRails != null
            ? Future<Map<String, List<dynamic>>>.value(feedRails)
            : _bindPageFeed(forceRefresh: false);
      } else {
        feedRails = null;
        feedError = null;
        feedFuture = _bindPageFeed(forceRefresh: true);
      }
    }

    void apply() {
      _loading = false;
      _error = null;
      _widgets = widgets;
      _layoutRtl = catalogLayoutIsRtl(data);
      _eagerLoadKeys = eager;
      _pageFeedRailIds = feedIds;
      _pageFeedFuture = feedFuture;
      _pageFeedRails = feedRails;
      _pageFeedError = feedError;
      _rowPrefetch.reset();
      initLayoutTabSelections(_layoutSelections, widgets);
      // Remembered view (List/Cards/EPG) wins over pack default (seeded above).
      final remembered = _viewStyle.trim();
      if (remembered == 'list' ||
          remembered == 'cards' ||
          remembered == 'guide' ||
          remembered == 'epg') {
        _layoutSelections['view'] = remembered;
      }
      // Page map first; root layout `focus` as fallback.
      _pageFocus = HubPageFocus.parse(pageMap);
      if (_pageFocus.isEmpty) {
        _pageFocus = HubPageFocus.parse(data);
      }
    }

    if (notify && mounted) {
      setState(apply);
    } else {
      apply();
    }
    _rebindChromeFilters();
    final tab = widget.tabId?.trim();
    if (tab != null && tab.isNotEmpty) {
      VerticalFiltersRegistry.syncFromLayout(
        tabId: tab,
        pluginId: widget.pluginId,
        packSourceUrl: widget.packSourceUrl,
        widgets: widgets,
      );
      // Lock TV sortOrder to layout order before async bleed/rails paint.
      PackPaintArtifact.reserveHubFocusRowOrder(
        tab,
        hubFocusRowIdsFromLayout(widgets),
      );
      _bindHubTvDefaults(tab);
    }
    markShellTabFresh();
  }

  /// Focus row ids in visual / D-pad order (hero bleed → rails → mood → …).
  static List<String> hubFocusRowIdsFromLayout(
    List<Map<String, dynamic>> widgets,
  ) {
    String? bleedKey;
    Map<String, dynamic>? bleedSpec;
    for (final w in widgets) {
      final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
      if (type != LayoutTypes.hero) continue;
      final bleed = (w['bleed'] ?? '').toString().trim();
      if (bleed.isNotEmpty) bleedKey = bleed;
      break;
    }
    if (bleedKey != null) {
      for (final preferRail in [true, false]) {
        for (final w in widgets) {
          final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
          if (preferRail) {
            final isRail = type == LayoutTypes.row ||
                type == 'rail' ||
                type == 'ranked' ||
                type == LayoutTypes.list;
            if (!isRail) continue;
          } else if (type == LayoutTypes.mood ||
              type == LayoutTypes.continueWatching ||
              type == LayoutTypes.because ||
              type == LayoutTypes.hero ||
              type == LayoutTypes.verticalFilters) {
            continue;
          }
          final id = (w['id'] ?? '').toString().trim();
          final rail = (w['rail'] ?? '').toString().trim();
          if (id != bleedKey && rail != bleedKey) continue;
          bleedSpec = w;
          break;
        }
        if (bleedSpec != null) break;
      }
    }

    final out = <String>[];
    void add(String id) {
      final t = id.trim();
      if (t.isEmpty) return;
      if (out.contains(t)) return;
      out.add(t);
    }

    for (final w in widgets) {
      final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
      if (type == LayoutTypes.verticalFilters) continue;
      if (identical(w, bleedSpec) && bleedSpec?['hideWhenBleed'] == true) {
        // Bleed rides under hero — reserve its id when we hit the hero.
        continue;
      }
      if (type == LayoutTypes.hero) {
        if (bleedKey != null) add(bleedKey);
        continue;
      }
      if (type == LayoutTypes.continueWatching) {
        final id = (w['id'] ?? 'continue_watching').toString().trim();
        add(id.isEmpty ? 'continue_watching' : id);
        continue;
      }
      if (type == LayoutTypes.mood) {
        add('mood-chips');
        add('mood-results');
        continue;
      }
      if (type == LayoutTypes.because) {
        add('because-shuffle');
        add('because');
        continue;
      }
      if (type == LayoutTypes.row ||
          type == 'rail' ||
          type == 'ranked' ||
          type == LayoutTypes.list) {
        final id = (w['id'] ?? w['rail'] ?? '').toString().trim();
        add(id);
      }
    }
    return out;
  }

  Future<void> _loadPage({bool force = false, bool keepPainted = false}) async {
    final action = _pageAction;
    if (action.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'This hub did not declare nav.page.action — pack must own the page load.';
        _widgets = const [];
      });
      return;
    }

    final soft = keepPainted || (_widgets.isNotEmpty && !force);
    if (!soft) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    await PluginInstallCoordinator.instance.waitUntilIdle();
    if (!mounted) return;

    final enabled = await PluginNavRegistry.isKitPluginEnabled(
      widget.pluginId,
      packSourceUrl: widget.packSourceUrl,
    );
    if (!mounted) return;
    if (!enabled) {
      setState(() {
        _loading = false;
        _widgets = const [];
        _error =
            'This hub plugin is off. Enable it under Settings → Sources → Forja (Hubs).';
      });
      return;
    }

    final params = _pageRunParams();

    // After install idle, cache may have filled — paint structure before await.
    if (!force && _widgets.isEmpty) {
      final peeked = MetaRuntime.instance.peekCached(
        pluginId: widget.pluginId,
        action: action,
        params: params,
        packSourceUrl: widget.packSourceUrl,
      );
      if (peeked != null &&
          peeked.ok &&
          peeked.data != null &&
          validateLayoutData(peeked.data) == null) {
        _applyLayoutData(peeked.data!, forceFeed: false, reuseFeed: true);
      }
    }

    final envelope = await packOpaqueRun(
      pluginId: widget.pluginId,
      action: action,
      params: params,
      packSourceUrl: widget.packSourceUrl,
      forceRefresh: force,
    );
    if (!mounted) return;

    if (!envelope.ok) {
      if (_widgets.isNotEmpty) return;
      setState(() {
        _loading = false;
        _error = userFacingCatalogError(
          envelope.error,
          fallback: 'Couldn’t load this hub. Try again.',
        );
      });
      return;
    }

    final invalid = validateLayoutData(envelope.data);
    if (invalid != null) {
      if (_widgets.isNotEmpty) return;
      setState(() {
        _loading = false;
        _error = 'This hub’s layout is invalid.';
      });
      return;
    }

    _applyLayoutData(
      envelope.data!,
      forceFeed: force,
      reuseFeed: !force,
    );
  }

  Set<String> _firstPaintEagerKeys(List<Map<String, dynamic>> widgets) {
    final out = <String>{};
    String? bleed;
    for (final w in widgets) {
      final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
      if (type == LayoutTypes.continueWatching) break;
      if (type == LayoutTypes.verticalFilters || type == LayoutTypes.mood) {
        continue;
      }
      final id = (w['id'] ?? '').toString().trim();
      final rail = (w['rail'] ?? '').toString().trim();
      if (id.isNotEmpty) out.add(id);
      if (rail.isNotEmpty) out.add(rail);
      if (type == LayoutTypes.hero) {
        final b = (w['bleed'] ?? '').toString().trim();
        if (b.isNotEmpty) bleed = b;
      }
    }
    if (bleed != null) out.add(bleed);
    return out;
  }

  Set<String> _feedRailIdsForPage(
    Map<String, dynamic>? pageMap,
    List<Map<String, dynamic>> widgets,
  ) {
    if (pageMap == null || pageMap['feed'] != true) return const {};
    final declared = catalogLayoutFeedRailIds(pageMap);
    if (declared.isNotEmpty) return declared;
    // Legacy feed pages: batch rail loads that share the feed map key only.
    // Skip per-instance params (e.g. genreRow) — those must hit action:'rail'.
    final out = <String>{};
    for (final w in widgets) {
      final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
      if (type == LayoutTypes.mood ||
          type == LayoutTypes.because ||
          type == LayoutTypes.continueWatching ||
          type == LayoutTypes.verticalFilters) {
        continue;
      }
      final load = packLoadSpec(w['load']);
      if (load == null || load.action != 'rail') continue;
      if (!packRailParamsAreFeedShared(load.params)) continue;
      final rail = (load.params['rail'] ?? w['rail'] ?? '').toString().trim();
      if (rail.isNotEmpty) out.add(rail);
    }
    return out;
  }

  Map<String, dynamic> _pageFeedParams() => catalogParamsWithFilters(
        const {},
        filters: catalogChromeFilters(
          tabId: widget.tabId,
          pluginId: widget.pluginId,
        ),
      );

  Map<String, List<dynamic>>? _railsMapFromEnvelope(MetaEnvelope? envelope) {
    if (envelope == null || !envelope.ok) return null;
    final rails = envelope.data?['rails'];
    if (rails is! Map) return null;
    final out = <String, List<dynamic>>{};
    for (final e in rails.entries) {
      final key = e.key.toString();
      final items = e.value;
      if (items is! List) continue;
      out[key] = List<dynamic>.from(items);
    }
    return out;
  }

  /// Sync page-feed rails from EngineCache (warm hub reopen / filter flip).
  Map<String, List<dynamic>>? _peekPageFeedRails() {
    return _railsMapFromEnvelope(
      MetaRuntime.instance.peekCached(
        pluginId: widget.pluginId,
        action: 'feed',
        params: _pageFeedParams(),
        packSourceUrl: widget.packSourceUrl,
      ),
    );
  }

  /// Page feed future — failures stay failed for PackLoadedPaint; sink avoids
  /// zone “unhandled” when no rail has subscribed yet.
  Future<Map<String, List<dynamic>>> _bindPageFeed({
    required bool forceRefresh,
  }) {
    final f = _fetchPageFeed(forceRefresh: forceRefresh);
    f.catchError((Object _) => const <String, List<dynamic>>{});
    return f;
  }

  Future<Map<String, List<dynamic>>> _fetchPageFeed({
    required bool forceRefresh,
  }) async {
    if (!forceRefresh) {
      final peeked = _peekPageFeedRails();
      if (peeked != null) {
        if (mounted) {
          _pageFeedRails = peeked;
          _pageFeedError = null;
        }
        return peeked;
      }
    }
    final envelope = await packOpaqueRun(
      pluginId: widget.pluginId,
      packSourceUrl: widget.packSourceUrl,
      action: 'feed',
      params: _pageFeedParams(),
      forceRefresh: forceRefresh,
    );
    if (!envelope.ok) {
      debugPrint(
        '[catalog] ${widget.pluginId} feed fail '
        '${envelope.error?.code.wire} ${envelope.error?.message}',
      );
      _pageFeedRails = null;
      _pageFeedError = envelope.error;
      if (mounted) setState(() {});
      // Failed future — PackLoadedPaint must not treat empty rails as ok.
      throw envelope;
    }
    final out =
        _railsMapFromEnvelope(envelope) ?? const <String, List<dynamic>>{};
    if (mounted) {
      setState(() {
        _pageFeedRails = out;
        _pageFeedError = null;
      });
    }
    return out;
  }

  void _onLayoutSelect(String widgetId, String value, {required bool toggle}) {
    setState(() {
      final prev = _layoutSelections[widgetId];
      if (toggle && prev == value) {
        _layoutSelections.remove(widgetId);
      } else {
        _layoutSelections[widgetId] = value;
      }
      if (widgetId == 'view') {
        final v = value.trim().toLowerCase();
        if (v == 'list' ||
            v == 'cards' ||
            v == 'guide' ||
            v == 'epg') {
          _viewStyle = v;
        }
      }
      // Live/Movies/Series shelf — Favorites / live cat ids must not stick onto
      // VOD and empty the grid (looks like the shelf click did nothing).
      if (widgetId == 'catalog' && prev != value) {
        _resetCategorySelectionAfterCatalogChange();
      }
    });
  }

  void _resetCategorySelectionAfterCatalogChange() {
    walkLayoutWidgets(_widgets, (spec) {
      final type = LayoutTypes.normalize((spec['type'] ?? '').toString(), spec);
      if (type == LayoutTypes.categoryBar) {
        final id = (spec['id'] ?? '').toString().trim();
        if (id.isEmpty) return;
        final def = (spec['default'] ?? 'all').toString().trim();
        _layoutSelections[id] = def.isEmpty ? 'all' : def;
        // Drop Live Favorites/cats immediately — empty → pack seed (All) until
        // the Movies/Series feed republishes kinds.
        _dynamicBarItems[id] = const [];
        return;
      }
      if (type == LayoutTypes.list) {
        final kindMenu = (spec['kindMenu'] ?? '').toString().trim();
        if (kindMenu.isEmpty) return;
        _layoutSelections[kindMenu] = 'all';
      }
    });
  }

  Widget _wrapLayoutScope(Widget child) {
    return PackChromeScope(
      eventQuery: _eventQuery,
      refreshEpoch: _refreshEpoch,
      refreshForceNetwork: _refreshForceNetwork,
      refreshKeepPainted: _refreshKeepPainted,
      catalogHoldEpoch: _catalogHoldEpoch,
      viewStyle: _viewStyle,
      dynamicBarItems: Map<String, List<Map<String, dynamic>>>.unmodifiable(
        Map<String, List<Map<String, dynamic>>>.from(_dynamicBarItems),
      ),
      selectedListItem: _selectedListItem,
      searchHitKindIds: _searchHitKinds,
      shellTabVisible: shellTabVisible,
      eagerLoadKeys: _eagerLoadKeys,
      pageFeedRailIds: _pageFeedRailIds,
      pageFeedFuture: _pageFeedFuture,
      pageFeedRails: _pageFeedRails,
      pageFeedError: _pageFeedError,
      rowPrefetch: _rowPrefetch,
      onEventQuery: (q) {
        if (_eventQuery == q) return;
        final prev = _eventQuery.trim();
        final next = q.trim();
        setState(() {
          _eventQuery = q;
          // Legacy IPTV: typing Search clears category → global hits; clear
          // restores the prior category unless the user picked one mid-search.
          if (prev.isEmpty && next.isNotEmpty) {
            _categoryBeforeSearch = _layoutSelections['cats'];
            _layoutSelections.remove('cats');
            _searchHitKinds.value = const {};
          } else if (prev.isNotEmpty && next.isEmpty) {
            final current = (_layoutSelections['cats'] ?? '').trim();
            if (current.isEmpty) {
              final restore = (_categoryBeforeSearch ?? '').trim();
              if (restore.isNotEmpty) {
                _layoutSelections['cats'] = restore;
              }
            }
            _categoryBeforeSearch = null;
            _searchHitKinds.value = const {};
          }
        });
      },
      onClearCatalog: () {
        _selectedListItem.value = null;
        setState(() {
          _catalogHoldEpoch++;
          _dynamicBarItems.clear();
        });
      },
      onBumpRefresh: ({bool forceNetwork = true}) {
        _selectedListItem.value = null;
        PortalChannelGuideOpen.invalidateLiveCatalog();
        setState(() {
          _refreshEpoch++;
          _refreshForceNetwork = forceNetwork;
          _refreshKeepPainted = false;
          if (!forceNetwork) {
            // Portal switch — drop stale Live kinds until the new feed publishes.
            _dynamicBarItems.clear();
          }
          if (_pageFeedRailIds.isNotEmpty) {
            if (forceNetwork) {
              _pageFeedRails = null;
              _pageFeedError = null;
              _pageFeedFuture = _bindPageFeed(forceRefresh: true);
            } else {
              _pageFeedError = null;
              _pageFeedRails = _peekPageFeedRails();
              _pageFeedFuture = _pageFeedRails != null
                  ? Future<Map<String, List<dynamic>>>.value(_pageFeedRails!)
                  : _bindPageFeed(forceRefresh: false);
            }
          }
        });
        // Soft portal switch keeps page layout; rails rebind via refreshEpoch.
        if (forceNetwork) {
          unawaited(onShellTabRefresh(force: true));
        }
      },
      onViewStyle: _applyViewStyle,
      onDynamicBarItems: (barId, items) {
        final prev = _dynamicBarItems[barId];
        if (prev != null &&
            prev.length == items.length &&
            listEquals(
              [for (final e in prev) e['id']],
              [for (final e in items) e['id']],
            )) {
          return;
        }
        setState(() => _dynamicBarItems[barId] = items);
      },
      onSelectListItem: (item) {
        _selectedListItem.value = item;
      },
      child: LayoutScope(
        selections: Map<String, String>.unmodifiable(
          Map<String, String>.from(_layoutSelections),
        ),
        widgetSpecs: layoutWidgetSpecIndex(_widgets),
        tabId: _pageKey,
        onSelect: _onLayoutSelect,
        focusEdge: (rowId, {last = false, lastItem = false}) =>
            kitFocusEdge(_pageKey, rowId, last: last, lastItem: lastItem),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _widgets.isEmpty) {
      return _hubPageLoadingSkeleton(context, tabId: _pageKey);
    }
    if (_error != null && _widgets.isEmpty) {
      return ColoredBox(
        color: ForjaShellColors.bgDark,
        child: ShellErrorRetryPanel(
          message: _error!,
          onRetry: () => unawaited(onShellTabRefresh(force: true)),
        ),
      );
    }

    final listenable = catalogChromeFilterListenable(_pageKey);
    Widget result = listenable == null
        ? _wrapLayoutScope(_pageBody())
        : ListenableBuilder(
            listenable: listenable,
            builder: (_, _) => _wrapLayoutScope(_pageBody()),
          );
    if (_layoutRtl) {
      result = Directionality(
        textDirection: TextDirection.rtl,
        child: result,
      );
    }
    final tab = widget.tabId?.trim() ?? '';
    if (tab.isNotEmpty) {
      _bindHubTvDefaults(tab);
      if (VerticalFiltersRegistry.hasFilters(tab)) {
        result = Stack(
          clipBehavior: Clip.none,
          children: [
            result,
            Positioned(
              key: ValueKey('kit-vf-rail-$tab'),
              left: catalogProviderRailInset(context),
              top: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: VerticalFiltersRail(tabId: tab)),
              ),
            ),
          ],
        );
      }
      result = TvFocusGraph(tabId: tab, child: result);
    }
    return result;
  }

  /// Expand stack / kit.list roots need a bounded Column — not SliverToBoxAdapter.
  Widget _pageBody() {
    final fullPage = _fullPageBody();
    if (fullPage != null) return fullPage;
    final sections = _composeSections();
    // Build ~2 viewports below the fold so Mood / Because register for D-pad
    // before ↓ reaches Popular's last on-screen neighbor.
    final cacheExtent = MediaQuery.sizeOf(context).height * 2;
    return CatalogBody(
      controller: _scroll,
      bottomGap: ShellTokens.homeRowSpacing,
      cacheExtent: cacheExtent,
      sections: sections,
      sectionSliver: (context, section, index) {
        final gap = index == 0
            ? 0.0
            : ShellTokens.homeRowSpacing;
        return SliverToBoxAdapter(
          child: gap <= 0
              ? section
              : Padding(
                  padding: EdgeInsets.only(top: gap),
                  child: section,
                ),
        );
      },
    );
  }

  Widget? _fullPageBody() {
    if (_widgets.length != 1) return null;
    final root = _widgets.first;
    if (!LayoutTypes.isCompositionRoot(root)) return null;
    // Bound the expand stack — without this, kit.list SizedBox.expand is 0×0
    // and pointer hit tests spam "render box with no size".
    return SizedBox.expand(
      child: PackPaintTree(
        spec: root,
        pluginId: widget.pluginId,
        packSourceUrl: widget.packSourceUrl,
        tabId: _pageKey,
      ),
    );
  }

  bool _chromeHidesTypeFilterRail() =>
      catalogChromeHidesTypeFilterRails(_pageKey);

  /// Hero bleed rail (VF registered via [VerticalFiltersRegistry.syncFromLayout]).
  List<Widget> _composeSections() {
    // Only reshuffle prefetch claim order when the section tree actually changes.
    final structureSig = [
      for (final w in _widgets)
        '${w['id']}|${w['rail']}|${w['type']}|${w['hideWhenTypeFilter']}',
    ].join('>');
    if (structureSig != _sectionStructureSig) {
      _sectionStructureSig = structureSig;
      _rowPrefetch.reset();
    }
    Map<String, dynamic>? heroSpec;
    String? bleedKey;
    for (final w in _widgets) {
      final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
      if (type != LayoutTypes.hero) continue;
      heroSpec = w;
      final bleed = (w['bleed'] ?? '').toString().trim();
      if (bleed.isNotEmpty) bleedKey = bleed;
      break;
    }

    Map<String, dynamic>? bleedSpec;
    if (bleedKey != null) {
      // Prefer real rails — mood nodes also carry `rail:` for their load
      // params and must not steal the hero bleed (anime double vibe).
      for (final preferRail in [true, false]) {
        for (final w in _widgets) {
          final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
          if (preferRail) {
            final isRail = type == LayoutTypes.row ||
                type == 'rail' ||
                type == 'ranked' ||
                type == LayoutTypes.list;
            if (!isRail) continue;
          } else if (type == LayoutTypes.mood ||
              type == LayoutTypes.continueWatching ||
              type == LayoutTypes.because ||
              type == LayoutTypes.hero ||
              type == LayoutTypes.verticalFilters) {
            continue;
          }
          final id = (w['id'] ?? '').toString().trim();
          final rail = (w['rail'] ?? '').toString().trim();
          if (id != bleedKey && rail != bleedKey) continue;
          if (w['hideWhenTypeFilter'] == true &&
              _chromeHidesTypeFilterRail()) {
            break;
          }
          bleedSpec = w;
          break;
        }
        if (bleedSpec != null) break;
      }
    }

    final out = <Widget>[];
    for (final w in _widgets) {
      final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
      if (type == LayoutTypes.verticalFilters) continue;
      if (identical(w, bleedSpec) &&
          bleedSpec != null &&
          bleedSpec['hideWhenBleed'] == true) {
        continue;
      }
      if (w['hideWhenTypeFilter'] == true && _chromeHidesTypeFilterRail()) {
        continue;
      }
      if (type == LayoutTypes.hero &&
          identical(w, heroSpec) &&
          bleedSpec != null) {
        // Featured (etc.) rides inside the hero as pageBottomChild — tall
        // backdrop + soft fade, not a sibling section below a short hero.
        out.add(
          KeyedSubtree(
            key: ValueKey('hub-section-${widget.pluginId}-${w['id'] ?? w['rail'] ?? type}'),
            child: PackPaintTree(
              spec: w,
              pluginId: widget.pluginId,
              packSourceUrl: widget.packSourceUrl,
              tabId: _pageKey,
              pageBottomChild: PackPaintTree(
                spec: Map<String, dynamic>.from(bleedSpec),
                pluginId: widget.pluginId,
                packSourceUrl: widget.packSourceUrl,
                tabId: _pageKey,
              ),
            ),
          ),
        );
        continue;
      }
      out.add(
        KeyedSubtree(
          key: ValueKey('hub-section-${widget.pluginId}-${w['id'] ?? w['rail'] ?? type}'),
          child: PackPaintTree(
            spec: w,
            pluginId: widget.pluginId,
            packSourceUrl: widget.packSourceUrl,
            tabId: _pageKey,
          ),
        ),
      );
    }
    return out;
  }
}

/// Resolves [tabId] → hub pluginId then mounts [PackLayoutPainter].
class PackLayoutPainterLoader extends StatefulWidget {
  const PackLayoutPainterLoader({super.key, required this.tabId});

  final String tabId;

  @override
  State<PackLayoutPainterLoader> createState() =>
      _PackLayoutPainterLoaderState();
}

class _PackLayoutPainterLoaderState extends State<PackLayoutPainterLoader> {
  String? _pluginId;
  String? _packSourceUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Sync registry hit — first frame mounts the painter (no skeleton flash).
    final syncId =
        PluginNavRegistry.pluginIdForTabSync(widget.tabId)?.trim() ?? '';
    if (syncId.isNotEmpty) {
      _pluginId = syncId;
      _packSourceUrl =
          PluginNavRegistry.packSourceUrlForTabSync(widget.tabId);
      _loading = false;
      return;
    }
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(covariant PackLayoutPainterLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId != widget.tabId) unawaited(_resolve());
  }

  Future<void> _resolve() async {
    final pluginId = await PluginNavRegistry.pluginIdForTab(widget.tabId);
    final url = await PluginNavRegistry.packSourceUrlForTab(widget.tabId);
    if (!mounted) return;
    setState(() {
      _pluginId = pluginId;
      _packSourceUrl = url;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _hubPageLoadingSkeleton(context, tabId: widget.tabId);
    }
    final id = _pluginId?.trim() ?? '';
    if (id.isEmpty) {
      return const Center(child: Text('No hub pack for this tab.'));
    }
    final action =
        PluginNavRegistry.pageActionForTab(widget.tabId)?.trim() ?? '';
    final params = PluginNavRegistry.pageParamsForTab(widget.tabId);
    return PackLayoutPainter(
      pluginId: id,
      tabId: widget.tabId,
      packSourceUrl: _packSourceUrl,
      pageAction: action.isEmpty ? null : action,
      pageParams: params,
    );
  }
}

/// Neutral full-page wait — pack layout owns structure; do not invent rails.
Widget _hubPageLoadingSkeleton(BuildContext context, {String? tabId}) {
  return hubNeutralLoadingSkeleton(context, tabId: tabId);
}

/// Backward-compatible aliases while call sites migrate.
typedef PackLayoutHost = PackLayoutPainter;
typedef PackLayoutHostLoader = PackLayoutPainterLoader;
