import 'package:flutter/material.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/media_details_cast_section.dart';
import 'package:forja/shared/widgets/media_details_trailers_section.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shared/widgets/watch_series_progress.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'anime_player_screen.dart';

Future<T?> openAnimeDetails<T>(BuildContext context, AnimeCard anime) {
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute(
      (_) => AnimeDetailsScreen(anime: anime),
      settings: const RouteSettings(name: 'anime_details'),
    ),
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
  final EpisodeWatchedService _episodeWatchedService = EpisodeWatchedService();
  final ScrollController _detailsScrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'anime-details-play');
  final FocusNode _backFocus = FocusNode(debugLabel: 'anime-details-back');
  bool _detailsHeroInitialFocusDone = false;

  /// AniList PREQUEL→SEQUEL spine (ordered). Empty until [getSeasons] returns.
  List<AnimeCard> _seasons = [];
  /// 1-based index into [_seasons] (matches [TvSeasonEpisodePicker]).
  int _selectedSeason = 1;
  int _loadGen = 0;

  AnimeCard? _full;
  List<AnimeEpisode> _episodes = [];
  bool _episodesLoading = true;
  List<AnimeRelation> _related = [];
  List<Map<String, String>> _characters = [];
  List<Map<String, String>> _staff = [];
  List<AnimeCard> _recommendations = [];
  Map<String, dynamic>? _progress;
  Set<String> _watchedEpisodes = {};
  String? _error;

  String _category = 'sub';
  int _selectedEpisode = 1;

  @override
  void initState() {
    super.initState();
    SettingsService.animeTitleLanguageNotifier.addListener(_onTitleLanguage);
    AnimeService.watchHistoryRevision.addListener(_onHistoryChanged);
    _seasons = [widget.anime];
    _load();
  }

  @override
  void dispose() {
    AnimeService.watchHistoryRevision.removeListener(_onHistoryChanged);
    SettingsService.animeTitleLanguageNotifier.removeListener(_onTitleLanguage);
    _heroPlayFocus.dispose();
    _backFocus.dispose();
    _detailsScrollController.dispose();
    super.dispose();
  }

  void _onTitleLanguage() {
    if (mounted) setState(() {});
  }

  void _onHistoryChanged() => _refreshProgress();

  AnimeCard get _activeSeed {
    if (_seasons.isEmpty) return widget.anime;
    final i = (_selectedSeason - 1).clamp(0, _seasons.length - 1);
    return _seasons[i];
  }

  AnimeCard get _data => _full ?? _activeSeed;

  int get _activeId => _data.id;

  Future<void> _refreshProgress() async {
    try {
      final p = await _service.getProgress(_activeId);
      if (!mounted) return;
      setState(() {
        _progress = p;
        final ep = (p?['episodeNumber'] as num?)?.toInt();
        if (ep != null &&
            ep > 0 &&
            (_episodesLoading || _episodes.any((e) => e.number == ep))) {
          _selectedEpisode = ep;
        }
      });
    } catch (_) {}
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

  void _focusDetailsBack() {
    if (!_backFocus.canRequestFocus) {
      maybePopShellOverlay();
      return;
    }
    _backFocus.requestFocus();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    _loadSeasonContent(_activeSeed);

    _service.getSeasons(widget.anime.id).then((chain) {
      if (!mounted || chain.isEmpty) return;
      final idx = chain.indexWhere((s) => s.id == widget.anime.id);
      setState(() {
        _seasons = chain;
        if (idx >= 0) _selectedSeason = idx + 1;
      });
    }).catchError((_) {});
  }

  void _onSeasonSelected(int season) {
    if (season < 1 ||
        season > _seasons.length ||
        season == _selectedSeason) {
      return;
    }
    setState(() {
      _selectedSeason = season;
      _selectedEpisode = 1;
      _full = null;
      _progress = null;
      _characters = [];
      _staff = [];
      _recommendations = [];
      _related = [];
      _watchedEpisodes = {};
      _error = null;
    });
    _loadSeasonContent(_seasons[season - 1]);
  }

  void _loadSeasonContent(AnimeCard seed) {
    final gen = ++_loadGen;
    setState(() {
      _episodes = [];
      _episodesLoading = true;
      _characters = [];
      _staff = [];
      _recommendations = [];
      _related = [];
    });

    // Episodes load only after details for this opened season (thumbs + count).
    _service.getDetails(seed.id).then((d) async {
      if (!mounted || gen != _loadGen) return;
      final seeded = seed.tmdbBackdropUrl == null
          ? d
          : d.copyWith(tmdbBackdropUrl: seed.tmdbBackdropUrl);
      final enriched = await _service.attachTmdbBackdrop(seeded);
      if (!mounted || gen != _loadGen) return;
      setState(() => _full = enriched);
      _loadEpisodesForOpenedSeason(enriched, gen: gen);
    }).catchError((e) {
      if (mounted && gen == _loadGen && _full == null) {
        setState(() {
          _error = 'Failed to load: $e';
          _episodesLoading = false;
        });
      }
    });

    if (seed.tmdbBackdropUrl == null) {
      _service.attachTmdbBackdrop(seed).then((enriched) {
        if (!mounted || gen != _loadGen || _full != null) return;
        setState(() => _full = enriched);
      });
    }

    _service.getRelations(seed.id).then((r) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _related = r);
    }).catchError((_) {});

    _service.getCharacters(seed.id).then((c) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _characters = c);
    }).catchError((_) {});

    _service.getStaff(seed.id).then((s) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _staff = s);
    }).catchError((_) {});

    _service.getRecommendations(seed.id).then((r) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _recommendations = r);
    }).catchError((_) {});

    _service.getProgress(seed.id).then((p) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _progress = p;
        final ep = (p?['episodeNumber'] as num?)?.toInt();
        if (ep != null &&
            ep > 0 &&
            (_episodesLoading || _episodes.any((e) => e.number == ep))) {
          _selectedEpisode = ep;
        }
      });
    }).catchError((_) {});

    _loadWatchedEpisodes(forId: seed.id, gen: gen);
  }

  void _loadEpisodesForOpenedSeason(AnimeCard details, {required int gen}) {
    _service.getEpisodes(details).then((eps) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _episodes = eps;
        _episodesLoading = false;
        if (_episodes.isNotEmpty &&
            !_episodes.any((e) => e.number == _selectedEpisode)) {
          _selectedEpisode = _episodes.first.number;
        }
      });
    }).catchError((_) {
      if (mounted && gen == _loadGen) {
        setState(() => _episodesLoading = false);
      }
    });
  }

  void _play(int epNumber, {Duration? startPosition}) {
    openAnimePlayer(
      context,
      anime: _data,
      episodeNumber: epNumber,
      category: _category,
      allEpisodes: _episodes,
      startPosition: startPosition,
    ).then((_) {
      _refreshProgress();
      _loadWatchedEpisodes();
    });
  }

  void _playSelected() {
    final match = _episodes.where((e) => e.number == _selectedEpisode);
    if (match.isEmpty || !match.first.aired) return;
    final p = _progress;
    final resumeEp = (p?['episodeNumber'] as num?)?.toInt();
    Duration? start;
    if (p != null && resumeEp == _selectedEpisode) {
      final posMs = (p['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (p['durationMs'] as num?)?.toInt() ?? 0;
      // Same as movies: ≥85% (or <2%) restarts at 0 — avoid credits seek.
      if (posMs > 0 && isInProgressResume(posMs, durMs)) {
        start = Duration(milliseconds: posMs);
      }
    }
    _play(_selectedEpisode, startPosition: start);
  }

  Future<void> _clearProgress() async {
    final id = _activeId;
    await _service.removeFromHistory(id);
    // Match movies/TV trash: drop cached extracts + sticky provider pin so
    // next Play re-resolves (not "Using saved source…").
    await _service.clearPlaybackCachesForShow(animeId: id);
    if (mounted) setState(() => _progress = null);
  }

  Future<void> _loadWatchedEpisodes({int? forId, int? gen}) async {
    final id = forId ?? _activeId;
    final set = await _episodeWatchedService.getWatchedSet(
      id,
      catalog: EpisodeWatchedService.catalogAnilist,
    );
    if (!mounted) return;
    if (gen != null && gen != _loadGen) return;
    setState(() => _watchedEpisodes = set);
  }

  Future<void> _toggleEpisodeWatched(int season, int episode) async {
    await _episodeWatchedService.toggle(
      _activeId,
      season,
      episode,
      catalog: EpisodeWatchedService.catalogAnilist,
    );
    await _loadWatchedEpisodes();
  }

  Widget? _seriesProgressWidget() {
    final total = _episodes.isNotEmpty
        ? _episodes.length
        : (_data.episodes ?? 0);
    final watched = _watchedEpisodes.length;
    if (total <= 0 || watched <= 0) return null;
    return WatchSeriesProgress(watched: watched, total: total);
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
      _selectedSeason: _episodes
          .map(
            (e) => {
              'episode_number': e.number,
              'name': _decodeEpisodeTitle(e.title),
              'overview': '',
              'runtime': _data.duration ?? 0,
              'still_path': e.thumbnail,
              'aired': e.aired,
            },
          )
          .toList(),
    };
  }

  Map<int, String> _seasonPosters() {
    final out = <int, String>{};
    for (var i = 0; i < _seasons.length; i++) {
      final url = _seasons[i].coverUrl;
      if (url.isNotEmpty) out[i + 1] = url;
    }
    return out;
  }

  Map<String, Map<String, dynamic>> _episodeProgressMap() {
    final p = _progress;
    if (p == null) return const {};
    final ep = (p['episodeNumber'] as num?)?.toInt();
    final pos = (p['positionMs'] as num?)?.toInt() ?? 0;
    final dur = (p['durationMs'] as num?)?.toInt() ?? 0;
    if (ep == null || ep <= 0) return const {};
    // Watched / progress keys stay S1 per AniList Media (see watchedSeasonForKeys).
    return {
      'S1_E$ep': {'position': pos, 'duration': dur},
    };
  }

  List<AnimeRelation> get _relatedFiltered {
    if (_related.isEmpty) return const [];
    final seasonIds = _seasons.map((s) => s.id).toSet()..add(_activeId);
    return _related.where((r) => !seasonIds.contains(r.anime.id)).toList();
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
              MediaDetailsBackButton(focusNode: _backFocus),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return ShellErrorRetryPanel(
      message: _error!,
      onRetry: _load,
    );
  }

  Widget _buildScrollLayout() {
    final a = _data;
    final resumeEp = (_progress?['episodeNumber'] as num?)?.toInt();
    final rawPosMs = (_progress?['positionMs'] as num?)?.toInt();
    final rawDurMs = (_progress?['durationMs'] as num?)?.toInt();
    final canResumeSelected = _progress != null &&
        resumeEp == _selectedEpisode &&
        isInProgressResume(rawPosMs ?? 0, rawDurMs ?? 0);
    final heroHeight = DetailsTokens.heroHeight(context, showEpisodeRail: true);
    final posMs = canResumeSelected ? rawPosMs : null;
    final durMs = canResumeSelected ? rawDurMs : null;
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;

    if (policy.heroPlayAutoFocus &&
        !_detailsHeroInitialFocusDone &&
        _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _detailsHeroInitialFocusDone) return;
        if (_heroPlayFocus.canRequestFocus) {
          _heroPlayFocus.requestFocus();
          _detailsHeroInitialFocusDone = true;
        }
      });
    }

    final heroFocusUp = _revealedDetailsHeroPlayFocus;
    final heroPopUp = tvFocus ? _focusDetailsBack : null;
    final showEpisodeRail = _episodesLoading || _episodes.isNotEmpty;
    final related = _relatedFiltered;
    final trailers = [
      if (_data.mediaTrailer != null) _data.mediaTrailer!,
    ];
    final showCharacters = _characters.isNotEmpty;
    final showStaff = _staff.isNotEmpty;
    final showTrailers = trailers.isNotEmpty;
    final showRecs = _recommendations.isNotEmpty;
    final showRelated = related.isNotEmpty;
    final hasMetaRows =
        showCharacters || showStaff || showTrailers || showRecs || showRelated;

    var rowOrder = showEpisodeRail ? 1 : 0;
    final relatedOrder = showRelated ? rowOrder++ : null;
    final charactersOrder = showCharacters ? rowOrder++ : null;
    final staffOrder = showStaff ? rowOrder++ : null;
    final trailersOrder = showTrailers ? rowOrder++ : null;
    final recsOrder = showRecs ? rowOrder : null;

    final firstMetaFocusUp = showEpisodeRail ? null : heroFocusUp;

    final episodePicker = showEpisodeRail
        ? MediaDetailsBody.padContent(
            context,
            TvSeasonEpisodePicker(
              tmdbId: a.id,
              seasonCount: _seasons.length.clamp(1, 99),
              selectedSeason: _selectedSeason,
              selectedEpisode: _selectedEpisode,
              isLoadingSeason: _episodesLoading,
              seasonData: null,
              watchedEpisodes: _watchedEpisodes,
              watchedCatalog: EpisodeWatchedService.catalogAnilist,
              watchedSeasonForKeys: 1,
              fallbackPosterPath: a.coverUrl,
              seasonPosters: _seasonPosters(),
              customEpisodesBySeason: _episodeMaps(),
              episodeProgress: _episodeProgressMap(),
              onSeasonSelected: _onSeasonSelected,
              onEpisodeSelected: (ep) {
                setState(() => _selectedEpisode = ep);
              },
              onEpisodePlay: (ep) {
                setState(() => _selectedEpisode = ep);
                _playSelected();
              },
              onToggleWatched: _toggleEpisodeWatched,
              tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
              tvSeasonRowId: 'seasons',
              tvEpisodeRowId: 'episodes',
              tvRowOrderBase: 0,
              tvFocusUp: heroFocusUp,
            ),
          )
        : MediaDetailsBody.padContent(
            context,
            Text(
              'No episodes available yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 14,
              ),
            ),
          );

    final scroll = SingleChildScrollView(
      controller: _detailsScrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HubDetailsHero(
            backdropUrl: a.heroBackdrop,
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
            pageBottomChild: episodePicker,
            positionMs: posMs,
            durationMs: durMs,
            seriesProgress: _seriesProgressWidget(),
            actionRow: DetailsHeroTvActionScope(
              tabId: MediaDetailsTv.tabId,
              itemCount: (_progress != null ? 2 : 1) + 2,
              onFocusUp: heroPopUp,
              child: Row(
                children: [
                  HubDetailsPlayRow(
                    label: canResumeSelected
                        ? 'Resume Ep $_selectedEpisode'
                        : 'Play Ep $_selectedEpisode',
                    enabled: _episodes.isNotEmpty,
                    onPlay: _playSelected,
                    focusNode: policy.heroPlayAutoFocus ? _heroPlayFocus : null,
                    onUpEdge: heroPopUp,
                    tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                    tvItemIndex: 0,
                  ),
                  if (_progress != null) ...[
                    const SizedBox(width: 10),
                    HeroPillIconGroup(
                      tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                      tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
                      tvItemIndexStart: 1,
                      onUpEdge: heroPopUp,
                      slots: [
                        HeroPillIconSlot(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Clear progress & stream cache',
                          onTap: _clearProgress,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(width: 10),
                  HeroPillSegmentedChoice<String>(
                    selected: _category,
                    onSelected: (cat) => setState(() => _category = cat),
                    tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                    tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
                    tvItemIndexStart: _progress != null ? 2 : 1,
                    onUpEdge: heroPopUp,
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
          ),
          if (hasMetaRows)
            MediaDetailsBody(
              backgroundColor: AppTheme.bgDark,
              bodyOverlap: 0,
              topSpacing: DetailsTokens.bodyTopSpacingWithEpisodes,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showRelated)
                    _buildRelated(
                      items: related,
                      tvRowOrder: relatedOrder!,
                      tvFocusUp: firstMetaFocusUp,
                    ),
                  if (showCharacters) ...[
                    if (showRelated)
                      const SizedBox(height: DetailsTokens.sectionSpacing),
                    MediaDetailsCastSection(
                      cast: _characters,
                      title: 'Characters',
                      tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                      tvRowId: 'characters',
                      tvRowOrder: charactersOrder!,
                      tvFocusUp: showRelated ? null : firstMetaFocusUp,
                    ),
                  ],
                  if (showStaff) ...[
                    if (showRelated || showCharacters)
                      const SizedBox(height: DetailsTokens.sectionSpacing),
                    MediaDetailsCastSection(
                      cast: _staff,
                      title: 'Staff',
                      tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                      tvRowId: 'staff',
                      tvRowOrder: staffOrder!,
                      tvFocusUp:
                          (showRelated || showCharacters) ? null : firstMetaFocusUp,
                    ),
                  ],
                  if (showTrailers) ...[
                    if (showRelated || showCharacters || showStaff)
                      const SizedBox(height: DetailsTokens.sectionSpacing),
                    MediaDetailsTrailersSection(
                      trailers: trailers,
                      tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                      tvRowId: 'trailers',
                      tvRowOrder: trailersOrder!,
                      tvFocusUp: (showRelated || showCharacters || showStaff)
                          ? null
                          : firstMetaFocusUp,
                    ),
                  ],
                  if (showRecs) ...[
                    if (showRelated ||
                        showCharacters ||
                        showStaff ||
                        showTrailers)
                      const SizedBox(height: DetailsTokens.sectionSpacing),
                    _buildRecommendations(
                      items: _recommendations,
                      tvRowOrder: recsOrder!,
                      tvFocusUp: (showRelated ||
                              showCharacters ||
                              showStaff ||
                              showTrailers)
                          ? null
                          : firstMetaFocusUp,
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

  Widget _buildRecommendations({
    required List<AnimeCard> items,
    required int tvRowOrder,
    VoidCallback? tvFocusUp,
  }) {
    return HubCatalogSection<AnimeCard>(
      title: 'More Like This',
      items: items,
      embedded: true,
      tvTabId: ShellScope.inputPolicyOf(context).useFocusableMoodChips
          ? MediaDetailsTv.tabId
          : null,
      tvRowId: 'recommendations',
      tvRowOrder: tvRowOrder,
      tvFocusUp: tvFocusUp,
      cardBuilder: (context, a, index) => HubPosterCard(
        imageUrl: a.coverUrl,
        title: a.displayTitle,
        subtitle: a.seasonYear?.toString(),
        onTap: () => openAnimeDetails(context, a),
        listIndex: index,
        tvTabId: ShellScope.inputPolicyOf(context).useFocusableMoodChips
            ? MediaDetailsTv.tabId
            : null,
        tvRowId: 'recommendations',
      ),
    );
  }

  Widget _buildRelated({
    required List<AnimeRelation> items,
    required int tvRowOrder,
    VoidCallback? tvFocusUp,
  }) {
    return HubCatalogSection<AnimeRelation>(
      title: 'Related',
      items: items,
      embedded: true,
      tvTabId: ShellScope.inputPolicyOf(context).useFocusableMoodChips
          ? MediaDetailsTv.tabId
          : null,
      tvRowId: 'related',
      tvRowOrder: tvRowOrder,
      tvFocusUp: tvFocusUp,
      cardBuilder: (context, r, index) => HubPosterCard(
        imageUrl: r.anime.coverUrl,
        title: r.anime.displayTitle,
        subtitle: r.formatLabel,
        badge: r.label,
        onTap: () => openAnimeDetails(context, r.anime),
        listIndex: index,
        tvTabId: ShellScope.inputPolicyOf(context).useFocusableMoodChips
            ? MediaDetailsTv.tabId
            : null,
        tvRowId: 'related',
      ),
    );
  }
}
