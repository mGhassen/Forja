import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/hub/kit_details_meta.dart';
import 'package:forja/shared/engine/hub/kit_details_play.dart';
import 'package:forja/shared/engine/hub/kit_details_sections.dart';
import 'package:forja/shared/engine/hub/kit_details_stremio.dart';
import 'package:forja/shared/host/watch/watch_history.dart';
import 'package:forja/shared/engine/hub/meta_movie.dart';
import 'package:forja/shared/playback/play_resolve.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja/shared/engine/hub/meta_runtime.dart';
import 'package:forja/shared/shell/shell_error_retry_panel.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja/shared/engine/hub/kit_iptv_play_hooks.dart';
import 'package:forja/shared/engine/hub/kit_panel_source_flags_hooks.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/playback/cache/catalog_sources_session_cache.dart';
import 'package:forja/shared/playback/cache/player_stream_extract_cache.dart';
import 'package:forja/shared/engine/lists/list_follow.dart';
import 'package:forja/shared/engine/lists/list_follow_from_watched.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/engine/hub/pack_filters.dart';
import 'package:forja/shared/engine/hub/play_filters.dart';
import 'package:forja/shared/shell/hero_pill_buttons.dart';
import 'package:forja/shared/player/sources/kit_sources.dart';
import 'package:forja/shared/player/details/kit_details_play_row.dart';
import 'package:forja/shared/player/details/kit_list_status_hero.dart';
import 'package:forja/shared/player/details/media_details.dart';
import 'package:forja/shared/shell/desktop_selectable_title.dart';
import 'package:forja_foundation/widgets/details/details_hero.dart';
import 'package:forja_foundation/widgets/details/details_screen.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/chrome/player_surface_chrome_stub.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:rust/rust.dart'
    show
        EpisodeWatchedService,
        MediaTrailer,
        WatchHistoryService,
        canResumeFromSavedProgress,
        isContinueWatchingRowEntry,
        watchHistoryInt;

Future<T?> openKitDetails<T>(
  BuildContext context, {
  required String pluginId,
  required MetaItem item,
  String? shellTabId,
  int? initialSeason,
  int? initialEpisode,
  Duration? startPosition,
  bool autoPlay = false,
}) {
  // Prefer the shell tab the user is on (e.g. My List), not the content hub
  // that owns extract (Home/Anime). Otherwise overlay origin steals nav.
  final tab = shellTabId ??
      ShellBus.activeShellTabId ??
      hubShellTabIdForPlugin(pluginId);
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute(
      (_) => KitDetailsScreen(
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
class KitDetailsScreen extends ConsumerStatefulWidget {
  const KitDetailsScreen({
    super.key,
    required this.pluginId,
    required this.item,
    this.initialSeason,
    this.initialEpisode,
    this.startPosition,
    this.autoPlay = false,
  });

  final String pluginId;
  final MetaItem item;
  final int? initialSeason;
  final int? initialEpisode;
  final Duration? startPosition;
  final bool autoPlay;

  @override
  ConsumerState<KitDetailsScreen> createState() => _KitDetailsScreenState();
}

class _KitDetailsScreenState extends ConsumerState<KitDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'hub-details-play');
  final FocusNode _backFocus = FocusNode(debugLabel: 'hub-details-back');

  MetaItem? _detail;
  List<KitDetailRailSection> _packRails = const [];
  List<String> _heroBackdrops = const [];
  bool _loading = true;
  String? _error;
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  final Map<String, String> _playFilterSelections = {};
  bool _detailsHeroInitialFocusDone = false;
  Map<String, dynamic>? _watchProgress;
  Set<String> _watchedEpisodes = {};
  bool _autoPlayConsumed = false;
  StreamSubscription<List<Map<String, dynamic>>>? _homeHistorySub;
  List<KitIptvRecHit> _iptvRecHits = const [];
  Object? _iptvPortal;

  @override
  void initState() {
    super.initState();
    WatchHistory.revision.addListener(_onWatchHistoryChanged);
    PackFiltersRegistry.revision.addListener(_onPackFiltersChanged);
    if (hubMetaUsesHomeWatchHistory(widget.item)) {
      _homeHistorySub = WatchHistoryService().historyStream.listen((_) {
        unawaited(_loadWatchProgress());
      });
    }
    unawaited(KitPanelSourceFlagsHooks.warm?.call(ref) ?? Future.value());
    unawaited(_ensurePackFilters());
    unawaited(_loadWatchProgress());
    unawaited(_loadWatchedEpisodes());
    _loading = !hubMetaTmdbEnriched(widget.item);
    _load();
  }

  @override
  void dispose() {
    WatchHistory.revision.removeListener(_onWatchHistoryChanged);
    PackFiltersRegistry.revision.removeListener(_onPackFiltersChanged);
    unawaited(_homeHistorySub?.cancel());
    _scrollController.dispose();
    _heroPlayFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  MetaItem get _show => _detail ?? widget.item;

  List<MetaVideo> get _videos => _show.videos;

  bool get _isMovie => metaIsMovie(_show);

  List<PlayFilterSpec> get _playFilters =>
      PackFiltersRegistry.playFiltersFor(widget.pluginId);

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
    await PackFiltersRegistry.ensureLoaded(widget.pluginId);
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

  String _playFilterValue(PlayFilterSpec spec) {
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
    unawaited(_loadWatchedEpisodes());
  }

  /// TMDB Home: unscoped `{tmdb}_S{s}_E{e}`. Hubs: `{pluginId}_{open.id}_S1_E{e}`
  /// (same keys as [hubEngineSaveProgressCallback] / play auto-mark).
  int? get _watchedMediaId {
    if (hubMetaUsesHomeWatchHistory(_show)) {
      return _show.numericId('tmdb');
    }
    return _show.open?.idInt;
  }

  String? get _watchedCatalog {
    if (hubMetaUsesHomeWatchHistory(_show)) return null;
    if (_watchedMediaId == null) return null;
    return widget.pluginId;
  }

  /// Hubs stamp season `1` in EpisodeWatchedService (play_hooks). TMDB uses real S#.
  int? get _watchedSeasonForKeys =>
      hubMetaUsesHomeWatchHistory(_show) ? null : 1;

  int get _watchedTotalEpisodes {
    final declared = _show.episodes;
    if (declared != null && declared > 0) return declared;
    return _videos.length;
  }

  Future<void> _loadWatchedEpisodes() async {
    final mediaId = _watchedMediaId;
    if (mediaId == null) {
      if (!mounted) return;
      setState(() => _watchedEpisodes = {});
      return;
    }
    final set = await EpisodeWatchedService().getWatchedSet(
      mediaId,
      catalog: _watchedCatalog,
    );
    if (!mounted) return;
    setState(() => _watchedEpisodes = set);
  }

  Future<void> _toggleEpisodeWatched(int season, int episode) async {
    final mediaId = _watchedMediaId;
    if (mediaId == null) return;
    final catalog = _watchedCatalog;
    final svc = EpisodeWatchedService();
    await svc.toggle(mediaId, season, episode, catalog: catalog);
    final watched = await svc.isWatched(
      mediaId,
      season,
      episode,
      catalog: catalog,
    );
    await _loadWatchedEpisodes();
    await _applyListStatusAfterWatchedChange(episodeNowWatched: watched);
    final listTarget = ListFollowTarget.fromMeta(
      pluginId: widget.pluginId,
      meta: _show,
    );
    if (listTarget != null && catalog != null) {
      unawaited(
        ListFollow.syncEpisodeWatched(
          listTarget,
          episode: episode,
          watched: watched,
        ),
      );
    }
  }

  Future<void> _toggleSeasonWatched(int season, List<int> episodes) async {
    final mediaId = _watchedMediaId;
    if (mediaId == null || episodes.isEmpty) return;
    final catalog = _watchedCatalog;
    final keySeason = _watchedSeasonForKeys ?? season;
    final watched = await EpisodeWatchedService().toggleSeason(
      mediaId,
      keySeason,
      episodes,
      catalog: catalog,
    );
    if (!mounted) return;
    await _loadWatchedEpisodes();
    await _applyListStatusAfterWatchedChange(episodeNowWatched: watched);
    final listTarget = ListFollowTarget.fromMeta(
      pluginId: widget.pluginId,
      meta: _show,
    );
    if (listTarget != null && catalog != null) {
      unawaited(
        ListFollow.syncSeasonWatched(
          listTarget,
          episodes: episodes,
          watched: watched,
        ),
      );
    }
  }

  Future<void> _applyListStatusAfterWatchedChange({
    required bool episodeNowWatched,
  }) async {
    final mediaId = _watchedMediaId;
    if (mediaId == null) return;
    final catalog = _watchedCatalog;
    final watchedCount = _watchedEpisodes.length;
    final total = _watchedTotalEpisodes;
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}

    if (catalog == null) {
      final movie = metaItemToMovie(_show);
      if (movie == null || movie.mediaType != 'tv') return;
      await ListFollowFromWatched.applyTmdb(
        movie: movie,
        watchedCount: watchedCount,
        totalEpisodes: movie.numberOfEpisodes > 0
            ? movie.numberOfEpisodes
            : total,
        episodeNowWatched: episodeNowWatched,
        container: container,
      );
      return;
    }

    final listTarget = ListFollowTarget.fromMeta(
      pluginId: widget.pluginId,
      meta: _show,
    );
    if (listTarget == null) return;
    await ListFollowFromWatched.applyHub(
      target: listTarget,
      watchedCount: watchedCount,
      totalEpisodes: total,
      episodeNowWatched: episodeNowWatched,
      container: container,
    );
  }

  Future<void> _loadWatchProgress() async {
    if (!mounted) return;
    try {
      final entries = await WatchHistory.getAll(widget.pluginId);
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
    await WatchHistory.remove(widget.pluginId, show.id);

    final listTarget = ListFollowTarget.fromMeta(
      pluginId: widget.pluginId,
      meta: show,
    );
    if (listTarget != null) {
      await ListFollow.clearProgress(listTarget);
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
            open: open,
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
      final result = await loadKitStremioDetails(widget.item);
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
      unawaited(_loadWatchedEpisodes());
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
    final env = await MetaRuntime.instance.run(
      pluginId: widget.pluginId,
      action: 'details',
      params: hubMetaIsIptv(widget.item)
          ? (KitIptvPlayHooks.hubDetailsParams?.call(widget.item) ??
              hubDetailsParams(widget.item))
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
        _error = notReady ??
            userFacingCatalogError(
              env.error,
              fallback: 'Couldn’t load details. Try again.',
            );
      });
      return;
    }
    final meta = hubMergeDetailsSeed(env.meta ?? widget.item, widget.item);
    final packRails = parseKitDetailRails(env.data);
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
      final resolve = KitIptvPlayHooks.resolvePortalFromMeta;
      _iptvPortal = resolve == null ? null : await resolve(meta);
    }
    unawaited(_loadWatchProgress());
    unawaited(_loadWatchedEpisodes());
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPlay());
    }
  }

  void _maybeAutoPlay() {
    if (!mounted || _autoPlayConsumed || _loading || _error != null) return;
    _autoPlayConsumed = true;
    _playSelected();
  }

  List<MediaTrailer> get _trailers => hubMetaTrailers(_show);

  void _openBestTrailer() {
    final trailers = _trailers;
    if (trailers.isEmpty || !mounted) return;
    AppRouter.openTrailerPlayer(
      context,
      trailers: trailers,
      initialIndex: 0,
      movie: metaItemToMovie(_show),
      languageCode: _show.facts?['originalLanguage']?.toString(),
    );
  }

  void _scrollDetailsToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  /// Episodes / seasons ↑ → Play (claim focus first so scroll cannot dump onto
  /// More Like This).
  void _revealedDetailsHeroPlayFocus() {
    if (_heroPlayFocus.canRequestFocus) {
      _heroPlayFocus.requestFocus();
    }
    _scrollDetailsToTop();
  }

  /// Characters / Cast ↑ on series → episodes (then seasons → Play → back).
  void _focusDetailsEpisodesFromMeta() {
    final handle = ShellTvFocusCoordinator.rowHandle(
      MediaDetailsTv.tabId,
      'episodes',
    );
    final idx = handle?.lastFocusedIndex ?? 0;
    final landed = ShellTvFocusCoordinator.focusRowItem(
          MediaDetailsTv.tabId,
          'episodes',
          idx,
        ) ||
        ShellTvFocusCoordinator.focusRowItem(
          MediaDetailsTv.tabId,
          'seasons',
          0,
        );
    if (!landed && _heroPlayFocus.canRequestFocus) {
      _heroPlayFocus.requestFocus();
    }
    _scrollDetailsToTop();
  }

  void _focusDetailsBack() {
    if (_backFocus.canRequestFocus) {
      _backFocus.requestFocus();
    } else {
      maybePopShellOverlay();
    }
    _scrollDetailsToTop();
  }

  MetaVideo? _selectedVideo() {
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

  Future<void> _playEpisode(MetaVideo? episode) async {
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
    await runPlayFromContext(context: context, ctx: ctx);
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
    unawaited(openSourcesFromContext(context: context, ctx: ctx));
  }

  @override
  Widget build(BuildContext context) {
    return PlayerSurfaceChromeStub(
      builder: (context) => ValueListenableBuilder<AppThemePreset>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, _, _) {
          return DetailsScreen(
            backgroundColor: AppTheme.bgDark,
            loading: _loading,
            errorMessage: _error,
            onRetry: _load,
            loadingChild: Center(
              child: CircularProgressIndicator(
                color: ForjaShellColors.sectionAccent,
              ),
            ),
            errorChild: _error == null
                ? null
                : ShellErrorRetryPanel(
                    message: _error!,
                    onRetry: _load,
                  ),
            body: (_loading || _error != null) ? null : _buildScrollLayout(),
            overlay: MediaDetailsBackButton(focusNode: _backFocus),
          );
        },
      ),
    );
  }

  Widget _buildScrollLayout() {
    final show = _show;
    final videos = _videos;
    final seasons = hubSeasonNumbers(videos).toList()..sort();
    final backdrop = resolveAbsoluteCoverUrl(
      _heroBackdrops.isNotEmpty
          ? _heroBackdrops.first
          : (show.background.isNotEmpty ? show.background : show.poster),
    );
    final backdropUrls = _heroBackdrops.length > 1
        ? _heroBackdrops
        : (backdrop.isNotEmpty ? [backdrop] : const <String>[]);
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;
    final playbackFlags = KitPanelSourceFlagsHooks.watch?.call(ref);
    final isIptv = hubMetaIsIptv(_show);
    final showCatalogSources = !isIptv && kitHasPanelSources(playbackFlags);
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

    // Series episode/season ↑ → Play. Films have no episode rail.
    final heroFocusUp = _revealedDetailsHeroPlayFocus;
    final heroPopUp = tvFocus ? _focusDetailsBack : null;
    final listTarget = ListFollowTarget.fromMeta(
      pluginId: widget.pluginId,
      meta: show,
    );
    final hasClearableProgress = _hasClearableProgress;
    final trailers = _trailers;
    final hasTrailers = trailers.isNotEmpty;
    final isUpcoming = hubMetaIsUpcoming(show, videos: videos);
    final premiereLabel = hubMetaPremiereDateLabel(show, videos: videos);
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
        ? TvSeasonEpisodePicker(
            tmdbId: _watchedMediaId ?? 0,
            seasonCount: seasons.length,
            selectedSeason: _selectedSeason,
            selectedEpisode: _selectedEpisode,
            isLoadingSeason: false,
            seasonData: null,
            fallbackPosterPath: show.poster,
            customEpisodesBySeason: hubEpisodeMaps(videos),
            watchedEpisodes: _watchedEpisodes,
            watchedCatalog: _watchedCatalog,
            watchedSeasonForKeys: _watchedSeasonForKeys,
            onToggleWatched: _toggleEpisodeWatched,
            onSeasonToggleWatched: _watchedMediaId == null
                ? null
                : _toggleSeasonWatched,
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

    // Series: Characters ↑ → episodes (scroll top). Film: Characters ↑ → Play.
    final firstMetaFocusUp = !tvFocus
        ? null
        : (hasEpisodes
            ? _focusDetailsEpisodesFromMeta
            : _revealedDetailsHeroPlayFocus);

    // Episodes own 0..(multi-season ? 1 : 0). Body rails continue after.
    // Order: Characters/Crew/Trailers → other pack rails → More Like This last.
    // Home used to put pack recommendations above Cast, so ↑ from Characters
    // landed on More Like This.
    final metaRowBase = !hasEpisodes
        ? 0
        : (seasons.length > 1 ? 2 : 1);
    final packRecs = _packRails
        .where((r) => r.id == 'recommendations' && r.items.isNotEmpty)
        .toList();
    final packOther = _packRails
        .where((r) => r.id != 'recommendations' && r.items.isNotEmpty)
        .toList();
    final hasPackRecs = packRecs.isNotEmpty;
    final iptvRecs = isIptv && _iptvRecHits.isNotEmpty
        ? _iptvRecHits.map((h) => h.movie).toList()
        : null;

    final identitySections = buildKitTmdbDetailSections(
      context: context,
      pluginId: widget.pluginId,
      cast: show.cast,
      crew: show.crew,
      trailers: hubMetaTrailers(show),
      tvFocus: tvFocus,
      tvRowOrderBase: metaRowBase,
      firstMetaFocusUp: firstMetaFocusUp,
      includeRecommendations: false,
    );
    final packMidSections = buildKitDetailRailSections(
      context: context,
      pluginId: widget.pluginId,
      rails: packOther,
      tvFocus: tvFocus,
      tvRowOrderBase: metaRowBase + identitySections.length,
      firstMetaFocusUp:
          identitySections.isEmpty ? firstMetaFocusUp : null,
    );
    final recOrderBase =
        metaRowBase + identitySections.length + packMidSections.length;
    final packRecSections = hasPackRecs
        ? buildKitDetailRailSections(
            context: context,
            pluginId: widget.pluginId,
            rails: packRecs,
            tvFocus: tvFocus,
            tvRowOrderBase: recOrderBase,
            firstMetaFocusUp: identitySections.isEmpty &&
                    packMidSections.isEmpty
                ? firstMetaFocusUp
                : null,
          )
        : const <Widget>[];
    final tmdbRecSections = hasPackRecs
        ? const <Widget>[]
        : buildKitTmdbDetailSections(
            context: context,
            pluginId: widget.pluginId,
            tvFocus: tvFocus,
            tvRowOrderBase: recOrderBase,
            firstMetaFocusUp: identitySections.isEmpty &&
                    packMidSections.isEmpty
                ? firstMetaFocusUp
                : null,
            includeCast: false,
            includeCrew: false,
            includeTrailers: false,
            includeRecommendations: true,
            recommendations: iptvRecs,
            onRecommendationTap: isIptv && _iptvPortal != null
                ? (movie) {
                    final open = KitIptvPlayHooks.openVodStream;
                    if (open == null) return;
                    for (final hit in _iptvRecHits) {
                      if (hit.movie.id != movie.id) continue;
                      unawaited(
                        open(
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
    final sections = [
      if (episodePicker != null) episodePicker,
      ...identitySections,
      ...packMidSections,
      ...packRecSections,
      ...tmdbRecSections,
    ];

    return MediaDetailsScrollPage(
      scrollController: _scrollController,
      tvHeroPlayFocus: _heroPlayFocus,
      tvBackFocus: _backFocus,
      bodyOverlap: 0,
      topSpacing: DetailsTokens.bodyTopSpacing,
      backgroundColor: AppTheme.bgDark,
      hero: DetailsHero(
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
        facts: kitPackFactRows(
          show,
          positionMs: heroPosMs,
          durationMs: heroDurMs,
        ),
        logoUrl: hubMetaLogoUrl(show),
        height: DetailsTokens.heroHeight(context),
        progressBar: heroPosMs != null && heroDurMs != null
            ? WatchProgressBar(
                positionMs: heroPosMs,
                durationMs: heroDurMs,
              )
            : null,
        seriesProgress: !_isMovie &&
                _watchedEpisodes.isNotEmpty &&
                _watchedTotalEpisodes > 0
            ? WatchSeriesProgress(
                watched: _watchedEpisodes.length,
                total: _watchedTotalEpisodes,
              )
            : null,
        enableKenBurns: policy.kenBurnsBackdrop,
        tvDensity: ShellScope.metricsOf(context).usesTvDensity,
        plainTitle: policy.useFocusableMoodChips,
        selectableTitle: shellDesktopTextSelect(context),
        factsValueMaxLines: policy.useFocusableMoodChips ? 2 : 1,
        actionRow: DetailsHeroTvActionScope(
          tabId: MediaDetailsTv.tabId,
          itemCount: heroActionCount,
          onFocusUp: heroPopUp,
          child: Row(
            children: [
              if (isUpcoming)
                KitDetailsUpcomingNotice(
                  releaseDateLabel: premiereLabel,
                )
              else
                KitDetailsPlayRow(
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
                KitListStatusHero(
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
                  KitGroupedPlayFilter(
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
