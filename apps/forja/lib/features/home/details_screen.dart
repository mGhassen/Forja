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
import 'package:forja/shared/playback/history_playback_resume.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'stremio_catalog_screen.dart';
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
import 'package:forja/features/home/widgets/details_collection_section.dart';

part 'details_screen_torrent.part.dart';
part 'details_screen_stremio.part.dart';

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
    with AtmosphereMixin, _DetailsScreenTorrent, _DetailsScreenStremio {
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

  /// Panel list filter: `all` | `torrents` | `stremio` | `nuvio`.
  String _panelKindFilter = 'all';

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
  StreamSubscription<NuvioScraperResult>? _nuvioSub;

  /// Cached list of installed Nuvio addons (refreshed when the Nuvio tab
  /// is opened). Used to render the addon-picker chips.
  List<NuvioAddon> _nuvioAddons = [];

  /// Manifest URL of the addon the user has drilled into. `null` means
  /// we're showing the addon-picker chips. Once non-null, scraper chips
  /// for that addon are rendered.
  String? _nuvioSelectedAddonUrl;

  /// Scraper id (`<scraperId>`) the user picked. Drives `_selectedSourceId`
  /// (`'nuvio:<scraperId>'`) and the active stream list.
  String? _nuvioSelectedScraperId;

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
  final ScrollController _chipsScrollController = ScrollController();
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
    _detailsHeroPlayFocus.dispose();
    _detailsScrollController.dispose();
    _episodeScrollController.dispose();
    _chipsScrollController.dispose();
    _jackett.dispose();
    _prowlarr.dispose();
    _linkResolver.dispose();
    _nuvioSub?.cancel();
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

  Future<void> _resolveInitialSeasonEpisode() async {
    if (widget.initialSeason != null) return;
    final history = await WatchHistoryService().getHistory();
    final entry = latestInProgressForShow(_movie.id, history);
    if (entry == null || !mounted) return;
    final season = entry['season'] as int?;
    final episode = entry['episode'] as int?;
    setState(() {
      if (season != null && season > 0) _selectedSeason = season;
      if (episode != null && episode > 0) _selectedEpisode = episode;
    });
  }

  Future<void> _loadEpisodeProgressForSeason(int season) async {
    List episodes = [];
    if (_seasonData != null) {
      if (_seasonData!['episodes'] != null) {
        episodes = _seasonData!['episodes'] as List;
      } else if (_seasonData!['episodesBySeason'] != null) {
        final bySeason = _seasonData!['episodesBySeason'] as Map;
        episodes = bySeason[season] as List? ?? [];
      }
    }
    final map = <String, Map<String, dynamic>>{};
    for (final ep in episodes) {
      final n = (ep['episode_number'] ?? ep['episode']) as int;
      final p = await WatchHistoryService().getProgress(
        _movie.id,
        season: season,
        episode: n,
      );
      if (p != null) map['S${season}_E$n'] = p;
    }
    if (mounted) setState(() => _episodeProgress = map);
  }

  void _refreshSourcesForEpisode() {
    if (!_isCurrentSourceAllowed()) {
      _syncSelectedSourceToPlaySources();
    }
    if (_selectedSourceId == 'forja') {
      _autoSearch();
    } else if (_selectedSourceId == 'jackett') {
      _searchJackett();
    } else if (_selectedSourceId == 'prowlarr') {
      _searchProwlarr();
    } else if (_selectedSourceId == 'all_stremio') {
      _fetchAllStremioStreams();
    } else if (_isNuvioSource) {
      _fetchAllNuvioStreams();
    } else {
      _fetchStremioStreams();
    }
  }

  void _highlightEpisode(int episode) {
    if (_selectedEpisode == episode) return;
    setState(() => _selectedEpisode = episode);
    _autoSearch();
  }

  void _applyPanelFilterForSavedMethod(String? method) {
    switch (method) {
      case 'torrent':
        if (_panelShowTorrent) {
          _panelKindFilter = _panelShowStremio ? 'torrents' : 'torrents';
        }
      case 'stremio_direct':
        if (_panelShowStremio) {
          _panelKindFilter = _panelShowTorrent ? 'stremio' : 'stremio';
        }
      default:
        break;
    }
  }

  bool _isDirectStreamingSavedMethod(String? method) {
    return method == 'stream' || method == 'amri' || method == 'stremio_direct';
  }

  Future<void> _resumeEpisodeWebStream(String providerId) async {
    final progress = _lastProgress;
    if (progress == null || !mounted) return;
    final startPosition = _startPositionForAutoPlay(fromRoute: false);
    var ok = await resumeSavedWebStreamProvider(
      context: context,
      movie: _movie,
      progress: progress,
      startPosition: startPosition,
    );
    if (ok || !mounted) return;
    if (await _tryResumeWebStreamFromWatchHistory(startPosition)) return;
    if (mounted) await _startWebstreamingOnlyPlayback();
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

  void _openTorrentPanelForEpisode({bool preselectHistory = false}) {
    setState(() {
      _sourcesPanelOpen = true;
      _episodePlayPending = false;
      if (preselectHistory) {
        _applyPanelFilterForSavedMethod('torrent');
      }
      if (_panelShowTorrent) _selectedSourceId = 'forja';
    });
    _refreshSourcesForEpisode();
  }

  Future<void> _onEpisodeSelected(int episode) async {
    setState(() {
      _selectedEpisode = episode;
      _webstreamingStreams = [];
      _webstreamingActiveProviderId = null;
      _syncSelectedSourceToPlaySources();
    });
    await _checkHistory();
    if (!mounted) return;

    final progress = _lastProgress;
    final savedPlayback = hasSavedEpisodePlayback(progress);
    final stale = savedPlayback && isStaleResume(progress);
    final savedMethod = progress?['method'] as String?;

    if (stale) {
      if (savedMethod == 'torrent' && _hasPanelPlaySources) {
        setState(() {
          _sourcesPanelOpen = true;
          _episodePlayPending = false;
          _applyPanelFilterForSavedMethod(savedMethod);
        });
        _refreshSourcesForEpisode();
      }
      return;
    }

    if (savedPlayback && progress != null) {
      if (savedMethod == 'torrent' &&
          _playSourceTorrent &&
          _hasPanelPlaySources) {
        _openTorrentPanelForEpisode(preselectHistory: true);
        return;
      }

      if (_isDirectStreamingSavedMethod(savedMethod)) {
        await _hydrateWebstreamingFromCache();
        if (!mounted) return;
        await _tryDirectEpisodeResumeFromHistory(progress);
        return;
      }
    }

    // Never played — webstreaming auto-play only; never auto-launch torrent.
    if (_playSourceWebstreaming) {
      unawaited(_startWebstreamingOnlyPlayback());
      return;
    }

    if (_hasPanelPlaySources) {
      _openTorrentPanelForEpisode();
    }
  }

  bool get _panelShowTorrent =>
      _playSourceTorrent && _playbackProfile.builtinTorrentSearch;

  bool get _panelShowStremio => _playSourceStremio;

  bool get _panelShowNuvio => _playSourceTorrent && _hasNuvioAddons;

  bool get _hasPanelPlaySources =>
      _panelShowTorrent || _panelShowStremio || _panelShowNuvio;

  String _defaultPanelKindFilter() {
    if (_panelShowTorrent && _panelShowStremio) return 'all';
    if (_panelShowTorrent) return 'torrents';
    if (_panelShowNuvio) return 'nuvio';
    if (_panelShowStremio) return 'stremio';
    return 'all';
  }

  void _syncPanelKindFilterToPlaySources() {
    final allowed = <String>{
      if (_panelShowTorrent && _panelShowStremio) 'all',
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
      return _streamAddons.length > 1
          ? 'all_stremio'
          : _streamAddons.first['baseUrl'] as String;
    }
    return 'forja';
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

  void _ensurePanelSourceLoaded() {
    if (_panelShowTorrent &&
        (_panelKindFilter == 'all' || _panelKindFilter == 'torrents')) {
      if (_allTorrentResults.isEmpty && !_isSearching) _autoSearch();
    }
    if (_panelShowStremio &&
        (_panelKindFilter == 'all' || _panelKindFilter == 'stremio')) {
      if (_allCombinedStremioStreams.isEmpty && !_isStremioFetching) {
        _fetchAllStremioStreams();
      }
    }
    if (_panelKindFilter == 'nuvio' && _panelShowNuvio) {
      _checkAndFetchNuvio();
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
          _selectedSourceId = _streamAddons.length > 1
              ? 'all_stremio'
              : (_streamAddons.isNotEmpty
                    ? _streamAddons.first['baseUrl'] as String
                    : 'all_stremio');
          _applyStremioFilter();
        case 'nuvio':
          _selectedSourceId = 'nuvio_picker';
          _nuvioSelectedAddonUrl = null;
          _nuvioSelectedScraperId = null;
          _nuvioStreams = [];
        case 'all':
          if (_panelShowTorrent) {
            _selectedSourceId = 'forja';
          } else if (_streamAddons.isNotEmpty) {
            _selectedSourceId = _streamAddons.length > 1
                ? 'all_stremio'
                : _streamAddons.first['baseUrl'] as String;
            _applyStremioFilter();
          }
      }
    });
    _ensurePanelSourceLoaded();
  }

  void _openSourcesPanel() {
    if (!_hasPanelPlaySources) return;
    setState(() {
      _syncSelectedSourceToPlaySources();
      _sourcesPanelOpen = true;
    });
    _ensurePanelSourceLoaded();
  }

  void _onPlayStreamingPressed() {
    unawaited(_playWebstreamingFromDetails());
  }

  Future<void> _playWebstreamingFromDetails() async {
    await _checkHistory();
    await _hydrateWebstreamingFromCache();
    if (!mounted) return;
    await _startWebstreamingOnlyPlayback();
  }

  String _webstreamingCacheKey() => WebstreamingStreamCache.cacheKeyFromProgress(
    tmdbId: _movie.id,
    mediaType: _movie.mediaType,
    season: _movie.mediaType == 'tv' ? _selectedSeason : null,
    episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
  );

  void _applyWebstreamingCacheHit(WebstreamingCacheHit hit) {
    _webstreamingStreams = hit.sources;
    _webstreamingActiveProviderId = hit.providerId;
  }

  Future<void> _hydrateWebstreamingFromCache() async {
    if (!_playSourceWebstreaming || _webstreamingStreams.isNotEmpty) return;
    final cached = await WebstreamingStreamCache.read(_webstreamingCacheKey());
    if (cached == null || cached.sources.isEmpty || !mounted) return;
    setState(() => _applyWebstreamingCacheHit(cached));
    debugPrint(
      '[DetailsScreen] hydrated webstreaming cache '
      '${cached.providerId} (${cached.sources.length})',
    );
  }

  Future<void> _persistWebstreamingCache({
    required String providerId,
    required List<StreamSource> sources,
  }) async {
    if (sources.isEmpty) return;
    await WebstreamingStreamCache.write(
      _webstreamingCacheKey(),
      WebstreamingCacheHit(providerId: providerId, sources: sources),
    );
  }

  Future<void> _rememberWebstreamingSelection(
    String sourceUrl,
    String sourceTitle,
    ValueNotifier<Map<String, List<StreamSource>>>? providerSourcesCache,
  ) async {
    if (sourceUrl.trim().isEmpty) return;
    final cache = providerSourcesCache?.value ?? const {};
    String? providerId;
    List<StreamSource>? providerSources;
    for (final entry in cache.entries) {
      final match = entry.value.any((s) => s.url == sourceUrl);
      if (!match) continue;
      providerId = entry.key;
      providerSources = entry.value;
      break;
    }
    providerId ??= _webstreamingActiveProviderId;
    providerSources ??= _webstreamingStreams;
    if (providerId == null || providerSources.isEmpty) return;
    final selected = providerSources.firstWhere(
      (s) => s.url == sourceUrl,
      orElse: () => StreamSource(
        url: sourceUrl,
        title: sourceTitle,
        type: sourceUrl.contains('.m3u8') ? 'hls' : 'video',
      ),
    );
    final reordered = [
      selected,
      for (final s in providerSources)
        if (s.url != sourceUrl) s,
    ];
    if (!mounted) return;
    setState(() {
      _webstreamingActiveProviderId = providerId;
      _webstreamingStreams = reordered;
    });
    await _persistWebstreamingCache(providerId: providerId, sources: reordered);
  }

  Future<void> _startWebstreamingOnlyPlayback() async {
    final startPosition = _startPositionForAutoPlay(fromRoute: false);
    if (_webstreamingStreams.isNotEmpty) {
      await _playWebstreamingStream(
        _webstreamingStreams.first,
        startPosition: startPosition,
      );
      return;
    }

    final cached = await WebstreamingStreamCache.read(_webstreamingCacheKey());
    if (cached != null && cached.sources.isNotEmpty) {
      if (!mounted) return;
      setState(() => _applyWebstreamingCacheHit(cached));
      debugPrint(
        '[DetailsScreen] webstreaming cache hit '
        '${cached.providerId} (${cached.sources.length})',
      );
      await _playWebstreamingStream(
        cached.sources.first,
        startPosition: startPosition,
      );
      return;
    }

    if (await _tryResumeWebStreamFromWatchHistory(startPosition)) return;

    if (_isWebstreamingOnlyExtracting) return;
    await _runWebstreamingOnlyExtraction(startPosition: startPosition);
  }

  /// Last-resume layer: reopen the saved URL + provider from watch history
  /// without re-racing extractors (survives cache drops after built-in fail).
  Future<bool> _tryResumeWebStreamFromWatchHistory(Duration? startPosition) async {
    final progress = _lastProgress;
    if (progress == null || progress['method'] != 'stream') return false;
    final savedUrl = progress['streamUrl'] as String?;
    final rawSourceId = progress['sourceId'] as String? ?? '';
    if (savedUrl == null ||
        savedUrl.trim().isEmpty ||
        isTorrentStreamUrl(savedUrl)) {
      return false;
    }
    final sourceId = isWebStreamProviderId(rawSourceId)
        ? rawSourceId
        : (_webstreamingActiveProviderId ?? 'stream');
    final source = StreamSource(
      url: savedUrl,
      title: _webstreamingProviderLabel(sourceId),
      type: savedUrl.contains('.m3u8')
          ? 'hls'
          : savedUrl.contains('.mpd')
          ? 'dash'
          : 'video',
    );
    if (!mounted) return false;
    setState(() {
      _webstreamingActiveProviderId = sourceId;
      _webstreamingStreams = [source];
    });
    await _persistWebstreamingCache(providerId: sourceId, sources: [source]);
    debugPrint(
      '[DetailsScreen] watch-history stream resume $sourceId '
      '(${startPosition?.inSeconds ?? 0}s)',
    );
    await _playWebstreamingStream(source, startPosition: startPosition);
    return true;
  }

  Future<void> _resumeContinueWatchingWebStream(
    String providerId, {
    required bool fromRoute,
  }) async {
    final progress = _lastProgress;
    if (progress == null) {
      if (fromRoute) {
        _failAutoPlayFromRoute();
      }
      return;
    }
    final ok = await resumeSavedWebStreamProvider(
      context: context,
      movie: _movie,
      progress: progress,
      startPosition: _startPositionForAutoPlay(fromRoute: fromRoute),
    );
    if (ok || !mounted) return;
    if (fromRoute) {
      _failAutoPlayFromRoute();
      return;
    }
    await _resumeEpisodeWebStream(providerId);
  }

  Future<void> _resumeContinueWatchingAmri({required bool fromRoute}) async {
    final progress = _lastProgress;
    if (progress == null) {
      if (fromRoute) _failAutoPlayFromRoute();
      return;
    }
    final ok = await resumeSavedAmriStream(
      context: context,
      movie: _movie,
      progress: progress,
      startPosition: _startPositionForAutoPlay(fromRoute: fromRoute),
    );
    if (ok || !mounted) return;
    if (fromRoute) {
      _failAutoPlayFromRoute();
      return;
    }
    if (_playSourceWebstreaming) await _startWebstreamingOnlyPlayback();
  }

  Future<void> _runWebstreamingOnlyExtraction({Duration? startPosition}) async {
    if (mounted) {
      setState(() => _isWebstreamingOnlyExtracting = true);
    } else {
      _isWebstreamingOnlyExtracting = true;
    }
    _webstreamingOnlyExtractionCancelled = false;
    final probeNotifier = ValueNotifier<List<StreamProviderProbe>>([]);
    final sourcesListNotifier = ValueNotifier<List<StreamSource>>(const []);
    final providerSourcesCache = ValueNotifier<Map<String, List<StreamSource>>>(
      {},
    );
    final fadeOutNotifier = ValueNotifier(false);
    var liveNotifiersDisposed = false;
    BuildContext? loadingDialogContext;

    void dismissLoading() {
      final ctx = loadingDialogContext;
      if (ctx != null && ctx.mounted) dismissLoadingOverlayRoute(ctx);
      loadingDialogContext = null;
    }

    showLoadingOverlayDialog(
      context,
      builder: (dialogContext) {
        loadingDialogContext = dialogContext;
        return LoadingOverlay(
          movie: _movie,
          providerProbesNotifier: probeNotifier,
          fadeOutNotifier: fadeOutNotifier,
          onCancel: () {
            _webstreamingOnlyExtractionCancelled = true;
            PlaybackEngine.cancelAllPending();
            dismissLoading();
          },
        );
      },
    );

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      dismissLoading();
      _isWebstreamingOnlyExtracting = false;
      fadeOutNotifier.dispose();
      liveNotifiersDisposed = true;
      probeNotifier.dispose();
      sourcesListNotifier.dispose();
      providerSourcesCache.dispose();
      return;
    }

    final providers = PlatformInfo.isAndroidTv
        ? TvStreamFallback.prioritizeProviders(_orderedWebstreamingProviders)
        : _orderedWebstreamingProviders;
    var found = false;

    try {
      final orderedKeys = SourceEngine.orderProviderIds(
        domain: SourceDomain.fromMediaType(_movie.mediaType),
        candidateIds: providers.keys,
        settingsOrder: _webstreamingProviderOrder,
      );
      if (orderedKeys.isNotEmpty) {
        final firstActiveIdx = orderedKeys.indexWhere(
          (k) => !TvStreamFallback.isSkippedOnTv(k, providers),
        );
        probeNotifier.value = [
          for (var i = 0; i < orderedKeys.length; i++)
            StreamProviderProbe(
              id: orderedKeys[i],
              label: _webstreamingProviderLabel(orderedKeys[i]),
              status: TvStreamFallback.isSkippedOnTv(orderedKeys[i], providers)
                  ? StreamProviderProbeStatus.skippedOnTv
                  : StreamProviderProbeStatus.pending,
              isPreferred: i == (firstActiveIdx >= 0 ? firstActiveIdx : 0),
            ),
        ];
      }

      StreamProviderProbeStatus probeStatusFromProgress(String status) {
        return switch (status) {
          'success' => StreamProviderProbeStatus.success,
          'failed' => StreamProviderProbeStatus.failed,
          'trying' => StreamProviderProbeStatus.trying,
          'skipped' => StreamProviderProbeStatus.skippedOnTv,
          _ => StreamProviderProbeStatus.pending,
        };
      }

      void syncResolvedHits(List<PlaybackResolveHit> hits) {
        if (hits.isEmpty || _webstreamingOnlyExtractionCancelled) return;
        providerSourcesCache.value = PlaybackEngine.hitsToProviderCache(hits);
        sourcesListNotifier.value = PlaybackEngine.mergeHitSources(hits);
        final best = hits.first;
        if (mounted) {
          setState(() {
            _webstreamingStreams = best.streamSources;
            _webstreamingActiveProviderId = best.providerId;
          });
        }
        final scope = ProviderScoreProbeSync.scopeFromPlayer(
          movie: _movie,
          providers: providers,
          selectedSeason: _selectedSeason,
          selectedEpisode: _selectedEpisode,
        );
        var probes = probeNotifier.value;
        for (final hit in hits) {
          final pid = hit.providerId;
          final idx = probes.indexWhere((p) => p.id == pid);
          if (idx >= 0) {
            probes = [
              for (final p in probes)
                if (p.id == pid)
                  p.copyWith(status: StreamProviderProbeStatus.success)
                else
                  p,
            ];
          }
        }
        probeNotifier.value = probes;
        unawaited(
          ProviderScoreProbeSync.syncSourcesCache(
            scope: scope,
            sourcesByProvider: providerSourcesCache.value,
          ),
        );
      }

      final hit = await PlaybackService.resolveWebstreaming(
        providers: providers,
        movie: _movie,
        season: _selectedSeason,
        episode: _selectedEpisode,
        settingsOrder: _webstreamingProviderOrder,
        isCancelled: () => _webstreamingOnlyExtractionCancelled,
        onHitsUpdated: syncResolvedHits,
        onProgress: (providerId, status) {
          if (!mounted) return;
          final nextStatus = probeStatusFromProgress(status);
          final existing = probeNotifier.value;
          final idx = existing.indexWhere((p) => p.id == providerId);
          if (idx < 0) {
            probeNotifier.value = [
              ...existing,
              StreamProviderProbe(
                id: providerId,
                label: _webstreamingProviderLabel(providerId),
                status: nextStatus,
                isPreferred: existing.isEmpty,
              ),
            ];
          final hasSources =
              (providerSourcesCache.value[providerId] ?? []).isNotEmpty;
          unawaited(
            ProviderScoreProbeSync.onProbeStatusChanged(
              scope: ProviderScoreProbeSync.scopeFromPlayer(
                movie: _movie,
                providers: providers,
                selectedSeason: _selectedSeason,
                selectedEpisode: _selectedEpisode,
              ),
              providerId: providerId,
              status: nextStatus,
              hasSources: hasSources,
            ),
          );
            return;
          }
          probeNotifier.value = existing
              .map(
                (probe) => probe.id == providerId
                    ? probe.copyWith(status: nextStatus)
                    : probe,
              )
              .toList();
          final hasSources =
              (providerSourcesCache.value[providerId] ?? []).isNotEmpty;
          unawaited(
            ProviderScoreProbeSync.onProbeStatusChanged(
              scope: ProviderScoreProbeSync.scopeFromPlayer(
                movie: _movie,
                providers: providers,
                selectedSeason: _selectedSeason,
                selectedEpisode: _selectedEpisode,
              ),
              providerId: providerId,
              status: nextStatus,
              hasSources: hasSources,
            ),
          );
        },
      );

      if (!mounted || _webstreamingOnlyExtractionCancelled) {
        // cancelled
      } else if (hit != null) {
        found = true;
        await Future<void>.delayed(const Duration(milliseconds: 250));

        final sources = hit.streamSources;
        final key = hit.providerId;
        final result = StreamProviderResolveResult(
          streamUrl: hit.streamUrl,
          audioUrl: hit.audioUrl,
          headers: hit.headers,
          sources: sources,
          subtitles: hit.subtitles,
        );

        if (!mounted) {
          // skip
        } else {
          setState(() {
            _webstreamingStreams = sources;
            _webstreamingActiveProviderId = key;
          });
          unawaited(
            _persistWebstreamingCache(providerId: key, sources: sources),
          );

          final isTv = _movie.mediaType == 'tv';
          final title = isTv
              ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode'
              : _movie.title;
          final ctx = loadingDialogContext;
          if (ctx != null && ctx.mounted) {
            final playerFuture = crossfadeLoadingOverlayToPlayer(
              loadingDialogContext: ctx,
              fadeOutNotifier: fadeOutNotifier,
              openPlayer: () => AppRouter.openPlayer(
                context,
                streamUrl: result.streamUrl,
                audioUrl: result.audioUrl,
                title: title,
                headers: result.headers,
                movie: _movie,
                providers: providers,
                activeProvider: key,
                selectedSeason: isTv ? _selectedSeason : null,
                selectedEpisode: isTv ? _selectedEpisode : null,
                startPosition: startPosition ?? widget.startPosition,
                sources: sources,
                externalSubtitles: result.subtitles,
                providerSourcesCache: providerSourcesCache,
                providerProbesNotifier: probeNotifier,
                pinSource: true,
                onSourcePinned: (sourceUrl, sourceTitle) =>
                    _rememberWebstreamingSelection(
                      sourceUrl,
                      sourceTitle,
                      providerSourcesCache,
                    ),
                fadeTransition: true,
              ),
            );
            await playerFuture;
            _webstreamingOnlyExtractionCancelled = true;
            PlaybackEngine.cancelAllPending();
            liveNotifiersDisposed = true;
            sourcesListNotifier.dispose();
            providerSourcesCache.dispose();
            probeNotifier.dispose();
          } else {
            await _playWebstreamingStream(
              sources.first,
              startPosition: startPosition,
            );
          }
        }
      }

      if (!found && mounted && !_webstreamingOnlyExtractionCancelled) {
        dismissLoading();
        ForjaToast.error('Failed to find a working stream.');
      }
    } finally {
      if (mounted) {
        setState(() => _isWebstreamingOnlyExtracting = false);
      } else {
        _isWebstreamingOnlyExtracting = false;
      }
      fadeOutNotifier.dispose();
      if (!liveNotifiersDisposed) {
        sourcesListNotifier.dispose();
        providerSourcesCache.dispose();
        probeNotifier.dispose();
      }
    }
  }

  void _onSeasonSelected(int season) {
    if (widget.stremioItem != null &&
        _seasonData != null &&
        _seasonData!['episodesBySeason'] != null) {
      setState(() {
        _selectedSeason = season;
        _selectedEpisode = 1;
        _webstreamingStreams = [];
        _webstreamingActiveProviderId = null;
      });
      _fetchStremioStreamsForCustomId(widget.stremioItem!);
      _checkHistory();
      _loadEpisodeProgressForSeason(season);
      return;
    }
    _fetchSeason(season);
  }

  Widget _buildDetailsHero({
    required double heroHeight,
    bool showEpisodeRail = false,
  }) {
    return MediaDetailsHero(
      movie: _movie,
      trailerYoutubeKey: _trailerKey,
      trailerLanguageCode: _originalLanguage,
      progress: _lastProgress,
      height: heroHeight,
      bodyOverlap: showEpisodeRail
          ? ShellTokens.detailsHeroBodyOverlapWithEpisodes
          : null,
      tagline: _tagline,
      certification: _certification,
      status: _status,
      imdbRating: _heroImdbRating,
      directorName: _directorName,
      budget: _budget,
      revenue: _revenue,
      languageCode: _originalLanguage,
      spokenLanguages: _spokenLanguages,
      productionCompanies: _productionCompanies,
      originCountries: _originCountries,
      lastAirDate: _lastAirDate,
      networks: _networks,
      creators: _creators,
      actionRow: _isCollection ? null : _buildHeroActionRow(),
    );
  }

  double? get _heroImdbRating {
    final r = _mdblistRatings;
    if (r == null) return null;
    final scores =
        r['scores'] as List<dynamic>? ?? r['ratings'] as List<dynamic>? ?? [];
    for (final s in scores) {
      final source = (s['source'] ?? '').toString().toLowerCase();
      if (source != 'imdb') continue;
      final value = s['value'] ?? s['score'];
      if (value is num && value > 0) return value.toDouble();
    }
    return null;
  }

  String _pickDirector(List<Map<String, String>> crew) {
    for (final c in crew) {
      final job = (c['job'] ?? '').toLowerCase();
      if (job.contains('director')) return c['name'] ?? '';
    }
    for (final c in crew) {
      final job = (c['job'] ?? '').toLowerCase();
      if (job.contains('creator')) return c['name'] ?? '';
    }
    return '';
  }

  Widget _buildHeroActionRow() {
    final hasResume =
        _lastProgress != null &&
        ((_lastProgress!['position'] as int? ?? 0) > 0);
    final showPlay = _hasPanelPlaySources;
    final policy = ShellScope.inputPolicyOf(context);
    if (policy.heroPlayAutoFocus &&
        !_detailsHeroInitialFocusDone &&
        !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _detailsHeroInitialFocusDone) return;
        if (_detailsHeroPlayFocus.canRequestFocus) {
          _detailsHeroPlayFocus.requestFocus();
          _detailsHeroInitialFocusDone = true;
        }
      });
    }
    return MediaDetailsTorrentActionRow(
      movie: _movie,
      hasResume: hasResume,
      showPlay: showPlay,
      showPlayStreaming: _playSourceWebstreaming,
      isStreamingExtracting: _isWebstreamingOnlyExtracting,
      onOpenSources: _openSourcesPanel,
      onClearProgress: hasResume ? _clearProgress : null,
      onPlayStreaming: _onPlayStreamingPressed,
      onDownload: _openSourcesPanel,
      onOverflowAction: _handleHeroOverflowAction,
      trailers: _trailers,
      trailerLanguageCode: _originalLanguage,
      userTraktRating: _trackerState.userTraktRating,
      userSimklRating: _trackerState.userSimklRating,
      isInTraktCollection: _trackerState.isInTraktCollection,
      playFocusNode: policy.heroPlayAutoFocus ? _detailsHeroPlayFocus : null,
      tvTabId: policy.useFocusableMoodChips ? MediaDetailsTv.tabId : null,
      tvFocusUp: policy.useFocusableMoodChips ? _popDetailsFromTvUp : null,
    );
  }

  void _popDetailsFromTvUp() {
    maybePopShellOverlay();
  }

  Future<void> _clearProgress() async {
    final progress = _lastProgress;
    if (progress == null) return;
    final uniqueId = progress['uniqueId'] as String?;
    if (uniqueId == null || uniqueId.isEmpty) return;
    await WatchHistoryService().removeItem(uniqueId);
    if (!mounted) return;
    setState(() {
      _lastProgress = null;
      if (_movie.mediaType == 'tv') {
        final season = progress['season'] as int? ?? _selectedSeason;
        final episode = progress['episode'] as int? ?? _selectedEpisode;
        _episodeProgress.remove('S${season}_E$episode');
      }
    });
  }

  Future<void> _handleHeroOverflowAction(String value) async {
    await _trackerHandlersOrCreate.handleOverflow(value);
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
      if (_detailsHeroPlayFocus.canRequestFocus) {
        _detailsHeroPlayFocus.requestFocus();
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

  int _detailsPickerRowCount() {
    var seasonCount = _movie.numberOfSeasons;
    if (_seasonData != null && _seasonData!['seasons'] != null) {
      seasonCount = (_seasonData!['seasons'] as List).length;
    }
    if (seasonCount <= 0) return 0;
    return seasonCount > 1 ? 2 : 1;
  }

  Widget _buildTvPicker({
    required int tvRowOrderBase,
    VoidCallback? tvFocusUp,
  }) {
    int seasonCount = _movie.numberOfSeasons;
    if (_seasonData != null && _seasonData!['seasons'] != null) {
      seasonCount = (_seasonData!['seasons'] as List).length;
    }
    Map<int, List<Map<String, dynamic>>>? customEpisodes;
    if (_seasonData != null && _seasonData!['episodesBySeason'] != null) {
      customEpisodes = Map<int, List<Map<String, dynamic>>>.from(
        (_seasonData!['episodesBySeason'] as Map).map(
          (k, v) =>
              MapEntry(k as int, List<Map<String, dynamic>>.from(v as List)),
        ),
      );
    }
    return TvSeasonEpisodePicker(
      tmdbId: _movie.id,
      seasonCount: seasonCount,
      selectedSeason: _selectedSeason,
      selectedEpisode: _selectedEpisode,
      isLoadingSeason: _isLoadingSeason,
      seasonData: _seasonData,
      watchedEpisodes: _watchedEpisodes,
      fallbackPosterPath: _movie.posterPath.isNotEmpty
          ? _movie.posterPath
          : _movie.backdropPath,
      seasonPosters: _seasonPosters,
      episodeProgress: _episodeProgress,
      customEpisodesBySeason: customEpisodes,
      onSeasonSelected: _onSeasonSelected,
      onEpisodeSelected: _onEpisodeSelected,
      onEpisodeFocused: _highlightEpisode,
      onToggleWatched: _toggleEpisodeWatched,
      tvTabId: MediaDetailsTv.tabId,
      tvSeasonRowId: 'seasons',
      tvEpisodeRowId: 'episodes',
      tvRowOrderBase: tvRowOrderBase,
      tvFocusUp: tvFocusUp,
    );
  }

  Future<void> _loadWatchedEpisodes() async {
    final set = await _episodeWatchedService.getWatchedSet(_movie.id);
    if (mounted) setState(() => _watchedEpisodes = set);
  }

  Future<void> _toggleEpisodeWatched(int season, int episode) async {
    await _episodeWatchedService.toggle(_movie.id, season, episode);
    await _loadWatchedEpisodes();
  }

  Future<void> _loadSortPreference() async {
    final pref = await _settings.getSortPreference();
    if (mounted) setState(() => _sortPreference = pref);
  }

  // ─── audio filter helpers ────────────────────────────────────────────────

  /// Torrent results after applying panel filters.
  List<TorrentResult> get _filteredTorrentResults => filterTorrentResults(
    _allTorrentResults,
    searchQuery: _sourceSearchQuery,
    qualityFilters: _activeQualityFilters,
    languageFilters: _activeLanguageFilters,
    techFilters: _activeTechFilters,
    audioFilters: _activeAudioFilters,
    sizeFilters: _activeSizeFilters,
  );

  bool get _panelShowsMerged =>
      _panelKindFilter == 'all' && _panelShowTorrent && _panelShowStremio;

  bool get _panelShowsTorrents =>
      _panelKindFilter == 'torrents' || _panelShowsMerged;

  bool get _panelShowsStremio =>
      _panelKindFilter == 'stremio' || _panelShowsMerged;

  bool get _panelShowsNuvio => _panelKindFilter == 'nuvio';

  List<Map<String, dynamic>> get _filteredPanelStremioStreams {
    final streams = _selectedSourceId == 'all_stremio' || _panelShowsMerged
        ? _allCombinedStremioStreams
        : _stremioStreams;
    return streams
        .whereType<Map<String, dynamic>>()
        .where((s) => _matchesPanelStreamFilters(s))
        .toList();
  }

  List<Map<String, dynamic>> get _filteredPanelNuvioStreams {
    final streams = _selectedSourceId == 'all_nuvio'
        ? _nuvioStreams
        : (_selectedSourceId.startsWith('nuvio:')
              ? _nuvioStreams
                    .where((s) => s['_addonBaseUrl'] == _selectedSourceId)
                    .toList()
              : <dynamic>[]);
    return streams
        .whereType<Map<String, dynamic>>()
        .where((s) => _matchesPanelStreamFilters(s))
        .toList();
  }

  List<String> get _panelFilterNames {
    final names = <String>[];
    if (_panelShowsTorrents) {
      names.addAll(_allTorrentResults.map((r) => r.name));
    }
    if (_panelShowsStremio) {
      final streams = _panelShowsMerged || _selectedSourceId == 'all_stremio'
          ? _allCombinedStremioStreams
          : _stremioStreams;
      names.addAll(
        streams.map(
          (s) => '${s['title'] ?? s['name'] ?? ''} ${s['description'] ?? ''}',
        ),
      );
    }
    if (_panelShowsNuvio) {
      final streams = _selectedSourceId == 'all_nuvio'
          ? _nuvioStreams
          : (_selectedSourceId.startsWith('nuvio:')
                ? _nuvioStreams
                      .where((s) => s['_addonBaseUrl'] == _selectedSourceId)
                      .toList()
                : <dynamic>[]);
      names.addAll(
        streams.map(
          (s) => '${s['title'] ?? s['name'] ?? ''} ${s['description'] ?? ''}',
        ),
      );
    }
    return names;
  }

  Set<String> get _panelAvailableQualities =>
      collectQualities(_panelFilterNames);

  Set<String> get _panelAvailableLanguages =>
      collectLanguages(_panelFilterNames);

  Set<String> get _panelAvailableTech => collectTechTags(_panelFilterNames);

  Set<String> get _panelAvailableSizeRanges {
    final sizes = <double>[];
    if (_panelShowsTorrents) {
      for (final r in _allTorrentResults) {
        final bytes = r.sizeInBytes > 0
            ? r.sizeInBytes
            : TorrentReleaseMetadata.parseSizeBytes(r.size);
        if (bytes > 0) sizes.add(bytes);
      }
    }
    if (_panelShowsStremio) {
      final streams = _panelShowsMerged || _selectedSourceId == 'all_stremio'
          ? _allCombinedStremioStreams
          : _stremioStreams;
      for (final s in streams.whereType<Map<String, dynamic>>()) {
        final bytes = _streamSizeBytes(s);
        if (bytes > 0) sizes.add(bytes);
      }
    }
    if (_panelShowsNuvio) {
      final streams = _selectedSourceId == 'all_nuvio'
          ? _nuvioStreams
          : (_selectedSourceId.startsWith('nuvio:')
                ? _nuvioStreams
                      .where((s) => s['_addonBaseUrl'] == _selectedSourceId)
                      .toList()
                : <dynamic>[]);
      for (final s in streams.whereType<Map<String, dynamic>>()) {
        final bytes = _streamSizeBytes(s);
        if (bytes > 0) sizes.add(bytes);
      }
    }
    return collectSizeRanges(sizes);
  }

  double _streamSizeBytes(Map<String, dynamic> s) {
    final label = TorrentReleaseMetadata.resolveStreamSizeLabel(s);
    if (label != null) {
      final bytes = TorrentReleaseMetadata.parseSizeBytes(label);
      if (bytes > 0) return bytes;
    }
    final hints = s['behaviorHints'];
    if (hints is Map) {
      final videoSize = hints['videoSize'] ?? hints['video_size'];
      if (videoSize is num && videoSize > 0) return videoSize.toDouble();
      final parsed = double.tryParse(videoSize?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    final blob =
        '${s['title'] ?? s['name'] ?? ''} ${s['description'] ?? ''} ${s['size'] ?? ''}';
    return TorrentReleaseMetadata.parseSizeBytes(blob);
  }

  bool _matchesPanelFilters(String name) =>
      TorrentReleaseMetadata.parse(name).matchesFiltersForName(
        name,
        searchQuery: _sourceSearchQuery,
        qualityFilters: _activeQualityFilters,
        languageFilters: _activeLanguageFilters,
        techFilters: _activeTechFilters,
        audioFilters: _activeAudioFilters,
      );

  bool _matchesPanelStreamFilters(Map<String, dynamic> s) {
    final name = '${s['title'] ?? s['name'] ?? ''} ${s['description'] ?? ''}';
    if (!_matchesPanelFilters(name)) return false;
    return TorrentReleaseMetadata.matchesSizeFilters(
      _streamSizeBytes(s),
      _activeSizeFilters,
    );
  }


  Duration? _startPositionForAutoPlay({required bool fromRoute}) {
    if (fromRoute) return widget.startPosition;
    final progress = _lastProgress;
    if (progress == null) return null;
    final pos = resumeStartPositionFromProgress(progress);
    return pos > Duration.zero ? pos : null;
  }

  void _failEpisodePlayPending() {
    if (!_episodePlayPending || !mounted) return;
    _episodePlayPending = false;
    if (!_hasPanelPlaySources && _playSourceWebstreaming) {
      unawaited(_startWebstreamingOnlyPlayback());
      return;
    }
    _openSourcesPanel();
  }

  void _failAutoPlayFromRoute() {
    if (!mounted) return;
    if (!_hasPanelPlaySources && _playSourceWebstreaming) {
      unawaited(_startWebstreamingOnlyPlayback());
      return;
    }
    _openSourcesPanel();
  }

  List<dynamic> _streamsForAutoPlay() {
    if (_isNuvioSource || _selectedSourceId == 'all_nuvio')
      return _nuvioStreams;
    if (_selectedSourceId == 'all_stremio' || _isTorrentSource) {
      return _allCombinedStremioStreams;
    }
    return _stremioStreams;
  }

  void _consumeAutoPlayFlags({
    required bool fromRoute,
    required bool fromEpisode,
  }) {
    if (fromRoute) _autoPlayConsumed = true;
    if (fromEpisode) _episodePlayPending = false;
  }

  void _maybeAutoPlay() {
    final fromRoute = widget.autoPlay && !_autoPlayConsumed;
    final fromEpisode = _episodePlayPending;
    if (!fromRoute && !fromEpisode) return;
    if (!mounted || _isLoading) return;

    final progress = _lastProgress;
    final isContinueWatchingResume =
        fromRoute && widget.startPosition != null && progress != null;
    final episodeSavedPlayback =
        fromEpisode && hasSavedEpisodePlayback(progress);
    final savedMethod = isContinueWatchingResume || episodeSavedPlayback
        ? (progress?['method'] as String?)
        : null;

    // Home hero Play → webstreaming. Continue Watching keeps the saved method.
    if (fromRoute && _playSourceWebstreaming && !isContinueWatchingResume) {
      _consumeAutoPlayFlags(fromRoute: true, fromEpisode: fromEpisode);
      unawaited(_startWebstreamingOnlyPlayback());
      return;
    }

    if (savedMethod == 'stream') {
      final sourceId = progress?['sourceId'] as String? ?? '';
      if (_playSourceWebstreaming) {
        if (_isWebstreamingOnlyExtracting) return;
        _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
        unawaited(
          _resumeContinueWatchingWebStream(sourceId, fromRoute: fromRoute),
        );
        return;
      }
    }

    if (savedMethod == 'amri' && _playSourceWebstreaming) {
      _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
      unawaited(_resumeContinueWatchingAmri(fromRoute: fromRoute));
      return;
    }

    if (savedMethod == 'stremio_direct' && _playSourceStremio) {
      if (_isStremioFetching || _isNuvioFetching) return;
      unawaited(() async {
        if (progress == null || !mounted) return;
        final ok = await resumeSavedStremioDirectStream(
          context: context,
          movie: _movie,
          progress: progress,
          startPosition: resumeStartPositionFromProgress(progress),
        );
        if (!mounted) return;
        if (ok) {
          _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
          return;
        }
        if (fromEpisode) {
          setState(() => _episodePlayPending = false);
          _openSourcesPanel();
        } else {
          _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: false);
          _failAutoPlayFromRoute();
        }
      }());
      return;
    }

    final startPosition = _startPositionForAutoPlay(fromRoute: fromRoute);

    // Episode picks never auto-launch torrent/stremio from search results.
    if (fromEpisode) {
      _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: true);
      return;
    }

    // Route auto-play must never fall through to torrent when saved method is
    // direct streaming.
    if (hasSavedEpisodePlayback(progress) &&
        _isDirectStreamingSavedMethod(savedMethod)) {
      return;
    }

    if (_playSourceTorrent && _playbackProfile.builtinTorrentSearch) {
      if (_isSearching) return;
      if (_allTorrentResults.isNotEmpty) {
        _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
        final toPlay = savedMethod == 'torrent'
            ? (_historyMatchedTorrent() ?? _allTorrentResults.first)
            : _allTorrentResults.first;
        _playTorrent(toPlay, startPosition: startPosition);
        return;
      }
      if (savedMethod == 'torrent' &&
          progress != null &&
          (progress['magnetLink'] as String?)?.isNotEmpty == true) {
        _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
        unawaited(() async {
          final ok = await resumeSavedTorrentStream(
            context: context,
            movie: _movie,
            progress: progress,
            startPosition: resumeStartPositionFromProgress(progress),
          );
          if (!ok && mounted) _openSourcesPanel();
        }());
        return;
      }
    }

    if (_playSourceStremio) {
      if (_isStremioFetching || _isNuvioFetching) return;
      final streams = _streamsForAutoPlay();
      if (streams.isNotEmpty) {
        final stream = streams.first;
        if (stream is Map<String, dynamic>) {
          _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
          _playStremioStream(stream, startPosition: startPosition);
          return;
        }
      }
    }

    final torrentPending =
        _playSourceTorrent &&
        _playbackProfile.builtinTorrentSearch &&
        _isSearching;
    final stremioPending = _playSourceStremio && _isStremioFetching;
    final nuvioPending = _panelShowNuvio && _isNuvioFetching;
    if (torrentPending || stremioPending || nuvioPending) return;

    if (fromEpisode) {
      _failEpisodePlayPending();
    } else if (fromRoute) {
      _consumeAutoPlayFlags(fromRoute: true, fromEpisode: false);
      _failAutoPlayFromRoute();
    }
  }

  Future<void> _fetchDetails() async {
    final stremioItem = widget.stremioItem;
    _playSourceTorrent = await _settings.isPlaySourceTorrentEnabled();
    _playSourceStremio = await _settings.isPlaySourceStremioEnabled();
    _playSourceWebstreaming = await _settings.isPlaySourceWebstreamingEnabled();
    _syncPanelKindFilterToPlaySources();
    if (!mounted) return;

    final bool isCustomId =
        stremioItem != null &&
        !(stremioItem['id']?.toString().startsWith('tt') ?? true);

    try {
      final streamAddons = await _stremio.getAddonsForResource('stream');

      // If this is a custom-ID Stremio item, skip TMDB fetch — we already
      // have all the info we need from the search result.
      if (isCustomId) {
        debugPrint('[DetailsScreen] Custom ID detected: ${stremioItem['id']}');
        debugPrint(
          '[DetailsScreen] stremioItem keys: ${stremioItem.keys.toList()}',
        );
        debugPrint(
          '[DetailsScreen] _addonBaseUrl: ${stremioItem['_addonBaseUrl']}',
        );
        debugPrint('[DetailsScreen] _addonName: ${stremioItem['_addonName']}');
        debugPrint('[DetailsScreen] type: ${stremioItem['type']}');

        // Update movie mediaType if it's a collection
        if (stremioItem['type'] == 'collections') {
          _movie = Movie(
            id: _movie.id,
            imdbId: _movie.imdbId,
            title: _movie.title,
            posterPath: _movie.posterPath,
            backdropPath: _movie.backdropPath,
            voteAverage: _movie.voteAverage,
            releaseDate: _movie.releaseDate,
            overview: _movie.overview,
            mediaType: 'collections',
            genres: _movie.genres,
            runtime: _movie.runtime,
            numberOfSeasons: _movie.numberOfSeasons,
            logoPath: _movie.logoPath,
            screenshots: _movie.screenshots,
          );
        }

        if (mounted) {
          setState(() {
            _streamAddons = streamAddons;
            _isLoading = false;
            // Auto-select the addon that owns this item
            final addonBaseUrl = stremioItem['_addonBaseUrl']?.toString() ?? '';
            if (addonBaseUrl.isNotEmpty) {
              _selectedSourceId = addonBaseUrl;
            } else if (streamAddons.isNotEmpty) {
              _selectedSourceId = streamAddons.first['baseUrl'];
            }
          });
          _fetchStremioStreamsForCustomId(stremioItem);
        }
        return;
      }

      final RichMediaDetails rich;
      if (_movie.mediaType == 'tv') {
        rich = await _api.getRichTvDetails(widget.movie.id);
        if (widget.initialSeason == null) {
          await _resolveInitialSeasonEpisode();
        }
        if (mounted) {
          setState(() => _seasonPosters.addAll(rich.extras.seasonPosters));
        }
        await _fetchSeason(_selectedSeason);
      } else {
        rich = await _api.getRichMovieDetails(widget.movie.id);
      }
      final similar = rich.movie.mediaType == 'tv'
          ? await _api.getTvRecommendations(rich.movie.id)
          : await _api.getMovieRecommendations(rich.movie.id);
      if (mounted) {
        setState(() {
          _movie = rich.movie;
          _trailerKey = rich.extras.trailerYoutubeKey;
          _originalLanguage = rich.extras.originalLanguage;
          _tagline = rich.extras.tagline;
          _certification = rich.extras.certification;
          _status = rich.extras.status;
          _lastAirDate = rich.extras.lastAirDate;
          _networks = rich.extras.networks;
          _creators = rich.extras.creators;
          _directorName = _pickDirector(rich.extras.crew);
          _budget = rich.extras.budget;
          _revenue = rich.extras.revenue;
          _spokenLanguages = rich.extras.spokenLanguages;
          _productionCompanies = rich.extras.productionCompanies;
          _originCountries = rich.extras.originCountries;
          _castMembers = rich.extras.cast;
          _trailers = rich.extras.trailers;
          _streamAddons = streamAddons;
          _similarMovies = similar;
          _isLoading = false;
          if (!_playbackProfile.builtinTorrentSearch &&
              streamAddons.isNotEmpty) {
            _selectedSourceId = streamAddons.length > 1
                ? 'all_stremio'
                : streamAddons.first['baseUrl'] as String;
          }
          _syncSelectedSourceToPlaySources();
        });
        await _hydrateWebstreamingFromCache();
        _maybeAutoPlay();
        if (_playSourceTorrent && _playbackProfile.builtinTorrentSearch) {
          _autoSearch();
          _checkAndFetchNuvio();
        }
        if (_playSourceStremio) {
          _fetchAllStremioStreams();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Probes Nuvio addons (installed + bundled virtual) for the Sources panel.
  /// Does NOT kick off scraping — that happens when the user picks a scraper.

  Future<void> _loadWebstreamingProviderOrder() async {
    final order = await _settings.getStreamProviderOrder();
    if (!mounted) return;
    setState(() => _webstreamingProviderOrder = order);
  }

  Map<String, dynamic> get _orderedWebstreamingProviders {
    final order = _webstreamingProviderOrder;
    final raw = <String, dynamic>{
      for (final k in order)
        if (_webstreamingProviders.containsKey(k)) k: _webstreamingProviders[k],
      for (final k in _webstreamingProviders.keys)
        if (!order.contains(k)) k: _webstreamingProviders[k],
    };
    return SourceEngine.orderProvidersMap(
      domain: SourceDomain.fromMediaType(_movie.mediaType),
      providers: raw,
      settingsOrder: order,
    );
  }

  String _webstreamingProviderLabel(String key) {
    final provider = _webstreamingProviders[key];
    final fallbackName = provider is Map ? provider['name']?.toString() : null;
    List<String>? contentLanguage;
    if (provider is Map && provider['contentLanguage'] is List) {
      contentLanguage = (provider['contentLanguage'] as List)
          .map((e) => e.toString())
          .toList();
    }
    return StreamProviderDisplay.playerLabel(
      key,
      fallbackName: fallbackName,
      contentLanguage: contentLanguage,
    );
  }

  Future<void> _playWebstreamingStream(
    StreamSource source, {
    Duration? startPosition,
  }) async {
    final isTv = _movie.mediaType == 'tv';
    final title = isTv
        ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode'
        : _movie.title;
    final providerId = _webstreamingActiveProviderId ?? 'videasy';
    final resolvedSources = _webstreamingStreams.isNotEmpty
        ? _webstreamingStreams
        : <StreamSource>[source];
    final providerSourcesCache = ValueNotifier<Map<String, List<StreamSource>>>(
      {providerId: resolvedSources},
    );
    await _persistWebstreamingCache(
      providerId: providerId,
      sources: resolvedSources,
    );
    if (mounted && _sourcesPanelOpen) setState(() => _sourcesPanelOpen = false);
    try {
      await AppRouter.openPlayer(
        context,
        streamUrl: source.url,
        title: title,
        headers: source.headers,
        movie: _movie,
        providers: _orderedWebstreamingProviders,
        activeProvider: providerId,
        selectedSeason: isTv ? _selectedSeason : null,
        selectedEpisode: isTv ? _selectedEpisode : null,
        startPosition: startPosition ?? widget.startPosition,
        sources: resolvedSources,
        providerSourcesCache: providerSourcesCache,
        pinSource: true,
        onSourcePinned: (sourceUrl, sourceTitle) =>
            _rememberWebstreamingSelection(
              sourceUrl,
              sourceTitle,
              providerSourcesCache,
            ),
        fadeTransition: true,
      );
    } finally {
      providerSourcesCache.dispose();
    }
  }

  Future<void> _fetchExternalRatings() async {
    try {
      if (!await MdblistService().isConfigured()) return;
      Map<String, dynamic>? ratings;
      if (_movie.imdbId != null && _movie.imdbId!.isNotEmpty) {
        ratings = await MdblistService().getRatingsByImdb(_movie.imdbId!);
      } else {
        ratings = await MdblistService().getRatingsByTmdb(
          _movie.id,
          _movie.mediaType == 'tv' ? 'show' : 'movie',
        );
      }
      if (mounted && ratings != null) setState(() => _mdblistRatings = ratings);
    } catch (_) {}
  }

  Future<void> _openRecommendation(Map<String, dynamic> rec) async {
    final id = rec['id']?.toString() ?? '';
    final type = rec['type']?.toString() ?? 'movie';

    // Try TMDB lookup first for IMDB IDs
    if (id.startsWith('tt')) {
      try {
        final movie = await _api.findByImdbId(
          id,
          mediaType: type == 'series' ? 'tv' : 'movie',
        );
        if (movie != null && mounted) {
          await AppRouter.openDetails(context, movie: movie);
          return;
        }
      } catch (_) {}
    }

    // Fallback: search TMDB by name
    final name = rec['name']?.toString() ?? '';
    if (name.isNotEmpty) {
      try {
        final results = await _api.searchMulti(name);
        if (results.isNotEmpty && mounted) {
          final match = results.firstWhere(
            (m) => m.title.toLowerCase() == name.toLowerCase(),
            orElse: () => results.first,
          );
          await AppRouter.openDetails(context, movie: match);
          return;
        }
      } catch (_) {}
    }

    // Last fallback: minimal Movie
    if (mounted) {
      await AppRouter.openDetails(
        context,
        movie: Movie(
          id: id.hashCode,
          imdbId: id.startsWith('tt') ? id : null,
          title: name.isNotEmpty ? name : id,
          posterPath: '',
          backdropPath: '',
          voteAverage: 0,
          releaseDate: '',
          overview: '',
          mediaType: type == 'series' ? 'tv' : 'movie',
        ),
      );
    }
  }

  Future<void> _fetchSeason(int seasonNumber) async {
    setState(() => _isLoadingSeason = true);
    try {
      final data = await _api.getTvSeasonDetails(_movie.id, seasonNumber);
      if (mounted) {
        final poster = data['poster_path'] as String?;
        setState(() {
          _seasonData = data;
          _isLoadingSeason = false;
          _selectedSeason = seasonNumber;
          _webstreamingStreams = [];
          _webstreamingActiveProviderId = null;
          if (poster != null && poster.isNotEmpty) {
            _seasonPosters[seasonNumber] = poster;
          }
          // Only reset to episode 1 if no initial episode was provided,
          // or if we're navigating to a different season after init.
          if (widget.initialEpisode != null &&
              seasonNumber == widget.initialSeason) {
            _selectedEpisode = widget.initialEpisode!;
          } else {
            _selectedEpisode = 1;
          }
        });
        await _hydrateWebstreamingFromCache();
        await _loadEpisodeProgressForSeason(seasonNumber);
        _checkHistory();
        if (_selectedSourceId == 'forja') {
          _autoSearch();
        } else if (_selectedSourceId == 'jackett') {
          _searchJackett();
        } else if (_selectedSourceId == 'prowlarr') {
          _searchProwlarr();
        } else if (_selectedSourceId == 'all_stremio') {
          _fetchAllStremioStreams();
        } else if (_isNuvioSource) {
          _fetchAllNuvioStreams();
        } else {
          _fetchStremioStreams();
        }
        _loadWatchedEpisodes();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSeason = false);
    }
  }

  void _autoSearch() {
    _checkHistory();
    final year = _movie.releaseDate.take(4);
    if (_movie.mediaType == 'tv') {
      final s = _selectedSeason.toString().padLeft(2, '0');
      final e = _selectedEpisode.toString().padLeft(2, '0');
      _searchTvTorrents('${_movie.title} S$s', '${_movie.title} S${s}E$e');
    } else {
      _searchTorrents('${_movie.title} $year');
    }
  }

  /// Fetches streams from ALL installed stream addons in parallel,
  /// updating the UI incrementally as each addon responds.


  // ─── safe field helpers ───────────────────────────────────────────────────

  List<Map<String, dynamic>> _filterStremioStreams(List<dynamic> streams) =>
      filterStremioStreamsForProfile(streams, _playbackProfile);

  // ─── play methods ─────────────────────────────────────────────────────────

  void _playStremioStream(
    Map<String, dynamic> stream, {
    Duration? startPosition,
  }) async {
    if (mounted && _sourcesPanelOpen) setState(() => _sourcesPanelOpen = false);
    final stremioId = widget.stremioItem?['id']?.toString() ?? _movie.imdbId;
    final stremioAddonBaseUrl =
        stream['_addonBaseUrl']?.toString() ?? _selectedSourceId;
    final isTv = _movie.mediaType == 'tv';

    final useDebrid = await _settings.useDebridForStreams();
    final debridService = await _settings.getDebridService();
    final precheck = classifyStremioStream(
      stream,
      _playbackProfile,
      useDebrid: useDebrid,
      debridService: debridService,
    );

    if (precheck is StremioExternalLink) {
      await _handleExternalUrl(
        precheck.externalUrl,
        addonBaseUrl: stremioAddonBaseUrl,
      );
      return;
    }

    if (precheck is StremioResolveFailure) {
      if (mounted) {
        ForjaToast.info(precheck.message);
      }
      return;
    }

    if (precheck is StremioPlayable) {
      if (!mounted) return;
      await AppRouter.openPlayer(
        context,
        streamUrl: precheck.streamUrl,
        title: _movie.title,
        headers: precheck.headers,
        movie: _movie,
        selectedSeason: isTv ? _selectedSeason : null,
        selectedEpisode: isTv ? _selectedEpisode : null,
        startPosition: startPosition,
        activeProvider: 'stremio_direct',
        stremioId: stremioId,
        stremioAddonBaseUrl: stremioAddonBaseUrl,
      );
      return;
    }

    if (!mounted) return;
    _streamCancelled = false;
    final fadeOutNotifier = ValueNotifier(false);
    BuildContext? loadingDialogContext;
    final loadingMessage = stremioResolveLoadingMessage(
      profile: _playbackProfile,
      useDebrid: useDebrid,
      debridService: debridService,
    );
    showLoadingOverlayDialog(
      context,
      builder: (dialogContext) {
        loadingDialogContext = dialogContext;
        return LoadingOverlay(
          movie: _movie,
          message: loadingMessage,
          fadeOutNotifier: fadeOutNotifier,
          subtitle: playbackSourceHint(
            useDebrid: useDebrid,
            debridService: debridService,
          ),
          onCancel: () => _dismissStreamLoadingDialog(dialogContext),
        );
      },
    );

    final resolved = await resolveStremioStream(
      stream: stream,
      profile: _playbackProfile,
      settings: _settings,
      season: isTv ? _selectedSeason : null,
      episode: isTv ? _selectedEpisode : null,
      isCancelled: () => _streamCancelled,
    );

    if (_streamCancelled) {
      fadeOutNotifier.dispose();
      return;
    }

    if (resolved is StremioPlayable && mounted) {
      final dialogContext = loadingDialogContext;
      if (dialogContext != null) {
        await crossfadeLoadingOverlayToPlayer(
          loadingDialogContext: dialogContext,
          fadeOutNotifier: fadeOutNotifier,
          openPlayer: () => AppRouter.openPlayer(
            context,
            streamUrl: resolved.streamUrl,
            title: _movie.title,
            magnetLink: resolved.magnetLink,
            movie: _movie,
            selectedSeason: isTv ? _selectedSeason : null,
            selectedEpisode: isTv ? _selectedEpisode : null,
            fileIndex: resolved.fileIndex,
            startPosition: startPosition,
            activeProvider: 'stremio_direct',
            stremioId: stremioId,
            stremioAddonBaseUrl: stremioAddonBaseUrl,
            fadeTransition: true,
          ),
        );
      }
    } else if (loadingDialogContext != null &&
        loadingDialogContext!.mounted &&
        Navigator.of(loadingDialogContext!).canPop()) {
      Navigator.of(loadingDialogContext!).pop();
    }
    fadeOutNotifier.dispose();

    if (resolved is StremioResolveFailure &&
        resolved.error != StremioPlaybackError.cancelled &&
        mounted) {
      ForjaToast.info(resolved.message);
    }
  }

  /// Handles a Stremio externalUrl: stremio:///detail, stremio:///search, or web URLs.
  Future<void> _handleExternalUrl(String url, {String? addonBaseUrl}) async {
    // Try parsing as a stremio:// link
    final parsed = StremioService.parseMetaLink(url);
    if (parsed != null) {
      switch (parsed['action']) {
        case 'detail':
          var id = parsed['id']?.toString() ?? '';
          final type = parsed['type']?.toString() ?? 'movie';
          // Extract IMDB ID from prefixed IDs like "mlt-rec-tt14905854"
          if (!id.startsWith('tt')) {
            final imdbMatch = RegExp(r'(tt\d+)').firstMatch(id);
            if (imdbMatch != null) {
              id = imdbMatch.group(1)!;
            }
          }
          await _openRecommendation({'id': id, 'type': type, 'name': ''});
          return;

        case 'search':
          final query = parsed['query']?.toString() ?? '';
          if (query.isNotEmpty && mounted) {
            // Pop back to MainScreen, then fire the search notifier
            Navigator.popUntil(context, (route) => route.isFirst);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ShellBus.openStremioSearch(
                query: query,
                addonBaseUrl: addonBaseUrl ?? '',
              );
            });
          }
          return;

        case 'discover':
          // Open the catalog screen for this discover link
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StremioCatalogScreen()),
            );
          }
          return;
      }
    }

    // Regular https:// URL → open in external browser
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (mounted) {
      ForjaToast.error('Unable to handle this link');
    }
  }

  void _playTorrent(TorrentResult result, {Duration? startPosition}) async {
    if (mounted && _sourcesPanelOpen) setState(() => _sourcesPanelOpen = false);
    final useDebrid = await _settings.useDebridForStreams();
    final debridService = await _settings.getDebridService();
    if (!mounted) return;

    _streamCancelled = false;
    final overlayMessage = ValueNotifier<String>(
      playbackResolveLabel(useDebrid: useDebrid, debridService: debridService),
    );
    final fadeOutNotifier = ValueNotifier(false);
    BuildContext? loadingDialogContext;
    final sourceHint = playbackSourceHint(
      useDebrid: useDebrid,
      debridService: debridService,
    );

    void showLoading({
      String? message,
      ValueNotifier<String>? messageNotifier,
    }) {
      showLoadingOverlayDialog(
        context,
        builder: (dialogContext) {
          loadingDialogContext = dialogContext;
          return LoadingOverlay(
            movie: _movie,
            message: message,
            messageNotifier: messageNotifier,
            fadeOutNotifier: fadeOutNotifier,
            subtitle: sourceHint,
            onCancel: () => _dismissStreamLoadingDialog(dialogContext),
          );
        },
      );
    }

    void popLoading() {
      final ctx = loadingDialogContext;
      if (ctx != null && ctx.mounted) {
        dismissLoadingOverlayRoute(ctx);
      }
      loadingDialogContext = null;
    }

    void abortPlayback() {
      popLoading();
      fadeOutNotifier.dispose();
    }

    showLoading(messageNotifier: overlayMessage);

    String? url;
    String? magnetLink = result.magnet;
    int? resolvedFileIndex;

    try {
      if (!magnetLink.startsWith('magnet:')) {
        if (!mounted || _streamCancelled) {
          abortPlayback();
          return;
        }
        popLoading();
        showLoading(message: 'Resolving download link...');
        try {
          final resolved = await _linkResolver.resolve(magnetLink);
          if (_streamCancelled) {
            abortPlayback();
            return;
          }
          if (resolved.isMagnet) {
            magnetLink = resolved.link;
          } else if (resolved.torrentBytes != null) {
            if (!mounted) {
              abortPlayback();
              return;
            }
            abortPlayback();
            ForjaToast.info(
              'Torrent file downloads not yet supported. Please use magnet links.',
            );
            return;
          }
        } catch (e) {
          if (_streamCancelled) {
            abortPlayback();
            return;
          }
          if (!mounted) {
            abortPlayback();
            return;
          }
          abortPlayback();
          ForjaToast.error(e.toString());
          return;
        }
        if (!mounted || _streamCancelled) {
          abortPlayback();
          return;
        }
        popLoading();
        showLoading(messageNotifier: overlayMessage);
      }

      overlayMessage.value = playbackResolveLabel(
        useDebrid: useDebrid,
        debridService: debridService,
      );

      final isTv = _movie.mediaType == 'tv';
      final playback = await resolveMagnetForPlayback(
        magnet: magnetLink,
        useDebrid: useDebrid,
        debridService: debridService,
        localTorrentEngine: _playbackProfile.localTorrentEngine,
        season: isTv ? _selectedSeason : null,
        episode: isTv ? _selectedEpisode : null,
      );
      if (_streamCancelled) {
        abortPlayback();
        return;
      }
      if (playback != null) {
        url = playback.url;
        resolvedFileIndex = playback.fileIndex;
        debugPrint('[Torrent] Playing via ${playback.sourceLabel}');
      }
    } catch (e) {
      debugPrint('Stream error: $e');
      if (mounted && !_streamCancelled) {
        final message = e is DebridAuthException
            ? e.toString()
            : debridUserMessage(e, debridService);
        ForjaToast.info(message);
      }
    } finally {
      overlayMessage.dispose();
    }

    if (!mounted || _streamCancelled) {
      abortPlayback();
      return;
    }

    final dialogContext = loadingDialogContext;
    if (url != null && dialogContext != null) {
      await crossfadeLoadingOverlayToPlayer(
        loadingDialogContext: dialogContext,
        fadeOutNotifier: fadeOutNotifier,
        openPlayer: () => AppRouter.openPlayer(
          context,
          streamUrl: url!,
          title: _movie.title,
          magnetLink: magnetLink,
          movie: _movie,
          selectedSeason: _movie.mediaType == 'tv' ? _selectedSeason : null,
          selectedEpisode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
          fileIndex: resolvedFileIndex,
          startPosition: startPosition,
          activeProvider: 'torrent',
          fadeTransition: true,
        ),
      );
    } else {
      popLoading();
    }
    fadeOutNotifier.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
            const MediaDetailsBackButton(),
          ],
        ),
      );
    }

    final scaffold = Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          _buildScrollLayout(),
          if (!_isCollection && _hasPanelPlaySources)
            TorrentSourcesPanel(
              isOpen: _sourcesPanelOpen,
              onClose: () => setState(() => _sourcesPanelOpen = false),
              child: _buildSourcesPanelContent(),
            ),
          const MediaDetailsBackButton(),
        ],
      ),
    );

    return scaffold;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SCROLL LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildScrollLayout() {
    final showEpisodeRail = _movie.mediaType == 'tv' && !_isCollection;
    final heroHeight = ShellTokens.detailsHeroHeight(
      context,
      showEpisodeRail: showEpisodeRail,
    );
    final showTvPicker = showEpisodeRail;
    final showCast = _castMembers.isNotEmpty;
    final showTrailers = _trailers.isNotEmpty;
    final heroFocusUp = _revealedDetailsHeroPlayFocus;
    final showCollection = _isCollection && _collectionItems.isNotEmpty;
    final firstRowIsCollection = showCollection;
    final firstRowIsCast = !showCollection && !showTvPicker && showCast;
    final firstRowIsTrailers =
        !showCollection && !showTvPicker && !showCast && showTrailers;
    final firstRowIsRecs =
        !showCollection && !showTvPicker && !showCast && !showTrailers;

    var rowOrder = 0;
    final collectionOrder = showCollection ? rowOrder++ : null;
    final pickerBase = rowOrder;
    if (showTvPicker) {
      rowOrder += _detailsPickerRowCount();
    }
    final castOrder = showCast ? rowOrder++ : null;
    final trailersOrder = showTrailers ? rowOrder++ : null;
    final recsOrder = rowOrder;

    final sections = <Widget>[
      if (showCollection)
        MediaDetailsBody.padContent(
          context,
          DetailsCollectionSection(
            items: _collectionItems,
            tvRowOrder: collectionOrder!,
            tvFocusUp: firstRowIsCollection ? heroFocusUp : null,
            onOpenItem: _openCollectionItem,
          ),
        ),
      if (showTvPicker)
        MediaDetailsBody.padContent(
          context,
          _buildTvPicker(
            tvRowOrderBase: pickerBase,
            tvFocusUp: heroFocusUp,
          ),
        ),
      if (showCast)
        MediaDetailsCastSection(
          cast: _castMembers,
          title: 'Main Characters',
          tvTabId: MediaDetailsTv.tabId,
          tvRowId: 'cast',
          tvRowOrder: castOrder!,
          tvFocusUp: firstRowIsCast ? heroFocusUp : null,
        ),
      if (showTrailers)
        MediaDetailsTrailersSection(
          trailers: _trailers,
          movie: _movie,
          languageCode: _originalLanguage,
          tvTabId: MediaDetailsTv.tabId,
          tvRowId: 'trailers',
          tvRowOrder: trailersOrder!,
          tvFocusUp: firstRowIsTrailers ? heroFocusUp : null,
        ),
      MediaDetailsRecommendationsSection(
        movies: _similarMovies,
        onMovieTap: (movie) => AppRouter.openMovie(context, movie: movie),
        tvTabId: MediaDetailsTv.tabId,
        tvRowOrder: recsOrder,
        tvFocusUp: firstRowIsRecs ? heroFocusUp : null,
      ),
    ];

    return MediaDetailsScrollPage(
      scrollController: _detailsScrollController,
      tvHeroPlayFocus: _detailsHeroPlayFocus,
      hero: _buildDetailsHero(
        heroHeight: heroHeight,
        showEpisodeRail: showEpisodeRail,
      ),
      backgroundColor: AppTheme.bgDark,
      bodyOverlap: showEpisodeRail
          ? ShellTokens.detailsHeroBodyOverlapWithEpisodes
          : null,
      topSpacing: showEpisodeRail
          ? ShellTokens.detailsBodyTopSpacingWithEpisodes
          : null,
      sections: sections,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SOURCES SLIDING PANEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSourcesPanelContent() {
    final showMerged =
        _panelKindFilter == 'all' && _panelShowTorrent && _panelShowStremio;
    final showTorrents = _panelKindFilter == 'torrents' || showMerged;
    final showNuvio = _panelKindFilter == 'nuvio';
    final showSort = showTorrents && !showNuvio;
    final showAudio = showTorrents && !showNuvio;
    final providerChips = showMerged
        ? const <Map<String, dynamic>>[]
        : _sourceChips();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TorrentSourcesPanelChrome(
          onClose: () => setState(() => _sourcesPanelOpen = false),
          kindFilter: _panelKindFilter,
          showTorrents: _panelShowTorrent,
          showStremio: _panelShowStremio,
          showNuvio: _panelShowNuvio,
          onKindChanged: _onPanelKindFilterChanged,
          resultCount: _panelVisibleCount,
          episodeLabel: _movie.mediaType == 'tv'
              ? 'S${_selectedSeason.toString().padLeft(2, '0')}E${_selectedEpisode.toString().padLeft(2, '0')}'
              : null,
          isFetching: _isSearching || _isStremioFetching || _isNuvioFetching,
          onCancelFetch: _cancelActiveSourceFetch,
          providerChips: providerChips,
          selectedSourceId: _selectedSourceId,
          nuvioSelectedAddonUrl: _nuvioSelectedAddonUrl,
          chipsScrollController: _chipsScrollController,
          onChipTap: _onSourceChipTap,
          onScrollBack: _scrollChipsBack,
          onScrollForward: _scrollChipsForward,
          searchQuery: _sourceSearchQuery,
          onSearchChanged: (q) => setState(() => _sourceSearchQuery = q),
          availableQualities: _panelAvailableQualities,
          availableLanguages: _panelAvailableLanguages,
          availableTech: _panelAvailableTech,
          availableSizeRanges: _panelAvailableSizeRanges,
          activeQualityFilters: _activeQualityFilters,
          activeLanguageFilters: _activeLanguageFilters,
          activeTechFilters: _activeTechFilters,
          activeSizeFilters: _activeSizeFilters,
          onQualityFiltersChanged: (v) =>
              setState(() => _activeQualityFilters = v),
          onLanguageFiltersChanged: (v) =>
              setState(() => _activeLanguageFilters = v),
          onTechFiltersChanged: (v) => setState(() => _activeTechFilters = v),
          onSizeFiltersChanged: (v) => setState(() => _activeSizeFilters = v),
          showAudioFilters: showAudio,
          activeAudioFilters: _activeAudioFilters,
          onAudioFiltersChanged: (v) => setState(() => _activeAudioFilters = v),
          sortPreference: showSort ? _sortPreference : null,
          onSortChanged: showSort
              ? (val) {
                  setState(() => _sortPreference = val);
                  _settings.setSortPreference(val);
                  _sortResults();
                }
              : null,
          showCacheLine: showTorrents && _playbackProfile.localTorrentEngine,
          cacheRefreshToken: Object.hash(
            _sourcesPanelOpen,
            _allTorrentResults.length,
            _isSearching,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildStreamList(inPanel: true)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SOURCE TOGGLE + CHIPS (sliding source panel)
  // ═══════════════════════════════════════════════════════════════════════════

  void _resetPanelFilters() {
    _sourceSearchQuery = '';
    _activeQualityFilters = {};
    _activeLanguageFilters = {};
    _activeTechFilters = {};
    _activeAudioFilters = {};
    _activeSizeFilters = {};
  }

  int? get _panelVisibleCount {
    var count = 0;
    if (_panelShowsTorrents) count += _filteredTorrentResults.length;
    if (_panelShowsStremio) count += _filteredPanelStremioStreams.length;
    if (_panelShowsNuvio) count += _filteredPanelNuvioStreams.length;
    return count;
  }

  bool get _isTorrentSource =>
      _selectedSourceId == 'forja' ||
      _selectedSourceId == 'jackett' ||
      _selectedSourceId == 'prowlarr';

  bool get _isNuvioSource =>
      _selectedSourceId == 'nuvio_picker' ||
      _selectedSourceId == 'all_nuvio' ||
      _selectedSourceId.startsWith('nuvio:') ||
      _selectedSourceId.startsWith('nuvio://');

  bool get _isWebstreamingSource =>
      _selectedSourceId == 'webstream_picker' ||
      _selectedSourceId.startsWith('stream:');

  List<Map<String, dynamic>> _sourceChips() {
    final chips = <Map<String, dynamic>>[];
    if (_panelKindFilter == 'torrents') {
      chips.add({'id': 'forja', 'label': 'Forja'});
      if (_isJackettConfigured)
        chips.add({'id': 'jackett', 'label': '🔍 Jackett'});
      if (_isProwlarrConfigured)
        chips.add({'id': 'prowlarr', 'label': '🔍 Prowlarr'});
      for (final a in _streamAddons) {
        if (a['type'] == 'torrent')
          chips.add({'id': a['baseUrl'], 'label': a['name']});
      }
    } else if (_panelKindFilter == 'nuvio') {
      if (_nuvioSelectedAddonUrl == null) {
        for (final a in _nuvioAddons) {
          chips.add({
            'id': 'nuvio_addon::${a.manifestUrl}',
            'label': '📦 ${a.name}',
          });
        }
      } else {
        chips.add({'id': 'nuvio_back', 'label': '← Addons'});
        final addon = _nuvioAddons.firstWhere(
          (a) => a.manifestUrl == _nuvioSelectedAddonUrl,
          orElse: () => NuvioAddon(
            manifestUrl: _nuvioSelectedAddonUrl!,
            name: '',
            version: '',
            scrapers: const [],
          ),
        );
        for (final s in addon.scrapers) {
          if (!s.enabled) continue;
          chips.add({'id': 'nuvio:${s.id}', 'label': s.name});
        }
      }
    } else if (_panelKindFilter == 'stremio') {
      if (_streamAddons.length > 1) {
        chips.add({'id': 'all_stremio', 'label': '⚡ All'});
      }
      for (final a in _streamAddons) {
        if (_loadedAddonBaseUrls.contains(a['baseUrl'])) {
          chips.add({'id': a['baseUrl'], 'label': a['name']});
        }
      }
    }
    return chips;
  }

  void _scrollChipsBack() {
    _chipsScrollController.animateTo(
      (_chipsScrollController.offset - 160).clamp(
        0.0,
        _chipsScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _scrollChipsForward() {
    _chipsScrollController.animateTo(
      (_chipsScrollController.offset + 160).clamp(
        0.0,
        _chipsScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _onSourceChipTap(String id) {
    if (id.startsWith('nuvio_addon::')) {
      setState(() {
        _nuvioSelectedAddonUrl = id.substring('nuvio_addon::'.length);
        _nuvioSelectedScraperId = null;
        _selectedSourceId = 'nuvio_picker';
        _nuvioStreams = [];
        _errorMessage = null;
      });
      return;
    }
    if (id == 'nuvio_back') {
      setState(() {
        _nuvioSelectedAddonUrl = null;
        _nuvioSelectedScraperId = null;
        _selectedSourceId = 'nuvio_picker';
        _nuvioStreams = [];
        _errorMessage = null;
      });
      return;
    }
    if (id.startsWith('nuvio:')) {
      final scraperId = id.substring('nuvio:'.length);
      setState(() {
        _selectedSourceId = id;
        _nuvioSelectedScraperId = scraperId;
        _resetPanelFilters();
      });
      _runSingleNuvioScraper(scraperId);
      return;
    }
    setState(() {
      _selectedSourceId = id;
      _resetPanelFilters();
    });
    if (id == 'forja') {
      _autoSearch();
    } else if (id == 'jackett') {
      _searchJackett();
    } else if (id == 'prowlarr') {
      _searchProwlarr();
    } else if (id == 'all_stremio') {
      setState(() {
        _applyStremioFilter();
        _errorMessage = _stremioStreams.isEmpty && !_isStremioFetching
            ? 'No streams found from any addon'
            : null;
      });
    } else if (id == 'all_nuvio' || id.startsWith('nuvio://')) {
      setState(() => _errorMessage = null);
    } else {
      final chip = _sourceChips().firstWhere(
        (c) => c['id'] == id,
        orElse: () => {'label': 'addon'},
      );
      setState(() {
        _applyStremioFilter();
        _errorMessage = _stremioStreams.isEmpty && !_isStremioFetching
            ? 'No streams found in ${chip['label']}'
            : null;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STREAM LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _torrentTileFor(TorrentResult r) {
    double prog = 0;
    var preselected = false;
    if (_lastProgress != null && _lastProgress!['method'] == 'torrent') {
      if (_getHash(r.magnet) == _getHash(_lastProgress!['sourceId'])) {
        preselected = true;
        final pos = (_lastProgress!['position'] as int?) ?? 0;
        final dur = (_lastProgress!['duration'] as int?) ?? 0;
        if (dur > 0) {
          prog = (pos / dur).clamp(0.0, 1.0);
        }
      }
    }
    return TorrentSourceTile(
      result: r,
      progress: prog,
      isResumable: preselected,
      highlightStart: widget.startPosition != null,
      onPlay: () => _playTorrent(
        r,
        startPosition: preselected
            ? resumeStartPositionFromProgress(_lastProgress!)
            : widget.startPosition,
      ),
    );
  }

  Widget _stremioTileFor(
    Map<String, dynamic> s, {
    required bool showAddonName,
  }) {
    final title = s['title'] ?? s['name'] ?? 'Unknown Stream';
    final description = s['description'] ?? '';
    double prog = 0;
    var resumable = false;
    if (_lastProgress != null) {
      final String? sid = s['infoHash'] != null
          ? 'magnet:?xt=urn:btih:${s['infoHash']}'
          : s['url'];
      if (sid != null) {
        final hs = _lastProgress!['sourceId'] as String;
        final match = s['infoHash'] != null
            ? _getHash(hs) == _getHash(sid)
            : hs == sid;
        if (match) {
          final pos = _lastProgress!['position'] as int;
          final dur = _lastProgress!['duration'] as int;
          if (dur > 0) {
            prog = (pos / dur).clamp(0.0, 1.0);
            resumable = true;
          }
        }
      }
    }
    final presentation = stremioTilePresentation(s, isResumable: resumable);
    return StremioSourceTile(
      title: title,
      description: description,
      leadingIcon: presentation.leadingIcon,
      leadingColor: presentation.leadingColor,
      isExternal: presentation.isExternal,
      addonName: s['_addonName']?.toString(),
      showAddonName: showAddonName,
      sizeText: s['size']?.toString(),
      seeders: s['seeders']?.toString() ?? s['seeds']?.toString(),
      stream: s,
      progress: prog,
      isResumable: resumable,
      highlightStart: widget.startPosition != null,
      onTap: () => _playStremioStream(
        s,
        startPosition: resumable
            ? Duration(milliseconds: _lastProgress!['position'] as int)
            : widget.startPosition,
      ),
    );
  }

  Widget _buildStreamList({bool inPanel = false}) {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    final torrents = _panelShowsTorrents
        ? _filteredTorrentResults
        : <TorrentResult>[];
    final stremio = _panelShowsStremio
        ? _filteredPanelStremioStreams
        : <Map<String, dynamic>>[];
    final nuvio = _panelShowsNuvio
        ? _filteredPanelNuvioStreams
        : <Map<String, dynamic>>[];
    final count = torrents.length + stremio.length + nuvio.length;
    final rawCount =
        (_panelShowsTorrents ? _allTorrentResults.length : 0) +
        (_panelShowsStremio
            ? (_panelShowsMerged || _selectedSourceId == 'all_stremio'
                  ? _allCombinedStremioStreams.length
                  : _stremioStreams.length)
            : 0) +
        (_panelShowsNuvio ? _nuvioStreams.length : 0);
    final isFetching =
        (_panelShowsTorrents && _isSearching) ||
        (_panelShowsStremio && _isStremioFetching) ||
        (_panelShowsNuvio && _isNuvioFetching);

    if (!_isSearching && !isFetching && count == 0) {
      String msg;
      if (rawCount > 0 &&
          (_sourceSearchQuery.isNotEmpty ||
              _activeAudioFilters.isNotEmpty ||
              _activeQualityFilters.isNotEmpty ||
              _activeLanguageFilters.isNotEmpty ||
              _activeTechFilters.isNotEmpty ||
              _activeSizeFilters.isNotEmpty)) {
        msg = 'No results match your filters';
      } else if (_panelShowsTorrents &&
          _activeAudioFilters.isNotEmpty &&
          _allTorrentResults.isNotEmpty) {
        msg = 'No results match the audio filter';
      } else if (_panelShowsNuvio && _nuvioSelectedScraperId == null) {
        msg = _nuvioSelectedAddonUrl == null
            ? 'Pick an addon to see its providers'
            : 'Pick a provider to fetch streams';
      } else {
        msg = 'No streams found';
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            msg,
            style: TextStyle(color: ForjaShellColors.cinematic.textSecondary),
          ),
        ),
      );
    }

    final showAddonName =
        _panelShowsMerged || _selectedSourceId == 'all_stremio';

    return ListView.separated(
      shrinkWrap: !inPanel,
      physics: inPanel
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i < torrents.length) return _torrentTileFor(torrents[i]);
        final j = i - torrents.length;
        if (j < stremio.length) {
          return _stremioTileFor(stremio[j], showAddonName: showAddonName);
        }
        return _stremioTileFor(nuvio[j - stremio.length], showAddonName: true);
      },
    );
  }

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
