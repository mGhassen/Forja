// Anime player resolver: races every available source for the chosen
// category (sub OR dub) until one returns a playable stream.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
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
  List<AnimeEpisode> allEpisodes = const [],
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    AppRouter.fadeRoute(
      (_) => AnimePlayerScreen(
        anime: anime,
        episodeNumber: episodeNumber,
        category: category,
        allEpisodes: allEpisodes,
      ),
    ),
  );
}

class AnimePlayerScreen extends StatefulWidget {
  final AnimeCard anime;
  final int episodeNumber;
  final String category;
  final List<AnimeEpisode> allEpisodes;

  const AnimePlayerScreen({
    super.key,
    required this.anime,
    required this.episodeNumber,
    this.category = 'sub',
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
    'spanish - latin america': 'es',
    'spanish (latin america)': 'es',
    'spanish (spain)': 'es',
    'european spanish': 'es',
    'french': 'fr',
    'german': 'de',
    'italian': 'it',
    'portuguese': 'pt',
    'portuguese - brazilian': 'pt-br',
    'portuguese (brazil)': 'pt-br',
    'brazilian portuguese': 'pt-br',
    'russian': 'ru',
    'turkish': 'tr',
    'dutch': 'nl',
    'polish': 'pl',
    'japanese': 'ja',
    'korean': 'ko',
    'chinese': 'zh',
    'chinese - simplified': 'zh-cn',
    'chinese - traditional': 'zh-tw',
    'simplified chinese': 'zh-cn',
    'traditional chinese': 'zh-tw',
    'hindi': 'hi',
    'indonesian': 'id',
    'thai': 'th',
    'vietnamese': 'vi',
    'swedish': 'sv',
    'danish': 'da',
    'norwegian': 'no',
    'finnish': 'fi',
    'czech': 'cs',
    'greek': 'el',
    'hebrew': 'he',
    'romanian': 'ro',
    'hungarian': 'hu',
    'ukrainian': 'uk',
    'malay': 'ms',
    'filipino': 'tl',
    'tagalog': 'tl',
  };
  if (map.containsKey(l)) return map[l]!;
  final stripped = l.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim();
  if (stripped != l && map.containsKey(stripped)) return map[stripped]!;
  return l;
}

int _sourcePriority(AnimeEmbed embed) {
  switch (embed.server) {
    case 'megaplay':
      return 0;
    case 'vidwish':
      return 1;
    case 'miruro':
      return 2;
    case 'allanime':
      return 3;
    default:
      return 4;
  }
}

String _decodeEpisodeTitle(String title) => title
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

class _AnimePlayerScreenState extends State<AnimePlayerScreen> {
  final AnimeService _service = AnimeService();
  List<AnimeEmbed> _allEmbeds = const [];
  AnikotoSeries? _series;
  late String _category;
  // ignore: unused_field
  AnimeEmbed? _activeEmbed;

  late final ValueNotifier<String> _messageNotifier;
  late final ValueNotifier<bool> _fadeOutNotifier;

  String _statusLine = '';
  bool _failedAll = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _messageNotifier = ValueNotifier('Looking up episode…');
    _fadeOutNotifier = ValueNotifier(false);
    _bootstrap();
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

  Future<void> _bootstrap() async {
    _setPhase('Looking up episode…');
    _series = await _service.resolveAnikoto(widget.anime);
    if (!mounted || _cancelled) return;
    if (_series == null) {
      debugPrint(
          '[AnimePlayer] Anikoto catalog miss for ${widget.anime.displayTitle} '
          '(anilist ${widget.anime.id})');
    }
    _allEmbeds = _service.buildAllEmbeds(
      anilistId: widget.anime.id,
      episode: widget.episodeNumber,
      series: _series,
      animeTitles: [
        widget.anime.titleEnglish,
        widget.anime.titleRomaji,
        widget.anime.titleNative,
      ],
      isAdult: widget.anime.isAdult,
    );
    await _resolveForCategory();
  }

  List<AnimeEmbed> get _currentPair =>
      _allEmbeds.where((e) => e.category == _category).toList();

  Future<void> _resolveForCategory() async {
    if (_cancelled) return;
    setState(() {
      _failedAll = false;
      _statusLine = '';
    });
    _setPhase('Finding a stream…');

    final pair = _currentPair;
    if (pair.isEmpty) {
      setState(() => _failedAll = true);
      _setPhase('No streams available');
      return;
    }

    const graceWindow = Duration(seconds: 4);
    final completer =
        Completer<List<({AnimeEmbed embed, ExtractedMedia media})>>();
    final successes = <({AnimeEmbed embed, ExtractedMedia media})>[];
    var settled = 0;
    final total = pair.length;
    Timer? graceTimer;

    void finishIfReady() {
      if (completer.isCompleted) return;
      if (settled >= total) {
        graceTimer?.cancel();
        completer.complete(successes);
      }
    }

    for (final embed in pair) {
      _tryEmbed(embed).then((media) {
        settled++;
        if (media != null && media.url.isNotEmpty) {
          successes.add((embed: embed, media: media));
          if (successes.length == 1 && !completer.isCompleted) {
            graceTimer = Timer(graceWindow, () {
              if (!completer.isCompleted) completer.complete(successes);
            });
          }
        }
        if (mounted && !completer.isCompleted) {
          setState(() => _statusLine =
              '$settled / $total checked${successes.isNotEmpty ? ' · ${successes.length} ready' : ''}');
        }
        finishIfReady();
      }).catchError((_) {
        settled++;
        finishIfReady();
      });
    }

    final hits = await completer.future;
    if (!mounted || _cancelled) return;
    if (hits.isNotEmpty) {
      final sorted = [...hits]
        ..sort((a, b) =>
            _sourcePriority(a.embed).compareTo(_sourcePriority(b.embed)));
      _activeEmbed = sorted.first.embed;
      await _launchPlayer(sorted);
      return;
    }
    setState(() => _failedAll = true);
    _setPhase(
      _series == null &&
              _currentPair.every(
                  (e) => e.server != 'megaplay' && e.server != 'vidwish')
          ? 'Catalog lookup failed'
          : 'No streams available',
    );
    setState(() => _statusLine = '');
  }

  Future<ExtractedMedia?> _tryEmbed(AnimeEmbed embed) async {
    try {
      final direct = await _service.extractDirect(embed);
      if (direct == null || direct.url.isEmpty) return null;
      final headers = <String, String>{
        'Referer': direct.referer,
        'Origin': direct.origin,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      };
      final subs = direct.tracks
          .map((t) => <String, dynamic>{
                'url': t.url,
                'display': t.label,
                'language': _langCodeFromLabel(t.label),
                'referer': direct.referer,
                'origin': direct.origin,
              })
          .toList();
      return ExtractedMedia(
        url: direct.url,
        headers: headers,
        provider: embed.server,
        sources: [
          StreamSource(
            url: direct.url,
            title: embed.displayName,
            type: 'video',
          ),
        ],
        externalSubtitles: subs.isNotEmpty ? subs : null,
      );
    } catch (e) {
      debugPrint('[AnimePlayer] ${embed.displayName} failed: $e');
      return null;
    }
  }

  Future<void> _launchPlayer(
      List<({AnimeEmbed embed, ExtractedMedia media})> hits) async {
    if (_cancelled || !mounted) return;

    final winner = hits.first;
    await _service.recordWatch(
      anime: widget.anime,
      episodeNumber: widget.episodeNumber,
      category: _category,
    );

    final sources = <StreamSource>[];
    for (final h in hits) {
      final headers = Map<String, String>.from(h.media.headers)
        ..putIfAbsent('Referer', () => '${h.embed.refererOrigin}/')
        ..putIfAbsent('Origin', () => h.embed.refererOrigin);
      sources.add(StreamSource(
        url: h.media.url,
        title: h.embed.displayName,
        type: h.media.url.contains('.m3u8') ? 'hls' : 'video',
        headers: headers,
      ));
    }

    final seenSubs = <String>{};
    final allSubs = <Map<String, dynamic>>[];
    for (final h in hits) {
      for (final s in (h.media.externalSubtitles ?? const [])) {
        final url = s['url']?.toString() ?? '';
        if (url.isEmpty || !seenSubs.add(url)) continue;
        allSubs.add(s);
      }
    }

    final winnerHeaders = sources.first.headers!;
    final title =
        '${widget.anime.displayTitle} • Ep ${widget.episodeNumber} (${winner.embed.displayName})';

    final totalEpisodes = _series?.episodes.length ??
        (widget.allEpisodes.isNotEmpty
            ? widget.allEpisodes.length
            : (widget.anime.episodes ?? 0));
    final hasNext = totalEpisodes > widget.episodeNumber;

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

    if (!mounted || _cancelled) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final resolverRoute = ModalRoute.of(context);

    Future<void> openEpisode(int epNumber) async {
      await navigator.pushReplacement(
        AppRouter.fadeRoute(
          (_) => AnimePlayerScreen(
            anime: widget.anime,
            episodeNumber: epNumber,
            category: _category,
            allEpisodes: episodes,
          ),
        ),
      );
    }

    _fadeOutNotifier.value = true;
    final playerFuture = AppRouter.openPlayer(
      context,
      streamUrl: winner.media.url,
      title: title,
      headers: winnerHeaders,
      sources: sources,
      activeProvider: winner.embed.server,
      externalSubtitles: allSubs.isNotEmpty ? allSubs : null,
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
          category: _category,
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
                      onPressed: _resolveForCategory,
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
    final episodeLabel = _statusLine.isNotEmpty
        ? 'EP ${widget.episodeNumber} · $_statusLine'
        : 'EP ${widget.episodeNumber}';

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
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
