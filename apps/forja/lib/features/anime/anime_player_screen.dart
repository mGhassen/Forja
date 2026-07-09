// Anime player — Miruro-first stream resolution with AnimeRealms fallback.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:forja/features/anime/catalog/anime_provider_map.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/anime/catalog/animerealms_extractor.dart';
import 'package:forja/features/anime/catalog/miruro_extractor.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
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
    AppRouter.fadeRoute(
      (_) => AnimePlayerScreen(
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

String _decodeEpisodeTitle(String title) => title
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

class _AnimePlayerScreenState extends State<AnimePlayerScreen> {
  final AnimeService _service = AnimeService();
  final MiruroExtractor _miruro = MiruroExtractor();
  final AnimeRealmsExtractor _animeRealms = AnimeRealmsExtractor();

  late final ValueNotifier<String> _messageNotifier;
  late final ValueNotifier<bool> _fadeOutNotifier;

  String _activeProvider = '';
  bool _usingAnimeRealms = false;
  bool _failed = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _activeProvider = widget.provider;
    _usingAnimeRealms = widget.useAnimeRealms;
    _messageNotifier = ValueNotifier(
      _usingAnimeRealms
          ? 'Fetching from $_activeProvider…'
          : 'Fetching stream from $_activeProvider…',
    );
    _fadeOutNotifier = ValueNotifier(false);
    _resolve();
  }

  @override
  void dispose() {
    _cancelled = true;
    _messageNotifier.dispose();
    _fadeOutNotifier.dispose();
    super.dispose();
  }

  void _setPhase(String phase) {
    _messageNotifier.value = phase;
  }

  Future<void> _resolve() async {
    if (_cancelled) return;
    setState(() => _failed = false);
    _setPhase(
      _usingAnimeRealms
          ? 'Fetching from $_activeProvider…'
          : 'Fetching stream from $_activeProvider…',
    );

    if (kDebugMode) {
      debugPrint(
        '[AnimePlayer] start anilist=${widget.anime.id} '
        '"${widget.anime.displayTitle}" ep=${widget.episodeNumber} '
        'cat=${widget.category} provider=$_activeProvider '
        'useAnimeRealms=$_usingAnimeRealms',
      );
    }

    if (_usingAnimeRealms) {
      final ok = await _tryAnimeRealms();
      if (!mounted || _cancelled) return;
      if (!ok) {
        setState(() => _failed = true);
        _setPhase('No streams available');
      }
      return;
    }

    final miruro = await _miruro.extractWithProvider(
      anilistId: widget.anime.id,
      episodeNumber: widget.episodeNumber,
      category: widget.category,
      provider: _activeProvider,
    );
    if (!mounted || _cancelled) return;
    if (miruro != null && miruro.url.isNotEmpty) {
      await _launchFromMiruro(miruro);
      return;
    }

    debugPrint(
        '[AnimePlayer] Miruro $_activeProvider empty, trying AnimeRealms…');
    _usingAnimeRealms = true;
    _setPhase('Trying AnimeRealms…');
    final ok = await _tryAnimeRealms(
      preferredProvider: toAnimeRealmsProvider(_activeProvider),
    );
    if (!mounted || _cancelled) return;
    if (!ok) {
      setState(() => _failed = true);
      _setPhase('No streams available');
    }
  }

  Future<bool> _tryAnimeRealms({String? preferredProvider}) async {
    try {
      final arProvider = preferredProvider ?? _activeProvider;
      final data = await _animeRealms.getStreams(
        provider: arProvider,
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
          arProvider,
        );
        return true;
      }

      _setPhase('Trying other providers…');
      final all = await _animeRealms.getAllSources(
        anilistId: widget.anime.id,
        episodeNumber: widget.episodeNumber,
      );
      if (!mounted || _cancelled || all.isEmpty) return false;
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

    var url = res.url;
    Map<String, String>? srcHeaders = headers;
    final ls = LocalServerService();
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
    if (_cancelled || !mounted) return;

    final episodeId = widget.episodeId ??
        widget.allEpisodes
            .where((e) => e.number == widget.episodeNumber)
            .map((e) => e.streamId)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .firstOrNull;

    await _service.recordWatch(
      anime: widget.anime,
      episodeNumber: widget.episodeNumber,
      category: widget.category,
      provider: _activeProvider,
      useAnimeRealms: _usingAnimeRealms,
      episodeId: episodeId,
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

    if (!mounted || _cancelled) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final resolverRoute = ModalRoute.of(context);

    Future<void> openEpisode(int epNumber) async {
      final epMatch =
          episodes.where((e) => e.number == epNumber).firstOrNull;
      await navigator.pushReplacement(
        AppRouter.fadeRoute(
          (_) => AnimePlayerScreen(
            anime: widget.anime,
            episodeNumber: epNumber,
            category: widget.category,
            provider: _activeProvider,
            useAnimeRealms: _usingAnimeRealms,
            episodeId: epMatch?.streamId,
            allEpisodes: episodes,
          ),
        ),
      );
    }

    _fadeOutNotifier.value = true;
    final playerFuture = AppRouter.openPlayer(
      context,
      streamUrl: streamUrl,
      title: title,
      headers: headers,
      sources: sources,
      activeProvider: providerLabel,
      externalSubtitles: externalSubtitles,
      movie: _hubMovieFromAnime(widget.anime),
      hubEpisodes: hubEpisodes,
      hubEpisodeNumber: widget.episodeNumber,
      episodeOverview: currentEp != null
          ? _decodeEpisodeTitle(currentEp.title)
          : null,
      onHubEpisodeSelected: (ep) => openEpisode(ep.number.toInt()),
      onSaveProgress: (pos, dur) async {
        await _service.recordWatch(
          anime: widget.anime,
          episodeNumber: widget.episodeNumber,
          category: widget.category,
          provider: _activeProvider,
          useAnimeRealms: _usingAnimeRealms,
          episodeId: episodeId,
          position: pos,
          duration: dur,
        );
      },
      hasNextEpisode: hasNext,
      onNextEpisode:
          hasNext ? () => openEpisode(widget.episodeNumber + 1) : null,
      fadeTransition: true,
    );
    await Future<void>.delayed(loadingOverlayFadeOutDuration);
    if (resolverRoute != null) {
      navigator.removeRoute(resolverRoute);
    }
    await playerFuture;
  }

  Widget _buildFailure(AppThemePreset theme) {
    final backdropUrl = widget.anime.bannerOrCover;
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
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _resolve,
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
    final movie = _hubMovieFromAnime(widget.anime);

    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, theme, _) {
        if (_failed) return _buildFailure(theme);

        return LoadingOverlay(
          movie: movie,
          messageNotifier: _messageNotifier,
          fadeOutNotifier: _fadeOutNotifier,
          subtitle: 'EP ${widget.episodeNumber}',
          onCancel: () {
            _cancelled = true;
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
