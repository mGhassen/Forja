import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/utils/extensions.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/playback/playback_service.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/playback/tv_stream_fallback.dart';
import 'package:forja/shared/playback/provider_score_probe_sync.dart';
import 'package:forja/shared/playback/webstreaming_stream_cache.dart';
import 'package:forja/shared/playback/catalog_sources_session_cache.dart';
import 'package:forja/shared/playback/history_playback_resume.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/features/media/stremio_catalog_screen.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/widgets/movie_atmosphere.dart';
import 'package:forja/shared/widgets/media_details/media_details.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/media_details/media_details_torrent_action_row.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_tiles.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel_chrome.dart';
import 'package:forja/shared/widgets/media_details_hero.dart';
import 'package:forja/shared/widgets/media_details_cast_section.dart';
import 'package:forja/shared/widgets/media_details_trailers_section.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/features/media/details/widgets/details_collection_section.dart';

part 'details_screen_torrent.dart';
part 'details_screen_stremio.dart';
part 'details_screen_webstreaming.dart';
part 'details_screen_episodes.dart';
part 'details_screen_panel.dart';
part 'details_screen_play.dart';
part 'details_screen_build.dart';
part 'details_screen_fetch.dart';

class DetailsScreen extends StatefulWidget {
  final Movie movie;

  /// Optional: when opened from a Stremio addon search result with a custom ID,
  /// pass the original item so we can auto-select the right addon and use its ID.
  final Map<String, dynamic>? stremioItem;

  /// Optional: pre-select a season (e.g. from Continue Watching / Trakt import).
  final int? initialSeason;

  /// Optional: pre-select an episode (e.g. from Continue Watching / Trakt import).
  final int? initialEpisode;

  /// Optional: resume position from Trakt/Simkl import (used when no local progress matches).
  final Duration? startPosition;

  /// When true, auto-plays the best source after the initial fetch/search completes.
  final bool autoPlay;
  const DetailsScreen({
    super.key,
    required this.movie,
    this.stremioItem,
    this.initialSeason,
    this.initialEpisode,
    this.startPosition,
    this.autoPlay = false,
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen>
    with
        AtmosphereMixin,
        _DetailsScreenTorrent,
        _DetailsScreenStremio,
        _DetailsScreenWebstreaming,
        _DetailsScreenEpisodes,
        _DetailsScreenPlay,
        _DetailsScreenPanel,
        _DetailsScreenFetch,
        _DetailsScreenBuild {
  late Movie _movie;
  bool _isLoading = true;
  final TmdbApi _api = TmdbApi();
  final SettingsService _settings = SettingsService();
  final StremioService _stremio = StremioService();
  final JackettService _jackett = JackettService();
  final ProwlarrService _prowlarr = ProwlarrService();
  final LinkResolver _linkResolver = LinkResolver();
  final PlaybackProfile _playbackProfile = PlatformPlayback.capabilities;

  String _sortPreference = 'Seeders (High to Low)';
  Set<String> _activeAudioFilters = {};
  Set<String> _activeQualityFilters = {};
  Set<String> _activeLanguageFilters = {};
  Set<String> _activeTechFilters = {};
  Set<String> _activeSizeFilters = {};
  String _sourceSearchQuery = '';
  List<TorrentResult> _allTorrentResults = [];
  bool _isSearching = false;
  int _torrentSearchGen = 0;
  int _stremioFetchGen = 0;
  String? _errorMessage;
  Map<String, dynamic>? _lastProgress;
  bool _sourcesPanelOpen = false;
  bool _autoPlayConsumed = false;
  bool _episodePlayPending = false;
  bool _playSourceTorrent = true;
  bool _playSourceStremio = true;
  bool _playSourceWebstreaming = true;

  /// Panel list filter: `torrents` | `stremio` | `nuvio`.
  String _panelKindFilter = 'torrents';

  String _selectedSourceId = 'forja';
  List<Map<String, dynamic>> _streamAddons = [];
  List<dynamic> _stremioStreams = [];
  List<Map<String, dynamic>> _allCombinedStremioStreams = [];
  bool _isStremioFetching = false;

  /// Tracks which addon baseUrls have returned results (for dynamic chip display).
  final Set<String> _loadedAddonBaseUrls = {};

  // Nuvio addon results — kept independent from Stremio addons so the UI
  // can show them under their own tab.
  List<Map<String, dynamic>> _nuvioStreams = [];
  bool _isNuvioFetching = false;
  bool _hasNuvioAddons = false;
  Set<String> _nuvioFetchedScraperIds = {};
  int _nuvioFetchGen = 0;

  /// Cached list of installed Nuvio addons (refreshed when the Nuvio tab
  /// is opened). Used to render the scraper filter chips.
  List<NuvioAddon> _nuvioAddons = [];

  /// Enabled Nuvio scraper ids currently included in the results filter.
  /// All enabled scrapers start selected when opening the Nuvio tab.
  Set<String> _nuvioSelectedScraperIds = {};

  // Direct webstreaming providers (videasy, webstreamr, …) — no global mode toggle.
  final Map<String, dynamic> _webstreamingProviders = {
    ...StreamProviders.providers,
  };
  List<String> _webstreamingProviderOrder = [];
  List<StreamSource> _webstreamingStreams = [];
  String? _webstreamingActiveProviderId;
  bool _isWebstreamingOnlyExtracting = false;
  bool _webstreamingOnlyExtractionCancelled = false;
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  Map<String, dynamic>? _seasonData;
  bool _isLoadingSeason = false;

  // Episode watched tracking
  final EpisodeWatchedService _episodeWatchedService = EpisodeWatchedService();
  Set<String> _watchedEpisodes = {};

  // Collection state
  List<Map<String, dynamic>> _collectionItems = [];
  bool _isCollection = false;

  bool _isJackettConfigured = false;
  bool _isProwlarrConfigured = false;

  List<Movie> _similarMovies = [];
  List<Map<String, String>> _castMembers = [];
  List<MediaTrailer> _trailers = [];

  // Stream resolution cancellation
  bool _streamCancelled = false;

  void _dismissStreamLoadingDialog(BuildContext dialogContext) {
    _streamCancelled = true;
    Engine.cancelPendingResolve();
    Navigator.of(dialogContext).pop();
  }

  String? _trailerKey;
  String _originalLanguage = '';
  String _tagline = '';
  String _certification = '';
  String _status = '';
  String _lastAirDate = '';
  List<String> _networks = [];
  List<String> _creators = [];
  String _directorName = '';
  int _budget = 0;
  int _revenue = 0;
  List<String> _spokenLanguages = [];
  List<String> _productionCompanies = [];
  List<String> _originCountries = [];
  final Map<int, String> _seasonPosters = {};
  Map<String, Map<String, dynamic>> _episodeProgress = {};

  final ScrollController _episodeScrollController = ScrollController();
  final ScrollController _detailsScrollController = ScrollController();
  final FocusNode _detailsHeroPlayFocus = FocusNode(
    debugLabel: 'details-hero-play',
  );
  bool _detailsHeroInitialFocusDone = false;

  // MDBlist aggregated ratings
  Map<String, dynamic>? _mdblistRatings;
  final MediaDetailsTrackerState _trackerState = MediaDetailsTrackerState();
  MediaDetailsTrackerHandlers? _trackerHandlers;

  MediaDetailsTrackerHandlers get _trackerHandlersOrCreate {
    return _trackerHandlers ??= MediaDetailsTrackerHandlers(
      context: context,
      state: _trackerState,
      movie: () => _movie,
      season: () => _selectedSeason,
      episode: () => _selectedEpisode,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  // ─── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    if (widget.initialSeason != null) _selectedSeason = widget.initialSeason!;
    if (widget.initialEpisode != null)
      _selectedEpisode = widget.initialEpisode!;
    // Start atmosphere color extraction
    final url = (_movie.posterPath.isNotEmpty
        ? _movie.posterPath
        : _movie.backdropPath);
    loadAtmosphere(url.startsWith('http') ? url : TmdbApi.getImageUrl(url));
    _checkHistory();
    _loadSortPreference();
    _checkIndexerConfiguration();
    _loadWatchedEpisodes();
    _fetchDetails();
    _fetchExternalRatings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _trackerHandlersOrCreate.load();
    });
    _loadWebstreamingProviderOrder();
  }

  @override
  void dispose() {
    // Leave the title → stop every in-flight source check (Nuvio/Xpass,
    // Stremio, torrents, KissKh, embeds). Subscription cancel alone is not
    // enough — scrapers kept fetching after the route was gone.
    _cancelActiveSourceFetch();
    _torrentSearchGen++;
    _stremioFetchGen++;
    _nuvioFetchGen++;
    NuvioService.instance.cancelPending();
    Engine.cancelPendingResolve();
    DomainStreamProviderResolver.cancelAllPending();
    _detailsHeroPlayFocus.dispose();
    _detailsScrollController.dispose();
    _episodeScrollController.dispose();
    _jackett.dispose();
    _prowlarr.dispose();
    _linkResolver.dispose();
    super.dispose();
  }

  // ─── data methods ─────────────────────────────────────────────────────────

  Future<void> _checkHistory() async {
    final progress = await WatchHistoryService().getProgress(
      _movie.id,
      season: _movie.mediaType == 'tv' ? _selectedSeason : null,
      episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
    );
    if (mounted) setState(() => _lastProgress = progress);
  }

  void _applyPanelFilterForSavedMethod(String? method) {
    switch (method) {
      case 'torrent':
        if (_panelShowTorrent) _panelKindFilter = 'torrents';
      case 'stremio_direct':
        if (_panelShowStremio) {
          _panelKindFilter = 'stremio';
        } else if (_panelShowTorrent) {
          _panelKindFilter = 'torrents';
        }
      default:
        if (_panelShowTorrent) {
          _panelKindFilter = 'torrents';
        } else if (_panelShowNuvio) {
          _panelKindFilter = 'nuvio';
        } else if (_panelShowStremio) {
          _panelKindFilter = 'stremio';
        }
    }
  }

  bool _isDirectStreamingSavedMethod(String? method) {
    return method == 'stream' || method == 'amri' || method == 'stremio_direct';
  }

  Future<bool> _tryDirectEpisodeResumeFromHistory(
    Map<String, dynamic> progress,
  ) async {
    final method = progress['method'] as String?;
    final startPosition = resumeStartPositionFromProgress(progress);

    switch (method) {
      case 'stream':
        if (!_playSourceWebstreaming) return false;
        if (_webstreamingStreams.isNotEmpty) {
          await _playWebstreamingStream(
            _webstreamingStreams.first,
            startPosition: startPosition,
          );
          return mounted;
        }
        final sourceId = progress['sourceId'] as String? ?? '';
        if (isWebStreamProviderId(sourceId)) {
          final ok = await resumeSavedWebStreamProvider(
            context: context,
            movie: _movie,
            progress: progress,
            startPosition: startPosition,
          );
          if (ok) return true;
        }
        if (await _tryResumeWebStreamFromWatchHistory(startPosition)) {
          return true;
        }
        await _startWebstreamingOnlyPlayback();
        return mounted;
      case 'amri':
        if (!_playSourceWebstreaming) return false;
        final ok = await resumeSavedAmriStream(
          context: context,
          movie: _movie,
          progress: progress,
          startPosition: startPosition,
        );
        if (ok) return true;
        await _startWebstreamingOnlyPlayback();
        return mounted;
      case 'stremio_direct':
        if (!_playSourceStremio) return false;
        return resumeSavedStremioDirectStream(
          context: context,
          movie: _movie,
          progress: progress,
          startPosition: startPosition,
        );
      case 'torrent':
        // Torrent resumes open the sources panel — see [_openTorrentPanelForEpisode].
        return false;
      default:
        return false;
    }
  }

  bool get _panelShowTorrent =>
      _playSourceTorrent && _playbackProfile.builtinTorrentSearch;

  bool get _panelShowStremio => _playSourceStremio;

  bool get _panelShowNuvio => _playSourceTorrent && _hasNuvioAddons;

  bool get _hasPanelPlaySources =>
      _panelShowTorrent || _panelShowStremio || _panelShowNuvio;

  String _defaultPanelKindFilter() {
    if (_panelShowTorrent) return 'torrents';
    if (_panelShowNuvio) return 'nuvio';
    if (_panelShowStremio) return 'stremio';
    return 'torrents';
  }

  void _syncPanelKindFilterToPlaySources() {
    final allowed = <String>{
      if (_panelShowTorrent) 'torrents',
      if (_panelShowStremio) 'stremio',
      if (_panelShowNuvio) 'nuvio',
    };
    if (!allowed.contains(_panelKindFilter)) {
      _panelKindFilter = _defaultPanelKindFilter();
    }
  }

  bool _isCurrentSourceAllowed() {
    if (_isTorrentSource) return _panelShowTorrent;
    if (_isNuvioSource) return _panelShowNuvio;
    if (_isWebstreamingSource) return false;
    return _panelShowStremio;
  }

  String _defaultSourceId() {
    if (_panelShowTorrent) return 'forja';
    if (_panelShowStremio && _streamAddons.isNotEmpty) {
      return _streamAddons.first['baseUrl'] as String;
    }
    return 'forja';
  }

  String _defaultStremioSourceId() {
    if (_streamAddons.isEmpty) return 'forja';
    for (final a in _streamAddons) {
      final base = a['baseUrl'] as String?;
      if (base != null && _loadedAddonBaseUrls.contains(base)) return base;
    }
    return _streamAddons.first['baseUrl'] as String;
  }

  void _syncSelectedSourceToPlaySources() {
    _syncPanelKindFilterToPlaySources();
    if (_isCurrentSourceAllowed()) return;
    _selectedSourceId = _defaultSourceId();
    _resetPanelFilters();
    if (_isWebstreamingSource) {
      _webstreamingStreams = [];
      _webstreamingActiveProviderId = null;
      unawaited(_hydrateWebstreamingFromCache());
    }
  }

  /// Clears cached torrent / Stremio / Nuvio panel results so the next panel
  /// open re-fetches for the current title / season / episode.
  void _invalidatePanelSourceCache() {
    _torrentSearchGen++;
    _stremioFetchGen++;
    if (_isNuvioFetching) {
      _nuvioFetchGen++;
      NuvioService.instance.cancelPending();
    }
    _isSearching = false;
    _isStremioFetching = false;
    _isNuvioFetching = false;
    _allTorrentResults = [];
    _stremioStreams = [];
    _allCombinedStremioStreams = [];
    _loadedAddonBaseUrls.clear();
    _nuvioStreams = [];
    _nuvioFetchedScraperIds = {};
    // Keep the Nuvio Filters default (all enabled) when staying on that tab.
    _nuvioSelectedScraperIds = _panelKindFilter == 'nuvio'
        ? _allEnabledNuvioScraperIds()
        : {};
    _errorMessage = null;
  }

  Set<String> _allEnabledNuvioScraperIds() {
    final ids = <String>{};
    for (final a in _nuvioAddons) {
      for (final s in a.scrapers) {
        if (s.enabled) ids.add(s.id);
      }
    }
    return ids;
  }

  void _selectAllEnabledNuvioScrapers() {
    _nuvioSelectedScraperIds = _allEnabledNuvioScraperIds();
  }

  String get _catalogCacheKey => CatalogSourcesSessionCache.cacheKey(
    mediaId: _movie.id,
    mediaType: _movie.mediaType,
    season: _movie.mediaType == 'tv' ? _selectedSeason : null,
    episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
  );

  void _ensurePanelSourceLoaded({bool force = false}) {
    if (_panelShowTorrent && _panelKindFilter == 'torrents') {
      _ensureTorrentsPanelLoaded(force: force);
    }
    if (_panelShowStremio && _panelKindFilter == 'stremio') {
      _ensureStremioPanelLoaded(force: force);
    }
    if (_panelShowNuvio && _panelKindFilter == 'nuvio') {
      unawaited(_ensureNuvioPanelLoaded(force: force));
    }
  }

  void _ensureTorrentsPanelLoaded({bool force = false}) {
    if (force) {
      CatalogSourcesSessionCache.invalidate(_catalogCacheKey, kind: 'torrents');
      _autoSearch();
      return;
    }
    if (_allTorrentResults.isNotEmpty || _isSearching) return;
    final cached = CatalogSourcesSessionCache.readTorrents(_catalogCacheKey);
    if (cached != null) {
      setState(() {
        _allTorrentResults = cached;
        _errorMessage = null;
      });
      unawaited(_sortResults());
      return;
    }
    _autoSearch();
  }

  void _ensureStremioPanelLoaded({bool force = false}) {
    if (force) {
      CatalogSourcesSessionCache.invalidate(_catalogCacheKey, kind: 'stremio');
      _fetchAllStremioStreams();
      return;
    }
    if (_allCombinedStremioStreams.isNotEmpty || _isStremioFetching) return;
    final cached = CatalogSourcesSessionCache.readStremio(_catalogCacheKey);
    if (cached != null) {
      setState(() {
        _allCombinedStremioStreams = cached;
        _loadedAddonBaseUrls
          ..clear()
          ..addAll({
            for (final s in cached)
              if (s['_addonBaseUrl'] is String) s['_addonBaseUrl'] as String,
          });
        _errorMessage = null;
        _applyStremioFilter();
      });
      return;
    }
    _fetchAllStremioStreams();
  }

  /// Loads addon metadata, then fetches one selected scraper at a time.
  Future<void> _ensureNuvioPanelLoaded({bool force = false}) async {
    await _checkAndFetchNuvio();
    if (!mounted || !_panelShowNuvio) return;
    if (_panelKindFilter != 'nuvio') return;
    if (_nuvioSelectedScraperIds.isEmpty) {
      setState(_selectAllEnabledNuvioScrapers);
    }
    if (force) {
      CatalogSourcesSessionCache.invalidate(_catalogCacheKey, kind: 'nuvio');
      await _fetchNextNuvioScraper(reset: true);
      return;
    }
    if (_nuvioStreams.isNotEmpty || _isNuvioFetching) return;
    final cached = CatalogSourcesSessionCache.readNuvio(_catalogCacheKey);
    if (cached != null) {
      setState(() {
        _nuvioStreams = cached.streams;
        _nuvioFetchedScraperIds = cached.fetchedScraperIds;
        _errorMessage = null;
      });
      return;
    }
    await _fetchNextNuvioScraper(reset: true);
  }

  void _reloadPanelKind(String kind) {
    switch (kind) {
      case 'torrents':
        _ensureTorrentsPanelLoaded(force: true);
      case 'stremio':
        _ensureStremioPanelLoaded(force: true);
      case 'nuvio':
        unawaited(_ensureNuvioPanelLoaded(force: true));
    }
  }

  void _onPanelKindFilterChanged(String kind) {
    setState(() {
      _panelKindFilter = kind;
      _errorMessage = null;
      switch (kind) {
        case 'torrents':
          _selectedSourceId = 'forja';
        case 'stremio':
          _selectedSourceId = _defaultStremioSourceId();
          _applyStremioFilter();
        case 'nuvio':
          _selectedSourceId = 'all_nuvio';
          _selectAllEnabledNuvioScrapers();
        default:
          _selectedSourceId = 'forja';
      }
    });
    _ensurePanelSourceLoaded();
  }

  void _openSourcesPanel() {
    if (!_hasPanelPlaySources) return;
    setState(() {
      _syncSelectedSourceToPlaySources();
      _sourcesPanelOpen = true;
      // Filters auto-opens with Sources — ensure Nuvio providers start selected.
      if (_panelKindFilter == 'nuvio' && _nuvioSelectedScraperIds.isEmpty) {
        _selectAllEnabledNuvioScrapers();
      }
    });
    _ensurePanelSourceLoaded();
  }

  /// Close Sources and stop any in-flight Torrents / Stremio / Nuvio fetches.
  ///
  /// Pass [cancelEngineJobs]: false when closing to start playback so the
  /// magnet resolve is not aborted by [Engine.cancelPendingResolve].
  void _closeSourcesPanel({bool cancelEngineJobs = true}) {
    if (!_sourcesPanelOpen &&
        !_isSearching &&
        !_isStremioFetching &&
        !_isNuvioFetching) {
      return;
    }
    _cancelActiveSourceFetch(cancelEngineJobs: cancelEngineJobs);
    if (_sourcesPanelOpen && mounted) {
      setState(() => _sourcesPanelOpen = false);
    }
  }

  Future<void> _loadSortPreference() async {
    final pref = await _settings.getSortPreference();
    if (mounted) setState(() => _sortPreference = pref);
  }

  /// Fetches streams from ALL installed stream addons in parallel,
  /// updating the UI incrementally as each addon responds.

  // ─── safe field helpers ───────────────────────────────────────────────────

  List<Map<String, dynamic>> _filterStremioStreams(List<dynamic> streams) =>
      filterStremioStreamsForProfile(streams, _playbackProfile);

  // ─── play methods ─────────────────────────────────────────────────────────

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  //  SOURCE TOGGLE + CHIPS (sliding source panel)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Opens a collection item by navigating to its detail page
  Future<void> _openCollectionItem(String id) async {
    // Try TMDB lookup first for IMDB IDs
    if (id.startsWith('tt')) {
      try {
        final movie = await _api.findByImdbId(id, mediaType: 'movie');
        if (movie != null && mounted) {
          await AppRouter.openDetails(context, movie: movie);
          return;
        }
      } catch (e) {
        debugPrint('[CollectionItem] TMDB lookup failed: $e');
      }
    }

    // Fallback: create minimal Movie object
    if (mounted) {
      await AppRouter.openDetails(
        context,
        movie: Movie(
          id: id.hashCode,
          imdbId: id.startsWith('tt') ? id : null,
          title: id,
          posterPath: '',
          backdropPath: '',
          voteAverage: 0,
          releaseDate: '',
          overview: '',
          mediaType: 'movie',
        ),
      );
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  EXPANDABLE SYNOPSIS
// ═════════════════════════════════════════════════════════════════════════════;
