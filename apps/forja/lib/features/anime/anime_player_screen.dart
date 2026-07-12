// Anime player resolver: races every available source for the chosen
// category (sub OR dub) until one returns a playable stream.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/anime/catalog/anime_stream_providers.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/shell/app_router.dart';

typedef _AnimeResolvedHit = ({AnimeEmbed embed, ExtractedMedia media});

/// In-memory resolved streams for the current app session. Avoids re-racing
/// every embed when the user closes the player and reopens the same episode.
class _AnimeStreamSessionCache {
  _AnimeStreamSessionCache._();

  static const _ttl = Duration(hours: 2);
  static const _maxEntries = 32;
  static final _store = <String, ({DateTime at, List<_AnimeResolvedHit> hits})>{};

  static String _key(int animeId, int episode, String category) =>
      '$animeId:$episode:$category';

  static List<_AnimeResolvedHit>? read(
    int animeId,
    int episode,
    String category,
  ) {
    final entry = _store[_key(animeId, episode, category)];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > _ttl) {
      _store.remove(_key(animeId, episode, category));
      return null;
    }
    return entry.hits;
  }

  static void write(
    int animeId,
    int episode,
    String category,
    List<_AnimeResolvedHit> hits,
  ) {
    if (hits.isEmpty) return;
    final key = _key(animeId, episode, category);
    _store[key] = (at: DateTime.now(), hits: hits);
    while (_store.length > _maxEntries) {
      String? oldestKey;
      DateTime? oldestAt;
      for (final e in _store.entries) {
        if (oldestAt == null || e.value.at.isBefore(oldestAt)) {
          oldestAt = e.value.at;
          oldestKey = e.key;
        }
      }
      if (oldestKey == null) break;
      _store.remove(oldestKey);
    }
  }

  static void drop(int animeId, int episode, String category) {
    _store.remove(_key(animeId, episode, category));
  }
}

List<Map<String, dynamic>> _hitsToJson(List<_AnimeResolvedHit> hits) {
  return hits
      .map(
        (h) => {
          'embed': {
            'label': h.embed.label,
            'server': h.embed.server,
            'category': h.embed.category,
            'url': h.embed.url,
          },
          'media': {
            'url': h.media.url,
            if (h.media.audioUrl != null) 'audioUrl': h.media.audioUrl,
            'headers': h.media.headers,
            if (h.media.provider != null) 'provider': h.media.provider,
            if (h.media.sources != null)
              'sources': h.media.sources!
                  .map(
                    (s) => {
                      'url': s.url,
                      'title': s.title,
                      'type': s.type,
                      if (s.headers != null) 'headers': s.headers,
                    },
                  )
                  .toList(),
            if (h.media.externalSubtitles != null)
              'externalSubtitles': h.media.externalSubtitles,
          },
        },
      )
      .toList(growable: false);
}

List<_AnimeResolvedHit>? _hitsFromJson(List<Map<String, dynamic>>? raw) {
  if (raw == null || raw.isEmpty) return null;
  final out = <_AnimeResolvedHit>[];
  for (final entry in raw) {
    final embedMap = (entry['embed'] as Map?)?.cast<String, dynamic>();
    final mediaMap = (entry['media'] as Map?)?.cast<String, dynamic>();
    if (embedMap == null || mediaMap == null) continue;
    final url = (mediaMap['url'] as String?) ?? '';
    if (url.isEmpty) continue;
    final headers = (mediaMap['headers'] as Map?)?.cast<String, String>() ?? {};
    final sourcesRaw = mediaMap['sources'] as List?;
    List<StreamSource>? sources;
    if (sourcesRaw != null) {
      sources = sourcesRaw
          .map((s) {
            final m = (s as Map).cast<String, dynamic>();
            return StreamSource(
              url: m['url'] as String? ?? '',
              title: m['title'] as String? ?? '',
              type: m['type'] as String? ?? 'video',
              headers: (m['headers'] as Map?)?.cast<String, String>(),
            );
          })
          .where((s) => s.url.isNotEmpty)
          .toList();
    }
    out.add((
      embed: AnimeEmbed(
        label: embedMap['label'] as String? ?? '',
        server: embedMap['server'] as String? ?? '',
        category: embedMap['category'] as String? ?? 'sub',
        url: embedMap['url'] as String? ?? '',
      ),
      media: ExtractedMedia(
        url: url,
        audioUrl: mediaMap['audioUrl'] as String?,
        headers: headers,
        provider: mediaMap['provider'] as String?,
        sources: sources,
        externalSubtitles: (mediaMap['externalSubtitles'] as List?)
            ?.map((s) => (s as Map).cast<String, dynamic>())
            .toList(),
      ),
    ));
  }
  return out.isEmpty ? null : out;
}

String _animeStreamSourceTitle(AnimeEmbed embed, AnimeStreamResult direct) {
  final tag = direct.streamLabel?.trim();
  if (tag != null && tag.isNotEmpty) {
    return '${embed.displayName} · $tag';
  }
  return embed.displayName;
}

Future<List<_AnimeResolvedHit>> _quietResolveEmbed(
  AnimeService service,
  AnimeEmbed embed,
) async {
  try {
    final candidates = await service.extractDirectCandidates(embed);
    final out = <_AnimeResolvedHit>[];
    final maxMirrors = embed.server == 'miruro' ? 2 : candidates.length;
    var mirrors = 0;
    for (final direct in candidates) {
      if (mirrors >= maxMirrors) break;
      if (direct.url.isEmpty) continue;
      final headers = <String, String>{
        'Referer': direct.referer,
        'Origin': direct.origin,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      };
      final title = _animeStreamSourceTitle(embed, direct);
      final subs = direct.tracks
          .map((t) => <String, dynamic>{
                'url': t.url,
                'display': t.label,
                'language': _langCodeFromLabel(t.label),
                'referer': direct.referer,
                'origin': direct.origin,
              })
          .toList();
      final isHls = direct.url.contains('.m3u8');
      out.add((
        embed: embed,
        media: ExtractedMedia(
          url: direct.url,
          headers: headers,
          provider: embed.server,
          sources: [
            StreamSource(
              url: direct.url,
              title: title,
              type: isHls ? 'hls' : 'video',
              headers: headers,
            ),
          ],
          externalSubtitles: subs.isNotEmpty ? subs : null,
        ),
      ));
      mirrors++;
    }
    return out;
  } catch (e) {
    debugPrint('[AnimePlayer] reload ${embed.displayName} failed: $e');
    return const [];
  }
}

List<StreamSource> _hitsToStreamSources(List<_AnimeResolvedHit> hits) {
  final sources = <StreamSource>[];
  for (final h in hits) {
    final headers = Map<String, String>.from(h.media.headers);
    if (!headers.containsKey('Referer') || headers['Referer']!.isEmpty) {
      headers['Referer'] = '${h.embed.refererOrigin}/';
      headers.putIfAbsent('Origin', () => h.embed.refererOrigin);
    }
    final sourceTitle =
        h.media.sources?.first.title ?? h.embed.displayName;
    sources.add(StreamSource(
      url: h.media.url,
      title: sourceTitle,
      type: h.media.url.contains('.m3u8') ? 'hls' : 'video',
      headers: headers,
    ));
  }
  return sources;
}

Future<List<StreamSource>?> reloadAnimeEpisodeStreams({
  required AnimeService service,
  required List<AnimeEmbed> allEmbeds,
  required String category,
  List<String> providerOrder = const [],
}) async {
  final pair = allEmbeds.where((e) => e.category == category).toList();
  if (pair.isEmpty) return null;

  final order = providerOrder.isEmpty
      ? await SettingsService().getAnimeProviderOrder()
      : providerOrder;
  final sorted = _sortEmbedsByProviderOrder(pair, order);

  final batches = await Future.wait(
    sorted.map((embed) => _quietResolveEmbed(service, embed)),
  );
  final hits = batches.expand((batch) => batch).toList();
  if (hits.isEmpty) return null;
  final ranked = _rankHitsByOrder(hits, order, null, null);
  final legacy = _hitsToStreamSources(ranked);
  return PlaybackSelection.rankAndDedupe(
    sources: legacy,
    providerId: 'anime',
  );
}

List<AnimeEmbed> _sortEmbedsByProviderOrder(
  List<AnimeEmbed> embeds,
  List<String> order,
) {
  if (order.isEmpty) return embeds;
  final keyed = embeds.map((e) => e.sourceKey).toList();
  final sortedKeys = AnimeStreamProviders.sortKeys(keyed, order);
  final byKey = <String, List<AnimeEmbed>>{};
  for (final e in embeds) {
    byKey.putIfAbsent(e.sourceKey, () => []).add(e);
  }
  final out = <AnimeEmbed>[];
  for (final k in sortedKeys) {
    out.addAll(byKey[k] ?? const []);
  }
  return out;
}

List<({AnimeEmbed embed, ExtractedMedia media})> _rankHitsByOrder(
  List<({AnimeEmbed embed, ExtractedMedia media})> hits,
  List<String> order,
  String? preferredKey,
  String? preferredTitle,
) {
  int rank(({AnimeEmbed embed, ExtractedMedia media}) hit) {
    final title = hit.media.sources?.first.title ?? '';
    if (preferredKey != null && hit.embed.sourceKey == preferredKey) {
      if (preferredTitle != null &&
          preferredTitle.isNotEmpty &&
          title == preferredTitle) {
        return -2;
      }
      return -1;
    }
    final idx = order.indexOf(hit.embed.sourceKey);
    return idx >= 0 ? idx : 1000;
  }

  final sorted = List<({AnimeEmbed embed, ExtractedMedia media})>.from(hits)
    ..sort((a, b) {
      final ra = rank(a);
      final rb = rank(b);
      if (ra != rb) return ra.compareTo(rb);
      final ta = a.media.sources?.first.title ?? '';
      final tb = b.media.sources?.first.title ?? '';
      return ta.compareTo(tb);
    });
  return sorted;
}

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

String? _episodeThumbnail(AnimeEpisode episode, AnimeCard anime) {
  final thumb = (episode.thumbnail ?? '').trim();
  if (thumb.isNotEmpty) return thumb;
  final fallback = anime.bannerOrCover.trim();
  return fallback.isNotEmpty ? fallback : null;
}

List<PlayerHubEpisode> _hubEpisodesFromAnime(
  AnimeCard anime,
  List<AnimeEpisode> episodes,
) =>
    episodes
        .map(
          (e) => PlayerHubEpisode(
            number: e.number,
            title: e.title,
            thumbnailUrl: _episodeThumbnail(e, anime),
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

String _decodeEpisodeTitle(String title) => title
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

class _AnimePlayerScreenState extends State<AnimePlayerScreen> {
  final AnimeService _service = AnimeService();
  final SettingsService _settings = SettingsService();
  List<AnimeEmbed> _allEmbeds = const [];
  List<String> _providerOrder = List<String>.from(
    AnimeStreamProviders.defaultOrder,
  );
  AnikotoSeries? _series;
  late String _category;
  String? _preferredSourceKey;
  String? _preferredSourceTitle;
  // ignore: unused_field
  AnimeEmbed? _activeEmbed;

  late final ValueNotifier<String> _messageNotifier;
  late final ValueNotifier<bool> _fadeOutNotifier;
  late final ValueNotifier<List<StreamProviderProbe>> _probeNotifier;

  String _statusLine = '';
  bool _failedAll = false;
  bool _cancelled = false;
  bool _resolverStopped = false;
  int _autoRecheckUsed = 0;
  bool _awaitingManualRecheck = false;
  bool _launchedFromSavedOrCache = false;
  /// Once the player route is open, keep resolving remaining embeds.
  bool _playerLaunched = false;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _messageNotifier = ValueNotifier('Looking up episode…');
    _fadeOutNotifier = ValueNotifier(false);
    _probeNotifier = ValueNotifier(const []);
    _bootstrap();
  }

  @override
  void dispose() {
    // Don't kill a background fill still feeding the open player.
    if (!_playerLaunched) {
      _cancelled = true;
    }
    _messageNotifier.dispose();
    _fadeOutNotifier.dispose();
    _probeNotifier.dispose();
    super.dispose();
  }

  void _setPhase(String phase) {
    _messageNotifier.value = phase;
  }

  void _setStatusLine(String line) {
    if (!mounted || _statusLine == line) return;
    setState(() => _statusLine = line);
  }

  void _initProbes(List<AnimeEmbed> embeds) {
    _probeNotifier.value = embeds
        .map(
          (e) => StreamProviderProbe(
            id: e.sourceKey,
            label: e.label,
            status: StreamProviderProbeStatus.trying,
            isPreferred: e.sourceKey == _preferredSourceKey,
          ),
        )
        .toList(growable: false);
    if (mounted) setState(() {});
  }

  void _setProbeStatus(AnimeEmbed embed, StreamProviderProbeStatus status) {
    if (!mounted || _cancelled) return;
    final id = embed.sourceKey;
    final probes = _probeNotifier.value;
    final idx = probes.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    if (probes[idx].status == status) return;
    final next = List<StreamProviderProbe>.from(probes);
    next[idx] = next[idx].copyWith(status: status);
    _probeNotifier.value = next;
  }

  Future<void> _dropAllStreamCaches() async {
    _AnimeStreamSessionCache.drop(
      widget.anime.id,
      widget.episodeNumber,
      _category,
    );
    await _service.dropCachedStream(
      animeId: widget.anime.id,
      episode: widget.episodeNumber,
      category: _category,
    );
  }

  Future<bool> _anyHitPlayable(List<_AnimeResolvedHit> hits) async {
    for (final h in hits) {
      final headers = Map<String, String>.from(h.media.headers);
      if (await _service.probeStreamUrl(h.media.url, headers)) return true;
    }
    return false;
  }

  Future<void> _ensureEmbedsReady() async {
    if (_allEmbeds.isNotEmpty) return;
    if (AnimeService.savedSourceNeedsAnikoto(_preferredSourceKey)) {
      _series ??= await _service.resolveAnikoto(widget.anime);
    }
    if (!mounted || _cancelled) return;
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
  }

  Future<void> _handleStaleSavedStreams() async {
    await _dropAllStreamCaches();
    _launchedFromSavedOrCache = false;
    _fadeOutNotifier.value = false;
    _resolverStopped = false;

    if (_autoRecheckUsed >= 1) {
      setState(() {
        _awaitingManualRecheck = true;
        _failedAll = false;
      });
      _probeNotifier.value = const [];
      _setPhase('Streams unavailable');
      _setStatusLine('Tap reload to search again');
      return;
    }

    _autoRecheckUsed++;
    setState(() {
      _awaitingManualRecheck = false;
      _failedAll = false;
    });
    _probeNotifier.value = const [];
    _setPhase('Finding a stream…');
    _setStatusLine('Starting source scan…');
    await _ensureEmbedsReady();
    if (!mounted || _cancelled) return;
    await _resolveForCategory(fresh: true);
  }

  void _manualRecheck() {
    _autoRecheckUsed = 0;
    setState(() => _awaitingManualRecheck = false);
    _retryResolve();
  }

  Future<void> _bootstrap() async {
    final prefFuture = _service.preferredSource(
      animeId: widget.anime.id,
      category: _category,
    );
    final orderFuture = _settings.getAnimeProviderOrder();

    var cached = _AnimeStreamSessionCache.read(
      widget.anime.id,
      widget.episodeNumber,
      _category,
    );
    if (cached == null) {
      final disk = await _service.cachedResolvedStreamsJson(
        animeId: widget.anime.id,
        episode: widget.episodeNumber,
        category: _category,
      );
      cached = _hitsFromJson(disk);
    }

    final pref = await prefFuture;
    _providerOrder = await orderFuture;
    _preferredSourceKey = pref?.sourceKey;
    _preferredSourceTitle = pref?.sourceTitle;

    if (cached != null) {
      if (!mounted || _cancelled) return;
      final ranked = _rankHits(
        cached,
        _preferredSourceKey,
        _preferredSourceTitle,
      );
      _activeEmbed = ranked.first.embed;
      if (kDebugMode) {
        debugPrint(
          '[AnimePlayer] stream cache hit ep ${widget.episodeNumber} '
          '(${ranked.length} streams)',
        );
      }
      _setPhase('Starting…');
      _setStatusLine('Resuming stream');
      _launchedFromSavedOrCache = true;
      if (!await _anyHitPlayable(ranked)) {
        if (kDebugMode) {
          debugPrint('[AnimePlayer] cached streams stale — rechecking');
        }
        await _handleStaleSavedStreams();
        return;
      }
      await _launchPlayer(ranked, usedSavedSource: true, fromSessionCache: true);
      return;
    }

    if (AnimeService.savedSourceNeedsAnikoto(_preferredSourceKey)) {
      _setPhase('Looking up episode…');
      _setStatusLine('Matching catalog…');
      _series = await _service.resolveAnikoto(widget.anime);
      if (!mounted || _cancelled) return;
      if (_series == null) {
        debugPrint(
            '[AnimePlayer] Anikoto catalog miss for ${widget.anime.displayTitle} '
            '(anilist ${widget.anime.id})');
        _setStatusLine('Catalog miss · trying fallbacks');
      } else {
        _setStatusLine('Catalog matched');
      }
    } else if (kDebugMode) {
      debugPrint(
        '[AnimePlayer] skipping Anikoto — saved source $_preferredSourceKey',
      );
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
    if (kDebugMode && pref != null) {
      debugPrint(
        '[AnimePlayer] loaded pref key=${pref.sourceKey} title=${pref.sourceTitle}',
      );
    }
    if (!mounted || _cancelled) return;
    _setStatusLine(
      '${_currentPair.length} sources · EP ${widget.episodeNumber} '
      '${_category.toUpperCase()}',
    );
    await _resolveForCategory();
  }

  void _retryResolve() {
    unawaited(_dropAllStreamCaches());
    _resolverStopped = false;
    _awaitingManualRecheck = false;
    if (_allEmbeds.isEmpty) {
      unawaited(_bootstrap());
      return;
    }
    _resolveForCategory(fresh: true);
  }

  List<AnimeEmbed> get _currentPair => _sortEmbedsByProviderOrder(
        _allEmbeds.where((e) => e.category == _category).toList(),
        _providerOrder,
      );

  Future<void> _resolveForCategory({bool fresh = false}) async {
    if (_cancelled) return;
    setState(() {
      _failedAll = false;
      _statusLine = '';
    });
    _probeNotifier.value = const [];

    final pair = _currentPair;
    if (pair.isEmpty) {
      setState(() => _failedAll = true);
      _setPhase('No streams available');
      return;
    }

    if (!fresh && _preferredSourceKey != null) {
      final preferredEmbeds =
          pair.where((e) => e.sourceKey == _preferredSourceKey).toList();
      if (preferredEmbeds.isNotEmpty) {
        _setPhase('Using saved source…');
        _setStatusLine('Trying pinned source');
        _launchedFromSavedOrCache = true;
          final prefHits = await _raceEmbeds(
          preferredEmbeds,
          hardTimeout: const Duration(seconds: 10),
          launchAfterUniqueServers: 1,
        );
        if (!mounted || _cancelled || _resolverStopped) return;
        if (prefHits.isNotEmpty) {
          final ranked = _rankHits(
            prefHits,
            _preferredSourceKey,
            _preferredSourceTitle,
          );
          _activeEmbed = ranked.first.embed;
          await _launchPlayer(
            ranked,
            usedSavedSource: true,
          );
          return;
        }
        if (kDebugMode) {
          debugPrint(
            '[AnimePlayer] saved source ${_preferredSourceKey!} failed — full search',
          );
        }
      }
    }

    _launchedFromSavedOrCache = false;
    _setPhase('Finding a stream…');
    _setStatusLine('Starting source scan…');

    final sourcesListNotifier = ValueNotifier<List<StreamSource>>(const []);
    final urlToSourceKey = <String, String>{};
    final titleToSourceKey = <String, String>{};

    void syncLiveHits(List<({AnimeEmbed embed, ExtractedMedia media})> all) {
      if (all.isEmpty) return;
      final ranked =
          _rankHits(all, _preferredSourceKey, _preferredSourceTitle);
      for (final h in ranked) {
        urlToSourceKey[h.media.url] = h.embed.sourceKey;
        final t = h.media.sources?.first.title ?? h.embed.displayName;
        titleToSourceKey[t] = h.embed.sourceKey;
      }
      sourcesListNotifier.value = _hitsToStreamSources(ranked);
      _AnimeStreamSessionCache.write(
        widget.anime.id,
        widget.episodeNumber,
        _category,
        ranked,
      );
      unawaited(_service.cacheResolvedStreamsJson(
        animeId: widget.anime.id,
        episode: widget.episodeNumber,
        category: _category,
        hits: _hitsToJson(ranked),
      ));
    }

    final hits = await _raceEmbeds(
      pair,
      onHitsUpdated: syncLiveHits,
    );
    if (!mounted || _cancelled) {
      sourcesListNotifier.dispose();
      return;
    }
    if (hits.isNotEmpty) {
      final ranked =
          _rankHits(hits, _preferredSourceKey, _preferredSourceTitle);
      _activeEmbed = ranked.first.embed;
      syncLiveHits(ranked);
      await _launchPlayer(
        ranked,
        sourcesListNotifier: sourcesListNotifier,
        urlToSourceKey: urlToSourceKey,
        titleToSourceKey: titleToSourceKey,
      );
      // Notifier disposed inside _launchPlayer after the player closes.
      return;
    }
    sourcesListNotifier.dispose();
    if (_autoRecheckUsed >= 1) {
      setState(() => _awaitingManualRecheck = true);
      _setPhase('No streams available');
      _setStatusLine('Tap reload to search again');
      _probeNotifier.value = const [];
      return;
    }
    setState(() => _failedAll = true);
    _setPhase('No streams available');
    setState(() => _statusLine = '');
  }

  /// Probe Settings order with limited concurrency. Launch as soon as
  /// [launchAfterUniqueServers] distinct sources work; remaining embeds keep
  /// resolving and call [onHitsUpdated] so the player source menu fills in.
  Future<List<({AnimeEmbed embed, ExtractedMedia media})>> _raceEmbeds(
    List<AnimeEmbed> embeds, {
    Duration fastGrace = const Duration(milliseconds: 800),
    Duration hardTimeout = const Duration(seconds: 14),
    Duration absoluteTimeout = const Duration(seconds: 75),
    int maxInFlight = 6,
    int launchAfterUniqueServers = 4,
    void Function(List<({AnimeEmbed embed, ExtractedMedia media})> hits)?
        onHitsUpdated,
  }) async {
    _initProbes(embeds);

    final completer =
        Completer<List<({AnimeEmbed embed, ExtractedMedia media})>>();
    final successes = <({AnimeEmbed embed, ExtractedMedia media})>[];
    var settled = 0;
    var inFlight = 0;
    var nextIndex = 0;
    final total = embeds.length;
    Timer? graceTimer;
    late final Timer hardTimer;
    late final Timer absoluteTimer;
    late void Function() pump;

    int uniqueServers() =>
        successes.map((h) => h.embed.sourceKey).toSet().length;

    void publishHits() {
      onHitsUpdated?.call(List.of(successes));
    }

    void completeIfOpen() {
      if (completer.isCompleted) return;
      hardTimer.cancel();
      absoluteTimer.cancel();
      graceTimer?.cancel();
      publishHits();
      completer.complete(List.of(successes));
    }

    void finishIfReady() {
      if (settled < total) return;
      hardTimer.cancel();
      absoluteTimer.cancel();
      graceTimer?.cancel();
      publishHits();
      if (!completer.isCompleted) {
        completer.complete(List.of(successes));
      }
    }

    void scheduleGrace() {
      graceTimer?.cancel();
      graceTimer = Timer(fastGrace, completeIfOpen);
    }

    void onBatch(
      AnimeEmbed embed,
      List<({AnimeEmbed embed, ExtractedMedia media})> batch,
    ) {
      settled++;
      inFlight--;
      _setProbeStatus(
        embed,
        batch.isNotEmpty
            ? StreamProviderProbeStatus.success
            : StreamProviderProbeStatus.failed,
      );
      if (_cancelled) {
        finishIfReady();
        pump();
        return;
      }
      if (batch.isNotEmpty) {
        successes.addAll(batch);
        publishHits();
        if (!completer.isCompleted) {
          if (uniqueServers() >= launchAfterUniqueServers) {
            completeIfOpen();
          } else if (successes.isNotEmpty) {
            scheduleGrace();
          }
        }
      }
      finishIfReady();
      pump();
    }

    pump = () {
      while (!_cancelled &&
          inFlight < maxInFlight &&
          nextIndex < embeds.length) {
        // Keep pumping after launch so the menu fills in the background.
        final embed = embeds[nextIndex++];
        inFlight++;
        _resolveEmbed(embed).then((batch) {
          onBatch(embed, batch);
        }).catchError((_) {
          onBatch(embed, const []);
        });
      }
    };

    hardTimer = Timer(hardTimeout, () {
      if (successes.isNotEmpty) completeIfOpen();
    });
    absoluteTimer = Timer(absoluteTimeout, completeIfOpen);

    pump();

    final hits = await completer.future;
    // Don't cancel in-flight / queued work — onHitsUpdated keeps filling.
    return hits;
  }

  String _streamSourceTitle(AnimeEmbed embed, AnimeStreamResult direct) {
    final tag = direct.streamLabel?.trim();
    if (tag != null && tag.isNotEmpty) {
      return '${embed.displayName} · $tag';
    }
    return embed.displayName;
  }

  Future<List<({AnimeEmbed embed, ExtractedMedia media})>> _resolveEmbed(
    AnimeEmbed embed,
  ) async {
    if (_resolverStopped) return const [];
    try {
      final candidates = await _service.extractDirectCandidates(embed);
      if (_resolverStopped) return const [];
      final out = <({AnimeEmbed embed, ExtractedMedia media})>[];
      final maxMirrors = embed.server == 'miruro' ? 2 : candidates.length;
      var mirrors = 0;
      for (final direct in candidates) {
        if (mirrors >= maxMirrors) break;
        if (direct.url.isEmpty) continue;
        final headers = <String, String>{
          'Referer': direct.referer,
          'Origin': direct.origin,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        };
        final title = _streamSourceTitle(embed, direct);
        final subs = direct.tracks
            .map((t) => <String, dynamic>{
                  'url': t.url,
                  'display': t.label,
                  'language': _langCodeFromLabel(t.label),
                  'referer': direct.referer,
                  'origin': direct.origin,
                })
            .toList();
        final isHls = direct.url.contains('.m3u8');
        out.add((
          embed: embed,
          media: ExtractedMedia(
            url: direct.url,
            headers: headers,
            provider: embed.server,
            sources: [
              StreamSource(
                url: direct.url,
                title: title,
                type: isHls ? 'hls' : 'video',
                headers: headers,
              ),
            ],
            externalSubtitles: subs.isNotEmpty ? subs : null,
          ),
        ));
        mirrors++;
      }
      return out;
    } catch (e) {
      debugPrint('[AnimePlayer] ${embed.displayName} failed: $e');
      return const [];
    }
  }

  /// Prefer Settings → Anime provider order — not whichever HTTP call finished
  /// first during the parallel race. Saved source still wins when present.
  List<({AnimeEmbed embed, ExtractedMedia media})> _rankHits(
    List<({AnimeEmbed embed, ExtractedMedia media})> hits,
    String? preferredKey,
    String? preferredTitle,
  ) {
    return _rankHitsByOrder(hits, _providerOrder, preferredKey, preferredTitle);
  }

  Future<void> _launchPlayer(
    List<({AnimeEmbed embed, ExtractedMedia media})> hits, {
    bool usedSavedSource = false,
    bool fromSessionCache = false,
    ValueNotifier<List<StreamSource>>? sourcesListNotifier,
    Map<String, String>? urlToSourceKey,
    Map<String, String>? titleToSourceKey,
  }) async {
    if (_cancelled || !mounted) return;

    if (usedSavedSource || fromSessionCache) {
      _launchedFromSavedOrCache = true;
      if (!await _anyHitPlayable(hits)) {
        await _handleStaleSavedStreams();
        return;
      }
    }

    // Keep filling remaining embeds after early launch.
    _playerLaunched = true;

    _AnimeStreamSessionCache.write(
      widget.anime.id,
      widget.episodeNumber,
      _category,
      hits,
    );
    unawaited(_service.cacheResolvedStreamsJson(
      animeId: widget.anime.id,
      episode: widget.episodeNumber,
      category: _category,
      hits: _hitsToJson(hits),
    ));

    final winner = hits.first;
    await _service.recordWatch(
      anime: widget.anime,
      episodeNumber: widget.episodeNumber,
      category: _category,
    );

    final pinSource = usedSavedSource ||
        (_preferredSourceKey != null &&
            winner.embed.sourceKey == _preferredSourceKey);

    final urlKeys = urlToSourceKey ??
        <String, String>{
          for (final h in hits) h.media.url: h.embed.sourceKey,
        };
    final titleKeys = titleToSourceKey ??
        <String, String>{
          for (final h in hits)
            (h.media.sources?.first.title ?? h.embed.displayName):
                h.embed.sourceKey,
        };

    final sources = sourcesListNotifier?.value.isNotEmpty == true
        ? sourcesListNotifier!.value
        : _hitsToStreamSources(hits);

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
    if (!fromSessionCache &&
        (episodes.isEmpty ||
            episodes.any((e) => (e.thumbnail ?? '').trim().isEmpty))) {
      final fetched = await _service.getEpisodes(widget.anime);
      if (fetched.isNotEmpty) episodes = fetched;
    }
    final hubEpisodes = _hubEpisodesFromAnime(widget.anime, episodes);
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
    var playbackStarted = false;
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
      onSourcePinned: (url, title) async {
        final key = urlKeys[url] ?? titleKeys[title];
        if (key == null) {
          if (kDebugMode) {
            debugPrint('[AnimePlayer] source pin lookup miss url=$url title=$title');
          }
          return;
        }
        await _service.recordPreferredSource(
          animeId: widget.anime.id,
          category: _category,
          sourceKey: key,
          sourceTitle: title,
        );
        await _dropAllStreamCaches();
        _preferredSourceKey = key;
        _preferredSourceTitle = title;
      },
      pinSource: pinSource,
      hasNextEpisode: hasNext,
      onNextEpisode:
          hasNext ? () => openEpisode(widget.episodeNumber + 1) : null,
      fadeTransition: true,
      sourcesListNotifier: sourcesListNotifier,
      onPlaybackStarted: () {
        playbackStarted = true;
        _autoRecheckUsed = 0;
        _awaitingManualRecheck = false;
        _launchedFromSavedOrCache = false;
        if (resolverRoute != null && mounted) {
          navigator.removeRoute(resolverRoute);
        }
      },
      onAllSourcesExhausted: () {
        if (navigator.canPop()) navigator.pop();
      },
      onReloadStreams: () => reloadAnimeEpisodeStreams(
        service: _service,
        allEmbeds: List<AnimeEmbed>.from(_allEmbeds),
        category: _category,
        providerOrder: _providerOrder,
      ),
    );
    await Future<void>.delayed(loadingOverlayFadeOutDuration);
    await playerFuture;
    final shouldRecheck = !playbackStarted && _launchedFromSavedOrCache;
    _cancelled = true;
    sourcesListNotifier?.dispose();
    if (shouldRecheck && mounted) {
      await _handleStaleSavedStreams();
    }
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
                      onPressed: _retryResolve,
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
    final probing = _probeNotifier.value.isNotEmpty;
    final episodeLabel = probing
        ? 'EP ${widget.episodeNumber} · ${_category.toUpperCase()}'
        : (_statusLine.isNotEmpty
            ? 'EP ${widget.episodeNumber} · $_statusLine'
            : 'EP ${widget.episodeNumber}');

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
          recheckBanner: _awaitingManualRecheck
              ? null
              : (_autoRecheckUsed > 0 ? 'Rechecking sources…' : null),
          showReloadButton: _awaitingManualRecheck,
          onReload: _manualRecheck,
          onCancel: () {
            _cancelled = true;
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
