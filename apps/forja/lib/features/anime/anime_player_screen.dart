// Anime player resolver: cascades through every available source for the
// chosen category (sub OR dub) until one returns a playable stream.
// No UI for switching audio or picking servers — just a loader.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:api/api/anime_service.dart';
import 'package:api/api/stream_extractor.dart';
import 'package:api/models/stream_source.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';

class AnimePlayerScreen extends StatefulWidget {
  final AnimeCard anime;
  final int episodeNumber;
  final String category; // initial 'sub' | 'dub'
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

// Best-effort mapping of human-readable subtitle labels (as returned by
// megaplay/vidwish) to ISO 639-1 codes so the player UI can group them.
String _langCodeFromLabel(String label) {
  final l = label.trim().toLowerCase();
  if (l.isEmpty) return 'und';
  // Already a 2/3-letter code or a region tag like en-US
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
  // Strip parenthetical region suffix and retry (e.g. "Spanish (Spain)" → "spanish")
  final stripped = l.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim();
  if (stripped != l && map.containsKey(stripped)) return map[stripped]!;
  return l;
}

class _AnimePlayerScreenState extends State<AnimePlayerScreen> {
  final AnimeService _service = AnimeService();
  List<AnimeEmbed> _allEmbeds = const [];
  AnikotoSeries? _series;
  late String _category;
  // ignore: unused_field
  AnimeEmbed? _activeEmbed;
  String _phase = 'Loading…';
  String _statusLine = '';
  bool _failedAll = false;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _resolving = true;
      _phase = 'Looking up episode…';
    });
    // Resolve Anikoto series first so we can build /stream/s-2/{embedId}/...
    // URLs (much more reliable than the anilist-mapped /stream/ani/... ones).
    _series = await _service.resolveAnikoto(widget.anime);
    if (!mounted) return;
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
    setState(() {});
    await _resolveForCategory();
  }

  List<AnimeEmbed> get _currentPair =>
      _allEmbeds.where((e) => e.category == _category).toList();

  Future<void> _resolveForCategory() async {
    setState(() {
      _resolving = true;
      _failedAll = false;
      _statusLine = '';
      _phase = 'Finding a stream…';
    });
    final pair = _currentPair;
    if (pair.isEmpty) {
      setState(() {
        _resolving = false;
        _failedAll = true;
        _phase = 'No streams available';
      });
      return;
    }

    // Race every source in parallel. The FIRST success starts a short grace
    // window during which we wait for slower extractors to land — those become
    // automatic fallbacks if the winner's CDN is dead (Miruro's rrr.pro25zone
    // links 404 frequently). After the grace expires, we launch with whatever
    // succeeded, ordered: winner first, then the rest in completion order.
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
          // First hit → start grace window for backups.
          if (successes.length == 1 && !completer.isCompleted) {
            graceTimer = Timer(graceWindow, () {
              if (!completer.isCompleted) completer.complete(successes);
            });
          }
        }
        if (mounted && !completer.isCompleted) {
          setState(() => _statusLine =
              '$settled / $total checked${successes.isNotEmpty ? ' \u00b7 ${successes.length} ready' : ''}');
        }
        finishIfReady();
      }).catchError((_) {
        settled++;
        finishIfReady();
      });
    }

    final hits = await completer.future;
    if (!mounted) return;
    if (hits.isNotEmpty) {
      _activeEmbed = hits.first.embed;
      await _launchPlayer(hits);
      return;
    }
    setState(() {
      _resolving = false;
      _failedAll = true;
      _phase = _series == null && _currentPair.every((e) => e.server != 'megaplay' && e.server != 'vidwish')
          ? 'Catalog lookup failed'
          : 'No streams available';
      _statusLine = '';
    });
  }

  Future<ExtractedMedia?> _tryEmbed(AnimeEmbed embed) async {
    // megaplay & vidwish expose /stream/getSources?id={dataId}
    // returning the m3u8 directly. Pure HTTP — no webview.
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
                // Subtitle CDNs (megacloud, vid-cdn, etc.) gate on the
                // embed's Referer/Origin — not the sub URL's own host.
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
    final winner = hits.first;
    await _service.recordWatch(
      anime: widget.anime,
      episodeNumber: widget.episodeNumber,
      category: _category,
    );

    // Each provider needs its own Referer/Origin (Miruro CDN gates on
    // miruro.tv, AllAnime on allmanga.to, etc). Encode that into each
    // StreamSource so PlayerScreen's per-source headers fallback works.
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

    // Aggregate subtitle tracks across all hits. Most extractors return
    // the same set, but a stale/dead source's subs would be lost if we
    // only kept the winner's.
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
        '${widget.anime.displayTitle} \u2022 Ep ${widget.episodeNumber} (${winner.embed.displayName})';

    final totalEpisodes = _series?.episodes.length ??
        (widget.allEpisodes.isNotEmpty
            ? widget.allEpisodes.length
            : (widget.anime.episodes ?? 0));
    final hasNext = totalEpisodes > widget.episodeNumber;

    if (!mounted) return;
    final navigator = Navigator.of(context);
    await navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: winner.media.url,
          title: title,
          headers: winnerHeaders,
          sources: sources,
          activeProvider: winner.embed.server,
          externalSubtitles: allSubs.isNotEmpty ? allSubs : null,
          hasNextEpisode: hasNext,
          onNextEpisode: hasNext
              ? () async {
                  await navigator.pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AnimePlayerScreen(
                        anime: widget.anime,
                        episodeNumber: widget.episodeNumber + 1,
                        category: _category,
                        allEpisodes: widget.allEpisodes,
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
                    CircularProgressIndicator(color: theme.primaryColor, strokeWidth: 2.5),
                    const SizedBox(height: 18),
                  ] else if (_failedAll) ...[
                    Icon(Icons.error_outline, color: theme.primaryColor, size: 48),
                    const SizedBox(height: 12),
                  ],
                  Text(_phase, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  if (_statusLine.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(_statusLine,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                        textAlign: TextAlign.center),
                  ],
                  if (_failedAll) ...[
                    const SizedBox(height: 22),
                    TextButton.icon(
                      onPressed: _resolveForCategory,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(foregroundColor: theme.primaryColor),
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

