import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/asian_drama/providers/asian_drama_providers.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/hero/hero_utils.dart';
import 'package:forja/shared/widgets/hero/rotating_hero_backdrop.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/hub_list_status_hero.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/media_details/media_details.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/media_details_cast_section.dart';
import 'package:forja/shared/widgets/media_details_trailers_section.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shared/widgets/watch_series_progress.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:rust/rust.dart';
import 'asian_drama_player_screen.dart';

Future<T?> openAsianDramaDetails<T>(BuildContext context, KdramaCard drama) {
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute(
      (_) => AsianDramaDetailsScreen(drama: drama),
      settings: const RouteSettings(name: 'asian_drama_details'),
    ),
  );
}

Future<T?> replaceAsianDramaDetails<T>(BuildContext context, KdramaCard drama) {
  return pushReplacementShellRoute<T, void>(
    context,
    AppRouter.slideShellRoute(
      (_) => AsianDramaDetailsScreen(drama: drama),
      settings: const RouteSettings(name: 'asian_drama_details'),
    ),
  );
}

class AsianDramaDetailsScreen extends ConsumerStatefulWidget {
  final KdramaCard drama;
  const AsianDramaDetailsScreen({super.key, required this.drama});

  @override
  ConsumerState<AsianDramaDetailsScreen> createState() =>
      _AsianDramaDetailsScreenState();
}

class _AsianDramaDetailsScreenState
    extends ConsumerState<AsianDramaDetailsScreen> {
  final KissKhService _service = KissKhService();
  final EpisodeWatchedService _episodeWatchedService = EpisodeWatchedService();
  final ScrollController _detailsScrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'asian-drama-details-play');
  final FocusNode _backFocus = FocusNode(debugLabel: 'asian-drama-details-back');
  bool _detailsHeroInitialFocusDone = false;
  KdramaDetails? _details;
  Map<String, dynamic>? _progress;
  Set<String> _watchedEpisodes = {};
  bool _loading = true;
  String? _error;
  int _selectedEpisode = 1;
  bool _listMenuOpen = false;

  @override
  void initState() {
    super.initState();
    KissKhService.watchHistoryRevision.addListener(_onHistoryChanged);
    _load();
    _loadWatchedEpisodes();
  }

  @override
  void dispose() {
    KissKhService.watchHistoryRevision.removeListener(_onHistoryChanged);
    _heroPlayFocus.dispose();
    _backFocus.dispose();
    _detailsScrollController.dispose();
    super.dispose();
  }

  void _revealedDetailsHeroPlayFocus() {
    void focusPlay() {
      if (!mounted) return;
      if (_heroPlayFocus.canRequestFocus) {
        _heroPlayFocus.requestFocus();
      }
    }

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

  void _onHistoryChanged() => _refreshProgress();

  Future<void> _refreshProgress() async {
    try {
      final p = await _service.getProgress(widget.drama.id);
      if (!mounted) return;
      setState(() {
        _progress = p;
        final ep = (p?['episodeNumber'] as num?)?.toInt();
        if (ep != null && ep > 0) _selectedEpisode = ep;
      });
    } catch (_) {}
  }

  Future<void> _load({int attempt = 0}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await ref.read(
        asianDramaDetailsProvider(widget.drama.id).future,
      );
      if (!mounted) return;
      final det = bundle.details;
      final p = bundle.progress;
      setState(() {
        _details = det;
        _progress = p;
        _loading = false;
        final ep = (p?['episodeNumber'] as num?)?.toInt();
        if (ep != null && ep > 0) _selectedEpisode = ep;
      });
    } catch (e) {
      if (attempt == 0) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          ref.invalidate(asianDramaDetailsProvider(widget.drama.id));
          return _load(attempt: 1);
        }
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyLoadError(e);
      });
    }
  }

  String _friendlyLoadError(Object e) {
    final raw = '$e';
    if (raw.contains('→ 429')) {
      return 'kisskh is busy - wait a moment and tap Retry.';
    }
    if (RegExp(r'→ 5\d\d').hasMatch(raw)) {
      return 'kisskh is temporarily unavailable - tap Retry.';
    }
    return raw;
  }

  HubListFollowTarget _followTarget(KdramaDetails det, RichMediaDetails? tmdb) {
    return HubListFollowTarget.drama(
      kisskhId: det.id,
      title: det.title,
      posterPath: det.cover,
      tmdbId: tmdb?.movie.id,
      tmdbMediaType: tmdb?.movie.mediaType,
      releaseDate: det.year ?? '',
      kissKhType: det.type,
      voteAverage: tmdb?.movie.voteAverage ?? 0,
    );
  }

  void _play(KdramaEpisode ep, {Duration? startPosition}) {
    final det = _details!;
    final enrich =
        ref.read(asianDramaTmdbEnrichmentProvider(_tmdbQuery)).asData?.value;
    HubListFollow.markWatchingOnPlay(_followTarget(det, enrich?.rich));
    openAsianDramaPlayer(
      context,
      drama: det.toCard(),
      episode: ep,
      allEpisodes: det.episodes,
      startPosition: startPosition,
    ).then((_) async {
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
    });
  }

  void _playSelected() {
    final det = _details;
    if (det == null || det.episodes.isEmpty) return;
    final ep = _episodeLookup(det)[_selectedEpisode];
    if (ep == null) return;
    final p = _progress;
    final resumeEp = (p?['episodeNumber'] as num?)?.toInt();
    if (p != null && resumeEp == _selectedEpisode) {
      _play(ep, startPosition: KissKhService.startPositionFromHistory(p));
      return;
    }
    _play(ep);
  }

  Future<void> _clearProgress() async {
    await _service.removeFromHistory(widget.drama.id);
    final det = _details;
    if (det != null) {
      final enrich =
          ref.read(asianDramaTmdbEnrichmentProvider(_tmdbQuery)).asData?.value;
      await HubListFollow.clearProgress(_followTarget(det, enrich?.rich));
    }
    if (mounted) setState(() => _progress = null);
  }

  Future<void> _loadWatchedEpisodes() async {
    final set = await _episodeWatchedService.getWatchedSet(
      widget.drama.id,
      catalog: EpisodeWatchedService.catalogKisskh,
    );
    if (mounted) setState(() => _watchedEpisodes = set);
  }

  Future<void> _toggleEpisodeWatched(int season, int episode) async {
    await _episodeWatchedService.toggle(
      widget.drama.id,
      season,
      episode,
      catalog: EpisodeWatchedService.catalogKisskh,
    );
    final watched = await _episodeWatchedService.isWatched(
      widget.drama.id,
      season,
      episode,
      catalog: EpisodeWatchedService.catalogKisskh,
    );
    final det = _details;
    if (det != null) {
      final enrich =
          ref.read(asianDramaTmdbEnrichmentProvider(_tmdbQuery)).asData?.value;
      HubListFollow.syncEpisodeWatched(
        _followTarget(det, enrich?.rich),
        episode: episode,
        watched: watched,
      );
    }
    await _loadWatchedEpisodes();
  }

  Widget? _seriesProgressWidget(KdramaDetails det) {
    final total =
        det.episodes.isNotEmpty ? det.episodes.length : det.episodesCount;
    final watched = _watchedEpisodes.length;
    if (total <= 0 || watched <= 0) return null;
    return WatchSeriesProgress(watched: watched, total: total);
  }

  AsianDramaTmdbQuery get _tmdbQuery {
    final det = _details;
    return (
      title: det?.title ?? widget.drama.title,
      year: det?.year ?? widget.drama.year,
      kissKhType: (det != null && det.type.isNotEmpty)
          ? det.type
          : widget.drama.type,
    );
  }

  List<String> _metaParts(KdramaDetails det, RichMediaDetails? tmdb) {
    final typeBadge = det.toCard().heroMediaBadge;
    final cert = tmdb?.extras.certification.trim() ?? '';
    return [
      ?det.year,
      if (det.country.isNotEmpty) det.country,
      ?typeBadge,
      if (cert.isNotEmpty) cert,
      if (det.status.isNotEmpty) det.status,
      if (det.episodesCount > 0) '${det.episodesCount} eps',
    ];
  }

  List<MapEntry<String, String>> _facts(
    KdramaDetails det,
    RichMediaDetails? tmdb,
  ) {
    final typeBadge = det.toCard().heroMediaBadge;
    final extras = tmdb?.extras;
    final director = extras == null
        ? null
        : pickDirectorFromCrew(extras.crew);
    final creators = extras?.creators ?? const <String>[];
    final networks = extras?.networks ?? const <String>[];
    final languages = extras?.spokenLanguages ?? const <String>[];
    final companies = extras?.productionCompanies ?? const <String>[];
    return [
      if (det.releaseDate.isNotEmpty)
        MapEntry('Released', _formatDate(det.releaseDate)),
      if (det.country.isNotEmpty) MapEntry('Country', det.country),
      if (typeBadge != null) MapEntry('Type', typeBadge),
      if (det.status.isNotEmpty) MapEntry('Status', det.status),
      if (det.label != null && det.label!.isNotEmpty)
        MapEntry('Label', det.label!),
      if (director != null && director.isNotEmpty)
        MapEntry('Director', director),
      if (creators.isNotEmpty) MapEntry('Created by', creators.take(3).join(', ')),
      if (networks.isNotEmpty) MapEntry('Network', networks.take(2).join(', ')),
      if (languages.isNotEmpty)
        MapEntry('Language', languages.take(2).join(', ')),
      if (companies.isNotEmpty)
        MapEntry('Studio', companies.take(2).join(', ')),
      if ((extras?.popularity ?? 0) > 0)
        MapEntry('Popularity', _compactNum(extras!.popularity.round())),
    ];
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

  String _compactNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String? _tmdbBackdropUrl(RichMediaDetails? tmdb) {
    final path = tmdb?.movie.backdropPath.trim() ?? '';
    if (path.isEmpty) return null;
    return TmdbApi.getBackdropUrl(path);
  }

  String? _tmdbLogoUrl(RichMediaDetails? tmdb) {
    final path = tmdb?.movie.logoPath.trim() ?? '';
    if (path.isEmpty) return null;
    return path.startsWith('http') ? path : TmdbApi.getImageUrl(path);
  }

  List<String> _heroBackdropUrls({
    required String primary,
    required List<String> screenshotPaths,
  }) {
    final urls = <String>[
      if (primary.trim().isNotEmpty) primary.trim(),
      for (final raw in screenshotPaths)
        if (raw.trim().isNotEmpty)
          raw.trim().startsWith('http')
              ? raw.trim()
              : TmdbApi.getBackdropUrl(raw.trim()),
    ];
    return RotatingHeroBackdrop.normalizeUrls(urls);
  }

  String _overview(KdramaDetails det, RichMediaDetails? tmdb) {
    final kiss = det.description.trim();
    if (kiss.isNotEmpty) return kiss;
    return tmdb?.movie.overview.trim() ?? '';
  }

  Map<int, List<Map<String, dynamic>>>? _episodeMaps(
    KdramaDetails det, {
    Map<int, String> stills = const {},
    Map<int, Map<String, dynamic>> meta = const {},
  }) {
    if (det.episodes.isEmpty) return null;
    return {
      1: [
        for (var i = 0; i < det.episodes.length; i++)
          _episodeMapEntry(
            index: i,
            ep: det.episodes[i],
            cover: det.cover,
            stills: stills,
            meta: meta,
          ),
      ],
    };
  }

  Map<String, dynamic> _episodeMapEntry({
    required int index,
    required KdramaEpisode ep,
    required String cover,
    required Map<int, String> stills,
    required Map<int, Map<String, dynamic>> meta,
  }) {
    // Picker selection keys are 1-based list indices (sorted KissKH order).
    final pickerNum = index + 1;
    final kissNum = ep.number == ep.number.truncateToDouble()
        ? ep.number.toInt()
        : null;
    final tmdbMeta = meta[kissNum] ?? meta[pickerNum] ?? const {};
    final still = stills[kissNum ?? -1] ?? stills[pickerNum] ?? '';
    final tmdbName = (tmdbMeta['name'] as String?)?.trim() ?? '';
    final overview = (tmdbMeta['overview'] as String?)?.trim() ?? '';
    final runtime = (tmdbMeta['runtime'] as int?) ?? 0;
    final aired = (tmdbMeta['aired'] as String?)?.trim() ?? '';
    return {
      'episode_number': pickerNum,
      'name': tmdbName.isNotEmpty
          ? tmdbName
          : 'Episode ${ep.displayNumber}',
      'overview': overview,
      'runtime': runtime,
      'still_path': still.isNotEmpty ? still : cover,
      if (aired.isNotEmpty) 'aired': aired,
    };
  }

  Map<int, KdramaEpisode> _episodeLookup(KdramaDetails det) {
    return {for (var i = 0; i < det.episodes.length; i++) i + 1: det.episodes[i]};
  }

  Map<String, Map<String, dynamic>> _episodeProgressMap() {
    final p = _progress;
    if (p == null || _details == null) return const {};
    final epNum = (p['episodeNumber'] as num?)?.toDouble();
    if (epNum == null) return const {};
    final index = _details!.episodes.indexWhere((e) => e.number == epNum);
    if (index < 0) return const {};
    final pos = (p['positionMs'] as num?)?.toInt() ?? 0;
    final dur = (p['durationMs'] as num?)?.toInt() ?? 0;
    return {
      'S1_E${index + 1}': {'position': pos, 'duration': dur},
    };
  }

  String _formatDate(String iso) {
    if (iso.length < 10) return iso;
    return iso.substring(0, 10);
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
              if (_loading)
                Center(
                  child: CircularProgressIndicator(
                    color: ForjaShellColors.sectionAccent,
                  ),
                )
              else if (_error != null)
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
      message: 'Failed to load:\n$_error',
      onRetry: _load,
      statusIconSize: 56,
    );
  }

  Widget _buildScrollLayout() {
    final det = _details!;
    final tmdbAsync = ref.watch(asianDramaTmdbEnrichmentProvider(_tmdbQuery));
    final enrich = tmdbAsync.asData?.value;
    final tmdb = enrich?.rich;
    final cast = tmdb?.extras.cast ?? const <Map<String, String>>[];
    final crew = _crewAsCast(tmdb?.extras.crew ?? const []);
    final trailers = tmdb?.extras.trailers ?? const <MediaTrailer>[];
    final recommendations =
        tmdb?.extras.recommendations ?? const <Movie>[];
    final genres = tmdb?.movie.genres ?? const <String>[];
    final rating = (tmdb?.movie.voteAverage ?? 0) > 0
        ? tmdb!.movie.voteAverage
        : null;
    final backdrop = _tmdbBackdropUrl(tmdb) ?? det.cover;
    final heroBackdrops = _heroBackdropUrls(
      primary: backdrop,
      screenshotPaths: [
        if (det.cover.isNotEmpty) det.cover,
        ...enrich?.imagePaths ?? const [],
      ],
    );

    final resumeEp = (_progress?['episodeNumber'] as num?)?.toInt();
    final rawPosMs = (_progress?['positionMs'] as num?)?.toInt();
    final rawDurMs = (_progress?['durationMs'] as num?)?.toInt();
    final canResumeSelected = _progress != null &&
        resumeEp == _selectedEpisode &&
        isInProgressResume(rawPosMs ?? 0, rawDurMs ?? 0);
    final heroHeight = DetailsTokens.heroHeight(
      context,
      showEpisodeRail: true,
      showSeasonRail: false,
    );
    final posMs = canResumeSelected ? rawPosMs : null;
    final durMs = canResumeSelected ? rawDurMs : null;
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;

    if (policy.heroPlayAutoFocus && !_detailsHeroInitialFocusDone) {
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
    final listExtra = HubListStatusHero.extraFocusSlots(_listMenuOpen);
    var tvIndex = 0;
    final playIndex = tvIndex++;
    final clearIndex = _progress != null ? tvIndex++ : null;
    final listIndex = tvIndex++;
    tvIndex += listExtra;
    final heroActionCount = tvIndex;

    final showCast = cast.isNotEmpty;
    final showCrew = crew.isNotEmpty;
    final showTrailers = trailers.isNotEmpty;
    final showRecs = recommendations.isNotEmpty;
    final hasMetaRows = showCast || showCrew || showTrailers || showRecs;

    var rowOrder = det.episodes.isNotEmpty ? 1 : 0;
    final castOrder = showCast ? rowOrder++ : null;
    final crewOrder = showCrew ? rowOrder++ : null;
    final trailersOrder = showTrailers ? rowOrder++ : null;
    final recsOrder = showRecs ? rowOrder : null;
    final firstMetaFocusUp = det.episodes.isNotEmpty ? null : heroFocusUp;

    final episodePicker = det.episodes.isNotEmpty
        ? MediaDetailsBody.padContent(
            context,
            TvSeasonEpisodePicker(
              tmdbId: det.id,
              seasonCount: 1,
              selectedSeason: 1,
              selectedEpisode: _selectedEpisode,
              isLoadingSeason: false,
              seasonData: null,
              watchedEpisodes: _watchedEpisodes,
              watchedCatalog: EpisodeWatchedService.catalogKisskh,
              fallbackPosterPath: det.cover,
              customEpisodesBySeason: _episodeMaps(
                det,
                stills: enrich?.episodeStills ?? const {},
                meta: enrich?.episodeMeta ?? const {},
              ),
              episodeProgress: _episodeProgressMap(),
              onSeasonSelected: (_) {},
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

    final sections = <Widget>[
      if (showCast)
        MediaDetailsCastSection(
          cast: cast,
          title: 'Characters',
          tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
          tvRowId: 'cast',
          tvRowOrder: castOrder!,
          tvFocusUp: firstMetaFocusUp,
        ),
      if (showCrew)
        MediaDetailsCastSection(
          cast: crew,
          title: 'Crew',
          tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
          tvRowId: 'crew',
          tvRowOrder: crewOrder!,
          tvFocusUp: showCast ? null : firstMetaFocusUp,
        ),
      if (showTrailers)
        MediaDetailsTrailersSection(
          trailers: trailers,
          tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
          tvRowId: 'trailers',
          tvRowOrder: trailersOrder!,
          tvFocusUp: (showCast || showCrew) ? null : firstMetaFocusUp,
        ),
      if (showRecs)
        MediaDetailsRecommendationsSection(
          movies: recommendations,
          onMovieTap: (movie) => AppRouter.openDetails(context, movie: movie),
          tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
          tvRowId: 'recommendations',
          tvRowOrder: recsOrder!,
          tvFocusUp: (showCast || showCrew || showTrailers)
              ? null
              : firstMetaFocusUp,
        ),
    ];

    return MediaDetailsScrollPage(
      scrollController: _detailsScrollController,
      tvHeroPlayFocus: _heroPlayFocus,
      tvBackFocus: _backFocus,
      bodyOverlap: 0,
      topSpacing: DetailsTokens.bodyTopSpacingWithEpisodes,
      backgroundColor: AppTheme.bgDark,
      hero: HubDetailsHero(
        backdropUrl: backdrop,
        backdropUrls: heroBackdrops,
        title: det.title,
        genres: genres,
        metaParts: _metaParts(det, tmdb),
        rating: rating,
        overview: _overview(det, tmdb),
        facts: _facts(det, tmdb),
        logoUrl: _tmdbLogoUrl(tmdb),
        height: heroHeight,
        pageBottomChild: episodePicker,
        positionMs: posMs,
        durationMs: durMs,
        seriesProgress: _seriesProgressWidget(det),
        actionRow: DetailsHeroTvActionScope(
          tabId: MediaDetailsTv.tabId,
          itemCount: heroActionCount,
          onFocusUp: heroPopUp,
          child: Row(
            children: [
              HubDetailsPlayRow(
                label: canResumeSelected
                    ? 'Resume'
                    : 'Play Ep $_selectedEpisode',
                enabled: det.episodes.isNotEmpty,
                onPlay: _playSelected,
                focusNode: policy.heroPlayAutoFocus ? _heroPlayFocus : null,
                onUpEdge: heroPopUp,
                tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                tvItemIndex: playIndex,
              ),
              if (_progress != null) ...[
                const SizedBox(width: 10),
                HeroPillIconGroup(
                  tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                  tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
                  tvItemIndexStart: clearIndex,
                  onUpEdge: heroPopUp,
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
              HubListStatusHero(
                target: _followTarget(det, tmdb),
                tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                tvItemIndexStart: listIndex,
                onUpEdge: heroPopUp,
                onMenuOpenChanged: (open) {
                  setState(() => _listMenuOpen = open);
                },
              ),
            ],
          ),
        ),
      ),
      // Always mount the body so TMDB rows appear under episodes as soon as
      // enrichment resolves (same shape as movie/TV + anime details).
      sections: hasMetaRows ? sections : const [],
    );
  }
}