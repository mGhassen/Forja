import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/anime/anime_details_screen.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/features/my_list/providers/my_list_providers.dart';
import 'package:rust/rust.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
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
      'mylist',
      enterFromNavFocus: _focusEntry,
      restoreFocus: () {
        if (ShellTvFocusCoordinator.focusRowItem('mylist', 'kind', 0)) {
          return true;
        }
        if (ShellTvFocusCoordinator.focusRowItem('mylist', 'tabs', 0)) {
          return true;
        }
        return ShellTvFocusCoordinator.focusRowItem('mylist', 'grid', 0);
      },
    );
    markShellTabFresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    ShellTvFocusCoordinator.clearTab('mylist');
    super.dispose();
  }

  void _focusEntry() {
    if (ShellTvFocusCoordinator.focusRowItem('mylist', 'kind', 0)) return;
    if (ShellTvFocusCoordinator.focusRowItem('mylist', 'tabs', 0)) return;
    ShellTvFocusCoordinator.focusRowItem('mylist', 'grid', 0);
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
      try {
        final card = await AnimeService().getDetails(anilistId);
        if (mounted) await openAnimeDetails(context, card);
        return;
      } catch (_) {}
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
    final gate = ref.watch(externalListsGateProvider).valueOrNull;
    final simklLoggedIn = gate?.simklLoggedIn ?? false;
    final simklAsync = simklLoggedIn
        ? ref.watch(simklWatchlistProvider(_status))
        : null;
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
    final items = simklLoggedIn ? simklItems : localForStatus;
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
              onDown: () =>
                  ShellTvFocusCoordinator.focusRowItem('mylist', 'tabs', 0),
            ),
            _StatusTabs(
              selected: _status,
              onSelect: _selectStatus,
              onUp: () =>
                  ShellTvFocusCoordinator.focusRowItem('mylist', 'kind', 0),
              onDown: () =>
                  ShellTvFocusCoordinator.focusRowItem('mylist', 'grid', 0),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final grid = _homeGrid(context, constraints.maxWidth);
                  if (simklLoading) return _loadingGrid(context, grid);
                  if (filtered.isEmpty) return _emptyState(kind: _kind);
                  return TvGrid(
                    tabId: 'mylist',
                    rowId: 'grid',
                    sortOrder: 2,
                    columns: grid.columns,
                    itemCount: filtered.length,
                    onFocusUp: () {
                      ShellTvFocusCoordinator.focusRowItem('mylist', 'tabs', 0);
                    },
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
                                gridIndex: index,
                                columns: grid.columns,
                                tvRowId: 'grid',
                                onTap: () => _openItem(item),
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
    this.count,
  });

  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onDown;
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ShellTokens.compactChromeLeadingInset(context),
        ShellTokens.tabHeaderTopPadding,
        ShellTokens.bodyHorizontalPadding,
        4,
      ),
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
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool tvFocus;
  final int listIndex;
  final VoidCallback onDownEdge;

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
    if (_hovered || _focused) return _hoverT;
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
        tvTabId: 'mylist',
        tvRowId: 'kind',
        tvZone: ShellTvZone.topBar,
        tvItemIndex: widget.listIndex,
        onDownEdge: widget.onDownEdge,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ShellTokens.compactChromeLeadingInset(context),
        0,
        ShellTokens.bodyHorizontalPadding,
        0,
      ),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            for (var i = 0; i < _MyListScreenState._tabs.length; i++)
              Expanded(child: _tab(context, i, useTv)),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int i, bool useTv) {
    final tab = _MyListScreenState._tabs[i];
    final on = tab.id == selected;
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
    final body = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: Center(child: label)),
        Container(
          height: 2,
          color: on ? ForjaShellColors.brandGreen : Colors.transparent,
        ),
      ],
    );
    if (!useTv) {
      return InkWell(onTap: () => onSelect(tab.id), child: body);
    }
    return shellFocusableTap(
      context: context,
      onTap: () => onSelect(tab.id),
      borderRadius: 0,
      listIndex: i,
      tvTabId: 'mylist',
      tvRowId: 'tabs',
      tvZone: ShellTvZone.chipStrip,
      onUpEdge: onUp,
      onDownEdge: onDown,
      child: body,
    );
  }
}

class _ListPoster extends StatelessWidget {
  const _ListPoster({
    required this.item,
    required this.onTap,
    required this.gridIndex,
    required this.columns,
    required this.tvRowId,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final int gridIndex;
  final int columns;
  final String tvRowId;

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? 'Unknown';
    final imageUrl = _posterUrl(item);
    final caption = _caption(item);
    final meta = TvGridScope.maybeOf(context)?.metaFor(gridIndex);

    final radius = shellCardBorderRadius(context);
    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: radius,
      showFocusBorder: true,
      focusBleedWidth: 0,
      gridIndex: meta?.gridIndex ?? gridIndex,
      gridColumns: meta?.gridColumns ?? columns,
      tvTabId: meta?.tvTabId ?? 'mylist',
      tvRowId: meta?.tvRowId ?? tvRowId,
      tvZone: meta?.tvZone ?? ShellTvZone.grid,
      tvItemIndex: meta?.tvItemIndex ?? gridIndex,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: AppTheme.bgCard,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(color: AppTheme.bgCard),
                  errorWidget: (_, _, _) => _titleFallback(title),
                )
              else
                _titleFallback(title),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.15,
                      ),
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
  if (mt == 'tv' || mt == 'series') return 'tv';
  return 'movie';
}

String _posterUrl(Map<String, dynamic> item) {
  final poster = item['posterPath']?.toString() ?? '';
  if (poster.isEmpty) return '';
  if (poster.startsWith('http')) return poster;
  if (poster.startsWith('/')) return TmdbApi.getImageUrl(poster);
  return poster;
}

String _caption(Map<String, dynamic> item) {
  final parts = <String>[];
  final date = item['releaseDate']?.toString() ?? '';
  if (date.isNotEmpty) {
    parts.add(date.contains('-') ? date.split('-').first : date);
  }
  final rating = (item['voteAverage'] as num?)?.toDouble() ?? 0;
  if (rating > 0) parts.add(rating.toStringAsFixed(1));
  return parts.join('  ·  ');
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
  return {
    'title': title,
    'posterPath': posterUrl,
    'source': 'simkl',
    'mediaType': kind == 'movies' ? 'movie' : 'tv',
    '_simklType': kind,
    'tmdbId': _asInt(ids['tmdb']),
    'anilistId': _asInt(ids['anilist']),
    'imdbId': ids['imdb']?.toString(),
    'voteAverage': 0,
    'releaseDate': year,
  };
}
