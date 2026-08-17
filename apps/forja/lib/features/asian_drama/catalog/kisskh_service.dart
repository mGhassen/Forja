// kisskh.co backend - Asian Drama (KDrama / CDrama / JDrama / Anime / Hollywood).
//
// Catalog/metadata API runs in Rust (`kisskh`). Stream extract signs Episode/Sub
// `kkey` in Rust and GETs the JSON APIs (WebView is fallback only).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rust/rust.dart';

class KissKhService {
  static const String primaryBaseUrl = 'https://kisskh.co';
  static const String defaultMirrorHost = 'kisskh.co';

  /// API-compatible KissKH hosts. Enable the ones you want under Settings →
  /// Sources → Server reliability → Asian Drama. Playback uses the first
  /// enabled host only — no automatic mirror failover (shared IP rate limit).
  static const List<String> mirrorHosts = <String>[
    'kisskh.co',
    'kisskh.nl',
    'kisskh.ovh',
    'kisskh.la',
    'kisskh.do',
  ];

  /// Settings / player catalog: id → display label.
  static Map<String, String> get settingsCatalog => {
    for (final host in mirrorHosts) host: mirrorLabel(host),
  };

  /// Enabled hosts in catalog order (first = active for catalog + playback).
  static List<String> mergeMirrorOrder(List<String> enabled) {
    final on = enabled.map(normalizeMirrorId).toSet();
    return [
      for (final host in mirrorHosts)
        if (on.contains(host)) host,
    ];
  }

  static String activeHostFromOrder(List<String> enabled) {
    final merged = mergeMirrorOrder(enabled);
    return merged.isEmpty ? defaultMirrorHost : merged.first;
  }

  static List<String> toggleMirrorInOrder({
    required List<String> current,
    required String host,
    required bool enabled,
  }) {
    final id = normalizeMirrorId(host);
    if (enabled) {
      if (current.contains(id)) return mergeMirrorOrder(current);
      return mergeMirrorOrder([...current, id]);
    }
    if (current.length <= 1) return mergeMirrorOrder(current);
    return mergeMirrorOrder(current.where((h) => h != id).toList());
  }

  static Future<String> ensureActiveMirrorFromSettings() async {
    final order = await SettingsService().getAsianDramaProviderOrder();
    final host = activeHostFromOrder(order);
    await activateEndpoint(baseUrlForHost(host));
    return host;
  }

  static String mirrorLabel(String hostOrId) {
    return normalizeMirrorId(hostOrId);
  }

  /// Map legacy `kisskh` and URLs to a mirror host id.
  static String normalizeMirrorId(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty || value == 'kisskh') return 'kisskh.co';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.tryParse(value)?.host.toLowerCase() ?? 'kisskh.co';
    }
    return value;
  }

  static bool isMirrorHost(String id) {
    final host = normalizeMirrorId(id);
    return mirrorHosts.contains(host);
  }

  static String baseUrlForHost(String hostOrId) {
    final host = normalizeMirrorId(hostOrId);
    return 'https://$host';
  }

  static String hostFromBaseUrl(String baseUrl) => normalizeMirrorId(baseUrl);

  /// KissKH list thumbnails often use `media.themoviedb.org` (301 → image CDN).
  /// Prefer `image.tmdb.org` so covers share Home's TMDB image TLS path.
  static String normalizeCoverUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host != 'media.themoviedb.org') return value;
    return uri.replace(host: 'image.tmdb.org').toString();
  }

  /// Ask the Rust catalog engine to race API-compatible mirrors. The returned
  /// order keeps the first healthy mirror first and excludes unrelated sites
  /// that happen to use the KissKh name.
  static Future<KissKhEndpointSelection> resolveEndpoint() async {
    final decoded = await kisskhCatalog({'action': 'resolve_base_url'});
    final selected = (decoded['base_url'] as String? ?? '').trim();
    final rawMirrors = decoded['mirror_urls'] as List<dynamic>? ?? const [];
    final mirrors = rawMirrors
        .map((value) => value.toString().trim().replaceFirst(RegExp(r'/$'), ''))
        .where((value) => Uri.tryParse(value)?.hasScheme == true)
        .toSet()
        .toList();
    if (selected.isEmpty || !mirrors.contains(selected)) {
      throw StateError('Rust returned an invalid KissKh mirror: $selected');
    }
    return KissKhEndpointSelection(
      selected: selected,
      mirrors: [selected, ...mirrors.where((value) => value != selected)],
    );
  }

  static Future<void> activateEndpoint(String baseUrl) async {
    await kisskhCatalog({'action': 'activate_base_url', 'base_url': baseUrl});
  }

  /// Per-mirror Dart ceiling - Rust already uses a short HTTP timeout, but a
  /// stuck engine worker must not block auto-select forever.
  static const Duration probeOneTimeout = Duration(seconds: 5);

  /// Wall clock for the whole fan-out. Auto extract proceeds with whatever
  /// answered UP; unanswered hosts are treated as DOWN.
  static const Duration probeDeadline = Duration(seconds: 5);

  /// Probe a single mirror API (engine worker, no nested Rust threads).
  static Future<bool> probeMirror(String hostOrId) async {
    final host = normalizeMirrorId(hostOrId);
    final base = baseUrlForHost(host);
    debugPrint('[KissKh] probe $base …');
    try {
      final decoded = await kisskhCatalog({
        'action': 'probe_one',
        'base_url': base,
      }).timeout(probeOneTimeout);
      final ok = decoded['healthy'] == true;
      debugPrint('[KissKh] probe $base → ${ok ? 'UP' : 'DOWN'}');
      return ok;
    } on TimeoutException {
      debugPrint('[KissKh] probe $base → TIMEOUT');
      return false;
    } catch (e) {
      debugPrint('[KissKh] probe $base failed: $e');
      return false;
    }
  }

  /// Parallel API health check - one engine job per mirror.
  ///
  /// Do not use a single Rust fan-out of threads around shared Tokio
  /// `block_on`. Do not [Future.wait] without a deadline: one hung worker
  /// (3-isolate pool) used to leave Asian Drama stuck with 0 checked and no
  /// auto server pick until the user tapped manually.
  ///
  /// [probe] overrides [probeMirror] for tests.
  static Future<KissKhMirrorHealth> probeMirrors({
    List<String>? hosts,
    void Function(String host, bool healthy)? onResult,
    Duration? deadline,
    Future<bool> Function(String host)? probe,
  }) async {
    final order = [
      for (final raw in (hosts ?? mirrorHosts))
        if (isMirrorHost(raw)) normalizeMirrorId(raw),
    ];
    final unique = <String>[];
    for (final host in order) {
      if (!unique.contains(host)) unique.add(host);
    }
    if (unique.isEmpty) {
      return const KissKhMirrorHealth(
        selected: null,
        healthyHosts: [],
        unhealthyHosts: [],
      );
    }

    final run = probe ?? probeMirror;
    final okByHost = <String, bool>{};
    final pending = unique.toSet();
    final done = Completer<KissKhMirrorHealth>();

    KissKhMirrorHealth snapshot() {
      final healthyHosts = [
        for (final host in unique)
          if (okByHost[host] == true) host,
      ];
      final unhealthyHosts = [
        for (final host in unique)
          if (okByHost[host] != true) host,
      ];
      return KissKhMirrorHealth(
        selected: healthyHosts.isEmpty ? null : healthyHosts.first,
        healthyHosts: healthyHosts,
        unhealthyHosts: unhealthyHosts,
      );
    }

    void finish() {
      if (done.isCompleted) return;
      done.complete(snapshot());
    }

    void record(String host, bool ok, {required bool fromDeadline}) {
      if (done.isCompleted) {
        // Late worker result - still notify so callers can ignore via gen.
        onResult?.call(host, ok);
        return;
      }
      if (!pending.remove(host)) {
        onResult?.call(host, ok);
        return;
      }
      okByHost[host] = ok;
      if (fromDeadline) {
        debugPrint('[KissKh] probe ${baseUrlForHost(host)} → DOWN (deadline)');
      }
      onResult?.call(host, ok);
      if (pending.isEmpty) finish();
    }

    for (final host in unique) {
      unawaited(run(host).then((ok) => record(host, ok, fromDeadline: false)));
    }

    final limit = deadline ?? probeDeadline;
    unawaited(
      Future<void>.delayed(limit).then((_) {
        if (done.isCompleted) return;
        for (final host in pending.toList()) {
          record(host, false, fromDeadline: true);
        }
        finish();
      }),
    );

    return done.future;
  }

  // ─── Public API (Rust engine) ─────────────────────────────────
  Future<KdramaHomeFeed> getHome() async {
    final decoded = await kisskhCatalog({'action': 'home'});
    return KdramaHomeFeed.fromEngineJson(decoded);
  }

  Future<List<KdramaCard>> search(String query) async {
    final decoded = await kisskhCatalog({'action': 'search', 'query': query});
    return _parseCards(decoded['cards']);
  }

  /// Browse the global catalog with filters. Backs the Explore screen.
  ///
  /// Filter codes (kisskh.ovh / kisskh.co Angular SPA):
  ///   type:    0=All, 1=TVSeries, 2=Movie, 3=Anime, 4=Hollywood
  ///   sub:     0=All, 1=English, 2=Khmer, 3=Indonesian, 4=Malay,
  ///            5=Thai, 6=Arabic
  ///   country: 0=All, 1=South Korea, 2=Chinese, 3=United States,
  ///            4=Thailand, 5=Philippine, 6=Japanese, 7=Hong Kong, 8=Taiwan
  ///   status:  0=All, 1=Ongoing, 2=Completed, 3=Upcoming
  ///   order:   1=Popular, 2=Last Update, 3=Release Date
  Future<KdramaExplorePage> explore({
    int page = 1,
    int type = 0,
    int sub = 0,
    int country = 0,
    int status = 0,
    int order = 1,
    int pageSize = 40,
  }) async {
    try {
      final decoded = await kisskhCatalog({
        'action': 'explore',
        'page': page,
        'type_filter': type,
        'sub': sub,
        'country': country,
        'status': status,
        'order': order,
        'page_size': pageSize,
      });
      return KdramaExplorePage.fromEngineJson(decoded);
    } catch (e) {
      debugPrint('[KissKh] explore failed: $e');
      return const KdramaExplorePage(items: [], total: 0, page: 1);
    }
  }

  Future<KdramaDetails> getDetails(int id) async {
    final decoded = await kisskhCatalog({'action': 'details', 'id': id});
    return KdramaDetails.fromEngineJson(decoded);
  }

  /// List endpoints omit year/type - fill from `/Drama/{id}` (cached in Rust).
  Future<List<KdramaCard>> enrichCards(List<KdramaCard> cards) async {
    if (cards.isEmpty) return cards;
    final decoded = await kisskhCatalog({
      'action': 'enrich_cards',
      'cards_json': jsonEncode(cards.map((c) => c.toEngineJson()).toList()),
    });
    return _parseCards(decoded['cards']);
  }

  /// Hero synopsis - list endpoints omit description; fetch from drama details.
  Future<List<KdramaCard>> enrichCardDescriptions(
    List<KdramaCard> cards,
  ) async {
    if (cards.isEmpty) return cards;
    final decoded = await kisskhCatalog({
      'action': 'enrich_card_descriptions',
      'cards_json': jsonEncode(cards.map((c) => c.toEngineJson()).toList()),
    });
    return _parseCards(decoded['cards']);
  }

  Future<KdramaHomeFeed> enrichHomeFeed(KdramaHomeFeed feed) async {
    final decoded = await kisskhCatalog({
      'action': 'enrich_home_feed',
      'feed_json': jsonEncode(feed.toEngineJson()),
    });
    return KdramaHomeFeed.fromEngineJson(decoded);
  }

  List<KdramaCard> _parseCards(dynamic raw) {
    final list = raw as List<dynamic>? ?? const [];
    return list
        .map((e) => KdramaCard.fromEngineJson(e as Map<String, dynamic>))
        .toList();
  }

  static String? yearFromRelease(String releaseDate) {
    if (releaseDate.length >= 4) {
      final y = releaseDate.substring(0, 4);
      if (RegExp(r'^\d{4}$').hasMatch(y)) return y;
    }
    return null;
  }

  /// KissKh drama `status` when the site shows a countdown instead of video.
  static bool isUpcomingStatus(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    return s == 'upcoming';
  }

  /// Human label for kisskh `releaseDate` (`YYYY-MM-DD…` → `Jun 14, 2026`).
  static String formatReleaseDateLabel(String releaseDate) {
    final raw = releaseDate.trim();
    if (raw.length < 10) return raw;
    final parts = raw.substring(0, 10).split('-');
    if (parts.length != 3) return raw.substring(0, 10);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null || month < 1 || month > 12) {
      return raw.substring(0, 10);
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[month - 1]} $day, ${parts[0]}';
  }

  /// Slug for URL building (title with spaces → dashes, lowercased).
  static String slugify(String title) {
    final s = title
        .toLowerCase()
        .replaceAll(RegExp(r"[''‘’`]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return s.isEmpty ? 'drama' : s;
  }

  /// Episode page URL - used as the WebView entry-point for the extractor.
  static String episodePageUrl({
    required String baseUrl,
    required int dramaId,
    required String title,
    required int episodeId,
    required double episodeNumber,
  }) {
    final slug = slugify(title);
    final epLabel = episodeNumber == episodeNumber.truncateToDouble()
        ? episodeNumber.toInt().toString()
        : episodeNumber.toString();
    final base = baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    return '$base/Drama/$slug/Episode-$epLabel'
        '?id=$dramaId&ep=$episodeId&page=0&pageSize=100';
  }

  // ─── Watch history (continue watching) ──────────────────────────
  static const String _historyKey = 'kisskh_history_v1';

  static final ValueNotifier<int> watchHistoryRevision = ValueNotifier<int>(0);

  Future<void> recordWatch({
    required KdramaCard drama,
    required double episodeNumber,
    required int totalEpisodes,
    int? episodeId,
    List<KdramaEpisode> episodes = const [],
    Duration? position,
    Duration? duration,
  }) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_historyKey) ?? [];
    list.removeWhere((e) {
      try {
        return jsonDecode(e)['id'] == drama.id;
      } catch (_) {
        return true;
      }
    });
    list.insert(
      0,
      jsonEncode({
        'id': drama.id,
        'title': drama.title,
        'cover': drama.cover,
        'episodeNumber': episodeNumber,
        if (episodeId != null && episodeId > 0) 'episodeId': episodeId,
        'totalEpisodes': totalEpisodes,
        if (episodes.isNotEmpty)
          'episodes': episodes
              .map(
                (e) => {
                  'id': e.id,
                  'number': e.number,
                  if (e.sub != 0) 'sub': e.sub,
                },
              )
              .toList(),
        'positionMs': position?.inMilliseconds ?? 0,
        'durationMs': duration?.inMilliseconds ?? 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    if (list.length > 50) list.removeRange(50, list.length);
    await p.setStringList(_historyKey, list);
    watchHistoryRevision.value++;
  }

  /// Reconstruct kisskh episode rows saved with [recordWatch].
  static List<KdramaEpisode> episodesFromHistory(Map<String, dynamic> entry) {
    final raw = entry['episodes'] as List?;
    if (raw == null || raw.isEmpty) return const [];
    final out = <KdramaEpisode>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final id = (item['id'] as num?)?.toInt();
      final number = (item['number'] as num?)?.toDouble();
      if (id == null || number == null) continue;
      out.add(
        KdramaEpisode(
          id: id,
          number: number,
          sub: (item['sub'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    out.sort((a, b) => a.number.compareTo(b.number));
    return out;
  }

  /// Same seek math as details → Resume (2–85% only; finished restarts at 0).
  static Duration? startPositionFromHistory(Map<String, dynamic> entry) {
    final posMs = (entry['positionMs'] as num?)?.toInt() ?? 0;
    final durMs = (entry['durationMs'] as num?)?.toInt() ?? 0;
    if (posMs <= 5000 || !isInProgressResume(posMs, durMs)) return null;
    return Duration(milliseconds: (posMs - 3000).clamp(0, 1 << 31));
  }

  /// Match watch-history entry to a live episode row (number first - stable
  /// across kisskh API id churn; id is a secondary hint).
  static KdramaEpisode? matchResumeEpisode({
    required List<KdramaEpisode> episodes,
    required double episodeNumber,
    int? episodeId,
  }) {
    if (episodes.isEmpty) return null;
    for (final e in episodes) {
      if (e.number == episodeNumber) return e;
    }
    if (episodeId != null && episodeId > 0) {
      try {
        return episodes.firstWhere((e) => e.id == episodeId);
      } catch (_) {}
    }
    return episodes.first;
  }

  Future<List<Map<String, dynamic>>> getWatchHistory() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_historyKey) ?? [];
    final out = <Map<String, dynamic>>[];
    for (final raw in list) {
      try {
        out.add(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return out;
  }

  Future<Map<String, dynamic>?> getProgress(int id) async {
    final all = await getWatchHistory();
    for (final h in all) {
      if ((h['id'] as num?)?.toInt() == id) return h;
    }
    return null;
  }

  Future<void> removeFromHistory(int id) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_historyKey) ?? [];
    list.removeWhere((e) {
      try {
        return jsonDecode(e)['id'] == id;
      } catch (_) {
        return true;
      }
    });
    await p.setStringList(_historyKey, list);
    watchHistoryRevision.value++;
  }

  Future<void> clearWatchHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_historyKey);
    watchHistoryRevision.value++;
  }
}

class KissKhEndpointSelection {
  final String selected;
  final List<String> mirrors;

  const KissKhEndpointSelection({
    required this.selected,
    required this.mirrors,
  });
}

class KissKhMirrorHealth {
  final String? selected;
  final List<String> healthyHosts;
  final List<String> unhealthyHosts;

  const KissKhMirrorHealth({
    required this.selected,
    required this.healthyHosts,
    required this.unhealthyHosts,
  });

  bool isHealthy(String hostOrId) =>
      healthyHosts.contains(KissKhService.normalizeMirrorId(hostOrId));
}

// ════════════════════════════════════════════════════════════════════
//  Models
// ════════════════════════════════════════════════════════════════════

class KdramaCard {
  final int id;
  final String title;
  final String cover;
  final String? label;
  final int episodesCount;
  final String? year;

  /// Raw kisskh type: `TVSeries`, `Movie`, `Anime`, `Hollywood`.
  final String? type;

  /// Synopsis from details enrich - list endpoints omit this.
  final String description;

  const KdramaCard({
    required this.id,
    required this.title,
    required this.cover,
    this.label,
    this.episodesCount = 0,
    this.year,
    this.type,
    this.description = '',
  });

  factory KdramaCard.fromEngineJson(Map<String, dynamic> json) {
    final typeRaw = (json['type'] as String?)?.trim();
    final labelRaw = (json['label'] as String?)?.trim();
    return KdramaCard(
      id: (json['id'] as num).toInt(),
      title: (json['title'] as String? ?? '').trim(),
      cover: KissKhService.normalizeCoverUrl(json['cover'] as String? ?? ''),
      label: labelRaw == null || labelRaw.isEmpty ? null : labelRaw,
      episodesCount: (json['episodes_count'] as num?)?.toInt() ?? 0,
      year: json['year'] as String?,
      type: typeRaw == null || typeRaw.isEmpty ? null : typeRaw,
      description: (json['description'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toEngineJson() => {
    'id': id,
    'title': title,
    'cover': cover,
    if (label != null) 'label': label,
    'episodes_count': episodesCount,
    if (year != null) 'year': year,
    if (type != null) 'type': type,
    if (description.isNotEmpty) 'description': description,
  };

  KdramaCard copyWith({
    int? id,
    String? title,
    String? cover,
    String? label,
    int? episodesCount,
    String? year,
    String? type,
    String? description,
  }) {
    return KdramaCard(
      id: id ?? this.id,
      title: title ?? this.title,
      cover: cover ?? this.cover,
      label: label ?? this.label,
      episodesCount: episodesCount ?? this.episodesCount,
      year: year ?? this.year,
      type: type ?? this.type,
      description: description ?? this.description,
    );
  }

  /// Home-hero style badge: SERIES / FILM / ANIME / HOLLYWOOD.
  String? get heroMediaBadge {
    switch ((type ?? '').toLowerCase()) {
      case 'tvseries':
        return 'SERIES';
      case 'movie':
        return 'FILM';
      case 'anime':
        return 'ANIME';
      case 'hollywood':
        return 'HOLLYWOOD';
      default:
        return type?.isNotEmpty == true ? type!.toUpperCase() : null;
    }
  }

  /// Home-poster style label: TV / FILM / ANIME / HOLLYWOOD.
  String? get cardMediaLabel {
    switch ((type ?? '').toLowerCase()) {
      case 'tvseries':
        return 'TV';
      case 'movie':
        return 'FILM';
      case 'anime':
        return 'ANIME';
      case 'hollywood':
        return 'HOLLYWOOD';
      default:
        return type?.isNotEmpty == true ? type : null;
    }
  }
}

class KdramaHomeFeed {
  final List<KdramaCard> spotlight;
  final List<KdramaCard> latest;
  final List<KdramaCard> mostViewed;
  final List<KdramaCard> trending;
  final List<KdramaCard> topRated;
  final List<KdramaCard> upcoming;
  final List<KdramaCard> anime;

  const KdramaHomeFeed({
    this.spotlight = const [],
    this.latest = const [],
    this.mostViewed = const [],
    this.trending = const [],
    this.topRated = const [],
    this.upcoming = const [],
    this.anime = const [],
  });

  factory KdramaHomeFeed.fromEngineJson(Map<String, dynamic> json) {
    List<KdramaCard> list(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw
          .map((e) => KdramaCard.fromEngineJson(e as Map<String, dynamic>))
          .toList();
    }

    return KdramaHomeFeed(
      spotlight: list('spotlight'),
      latest: list('latest'),
      mostViewed: list('most_viewed'),
      trending: list('trending'),
      topRated: list('top_rated'),
      upcoming: list('upcoming'),
      anime: list('anime'),
    );
  }

  Map<String, dynamic> toEngineJson() => {
    'spotlight': spotlight.map((c) => c.toEngineJson()).toList(),
    'latest': latest.map((c) => c.toEngineJson()).toList(),
    'most_viewed': mostViewed.map((c) => c.toEngineJson()).toList(),
    'trending': trending.map((c) => c.toEngineJson()).toList(),
    'top_rated': topRated.map((c) => c.toEngineJson()).toList(),
    'upcoming': upcoming.map((c) => c.toEngineJson()).toList(),
    'anime': anime.map((c) => c.toEngineJson()).toList(),
  };

  /// Merge enriched cards (by id) into every feed row.
  KdramaHomeFeed withCardsReplaced(List<KdramaCard> updates) {
    if (updates.isEmpty) return this;
    final byId = {for (final c in updates) c.id: c};
    KdramaCard patch(KdramaCard c) => byId[c.id] ?? c;
    return KdramaHomeFeed(
      spotlight: spotlight.map(patch).toList(),
      latest: latest.map(patch).toList(),
      mostViewed: mostViewed.map(patch).toList(),
      trending: trending.map(patch).toList(),
      topRated: topRated.map(patch).toList(),
      upcoming: upcoming.map(patch).toList(),
      anime: anime.map(patch).toList(),
    );
  }
}

class KdramaDetails {
  final int id;
  final String title;
  final String description;
  final String cover;
  final String releaseDate;
  final String country;
  final String status;
  final String type;
  final int episodesCount;
  final String? label;
  final List<KdramaEpisode> episodes;

  const KdramaDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.cover,
    required this.releaseDate,
    required this.country,
    required this.status,
    required this.type,
    required this.episodesCount,
    this.label,
    this.episodes = const [],
  });

  factory KdramaDetails.fromEngineJson(Map<String, dynamic> json) {
    final eps = (json['episodes'] as List<dynamic>? ?? const [])
        .map((e) => KdramaEpisode.fromEngineJson(e as Map<String, dynamic>))
        .toList();
    final labelRaw = (json['label'] as String?)?.trim();
    return KdramaDetails(
      id: (json['id'] as num).toInt(),
      title: (json['title'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      cover: KissKhService.normalizeCoverUrl(json['cover'] as String? ?? ''),
      releaseDate: json['release_date'] as String? ?? '',
      country: json['country'] as String? ?? '',
      status: json['status'] as String? ?? '',
      type: json['type'] as String? ?? '',
      episodesCount: (json['episodes_count'] as num?)?.toInt() ?? eps.length,
      label: labelRaw == null || labelRaw.isEmpty ? null : labelRaw,
      episodes: eps,
    );
  }

  String? get year => KissKhService.yearFromRelease(releaseDate);

  KdramaCard toCard() => KdramaCard(
    id: id,
    title: title,
    cover: cover,
    label: label,
    episodesCount: episodesCount,
    year: year,
    type: type.isEmpty ? null : type,
    description: description,
  );

  /// Match a watch-history entry to a live episode row (number first - stable
  /// across kisskh API id churn; id is a secondary hint).
  KdramaEpisode? episodeForResume({
    required double episodeNumber,
    int? episodeId,
  }) {
    return KissKhService.matchResumeEpisode(
      episodes: episodes,
      episodeNumber: episodeNumber,
      episodeId: episodeId,
    );
  }
}

class KdramaEpisode {
  final int id;
  final double number;
  final int sub;

  const KdramaEpisode({required this.id, required this.number, this.sub = 0});

  factory KdramaEpisode.fromEngineJson(Map<String, dynamic> json) {
    return KdramaEpisode(
      id: (json['id'] as num).toInt(),
      number: (json['number'] as num).toDouble(),
      sub: (json['sub'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayNumber {
    if (number == number.truncateToDouble()) return number.toInt().toString();
    return number.toString();
  }
}

/// Single page of the `/DramaList/List` Explore endpoint.
class KdramaExplorePage {
  final List<KdramaCard> items;
  final int total;
  final int page;
  final int pageSize;
  const KdramaExplorePage({
    required this.items,
    required this.total,
    required this.page,
    this.pageSize = 40,
  });

  factory KdramaExplorePage.fromEngineJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return KdramaExplorePage(
      items: raw
          .map((e) => KdramaCard.fromEngineJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 40,
    );
  }

  bool get hasMore => page * pageSize < total;
}

/// Static lookup tables for the Explore filter chips. Order matches the
/// integer codes consumed by `KissKhService.explore(...)`.
class KissKhExploreFilters {
  static const List<String> types = [
    'All',
    'TV Series',
    'Movie',
    'Anime',
    'Hollywood',
  ];
  static const List<String> subtitles = [
    'All',
    'English',
    'Khmer',
    'Indonesian',
    'Malay',
    'Thai',
    'Arabic',
  ];
  static const List<String> countries = [
    'All',
    'South Korea',
    'Chinese',
    'United States',
    'Thailand',
    'Philippine',
    'Japanese',
    'Hong Kong',
    'Taiwan',
  ];
  static const List<String> statuses = [
    'All',
    'Ongoing',
    'Completed',
    'Upcoming',
  ];
  static const List<String> orders = [
    // index 0 unused - the API uses 1-based ordering codes.
    '', 'Popular', 'Last Update', 'Release Date',
  ];
}
