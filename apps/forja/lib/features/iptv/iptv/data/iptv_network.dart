import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:forja/shared/sync/src/account_features.dart';
import 'package:rust/rust.dart';
import 'models.dart';

Future<String?> _engineHttpGet(
  String url, {
  Duration timeout = const Duration(seconds: 10),
  Map<String, String>? headers,
}) async {
  try {
    final hdr = jsonEncode(headers ?? const {});
    final secs = timeout.inSeconds.clamp(1, 120);
    final raw = await runHttpGetJson(
      url,
      timeoutSecs: secs,
      headersJson: hdr,
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) return null;
    final status = parsed['status'] as int;
    if (status < 200 || status >= 300) return null;
    return parsed['body'] as String;
  } catch (_) {
    return null;
  }
}

Future<String> _engineProbeStream(String url, int timeoutSecs) =>
    runIptvProbeStreamJson(url, timeoutSecs: timeoutSecs);

Future<Map<String, dynamic>?> _xtreamRequest(
  Map<String, dynamic> body,
) async {
  final raw = await _xtreamRequestRaw(body);
  if (raw == null || raw.containsKey('error')) return null;
  return raw;
}

/// Full engine JSON including `{error: …}` - used when empty vs failure matters.
Future<Map<String, dynamic>?> _xtreamRequestRaw(
  Map<String, dynamic> body,
) async {
  try {
    final raw = await runIptvXtreamJson(jsonEncode(body));
    final parsed = jsonDecode(raw);
    if (parsed is! Map<String, dynamic>) return null;
    return parsed;
  } catch (_) {
    return null;
  }
}

/// Result of a shelf catalog fetch (Live / Movies / Series).
class IptvCatalogFetch {
  const IptvCatalogFetch({
    required this.categories,
    required this.streams,
    this.error,
    this.epgUrl,
  });

  final List<IptvCategory> categories;
  final List<IptvStream> streams;
  final String? error;

  /// XMLTV guide URL the portal embedded (M3U `url-tvg` / `x-tvg-url`).
  /// Not persisted yet — surfaced for future EPG wiring (RFC-051 out of
  /// scope item: "Stalker/M3U EPG parity").
  final String? epgUrl;

  bool get ok => error == null;

  static const emptyOk = IptvCatalogFetch(
    categories: [],
    streams: [],
  );
}

/// Xtream-Codes player_api client. Login + catalog + episodes via Rust.
class IptvClient {
  static const _ua = 'VLC/3.0.20 LibVLC/3.0.20';

  /// Large Live lineups (20k+ streams) need headroom for download + parse.
  static int _catalogTimeoutSecs(IptvSection kind) => switch (kind) {
        IptvSection.live => 90,
        IptvSection.vod => 60,
        IptvSection.series => 60,
      };

  static String _enc(String s) => Uri.encodeComponent(s);

  static String _sectionName(IptvSection kind) => switch (kind) {
        IptvSection.live => 'live',
        IptvSection.vod => 'vod',
        IptvSection.series => 'series',
      };

  static Map<String, dynamic> _portalBody(
    IptvPortal p, {
    required String action,
    required int timeoutSecs,
    String? section,
    String? categoryId,
    String? seriesId,
    String? cmd,
  }) =>
      {
        'action': action,
        'platform': p.platform.wire,
        'url': p.url,
        'username': p.username,
        'password': p.password,
        'timeout_secs': timeoutSecs,
        if (p.userAgent.isNotEmpty) 'user_agent': p.userAgent,
        if (section != null) 'section': section,
        if (categoryId != null) 'category_id': categoryId,
        if (seriesId != null) 'series_id': seriesId,
        if (cmd != null && cmd.isNotEmpty) 'cmd': cmd,
      };

  static Future<String?> _httpGet(String url, {Duration? timeout}) =>
      _engineHttpGet(
        url,
        timeout: timeout ?? const Duration(seconds: 10),
        headers: const {
          'User-Agent': _ua,
          'Accept': 'application/json,*/*',
        },
      );

  static Future<Map<String, dynamic>?> login(IptvPortal p,
      {Duration timeout = const Duration(seconds: 6)}) async {
    final root = await _xtreamRequest(_portalBody(
      p,
      action: 'login',
      timeoutSecs: timeout.inSeconds.clamp(1, 120),
    ));
    if (root == null) return null;
    final info = root['user_info'];
    if (info is! Map<String, dynamic>) return null;
    return info;
  }

  static Future<VerifiedPortal?> verifyOrNull(IptvPortal p,
      {Duration timeout = const Duration(seconds: 6)}) async {
    final info = await login(p, timeout: timeout);
    if (info == null) return null;
    return VerifiedPortal(
      portal: p,
      name: (info['username']?.toString() ?? '').isNotEmpty
          ? info['username'].toString()
          : p.username,
      expiry: _formatExpiry(info['exp_date']?.toString()),
      maxConnections: info['max_connections']?.toString() ?? '1',
      activeConnections: info['active_cons']?.toString() ?? '0',
    );
  }

  static String _formatExpiry(String? raw) {
    if (raw == null) return 'Unknown';
    final ts = int.tryParse(raw);
    if (ts == null) return 'Unknown';
    try {
      final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  /// Categories + streams for one shelf (orphans already merged in Rust).
  static Future<IptvCatalogFetch> catalog(
    IptvPortal p,
    IptvSection kind,
  ) async {
    final root = await _xtreamRequestRaw(_portalBody(
      p,
      action: 'catalog',
      section: _sectionName(kind),
      timeoutSecs: _catalogTimeoutSecs(kind),
    ));
    if (root == null) {
      return const IptvCatalogFetch(
        categories: [],
        streams: [],
        error: 'Catalog request failed',
      );
    }
    if (root['error'] != null) {
      return IptvCatalogFetch(
        categories: const [],
        streams: const [],
        error: root['error'].toString(),
      );
    }
    return IptvCatalogFetch(
      categories: _mapCategories(root['categories']),
      streams: _mapStreams(root['streams'], _sectionName(kind)),
      epgUrl: root['epg_url']?.toString(),
    );
  }

  static Future<List<IptvCategory>> categories(
      IptvPortal p, IptvSection kind) async {
    final root = await _xtreamRequest(_portalBody(
      p,
      action: 'categories',
      section: _sectionName(kind),
      timeoutSecs: 20,
    ));
    if (root == null) return const [];
    return _mapCategories(root['categories']);
  }

  static Future<List<IptvStream>> streams(
      IptvPortal p, IptvSection kind, String categoryId) async {
    final root = await _xtreamRequest(_portalBody(
      p,
      action: 'streams',
      section: _sectionName(kind),
      categoryId: categoryId,
      timeoutSecs: _catalogTimeoutSecs(kind),
    ));
    if (root == null) return const [];
    return _mapStreams(root['streams'], _sectionName(kind));
  }

  /// Merge portal categories with stream orphan ids (Rust normalize).
  static Future<List<IptvCategory>> mergeOrphanCategories(
    List<IptvCategory> categories,
    List<IptvStream> streams,
  ) async {
    final root = await _xtreamRequest({
      'action': 'merge',
      'categories': [
        for (final c in categories) {'id': c.id, 'name': c.name},
      ],
      'streams': [
        for (final s in streams)
          {
            'stream_id': s.streamId,
            'name': s.name,
            'icon': s.icon,
            'category_id': s.categoryId,
            'container_ext': s.containerExt,
            'epg_channel_id': s.epgChannelId,
            'kind': s.kind,
          },
      ],
    });
    if (root == null) return categories;
    return _mapCategories(root['categories']);
  }

  static List<IptvCategory> _mapCategories(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>)
          IptvCategory(
            id: e['id']?.toString() ?? '',
            name: e['name']?.toString() ?? '',
          ),
    ];
  }

  static List<IptvStream> _mapStreams(dynamic raw, String sectionName) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>)
          IptvStream(
            streamId: e['stream_id']?.toString() ?? '',
            name: e['name']?.toString() ?? '',
            icon: e['icon']?.toString() ?? '',
            categoryId: e['category_id']?.toString() ?? '',
            containerExt: e['container_ext']?.toString() ?? '',
            epgChannelId: e['epg_channel_id']?.toString() ?? '',
            kind: e['kind']?.toString() ?? sectionName,
          ),
    ];
  }

  static Future<List<IptvEpisode>> seriesEpisodes(
      IptvPortal p, String seriesId) async {
    final root = await _xtreamRequest(_portalBody(
      p,
      action: 'series_episodes',
      seriesId: seriesId,
      timeoutSecs: 15,
    ));
    if (root == null) return const [];
    final raw = root['episodes'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>)
          IptvEpisode(
            id: e['id']?.toString() ?? '',
            title: e['title']?.toString() ?? '',
            containerExt: e['container_ext']?.toString() ?? '',
            season: (e['season'] as num?)?.toInt() ?? 0,
            episode: (e['episode'] as num?)?.toInt() ?? 0,
            plot: e['plot']?.toString() ?? '',
            image: e['image']?.toString() ?? '',
          ),
    ];
  }

  /// Sync path URL for Xtream. For M3U returns [IptvStream.streamId] (the
  /// channel URL). For Stalker returns empty — use [resolvePlayUrl].
  static String streamUrl(IptvPortal p, IptvStream s) {
    switch (p.platform) {
      case IptvPortalPlatform.m3u:
        return s.streamId;
      case IptvPortalPlatform.stalker:
        return '';
      case IptvPortalPlatform.xtream:
        final user = _enc(p.username);
        final pass = _enc(p.password);
        switch (s.kind) {
          case 'live':
            return '${p.url}/live/$user/$pass/${s.streamId}.${s.containerExt}';
          case 'vod':
            return '${p.url}/movie/$user/$pass/${s.streamId}.${s.containerExt}';
          default:
            return '';
        }
    }
  }

  static String episodeUrl(IptvPortal p, IptvEpisode e) {
    switch (p.platform) {
      case IptvPortalPlatform.m3u:
        return e.id;
      case IptvPortalPlatform.stalker:
        return '';
      case IptvPortalPlatform.xtream:
        return '${p.url}/series/${_enc(p.username)}/${_enc(p.password)}/${e.id}.${e.containerExt}';
    }
  }

  /// Resolve a playable URL for any platform (Stalker create_link when needed).
  static Future<String?> resolvePlayUrl(
    IptvPortal p,
    IptvStream s, {
    String? section,
  }) async {
    switch (p.platform) {
      case IptvPortalPlatform.m3u:
        return s.streamId.isEmpty ? null : s.streamId;
      case IptvPortalPlatform.xtream:
        final u = streamUrl(p, s);
        return u.isEmpty ? null : u;
      case IptvPortalPlatform.stalker:
        return createLink(
          p,
          cmd: s.streamId,
          section: section ?? s.kind,
        );
    }
  }

  static Future<String?> resolveEpisodeUrl(IptvPortal p, IptvEpisode e) async {
    switch (p.platform) {
      case IptvPortalPlatform.m3u:
        return e.id.isEmpty ? null : e.id;
      case IptvPortalPlatform.xtream:
        final u = episodeUrl(p, e);
        return u.isEmpty ? null : u;
      case IptvPortalPlatform.stalker:
        return createLink(p, cmd: e.id, section: 'series');
    }
  }

  static Future<String?> createLink(
    IptvPortal p, {
    required String cmd,
    String section = 'live',
  }) async {
    if (cmd.trim().isEmpty) return null;
    final root = await _xtreamRequest(_portalBody(
      p,
      action: 'create_link',
      timeoutSecs: 20,
      section: section,
      cmd: cmd,
    ));
    if (root == null) return null;
    final url = root['url']?.toString() ?? '';
    return url.isEmpty ? null : url;
  }

  /// Fetches the next [limit] EPG programmes for [streamId] via Xtream's
  /// `get_short_epg`. Returns an empty list on any failure (no panel EPG,
  /// timeout, malformed JSON, etc.) so callers can simply hide the row.
  ///
  /// Xtream encodes `title` and `description` as base64 strings.
  static String _decodeXtreamField(String s) {
    return RustLib.instance.decodeXtreamText(s);
  }

  static DateTime? _parseEpgTs(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    // Xtream sends both unix-seconds ("start_timestamp") and ISO-ish
    // strings ("start": "2026-04-25 19:00:00"). Try seconds first.
    final secs = int.tryParse(s);
    if (secs != null && secs > 1000000000) {
      final ms = secs > 1000000000000 ? secs : secs * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    try {
      return DateTime.parse(s.replaceFirst(' ', 'T')).toLocal();
    } catch (_) {
      return null;
    }
  }

  static List<EpgEntry> _parseEpgListings(String text) {
    final root = json.decode(text);
    final List arr = root is Map<String, dynamic>
        ? (root['epg_listings'] as List? ?? const [])
        : (root is List ? root : const []);
    final out = <EpgEntry>[];
    for (final e in arr) {
      if (e is! Map<String, dynamic>) continue;
      final start = _parseEpgTs(e['start_timestamp']) ?? _parseEpgTs(e['start']);
      final stop = _parseEpgTs(e['stop_timestamp']) ??
          _parseEpgTs(e['end']) ??
          _parseEpgTs(e['stop']);
      if (start == null || stop == null) continue;
      out.add(EpgEntry(
        title: _decodeXtreamField(e['title']?.toString() ?? ''),
        description: _decodeXtreamField(e['description']?.toString() ?? ''),
        start: start,
        stop: stop,
      ));
    }
    out.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return b.stop.compareTo(a.stop);
    });
    // Panels often repeat the same programme (or near-identical rows).
    final deduped = <EpgEntry>[];
    for (final e in out) {
      if (!e.stop.isAfter(e.start)) continue;
      if (deduped.isNotEmpty) {
        final prev = deduped.last;
        if (prev.start == e.start &&
            prev.stop == e.stop &&
            prev.title == e.title) {
          continue;
        }
      }
      deduped.add(e);
    }
    return deduped;
  }

  static Future<List<EpgEntry>> shortEpg(
    IptvPortal p,
    String streamId, {
    int limit = 2,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (streamId.isEmpty) return const [];
    final url = '${p.url}/player_api.php?username=${_enc(p.username)}'
        '&password=${_enc(p.password)}'
        '&action=get_short_epg&stream_id=${_enc(streamId)}&limit=$limit';
    final text = await _httpGet(url, timeout: timeout);
    if (text == null) return const [];
    try {
      return _parseEpgListings(text);
    } catch (_) {
      return const [];
    }
  }

  /// Full EPG table for one live stream (`get_simple_data_table`).
  /// Optionally keep only programmes overlapping `[windowStart, windowEnd]`.
  static Future<List<EpgEntry>> simpleDataTable(
    IptvPortal p,
    String streamId, {
    DateTime? windowStart,
    DateTime? windowEnd,
    Duration timeout = const Duration(seconds: 18),
  }) async {
    if (streamId.isEmpty) return const [];
    final url = '${p.url}/player_api.php?username=${_enc(p.username)}'
        '&password=${_enc(p.password)}'
        '&action=get_simple_data_table&stream_id=${_enc(streamId)}';
    final text = await _httpGet(url, timeout: timeout);
    if (text == null) return const [];
    try {
      final all = _parseEpgListings(text);
      if (windowStart == null || windowEnd == null) return all;
      return all
          .where((e) => e.stop.isAfter(windowStart) && e.start.isBefore(windowEnd))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verifier - bounded concurrency, abort once `target` portals authenticated.
// ─────────────────────────────────────────────────────────────────────────────
class IptvVerifier {
  static const _parallel = 4;

  static Future<List<VerifiedPortal>> verifyUntil({
    required List<IptvPortal> portals,
    int target = 5,
    void Function(int checked, int total, int alive)? onProgress,
    void Function(VerifiedPortal v)? onAlive,
    void Function(IptvPortal p)? onAttempted,
    bool Function()? isCancelled,
  }) async {
    if (portals.isEmpty) return const [];

    var nextIdx = 0;
    var checked = 0;
    final alive = <VerifiedPortal>[];
    final completer = Completer<void>();
    var stopped = false;

    void stop() {
      if (!stopped) {
        stopped = true;
        if (!completer.isCompleted) completer.complete();
      }
    }

    Future<void> worker() async {
      while (!stopped) {
        if (isCancelled?.call() == true) {
          stop();
          break;
        }
        if (alive.length >= target) {
          stop();
          break;
        }
        final idx = nextIdx++;
        if (idx >= portals.length) break;
        onAttempted?.call(portals[idx]);
        VerifiedPortal? v;
        try {
          v = await IptvClient.verifyOrNull(portals[idx]);
        } catch (_) {
          v = null;
        }
        if (stopped) break;
        checked++;
        if (v != null && alive.length < target) {
          alive.add(v);
          onAlive?.call(v);
        }
        onProgress?.call(checked, portals.length, alive.length);
        if (alive.length >= target) {
          stop();
          break;
        }
      }
    }

    final workers = List.generate(
      _parallel.clamp(1, portals.length),
      (_) => worker(),
    );
    // Wait either all workers done or `stop()` triggered.
    await Future.any([
      Future.wait(workers),
      completer.future,
    ]);
    return List.unmodifiable(alive);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alive checker - partial-content stream-content sniffing.
// ─────────────────────────────────────────────────────────────────────────────
class AliveProgress {
  final int checked;
  final int total;
  final int alive;
  const AliveProgress(this.checked, this.total, this.alive);
}

class IptvAliveChecker {
  static const Duration _timeout = Duration(seconds: 8);
  static const int _concurrency = 24;

  /// Run alive checks. Caller controls cancellation via [isCancelled].
  /// Returns when all complete or cancelled.
  static Future<void> launchCheck({
    required List<MapEntry<String, String>> streams, // (id, url)
    required Future<void> Function(String id, bool alive) onResult,
    required Future<void> Function(AliveProgress p) onProgress,
    required Future<void> Function() onDone,
    bool Function()? isCancelled,
  }) async {
    var checked = 0;
    var alive = 0;
    final total = streams.length;
    final pending = List<MapEntry<String, String>>.from(streams);

    Future<void> worker() async {
      while (true) {
        if (isCancelled?.call() == true) return;
        if (pending.isEmpty) return;
        final job = pending.removeAt(0);
        final ok = await _isAlive(job.value);
        if (isCancelled?.call() == true) return;
        checked++;
        if (ok) alive++;
        await onResult(job.key, ok);
        await onProgress(AliveProgress(checked, total, alive));
      }
    }

    final workers = List.generate(_concurrency, (_) => worker());
    await Future.wait(workers);
    if (isCancelled?.call() != true) await onDone();
  }

  /// Lightweight single-stream probe for lazy viewport checks.
  static Future<bool> checkOne(String url) => _isAlive(url);

  static Future<bool> _isAlive(String url) async {
    try {
      final raw = await _engineProbeStream(url, _timeout.inSeconds);
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (parsed.containsKey('error')) return false;
      return parsed['alive'] == true;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Catalog Xtream-Codes scraper
// ─────────────────────────────────────────────────────────────────────────────

/// Which backend the catalog scraper should pull from.
///
/// Prefer calling [IptvScraper.scrapeCatalogPage] without [source] - Reddit
/// catalog when [_xml2ScrapeEnabled] is false; otherwise Reddit → XML2 chain.
/// Kept for callers that still pass an explicit backend.
enum CatalogSource { best, works }

/// Parsed Reddit catalog pagination cursor.
class RedditCatalogCursor {
  final int subIdx;
  final String? after;
  const RedditCatalogCursor({this.subIdx = 0, this.after});
}

/// Decodes Reddit catalog cursors (parity with Rust `parse_reddit_catalog_cursor`):
///   `reddit:<subIdx>:<token>` - current format
///   `reddit:<token>`          - legacy (sub 0)
///   `<token>`                 - legacy bare token (sub 0)
RedditCatalogCursor parseRedditCatalogCursor(String? after) {
  if (after == null || after.isEmpty) {
    return const RedditCatalogCursor();
  }
  if (after.startsWith('reddit:')) {
    final rest = after.substring(7);
    if (rest.isEmpty) return const RedditCatalogCursor();
    final colon = rest.indexOf(':');
    if (colon >= 0) {
      final subIdx = int.tryParse(rest.substring(0, colon)) ?? 0;
      final token = rest.substring(colon + 1);
      final pageAfter = (token.isEmpty || token == 'null') ? null : token;
      return RedditCatalogCursor(subIdx: subIdx, after: pageAfter);
    }
    final pageAfter = rest == 'null' ? null : rest;
    return RedditCatalogCursor(subIdx: 0, after: pageAfter);
  }
  final pageAfter = after == 'null' ? null : after;
  return RedditCatalogCursor(subIdx: 0, after: pageAfter);
}

class IptvScraper {
  /// GitHub XML2 dump scraping (`CatalogSource.works`). Off for now - Reddit
  /// only until adult-host filtering / source quality is addressed.
  static const _xml2ScrapeEnabled = false;

  /// Number of Reddit catalog subs scraped by the Rust engine.
  static const catalogSubCount = 4;

  static const _ua = 'Mozilla/5.0 (Linux; Android 11; Forja) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36';

  // ── GitHub XML2 dump source (disabled via [_xml2ScrapeEnabled]). ──
  static const _xml2Base =
      'https://raw.githubusercontent.com/akeotaseo/world_repo/main/Updater_Matrix/XML2/';
  static const _xml2ListApi =
      'https://api.github.com/repos/akeotaseo/world_repo/contents/Updater_Matrix/XML2?ref=main';
  static const _xml2FallbackFiles = <String>[
    '25.txt',
    '71.txt',
    'ABN.txt',
    'DOV.txt',
    '%5BK_B_W_%20Client%5D.txt',
    'br.txt',
    'channels_fulltime%20(OR).txt',
    'channels_fulltime.txt',
    'kgen%20(4).txt',
    'kgen.txt',
    'rg.txt',
    'x.txt',
    '%7BAllTelegram%7D2.txt',
  ];

  static List<String>? _xml2Files;
  static DateTime? _xml2FilesFetchedAt;
  static const _xml2ListTtl = Duration(hours: 6);

  static Future<List<String>> _getXml2Files() async {
    final cached = _xml2Files;
    final fetchedAt = _xml2FilesFetchedAt;
    if (cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _xml2ListTtl) {
      return cached;
    }
    try {
      final body = await _engineHttpGet(
        _xml2ListApi,
        timeout: const Duration(seconds: 12),
        headers: const {
          'User-Agent': _ua,
          'Accept': 'application/vnd.github+json',
        },
      );
      if (body != null) {
        final decoded = json.decode(body);
        if (decoded is List) {
          final entries = <MapEntry<String, int>>[];
          for (final entry in decoded) {
            if (entry is! Map) continue;
            if (entry['type'] != 'file') continue;
            final name = entry['name']?.toString();
            if (name == null || !name.toLowerCase().endsWith('.txt')) continue;
            final size =
                int.tryParse('${entry['size'] ?? ''}') ?? 1 << 30;
            entries.add(MapEntry(Uri.encodeComponent(name), size));
          }
          if (entries.isNotEmpty) {
            entries.sort((a, b) => a.value.compareTo(b.value));
            final files = entries.map((e) => e.key).toList(growable: false);
            _xml2Files = files;
            _xml2FilesFetchedAt = DateTime.now();
            debugPrint(
                '[XML2] listed ${files.length} files from GitHub (sorted by size, smallest first)');
            return files;
          }
        }
      } else {
        debugPrint('[XML2] list HTTP failed');
      }
    } catch (e) {
      debugPrint('[XML2] list failed: $e');
    }
    _xml2Files = _xml2FallbackFiles;
    _xml2FilesFetchedAt = DateTime.now();
    debugPrint('[XML2] using fallback list (${_xml2FallbackFiles.length} files)');
    return _xml2FallbackFiles;
  }

  /// Cursor encoding for [scrapeCatalogPage]:
  ///   `null`                 → start Reddit catalog
  ///   `'reddit:<sub>:<tok>'` → Reddit pagination
  ///   `'xml2:N'`             → XML2 dump at index N
  ///
  /// Reddit fetch + portal extract + paste deep-links run in Rust
  /// (`iptv_reddit_catalog_json` action `scrape_page`).
  static Future<ScrapePage> scrapeCatalogPage({
    int maxResults = 50,
    String? after,
    CatalogSource? source,
  }) async {
    if (!AccountFeatures.instance.isIptvScrapeEnabled) {
      debugPrint('[Catalog] iptvScrape feature disabled - skipping scrape');
      return const ScrapePage(portals: [], nextAfter: null);
    }
    if (!_xml2ScrapeEnabled) {
      if (source == CatalogSource.works ||
          (after != null && after.startsWith('xml2:'))) {
        debugPrint('[Catalog] XML2 scrape disabled - ignoring works/xml2 cursor');
        return const ScrapePage(portals: [], nextAfter: null);
      }
      if (source == CatalogSource.best || source == null) {
        return _scrapeRedditCatalog(maxResults: maxResults, after: after);
      }
    }

    if (source == CatalogSource.works ||
        (after != null && after.startsWith('xml2:'))) {
      final files = await _getXml2Files();
      final idx = after == null || !after.startsWith('xml2:')
          ? 0
          : int.tryParse(after.substring('xml2:'.length)) ?? 0;
      if (idx < files.length) {
        return _scrapeXml2File(idx, files);
      }
      return const ScrapePage(portals: [], nextAfter: null);
    }

    if (source == CatalogSource.best) {
      return _scrapeRedditCatalog(maxResults: maxResults, after: after);
    }

    final reddit = await _scrapeRedditCatalog(
      maxResults: maxResults,
      after: after,
    );
    if (reddit.hasMore) return reddit;

    if (!_xml2ScrapeEnabled) {
      return ScrapePage(portals: reddit.portals, nextAfter: null);
    }

    final files = await _getXml2Files();
    if (files.isEmpty) {
      return ScrapePage(portals: reddit.portals, nextAfter: null);
    }
    return ScrapePage(portals: reddit.portals, nextAfter: 'xml2:0');
  }

  static Future<ScrapePage> _scrapeXml2File(
      int idx, List<String> files) async {
    final encoded = files[idx];
    final url = '$_xml2Base$encoded';
    final pretty = Uri.decodeComponent(encoded).replaceAll('.txt', '');
    debugPrint('[XML2] [$idx/${files.length}] fetching $pretty');

    String? body;
    try {
      body = await _engineHttpGet(
        url,
        timeout: const Duration(seconds: 25),
        headers: const {
          'User-Agent': _ua,
          'Accept': 'text/plain,*/*',
        },
      );
      if (body == null) {
        debugPrint('[XML2]   fetch failed');
      }
    } catch (e) {
      debugPrint('[XML2]   fetch failed: $e');
    }

    final next = idx + 1 < files.length ? 'xml2:${idx + 1}' : null;
    if (body == null || body.isEmpty) {
      return ScrapePage(portals: const [], nextAfter: next);
    }

    final extracted = await _extractPortalsEngine(body, 'XML2/$pretty');
    debugPrint('[XML2]   $pretty → ${extracted.length} portals');
    return ScrapePage(portals: extracted, nextAfter: next);
  }

  /// Reddit catalog page - fetch, parse, deep-link follow, extract in Rust.
  static Future<ScrapePage> _scrapeRedditCatalog({
    int maxResults = 50,
    String? after,
  }) async {
    debugPrint('[Catalog] scrape_page after=$after max=$maxResults');
    try {
      final raw = await runIptvRedditCatalogJson(
        jsonEncode({
          'action': 'scrape_page',
          'max_results': maxResults,
          if (after != null && after.isNotEmpty) 'after': after,
        }),
      );
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (parsed.containsKey('error')) {
        debugPrint('[Catalog] scrape_page error: ${parsed['error']}');
        return const ScrapePage(portals: [], nextAfter: null);
      }
      final portals = _portalsFromJson(parsed['portals']);
      final nextRaw = parsed['next_after']?.toString();
      final nextAfter =
          (nextRaw == null || nextRaw.isEmpty || nextRaw == 'null')
              ? null
              : nextRaw;
      debugPrint(
          '[Catalog] DONE - ${portals.length} portals next=$nextAfter');
      return ScrapePage(portals: portals, nextAfter: nextAfter);
    } catch (e) {
      debugPrint('[Catalog] scrape_page failed: $e');
      return const ScrapePage(portals: [], nextAfter: null);
    }
  }

  static Future<List<IptvPortal>> _extractPortalsEngine(
      String text, String source) async {
    try {
      final raw = await runIptvRedditCatalogJson(
        jsonEncode({
          'action': 'extract_portals',
          'text': text,
          'source': source,
        }),
      );
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (parsed.containsKey('error')) return const [];
      return _portalsFromJson(parsed['portals']);
    } catch (_) {
      return const [];
    }
  }

  static List<IptvPortal> _portalsFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => IptvPortal.fromJson(Map<String, dynamic>.from(m)))
        .where((p) => p.url.isNotEmpty && p.username.isNotEmpty)
        .toList();
  }
}
