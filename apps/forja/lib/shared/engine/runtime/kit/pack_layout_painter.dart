import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/engine/cache/engine_cache.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/portals/guide/portal_channel_guide_open.dart';
import 'package:forja/shared/engine/runtime/kit/focus_edge.dart';
import 'package:forja/shared/engine/runtime/kit/hub_menu_clearance.dart';
import 'package:forja/shared/engine/runtime/kit/hub_page_focus.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_feed.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/engine/runtime/kit/paint_tree.dart';
import 'package:forja/shared/engine/runtime/kit/row_prefetch.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/engine/runtime/vm/service.dart';
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
import 'package:forja/shell/core/forja_shell_scope.dart';
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
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
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
  /// Bumped on chrome filter flip / forced page-feed reload — drop late
  /// progressive publishes from a superseded All/Films/TV fetch.
  int _pageFeedGen = 0;
  String _sectionStructureSig = '';
  Listenable? _filterListenable;
  final KitRowPrefetchLane _rowPrefetch = KitRowPrefetchLane();
  HubPageFocus _pageFocus = HubPageFocus.empty;
  String? _tvBoundKey;
  bool _listStyleHydrateStarted = false;
  /// Pack install wiped this hub's cache. Soft-reload when the user opens
  /// the hub — never scrape on the wipe itself.
  bool _pendingHubFeedSoftReload = false;
  bool _openReloadRunning = false;
  /// Bumped when a pack reload flags this hub, so an in-flight layout
  /// waiting on install idle cannot continue and mark the tab fresh.
  int _layoutGen = 0;

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
    // Reset chrome scroll fade after mount — never from dispose (finalizeTree
    // locks the tree; notifying KitChromeTopBar asserts and can blank the hub).
    final tab = widget.tabId?.trim();
    if (tab != null && tab.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final offset = ShellBus.hubScrollOffsetFor(tab);
        if (offset.value != 0) offset.value = 0;
      });
    }
    // Sync shell from EngineCache when boot prefetch / prior visit warmed layout.
    final warmed = _tryApplyCachedLayout();
    if (PluginRegistry.hubNeedsReloadOnOpen(widget.pluginId)) {
      _pendingHubFeedSoftReload = true;
      _refreshForceNetwork = true;
      unawaited(_reloadFlaggedHubOnOpen());
    } else {
      unawaited(_loadPage(keepPainted: warmed));
    }
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
      // Do not set ShellBus.hubScrollOffsetFor here — ValueListenableBuilder in
      // the top bar is still mounted; notify during finalizeTree asserts
      // ("widget tree was locked") and aborts hub remount paint.
      // Drop tab TV defaults — hero may have merged defaultFocus into the same id.
      TvHeroActions.unbind(tab);
      ShellTvFocusCoordinator.setTabPageScroll(tab, null);
    }
    super.dispose();
  }

  void _bindHubTvDefaults(String tab) {
    if (tab.isEmpty) return;
    final key = '$tab|${_pageFocus.signature}';
    if (_tvBoundKey != key) {
      _tvBoundKey = key;
      bindHubPageFocus(tab, _pageFocus);
      ShellTvFocusCoordinator.setTabPageScroll(tab, _nudgeHubPageScroll);
    }
    // Always refresh reveal — hub hero only binds defaultFocus; a prior State
    // reveal callback must not stay registered across hero remounts.
    TvHeroActions.bind(tab, heroReveal: _revealHeroScroll);
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
    if (!mounted) return;
    // Always recompose — `showWhenType` / `hideWhenTypeFilter` need a rebuild
    // even when this hub has no page-feed rails (Stremio catalog hub).
    if (_pageFeedRailIds.isEmpty) {
      setState(() {});
      return;
    }
    // Films / TV Shows / Categories must refetch — never peek-or-promote over
    // the previously painted mixed rails (progressive promote skipped non-empty
    // envelopes and soft peek could poison the filtered feed cache).
    _pageFeedGen++;
    PackLoadedPaint.clearMemosForPlugin(widget.pluginId);
    setState(() {
      _pageFeedError = null;
      _pageFeedRails = null;
      _pageFeedFuture = _bindPageFeed(forceRefresh: true);
    });
  }

  void _deferHubUntilOpened({required bool forceNetwork}) {
    _pendingHubFeedSoftReload = true;
    if (forceNetwork) {
      _refreshForceNetwork = true;
    } else if (!PluginRegistry.hubNeedsReloadOnOpen(widget.pluginId)) {
      _refreshForceNetwork = false;
    }
    _layoutGen++;
    _pageFeedGen++;
    markShellTabStale();
  }

  bool _layoutStillCurrent(int gen) =>
      mounted &&
      gen == _layoutGen &&
      !_pendingHubFeedSoftReload &&
      shellTabVisible;

  void _onHubFeedEpoch() {
    if (!mounted) return;
    if (!PluginRegistry.hubFeedEpochTouches(widget.pluginId)) return;
    final forceNet = PluginRegistry.hubFeedEpochForceNetwork;
    // Pack install / Reload / Update (forceNetwork): flag only — never scrape
    // catalog/rails here. Soft reload runs when the user opens the hub.
    // Settings tweaks (forceNetwork: false) still soft-reload while this hub
    // is the selected tab so Addons fields rebind without leaving.
    if (forceNet || !shellTabVisible) {
      _deferHubUntilOpened(forceNetwork: forceNet);
      return;
    }
    unawaited(_applyHubFeedSoftReload(forceNetwork: forceNet));
  }

  /// Soft reload after pack script wipe (issue 305 / 311 / 380) or pack settings
  /// (issue 314 — settings keep [live_sports.feed] when [forceNetwork] is false).
  Future<void> _applyHubFeedSoftReload({bool? forceNetwork}) async {
    if (!mounted) return;
    // Belt: pack wipe must not scrape while this hub is keep-alive off-screen.
    if (!shellTabVisible) {
      _deferHubUntilOpened(forceNetwork: forceNetwork == true);
      return;
    }
    _pendingHubFeedSoftReload = false;
    _layoutGen++;
    final force = forceNetwork ?? _refreshForceNetwork;
    // Soft: keep painted rails while scripts refresh. Must bump refreshEpoch
    // so PackLoadedPaint rebinds — layout-only soft reload left Home on a
    // stale/empty page-feed slice (Popular title, no hero) after Reload packs.
    PackLoadedPaint.clearMemosForPlugin(widget.pluginId);
    setState(() {
      _refreshEpoch++;
      _refreshForceNetwork = force;
      _refreshKeepPainted = true;
      if (_pageFeedRailIds.isNotEmpty) {
        _pageFeedGen++;
        _pageFeedRails = null;
        _pageFeedError = null;
        _pageFeedFuture = _bindPageFeed(forceRefresh: force);
      }
    });
    await _loadPage(force: force, keepPainted: true);
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
        _pageFeedGen++;
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
  void onShellTabHidden() {
    super.onShellTabHidden();
    // RFC-024: keep-alive must not keep fetching. Drop late page-feed publishes
    // and abort in-flight catalog / live scrapes (Stremio rails, Live Sports,
    // Home TMDB pools) so a background hub cannot hammer the network while the
    // user is on another tab (e.g. IPTV).
    _layoutGen++;
    _pageFeedGen++;
    EngineService.instance.cancelCatalog();
    EngineService.instance.cancelLiveCatalog();
    // Push shellTabVisible:false into PackChromeScope so PackLoadedPaint /
    // LazyViewportGate stop binding. Without setState, chrome stayed true and
    // keep-alive hubs kept scraping after pack reload (AniList 429 stampede).
    if (mounted) setState(() {});
  }

  @override
  void onShellTabShown() {
    super.onShellTabShown();
    if (mounted) setState(() {});
    unawaited(_reloadFlaggedHubOnOpen());
  }

  @override
  Future<void> refreshIfStale({bool force = false}) async {
    if (_openReloadRunning) return;
    if (_pendingHubFeedSoftReload ||
        PluginRegistry.hubNeedsReloadOnOpen(widget.pluginId)) {
      await _reloadFlaggedHubOnOpen();
      return;
    }
    await super.refreshIfStale(force: force);
  }

  /// Pack reload sets the registry flag. Opening this hub consumes it.
  Future<void> _reloadFlaggedHubOnOpen() async {
    final flagged = _pendingHubFeedSoftReload ||
        PluginRegistry.hubNeedsReloadOnOpen(widget.pluginId);
    if (!flagged || _openReloadRunning) return;
    if (!shellTabVisible) {
      _pendingHubFeedSoftReload = true;
      _refreshForceNetwork = true;
      markShellTabStale();
      return;
    }
    final packReload = PluginRegistry.hubNeedsReloadOnOpen(widget.pluginId);
    final force = packReload || _refreshForceNetwork;
    _openReloadRunning = true;
    _pendingHubFeedSoftReload = true;
    _refreshForceNetwork = force;
    debugPrint(
      '[HubReload] opened ${widget.pluginId} tab=$_pageKey — reloading',
    );
    try {
      if (packReload) PluginRegistry.consumeHubReloadOnOpen(widget.pluginId);
      await _applyHubFeedSoftReload(forceNetwork: force);
    } finally {
      _openReloadRunning = false;
    }
  }

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    if (_pendingHubFeedSoftReload) {
      await _applyHubFeedSoftReload();
      return;
    }
    await _loadPage(force: force);
  }

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
        _pageFeedGen++;
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

  /// True when this hub already has layout and feed rails to paint.
  ///
  /// Restores a page-feed peek into the painter when the State was empty but
  /// [EngineCache] still holds the last visit.
  bool _restoreWarmHub() {
    if (_widgets.isEmpty) return false;
    if (_pageFeedRailIds.isEmpty) return true;
    final rails = _pageFeedRails;
    if (rails != null && rails.values.any((items) => items.isNotEmpty)) {
      return true;
    }
    final feed = _peekPageFeedRails();
    if (feed == null || !feed.values.any((items) => items.isNotEmpty)) {
      return false;
    }
    _loading = false;
    _error = null;
    _pageFeedRails = feed;
    _pageFeedError = null;
    _pageFeedFuture = Future<Map<String, List<dynamic>>>.value(feed);
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    return true;
  }

  Future<void> _loadPage({bool force = false, bool keepPainted = false}) async {
    final layoutGen = _layoutGen;
    if (_pendingHubFeedSoftReload || !shellTabVisible) return;
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

    // Keep-alive off-screen, or flagged by pack reload: do not start network.
    // Opening the hub consumes the flag and loads.
    if (!_layoutStillCurrent(layoutGen)) return;

    // Hub already on screen from cache. Coming back must not start a new
    // catalog load (same as 1.5.36 memoized rails). Re-tap / Refresh passes
    // [force] and still reloads.
    if (!force && _restoreWarmHub()) {
      markShellTabFresh();
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
    if (!_layoutStillCurrent(layoutGen)) return;

    final enabled = await PluginNavRegistry.isKitPluginEnabled(
      widget.pluginId,
      packSourceUrl: widget.packSourceUrl,
    );
    if (!_layoutStillCurrent(layoutGen)) return;
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

    if (!_layoutStillCurrent(layoutGen)) return;
    final envelope = await packOpaqueRun(
      pluginId: widget.pluginId,
      action: action,
      params: params,
      packSourceUrl: widget.packSourceUrl,
      forceRefresh: force,
    );
    if (!_layoutStillCurrent(layoutGen)) return;

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
    final gen = _pageFeedGen;
    if (_pendingHubFeedSoftReload || !shellTabVisible) {
      return const <String, List<dynamic>>{};
    }
    // Capture chrome filters at fetch start — a mid-flight Films flip must not
    // store this All batch under the Films feed cache key.
    final feedParams = _pageFeedParams();
    final chromeFilters = catalogChromeFilters(
      tabId: widget.tabId,
      pluginId: widget.pluginId,
    );

    if (!forceRefresh) {
      final peeked = _railsMapFromEnvelope(
        MetaRuntime.instance.peekCached(
          pluginId: widget.pluginId,
          action: 'feed',
          params: feedParams,
          packSourceUrl: widget.packSourceUrl,
        ),
      );
      if (peeked != null) {
        if (mounted && gen == _pageFeedGen && shellTabVisible) {
          _pageFeedRails = peeked;
          _pageFeedError = null;
        }
        return peeked;
      }
    }

    // Progressive first paint (Spotlight can land while Popular is still
    // pooling) with release-parity economics: kick a 2-page pool per rail in
    // parallel (pack `TMDB_HOME_FETCH_PAGES`), claim in layout order, then
    // backfill only when exclusive claim left a rail short (sparse genres).
    final ordered = _pageFeedRailIds.toList(growable: false);
    if (ordered.isEmpty) {
      if (mounted && gen == _pageFeedGen) {
        setState(() {
          _pageFeedRails = const {};
          _pageFeedError = null;
        });
      }
      return const {};
    }

    final pools = <String, Future<({List<dynamic> items, MetaError? error})>>{
      for (final railId in ordered)
        railId: _fetchPageFeedPool(
          railId: railId,
          fromPage: 1,
          pageCount: _kPageFeedPoolPages,
          chromeFilters: chromeFilters,
          forceRefresh: forceRefresh,
        ),
    };

    final acc = <String, List<dynamic>>{};
    final claimed = <String>{};
    MetaError? hardError;
    var anyOk = false;

    for (final railId in ordered) {
      if (gen != _pageFeedGen) {
        return const <String, List<dynamic>>{};
      }
      var items = const <dynamic>[];
      try {
        final pool = await pools[railId]!;
        final cap = _pageFeedRailCap(railId);
        items = _claimPageFeedItems(
          pool.items,
          claimed: claimed,
          cap: cap,
        );
        MetaError? railError = pool.error;
        if (items.length < cap) {
          final filled = await _backfillPageFeedRail(
            railId: railId,
            already: items,
            claimed: claimed,
            cap: cap,
            startPage: _kPageFeedPoolPages + 1,
            chromeFilters: chromeFilters,
            forceRefresh: forceRefresh,
            gen: gen,
          );
          items = filled.items;
          railError ??= filled.error;
        }
        if (items.isEmpty && railError != null) {
          hardError ??= railError;
          debugPrint(
            '[catalog] ${widget.pluginId} page-feed rail=$railId fail '
            '${railError.code.wire} ${railError.message}',
          );
        } else {
          anyOk = true;
        }
      } catch (e) {
        debugPrint(
          '[catalog] ${widget.pluginId} page-feed rail=$railId error $e',
        );
      }
      acc[railId] = items;
      if (mounted && gen == _pageFeedGen) {
        setState(() {
          _pageFeedRails = Map<String, List<dynamic>>.from(acc);
          _pageFeedError = anyOk ? null : hardError;
        });
      }
    }

    if (gen != _pageFeedGen) {
      return const <String, List<dynamic>>{};
    }

    if (!anyOk) {
      debugPrint(
        '[catalog] ${widget.pluginId} page-feed fail '
        '${hardError?.code.wire} ${hardError?.message}',
      );
      if (mounted) {
        setState(() {
          _pageFeedRails = null;
          _pageFeedError = hardError;
        });
      }
      throw MetaEnvelope(
        ok: false,
        action: 'feed',
        error: hardError,
      );
    }

    _storePageFeedCache(acc, params: feedParams);
    return acc;
  }

  /// Display caps — must match pack `TMDB_HOME_*_CAP` / layout pageSize.
  static const _kPageFeedPoolPageSize = 20;
  /// Match pack `TMDB_HOME_FETCH_PAGES` — first batch per rail, fetched in parallel.
  static const _kPageFeedPoolPages = 2;
  /// Extra pages after the pool when exclusive claim left a rail short.
  static const _kPageFeedFillMaxPages = 10;

  static int _pageFeedRailCap(String railId) {
    if (railId == 'spotlight') return 5;
    return _kPageFeedPoolPageSize;
  }

  Future<({List<dynamic> items, MetaError? error})> _runPageFeedRailPage({
    required String railId,
    required int page,
    required List<Map<String, dynamic>?> chromeFilters,
    required bool forceRefresh,
  }) async {
    try {
      final envelope = await packOpaqueRun(
        pluginId: widget.pluginId,
        packSourceUrl: widget.packSourceUrl,
        action: 'rail',
        params: catalogParamsWithFilters(
          {
            'rail': railId,
            'page': page,
            'limit': _kPageFeedPoolPageSize,
            '_poolPage': true,
          },
          filters: chromeFilters,
        ),
        forceRefresh: forceRefresh,
      );
      if (!envelope.ok) {
        return (items: const <dynamic>[], error: envelope.error);
      }
      final raw = envelope.data?['items'];
      if (raw is! List || raw.isEmpty) {
        return (items: const <dynamic>[], error: null);
      }
      return (items: List<dynamic>.from(raw), error: null);
    } catch (e) {
      debugPrint(
        '[catalog] ${widget.pluginId} page-feed rail=$railId page=$page error $e',
      );
      return (items: const <dynamic>[], error: null);
    }
  }

  /// Parallel TMDB pages in page order — same shape as pack `tmdbListPool`.
  Future<({List<dynamic> items, MetaError? error})> _fetchPageFeedPool({
    required String railId,
    required int fromPage,
    required int pageCount,
    required List<Map<String, dynamic>?> chromeFilters,
    required bool forceRefresh,
  }) async {
    if (pageCount <= 0) {
      return (items: const <dynamic>[], error: null);
    }
    final results = await Future.wait([
      for (var i = 0; i < pageCount; i++)
        _runPageFeedRailPage(
          railId: railId,
          page: fromPage + i,
          chromeFilters: chromeFilters,
          forceRefresh: forceRefresh,
        ),
    ]);
    MetaError? hardError;
    final merged = <dynamic>[];
    final seen = <String>{};
    for (final result in results) {
      hardError ??= result.error;
      for (final item in result.items) {
        final key = _pageFeedMetaKey(item);
        if (key != null) {
          if (seen.contains(key)) continue;
          seen.add(key);
        }
        merged.add(item);
      }
    }
    return (items: merged, error: hardError);
  }

  List<dynamic> _claimPageFeedItems(
    List<dynamic> pool, {
    required Set<String> claimed,
    required int cap,
  }) {
    final out = <dynamic>[];
    for (final item in pool) {
      if (out.length >= cap) break;
      final key = _pageFeedMetaKey(item);
      if (key != null) {
        if (claimed.contains(key)) continue;
        claimed.add(key);
      }
      out.add(item);
    }
    return out;
  }

  /// Sequential pages after the parallel pool until [cap] or upstream exhaustion.
  Future<({List<dynamic> items, MetaError? error})> _backfillPageFeedRail({
    required String railId,
    required List<dynamic> already,
    required Set<String> claimed,
    required int cap,
    required int startPage,
    required List<Map<String, dynamic>?> chromeFilters,
    required bool forceRefresh,
    required int gen,
  }) async {
    final out = List<dynamic>.from(already);
    MetaError? hardError;

    for (var page = startPage;
        page <= _kPageFeedFillMaxPages && out.length < cap;
        page++) {
      if (gen != _pageFeedGen) {
        return (items: out, error: hardError);
      }
      final result = await _runPageFeedRailPage(
        railId: railId,
        page: page,
        chromeFilters: chromeFilters,
        forceRefresh: forceRefresh,
      );
      if (result.items.isEmpty) {
        hardError ??= result.error;
        break;
      }
      for (final item in result.items) {
        if (out.length >= cap) break;
        final key = _pageFeedMetaKey(item);
        if (key != null) {
          if (claimed.contains(key)) continue;
          claimed.add(key);
        }
        out.add(item);
      }
      if (result.items.length < _kPageFeedPoolPageSize) break;
    }

    return (items: out, error: hardError);
  }

  /// Warm action:`feed` peek cache so the next open can sync-paint all rails.
  void _storePageFeedCache(
    Map<String, List<dynamic>> rails, {
    required Map<String, dynamic> params,
  }) {
    final key = EngineCache.keyFor(
      pluginId: widget.pluginId,
      action: 'feed',
      params: params,
      packSourceUrl: widget.packSourceUrl,
    );
    EngineCache.instance.putEntry(
      key: key,
      pluginId: widget.pluginId,
      data: {'rails': rails},
      hints: const CatalogCacheHints(
        maxAge: Duration(seconds: 900),
        swr: Duration(seconds: 3600),
      ),
    );
  }

  static String? _pageFeedMetaKey(dynamic item) {
    if (item is! Map) return null;
    Map? ids = item['ids'] is Map ? item['ids'] as Map : null;
    if (ids == null && item['meta'] is Map) {
      final metaIds = (item['meta'] as Map)['ids'];
      if (metaIds is Map) ids = metaIds;
    }
    if (ids == null) return null;
    final tmdb = ids['tmdb'];
    if (tmdb == null || tmdb.toString().trim().isEmpty) return null;
    final type = (item['type'] ??
            (item['meta'] is Map ? (item['meta'] as Map)['type'] : null) ??
            '')
        .toString();
    return '$type:$tmdb';
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

  Widget _wrapLayoutScope(BuildContext context, Widget child) {
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
        // Keep the docked resolve panel open across Reload / soft bumps.
        // Portal wipe still clears via [onClearCatalog].
        final keepSidePanel = _selectedListItem.value != null;
        PortalChannelGuideOpen.invalidateLiveCatalog();
        setState(() {
          _refreshEpoch++;
          _refreshForceNetwork = forceNetwork;
          _refreshKeepPainted = keepSidePanel;
          if (!forceNetwork) {
            // Portal switch — drop stale Live kinds until the new feed publishes.
            _dynamicBarItems.clear();
          }
          if (_pageFeedRailIds.isNotEmpty) {
            if (forceNetwork) {
              _pageFeedGen++;
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
        focusEdge: (rowId, {last = false, lastItem = false, down = false}) {
          final shelf = _focusShelfChip(context, rowId);
          if (shelf != null) return shelf;
          return kitFocusEdge(
            _pageKey,
            rowId,
            last: last,
            lastItem: lastItem,
            down: down,
          );
        },
        child: child,
      ),
    );
  }

  /// Pack `focusUp: 'catalog'` → selected Live / Movies / Series chrome chip.
  VoidCallback? _focusShelfChip(BuildContext context, String? rowId) {
    final actionId = (rowId ?? '').trim();
    if (actionId.isEmpty) return null;
    final action = _topBarAction(actionId);
    if (action == null || !_actionIsShelf(action)) return null;
    final items = layoutItemsFromSpec(action);
    if (items.isEmpty) return null;
    final sel = (_layoutSelections[actionId] ??
            (action['default'] ?? items.first.id).toString())
        .trim();
    var itemIdx = 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i].id == sel) {
        itemIdx = i;
        break;
      }
    }
    final base = _chromeShelfBaseIndex(context, actionId);
    return kitFocusChromeAt(_pageKey, base + itemIdx);
  }

  Map<String, dynamic>? _topBarAction(String actionId) {
    Map<String, dynamic>? found;
    walkLayoutWidgets(_widgets, (spec) {
      final actions = spec['actions'];
      if (actions is! List) return;
      for (final raw in actions) {
        if (raw is! Map) continue;
        final id = (raw['id'] ?? '').toString().trim();
        if (id == actionId) {
          found = Map<String, dynamic>.from(raw);
        }
      }
    });
    return found;
  }

  bool _actionIsShelf(Map<String, dynamic> action) {
    final style =
        (action['style'] ?? action['paint'] ?? '').toString().trim().toLowerCase();
    final nested = layoutItemsFromSpec(action);
    return nested.isNotEmpty &&
        (style == 'shelf' ||
            style == 'segment' ||
            action['expandOnHover'] == true);
  }

  int _chromeShelfBaseIndex(BuildContext context, String actionId) {
    final actions = <Map<String, dynamic>>[];
    walkLayoutWidgets(_widgets, (spec) {
      final raw = spec['actions'];
      if (raw is! List) return;
      for (final a in raw) {
        if (a is Map) actions.add(Map<String, dynamic>.from(a));
      }
    });
    var index = 0;
    final compact = ShellTokens.usesCompactNavDrawer(context);
    final tv = ShellPaintScope.usesTvDensityOf(context);
    for (final a in actions) {
      final id = (a['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      if (a['hideWhenCompact'] == true && compact) continue;
      if (a['hideWhenTv'] == true && tv) continue;
      if (a['compactOnly'] == true && !compact) continue;
      final when = a['showWhen'];
      if (when is Map) {
        var gated = false;
        for (final e in when.entries) {
          final menuId = e.key.toString().trim();
          if (menuId.isEmpty) continue;
          final selected = (_layoutSelections[menuId] ?? '').trim();
          final want = e.value;
          if (want is List) {
            final ids = <String>{
              for (final raw in want) raw.toString().trim(),
            }..removeWhere((s) => s.isEmpty);
            if (ids.isNotEmpty && !ids.contains(selected)) {
              gated = true;
              break;
            }
          } else {
            final wantId = want.toString().trim();
            if (wantId.isNotEmpty && selected != wantId) {
              gated = true;
              break;
            }
          }
        }
        if (gated) continue;
      }
      if (id == actionId) return index;
      index += _chromeShelfSlotSpan(a);
    }
    return 0;
  }

  int _chromeShelfSlotSpan(Map<String, dynamic> action) {
    final id = (action['id'] ?? '').toString().trim().toLowerCase();
    final verb =
        (action['action'] ?? action['id'] ?? '').toString().trim().toLowerCase();
    final style =
        (action['style'] ?? action['paint'] ?? '').toString().trim().toLowerCase();
    final nested = layoutItemsFromSpec(action);
    final isView = id == 'view' || verb == 'view';
    final isViewGroup = isView &&
        nested.isNotEmpty &&
        (style == 'group' ||
            style == 'toggle' ||
            style == 'buttons' ||
            style.isEmpty);
    final isShelf = nested.isNotEmpty &&
        (style == 'shelf' ||
            style == 'segment' ||
            action['expandOnHover'] == true);
    return (isViewGroup || isShelf) ? nested.length : 1;
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
        ? _wrapLayoutScope(context, _pageBody())
        : ListenableBuilder(
            listenable: listenable,
            builder: (_, _) => _wrapLayoutScope(context, _pageBody()),
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
    final leadingInset = _leadingSectionTopInset(context);
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
            ? leadingInset
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

  static bool _chromeTypeMatches(String want, String active) {
    if (want == active) return true;
    if ((want == 'tv' || want == 'series') &&
        (active == 'tv' || active == 'series')) {
      return true;
    }
    return false;
  }

  /// Layout type visibility (`showWhenType` / `showOnlyWhenType`).
  ///
  /// - `showWhenType`: hide when a type menu is selected and does not match
  ///   (`series` ≡ `tv`). When no type menu is selected, still show.
  /// - `showOnlyWhenType`: show only when that type menu is selected (hide
  ///   when All / no menu) — used for per-type heroes.
  bool _chromeShowsWidget(Map<String, dynamic> w) {
    final active = catalogChromeTypeFilterValue(
      tabId: _pageKey,
      pluginId: widget.pluginId,
    )?.toLowerCase();
    final only =
        (w['showOnlyWhenType'] ?? '').toString().trim().toLowerCase();
    if (only.isNotEmpty) {
      if (active == null || active.isEmpty) return false;
      return _chromeTypeMatches(only, active);
    }
    final want = (w['showWhenType'] ?? '').toString().trim().toLowerCase();
    if (want.isEmpty) return true;
    if (active == null || active.isEmpty) return true;
    return _chromeTypeMatches(want, active);
  }

  /// Hero bleed rail (VF registered via [VerticalFiltersRegistry.syncFromLayout]).
  List<Widget> _composeSections() {
    // Only reshuffle prefetch claim order when the section tree actually changes.
    final structureSig = [
      for (final w in _widgets)
        '${w['id']}|${w['rail']}|${w['type']}|${w['hideWhenTypeFilter']}|${w['showWhenType']}|${w['showOnlyWhenType']}',
    ].join('>');
    if (structureSig != _sectionStructureSig) {
      _sectionStructureSig = structureSig;
      _rowPrefetch.reset();
    }
    final resolved = _heroAndBleed();
    final heroSpec = resolved.hero;
    final bleedSpec = resolved.bleed;

    final out = <Widget>[];
    for (final w in _widgets) {
      if (!_includeInPage(w, bleedSpec)) continue;
      final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
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

  /// Overlay menu height for the first painted section.
  ///
  /// A leading hero stays at 0 — its backdrop runs under the menu and its
  /// text column already clears [catalogHomeTopBarHeight].
  double _leadingSectionTopInset(BuildContext context) {
    final scope = ShellScope.maybeOf(context);
    final shellMenu = scope?.config.showKitTopBar ?? false;
    final packs = PluginRegistry.instance.peekPacks();
    final plugin = packs == null
        ? null
        : PluginRegistry.pluginFromPacks(packs, widget.pluginId);
    final menuVisible = shellMenu &&
        hubShellTopBarVisible(
          plugin,
          hasVerticalFilters:
              VerticalFiltersRegistry.specFor(_pageKey) != null,
        );
    final leading = _firstPaintedSpec();
    final leadingHero = leading != null &&
        LayoutTypes.normalize((leading['type'] ?? '').toString(), leading) ==
            LayoutTypes.hero;
    final menuHeight = menuVisible
        ? MediaQuery.paddingOf(context).top + catalogHomeTopBarHeight(context)
        : 0.0;
    return hubFirstSectionTopInset(
      menuVisible: menuVisible,
      leadingIsHero: leadingHero,
      menuHeight: menuHeight,
    );
  }

  Map<String, dynamic>? _firstPaintedSpec() {
    final bleedSpec = _heroAndBleed().bleed;
    for (final w in _widgets) {
      if (_includeInPage(w, bleedSpec)) return w;
    }
    return null;
  }

  ({Map<String, dynamic>? hero, Map<String, dynamic>? bleed}) _heroAndBleed() {
    Map<String, dynamic>? heroSpec;
    String? bleedKey;
    for (final w in _widgets) {
      final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
      if (type != LayoutTypes.hero) continue;
      if (!_chromeShowsWidget(w)) continue;
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
          if (!_chromeShowsWidget(w)) continue;
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
    return (hero: heroSpec, bleed: bleedSpec);
  }

  bool _includeInPage(
    Map<String, dynamic> w,
    Map<String, dynamic>? bleedSpec,
  ) {
    final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
    if (type == LayoutTypes.verticalFilters) return false;
    if (!_chromeShowsWidget(w)) return false;
    if (identical(w, bleedSpec) &&
        bleedSpec != null &&
        bleedSpec['hideWhenBleed'] == true) {
      return false;
    }
    if (w['hideWhenTypeFilter'] == true && _chromeHidesTypeFilterRail()) {
      return false;
    }
    return true;
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
