import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/features/my_list/providers/my_list_providers.dart';
import 'package:rust/rust.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/movie_poster_card.dart';
import 'package:forja/shared/widgets/my_list_button.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

class MyListScreen extends ConsumerStatefulWidget {
  const MyListScreen({super.key});

  @override
  ConsumerState<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends ConsumerState<MyListScreen>
    with ShellTabRefresh<MyListScreen> {
  final TmdbApi _api = TmdbApi();
  final _scroll = ScrollController();
  final FocusNode _filmsFocus = FocusNode(debugLabel: 'mylist-films');

  static const _tabId = 'mylist';
  static const _kindRowId = 'kind';
  static const _tabsRowId = 'tabs';
  static const _gridRowId = 'grid';

  static const _tabs = [
    (id: 'plantowatch', title: 'Plan to Watch'),
    (id: 'watching', title: 'Watching'),
    (id: 'hold', title: 'On Hold'),
    (id: 'completed', title: 'Completed'),
    (id: 'dropped', title: 'Dropped'),
  ];

  String _status = 'plantowatch';
  String? _kind;

  @override
  Duration get shellStaleAfter => ShellTokens.tabStaleDefault;

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    if (!mounted) return;
    ref.invalidate(myListRevisionProvider);
    ref.invalidate(simklWatchlistProvider);
  }

  @override
  void initState() {
    super.initState();
    TvHeroActions.bind(
      _tabId,
      enterFromNavFocus: _focusEntry,
      restoreFocus: () {
        if (_focusRow(_kindRowId, 0)) return true;
        if (_focusRow(_tabsRowId, 0)) return true;
        return _focusRow(_gridRowId, 0);
      },
    );
    markShellTabFresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _filmsFocus.dispose();
    ShellTvFocusCoordinator.clearTab(_tabId);
    super.dispose();
  }

  bool _focusRow(String rowId, int index) =>
      ShellTvFocusCoordinator.focusRowItem(_tabId, rowId, index);

  bool _focusRowLast(String rowId) {
    final handle = ShellTvFocusCoordinator.rowHandle(_tabId, rowId);
    if (handle == null || handle.itemCount <= 0) return false;
    final idx = handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
    return _focusRow(rowId, idx);
  }

  void _focusEntry() {
    bool tryFocus() {
      if (_filmsFocus.context != null && _filmsFocus.canRequestFocus) {
        _filmsFocus.requestFocus();
        return true;
      }
      return _focusRow(_kindRowId, 0);
    }

    if (tryFocus()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ShellTvFocus.currentNavTabId != _tabId) return;
      tryFocus();
    });
  }

  void _selectStatus(String id) {
    if (_status == id) return;
    setState(() => _status = id);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toggleKind(String kind) {
    setState(() => _kind = _kind == kind ? null : kind);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    if (!mounted) return;
    if (item['source'] == 'simkl') {
      await _openSimklItem(item);
      return;
    }

    final source = item['source']?.toString() ?? 'tmdb';
    final tmdbId = item['tmdbId'] as int?;
    final imdbId = item['imdbId']?.toString();
    final title = item['title']?.toString() ?? 'Unknown';
    final poster = item['posterPath']?.toString() ?? '';
    final mediaType = item['mediaType']?.toString() ?? 'movie';
    final anilistId = item['anilistId'] as int?;
    final kisskhId = item['kisskhId'] as int?;

    final pluginId = item['pluginId']?.toString();
    final storedOpen = CatalogOpen.fromJson(item['catalogOpen']);
    if (pluginId != null && storedOpen != null && mounted) {
      await openCatalogMetaItem(
        context,
        pluginId: pluginId,
        item: CatalogMetaItem(
          id: item['metaId']?.toString() ??
              item['uniqueId']?.toString() ??
              '$pluginId:${storedOpen.id}',
          type: item['mediaType']?.toString() ?? 'tv',
          name: title,
          poster: poster,
          releaseInfo: item['releaseDate']?.toString() ?? '',
          open: storedOpen,
        ),
      );
      return;
    }

    if (mediaType == 'anime' || anilistId != null) {
      final id = anilistId ?? tmdbId;
      if (id != null && mounted) {
        final hubPlugin = await PluginNavRegistry.resolveHubPluginId(
          pluginId: pluginId ?? item['pluginId']?.toString(),
          tabId: item['hubTabId']?.toString(),
          engineType: 'anime',
        );
        if (hubPlugin == null) return;
        await openCatalogMetaItem(
          context,
          pluginId: hubPlugin,
          item: CatalogMetaItem(
            id: item['metaId']?.toString() ?? '$hubPlugin:$id',
            type: 'anime',
            name: title,
            poster: poster,
            releaseInfo: item['releaseDate']?.toString() ?? '',
            open: CatalogOpen(
              surface: 'anime',
              id: id.toString(),
              extract: CatalogOpenExtract(
                resolveType: 'anime',
                panelCategory: 'anime',
                ctx: {'anilistId': id},
              ),
            ),
          ),
        );
        return;
      }
    }

    if (mediaType == 'asian_drama' || kisskhId != null) {
      final id = kisskhId;
      if (id != null && mounted) {
        final hubPlugin = await PluginNavRegistry.resolveHubPluginId(
          pluginId: pluginId ?? item['pluginId']?.toString(),
          tabId: item['hubTabId']?.toString(),
          engineType: 'drama',
        );
        if (hubPlugin == null) return;
        await openCatalogMetaItem(
          context,
          pluginId: hubPlugin,
          item: CatalogMetaItem(
            id: item['metaId']?.toString() ?? '$hubPlugin:$id',
            type: 'drama',
            name: title,
            poster: poster,
            releaseInfo: item['releaseDate']?.toString() ?? '',
            open: CatalogOpen(
              surface: 'drama',
              id: id.toString(),
              extract: CatalogOpenExtract(
                resolveType: 'drama',
                panelCategory: 'drama',
                ctx: {'kisskhId': id},
              ),
            ),
          ),
        );
        return;
      }
    }

    if (source == 'tmdb' && tmdbId != null) {
      try {
        final details = mediaType == 'tv'
            ? await _api.getTvDetails(tmdbId)
            : await _api.getMovieDetails(tmdbId);
        if (mounted) {
          await AppRouter.openMovie(context, movie: details);
          return;
        }
      } catch (_) {}
    }

    if (imdbId != null && imdbId.startsWith('tt')) {
      try {
        final movie = await _api.findByImdbId(
          imdbId,
          mediaType: mediaType == 'series' ? 'tv' : mediaType,
        );
        if (movie != null && mounted) {
          await AppRouter.openMovie(context, movie: movie);
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      await AppRouter.openMovie(
        context,
        movie: Movie(
          id: tmdbId ?? title.hashCode,
          imdbId: imdbId,
          title: title,
          posterPath: poster,
          backdropPath: poster,
          voteAverage: (item['voteAverage'] as num?)?.toDouble() ?? 0,
          releaseDate: item['releaseDate']?.toString() ?? '',
          mediaType: mediaType == 'series' ? 'tv' : mediaType,
        ),
      );
    }
  }

  Future<void> _openSimklItem(Map<String, dynamic> item) async {
    final kind = item['_simklType']?.toString() ?? 'movies';
    final anilistId = item['anilistId'] as int?;
    final tmdbId = item['tmdbId'] as int?;
    final imdbId = item['imdbId']?.toString();

    if (kind == 'anime' && anilistId != null) {
      if (mounted) {
        final hubPlugin = await PluginNavRegistry.resolveHubPluginId(
          engineType: 'anime',
        );
        if (hubPlugin == null) return;
        await openCatalogMetaItem(
          context,
          pluginId: hubPlugin,
          item: CatalogMetaItem(
            id: '$hubPlugin:$anilistId',
            type: 'anime',
            name: item['title']?.toString() ?? 'Anime',
            poster: item['posterPath']?.toString() ?? '',
            open: CatalogOpen(surface: 'anime', id: anilistId.toString()),
            ids: {'anilist': anilistId.toString()},
          ),
        );
      }
      return;
    }
    if (tmdbId != null) {
      try {
        final movie = kind == 'shows'
            ? await _api.getTvDetails(tmdbId)
            : await _api.getMovieDetails(tmdbId);
        if (mounted) {
          await AppRouter.openMovie(context, movie: movie);
          return;
        }
      } catch (_) {}
    }
    if (imdbId != null && imdbId.startsWith('tt')) {
      try {
        final movie = await _api.findByImdbId(
          imdbId,
          mediaType: kind == 'shows' ? 'tv' : 'movie',
        );
        if (movie != null && mounted) {
          await AppRouter.openMovie(context, movie: movie);
          return;
        }
      } catch (_) {}
    }
    if (mounted) ForjaToast.info('Can’t open this title in Forja');
  }

  @override
  Widget build(BuildContext context) {
    final localItems = ref.watch(myListItemsProvider);
    final hiddenKeys = ref.watch(myListHiddenKeysProvider);
    final gate = ref.watch(externalListsGateProvider).valueOrNull;
    final simklLoggedIn = gate?.simklLoggedIn ?? false;
    final simklAsync = simklLoggedIn
        ? ref.watch(simklWatchlistProvider(_status))
        : null;
    ref.listen(simklWatchlistProvider(_status), (prev, next) {
      if (!simklLoggedIn) return;
      if (!next.isLoading && next.hasValue) {
        final cards = [
          for (final raw in next.requireValue) _simklCardItem(raw),
        ].whereType<Map<String, dynamic>>();
        ref.read(myListHiddenKeysProvider.notifier).retainOnlyPresentIn(cards);
      }
    });
    final simklLoading =
        simklLoggedIn &&
        simklAsync != null &&
        simklAsync.isLoading &&
        !simklAsync.hasValue;
    final simklItems = [
      for (final raw
          in simklAsync?.valueOrNull ?? const <Map<String, dynamic>>[])
        _simklCardItem(raw),
    ].whereType<Map<String, dynamic>>().toList();
    final localForStatus = localItems
        .where((e) => (e['listStatus']?.toString() ?? 'plantowatch') == _status)
        .toList();
    final items = simklLoggedIn
        ? _mergeLocalHubs(
            _filterSimklByLocal(simklItems, localItems, _status, hiddenKeys),
            localForStatus,
          )
        : localForStatus;
    final filtered = _kind == null
        ? items
        : items.where((e) => _itemKind(e) == _kind).toList();
    return TvFocusGraph(
      tabId: 'mylist',
      child: ColoredBox(
        color: AppTheme.bgDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KindMenu(
              selected: _kind,
              count: simklLoading ? null : filtered.length,
              onSelect: _toggleKind,
              filmsFocus: _filmsFocus,
              onDown: () => _focusRowLast(_tabsRowId) || _focusRow(_tabsRowId, 0),
            ),
            _StatusTabs(
              selected: _status,
              onSelect: _selectStatus,
              onUp: () => _focusRowLast(_kindRowId) || _focusRow(_kindRowId, 0),
              onDown: () => _focusRowLast(_gridRowId) || _focusRow(_gridRowId, 0),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final grid = _homeGrid(context, constraints.maxWidth);
                  if (simklLoading) return _loadingGrid(context, grid);
                  if (filtered.isEmpty) return _emptyState(kind: _kind);
                  return TvGrid(
                    tabId: _tabId,
                    rowId: _gridRowId,
                    sortOrder: 2,
                    columns: grid.columns,
                    itemCount: filtered.length,
                    onFocusUp: () =>
                        _focusRowLast(_tabsRowId) || _focusRow(_tabsRowId, 0),
                    child: CustomScrollView(
                      controller: _scroll,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            grid.leading,
                            grid.topPad,
                            grid.rightPad,
                            48,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: grid.columns,
                                  mainAxisSpacing: grid.gap,
                                  crossAxisSpacing: grid.gap,
                                  childAspectRatio: grid.cardW / grid.cardH,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = filtered[index];
                              return _ListPoster(
                                item: item,
                                tabStatus: _status,
                                gridIndex: index,
                                columns: grid.columns,
                                tvRowId: _gridRowId,
                                onTap: () => _openItem(item),
                                onUpEdge: index < grid.columns
                                    ? () =>
                                        _focusRowLast(_tabsRowId) ||
                                        _focusRow(_tabsRowId, 0)
                                    : null,
                              );
                            }, childCount: filtered.length),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingGrid(BuildContext context, _HomeGrid grid) {
    return homeLoadingShimmer(
      GridView.builder(
        padding: EdgeInsets.fromLTRB(
          grid.leading,
          grid.topPad,
          grid.rightPad,
          ShellTokens.bodyHorizontalPadding,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: grid.columns,
          mainAxisSpacing: grid.gap,
          crossAxisSpacing: grid.gap,
          childAspectRatio: grid.cardW / grid.cardH,
        ),
        itemCount: grid.columns * 2,
        itemBuilder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(shellCardBorderRadius(context)),
          ),
        ),
      ),
    );
  }

  Widget _emptyState({String? kind}) {
    final filtered = kind != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 40,
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),
            Text(
              filtered
                  ? 'Nothing in ${switch (kind) {
                      'tv' => 'TV Shows',
                      'anime' => 'Anime',
                      _ => 'Films',
                    }}'
                  : 'Nothing in this list',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Tap Films, TV Shows, or Anime again to show everything'
                  : 'Tap + on a title to set Plan to Watch / Watching / On Hold / Completed / Dropped',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindMenu extends StatelessWidget {
  const _KindMenu({
    required this.selected,
    required this.onSelect,
    required this.onDown,
    required this.filmsFocus,
    this.count,
  });

  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onDown;
  final FocusNode filmsFocus;
  final int? count;

  static const _items = [
    (id: 'movie', label: 'Films'),
    (id: 'tv', label: 'TV Shows'),
    (id: 'anime', label: 'Anime'),
  ];

  @override
  Widget build(BuildContext context) {
    final useTv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final tabGap = useTv
        ? 28.0
        : MediaQuery.sizeOf(context).width < 560
        ? 20.0
        : 36.0;
    return TvCatalogRow(
      tabId: _MyListScreenState._tabId,
      rowId: _MyListScreenState._kindRowId,
      sortOrder: 0,
      itemCount: _items.length,
      onFocusUp: () {},
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ShellTokens.compactChromeLeadingInset(context),
          ShellTokens.tabHeaderTopPadding,
          ShellTokens.bodyHorizontalPadding,
          4,
        ),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) SizedBox(width: tabGap),
                _KindTab(
                  label: _items[i].label,
                  isActive: selected == _items[i].id,
                  onTap: () => onSelect(_items[i].id),
                  tvFocus: useTv,
                  listIndex: i,
                  onDownEdge: onDown,
                  focusNode: i == 0 ? filmsFocus : null,
                ),
              ],
              const Spacer(),
              if (count != null && count! > 0)
                Text(
                  '$count',
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindTab extends StatefulWidget {
  const _KindTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.tvFocus,
    required this.listIndex,
    required this.onDownEdge,
    this.focusNode,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool tvFocus;
  final int listIndex;
  final VoidCallback onDownEdge;
  final FocusNode? focusNode;

  @override
  State<_KindTab> createState() => _KindTabState();
}

class _KindTabState extends State<_KindTab> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _hoverT = 0.62;
  static const _selectedT = 1.0;

  bool _hovered = false;
  bool _focused = false;

  double get _visualTarget {
    if (widget.isActive) return _selectedT;
    final policy = ShellScope.inputPolicyOf(context);
    // Desktop hybrid keeps keyboard focus on Films after mouse taps Anime —
    // only paint hover chrome when focus chrome is actually visible.
    if (_hovered || policy.focusStyled(context, focused: _focused)) {
      return _hoverT;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final child = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _visualTarget),
      duration: _animDuration,
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final idle = ForjaShellColors.cinematic.textSecondary;
        final hoverWhite = Colors.white.withValues(alpha: 0.92);
        final color = t <= 0
            ? idle
            : t < _hoverT
            ? Color.lerp(idle, hoverWhite, t / _hoverT)!
            : Color.lerp(
                hoverWhite,
                Colors.white,
                (t - _hoverT) / (_selectedT - _hoverT),
              )!;
        final tabHeight = shellScaled(context, 34).clamp(28.0, 34.0);
        final tabFont = shellScaled(context, 17).clamp(14.0, 17.0);
        final hoverW = shellScaled(context, 28).clamp(14.0, 28.0);
        final underline = t <= 0
            ? 0.0
            : t < _hoverT
            ? hoverW * (t / _hoverT)
            : hoverW +
                  shellScaled(context, 4).clamp(2.0, 4.0) *
                      ((t - _hoverT) / (_selectedT - _hoverT));
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: tabHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: tabFont,
                    fontWeight: FontWeight.lerp(
                      FontWeight.w500,
                      FontWeight.w700,
                      t,
                    ),
                    color: color,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: shellScaled(
                context,
                ShellTokens.shellCategoryUnderlineGap,
              ).clamp(2.0, ShellTokens.shellCategoryUnderlineGap),
            ),
            Container(
              height: shellScaled(
                context,
                ShellTokens.shellNavUnderlineHeight,
              ).clamp(1.0, ShellTokens.shellNavUnderlineHeight),
              width: underline,
              decoration: BoxDecoration(
                color: underline > 0 ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );

    if (widget.tvFocus) {
      return shellFocusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: 4,
        scaleOnFocus: ShellTokens.focusActiveScale,
        listIndex: widget.listIndex,
        tvTabId: _MyListScreenState._tabId,
        tvRowId: _MyListScreenState._kindRowId,
        tvZone: ShellTvZone.row,
        tvItemIndex: widget.listIndex,
        onDownEdge: widget.onDownEdge,
        focusNode: widget.focusNode,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: (h) => setState(() => _hovered = h),
        child: child,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.selected,
    required this.onSelect,
    this.onUp,
    this.onDown,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final useTv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    return TvCatalogRow(
      tabId: _MyListScreenState._tabId,
      rowId: _MyListScreenState._tabsRowId,
      sortOrder: 1,
      itemCount: _MyListScreenState._tabs.length,
      onFocusUp: onUp,
      onFocusDown: onDown,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ShellTokens.compactChromeLeadingInset(context),
          0,
          ShellTokens.bodyHorizontalPadding,
          0,
        ),
        child: SizedBox(
          height: 42,
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Row(
              children: [
                for (var i = 0; i < _MyListScreenState._tabs.length; i++)
                  Expanded(child: _tab(context, i, useTv)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int i, bool useTv) {
    final tab = _MyListScreenState._tabs[i];
    final on = tab.id == selected;
    if (!useTv) {
      final label = Text(
        tab.title,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: on
              ? ForjaShellColors.textPrimary
              : ForjaShellColors.textSecondary,
          fontWeight: on ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
      );
      return InkWell(
        onTap: () => onSelect(tab.id),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Center(child: label)),
            Container(
              height: 2,
              color: on ? ForjaShellColors.brandGreen : Colors.transparent,
            ),
          ],
        ),
      );
    }
    return _StatusTabFocus(
      label: tab.title,
      selected: on,
      listIndex: i,
      onTap: () => onSelect(tab.id),
      onUp: onUp,
      onDown: onDown,
    );
  }
}

class _StatusTabFocus extends StatefulWidget {
  const _StatusTabFocus({
    required this.label,
    required this.selected,
    required this.listIndex,
    required this.onTap,
    this.onUp,
    this.onDown,
  });

  final String label;
  final bool selected;
  final int listIndex;
  final VoidCallback onTap;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  State<_StatusTabFocus> createState() => _StatusTabFocusState();
}

class _StatusTabFocusState extends State<_StatusTabFocus> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final emphasize = widget.selected ||
        policy.focusStyled(context, focused: _focused);
    final label = Text(
      widget.label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: emphasize
            ? ForjaShellColors.textPrimary
            : ForjaShellColors.textSecondary,
        fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
    );
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      listIndex: widget.listIndex,
      tvTabId: _MyListScreenState._tabId,
      tvRowId: _MyListScreenState._tabsRowId,
      tvZone: ShellTvZone.chipStrip,
      tvItemIndex: widget.listIndex,
      onUpEdge: widget.onUp,
      onDownEdge: widget.onDown,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Center(child: label)),
          Container(
            height: 2,
            color: widget.selected
                ? ForjaShellColors.brandGreen
                : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _ListPoster extends StatelessWidget {
  const _ListPoster({
    required this.item,
    required this.tabStatus,
    required this.onTap,
    required this.gridIndex,
    required this.columns,
    required this.tvRowId,
    this.onUpEdge,
  });

  final Map<String, dynamic> item;
  final String tabStatus;
  final VoidCallback onTap;
  final int gridIndex;
  final int columns;
  final String tvRowId;
  final VoidCallback? onUpEdge;

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? 'Unknown';
    final imageUrl = _posterUrl(item);
    final metaLine = _metaLine(item);
    final rating = (item['voteAverage'] as num?)?.toDouble() ?? 0;
    final meta = TvGridScope.maybeOf(context)?.metaFor(gridIndex);
    final radius = shellCardBorderRadius(context);
    final inset = shellScaled(context, 10).clamp(4.0, 10.0);
    final titleSize = shellHubCardTitleFontSize(context);
    final metaSize = shellScaled(context, 11).clamp(7.0, 11.0);
    final knownStatus =
        item['listStatus']?.toString() ?? tabStatus;
    final pin = _listPin(context, item, knownStatus: knownStatus);

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: radius,
      showFocusBorder: true,
      focusBleedWidth: 0,
      gridIndex: meta?.gridIndex ?? gridIndex,
      gridColumns: meta?.gridColumns ?? columns,
      tvTabId: meta?.tvTabId ?? _MyListScreenState._tabId,
      tvRowId: meta?.tvRowId ?? tvRowId,
      tvZone: meta?.tvZone ?? ShellTvZone.grid,
      tvItemIndex: meta?.tvItemIndex ?? gridIndex,
      onUpEdge: onUpEdge,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppTheme.bgDark,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      placeholder: (_, _) =>
                          ColoredBox(color: AppTheme.bgDark),
                      errorWidget: (_, _, _) => _titleFallback(title),
                    )
                  : _titleFallback(title),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.45, 0.8, 1.0],
                ),
              ),
            ),
            if (pin != null || rating > 0)
              Positioned(
                top: inset,
                left: inset,
                right: inset,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ?pin,
                    const Spacer(),
                    if (rating > 0)
                      MovieRatingBadge(voteAverage: rating),
                  ],
                ),
              ),
            Positioned(
              bottom: inset,
              left: inset,
              right: inset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: titleSize,
                      height: 1.15,
                    ),
                  ),
                  if (metaLine.isNotEmpty) ...[
                    SizedBox(height: shellScaled(context, 4).clamp(1.0, 4.0)),
                    Text(
                      metaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: metaSize,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _titleFallback(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Colors.white38),
        ),
      ),
    );
  }
}

Widget? _listPin(
  BuildContext context,
  Map<String, dynamic> item, {
  String? knownStatus,
}) {
  final iconSize = shellScaled(context, 18).clamp(12.0, 18.0);
  final title = item['title']?.toString() ?? 'Unknown';
  final poster = item['posterPath']?.toString() ?? '';
  final vote = (item['voteAverage'] as num?)?.toDouble() ?? 0;
  final date = item['releaseDate']?.toString() ?? '';
  final mt = item['mediaType']?.toString() ?? 'movie';
  final anilistId = item['anilistId'] as int?;
  final kisskhId = item['kisskhId'] as int?;
  final tmdbId = item['tmdbId'] as int?;

  if (mt == 'anime' || anilistId != null) {
    if (anilistId == null) return null;
    final stored = CatalogOpen.fromJson(item['catalogOpen']);
    return MyListButton.hub(
      hubTarget: CatalogListFollowTarget(
        pluginId: item['pluginId']?.toString() ?? item['source']?.toString() ?? 'catalog',
        open: stored ??
            CatalogOpen(
              surface: 'anime',
              id: anilistId.toString(),
              extract: CatalogOpenExtract(
                resolveType: 'anime',
                panelCategory: 'anime',
                ctx: {'anilistId': anilistId},
              ),
            ),
        title: title,
        posterPath: poster,
        voteAverage: vote,
        releaseDate: date,
        mediaType: 'anime',
      ),
      excludeFromTvTraversal: true,
      iconSize: iconSize,
      knownStatus: knownStatus,
    );
  }

  if (mt == 'asian_drama' || kisskhId != null) {
    if (kisskhId == null) return null;
    final stored = CatalogOpen.fromJson(item['catalogOpen']);
    return MyListButton.hub(
      hubTarget: CatalogListFollowTarget(
        pluginId: item['pluginId']?.toString() ?? item['source']?.toString() ?? 'catalog',
        open: stored ??
            CatalogOpen(
              surface: 'drama',
              id: kisskhId.toString(),
              extract: CatalogOpenExtract(
                resolveType: 'drama',
                panelCategory: 'drama',
                ctx: {'kisskhId': kisskhId},
              ),
            ),
        title: title,
        posterPath: poster,
        tmdbId: tmdbId,
        tmdbMediaType: item['tmdbMediaType']?.toString(),
        releaseDate: date,
        voteAverage: vote,
        mediaType: 'asian_drama',
      ),
      excludeFromTvTraversal: true,
      iconSize: iconSize,
      knownStatus: knownStatus,
    );
  }

  if (tmdbId == null) return null;
  final mediaType = (mt == 'tv' || mt == 'series') ? 'tv' : 'movie';
  return MyListButton.movie(
    movie: Movie(
      id: tmdbId,
      imdbId: item['imdbId']?.toString(),
      title: title,
      posterPath: poster.startsWith('http') ? poster : poster,
      backdropPath: '',
      voteAverage: vote,
      releaseDate: date,
      mediaType: mediaType,
    ),
    excludeFromTvTraversal: true,
    iconSize: iconSize,
    knownStatus: knownStatus,
  );
}

class _HomeGrid {
  const _HomeGrid({
    required this.columns,
    required this.cardW,
    required this.cardH,
    required this.gap,
    required this.leading,
    required this.rightPad,
    required this.topPad,
  });

  final int columns;
  final double cardW;
  final double cardH;
  final double gap;
  final double leading;
  final double rightPad;
  final double topPad;
}

_HomeGrid _homeGrid(BuildContext context, double maxWidth) {
  final cardW = shellMovieCardWidth(context);
  final cardH = shellMovieCardHeight(context);
  final gap = shellMovieCardRowGap(context);
  final leading = ShellTokens.compactChromeLeadingInset(context);
  final trailing = ShellTokens.bodyHorizontalPadding;
  final inner = math.max(0.0, maxWidth - leading - trailing);
  final columns = math.max(1, ((inner + gap) / (cardW + gap)).floor());
  final gridW = columns * cardW + (columns - 1) * gap;
  final rightPad = math.max(trailing, maxWidth - leading - gridW);
  final topPad = cardH * (ShellTokens.focusActiveScale - 1) / 2 + 4;
  return _HomeGrid(
    columns: columns,
    cardW: cardW,
    cardH: cardH,
    gap: gap,
    leading: leading,
    rightPad: rightPad,
    topPad: topPad,
  );
}

String _itemKind(Map<String, dynamic> item) {
  final simkl = item['_simklType']?.toString();
  if (simkl == 'anime') return 'anime';
  if (simkl == 'shows') return 'tv';
  if (simkl == 'movies') return 'movie';
  final mt = item['mediaType']?.toString() ?? 'movie';
  if (mt == 'anime') return 'anime';
  if (mt == 'tv' || mt == 'series' || mt == 'asian_drama') return 'tv';
  return 'movie';
}

/// Drop Simkl rows that local My List already places elsewhere, or that the
/// user just removed (optimistic hide until Simkl refetch).
List<Map<String, dynamic>> _filterSimklByLocal(
  List<Map<String, dynamic>> simklItems,
  List<Map<String, dynamic>> allLocal,
  String status,
  Set<String> hiddenKeys,
) {
  final out = <Map<String, dynamic>>[];
  for (final s in simklItems) {
    if (_simklHidden(s, hiddenKeys)) continue;
    final local = _localMatch(allLocal, s);
    if (local != null) {
      final localStatus =
          local['listStatus']?.toString() ?? 'plantowatch';
      if (localStatus != status) continue;
    }
    out.add(s);
  }
  return out;
}

bool _simklHidden(Map<String, dynamic> item, Set<String> hiddenKeys) {
  if (hiddenKeys.isEmpty) return false;
  return myListItemHideKeys(item).any(hiddenKeys.contains);
}

Map<String, dynamic>? _localMatch(
  List<Map<String, dynamic>> allLocal,
  Map<String, dynamic> item,
) {
  final anilist = item['anilistId'] as int?;
  final kisskh = item['kisskhId'] as int?;
  final tmdb = item['tmdbId'] as int?;
  final mt = item['mediaType']?.toString();
  for (final local in allLocal) {
    if (anilist != null && local['anilistId'] == anilist) return local;
    if (kisskh != null && local['kisskhId'] == kisskh) return local;
    if (tmdb != null && local['tmdbId'] == tmdb) {
      final lmt = local['mediaType']?.toString();
      if (lmt == 'asian_drama') return local;
      if (mt == null || lmt == null || lmt == mt) return local;
      final localNorm = (lmt == 'tv' || lmt == 'series') ? 'tv' : lmt;
      final itemNorm = (mt == 'tv' || mt == 'series' || mt == 'shows')
          ? 'tv'
          : mt;
      if (localNorm == itemNorm) return local;
    }
  }
  return null;
}

List<Map<String, dynamic>> _mergeLocalHubs(
  List<Map<String, dynamic>> simklItems,
  List<Map<String, dynamic>> localForStatus,
) {
  final out = [...simklItems];
  final seenAnilist = <int>{
    for (final e in simklItems)
      if (e['anilistId'] is int) e['anilistId'] as int,
  };
  final seenTmdb = <int>{
    for (final e in simklItems)
      if (e['tmdbId'] is int) e['tmdbId'] as int,
  };
  final seenKisskh = <int>{
    for (final e in simklItems)
      if (e['kisskhId'] is int) e['kisskhId'] as int,
  };
  for (final local in localForStatus) {
    final mt = local['mediaType']?.toString();
    if (mt == 'anime') {
      final id = local['anilistId'] as int?;
      if (id != null && seenAnilist.contains(id)) continue;
      out.add(local);
      if (id != null) seenAnilist.add(id);
    } else if (mt == 'asian_drama') {
      final kisskh = local['kisskhId'] as int?;
      final tmdb = local['tmdbId'] as int?;
      if (kisskh != null && seenKisskh.contains(kisskh)) continue;
      if (tmdb != null && seenTmdb.contains(tmdb)) continue;
      out.add(local);
      if (kisskh != null) seenKisskh.add(kisskh);
      if (tmdb != null) seenTmdb.add(tmdb);
    } else {
      // Movies / TV — local wins when Simkl is slow or status just moved.
      final tmdb = local['tmdbId'] as int?;
      if (tmdb != null && seenTmdb.contains(tmdb)) continue;
      out.add(local);
      if (tmdb != null) seenTmdb.add(tmdb);
    }
  }
  return out;
}

String _posterUrl(Map<String, dynamic> item) {
  final poster = item['posterPath']?.toString() ?? '';
  if (poster.isEmpty) return '';
  if (poster.startsWith('http')) return poster;
  if (poster.startsWith('/')) return TmdbApi.getImageUrl(poster);
  return poster;
}

/// Home-style bottom meta: `year • FILM` / `TV` / `ANIME`.
String _metaLine(Map<String, dynamic> item) {
  final parts = <String>[];
  final date = item['releaseDate']?.toString() ?? '';
  if (date.isNotEmpty) {
    parts.add(date.contains('-') ? date.split('-').first : date);
  }
  final type = _typeLabel(item);
  if (type != null) parts.add(type);
  return parts.join(' • ');
}

String? _typeLabel(Map<String, dynamic> item) {
  final mt = item['mediaType']?.toString() ?? 'movie';
  final simkl = item['_simklType']?.toString();
  if (simkl == 'anime' || mt == 'anime') return 'ANIME';
  if (mt == 'asian_drama') {
    final kt = (item['kissKhType'] ?? '').toString().toLowerCase();
    if (kt == 'movie') return 'FILM';
    if (kt == 'anime') return 'ANIME';
    if (kt == 'hollywood') return 'HOLLYWOOD';
    return 'TV';
  }
  if (simkl == 'shows' || mt == 'tv' || mt == 'series') return 'TV';
  if (simkl == 'movies' || mt == 'movie') return 'FILM';
  return null;
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

Map<String, dynamic>? _simklCardItem(Map<String, dynamic> item) {
  final media = item['show'] ?? item['movie'] ?? item['anime'] ?? item;
  if (media is! Map) return null;
  final ids = media['ids'] is Map
      ? Map<String, dynamic>.from(media['ids'] as Map)
      : const <String, dynamic>{};
  final title = media['title']?.toString();
  if (title == null || title.isEmpty) return null;
  final kind = item['_simklType']?.toString() ?? 'movies';
  final poster = media['poster']?.toString();
  final posterUrl = (poster == null || poster.isEmpty)
      ? ''
      : (poster.startsWith('http')
            ? poster
            : 'https://simkl.in/posters/${poster}_c.jpg');
  final year = media['year']?.toString() ?? '';
  final anilist = _asInt(ids['anilist']);
  return {
    'title': title,
    'posterPath': posterUrl,
    'source': 'simkl',
    'mediaType': kind == 'anime'
        ? 'anime'
        : (kind == 'movies' ? 'movie' : 'tv'),
    '_simklType': kind,
    'tmdbId': _asInt(ids['tmdb']),
    'anilistId': anilist,
    'imdbId': ids['imdb']?.toString(),
    'voteAverage': 0,
    'releaseDate': year,
  };
}
