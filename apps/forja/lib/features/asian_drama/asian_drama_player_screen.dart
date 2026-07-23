// Asian Drama (KissKH) per-episode resolver.
//
// Only one KissKH host is active. Mirror fan-out is deliberately disabled:
// aliases share the client's rate limit, so probing/failover can cause a ban.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:forja/shared/extractors/providers/kisskh/kisskh_extractor.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/resolve_failure_view.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

Movie _hubMovieFromDrama(KdramaCard drama, {String overview = ''}) => Movie(
  id: -drama.id,
  title: drama.title,
  posterPath: drama.cover,
  backdropPath: drama.cover,
  voteAverage: 0,
  releaseDate: '',
  overview: overview,
  mediaType: 'asian_drama',
  numberOfEpisodes: drama.episodesCount,
);

String? _dramaEpisodeThumbnail(String cover) {
  final value = cover.trim();
  return value.isNotEmpty ? value : null;
}

List<PlayerHubEpisode> _hubEpisodesFromDrama(
  KdramaCard drama,
  List<KdramaEpisode> episodes,
) {
  final thumb = _dramaEpisodeThumbnail(drama.cover);
  return episodes
      .map(
        (e) => PlayerHubEpisode(
          number: e.number,
          title: 'Episode ${e.displayNumber}',
          thumbnailUrl: thumb,
        ),
      )
      .toList();
}

Map<String, dynamic> _kissKhProvidersForEpisode({
  required KdramaCard drama,
  required KdramaEpisode episode,
  required List<String> mirrorOrder,
}) {
  return {
    for (final host in mirrorOrder.take(1))
      host: <String, dynamic>{
        'dramaId': drama.id,
        'dramaTitle': drama.title,
        'episodeId': episode.id,
        'episodeNumber': episode.number,
        'baseUrl': KissKhService.baseUrlForHost(host),
      },
  };
}

Future<T?> openAsianDramaPlayer<T>(
  BuildContext context, {
  required KdramaCard drama,
  required KdramaEpisode episode,
  List<KdramaEpisode> allEpisodes = const [],
  Duration? startPosition,
}) {
  final hostContext = context;
  return Navigator.of(context, rootNavigator: true).push<T>(
    AppRouter.fadeRoute(
      (_) => ShellScope.rehost(
        hostContext,
        AsianDramaPlayerScreen(
          drama: drama,
          episode: episode,
          allEpisodes: allEpisodes,
          startPosition: startPosition,
        ),
      ),
    ),
  );
}

class AsianDramaPlayerScreen extends StatefulWidget {
  final KdramaCard drama;
  final KdramaEpisode episode;
  final List<KdramaEpisode> allEpisodes;
  final Duration? startPosition;

  const AsianDramaPlayerScreen({
    super.key,
    required this.drama,
    required this.episode,
    this.allEpisodes = const [],
    this.startPosition,
  });

  @override
  State<AsianDramaPlayerScreen> createState() => _AsianDramaPlayerScreenState();
}

class _AsianDramaPlayerScreenState extends State<AsianDramaPlayerScreen> {
  final KissKhService _service = KissKhService();
  final KissKhExtractor _extractor = KissKhExtractor();

  late final ValueNotifier<String> _messageNotifier;
  late final ValueNotifier<bool> _fadeOutNotifier;
  late final ValueNotifier<List<StreamProviderProbe>> _probeNotifier;
  late final ValueNotifier<Map<String, List<StreamSource>>>
  _providerSourcesCache;

  String _statusLine = '';
  bool _failedAll = false;

  /// KissKh countdown / not-yet-published — skip extract, show availability copy.
  bool _isUpcoming = false;
  bool _cancelled = false;
  bool _handedOffLiveNotifiers = false;
  /// Next/prev while player is open — pop player, then replace this host.
  KdramaEpisode? _handOffEpisode;
  List<KdramaEpisode> _handOffEpisodes = const [];
  KdramaCard? _resolvedDrama;
  KdramaEpisode? _resolvedEpisode;
  List<KdramaEpisode> _resolvedEpisodes = const [];
  String _resolvedOverview = '';
  final List<String> _mirrorOrder = const [KissKhService.activeMirrorHost];
  Map<String, dynamic> _providers = const {};

  @override
  void initState() {
    super.initState();
    _messageNotifier = ValueNotifier('Checking availability…');
    _fadeOutNotifier = ValueNotifier(false);
    _probeNotifier = ValueNotifier(const []);
    _providerSourcesCache = ValueNotifier({});
    _bootstrap();
  }

  @override
  void dispose() {
    _haltResolve();
    _messageNotifier.dispose();
    _fadeOutNotifier.dispose();
    if (!_handedOffLiveNotifiers) {
      _probeNotifier.dispose();
      _providerSourcesCache.dispose();
    }
    super.dispose();
  }

  /// Leave title / Cancel / tab switch — same stop as the Cancel button.
  void _haltResolve() {
    _cancelled = true;
    unawaited(_extractor.cancel());
    DomainStreamProviderResolver.cancelAllPending();
  }

  void _setPhase(String message) {
    _messageNotifier.value = message;
  }

  void _applyProbeStatus(String mirrorId, StreamProviderProbeStatus status) {
    final existing = _probeNotifier.value;
    final idx = existing.indexWhere((p) => p.id == mirrorId);
    if (idx < 0) {
      _probeNotifier.value = [
        ...existing,
        StreamProviderProbe(
          id: mirrorId,
          label: KissKhService.mirrorLabel(mirrorId),
          status: status,
          isPreferred: existing.isEmpty,
        ),
      ];
      return;
    }
    _probeNotifier.value = [
      for (final p in existing)
        if (p.id == mirrorId) p.copyWith(status: status) else p,
    ];
  }

  void _prepareActiveHost() {
    _probeNotifier.value = [
      StreamProviderProbe(
        id: KissKhService.activeMirrorHost,
        label: KissKhService.mirrorLabel(KissKhService.activeMirrorHost),
        status: StreamProviderProbeStatus.pending,
        isPreferred: true,
      ),
    ];
  }

  KdramaEpisode? _episodeByNumber(List<KdramaEpisode> episodes, double number) {
    for (final e in episodes) {
      if (e.number == number) return e;
    }
    return null;
  }

  String _upcomingStatusLine(KdramaDetails det) {
    final release = det.releaseDate.trim();
    if (release.isNotEmpty) {
      final label = KissKhService.formatReleaseDateLabel(release);
      return 'This title isn’t published yet. Streams usually unlock around $label.';
    }
    return 'This title isn’t published yet. Check back when the countdown ends.';
  }

  /// Episode row exists but kisskh still serves a countdown widget (not unlocked).
  String _countdownStatusLine(KdramaDetails det) {
    final release = det.releaseDate.trim();
    if (release.isNotEmpty) {
      final label = KissKhService.formatReleaseDateLabel(release);
      return 'This episode isn’t unlocked yet. Try again around $label.';
    }
    return 'This episode isn’t unlocked yet. Check back when the countdown ends.';
  }

  /// Loads drama details (status gate) and resolves the episode row.
  Future<
    ({
      KdramaDetails details,
      KdramaCard drama,
      KdramaEpisode? episode,
      List<KdramaEpisode> episodes,
      bool matched,
    })
  >
  _resolveEpisodeContext() async {
    var drama = widget.drama;
    var episodes = widget.allEpisodes;
    var episode = widget.episode;

    setState(() => _setPhase('Checking availability…'));

    final det = await _service.getDetails(drama.id);
    if (!mounted) {
      return (
        details: det,
        drama: drama,
        episode: null,
        episodes: episodes,
        matched: false,
      );
    }
    drama = det.toCard();
    _resolvedOverview = det.description;
    if (det.episodes.isNotEmpty) {
      episodes = det.episodes;
    }

    // Upcoming titles often list stub episodes (or none) with a site countdown.
    if (KissKhService.isUpcomingStatus(det.status)) {
      _resolvedDrama = drama;
      _resolvedEpisode = episode.id > 0 ? episode : null;
      _resolvedEpisodes = episodes;
      return (
        details: det,
        drama: drama,
        episode: episode,
        episodes: episodes,
        matched: true,
      );
    }

    final matched = det.episodeForResume(
      episodeNumber: episode.number,
      episodeId: episode.id > 0 ? episode.id : null,
    );
    if (matched != null) {
      episode = matched;
    } else if (episode.id > 0) {
      try {
        episode = episodes.firstWhere((e) => e.id == episode.id);
      } catch (_) {
        final byNumber = _episodeByNumber(episodes, episode.number);
        if (byNumber != null) {
          episode = byNumber;
        } else if (episodes.length == 1) {
          episode = episodes.first;
        } else {
          return (
            details: det,
            drama: drama,
            episode: null,
            episodes: episodes,
            matched: false,
          );
        }
      }
    } else {
      final byNumber = _episodeByNumber(episodes, episode.number);
      if (byNumber != null) {
        episode = byNumber;
      } else if (episodes.length == 1) {
        episode = episodes.first;
      } else {
        return (
          details: det,
          drama: drama,
          episode: null,
          episodes: episodes,
          matched: false,
        );
      }
    }

    if (episode.id <= 0 || episodes.isEmpty) {
      return (
        details: det,
        drama: drama,
        episode: null,
        episodes: episodes,
        matched: false,
      );
    }

    _resolvedDrama = drama;
    _resolvedEpisode = episode;
    _resolvedEpisodes = episodes;
    return (
      details: det,
      drama: drama,
      episode: episode,
      episodes: episodes,
      matched: true,
    );
  }

  Future<void> _bootstrap() async {
    try {
      final ctx = await _resolveEpisodeContext();
      if (!mounted) return;

      if (KissKhService.isUpcomingStatus(ctx.details.status)) {
        setState(() {
          _failedAll = true;
          _isUpcoming = true;
          _setPhase('Not available yet');
          _statusLine = _upcomingStatusLine(ctx.details);
        });
        return;
      }

      if (!ctx.matched || ctx.episode == null) {
        setState(() {
          _failedAll = true;
          _isUpcoming = false;
          _setPhase('Episode not found');
          _statusLine =
              'We couldn’t match this episode. Go back and pick another one.';
        });
        return;
      }

      final drama = ctx.drama;
      final episode = ctx.episode!;

      _providers = _kissKhProvidersForEpisode(
        drama: drama,
        episode: episode,
        mirrorOrder: _mirrorOrder,
      );

      if (!mounted) return;
      final activeHost = KissKhService.activeMirrorHost;
      var sawRateLimit = false;
      var sawCountdown = false;
      _prepareActiveHost();
      _applyProbeStatus(activeHost, StreamProviderProbeStatus.trying);
      _setPhase('Opening ${KissKhService.mirrorLabel(activeHost)}…');
      debugPrint(
        '[AsianDrama] single-host mode: $activeHost '
        '(mirror probes and failover disabled)',
      );

      final stream = await _extractor.resolve(
        dramaId: drama.id,
        dramaTitle: drama.title,
        episodeId: episode.id,
        episodeNumber: episode.number,
        forcedBaseUrl: KissKhService.baseUrlForHost(activeHost),
        timeout: const Duration(seconds: 45),
        isCancelled: () => _cancelled,
        onProgress: (phase, detail) {
          if (!mounted) return;
          if (phase == 'rate_limit') sawRateLimit = true;
          if (phase == 'countdown') sawCountdown = true;
          if (phase == 'init' ||
              phase == 'loaded' ||
              phase == 'retry' ||
              phase == 'rate_limit' ||
              phase == 'countdown' ||
              phase == 'embed' ||
              phase == 'subs') {
            _setPhase(detail);
          }
        },
      );

      if (!mounted || _cancelled) return;
      if (stream == null) {
        _applyProbeStatus(activeHost, StreamProviderProbeStatus.failed);
        setState(() {
          _failedAll = true;
          if (sawCountdown) {
            _isUpcoming = true;
            _setPhase('Not available yet');
            _statusLine = _countdownStatusLine(ctx.details);
          } else if (sawRateLimit) {
            _isUpcoming = false;
            _setPhase('Taking a short break');
            _statusLine =
                'The server asked us to slow down. Wait about a minute, then try again.';
          } else {
            _isUpcoming = false;
            _setPhase('Couldn’t find a stream');
            _statusLine =
                'Nothing playable came back for this episode. Try again in a bit.';
          }
        });
        return;
      }
      _applyProbeStatus(activeHost, StreamProviderProbeStatus.success);
      final sources = _kissKhSources(stream, activeHost);
      _providerSourcesCache.value = {activeHost: sources};
      await _launchPlayer(stream, activeHost);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failedAll = true;
        _isUpcoming = false;
        _setPhase('Something went wrong');
        _statusLine =
            'Playback couldn’t start. Try again, or come back later.';
      });
      debugPrint('[AsianDrama] resolve failed: $e');
    }
  }

  List<StreamSource> _kissKhSources(KissKhStream stream, String activeMirror) {
    final pid =
        activeMirror.trim().isNotEmpty ? activeMirror.trim() : 'kisskh';
    final raw = stream.toSources(
      label: KissKhService.mirrorLabel(activeMirror),
      providerId: pid,
    );
    final hdrs = resolvePlaybackHttpHeaders(
      raw.first.headers,
      streamUrl: raw.first.url,
      providerId: pid,
    );
    return [
      StreamSource(
        url: raw.first.url,
        title: raw.first.title,
        type: raw.first.type,
        headers: hdrs,
        providerId: pid,
        catalogUrl: raw.first.catalogUrl ?? raw.first.url,
      ),
    ];
  }

  Future<void> _launchPlayer(KissKhStream stream, String activeMirror) async {
    final sources = _kissKhSources(stream, activeMirror);
    final subs = stream.subtitles;

    final drama = _resolvedDrama ?? widget.drama;
    final episode = _resolvedEpisode ?? widget.episode;
    var episodes = _resolvedEpisodes;
    var overview = _resolvedOverview;
    if (episodes.isEmpty) {
      try {
        final det = await _service.getDetails(drama.id);
        episodes = det.episodes;
        overview = det.description;
      } catch (_) {}
    }

    await _service.recordWatch(
      drama: drama,
      episodeNumber: episode.number,
      episodeId: episode.id,
      episodes: episodes,
      totalEpisodes: episodes.isNotEmpty
          ? episodes.length
          : episode.number.toInt(),
    );

    final title = '${drama.title} • EP ${episode.displayNumber}';

    KdramaEpisode? nextFromList;
    if (episodes.isNotEmpty) {
      for (final e in episodes) {
        if (e.number == episode.number + 1) {
          nextFromList = e;
          break;
        }
      }
    }
    final hasNext = episodes.isEmpty ? true : nextFromList != null;
    final hubEpisodes = _hubEpisodesFromDrama(drama, episodes);

    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);

    Future<void> goNext() async {
      var ep = nextFromList;
      var list = episodes;
      if (ep == null) {
        try {
          final det = await _service.getDetails(drama.id);
          list = det.episodes;
          for (final e in det.episodes) {
            if (e.number == episode.number + 1) {
              ep = e;
              break;
            }
          }
        } catch (_) {}
      }
      if (ep == null) return;
      _handOffEpisode = ep;
      _handOffEpisodes = list;
      if (navigator.canPop()) navigator.pop();
    }

    // Per-episode cache key — do not collapse every ep onto S1:E1.
    final cacheEpisode = episode.number == episode.number.truncateToDouble()
        ? episode.number.toInt()
        : (episode.number * 100).round();

    _providerSourcesCache.value = {
      ..._providerSourcesCache.value,
      activeMirror: sources,
    };

    _fadeOutNotifier.value = true;
    _handedOffLiveNotifiers = true;
    final playerFuture = AppRouter.openPlayer(
      context,
      streamUrl: sources.first.url,
      title: title,
      headers: sources.first.headers,
      sources: sources,
      providers: _providers,
      activeProvider: activeMirror,
      movie: _hubMovieFromDrama(drama, overview: overview),
      selectedSeason: 1,
      selectedEpisode: cacheEpisode,
      startPosition: widget.startPosition,
      externalSubtitles: subs.isNotEmpty ? subs : null,
      providerSourcesCache: _providerSourcesCache,
      providerProbesNotifier: _probeNotifier,
      hubEpisodes: hubEpisodes,
      hubEpisodeNumber: episode.number,
      episodeOverview: 'Episode ${episode.displayNumber}',
      onHubEpisodeSelected: (ep) async {
        KdramaEpisode? target;
        for (final e in episodes) {
          if (e.number == ep.number) {
            target = e;
            break;
          }
        }
        if (target == null) return;
        _handOffEpisode = target;
        _handOffEpisodes = episodes;
        if (navigator.canPop()) navigator.pop();
      },
      onSaveProgress: (pos, dur) async {
        await _service.recordWatch(
          drama: drama,
          episodeNumber: episode.number,
          episodeId: episode.id,
          episodes: episodes,
          totalEpisodes: episodes.isNotEmpty
              ? episodes.length
              : episode.number.toInt(),
          position: pos,
          duration: dur,
        );
        final index = episodes.indexWhere((e) => e.id == episode.id);
        final epKey = index >= 0 ? index + 1 : episode.number.toInt();
        await EpisodeWatchedService().markWatchedIfFinished(
          mediaId: drama.id,
          season: 1,
          episode: epKey,
          positionMs: pos.inMilliseconds,
          durationMs: dur.inMilliseconds,
          catalog: EpisodeWatchedService.catalogKisskh,
        );
      },
      hasNextEpisode: hasNext,
      onNextEpisode: hasNext ? goNext : null,
      fadeTransition: true,
    );
    // Keep this route under the player for the whole session. Removing it on
    // fade disposed Source cache notifiers while the player was still open.
    await playerFuture;
    _probeNotifier.dispose();
    _providerSourcesCache.dispose();
    final handOff = _handOffEpisode;
    final handOffList = _handOffEpisodes;
    _handOffEpisode = null;
    _handOffEpisodes = const [];
    if (handOff != null && mounted) {
      await navigator.pushReplacement(
        AppRouter.fadeRoute(
          (_) => ShellScope.rehost(
            context,
            AsianDramaPlayerScreen(
              drama: drama,
              episode: handOff,
              allEpisodes: handOffList,
            ),
          ),
        ),
      );
      return;
    }
    if (mounted && navigator.canPop()) {
      navigator.pop();
    }
  }

  void _retryFromFailure() {
    setState(() {
      _failedAll = false;
      _isUpcoming = false;
      _setPhase('Checking availability…');
      _statusLine = '';
      _probeNotifier.value = const [];
    });
    _bootstrap();
  }

  Widget _buildFailure(AppThemePreset _) {
    final upcoming = _isUpcoming;
    final waiting = upcoming ||
        _messageNotifier.value == 'Taking a short break' ||
        _messageNotifier.value == 'Not available yet';
    return ResolveFailureScaffold(
      backdropUrl: widget.drama.cover,
      failure: ResolveFailure(
        title: _messageNotifier.value,
        detail: _statusLine.isNotEmpty ? _statusLine : null,
        tone: waiting ? ResolveFailureTone.waiting : ResolveFailureTone.error,
        primaryLabel: upcoming ? 'Check again' : 'Try again',
        onPrimary: _retryFromFailure,
        secondaryLabel: 'Close',
        onSecondary: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = _hubMovieFromDrama(widget.drama);
    final episodeLabel = 'EP ${widget.episode.displayNumber}';

    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, theme, _) {
        if (_failedAll) return _buildFailure(theme);

        return LoadingOverlay(
          movie: movie,
          messageNotifier: _messageNotifier,
          providerProbesNotifier: _probeNotifier,
          fadeOutNotifier: _fadeOutNotifier,
          subtitle: episodeLabel,
          onCancel: () {
            _haltResolve();
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
