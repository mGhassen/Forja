import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/home/widgets/home_movie_section.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/hero/cinematic_hero.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/home_movie_card.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/shell_mood_circle.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:rust/rust.dart';

import '../filter.dart';
import '../plugin_nav.dart';
import '../protocol.dart';
import '../runtime.dart';
import 'catalog_chrome_filters.dart';
import 'catalog_host_because.dart';
import 'catalog_host_continue.dart';
import 'catalog_host_genre_rows.dart';
import 'catalog_host_home_mood.dart';
import 'catalog_host_popular_asian.dart';
import 'catalog_host_trakt.dart';
import 'catalog_meta_movie.dart';
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

  Listenable? _chromeListenable;

  @override
  bool get wantKeepAlive => true;

  String get _pageKey {
    final id = widget.tabId?.trim();
    return (id == null || id.isEmpty) ? 'home' : id;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_publishScroll);
    _chromeListenable = catalogChromeFilterListenable(widget.tabId);
    _chromeListenable?.addListener(_onChromeFilterChanged);
    unawaited(_loadLayout());
  }

  @override
  void dispose() {
    _chromeListenable?.removeListener(_onChromeFilterChanged);
    _scroll.removeListener(_publishScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onChromeFilterChanged() {
    if (!mounted) return;
    setState(() => _chromeEpoch++);
  }

  void _publishScroll() {
    final n = switch (widget.tabId) {
      'anime' => ShellBus.animeScrollOffset,
      'asian_drama' => ShellBus.asianDramaScrollOffset,
      'home' => ShellBus.homeScrollOffset,
      'arabic' => ShellBus.arabicScrollOffset,
      _ => null,
    };
    n?.value = _scroll.hasClients ? _scroll.offset : 0;
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

    final enabled =
        await PluginNavRegistry.isHubPluginEnabled(widget.pluginId);
    if (!mounted) return;
    if (!enabled) {
      setState(() {
        _loading = false;
        _widgets = const [];
        _error =
            'This hub plugin is off. Enable it under Settings → Sources → Forja (Hubs). '
            'To hide the tab, use Settings → Features.';
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
    final rawWidgets = (page as Map)['widgets'] as List;
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
    markShellTabFresh();
  }

  @override
  Future<void> onShellTabRefresh({required bool force}) =>
      _loadLayout(forceRefresh: force);

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

  Future<List<CatalogMetaItem>> _fetchRail(Map<String, dynamic> spec) async {
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
      moodFilter ??=
          catalogFilterFromSelection(field: 'genre', value: moodId);
    }
    final envelope = await CatalogRuntime.instance.run(
      pluginId: widget.pluginId,
      action: action,
      params: catalogParamsWithFilters(
        params,
        filters: [
          ...catalogChromeFilters(widget.tabId),
          moodFilter,
        ],
      ),
    );
    if (!envelope.ok) return const [];
    return envelope.items;
  }

  Future<void> _openMeta(CatalogMetaItem item) => openCatalogMetaItem(
        context,
        pluginId: widget.pluginId,
        item: item,
      );

  HubListFollowTarget? _listTarget(CatalogMetaItem item) {
    switch (item.type) {
      case 'anime':
        final id = item.numericId('anilist');
        if (id == null) return null;
        return HubListFollowTarget.anime(
          anilistId: id,
          title: item.name,
          posterPath: item.poster,
          voteAverage: item.rating ?? 0,
          releaseDate: item.releaseInfo,
        );
      case 'drama':
        final id = item.numericId('kisskh');
        if (id == null) return null;
        return HubListFollowTarget.drama(
          kisskhId: id,
          title: item.name,
          posterPath: item.poster,
          tmdbId: item.numericId('tmdb'),
          releaseDate: item.releaseInfo,
        );
      default:
        return null;
    }
  }

  List<HubHeroSlide> _heroSlides(List<CatalogMetaItem> items) {
    return [
      for (final item in items.take(5))
        HubHeroSlide(
          id: item.id,
          title: item.name,
          imageUrl: item.background.isNotEmpty ? item.background : item.poster,
          overview: item.description,
          rating: item.rating,
          year: item.releaseInfo.isEmpty ? null : item.releaseInfo,
          badge: item.badge,
          genres: item.genres,
          tmdbId: item.numericId('tmdb'),
          tmdbMediaType: item.type == 'movie' ? 'movie' : 'tv',
          listTarget: _listTarget(item),
          onDetails: () => unawaited(_openMeta(item)),
        ),
    ];
  }

  HubPosterCard _card(
    BuildContext context,
    CatalogMetaItem item,
    int index, {
    bool showRank = false,
    String? rowId,
    HubPosterAspect aspect = HubPosterAspect.portrait,
  }) =>
      HubPosterCard(
        imageUrl: item.poster,
        title: item.name,
        subtitle: item.releaseInfo.isEmpty ? null : item.releaseInfo,
        rating: item.rating,
        rank: showRank ? index + 1 : null,
        badge: item.badge,
        listIndex: index,
        listTarget: _listTarget(item),
        tvTabId: widget.tabId,
        tvRowId: rowId,
        aspect: aspect,
        onTap: () => unawaited(_openMeta(item)),
      );

  HubPosterAspect _aspectOf(Map<String, dynamic> spec) {
    final a = (spec['aspect'] ?? '').toString().trim().toLowerCase();
    return a == 'landscape' ? HubPosterAspect.landscape : HubPosterAspect.portrait;
  }

  bool get _fullHeroBleed => hubIsFullCinematicHero(context);

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

  bool get _isHomeTab => widget.tabId == 'home' || widget.tabId == null;

  Future<List<Movie>> _fetchHomeMovies(Map<String, dynamic> spec) async {
    final items = await _fetchRail(spec);
    return catalogMetasToMovies(items);
  }

  Widget _homeMovieRail(Map<String, dynamic> spec, {bool compactTop = false}) {
    final id = (spec['id'] ?? '').toString();
    final title = (spec['title'] ?? '').toString();
    final numbered = _isNumbered(spec);
    final chrome = catalogChromeFilterEpoch(widget.tabId);
    if (_isVertical(spec)) {
      return _VerticalHomeMovieRail(
        key: ValueKey('vrail:$id:$chrome:$_chromeEpoch'),
        title: title,
        future: _fetchHomeMovies(spec),
        showRank: numbered,
        compactTop: compactTop,
        tvRowId: id,
        onMovieTap: (m) => AppRouter.openDetails(context, movie: m),
      );
    }
    return HomeMovieSection(
      key: ValueKey('hrail:$id:$chrome:$_chromeEpoch'),
      title: title,
      future: _fetchHomeMovies(spec),
      onMovieTap: (m) => AppRouter.openDetails(context, movie: m),
      compactTop: compactTop,
      showRank: numbered,
      tvRowId: id,
    );
  }

  Future<List<CatalogMetaItem>> _fetchMoodRail(Map<String, dynamic> moodSpec) {
    final rail = (moodSpec['rail'] ?? 'discover').toString();
    return _fetchRail({
      ...moodSpec,
      'type': 'rail',
      'id': '${moodSpec['id']}_results',
      'rail': rail,
      'moodSource': moodSpec['id'],
      'title': '',
    });
  }

  Widget _railSection(Map<String, dynamic> spec, {bool showRank = false}) {
    if (_isHomeTab) {
      return _homeMovieRail(spec);
    }
    final id = (spec['id'] ?? '').toString();
    final mood = _moods[(spec['moodSource'] ?? '').toString()] ?? '';
    final chrome = catalogChromeFilterEpoch(widget.tabId);
    final aspect = _aspectOf(spec);
    final numbered = showRank || _isNumbered(spec);
    if (_isVertical(spec)) {
      return _VerticalHubRail(
        key: ValueKey('vhub:$id:$mood:$chrome:$_chromeEpoch'),
        title: (spec['title'] ?? '').toString(),
        future: _fetchRail(spec),
        showRank: numbered,
        aspect: aspect,
        tvTabId: widget.tabId,
        tvRowId: id,
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
      future: _fetchRail(spec),
      showRank: numbered,
      cardAspect: aspect,
      tvTabId: widget.tabId,
      tvRowId: id,
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
  }) {
    final chrome = catalogChromeFilterEpoch(widget.tabId);
    return _CatalogHeroSection(
      key: ValueKey('hero:$chrome:$_chromeEpoch'),
      future: _fetchRail(spec),
      buildSlides: _heroSlides,
      tvTabId: widget.tabId ?? 'home',
      scrollController: _scroll,
      pageBottomChild: pageBottomChild,
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

  Widget _moodSection(Map<String, dynamic> spec) {
    final id = (spec['id'] ?? 'mood').toString();
    final title = (spec['title'] ?? 'Moods').toString();
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
            final row = Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0) SizedBox(width: layout.horizontalGap),
                  ShellMoodCircleItem(
                    layout: layout,
                    label: (options[i]['label'] ?? options[i]['id'] ?? '')
                        .toString(),
                    icon: _moodIcon(options[i]['icon']?.toString()),
                    accent: _moodAccent(options[i]['accent']?.toString()),
                    selected: options[i]['id']?.toString() == selected,
                    listIndex: i,
                    tvTabId: widget.tabId,
                    tvRowId: id,
                    onTap: () => setState(() {
                      _moods[id] = options[i]['id']?.toString() ?? '';
                    }),
                  ),
                ],
              ],
            );
            if (layout.contentWidth(options.length) <= constraints.maxWidth) {
              return Center(child: row);
            }
            return HorizontalScroller(
              height: layout.rowHeight,
              padding: EdgeInsets.symmetric(
                horizontal: shellHomeSectionHorizontalPadding(context),
              ),
              itemCount: options.length,
              separatorBuilder: (_, _) => SizedBox(width: layout.horizontalGap),
              itemBuilder: (context, i) => ShellMoodCircleItem(
                layout: layout,
                label:
                    (options[i]['label'] ?? options[i]['id'] ?? '').toString(),
                icon: _moodIcon(options[i]['icon']?.toString()),
                accent: _moodAccent(options[i]['accent']?.toString()),
                selected: options[i]['id']?.toString() == selected,
                listIndex: i,
                tvTabId: widget.tabId,
                tvRowId: id,
                onTap: () => setState(() {
                  _moods[id] = options[i]['id']?.toString() ?? '';
                }),
              ),
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
            tvRowId: '$id-results',
            cardBuilder: (context, item, index) => _card(
              context,
              item,
              index,
              rowId: '$id-results',
            ),
          ),
        ],
      ],
    );
  }

  Widget? _widgetFor(
    Map<String, dynamic> spec, {
    Widget? heroBleedChild,
  }) {
    switch ((spec['type'] ?? '').toString().trim()) {
      case 'hero':
        return _heroSection(spec, pageBottomChild: heroBleedChild);
      case 'rail':
        return _railSection(spec);
      case 'ranked':
        return _railSection(spec, showRank: true);
      case 'mood':
        if (_isHomeTab) {
          final options = [
            for (final o in (spec['options'] as List? ?? const []))
              if (o is Map) Map<String, dynamic>.from(o),
          ];
          return CatalogHostHomeMood(
            options: options,
            title: (spec['title'] ?? "What's your mood?").toString(),
            tvRowOrder: 3,
          );
        }
        return _moodSection(spec);
      case 'host.continue':
        return CatalogHostContinue(
          tabId: widget.tabId ?? 'home',
          tvRowOrder: _isHomeTab ? 2 : 1,
        );
      case 'host.popular_asian':
        return const CatalogHostPopularAsian();
      case 'host.because':
        return _isHomeTab ? const CatalogHostBecause() : null;
      case 'host.trakt':
        return _isHomeTab ? const CatalogHostTrakt() : null;
      case 'host.genre_rows':
        return _isHomeTab ? const CatalogHostGenreRows() : null;
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
              bleedSpec = w;
              break;
            }
          }
        }
      }
      final bleed = bleedSpec;
      final Widget? bleedChild = bleed == null
          ? null
          : (_isHomeTab
              ? _homeMovieRail(bleed, compactTop: true)
              : HubCatalogSection<CatalogMetaItem>(
                  key: ValueKey('bleed:${bleed['id']}:$_chromeEpoch'),
                  title: (bleed['title'] ?? '').toString(),
                  future: _fetchRail(bleed),
                  showRank: _isNumbered(bleed),
                  compactTop: true,
                  cardAspect: _aspectOf(bleed),
                  tvTabId: widget.tabId,
                  tvRowId: (bleed['id'] ?? '').toString(),
                  cardBuilder: (context, item, index) => _card(
                    context,
                    item,
                    index,
                    showRank: _isNumbered(bleed),
                    rowId: (bleed['id'] ?? '').toString(),
                    aspect: _aspectOf(bleed),
                  ),
                ));

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
        if (spec['hideWhenTypeFilter'] == true) {
          final chrome = catalogChromeFilters(widget.tabId);
          final hasType = chrome.any(
            (f) =>
                f != null &&
                ((f['field'] ?? '').toString() == 'type') &&
                f['value'] != null,
          );
          if (hasType) continue;
        }
        final w = _widgetFor(
          spec,
          heroBleedChild: type == 'hero' ? bleedChild : null,
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
  });

  final Future<List<CatalogMetaItem>> future;
  final List<HubHeroSlide> Function(List<CatalogMetaItem>) buildSlides;
  final String tvTabId;
  final ScrollController scrollController;
  final Widget? pageBottomChild;

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
    try {
      final items = await widget.future;
      if (!mounted || gen != _gen) return;
      setState(() => _items = items);
    } catch (_) {
      if (!mounted || gen != _gen) return;
      setState(() => _items = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return homeCinematicHeroShimmer(context);
    }
    if (items.isEmpty) return const SizedBox.shrink();
    final bottom = widget.pageBottomChild;
    return HomeCinematicHero.hub(
      slides: widget.buildSlides(items),
      tvTabId: widget.tvTabId,
      scrollController: widget.scrollController,
      pageBottomChild: bottom,
      firstCatalogRowHeight: bottom == null
          ? null
          : HomeMovieSection.sectionHeight(context, compactTop: true),
    );
  }
}

class _VerticalHomeMovieRail extends StatelessWidget {
  const _VerticalHomeMovieRail({
    super.key,
    required this.title,
    required this.future,
    required this.onMovieTap,
    this.showRank = false,
    this.compactTop = false,
    this.tvRowId,
  });

  final String title;
  final Future<List<Movie>> future;
  final void Function(Movie) onMovieTap;
  final bool showRank;
  final bool compactTop;
  final String? tvRowId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return homeLoadingShimmer(
            homeMovieRowSkeleton(context, compactTop: compactTop),
          );
        }
        final movies = snap.data ?? const <Movie>[];
        if (movies.isEmpty) return const SizedBox.shrink();
        final pad = shellHomeSectionHorizontalPadding(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShellSectionTitle(
              title: title,
              padding: shellHomeSectionTitlePadding(
                context,
                top: compactTop
                    ? shellSectionTitleTopCompact(context)
                    : shellHomeSectionTitleTop(context),
              ),
            ),
            for (var i = 0; i < movies.length; i++)
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, shellMovieCardRowGap(context)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: HomeMovieCard(
                    movie: movies[i],
                    onTap: () => onMovieTap(movies[i]),
                    rank: showRank ? i + 1 : null,
                    listIndex: i,
                    tvTabId: 'home',
                    tvRowId: tvRowId,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VerticalHubRail extends StatelessWidget {
  const _VerticalHubRail({
    super.key,
    required this.title,
    required this.future,
    required this.cardBuilder,
    this.showRank = false,
    this.aspect = HubPosterAspect.portrait,
    this.tvTabId,
    this.tvRowId,
  });

  final String title;
  final Future<List<CatalogMetaItem>> future;
  final HubPosterCard Function(BuildContext, CatalogMetaItem, int) cardBuilder;
  final bool showRank;
  final HubPosterAspect aspect;
  final String? tvTabId;
  final String? tvRowId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CatalogMetaItem>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return homeLoadingShimmer(homeMovieRowSkeleton(context));
        }
        final items = snap.data ?? const <CatalogMetaItem>[];
        if (items.isEmpty) return const SizedBox.shrink();
        final pad = shellHomeSectionHorizontalPadding(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShellSectionTitle(
              title: title,
              padding: shellHomeSectionTitlePadding(context),
            ),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  0,
                  pad,
                  showRank
                      ? shellScaled(context, 6).clamp(3.0, 6.0)
                      : shellMovieCardRowGap(context),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: cardBuilder(context, items[i], i),
                ),
              ),
          ],
        );
      },
    );
  }
}
