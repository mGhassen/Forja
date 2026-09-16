import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/portals/guide/portal_channel_guide_open.dart';
import 'package:forja/shared/engine/runtime/kit/focus_edge.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_feed.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_tree.dart';
import 'package:forja/shared/engine/runtime/kit/row_prefetch.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/chrome/vertical_filters_rail.dart';
import 'package:forja/shell/routing/shell_tab_refresh.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/protocol/protocol.dart';
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
  String _viewStyle = '';
  final Map<String, List<Map<String, dynamic>>> _dynamicBarItems = {};
  final ValueNotifier<Map<String, dynamic>?> _selectedListItem =
      ValueNotifier<Map<String, dynamic>?>(null);
  bool _layoutRtl = false;
  String? _error;
  bool _loading = true;
  final ScrollController _scroll = ScrollController();

  Set<String> _eagerLoadKeys = const {};
  Set<String> _pageFeedRailIds = const {};
  Future<Map<String, List<dynamic>>>? _pageFeedFuture;
  Listenable? _filterListenable;
  final KitRowPrefetchLane _rowPrefetch = KitRowPrefetchLane();

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
    unawaited(_loadPage());
  }

  @override
  void didUpdateWidget(covariant PackLayoutPainter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pluginId != widget.pluginId ||
        oldWidget.tabId != widget.tabId ||
        oldWidget.packSourceUrl != widget.packSourceUrl ||
        oldWidget.pageAction != widget.pageAction) {
      unawaited(_loadPage(force: true));
    }
  }

  @override
  void dispose() {
    _filterListenable?.removeListener(_onChromeFiltersChanged);
    PluginRegistry.hubFeedEpoch.removeListener(_onHubFeedEpoch);
    _scroll.removeListener(_publishScroll);
    _scroll.dispose();
    _selectedListItem.dispose();
    final tab = widget.tabId?.trim();
    if (tab != null && tab.isNotEmpty) {
      VerticalFiltersRegistry.unregister(tab);
      ShellBus.hubScrollOffsetFor(tab).value = 0;
    }
    super.dispose();
  }

  void _rebindChromeFilters() {
    _filterListenable?.removeListener(_onChromeFiltersChanged);
    _filterListenable = catalogChromeFilterListenable(_pageKey);
    _filterListenable?.addListener(_onChromeFiltersChanged);
  }

  void _onChromeFiltersChanged() {
    if (!mounted || _pageFeedRailIds.isEmpty) return;
    setState(() {
      _pageFeedFuture = _fetchPageFeed(forceRefresh: false);
    });
  }

  void _onHubFeedEpoch() {
    if (!mounted) return;
    if (!PluginRegistry.hubFeedEpochTouches(widget.pluginId)) return;
    // Soft reload — keep painted rails while pack settings / scripts refresh.
    unawaited(_loadPage(force: true, keepPainted: true));
  }

  void _publishScroll() {
    if (_pageKey.isEmpty) return;
    ShellBus.hubScrollOffsetFor(_pageKey).value =
        _scroll.hasClients ? _scroll.offset : 0;
  }

  @override
  Future<void> onShellTabRefresh({required bool force}) =>
      _loadPage(force: force);

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

    final params = <String, dynamic>{
      ...?widget.pageParams,
      ...?PluginNavRegistry.pageParamsForTab(_pageKey),
      'page': _pageKey,
    };

    final envelope = await packOpaqueRun(
      pluginId: widget.pluginId,
      action: action,
      params: params,
      packSourceUrl: widget.packSourceUrl,
      forceRefresh: force,
    );
    if (!mounted) return;

    if (!envelope.ok) {
      setState(() {
        _loading = false;
        _error = envelope.error?.message.isNotEmpty == true
            ? envelope.error!.message
            : 'Pack page load failed.';
      });
      return;
    }

    final invalid = validateLayoutData(envelope.data);
    if (invalid != null) {
      setState(() {
        _loading = false;
        _error = 'This hub’s layout is invalid.';
      });
      return;
    }

    final data = envelope.data!;
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

    final eager = {
      ..._firstPaintEagerKeys(widgets),
      // Pack `feedRails` = first-paint batch — keep those gates eager so tab
      // show does not flash LazyViewportGate placeholders.
      if (pageMap != null) ...catalogLayoutFeedRailIds(pageMap),
    };
    final feedIds = _feedRailIdsForPage(pageMap, widgets);
    Future<Map<String, List<dynamic>>>? feedFuture;
    if (feedIds.isNotEmpty) {
      // Reuse in-flight / completed page feed when layout soft-reloads so
      // PackLoadedPaint does not remount every rail (skeleton flash).
      if (!force &&
          _pageFeedFuture != null &&
          setEquals(feedIds, _pageFeedRailIds)) {
        feedFuture = _pageFeedFuture;
      } else {
        feedFuture = _fetchPageFeed(forceRefresh: force);
      }
    }

    setState(() {
      _loading = false;
      _error = null;
      _widgets = widgets;
      _layoutRtl = catalogLayoutIsRtl(data);
      _eagerLoadKeys = eager;
      _pageFeedRailIds = feedIds;
      _pageFeedFuture = feedFuture;
      _rowPrefetch.reset();
      initLayoutTabSelections(_layoutSelections, widgets);
    });
    _rebindChromeFilters();
    final tab = widget.tabId?.trim();
    if (tab != null && tab.isNotEmpty) {
      VerticalFiltersRegistry.syncFromLayout(
        tabId: tab,
        pluginId: widget.pluginId,
        packSourceUrl: widget.packSourceUrl,
        widgets: widgets,
      );
    }
    markShellTabFresh();
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

  Future<Map<String, List<dynamic>>> _fetchPageFeed({
    required bool forceRefresh,
  }) async {
    final envelope = await packOpaqueRun(
      pluginId: widget.pluginId,
      packSourceUrl: widget.packSourceUrl,
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
    final rails = envelope.data?['rails'];
    if (rails is! Map) return const {};
    final out = <String, List<dynamic>>{};
    for (final e in rails.entries) {
      final key = e.key.toString();
      final items = e.value;
      if (items is! List) continue;
      out[key] = List<dynamic>.from(items);
    }
    return out;
  }

  void _onLayoutSelect(String widgetId, String value, {required bool toggle}) {
    setState(() {
      if (toggle && _layoutSelections[widgetId] == value) {
        _layoutSelections.remove(widgetId);
      } else {
        _layoutSelections[widgetId] = value;
      }
      if (widgetId == 'view') {
        _viewStyle = value;
      }
    });
  }

  Widget _wrapLayoutScope(Widget child) {
    return PackChromeScope(
      eventQuery: _eventQuery,
      refreshEpoch: _refreshEpoch,
      viewStyle: _viewStyle,
      dynamicBarItems: Map<String, List<Map<String, dynamic>>>.unmodifiable(
        Map<String, List<Map<String, dynamic>>>.from(_dynamicBarItems),
      ),
      selectedListItem: _selectedListItem,
      shellTabVisible: shellTabVisible,
      eagerLoadKeys: _eagerLoadKeys,
      pageFeedRailIds: _pageFeedRailIds,
      pageFeedFuture: _pageFeedFuture,
      rowPrefetch: _rowPrefetch,
      onEventQuery: (q) {
        if (_eventQuery == q) return;
        setState(() => _eventQuery = q);
      },
      onBumpRefresh: () {
        _selectedListItem.value = null;
        PortalChannelGuideOpen.invalidateLiveCatalog();
        setState(() {
          _refreshEpoch++;
          if (_pageFeedRailIds.isNotEmpty) {
            _pageFeedFuture = _fetchPageFeed(forceRefresh: true);
          }
        });
        unawaited(onShellTabRefresh(force: true));
      },
      onViewStyle: (style) {
        if (_viewStyle == style) return;
        setState(() {
          _viewStyle = style;
          _layoutSelections['view'] = style;
        });
      },
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
        focusEdge: (rowId, {last = false}) =>
            kitFocusEdge(_pageKey, rowId, last: last),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _widgets.isEmpty) {
      return _hubPageLoadingSkeleton(context);
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
    if (tab.isNotEmpty && VerticalFiltersRegistry.hasFilters(tab)) {
      result = Stack(
        clipBehavior: Clip.none,
        children: [
          result,
          Positioned(
            key: ValueKey('kit-vf-rail-$tab'),
            left: ShellTokens.shellProviderRailInset,
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
    return result;
  }

  /// Expand stack / kit.list roots need a bounded Column — not SliverToBoxAdapter.
  Widget _pageBody() {
    final fullPage = _fullPageBody();
    if (fullPage != null) return fullPage;
    final sections = _composeSections();
    return CatalogBody(
      controller: _scroll,
      bottomGap: ShellTokens.homeRowSpacing,
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
    // Fresh claim order for LazyViewportGate slots this frame.
    _rowPrefetch.reset();
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
          PackPaintTree(
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
        );
        continue;
      }
      out.add(
        PackPaintTree(
          spec: w,
          pluginId: widget.pluginId,
          packSourceUrl: widget.packSourceUrl,
          tabId: _pageKey,
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
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(covariant PackLayoutPainterLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId != widget.tabId) unawaited(_resolve());
  }

  Future<void> _resolve() async {
    setState(() => _loading = true);
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
      return _hubPageLoadingSkeleton(context);
    }
    final id = _pluginId?.trim() ?? '';
    if (id.isEmpty) {
      return const Center(child: Text('No hub pack for this tab.'));
    }
    return PackLayoutPainter(
      pluginId: id,
      tabId: widget.tabId,
      packSourceUrl: _packSourceUrl,
    );
  }
}

/// Pre-wipe light full-page skeleton (hero + continue + poster rows).
Widget _hubPageLoadingSkeleton(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final compact = size.width < ShellTokens.heroDesktopMinBodyWidth;
  final heroH = homeCinematicHeroBodyHeight(
    screenHeight: size.height,
    compact: compact,
    pageBottomBleed: true,
  );
  return ColoredBox(
    color: ForjaShellColors.bgDark,
    child: CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: homeHubLoadingSlivers(
        heroShimmer: homeCinematicHeroShimmer(height: heroH),
      ),
    ),
  );
}

/// Backward-compatible aliases while call sites migrate.
typedef PackLayoutHost = PackLayoutPainter;
typedef PackLayoutHostLoader = PackLayoutPainterLoader;
