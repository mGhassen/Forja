import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/utils/extensions.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'stremio_catalog_screen.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/widgets/movie_atmosphere.dart';
import 'package:forja/shared/widgets/home_movie_row.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/media_details/media_details_torrent_action_row.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_filters.dart';
import 'package:forja/shared/widgets/media_details_hero.dart';
import 'package:forja/shared/widgets/media_details_cast_section.dart';
import 'package:forja/shared/widgets/media_details_trailers_section.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shared/navigation/back_navigation_scope.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shared/design/design.dart' hide AppTheme;
import 'package:forja/shared/theme/app_theme.dart';

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
  const DetailsScreen({super.key, required this.movie, this.stremioItem, this.initialSeason, this.initialEpisode, this.startPosition});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> with AtmosphereMixin {
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
  List<TorrentResult> _allTorrentResults = [];
  bool _isSearching = false;
  int _torrentSearchGen = 0;
  int _stremioFetchGen = 0;
  String? _errorMessage;
  Map<String, dynamic>? _lastProgress;
  bool _sourcesPanelOpen = false;

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
  final ScrollController _seasonScrollController = ScrollController();
  final ScrollController _chipsScrollController = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  // MDBlist aggregated ratings
  Map<String, dynamic>? _mdblistRatings;
  // User's Trakt rating (1-10, null if not rated)
  int? _userTraktRating;
  // User's Simkl rating (1-10, null if not rated)
  int? _userSimklRating;
  // Trakt collection status
  bool _isInTraktCollection = false;

  // ─── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    if (widget.initialSeason != null) _selectedSeason = widget.initialSeason!;
    if (widget.initialEpisode != null) _selectedEpisode = widget.initialEpisode!;
    // Start atmosphere color extraction
    final url = (_movie.posterPath.isNotEmpty ? _movie.posterPath : _movie.backdropPath);
    loadAtmosphere(url.startsWith('http') ? url : TmdbApi.getImageUrl(url));
    _checkHistory();
    _loadSortPreference();
    _checkIndexerConfiguration();
    _loadWatchedEpisodes();
    _fetchDetails();
    _fetchExternalRatings();
    _fetchUserTraktRating();
    _fetchUserSimklRating();
    _fetchTraktCollectionStatus();
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _episodeScrollController.dispose();
    _seasonScrollController.dispose();
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

  void _onEpisodeSelected(int episode) {
    setState(() => _selectedEpisode = episode);
    _checkHistory();
    _refreshSourcesForEpisode();
  }

  void _onSeasonSelected(int season) {
    if (widget.stremioItem != null &&
        _seasonData != null &&
        _seasonData!['episodesBySeason'] != null) {
      setState(() {
        _selectedSeason = season;
        _selectedEpisode = 1;
      });
      _fetchStremioStreamsForCustomId(widget.stremioItem!);
      _checkHistory();
      _loadEpisodeProgressForSeason(season);
      return;
    }
    _fetchSeason(season);
  }

  Widget _buildDetailsHero({required double heroHeight}) {
    return MediaDetailsHero(
      movie: _movie,
      trailerYoutubeKey: _trailerKey,
      trailerLanguageCode: _originalLanguage,
      progress: _lastProgress,
      height: heroHeight,
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
    final scores = r['scores'] as List<dynamic>? ?? r['ratings'] as List<dynamic>? ?? [];
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
    final hasResume = _lastProgress != null &&
        ((_lastProgress!['position'] as int? ?? 0) > 0);
    return MediaDetailsTorrentActionRow(
      movie: _movie,
      hasResume: hasResume,
      onOpenSources: () => setState(() => _sourcesPanelOpen = true),
      onOverflowAction: _handleHeroOverflowAction,
      userTraktRating: _userTraktRating,
      userSimklRating: _userSimklRating,
      isInTraktCollection: _isInTraktCollection,
    );
  }

  Future<void> _handleHeroOverflowAction(String value) async {
    switch (value) {
      case 'trakt_rate':
        if (await TraktService().isLoggedIn()) {
          _showRatingDialog();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login to Trakt first in Settings')));
        }
      case 'simkl_rate':
        if (await SimklService().isLoggedIn()) {
          _showSimklRatingDialog();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login to Simkl first in Settings')));
        }
      case 'collect':
        await _toggleTraktCollection();
      case 'checkin':
        await _traktCheckin();
      case 'trakt_list':
        await _addToTraktList();
    }
  }

  Widget _buildTvPicker() {
    int seasonCount = _movie.numberOfSeasons;
    if (_seasonData != null && _seasonData!['seasons'] != null) {
      seasonCount = (_seasonData!['seasons'] as List).length;
    }
    Map<int, List<Map<String, dynamic>>>? customEpisodes;
    if (_seasonData != null && _seasonData!['episodesBySeason'] != null) {
      customEpisodes = Map<int, List<Map<String, dynamic>>>.from(
        (_seasonData!['episodesBySeason'] as Map).map(
          (k, v) => MapEntry(k as int, List<Map<String, dynamic>>.from(v as List)),
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
      onToggleWatched: _toggleEpisodeWatched,
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

  /// Returns every audio tag found in [name] (upper-cased for matching).
  static List<String> _detectAudioTags(String name) {
    final n = name.toUpperCase();
    final found = <String>[];
    // Order matters – more specific tags must be checked before their substrings
    if (n.contains('ATMOS')) found.add('Atmos');
    if (n.contains('TRUEHD')) found.add('TrueHD');
    if (n.contains('DTS:X') || n.contains('DTSX')) found.add('DTS:X');
    if (!found.contains('DTS:X') && (n.contains('DTS-HD') || n.contains('DTSHD'))) found.add('DTS-HD');
    if (!found.contains('DTS:X') && !found.contains('DTS-HD') && n.contains('DTS')) found.add('DTS');
    if (n.contains('DD+') || n.contains('EAC3') || n.contains('E-AC-3') || n.contains('DDPLUS')) found.add('DD+');
    if (!found.contains('DD+') && (n.contains(' DD ') || n.contains('AC3') || n.contains('DOLBY DIGITAL'))) found.add('DD');
    if (n.contains('AAC')) found.add('AAC');
    if (n.contains('7.1')) found.add('7.1');
    if (!found.contains('7.1') && n.contains('5.1')) found.add('5.1');
    if (n.contains(' 2.0') || n.contains('.2.0')) found.add('2.0');
    return found;
  }

  /// Torrent results after applying the active audio filters.
  List<TorrentResult> get _filteredTorrentResults {
    if (_activeAudioFilters.isEmpty) return _allTorrentResults;
    return _allTorrentResults.where((r) {
      final tags = _detectAudioTags(r.name);
      // Show the result if it matches ANY of the selected tags
      return tags.any((t) => _activeAudioFilters.contains(t));
    }).toList();
  }

  Future<void> _checkIndexerConfiguration() async {
    final jackettConfigured = await _settings.isJackettConfigured();
    final prowlarrConfigured = await _settings.isProwlarrConfigured();
    if (mounted) {
      setState(() {
        _isJackettConfigured = jackettConfigured;
        _isProwlarrConfigured = prowlarrConfigured;
      });
    }
  }

  String _getHash(String magnet) {
    if (magnet.startsWith('magnet:?xt=urn:btih:')) {
      final parts = magnet.split('magnet:?xt=urn:btih:')[1].split('&');
      if (parts.isNotEmpty) return parts[0].toLowerCase();
    }
    return magnet.toLowerCase();
  }

  Future<void> _sortResults() async {
    if (_allTorrentResults.isEmpty) return;
    final sorted = (await Engine.sortTorrents(
      _allTorrentResults.map((e) => e.toJson()).toList(),
      _sortPreference,
    )).map(TorrentResult.fromJson).toList();
    if (_lastProgress != null && _lastProgress!['method'] == 'torrent') {
      final historyHash = _getHash(_lastProgress!['sourceId']);
      final index = sorted.indexWhere((r) => _getHash(r.magnet) == historyHash);
      if (index != -1) {
        final match = sorted.removeAt(index);
        sorted.insert(0, match);
      }
    }
    if (mounted) setState(() => _allTorrentResults = sorted);
  }

  Future<void> _fetchDetails() async {
    final stremioItem = widget.stremioItem;
    final bool isCustomId = stremioItem != null &&
        !(stremioItem['id']?.toString().startsWith('tt') ?? true);

    try {
      final streamAddons = await _stremio.getAddonsForResource('stream');

      // If this is a custom-ID Stremio item, skip TMDB fetch — we already
      // have all the info we need from the search result.
      if (isCustomId) {
        debugPrint('[DetailsScreen] Custom ID detected: ${stremioItem['id']}');
        debugPrint('[DetailsScreen] stremioItem keys: ${stremioItem.keys.toList()}');
        debugPrint('[DetailsScreen] _addonBaseUrl: ${stremioItem['_addonBaseUrl']}');
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
        await _fetchSeason(widget.initialSeason ?? 1);
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
          if (!_playbackProfile.builtinTorrentSearch && streamAddons.isNotEmpty) {
            _selectedSourceId = streamAddons.length > 1
                ? 'all_stremio'
                : streamAddons.first['baseUrl'] as String;
          }
        });
        if (_playbackProfile.builtinTorrentSearch) _autoSearch();
        _fetchAllStremioStreams();
        _checkAndFetchNuvio();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Probes installed Nuvio addons and exposes the "Nuvio Addons" tab if
  /// any are enabled. Does NOT kick off scraping — that happens lazily
  /// when the user actually clicks an addon → a scraper.
  Future<void> _checkAndFetchNuvio() async {
    try {
      final addons = await NuvioService.instance.listUserAddons();
      final hasEnabled = addons.any((a) => a.scrapers.any((s) => s.enabled));
      if (!mounted) return;
      setState(() {
        _hasNuvioAddons = hasEnabled;
        _nuvioAddons = addons.where((a) =>
            a.scrapers.any((s) => s.enabled)).toList();
      });
    } catch (_) {}
  }

  Future<void> _fetchExternalRatings() async {
    try {
      if (!await MdblistService().isConfigured()) return;
      Map<String, dynamic>? ratings;
      if (_movie.imdbId != null && _movie.imdbId!.isNotEmpty) {
        ratings = await MdblistService().getRatingsByImdb(_movie.imdbId!);
      } else {
        ratings = await MdblistService().getRatingsByTmdb(
          _movie.id, _movie.mediaType == 'tv' ? 'show' : 'movie');
      }
      if (mounted && ratings != null) setState(() => _mdblistRatings = ratings);
    } catch (_) {}
  }

  Future<void> _fetchUserTraktRating() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      final type = _movie.mediaType == 'tv' ? 'shows' : 'movies';
      final allRatings = await TraktService().getAllRatings();
      final ratings = allRatings[type] as List? ?? [];
      for (final r in ratings) {
        final show = r['show'] ?? r['movie'];
        if (show != null) {
          final ids = show['ids'] as Map<String, dynamic>?;
          if (ids != null && ids['tmdb'] == _movie.id) {
            if (mounted) setState(() => _userTraktRating = r['rating'] as int?);
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _rateTraktItem(int rating) async {
    final success = await TraktService().rateItem(
      tmdbId: _movie.id,
      mediaType: _movie.mediaType,
      rating: rating,
    );
    if (success && mounted) setState(() => _userTraktRating = rating);
  }

  Future<void> _removeTraktRating() async {
    final success = await TraktService().removeRating(
      tmdbId: _movie.id,
      mediaType: _movie.mediaType,
    );
    if (success && mounted) setState(() => _userTraktRating = null);
  }

  // ─── Simkl rating ─────────────────────────────────────────────────────────

  Future<void> _fetchUserSimklRating() async {
    try {
      if (!await SimklService().isLoggedIn()) return;
      final ratings = await SimklService().getRatings();
      for (final r in ratings) {
        final ids = r['ids'] as Map<String, dynamic>? ?? {};
        if (ids['tmdb'] == _movie.id) {
          if (mounted) setState(() => _userSimklRating = r['rating'] as int?);
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _rateSimklItem(int rating) async {
    final success = await SimklService().addRating(
      tmdbId: _movie.id,
      mediaType: _movie.mediaType,
      rating: rating,
    );
    if (success && mounted) setState(() => _userSimklRating = rating);
  }

  Future<void> _removeSimklRating() async {
    final success = await SimklService().removeRating(
      tmdbId: _movie.id,
      mediaType: _movie.mediaType,
    );
    if (success && mounted) setState(() => _userSimklRating = null);
  }

  void _showSimklRatingDialog() {
    int selected = _userSimklRating ?? 5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text('Rate on Simkl', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(10, (i) {
                  final val = i + 1;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selected = val),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(
                        val <= selected ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFF0BF5E5),
                        size: 28,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text('$selected / 10',
                style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            if (_userSimklRating != null)
              TextButton(
                onPressed: () { Navigator.pop(ctx); _removeSimklRating(); },
                child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () { Navigator.pop(ctx); _rateSimklItem(selected); },
              child: const Text('Rate', style: TextStyle(color: Color(0xFF0BF5E5))),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Trakt collection ─────────────────────────────────────────────────────

  Future<void> _fetchTraktCollectionStatus() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      final collection = await TraktService().getCollection();
      final type = _movie.mediaType == 'tv' ? 'shows' : 'movies';
      final items = collection[type] as List? ?? [];
      for (final item in items) {
        final media = item['show'] ?? item['movie'];
        if (media != null) {
          final ids = media['ids'] as Map<String, dynamic>? ?? {};
          if (ids['tmdb'] == _movie.id) {
            if (mounted) setState(() => _isInTraktCollection = true);
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleTraktCollection() async {
    if (!await TraktService().isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to Trakt first in Settings')));
      return;
    }
    if (_isInTraktCollection) {
      final success = await TraktService().removeFromCollection(
        tmdbId: _movie.id,
        mediaType: _movie.mediaType,
      );
      if (success && mounted) setState(() => _isInTraktCollection = false);
    } else {
      final success = await TraktService().addToCollection(
        tmdbId: _movie.id,
        mediaType: _movie.mediaType,
      );
      if (success && mounted) setState(() => _isInTraktCollection = true);
    }
  }

  // ─── Trakt check-in ───────────────────────────────────────────────────────

  Future<void> _traktCheckin() async {
    if (!await TraktService().isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to Trakt first in Settings')));
      return;
    }
    final success = await TraktService().checkin(
      tmdbId: _movie.id,
      mediaType: _movie.mediaType,
      season: _movie.mediaType == 'tv' ? _selectedSeason : null,
      episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checked in on Trakt!')),
      );
    } else {
      // Offer to cancel existing check-in and retry
      final shouldCancel = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text('Check-in Failed', style: TextStyle(color: Colors.white)),
          content: const Text(
            'You may already have an active check-in.\nCancel existing and retry?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, retry')),
          ],
        ),
      );
      if (shouldCancel == true && mounted) {
        final cancelled = await TraktService().cancelCheckin();
        if (cancelled && mounted) {
          final retrySuccess = await TraktService().checkin(
            tmdbId: _movie.id,
            mediaType: _movie.mediaType,
            season: _movie.mediaType == 'tv' ? _selectedSeason : null,
            episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(retrySuccess ? 'Checked in on Trakt!' : 'Check-in failed')),
          );
        }
      }
    }
  }

  // ─── Trakt add to list ────────────────────────────────────────────────────

  Future<void> _addToTraktList() async {
    if (!await TraktService().isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to Trakt first in Settings')));
      return;
    }
    final lists = await TraktService().getUserLists();
    if (!mounted || lists.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Trakt lists found. Create one in Lists screen.')));
      }
      return;
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Add to Trakt List', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: lists.length,
            itemBuilder: (_, i) {
              final list = lists[i];
              final name = list['name']?.toString() ?? 'Untitled';
              final count = list['item_count'] ?? 0;
              return ListTile(
                title: Text(name, style: const TextStyle(color: Colors.white)),
                subtitle: Text('$count items', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, list),
              );
            },
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final slug = selected['ids']?['slug']?.toString() ?? '';
    if (slug.isEmpty) return;

    final type = _movie.mediaType == 'tv' ? 'shows' : 'movies';
    final entry = <String, dynamic>{'ids': {'tmdb': _movie.id}};
    final success = await TraktService().addToList(
      listId: slug,
      movies: type == 'movies' ? [entry] : [],
      shows: type == 'shows' ? [entry] : [],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success
        ? 'Added to "${selected['name']}"'
        : 'Failed to add to list')),
    );
  }

  void _showRatingDialog() {
    int selected = _userTraktRating ?? 5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text('Rate on Trakt', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(10, (i) {
                  final val = i + 1;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selected = val),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(
                        val <= selected ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFFFD700),
                        size: 28,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text('$selected / 10',
                style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            if (_userTraktRating != null)
              TextButton(
                onPressed: () { Navigator.pop(ctx); _removeTraktRating(); },
                child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () { Navigator.pop(ctx); _rateTraktItem(selected); },
              child: const Text('Rate', style: TextStyle(color: Color(0xFF00E5FF))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRecommendation(Map<String, dynamic> rec) async {
    final id = rec['id']?.toString() ?? '';
    final type = rec['type']?.toString() ?? 'movie';

    // Try TMDB lookup first for IMDB IDs
    if (id.startsWith('tt')) {
      try {
        final movie = await _api.findByImdbId(id, mediaType: type == 'series' ? 'tv' : 'movie');
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
          posterPath: '', backdropPath: '', voteAverage: 0,
          releaseDate: '', overview: '',
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
          if (poster != null && poster.isNotEmpty) {
            _seasonPosters[seasonNumber] = poster;
          }
          // Only reset to episode 1 if no initial episode was provided,
          // or if we're navigating to a different season after init.
          if (widget.initialEpisode != null && seasonNumber == widget.initialSeason) {
            _selectedEpisode = widget.initialEpisode!;
          } else {
            _selectedEpisode = 1;
          }
        });
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
  /// Stops in-flight torrent / Stremio / Nuvio fetches on the details tab.
  void _cancelActiveSourceFetch() {
    var changed = false;
    if (_isSearching) {
      _torrentSearchGen++;
      _isSearching = false;
      changed = true;
    }
    if (_isStremioFetching) {
      _stremioFetchGen++;
      _isStremioFetching = false;
      changed = true;
    }
    if (_isNuvioFetching) {
      NuvioService.instance.cancelPending();
      _nuvioSub?.cancel();
      _nuvioSub = null;
      _isNuvioFetching = false;
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _fetchAllStremioStreams() async {
    if (_streamAddons.isEmpty) return;
    final gen = ++_stremioFetchGen;
    setState(() {
      _isStremioFetching = true;
      _errorMessage = null;
      _allCombinedStremioStreams = [];
      _loadedAddonBaseUrls.clear();
      if (_selectedSourceId == 'all_stremio') _stremioStreams = [];
    });
    try {
      String stremioId = _movie.imdbId ?? '';
      if (stremioId.isEmpty) {
        if (mounted && gen == _stremioFetchGen) {
          setState(() => _isStremioFetching = false);
        }
        return;
      }
      if (_movie.mediaType == 'tv') stremioId = '$stremioId:$_selectedSeason:$_selectedEpisode';
      final type = _movie.mediaType == 'tv' ? 'series' : 'movie';

      int pendingCount = _streamAddons.length;

      void completeOne() {
        if (!mounted || gen != _stremioFetchGen) return;
        pendingCount--;
        if (pendingCount <= 0) {
          setState(() {
            _isStremioFetching = false;
            if (_allCombinedStremioStreams.isEmpty &&
                _selectedSourceId == 'all_stremio') {
              _errorMessage = 'No streams found from any addon';
            }
          });
        }
      }

      for (final addon in _streamAddons) {
        _stremio.getStreams(baseUrl: addon['baseUrl'], type: type, id: stremioId).then((streams) {
          if (!mounted || gen != _stremioFetchGen) return;
          final tagged = _filterStremioStreams(streams.map((s) {
            if (s is Map<String, dynamic>) {
              return <String, dynamic>{
                ...s,
                '_addonName': addon['name'] ?? 'Unknown',
                '_addonBaseUrl': addon['baseUrl'],
              };
            }
            return <String, dynamic>{'_addonName': addon['name'], '_addonBaseUrl': addon['baseUrl']};
          }).toList());

          setState(() {
            // Only show chip if addon returned results
            if (tagged.isNotEmpty) {
              _loadedAddonBaseUrls.add(addon['baseUrl'] as String);
            }
            // Append below existing results
            _allCombinedStremioStreams.addAll(tagged);
            if (_selectedSourceId == 'all_stremio' ||
                _selectedSourceId == addon['baseUrl']) {
              _applyStremioFilter();
            }
          });
        }).catchError((_) {
          // No-op: don't show chip for errored addons
        }).whenComplete(() {
          completeOne();
        });
      }
    } catch (e) {
      if (mounted && gen == _stremioFetchGen) {
        setState(() { _errorMessage = 'Error: $e'; _isStremioFetching = false; });
      }
    }
  }

  /// Runs ONE Nuvio scraper on demand and replaces `_nuvioStreams` with its
  /// results. Triggered when the user taps a scraper chip — keeps the
  /// details page snappy by avoiding the parallel-everything fetch.
  Future<void> _runSingleNuvioScraper(String scraperId) async {
    if (_movie.id <= 0) return;
    await _nuvioSub?.cancel();
    _nuvioSub = null;
    setState(() {
      _isNuvioFetching = true;
      _nuvioStreams = [];
      _errorMessage = null;
    });
    final type = _movie.mediaType == 'tv' ? 'tv' : 'movie';
    try {
      final results = await NuvioService.instance.runOneScraper(
        scraperId: scraperId,
        tmdbId: _movie.id.toString(),
        type: type,
        season: _movie.mediaType == 'tv' ? _selectedSeason : null,
        episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
      );
      if (!mounted) return;
      // Resolve the human-readable scraper name for tagging.
      String scraperName = scraperId;
      for (final a in _nuvioAddons) {
        for (final s in a.scrapers) {
          if (s.id == scraperId) { scraperName = s.name; break; }
        }
      }
      setState(() {
        _nuvioStreams = results
            .map((r) => <String, dynamic>{
                  ...r.toStremioStream(sourceLabel: scraperName),
                  '_addonName': scraperName,
                  '_addonBaseUrl': 'nuvio:$scraperId',
                })
            .toList();
        _isNuvioFetching = false;
        _errorMessage = _nuvioStreams.isEmpty
            ? 'No streams found from $scraperName'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isNuvioFetching = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  /// Fetches streams from every enabled Nuvio scraper in parallel and
  /// appends results in real time as each scraper completes — so chips and
  /// streams light up the UI progressively instead of waiting for the
  /// slowest provider. Re-entrant: a fresh call cancels the previous
  /// subscription and resets the visible list.
  Future<void> _fetchAllNuvioStreams() async {
    if (!_hasNuvioAddons || _movie.id <= 0) return;
    // Tear down any previous in-flight stream — e.g. user switched
    // season/episode mid-fetch.
    await _nuvioSub?.cancel();
    _nuvioSub = null;
    setState(() {
      _isNuvioFetching = true;
      _nuvioStreams = [];
      if (_selectedSourceId == 'all_nuvio') _errorMessage = null;
    });
    final type = _movie.mediaType == 'tv' ? 'tv' : 'movie';
    final stream = NuvioService.instance.streamAll(
      tmdbId: _movie.id.toString(),
      type: type,
      season: _movie.mediaType == 'tv' ? _selectedSeason : null,
      episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
    );
    _nuvioSub = stream.listen(
      (batch) {
        if (!mounted) return;
        if (batch.streams.isEmpty) return; // failed/empty scrapers add nothing
        setState(() {
          _nuvioStreams.addAll(batch.streams.map((s) => <String, dynamic>{
                ...s,
                '_addonName': s['sourceName'] ?? batch.scraperName,
                '_addonBaseUrl':
                    'nuvio://${s['sourceName'] ?? batch.scraperId}',
              }));
          if (_selectedSourceId == 'all_nuvio') _errorMessage = null;
        });
      },
      onError: (e) {
        debugPrint('[DetailsScreen] Nuvio stream error: $e');
      },
      onDone: () {
        _nuvioSub = null;
        if (!mounted) return;
        setState(() {
          _isNuvioFetching = false;
          if (_selectedSourceId == 'all_nuvio' && _nuvioStreams.isEmpty) {
            _errorMessage = 'No streams found from any Nuvio addon';
          }
        });
      },
      cancelOnError: false,
    );
  }

  /// Fetches streams using the custom Stremio ID from the originating addon.
  Future<void> _fetchStremioStreamsForCustomId(Map<String, dynamic> item) async {
    final customId = item['id']?.toString() ?? '';
    final addonBaseUrl = item['_addonBaseUrl']?.toString() ?? '';
    final addonName = item['_addonName']?.toString() ?? 'Unknown';
    final type = item['type']?.toString() ?? (_movie.mediaType == 'tv' ? 'series' : 'movie');
    debugPrint('[CustomIdStreams] customId=$customId, addonBaseUrl=$addonBaseUrl, type=$type');
    if (customId.isEmpty || addonBaseUrl.isEmpty) {
      debugPrint('[CustomIdStreams] SKIPPED: customId empty=${customId.isEmpty}, addonBaseUrl empty=${addonBaseUrl.isEmpty}');
      return;
    }

    final gen = ++_stremioFetchGen;
    setState(() { _isStremioFetching = true; _errorMessage = null; _stremioStreams = []; _allCombinedStremioStreams = []; _loadedAddonBaseUrls.clear(); });
    
    try {
      if (type == 'collections') {
        final meta = await _stremio.getMeta(baseUrl: addonBaseUrl, type: type, id: customId);
        if (!mounted || gen != _stremioFetchGen) return;
        if (meta != null && meta['videos'] != null) {
          final videos = meta['videos'] as List;
          debugPrint('[CustomIdStreams] Got ${videos.length} collection items from meta');
          
          // Parse videos to build collection structure
          _parseCollectionVideos(videos);
          
          // Collections don't have streams - they're just containers for other content
          // The UI will display the collection items and allow navigation to them
          if (mounted && gen == _stremioFetchGen) {
            setState(() {
              _isStremioFetching = false;
              _errorMessage = null;
            });
          }
          return;
        }
      }
      
      if (type == 'series') {
        final meta = await _stremio.getMeta(baseUrl: addonBaseUrl, type: type, id: customId);
        if (!mounted || gen != _stremioFetchGen) return;
        if (meta != null && meta['videos'] != null) {
          final videos = meta['videos'] as List;
          debugPrint('[CustomIdStreams] Got ${videos.length} videos from meta');
          
          // Parse videos to build season/episode structure
          _parseCustomIdVideos(videos);
          
          // Now fetch streams for the selected episode
          final selectedVideo = _getSelectedVideoFromCustomId(videos);
          if (selectedVideo != null) {
            final videoId = selectedVideo['id']?.toString() ?? '';
            debugPrint('[CustomIdStreams] Fetching streams for video: $videoId');
            final streams = await _stremio.getStreams(baseUrl: addonBaseUrl, type: type, id: videoId);
            debugPrint('[CustomIdStreams] Got ${streams.length} streams');
            
            if (!mounted || gen != _stremioFetchGen) return;
            final tagged = _filterStremioStreams(streams.map((s) {
              if (s is Map<String, dynamic>) {
                return <String, dynamic>{...s, '_addonName': addonName, '_addonBaseUrl': addonBaseUrl};
              }
              return <String, dynamic>{'_addonName': addonName, '_addonBaseUrl': addonBaseUrl};
            }).toList());
            setState(() {
              _stremioStreams = tagged;
              _allCombinedStremioStreams = tagged;
              _loadedAddonBaseUrls.add(addonBaseUrl);
              _isStremioFetching = false;
              if (streams.isEmpty) _errorMessage = 'No streams found';
            });
            return;
          }
        }
      }
      
      final streams = await _stremio.getStreams(baseUrl: addonBaseUrl, type: type, id: customId);
      debugPrint('[CustomIdStreams] Got ${streams.length} streams');
      if (streams.isNotEmpty) debugPrint('[CustomIdStreams] First stream: ${streams.first}');
      if (!mounted || gen != _stremioFetchGen) return;
      final tagged = _filterStremioStreams(streams.map((s) {
        if (s is Map<String, dynamic>) {
          return <String, dynamic>{...s, '_addonName': addonName, '_addonBaseUrl': addonBaseUrl};
        }
        return <String, dynamic>{'_addonName': addonName, '_addonBaseUrl': addonBaseUrl};
      }).toList());
      setState(() {
        _stremioStreams = tagged;
        _allCombinedStremioStreams = tagged;
        _loadedAddonBaseUrls.add(addonBaseUrl);
        _isStremioFetching = false;
        if (streams.isEmpty) _errorMessage = 'No streams found';
      });
    } catch (e) {
      if (mounted && gen == _stremioFetchGen) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isStremioFetching = false;
          _loadedAddonBaseUrls.add(addonBaseUrl);
        });
      }
    }
  }

  /// Parses the videos array from custom ID meta to build season/episode structure
  void _parseCustomIdVideos(List videos) {
    if (videos.isEmpty) return;
    
    // Build a map of seasons to episodes
    final Map<int, List<Map<String, dynamic>>> seasonMap = {};
    for (final video in videos) {
      if (video is! Map) continue;
      final season = video['season'] as int? ?? 1;
      final episode = video['episode'] as int? ?? 1;
      
      seasonMap.putIfAbsent(season, () => []);
      seasonMap[season]!.add({
        'id': video['id'],
        'title': video['title'] ?? 'Episode $episode',
        'episode': episode,
        'season': season,
        'thumbnail': video['thumbnail'],
        'released': video['released'],
      });
    }
    
    // Sort episodes within each season
    for (final episodes in seasonMap.values) {
      episodes.sort((a, b) => (a['episode'] as int).compareTo(b['episode'] as int));
    }
    
    // Store in _seasonData format compatible with existing UI
    if (mounted) {
      setState(() {
        _seasonData = {
          'seasons': seasonMap.keys.toList()..sort(),
          'episodesBySeason': seasonMap,
        };
        // Ensure selected season/episode are valid
        if (!seasonMap.containsKey(_selectedSeason)) {
          _selectedSeason = seasonMap.keys.first;
        }
        final episodes = seasonMap[_selectedSeason] ?? [];
        if (episodes.isEmpty || _selectedEpisode > episodes.length) {
          _selectedEpisode = episodes.isNotEmpty ? episodes.first['episode'] : 1;
        }
      });
    }
  }

  /// Parses the videos array from collection meta to build collection items list
  void _parseCollectionVideos(List videos) {
    if (videos.isEmpty) return;
    
    final List<Map<String, dynamic>> items = [];
    for (final video in videos) {
      if (video is! Map) continue;
      
      items.add({
        'id': video['id'],
        'title': video['title'] ?? 'Unknown',
        'thumbnail': video['thumbnail'],
        'released': video['released'],
        'ratings': video['ratings'],
        'overview': video['overview'],
      });
    }
    
    if (mounted) {
      setState(() {
        _collectionItems = items;
        _isCollection = true;
      });
    }
  }

  /// Gets the selected video from the custom ID videos array
  Map<String, dynamic>? _getSelectedVideoFromCustomId(List videos) {
    for (final video in videos) {
      if (video is! Map) continue;
      final season = video['season'] as int? ?? 1;
      final episode = video['episode'] as int? ?? 1;
      if (season == _selectedSeason && episode == _selectedEpisode) {
        return video as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Fetches streams from a single selected addon only.
  Future<void> _fetchStremioStreams() async {
    if (_selectedSourceId == 'all_stremio') {
      // "All" chip → just re-filter from cached results, or re-fetch if empty
      if (_allCombinedStremioStreams.isEmpty) {
        return _fetchAllStremioStreams();
      }
      setState(() { _stremioStreams = _allCombinedStremioStreams; _errorMessage = null; });
      return;
    }
    final addon = _streamAddons.firstWhere(
      (a) => a['baseUrl'] == _selectedSourceId,
      orElse: () => _streamAddons.isNotEmpty ? _streamAddons.first : <String, dynamic>{},);
    if (addon.isEmpty) return;
    final gen = ++_stremioFetchGen;
    setState(() { _isStremioFetching = true; _errorMessage = null; _stremioStreams = []; });
    try {
      String stremioId = _movie.imdbId ?? '';
      if (_movie.mediaType == 'tv') stremioId = '$stremioId:$_selectedSeason:$_selectedEpisode';
      final type = _movie.mediaType == 'tv' ? 'series' : 'movie';
      final streams = await _stremio.getStreams(baseUrl: addon['baseUrl'], type: type, id: stremioId);
      if (!mounted || gen != _stremioFetchGen) return;
      setState(() {
        _stremioStreams = _filterStremioStreams(streams);
        if (streams.isEmpty) _errorMessage = 'No streams found in ${addon['name']}';
      });
    } catch (e) {
      if (!mounted || gen != _stremioFetchGen) return;
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted && gen == _stremioFetchGen) {
        setState(() => _isStremioFetching = false);
      }
    }
  }

  /// Applies the current addon filter chip to _allCombinedStremioStreams.
  void _applyStremioFilter() {
    if (_selectedSourceId == 'all_stremio' || _isTorrentSource) {
      _stremioStreams = _allCombinedStremioStreams;
    } else {
      _stremioStreams = _allCombinedStremioStreams
          .where((s) => s['_addonBaseUrl'] == _selectedSourceId)
          .toList();
    }
  }

  Future<void> _searchTvTorrents(String seasonQuery, String episodeQuery) async {
    final gen = ++_torrentSearchGen;
    setState(() { _isSearching = true; _allTorrentResults = []; _errorMessage = null; });
    try {
      final results = await Future.wait([
        Engine.searchTorrents(seasonQuery).then(
            (list) => list.map(TorrentResult.fromJson).toList()),
        Engine.searchTorrents(episodeQuery).then(
            (list) => list.map(TorrentResult.fromJson).toList()),
      ]);
      if (!mounted || gen != _torrentSearchGen) return;
      final filteredSeason = (await Engine.filterTorrents(
        results[0].map((e) => e.toJson()).toList(),
        _movie.title,
        requiredSeason: _selectedSeason,
      )).map(TorrentResult.fromJson).toList();
      if (!mounted || gen != _torrentSearchGen) return;
      final filteredEpisode = (await Engine.filterTorrents(
        results[1].map((e) => e.toJson()).toList(),
        _movie.title,
        requiredSeason: _selectedSeason,
        requiredEpisode: _selectedEpisode,
      )).map(TorrentResult.fromJson).toList();
      final combined = <String, TorrentResult>{};
      for (var r in filteredEpisode) { combined[r.magnet] = r; }
      for (var r in filteredSeason) { combined[r.magnet] = r; }
      if (!mounted || gen != _torrentSearchGen) return;
      setState(() { _allTorrentResults = combined.values.toList(); _isSearching = false; });
      _sortResults();
    } catch (e) {
      if (mounted && gen == _torrentSearchGen) {
        setState(() { _errorMessage = e.toString(); _isSearching = false; });
      }
    }
  }

  Future<void> _searchTorrents(String query) async {
    final gen = ++_torrentSearchGen;
    setState(() { _isSearching = true; _allTorrentResults = []; _errorMessage = null; });
    try {
      final results = (await Engine.searchTorrents(query))
          .map(TorrentResult.fromJson)
          .toList();
      if (!mounted || gen != _torrentSearchGen) return;
      final filtered = (await Engine.filterTorrents(
        results.map((e) => e.toJson()).toList(),
        _movie.title,
      )).map(TorrentResult.fromJson).toList();
      if (!mounted || gen != _torrentSearchGen) return;
      setState(() { _allTorrentResults = filtered; _isSearching = false; });
      _sortResults();
    } catch (e) {
      if (mounted && gen == _torrentSearchGen) {
        setState(() { _errorMessage = e.toString(); _isSearching = false; });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Jackett Search
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _searchJackett() async {
    if (!_isJackettConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jackett is not configured. Go to Settings to add your Base URL and API Key.'))
        );
      }
      return;
    }

    final gen = ++_torrentSearchGen;
    setState(() { _isSearching = true; _allTorrentResults = []; _errorMessage = null; });

    try {
      final baseUrl = await _settings.getJackettBaseUrl();
      final apiKey = await _settings.getJackettApiKey();
      if (!mounted || gen != _torrentSearchGen) return;

      if (baseUrl == null || apiKey == null) throw Exception('Jackett configuration missing');

      if (_movie.mediaType == 'tv') {
        final s = _selectedSeason.toString().padLeft(2, '0');
        final e = _selectedEpisode.toString().padLeft(2, '0');
        final results = await Future.wait([
          _jackett.search(baseUrl, apiKey, '${_movie.title} S$s'),
          _jackett.search(baseUrl, apiKey, '${_movie.title} S${s}E$e'),
        ]);
        if (!mounted || gen != _torrentSearchGen) return;
        final filteredSeason = (await Engine.filterTorrents(
          results[0].map((e) => e.toJson()).toList(),
          _movie.title,
          requiredSeason: _selectedSeason,
        )).map(TorrentResult.fromJson).toList();
        if (!mounted || gen != _torrentSearchGen) return;
        final filteredEpisode = (await Engine.filterTorrents(
          results[1].map((e) => e.toJson()).toList(),
          _movie.title,
          requiredSeason: _selectedSeason,
          requiredEpisode: _selectedEpisode,
        )).map(TorrentResult.fromJson).toList();
        final combined = <String, TorrentResult>{};
        for (var r in filteredEpisode) { combined[r.magnet] = r; }
        for (var r in filteredSeason) { combined[r.magnet] = r; }
        if (!mounted || gen != _torrentSearchGen) return;
        if (combined.isEmpty) {
          setState(() { _errorMessage = 'No results found for "S${s}E$e". Try checking your configured indexers in Jackett.'; _isSearching = false; });
        } else {
          setState(() { _allTorrentResults = combined.values.toList(); _isSearching = false; });
          _sortResults();
        }
      } else {
        final year = _movie.releaseDate.length >= 4 ? _movie.releaseDate.substring(0, 4) : '';
        final query = year.isNotEmpty ? '${_movie.title} $year' : _movie.title;
        final results = await _jackett.search(baseUrl, apiKey, query);
        if (!mounted || gen != _torrentSearchGen) return;
        final filtered = (await Engine.filterTorrents(
          results.map((e) => e.toJson()).toList(),
          _movie.title,
        )).map(TorrentResult.fromJson).toList();
        if (!mounted || gen != _torrentSearchGen) return;
        if (filtered.isEmpty) {
          setState(() { _errorMessage = 'No results found for "$query". Try checking your configured indexers in Jackett.'; _isSearching = false; });
        } else {
          setState(() { _allTorrentResults = filtered; _isSearching = false; });
          _sortResults();
        }
      }
    } catch (e) {
      if (mounted && gen == _torrentSearchGen) {
        setState(() { _errorMessage = e.toString(); _isSearching = false; });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Prowlarr Search
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _searchProwlarr() async {
    if (!_isProwlarrConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prowlarr is not configured. Go to Settings to add your Base URL and API Key.'))
        );
      }
      return;
    }

    final gen = ++_torrentSearchGen;
    setState(() { _isSearching = true; _allTorrentResults = []; _errorMessage = null; });

    try {
      final baseUrl = await _settings.getProwlarrBaseUrl();
      final apiKey = await _settings.getProwlarrApiKey();
      if (!mounted || gen != _torrentSearchGen) return;

      if (baseUrl == null || apiKey == null) throw Exception('Prowlarr configuration missing');

      final tagIds = await _settings.getProwlarrTagIds();
      if (!mounted || gen != _torrentSearchGen) return;
      List<int>? allowedIndexerIds;
      if (tagIds.isNotEmpty) {
        final resolved = await _prowlarr.resolveTagIndexerIds(baseUrl, apiKey, tagIds);
        if (!mounted || gen != _torrentSearchGen) return;
        if (resolved.isNotEmpty) allowedIndexerIds = resolved;
      }

      if (_movie.mediaType == 'tv') {
        final s = _selectedSeason.toString().padLeft(2, '0');
        final e = _selectedEpisode.toString().padLeft(2, '0');
        final results = await Future.wait([
          _prowlarr.search(baseUrl, apiKey, '${_movie.title} S$s', indexerIds: allowedIndexerIds),
          _prowlarr.search(baseUrl, apiKey, '${_movie.title} S${s}E$e', indexerIds: allowedIndexerIds),
        ]);
        if (!mounted || gen != _torrentSearchGen) return;
        final filteredSeason = (await Engine.filterTorrents(
          results[0].map((e) => e.toJson()).toList(),
          _movie.title,
          requiredSeason: _selectedSeason,
        )).map(TorrentResult.fromJson).toList();
        if (!mounted || gen != _torrentSearchGen) return;
        final filteredEpisode = (await Engine.filterTorrents(
          results[1].map((e) => e.toJson()).toList(),
          _movie.title,
          requiredSeason: _selectedSeason,
          requiredEpisode: _selectedEpisode,
        )).map(TorrentResult.fromJson).toList();
        final combined = <String, TorrentResult>{};
        for (var r in filteredEpisode) { combined[r.magnet] = r; }
        for (var r in filteredSeason) { combined[r.magnet] = r; }
        if (!mounted || gen != _torrentSearchGen) return;
        if (combined.isEmpty) {
          setState(() { _errorMessage = 'No results found for "S${s}E$e". Try checking your configured indexers in Prowlarr.'; _isSearching = false; });
        } else {
          setState(() { _allTorrentResults = combined.values.toList(); _isSearching = false; });
          _sortResults();
        }
      } else {
        final year = _movie.releaseDate.length >= 4 ? _movie.releaseDate.substring(0, 4) : '';
        final query = year.isNotEmpty ? '${_movie.title} $year' : _movie.title;
        final results = await _prowlarr.search(baseUrl, apiKey, query, indexerIds: allowedIndexerIds);
        if (!mounted || gen != _torrentSearchGen) return;
        final filtered = (await Engine.filterTorrents(
          results.map((e) => e.toJson()).toList(),
          _movie.title,
        )).map(TorrentResult.fromJson).toList();
        if (!mounted || gen != _torrentSearchGen) return;
        if (filtered.isEmpty) {
          setState(() { _errorMessage = 'No results found for "$query". Try checking your configured indexers in Prowlarr.'; _isSearching = false; });
        } else {
          setState(() { _allTorrentResults = filtered; _isSearching = false; });
          _sortResults();
        }
      }
    } catch (e) {
      if (mounted && gen == _torrentSearchGen) {
        setState(() { _errorMessage = e.toString(); _isSearching = false; });
      }
    }
  }

  // ─── safe field helpers ───────────────────────────────────────────────────

  String _getTrackerName(TorrentResult result) {
    try {
      final dynamic r = result;
      final dynamic raw = r.source ?? r.tracker ?? r.provider ?? r.site;
      if (raw is String) return raw;
    } catch (_) {}
    return '';
  }

  List<Map<String, dynamic>> _filterStremioStreams(List<dynamic> streams) =>
      filterStremioStreamsForProfile(streams, _playbackProfile);

  // ─── play methods ─────────────────────────────────────────────────────────

  void _playStremioStream(Map<String, dynamic> stream, {Duration? startPosition}) async {
    if (mounted && _sourcesPanelOpen) setState(() => _sourcesPanelOpen = false);
    final stremioId = widget.stremioItem?['id']?.toString() ?? _movie.imdbId;
    final stremioAddonBaseUrl = stream['_addonBaseUrl']?.toString() ?? _selectedSourceId;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(precheck.message)),
        );
      }
      return;
    }

    if (precheck is StremioPlayable) {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
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
      )));
      return;
    }

    if (!mounted) return;
    _streamCancelled = false;
    final loadingMessage = stremioResolveLoadingMessage(
      profile: _playbackProfile,
      useDebrid: useDebrid,
      debridService: debridService,
    );
    showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (dialogContext) => LoadingOverlay(
        movie: _movie,
        message: loadingMessage,
        subtitle: playbackSourceHint(
          useDebrid: useDebrid,
          debridService: debridService,
        ),
        onCancel: () => _dismissStreamLoadingDialog(dialogContext),
      ),
    );
    final navigator = Navigator.of(context);

    final resolved = await resolveStremioStream(
      stream: stream,
      profile: _playbackProfile,
      settings: _settings,
      season: isTv ? _selectedSeason : null,
      episode: isTv ? _selectedEpisode : null,
      isCancelled: () => _streamCancelled,
    );

    if (_streamCancelled) return;
    if (navigator.canPop()) navigator.pop();

    if (resolved is StremioPlayable && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
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
      )));
    } else if (resolved is StremioResolveFailure &&
        resolved.error != StremioPlaybackError.cancelled &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resolved.message)),
      );
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
              ShellBus.openStremioSearch(query: query, addonBaseUrl: addonBaseUrl ?? '');
            });
          }
          return;

        case 'discover':
          // Open the catalog screen for this discover link
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => StremioCatalogScreen()));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to handle this link')));
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
    final sourceHint = playbackSourceHint(
      useDebrid: useDebrid,
      debridService: debridService,
    );
    showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (dialogContext) => LoadingOverlay(
        movie: _movie,
        messageNotifier: overlayMessage,
        subtitle: sourceHint,
        onCancel: () => _dismissStreamLoadingDialog(dialogContext),
      ),
    );

    String? url;
    String? magnetLink = result.magnet;
    int? resolvedFileIndex;

    try {
      if (!magnetLink.startsWith('magnet:')) {
        if (!mounted || _streamCancelled) return;
        Navigator.pop(context);
        showDialog(
          context: context,
          useRootNavigator: false,
          barrierDismissible: false,
          barrierColor: Colors.black,
          builder: (dialogContext) => LoadingOverlay(
            movie: _movie,
            message: 'Resolving download link...',
            onCancel: () => _dismissStreamLoadingDialog(dialogContext),
          ),
        );
        try {
          final resolved = await _linkResolver.resolve(magnetLink);
          if (_streamCancelled) return;
          if (resolved.isMagnet) {
            magnetLink = resolved.link;
          } else if (resolved.torrentBytes != null) {
            if (!mounted) return;
            if (Navigator.canPop(context)) Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Torrent file downloads not yet supported. Please use magnet links.'))
            );
            return;
          }
        } catch (e) {
          if (_streamCancelled) return;
          if (!mounted) return;
          if (Navigator.canPop(context)) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          return;
        }
        if (!mounted || _streamCancelled) return;
        if (Navigator.canPop(context)) Navigator.pop(context);
        showDialog(
          context: context,
          useRootNavigator: false,
          barrierDismissible: false,
          barrierColor: Colors.black,
          builder: (dialogContext) => LoadingOverlay(
            movie: _movie,
            messageNotifier: overlayMessage,
            subtitle: sourceHint,
            onCancel: () => _dismissStreamLoadingDialog(dialogContext),
          ),
        );
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
      if (_streamCancelled) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      overlayMessage.dispose();
    }

    if (!mounted || _streamCancelled) return;
    if (Navigator.canPop(context)) Navigator.pop(context);

    if (url != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
        streamUrl: url!, title: result.name, magnetLink: magnetLink, movie: _movie,
        selectedSeason: _movie.mediaType == 'tv' ? _selectedSeason : null,
        selectedEpisode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
        fileIndex: resolvedFileIndex,
        startPosition: startPosition,
        activeProvider: 'torrent')));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return BackNavigationScope(
        child: Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
              const MediaDetailsBackButton(),
            ],
          ),
        ),
      );
    }

    return BackNavigationScope(
      child: Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent || _movie.mediaType != 'tv' || _seasonData == null) {
          return KeyEventResult.ignored;
        }
        final episodes = _seasonData!['episodes'] as List?;
        if (episodes == null || episodes.isEmpty) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          if (_selectedEpisode > 1) {
            setState(() => _selectedEpisode--);
            _autoSearch();
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (_selectedEpisode < episodes.length) {
            setState(() => _selectedEpisode++);
            _autoSearch();
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp && _selectedSeason > 1) {
          _fetchSeason(_selectedSeason - 1);
          setState(() => _selectedEpisode = 1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
            _selectedSeason < _movie.numberOfSeasons) {
          _fetchSeason(_selectedSeason + 1);
          setState(() => _selectedEpisode = 1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(children: [
          _buildScrollLayout(),
          if (!_isCollection) _buildSourcesSlidingPanel(),
          const MediaDetailsBackButton(),
        ]),
      ),
    ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SCROLL LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildScrollLayout() {
    final heroHeight = ShellTokens.detailsHeroHeight(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailsHero(heroHeight: heroHeight),
          MediaDetailsBody(
            backgroundColor: AppTheme.bgDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isCollection && _collectionItems.isNotEmpty) ...[
                  _buildCollectionItemsSection(),
                  const SizedBox(height: ShellTokens.detailsSectionSpacing),
                ],
                if (_movie.mediaType == 'tv' && !_isCollection) ...[
                  _buildTvPicker(),
                  const SizedBox(height: ShellTokens.detailsSectionSpacing),
                ],
                if (_castMembers.isNotEmpty) ...[
                  MediaDetailsCastSection(
                    cast: _castMembers,
                    title: 'Main Characters',
                    outdentHorizontal: ShellTokens.homeSectionHorizontalPadding,
                  ),
                  const SizedBox(height: ShellTokens.detailsSectionSpacing),
                ],
                if (_trailers.isNotEmpty) ...[
                  MediaDetailsTrailersSection(trailers: _trailers),
                  const SizedBox(height: ShellTokens.detailsSectionSpacing),
                ],
                _buildRecommendationsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SOURCES SLIDING PANEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSourcesSlidingPanel() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth < 700 ? screenWidth * 0.92 : 480.0;

    return Stack(
      children: [
        if (_sourcesPanelOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _sourcesPanelOpen = false),
              child: Container(color: Colors.black54),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: _sourcesPanelOpen ? 0 : -panelWidth,
          width: panelWidth,
          child: Material(
            color: const Color(0xFF0A0A14),
            elevation: 12,
            child: SafeArea(
              left: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
                child: _buildSourcesPanelContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourcesPanelContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Sources',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Close',
              onPressed: () => setState(() => _sourcesPanelOpen = false),
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
        _buildSourceToggle(),
        const SizedBox(height: 14),
        _buildSourceChips(),
        const SizedBox(height: 16),
        TorrentSourceResultsHeader(
          showSort: _isTorrentSource,
          isFetching: _isSearching || _isStremioFetching || _isNuvioFetching,
          episodeLabel: _movie.mediaType == 'tv'
              ? 'S${_selectedSeason.toString().padLeft(2, '0')}E${_selectedEpisode.toString().padLeft(2, '0')}'
              : null,
          sortPreference: _sortPreference,
          activeAudioFilters: _activeAudioFilters,
          onSortChanged: (val) {
            setState(() => _sortPreference = val);
            _settings.setSortPreference(val);
            _sortResults();
          },
          onCancelFetch: _cancelActiveSourceFetch,
          onAudioFiltersChanged: (updated) =>
              setState(() => _activeAudioFilters = updated),
        ),
        const SizedBox(height: 10),
        Expanded(child: _buildStreamList(inPanel: true)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SOURCE TOGGLE + CHIPS (sliding source panel)
  // ═══════════════════════════════════════════════════════════════════════════

  bool get _isTorrentSource =>
      _selectedSourceId == 'forja' ||
      _selectedSourceId == 'jackett' ||
      _selectedSourceId == 'prowlarr';

  bool get _isNuvioSource =>
      _selectedSourceId == 'nuvio_picker' ||
      _selectedSourceId == 'all_nuvio' ||
      _selectedSourceId.startsWith('nuvio:') ||
      _selectedSourceId.startsWith('nuvio://');

  Widget _buildSourceToggle() {
    final isTorrent = _isTorrentSource;
    final isNuvio = _isNuvioSource;
    final isStremio = !isTorrent && !isNuvio;
    // On narrow phones the three labelled tabs would push past the screen
    // edge — stretch each tab to share the row equally and shrink the
    // label/icon so nothing overflows the rounded container.
    final w = MediaQuery.of(context).size.width;
    final compact = w < 420;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _sourceTab('Stremio Addons', Icons.extension_outlined, isStremio, compact, () {
            if (_streamAddons.isNotEmpty) {
              setState(() {
                _selectedSourceId = 'all_stremio';
                _applyStremioFilter();
                _errorMessage = null;
              });
              if (_allCombinedStremioStreams.isEmpty) _fetchAllStremioStreams();
            }
          }),
          ),
          if (_hasNuvioAddons)
            Expanded(
              child: _sourceTab('Nuvio Addons', Icons.code_rounded, isNuvio, compact, () {
              setState(() {
                _selectedSourceId = 'nuvio_picker';
                _nuvioSelectedAddonUrl = null;
                _nuvioSelectedScraperId = null;
                _nuvioStreams = [];
                _errorMessage = null;
              });
              _checkAndFetchNuvio();
            }),
            ),
          if (_playbackProfile.builtinTorrentSearch)
            Expanded(
              child: _sourceTab('Torrent Sources', Icons.downloading_rounded, isTorrent, compact, () {
              setState(() => _selectedSourceId = 'forja');
              _autoSearch();
            }),
            ),
        ],
      ),
    );
  }

  Widget _sourceTab(String label, IconData icon, bool selected, bool compact, VoidCallback onTap) {
    // "Stremio Addons" / "Torrent Sources" are too wide for ~360-400dp
    // phones. Use a shorter label in compact mode and a FittedBox so any
    // remaining overflow gracefully shrinks rather than clipping.
    final shortLabel = compact
        ? (label.startsWith('Stremio')
            ? 'Stremio'
            : label.startsWith('Nuvio')
                ? 'Nuvio'
                : 'Torrent')
        : label;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: selected ? Colors.white : Colors.white54),
            const SizedBox(width: 5),
            Text(shortLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.white54)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSourceChips() {
    final isTorrent = _isTorrentSource;
    final isNuvio = _isNuvioSource;
    final chips = <Map<String, dynamic>>[];
    if (isTorrent) {
      chips.add({'id': 'forja', 'label': 'Forja'});
      if (_isJackettConfigured) chips.add({'id': 'jackett', 'label': '🔍 Jackett'});
      if (_isProwlarrConfigured) chips.add({'id': 'prowlarr', 'label': '🔍 Prowlarr'});
      for (final a in _streamAddons) {
        if (a['type'] == 'torrent') chips.add({'id': a['baseUrl'], 'label': a['name']});
      }
    } else if (isNuvio) {
      // Two-level navigation:
      //   Level 0 — addon picker: one chip per installed addon.
      //   Level 1 — scraper picker: a "Back" chip + one chip per enabled
      //             scraper inside the chosen addon.
      // No scraping happens until the user actually taps a scraper chip.
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
              scrapers: const []),
        );
        for (final s in addon.scrapers) {
          if (!s.enabled) continue;
          chips.add({'id': 'nuvio:${s.id}', 'label': s.name});
        }
      }
    } else {
      // "All" chip shows combined streams from every addon
      if (_streamAddons.length > 1) {
        chips.add({'id': 'all_stremio', 'label': '⚡ All'});
      }
      // Only show addon chips that have finished loading
      for (final a in _streamAddons) {
        if (_loadedAddonBaseUrls.contains(a['baseUrl'])) {
          chips.add({'id': a['baseUrl'], 'label': a['name']});
        }
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        _scrollArrow(Icons.arrow_back_ios_rounded, () => _chipsScrollController.animateTo(
          (_chipsScrollController.offset - 160).clamp(0.0, _chipsScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 280), curve: Curves.easeInOut)),
        Expanded(
          child: SingleChildScrollView(
            controller: _chipsScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chips.map((chip) {
          final id = chip['id'] as String;
          // Selection rules for the new Nuvio drill-down:
          //   - addon-picker chip: selected when its addon is the active one
          //   - back chip: never visually selected
          //   - scraper chip: selected when its scraperId matches
          //   - everything else: legacy `_selectedSourceId` match
          final bool sel;
          if (id.startsWith('nuvio_addon::')) {
            sel = _nuvioSelectedAddonUrl ==
                id.substring('nuvio_addon::'.length);
          } else if (id == 'nuvio_back') {
            sel = false;
          } else {
            sel = _selectedSourceId == id;
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (id.startsWith('nuvio_addon::')) {
                  setState(() {
                    _nuvioSelectedAddonUrl =
                        id.substring('nuvio_addon::'.length);
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
                  });
                  _runSingleNuvioScraper(scraperId);
                  return;
                }
                setState(() => _selectedSourceId = id);
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
                        ? 'No streams found from any addon' : null;
                  });
                } else if (id == 'all_nuvio' || id.startsWith('nuvio://')) {
                  setState(() {
                    _errorMessage = null;
                  });
                } else {
                  // Single addon filter from cached combined results
                  setState(() {
                    _applyStremioFilter();
                    _errorMessage = _stremioStreams.isEmpty && !_isStremioFetching
                        ? 'No streams found in ${chip['label']}' : null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(chip['label'] as String,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : Colors.white.withValues(alpha: 0.6))),
              ),
            ),
          );
              }).toList(),
            ),
          ),
        ),
        _scrollArrow(Icons.arrow_forward_ios_rounded, () => _chipsScrollController.animateTo(
          (_chipsScrollController.offset + 160).clamp(0.0, _chipsScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 280), curve: Curves.easeInOut)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STREAM LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStreamList({bool inPanel = false}) {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent))),
      );
    }
    final isTorrent = _isTorrentSource;
    final isNuvio = _isNuvioSource;
    // Pick the active stream list based on the source tab.
    final List<dynamic> visibleStreams = isNuvio
        ? (_selectedSourceId == 'all_nuvio'
            ? _nuvioStreams
            : (_selectedSourceId.startsWith('nuvio:')
                ? _nuvioStreams
                    .where((s) =>
                        s['_addonBaseUrl'] == _selectedSourceId)
                    .toList()
                : <dynamic>[]))
        : _stremioStreams;
    final count = isTorrent ? _filteredTorrentResults.length : visibleStreams.length;
    final isFetching = isTorrent
        ? _isSearching
        : (isNuvio ? _isNuvioFetching : _isStremioFetching);
    if (!_isSearching && !isFetching && count == 0) {
      String msg;
      if (isTorrent && _activeAudioFilters.isNotEmpty && _allTorrentResults.isNotEmpty) {
        msg = 'No results match the audio filter';
      } else if (isNuvio && _nuvioSelectedScraperId == null) {
        msg = _nuvioSelectedAddonUrl == null
            ? 'Pick an addon to see its providers'
            : 'Pick a provider to fetch streams';
      } else {
        msg = 'No streams found';
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(msg, style: const TextStyle(color: Colors.white38))),
      );
    }
    return ListView.separated(
      shrinkWrap: !inPanel,
      physics: inPanel ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (isTorrent) {
          final r = _filteredTorrentResults[i];
          double prog = 0; bool resumable = false;
          if (_lastProgress != null && _lastProgress!['method'] == 'torrent') {
            if (_getHash(r.magnet) == _getHash(_lastProgress!['sourceId'])) {
              final pos = _lastProgress!['position'] as int;
              final dur = _lastProgress!['duration'] as int;
              if (dur > 0) { prog = (pos / dur).clamp(0.0, 1.0); resumable = true; }
            }
          }
          return _buildTorrentTile(r, progress: prog, isResumable: resumable);
        } else {
          final s = visibleStreams[i];
          double prog = 0; bool resumable = false;
          if (_lastProgress != null) {
            final String? sid = s['infoHash'] != null
                ? 'magnet:?xt=urn:btih:${s['infoHash']}' : s['url'];
            if (sid != null) {
              final hs = _lastProgress!['sourceId'] as String;
              final match = s['infoHash'] != null
                  ? _getHash(hs) == _getHash(sid) : hs == sid;
              if (match) {
                final pos = _lastProgress!['position'] as int;
                final dur = _lastProgress!['duration'] as int;
                if (dur > 0) { prog = (pos / dur).clamp(0.0, 1.0); resumable = true; }
              }
            }
          }
          return _buildStremioTile(
            stream: s,
            title: s['title'] ?? s['name'] ?? 'Unknown Stream',
            description: s['description'] ?? '',
            progress: prog, isResumable: resumable);
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TORRENT TILE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTorrentTile(TorrentResult result, {double progress = 0, bool isResumable = false}) {
    final n = result.name.toUpperCase();
    String quality = '?'; Color qColor = Colors.grey;
    if (n.contains('2160') || n.contains('4K') || n.contains('UHD')) {
      quality = '4K'; qColor = const Color(0xFF7C3AED);
    } else if (n.contains('1080')) {
      quality = '1080p'; qColor = const Color(0xFF1D4ED8);
    } else if (n.contains('720')) {
      quality = '720p'; qColor = const Color(0xFF0369A1);
    } else if (n.contains('480')) {
      quality = '480p'; qColor = Colors.grey.shade700;
    }

    String? codec;
    if (n.contains('HEVC') || n.contains('X265') || n.contains('H.265')) {
      codec = 'HEVC';
    } else if (n.contains('X264') || n.contains('H.264') || n.contains('H264') || n.contains('AVC')) {
      codec = 'h264';
    } else if (n.contains('AV1')) {
      codec = 'AV1';
    }

    final tracker = _getTrackerName(result);

    return FocusableControl(
      onTap: () => _playTorrent(result,
        startPosition: isResumable ? Duration(milliseconds: _lastProgress!['position'] as int) : widget.startPosition),
      borderRadius: 10,
      child: Container(
        decoration: BoxDecoration(
          color: (isResumable || widget.startPosition != null) ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isResumable
              ? AppTheme.primaryColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.07)),
        ),
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _qualityBadge(quality, qColor),
                      if (codec != null) ...[const SizedBox(height: 4), _codecBadge(codec)],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isResumable)
                        const Text('RESUME', style: TextStyle(color: AppTheme.primaryColor,
                          fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                      Text(result.name, maxLines: 3, overflow: TextOverflow.visible,
                        style: const TextStyle(color: Colors.white, fontSize: 12,
                          height: 1.35, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8, runSpacing: 2,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.arrow_upward_rounded, size: 11, color: Color(0xFF22C55E)),
                            const SizedBox(width: 2),
                            Text(result.seeders, style: const TextStyle(color: Color(0xFF22C55E), fontSize: 11)),
                          ]),
                          Text(result.size, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          if (tracker.isNotEmpty)
                            Text(tracker, style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(children: [
                  _iconBtn(Icons.content_copy_rounded, false, () {
                    Clipboard.setData(ClipboardData(text: result.magnet));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Magnet copied'), duration: Duration(seconds: 1)));
                  }),
                  const SizedBox(height: 6),
                  _iconBtn(Icons.play_arrow_rounded, true, () => _playTorrent(result,
                    startPosition: isResumable ? Duration(milliseconds: _lastProgress!['position'] as int) : widget.startPosition)),
                ]),
              ],
            ),
          ),
          if (isResumable && progress > 0)
            Positioned(bottom: 0, left: 0, right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                child: LinearProgressIndicator(value: progress,
                  backgroundColor: Colors.transparent, color: AppTheme.primaryColor, minHeight: 2.5))),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STREMIO TILE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStremioTile({
    required Map<String, dynamic> stream,
    required String title,
    required String description,
    double progress = 0,
    bool isResumable = false,
  }) {
    // Determine if this is an external-link stream (e.g. "More Like This" addon)
    final externalUrl = stream['externalUrl']?.toString();
    final isExternal = externalUrl != null && externalUrl.isNotEmpty;
    final bool isStremioLink = isExternal && externalUrl.startsWith('stremio://');
    final bool isWebLink = isExternal && (externalUrl.startsWith('http://') || externalUrl.startsWith('https://'));
    final String? addonName = stream['_addonName']?.toString();

    // Choose icon based on link type
    IconData leadingIcon;
    Color leadingColor;
    IconData actionIcon;
    if (isStremioLink) {
      final parsed = StremioService.parseMetaLink(externalUrl);
      final action = parsed?['action'];
      if (action == 'detail') {
        leadingIcon = Icons.movie_outlined;
        leadingColor = Colors.amberAccent;
        actionIcon = Icons.open_in_new_rounded;
      } else if (action == 'search') {
        leadingIcon = Icons.search_rounded;
        leadingColor = Colors.cyanAccent;
        actionIcon = Icons.search_rounded;
      } else {
        leadingIcon = Icons.explore_outlined;
        leadingColor = Colors.tealAccent;
        actionIcon = Icons.open_in_new_rounded;
      }
    } else if (isWebLink) {
      leadingIcon = Icons.language_rounded;
      leadingColor = Colors.lightBlueAccent;
      actionIcon = Icons.open_in_browser_rounded;
    } else if (isResumable) {
      leadingIcon = Icons.play_circle_filled_rounded;
      leadingColor = AppTheme.primaryColor;
      actionIcon = Icons.play_arrow_rounded;
    } else {
      leadingIcon = Icons.extension_rounded;
      leadingColor = Colors.blueAccent;
      actionIcon = Icons.play_arrow_rounded;
    }

    return FocusableControl(
      onTap: () => _playStremioStream(stream,
        startPosition: isResumable ? Duration(milliseconds: _lastProgress!['position'] as int) : widget.startPosition),
      borderRadius: 10,
      child: Container(
        decoration: BoxDecoration(
          color: isExternal
              ? leadingColor.withValues(alpha: 0.06)
              : ((isResumable || widget.startPosition != null) ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isExternal
              ? leadingColor.withValues(alpha: 0.25)
              : (isResumable ? AppTheme.primaryColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.07))),
        ),
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Icon(leadingIcon, color: leadingColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (isResumable && !isExternal)
                    const Text('RESUME', style: TextStyle(color: AppTheme.primaryColor,
                      fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  if (addonName != null && _selectedSourceId == 'all_stremio')
                    Text(addonName, style: TextStyle(color: leadingColor.withValues(alpha: 0.7),
                      fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  Text(title, maxLines: 4, overflow: TextOverflow.visible,
                    style: const TextStyle(color: Colors.white, fontSize: 12,
                      height: 1.35, fontWeight: FontWeight.w500)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(description, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ]),
              ),
              const SizedBox(width: 8),
              _iconBtn(actionIcon, true, () => _playStremioStream(stream,
                startPosition: isResumable ? Duration(milliseconds: _lastProgress!['position'] as int) : widget.startPosition)),
            ]),
          ),
          if (isResumable && progress > 0 && !isExternal)
            Positioned(bottom: 0, left: 0, right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                child: LinearProgressIndicator(value: progress,
                  backgroundColor: Colors.transparent, color: AppTheme.primaryColor, minHeight: 2.5))),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SMALL REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.3,
        ),
      );

  Widget _qualityBadge(String q, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
    child: Text(q, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)));

  Widget _codecBadge(String codec) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
    child: Text(codec,
      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w600)));

  Widget _iconBtn(IconData icon, bool highlight, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: highlight ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? AppTheme.primaryColor.withValues(alpha: 0.4) : Colors.white12)),
      child: Icon(icon, size: 17, color: highlight ? AppTheme.primaryColor : Colors.white54)));

  Widget _scrollArrow(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(icon, color: Colors.white38, size: 16)));

  Widget _buildCollectionItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Collection Items'),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _collectionItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _collectionItems[index];
            final id = item['id']?.toString() ?? '';
            final title = item['title']?.toString() ?? 'Unknown';
            final thumbnail = item['thumbnail']?.toString() ?? '';
            final ratings = item['ratings']?.toString() ?? '';
            final overview = item['overview']?.toString() ?? '';

            return FocusableControl(
              onTap: () => _openCollectionItem(id),
              borderRadius: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thumbnail.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: thumbnail,
                          width: 120,
                          height: 68,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            width: 120,
                            height: 68,
                            color: Colors.white.withValues(alpha: 0.1),
                            child: const Icon(Icons.movie, color: Colors.white24),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (ratings.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              ratings,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (overview.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              overview,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ],
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
          posterPath: '', backdropPath: '', voteAverage: 0,
          releaseDate: '', overview: '',
          mediaType: 'movie',
        ),
      );
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  RECOMMENDATIONS SECTION
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildRecommendationsSection() {
    return HomeMovieRow(
      title: 'More Like This',
      movies: _similarMovies,
      outdentHorizontal: ShellTokens.homeSectionHorizontalPadding,
      onMovieTap: (movie) => AppRouter.openMovie(context, movie: movie),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  EXPANDABLE SYNOPSIS
// ═════════════════════════════════════════════════════════════════════════════