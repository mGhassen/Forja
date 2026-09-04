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
  /// Surfaced for future M3U XMLTV wiring; Stalker uses MAG EPG instead.
  final String? epgUrl;

  bool get ok => error == null;

  static const emptyOk = IptvCatalogFetch(
    categories: [],
    streams: [],
  );
}

class IptvEpgFetchException implements Exception {
  const IptvEpgFetchException();
}

/// Memoize a successful short-EPG load (including empty listings).
/// HTTP/parse failures complete as empty for this call, then drop from
/// [cache] after [retryFailedAfter] so a later build can retry without
/// refetching on every `notifyListeners`.
Future<List<EpgEntry>> rememberIptvEpg(
  Map<String, Future<List<EpgEntry>>> cache,
  String key,
  Future<List<EpgEntry>> Function() load, {
  Duration retryFailedAfter = const Duration(seconds: 15),
  bool Function()? isAlive,
}) {
  final hit = cache[key];
  if (hit != null) return hit;
  late final Future<List<EpgEntry>> future;
  future = () async {
    try {
      return await load();
    } catch (_) {
      unawaited(Future<void>.delayed(retryFailedAfter, () {
        if (isAlive != null && !isAlive()) return;
        if (identical(cache[key], future)) cache.remove(key);
      }));
      return const <EpgEntry>[];
    }
  }();
  cache[key] = future;
  return future;
}

/// Xtream-Codes player_api client. Login + catalog + episodes via Rust.
class IptvClient {
  static const _ua = 'VLC/3.0.20 LibVLC/3.0.20';

  /// Shared `get_short_epg` page size — catalog cards and the long-press
  /// sheet must use the same limit so they share one cache entry.
  static const shortEpgLimit = 8;

  /// Map engine / transport noise to a safe UI string (no request URLs /
  /// credentials). Matches Rust `format_transport_err`.
  static String formatEngineError(Object? raw) {
    final s = raw?.toString().trim() ?? '';
    if (s.isEmpty) return 'Could not load catalog';
    final lower = s.toLowerCase();
    if (lower.contains('auth_failed')) {
      return 'Login failed — check username and password';
    }
    if (lower.contains('error sending request') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('dns') ||
        lower.contains('network is unreachable') ||
        lower.contains('certificate') ||
        lower.contains('tls') ||
        lower.contains('ssl') ||
        lower.contains('player_api') ||
        s.contains('://') ||
        lower.contains('could not reach portal')) {
      return 'Could not reach portal — check URL or network';
    }
    if (RegExp(r'^HTTP \d{3}$').hasMatch(s)) {
      return 'Portal returned $s';
    }
    return s;
  }

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
    String? channelId,
    int? limit,
    int? period,
  }) =>
      {
        'action': action,
        'platform': p.platform.wire,
        'url': p.url,
        'username': p.username,
        'password': p.password,
        'timeout_secs': timeoutSecs,
        if (p.userAgent.isNotEmpty) 'user_agent': p.userAgent,
        'section': ?section,
        'category_id': ?categoryId,
        'series_id': ?seriesId,
        if (cmd != null && cmd.isNotEmpty) 'cmd': cmd,
        if (channelId != null && channelId.isNotEmpty) 'channel_id': channelId,
        'limit': ?limit,
        'period': ?period,
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
      {Duration? timeout}) async {
    // M3U login downloads + parses the whole playlist (iptv-org index ≈ 3MB).
    final effective = timeout ??
        (p.platform == IptvPortalPlatform.m3u
            ? const Duration(seconds: 90)
            : const Duration(seconds: 6));
    final root = await _xtreamRequest(_portalBody(
      p,
      action: 'login',
      timeoutSecs: effective.inSeconds.clamp(1, 120),
    ));
    if (root == null) return null;
    final info = root['user_info'];
    if (info is! Map<String, dynamic>) return null;
    return info;
  }

  static Future<VerifiedPortal?> verifyOrNull(IptvPortal p,
      {Duration? timeout}) async {
    final probe = await probePortal(p, timeout: timeout);
    if (!probe.alive) return null;
    return VerifiedPortal.fromProbe(p, probe);
  }

  /// Login probe that keeps structured auth failures (status / message / server).
  static Future<PortalProbeResult> probePortal(
    IptvPortal p, {
    Duration? timeout,
  }) async {
    final effective = timeout ??
        (p.platform == IptvPortalPlatform.m3u
            ? const Duration(seconds: 90)
            : const Duration(seconds: 6));
    final root = await _xtreamRequestRaw(_portalBody(
      p,
      action: 'login',
      timeoutSecs: effective.inSeconds.clamp(1, 120),
    ));
    if (root == null) {
      return const PortalProbeResult(
        alive: false,
        errorKind: 'transport',
      );
    }

    final err = root['error']?.toString() ?? '';
    final infoRaw = root['user_info'];
    final info = infoRaw is Map<String, dynamic> ? infoRaw : null;
    final server = PortalServerInfo.fromJson(
      root['server_info'] is Map<String, dynamic>
          ? root['server_info'] as Map<String, dynamic>
          : null,
    );

    String field(Map<String, dynamic>? m, String key) =>
        m?[key]?.toString() ?? '';

    if (err.isNotEmpty) {
      final lower = err.toLowerCase();
      final isAuth = lower.contains('auth_failed');
      final status = root['status']?.toString() ?? field(info, 'status');
      final message = root['message']?.toString() ?? field(info, 'message');
      return PortalProbeResult(
        alive: false,
        accountStatus: status,
        message: message,
        errorKind: isAuth ? 'auth' : 'transport',
        accountName: field(info, 'username'),
        expiry: IptvPortalExpiry.format(field(info, 'exp_date')),
        maxConnections: field(info, 'max_connections'),
        activeConnections: field(info, 'active_cons'),
        server: server,
      );
    }

    if (info == null) {
      return PortalProbeResult(
        alive: false,
        errorKind: 'transport',
        server: server,
      );
    }

    return PortalProbeResult(
      alive: true,
      accountStatus: field(info, 'status').isNotEmpty
          ? field(info, 'status')
          : 'Active',
      message: field(info, 'message'),
      accountName: field(info, 'username').isNotEmpty
          ? field(info, 'username')
          : p.username,
      expiry: IptvPortalExpiry.format(field(info, 'exp_date')),
      maxConnections:
          field(info, 'max_connections').isNotEmpty
              ? field(info, 'max_connections')
              : '1',
      activeConnections:
          field(info, 'active_cons').isNotEmpty
              ? field(info, 'active_cons')
              : '0',
      server: server,
    );
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
        error: formatEngineError(root['error']),
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

  /// Xtream encodes `title` and `description` as base64 strings.
  static String _decodeXtreamField(String s) {
    return RustLib.instance.decodeXtreamText(s);
  }

  /// Parse Xtream / Mag EPG times into **device-local** [DateTime].
  ///
  /// Unix epochs (`start_timestamp`) are UTC instants → [DateTime.toLocal].
  /// Naive wall-clock strings are treated as already regional/local (Mag
  /// cookie + `set_timezone` match the device; Xtream prefers timestamps).
  /// Strings with `Z` / explicit offset are absolute → local.
  @visibleForTesting
  static DateTime? parseEpgTs(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    // Xtream/Mag send unix-seconds ("start_timestamp") and ISO-ish
    // strings ("start": "2026-04-25 19:00:00"). Prefer epochs.
    final secs = int.tryParse(s);
    if (secs != null && secs > 1000000000) {
      final ms = secs > 1000000000000 ? secs : secs * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    try {
      final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
      final parsed = DateTime.parse(normalized);
      // Offset / Z → UTC instant in Dart; naive → local wall-clock.
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseEpgTs(dynamic v) => parseEpgTs(v);

  static List<EpgEntry> _parseEpgListings(String text) {
    final root = json.decode(text);
    final List arr = root is Map<String, dynamic>
        ? (root['epg_listings'] as List? ?? const [])
        : (root is List ? root : const []);
    return _parseEpgListingsList(arr);
  }

  static List<EpgEntry> _parseEpgListingsList(List arr) {
    final out = <EpgEntry>[];
    for (final e in arr) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final start = _parseEpgTs(m['start_timestamp']) ??
          _parseEpgTs(m['start']) ??
          _parseEpgTs(m['time']) ??
          _parseEpgTs(m['from']);
      final stop = _parseEpgTs(m['stop_timestamp']) ??
          _parseEpgTs(m['end']) ??
          _parseEpgTs(m['stop']) ??
          _parseEpgTs(m['time_to']) ??
          _parseEpgTs(m['to']);
      if (start == null || stop == null) continue;
      final title = m['title']?.toString() ??
          m['name']?.toString() ??
          m['progname']?.toString() ??
          '';
      final description = m['description']?.toString() ??
          m['descr']?.toString() ??
          m['desc']?.toString() ??
          '';
      out.add(EpgEntry(
        title: _decodeXtreamField(title),
        description: _decodeXtreamField(description),
        start: start,
        stop: stop,
      ));
    }
    out.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return b.stop.compareTo(a.stop);
    });
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

  static Future<List<EpgEntry>?> _shortEpgOnce(
    IptvPortal p,
    String streamId, {
    required int limit,
    required Duration timeout,
  }) async {
    if (streamId.isEmpty) return const [];
    if (p.platform == IptvPortalPlatform.stalker) {
      return _stalkerEpgOnce(p, streamId, limit: limit, timeout: timeout);
    }
    final url = '${p.url}/player_api.php?username=${_enc(p.username)}'
        '&password=${_enc(p.password)}'
        '&action=get_short_epg&stream_id=${_enc(streamId)}&limit=$limit';
    final text = await _httpGet(url, timeout: timeout);
    if (text == null) return null;
    try {
      return _parseEpgListings(text);
    } catch (_) {
      return null;
    }
  }

  /// Stalker ITV channel id for EPG — never the bare create_link `cmd` URL.
  ///
  /// Prefers [epgChannelId]; else a pure-numeric [streamId]; else `stream=`
  /// (or trailing digits) embedded in Xtream-UI-style Stalker `cmd` URLs so
  /// catalogs cached before `epg_channel_id` was filled still resolve.
  static String stalkerChannelId({
    required String streamId,
    required String epgChannelId,
  }) {
    final epg = epgChannelId.trim();
    if (epg.isNotEmpty) return epg;
    final id = streamId.trim();
    if (id.isEmpty) return '';
    if (RegExp(r'^\d+$').hasMatch(id)) return id;
    final streamParam = RegExp(r'[?&]stream=(\d+)').firstMatch(id)?.group(1);
    if (streamParam != null && streamParam.isNotEmpty) return streamParam;
    final digits = RegExp(r'(\d{3,})').allMatches(id).map((m) => m.group(1)!);
    if (digits.isNotEmpty) return digits.last;
    return '';
  }

  static Future<List<EpgEntry>?> _stalkerEpgOnce(
    IptvPortal p,
    String channelId, {
    required int limit,
    required Duration timeout,
  }) async {
    if (channelId.isEmpty) return const [];
    final root = await _xtreamRequestRaw(_portalBody(
      p,
      action: 'epg',
      timeoutSecs: timeout.inSeconds.clamp(1, 60),
      channelId: channelId,
      limit: limit,
    ));
    if (root == null || root.containsKey('error')) return null;
    try {
      return _parseEpgListings(jsonEncode(root));
    } catch (_) {
      return null;
    }
  }

  /// Fetches the next [limit] EPG programmes for [streamId] via Xtream's
  /// `get_short_epg` or Stalker `get_short_epg` / `get_epg_info`. Empty list
  /// = the panel has no listings.
  ///
  /// HTTP / parse failures retry once, then throw so callers can avoid
  /// caching a sticky miss. Xtream encodes `title` and `description` as
  /// base64 strings.
  static Future<List<EpgEntry>> shortEpg(
    IptvPortal p,
    String streamId, {
    int limit = shortEpgLimit,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (p.platform == IptvPortalPlatform.m3u) return const [];
    final first = await _shortEpgOnce(
      p,
      streamId,
      limit: limit,
      timeout: timeout,
    );
    if (first != null) return first;
    final second = await _shortEpgOnce(
      p,
      streamId,
      limit: limit,
      timeout: timeout,
    );
    if (second != null) return second;
    throw const IptvEpgFetchException();
  }

  /// `get_short_epg` by stream id, then `epg_channel_id` if that is empty.
  /// Stalker prefers numeric `epg_channel_id` (ITV `ch_id`) over create_link cmd.
  static Future<List<EpgEntry>> shortEpgForStream(
    IptvPortal p, {
    required String streamId,
    required String epgChannelId,
    int limit = shortEpgLimit,
  }) async {
    if (p.platform == IptvPortalPlatform.m3u) return const [];
    if (p.platform == IptvPortalPlatform.stalker) {
      final ch = stalkerChannelId(
        streamId: streamId,
        epgChannelId: epgChannelId,
      );
      if (ch.isEmpty) return const [];
      return shortEpg(p, ch, limit: limit);
    }
    Object? lastFail;
    if (streamId.isNotEmpty) {
      try {
        final rows = await shortEpg(p, streamId, limit: limit);
        if (rows.isNotEmpty) return rows;
        if (epgChannelId.isEmpty || epgChannelId == streamId) return rows;
      } catch (e) {
        lastFail = e;
      }
    }
    if (epgChannelId.isNotEmpty && epgChannelId != streamId) {
      return shortEpg(p, epgChannelId, limit: limit);
    }
    if (lastFail != null) throw lastFail;
    return const [];
  }

  /// Mag `get_epg_info&period=` raw channel→rows map (parsed per channel on demand).
  static final Map<String, Future<Map<String, List>>> _stalkerBulkRaw = {};

  /// Completed Mag dumps (same keys as [_stalkerBulkRaw]).
  static final Map<String, Map<String, List>> _stalkerBulkRawDone = {};

  /// Parsed channel listings carved from [_stalkerBulkRawDone].
  static final Map<String, Map<String, List<EpgEntry>>> _stalkerBulkParsed = {};

  static void clearStalkerEpgCache() {
    _stalkerBulkRaw.clear();
    _stalkerBulkRawDone.clear();
    _stalkerBulkParsed.clear();
  }

  static String _stalkerBulkKey(IptvPortal p) =>
      '${p.platform.wire}|${p.url}|${p.username}';

  /// True once the Mag period dump finished (may be empty).
  static bool stalkerBulkReady(IptvPortal p) =>
      _stalkerBulkRawDone.containsKey(_stalkerBulkKey(p));

  /// Kick the Mag period dump without awaiting guide paint.
  static Future<void> primeStalkerGuideEpg(
    IptvPortal p, {
    Duration timeout = const Duration(seconds: 90),
  }) =>
      _stalkerBulkRawMap(p, timeout: timeout).then((_) {});

  static Future<Map<String, List>> _stalkerBulkRawMap(
    IptvPortal p, {
    Duration timeout = const Duration(seconds: 90),
  }) {
    final key = _stalkerBulkKey(p);
    return _stalkerBulkRaw.putIfAbsent(key, () async {
      final root = await _xtreamRequestRaw(_portalBody(
        p,
        action: 'epg_bulk',
        timeoutSecs: timeout.inSeconds.clamp(15, 180),
        period: 48,
      ));
      final out = <String, List>{};
      if (root != null && !root.containsKey('error')) {
        final data = root['data'];
        if (data is Map) {
          for (final e in data.entries) {
            final rows = e.value;
            if (rows is List && rows.isNotEmpty) {
              out[e.key.toString()] = rows;
            }
          }
        } else {
          final channels = root['channels'];
          if (channels is Map) {
            for (final e in channels.entries) {
              final rows = e.value;
              if (rows is List && rows.isNotEmpty) {
                out[e.key.toString()] = rows;
              }
            }
          }
        }
      }
      _stalkerBulkRawDone[key] = out;
      _stalkerBulkParsed[key] = {};
      return out;
    });
  }

  static List<EpgEntry> _stalkerBulkListings(IptvPortal p, String ch) {
    final key = _stalkerBulkKey(p);
    final parsed = _stalkerBulkParsed[key];
    final map = _stalkerBulkRawDone[key];
    if (parsed == null || map == null) return const [];
    final hit = parsed[ch];
    if (hit != null) return hit;
    final rows = map[ch];
    if (rows == null || rows.isEmpty) {
      parsed[ch] = const [];
      return const [];
    }
    final listings = _parseEpgListingsList(rows);
    parsed[ch] = listings;
    return listings;
  }

  /// Full EPG table for one live stream (`get_simple_data_table` on Xtream,
  /// Stalker: short Mag EPG immediately, Mag period dump when ready).
  /// Optionally keep only programmes overlapping `[windowStart, windowEnd]`.
  static Future<List<EpgEntry>> simpleDataTable(
    IptvPortal p,
    String streamId, {
    DateTime? windowStart,
    DateTime? windowEnd,
    Duration timeout = const Duration(seconds: 18),
    String epgChannelId = '',
  }) async {
    if (p.platform == IptvPortalPlatform.m3u) return const [];
    if (p.platform == IptvPortalPlatform.stalker) {
      final ch = stalkerChannelId(
        streamId: streamId,
        epgChannelId: epgChannelId,
      );
      if (ch.isEmpty) return const [];
      List<EpgEntry> slice(List<EpgEntry> all) {
        if (windowStart == null || windowEnd == null) return all;
        return all
            .where(
              (e) => e.stop.isAfter(windowStart) && e.start.isBefore(windowEnd),
            )
            .toList(growable: false);
      }

      // Bulk already warm → use it (longer timeline than short EPG).
      if (stalkerBulkReady(p)) {
        final bulk = _stalkerBulkListings(p, ch);
        if (bulk.isNotEmpty) return slice(bulk);
      }

      // Paint fast with short EPG; host primes bulk separately then refreshes.
      try {
        final short = await shortEpg(p, ch, limit: shortEpgLimit, timeout: timeout);
        return slice(short);
      } catch (_) {
        return const [];
      }
    }
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
