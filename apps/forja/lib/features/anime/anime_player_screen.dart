// Anime player — Miruro-first stream resolution with AnimeRealms fallback.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/anime/catalog/animerealms_extractor.dart';
import 'package:forja/features/anime/catalog/miruro_extractor.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/app_router.dart';

Movie _hubMovieFromAnime(AnimeCard anime) => Movie(
      id: -anime.id,
      title: anime.displayTitle,
      posterPath: anime.coverUrl,
      backdropPath: anime.bannerOrCover,
      voteAverage: (anime.averageScore ?? 0) / 10.0,
      releaseDate: anime.seasonYear?.toString() ?? '',
      overview: anime.cleanDescription,
      genres: anime.genres,
      runtime: anime.duration ?? 0,
      mediaType: 'tv',
      numberOfEpisodes: anime.episodes ?? 0,
    );

List<PlayerHubEpisode> _hubEpisodesFromAnime(List<AnimeEpisode> episodes) =>
    episodes
        .map(
          (e) => PlayerHubEpisode(
            number: e.number,
            title: e.title,
            thumbnailUrl: e.thumbnail,
          ),
        )
        .toList();

Future<T?> openAnimePlayer<T>(
  BuildContext context, {
  required AnimeCard anime,
  required int episodeNumber,
  String category = 'sub',
  String provider = 'kiwi',
  bool useAnimeRealms = false,
  String? episodeId,
  List<AnimeEpisode> allEpisodes = const [],
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute(
      builder: (_) => AnimePlayerScreen(
        anime: anime,
        episodeNumber: episodeNumber,
        category: category,
        provider: provider,
        useAnimeRealms: useAnimeRealms,
        episodeId: episodeId,
        allEpisodes: allEpisodes,
      ),
    ),
  );
}

class AnimePlayerScreen extends StatefulWidget {
  final AnimeCard anime;
  final int episodeNumber;
  final String category;
  final String provider;
  final bool useAnimeRealms;
  final String? episodeId;
  final List<AnimeEpisode> allEpisodes;

  const AnimePlayerScreen({
    super.key,
    required this.anime,
    required this.episodeNumber,
    this.category = 'sub',
    this.provider = 'kiwi',
    this.useAnimeRealms = false,
    this.episodeId,
    this.allEpisodes = const [],
  });

  @override
  State<AnimePlayerScreen> createState() => _AnimePlayerScreenState();
}

String _langCodeFromLabel(String label) {
  final l = label.trim().toLowerCase();
  if (l.isEmpty) return 'und';
  if (RegExp(r'^[a-z]{2,3}([-_][a-z0-9]+)?$').hasMatch(l)) return l;
  const map = <String, String>{
    'english': 'en',
    'arabic': 'ar',
    'spanish': 'es',
    'french': 'fr',
    'german': 'de',
    'italian': 'it',
    'portuguese': 'pt',
    'russian': 'ru',
    'japanese': 'ja',
    'korean': 'ko',
    'chinese': 'zh',
  };
  if (map.containsKey(l)) return map[l]!;
  return l;
}

class _AnimePlayerScreenState extends State<AnimePlayerScreen> {
  final AnimeService _service = AnimeService();
  final MiruroExtractor _miruro = MiruroExtractor();
  final AnimeRealmsExtractor _animeRealms = AnimeRealmsExtractor();

  String _phase = 'Loading…';
  bool _failed = false;
  bool _resolving = false;
  String _activeProvider = '';
  bool _usingAnimeRealms = false;

  @override
  void initState() {
    super.initState();
    _activeProvider = widget.provider;
    _usingAnimeRealms = widget.useAnimeRealms;
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() {
      _resolving = true;
      _failed = false;
      _phase = _usingAnimeRealms
          ? 'Fetching from $_activeProvider…'
          : 'Fetching stream from $_activeProvider…';
    });

    if (_usingAnimeRealms) {
      final ok = await _tryAnimeRealms();
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _resolving = false;
          _failed = true;
          _phase = 'No streams available';
        });
      }
      return;
    }

    final miruro = await _miruro.extractWithProvider(
      anilistId: widget.anime.id,
      episodeNumber: widget.episodeNumber,
      category: widget.category,
      provider: _activeProvider,
    );
    if (!mounted) return;
    if (miruro != null && miruro.url.isNotEmpty) {
      await _launchFromMiruro(miruro);
      return;
    }

    debugPrint(
        '[AnimePlayer] Miruro $_activeProvider empty, trying AnimeRealms…');
    setState(() {
      _usingAnimeRealms = true;
      _phase = 'Trying AnimeRealms…';
    });
    final ok = await _tryAnimeRealms();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _resolving = false;
        _failed = true;
        _phase = 'No streams available';
      });
    }
  }

  Future<bool> _tryAnimeRealms() async {
    try {
      final data = await _animeRealms.getStreams(
        provider: _activeProvider,
        anilistId: widget.anime.id,
        episodeNumber: widget.episodeNumber,
      );
      final streams = (data['streams'] as List?) ?? [];
      final real = streams
          .where((s) =>
              s is Map &&
              s['url'] != null &&
              !(s['url'] as String).contains('test-streams.mux.dev'))
          .cast<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (real.isNotEmpty) {
        await _launchFromAnimeRealms(
          real,
          (data['subtitles'] as List?) ?? const [],
          _activeProvider,
        );
        return true;
      }

      setState(() => _phase = 'Trying other providers…');
      final all = await _animeRealms.getAllSources(
        anilistId: widget.anime.id,
        episodeNumber: widget.episodeNumber,
      );
      if (!mounted || all.isEmpty) return false;
      final best = all.first;
      await _launchFromAnimeRealms(
        (best['streams'] as List).cast<Map<String, dynamic>>(),
        (best['subtitles'] as List?) ?? const [],
        best['provider'] as String,
      );
      return true;
    } catch (e) {
      debugPrint('[AnimePlayer] AnimeRealms failed: $e');
      return false;
    }
  }

  Future<void> _launchFromMiruro(MiruroResult res) async {
    final subs = res.tracks
        .map((t) => <String, dynamic>{
              'url': t.url,
              'display': t.label,
              'language': _langCodeFromLabel(
                t.language.isNotEmpty ? t.language : t.label,
              ),
              'referer': res.referer,
              'origin': res.origin,
            })
        .toList();

    final headers = <String, String>{
      'Referer': res.referer,
      'Origin': res.origin,
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    };

    final ls = LocalServerService();
    var url = res.url;
    Map<String, String>? srcHeaders = headers;
    if (url.contains('.m3u8') && ls.port != 0) {
      url = ls.getHlsProxyUrl(url, headers);
      srcHeaders = null;
    }

    final sources = [
      StreamSource(
        url: url,
        title: 'Miruro · $_activeProvider',
        type: res.url.contains('.m3u8') ? 'hls' : 'video',
        headers: srcHeaders,
      ),
    ];

    await _openPlayer(
      streamUrl: url,
      headers: srcHeaders,
      sources: sources,
      providerLabel: 'miruro_$_activeProvider',
      externalSubtitles: subs.isNotEmpty ? subs : null,
    );
  }

  Future<void> _launchFromAnimeRealms(
    List<Map<String, dynamic>> streams,
    List rawSubs,
    String provider,
  ) async {
    _activeProvider = provider;
    _usingAnimeRealms = true;

    final playable = streams
        .map((s) {
          final url = (s['url'] as String?) ?? '';
          if (url.isEmpty) return null;
          final hdrs = s['headers'] as Map<String, dynamic>?;
          final referer = hdrs?['Referer'] as String?;
          final isHls = url.contains('.m3u8');
          return (
            url: url,
            referer: referer,
            quality: (s['quality'] as String?) ?? 'Default',
            type: isHls ? 'hls' : 'video',
          );
        })
        .whereType<({String url, String? referer, String quality, String type})>()
        .toList();

    if (playable.isEmpty) return;

    final best = playable.first;
    final headers = <String, String>{};
    if (best.referer != null && best.referer!.isNotEmpty) {
      headers['Referer'] = best.referer!;
    }

    final ls = LocalServerService();
    final sources = <StreamSource>[];
    for (final s in playable) {
      var url = s.url;
      Map<String, String>? srcHeaders;
      if (s.referer != null && s.referer!.isNotEmpty) {
        srcHeaders = {'Referer': s.referer!};
      }
      if (url.contains('.m3u8') && ls.port != 0 && srcHeaders != null) {
        url = ls.getHlsProxyUrl(url, srcHeaders);
        srcHeaders = null;
      }
      sources.add(StreamSource(
        url: url,
        title: '${s.quality} ($provider)',
        type: s.type,
        headers: srcHeaders,
      ));
    }

    final subs = rawSubs
        .whereType<Map>()
        .map((s) => <String, dynamic>{
              'url': s['url'] ?? s['file'] ?? '',
              'display': s['label'] ?? 'Unknown',
              'language': s['language'] ?? '',
            })
        .where((s) => (s['url'] as String).isNotEmpty)
        .toList();

    await _openPlayer(
      streamUrl: sources.first.url,
      headers: headers.isNotEmpty ? headers : null,
      sources: sources,
      providerLabel: 'animerealms_$provider',
      externalSubtitles: subs.isNotEmpty ? subs : null,
    );
  }

  Future<void> _openPlayer({
    required String streamUrl,
    Map<String, String>? headers,
    required List<StreamSource> sources,
    required String providerLabel,
    List<Map<String, dynamic>>? externalSubtitles,
  }) async {
    await _service.recordWatch(
      anime: widget.anime,
      episodeNumber: widget.episodeNumber,
      category: widget.category,
      provider: _activeProvider,
      useAnimeRealms: _usingAnimeRealms,
    );

    var episodes = widget.allEpisodes;
    if (episodes.isEmpty) {
      episodes = await _service.getEpisodes(widget.anime);
    }
    final hubEpisodes = _hubEpisodesFromAnime(episodes);
    AnimeEpisode? currentEp;
    for (final e in episodes) {
      if (e.number == widget.episodeNumber) {
        currentEp = e;
        break;
      }
    }

    final totalEpisodes = episodes.isNotEmpty
        ? episodes.length
        : (widget.anime.episodes ?? 0);
    final hasNext = totalEpisodes > widget.episodeNumber;

    final title =
        '${widget.anime.displayTitle} • Ep ${widget.episodeNumber} ($_activeProvider)';

    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    await navigator.pushReplacement(
      AppRouter.fadeRoute(
        (_) => PlayerScreen(
          streamUrl: streamUrl,
          title: title,
          headers: headers,
          sources: sources,
          activeProvider: providerLabel,
          externalSubtitles: externalSubtitles,
          movie: _hubMovieFromAnime(widget.anime),
          hubEpisodes: hubEpisodes,
          hubEpisodeNumber: widget.episodeNumber,
          episodeOverview: currentEp?.title,
          onHubEpisodeSelected: (ep) async {
            await navigator.pushReplacement(
              AppRouter.fadeRoute(
                (_) => AnimePlayerScreen(
                  anime: widget.anime,
                  episodeNumber: ep.number.toInt(),
                  category: widget.category,
                  provider: _activeProvider,
                  useAnimeRealms: _usingAnimeRealms,
                  allEpisodes: episodes,
                ),
              ),
            );
          },
          onSaveProgress: (pos, dur) async {
            await _service.recordWatch(
              anime: widget.anime,
              episodeNumber: widget.episodeNumber,
              category: widget.category,
              provider: _activeProvider,
              useAnimeRealms: _usingAnimeRealms,
              position: pos,
              duration: dur,
            );
          },
          hasNextEpisode: hasNext,
          onNextEpisode: hasNext
              ? () async {
                  await navigator.pushReplacement(
                    AppRouter.fadeRoute(
                      (_) => AnimePlayerScreen(
                        anime: widget.anime,
                        episodeNumber: widget.episodeNumber + 1,
                        category: widget.category,
                        provider: _activeProvider,
                        useAnimeRealms: _usingAnimeRealms,
                        allEpisodes: episodes,
                      ),
                    ),
                  );
                }
              : null,
        ),
      ),
    );
  }

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
              '${widget.anime.displayTitle} • EP ${widget.episodeNumber}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                    CircularProgressIndicator(
                        color: theme.primaryColor, strokeWidth: 2.5),
                    const SizedBox(height: 18),
                  ] else if (_failed) ...[
                    Icon(Icons.error_outline,
                        color: theme.primaryColor, size: 48),
                    const SizedBox(height: 12),
                  ],
                  Text(_phase,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  if (_failed) ...[
                    const SizedBox(height: 22),
                    TextButton.icon(
                      onPressed: _resolve,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                          foregroundColor: theme.primaryColor),
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
