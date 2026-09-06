import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/hero/cinematic_hero.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/service.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/shell_mood_circle.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_tab_refresh.dart';

import '../kit/cards/hub_poster_card.dart';
import '../kit/chrome/catalog_pack_filters.dart';
import '../kit/chrome/catalog_vertical_filters.dart';
import '../kit/layout/catalog_kit_list_widget.dart';
import '../kit/layout/catalog_kit_menu_widget.dart';
import '../kit/layout/catalog_stack_widget.dart';
import '../kit/layout/catalog_kit_tabs_widget.dart';
import '../kit/layout/catalog_kit_top_menu_registry.dart';
import '../kit/layout/catalog_kit_types.dart';
import '../kit/layout/catalog_layout_scope.dart';
import '../kit/widgets/catalog_because_section.dart';
import '../kit/widgets/catalog_continue_widget.dart';
import '../kit/details/hub_details_meta.dart';
import '../kit/meta/catalog_meta_movie.dart';
import '../kit/rows/catalog_row_prefetch.dart';
import '../kit/rows/hub_catalog_section.dart';
import '../filter.dart';
import '../plugin_nav.dart';
import '../protocol.dart';
import '../runtime.dart';
import '../kit/chrome/catalog_chrome_filters.dart';
import 'package:forja/features/live_matches/live_schedule/live_sports_kit_page.dart';
import 'catalog_open.dart';

/// Renders a shell tab from a `kind: catalog` plugin layout.
///
/// One `layout` call describes the page; each rail fetches when it enters the
/// viewport and paginates horizontally as the user scrolls the row.
class CatalogShell extends StatefulWidget {
  const CatalogShell({super.key, required this.pluginId, this.tabId});

  final String pluginId;

  /// Shell nav id — used for the layout page key (defaults to `home`).
  final String? tabId;

  @override
  State<CatalogShell> createState() => _CatalogShellState();
}

class _CatalogShellState extends State<CatalogShell>
    with AutomaticKeepAliveClientMixin, ShellTabRefresh<CatalogShell> {
  final ScrollController _scroll = ScrollController();

  List<Map<String, dynamic>> _widgets = const [];
  String? _error;
  bool _loading = true;

  /// Hero bleed rail loaded — `null` loading, `true` has items, `false` empty.
  bool? _bleedPopulated;

  /// Selected mood per mood-widget id.
  final Map<String, String> _moods = {};

  /// Stable rail futures — rebuild must not create a new Future (shimmer flash).
  final Map<String, Future<CatalogRailPage<CatalogMetaItem>>> _metaRailFutures =
      {};

  /// Pack `layout` page default and manifest `config` rail page sizes.
  int? _layoutPageSize;
  int? _pluginConfigPageSize;

  /// Pack `feed` action — one JS call claims across layout [feedRails].
  bool _pageUsesFeed = false;
  Set<String> _layoutFeedRailIds = {};
  Map<String, List<CatalogMetaItem>> _feedRails = {};
  String _feedCacheKey = '';
  Future<Map<String, List<CatalogMetaItem>>>? _feedLoadFuture;

  /// Rails served by the pack `feed` action (exclusive claim pools).
  static const Set<String> _packFeedRailIds = {
    'spotlight',
    'featured',
    'popular',
    'new_releases',
  };

  /// Next [_railFuture] miss goes through `forceRefresh`.
  bool _forceNextRails = false;

  /// Bumped on shell tab refresh for host-owned widgets (My List).
  int _hostRefreshEpoch = 0;

  final Map<String, String> _layoutSelections = {};
  Map<String, Map<String, dynamic>> _layoutWidgetSpecs = {};

  /// Last [catalogChromeFilterEpoch] — ignore structural revision bumps.
  String _chromeFilterEpoch = '';

  final CatalogHubRowPrefetchLane _rowPrefetchLane =
      CatalogHubRowPrefetchLane();

  Listenable? _chromeListenable;
  VoidCallback? _verticalFiltersRevisionListener;

  @override
  bool get wantKeepAlive => true;

  String get _pageKey {
    final id = widget.tabId?.trim();
    return (id == null || id.isEmpty) ? 'home' : id;
  }

  @override
  void initState() {
    super.initState();
    _chromeFilterEpoch = catalogChromeFilterEpoch(widget.tabId);
    _scroll.addListener(_publishScroll);
    _rebindChromeListenable();
    _verticalFiltersRevisionListener = () {
      if (!mounted) return;
      _rebindChromeListenable();
      _onChromeFilterChanged();
    };
    CatalogVerticalFiltersRegistry.revision.addListener(
      _verticalFiltersRevisionListener!,
    );
    CatalogKitTopMenuRegistry.revision.addListener(_onKitTopMenuRevision);
    EngineService.changeNotifier.addListener(_onEnginePackChanged);
    unawaited(_loadLayout());
  }

  void _rebindChromeListenable() {
    _chromeListenable?.removeListener(_onChromeFilterChanged);
    _chromeListenable = catalogChromeFilterListenable(widget.tabId);
    _chromeFilterEpoch = catalogChromeFilterEpoch(widget.tabId);
    _chromeListenable?.addListener(_onChromeFilterChanged);
  }

  void _onKitTopMenuRevision() {
    if (!mounted) return;
    setState(() {});
  }

  /// Pack install / refresh / enable — keep-alive shell must drop memoized rails.
  void _onEnginePackChanged() {
    if (!mounted) return;
    CatalogPackFiltersRegistry.invalidate(widget.pluginId);
    markShellTabStale();
    _forceNextRails = true;
    _invalidateRailFutures();
    if (shellTabVisible) {
      unawaited(refreshIfStale(force: true));
    }
  }

  @override
  void dispose() {
    EngineService.changeNotifier.removeListener(_onEnginePackChanged);
    CatalogKitTopMenuRegistry.revision.removeListener(_onKitTopMenuRevision);
    if (_verticalFiltersRevisionListener != null) {
      CatalogVerticalFiltersRegistry.revision.removeListener(
        _verticalFiltersRevisionListener!,
      );
    }
    _chromeListenable?.removeListener(_onChromeFilterChanged);
    CatalogVerticalFiltersRegistry.unregister(_pageKey);
    CatalogKitTopMenuRegistry.unregister(_pageKey);
    _scroll.removeListener(_publishScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onChromeFilterChanged() {
    if (!mounted) return;
    final epoch = catalogChromeFilterEpoch(widget.tabId);
    if (epoch == _chromeFilterEpoch) return;
    _chromeFilterEpoch = epoch;
    _invalidateRailFutures();
    setState(() {});
  }

  void _invalidateRailFutures() {
    _metaRailFutures.clear();
    _feedRails = {};
    _feedCacheKey = '';
    _feedLoadFuture = null;
    _bleedPopulated = null;
    _rowPrefetchLane.reset();
  }

  CatalogHubRowPrefetchSlot _prefetchSlot(int index) =>
      CatalogHubRowPrefetchSlot(lane: _rowPrefetchLane, index: index);

  void _publishScroll() {
    ShellBus.hubScrollOffsetFor(_pageKey).value = _scroll.hasClients
        ? _scroll.offset
        : 0;
  }

  Future<void> _loadLayout({bool forceRefresh = false}) async {
    final soft = _widgets.isNotEmpty && !forceRefresh;
    if (!soft) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    final enabled = await PluginNavRegistry.isHubPluginEnabled(widget.pluginId);
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

    final envelope = await CatalogRuntime.instance.run(
      pluginId: widget.pluginId,
      action: 'layout',
      params: {'page': _pageKey},
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;

    if (!envelope.ok) {
      setState(() {
        _loading = false;
        _error = _errorMessage(envelope.error);
      });
      return;
    }
    final invalid = validateLayoutData(envelope.data);
    if (invalid != null) {
      setState(() {
        _loading = false;
        _error = 'Layout from ${widget.pluginId} is invalid: $invalid';
      });
      return;
    }

    final pluginEntry = await PluginRegistry.instance.findPlugin(
      widget.pluginId,
    );
    _applyLayoutPage(
      envelope.data!,
      packSourceUrl: pluginEntry?.pack.sourceUrl,
      pluginEntry: pluginEntry,
    );
  }

  void _applyLayoutPage(
    Map<String, dynamic> data, {
    String? packSourceUrl,
    ({EnginePack pack, EnginePlugin plugin})? pluginEntry,
  }) {
    final pages = data['pages'] as Map;
    final page = pages[_pageKey] ?? pages.values.first;
    final pageMap = Map<String, dynamic>.from(page as Map);
    _pageUsesFeed = pageMap['feed'] == true;
    _layoutFeedRailIds = catalogLayoutFeedRailIds(
      pageMap,
      legacyWhenFeedOnly: _packFeedRailIds,
    );
    _layoutPageSize = catalogRailPageSizeFrom(pageMap);
    if (pluginEntry != null) {
      _pluginConfigPageSize = catalogRailPageSizeFrom(
        pluginEntry.plugin.config,
      );
    }
    final rawWidgets = pageMap['widgets'] as List;
    final widgets = <Map<String, dynamic>>[
      for (final w in rawWidgets)
        if (w is Map) Map<String, dynamic>.from(w),
    ];
    for (final w in widgets) {
      if ((w['type'] ?? '').toString() != 'mood') continue;
      final id = (w['id'] ?? 'mood').toString();
      if (_moods.containsKey(id)) continue;
      final options = w['options'];
      if (options is! List || options.isEmpty) continue;
      final picked = _randomMoodOptionId(options);
      if (picked != null) {
        _moods[id] = picked;
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _widgets = widgets;
      _layoutWidgetSpecs = layoutWidgetSpecIndex(widgets);
      initLayoutTabSelections(_layoutSelections, widgets);
    });
    if (_pageUsesFeed) {
      unawaited(_ensureFeedLoaded());
    }
    if (!mounted) return;
    CatalogVerticalFiltersRegistry.syncFromLayout(
      tabId: _pageKey,
      pluginId: widget.pluginId,
      packSourceUrl: packSourceUrl,
      widgets: widgets,
    );
    CatalogKitTopMenuRegistry.syncFromLayout(
      tabId: _pageKey,
      widgets: widgets,
      selections: _layoutSelections,
      widgetSpecs: _layoutWidgetSpecs,
      onSelect: _onLayoutTabSelect,
    );
    unawaited(CatalogPackFiltersRegistry.ensureLoaded(widget.pluginId));
    _rebindChromeListenable();
    markShellTabFresh();
  }

  bool get _hasHostListWidget => CatalogKitTypes.treeContains(
    _widgets,
    slot: CatalogKitTypes.list,
  );

  void _onLayoutTabSelect(String widgetId, String value, {required bool toggle}) {
    setState(() {
      if (toggle) {
        final current = _layoutSelections[widgetId];
        _layoutSelections[widgetId] = current == value ? '' : value;
      } else {
        _layoutSelections[widgetId] = value;
      }
    });
    CatalogKitTopMenuRegistry.notifySelectionChanged(_pageKey);
  }

  Widget? _buildLayoutWidget(
    Map<String, dynamic> spec, {
    required Map<String, int> tvOrders,
    int stackIndex = 0,
  }) {
    final type = _layoutWidgetType(spec);
    final id = (spec['id'] ?? '').toString();
    switch (type) {
      case CatalogKitTypes.stack:
        return CatalogKitStackWidget(
          spec: spec,
          childBuilder: (childSpec, index) => _buildLayoutWidget(
            childSpec,
            tvOrders: tvOrders,
            stackIndex: index,
          ),
        );
      case CatalogKitTypes.menu:
        if (CatalogKitTopMenuRegistry.hasTopMenu(_pageKey)) return null;
        return CatalogKitMenuWidget(
          tabId: _pageKey,
          spec: spec,
          sortOrder: stackIndex,
        );
      case CatalogKitTypes.tabs:
        if (CatalogKitTopMenuRegistry.hasTopMenu(_pageKey)) return null;
        return CatalogKitTabsWidget(
          tabId: _pageKey,
          spec: spec,
          sortOrder: stackIndex,
        );
      case CatalogKitTypes.list:
        return CatalogKitListWidget(
          tabId: widget.tabId ?? '',
          pluginId: widget.pluginId,
          layoutSpec: spec,
          refreshEpoch: _hostRefreshEpoch,
          tvRowOrder: _tvOrder(tvOrders, id),
        );
      default:
        return _widgetFor(spec, tvOrders: tvOrders, prefetch: null);
    }
  }

  Widget? _fullPageLayoutBody({required Map<String, int> tvOrders}) {
    if (LiveSportsKitPage.matchesLayout(_widgets)) {
      return LiveSportsKitPage(
        pluginId: widget.pluginId,
        tabId: widget.tabId,
        layoutWidgets: _widgets,
        shellTabVisible: shellTabVisible,
        refreshEpoch: _hostRefreshEpoch,
      );
    }
    if (_widgets.length != 1) return null;
    final root = _widgets.first;
    if (!CatalogKitTypes.isCompositionRoot(root)) return null;
    final body = _buildLayoutWidget(root, tvOrders: tvOrders);
    if (body == null) return null;
    return CatalogLayoutScope(
      selections: Map.unmodifiable(_layoutSelections),
      widgetSpecs: _layoutWidgetSpecs,
      onSelect: _onLayoutTabSelect,
      child: TvFocusGraph(tabId: _pageKey, child: body),
    );
  }

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    if ((_hasHostListWidget || _isLiveHub) && mounted) {
      setState(() => _hostRefreshEpoch++);
    }
    _forceNextRails = force;
    _invalidateRailFutures();
    await _loadLayout(forceRefresh: force);
    if (!mounted) return;
    // Build after layout setState consumes [_forceNextRails] into new futures.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceNextRails = false;
    });
  }

  bool get _isLiveHub =>
      widget.tabId == 'live_matches' ||
      LiveSportsKitPage.matchesLayout(_widgets);

  @override
  void onShellTabHidden() {
    super.onShellTabHidden();
    if (_isLiveHub) {
      EngineService.instance.cancelLiveCatalog();
    }
  }

  @override
  void onShellTabShown() {
    super.onShellTabShown();
    if (_isLiveHub && mounted) {
      setState(() {});
    }
  }

  String _errorMessage(CatalogError? error) {
    if (error == null) return 'Could not load ${widget.pluginId}';
    if (error.message.isNotEmpty) return error.message;
    return switch (error.code) {
      CatalogErrorCode.authRequired => 'Sign in to use this hub',
      CatalogErrorCode.authExpired => 'Session expired. Sign in again.',
      CatalogErrorCode.rateLimit => 'Rate limited. Try again shortly.',
      _ => 'Could not load ${widget.pluginId} (${error.code.wire})',
    };
  }

  int _railPageSizeHint(Map<String, dynamic> spec) {
    return catalogRailPageSizeFrom(spec) ??
        catalogRailPageSizeFrom(
          spec['params'] is Map
              ? Map<String, dynamic>.from(spec['params'] as Map)
              : null,
        ) ??
        _layoutPageSize ??
        _pluginConfigPageSize ??
        kCatalogRailPageSizeFallback;
  }

  Future<CatalogRailPage<CatalogMetaItem>> _fetchRail(
    Map<String, dynamic> spec, {
    bool forceRefresh = false,
    int page = 1,
  }) async {
    final action = (spec['action'] ?? 'rail').toString().trim();
    final rawParams = spec['params'];
    final params = <String, dynamic>{
      if (rawParams is Map) ...Map<String, dynamic>.from(rawParams),
      if (spec['rail'] != null) 'rail': spec['rail'],
      if (page > 1) 'page': page,
    };
    for (final key in ['limit', 'pageSize', 'perPage']) {
      final v = spec[key];
      if (v != null) params.putIfAbsent(key, () => v);
      if (rawParams is Map && rawParams[key] != null) {
        params.putIfAbsent(key, () => rawParams[key]);
      }
    }
    final moodSource = (spec['moodSource'] ?? '').toString();
    final moodId = _moods[moodSource];
    Map<String, dynamic>? moodFilter;
    if (moodId != null && moodSource.isNotEmpty) {
      Map<String, dynamic>? moodSpec;
      for (final w in _widgets) {
        if ((w['type'] ?? '').toString() != 'mood') continue;
        if ((w['id'] ?? '').toString() != moodSource) continue;
        moodSpec = w;
        break;
      }
      final options = moodSpec?['options'];
      if (options is List) {
        for (final o in options) {
          if (o is! Map) continue;
          if (o['id']?.toString() != moodId) continue;
          moodFilter = catalogMoodFilter(Map<String, dynamic>.from(o));
          break;
        }
      }
      moodFilter ??= catalogFilterFromSelection(field: 'genre', value: moodId);
    }
    final envelope = await CatalogRuntime.instance.run(
      pluginId: widget.pluginId,
      action: action,
      params: catalogParamsWithFilters(
        params,
        filters: [
          ...catalogChromeFilters(
            tabId: widget.tabId,
            pluginId: widget.pluginId,
          ),
          moodFilter,
        ],
      ),
      forceRefresh: forceRefresh,
    );
    if (!envelope.ok) return const CatalogRailPage.empty();
    return CatalogRailPage(
      items: envelope.items,
      pageSize:
          catalogRailPageSizeFrom(envelope.data) ?? _railPageSizeHint(spec),
      hasMore: catalogRailHasMoreFrom(envelope.data),
    );
  }

  String? _packRailId(Map<String, dynamic> spec) {
    final rail = (spec['rail'] ?? '').toString().trim();
    return rail.isEmpty ? null : rail;
  }

  bool _isPackFeedRail(Map<String, dynamic> spec) {
    if (!_pageUsesFeed) return false;
    if ((spec['moodSource'] ?? '').toString().isNotEmpty) return false;
    final rail = _packRailId(spec);
    return rail != null && _layoutFeedRailIds.contains(rail);
  }

  String _feedMemoKey() => 'feed|${catalogChromeFilterEpoch(widget.tabId)}';

  Future<Map<String, List<CatalogMetaItem>>> _ensureFeedLoaded({
    bool force = false,
  }) {
    final key = _feedMemoKey();
    if (!force && _feedCacheKey == key && _feedRails.isNotEmpty) {
      return Future.value(_feedRails);
    }
    final pending = _feedLoadFuture;
    if (!force && pending != null) return pending;
    final load = _fetchFeed(forceRefresh: force).then((map) {
      _feedRails = map;
      _feedCacheKey = key;
      return map;
    });
    _feedLoadFuture = load;
    return load;
  }

  Future<Map<String, List<CatalogMetaItem>>> _fetchFeed({
    bool forceRefresh = false,
  }) async {
    final envelope = await CatalogRuntime.instance.run(
      pluginId: widget.pluginId,
      action: 'feed',
      params: catalogParamsWithFilters(
        const {},
        filters: catalogChromeFilters(
          tabId: widget.tabId,
          pluginId: widget.pluginId,
        ),
      ),
      forceRefresh: forceRefresh,
    );
    if (!envelope.ok) return const {};
    final data = envelope.data;
    if (data == null) return const {};
    final rails = data['rails'];
    if (rails is! Map) return const {};
    final out = <String, List<CatalogMetaItem>>{};
    for (final entry in rails.entries) {
      final items = entry.value;
      if (items is! List) continue;
      out[entry.key.toString()] = [
        for (final it in items)
          if (it is Map)
            CatalogMetaItem.fromJson(Map<String, dynamic>.from(it)),
      ];
    }
    return out;
  }

  String _railMemoKey(Map<String, dynamic> spec) {
    final id = (spec['id'] ?? spec['rail'] ?? '').toString();
    final moodSrc = (spec['moodSource'] ?? '').toString();
    final mood = moodSrc.isEmpty ? '' : (_moods[moodSrc] ?? '');
    final chrome = catalogChromeFilterEpoch(widget.tabId);
    return '$id|$moodSrc|$mood|$chrome';
  }

  Future<CatalogRailPage<CatalogMetaItem>> _itemsForRailSpec(
    Map<String, dynamic> spec, {
    bool forceRefresh = false,
    bool useFeedBatch = false,
  }) async {
    if (useFeedBatch && _isPackFeedRail(spec)) {
      final railId = _packRailId(spec)!;
      final feed = await _ensureFeedLoaded(force: forceRefresh);
      final batched = feed[railId] ?? const [];
      if (batched.isNotEmpty) {
        final pageSize = _railPageSizeHint(spec);
        return CatalogRailPage(
          items: batched,
          pageSize: pageSize,
          hasMore: batched.length >= pageSize,
        );
      }
      // Partial/empty feed slice (e.g. spotlight missing) — direct rail fetch.
    }
    return _fetchRail(spec, forceRefresh: forceRefresh);
  }

  Future<CatalogRailPage<CatalogMetaItem>> _fetchRailPage(
    Map<String, dynamic> spec, {
    required int page,
    bool useFeedBatch = false,
  }) {
    if (page > 1) {
      return _fetchRail(spec, page: page);
    }
    final key = _railMemoKey(spec);
    final force = _forceNextRails;
    return _metaRailFutures.putIfAbsent(
      key,
      () => _itemsForRailSpec(
        spec,
        forceRefresh: force,
        useFeedBatch: useFeedBatch,
      ),
    );
  }

  /// Same Future across rebuilds until chrome / mood / tab refresh invalidates.
  Future<List<CatalogMetaItem>> _railFuture(
    Map<String, dynamic> spec, {
    bool useFeedBatch = false,
  }) async {
    final page = await _fetchRailPage(
      spec,
      page: 1,
      useFeedBatch: useFeedBatch,
    );
    return page.items;
  }

  Future<void> _openMeta(CatalogMetaItem item) =>
      openCatalogMetaItem(context, pluginId: widget.pluginId, item: item);

  CatalogListFollowTarget? _listTarget(CatalogMetaItem item) {
    return CatalogListFollowTarget.fromMeta(
      pluginId: widget.pluginId,
      meta: item,
    );
  }

  List<HubHeroSlide> _heroSlides(List<CatalogMetaItem> items) {
    return [for (final item in items.take(5)) _heroSlideFor(item)];
  }

  HubHeroSlide _heroSlideFor(CatalogMetaItem item) {
    final status = (item.status ?? '').trim();
    final isUpcoming = hubMetaIsUpcoming(item);
    final useAniBanner =
        item.open != null &&
        item.bannerImage.isNotEmpty &&
        item.background == item.bannerImage;
    final yearBit = item.releaseInfo.isEmpty
        ? null
        : item.releaseInfo.split(' • ').first;
    final open = item.open;
    final hubNative = open != null && catalogOpenUsesHubDetails(open);
    final movie = hubNative ? null : catalogMetaToMovie(item);
    final tmdbMediaType = movie?.mediaType ?? hubMetaTmdbMediaType(item);
    final heroTypeLabel = hubPosterTypeLabel(item);
    final tmdbSearch = item.ids['tmdbSearch']?.toString().trim();
    final tmdbFromIds = item.numericId('tmdb');
    return HubHeroSlide(
      id: item.id,
      title: item.name,
      matchTitle: tmdbSearch != null && tmdbSearch.isNotEmpty
          ? tmdbSearch
          : null,
      imageUrl: item.background.isNotEmpty ? item.background : item.poster,
      overview: item.description,
      rating: item.rating,
      year: yearBit,
      badge: heroTypeLabel ?? item.badge,
      statusChip: status.isEmpty ? null : status.replaceAll('_', ' '),
      isUpcoming: isUpcoming,
      upcomingReleaseLabel:
          isUpcoming ? (hubMetaPremiereDateLabel(item) ?? yearBit) : null,
      genres: item.genres,
      imageFit: useAniBanner ? BoxFit.fitWidth : BoxFit.cover,
      imageAlignment: useAniBanner ? Alignment.center : Alignment.centerRight,
      tmdbId: tmdbFromIds ?? (hubNative ? null : (open?.idInt ?? movie?.id)),
      tmdbMediaType: tmdbMediaType,
      movie: movie,
      listTarget: _listTarget(item),
      onDetails: () => unawaited(_openMeta(item)),
    );
  }

  HubPosterCard _card(
    BuildContext context,
    CatalogMetaItem item,
    int index, {
    bool showRank = false,
    String? rowId,
    HubPosterAspect aspect = HubPosterAspect.portrait,
    VoidCallback? onUpEdge,
  }) => HubPosterCard(
    imageUrl: item.poster,
    title: item.name,
    subtitle: hubPosterCardSubtitle(item),
    rating: item.rating,
    rank: showRank ? index + 1 : null,
    badge: hubPosterCardBadge(item, pluginId: widget.pluginId),
    listIndex: index,
    listTarget: _listTarget(item),
    tvTabId: widget.tabId,
    tvRowId: rowId,
    onUpEdge: onUpEdge,
    aspect: aspect,
    onTap: () => unawaited(_openMeta(item)),
  );

  HubPosterAspect _aspectOf(Map<String, dynamic> spec) {
    final a = (spec['aspect'] ?? '').toString().trim().toLowerCase();
    return a == 'landscape'
        ? HubPosterAspect.landscape
        : HubPosterAspect.portrait;
  }

  bool get _fullHeroBleed => hubIsFullCinematicHero(context);

  /// Chrome Films / Series — hide `hideWhenTypeFilter` rails (not Categories).
  bool _chromeHidesTypeFilterRail() =>
      catalogChromeHidesTypeFilterRails(widget.tabId);

  String? get _bleedRailId {
    if (!_fullHeroBleed) return null;
    for (final w in _widgets) {
      if ((w['type'] ?? '').toString() != 'hero') continue;
      final bleed = (w['bleed'] ?? '').toString().trim();
      if (bleed.isNotEmpty) return bleed;
    }
    return null;
  }

  /// `style: numbered|ranked` or widget type `ranked` → rank badges.
  bool _isNumbered(Map<String, dynamic> spec) {
    final style = (spec['style'] ?? '').toString().trim().toLowerCase();
    if (style == 'numbered' || style == 'ranked') return true;
    return (spec['type'] ?? '').toString() == 'ranked';
  }

  /// `orientation: vertical` → stacked cards; default horizontal scroller.
  bool _isVertical(Map<String, dynamic> spec) {
    final o = (spec['orientation'] ?? spec['layout'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return o == 'vertical';
  }

  /// Assigns monotonic [sortOrder] values for TV row registry from layout order.
  Map<String, int> _planTvRowOrders({
    Map<String, dynamic>? bleedSpec,
    String? bleedId,
    bool bleedActive = true,
  }) {
    final orders = <String, int>{};
    var order = 0;

    // Hero bleed row (Featured under spotlight) is always the first catalog row.
    if (bleedSpec != null && bleedActive) {
      final bleedWidgetId = (bleedSpec['id'] ?? bleedId ?? '')
          .toString()
          .trim();
      if (bleedWidgetId.isNotEmpty) {
        orders[bleedWidgetId] = order++;
      }
    }

    for (final spec in _widgets) {
      final type = (spec['type'] ?? '').toString();
      final id = (spec['id'] ?? '').toString();
      final rail = (spec['rail'] ?? '').toString();
      if (bleedSpec != null &&
          bleedActive &&
          bleedId != null &&
          (id == bleedId || rail == bleedId) &&
          (type == 'rail' || type == 'ranked') &&
          spec['hideWhenBleed'] == true) {
        continue;
      }
      if (spec['hideWhenTypeFilter'] == true && _chromeHidesTypeFilterRail()) {
        continue;
      }
      if (!_layoutWidgetCountsForTv(spec)) continue;

      switch (type) {
        case 'hero':
        case 'vertical_filters':
        case 'host.vertical_filters':
          break;
        case 'mood':
          orders['$id-chips'] = order;
          orders['$id-results'] = order + 1;
          order += 2;
        default:
          if (id.isNotEmpty) {
            orders[id] = order++;
          }
      }
    }
    return orders;
  }

  bool _layoutWidgetCountsForTv(Map<String, dynamic> spec) {
    switch (_layoutWidgetType(spec)) {
      case 'vertical_filters':
      case 'host.vertical_filters':
        return false;
      case 'continue':
      case 'host.continue':
        return true;
      case CatalogKitTypes.list:
      case CatalogKitTypes.stack:
      case CatalogKitTypes.menu:
      case CatalogKitTypes.tabs:
        return true;
      default:
        return true;
    }
  }

  int _tvOrder(Map<String, int> orders, String id, {int fallback = 0}) =>
      orders[id] ?? fallback;

  void _focusHeroPlay() {
    ShellTvFocusCoordinator.revealHeroForTab(_pageKey);
    ShellTvFocus.focusHomeHeroPlay();
  }

  Widget _railSection(
    Map<String, dynamic> spec, {
    bool showRank = false,
    int tvRowOrder = 0,
    VoidCallback? tvFocusUp,
    CatalogHubRowPrefetchSlot? prefetch,
  }) {
    final id = (spec['id'] ?? '').toString();
    final aspect = _aspectOf(spec);
    final reload = _chromeFilterEpoch;
    final numbered = showRank || _isNumbered(spec);
    if (_isVertical(spec)) {
      return _VerticalHubRail(
        key: ValueKey('vhub:$id'),
        title: (spec['title'] ?? '').toString(),
        reloadToken: reload,
        fetchPage: (page) => _fetchRailPage(spec, page: page),
        prefetchSlot: prefetch,
        showRank: numbered,
        aspect: aspect,
        tvTabId: widget.tabId,
        tvRowId: id,
        tvRowOrder: tvRowOrder,
        cardBuilder: (context, item, index) => _card(
          context,
          item,
          index,
          showRank: numbered,
          rowId: id,
          aspect: aspect,
        ),
      );
    }
    return HubCatalogSection<CatalogMetaItem>(
      key: ValueKey('rail:$id'),
      title: (spec['title'] ?? '').toString(),
      reloadToken: reload,
      lazy: true,
      fetchPage: (page) => _fetchRailPage(
        spec,
        page: page,
        useFeedBatch: page == 1 && _isPackFeedRail(spec),
      ),
      pageSizeHint: _railPageSizeHint(spec),
      prefetchSlot: prefetch,
      itemKey: (item) => item.id,
      showRank: numbered,
      cardAspect: aspect,
      tvTabId: widget.tabId,
      tvRowId: id,
      tvRowOrder: tvRowOrder,
      tvFocusUp: tvFocusUp,
      cardBuilder: (context, item, index) => _card(
        context,
        item,
        index,
        showRank: numbered,
        rowId: id,
        aspect: aspect,
      ),
    );
  }

  Widget _heroSection(
    Map<String, dynamic> spec, {
    Widget? pageBottomChild,
    String? bleedRowId,
    CatalogHubRowPrefetchSlot? prefetch,
  }) {
    return _CatalogHeroSection(
      key: const ValueKey('hero:spotlight'),
      future: _railFuture(spec, useFeedBatch: true),
      buildSlides: _heroSlides,
      tvTabId: widget.tabId ?? 'home',
      scrollController: _scroll,
      pageBottomChild: pageBottomChild,
      bleedRowId: bleedRowId,
      prefetchSlot: prefetch,
    );
  }

  IconData _moodIcon(String? name) {
    return switch ((name ?? '').trim()) {
      'psychology' => Icons.psychology_rounded,
      'wb_sunny' => Icons.wb_sunny_rounded,
      'dark_mode' => Icons.dark_mode_rounded,
      'favorite' => Icons.favorite_rounded,
      'bedtime' => Icons.bedtime_rounded,
      'local_fire_department' => Icons.local_fire_department_rounded,
      'brush' => Icons.brush_rounded,
      'theaters' => Icons.theaters_rounded,
      'emoji_emotions' => Icons.emoji_emotions_rounded,
      'auto_awesome' => Icons.auto_awesome_rounded,
      'rocket_launch' => Icons.rocket_launch_rounded,
      'sports_soccer' => Icons.sports_soccer_rounded,
      _ => Icons.circle_outlined,
    };
  }

  String? _randomMoodOptionId(List options) {
    final ids = <String>[
      for (final o in options)
        if (o is Map && o['id'] != null) o['id'].toString(),
    ];
    if (ids.isEmpty) return null;
    return ids[Random().nextInt(ids.length)];
  }

  Color _moodAccent(String? hex) {
    final raw = (hex ?? '').trim().replaceFirst('#', '');
    if (raw.length != 6) return ForjaShellColors.sectionAccent;
    final v = int.tryParse(raw, radix: 16);
    if (v == null) return ForjaShellColors.sectionAccent;
    return Color(0xFF000000 | v);
  }

  Map<String, dynamic> _moodResultsSpec(Map<String, dynamic> spec) {
    final id = (spec['id'] ?? 'mood').toString();
    final rail = (spec['rail'] ?? 'discover').toString().trim();
    return {
      ...spec,
      'type': 'rail',
      'id': '${id}_results',
      'rail': rail.isEmpty ? 'discover' : rail,
      'moodSource': id,
      'title': '',
    };
  }

  double _moodSectionPlaceholderHeight(
    BuildContext context, {
    required int optionCount,
    required bool hasResults,
  }) {
    final titleTop = shellHomeSectionTitleTop(context);
    final titleBlock =
        titleTop +
        shellHomeSectionHeaderHeight(context) +
        shellScaled(context, 12).clamp(4.0, 12.0);
    final layout = ShellMoodCircleLayout.resolve(
      context,
      itemCount: optionCount,
      maxWidth: MediaQuery.sizeOf(context).width,
    );
    final resultsGap = hasResults ? 16.0 : 0.0;
    final resultsRow = hasResults
        ? HubCatalogSection.sectionHeight(
            context,
            compactTop: true,
            embedded: true,
          )
        : 0.0;
    return titleBlock + layout.rowHeight + resultsGap + resultsRow;
  }

  Widget _moodSection(
    Map<String, dynamic> spec, {
    required int tvRowOrder,
    CatalogHubRowPrefetchSlot? prefetch,
  }) {
    final id = (spec['id'] ?? 'mood').toString();
    final title = (spec['title'] ?? 'Moods').toString();
    final chipRowId = '$id-chips';
    final resultsRowId = '$id-results';
    final options = [
      for (final o in (spec['options'] as List? ?? const []))
        if (o is Map) Map<String, dynamic>.from(o),
    ];
    if (options.isEmpty) return const SizedBox.shrink();
    if (_moods[id] == null) {
      final picked = _randomMoodOptionId(options);
      if (picked != null) _moods[id] = picked;
    }
    final selected = _moods[id] ?? '';
    final titleTop = shellHomeSectionTitleTop(context);
    final resultsRail = (spec['rail'] ?? '').toString().trim();
    final tvNav = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    Widget moodChip({
      required ShellMoodCircleLayout layout,
      required int i,
      TvChipEdges? edges,
    }) {
      final opt = options[i];
      final optId = opt['id']?.toString() ?? '';
      final isSelected = optId == selected;
      return ShellMoodCircleItem(
        layout: layout,
        label: (opt['label'] ?? optId).toString(),
        icon: _moodIcon(opt['icon']?.toString()),
        accent: _moodAccent(opt['accent']?.toString()),
        selected: isSelected,
        listIndex: i,
        tvTabId: widget.tabId,
        tvRowId: chipRowId,
        onTap: () {
          setState(() {
            _invalidateRailFutures();
            _moods[id] = optId;
          });
          if (isSelected && edges != null) {
            edges.onSelectAlreadySelected();
          }
        },
        onLeftEdge: edges?.onLeft,
        onRightEdge: edges?.onRight,
        onUpEdge: edges?.onUp,
        onDownEdge: edges?.onDown,
      );
    }

    Widget moodChipRow({
      required ShellMoodCircleLayout layout,
      TvChipEdges Function(int index)? edgesFor,
      bool scaleToFit = false,
    }) {
      final row = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) SizedBox(width: layout.horizontalGap),
            moodChip(layout: layout, i: i, edges: edgesFor?.call(i)),
          ],
        ],
      );
      return SizedBox(
        height: layout.rowHeight,
        width: double.infinity,
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: scaleToFit
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: row,
                )
              : Center(child: row),
        ),
      );
    }

    final resultsSpec = _moodResultsSpec(spec);

    Widget moodBody() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: shellHomeSectionTitlePadding(
              context,
              top: titleTop,
              bottom: shellScaled(context, 12).clamp(4.0, 12.0),
            ),
            child: Text(title, style: ShellSectionTitle.titleStyle),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final layout = ShellMoodCircleLayout.resolve(
                context,
                itemCount: options.length,
                maxWidth: constraints.maxWidth,
              );
              if (tvNav) {
                return TvChipStrip(
                  tabId: widget.tabId,
                  rowId: chipRowId,
                  sortOrder: tvRowOrder,
                  itemCount: options.length,
                  resultsRowId: resultsRowId,
                  builder: (context, edgesFor) {
                    if (layout.contentWidth(options.length) <=
                        constraints.maxWidth) {
                      return moodChipRow(
                        layout: layout,
                        edgesFor: edgesFor,
                        scaleToFit: true,
                      );
                    }
                    return SizedBox(
                      height: layout.rowHeight,
                      child: HorizontalScroller(
                        height: layout.rowHeight,
                        padding: EdgeInsets.symmetric(
                          horizontal: shellHomeSectionHorizontalPadding(
                            context,
                          ),
                        ),
                        itemCount: options.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(width: layout.horizontalGap),
                        itemBuilder: (context, i) =>
                            moodChip(layout: layout, i: i, edges: edgesFor(i)),
                      ),
                    );
                  },
                );
              }

              if (layout.contentWidth(options.length) <= constraints.maxWidth) {
                return Center(child: moodChipRow(layout: layout));
              }
              return HorizontalScroller(
                height: layout.rowHeight,
                padding: EdgeInsets.symmetric(
                  horizontal: shellHomeSectionHorizontalPadding(context),
                ),
                itemCount: options.length,
                separatorBuilder: (_, _) =>
                    SizedBox(width: layout.horizontalGap),
                itemBuilder: (context, i) => moodChip(layout: layout, i: i),
              );
            },
          ),
          if (resultsRail.isNotEmpty) ...[
            const SizedBox(height: 16),
            HubCatalogSection<CatalogMetaItem>(
              key: ValueKey('mood-results:$id:$selected'),
              title: '',
              reloadToken: _chromeFilterEpoch,
              fetchPage: (page) => _fetchRailPage(resultsSpec, page: page),
              pageSizeHint: _railPageSizeHint(spec),
              itemKey: (item) => item.id,
              embedded: true,
              compactTop: true,
              tvTabId: widget.tabId,
              tvRowId: resultsRowId,
              tvRowOrder: tvRowOrder + 1,
              cardBuilder: (context, item, index) => _card(
                context,
                item,
                index,
                rowId: resultsRowId,
                onUpEdge: tvResultsUpToChips(context, chipRowId: chipRowId),
              ),
            ),
          ],
        ],
      );
    }

    return HubLazyViewportGate(
      detectorKey: ValueKey('mood:$id'),
      placeholderHeight: _moodSectionPlaceholderHeight(
        context,
        optionCount: options.length,
        hasResults: resultsRail.isNotEmpty,
      ),
      prefetchSlot: prefetch,
      onVisible: () {},
      builder: (_) => moodBody(),
    );
  }

  String _layoutWidgetType(Map<String, dynamic> spec) {
    final raw = _rawLayoutWidgetType(spec);
    final kit = CatalogKitTypes.normalize(raw, spec);
    if (kit.startsWith('kit.')) return kit;
    return switch (raw) {
      'host.continue' => 'continue',
      'host.because' => 'because',
      'host.trakt' => 'trakt',
      'host.vertical_filters' => 'vertical_filters',
      _ => raw,
    };
  }

  String _rawLayoutWidgetType(Map<String, dynamic> spec) =>
      (spec['type'] ?? '').toString().trim();

  Widget? _widgetFor(
    Map<String, dynamic> spec, {
    Widget? heroBleedChild,
    String? heroBleedRowId,
    required Map<String, int> tvOrders,
    CatalogHubRowPrefetchSlot? prefetch,
  }) {
    final id = (spec['id'] ?? '').toString();
    final slot = _layoutWidgetType(spec);
    switch (slot) {
      case 'hero':
        return _heroSection(
          spec,
          pageBottomChild: heroBleedChild,
          bleedRowId: heroBleedRowId,
          prefetch: prefetch,
        );
      case CatalogKitTypes.row:
      case 'rail':
      case 'ranked':
        return _railSection(
          spec,
          showRank: _rawLayoutWidgetType(spec) == 'ranked',
          tvRowOrder: _tvOrder(tvOrders, id),
          prefetch: prefetch,
        );
      case 'mood':
        return _moodSection(
          spec,
          tvRowOrder: _tvOrder(tvOrders, '$id-chips'),
          prefetch: prefetch,
        );
      case 'continue':
        return CatalogContinueWidget(
          pluginId: widget.pluginId,
          tabId: widget.tabId ?? '',
          mergeHomeWatchHistory: spec['mergeHomeWatchHistory'] == true,
          tvRowOrder: _tvOrder(tvOrders, id),
          tvFocusUp: _focusHeroPlay,
          prefetchSlot: prefetch,
        );
      case 'because':
        return CatalogBecauseSection(
          pluginId: widget.pluginId,
          tabId: widget.tabId ?? '',
          spec: spec,
          tvRowOrder: _tvOrder(tvOrders, id),
          prefetchSlot: prefetch,
        );
      case CatalogKitTypes.list:
        return CatalogKitListWidget(
          tabId: widget.tabId ?? '',
          pluginId: widget.pluginId,
          layoutSpec: spec,
          refreshEpoch: _hostRefreshEpoch,
          tvRowOrder: _tvOrder(tvOrders, id),
        );
      case CatalogKitTypes.stack:
        return CatalogKitStackWidget(
          spec: spec,
          childBuilder: (childSpec, index) => _buildLayoutWidget(
            childSpec,
            tvOrders: tvOrders,
            stackIndex: index,
          ),
        );
      case CatalogKitTypes.menu:
      case CatalogKitTypes.tabs:
        if (CatalogKitTopMenuRegistry.hasTopMenu(_pageKey)) return null;
        return CatalogLayoutScope(
          selections: Map.unmodifiable(_layoutSelections),
          widgetSpecs: _layoutWidgetSpecs,
          onSelect: _onLayoutTabSelect,
          child: slot == CatalogKitTypes.menu
              ? CatalogKitMenuWidget(
                  tabId: _pageKey,
                  spec: spec,
                  sortOrder: _tvOrder(tvOrders, id),
                )
              : CatalogKitTabsWidget(
                  tabId: _pageKey,
                  spec: spec,
                  sortOrder: _tvOrder(tvOrders, id),
                ),
        );
      case 'vertical_filters':
      case 'host.vertical_filters':
        return null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final body = () {
      final liveHub = widget.tabId == 'live_matches' ||
          LiveSportsKitPage.matchesLayout(_widgets);
      if (liveHub) {
        return LiveSportsKitPage(
          pluginId: widget.pluginId,
          tabId: widget.tabId,
          layoutWidgets: _widgets,
          shellTabVisible: shellTabVisible,
          refreshEpoch: _hostRefreshEpoch,
        );
      }
      if (_loading && _widgets.isEmpty) {
        return CustomScrollView(
          controller: _scroll,
          slivers: homeHubLoadingSlivers(
            context,
            heroShimmer: homeCinematicHeroShimmer(
              context,
              pageBottomBleed: _fullHeroBleed,
            ),
          ),
        );
      }
      final error = _error;
      if (error != null && _widgets.isEmpty) {
        return ShellErrorRetryPanel(
          message: error,
          onRetry: () => unawaited(_loadLayout(forceRefresh: true)),
        );
      }

      final bleedId = _bleedRailId;
      Map<String, dynamic>? bleedSpec;
      if (bleedId != null) {
        for (final w in _widgets) {
          if ((w['id'] ?? '').toString() == bleedId ||
              (w['rail'] ?? '').toString() == bleedId) {
            final t = (w['type'] ?? '').toString();
            if (t == 'rail' || t == 'ranked') {
              // Don't bleed a rail the chrome filter would hide (Anime Films/
              // Series / Categories hid Trending under the hero too).
              if (w['hideWhenTypeFilter'] == true &&
                  _chromeHidesTypeFilterRail()) {
                break;
              }
              bleedSpec = w;
              break;
            }
          }
        }
      }
      final bleed = bleedSpec;
      final bleedActive = bleed == null || _bleedPopulated != false;
      final tvOrders = _planTvRowOrders(
        bleedSpec: bleed,
        bleedId: bleedId,
        bleedActive: bleedActive,
      );
      final bleedRowId = bleed == null ? null : (bleed['id'] ?? '').toString();

      // Full-page stack / host.my_list — Column+Expanded, not a sliver adapter.
      final fullPage = _fullPageLayoutBody(tvOrders: tvOrders);
      if (fullPage != null) return fullPage;

      final Widget? bleedChild = bleed == null || !bleedActive
          ? null
          : HubCatalogSection<CatalogMetaItem>(
              key: ValueKey('bleed:${bleed['id']}'),
              title: (bleed['title'] ?? '').toString(),
              reloadToken: _chromeFilterEpoch,
              fetchPage: (page) =>
                  _fetchRailPage(bleed, page: page, useFeedBatch: page == 1),
              pageSizeHint: _railPageSizeHint(bleed),
              itemKey: (item) => item.id,
              showRank: _isNumbered(bleed),
              compactTop: true,
              cardAspect: _aspectOf(bleed),
              tvTabId: widget.tabId,
              tvRowId: bleedRowId,
              tvRowOrder: _tvOrder(tvOrders, bleedRowId ?? ''),
              tvFocusUp: _focusHeroPlay,
              onFirstPageLoaded: (count) {
                if (!mounted) return;
                final populated = count > 0;
                if (_bleedPopulated == populated) return;
                setState(() => _bleedPopulated = populated);
              },
              cardBuilder: (context, item, index) => _card(
                context,
                item,
                index,
                showRank: _isNumbered(bleed),
                rowId: (bleed['id'] ?? '').toString(),
                aspect: _aspectOf(bleed),
              ),
            );

      final sections = <Widget>[];
      var rowIndex = 0;
      for (final spec in _widgets) {
        final type = (spec['type'] ?? '').toString();
        final id = (spec['id'] ?? '').toString();
        final rail = (spec['rail'] ?? '').toString();
        if (bleedSpec != null &&
            bleedActive &&
            (id == bleedId || rail == bleedId) &&
            (type == 'rail' || type == 'ranked') &&
            spec['hideWhenBleed'] == true) {
          continue;
        }
        if (spec['hideWhenTypeFilter'] == true &&
            _chromeHidesTypeFilterRail()) {
          continue;
        }
        final w = _widgetFor(
          spec,
          heroBleedChild: type == 'hero' ? bleedChild : null,
          heroBleedRowId: type == 'hero' ? bleedRowId : null,
          tvOrders: tvOrders,
          prefetch: _prefetchSlot(rowIndex),
        );
        if (w != null) {
          sections.add(w);
          rowIndex++;
        }
      }
      if (sections.isEmpty) {
        return ShellErrorRetryPanel(
          message: '${widget.pluginId} returned an empty layout',
          onRetry: () => unawaited(_loadLayout(forceRefresh: true)),
        );
      }

      return CustomScrollView(
        controller: _scroll,
        slivers: [
          for (var i = 0; i < sections.length; i++)
            hubRowSliver(context, sections[i], isFirstAfterHero: i == 0),
          SliverToBoxAdapter(
            child: SizedBox(height: shellTvCatalogScrollBottomGap(context)),
          ),
        ],
      );
    }();

    return ColoredBox(
      color: AppTheme.bgDark,
      child: TvFocusGraph(tabId: _pageKey, child: body),
    );
  }
}

class _CatalogHeroSection extends StatefulWidget {
  const _CatalogHeroSection({
    super.key,
    required this.future,
    required this.buildSlides,
    required this.tvTabId,
    required this.scrollController,
    this.pageBottomChild,
    this.bleedRowId,
    this.prefetchSlot,
  });

  final Future<List<CatalogMetaItem>> future;
  final List<HubHeroSlide> Function(List<CatalogMetaItem>) buildSlides;
  final String tvTabId;
  final ScrollController scrollController;
  final Widget? pageBottomChild;
  final String? bleedRowId;
  final CatalogHubRowPrefetchSlot? prefetchSlot;

  @override
  State<_CatalogHeroSection> createState() => _CatalogHeroSectionState();
}

class _CatalogHeroSectionState extends State<_CatalogHeroSection> {
  List<CatalogMetaItem>? _items;
  List<CatalogMetaItem>? _lastSlides;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _CatalogHeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.future != widget.future) unawaited(_load());
  }

  Future<void> _load() async {
    final gen = ++_gen;
    final had = _items != null && _items!.isNotEmpty;
    try {
      var items = await widget.future;
      if (!mounted || gen != _gen) return;
      if (items.isEmpty && _lastSlides != null && _lastSlides!.isNotEmpty) {
        items = _lastSlides!;
      } else if (items.isNotEmpty) {
        _lastSlides = items;
      }
      setState(() => _items = items);
      if (items.isNotEmpty) widget.prefetchSlot?.notifyVisible();
    } catch (_) {
      if (!mounted || gen != _gen) return;
      // Keep last slides on error when we already painted.
      if (!had) setState(() => _items = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    // Keep shimmer until first slides arrive. Later future swaps keep last
    // slides (memoized rails + soft refresh) — never blank the hero.
    if (items == null) {
      return homeCinematicHeroShimmer(
        context,
        pageBottomBleed: widget.pageBottomChild != null,
      );
    }
    if (items.isEmpty) {
      // Keep cinematic chrome (shimmer + bleed row) — bleed-only looked like a
      // missing hero when spotlight was empty in a partial feed batch.
      return homeCinematicHeroShimmer(
        context,
        pageBottomBleed: widget.pageBottomChild != null,
      );
    }
    final bottom = widget.pageBottomChild;
    return HomeCinematicHero.hub(
      slides: widget.buildSlides(items),
      tvTabId: widget.tvTabId,
      scrollController: widget.scrollController,
      pageBottomChild: bottom,
      bleedRowId: widget.bleedRowId,
      firstCatalogRowHeight: bottom == null
          ? null
          : HubCatalogSection.sectionHeight(context, compactTop: true),
    );
  }
}

class _VerticalHubRail extends StatefulWidget {
  const _VerticalHubRail({
    super.key,
    required this.title,
    required this.fetchPage,
    required this.cardBuilder,
    this.prefetchSlot,
    this.showRank = false,
    this.aspect = HubPosterAspect.portrait,
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.reloadToken,
  });

  final String title;
  final Future<CatalogRailPage<CatalogMetaItem>> Function(int page) fetchPage;
  final CatalogHubRowPrefetchSlot? prefetchSlot;
  final HubPosterCard Function(BuildContext, CatalogMetaItem, int) cardBuilder;
  final bool showRank;
  final HubPosterAspect aspect;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;
  final String? reloadToken;

  @override
  State<_VerticalHubRail> createState() => _VerticalHubRailState();
}

class _VerticalHubRailState extends State<_VerticalHubRail> {
  List<CatalogMetaItem> _items = const [];
  bool _loading = false;
  int _loadGen = 0;

  @override
  void didUpdateWidget(covariant _VerticalHubRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    setState(() => _loading = true);
    try {
      final result = await widget.fetchPage(1);
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HubLazyViewportGate(
      detectorKey: ValueKey('vhub-lazy:${widget.tvRowId ?? widget.title}'),
      placeholderHeight:
          shellHomeSectionTitleTop(context) +
          shellHomeSectionHeaderHeight(context) +
          HubPosterCard.cardHeight(context, aspect: widget.aspect),
      prefetchSlot: widget.prefetchSlot,
      onVisible: () => unawaited(_load()),
      builder: (activated) {
        if (!activated || (_loading && _items.isEmpty)) {
          return homeLoadingShimmer(homeMovieRowSkeleton(context));
        }
        final items = _items;
        if (items.isEmpty) return const SizedBox.shrink();
        final pad = shellHomeSectionHorizontalPadding(context);
        final rowId = widget.tvRowId;
        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShellSectionTitle(
              title: widget.title,
              padding: shellHomeSectionTitlePadding(context),
            ),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  0,
                  pad,
                  widget.showRank
                      ? shellScaled(context, 6).clamp(3.0, 6.0)
                      : shellMovieCardRowGap(context),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: widget.cardBuilder(context, items[i], i),
                ),
              ),
          ],
        );
        if (rowId == null || widget.tvTabId == null) return column;
        return TvCatalogRow(
          tabId: widget.tvTabId,
          rowId: rowId,
          sortOrder: widget.tvRowOrder,
          itemCount: items.length,
          orientation: ShellTvRowOrientation.vertical,
          child: column,
        );
      },
    );
  }
}

/// Resolves [tabId] → installed hub [pluginId] before building [CatalogShell].
class CatalogShellLoader extends StatefulWidget {
  const CatalogShellLoader({super.key, required this.tabId});

  final String tabId;

  @override
  State<CatalogShellLoader> createState() => _CatalogShellLoaderState();
}

class _CatalogShellLoaderState extends State<CatalogShellLoader> {
  String? _pluginId;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    try {
      final id = await PluginNavRegistry.pluginIdForTab(widget.tabId);
      if (!mounted) return;
      if (id == null || id.isEmpty) {
        setState(() => _error = 'Hub pack not installed');
        return;
      }
      setState(() => _pluginId = id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pluginId = _pluginId;
    if (pluginId != null) {
      return CatalogShell(pluginId: pluginId, tabId: widget.tabId);
    }
    if (_error != null) {
      return ShellErrorRetryPanel(
        message: 'Could not load hub tab',
        onRetry: () => unawaited(_resolve()),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
