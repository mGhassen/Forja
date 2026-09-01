import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv_catalog_recs.dart';
import 'package:forja/features/iptv/providers/iptv_controller_provider.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/shared/catalog/shell/catalog_iptv_open.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_meta.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_play.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_sections.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_stremio.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
import 'package:forja/shared/catalog/kit/meta/catalog_meta_movie.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_resolve.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/playback/catalog_sources_session_cache.dart';
import 'package:forja/shared/playback/player_stream_extract_cache.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/services/youtube_stream_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_pack_filters.dart';
import 'package:forja/shared/catalog/kit/details/catalog_play_filters.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/hub_details/hub_catalog_sources.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/hub_list_status_hero.dart';
import 'package:forja/shared/widgets/media_details/media_details.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:rust/rust.dart'
    show
        MediaTrailer,
        RichMediaDetails,
        WatchHistoryService,
        canResumeFromSavedProgress,
        isContinueWatchingRowEntry,
        watchHistoryInt;

Future<T?> openHubDetails<T>(
  BuildContext context, {
  required String pluginId,
  required CatalogMetaItem item,
  String? shellTabId,
  int? initialSeason,
  int? initialEpisode,
  Duration? startPosition,
  bool autoPlay = false,
}) {
  final tab = shellTabId ?? hubShellTabIdForPlugin(pluginId);
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute(
      (_) => HubDetailsScreen(
        pluginId: pluginId,
        item: item,
        initialSeason: initialSeason,
        initialEpisode: initialEpisode,
        startPosition: startPosition,
        autoPlay: autoPlay,
      ),
      settings: RouteSettings(name: '${tab ?? pluginId}_hub_details'),
    ),
    shellTabId: tab,
  );
}

/// Pack-driven details — host loads `action: details` then renders shared chrome.
class HubDetailsScreen extends ConsumerStatefulWidget {
  const HubDetailsScreen({
    super.key,
    required this.pluginId,
    required this.item,
    this.initialSeason,
    this.initialEpisode,
    this.startPosition,
    this.autoPlay = false,
  });

  final String pluginId;
  final CatalogMetaItem item;
  final int? initialSeason;
  final int? initialEpisode;
  final Duration? startPosition;
  final bool autoPlay;

  @override
  ConsumerState<HubDetailsScreen> createState() => _HubDetailsScreenState();
}

class _HubDetailsScreenState extends ConsumerState<HubDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'hub-details-play');
  final FocusNode _backFocus = FocusNode(debugLabel: 'hub-details-back');

  CatalogMetaItem? _detail;
  List<HubDetailRailSection> _packRails = const [];
  List<String> _heroBackdrops = const [];
  RichMediaDetails? _rich;
  bool _loading = true;
  String? _error;
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  final Map<String, String> _playFilterSelections = {};
  bool _detailsHeroInitialFocusDone = false;
  Map<String, dynamic>? _watchProgress;
  bool _autoPlayConsumed = false;
  StreamSubscription<List<Map<String, dynamic>>>? _homeHistorySub;
  List<IptvCatalogRecHit> _iptvRecHits = const [];
  VerifiedPortal? _iptvPortal;

  @override
  void initState() {
    super.initState();
    CatalogWatchHistory.revision.addListener(_onWatchHistoryChanged);
    CatalogPackFiltersRegistry.revision.addListener(_onPackFiltersChanged);
    if (hubMetaUsesHomeWatchHistory(widget.item)) {
      _homeHistorySub = WatchHistoryService().historyStream.listen((_) {
        unawaited(_loadWatchProgress());
      });
    }
    unawaited(ref.read(settingsPlaybackProvider.future));
    unawaited(_ensurePackFilters());
    unawaited(_loadWatchProgress());
    _loading = !hubMetaTmdbEnriched(widget.item);
    _load();
  }

  @override
  void dispose() {
    CatalogWatchHistory.revision.removeListener(_onWatchHistoryChanged);
    CatalogPackFiltersRegistry.revision.removeListener(_onPackFiltersChanged);
    unawaited(_homeHistorySub?.cancel());
    _scrollController.dispose();
    _heroPlayFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  CatalogMetaItem get _show => _detail ?? widget.item;

  List<CatalogVideo> get _videos => _show.videos;

  bool get _isMovie => hubMetaIsMovie(_show);

  List<CatalogPlayFilterSpec> get _playFilters =>
      CatalogPackFiltersRegistry.playFiltersFor(widget.pluginId);

  Map<String, dynamic> get _playFilterExtras => catalogPlayFilterValues(
        pluginId: widget.pluginId,
        selections: _playFilterSelections,
      );

  void _onPackFiltersChanged() {
    if (!mounted) return;
    _seedPlayFilterDefaults();
    setState(() {});
  }

  Future<void> _ensurePackFilters() async {
    await CatalogPackFiltersRegistry.ensureLoaded(widget.pluginId);
    if (!mounted) return;
    _seedPlayFilterDefaults();
    setState(() {});
  }

  void _seedPlayFilterDefaults({Map<String, dynamic>? progressExtras}) {
    for (final spec in _playFilters) {
      if (_playFilterSelections.containsKey(spec.field)) continue;
      final initial = spec.initialValue(progressExtras);
      if (initial != null) _playFilterSelections[spec.field] = initial;
    }
  }

  void _restorePlayFiltersFromProgress(Map<String, dynamic>? progress) {
    final extras = progress?['extras'];
    if (extras is! Map) return;
    final map = Map<String, dynamic>.from(extras);
    for (final spec in _playFilters) {
      final saved = map[spec.field]?.toString();
      if (saved != null && spec.optionByValue(saved) != null) {
        _playFilterSelections[spec.field] = saved;
      }
    }
  }

  String _playFilterValue(CatalogPlayFilterSpec spec) {
    final hit = _playFilterSelections[spec.field];
    if (hit != null && spec.optionByValue(hit) != null) return hit;
    final progressExtras = _watchProgress?['extras'];
    return spec.initialValue(
          progressExtras is Map
              ? Map<String, dynamic>.from(progressExtras)
              : null,
        ) ??
        spec.options.first.value;
  }

  Iterable<String?> _audioCategoriesForCacheClear() sync* {
    yield null;
    for (final spec in _playFilters) {
      if (spec.field != 'category') continue;
      for (final opt in spec.options) {
        yield opt.value;
      }
    }
  }

  void _onWatchHistoryChanged() {
    unawaited(_loadWatchProgress());
  }

  Future<void> _loadWatchProgress() async {
    if (!mounted) return;
    try {
      final entries = await CatalogWatchHistory.getAll(widget.pluginId);
      Map<String, dynamic>? hit;
      for (final entry in entries) {
        if (entry['metaId']?.toString() == _show.id) {
          hit = entry;
          break;
        }
      }
      if (hit == null && hubMetaUsesHomeWatchHistory(_show)) {
        hit = await _homeWatchHistoryProgress();
      }
      if (!mounted) return;
      setState(() {
        _watchProgress = hit;
        if (hit != null) _restorePlayFiltersFromProgress(hit);
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _homeWatchHistoryProgress() async {
    final tmdbId = _show.numericId('tmdb');
    if (tmdbId == null) return null;
    final item = await WatchHistoryService().getProgress(
      tmdbId,
      season: _isMovie ? null : _selectedSeason,
      episode: _isMovie ? null : _selectedEpisode,
    );
    if (item == null) return null;
    return {
      'metaId': _show.id,
      'episodeNumber': item['episode'] ?? _selectedEpisode,
      'positionMs': watchHistoryInt(item['position']),
      'durationMs': watchHistoryInt(item['duration']),
      'episodeVideoId': item['episodeVideoId'],
      'extras': item['extras'],
    };
  }

  Duration? _startPositionForEpisode(int episodeNumber) {
    if (widget.startPosition != null) {
      if (_isMovie ||
          widget.initialEpisode == null ||
          widget.initialEpisode == episodeNumber) {
        return widget.startPosition;
      }
    }
    final progress = _watchProgress;
    if (progress == null) return null;
    final savedEp = (progress['episodeNumber'] as num?)?.toInt();
    if (savedEp != null && savedEp != episodeNumber) return null;
    final posMs = (progress['positionMs'] as num?)?.toInt() ?? 0;
    final durMs = (progress['durationMs'] as num?)?.toInt() ?? 0;
    if (posMs <= 5000 || !canResumeFromSavedProgress(posMs, durMs)) return null;
    final clamped =
        (durMs > 0 && posMs > durMs - 30000) ? (durMs - 30000) : posMs;
    return Duration(milliseconds: (clamped - 3000).clamp(0, 1 << 31));
  }

  bool get _canResumeSelected {
    final progress = _watchProgress;
    if (progress == null) return false;
    final savedEp = (progress['episodeNumber'] as num?)?.toInt();
    if (savedEp != null && savedEp != _selectedEpisode) return false;
    final posMs = (progress['positionMs'] as num?)?.toInt() ?? 0;
    final durMs = (progress['durationMs'] as num?)?.toInt() ?? 0;
    return isContinueWatchingRowEntry(posMs, durMs);
  }

  bool get _hasClearableProgress {
    final progress = _watchProgress;
    if (progress == null) return false;
    final posMs = (progress['positionMs'] as num?)?.toInt() ?? 0;
    return posMs > 0;
  }

  Future<void> _clearProgress() async {
    final progress = _watchProgress;
    if (progress == null) return;
    final show = _show;
    await CatalogWatchHistory.remove(widget.pluginId, show.id);

    final listTarget = CatalogListFollowTarget.fromMeta(
      pluginId: widget.pluginId,
      meta: show,
    );
    if (listTarget != null) {
      await HubListFollow.clearProgress(listTarget);
    }

    final ep = (progress['episodeNumber'] as num?)?.toInt() ?? _selectedEpisode;
    final open = show.open;
    if (open != null) {
      final videoId = progress['episodeVideoId']?.toString();
      for (final audio in _audioCategoriesForCacheClear()) {
        CatalogSourcesSessionCache.invalidate(
          CatalogSourcesSessionCache.cacheKey(
            mediaId: 0,
            mediaType: show.type,
            season: _isMovie ? null : _selectedSeason,
            episode: ep,
            catalogOpen: open,
            pluginId: widget.pluginId,
            metaId: show.id,
            audioCategory: audio,
            episodeVideoId: videoId,
          ),
        );
      }
    }

    final tmdbId = show.numericId('tmdb');
    if (tmdbId != null) {
      await PlayerStreamExtractCache.drop(
        PlayerStreamExtractCache.cacheKeyFromProgress(
          tmdbId: tmdbId,
          mediaType: _isMovie ? 'movie' : 'tv',
          season: _isMovie ? null : _selectedSeason,
          episode: _isMovie ? null : ep,
        ),
      );
      if (hubMetaUsesHomeWatchHistory(show)) {
        final uniqueId = _isMovie
            ? '$tmdbId'
            : '${tmdbId}_S${_selectedSeason}_E$ep';
        await WatchHistoryService().removeItem(uniqueId);
      }
    }

    if (!mounted) return;
    setState(() => _watchProgress = null);
  }

  Future<void> _load() async {
    if (hubMetaIsStremio(widget.item)) {
      setState(() {
        _loading = true;
        _error = null;
      });
      final result = await loadHubStremioDetails(widget.item);
      if (!mounted) return;
      final meta = result.meta;
      final backdrops = hubHeroBackdropUrls(meta);
      final seasons = hubSeasonNumbers(meta.videos).toList()..sort();
      var firstSeason = seasons.isEmpty ? 1 : seasons.first;
      var firstEp = 1;
      if (widget.initialSeason != null &&
          (seasons.isEmpty || seasons.contains(widget.initialSeason))) {
        firstSeason = widget.initialSeason!;
      }
      final seasonVideos = hubVideosForSeason(meta.videos, firstSeason);
      firstEp = seasonVideos.isEmpty
          ? (widget.initialEpisode ?? 1)
          : (widget.initialEpisode != null &&
                  seasonVideos.any((v) => v.episode == widget.initialEpisode)
              ? widget.initialEpisode!
              : (seasonVideos.first.episode ?? 1));
      setState(() {
        _detail = meta;
        _packRails = result.rails;
        _heroBackdrops = backdrops;
        _loading = false;
        _selectedSeason = firstSeason;
        _selectedEpisode = firstEp;
      });
      unawaited(_loadWatchProgress());
      if (meta.numericId('tmdb') != null) {
        unawaited(_loadTmdbUi(meta));
      }
      if (widget.autoPlay) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPlay());
      }
      return;
    }

    final seedEnriched = hubMetaTmdbEnriched(widget.item);
    if (!seedEnriched) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final env = await CatalogRuntime.instance.run(
      pluginId: widget.pluginId,
      action: 'details',
      params: hubMetaIsIptv(widget.item)
          ? iptvHubDetailsParams(widget.item)
          : hubDetailsParams(widget.item),
    );
    if (!mounted) return;
    if (!env.ok) {
      final notReady =
          await PluginInstallCoordinator.instance.pluginNotReadyMessage(
        widget.pluginId,
      );
      setState(() {
        _loading = false;
        _error = notReady ?? env.error?.message ?? 'Failed to load details';
      });
      return;
    }
    final meta = env.meta ?? widget.item;
    final packRails = parseHubDetailRails(env.data);
    final backdrops = hubHeroBackdropUrls(meta);
    if (!mounted) return;
    final seasons = hubSeasonNumbers(meta.videos).toList()..sort();
    var firstSeason = seasons.isEmpty ? 1 : seasons.first;
    var firstEp = 1;
    if (widget.initialSeason != null &&
        (seasons.isEmpty || seasons.contains(widget.initialSeason))) {
      firstSeason = widget.initialSeason!;
    }
    final seasonVideos = hubVideosForSeason(meta.videos, firstSeason);
    firstEp = seasonVideos.isEmpty
        ? (widget.initialEpisode ?? 1)
        : (widget.initialEpisode != null &&
                seasonVideos.any((v) => v.episode == widget.initialEpisode)
            ? widget.initialEpisode!
            : (seasonVideos.first.episode ?? 1));
    setState(() {
      _detail = meta;
      _packRails = packRails;
      _heroBackdrops = backdrops;
      _loading = false;
      _selectedSeason = firstSeason;
      _selectedEpisode = firstEp;
    });
    if (hubMetaIsIptv(meta)) {
      _iptvPortal = await resolveIptvPortalFromMeta(meta);
    }
    unawaited(_loadWatchProgress());
    unawaited(_loadTmdbUi(meta));
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPlay());
    }
  }

  void _maybeAutoPlay() {
    if (!mounted || _autoPlayConsumed || _loading || _error != null) return;
    _autoPlayConsumed = true;
    _playSelected();
  }

  Future<void> _loadTmdbUi(CatalogMetaItem meta) async {
    if (meta.numericId('tmdb') == null) return;
    final results = await Future.wait<Object?>([
      hubTmdbHeroBackdropUrls(meta),
      hubLoadTmdbRich(meta),
    ]);
    if (!mounted) return;
    final backdrops = results[0] as List<String>;
    final rich = results[1] as RichMediaDetails?;
    if (backdrops.isEmpty && rich == null) return;
    setState(() {
      if (backdrops.isNotEmpty) _heroBackdrops = backdrops;
      if (rich != null) _rich = rich;
    });
    if (rich != null && rich.extras.trailers.isNotEmpty) {
      YoutubeStreamService.prefetch(
        rich.extras.trailers.map((t) => t.key),
        limit: 1,
      );
    }
    if (hubMetaIsIptv(meta)) {
      unawaited(_loadIptvCatalogRecs(meta, rich));
    }
  }

  Future<void> _loadIptvCatalogRecs(
    CatalogMetaItem meta,
    RichMediaDetails? rich,
  ) async {
    final portal = _iptvPortal ?? await resolveIptvPortalFromMeta(meta);
    if (portal == null || rich == null) return;
    try {
      final catalog = await ref
          .read(iptvControllerProvider)
          .vodSeriesCatalog(portal.key);
      final stream = iptvStreamFromMeta(meta);
      final hits = filterIptvCatalogRecommendations(
        recommendations: rich.extras.recommendations,
        catalog: catalog,
        excludeStreamId: stream.streamId,
      );
      if (!mounted) return;
      setState(() => _iptvRecHits = hits);
    } catch (_) {}
  }

  List<MediaTrailer> get _trailers =>
      _rich?.extras.trailers ?? const <MediaTrailer>[];

  void _openBestTrailer() {
    final trailers = _trailers;
    if (trailers.isEmpty || !mounted) return;
    AppRouter.openTrailerPlayer(
      context,
      trailers: trailers,
      initialIndex: 0,
      movie: _rich?.movie ?? catalogMetaToMovie(_show),
      languageCode: _rich?.extras.originalLanguage,
    );
  }

  void _scrollDetailsHeroIntoView() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _revealedDetailsHeroPlayFocus() => _scrollDetailsHeroIntoView();

  void _focusDetailsBack() {
    if (_backFocus.canRequestFocus) {
      _backFocus.requestFocus();
    } else {
      maybePopShellOverlay();
    }
  }

  CatalogVideo? _selectedVideo() {
    for (final v in _videos) {
      if ((v.season ?? 1) == _selectedSeason &&
          (v.episode ?? 1) == _selectedEpisode) {
        return v;
      }
    }
    return _videos.isEmpty ? null : _videos.first;
  }

  Future<void> _afterPlayClosed() => hubDetailsAfterPlayClosed(
        scrollController: _scrollController,
        heroPlayFocus: _heroPlayFocus,
        isMounted: () => mounted,
      );

  Future<void> _playEpisode(CatalogVideo? episode) async {
    if (!mounted) return;
    final ep = episode ?? _selectedVideo();
    final epNum = ep?.episode ?? _selectedEpisode;
    final season = ep?.season ?? _selectedSeason;
    final progress = _watchProgress;
    final progressExtras = progress?['extras'] is Map
        ? Map<String, dynamic>.from(progress!['extras'] as Map)
        : const <String, dynamic>{};
    final mergedExtras = {...progressExtras, ..._playFilterExtras};
    final progressVideoId = progress?['episodeVideoId']?.toString();
    final ctx = catalogPlayContextFromMeta(
      meta: _show,
      pluginId: widget.pluginId,
      episode: ep,
      season: season,
      episodeNumber: epNum,
      videos: _videos,
      episodeVideoId: progressVideoId,
      extras: mergedExtras,
      audioCategory: catalogPlayAudioCategory(_playFilterSelections),
      startPosition: _startPositionForEpisode(epNum),
    );
    await runHubPlayFromContext(context: context, ctx: ctx);
    if (!mounted) return;
    await _loadWatchProgress();
    await _afterPlayClosed();
  }

  void _playSelected() {
    if (_isMovie || _videos.isEmpty) {
      unawaited(_playEpisode(null));
      return;
    }
    final ep = _selectedVideo();
    if (ep == null || hubVideoNotAiredYet(ep)) return;
    unawaited(_playEpisode(ep));
  }

  void _openCatalogSources() {
    final ep = _selectedVideo();
    final ctx = catalogPlayContextFromMeta(
      meta: _show,
      pluginId: widget.pluginId,
      episode: ep,
      season: _selectedSeason,
      episodeNumber: _selectedEpisode,
      videos: _videos,
      extras: _playFilterExtras,
      audioCategory: catalogPlayAudioCategory(_playFilterSelections),
    );
    unawaited(openHubSourcesFromContext(context: context, ctx: ctx));
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
                ShellErrorRetryPanel(
                  message: _error!,
                  onRetry: _load,
                )
              else
                _buildScrollLayout(),
              MediaDetailsBackButton(focusNode: _backFocus),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScrollLayout() {
    final show = _show;
    final videos = _videos;
    final seasons = hubSeasonNumbers(videos).toList()..sort();
    final backdrop = hubImageUrl(
      _heroBackdrops.isNotEmpty
          ? _heroBackdrops.first
          : (show.background.isNotEmpty ? show.background : show.poster),
    );
    final backdropUrls = _heroBackdrops.length > 1
        ? _heroBackdrops
        : (backdrop.isNotEmpty ? [backdrop] : const <String>[]);
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;
    final playbackSnap = ref.watch(settingsPlaybackProvider).valueOrNull;
    final isIptv = hubMetaIsIptv(_show);
    final showCatalogSources =
        !isIptv && hubHasCatalogPanelSources(playbackSnap);
    final hasEpisodes = videos.isNotEmpty && !_isMovie;

    if (policy.heroPlayAutoFocus &&
        !_detailsHeroInitialFocusDone &&
        (_isMovie || videos.isNotEmpty)) {
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
    final listTarget = CatalogListFollowTarget.fromMeta(
      pluginId: widget.pluginId,
      meta: show,
    );
    final hasClearableProgress = _hasClearableProgress;
    final trailers = _trailers;
    final hasTrailers = trailers.isNotEmpty;
    final isUpcoming = hubMetaIsUpcoming(show, videos: videos);
    final premiereLabel = hubMetaPremiereDateLabel(show);
    final selectedVideo = _selectedVideo();
    final selectedUnaired =
        selectedVideo != null && hubVideoNotAiredYet(selectedVideo);
    var tvIndex = 0;
    final playIndex = tvIndex++;
    final sourcesIndex = showCatalogSources ? tvIndex++ : null;
    final clearIndex = hasClearableProgress ? tvIndex++ : null;
    final trailerIndex = hasTrailers ? tvIndex++ : null;
    final listIndex = listTarget != null ? tvIndex++ : null;
    final playFilters = _playFilters
        .where((f) => f.style == 'grouped' && f.options.length >= 2)
        .toList();
    final showPlayFilters = !isUpcoming && playFilters.isNotEmpty;
    final playFilterIndex = showPlayFilters ? tvIndex : null;
    if (showPlayFilters) {
      for (final f in playFilters) {
        tvIndex += f.options.length;
      }
    }
    final heroActionCount = tvIndex;

    final episodePicker = hasEpisodes
        ? MediaDetailsBody.padContent(
            context,
            TvSeasonEpisodePicker(
              tmdbId: show.id.hashCode,
              seasonCount: seasons.length,
              selectedSeason: _selectedSeason,
              selectedEpisode: _selectedEpisode,
              isLoadingSeason: false,
              seasonData: null,
              fallbackPosterPath: show.poster,
              customEpisodesBySeason: hubEpisodeMaps(videos),
              watchedEpisodes: const {},
              onToggleWatched: (season, episode) {},
              onSeasonSelected: (season) {
                final eps = hubVideosForSeason(videos, season);
                setState(() {
                  _selectedSeason = season;
                  _selectedEpisode =
                      eps.isEmpty ? 1 : (eps.first.episode ?? 1);
                });
              },
              onEpisodeSelected: (ep) => setState(() => _selectedEpisode = ep),
              onEpisodePlay: (ep) {
                setState(() => _selectedEpisode = ep);
                _playSelected();
              },
              tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
              tvSeasonRowId: 'seasons',
              tvEpisodeRowId: 'episodes',
              tvRowOrderBase: 0,
              tvFocusUp: heroFocusUp,
            ),
          )
        : null;

    final canResume = _canResumeSelected;
    final progress = _watchProgress;
    final playLabel = _isMovie
        ? (canResume ? 'Resume' : 'Play')
        : (videos.isEmpty
            ? (canResume ? 'Resume' : 'Play')
            : (canResume
                ? 'Resume Ep $_selectedEpisode'
                : 'Play Ep $_selectedEpisode'));
    final heroPosMs = canResume
        ? (progress?['positionMs'] as num?)?.toInt()
        : null;
    final heroDurMs = canResume
        ? (progress?['durationMs'] as num?)?.toInt()
        : null;

    final firstMetaFocusUp = tvFocus ? _revealedDetailsHeroPlayFocus : null;

    final packSections = buildHubDetailRailSections(
      context: context,
      pluginId: widget.pluginId,
      rails: _packRails,
      tvFocus: tvFocus,
      firstMetaFocusUp: firstMetaFocusUp,
    );
    final tmdbSections = buildHubTmdbDetailSections(
      context: context,
      pluginId: widget.pluginId,
      rich: _rich,
      tvFocus: tvFocus,
      firstMetaFocusUp: packSections.isEmpty ? firstMetaFocusUp : null,
      recommendations: isIptv && _iptvRecHits.isNotEmpty
          ? _iptvRecHits.map((h) => h.tmdb).toList()
          : null,
      onRecommendationTap: isIptv && _iptvPortal != null
          ? (movie) {
              for (final hit in _iptvRecHits) {
                if (hit.tmdb.id != movie.id) continue;
                unawaited(
                  openIptvVodStream(
                    context,
                    stream: hit.stream,
                    portal: _iptvPortal!,
                  ),
                );
                break;
              }
            }
          : null,
    );
    final sections = [...packSections, ...tmdbSections];

    return MediaDetailsScrollPage(
      scrollController: _scrollController,
      tvHeroPlayFocus: _heroPlayFocus,
      tvBackFocus: _backFocus,
      bodyOverlap: 0,
      topSpacing: hasEpisodes
          ? DetailsTokens.bodyTopSpacingWithEpisodes
          : DetailsTokens.bodyTopSpacing,
      backgroundColor: AppTheme.bgDark,
      hero: HubDetailsHero(
        backdropUrl: backdrop,
        backdropUrls: backdropUrls,
        title: show.name,
        genres: show.genres,
        overview: show.description.trim(),
        metaParts: [
          if (_isMovie) 'FILM' else 'TV',
          if (show.releaseInfo.isNotEmpty) show.releaseInfo,
        ],
        rating: show.rating,
        richFacts: _rich,
        logoUrl: hubTmdbLogoUrl(_rich) ?? hubMetaLogoUrl(show),
        height: DetailsTokens.heroHeight(
          context,
          showEpisodeRail: hasEpisodes,
          showSeasonRail: seasons.length > 1,
        ),
        pageBottomChild: episodePicker,
        showSeasonRail: seasons.length > 1,
        positionMs: heroPosMs,
        durationMs: heroDurMs,
        actionRow: DetailsHeroTvActionScope(
          tabId: MediaDetailsTv.tabId,
          itemCount: heroActionCount,
          onFocusUp: heroPopUp,
          child: Row(
            children: [
              if (isUpcoming)
                HubDetailsUpcomingNotice(
                  releaseDateLabel: premiereLabel,
                )
              else
                HubDetailsPlayRow(
                  label: playLabel,
                  enabled: !selectedUnaired &&
                      (_isMovie || videos.isNotEmpty || show.open != null),
                  onPlay: _playSelected,
                  onOpenSources:
                      showCatalogSources && (_isMovie || videos.isNotEmpty)
                          ? _openCatalogSources
                          : null,
                  focusNode: policy.heroPlayAutoFocus ? _heroPlayFocus : null,
                  onUpEdge: heroPopUp,
                  tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                  tvItemIndex: playIndex,
                  tvSourcesItemIndex: sourcesIndex,
                ),
              if (hasClearableProgress) ...[
                const SizedBox(width: 10),
                HeroPillIconGroup(
                  tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                  tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
                  tvItemIndexStart: clearIndex!,
                  onUpEdge: heroPopUp,
                  slots: [
                    HeroPillIconSlot(
                      icon: Icons.delete_outline_rounded,
                      label: 'Clear',
                      tooltip: 'Clear progress & stream cache',
                      onTap: () => unawaited(_clearProgress()),
                    ),
                  ],
                ),
              ],
              if (hasTrailers) ...[
                const SizedBox(width: 10),
                HeroPillPlayButton(
                  label: 'Trailer',
                  icon: Icons.smart_display_outlined,
                  tone: HeroPillPlayTone.secondary,
                  onTap: _openBestTrailer,
                  onUpEdge: heroPopUp,
                  tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                  tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
                  tvItemIndex: trailerIndex,
                ),
              ],
              if (listTarget != null) ...[
                const SizedBox(width: 10),
                HubListStatusHero(
                  target: listTarget,
                  tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                  tvItemIndexStart: listIndex!,
                  onUpEdge: heroPopUp,
                ),
              ],
              if (showPlayFilters) ...[
                const SizedBox(width: 10),
                for (var i = 0; i < playFilters.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  CatalogKitGroupedPlayFilter(
                    spec: playFilters[i],
                    selected: _playFilterValue(playFilters[i]),
                    onSelected: (value) => setState(
                      () =>
                          _playFilterSelections[playFilters[i].field] = value,
                    ),
                    tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                    tvItemIndexStart: playFilterIndex! +
                        playFilters
                            .take(i)
                            .fold<int>(0, (n, f) => n + f.options.length),
                    onUpEdge: heroPopUp,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      sections: sections,
    );
  }
}
