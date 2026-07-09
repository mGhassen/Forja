import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/extractors/stream_extractor.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:rust/rust.dart' as site111477_proxy;
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/shared/widgets/movie_atmosphere.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/widgets/home_movie_row.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/media_details_hero.dart';
import 'package:forja/shared/widgets/media_details_cast_section.dart';
import 'package:forja/shared/widgets/media_details_trailers_section.dart';
import 'package:forja/shared/widgets/media_details/media_details_torrent_action_row.dart';
import 'package:forja/shared/widgets/media_details/media_details_tracker_handlers.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shared/navigation/back_navigation_scope.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
class StreamingDetailsScreen extends StatefulWidget {
  final Movie movie;
  final int? initialSeason;
  final int? initialEpisode;
  final Duration? startPosition;
  final bool autoPlay;

  const StreamingDetailsScreen({
    super.key,
    required this.movie,
    this.initialSeason,
    this.initialEpisode,
    this.startPosition,
    this.autoPlay = false,
  });

  @override
  State<StreamingDetailsScreen> createState() => _StreamingDetailsScreenState();
}

class _StreamingDetailsScreenState extends State<StreamingDetailsScreen> with AtmosphereMixin {
  bool _isExtracting = false;
  bool _extractionCancelled = false;
  String? _statusMessage;
  final StreamExtractor _extractor = StreamExtractor();
  final StremioService _stremio = StremioService();
  final TmdbApi _api = TmdbApi();
  late Movie _movie;
  bool _isLoading = true;
  List<Movie> _similarContent = [];

  // Source Selection
  final String _selectedSourceId = 'forja';
  List<Map<String, dynamic>> _streamAddons = [];

  // TV State
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  Map<String, dynamic>? _seasonData;
  bool _isLoadingSeason = false;

  // Episode watched tracking
  final EpisodeWatchedService _episodeWatchedService = EpisodeWatchedService();
  Set<String> _watchedEpisodes = {};
  Map<String, dynamic>? _lastProgress;
  MediaDetailsExtras? _mediaExtras;

  Duration? get _playbackStartPosition {
    if (widget.startPosition != null) return widget.startPosition;
    final pos = _lastProgress?['position'] as int? ?? 0;
    return pos > 0 ? Duration(milliseconds: pos) : null;
  }

  String? _trailerKey;
  final Map<int, String> _seasonPosters = {};
  Map<String, Map<String, dynamic>> _episodeProgress = {};
  
  final ScrollController _episodeScrollController = ScrollController();
  final ScrollController _seasonScrollController = ScrollController();

  final Map<String, dynamic> _providers = <String, dynamic>{
    ...StreamProviders.providers,
  };
  final SettingsService _settings = SettingsService();
  final PlaybackProfile _playbackProfile = PlatformPlayback.capabilities;
  final MediaDetailsTrackerState _trackerState = MediaDetailsTrackerState();
  late final MediaDetailsTrackerHandlers _trackerHandlers;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    _trackerHandlers = MediaDetailsTrackerHandlers(
      context: context,
      state: _trackerState,
      movie: () => _movie,
      season: () => _selectedSeason,
      episode: () => _selectedEpisode,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    if (widget.initialSeason != null) _selectedSeason = widget.initialSeason!;
    if (widget.initialEpisode != null) _selectedEpisode = widget.initialEpisode!;
    // Start atmosphere color extraction
    final url = (_movie.posterPath.isNotEmpty ? _movie.posterPath : _movie.backdropPath);
    loadAtmosphere(url.startsWith('http') ? url : TmdbApi.getImageUrl(url));
    _checkHistory();
    _loadWatchedEpisodes();
    _loadNuvioProviders();
    _fetchDetails();
    _trackerHandlers.load();
  }

  Future<void> _loadNuvioProviders() async {
    try {
      final entries = await NuvioService.instance.getProviderEntries();
      if (!mounted || entries.isEmpty) return;
      setState(() => _providers.addAll(entries));
    } catch (e) {
      debugPrint('[StreamingDetails] nuvio provider load failed: $e');
    }
  }

  Future<void> _checkHistory() async {
    final progress = await WatchHistoryService().getProgress(
      _movie.id,
      season: _movie.mediaType == 'tv' ? _selectedSeason : null,
      episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
    );
    if (mounted) setState(() => _lastProgress = progress);
  }

  Future<void> _loadEpisodeProgressForSeason(int season) async {
    if (_seasonData == null || _seasonData!['episodes'] == null) return;
    final episodes = _seasonData!['episodes'] as List;
    final map = <String, Map<String, dynamic>>{};
    for (final ep in episodes) {
      final n = ep['episode_number'] as int;
      final p = await WatchHistoryService().getProgress(
        _movie.id,
        season: season,
        episode: n,
      );
      if (p != null) map['S${season}_E$n'] = p;
    }
    if (mounted) setState(() => _episodeProgress = map);
  }

  Future<void> _fetchDetails() async {
    try {
      final RichMediaDetails rich;
      if (_movie.mediaType == 'tv') {
        rich = await _api.getRichTvDetails(widget.movie.id);
        await _fetchSeason(widget.initialSeason ?? 1);
      } else {
        rich = await _api.getRichMovieDetails(widget.movie.id);
      }

      final streamAddons = await _stremio.getAddonsForResource('stream');
      
      // Fetch similar content
      final similar = _movie.mediaType == 'tv' 
          ? await _api.getSimilarTvShows(_movie.id)
          : await _api.getSimilarMovies(_movie.id);
      
      if (mounted) {
        setState(() {
          _movie = rich.movie;
          _mediaExtras = rich.extras;
          _trailerKey = rich.extras.trailerYoutubeKey;
          _streamAddons = streamAddons;
          _similarContent = similar;
          _isLoading = false;
        });

        if (widget.startPosition != null || widget.autoPlay) {
          _startExtraction();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
        });
        await _loadEpisodeProgressForSeason(seasonNumber);
        _checkHistory();
        _loadWatchedEpisodes();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSeason = false);
    }
  }

  @override
  void dispose() {
    _extractor.dispose();
    _episodeScrollController.dispose();
    _seasonScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWatchedEpisodes() async {
    final set = await _episodeWatchedService.getWatchedSet(_movie.id);
    if (mounted) setState(() => _watchedEpisodes = set);
  }

  Future<void> _toggleEpisodeWatched(int season, int episode) async {
    await _episodeWatchedService.toggle(_movie.id, season, episode);
    await _loadWatchedEpisodes();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXTRACTION LOGIC - PRESERVED FROM ORIGINAL
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startExtraction() async {
    if (_selectedSourceId == 'forja') {
      _runStreamExtraction();
    } else {
      _startStremioExtraction();
    }
  }

  Future<void> _startStremioExtraction() async {
    final addon = _streamAddons.firstWhere((a) => a['baseUrl'] == _selectedSourceId);
    final baseUrl = addon['baseUrl'];

    setState(() {
      _statusMessage = 'Fetching from ${addon['name']}...';
    });

    try {
      String stremioId = _movie.imdbId ?? '';
      if (_movie.mediaType == 'tv') {
        stremioId = '$stremioId:$_selectedSeason:$_selectedEpisode';
      }

      final type = _movie.mediaType == 'tv' ? 'series' : 'movie';
      final streams = await _stremio.getStreams(baseUrl: baseUrl, type: type, id: stremioId);
      final visible = filterStremioStreamsForProfile(streams, _playbackProfile);

      if (!mounted) return;
      if (visible.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No streams found for this content.')),
        );
        return;
      }

      final isTv = _movie.mediaType == 'tv';
      final title = isTv
          ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode'
          : _movie.title;

      for (final stream in visible) {
        final useDebrid = await _settings.useDebridForStreams();
        final debridService = await _settings.getDebridService();
        final precheck = classifyStremioStream(
          stream,
          _playbackProfile,
          useDebrid: useDebrid,
          debridService: debridService,
        );

        if (precheck is StremioPlayable) {
          if (!mounted) return;
          await AppRouter.openPlayer(
            context,
            streamUrl: precheck.streamUrl,
            title: title,
            headers: precheck.headers,
            movie: _movie,
            selectedSeason: isTv ? _selectedSeason : null,
            selectedEpisode: isTv ? _selectedEpisode : null,
            startPosition: _playbackStartPosition,
            activeProvider: 'stremio_direct',
          );
          return;
        }

        if (precheck is StremioResolveFailure) continue;

        final resolved = await resolveStremioStream(
          stream: stream,
          profile: _playbackProfile,
          settings: _settings,
          season: isTv ? _selectedSeason : null,
          episode: isTv ? _selectedEpisode : null,
        );
        if (resolved is StremioPlayable && mounted) {
          await AppRouter.openPlayer(
            context,
            streamUrl: resolved.streamUrl,
            title: title,
            magnetLink: resolved.magnetLink,
            movie: _movie,
            selectedSeason: isTv ? _selectedSeason : null,
            selectedEpisode: isTv ? _selectedEpisode : null,
            fileIndex: resolved.fileIndex,
            startPosition: _playbackStartPosition,
            activeProvider: 'stremio_direct',
          );
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _playbackProfile.localTorrentEngine
                  ? 'Failed to resolve stream.'
                  : 'Hash-based streams require debrid on this platform.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _statusMessage = null);
    }
  }

  Future<void> _runStreamExtraction() async {
    if (_isExtracting) return;
    _isExtracting = true;
    _extractionCancelled = false;
    final probeNotifier = ValueNotifier<List<StreamProviderProbe>>([]);
    final fadeOutNotifier = ValueNotifier(false);
    BuildContext? loadingDialogContext;
    Future<void>? overlayDismissFuture;

    void dismissLoadingOverlay() {
      final ctx = loadingDialogContext;
      if (ctx != null && ctx.mounted) {
        dismissLoadingOverlayRoute(ctx);
      }
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
            _extractionCancelled = true;
            WebStreamrService().cancelPending();
            VidsrcExtractor.cancelPending();
            NuvioService.instance.cancelPending();
            unawaited(_extractor.cancel());
            dismissLoadingOverlay();
          },
        );
      },
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      dismissLoadingOverlay();
      _isExtracting = false;
      fadeOutNotifier.dispose();
      probeNotifier.dispose();
      return;
    }

    setState(() {
      _statusMessage = 'Initializing Stream Extractor...';
    });

    try {
      // Load user-defined provider order. The first provider that yields a
      // working stream wins; the player uses the rest as fallbacks (in this
      // same order) when the active source dies.
      final order = await _settings.getStreamProviderOrder();

      // Build a reordered providers map so the player's fallback loop
      // (which iterates `widget.providers!.keys`) follows the user's order.
      final orderedProviders = <String, dynamic>{
        for (final k in order)
          if (_providers.containsKey(k)) k: _providers[k],
        // Append anything in StreamProviders not in the saved order, just in
        // case a new built-in provider ships before settings are migrated.
        for (final k in _providers.keys)
          if (!order.contains(k)) k: _providers[k],
      };

      bool found = false;
      var isFirstProvider = true;
      for (final key in orderedProviders.keys) {
        if (!mounted || _extractionCancelled) break;

        final displayName = _providerDisplayLabel(key, orderedProviders[key]);
        probeNotifier.value = [
          ...probeNotifier.value,
          StreamProviderProbe(
            id: key,
            label: displayName,
            status: StreamProviderProbeStatus.trying,
            isPreferred: isFirstProvider,
          ),
        ];
        isFirstProvider = false;
        if (mounted) {
          setState(() => _statusMessage = 'Searching $displayName…');
        }

        try {
          found = await _tryProvider(
            key,
            orderedProviders,
            probeNotifier: probeNotifier,
            fadeOutNotifier: fadeOutNotifier,
            loadingDialogContext: loadingDialogContext,
            onOverlayDismissScheduled: (future) => overlayDismissFuture = future,
          );
        } catch (e) {
          debugPrint('Error extracting from $key: $e');
        }

        if (!found) {
          probeNotifier.value = probeNotifier.value
              .map(
                (probe) => probe.id == key
                    ? probe.copyWith(status: StreamProviderProbeStatus.failed)
                    : probe,
              )
              .toList();
        }

        if (found) break;
      }

      if (mounted) {
        if (_extractionCancelled) {
          setState(() {
            _isExtracting = false;
            _statusMessage = null;
          });
          return;
        }
        if (!found) dismissLoadingOverlay();
        setState(() {
          _isExtracting = false;
          _statusMessage = found ? null : 'No streams found. Try again later.';
        });
        if (!found) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to find a working stream.')),
          );
        }
      }
    } finally {
      await overlayDismissFuture;
      fadeOutNotifier.dispose();
      probeNotifier.dispose();
    }
  }

  String _providerDisplayLabel(String key, dynamic provider) {
    final fallbackName = provider is Map ? provider['name']?.toString() : null;
    List<String>? contentLanguage;
    if (provider is Map && provider['contentLanguage'] is List) {
      contentLanguage =
          (provider['contentLanguage'] as List).map((e) => e.toString()).toList();
    }
    return StreamProviderDisplay.playerLabel(
      key,
      fallbackName: fallbackName,
      contentLanguage: contentLanguage,
    );
  }

  /// Tries a single provider by key. Returns true if a stream was found and
  /// the PlayerScreen was pushed; false otherwise. Always passes
  /// [orderedProviders] (not the static map) so the player's auto-fallback
  /// honours the user's preferred order.
  Future<bool> _tryProvider(
    String key,
    Map<String, dynamic> orderedProviders, {
    ValueNotifier<List<StreamProviderProbe>>? probeNotifier,
    ValueNotifier<bool>? fadeOutNotifier,
    BuildContext? loadingDialogContext,
    void Function(Future<void> future)? onOverlayDismissScheduled,
  }) async {
    final isTv = _movie.mediaType == 'tv';
    final title = isTv
        ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode'
        : _movie.title;

    Future<void> closeLoadingOverlay({
      Future<dynamic> Function()? openPlayer,
    }) async {
      Future<void> beforeFade() async {
        if (probeNotifier == null) return;
        probeNotifier.value = probeNotifier.value
            .map(
              (probe) => probe.id == key
                  ? probe.copyWith(status: StreamProviderProbeStatus.success)
                  : probe,
            )
            .toList();
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      final ctx = loadingDialogContext;
      if (openPlayer != null) {
        if (ctx != null && ctx.mounted) {
          await crossfadeLoadingOverlayToPlayer<dynamic>(
            loadingDialogContext: ctx,
            fadeOutNotifier: fadeOutNotifier,
            beforeFade: beforeFade,
            openPlayer: openPlayer,
          );
        } else {
          await beforeFade();
          await openPlayer();
        }
        return;
      }

      await beforeFade();
      fadeOutNotifier?.value = true;
      await Future<void>.delayed(loadingOverlayFadeOutDuration);
      if (ctx != null && ctx.mounted) {
        dismissLoadingOverlayRoute(ctx);
      }
    }

    void pushPlayer({
      required String streamUrl,
      String? audioUrl,
      Map<String, String>? headers,
      List<dynamic>? sources,
      List<Map<String, dynamic>>? subtitles,
    }) {
      if (!mounted) return;
      final dismissFuture = closeLoadingOverlay(
        openPlayer: () {
          final playerFuture = AppRouter.openPlayer<dynamic>(
            context,
            streamUrl: streamUrl,
            audioUrl: audioUrl,
            title: title,
            headers: headers,
            movie: _movie,
            providers: orderedProviders,
            activeProvider: key,
            selectedSeason: isTv ? _selectedSeason : null,
            selectedEpisode: isTv ? _selectedEpisode : null,
            startPosition: _playbackStartPosition,
            sources: sources?.cast(),
            externalSubtitles: subtitles,
            fadeTransition: true,
          );
          playerFuture.then((result) {
            if (!mounted || result is! Map) return;
            final nextSeason = result['nextSeason'];
            final nextEpisode = result['nextEpisode'];
            if (nextSeason is! int || nextEpisode is! int) return;
            setState(() {
              _selectedSeason = nextSeason;
              _selectedEpisode = nextEpisode;
            });
            _loadWatchedEpisodes();
            _runStreamExtraction();
          });
          return playerFuture;
        },
      );
      onOverlayDismissScheduled?.call(dismissFuture);
    }

    if (key == 'service111477') {
      final svc = Site111477Service();
      List<Site111477Match> hits;
      if (isTv) {
        hits = await svc.findEpisodeSources(
          showTitle: _movie.title,
          season: _selectedSeason,
          episode: _selectedEpisode,
        );
      } else {
        final year = _movie.releaseDate.length >= 4
            ? _movie.releaseDate.substring(0, 4)
            : null;
        hits = await svc.findMovieSources(title: _movie.title, year: year);
      }
      if (_extractionCancelled || hits.isEmpty) return false;
      if (mounted) setState(() => _statusMessage = 'Starting 111477 proxy…');
      final proxiedUrl =
          await site111477_proxy.start111477Proxy(hits.first.fileUrl);
      if (_extractionCancelled || !mounted) return false;
      pushPlayer(
        streamUrl: proxiedUrl,
        sources: Site111477Service.toStreamSources(hits),
      );
      return true;
    }

    if (key == 'webstreamr') {
      if (_movie.imdbId == null || _movie.imdbId!.isEmpty) return false;
      final ws = WebStreamrService();
      final wsSources = await ws.getStreams(
        imdbId: _movie.imdbId!,
        isMovie: !isTv,
        season: isTv ? _selectedSeason : null,
        episode: isTv ? _selectedEpisode : null,
        tmdbId: _movie.id,
      );
      if (_extractionCancelled || wsSources.isEmpty) return false;
      if (!mounted) return false;
      debugPrint(
        '[StreamingDetails] webstreamr pushing ${wsSources.length} sources'
        ' for ${_movie.imdbId ?? _movie.id}',
      );
      final first = wsSources.first;
      pushPlayer(
        streamUrl: first.url,
        headers: first.headers,
        sources: wsSources,
      );
      return true;
    }

    if (key == 'videasy') {
      final ve = VideasyExtractor(onLog: (m) => debugPrint(m));
      final result = await ve.extract(
        tmdbId: _movie.id.toString(),
        isMovie: !isTv,
        season: isTv ? _selectedSeason : null,
        episode: isTv ? _selectedEpisode : null,
        isCancelled: () => _extractionCancelled,
      );
      if (_extractionCancelled || result == null || result.url.isEmpty) {
        return false;
      }
      if (!mounted) return false;
      pushPlayer(
        streamUrl: result.url,
        audioUrl: result.audioUrl,
        headers: result.headers,
        sources: result.sources,
        subtitles: result.externalSubtitles,
      );
      return true;
    }

    if (key == 'vidsrc') {
      final ve = VidsrcExtractor();
      final result = await ve.extract(
        tmdbId: _movie.id.toString(),
        isMovie: !isTv,
        season: isTv ? _selectedSeason : null,
        episode: isTv ? _selectedEpisode : null,
      );
      if (_extractionCancelled || result == null || result.url.isEmpty) {
        return false;
      }
      if (!mounted) return false;
      pushPlayer(
        streamUrl: result.url,
        audioUrl: result.audioUrl,
        headers: result.headers,
        sources: result.sources,
        subtitles: result.externalSubtitles,
      );
      return true;
    }

    // Nuvio scrapers — `nuvio:<scraperId>`. Each entry is one provider in
    // the user's priority list, so we run a SINGLE scraper here (not all of
    // them like the regular details screen does). The first stream becomes
    // the primary; the rest become entries in the player's multi-link menu.
    if (key.startsWith('nuvio:')) {
      final scraperId = key.substring(6);
      final results = await NuvioService.instance.runOneScraper(
        scraperId: scraperId,
        tmdbId: _movie.id.toString(),
        type: isTv ? 'tv' : 'movie',
        season: isTv ? _selectedSeason : null,
        episode: isTv ? _selectedEpisode : null,
      );
      if (_extractionCancelled || results.isEmpty || !mounted) return false;
      final first = results.first;
      final sources = results.map((r) => StreamSource(
            url: r.url,
            title: r.title.isNotEmpty ? r.title : r.name,
            type: _typeFromUrl(r.url),
            headers: r.headers.isEmpty ? null : r.headers,
          )).toList();
      final subtitles = first.subtitles
          .where((s) => (s['url'] ?? '').isNotEmpty)
          .map((s) => <String, dynamic>{
                'url': s['url']!,
                'lang': s['lang'] ?? 'Unknown',
              })
          .toList();
      pushPlayer(
        streamUrl: first.url,
        headers: first.headers.isEmpty ? null : first.headers,
        sources: sources,
        subtitles: subtitles,
      );
      return true;
    }

    // Generic web-embed providers (vidlink/vixsrc/vidnest/…).
    final provider = orderedProviders[key];
    if (provider == null ||
        provider['movie'] == null ||
        provider['tv'] == null) {
      return false;
    }
    final String url = isTv
        ? provider['tv'](
            _movie.id.toString(),
            _selectedSeason,
            _selectedEpisode,
          )
        : provider['movie'](_movie.id.toString());
    debugPrint('[StreamExtractor] Trying ${provider['name']} source: $url');
    final result =
        await _extractor.extract(
      url,
      timeout: const Duration(seconds: 5),
      isCancelled: () => _extractionCancelled,
    );
    if (_extractionCancelled || result == null) return false;
    if (!mounted) return false;
    pushPlayer(
      streamUrl: result.url,
      audioUrl: result.audioUrl,
      headers: result.headers,
      sources: result.sources,
      subtitles: result.externalSubtitles,
    );
    return true;
  }

  String _typeFromUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8')) return 'hls';
    if (u.contains('.mpd')) return 'dash';
    if (u.contains('.mkv')) return 'mkv';
    return 'mp4';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD METHOD - NEW DESIGN
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
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF1565C0)),
              ),
              const MediaDetailsBackButton(),
            ],
          ),
        ),
      );
    }

    return BackNavigationScope(
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailsHero(
                    heroHeight: ShellTokens.detailsHeroHeight(
                      context,
                      showEpisodeRail: _movie.mediaType == 'tv',
                    ),
                  ),
                  MediaDetailsBody(
                    backgroundColor: AppTheme.bgDark,
                    bodyOverlap: _movie.mediaType == 'tv'
                        ? ShellTokens.detailsHeroBodyOverlapWithEpisodes
                        : null,
                    topSpacing: _movie.mediaType == 'tv'
                        ? ShellTokens.detailsBodyTopSpacingWithEpisodes
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_movie.mediaType == 'tv') ...[
                          TvSeasonEpisodePicker(
                            tmdbId: _movie.id,
                            seasonCount: _movie.numberOfSeasons,
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
                            onSeasonSelected: _fetchSeason,
                            onEpisodeSelected: (ep) async {
                              setState(() => _selectedEpisode = ep);
                              await _checkHistory();
                              if (!mounted || _isExtracting) return;
                              _startExtraction();
                            },
                            onToggleWatched: _toggleEpisodeWatched,
                          ),
                          const SizedBox(height: ShellTokens.detailsSectionSpacing),
                        ],
                        if (_mediaExtras != null && _mediaExtras!.cast.isNotEmpty) ...[
                          MediaDetailsCastSection(
                            cast: _mediaExtras!.cast,
                            title: 'Main Characters',
                            outdentHorizontal: ShellTokens.homeSectionHorizontalPadding,
                          ),
                          const SizedBox(height: ShellTokens.detailsSectionSpacing),
                        ],
                        if (_mediaExtras != null && _mediaExtras!.trailers.isNotEmpty) ...[
                          MediaDetailsTrailersSection(
                            trailers: _mediaExtras!.trailers,
                            movie: _movie,
                            languageCode: _mediaExtras!.originalLanguage,
                          ),
                          const SizedBox(height: ShellTokens.detailsSectionSpacing),
                        ],
                        _buildSimilarContent(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const MediaDetailsBackButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsHero({required double heroHeight}) {
    final extras = _mediaExtras;
    return MediaDetailsHero(
      movie: _movie,
      trailerYoutubeKey: _trailerKey,
      trailerLanguageCode: extras?.originalLanguage,
      progress: _lastProgress,
      height: heroHeight,
      tagline: extras?.tagline,
      certification: extras?.certification,
      status: extras?.status,
      directorName: extras != null ? _pickDirector(extras.crew) : null,
      budget: extras?.budget,
      revenue: extras?.revenue,
      languageCode: extras?.originalLanguage,
      spokenLanguages: extras?.spokenLanguages ?? const [],
      productionCompanies: extras?.productionCompanies ?? const [],
      originCountries: extras?.originCountries ?? const [],
      lastAirDate: extras?.lastAirDate,
      networks: extras?.networks ?? const [],
      creators: extras?.creators ?? const [],
      actionRow: _buildHeroActionRow(),
    );
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
      isExtracting: _isExtracting,
      onOpenSources: _startExtraction,
      onOverflowAction: _trackerHandlers.handleOverflow,
      trailers: _mediaExtras?.trailers ?? const [],
      trailerLanguageCode: _mediaExtras?.originalLanguage,
      statusMessage: _statusMessage,
      userTraktRating: _trackerState.userTraktRating,
      userSimklRating: _trackerState.userSimklRating,
      isInTraktCollection: _trackerState.isInTraktCollection,
    );
  }

  Widget _buildSimilarContent() {
    return HomeMovieRow(
      title: 'More Like This',
      movies: _similarContent,
      outdentHorizontal: ShellTokens.homeSectionHorizontalPadding,
      onMovieTap: (movie) {
        pushReplacementShellRoute(
          context,
          AppRouter.slideRoute(
            (_) => StreamingDetailsScreen(movie: movie),
          ),
        );
      },
    );
  }
}
