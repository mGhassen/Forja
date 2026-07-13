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
part 'details_screen_webstreaming.part.dart';
part 'details_screen_episodes.part.dart';
part 'details_screen_panel.part.dart';
part 'details_screen_play.part.dart';

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
    with AtmosphereMixin, _DetailsScreenTorrent, _DetailsScreenStremio, _DetailsScreenWebstreaming, _DetailsScreenEpisodes, _DetailsScreenPlay, _DetailsScreenPanel {
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


  Future<void> _loadSortPreference() async {
    final pref = await _settings.getSortPreference();
    if (mounted) setState(() => _sortPreference = pref);
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
