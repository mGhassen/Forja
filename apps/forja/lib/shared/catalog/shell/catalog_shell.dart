import 'dart:async';

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
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/shell_mood_circle.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_tab_refresh.dart';

import '../kit/cards/hub_poster_card.dart';
import '../kit/chrome/catalog_vertical_filters.dart';
import '../kit/widgets/catalog_because_section.dart';
import '../kit/widgets/catalog_continue_widget.dart';
import '../kit/widgets/catalog_host_trakt.dart';
import '../kit/meta/catalog_meta_movie.dart';
import '../kit/rows/hub_catalog_section.dart';
import '../filter.dart';
import '../plugin_nav.dart';
import '../protocol.dart';
import '../runtime.dart';
import '../kit/chrome/catalog_chrome_filters.dart';
import 'catalog_open.dart';

/// Renders a shell tab from a `kind: catalog` plugin layout.
///
/// One `layout` call describes the page; each rail widget pulls its own `rail`
/// action so rows paint independently.
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
  int _chromeEpoch = 0;

  /// Selected mood per mood-widget id.
  final Map<String, String> _moods = {};

  /// Stable rail Futures — rebuild must not create a new Future (shimmer flash).
  final Map<String, Future<List<CatalogMetaItem>>> _metaRailFutures = {};

  /// Pack `feed` action — one JS call claims across spotlight / featured / …
  bool _pageUsesFeed = false;
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

  /// Last [catalogChromeFilterEpoch] — ignore structural revision bumps.
  String _chromeFilterEpoch = '';

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
    unawaited(_loadLayout());
  }

  void _rebindChromeListenable() {
    _chromeListenable?.removeListener(_onChromeFilterChanged);
    _chromeListenable = catalogChromeFilterListenable(widget.tabId);
    _chromeFilterEpoch = catalogChromeFilterEpoch(widget.tabId);
    _chromeListenable?.addListener(_onChromeFilterChanged);
  }

  @override
  void dispose() {
    CatalogVerticalFiltersRegistry.unregister(_pageKey);
    if (_verticalFiltersRevisionListener != null) {
      CatalogVerticalFiltersRegistry.revision.removeListener(
        _verticalFiltersRevisionListener!,
      );
    }
    _chromeListenable?.removeListener(_onChromeFilterChanged);
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
    setState(() => _chromeEpoch++);
  }

  void _invalidateRailFutures() {
    _metaRailFutures.clear();
    _feedRails = {};
    _feedCacheKey = '';
    _feedLoadFuture = null;
  }

  void _publishScroll() {
    ShellBus.hubScrollOffsetFor(_pageKey).value =
        _scroll.hasClients ? _scroll.offset : 0;
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
        _error = 'Layout from ${widget.pluginId} is invalid — $invalid';
      });
      return;
    }

    final pages = envelope.data!['pages'] as Map;
    final page = pages[_pageKey] ?? pages.values.first;
    final pageMap = Map<String, dynamic>.from(page as Map);
    _pageUsesFeed = pageMap['feed'] == true;
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
      final first = options.first;
      if (first is Map && first['id'] != null) {
        _moods[id] = first['id'].toString();
      }
    }
    setState(() {
      _loading = false;
      _widgets = widgets;
    });
    if (_pageUsesFeed) {
      unawaited(_ensureFeedLoaded());
    }
    final packSourceUrl = (await PluginRegistry.instance.findPlugin(
      widget.pluginId,
    ))?.pack.sourceUrl;
    if (!mounted) return;
    CatalogVerticalFiltersRegistry.syncFromLayout(
      tabId: _pageKey,
      pluginId: widget.pluginId,
      packSourceUrl: packSourceUrl,
      widgets: widgets,
    );
    _rebindChromeListenable();
    markShellTabFresh();
  }

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    _forceNextRails = force;
    _invalidateRailFutures();
    await _loadLayout(forceRefresh: force);
    if (!mounted) return;
    // Build after layout setState consumes [_forceNextRails] into new futures.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceNextRails = false;
    });
  }

  String _errorMessage(CatalogError? error) {
    if (error == null) return 'Could not load ${widget.pluginId}';
    if (error.message.isNotEmpty) return error.message;
    return switch (error.code) {
      CatalogErrorCode.authRequired => 'Sign in to use this hub',
      CatalogErrorCode.authExpired => 'Session expired — sign in again',
      CatalogErrorCode.rateLimit => 'Rate limited — try again shortly',
      _ => 'Could not load ${widget.pluginId} (${error.code.wire})',
    };
  }

  Future<List<CatalogMetaItem>> _fetchRail(
    Map<String, dynamic> spec, {
    bool forceRefresh = false,
  }) async {
    final action = (spec['action'] ?? 'rail').toString().trim();
    final rawParams = spec['params'];
    final params = <String, dynamic>{
      if (rawParams is Map) ...Map<String, dynamic>.from(rawParams),
      if (spec['rail'] != null) 'rail': spec['rail'],
    };
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
        filters: [...catalogChromeFilters(tabId: widget.tabId, pluginId: widget.pluginId), moodFilter],
      ),
      forceRefresh: forceRefresh,
    );
    if (!envelope.ok) return const [];
    return envelope.items;
  }

  String? _packRailId(Map<String, dynamic> spec) {
    final rail = (spec['rail'] ?? '').toString().trim();
    return rail.isEmpty ? null : rail;
  }

  bool _isPackFeedRail(Map<String, dynamic> spec) {
    if (!_pageUsesFeed) return false;
    if ((spec['moodSource'] ?? '').toString().isNotEmpty) return false;
    final rail = _packRailId(spec);
    return rail != null && _packFeedRailIds.contains(rail);
  }

  String _feedMemoKey() =>
      'feed|${catalogChromeFilterEpoch(widget.tabId)}|$_chromeEpoch';

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
        filters: catalogChromeFilters(tabId: widget.tabId, pluginId: widget.pluginId),
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
    return '$id|$moodSrc|$mood|$chrome|$_chromeEpoch';
  }

  Future<List<CatalogMetaItem>> _itemsForRailSpec(
    Map<String, dynamic> spec, {
    bool forceRefresh = false,
  }) async {
    if (_isPackFeedRail(spec)) {
      final railId = _packRailId(spec)!;
      final feed = await _ensureFeedLoaded(force: forceRefresh);
      return feed[railId] ?? const [];
    }
    return _fetchRail(spec, forceRefresh: forceRefresh);
  }

  /// Same Future across rebuilds until chrome / mood / tab refresh invalidates.
  Future<List<CatalogMetaItem>> _railFuture(Map<String, dynamic> spec) {
    final key = _railMemoKey(spec);
    final force = _forceNextRails;
    return _metaRailFutures.putIfAbsent(
      key,
      () => _itemsForRailSpec(spec, forceRefresh: force),
    );
  }

  Future<void> _openMeta(CatalogMetaItem item) =>
      openCatalogMetaItem(context, pluginId: widget.pluginId, item: item);

  HubListFollowTarget? _listTarget(CatalogMetaItem item) {
    final open = item.open;
    if (open == null) return null;
    switch (open.surface) {
      case 'anime':
        final id = open.idInt;
        if (id == null) return null;
        return HubListFollowTarget.anime(
          anilistId: id,
          title: item.name,
          posterPath: item.poster,
          voteAverage: item.rating ?? 0,
          releaseDate: item.releaseInfo,
        );
      case 'drama':
        final id = open.idInt;
        if (id == null) return null;
        return HubListFollowTarget.drama(
          kisskhId: id,
          title: item.name,
          posterPath: item.poster,
          tmdbId: item.numericId('tmdb'),
          tmdbMediaType: item.tmdbMediaType,
          releaseDate: item.releaseInfo,
        );
      default:
        return null;
    }
  }

  List<HubHeroSlide> _heroSlides(List<CatalogMetaItem> items) {
    return [for (final item in items.take(5)) _heroSlideFor(item)];
  }

  HubHeroSlide _heroSlideFor(CatalogMetaItem item) {
    final status = (item.status ?? '').trim();
    final isUpcoming = status.toUpperCase() == 'NOT_YET_RELEASED';
    final useAniBanner =
        item.open?.surface == 'anime' &&
        item.bannerImage.isNotEmpty &&
        item.background == item.bannerImage;
    final yearBit = item.releaseInfo.isEmpty
        ? null
        : item.releaseInfo.split(' • ').first;
    // Hub-native surfaces: keep pack open + listTarget. Never set [movie]
    // — hub hero has onOpenDetails=null, so a TMDB Movie made View details a
    // silent no-op after spotlight enrich.
    final surface = item.open?.surface;
    final hubNative =
        surface == 'anime' || surface == 'drama' || surface == 'arabic';
    final movie = hubNative ? null : catalogMetaToMovie(item);
    final mediaHint = (item.tmdbMediaType ?? '').trim().toLowerCase();
    final badge = (item.badge ?? '').trim().toUpperCase();
    final tmdbMediaType =
        movie?.mediaType ??
        (mediaHint == 'movie' || mediaHint == 'tv'
            ? mediaHint
            : (badge == 'MOVIE' || badge == 'FILM' || badge == 'HOLLYWOOD'
                  ? 'movie'
                  : 'tv'));
    final tmdbSearch = item.ids['tmdbSearch']?.toString().trim();
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
      badge: item.badge,
      statusChip: status.isEmpty ? null : status.replaceAll('_', ' '),
      isUpcoming: isUpcoming,
      upcomingReleaseLabel: isUpcoming ? yearBit : null,
      genres: item.genres,
      imageFit: useAniBanner ? BoxFit.fitWidth : BoxFit.cover,
      imageAlignment: useAniBanner ? Alignment.center : Alignment.centerRight,
      tmdbId: item.numericId('tmdb') ?? movie?.id,
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
    subtitle: item.releaseInfo.isEmpty ? null : item.releaseInfo,
    rating: item.rating,
    rank: showRank ? index + 1 : null,
    // Anime pre-cutover put format under the title (releaseInfo), not a badge.
    badge: item.type == 'anime' ? null : item.badge,
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

  /// Chrome leaf that should hide `hideWhenTypeFilter` rails (and their bleed).
  bool _chromeHidesTypeFilterRail() {
    final chrome = catalogChromeFilters(
      tabId: widget.tabId,
      pluginId: widget.pluginId,
    );
    return chrome.any((f) => f != null);
  }

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
  }) {
    final orders = <String, int>{};
    var order = 0;

    // Hero bleed row (Featured under spotlight) is always the first catalog row.
    if (bleedSpec != null) {
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
  }) {
    final id = (spec['id'] ?? '').toString();
    final mood = _moods[(spec['moodSource'] ?? '').toString()] ?? '';
    final chrome = catalogChromeFilterEpoch(widget.tabId);
    final aspect = _aspectOf(spec);
    final numbered = showRank || _isNumbered(spec);
    if (_isVertical(spec)) {
      return _VerticalHubRail(
        key: ValueKey('vhub:$id:$mood:$chrome:$_chromeEpoch'),
        title: (spec['title'] ?? '').toString(),
        future: _railFuture(spec),
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
      key: ValueKey('$id:$mood:$chrome:$_chromeEpoch'),
      title: (spec['title'] ?? '').toString(),
      future: _railFuture(spec),
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

  Future<List<CatalogMetaItem>> _fetchMoodRail(Map<String, dynamic> moodSpec) {
    final rail = (moodSpec['rail'] ?? 'discover').toString();
    return _railFuture({
      ...moodSpec,
      'type': 'rail',
      'id': '${moodSpec['id']}_results',
      'rail': rail,
      'moodSource': moodSpec['id'],
      'title': '',
    });
  }

  Widget _heroSection(
    Map<String, dynamic> spec, {
    Widget? pageBottomChild,
    String? bleedRowId,
  }) {
    final chrome = catalogChromeFilterEpoch(widget.tabId);
    return _CatalogHeroSection(
      key: ValueKey('hero:$chrome:$_chromeEpoch'),
      future: _railFuture(spec),
      buildSlides: _heroSlides,
      tvTabId: widget.tabId ?? 'home',
      scrollController: _scroll,
      pageBottomChild: pageBottomChild,
      bleedRowId: bleedRowId,
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

  Color _moodAccent(String? hex) {
    final raw = (hex ?? '').trim().replaceFirst('#', '');
    if (raw.length != 6) return ForjaShellColors.sectionAccent;
    final v = int.tryParse(raw, radix: 16);
    if (v == null) return ForjaShellColors.sectionAccent;
    return Color(0xFF000000 | v);
  }

  Widget _moodSection(Map<String, dynamic> spec, {required int tvRowOrder}) {
    final id = (spec['id'] ?? 'mood').toString();
    final title = (spec['title'] ?? 'Moods').toString();
    final chipRowId = '$id-chips';
    final resultsRowId = '$id-results';
    final options = [
      for (final o in (spec['options'] as List? ?? const []))
        if (o is Map) Map<String, dynamic>.from(o),
    ];
    if (options.isEmpty) return const SizedBox.shrink();
    final selected = _moods[id] ?? options.first['id']?.toString() ?? '';
    if (_moods[id] == null && selected.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _moods[id] != null) return;
        setState(() => _moods[id] = selected);
      });
    }
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
                        horizontal: shellHomeSectionHorizontalPadding(context),
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
              separatorBuilder: (_, _) => SizedBox(width: layout.horizontalGap),
              itemBuilder: (context, i) => moodChip(layout: layout, i: i),
            );
          },
        ),
        if (resultsRail.isNotEmpty) ...[
          const SizedBox(height: 16),
          HubCatalogSection<CatalogMetaItem>(
            key: ValueKey('mood-results:$id:$selected:$_chromeEpoch'),
            title: '',
            future: _fetchMoodRail({...spec, 'id': id}),
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

  String _layoutWidgetType(Map<String, dynamic> spec) {
    return switch ((spec['type'] ?? '').toString().trim()) {
      'host.continue' => 'continue',
      'host.because' => 'because',
      'host.trakt' => 'trakt',
      'host.vertical_filters' => 'vertical_filters',
      _ => (spec['type'] ?? '').toString().trim(),
    };
  }

  Widget? _widgetFor(
    Map<String, dynamic> spec, {
    Widget? heroBleedChild,
    String? heroBleedRowId,
    required Map<String, int> tvOrders,
  }) {
    final id = (spec['id'] ?? '').toString();
    switch (_layoutWidgetType(spec)) {
      case 'hero':
        return _heroSection(
          spec,
          pageBottomChild: heroBleedChild,
          bleedRowId: heroBleedRowId,
        );
      case 'rail':
        return _railSection(spec, tvRowOrder: _tvOrder(tvOrders, id));
      case 'ranked':
        return _railSection(
          spec,
          showRank: true,
          tvRowOrder: _tvOrder(tvOrders, id),
        );
      case 'mood':
        return _moodSection(spec, tvRowOrder: _tvOrder(tvOrders, '$id-chips'));
      case 'continue':
        return CatalogContinueWidget(
          pluginId: widget.pluginId,
          tabId: widget.tabId ?? 'home',
          tvRowOrder: _tvOrder(tvOrders, id),
        );
      case 'because':
        return CatalogBecauseSection(
          pluginId: widget.pluginId,
          tabId: widget.tabId ?? 'home',
          spec: spec,
          tvRowOrder: _tvOrder(tvOrders, id),
        );
      case 'trakt':
        return CatalogHostTrakt(
          tabId: widget.tabId ?? 'home',
          tvRowOrderBase: _tvOrder(tvOrders, id),
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
      if (_loading && _widgets.isEmpty) {
        return homeLoadingShimmer(homeMovieRowSkeleton(context));
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
      final tvOrders = _planTvRowOrders(bleedSpec: bleed, bleedId: bleedId);
      final bleedRowId = bleed == null ? null : (bleed['id'] ?? '').toString();
      final Widget? bleedChild = bleed == null
          ? null
          : HubCatalogSection<CatalogMetaItem>(
              key: ValueKey('bleed:${bleed['id']}:$_chromeEpoch'),
              title: (bleed['title'] ?? '').toString(),
              future: _railFuture(bleed),
              showRank: _isNumbered(bleed),
              compactTop: true,
              cardAspect: _aspectOf(bleed),
              tvTabId: widget.tabId,
              tvRowId: bleedRowId,
              tvRowOrder: _tvOrder(tvOrders, bleedRowId ?? ''),
              tvFocusUp: _focusHeroPlay,
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
      for (final spec in _widgets) {
        final type = (spec['type'] ?? '').toString();
        final id = (spec['id'] ?? '').toString();
        final rail = (spec['rail'] ?? '').toString();
        if (bleedSpec != null &&
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
        );
        if (w != null) sections.add(w);
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

    return ColoredBox(color: AppTheme.bgDark, child: body);
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
  });

  final Future<List<CatalogMetaItem>> future;
  final List<HubHeroSlide> Function(List<CatalogMetaItem>) buildSlides;
  final String tvTabId;
  final ScrollController scrollController;
  final Widget? pageBottomChild;
  final String? bleedRowId;

  @override
  State<_CatalogHeroSection> createState() => _CatalogHeroSectionState();
}

class _CatalogHeroSectionState extends State<_CatalogHeroSection> {
  List<CatalogMetaItem>? _items;
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
      final items = await widget.future;
      if (!mounted || gen != _gen) return;
      setState(() => _items = items);
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
      // Empty rail — don't infinite-shimmer the hub (looks like a hung load).
      return widget.pageBottomChild ?? const SizedBox.shrink();
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
    required this.future,
    required this.cardBuilder,
    this.showRank = false,
    this.aspect = HubPosterAspect.portrait,
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
  });

  final String title;
  final Future<List<CatalogMetaItem>> future;
  final HubPosterCard Function(BuildContext, CatalogMetaItem, int) cardBuilder;
  final bool showRank;
  final HubPosterAspect aspect;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;

  @override
  State<_VerticalHubRail> createState() => _VerticalHubRailState();
}

class _VerticalHubRailState extends State<_VerticalHubRail> {
  List<CatalogMetaItem>? _last;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CatalogMetaItem>>(
      future: widget.future,
      builder: (context, snap) {
        if (snap.hasData) _last = snap.data;
        final items = snap.data ?? _last ?? const <CatalogMetaItem>[];
        if (items.isEmpty) {
          if (snap.connectionState == ConnectionState.waiting) {
            return homeLoadingShimmer(homeMovieRowSkeleton(context));
          }
          return const SizedBox.shrink();
        }
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
