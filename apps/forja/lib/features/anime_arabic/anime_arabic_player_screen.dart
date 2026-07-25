// Anime Arabic player resolver: cracks streamData, then races every
// available iframe through StreamExtractor in parallel. The first hit
// triggers a short grace window so slower extractors land as fallbacks
// for the in-player source switcher. No UI to pick servers - auto only.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:forja/features/anime_arabic/catalog/anime_arabic_extractor.dart';
import 'package:forja/features/anime_arabic/catalog/anime_arabic_service.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:rust/rust.dart';

class AnimeArabicPlayerScreen extends StatefulWidget {
  final ArabicAnimeCard anime;
  final ArabicEpisode episode;
  final List<ArabicEpisode> allEpisodes;
  final Duration? startPosition;

  const AnimeArabicPlayerScreen({
    super.key,
    required this.anime,
    required this.episode,
    this.allEpisodes = const [],
    this.startPosition,
  });

  @override
  State<AnimeArabicPlayerScreen> createState() =>
      _AnimeArabicPlayerScreenState();
}

class _AnimeArabicPlayerScreenState extends State<AnimeArabicPlayerScreen>
    with TickerProviderStateMixin {
  final AnimeArabicService _service = AnimeArabicService();
  final AnimeArabicExtractor _extractor = AnimeArabicExtractor();

  String _phase = 'Fetching streams…';
  String _statusLine = '';
  bool _resolving = true;
  bool _failedAll = false;
  int _serversFound = 0;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _bootstrap();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final hits = await _extractor.resolveEpisode(
        widget.episode,
        onProgress: (phase, detail) {
          if (!mounted) return;
          if (phase == 'error') {
            setState(() => _statusLine = detail);
          }
        },
      );

      if (!mounted) return;
      if (hits.isEmpty) {
        setState(() {
          _resolving = false;
          _failedAll = true;
          _phase = 'No streams available';
          _statusLine = '';
        });
        return;
      }
      _serversFound = hits.length;
      await _launchPlayer(hits);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _failedAll = true;
        _phase = 'Resolver crashed';
        _statusLine = '$e';
      });
    }
  }

  Future<void> _launchPlayer(List<ArabicResolvedStream> hits) async {
    final winner = hits.first;
    final sources = await PlaybackSelection.rankAndDedupe(
      sources: AnimeArabicExtractor.toSources(hits),
      providerId: 'anime_arabic',
    );
    final subs = AnimeArabicExtractor.collectSubtitles(hits);

    await _service.recordWatch(
      anime: widget.anime,
      episodeNumber: widget.episode.number,
      totalEpisodes: widget.allEpisodes.isNotEmpty
          ? widget.allEpisodes.length
          : widget.episode.number,
    );

    final title = '${widget.anime.title} • Ep ${widget.episode.number} '
        '(${winner.server.displayName})';

    // Next-episode detection. When `allEpisodes` was passed in (the normal
    // launch path from the details screen / continue-watching), pick it
    // straight from the list. Otherwise, optimistically assume there *is*
    // a next episode and refetch the details on click.
    ArabicEpisode? nextFromList;
    if (widget.allEpisodes.isNotEmpty) {
      for (final e in widget.allEpisodes) {
        if (e.number == widget.episode.number + 1 &&
            e.watchPath.isNotEmpty) {
          nextFromList = e;
          break;
        }
      }
    }
    final hasNext = widget.allEpisodes.isEmpty
        // Unknown total - let the user try; refetch decides on click.
        ? true
        : nextFromList != null;

    if (!mounted) return;
    final navigator = Navigator.of(context);

    Future<void> goNext() async {
      var ep = nextFromList;
      var list = widget.allEpisodes;
      if (ep == null || ep.watchPath.isEmpty) {
        // Either we never had the list, or the cached next entry is empty.
        // Refetch the details now so we have a fresh slug + watchPath.
        try {
          final det = await _service.getDetails(widget.anime.slug);
          list = det.episodes;
          for (final e in det.episodes) {
            if (e.number == widget.episode.number + 1 &&
                e.watchPath.isNotEmpty) {
              ep = e;
              break;
            }
          }
        } catch (_) {}
      }
      if (ep == null || ep.watchPath.isEmpty) return;
      await navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => AnimeArabicPlayerScreen(
            anime: widget.anime,
            episode: ep!,
            allEpisodes: list,
          ),
        ),
      );
    }

    await navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: sources.first.url,
          title: title,
          headers: sources.first.headers,
          sources: sources,
          activeProvider: winner.server.name,
          startPosition: widget.startPosition,
          externalSubtitles: subs.isNotEmpty ? subs : null,
          onSaveProgress: (pos, dur) async {
            await _service.recordWatch(
              anime: widget.anime,
              episodeNumber: widget.episode.number,
              totalEpisodes: widget.allEpisodes.isNotEmpty
                  ? widget.allEpisodes.length
                  : widget.episode.number,
              position: pos,
              duration: dur,
            );
          },
          hasNextEpisode: hasNext,
          onNextEpisode: hasNext ? goNext : null,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: theme.bgDark,
          appBar: AppBar(
            backgroundColor: theme.bgDark,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              '${widget.anime.title} • EP ${widget.episode.number}',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_resolving) ...[
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, child) => Transform.scale(
                        scale: 0.92 + (_pulseCtrl.value * 0.18),
                        child: child,
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              theme.primaryColor.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ] else if (_failedAll) ...[
                    Icon(Icons.error_outline,
                        color: theme.primaryColor, size: 56),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    _phase,
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
                  if (_serversFound > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$_serversFound source${_serversFound > 1 ? 's' : ''}'
                      ' ready',
                      style: TextStyle(
                        color: theme.primaryColor.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (_failedAll) ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _resolving = true;
                          _failedAll = false;
                          _phase = 'Fetching streams…';
                          _statusLine = '';
                        });
                        _bootstrap();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3)),
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
                            color:
                                Colors.white.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
