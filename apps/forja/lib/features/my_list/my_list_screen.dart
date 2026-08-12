import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:forja/shared/services/tracker/simkl_service.dart';

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
        if (ShellTvFocusCoordinator.focusRowItem('mylist', 'tabs', 0)) {
          return true;
        }
        for (final id in ['films', 'tv', 'anime', 'grid']) {
          if (ShellTvFocusCoordinator.focusRowItem('mylist', id, 0)) {
            return true;
          }
        }
        return false;
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
    if (ShellTvFocusCoordinator.focusRowItem('mylist', 'tabs', 0)) return;
    for (final id in ['films', 'tv', 'anime', 'grid']) {
      if (ShellTvFocusCoordinator.focusRowItem('mylist', id, 0)) return;
    }
  }

  void _selectStatus(String id) {
    if (_status == id) return;
    setState(() => _status = id);
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
    final simklAsync =
        simklLoggedIn ? ref.watch(simklWatchlistProvider) : null;
    final buckets = simklAsync?.valueOrNull ?? const <SimklWatchlistBucket>[];
    final simklLoading = simklLoggedIn &&
        simklAsync != null &&
        simklAsync.isLoading &&
        !simklAsync.hasValue;

    final byStatus = {
      for (final b in buckets)
        b.status: [
          for (final raw in b.items) _simklCardItem(raw),
        ].whereType<Map<String, dynamic>>().toList(),
    };
    final items = simklLoggedIn
        ? (byStatus[_status] ?? const <Map<String, dynamic>>[])
        : localItems;
    final groups = _groups(items);
    final columns = shellGridCrossAxisCount(context);

    return TvFocusGraph(
      tabId: 'mylist',
      child: ColoredBox(
        color: AppTheme.bgDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShellTabHeader(
              title: 'My List',
              actions: [
                if (!simklLoading && items.isNotEmpty)
                  Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
            if (simklLoggedIn)
              _StatusTabs(
                selected: _status,
                onSelect: _selectStatus,
              ),
            Expanded(
              child: simklLoading
                  ? _loadingGrid(context, columns)
                  : groups.isEmpty
                      ? _emptyState(simklLoggedIn)
                      : CustomScrollView(
                          controller: _scroll,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            for (var i = 0; i < groups.length; i++)
                              SliverToBoxAdapter(
                                child: TvGrid(
                                  tabId: 'mylist',
                                  rowId: groups[i].id,
                                  sortOrder: i,
                                  columns: columns,
                                  itemCount: groups[i].items.length,
                                  onFocusUp: i == 0
                                      ? (simklLoggedIn
                                          ? () {
                                              ShellTvFocusCoordinator
                                                  .focusRowItem(
                                                'mylist',
                                                'tabs',
                                                0,
                                              );
                                            }
                                          : null)
                                      : () {
                                          ShellTvFocusCoordinator.focusRowItem(
                                            'mylist',
                                            groups[i - 1].id,
                                            0,
                                          );
                                        },
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      ShellTokens.bodyHorizontalPadding,
                                      i == 0 ? 4 : 22,
                                      ShellTokens.bodyHorizontalPadding,
                                      i == groups.length - 1 ? 48 : 0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (groups.length > 1) ...[
                                          Text(
                                            groups[i].title,
                                            style: TextStyle(
                                              color: ForjaShellColors
                                                  .textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        GridView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            mainAxisSpacing: 12,
                                            crossAxisSpacing: 12,
                                            childAspectRatio: 2 / 3,
                                          ),
                                          itemCount: groups[i].items.length,
                                          itemBuilder: (context, index) {
                                            final item = groups[i].items[index];
                                            return _ListPoster(
                                              item: item,
                                              gridIndex: index,
                                              columns: columns,
                                              tvRowId: groups[i].id,
                                              onTap: () => _openItem(item),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingGrid(BuildContext context, int columns) {
    return homeLoadingShimmer(
      GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          ShellTokens.bodyHorizontalPadding,
          0,
          ShellTokens.bodyHorizontalPadding,
          ShellTokens.bodyHorizontalPadding,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2 / 3,
        ),
        itemCount: columns * 2,
        itemBuilder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(bool simkl) {
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
              simkl ? 'Nothing in this list' : 'Your list is empty',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              simkl
                  ? 'Tap + on a title to set its Simkl status'
                  : 'Tap + on a movie or show to add it here',
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

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final useTv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          for (var i = 0; i < _MyListScreenState._tabs.length; i++)
            Expanded(
              child: _tab(context, i, useTv),
            ),
        ],
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
      return InkWell(
        onTap: () => onSelect(tab.id),
        child: body,
      );
    }
    return shellFocusableTap(
      context: context,
      onTap: () => onSelect(tab.id),
      borderRadius: 0,
      listIndex: i,
      tvTabId: 'mylist',
      tvRowId: 'tabs',
      tvZone: ShellTvZone.chipStrip,
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

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 12,
      showFocusBorder: true,
      gridIndex: meta?.gridIndex ?? gridIndex,
      gridColumns: meta?.gridColumns ?? columns,
      tvTabId: meta?.tvTabId ?? 'mylist',
      tvRowId: meta?.tvRowId ?? tvRowId,
      tvZone: meta?.tvZone ?? ShellTvZone.grid,
      tvItemIndex: meta?.tvItemIndex ?? gridIndex,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: AppTheme.bgCard,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      ColoredBox(color: AppTheme.bgCard),
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

List<({String id, String title, List<Map<String, dynamic>> items})> _groups(
  List<Map<String, dynamic>> items,
) {
  final films = <Map<String, dynamic>>[];
  final tv = <Map<String, dynamic>>[];
  final anime = <Map<String, dynamic>>[];
  for (final item in items) {
    switch (_itemKind(item)) {
      case 'anime':
        anime.add(item);
      case 'tv':
        tv.add(item);
      default:
        films.add(item);
    }
  }
  return [
    if (films.isNotEmpty) (id: 'films', title: 'Films', items: films),
    if (tv.isNotEmpty) (id: 'tv', title: 'TV', items: tv),
    if (anime.isNotEmpty) (id: 'anime', title: 'Anime', items: anime),
  ];
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
