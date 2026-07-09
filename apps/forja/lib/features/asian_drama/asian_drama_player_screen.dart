// Asian Drama (kisskh.co) per-episode resolver. Single extraction path
// (no multi-server fan-out) that runs `KissKhExtractor` against a hidden
// WebView, then hands the resulting URL + subtitles to `PlayerScreen`.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:forja/features/asian_drama/catalog/kisskh_extractor.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
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
  return Navigator.of(context, rootNavigator: true).push<T>(
    AppRouter.fadeRoute(
      (_) => AsianDramaPlayerScreen(
        drama: drama,
        episode: episode,
        allEpisodes: allEpisodes,
        startPosition: startPosition,
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

  Future<void> _bootstrap() async {
    try {
      final stream = await _extractor.resolve(
        dramaId: widget.drama.id,
        dramaTitle: widget.drama.title,
        episodeId: widget.episode.id,
        episodeNumber: widget.episode.number,
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

    var drama = widget.drama;
    var episodes = widget.allEpisodes;
    var overview = '';
    if (episodes.isEmpty) {
      try {
        final det = await _service.getDetails(widget.drama.id);
        episodes = det.episodes;
        overview = det.description;
        drama = det.toCard();
      } catch (_) {}
    }

    await _service.recordWatch(
      drama: widget.drama,
      episodeNumber: widget.episode.number,
      totalEpisodes: episodes.isNotEmpty
          ? episodes.length
          : widget.episode.number.toInt(),
    );

    final title =
        '${widget.drama.title} • EP ${widget.episode.displayNumber}';

    KdramaEpisode? nextFromList;
    if (episodes.isNotEmpty) {
      for (final e in episodes) {
        if (e.number == widget.episode.number + 1) {
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
          final det = await _service.getDetails(widget.drama.id);
          list = det.episodes;
          for (final e in det.episodes) {
            if (e.number == widget.episode.number + 1) {
              ep = e;
              break;
            }
          }
        } catch (_) {}
      }
      if (ep == null) return;
      await navigator.pushReplacement(
        AppRouter.fadeRoute(
          (_) => AsianDramaPlayerScreen(
            drama: widget.drama,
            episode: ep!,
            allEpisodes: list,
          ),
        ),
      );
    }

    _fadeOutNotifier.value = true;
    final playerFuture = AppRouter.openPlayer(
      context,
      streamUrl: sources.first.url,
      title: title,
      headers: sources.first.headers,
      sources: sources,
      activeProvider: 'kisskh',
      movie: _hubMovieFromDrama(drama, overview: overview),
      startPosition: widget.startPosition,
      externalSubtitles: subs.isNotEmpty ? subs : null,
      hubEpisodes: hubEpisodes,
      hubEpisodeNumber: widget.episode.number,
      episodeOverview: 'Episode ${widget.episode.displayNumber}',
      onHubEpisodeSelected: (ep) async {
        KdramaEpisode? target;
        for (final e in episodes) {
          if (e.number == ep.number) {
            target = e;
            break;
          }
        }
        if (target == null) return;
        await navigator.pushReplacement(
          AppRouter.fadeRoute(
            (_) => AsianDramaPlayerScreen(
              drama: widget.drama,
              episode: target!,
              allEpisodes: episodes,
            ),
          ),
        );
      },
      onSaveProgress: (pos, dur) async {
        await _service.recordWatch(
          drama: widget.drama,
          episodeNumber: widget.episode.number,
          totalEpisodes: episodes.isNotEmpty
              ? episodes.length
              : widget.episode.number.toInt(),
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
