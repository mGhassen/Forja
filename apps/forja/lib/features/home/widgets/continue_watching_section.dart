// Home tab section widgets - extracted from home_screen.dart (RFC-019 Phase B).

import 'dart:convert';

import 'package:forja/features/home/widgets/home_widget_imports.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shared/playback/history_playback_resume.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
class HomeContinueWatchingSection extends StatefulWidget {
  final bool compactTop;
  final String? tvRowId;
  final int tvRowOrder;

  const HomeContinueWatchingSection({
    this.compactTop = false,
    this.tvRowId,
    this.tvRowOrder = 2,
  });

  @override
  State<HomeContinueWatchingSection> createState() => HomeContinueWatchingSectionState();
}

class HomeContinueWatchingSectionState extends State<HomeContinueWatchingSection> {
  String? _loadingItemId;
  final Map<int, String> _resolvedBackdrops = {};
  String get _rowId => widget.tvRowId ?? 'continue-watching';

  @override
  void initState() {
    super.initState();
    _resolveMissingBackdrops(WatchHistoryService().current);
  }

  Future<void> _resolveMissingBackdrops(List<Map<String, dynamic>> items) async {
    for (final item in items) {
      final stored = item['backdropPath'] as String?;
      if (stored != null && stored.isNotEmpty) continue;

      final tmdbId = item['tmdbId'] as int?;
      if (tmdbId == null || _resolvedBackdrops.containsKey(tmdbId)) continue;

      final mediaType = item['mediaType']?.toString() ??
          (item['season'] != null ? 'tv' : 'movie');
      final type = (mediaType == 'tv' || mediaType == 'series') ? 'tv' : 'movie';

      try {
        final raw = await runTmdbGetJson('$type/$tmdbId');
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic> && data['error'] == null) {
          final backdrop = data['backdrop_path']?.toString() ?? '';
          if (backdrop.isNotEmpty && mounted) {
            setState(() => _resolvedBackdrops[tmdbId] = backdrop);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _resumePlayback(Map<String, dynamic> item) async {
    final uniqueId = item['uniqueId'] as String;
    if (_loadingItemId != null) return;

    setState(() => _loadingItemId = uniqueId);
    try {
      await resumePlaybackFromHistory(context, item);
    } finally {
      if (mounted) setState(() => _loadingItemId = null);
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    await WatchHistoryService().removeItem(item['uniqueId']);

    // Also remove from Trakt playback progress if logged in
    final tmdbId = item['tmdbId'] as int?;
    if (tmdbId != null) {
      final mediaType = item['mediaType']?.toString() ?? 'movie';
      final season = item['season'] as int?;
      final episode = item['episode'] as int?;
      await TraktService().removePlaybackProgress(
        tmdbId: tmdbId,
        mediaType: mediaType,
        season: season,
        episode: episode,
      );
    }
  }

  /// Opens the details page for a history item based on streaming mode and item type
  Future<void> _openHistoryItemDetails(Map<String, dynamic> item) async {
    final tmdbId = item['tmdbId'] as int;
    final title = item['title'] as String;
    final posterPath = item['posterPath'] as String;
    final season = item['season'] as int?;
    final episode = item['episode'] as int?;
    final mediaType = item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
    
    final movie = Movie(
      id: tmdbId,
      title: title,
      posterPath: posterPath,
      backdropPath: '',
      overview: '',
      releaseDate: '',
      voteAverage: 0,
      mediaType: mediaType,
      genres: [],
      imdbId: item['imdbId'],
    );

    final stremioItemId = item['stremioId'] as String?;
    final stremioAddonBase = item['stremioAddonBaseUrl'] as String?;
    final isCustomId = stremioItemId != null &&
        stremioAddonBase != null &&
        !stremioItemId.startsWith('tt');

    Map<String, dynamic>? stremioItem;
    if (isCustomId) {
      stremioItem = {
        'id': stremioItemId,
        '_addonBaseUrl': stremioAddonBase,
        'type': item['stremioType'] ?? (season != null ? 'series' : 'movie'),
        'name': title,
      };
    }

    if (mounted) {
      await AppRouter.openDetails(
        context,
        movie: movie,
        stremioItem: stremioItem,
        initialSeason: season,
        initialEpisode: episode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: WatchHistoryService().historyStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return homeContinueWatchingSkeleton(
            context,
            compactTop: widget.compactTop,
          );
        }
        if (snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final raw = snapshot.data!;
        if (_resolvedBackdrops.length < raw.length) {
          _resolveMissingBackdrops(raw);
        }
        // Deduplicate by tmdbId for shows - keep only the latest episode per show
        final seen = <dynamic>{};
        final history = <Map<String, dynamic>>[];
        for (final item in raw) {
          final key = (item['mediaType'] == 'tv' || item['season'] != null)
              ? item['tmdbId']
              : item['uniqueId'];
          if (seen.add(key)) history.add(item);
        }

        final titleTop = shellHomeSectionTitleTop(context, compact: widget.compactTop,
        );

        return TvCatalogRow(
          rowId: _rowId,
          sortOrder: widget.tvRowOrder,
          itemCount: history.length,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShellSectionTitle(
                title: 'Continue Watching',
                padding: shellHomeSectionTitlePadding(context, top: titleTop),
              ),
              HorizontalScroller(
                height: HomeHistoryCard.cardHeight(context),
                padding: EdgeInsets.symmetric(
                  horizontal: shellHomeSectionHorizontalPadding(context),
                ),
                itemCount: history.length,
                separatorBuilder: (_, _) =>
                    SizedBox(width: shellMovieCardRowGap(context)),
                itemBuilder: (context, index) {
                  final historyItem = history[index];
                  final itemId = historyItem['uniqueId'] as String;
                  return HomeHistoryCard(
                    listIndex: index,
                    tvRowId: _rowId,
                    item: historyItem,
                    resolvedBackdropPath:
                        _resolvedBackdrops[historyItem['tmdbId'] as int?],
                    onTap: () => _resumePlayback(historyItem),
                    onRemove: () => _removeItem(historyItem),
                    onInfo: () => _openHistoryItemDetails(historyItem),
                    isLoading: _loadingItemId == itemId,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeHistoryCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? resolvedBackdropPath;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onInfo;
  final bool isLoading;
  final int listIndex;
  final String? tvRowId;

  const HomeHistoryCard({
    required this.item,
    this.resolvedBackdropPath,
    required this.onTap,
    required this.onRemove,
    required this.onInfo,
    required this.listIndex,
    this.tvRowId,
    this.isLoading = false,
  });

  static double cardWidth(BuildContext context) =>
      shellContinueWatchingCardWidth(context);

  static double cardHeight(BuildContext context) =>
      shellContinueWatchingCardHeight(context);

  @override
  State<HomeHistoryCard> createState() => HomeHistoryCardState();
}

class HomeHistoryCardState extends State<HomeHistoryCard> {
  bool _hovered = false;
  bool _focused = false;

  bool _active(BuildContext context) => ShellInputPolicy.interactiveActive(
        ShellScope.inputPolicyOf(context),
        hovered: _hovered,
        focused: _focused,
      );

  @override
  Widget build(BuildContext context) {
    final posterPath = widget.item['posterPath'] as String;
    final storedBackdrop = widget.item['backdropPath'] as String?;
    final backdropPath = (storedBackdrop != null && storedBackdrop.isNotEmpty)
        ? storedBackdrop
        : widget.resolvedBackdropPath;
    final title = widget.item['title'] as String;
    final season = widget.item['season'] == null
        ? null
        : watchHistoryInt(widget.item['season']);
    final episode = widget.item['episode'] == null
        ? null
        : watchHistoryInt(widget.item['episode']);
    final episodeTitle = widget.item['episodeTitle'] as String?;
    final position = watchHistoryInt(widget.item['position']);
    final duration = watchHistoryInt(widget.item['duration']);
    
    final progress = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
    final remaining = duration > 0 ? Duration(milliseconds: duration - position) : Duration.zero;
    final remainingText = remaining.inMinutes > 0 ? '${remaining.inMinutes}m left' : '';
    final imageUrl = homeHistoryCardImageUrl(
      backdropPath: backdropPath,
      posterPath: posterPath,
    );
    
    final subtitle = season != null 
        ? 'S$season E$episode${episodeTitle != null && episodeTitle.isNotEmpty ? ' • $episodeTitle' : ''}'
        : '';

    final policy = ShellScope.inputPolicyOf(context);
    final cardWidth = HomeHistoryCard.cardWidth(context);
    final cardHeight = HomeHistoryCard.cardHeight(context);

    return shellFocusableTap(
      context: context,
      onTap: widget.isLoading ? null : widget.onTap,
      listIndex: widget.listIndex,
      tvTabId: 'home',
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.listIndex,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: AnimatedScale(
        scale: _active(context) ? ShellCardPlayOverlay.cardHoverScale : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
              ColoredBox(
                color: AppTheme.bgDark,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        placeholder: (c, u) =>
                            ColoredBox(color: AppTheme.bgDark),
                      )
                    : const Icon(Icons.movie, color: Colors.white24, size: 40),
              ),
            
            // Dark overlay gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // Top-right actions (mouse only - TV uses card select + details via info elsewhere)
            Positioned(
              top: 6, right: 6,
              child: ExcludeFocus(
                excluding: !policy.scaleOnHover,
                child: Column(
                  children: [
                    ForjaCloseButton(
                      size: 14,
                      hitSize: 28,
                      color: Colors.white70,
                      onTap: widget.onRemove,
                    ),
                    const SizedBox(height: 4),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        hoverColor: ForjaShellColors.inkHover,
                        splashColor: ForjaShellColors.inkSplash,
                        highlightColor: ForjaShellColors.inkSplash,
                        onTap: widget.onInfo,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom content: title + episode + progress
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                            ),
                          ),
                        if (remainingText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              remainingText,
                              style: TextStyle(color: ForjaShellColors.badgeLabel, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Progress bar
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: ForjaShellColors.sectionAccent,
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
            
            ShellCardPlayOverlay(
              active: false,
              visible: _active(context) && !widget.isLoading,
            ),

            if (widget.isLoading)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: ForjaShellColors.sectionAccent,
                  ),
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

String homeHistoryCardImageUrl({
  String? backdropPath,
  required String posterPath,
}) {
  if (backdropPath != null && backdropPath.isNotEmpty) {
    return backdropPath.startsWith('http')
        ? backdropPath
        : TmdbApi.getBackdropUrl(backdropPath);
  }
  if (posterPath.isNotEmpty) {
    return posterPath.startsWith('http')
        ? posterPath
        : TmdbApi.getImageUrl(posterPath);
  }
  return '';
}
