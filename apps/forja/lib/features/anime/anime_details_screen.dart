import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/anime/providers/anime_details_providers.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/hero/hero_utils.dart';
import 'package:forja/shared/widgets/hero/rotating_hero_backdrop.dart';
import 'package:forja/shared/widgets/hero/tmdb_paint_gate.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/shared/widgets/hub_details/hub_catalog_sources.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/hub_details/hub_engine_auto_play.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/widgets/hub_list_status_hero.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/services/list_follow_from_watched.dart';
import 'package:forja/shared/widgets/media_details/media_details.dart';
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
    shellTabId: 'anime',
  );
}

class AnimeDetailsScreen extends ConsumerStatefulWidget {
  final AnimeCard anime;
  const AnimeDetailsScreen({super.key, required this.anime});

  @override
  ConsumerState<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends ConsumerState<AnimeDetailsScreen> {
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
  List<String> _heroBackdropUrls = [];
  Map<String, dynamic>? _progress;
  Set<String> _watchedEpisodes = {};
  String? _error;

  String _category = 'sub';
  int _selectedEpisode = 1;
  bool _listMenuOpen = false;

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

  AnimeTmdbQuery get _tmdbQuery {
    final a = _data;
    final title = a.titleEnglish.trim().isNotEmpty
        ? a.titleEnglish.trim()
        : a.titleRomaji.trim();
    return (
      title: title,
      year: a.seasonYear,
      isMovie: (a.format ?? '').toUpperCase() == 'MOVIE',
    );
  }

  HubListFollowTarget get _followTarget {
    final a = _data;
    return HubListFollowTarget.anime(
      anilistId: a.id,
      title: a.displayTitle,
      posterPath: a.coverUrl,
      voteAverage: (a.averageScore ?? 0) / 10.0,
      releaseDate: a.seasonYear?.toString() ?? '',
    );
  }

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
    void focusBack() {
      if (!mounted) return;
      if (!_backFocus.canRequestFocus) {
        maybePopShellOverlay();
        return;
      }
      _backFocus.requestFocus();
    }

    _scrollDetailsHeroIntoView();
    if (!_detailsScrollController.hasClients) {
      focusBack();
      return;
    }
    _detailsScrollController
        .animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(focusBack);
  }

  Future<void> _load() async {
    setState(() => _error = null);
    _loadSeasonContent(_activeSeed);

    ref.read(animeSeasonsProvider(widget.anime.id).future).then((chain) {
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
      _heroBackdropUrls = [];
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
      _heroBackdropUrls = [];
    });

    // Paint episode rail from seed count immediately — don't wait on AniList
    // details (streamingEpisodes thumbs) or TMDB. Enrich when details lands.
    _loadEpisodesForOpenedSeason(seed, gen: gen);

    ref.read(animeDetailsProvider(seed.id).future).then((d) async {
      if (!mounted || gen != _loadGen) return;
      final seeded = seed.tmdbBackdropUrl == null
          ? d
          : d.copyWith(tmdbBackdropUrl: seed.tmdbBackdropUrl);
      setState(() => _full = seeded);
      _loadEpisodesForOpenedSeason(seeded, gen: gen);
      _loadHeroBackdropUrls(seeded, gen: gen);
      final enriched = await _service.attachTmdbBackdrop(seeded);
      if (!mounted || gen != _loadGen) return;
      setState(() => _full = enriched);
      _loadHeroBackdropUrls(enriched, gen: gen);
    }).catchError((e) {
      if (mounted && gen == _loadGen && _full == null) {
        setState(() => _error = 'Failed to load: $e');
      }
    });

    if (seed.tmdbBackdropUrl == null) {
      _service.attachTmdbBackdrop(seed).then((enriched) {
        if (!mounted || gen != _loadGen || _full != null) return;
        setState(() => _full = enriched);
      });
    }
    _loadHeroBackdropUrls(seed, gen: gen);

    ref.read(animeRelationsProvider(seed.id).future).then((r) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _related = r);
    }).catchError((_) {});

    ref.read(animeCharactersProvider(seed.id).future).then((c) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _characters = c);
    }).catchError((_) {});

    ref.read(animeStaffProvider(seed.id).future).then((s) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _staff = s);
    }).catchError((_) {});

    ref.read(animeRecommendationsProvider(seed.id).future).then((r) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _recommendations = r);
    }).catchError((_) {});

    ref.read(animeProgressProvider(seed.id).future).then((p) {
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

  Future<void> _loadHeroBackdropUrls(AnimeCard card, {required int gen}) async {
    final urls = await _service.resolveTmdbHeroUrls(card);
    if (!mounted || gen != _loadGen) return;
    final fallback = card.heroBackdrop.trim();
    final merged = <String>[
      if (fallback.isNotEmpty) fallback,
      ...urls,
    ];
    // Dedupe while keeping order
    final seen = <String>{};
    final out = <String>[];
    for (final u in merged) {
      if (seen.add(u)) out.add(u);
    }
    if (out.isEmpty) return;
    setState(() => _heroBackdropUrls = out);
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

  Movie _playMovieFor(RichMediaDetails? tmdb) {
    final m = tmdb?.movie;
    if (m != null && m.id > 0) return m;
    final a = _data;
    return Movie(
      id: -a.id,
      title: a.displayTitle,
      posterPath: a.coverUrl,
      backdropPath: a.heroBackdrop,
      voteAverage: (a.averageScore ?? 0) / 10.0,
      releaseDate: a.seasonYear?.toString() ?? '',
      overview: a.cleanDescription,
      genres: a.genres,
      runtime: a.duration ?? 0,
      mediaType: 'anime',
      numberOfEpisodes: a.episodes ?? 0,
    );
  }

  Future<void> _afterPlayClosed() async {
    await _refreshProgress();
    _loadWatchedEpisodes();
    if (!mounted) return;
    if (_detailsScrollController.hasClients) {
      _detailsScrollController.jumpTo(0);
    }
    ShellTvFocusCoordinator.claimHeroPlayAfterPlayerExit(
      _heroPlayFocus,
      isMounted: () => mounted,
    );
  }

  void _play(int epNumber, {Duration? startPosition}) {
    HubListFollow.markWatchingOnPlay(_followTarget);
    unawaited(_playEpisode(epNumber, startPosition: startPosition));
  }

  Future<void> _playEpisode(int epNumber, {Duration? startPosition}) async {
    // Movie RFC-063: Forja + Auto + Webstreaming off → race anime plugins.
    if (await hubEngineAutoPlayEnabled()) {
      if (!mounted) return;
      final tmdb = ref.read(animeTmdbEnrichmentProvider(_tmdbQuery)).asData?.value;
      final movie = _playMovieFor(tmdb);
      final isMovie = (movie.mediaType == 'movie') ||
          (_data.format ?? '').toUpperCase() == 'MOVIE';
      final malId = await _service.resolveMalId(_activeId);
      if (!mounted) return;
      await runHubEngineAutoPlay(
        context: context,
        movie: movie,
        engineCategory: 'anime',
        season: isMovie ? null : 1,
        episode: isMovie ? null : epNumber,
        anilistId: _activeId,
        malId: malId,
        animeAudioCategory: _category,
        startPosition: startPosition,
        loadingSubtitle: 'EP $epNumber',
        hubEpisodes: isMovie
            ? null
            : [
                for (final e in _episodes)
                  PlayerHubEpisode(
                    number: e.number,
                    title: e.title,
                    notShippedYet: !e.aired,
                  ),
              ],
      );
      if (!mounted) return;
      await _afterPlayClosed();
      return;
    }

    if (!mounted) return;
    await openAnimePlayer(
      context,
      anime: _data,
      episodeNumber: epNumber,
      category: _category,
      allEpisodes: _episodes,
      startPosition: startPosition,
    );
    if (!mounted) return;
    await _afterPlayClosed();
  }

  void _openCatalogSources(Movie movie) {
    final isTv = movie.mediaType == 'tv';
    unawaited(() async {
      final malId = await _service.resolveMalId(_activeId);
      if (!mounted) return;
      await openHubCatalogSources(
        context: context,
        movie: movie,
        season: isTv ? 1 : null,
        episode: isTv ? _selectedEpisode : null,
        anilistId: _activeId,
        malId: malId,
        engineCategory: 'anime',
        animeAudioCategory: _category,
      );
    }());
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
      // Same as movies: ≥85% (or <2%) restarts at 0 - avoid credits seek.
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
    await HubListFollow.clearProgress(_followTarget);
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
    final watched = await _episodeWatchedService.isWatched(
      _activeId,
      season,
      episode,
      catalog: EpisodeWatchedService.catalogAnilist,
    );
    HubListFollow.syncEpisodeWatched(_followTarget, episode: episode, watched: watched);
    await _loadWatchedEpisodes();
    final total = _episodes.isNotEmpty
        ? _episodes.length
        : (_data.episodes ?? 0);
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}
    await ListFollowFromWatched.applyHub(
      target: _followTarget,
      watchedCount: _watchedEpisodes.length,
      totalEpisodes: total,
      episodeNowWatched: watched,
      container: container,
    );
  }

  Widget? _seriesProgressWidget() {
    final total = _episodes.isNotEmpty
        ? _episodes.length
        : (_data.episodes ?? 0);
    final watched = _watchedEpisodes.length;
    if (total <= 0 || watched <= 0) return null;
    return WatchSeriesProgress(watched: watched, total: total);
  }

  List<String> _metaParts(AnimeCard a, RichMediaDetails? tmdb) {
    final cert = tmdb?.extras.certification.trim() ?? '';
    return [
      if (a.format != null && a.format!.isNotEmpty) a.format!,
      if (a.seasonYear != null) '${a.seasonYear}',
      if (a.episodes != null) '${a.episodes} eps',
      if (a.status != null && a.status!.isNotEmpty) _statusLabel(a.status!),
      if (cert.isNotEmpty) cert,
    ];
  }

  List<MapEntry<String, String>> _facts(AnimeCard a, RichMediaDetails? tmdb) {
    final extras = tmdb?.extras;
    final director = extras == null ? null : pickDirectorFromCrew(extras.crew);
    final creators = extras?.creators ?? const <String>[];
    final networks = extras?.networks ?? const <String>[];
    final languages = extras?.spokenLanguages ?? const <String>[];
    final companies = extras?.productionCompanies ?? const <String>[];
    return [
      if (a.displayTitle.trim().isNotEmpty)
        MapEntry('Name', a.displayTitle.trim()),
      if (a.mainStudio != null && a.mainStudio!.isNotEmpty)
        MapEntry('Studio', a.mainStudio!)
      else if (companies.isNotEmpty)
        MapEntry('Studio', companies.take(2).join(', ')),
      if (a.duration != null) MapEntry('Duration', '${a.duration} min/ep'),
      if (a.season != null && a.seasonYear != null)
        MapEntry(
          'Season',
          '${a.season![0]}${a.season!.substring(1).toLowerCase()} ${a.seasonYear}',
        ),
      if (a.popularity != null)
        MapEntry('Popularity', _compactNum(a.popularity!))
      else if ((extras?.popularity ?? 0) > 0)
        MapEntry('Popularity', _compactNum(extras!.popularity.round())),
      if (a.genres.isNotEmpty)
        MapEntry('Genres', a.genres.join(', '))
      else if ((tmdb?.movie.genres ?? const <String>[]).isNotEmpty)
        MapEntry('Genres', tmdb!.movie.genres.take(4).join(', ')),
      if (director != null && director.isNotEmpty)
        MapEntry('Director', director),
      if (creators.isNotEmpty)
        MapEntry('Created by', creators.take(3).join(', ')),
      if (networks.isNotEmpty)
        MapEntry('Network', networks.take(2).join(', ')),
      if (languages.isNotEmpty)
        MapEntry('Language', languages.take(2).join(', ')),
    ];
  }

  String _overview(AnimeCard a, RichMediaDetails? tmdb) {
    final anilist = a.cleanDescription;
    if (anilist.isNotEmpty) return anilist;
    return tmdb?.movie.overview.trim() ?? '';
  }

  String? _tmdbLogoUrl(RichMediaDetails? tmdb) {
    final path = tmdb?.movie.logoPath.trim() ?? '';
    if (path.isEmpty) return null;
    return path.startsWith('http') ? path : TmdbApi.getImageUrl(path);
  }

  List<String> _heroUrls(AnimeCard a, RichMediaDetails? tmdb) {
    final urls = <String>[
      ..._heroBackdropUrls,
      if (a.heroBackdrop.isNotEmpty) a.heroBackdrop,
      for (final raw in tmdb?.movie.screenshots ?? const <String>[])
        if (raw.trim().isNotEmpty)
          raw.trim().startsWith('http')
              ? raw.trim()
              : TmdbApi.getBackdropUrl(raw.trim()),
    ];
    return RotatingHeroBackdrop.normalizeUrls(urls);
  }

  List<Map<String, String>> _crewAsCast(List<Map<String, String>> crew) {
    return [
      for (final c in crew)
        if ((c['name'] ?? '').trim().isNotEmpty)
          {
            'name': c['name']!,
            'character': (c['job'] ?? '').trim(),
            'profilePath': (c['profilePath'] ?? '').trim(),
          },
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
    final tmdb =
        ref.watch(animeTmdbEnrichmentProvider(_tmdbQuery)).asData?.value;
    return TmdbPaintGate(
      ready: tmdb != null,
      builder: (context, level) => _buildPaintedLayout(a, tmdb, level),
    );
  }

  Widget _buildPaintedLayout(
    AnimeCard a,
    RichMediaDetails? tmdb,
    TmdbPaintLevel level,
  ) {
    final paintTmdb = level.hasChrome || level.hasRows ? tmdb : null;
    final resumeEp = (_progress?['episodeNumber'] as num?)?.toInt();
    final rawPosMs = (_progress?['positionMs'] as num?)?.toInt();
    final rawDurMs = (_progress?['durationMs'] as num?)?.toInt();
    final canResumeSelected = _progress != null &&
        resumeEp == _selectedEpisode &&
        isInProgressResume(rawPosMs ?? 0, rawDurMs ?? 0);
    final showSeasonRail = _seasons.length > 1;
    final heroHeight = DetailsTokens.heroHeight(
      context,
      showEpisodeRail: true,
      showSeasonRail: showSeasonRail,
    );
    final posMs = canResumeSelected ? rawPosMs : null;
    final durMs = canResumeSelected ? rawDurMs : null;
    final isUpcoming = a.status == 'NOT_YET_RELEASED';
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;

    if (policy.heroPlayAutoFocus &&
        !isUpcoming &&
        !_detailsHeroInitialFocusDone &&
        _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _detailsHeroInitialFocusDone) return;
        if (_heroPlayFocus.context == null || !_heroPlayFocus.canRequestFocus) {
          return;
        }
        _heroPlayFocus.requestFocus();
        _detailsHeroInitialFocusDone = true;
      });
    }

    final heroFocusUp = _revealedDetailsHeroPlayFocus;
    final heroPopUp = tvFocus ? _focusDetailsBack : null;
    final episodeFocusUp =
        tvFocus && isUpcoming ? _focusDetailsBack : heroFocusUp;
    final listExtra = HubListStatusHero.extraFocusSlots(_listMenuOpen);
    final playbackSnap = ref.watch(settingsPlaybackProvider).valueOrNull;
    final showCatalogSources = hubHasCatalogPanelSources(playbackSnap);
    var tvIndex = 0;
    final playIndex = isUpcoming ? null : tvIndex++;
    final sourcesIndex =
        !isUpcoming && showCatalogSources ? tvIndex++ : null;
    final clearIndex = !isUpcoming && _progress != null ? tvIndex++ : null;
    final listIndex = tvIndex++;
    tvIndex += listExtra;
    final subDubIndex = isUpcoming ? null : tvIndex;
    if (!isUpcoming) tvIndex += 2;
    final heroActionCount = isUpcoming ? tvIndex : tvIndex + 2;
    final showEpisodeRail = _episodesLoading || _episodes.isNotEmpty;
    final related = _relatedFiltered;
    final tmdbCast = level.hasRows
        ? (tmdb?.extras.cast ?? const <Map<String, String>>[])
        : const <Map<String, String>>[];
    final tmdbCrew = level.hasRows
        ? _crewAsCast(tmdb?.extras.crew ?? const [])
        : const <Map<String, String>>[];
    final tmdbTrailers = level.hasRows
        ? (tmdb?.extras.trailers ?? const <MediaTrailer>[])
        : const <MediaTrailer>[];
    final tmdbRecs = level.hasRows
        ? (tmdb?.extras.recommendations ?? const <Movie>[])
        : const <Movie>[];
    final characters = _characters.isNotEmpty ? _characters : tmdbCast;
    final staff = _staff.isNotEmpty ? _staff : tmdbCrew;
    final trailers = a.mediaTrailer != null
        ? <MediaTrailer>[a.mediaTrailer!]
        : tmdbTrailers;
    final useTmdbRecs = _recommendations.isEmpty && tmdbRecs.isNotEmpty;
    final showCharacters = characters.isNotEmpty;
    final showStaff = staff.isNotEmpty;
    final showTrailers = trailers.isNotEmpty;
    final showRecs = _recommendations.isNotEmpty || useTmdbRecs;
    final showRelated = related.isNotEmpty;
    final hasMetaRows =
        showCharacters || showStaff || showTrailers || showRecs || showRelated;

    // Match TMDB details: seasons=0 + episodes=1 when multi-season, else
    // episodes alone at 0. Meta rows must start after the picker so Related
    // does not share sortOrder with episodes (D-pad jump).
    final pickerRowCount = !showEpisodeRail
        ? 0
        : (_seasons.length > 1 ? 2 : 1);
    var rowOrder = pickerRowCount;
    final relatedOrder = showRelated ? rowOrder++ : null;
    final charactersOrder = showCharacters ? rowOrder++ : null;
    final staffOrder = showStaff ? rowOrder++ : null;
    final trailersOrder = showTrailers ? rowOrder++ : null;
    final recsOrder = showRecs ? rowOrder : null;

    final firstMetaFocusUp = showEpisodeRail
        ? null
        : (isUpcoming ? (tvFocus ? _focusDetailsBack : null) : heroFocusUp);

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
              onEpisodePlay: isUpcoming
                  ? null
                  : (ep) {
                      setState(() => _selectedEpisode = ep);
                      _playSelected();
                    },
              onToggleWatched: _toggleEpisodeWatched,
              tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
              tvSeasonRowId: 'seasons',
              tvEpisodeRowId: 'episodes',
              tvRowOrderBase: 0,
              tvFocusUp: episodeFocusUp,
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
            backdropUrls: level.hasArt
                ? _heroUrls(a, tmdb)
                : RotatingHeroBackdrop.normalizeUrls(
                    [if (a.heroBackdrop.isNotEmpty) a.heroBackdrop],
                  ),
            title: a.displayTitle,
            subtitle: a.titleNative.isNotEmpty && a.titleNative != a.displayTitle
                ? a.titleNative
                : null,
            genres: a.genres.isNotEmpty
                ? a.genres
                : (level.hasChrome
                    ? (tmdb?.movie.genres ?? const <String>[])
                    : const <String>[]),
            metaParts: _metaParts(a, paintTmdb),
            rating: (a.averageScore ?? 0) > 0
                ? a.averageScore! / 10
                : (level.hasChrome && (tmdb?.movie.voteAverage ?? 0) > 0
                    ? tmdb!.movie.voteAverage
                    : null),
            overview: _overview(a, paintTmdb),
            facts: _facts(a, paintTmdb),
            logoUrl: level.hasChrome ? _tmdbLogoUrl(tmdb) : null,
            height: heroHeight,
            pageBottomChild: episodePicker,
            showSeasonRail: showSeasonRail,
            positionMs: posMs,
            durationMs: durMs,
            seriesProgress: _seriesProgressWidget(),
            actionRow: DetailsHeroTvActionScope(
              tabId: MediaDetailsTv.tabId,
              itemCount: heroActionCount,
              onFocusUp: heroPopUp,
              child: Row(
                children: [
                  if (isUpcoming)
                    HubDetailsUpcomingNotice(
                      releaseDateLabel: a.seasonYear?.toString(),
                    )
                  else
                    HubDetailsPlayRow(
                      label: canResumeSelected
                          ? 'Resume Ep $_selectedEpisode'
                          : 'Play Ep $_selectedEpisode',
                      enabled: _episodes.isNotEmpty,
                      onPlay: _playSelected,
                      onOpenSources: showCatalogSources
                          ? () => _openCatalogSources(_playMovieFor(tmdb))
                          : null,
                      focusNode:
                          policy.heroPlayAutoFocus ? _heroPlayFocus : null,
                      onUpEdge: heroPopUp,
                      tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                      tvItemIndex: playIndex,
                      tvSourcesItemIndex: sourcesIndex,
                    ),
                  if (!isUpcoming && _progress != null) ...[
                    const SizedBox(width: 10),
                    HeroPillIconGroup(
                      tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                      tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
                      tvItemIndexStart: clearIndex,
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
                  HubListStatusHero(
                    target: _followTarget,
                    tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                    tvItemIndexStart: listIndex,
                    onUpEdge: heroPopUp,
                    onMenuOpenChanged: (open) {
                      setState(() => _listMenuOpen = open);
                    },
                  ),
                  if (!isUpcoming) ...[
                    const SizedBox(width: 10),
                    HeroPillSegmentedChoice<String>(
                      selected: _category,
                      onSelected: (cat) => setState(() => _category = cat),
                      tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                      tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
                      tvItemIndexStart: subDubIndex,
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
                      cast: characters,
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
                      cast: staff,
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
                    if (useTmdbRecs)
                      MediaDetailsRecommendationsSection(
                        movies: tmdbRecs,
                        onMovieTap: (movie) =>
                            AppRouter.openDetails(context, movie: movie),
                        tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                        tvRowId: 'recommendations',
                        tvRowOrder: recsOrder!,
                        tvFocusUp: (showRelated ||
                                showCharacters ||
                                showStaff ||
                                showTrailers)
                            ? null
                            : firstMetaFocusUp,
                      )
                    else
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
      backFocus: _backFocus,
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
        subtitle: _animeDetailsCardMeta(a),
        onTap: () => openAnimeDetails(context, a),
        listIndex: index,
        tvTabId: ShellScope.inputPolicyOf(context).useFocusableMoodChips
            ? MediaDetailsTv.tabId
            : null,
        tvRowId: 'recommendations',
        listTarget: HubListFollowTarget.anime(
          anilistId: a.id,
          title: a.displayTitle,
          posterPath: a.coverUrl,
          voteAverage: (a.averageScore ?? 0) > 0 ? (a.averageScore! / 10) : 0,
          releaseDate: a.seasonYear?.toString() ?? '',
        ),
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
        subtitle: _animeDetailsCardMeta(r.anime),
        badge: r.label,
        onTap: () => openAnimeDetails(context, r.anime),
        listIndex: index,
        tvTabId: ShellScope.inputPolicyOf(context).useFocusableMoodChips
            ? MediaDetailsTv.tabId
            : null,
        tvRowId: 'related',
        listTarget: HubListFollowTarget.anime(
          anilistId: r.anime.id,
          title: r.anime.displayTitle,
          posterPath: r.anime.coverUrl,
          voteAverage: (r.anime.averageScore ?? 0) > 0
              ? (r.anime.averageScore! / 10)
              : 0,
          releaseDate: r.anime.seasonYear?.toString() ?? '',
        ),
      ),
    );
  }

  /// Same bottom meta as hub posters — series keep eps, never “TV”.
  String? _animeDetailsCardMeta(AnimeCard anime) {
    final parts = <String>[];
    if (anime.seasonYear != null) parts.add('${anime.seasonYear}');
    final fmt = (anime.format ?? '').toUpperCase();
    if (fmt == 'TV' || fmt == 'TV_SHORT') {
      if (anime.episodes != null) parts.add('${anime.episodes} eps');
    } else if (fmt == 'MOVIE') {
      parts.add('FILM');
    } else if (fmt.isNotEmpty) {
      parts.add(fmt.replaceAll('_', ' '));
    } else if (anime.episodes != null) {
      parts.add('${anime.episodes} eps');
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }
}
