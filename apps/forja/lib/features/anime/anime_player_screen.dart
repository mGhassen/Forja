// Anime player resolver: tries embeds in provider order until one works.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/anime/catalog/anime_stream_providers.dart';
import 'package:forja/features/anime/catalog/miruro_pipe_session.dart';
import 'package:forja/shared/playback/anime_playback_bridge.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/playback/provider_score_probe_sync.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/resolve_failure_view.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/shared/design/design.dart';
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
            'sourceKey': h.embed.sourceKey,
          },
          'media': {
            'url': h.media.url,
            if (h.media.audioUrl != null) 'audioUrl': h.media.audioUrl,
            'headers': h.media.headers,
            if (h.media.provider != null) 'provider': h.media.provider,
            'providerId': h.embed.sourceKey,
            if (h.media.sources != null)
              'sources': h.media.sources!
                  .map(
                    (s) => {
                      'url': s.url,
                      'title': s.title,
                      'type': s.type,
                      if (s.headers != null) 'headers': s.headers,
                      'providerId': s.providerId ?? h.embed.sourceKey,
                      if (s.catalogUrl != null) 'catalogUrl': s.catalogUrl,
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
    final embed = AnimeEmbed(
      label: embedMap['label'] as String? ?? '',
      server: embedMap['server'] as String? ?? '',
      category: embedMap['category'] as String? ?? 'sub',
      url: embedMap['url'] as String? ?? '',
    );
    final providerId = (embedMap['sourceKey'] as String?)?.trim().isNotEmpty ==
            true
        ? (embedMap['sourceKey'] as String).trim()
        : ((mediaMap['providerId'] as String?)?.trim().isNotEmpty == true
            ? (mediaMap['providerId'] as String).trim()
            : embed.sourceKey);
    if (sourcesRaw != null) {
      sources = sourcesRaw
          .map((s) {
            final m = (s as Map).cast<String, dynamic>();
            return StreamSource(
              url: m['url'] as String? ?? '',
              title: m['title'] as String? ?? '',
              type: m['type'] as String? ?? 'video',
              headers: (m['headers'] as Map?)?.cast<String, String>(),
              providerId: (m['providerId'] as String?)?.trim().isNotEmpty == true
                  ? (m['providerId'] as String).trim()
                  : providerId,
              catalogUrl: (m['catalogUrl'] as String?)?.trim(),
            );
          })
          .where((s) => s.url.isNotEmpty)
          .toList();
    }
    out.add((
      embed: embed,
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
  if (tag != null && tag.isNotEmpty) return tag;
  return 'Stream';
}

List<StreamSource> _hitsToStreamSources(List<_AnimeResolvedHit> hits) =>
    AnimePlaybackBridge.hitsToStreamSources(hits);

Map<String, dynamic> _animeProviderMap(Iterable<AnimeEmbed> embeds) {
  return AnimePlaybackBridge.embedsToPanelProviders(embeds.toList());
}

Map<String, List<StreamSource>> _hitsToProviderCache(
  List<_AnimeResolvedHit> hits,
) {
  final cache = <String, List<StreamSource>>{};
  for (final hit in hits) {
    cache[hit.embed.panelKey] = _hitsToStreamSources([hit]);
  }
  return cache;
}

Future<List<StreamSource>?> reloadAnimeEpisodeStreams({
  required AnimeService service,
  required List<AnimeEmbed> allEmbeds,
  required String category,
  List<String> providerOrder = const [],
  Movie? hubMovie,
}) =>
    AnimePlaybackBridge.reloadStreams(
      service: service,
      allEmbeds: allEmbeds,
      category: category,
      hubMovie: hubMovie ??
          Movie(
            id: 0,
            title: 'Anime',
            posterPath: '',
            backdropPath: '',
            voteAverage: 0,
            releaseDate: '',
            mediaType: 'anime',
          ),
      providerOrder: providerOrder,
    );

List<AnimeEmbed> _sortEmbedsByProviderOrder(
  List<AnimeEmbed> embeds,
  List<String> order,
) {
  if (embeds.isEmpty) return embeds;
  final keyed = embeds.map((e) => e.sourceKey).toSet().toList();
  final sortedKeys = SourceEngine.orderProviderIds(
    domain: SourceDomain.anime,
    candidateIds: keyed,
    settingsOrder: order.isEmpty ? AnimeStreamProviders.defaultOrder : order,
  );
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
      backdropPath: anime.heroBackdrop,
      voteAverage: (anime.averageScore ?? 0) / 10.0,
      releaseDate: anime.seasonYear?.toString() ?? '',
      overview: anime.cleanDescription,
      genres: anime.genres,
      runtime: anime.duration ?? 0,
      mediaType: 'anime',
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
            notShippedYet: !e.aired,
          ),
        )
        .toList();

Future<T?> openAnimePlayer<T>(
  BuildContext context, {
  required AnimeCard anime,
  required int episodeNumber,
  String category = 'sub',
  List<AnimeEpisode> allEpisodes = const [],
  Duration? startPosition,
  bool freshResolve = false,
}) {
  final hostContext = context;
  return Navigator.of(context, rootNavigator: true).push<T>(
    AppRouter.fadeRoute(
      (_) => ShellScope.rehost(
        hostContext,
        AnimePlayerScreen(
          anime: anime,
          episodeNumber: episodeNumber,
          category: category,
          allEpisodes: allEpisodes,
          startPosition: startPosition,
          freshResolve: freshResolve,
        ),
      ),
    ),
  );
}

class AnimePlayerScreen extends StatefulWidget {
  final AnimeCard anime;
  final int episodeNumber;
  final String category;
  final List<AnimeEpisode> allEpisodes;
  final Duration? startPosition;
  final bool freshResolve;

  const AnimePlayerScreen({
    super.key,
    required this.anime,
    required this.episodeNumber,
    this.category = 'sub',
    this.allEpisodes = const [],
    this.startPosition,
    this.freshResolve = false,
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
  /// When set, the active Auto race is cancelled and re-run for this sourceKey.
  String? _manualPreferredSourceKey;
  bool _manualSwitchRequested = false;
  int _autoRecheckUsed = 0;
  bool _awaitingManualRecheck = false;
  bool _launchedFromSavedOrCache = false;
  /// Prefer writing source prefs only after real playback (not abortive open).
  bool _prefWriteAllowed = false;
  String? _pendingPrefKey;
  String? _pendingPrefTitle;
  /// Next/prev episode while player is open — pop player, then replace host.
  int? _handOffEpisode;

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
    _haltBackgroundResolve();
    _messageNotifier.dispose();
    _fadeOutNotifier.dispose();
    _probeNotifier.dispose();
    super.dispose();
  }

  void _haltBackgroundResolve() {
    _cancelled = true;
    _resolverStopped = true;
    DomainStreamProviderResolver.cancelAllPending();
  }

  /// Resolve finished (play or fail) — kill Miruro WebView so SPA /health stops.
  void _closeMiruroPipe() {
    MiruroPipeSession.instance.cancelPending();
  }

  void _setPhase(String phase) {
    _messageNotifier.value = phase;
  }

  void _setStatusLine(String line) {
    if (!mounted || _statusLine == line) return;
    setState(() => _statusLine = line);
  }

  void _initProbes(List<AnimeEmbed> embeds) {
    final probes = <StreamProviderProbe>[];
    for (final e in embeds) {
      probes.add(
        StreamProviderProbe(
          id: e.panelKey,
          label: e.displayName,
          status: StreamProviderProbeStatus.pending,
          isPreferred:
              e.sourceKey == _preferredSourceKey && e.category == _category,
        ),
      );
    }
    _probeNotifier.value = probes;
    if (mounted) setState(() {});
  }

  void _markProbeStatus(String panelKey, StreamProviderProbeStatus status) {
    final probes = _probeNotifier.value;
    final idx = probes.indexWhere((p) => p.id == panelKey);
    if (idx < 0) return;
    if (probes[idx].status == status) return;
    final next = List<StreamProviderProbe>.from(probes);
    next[idx] = next[idx].copyWith(status: status);
    _probeNotifier.value = next;
  }

  ProviderScoreScope? get _animeScoreScope =>
      ProviderScoreProbeSync.scopeFromPlayer(
        movie: _hubMovieFromAnime(widget.anime),
        providers: _animeProviderMap(_allEmbeds),
        hubEpisodeNumber: widget.episodeNumber,
      );

  /// Score only when the CDN/stream check finished — not on extract alone.
  void _scoreAnimeProbe({
    required String panelKey,
    required StreamProviderProbeStatus status,
    bool hasSources = false,
    bool streamsResolved = false,
  }) {
    unawaited(
      ProviderScoreProbeSync.onProbeStatusChanged(
        scope: _animeScoreScope,
        providerId: panelKey,
        status: status,
        hasSources: hasSources,
        streamsResolved: streamsResolved,
      ),
    );
  }

  StreamProviderProbeStatus _probeStatusFromProgress(String status) {
    return switch (status) {
      'success' => StreamProviderProbeStatus.success,
      'failed' => StreamProviderProbeStatus.failed,
      'trying' => StreamProviderProbeStatus.trying,
      'skipped' => StreamProviderProbeStatus.skippedOnTv,
      _ => StreamProviderProbeStatus.pending,
    };
  }

  void Function(String providerId, String status) _animeResolveProgress(
    List<AnimeEmbed> embeds,
  ) {
    return (providerId, status) {
      if (!mounted || _cancelled) return;
      final nextStatus = _probeStatusFromProgress(status);
      final targets = embeds
          .where((e) => e.sourceKey == providerId || e.panelKey == providerId)
          .map((e) => e.panelKey)
          .toSet();
      if (targets.isEmpty) return;

      var probes = _probeNotifier.value;
      for (final panelKey in targets) {
        final idx = probes.indexWhere((p) => p.id == panelKey);
        if (idx < 0) {
          final embed = embeds.firstWhere(
            (e) => e.panelKey == panelKey,
            orElse: () => embeds.first,
          );
          probes = [
            ...probes,
            StreamProviderProbe(
              id: panelKey,
              label: embed.displayName,
              status: nextStatus,
              isPreferred: embed.sourceKey == _preferredSourceKey &&
                  embed.category == _category,
            ),
          ];
        } else if (probes[idx].status != nextStatus) {
          final next = List<StreamProviderProbe>.from(probes);
          next[idx] = next[idx].copyWith(status: nextStatus);
          probes = next;
        }
      }
      _probeNotifier.value = probes;
      for (final panelKey in targets) {
        // Extract success → await CDN `_playableHits` (no +2+2 yet).
        // Extract empty/fail → server −2 only.
        _scoreAnimeProbe(
          panelKey: panelKey,
          status: nextStatus,
          hasSources: nextStatus == StreamProviderProbeStatus.success,
        );
      }
      final current = _probeNotifier.value;
      final total = current.length;
      final checked = current
          .where(
            (p) =>
                p.status != StreamProviderProbeStatus.trying &&
                p.status != StreamProviderProbeStatus.pending,
          )
          .length;
      final ready =
          current.where((p) => p.status == StreamProviderProbeStatus.success).length;
      if (total > 0) {
        _setStatusLine('$checked / $total checked · $ready up');
      }
    };
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

  /// Probe CDN reachability before open / cache write (movie I43 style).
  /// Mode is per [AnimeEmbed.sourceKey] via provider_runtime_config.
  Future<List<_AnimeResolvedHit>> _playableHits(
    List<_AnimeResolvedHit> hits,
  ) async {
    if (hits.isEmpty) return const [];
    final flags = await Future.wait(
      hits.map((h) {
        final headers = Map<String, String>.from(h.media.headers);
        return _service.probeStreamUrl(
          h.media.url,
          headers,
          sourceKey: h.embed.sourceKey,
        );
      }),
    );
    return [
      for (var i = 0; i < hits.length; i++)
        if (flags[i]) hits[i],
    ];
  }

  Future<void> _flushPendingPreferredSource() async {
    final key = _pendingPrefKey;
    if (key == null || !_prefWriteAllowed) return;
    final title = _pendingPrefTitle;
    _pendingPrefKey = null;
    _pendingPrefTitle = null;
    await _service.recordPreferredSource(
      animeId: widget.anime.id,
      category: _category,
      sourceKey: key,
      sourceTitle: title,
    );
    await _dropAllStreamCaches();
    _preferredSourceKey = key;
    _preferredSourceTitle = title;
  }

  Future<void> _ensureEmbedsReady() async {
    if (_allEmbeds.isNotEmpty) return;
    if (AnimeService.savedSourceNeedsAnikoto(_preferredSourceKey)) {
      _series ??= await _service.resolveAnikoto(widget.anime);
    }
    if (!mounted || _cancelled) return;
    final malId = await _service.resolveMalId(widget.anime.id);
    if (!mounted || _cancelled) return;
    _allEmbeds = _service.buildAllEmbeds(
      anilistId: widget.anime.id,
      episode: widget.episodeNumber,
      series: _series,
      animeTitles: widget.anime.resolveTitleCandidates(),
      isAdult: widget.anime.isAdult,
      malId: malId,
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
      _setPhase('Still searching…');
      _setStatusLine('Saved link expired — search again');
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

    var cached = widget.freshResolve
        ? null
        : _AnimeStreamSessionCache.read(
            widget.anime.id,
            widget.episodeNumber,
            _category,
          );
    if (cached == null && !widget.freshResolve) {
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
      // Pref is per show/ep/category — a bee-only cache cannot honor kiwi.
      final pref = _preferredSourceKey;
      if (pref != null &&
          pref.isNotEmpty &&
          !ranked.any((h) => h.embed.sourceKey == pref)) {
        if (kDebugMode) {
          debugPrint(
            '[AnimePlayer] cache misses preferred $pref — full resolve',
          );
        }
        await _dropAllStreamCaches();
      } else {
        _activeEmbed = ranked.first.embed;
        if (kDebugMode) {
          debugPrint(
            '[AnimePlayer] stream cache hit ep ${widget.episodeNumber} '
            '(${ranked.length} streams)',
          );
        }
        // Same as movie dead-cache recovery: Source panel needs the full server
        // list even when we resume from a cached stream URL.
        await _ensureEmbedsReady();
        if (!mounted || _cancelled) return;
        _setPhase('Starting…');
        _setStatusLine('Resuming stream');
        _launchedFromSavedOrCache = true;
        final playable = await _playableHits(ranked);
        if (playable.isEmpty) {
          if (kDebugMode) {
            debugPrint('[AnimePlayer] cached streams stale — rechecking');
          }
          await _handleStaleSavedStreams();
          return;
        }
        // Do not pass usedSavedSource:true — that pins the stream and blocks
        // Auto dead-cache re-resolve (movie I43). Session cache is resume, not pin.
        await _launchPlayer(playable, fromSessionCache: true);
        return;
      }
    }

    if (AnimeService.savedSourceNeedsAnikoto(_preferredSourceKey)) {
      _setPhase('Looking up episode…');
      _setStatusLine('Matching AniKoto…');
      _series = await _service.resolveAnikoto(widget.anime);
      if (!mounted || _cancelled) return;
      if (_series == null) {
        debugPrint(
            '[AnimePlayer] Anikoto catalog miss for ${widget.anime.displayTitle} '
            '(anilist ${widget.anime.id})');
        _setStatusLine('AniKoto miss · trying fallbacks');
      } else {
        _setStatusLine('AniKoto matched');
      }
    } else if (kDebugMode) {
      debugPrint(
        '[AnimePlayer] skipping Anikoto — saved source $_preferredSourceKey',
      );
    }

    _setStatusLine('Resolving MAL id…');
    final malId = await _service.resolveMalId(widget.anime.id);
    if (!mounted || _cancelled) return;
    if (kDebugMode) {
      debugPrint(
        '[AnimePlayer] anilist=${widget.anime.id} mal=$malId '
        '(anilist idMal=${widget.anime.idMal})',
      );
    }

    _allEmbeds = _service.buildAllEmbeds(
      anilistId: widget.anime.id,
      episode: widget.episodeNumber,
      series: _series,
      animeTitles: widget.anime.resolveTitleCandidates(),
      isAdult: widget.anime.isAdult,
      malId: malId,
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
    _manualPreferredSourceKey = null;
    _manualSwitchRequested = false;
    _probeNotifier.value = const [];

    final pair = _currentPair;
    if (pair.isEmpty) {
      setState(() => _failedAll = true);
      _setPhase('No streams found');
      _setStatusLine(
        'We couldn’t find a working source for this episode.',
      );
      _closeMiruroPipe();
      return;
    }

    if (!fresh && _preferredSourceKey != null) {
      final preferredEmbeds =
          pair.where((e) => e.sourceKey == _preferredSourceKey).toList();
      if (preferredEmbeds.isNotEmpty) {
        _setPhase('Using saved source…');
        _initProbes(preferredEmbeds);
        _setStatusLine('Trying pinned source');
        _launchedFromSavedOrCache = true;
        final prefHits = await AnimePlaybackBridge.raceEmbeds(
          embeds: preferredEmbeds,
          hubMovie: _hubMovieFromAnime(widget.anime),
          settingsOrder: _providerOrder,
          animeService: _service,
          preferredProvider: _preferredSourceKey!,
          isCancelled: () => _cancelled || _resolverStopped,
          onProgress: _animeResolveProgress(preferredEmbeds),
          maxInFlight: 1,
        );
        if (!mounted || _cancelled || _resolverStopped) {
          _closeMiruroPipe();
          return;
        }
        if (prefHits.isNotEmpty) {
          final playable = await _playableHits(prefHits);
          if (!mounted || _cancelled || _resolverStopped) {
            _closeMiruroPipe();
            return;
          }
          if (playable.isNotEmpty) {
            _activeEmbed = playable.first.embed;
            _closeMiruroPipe();
            await _launchPlayer(
              playable,
              usedSavedSource: true,
            );
            return;
          }
          for (final h in prefHits) {
            _markProbeStatus(h.embed.panelKey, StreamProviderProbeStatus.failed);
            _scoreAnimeProbe(
              panelKey: h.embed.panelKey,
              status: StreamProviderProbeStatus.failed,
              hasSources: true,
              streamsResolved: true,
            );
          }
        }
        if (kDebugMode) {
          debugPrint(
            '[AnimePlayer] saved source ${_preferredSourceKey!} failed — full search',
          );
        }
        _launchedFromSavedOrCache = false;
      }
    }

    _launchedFromSavedOrCache = false;
    _setPhase('Finding a stream…');
    _initProbes(pair);
    _setStatusLine('${pair.map((e) => e.sourceKey).toSet().length} sources · scanning…');

    final sourcesListNotifier = ValueNotifier<List<StreamSource>>(const []);
    final providerSourcesCache =
        ValueNotifier<Map<String, List<StreamSource>>>({});
    final urlToSourceKey = <String, String>{};
    final titleToSourceKey = <String, String>{};

    Future<void> syncLiveHits(
      List<({AnimeEmbed embed, ExtractedMedia media})> all,
    ) async {
      if (_cancelled ||
          _resolverStopped ||
          _manualSwitchRequested ||
          all.isEmpty) {
        return;
      }
      for (final h in all) {
        urlToSourceKey[h.media.url] = h.embed.sourceKey;
        titleToSourceKey[h.embed.displayName] = h.embed.sourceKey;
        for (final s in h.media.sources ?? const <StreamSource>[]) {
          urlToSourceKey[s.url] = h.embed.sourceKey;
          if (s.title.trim().isNotEmpty) {
            titleToSourceKey[s.title] = h.embed.sourceKey;
          }
        }
        _markProbeStatus(
          h.embed.panelKey,
          StreamProviderProbeStatus.success,
        );
        _scoreAnimeProbe(
          panelKey: h.embed.panelKey,
          status: StreamProviderProbeStatus.success,
          hasSources: true,
          streamsResolved: true,
        );
      }
      final stripped = await AnimePlaybackBridge.stripHitsPng(all);
      if (_cancelled || _resolverStopped) return;
      sourcesListNotifier.value = stripped;
      final cache = <String, List<StreamSource>>{};
      for (final hit in all) {
        cache[hit.embed.panelKey] = await AnimePlaybackBridge.stripHitsPng(
          [hit],
        );
      }
      if (_cancelled || _resolverStopped) return;
      providerSourcesCache.value = {
        ...providerSourcesCache.value,
        ...cache,
      };
    }

    // First *CDN-playable* wins: try providers in order, probe each extract,
    // drop dead CDNs and continue. Stop as soon as one probes OK — no
    // background scan of the rest after launch.
    var remaining = List<AnimeEmbed>.from(pair);
    var preferred = SourceEngine.auto;

    while (mounted &&
        !_cancelled &&
        !_resolverStopped &&
        remaining.isNotEmpty) {
      _manualSwitchRequested = false;
      final manualKey = _manualPreferredSourceKey;
      preferred = manualKey ?? SourceEngine.auto;
      if (manualKey != null) {
        remaining = pair
            .where((e) => e.sourceKey == manualKey)
            .toList(growable: true);
        if (remaining.isEmpty) remaining = List<AnimeEmbed>.from(pair);
        _probeNotifier.value = [
          for (final p in _probeNotifier.value)
            StreamProviderProbe(
              id: p.id,
              label: p.label,
              status: p.status == StreamProviderProbeStatus.trying
                  ? StreamProviderProbeStatus.pending
                  : p.status,
              isPreferred: pair.any(
                (e) => e.panelKey == p.id && e.sourceKey == manualKey,
              ),
            ),
        ];
        _setPhase('Checking ${manualKey.toUpperCase()}…');
      }

      final hits = await AnimePlaybackBridge.raceEmbeds(
        embeds: remaining,
        hubMovie: _hubMovieFromAnime(widget.anime),
        settingsOrder: _providerOrder,
        animeService: _service,
        preferredProvider: preferred,
        isCancelled: () =>
            _cancelled || _resolverStopped || _manualSwitchRequested,
        onProgress: _animeResolveProgress(pair),
        maxInFlight: 1,
      );

      if (_cancelled || _resolverStopped) {
        sourcesListNotifier.dispose();
        providerSourcesCache.dispose();
        _closeMiruroPipe();
        return;
      }
      if (_manualSwitchRequested && _manualPreferredSourceKey != null) {
        continue;
      }
      if (hits.isEmpty) {
        break;
      }

      final playable = await _playableHits(hits);
      if (!mounted || _cancelled) {
        sourcesListNotifier.dispose();
        providerSourcesCache.dispose();
        _closeMiruroPipe();
        return;
      }
      if (playable.isNotEmpty) {
        await syncLiveHits(playable);
        _activeEmbed = playable.first.embed;
        final usedSaved = !SourceEngine.isAuto(preferred) &&
            _preferredSourceKey != null &&
            playable.any((h) => h.embed.sourceKey == _preferredSourceKey);
        _closeMiruroPipe();
        await _launchPlayer(
          playable,
          usedSavedSource: usedSaved,
          sourcesListNotifier: sourcesListNotifier,
          providerSourcesCache: providerSourcesCache,
          urlToSourceKey: urlToSourceKey,
          titleToSourceKey: titleToSourceKey,
        );
        return;
      }

      // Extracted but CDN dead — skip these keys and try the next server.
      final deadKeys = <String>{};
      for (final h in hits) {
        deadKeys.add(h.embed.sourceKey);
        _markProbeStatus(h.embed.panelKey, StreamProviderProbeStatus.failed);
        // Extract OK + CDN dead → linked +2−2 (not stale +2+2).
        _scoreAnimeProbe(
          panelKey: h.embed.panelKey,
          status: StreamProviderProbeStatus.failed,
          hasSources: true,
          streamsResolved: true,
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[AnimePlayer] CDN probe failed for ${deadKeys.join(", ")} — next',
        );
      }
      remaining = [
        for (final e in remaining)
          if (!deadKeys.contains(e.sourceKey)) e,
      ];
    }

    if (!mounted || _cancelled) {
      sourcesListNotifier.dispose();
      providerSourcesCache.dispose();
      _closeMiruroPipe();
      return;
    }

    sourcesListNotifier.dispose();
    providerSourcesCache.dispose();
    _closeMiruroPipe();
    if (_autoRecheckUsed >= 1) {
      setState(() => _awaitingManualRecheck = true);
      _setPhase('Still searching…');
      _setStatusLine('No working source yet — search again');
      _probeNotifier.value = const [];
      return;
    }
    setState(() => _failedAll = true);
    _setPhase('No streams found');
    _setStatusLine(
      'We couldn’t find a working source for this episode.',
    );
  }

  /// Prefer Settings → Anime provider order — saved source still wins when present.
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
    ValueNotifier<Map<String, List<StreamSource>>>? providerSourcesCache,
    Map<String, String>? urlToSourceKey,
    Map<String, String>? titleToSourceKey,
  }) async {
    if (_cancelled || !mounted) return;

    // Saved/cache paths re-probe here; fresh Auto/preferred already probed.
    if (usedSavedSource || fromSessionCache) {
      _launchedFromSavedOrCache = true;
      final playable = await _playableHits(hits);
      if (playable.isEmpty) {
        await _handleStaleSavedStreams();
        return;
      }
      hits = playable;
    }

    // Winner is ready — stop scanning; remaining servers stay available for
    // manual Source taps / dead-stream recovery only.

    // Do not re-stamp session/disk cache on cache resume — a dead URL would
    // overwrite a drop and poison the next Play. Fresh resolves still cache
    // playable multi-provider hits only.
    if (!fromSessionCache) {
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
    }

    final winner = hits.first;
    await _service.recordWatch(
      anime: widget.anime,
      episodeNumber: widget.episodeNumber,
      category: _category,
    );

    final pinSource = usedSavedSource ||
        (!fromSessionCache &&
            _preferredSourceKey != null &&
            winner.embed.sourceKey == _preferredSourceKey);

    final urlKeys = urlToSourceKey ??
        <String, String>{
          for (final h in hits) ...{
            h.media.url: h.embed.sourceKey,
            for (final s in h.media.sources ?? const <StreamSource>[])
              s.url: h.embed.sourceKey,
          },
        };
    final titleKeys = titleToSourceKey ??
        <String, String>{
          for (final h in hits) ...{
            h.embed.displayName: h.embed.sourceKey,
            for (final s in h.media.sources ?? const <StreamSource>[])
              if (s.title.trim().isNotEmpty) s.title: h.embed.sourceKey,
          },
        };

    if (!mounted || _cancelled) return;
    final navigator = Navigator.of(context, rootNavigator: true);

    // Player "current" list = winner servers only. Other providers live in cache.
    // Nekostream/Megaplay HLS: unwrap PNG-shelled MPEG-TS via local hls-proxy.
    final rawSources = await AnimePlaybackBridge.stripHitsPng([winner]);
    final sources = await PlaybackSelection.rankAndDedupe(
      sources: rawSources,
      providerId: winner.embed.sourceKey,
      providerRank: SourceEngine.orderProviders(
        domain: SourceDomain.anime,
        candidateIds: [winner.embed.sourceKey],
        settingsOrder: _providerOrder,
      ).rows.first.effectiveRank,
    );
    if (sources.isEmpty) {
      setState(() => _failedAll = true);
      return;
    }
    final openUrl = sources.first.url;

    final seenSubs = <String>{};
    final allSubs = <Map<String, dynamic>>[];
    for (final h in hits) {
      for (final s in (h.media.externalSubtitles ?? const [])) {
        final url = s['url']?.toString() ?? '';
        if (url.isEmpty || !seenSubs.add(url)) continue;
        allSubs.add(s);
      }
    }

    final winnerHeaders = Map<String, String>.from(
      sources.first.headers ?? const {},
    );
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

    Future<void> openEpisode(int epNumber) async {
      // Player is on top of this host. Replacing the host under it left a
      // dead player (black screen). Pop the player first; after playerFuture
      // completes we pushReplacement to the next episode host.
      _handOffEpisode = epNumber;
      if (navigator.canPop()) navigator.pop();
    }

    _fadeOutNotifier.value = true;
    // Do not re-init probes — that resets every server to pending and looks
    // like a full re-scan. Keep race progress; mark winners success.
    for (final h in hits) {
      _markProbeStatus(
        h.embed.panelKey,
        StreamProviderProbeStatus.success,
      );
      _scoreAnimeProbe(
        panelKey: h.embed.panelKey,
        status: StreamProviderProbeStatus.success,
        hasSources: true,
        streamsResolved: true,
      );
    }
    final ownsProviderCache = providerSourcesCache == null;
    final liveProviderCache = providerSourcesCache ??
        ValueNotifier<Map<String, List<StreamSource>>>(
          _hitsToProviderCache(hits),
        );
    final liveProbeNotifier = ValueNotifier<List<StreamProviderProbe>>(
      List<StreamProviderProbe>.from(_probeNotifier.value),
    );
    if (!mounted || _cancelled) {
      liveProbeNotifier.dispose();
      if (ownsProviderCache) liveProviderCache.dispose();
      return;
    }
    final playerFuture = AppRouter.openPlayer<Object?>(
      context,
      streamUrl: openUrl,
      title: title,
      headers: winnerHeaders,
      startPosition: widget.startPosition,
      sources: sources,
      providers: _animeProviderMap(_allEmbeds),
      providerSourcesCache: liveProviderCache,
      providerProbesNotifier: liveProbeNotifier,
      activeProvider: winner.embed.panelKey,
      externalSubtitles: allSubs.isNotEmpty ? allSubs : null,
      movie: _hubMovieFromAnime(widget.anime),
      hubEpisodes: hubEpisodes,
      hubEpisodeNumber: widget.episodeNumber,
      episodeOverview: currentEp != null
          ? _decodeEpisodeTitle(currentEp.title)
          : null,
      streamsPrevalidated: true,
      onHubEpisodeSelected: (ep) => openEpisode(ep.number.toInt()),
      onSaveProgress: (pos, dur) async {
        await _service.recordWatch(
          anime: widget.anime,
          episodeNumber: widget.episodeNumber,
          category: _category,
          position: pos,
          duration: dur,
        );
        await EpisodeWatchedService().markWatchedIfFinished(
          mediaId: widget.anime.id,
          season: 1,
          episode: widget.episodeNumber,
          positionMs: pos.inMilliseconds,
          durationMs: dur.inMilliseconds,
          catalog: EpisodeWatchedService.catalogAnilist,
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
        // Do not overwrite pref during a failed / abortive open — wait until
        // playback has been confirmed beyond the early-EOF window.
        _pendingPrefKey = key;
        _pendingPrefTitle = title;
        if (_prefWriteAllowed) {
          await _flushPendingPreferredSource();
        }
      },
      pinSource: pinSource,
      hasNextEpisode: hasNext,
      onNextEpisode:
          hasNext ? () => openEpisode(widget.episodeNumber + 1) : null,
      fadeTransition: true,
      sourcesListNotifier: sourcesListNotifier,
      onPlaybackStarted: () {
        _autoRecheckUsed = 0;
        _awaitingManualRecheck = false;
        _launchedFromSavedOrCache = false;
        // Brief demux can fire started then abortive EOF — defer pref write.
        unawaited(Future<void>.delayed(const Duration(seconds: 12), () async {
          if (!mounted || _cancelled) return;
          _prefWriteAllowed = true;
          await _flushPendingPreferredSource();
        }));
      },
      onAllSourcesExhausted: () {
        if (mounted) _fadeOutNotifier.value = false;
        unawaited(_dropAllStreamCaches());
        if (navigator.canPop()) navigator.pop();
      },
      onReloadStreams: () async {
        await _dropAllStreamCaches();
        await _ensureEmbedsReady();
        // Stay usable while the player sits on top of this route — do not
        // treat dispose/_cancelled from a premature removeRoute.
        if (!mounted) return null;
        return reloadAnimeEpisodeStreams(
          service: _service,
          allEmbeds: List<AnimeEmbed>.from(_allEmbeds),
          category: _category,
          providerOrder: _providerOrder,
          hubMovie: _hubMovieFromAnime(widget.anime),
        );
      },
    );
    // Keep this route under the player for the whole session. Removing it on
    // fade/playback-start disposed Source cache notifiers and cancelled
    // onReloadStreams — dead-cache recovery and server taps broke.
    await playerFuture;
    // Cache resume that never confirmed playback left a dead URL on disk —
    // drop so the next Play re-resolves like green Play (movie I43).
    if (_launchedFromSavedOrCache) {
      await _dropAllStreamCaches();
      _launchedFromSavedOrCache = false;
    }
    sourcesListNotifier?.dispose();
    liveProbeNotifier.dispose();
    if (ownsProviderCache) {
      liveProviderCache.dispose();
    } else {
      providerSourcesCache!.dispose();
    }
    final handOff = _handOffEpisode;
    _handOffEpisode = null;
    if (handOff != null && mounted) {
      final existing = ShellScope.maybeOf(context);
      final profile = existing?.profile ?? resolveShellProfile(context);
      final config = existing?.config ?? shellPlatformConfigFor(profile);
      await navigator.pushReplacement(
        AppRouter.fadeRoute(
          (_) => ShellScope(
            profile: profile,
            config: config,
            child: AnimePlayerScreen(
              anime: widget.anime,
              episodeNumber: handOff,
              category: _category,
              allEpisodes: episodes,
            ),
          ),
        ),
      );
      return;
    }
    // Player closed — leave the loading shell and return to details.
    if (mounted && navigator.canPop()) {
      navigator.pop();
    }
  }

  Widget _buildFailure(AppThemePreset _) {
    return ResolveFailureScaffold(
      backdropUrl: widget.anime.heroBackdrop,
      failure: ResolveFailure(
        title: _messageNotifier.value,
        detail: _statusLine.isNotEmpty ? _statusLine : null,
        primaryLabel: 'Try again',
        onPrimary: _retryResolve,
        secondaryLabel: 'Close',
        onSecondary: () => Navigator.of(context).pop(),
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
              : (_autoRecheckUsed > 0 ? 'Checking sources again…' : null),
          showReloadButton: _awaitingManualRecheck,
          reloadLabel: 'Search again',
          reloadHint: 'That saved link is no longer working',
          onReload: _manualRecheck,
          onCancel: () {
            _haltBackgroundResolve();
            _manualSwitchRequested = false;
            _manualPreferredSourceKey = null;
            Navigator.of(context).pop();
          },
          onManualCheckProvider: (panelKey) {
            final match = _currentPair.where((e) => e.panelKey == panelKey);
            if (match.isEmpty) return;
            _manualPreferredSourceKey = match.first.sourceKey;
            _manualSwitchRequested = true;
            DomainStreamProviderResolver.cancelAllPending();
          },
        );
      },
    );
  }
}
