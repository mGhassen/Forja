// Asian Drama (KissKH) per-episode resolver — sequential mirror probes like
// Movies webstreaming (CHECKING / UP / DOWN), then player Sources switch.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:forja/shared/extractors/providers/kisskh/kisskh_extractor.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
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
    for (final host in mirrorOrder)
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
  State<AsianDramaPlayerScreen> createState() =>
      _AsianDramaPlayerScreenState();
}

class _AsianDramaPlayerScreenState extends State<AsianDramaPlayerScreen> {
  final KissKhService _service = KissKhService();
  final KissKhExtractor _extractor = KissKhExtractor();
  final SettingsService _settings = SettingsService();

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
  bool _switchingManualMirror = false;
  String? _pendingManualMirrorId;
  KdramaCard? _resolvedDrama;
  KdramaEpisode? _resolvedEpisode;
  List<KdramaEpisode> _resolvedEpisodes = const [];
  String _resolvedOverview = '';
  List<String> _mirrorOrder = List<String>.from(
    SettingsService.defaultAsianDramaProviderOrder,
  );
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
    _cancelled = true;
    unawaited(_extractor.cancel());
    _messageNotifier.dispose();
    _fadeOutNotifier.dispose();
    if (!_handedOffLiveNotifiers) {
      _probeNotifier.dispose();
      _providerSourcesCache.dispose();
    }
    super.dispose();
  }

  void _setPhase(String message) {
    _messageNotifier.value = message;
  }

  void _requestManualMirrorCheck(String mirrorId) {
    if (_cancelled || _failedAll) return;
    _pendingManualMirrorId = mirrorId;
    _switchingManualMirror = true;
    unawaited(_extractor.cancel());
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

  void _prepareProbes({String? preferred}) {
    final isManual =
        preferred != null && preferred.isNotEmpty && preferred != 'auto';
    _probeNotifier.value = [
      for (var i = 0; i < _mirrorOrder.length; i++)
        StreamProviderProbe(
          id: _mirrorOrder[i],
          label: KissKhService.mirrorLabel(_mirrorOrder[i]),
          status: StreamProviderProbeStatus.pending,
          isPreferred: isManual
              ? _mirrorOrder[i] == preferred
              : i == 0,
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
      return 'Marked Upcoming on kisskh — expected $label. '
          'The site shows a countdown until streams unlock.';
    }
    return 'Marked Upcoming on kisskh. '
        'The site shows a countdown until streams unlock.';
  }

  /// Loads drama details (status gate) and resolves the episode row.
  Future<
      ({
        KdramaDetails details,
        KdramaCard drama,
        KdramaEpisode? episode,
        List<KdramaEpisode> episodes,
        bool matched,
      })> _resolveEpisodeContext() async {
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
          _statusLine = 'Could not resolve this episode on kisskh.';
        });
        return;
      }

      final drama = ctx.drama;
      final episode = ctx.episode!;

      _mirrorOrder = await _settings.getAsianDramaProviderOrder();
      if (!mounted || _cancelled) return;
      _providers = _kissKhProvidersForEpisode(
        drama: drama,
        episode: episode,
        mirrorOrder: _mirrorOrder,
      );

      if (!mounted) return;
      setState(() => _setPhase('Checking mirrors…'));

      var preferred = SourceEngine.auto;
      KissKhStream? stream;
      String? winningHost;

      while (mounted && !_cancelled) {
        _switchingManualMirror = false;
        final pin = preferred;
        final tryOrder = SourceEngine.isAuto(pin)
            ? _mirrorOrder
            : <String>[
                pin,
                ..._mirrorOrder.where((h) => h != pin),
              ];
        _prepareProbes(preferred: pin);

        stream = null;
        winningHost = null;
        for (final host in tryOrder) {
          if (!mounted || _cancelled || _switchingManualMirror) break;
          _applyProbeStatus(host, StreamProviderProbeStatus.trying);
          _setPhase('Checking ${KissKhService.mirrorLabel(host)}…');

          final result = await _extractor.resolve(
            dramaId: drama.id,
            dramaTitle: drama.title,
            episodeId: episode.id,
            episodeNumber: episode.number,
            forcedBaseUrl: KissKhService.baseUrlForHost(host),
            timeout: const Duration(seconds: 16),
            isCancelled: () =>
                _cancelled || _switchingManualMirror,
            onProgress: (phase, detail) {
              if (!mounted || _switchingManualMirror) return;
              if (phase == 'init' ||
                  phase == 'loaded' ||
                  phase == 'retry' ||
                  phase == 'embed' ||
                  phase == 'subs') {
                _setPhase(detail);
              }
            },
          );

          if (_cancelled) return;
          if (_switchingManualMirror) break;

          if (result != null) {
            _applyProbeStatus(host, StreamProviderProbeStatus.success);
            final sources = result.toSources(
              label: KissKhService.mirrorLabel(host),
            );
            _providerSourcesCache.value = {
              ..._providerSourcesCache.value,
              host: sources,
            };
            stream = result;
            winningHost = host;
            break;
          }
          _applyProbeStatus(host, StreamProviderProbeStatus.failed);
        }

        if (_cancelled) return;
        if (_switchingManualMirror && _pendingManualMirrorId != null) {
          preferred = _pendingManualMirrorId!;
          _pendingManualMirrorId = null;
          continue;
        }
        break;
      }

      if (!mounted || _cancelled) return;
      if (stream == null || winningHost == null) {
        setState(() {
          _failedAll = true;
          _isUpcoming = false;
          _setPhase('No stream available');
          _statusLine = 'All KissKH mirrors failed for this episode.';
        });
        return;
      }
      await _launchPlayer(stream, winningHost);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failedAll = true;
        _isUpcoming = false;
        _setPhase('Resolver crashed');
        _statusLine = '$e';
      });
    }
  }

  Future<void> _launchPlayer(KissKhStream stream, String activeMirror) async {
    final sources = stream.toSources(
      label: KissKhService.mirrorLabel(activeMirror),
    );
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
    final resolverRoute = ModalRoute.of(context);

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
      final hostContext = context;
      await navigator.pushReplacement(
        AppRouter.fadeRoute(
          (_) => ShellScope.rehost(
            hostContext,
            AsianDramaPlayerScreen(
              drama: drama,
              episode: ep!,
              allEpisodes: list,
            ),
          ),
        ),
      );
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
        final hostContext = context;
        await navigator.pushReplacement(
          AppRouter.fadeRoute(
            (_) => ShellScope.rehost(
              hostContext,
              AsianDramaPlayerScreen(
                drama: drama,
                episode: target!,
                allEpisodes: episodes,
              ),
            ),
          ),
        );
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
      },
      hasNextEpisode: hasNext,
      onNextEpisode: hasNext ? goNext : null,
      fadeTransition: true,
    );
    await Future<void>.delayed(loadingOverlayFadeOutDuration);
    if (resolverRoute != null) {
      navigator.removeRoute(resolverRoute);
    }
    await playerFuture;
    _probeNotifier.dispose();
    _providerSourcesCache.dispose();
  }

  Widget _buildFailure(AppThemePreset theme) {
    final backdropUrl = widget.drama.cover;
    final upcoming = _isUpcoming;
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backdropUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: backdropUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: Colors.black),
              errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
            )
          else
            const ColoredBox(color: Colors.black),
          Container(color: Colors.black.withValues(alpha: 0.72)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      upcoming ? Icons.schedule : Icons.error_outline,
                      color: theme.primaryColor,
                      size: 56,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _messageNotifier.value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_statusLine.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _statusLine,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _failedAll = false;
                          _isUpcoming = false;
                          _setPhase('Checking availability…');
                          _statusLine = '';
                          _probeNotifier.value = const [];
                        });
                        _bootstrap();
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(upcoming ? 'Check again' : 'Try again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
          onManualCheckProvider: _requestManualMirrorCheck,
          onCancel: () {
            _cancelled = true;
            unawaited(_extractor.cancel());
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
