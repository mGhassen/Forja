import 'package:flutter/material.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'anime_player_screen.dart';

Future<T?> openAnimeDetails<T>(BuildContext context, AnimeCard anime) {
  return pushShellRoute<T>(
    context,
    AppRouter.slideRoute((_) => AnimeDetailsScreen(anime: anime)),
  );
}

class AnimeDetailsScreen extends StatefulWidget {
  final AnimeCard anime;
  const AnimeDetailsScreen({super.key, required this.anime});

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  final AnimeService _service = AnimeService();
  final ScrollController _detailsScrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'anime-details-play');

  AnimeCard? _full;
  List<AnimeEpisode> _episodes = [];
  List<AnimeCard> _related = [];
  Map<String, dynamic>? _progress;
  String? _error;

  String _category = 'sub';
  int _selectedEpisode = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _heroPlayFocus.dispose();
    _detailsScrollController.dispose();
    super.dispose();
  }

  void _scrollDetailsHeroIntoView() {
    if (!_detailsScrollController.hasClients) return;
    _detailsScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _revealedDetailsHeroPlayFocus() {
    void focusPlay() {
      if (!mounted) return;
      if (_heroPlayFocus.canRequestFocus) {
        _heroPlayFocus.requestFocus();
      }
    }

    _scrollDetailsHeroIntoView();
    if (!_detailsScrollController.hasClients) {
      focusPlay();
      return;
    }
    _detailsScrollController
        .animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(focusPlay);
  }

  AnimeCard get _data => _full ?? widget.anime;

  List<AnimeEpisode> _synthEpisodes(AnimeCard a) {
    final count = a.episodes ?? a.nextAiringEpisode?['episode'];
    final n = (count is int && count > 0) ? count : 1;
    final airedNow = a.nextAiringEpisode?['episode'];
    final maxAired = (airedNow is int && airedNow > 1) ? (airedNow - 1) : n;
    return List.generate(
      n,
      (i) => AnimeEpisode(
        number: i + 1,
        title: 'Episode ${i + 1}',
        aired: (i + 1) <= maxAired,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _episodes = _synthEpisodes(widget.anime);
    });

    _service.getDetails(widget.anime.id).then((d) {
      if (!mounted) return;
      setState(() {
        _full = d;
        if (_episodes.isEmpty || _episodes.length < (d.episodes ?? 0)) {
          _episodes = _synthEpisodes(d);
        }
      });
    }).catchError((e) {
      if (mounted && _full == null) setState(() => _error = 'Failed to load: $e');
    });

    _service.getEpisodes(widget.anime).then((eps) {
      if (!mounted || eps.isEmpty) return;
      setState(() => _episodes = eps);
    }).catchError((_) {});

    _service.getRelations(widget.anime.id).then((r) {
      if (!mounted) return;
      setState(() => _related = r);
    }).catchError((_) {});

    _service.getProgress(widget.anime.id).then((p) {
      if (!mounted) return;
      setState(() {
        _progress = p;
        final ep = (p?['episodeNumber'] as num?)?.toInt();
        if (ep != null && ep > 0) _selectedEpisode = ep;
      });
    }).catchError((_) {});

  }

  void _play(int epNumber) {
    openAnimePlayer(
      context,
      anime: _data,
      episodeNumber: epNumber,
      category: _category,
      allEpisodes: _episodes,
    );
  }

  Future<void> _clearProgress() async {
    await _service.removeFromHistory(widget.anime.id);
    if (mounted) setState(() => _progress = null);
  }

  List<String> _metaParts(AnimeCard a) {
    return [
      if (a.format != null && a.format!.isNotEmpty) a.format!,
      if (a.seasonYear != null) '${a.seasonYear}',
      if (a.episodes != null) '${a.episodes} eps',
      if (a.status != null && a.status!.isNotEmpty) _statusLabel(a.status!),
    ];
  }

  List<MapEntry<String, String>> _facts(AnimeCard a) {
    return [
      if (a.mainStudio != null && a.mainStudio!.isNotEmpty)
        MapEntry('Studio', a.mainStudio!),
      if (a.duration != null) MapEntry('Duration', '${a.duration} min/ep'),
      if (a.season != null && a.seasonYear != null)
        MapEntry(
          'Season',
          '${a.season![0]}${a.season!.substring(1).toLowerCase()} ${a.seasonYear}',
        ),
      if (a.popularity != null) MapEntry('Popularity', _compactNum(a.popularity!)),
      if (a.genres.isNotEmpty) MapEntry('Genres', a.genres.join(', ')),
    ];
  }

  Map<int, List<Map<String, dynamic>>>? _episodeMaps() {
    if (_episodes.isEmpty) return null;
    return {
      1: _episodes
          .map(
            (e) => {
              'episode_number': e.number,
              'name': _decodeEpisodeTitle(e.title),
              'overview': '',
              'runtime': _data.duration ?? 0,
              'still_path': e.thumbnail,
            },
          )
          .toList(),
    };
  }

  Map<String, Map<String, dynamic>> _episodeProgressMap() {
    final p = _progress;
    if (p == null) return const {};
    final ep = (p['episodeNumber'] as num?)?.toInt();
    final pos = (p['positionMs'] as num?)?.toInt() ?? 0;
    final dur = (p['durationMs'] as num?)?.toInt() ?? 0;
    if (ep == null || ep <= 0) return const {};
    return {
      'S1_E$ep': {'position': pos, 'duration': dur},
    };
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'RELEASING':
        return 'Airing';
      case 'FINISHED':
        return 'Completed';
      case 'NOT_YET_RELEASED':
        return 'Upcoming';
      case 'CANCELLED':
        return 'Cancelled';
      case 'HIATUS':
        return 'Hiatus';
      default:
        return s;
    }
  }

  String _compactNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_error != null)
                _buildError()
              else
                _buildScrollLayout(),
              const MediaDetailsBackButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: ForjaShellColors.sectionAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollLayout() {
    final a = _data;
    final hasProgress = _progress != null;
    final resumeEp =
        hasProgress ? (_progress!['episodeNumber'] as num?)?.toInt() : null;
    final heroHeight = ShellTokens.detailsHeroHeight(context, showEpisodeRail: true);
    final posMs = (_progress?['positionMs'] as num?)?.toInt();
    final durMs = (_progress?['durationMs'] as num?)?.toInt();

    final heroFocusUp = _revealedDetailsHeroPlayFocus;
    final showEpisodes = _episodes.isNotEmpty;
    final relatedOrder = showEpisodes ? 1 : 0;

    final scroll = SingleChildScrollView(
      controller: _detailsScrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HubDetailsHero(
            backdropUrl: a.bannerOrCover,
            title: a.displayTitle,
            subtitle: a.titleNative.isNotEmpty && a.titleNative != a.displayTitle
                ? a.titleNative
                : null,
            genres: a.genres,
            metaParts: _metaParts(a),
            rating: (a.averageScore ?? 0) > 0 ? (a.averageScore! / 10) : null,
            overview: a.cleanDescription,
            facts: _facts(a),
            height: heroHeight,
            bodyOverlap: ShellTokens.detailsHeroBodyOverlapWithEpisodes,
            positionMs: posMs,
            durationMs: durMs,
            actionRow: Row(
              children: [
                HubDetailsPlayRow(
                  label: hasProgress && resumeEp != null
                      ? 'Resume Ep $resumeEp'
                      : 'Play Ep 1',
                  enabled: _episodes.isNotEmpty,
                  onPlay: () => _play(resumeEp ?? 1),
                  focusNode: _heroPlayFocus,
                ),
                if (hasProgress) ...[
                  const SizedBox(width: 10),
                  HeroPillIconGroup(
                    slots: [
                      HeroPillIconSlot(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Clear progress',
                        onTap: _clearProgress,
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 10),
                HeroPillSegmentedChoice<String>(
                  selected: _category,
                  onSelected: (cat) => setState(() => _category = cat),
                  segments: const [
                    HeroPillSegment(
                      value: 'sub',
                      label: 'SUB',
                      icon: Icons.subtitles_rounded,
                    ),
                    HeroPillSegment(
                      value: 'dub',
                      label: 'DUB',
                      icon: Icons.mic_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          MediaDetailsBody(
            backgroundColor: AppTheme.bgDark,
            bodyOverlap: ShellTokens.detailsHeroBodyOverlapWithEpisodes,
            topSpacing: ShellTokens.detailsBodyTopSpacingWithEpisodes,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showEpisodes)
                  MediaDetailsBody.padContent(
                    context,
                    TvSeasonEpisodePicker(
                      tmdbId: a.id,
                      seasonCount: 1,
                      selectedSeason: 1,
                      selectedEpisode: _selectedEpisode,
                      isLoadingSeason: false,
                      seasonData: null,
                      watchedEpisodes: const {},
                      fallbackPosterPath: a.coverUrl,
                      customEpisodesBySeason: _episodeMaps(),
                      episodeProgress: _episodeProgressMap(),
                      onSeasonSelected: (_) {},
                      onEpisodeSelected: (ep) {
                        setState(() => _selectedEpisode = ep);
                        final match = _episodes.where((e) => e.number == ep);
                        if (match.isNotEmpty && match.first.aired) {
                          _play(ep);
                        }
                      },
                      onToggleWatched: (_, _) {},
                      tvTabId: MediaDetailsTv.tabId,
                      tvSeasonRowId: 'seasons',
                      tvEpisodeRowId: 'episodes',
                      tvRowOrderBase: 0,
                      tvFocusUp: heroFocusUp,
                    ),
                  )
                else
                  MediaDetailsBody.padContent(
                    context,
                    Text(
                      'No episodes available yet',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                    ),
                  ),
                if (_related.isNotEmpty) ...[
                  const SizedBox(height: ShellTokens.detailsSectionSpacing),
                  _buildRelated(
                    tvRowOrder: relatedOrder,
                    tvFocusUp: showEpisodes ? null : heroFocusUp,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return MediaDetailsTvScope(
      heroPlayFocus: _heroPlayFocus,
      scrollController: _detailsScrollController,
      child: scroll,
    );
  }

  String _decodeEpisodeTitle(String title) => title
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  Widget _buildRelated({
    required int tvRowOrder,
    VoidCallback? tvFocusUp,
  }) {
    return HubCatalogSection<AnimeCard>(
      title: 'More Like This',
      items: _related,
      tvTabId: MediaDetailsTv.tabId,
      tvRowId: 'related',
      tvRowOrder: tvRowOrder,
      tvFocusUp: tvFocusUp,
      cardBuilder: (context, r, index) => HubPosterCard(
        imageUrl: r.coverUrl,
        title: r.displayTitle,
        onTap: () => openAnimeDetails(context, r),
        listIndex: index,
        tvTabId: MediaDetailsTv.tabId,
        tvRowId: 'related',
      ),
    );
  }
}
