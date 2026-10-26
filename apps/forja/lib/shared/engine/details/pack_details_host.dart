import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/downloads/download_page_store.dart';
import 'package:forja/shared/downloads/download_play.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/engine/details/details_host_wire.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/kit_details_play.dart';
import 'package:forja/shared/engine/details/details_stremio.dart';
import 'package:forja/shared/engine/store/watch_history.dart';
import 'package:forja/shared/engine/runtime/open/meta_movie.dart';
import 'package:forja/shared/playback/play_resolve.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja_foundation/widgets/feedback/error_retry_panel.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja/shared/player/sources/resolve/stream_play_hooks.dart';
import 'package:forja/shared/player/sources/kit/panel_source_flags.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';
import 'package:forja/shared/engine/runtime/kit/list/list_open_mode.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/playback/cache/catalog_sources_session_cache.dart';
import 'package:forja/shared/playback/cache/player_stream_extract_cache.dart';
import 'package:forja/shared/engine/store/list_follow.dart';
import 'package:forja/shared/engine/store/list_follow_from_watched.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/models/plugin_language.dart';
import 'package:forja/shared/engine/runtime/nav/pack_filters.dart';
import 'package:forja/shared/engine/runtime/nav/play_filters.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/grouped_play_filter.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/multiselect_play_filter.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/hero_pill_buttons.dart';
import 'package:forja/shared/player/sources/kit/kit_sources.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/kit_details_play_row.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/kit_list_status_hero.dart';
import 'package:forja/shared/engine/details/media_details.dart';
import 'package:forja/shell/desktop/desktop_selectable_title.dart';
import 'package:forja_foundation/widgets/feedback/loading_state.dart';
import 'package:forja_foundation/widgets/details/details_hero.dart';
import 'package:forja_foundation/blocks/details/details_block.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
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
        isContinueWatchingEligible,
        isContinueWatchingRowEntry,
        latestHistoryForShow,
        latestInProgressForShow,
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
}) async {
  // Prefer the content hub that owns the title (Anime / Asian Drama / Home),
  // not the browse tab you opened from (e.g. My List). Switch the rail to match.
  // Sync when pack mem is warm — never block the route on prefs/repair.
  final contentTab = await resolveDetailsShellTabId(
    pluginId: pluginId,
    item: item,
  );
  final tab = contentTab ?? shellTabId ?? ShellBus.activeShellTabId;
  if (tab != null && tab.isNotEmpty && ShellBus.activeShellTabId != tab) {
    ShellBus.requestTab.value = tab;
  }
  if (!context.mounted) return null;
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute(
      (_) => PackDetailsHost(
        pluginId: pluginId,
        item: item,
        shellTabId: tab,
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
typedef KitDetailsScreen = PackDetailsHost;

class PackDetailsHost extends ConsumerStatefulWidget {
  const PackDetailsHost({
    super.key,
    required this.pluginId,
    required this.item,
    this.shellTabId,
    this.initialSeason,
    this.initialEpisode,
    this.startPosition,
    this.autoPlay = false,
  });

  final String pluginId;
  final MetaItem item;
  final String? shellTabId;
  final int? initialSeason;
  final int? initialEpisode;
  final Duration? startPosition;
  final bool autoPlay;

  @override
  ConsumerState<PackDetailsHost> createState() => _PackDetailsHostState();
}

class _PackDetailsHostState extends ConsumerState<PackDetailsHost> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'hub-details-play');
  final FocusNode _backFocus = FocusNode(debugLabel: 'hub-details-back');

  MetaItem? _detail;
  List<KitDetailRailSection> _packRails = const [];
  List<KitDetailSeasonLink> _packSeasons = const [];
  KitDetailsLayout _layout = KitDetailsLayout.classic;
  List<String> _heroBackdrops = const [];
  bool _loading = true;
  String? _error;
  int _selectedSeason = 1;
  int _selectedEpisode = 1;

  /// Opaque pack Media id for season-chain reload (`data.seasons[].id`).
  String? _detailsOverrideId;

  /// Season-chip reload — skip stale cache and don't merge previous cour art.
  bool _packSeasonForceRefresh = false;

  /// Apply [widget.initialSeason] / [widget.initialEpisode] only on first paint.
  bool _appliedInitialSeasonEpisode = false;
  int _detailsLoadGen = 0;
  final Map<String, String> _playFilterSelections = {};
  Set<String> _streamLanguageKeys = {};
  List<PluginLanguage> _streamLanguageOptions = const [];
  bool _detailsHeroInitialFocusDone = false;
  Map<String, dynamic>? _watchProgress;
  Set<String> _watchedEpisodes = {};
  bool _autoPlayConsumed = false;
  StreamSubscription<List<Map<String, dynamic>>>? _homeHistorySub;
  String _episodeView = kEpisodeViewCards;

  /// Cast / trailers / pack rails mount after hero+episodes so cover inserts
  /// cannot pile into `libCachedImageData.db` during the first leanback KeyEvents.
  bool _belowFoldReady = false;
  Timer? _belowFoldTimer;

  @override
  void initState() {
    super.initState();
    WatchHistory.revision.addListener(_onWatchHistoryChanged);
    PackFiltersRegistry.revision.addListener(_onPackFiltersChanged);
    packSettingsRevisionListenable.addListener(_onPackSettingsChanged);
    if (hubMetaUsesHomeWatchHistory(widget.item)) {
      _homeHistorySub = WatchHistoryService().historyStream.listen((_) {
        unawaited(_loadWatchProgress());
      });
    }
    unawaited(KitPanelSourceFlagsHooks.warm?.call(ref) ?? Future.value());
    unawaited(_ensurePackFilters());
    unawaited(_loadWatchProgress());
    unawaited(_loadWatchedEpisodes());
    unawaited(_loadEpisodeView());
    unawaited(_loadStreamLanguages());
    _loading = !hubMetaTmdbEnriched(widget.item);
    _noteDownloadPage(widget.item);
    _load();
  }

  @override
  void dispose() {
    // Release a pending player-surface wait so no listener outlives us.
    final wait = _playerSurfaceWait;
    if (wait != null && !wait.isCompleted) wait.complete();
    WatchHistory.revision.removeListener(_onWatchHistoryChanged);
    PackFiltersRegistry.revision.removeListener(_onPackFiltersChanged);
    packSettingsRevisionListenable.removeListener(_onPackSettingsChanged);
    unawaited(_homeHistorySub?.cancel());
    _belowFoldTimer?.cancel();
    _scrollController.dispose();
    _heroPlayFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  void _armBelowFoldCovers() {
    _belowFoldTimer?.cancel();
    _belowFoldTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || _belowFoldReady) return;
      setState(() => _belowFoldReady = true);
    });
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
    unawaited(_loadStreamLanguages());
  }

  void _onPackSettingsChanged() {
    unawaited(_loadEpisodeView());
    unawaited(_loadStreamLanguages());
  }

  Future<void> _loadEpisodeView() async {
    final raw = await PackSettingsStore.getString(
      widget.pluginId,
      'episodeView',
      defaultValue: kEpisodeViewCards,
    );
    final next = episodeViewIsChips(raw)
        ? kEpisodeViewChips
        : kEpisodeViewCards;
    if (!mounted || next == _episodeView) return;
    setState(() => _episodeView = next);
  }

  Future<void> _setEpisodeView(String raw) async {
    final next = episodeViewIsChips(raw)
        ? kEpisodeViewChips
        : kEpisodeViewCards;
    if (next == _episodeView) return;
    setState(() => _episodeView = next);
    // No hub remount — details chrome only; prefs + revision still sync Settings.
    await PackSettingsStore.setString(
      widget.pluginId,
      'episodeView',
      next,
      reloadHub: false,
    );
    PackSettingsStore.onNonSecretUserWrite?.call();
  }

  bool get _hasStreamLanguageFilter =>
      _playFilters.any((f) => f.isMultiselect && f.isPluginLanguagesSource);

  PlayFilterSpec? get _streamLanguageFilterSpec {
    for (final f in _playFilters) {
      if (f.isMultiselect && f.isPluginLanguagesSource) return f;
    }
    return null;
  }

  Future<void> _loadStreamLanguages() async {
    final spec = _streamLanguageFilterSpec;
    if (spec == null) {
      if (_streamLanguageOptions.isEmpty && _streamLanguageKeys.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _streamLanguageOptions = const [];
        _streamLanguageKeys = {};
      });
      return;
    }
    final packs = await EngineService.instance.listSourcesPanelPacks();
    // Pack-declared types (e.g. anime). Else Home movie|tv from the title.
    // Options = full hub-type union (not enabled-only) — same idea as Home.
    final types = spec.types.isNotEmpty
        ? spec.types
        : [_isMovie ? 'movie' : 'tv'];
    final options = PluginStreamLanguages.unionFromPacks(
      packs: packs,
      types: types,
      kinds: spec.kinds,
    );
    final selected = await PluginStreamLanguages.selectedKeys(widget.pluginId);
    final valid = {
      for (final k in selected)
        if (options.any((o) => o.key == k)) k,
    };
    if (!mounted) return;
    setState(() {
      _streamLanguageOptions = options;
      _streamLanguageKeys = valid;
    });
  }

  Future<void> _setStreamLanguages(Set<String> next) async {
    setState(() => _streamLanguageKeys = next);
    await PluginStreamLanguages.saveSelectedKeys(widget.pluginId, next);
  }

  Future<void> _ensurePackFilters() async {
    // Bust 24h filters cache so play[] edits (e.g. drop kinds/grouped) apply.
    await PackFiltersRegistry.ensureLoaded(widget.pluginId, force: true);
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

  /// Grouped SUB/DUB play filter, else kind inferred from stream language keys.
  String? get _effectiveAudioCategory =>
      catalogPlayAudioCategory(_playFilterSelections) ??
      PluginStreamLanguages.audioCategoryFromKeys(_streamLanguageKeys);

  Iterable<String?> _audioCategoriesForCacheClear() sync* {
    yield null;
    yield 'sub';
    yield 'dub';
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

  /// Hero progress denominator — declared total, else loaded videos.
  int get _watchedTotalEpisodes {
    final declared = metaDeclaredEpisodeCount(_show);
    if (declared > 0) return declared;
    return _videos.length;
  }

  /// My List / Simkl Completed — declared total only (never invent from videos).
  int get _listSeriesTotal => metaDeclaredEpisodeCount(_show);

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
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}

    if (catalog == null) {
      final movie = metaItemToMovie(_show);
      if (movie == null || movie.mediaType != 'tv') return;
      final total = _listSeriesTotal > 0
          ? _listSeriesTotal
          : (movie.numberOfEpisodes > 0 ? movie.numberOfEpisodes : 0);
      await ListFollowFromWatched.applyTmdb(
        movie: movie,
        watchedCount: watchedCount,
        totalEpisodes: total,
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
      totalEpisodes: _listSeriesTotal,
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
      if (hubMetaUsesHomeWatchHistory(_show)) {
        final hubPos = (hit?['positionMs'] as num?)?.toInt() ?? 0;
        final hubDur = (hit?['durationMs'] as num?)?.toInt() ?? 0;
        // Seed-only hub rows (pos 0) must not hide real Home resume progress.
        final hubUpNext = hit != null && hit['upNext'] == true;
        final hubShowStarted = hit != null && hit['showStarted'] == true;
        if (hit == null ||
            !isContinueWatchingEligible(
              hubPos,
              hubDur,
              upNext: hubUpNext,
              showStarted: hubShowStarted,
            )) {
          final home = await _homeWatchHistoryProgress();
          if (home != null) hit = home;
        }
      }
      if (!mounted) return;
      setState(() {
        _watchProgress = hit;
        if (hit != null) {
          _restorePlayFiltersFromProgress(hit);
          _applyProgressEpisodeSelection(hit);
        }
      });
    } catch (_) {}
  }

  /// Open on the last played episode when caller did not deep-link S/E.
  void _applyProgressEpisodeSelection(Map<String, dynamic> hit) {
    if (widget.initialSeason != null || widget.initialEpisode != null) return;
    if (_isMovie) return;
    final ep = (hit['episodeNumber'] as num?)?.toInt();
    if (ep == null || ep <= 0) return;
    if (_usesPackSeasons) {
      // Hub progress keys are always S1 per AniList Media id.
      final videos = hubVideosForSeason(_videos, 1);
      if (videos.isNotEmpty && !videos.any((v) => (v.episode ?? 1) == ep)) {
        return;
      }
      _selectedEpisode = ep;
      return;
    }
    final season = (hit['season'] as num?)?.toInt() ?? _selectedSeason;
    final videos = hubVideosForSeason(_videos, season);
    if (videos.isNotEmpty && !videos.any((v) => (v.episode ?? 1) == ep)) {
      return;
    }
    _selectedSeason = season;
    _selectedEpisode = ep;
  }

  Future<Map<String, dynamic>?> _homeWatchHistoryProgress() async {
    final tmdbId = _show.numericId('tmdb');
    if (tmdbId == null) return null;
    final history = await WatchHistoryService().getHistory();
    final item =
        latestInProgressForShow(tmdbId, history) ??
        latestHistoryForShow(tmdbId, history);
    if (item == null) return null;
    return {
      'metaId': _show.id,
      'season': item['season'] ?? _selectedSeason,
      'episodeNumber': item['episode'] ?? _selectedEpisode,
      'positionMs': watchHistoryInt(item['position']),
      'durationMs': watchHistoryInt(item['duration']),
      'episodeVideoId': item['episodeVideoId'],
      'extras': item['extras'],
      'sourceId': item['sourceId'],
      'streamUrl': item['streamUrl'],
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
    final clamped = (durMs > 0 && posMs > durMs - 30000)
        ? (durMs - 30000)
        : posMs;
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
    final clearSeason = _playbackSeason;
    final open = show.open;
    if (open != null) {
      final videoId = progress['episodeVideoId']?.toString();
      for (final audio in _audioCategoriesForCacheClear()) {
        CatalogSourcesSessionCache.invalidate(
          CatalogSourcesSessionCache.cacheKey(
            mediaId: 0,
            mediaType: show.type,
            season: _isMovie ? null : clearSeason,
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
          season: _isMovie ? null : clearSeason,
          episode: _isMovie ? null : ep,
        ),
      );
      if (hubMetaUsesHomeWatchHistory(show)) {
        final uniqueId = _isMovie
            ? '$tmdbId'
            : '${tmdbId}_S${clearSeason}_E$ep';
        await WatchHistoryService().removeItem(uniqueId);
      }
    }

    if (!mounted) return;
    setState(() => _watchProgress = null);
  }

  bool get _offlineLibrary => widget.item.open?.surface == 'offline';

  void _noteDownloadPage(MetaItem item) {
    DownloadPageStore.note(mediaIdForMetaItem(item), item);
  }

  bool get _usesPackSeasons => _packSeasons.length > 1;

  /// Pack season ids are opaque (`anilist:123` or bare `123`).
  bool _packSeasonIdMatches(String seasonId, MetaItem meta) {
    final a = seasonId.trim();
    if (a.isEmpty) return false;
    final openId = meta.open?.id.trim() ?? '';
    final metaId = meta.id.trim();
    if (a == metaId || a == openId) return true;
    final aTail = a.contains(':') ? a.split(':').last : a;
    final metaTail = metaId.contains(':') ? metaId.split(':').last : metaId;
    if (aTail.isNotEmpty && (aTail == openId || aTail == metaTail)) {
      return true;
    }
    return false;
  }

  /// Bare details id for a pack season switch — no previous cour `open.extract`.
  Map<String, dynamic> _hubDetailsParamsForSeasonId(String seasonId) {
    final raw = seasonId.trim();
    final tail = raw.contains(':') ? raw.split(':').last.trim() : raw;
    return {'id': tail.isNotEmpty ? tail : raw};
  }

  Map<String, dynamic> _hubDetailsParamsForLoad() {
    final override = _detailsOverrideId?.trim();
    if (override != null && override.isNotEmpty) {
      return _hubDetailsParamsForSeasonId(override);
    }
    final seed = _detail ?? widget.item;
    return hubMetaIsIptv(seed)
        ? (KitStreamPlayHooks.hubDetailsParams?.call(seed) ??
              hubDetailsParams(seed))
        : hubDetailsParams(seed);
  }

  /// Merge seed for details paint. Season switch uses a stub so S4 name/logo
  /// /synopsis cannot bleed onto S1.
  MetaItem _detailsMergeSeed() {
    final override = _detailsOverrideId?.trim();
    if (override == null || override.isEmpty) {
      return _detail ?? widget.item;
    }
    final prev = _detail ?? widget.item;
    final raw = override;
    final tail = raw.contains(':') ? raw.split(':').last.trim() : raw;
    final surface = (prev.open?.surface ?? '').trim();
    final id = raw.contains(':') ? raw : (tail.isEmpty ? raw : 'anilist:$tail');
    return MetaItem(
      id: id,
      type: prev.type.isNotEmpty ? prev.type : 'anime',
      name: '',
      open: MetaOpen(
        surface: surface.isNotEmpty ? surface : 'anime',
        id: tail.isNotEmpty ? tail : raw,
      ),
    );
  }

  KitDetailSeasonLink? _packSeasonLink(int season) {
    for (final s in _packSeasons) {
      if (s.number == season) return s;
    }
    return null;
  }

  String? get _packSeasonSubtitle {
    if (!_usesPackSeasons) return null;
    final link = _packSeasonLink(_selectedSeason);
    final label = (link?.label ?? '').trim();
    if (label.isEmpty) return null;
    final year = link?.year;
    if (year != null && year > 0) return '$label · $year';
    return label;
  }

  void _paintLoaded(
    MetaItem meta, {
    required List<KitDetailRailSection> rails,
    required KitDetailsLayout layout,
    required List<String> backdrops,
    List<KitDetailSeasonLink> packSeasons = const [],
  }) {
    final applyInitial = !_appliedInitialSeasonEpisode;
    var firstSeason = 1;
    var firstEp = 1;
    if (packSeasons.length > 1) {
      final matched = packSeasons
          .where((s) => _packSeasonIdMatches(s.id, meta))
          .toList();
      if (matched.isNotEmpty) {
        firstSeason = matched.first.number;
      } else {
        final marked = packSeasons.where((s) => s.selected).toList();
        if (marked.isNotEmpty) {
          firstSeason = marked.first.number;
        } else if (packSeasons.any((s) => s.number == _selectedSeason)) {
          firstSeason = _selectedSeason;
        } else {
          firstSeason = packSeasons.first.number;
        }
      }
      if (applyInitial &&
          widget.initialSeason != null &&
          packSeasons.any((s) => s.number == widget.initialSeason)) {
        firstSeason = widget.initialSeason!;
      }
      // Pack seasons keep per-Media videos at season 1.
      final seasonVideos = hubVideosForSeason(meta.videos, 1);
      final wantInitialEp = applyInitial ? widget.initialEpisode : null;
      firstEp = seasonVideos.isEmpty
          ? (wantInitialEp ?? 1)
          : (wantInitialEp != null &&
                    seasonVideos.any((v) => v.episode == wantInitialEp)
                ? wantInitialEp
                : (seasonVideos.first.episode ?? 1));
    } else {
      final seasons = hubSeasonNumbers(meta.videos).toList()..sort();
      firstSeason = seasons.isEmpty ? 1 : seasons.first;
      if (applyInitial &&
          widget.initialSeason != null &&
          (seasons.isEmpty || seasons.contains(widget.initialSeason))) {
        firstSeason = widget.initialSeason!;
      }
      final seasonVideos = hubVideosForSeason(meta.videos, firstSeason);
      final wantInitialEp = applyInitial ? widget.initialEpisode : null;
      firstEp = seasonVideos.isEmpty
          ? (wantInitialEp ?? 1)
          : (wantInitialEp != null &&
                    seasonVideos.any((v) => v.episode == wantInitialEp)
                ? wantInitialEp
                : (seasonVideos.first.episode ?? 1));
    }
    setState(() {
      _detail = meta;
      _packRails = rails;
      _packSeasons = packSeasons;
      _layout = layout;
      _heroBackdrops = backdrops;
      _loading = false;
      _error = null;
      _selectedSeason = firstSeason;
      _selectedEpisode = firstEp;
      _detailsOverrideId = null;
      _packSeasonForceRefresh = false;
      _appliedInitialSeasonEpisode = true;
      _belowFoldReady = false;
    });
    _noteDownloadPage(meta);
    unawaited(_loadStreamLanguages());
    _armBelowFoldCovers();
  }

  Future<void> _onPackSeasonSelected(int season) async {
    final link = _packSeasonLink(season);
    if (link == null) return;
    if (_packSeasonIdMatches(link.id, _show)) {
      final eps = hubVideosForSeason(_videos, 1);
      setState(() {
        _selectedSeason = season;
        _selectedEpisode = eps.isEmpty ? 1 : (eps.first.episode ?? 1);
      });
      return;
    }
    setState(() {
      _selectedSeason = season;
      _detailsOverrideId = link.id;
      _packSeasonForceRefresh = true;
      _loading = true;
      _error = null;
      _watchProgress = null;
      _watchedEpisodes = {};
    });
    await _load();
  }

  Future<void> _load() async {
    final loadGen = ++_detailsLoadGen;
    if (_offlineLibrary) {
      if (loadGen != _detailsLoadGen) return;
      _paintLoaded(
        widget.item,
        rails: const [],
        layout: KitDetailsLayout.classic,
        backdrops: hubHeroBackdropUrls(widget.item),
      );
      return;
    }
    if (hubMetaIsStremio(widget.item)) {
      setState(() {
        _loading = true;
        _error = null;
      });
      final result = await loadKitStremioDetails(widget.item);
      if (!mounted || loadGen != _detailsLoadGen) return;
      final meta = result.meta;
      final backdrops = hubHeroBackdropUrls(meta);
      _paintLoaded(
        meta,
        rails: result.rails,
        layout: KitDetailsLayout.classic,
        backdrops: backdrops,
      );
      unawaited(_loadWatchProgress());
      unawaited(_loadWatchedEpisodes());
      if (widget.autoPlay) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPlay());
      }
      return;
    }

    final forceRefresh = _packSeasonForceRefresh;
    final seedEnriched = !forceRefresh && hubMetaTmdbEnriched(widget.item);
    if (!seedEnriched) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    var railsArrived = false;
    final seed = _detailsMergeSeed();
    final env = await MetaRuntime.instance.run(
      pluginId: widget.pluginId,
      action: 'details',
      params: _hubDetailsParamsForLoad(),
      forceRefresh: forceRefresh,
      onUpdated: (next) {
        if (!mounted || loadGen != _detailsLoadGen) return;
        final meta = hubMergeDetailsSeed(next.meta ?? seed, seed);
        final packRails = parseKitDetailRails(next.data);
        final packSeasons = parseKitDetailSeasons(next.data);
        if (packRails.isNotEmpty) railsArrived = true;
        setState(() {
          _detail = meta;
          if (packRails.isNotEmpty) _packRails = packRails;
          if (packSeasons.length > 1) _packSeasons = packSeasons;
          _heroBackdrops = hubHeroBackdropUrls(meta);
        });
        _noteDownloadPage(meta);
      },
    );
    if (!mounted || loadGen != _detailsLoadGen) return;
    if (!env.ok) {
      final notReady = await PluginInstallCoordinator.instance
          .pluginNotReadyMessage(widget.pluginId);
      if (!mounted || loadGen != _detailsLoadGen) return;
      setState(() {
        _loading = false;
        _packSeasonForceRefresh = false;
        _error =
            notReady ??
            userFacingCatalogError(
              env.error,
              fallback: 'Couldn’t load details. Try again.',
            );
      });
      return;
    }
    final meta = hubMergeDetailsSeed(env.meta ?? seed, seed);
    final loadedRails = parseKitDetailRails(env.data);
    // Deferred More Like This can land before this paint. Don't replace it
    // with the first envelope, which has no rails yet.
    final packRails = loadedRails.isNotEmpty || !railsArrived
        ? loadedRails
        : _packRails;
    final loadedSeasons = parseKitDetailSeasons(env.data);
    final packSeasons = loadedSeasons.length > 1 ? loadedSeasons : _packSeasons;
    final layout = parseKitDetailsLayout(env.data);
    final backdrops = hubHeroBackdropUrls(meta);
    if (!mounted || loadGen != _detailsLoadGen) return;
    _paintLoaded(
      meta,
      rails: packRails,
      layout: layout,
      backdrops: backdrops,
      packSeasons: packSeasons,
    );
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

  /// Characters / Cast ↑ on series → episodes (then seasons → range → Play → back).
  void _focusDetailsEpisodesFromMeta() {
    final tab = MediaDetailsTv.tabId;
    final handle = ShellTvFocusCoordinator.rowHandle(tab, 'episodes');
    final idx = handle?.lastFocusedIndex ?? 0;
    final landed =
        ShellTvFocusCoordinator.focusRowItem(tab, 'episodes', idx) ||
        ShellTvFocusCoordinator.focusRowItem(tab, 'seasons', 0) ||
        ShellTvFocusCoordinator.focusRowItem(tab, 'episode-chrome', 0);
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

  /// Media-local season for play / sources (pack franchise chips use UI numbers).
  int get _playbackSeason => _usesPackSeasons ? 1 : _selectedSeason;

  MetaVideo? _selectedVideo() {
    final matchSeason = _playbackSeason;
    for (final v in _videos) {
      if ((v.season ?? 1) == matchSeason &&
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
    final season = ep?.season ?? _playbackSeason;
    final progress = _watchProgress;
    final progressExtras = progress?['extras'] is Map
        ? Map<String, dynamic>.from(progress!['extras'] as Map)
        : const <String, dynamic>{};
    final mergedExtras = {...progressExtras, ..._playFilterExtras};
    final progressVideoId = progress?['episodeVideoId']?.toString();
    final startPosition = _startPositionForEpisode(epNum);
    final preferredPluginId = preferredEnginePluginForResume(
      progress: progress,
      startPosition: startPosition,
    );
    final ctx = catalogPlayContextFromMeta(
      meta: _show,
      pluginId: widget.pluginId,
      episode: ep,
      season: season,
      episodeNumber: epNum,
      videos: _videos,
      episodeVideoId: progressVideoId,
      extras: mergedExtras,
      audioCategory: _effectiveAudioCategory,
      startPosition: startPosition,
      preferredPluginId: preferredPluginId,
      savedStreamUrl: progress?['streamUrl'] as String?,
    );
    await runPlayFromContext(context: context, ctx: ctx);
    if (!mounted) return;
    // An in-player episode switch replaces the player route, which completes
    // the future above while the next episode is still playing. Reload
    // progress once the player surface is really gone, so the details page
    // selects the episode the viewer actually stopped on.
    await _awaitPlayerSurfaceClosed();
    if (!mounted) return;
    await _loadWatchProgress();
    await _loadWatchedEpisodes();
    await _afterPlayClosed();
  }

  Completer<void>? _playerSurfaceWait;

  Future<void> _awaitPlayerSurfaceClosed() async {
    final active = ShellBus.playerSurfaceActive;
    if (!active.value) return;
    final closed = Completer<void>();
    _playerSurfaceWait = closed;
    void onChange() {
      if (!active.value && !closed.isCompleted) closed.complete();
    }

    active.addListener(onChange);
    try {
      await closed.future;
    } finally {
      active.removeListener(onChange);
      if (identical(_playerSurfaceWait, closed)) _playerSurfaceWait = null;
    }
  }

  Future<void> _playFirstDownload() async {
    final movie = metaItemToMovie(_show);
    final mediaId = mediaIdForMetaItem(_show);
    final task = firstCompletedDownload(
      DownloadService.instance.tasksNotifier.value,
      mediaId,
    );
    if (task == null) {
      ForjaToast.info('No saved file');
      return;
    }
    if (!mounted) return;
    await playCompletedDownloadTask(context, task, movie: movie);
  }

  void _playSelected() {
    if (_offlineLibrary) {
      unawaited(_playFirstDownload());
      return;
    }
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
      season: _playbackSeason,
      episodeNumber: _selectedEpisode,
      videos: _videos,
      extras: _playFilterExtras,
      audioCategory: _effectiveAudioCategory,
    );
    unawaited(
      openSourcesFromContext(
        context: context,
        ctx: ctx,
        filesOnly: _offlineLibrary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.shellTabId?.trim() ?? '';
    return ValueListenableBuilder<bool>(
      valueListenable: ShellBus.hubLayoutRtlFor(tab),
      builder: (context, rtl, child) {
        if (!rtl) return child!;
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      child: PlayerSurfaceChromeStub(
        builder: (context) => ValueListenableBuilder<AppThemePreset>(
          valueListenable: AppTheme.themeNotifier,
          builder: (context, _, _) {
            return DetailsScreen(
              backgroundColor: AppTheme.bgDark,
              loading: _loading,
              errorMessage: _error,
              onRetry: _load,
              // Centered indicator at shell scale while metadata loads.
              // Franchise name (strip "4th Season" / Part N) — not the cour card.
              loadingChild: ForjaLoadingState(
                backgroundColor: AppTheme.bgDark,
                title: hubFranchiseLoadingTitle(widget.item),
              ),
              errorChild: _error == null
                  ? null
                  : ShellErrorRetryPanel(message: _error!, onRetry: _load),
              body: (_loading || _error != null) ? null : _buildScrollLayout(),
              overlay: MediaDetailsBackButton(focusNode: _backFocus),
            );
          },
        ),
      ),
    );
  }

  /// Episode maps for the picker. Pack franchise seasons remap Media videos
  /// (always season 1) under the selected pack season number.
  Map<int, List<Map<String, dynamic>>>? _episodeMapsForPicker(
    List<MetaVideo> videos,
  ) {
    if (!_usesPackSeasons) return hubEpisodeMaps(videos);
    final base = hubEpisodeMaps(videos);
    final eps =
        base?[1] ??
        (base?.values.isNotEmpty == true
            ? base!.values.first
            : const <Map<String, dynamic>>[]);
    return {_selectedSeason: eps};
  }

  Widget _buildScrollLayout() {
    final show = _show;
    final videos = _videos;
    final seasons = _usesPackSeasons
        ? _packSeasons.map((s) => s.number).toList()
        : (hubSeasonNumbers(videos).toList()..sort());
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
    final showCatalogSources =
        _offlineLibrary || (!isIptv && kitHasPanelSources(playbackFlags));
    // Pack season chain: show Season 1…N even when opening a bridge film.
    final hasEpisodes = _usesPackSeasons
        ? (videos.isNotEmpty || _packSeasons.length > 1)
        : (videos.isNotEmpty && !_isMovie);

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
    final selectedAir = selectedVideo == null
        ? null
        : hubVideoAirDateInfo(selectedVideo);
    final selectedUnaired = selectedAir?.notShippedYet == true;
    // Same as a not-yet-started title: message, no green Play / white Sources.
    final blockPlay = isUpcoming || selectedUnaired;
    final episodeAirLabel = selectedAir?.label?.trim() ?? '';
    final noticeLabel = selectedUnaired && episodeAirLabel.isNotEmpty
        ? episodeAirLabel
        : premiereLabel;
    var tvIndex = 0;
    final playIndex = blockPlay ? 0 : tvIndex++;
    final sourcesIndex = !blockPlay && showCatalogSources ? tvIndex++ : null;
    final clearIndex = hasClearableProgress ? tvIndex++ : null;
    final trailerIndex = hasTrailers ? tvIndex++ : null;
    final listIndex = listTarget != null ? tvIndex++ : null;
    final playFilters = _playFilters
        .where((f) => f.style == 'grouped' && f.options.length >= 2)
        .toList();
    final showPlayFilters = !blockPlay && playFilters.isNotEmpty;
    final showLangFilter =
        !blockPlay &&
        _hasStreamLanguageFilter &&
        _streamLanguageOptions.isNotEmpty;
    final playFilterIndex = showPlayFilters ? tvIndex : null;
    if (showPlayFilters) {
      for (final f in playFilters) {
        tvIndex += f.options.length;
      }
    }
    // SUB + DUB are separate hero focus slots — must match
    // KitMultiselectPlayFilter.focusSlotCount (was tvIndex++ → DUB unreachable).
    final langFilterIndex = showLangFilter ? tvIndex : null;
    if (showLangFilter) {
      tvIndex += KitMultiselectPlayFilter.focusSlotCount(
        _streamLanguageOptions,
      );
    }
    final heroActionCount = tvIndex;

    Widget? episodePicker;
    if (hasEpisodes) {
      final packSeasonLabels = <int, String>{
        for (final s in _packSeasons)
          if ((s.label ?? '').trim().isNotEmpty) s.number: s.label!.trim(),
      };
      final packSeasonYears = <int, int>{
        for (final s in _packSeasons)
          if (s.year != null && s.year! > 0) s.number: s.year!,
      };
      final packSeasonPosters = <int, String>{
        for (final s in _packSeasons)
          if ((s.poster ?? '').trim().isNotEmpty) s.number: s.poster!.trim(),
      };
      final picker = TvSeasonEpisodePicker(
        tmdbId: _watchedMediaId ?? 0,
        seasonCount: seasons.length,
        selectedSeason: _selectedSeason,
        selectedEpisode: _selectedEpisode,
        isLoadingSeason: false,
        seasonData: null,
        fallbackPosterPath: show.poster,
        seasonPosters: _usesPackSeasons ? packSeasonPosters : const {},
        seasonLabels: _usesPackSeasons ? packSeasonLabels : const {},
        seasonYears: _usesPackSeasons ? packSeasonYears : const {},
        customEpisodesBySeason: _episodeMapsForPicker(videos),
        watchedEpisodes: _watchedEpisodes,
        watchedCatalog: _watchedCatalog,
        watchedSeasonForKeys: _watchedSeasonForKeys,
        onToggleWatched: _toggleEpisodeWatched,
        onSeasonToggleWatched: _watchedMediaId == null
            ? null
            : _toggleSeasonWatched,
        onSeasonSelected: (season) {
          if (_usesPackSeasons) {
            unawaited(_onPackSeasonSelected(season));
            return;
          }
          final eps = hubVideosForSeason(videos, season);
          setState(() {
            _selectedSeason = season;
            _selectedEpisode = eps.isEmpty ? 1 : (eps.first.episode ?? 1);
          });
        },
        onEpisodeSelected: (ep) => setState(() => _selectedEpisode = ep),
        onEpisodePlay: (ep) {
          setState(() => _selectedEpisode = ep);
          _playSelected();
        },
        tvRowOrderBase: 0,
        tvFocusUp: heroFocusUp,
        episodeView: _episodeView,
        onEpisodeViewChanged: _setEpisodeView,
      );
      episodePicker = tvFocus
          ? ShellPaintTvTabScope(tabId: MediaDetailsTv.tabId, child: picker)
          : picker;
    }

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

    // Episodes own view chrome / seasons / episode rows. Then protocol cast /
    // crew / trailers, then pack rails (Related / More Like This / …).
    final metaRowBase = detailsEpisodeFocusRowCount(
      hasEpisodes: hasEpisodes,
      seasonCount: seasons.length,
    );
    final isAnime = (show.open?.surface ?? '').trim() == 'anime';
    final castMaps = show.cast;
    final crewMaps = [
      for (final e in show.crew)
        {
          'name': e['name'] ?? '',
          'character': e['job'] ?? e['character'] ?? '',
          'profilePath': e['profilePath'] ?? '',
        },
    ];
    final hasCast = castMaps.isNotEmpty;
    final hasCrew = crewMaps.isNotEmpty;
    final bodyTrailers = trailers;
    final hasBodyTrailers = bodyTrailers.isNotEmpty;

    var protocolOrder = metaRowBase;
    final mountBelow = _belowFoldReady;
    final castSection = hasCast && mountBelow
        ? MediaDetailsCastSection(
            cast: castMaps,
            title: isAnime ? 'Characters' : 'Cast',
            tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
            tvRowId: tvFocus ? 'cast' : null,
            tvRowOrder: protocolOrder,
            tvFocusUp: firstMetaFocusUp,
          )
        : null;
    if (hasCast) protocolOrder++;
    final crewSection = hasCrew && mountBelow
        ? MediaDetailsCastSection(
            cast: crewMaps,
            title: 'Crew',
            tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
            tvRowId: tvFocus ? 'crew' : null,
            tvRowOrder: protocolOrder,
            // Cast owns ↑ when present; otherwise Crew is first meta row.
            tvFocusUp: hasCast ? null : firstMetaFocusUp,
          )
        : null;
    if (hasCrew) protocolOrder++;
    final trailersSection = hasBodyTrailers && mountBelow
        ? MediaDetailsTrailersSection(
            trailers: bodyTrailers,
            movie: metaItemToMovie(show),
            languageCode: show.facts?['originalLanguage']?.toString(),
            tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
            tvRowId: 'trailers',
            tvRowOrder: protocolOrder,
            tvFocusUp: !hasCast && !hasCrew ? firstMetaFocusUp : null,
          )
        : null;
    if (hasBodyTrailers) protocolOrder++;

    final packRecs = mountBelow
        ? _packRails
              .where((r) => r.id == 'recommendations' && r.items.isNotEmpty)
              .toList()
        : const <KitDetailRailSection>[];
    final packOther = mountBelow
        ? _packRails
              .where((r) => r.id != 'recommendations' && r.items.isNotEmpty)
              .toList()
        : const <KitDetailRailSection>[];
    final hasPackRecs = packRecs.isNotEmpty;

    final packMidBase = protocolOrder;
    final packMidSections = buildKitDetailRailSections(
      context: context,
      pluginId: widget.pluginId,
      rails: packOther,
      tvFocus: tvFocus,
      tvRowOrderBase: packMidBase,
      firstMetaFocusUp: !hasCast && !hasCrew && !hasBodyTrailers
          ? firstMetaFocusUp
          : null,
    );
    final recOrderBase = packMidBase + packMidSections.length;
    final packRecSections = hasPackRecs
        ? buildKitDetailRailSections(
            context: context,
            pluginId: widget.pluginId,
            rails: packRecs,
            tvFocus: tvFocus,
            tvRowOrderBase: recOrderBase,
            firstMetaFocusUp:
                !hasCast &&
                    !hasCrew &&
                    !hasBodyTrailers &&
                    packMidSections.isEmpty
                ? firstMetaFocusUp
                : null,
          )
        : const <Widget>[];
    final sections = [
      ?episodePicker,
      ?castSection,
      ?crewSection,
      ?trailersSection,
      ...packMidSections,
      ...packRecSections,
    ];

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final heroH = DetailsTokens.heroHeight(
      context,
      fullBleedBackdrop: _layout.fullBleedBackdrop,
      backdropFraction: _layout.backdropFraction,
    );
    final firstRowOverlap = DetailsTokens.bodyOverlapForFirstRow(
      viewportHeight: viewportHeight,
      heroHeight: heroH,
      firstBodyRowFraction: _layout.firstBodyRowFraction,
    );

    return MediaDetailsScrollPage(
      scrollController: _scrollController,
      tvHeroPlayFocus: _heroPlayFocus,
      bodyOverlap: firstRowOverlap,
      topSpacing: 0,
      backgroundColor: AppTheme.bgDark,
      hero: DetailsHero(
        backdropUrl: backdrop,
        backdropUrls: backdropUrls,
        title: show.name,
        // Pack franchise rail — which cour is open (Season 1 / OVA 1 / …).
        subtitle: _packSeasonSubtitle,
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
        height: heroH,
        bodyOverlap: firstRowOverlap,
        progressBar: heroPosMs != null && heroDurMs != null
            ? WatchProgressBar(positionMs: heroPosMs, durationMs: heroDurMs)
            : null,
        seriesProgress:
            !_isMovie &&
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
        // FittedBox scaleDown + overlay menus → full-size ghost SUB/DUB pill.
        // Keep intrinsic size on leanback only (desktop hybrid still scales).
        scaleActionRow: !policy.leanbackOnly,
        actionRow: DetailsHeroTvActionScope(
          tabId: MediaDetailsTv.tabId,
          itemCount: heroActionCount,
          onFocusUp: heroPopUp,
          child: Row(
            children: [
              if (blockPlay)
                KitDetailsUpcomingNotice(releaseDateLabel: noticeLabel)
              else
                KitDetailsPlayRow(
                  label: playLabel,
                  enabled: _isMovie || videos.isNotEmpty || show.open != null,
                  onPlay: _playSelected,
                  onOpenSources:
                      showCatalogSources &&
                          (_isMovie || videos.isNotEmpty || show.open != null)
                      ? _openCatalogSources
                      : null,
                  secondaryIcon: _offlineLibrary
                      ? Icons.folder_open_rounded
                      : Icons.link_rounded,
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
                      () => _playFilterSelections[playFilters[i].field] = value,
                    ),
                    tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                    tvItemIndexStart:
                        playFilterIndex! +
                        playFilters
                            .take(i)
                            .fold<int>(0, (n, f) => n + f.options.length),
                    onUpEdge: heroPopUp,
                  ),
                ],
              ],
              if (showLangFilter) ...[
                const SizedBox(width: 10),
                KitMultiselectPlayFilter(
                  options: _streamLanguageOptions,
                  selected: _streamLanguageKeys,
                  onChanged: (next) => unawaited(_setStreamLanguages(next)),
                  tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                  tvItemIndexStart: langFilterIndex,
                  onUpEdge: heroPopUp,
                ),
              ],
            ],
          ),
        ),
      ),
      sections: sections,
    );
  }
}
