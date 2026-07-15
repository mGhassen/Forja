// Asian Drama (kisskh.co) per-episode resolver. Single WebView extraction path
// (no multi-server fan-out) — KissKH is not raced like webstreaming providers.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:forja/shared/extractors/providers/kisskh/kisskh_extractor.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
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
      mediaType: 'tv',
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

  late final ValueNotifier<String> _messageNotifier;
  late final ValueNotifier<bool> _fadeOutNotifier;

  String _statusLine = '';
  bool _failedAll = false;
  bool _cancelled = false;
  KdramaCard? _resolvedDrama;
  KdramaEpisode? _resolvedEpisode;
  List<KdramaEpisode> _resolvedEpisodes = const [];
  String _resolvedOverview = '';

  @override
  void initState() {
    super.initState();
    _messageNotifier = ValueNotifier('Fetching streams…');
    _fadeOutNotifier = ValueNotifier(false);
    _bootstrap();
  }

  @override
  void dispose() {
    _cancelled = true;
    _messageNotifier.dispose();
    _fadeOutNotifier.dispose();
    unawaited(_extractor.cancel());
    super.dispose();
  }

  void _setPhase(String phase) {
    _messageNotifier.value = phase;
  }

  KdramaEpisode? _episodeByNumber(List<KdramaEpisode> episodes, double number) {
    for (final e in episodes) {
      if (e.number == number) return e;
    }
    return null;
  }

  Future<bool> _resolveEpisodeContext() async {
    var drama = widget.drama;
    var episodes = widget.allEpisodes;
    var episode = widget.episode;

    if (episodes.isEmpty || drama.title.trim().isEmpty) {
      if (!mounted) return false;
      setState(() => _setPhase('Loading drama…'));
      final det = await _service.getDetails(drama.id);
      episodes = det.episodes;
      drama = det.toCard();
      _resolvedOverview = det.description;
      final matched = det.episodeForResume(
        episodeNumber: episode.number,
        episodeId: episode.id > 0 ? episode.id : null,
      );
      if (matched != null) episode = matched;
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
          return false;
        }
      }
    } else {
      final byNumber = _episodeByNumber(episodes, episode.number);
      if (byNumber != null) {
        episode = byNumber;
      } else if (episodes.length == 1) {
        episode = episodes.first;
      } else {
        return false;
      }
    }

    if (episode.id <= 0 || episodes.isEmpty) return false;

    _resolvedDrama = drama;
    _resolvedEpisode = episode;
    _resolvedEpisodes = episodes;
    return true;
  }

  Future<void> _bootstrap() async {
    try {
      if (!await _resolveEpisodeContext()) {
        if (!mounted) return;
        setState(() {
          _failedAll = true;
          _setPhase('Episode not found');
          _statusLine = 'Could not resolve this episode on kisskh.';
        });
        return;
      }

      final drama = _resolvedDrama!;
      final episode = _resolvedEpisode!;

      final stream = await _extractor.resolve(
        dramaId: drama.id,
        dramaTitle: drama.title,
        episodeId: episode.id,
        episodeNumber: episode.number,
        isCancelled: () => _cancelled,
        onProgress: (phase, detail) {
          if (!mounted) return;
          setState(() {
            if (phase == 'init') _setPhase('Opening kisskh…');
            if (phase == 'loaded') _setPhase('Waiting for stream key…');
            if (phase == 'embed') _setPhase('Extracting stream…');
            if (phase == 'subs') _setPhase(detail);
            if (phase == 'done') _setPhase('Stream ready');
            if (phase == 'error') _statusLine = detail;
          });
        },
      );

      if (!mounted) return;
      if (stream == null) {
        setState(() {
          _failedAll = true;
          _setPhase('No stream available');
        });
        return;
      }
      await _launchPlayer(stream);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failedAll = true;
        _setPhase('Resolver crashed');
        _statusLine = '$e';
      });
    }
  }

  Future<void> _launchPlayer(KissKhStream stream) async {
    final sources = stream.toSources(label: 'kisskh');
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

    // TV-shaped cache key (mediaType is always `tv` for hub movies). Pass the
    // real episode so reopen / hydrate does not collapse every ep onto S1:E1.
    final cacheEpisode = episode.number == episode.number.truncateToDouble()
        ? episode.number.toInt()
        : (episode.number * 100).round();

    _fadeOutNotifier.value = true;
    final playerFuture = AppRouter.openPlayer(
      context,
      streamUrl: sources.first.url,
      title: title,
      headers: sources.first.headers,
      sources: sources,
      activeProvider: 'kisskh',
      movie: _hubMovieFromDrama(drama, overview: overview),
      selectedSeason: 1,
      selectedEpisode: cacheEpisode,
      startPosition: widget.startPosition,
      externalSubtitles: subs.isNotEmpty ? subs : null,
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
  }

  Widget _buildFailure(AppThemePreset theme) {
    final backdropUrl = widget.drama.cover;
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
                    Icon(Icons.error_outline,
                        color: theme.primaryColor, size: 56),
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
                          _setPhase('Fetching streams…');
                          _statusLine = '';
                        });
                        _bootstrap();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
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
          fadeOutNotifier: _fadeOutNotifier,
          subtitle: episodeLabel,
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
