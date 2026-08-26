import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/media/details/providers/details_providers.dart';
import 'package:forja/features/media/details/providers/details_play_session.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/lan/lan_client_service.dart';
import 'package:forja/shared/lan/lan_p2p_playback.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/utils/extensions.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/playback/playback_service.dart';
import 'package:forja/shared/playback/simple_streaming_resolve.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/playback/tv_stream_fallback.dart';
import 'package:forja/shared/playback/provider_score_probe_sync.dart';
import 'package:forja/shared/playback/sources_panel_stream_probe.dart';
import 'package:forja/shared/playback/webstreaming_stream_cache.dart';
import 'package:forja/shared/playback/catalog_sources_session_cache.dart';
import 'package:forja/shared/playback/engine_catalog_stream_probe.dart';
import 'package:forja/shared/playback/engine_auto_play.dart';
import 'package:forja/shared/playback/history_playback_resume.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/resolve_failure_view.dart';
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
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:forja/shared/widgets/watch_series_progress.dart';
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
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/services/tracker_sync.dart';
import 'package:forja/features/media/details/widgets/details_collection_section.dart';

part 'details_screen_torrent.dart';
part 'details_screen_stremio.dart';
part 'details_screen_engine.dart';
part 'details_screen_webstreaming.dart';
part 'details_screen_episodes.dart';
part 'details_screen_panel.dart';
part 'details_screen_play.dart';
part 'details_screen_build.dart';
part 'details_screen_fetch.dart';

class DetailsScreen extends ConsumerStatefulWidget {
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
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen>
    with
        AtmosphereMixin,
        _DetailsScreenTorrent,
        _DetailsScreenStremio,
        _DetailsScreenEngine,
        _DetailsScreenWebstreaming,
        _DetailsScreenEpisodes,
        _DetailsScreenPlay,
        _DetailsScreenPanel,
        _DetailsScreenFetch,
        _DetailsScreenBuild {
  late Movie _movie;
  bool _isLoading = true;

  DetailsMetaKey get _metaKey =>
      DetailsMetaKey(id: widget.movie.id, mediaType: widget.movie.mediaType);

  /// Cached in [initState] — dispose must not call [ref] (Riverpod element
  /// is already defunct by then; see cancel flags in [dispose]).
  late final DetailsPlaySession _play;
  late final DetailsPlaySessionNotifier _playN;

  bool get _isCustomStremioItem {
    final item = widget.stremioItem;
    return item != null && !(item['id']?.toString().startsWith('tt') ?? true);
  }

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
  /// Soft Forja chip categories (Filters → Category). Null = media default.
  Set<String>? _engineVisibleCategories;
  String _sourceSearchQuery = '';

  Set<String> get _effectiveEngineCategories =>
      _engineVisibleCategories ??
      EngineCategories.defaultsForPanelCategory(_enginePanelCategory);

  String get _enginePanelCategory =>
      EngineCategories.panelCategoryFor(mediaType: _movie.mediaType);

  // ── play / resolve (owned by [detailsPlaySessionProvider]) ───────────────
  List<TorrentResult> get _allTorrentResults => _play.torrents;
  set _allTorrentResults(List<TorrentResult> v) => _play.torrents = v;

  bool get _isSearching => _play.isSearching;
  set _isSearching(bool v) => _play.isSearching = v;

  int get _torrentSearchGen => _play.torrentSearchGen;
  set _torrentSearchGen(int v) => _play.torrentSearchGen = v;

  Set<String> get _torrentFetchedProviderIds => _play.torrentFetchedProviderIds;

  Set<String> get _torrentInFlightProviderIds =>
      _play.torrentInFlightProviderIds;

  int get _stremioFetchGen => _play.stremioFetchGen;
  set _stremioFetchGen(int v) => _play.stremioFetchGen = v;

  String? get _errorMessage => _play.errorMessage;
  set _errorMessage(String? v) => _play.errorMessage = v;

  bool get _playSourceTorrent => _play.playSources.torrent;
  bool get _playSourceNuvio => _play.playSources.nuvio;
  bool get _playSourceEngine => _play.playSources.engine;
  bool get _playSourceEngineAutoStart => _play.playSources.engineAutoStart;
  bool get _playSourceStremio => _play.playSources.stremio;
  bool get _playSourceWebstreaming => _play.playSources.webstreaming;

  bool get _showGreenPlay =>
      _playSourceWebstreaming ||
      (_playSourceEngine && _playSourceEngineAutoStart);

  String get _panelKindFilter => _play.panelKindFilter;
  set _panelKindFilter(String v) => _play.panelKindFilter = v;
  Map<String, String> get _panelSourceIdByKind => _play.panelSourceIdByKind;

  String get _selectedSourceId => _play.selectedSourceId;
  set _selectedSourceId(String v) => _play.selectedSourceId = v;

  String? get _playingPanelKind => _play.playingPanelKind;
  set _playingPanelKind(String? v) => _play.playingPanelKind = v;

  String? get _playingCatalogUrl => _play.playingCatalogUrl;
  set _playingCatalogUrl(String? v) => _play.playingCatalogUrl = v;

  List<Map<String, dynamic>> get _streamAddons => _play.streamAddons;
  set _streamAddons(List<Map<String, dynamic>> v) => _play.streamAddons = v;

  List<dynamic> get _stremioStreams => _play.stremioStreams;
  set _stremioStreams(List<dynamic> v) => _play.stremioStreams = v;

  List<Map<String, dynamic>> get _allCombinedStremioStreams =>
      _play.allCombinedStremioStreams;
  set _allCombinedStremioStreams(List<Map<String, dynamic>> v) =>
      _play.allCombinedStremioStreams = v;

  bool get _isStremioFetching => _play.isStremioFetching;
  set _isStremioFetching(bool v) => _play.isStremioFetching = v;

  Set<String> get _loadedAddonBaseUrls => _play.loadedAddonBaseUrls;
  Set<String> get _completedAddonBaseUrls => _play.completedAddonBaseUrls;

  bool get _userPickedStremioProvider => _play.userPickedStremioProvider;
  set _userPickedStremioProvider(bool v) => _play.userPickedStremioProvider = v;

  List<Map<String, dynamic>> get _nuvioStreams => _play.nuvioStreams;
  set _nuvioStreams(List<Map<String, dynamic>> v) => _play.nuvioStreams = v;

  bool get _isNuvioFetching => _play.isNuvioFetching;
  set _isNuvioFetching(bool v) => _play.isNuvioFetching = v;

  bool get _hasNuvioAddons => _play.hasNuvioAddons;
  set _hasNuvioAddons(bool v) => _play.hasNuvioAddons = v;

  Set<String> get _nuvioFetchedScraperIds => _play.nuvioFetchedScraperIds;
  set _nuvioFetchedScraperIds(Set<String> v) =>
      _play.nuvioFetchedScraperIds = v;

  int get _nuvioFetchGen => _play.nuvioFetchGen;
  set _nuvioFetchGen(int v) => _play.nuvioFetchGen = v;

  Set<String> get _nuvioInFlightScraperIds => _play.nuvioInFlightScraperIds;

  List<NuvioAddon> get _nuvioAddons => _play.nuvioAddons;
  set _nuvioAddons(List<NuvioAddon> v) => _play.nuvioAddons = v;

  Set<String> get _nuvioSelectedScraperIds => _play.nuvioSelectedScraperIds;
  set _nuvioSelectedScraperIds(Set<String> v) =>
      _play.nuvioSelectedScraperIds = v;

  bool get _nuvioAllMode => _play.nuvioAllMode;
  set _nuvioAllMode(bool v) => _play.nuvioAllMode = v;

  bool get _nuvioSelectionHydrated => _play.nuvioSelectionHydrated;
  set _nuvioSelectionHydrated(bool v) => _play.nuvioSelectionHydrated = v;

  List<Map<String, dynamic>> get _engineStreams => _play.engineStreams;
  set _engineStreams(List<Map<String, dynamic>> v) => _play.engineStreams = v;

  bool get _isEngineFetching => _play.isEngineFetching;
  set _isEngineFetching(bool v) => _play.isEngineFetching = v;

  bool get _hasEnginePacks => _play.hasEnginePacks;
  set _hasEnginePacks(bool v) => _play.hasEnginePacks = v;

  Set<String> get _engineFetchedPluginIds => _play.engineFetchedPluginIds;
  set _engineFetchedPluginIds(Set<String> v) =>
      _play.engineFetchedPluginIds = v;

  int get _engineFetchGen => _play.engineFetchGen;
  set _engineFetchGen(int v) => _play.engineFetchGen = v;

  Set<String> get _engineInFlightPluginIds => _play.engineInFlightPluginIds;
  set _engineInFlightPluginIds(Set<String> v) =>
      _play.engineInFlightPluginIds = v;

  List<EnginePack> get _enginePacks => _play.enginePacks;
  set _enginePacks(List<EnginePack> v) => _play.enginePacks = v;

  Set<String> get _engineSelectedPluginIds => _play.engineSelectedPluginIds;
  set _engineSelectedPluginIds(Set<String> v) =>
      _play.engineSelectedPluginIds = v;

  bool get _engineAllMode => _play.engineAllMode;
  set _engineAllMode(bool v) => _play.engineAllMode = v;

  /// Soft-cancel while in-flight — discard late plugin/scraper results.
  final Set<String> _engineDiscardPluginIds = {};
  final Set<String> _nuvioDiscardScraperIds = {};

  bool get _engineSelectionHydrated => _play.engineSelectionHydrated;
  set _engineSelectionHydrated(bool v) => _play.engineSelectionHydrated = v;

  Map<String, dynamic> get _webstreamingProviders =>
      _play.webstreamingProviders;

  List<String> get _webstreamingProviderOrder =>
      _play.webstreamingProviderOrder;
  set _webstreamingProviderOrder(List<String> v) =>
      _play.webstreamingProviderOrder = v;

  List<StreamSource> get _webstreamingStreams => _play.webstreamingStreams;
  set _webstreamingStreams(List<StreamSource> v) =>
      _play.webstreamingStreams = v;

  String? get _webstreamingActiveProviderId =>
      _play.webstreamingActiveProviderId;
  set _webstreamingActiveProviderId(String? v) =>
      _play.webstreamingActiveProviderId = v;

  bool get _isWebstreamingOnlyExtracting => _play.isWebstreamingOnlyExtracting;
  set _isWebstreamingOnlyExtracting(bool v) =>
      _play.isWebstreamingOnlyExtracting = v;

  bool get _webstreamingOnlyExtractionCancelled =>
      _play.webstreamingOnlyExtractionCancelled;
  set _webstreamingOnlyExtractionCancelled(bool v) =>
      _play.webstreamingOnlyExtractionCancelled = v;

  int get _webstreamingPlayGen => _play.webstreamingPlayGen;
  set _webstreamingPlayGen(int v) => _play.webstreamingPlayGen = v;

  bool get _isEngineAutoExtracting => _play.isEngineAutoExtracting;
  set _isEngineAutoExtracting(bool v) => _play.isEngineAutoExtracting = v;

  bool get _engineAutoExtractionCancelled =>
      _play.engineAutoExtractionCancelled;
  set _engineAutoExtractionCancelled(bool v) =>
      _play.engineAutoExtractionCancelled = v;

  int get _engineAutoPlayGen => _play.engineAutoPlayGen;
  set _engineAutoPlayGen(int v) => _play.engineAutoPlayGen = v;

  Map<String, dynamic>? _lastProgress;
  StreamSubscription<List<Map<String, dynamic>>>? _watchHistorySub;
  bool _sourcesPanelOpen = false;
  /// Completes when enabled Sources chip metadata (Stremio/Nuvio/Forja) is loaded.
  Future<void>? _sourcesChromeWarm;
  bool _autoPlayConsumed = false;
  bool _episodePlayPending = false;
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
  List<String> _enabledTorrentProviders = List<String>.from(
    TorrentSearchProviders.all,
  );

  List<Movie> _similarMovies = [];
  List<Map<String, String>> _castMembers = [];
  List<MediaTrailer> _trailers = [];

  // Stream resolution cancellation
  bool _streamCancelled = false;

  /// Blocks taps on details/Sources after a source row is chosen until the
  /// loading overlay or player takes over (settings/debrid awaits used to
  /// leave a clickable gap).
  bool _playbackLaunchInFlight = false;

  bool _tryLockPlaybackLaunch() {
    if (_playbackLaunchInFlight) return false;
    _playbackLaunchInFlight = true;
    if (mounted) setState(() {});
    return true;
  }

  void _unlockPlaybackLaunch() {
    if (!_playbackLaunchInFlight) return;
    _playbackLaunchInFlight = false;
    if (mounted) setState(() {});
  }

  void _dismissStreamLoadingDialog(BuildContext dialogContext) {
    _streamCancelled = true;
    Engine.cancelPendingResolve();
    dismissLoadingOverlayRoute(dialogContext);
    _unlockPlaybackLaunch();
    _claimTvHeroPlayAfterPlayer();
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
  List<WatchProvider> _watchProviders = [];
  final Map<int, String> _seasonPosters = {};
  Map<String, Map<String, dynamic>> _episodeProgress = {};

  final ScrollController _episodeScrollController = ScrollController();
  final ScrollController _detailsScrollController = ScrollController();
  final FocusNode _detailsHeroPlayFocus = FocusNode(
    debugLabel: 'details-hero-play',
  );
  final FocusNode _detailsBackFocus = FocusNode(debugLabel: 'details-back');
  final ScrollController _sourcesListScrollController = ScrollController();
  bool _detailsHeroInitialFocusDone = false;

  /// TV: button that opened Sources — restore on Back.
  FocusNode? _sourcesPanelReturnFocus;

  /// TV: reclaim Play/Resume after player pop or loading cancel.
  void _claimTvHeroPlayAfterPlayer() {
    if (_detailsScrollController.hasClients) {
      _detailsScrollController.jumpTo(0);
    }
    ShellTvFocusCoordinator.claimHeroPlayAfterPlayerExit(
      _detailsHeroPlayFocus,
      isMounted: () => mounted,
      skip: () => _sourcesPanelOpen,
    );
  }

  void _captureSourcesPanelReturnFocus() {
    final node = FocusManager.instance.primaryFocus;
    if (node == null || identical(node, _detailsBackFocus)) {
      _sourcesPanelReturnFocus = _detailsHeroPlayFocus;
      return;
    }
    try {
      if (!node.canRequestFocus) {
        _sourcesPanelReturnFocus = _detailsHeroPlayFocus;
        return;
      }
    } catch (_) {
      _sourcesPanelReturnFocus = _detailsHeroPlayFocus;
      return;
    }
    _sourcesPanelReturnFocus = node;
  }

  void _restoreTvFocusAfterSourcesPanel() {
    final saved = _sourcesPanelReturnFocus ?? _detailsHeroPlayFocus;
    _sourcesPanelReturnFocus = null;
    if (identical(saved, _detailsHeroPlayFocus) &&
        _detailsScrollController.hasClients) {
      _detailsScrollController.jumpTo(0);
    }
    ShellTvFocusCoordinator.claimHeroPlayAfterPlayerExit(
      saved,
      isMounted: () => mounted,
      skip: () => _sourcesPanelOpen,
    );
  }

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
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (!mounted) return;
    // Play/resolve fields live in [detailsPlaySessionProvider]; bump so
    // watchers (hero buttons, panel) see the same bag the mixins mutate.
    _playN.bump();
    final status = _play.resolveStatus;
    final resolve = ref.read(detailsResolveStatusProvider(_metaKey).notifier);
    switch (status) {
      case DetailsResolveStatus.idle:
        break;
      case DetailsResolveStatus.loading:
        resolve.setLoading();
      case DetailsResolveStatus.ready:
        resolve.setReady();
      case DetailsResolveStatus.error:
        resolve.setError();
    }
  }

  @override
  void initState() {
    super.initState();
    _playN = ref.read(detailsPlaySessionProvider(_metaKey).notifier);
    _play = _playN.session;
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
    _watchHistorySub = WatchHistoryService().historyStream.listen((_) {
      if (!mounted) return;
      unawaited(_refreshProgressFromHistory());
    });
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
    // Leave the title → stop every in-flight source fetch (panel owner gone).
    // Flags first so Auto host loops halt even if cancel races mid-sniff.
    // rebuild: false — Element is already defunct here; setState would assert.
    _webstreamingOnlyExtractionCancelled = true;
    _engineAutoExtractionCancelled = true;
    _streamCancelled = true;
    _cancelActiveSourceFetch(rebuild: false);
    _sourcesPanelReturnFocus = null;
    _detailsHeroPlayFocus.dispose();
    _detailsBackFocus.dispose();
    _detailsScrollController.dispose();
    _episodeScrollController.dispose();
    _sourcesListScrollController.dispose();
    _watchHistorySub?.cancel();
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

  Future<void> _refreshProgressFromHistory() async {
    await _checkHistory();
    if (!mounted) return;
    if (_movie.mediaType == 'tv') {
      await _loadEpisodeProgressForSeason(_selectedSeason);
    }
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
        _panelKindFilter = _defaultPanelKindFilter();
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
          if (ok) {
            if (mounted) _claimTvHeroPlayAfterPlayer();
            return true;
          }
        }
        if (await _tryResumeWebStreamFromWatchHistory(startPosition)) {
          if (mounted) _claimTvHeroPlayAfterPlayer();
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
        // Torrent resumes: user opens Sources (white Play) for the selected episode.
        return false;
      default:
        return false;
    }
  }

  bool get _panelShowTorrent =>
      _playSourceTorrent &&
      ((_playbackProfile.playSourceTorrent &&
              _playbackProfile.builtinTorrentSearch) ||
          // Paired LAN client (ATV): settings already gated torrent on.
          (!_playbackProfile.localTorrentEngine && _playSourceTorrent));

  bool get _panelShowStremio =>
      _playSourceStremio &&
      (_playbackProfile.playSourceStremio ||
          (!_playbackProfile.localTorrentEngine && _playSourceStremio));

  bool get _panelShowNuvio =>
      _playSourceNuvio &&
      (_playbackProfile.playSourceNuvio ||
          (!_playbackProfile.localTorrentEngine && _playSourceNuvio));

  bool get _panelShowEngine =>
      _playSourceEngine &&
      (_playbackProfile.playSourceEngine ||
          (!_playbackProfile.localTorrentEngine && _playSourceEngine));

  bool get _hasPanelPlaySources =>
      _panelShowTorrent ||
      _panelShowStremio ||
      _panelShowNuvio ||
      _panelShowEngine;

  String _defaultPanelKindFilter() {
    if (_panelShowEngine) return EngineIds.kind;
    if (_panelShowTorrent) return 'torrents';
    if (_panelShowStremio) return 'stremio';
    if (_panelShowNuvio) return 'nuvio';
    return 'torrents';
  }

  void _syncPanelKindFilterToPlaySources() {
    final allowed = <String>{
      if (_panelShowTorrent) 'torrents',
      if (_panelShowStremio) 'stremio',
      if (_panelShowNuvio) 'nuvio',
      if (_panelShowEngine) EngineIds.kind,
    };
    if (!allowed.contains(_panelKindFilter)) {
      _panelKindFilter = _defaultPanelKindFilter();
    }
  }

  bool _isCurrentSourceAllowed() {
    if (_isTorrentSource) return _panelShowTorrent;
    if (_isNuvioSource) return _panelShowNuvio;
    if (_isEngineSource) return _panelShowEngine;
    if (_isWebstreamingSource) return false;
    return _panelShowStremio;
  }

  String _defaultSourceIdForKind(String kind) {
    switch (kind) {
      case EngineIds.kind:
        if (_panelShowEngine) return EngineIds.allChip;
      case 'torrents':
        if (_panelShowTorrent) return TorrentSearchProviders.noneId;
      case 'nuvio':
        if (_panelShowNuvio) return 'all_nuvio';
      case 'stremio':
        if (_panelShowStremio) return '';
    }
    return TorrentSearchProviders.noneId;
  }

  String _defaultSourceId() => _defaultSourceIdForKind(_panelKindFilter);

  void _stashPanelSourceIdForKind(String kind) {
    if (kind.isEmpty) return;
    _panelSourceIdByKind[kind] = _selectedSourceId;
  }

  void _restorePanelSourceIdForKind(String kind) {
    _selectedSourceId =
        _panelSourceIdByKind[kind] ?? _defaultSourceIdForKind(kind);
    if (kind == 'stremio') {
      _applyStremioFilter();
    }
  }

  /// After green Play, open Sources on the playing kind tab only.
  /// Do not narrow Forja / Nuvio multi-select chips to the playing provider —
  /// that broke All (same as player Sources panel).
  void _focusPanelOnPlayingSource() {
    final kind = _playingPanelKind;
    if (kind == null || kind.isEmpty) return;
    final allowed = <String>{
      if (_panelShowTorrent) 'torrents',
      if (_panelShowStremio) 'stremio',
      if (_panelShowNuvio) 'nuvio',
      if (_panelShowEngine) EngineIds.kind,
    };
    if (!allowed.contains(kind)) return;

    if (_panelKindFilter != kind) {
      _stashPanelSourceIdForKind(_panelKindFilter);
      _panelKindFilter = kind;
      _restorePanelSourceIdForKind(kind);
    }
  }

  String _defaultStremioSourceId() {
    if (_streamAddons.isEmpty) return TorrentSearchProviders.allId;
    for (final a in _streamAddons) {
      final base = a['baseUrl'] as String?;
      if (base != null && _loadedAddonBaseUrls.contains(base)) return base;
    }
    return _streamAddons.first['baseUrl'] as String;
  }

  List<String> get _stremioAddonBaseUrlsInOrder => [
    for (final a in _streamAddons)
      if (a['baseUrl'] is String) a['baseUrl'] as String,
  ];

  /// Move Stremio provider chip off a failed/empty addon when another has rows.
  void _syncStremioProviderSelection() {
    if (_panelKindFilter != 'stremio') return;
    final next = promoteStremioProviderId(
      currentId: _selectedSourceId,
      preferredId: null,
      addonBaseUrlsInOrder: _stremioAddonBaseUrlsInOrder,
      loadedIds: _loadedAddonBaseUrls,
      completedIds: _completedAddonBaseUrls,
      fetching: _isStremioFetching,
      userPicked: _userPickedStremioProvider,
    );
    if (next != null) _selectedSourceId = next;
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
      DomainStreamProviderResolver.cancelAllPending(cancelEngineJobs: false);
    }
    if (_isEngineFetching) {
      _engineFetchGen++;
      EngineService.instance.cancelPending();
    }
    _isSearching = false;
    _isStremioFetching = false;
    _isNuvioFetching = false;
    _isEngineFetching = false;
    _allTorrentResults = [];
    _torrentFetchedProviderIds.clear();
    _torrentInFlightProviderIds.clear();
    _stremioStreams = [];
    _allCombinedStremioStreams = [];
    _loadedAddonBaseUrls.clear();
    _completedAddonBaseUrls.clear();
    _userPickedStremioProvider = false;
    _nuvioStreams = [];
    _nuvioFetchedScraperIds = {};
    _nuvioInFlightScraperIds.clear();
    _nuvioPoolTasks.clear();
    _engineStreams = [];
    _engineFetchedPluginIds = {};
    _engineInFlightPluginIds.clear();
    _enginePoolTasks.clear();
    _engineDiscardPluginIds.clear();
    _nuvioDiscardScraperIds.clear();
    // Keep scraper chip selection - persisted preference, not per-title.
    _errorMessage = null;
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
    if (_panelShowEngine && _panelKindFilter == EngineIds.kind) {
      unawaited(_ensureEnginePanelLoaded(force: force));
    }
  }

  void _ensureTorrentsPanelLoaded({bool force = false}) {
    if (_panelKindFilter != 'torrents') return;
    if (force) {
      _autoSearch(force: true);
      return;
    }
    if (_isSearching) return;
    final cached = CatalogSourcesSessionCache.readTorrents(_catalogCacheKey);
    if (cached != null && _allTorrentResults.isEmpty) {
      setState(() {
        _allTorrentResults = cached;
        TorrentSearchProviders.addFetchedFromResultSources(
          _torrentFetchedProviderIds,
          cached.map((r) => r.source),
        );
        _errorMessage = null;
      });
      unawaited(_sortResults());
    }
    _autoSearch();
  }

  Future<void> _refreshStreamAddons() async {
    try {
      final addons = await _stremio.getAddonsForResource('stream');
      if (!mounted) return;
      if (addons.length == _streamAddons.length &&
          addons.every((a) {
            final id = a['baseUrl']?.toString();
            return id != null &&
                _streamAddons.any((b) => b['baseUrl']?.toString() == id);
          })) {
        return;
      }
      setState(() {
        _streamAddons = addons;
        if (_panelKindFilter == 'stremio' &&
            !_streamAddons.any(
              (a) => a['baseUrl']?.toString() == _selectedSourceId,
            )) {
          _userPickedStremioProvider = false;
          _selectedSourceId = '';
        }
      });
    } catch (_) {}
  }

  void _ensureStremioPanelLoaded({bool force = false}) {
    if (_panelKindFilter != 'stremio') return;
    // Re-read installs when opening/reloading - Settings installs after details
    // open used to leave the chip strip empty until remount.
    unawaited(
      _refreshStreamAddons().then((_) {
        if (!mounted || _panelKindFilter != 'stremio') return;
        if (force) {
          _fetchStremioStreams(refresh: true);
          return;
        }
        if (_isStremioFetching) return;
        final cached = CatalogSourcesSessionCache.readStremio(_catalogCacheKey);
        // Empty cache is a miss - a prior all-failed fetch must not block YTS.
        if (cached != null && cached.isNotEmpty) {
          setState(() {
            _allCombinedStremioStreams = cached;
            _loadedAddonBaseUrls
              ..clear()
              ..addAll({
                for (final s in cached)
                  if (s['_addonBaseUrl'] is String)
                    s['_addonBaseUrl'] as String,
              });
            _completedAddonBaseUrls
              ..clear()
              ..addAll(_loadedAddonBaseUrls);
            _errorMessage = null;
            _userPickedStremioProvider = false;
            _syncStremioProviderSelection();
            _applyStremioFilter();
          });
        } else if (cached != null && cached.isEmpty) {
          CatalogSourcesSessionCache.invalidate(
            _catalogCacheKey,
            kind: 'stremio',
          );
        }
        if (_selectedSourceId.isNotEmpty) {
          _fetchStremioStreams();
        }
      }),
    );
  }

  /// Loads addon metadata, then fetches selected scrapers in batches of 5.
  Future<void> _ensureNuvioPanelLoaded({bool force = false}) async {
    await _checkAndFetchNuvio();
    if (!mounted || !_panelShowNuvio) return;
    if (_panelKindFilter != 'nuvio') return;
    if (_nuvioSelectedScraperIds.isEmpty) return;
    if (force) {
      await _fetchNextNuvioScraper(refresh: true);
      return;
    }
    if (_isNuvioFetching) return;
    if (_nuvioStreams.isEmpty) {
      final cached = CatalogSourcesSessionCache.readNuvio(_catalogCacheKey);
      if (cached != null) {
        setState(() {
          _nuvioStreams = cached.streams;
          _nuvioFetchedScraperIds = cached.fetchedScraperIds;
          _errorMessage = null;
        });
      }
    }
    if (_pendingNuvioScraperIds.isNotEmpty) {
      await _fetchNextNuvioScraper();
    }
  }

  Future<void> _ensureEnginePanelLoaded({bool force = false}) async {
    await _checkAndFetchEngine();
    if (!mounted || !_panelShowEngine) return;
    if (_panelKindFilter != EngineIds.kind) return;
    if (_engineSelectedPluginIds.isEmpty) return;
    if (force) {
      await _fetchNextEnginePlugin(refresh: true);
      return;
    }
    if (_isEngineFetching) return;
    if (_engineStreams.isEmpty) {
      final cached = CatalogSourcesSessionCache.readEngine(_catalogCacheKey);
      if (cached != null) {
        setState(() {
          _engineStreams = cached.streams;
          _engineFetchedPluginIds = cached.fetchedPluginIds;
          _errorMessage = null;
        });
      }
    }
    if (_pendingEnginePluginIds.isNotEmpty) {
      await _fetchNextEnginePlugin();
    }
  }

  void _reloadPanelKind(String kind) {
    // Reload only the opened kind - never prefetch a hidden category.
    if (kind != _panelKindFilter) return;
    switch (kind) {
      case 'torrents':
        _ensureTorrentsPanelLoaded(force: true);
      case 'stremio':
        _ensureStremioPanelLoaded(force: true);
      case 'nuvio':
        unawaited(_ensureNuvioPanelLoaded(force: true));
      case 'engine':
        unawaited(_ensureEnginePanelLoaded(force: true));
    }
  }

  /// Stop in-flight work for kinds that are no longer selected so they cannot
  /// finish/cache in the background. Incomplete rows are dropped.
  void _abortHiddenKindFetches(String keepKind) {
    if (keepKind != 'torrents' && _isSearching) {
      _torrentSearchGen++;
      _isSearching = false;
      _allTorrentResults = [];
      _torrentFetchedProviderIds.clear();
      _torrentInFlightProviderIds.clear();
    }
    if (keepKind != 'stremio' && _isStremioFetching) {
      _stremioFetchGen++;
      _isStremioFetching = false;
      _allCombinedStremioStreams = [];
      _stremioStreams = [];
      _loadedAddonBaseUrls.clear();
      _completedAddonBaseUrls.clear();
    }
    if (keepKind != 'nuvio' && _isNuvioFetching) {
      _nuvioAbortWork(clearFetched: true);
      _nuvioStreams = [];
    }
    if (keepKind != EngineIds.kind && _isEngineFetching) {
      _engineAbortWork(clearFetched: true);
      _engineStreams = [];
    }
  }

  void _onPanelKindFilterChanged(String kind) {
    setState(() {
      _stashPanelSourceIdForKind(_panelKindFilter);
      _abortHiddenKindFetches(kind);
      _panelKindFilter = kind;
      _errorMessage = null;
      _restorePanelSourceIdForKind(kind);
    });
    if (_sourcesListScrollController.hasClients) {
      _sourcesListScrollController.jumpTo(0);
    }
    _ensurePanelSourceLoaded();
  }

  /// Prefetch Sources chrome (addon/plugin chip lists) for enabled play sources.
  /// Does not start torrent/stream scrapes — those still wait on kind/chip tap.
  Future<void> _warmSourcesPanelChrome({bool force = false}) {
    if (force) _sourcesChromeWarm = null;
    final existing = _sourcesChromeWarm;
    if (existing != null) return existing;
    final future = _warmSourcesPanelChromeBody();
    _sourcesChromeWarm = future;
    return future;
  }

  Future<void> _warmSourcesPanelChromeBody() async {
    final tasks = <Future<void>>[];
    if (_playSourceStremio) {
      tasks.add(
        _stremio.getAddonsForResource('stream').then(
          _applyStreamAddons,
          onError: (_) {},
        ),
      );
    }
    if (_playSourceNuvio) {
      tasks.add(_checkAndFetchNuvio());
    }
    if (_playSourceEngine) {
      tasks.add(_checkAndFetchEngine());
    }
    if (tasks.isEmpty) return;
    await Future.wait(tasks);
  }

  void _openSourcesPanel() {
    if (!_hasPanelPlaySources) return;
    unawaited(() async {
      await _warmSourcesPanelChrome();
      if (!mounted || !_hasPanelPlaySources) return;
      _captureSourcesPanelReturnFocus();
      setState(() {
        _syncPanelKindFilterToPlaySources();
        _focusPanelOnPlayingSource();
        _sourcesPanelOpen = true;
      });
      _ensurePanelSourceLoaded();
    }());
  }

  /// Close Sources and stop any in-flight Torrents / Stremio / Nuvio fetches.
  ///
  /// Pass [cancelEngineJobs]: false when closing to start playback so the
  /// magnet resolve is not aborted by [Engine.cancelPendingResolve].
  void _closeSourcesPanel({
    bool cancelEngineJobs = true,
    bool restoreTvPlayFocus = false,
  }) {
    if (!_sourcesPanelOpen &&
        !_isSearching &&
        !_isStremioFetching &&
        !_isNuvioFetching &&
        !_isEngineFetching) {
      return;
    }
    _cancelActiveSourceFetch(cancelEngineJobs: cancelEngineJobs);
    if (_sourcesPanelOpen && mounted) {
      setState(() => _sourcesPanelOpen = false);
      if (restoreTvPlayFocus) {
        _restoreTvFocusAfterSourcesPanel();
      } else {
        _sourcesPanelReturnFocus = null;
      }
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
