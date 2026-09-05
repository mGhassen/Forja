part of '../live_sports_hub_page.dart';


/// Host IPTV sports match API (RFC-073). Logic lives in this library part;
/// call sites use [_IptvSportsMatchService] instead of private helpers.
abstract final class _IptvSportsMatchService {
  _IptvSportsMatchService._();

  static Future<List<IptvPlaySource>> resolveStreams(
    _StreamedMatch match, {
    void Function(List<IptvPlaySource> batch)? onPartial,
    bool force = false,
  }) =>
      _resolveIptvSportsStreams(match, onPartial: onPartial, force: force);

  static Future<_LiveBroadcastHints> broadcastHintsFor(_StreamedMatch match) =>
      _broadcastHintsForMatch(match);

  static Future<List<Map<String, dynamic>>> fetchEspnGames() =>
      _fetchEspnSportMatchGames();

  static void invalidateBroadcastCaches() => invalidateLiveBroadcastCaches();

  static Map<String, dynamic> sportMatchGameForResolve(
    _StreamedMatch match,
    List<Map<String, dynamic>> espnGames,
  ) =>
      _sportMatchGameForIptvResolve(match, espnGames);

  static Map<String, dynamic>? findEspnGame(
    _StreamedMatch match,
    List<Map<String, dynamic>> espnGames,
  ) =>
      _findEspnGameForMatch(match, espnGames);

  static _StreamedMatch copyMatch(
    _StreamedMatch m, {
    Map<String, dynamic>? sportMatchGame,
    String? homeTeam,
    String? awayTeam,
    String? homeBadge,
    String? awayBadge,
    bool? airing,
  }) =>
      _copyStreamedMatch(
        m,
        sportMatchGame: sportMatchGame,
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        homeBadge: homeBadge,
        awayBadge: awayBadge,
        airing: airing,
      );

  static ({List<_StreamedMatch> streamed, List<Map<String, dynamic>> espnGames})
      mergeWithEspn(
    List<_StreamedMatch> streamed,
    List<Map<String, dynamic>> espnGames, {
    bool appendUnmatched = true,
  }) =>
      _mergeStreamedWithEspn(
        streamed,
        espnGames,
        appendUnmatched: appendUnmatched,
      );
}

// My IPTV catalog = All (PPV/Streamed/CDN) merged with ESPN (Sportio schedule).

Future<List<Map<String, dynamic>>> _fetchEspnSportMatchGames() async {
  try {
    final config = await LiveMatchesIptvSportsConfig.load();
    final leagues = config.leagues.isEmpty
        ? LiveMatchesIptvSportsConfig.allLeagues
        : config.leagues;
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final raw = await runLiveMatchesFetchJson(
      jsonEncode({
        'action': 'sport_match_games',
        'leagues': leagues,
        'date': date,
      }),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) {
      debugPrint('[LiveMatches] ESPN games error: ${parsed['error']}');
      return [];
    }
    final list = parsed['items'] as List? ?? [];
    return [
      for (final item in list)
        if (item is Map)
          Map<String, dynamic>.from(item),
    ];
  } catch (e) {
    debugPrint('[LiveMatches] ESPN games fetch failed: $e');
    return [];
  }
}

Map<String, dynamic> _espnGamePayload(Map<String, dynamic> g) {
  return {
    'id': (g['id'] ?? '').toString(),
    'title': (g['title'] ?? g['name'] ?? '').toString(),
    'sport': (g['sport'] ?? '').toString(),
    'category': (g['category'] ?? g['sport'] ?? '').toString(),
    'homeTeam': (g['homeTeam'] ?? '').toString(),
    'awayTeam': (g['awayTeam'] ?? '').toString(),
    'homeNick': (g['homeNick'] ?? '').toString(),
    'awayNick': (g['awayNick'] ?? '').toString(),
    'homeAbbr': (g['homeAbbr'] ?? '').toString(),
    'awayAbbr': (g['awayAbbr'] ?? '').toString(),
    'dateMs': (g['dateMs'] as num?)?.toInt() ?? 0,
    'date': (g['date'] ?? '').toString(),
  };
}

_StreamedMatch _espnGameToStreamedMatch(Map<String, dynamic> g) {
  final home = (g['homeTeam'] ?? '').toString().trim();
  final away = (g['awayTeam'] ?? '').toString().trim();
  final title = (g['title'] ?? g['name'] ?? '').toString().trim();
  final live = g['live'] == true;
  return _StreamedMatch(
    id: 'espn:${(g['id'] ?? '').toString()}',
    title: title.isNotEmpty
        ? title
        : (home.isNotEmpty && away.isNotEmpty ? '$away vs $home' : 'ESPN'),
    category: (g['category'] ?? g['sport'] ?? 'other').toString(),
    dateMs: (g['dateMs'] as num?)?.toInt() ?? 0,
    poster: (g['poster'] ?? g['homeLogo'] ?? g['awayLogo'] ?? '').toString(),
    popular: false,
    airing: live,
    homeTeam: home.isEmpty ? null : home,
    awayTeam: away.isEmpty ? null : away,
    homeBadge: (g['homeLogo'] ?? '').toString(),
    awayBadge: (g['awayLogo'] ?? '').toString(),
    sources: const [],
    catalog: 'iptv_sports',
    sportMatchGame: _espnGamePayload(g),
  );
}

_StreamedMatch _copyStreamedMatch(
  _StreamedMatch m, {
  Map<String, dynamic>? sportMatchGame,
  String? homeTeam,
  String? awayTeam,
  String? homeBadge,
  String? awayBadge,
  bool? airing,
}) {
  return _StreamedMatch(
    id: m.id,
    title: m.title,
    category: m.category,
    dateMs: m.dateMs,
    poster: m.poster,
    popular: m.popular,
    airing: airing ?? m.airing,
    viewers: m.viewers,
    homeTeam: homeTeam ?? m.homeTeam,
    homeBadge: homeBadge ?? m.homeBadge,
    awayTeam: awayTeam ?? m.awayTeam,
    awayBadge: awayBadge ?? m.awayBadge,
    sources: m.sources,
    inlineStreams: m.inlineStreams,
    catalog: m.catalog,
    stremioBaseUrl: m.stremioBaseUrl,
    stremioType: m.stremioType,
    stremioAddonName: m.stremioAddonName,
    sportMatchGame: sportMatchGame ?? m.sportMatchGame,
    livePluginId: m.livePluginId,
  );
}

bool _kickoffClose(int aMs, int bMs) {
  if (aMs <= 0 || bMs <= 0) return true;
  return (aMs - bMs).abs() <= const Duration(minutes: 45).inMilliseconds;
}

bool _kickoffLoose(int aMs, int bMs) {
  if (aMs <= 0 || bMs <= 0) return true;
  if (_kickoffClose(aMs, bMs)) return true;
  if ((aMs - bMs).abs() <= const Duration(hours: 6).inMilliseconds) {
    return true;
  }
  final a = DateTime.fromMillisecondsSinceEpoch(aMs).toLocal();
  final b = DateTime.fromMillisecondsSinceEpoch(bMs).toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

List<String> _broadcastChannelsFromGame(Map<String, dynamic>? game) {
  final raw = game?['broadcastChannels'];
  if (raw is! List) return const [];
  return [
    for (final c in raw)
      if (c.toString().trim().isNotEmpty) c.toString().trim(),
  ];
}

Map<String, dynamic> _sportMatchGameForIptvResolve(
  _StreamedMatch match,
  List<Map<String, dynamic>> espnGames,
) {
  final existing = match.sportMatchGame != null
      ? Map<String, dynamic>.from(match.sportMatchGame!)
      : _sportMatchGamePayloadFromMatch(match);
  final channels = _broadcastChannelsFromGame(existing);
  final espn = _findEspnGameForMatch(match, espnGames);
  if (espn == null) return existing;
  final out = Map<String, dynamic>.from(espn);
  if (channels.isNotEmpty) {
    out['broadcastChannels'] = channels;
  }
  return out;
}

bool _teamPairsMatch(String? home, String? away, Map<String, dynamic> espn) {
  final epair = _teamPairKey(
    (espn['homeTeam'] ?? '').toString(),
    (espn['awayTeam'] ?? '').toString(),
  );
  final pair = _teamPairKey(home, away);
  if (pair != null && epair != null && pair == epair) return true;

  final nickPair = _teamPairKey(
    (espn['homeNick'] ?? '').toString(),
    (espn['awayNick'] ?? '').toString(),
  );
  if (pair != null && nickPair != null && pair == nickPair) return true;

  // Catalog title parse vs ESPN full / nick.
  return false;
}

bool _sameCatalogEventAsEspn({
  required String title,
  required String? homeTeam,
  required String? awayTeam,
  required int dateMs,
  required Map<String, dynamic> espn,
}) {
  final espnMs = (espn['dateMs'] as num?)?.toInt() ?? 0;
  if (!_kickoffClose(dateMs, espnMs)) return false;

  final (home, away) = resolveLiveMatchTeams(
    homeTeam: homeTeam,
    awayTeam: awayTeam,
    title: title,
  );
  if (_teamPairsMatch(home, away, espn)) return true;

  final espnTitle = _matchTextKey((espn['title'] ?? espn['name'] ?? '').toString());
  final catalogTitle = _matchTextKey(title);
  return espnTitle.isNotEmpty &&
      catalogTitle.isNotEmpty &&
      espnTitle == catalogTitle;
}

/// Enrich streamed rows with ESPN teams; optionally append ESPN-only games.
({List<_StreamedMatch> streamed, List<Map<String, dynamic>> espnGames})
    _mergeStreamedWithEspn(
  List<_StreamedMatch> streamed,
  List<Map<String, dynamic>> espnGames, {
  bool appendUnmatched = true,
}) {
  final remaining = <Map<String, dynamic>>[];
  final byPair = <String, Map<String, dynamic>>{};
  final byTitle = <String, Map<String, dynamic>>{};
  for (final g in espnGames) {
    remaining.add(g);
    final home = (g['homeTeam'] ?? '').toString();
    final away = (g['awayTeam'] ?? '').toString();
    final pair = _teamPairKey(home, away);
    if (pair != null) byPair.putIfAbsent(pair, () => g);
    final nickPair = _teamPairKey(
      (g['homeNick'] ?? '').toString(),
      (g['awayNick'] ?? '').toString(),
    );
    if (nickPair != null) byPair.putIfAbsent(nickPair, () => g);
    final titleKey = _matchTextKey((g['title'] ?? g['name'] ?? '').toString());
    if (titleKey.isNotEmpty) byTitle.putIfAbsent(titleKey, () => g);
  }

  Map<String, dynamic>? matchEspnForRow(_StreamedMatch m) {
    final (home, away) = resolveLiveMatchTeams(
      homeTeam: m.homeTeam,
      awayTeam: m.awayTeam,
      title: m.title,
    );
    final pair = _teamPairKey(home, away);
    Map<String, dynamic>? g;
    if (pair != null) g = byPair.remove(pair);
    if (g == null) {
      final titleKey = _matchTextKey(m.title);
      if (titleKey.isNotEmpty) g = byTitle.remove(titleKey);
    }
    if (g == null) {
      final idx = remaining.indexWhere(
        (eg) => _sameCatalogEventAsEspn(
          title: m.title,
          homeTeam: m.homeTeam,
          awayTeam: m.awayTeam,
          dateMs: m.dateMs,
          espn: eg,
        ),
      );
      if (idx >= 0) g = remaining.removeAt(idx);
    } else {
      remaining.remove(g);
    }
    return g;
  }

  final out = <_StreamedMatch>[];
  for (final m in streamed) {
    final g = matchEspnForRow(m);
    if (g == null) {
      out.add(m);
      continue;
    }
    final payload = _espnGamePayload(g);
    out.add(
      _copyStreamedMatch(
        m,
        sportMatchGame: payload,
        homeTeam: (payload['homeTeam'] as String?)?.trim().isNotEmpty == true
            ? payload['homeTeam'] as String
            : m.homeTeam,
        awayTeam: (payload['awayTeam'] as String?)?.trim().isNotEmpty == true
            ? payload['awayTeam'] as String
            : m.awayTeam,
        homeBadge: () {
          final logo = (g['homeLogo'] ?? '').toString();
          return logo.isNotEmpty ? logo : m.homeBadge;
        }(),
        awayBadge: () {
          final logo = (g['awayLogo'] ?? '').toString();
          return logo.isNotEmpty ? logo : m.awayBadge;
        }(),
        airing: g['live'] == true ? true : m.airing,
      ),
    );
  }
  if (appendUnmatched) {
    out.addAll(remaining.map(_espnGameToStreamedMatch));
  }
  return (streamed: out, espnGames: espnGames);
}

Map<String, dynamic>? _findEspnGameForMatch(
  _StreamedMatch match,
  List<Map<String, dynamic>> espnGames,
) {
  if (match.sportMatchGame != null) {
    return Map<String, dynamic>.from(match.sportMatchGame!);
  }
  for (final g in espnGames) {
    if (_sameCatalogEventAsEspn(
      title: match.title,
      homeTeam: match.homeTeam,
      awayTeam: match.awayTeam,
      dateMs: match.dateMs,
      espn: g,
    )) {
      return _espnGamePayload(g);
    }
  }
  return null;
}

bool _broadcastTokenMatches(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  if (a.length >= 3 && b.contains(a)) return true;
  if (b.length >= 3 && a.contains(b)) return true;
  if (a.length >= 4 && b.length >= 4) {
    final prefixLen = a.length < b.length ? a.length : b.length;
    if (prefixLen >= 4 && a.substring(0, 4) == b.substring(0, 4)) {
      return true;
    }
  }
  return false;
}

Set<String> _broadcastTeamTokens(String team) {
  final key = _matchTextKey(team);
  if (key.isEmpty) return const {};
  return {
    for (final token in key.split(' '))
      if (token.length >= 3) token,
  };
}

bool _broadcastTeamSideMatches(String a, String b) {
  final left = _matchTextKey(a);
  final right = _matchTextKey(b);
  if (left.isNotEmpty && left == right) return true;

  final ta = _broadcastTeamTokens(a);
  final tb = _broadcastTeamTokens(b);
  if (ta.isEmpty || tb.isEmpty) return false;

  var hits = 0;
  for (final x in ta) {
    for (final y in tb) {
      if (_broadcastTokenMatches(x, y)) {
        hits++;
        break;
      }
    }
  }
  final needed = ta.length <= 2 || tb.length <= 2 ? 1 : 2;
  return hits >= needed;
}

bool _broadcastTitleTokenOverlap(String leftTitle, String rightTitle) {
  final left = _matchTextKey(leftTitle);
  final right = _matchTextKey(rightTitle);
  if (left.isEmpty || right.isEmpty) return false;
  if (left == right) return true;

  final lt = left.split(' ').where((t) => t.length >= 4).toSet();
  final rt = right.split(' ').where((t) => t.length >= 4).toSet();
  if (lt.isEmpty || rt.isEmpty) return false;
  final overlap = lt.intersection(rt).length;
  return overlap >= 2 || (overlap >= 1 && lt.length <= 2 && rt.length <= 2);
}

bool _sameCatalogEventAsBroadcast({
  required String title,
  required String? homeTeam,
  required String? awayTeam,
  required int dateMs,
  required Map<String, dynamic> broadcastGame,
}) {
  final broadcastMs = (broadcastGame['dateMs'] as num?)?.toInt() ?? 0;
  if (!_kickoffLoose(dateMs, broadcastMs)) return false;

  final (home, away) = resolveLiveMatchTeams(
    homeTeam: homeTeam,
    awayTeam: awayTeam,
    title: title,
  );
  if (_teamPairsMatch(home, away, broadcastGame)) return true;

  final bHome = (broadcastGame['homeTeam'] ?? '').toString().trim();
  final bAway = (broadcastGame['awayTeam'] ?? '').toString().trim();
  if (home.isNotEmpty &&
      away.isNotEmpty &&
      bHome.isNotEmpty &&
      bAway.isNotEmpty) {
    if (_broadcastTeamSideMatches(home, bHome) &&
        _broadcastTeamSideMatches(away, bAway)) {
      return true;
    }
    if (_broadcastTeamSideMatches(home, bAway) &&
        _broadcastTeamSideMatches(away, bHome)) {
      return true;
    }
  }

  final broadcastTitle =
      (broadcastGame['title'] ?? broadcastGame['name'] ?? '').toString();
  if (_broadcastTitleTokenOverlap(title, broadcastTitle)) return true;

  final broadcastTitleKey = _matchTextKey(broadcastTitle);
  final catalogTitle = _matchTextKey(title);
  return broadcastTitleKey.isNotEmpty &&
      catalogTitle.isNotEmpty &&
      broadcastTitleKey == catalogTitle;
}

/// Matched My IPTV channels for a match — reused for [_iptvSportsStreamsCacheTtl].
const _iptvSportsStreamsCacheTtl = Duration(minutes: 30);
const _iptvSportsEpgBatchSize = 12;
const _liveBroadcastCacheTtl = Duration(minutes: 30);

void invalidateLiveBroadcastCaches() {
  _liveBroadcastCacheExpiry = null;
  _liveBroadcastIndex = [];
  _liveBroadcastIndexedSources.clear();
  _liveBroadcastInFlight = null;
  _liveBroadcastPluginRowsCache.clear();
  _liveBroadcastPluginInflight.clear();
}

void invalidateIptvSportsStreamsCache() {
  _iptvSportsStreamsCache.clear();
  _iptvSportsStreamsInFlight.clear();
}

DateTime? _liveBroadcastCacheExpiry;
List<Map<String, dynamic>> _liveBroadcastIndex = [];
final Set<String> _liveBroadcastIndexedSources = {};
Future<List<Map<String, dynamic>>>? _liveBroadcastInFlight;

class _LiveBroadcastPluginCacheEntry {
  const _LiveBroadcastPluginCacheEntry({
    required this.expiresAt,
    required this.rows,
  });

  final DateTime expiresAt;
  final List<Map<String, dynamic>> rows;
}

final Map<String, _LiveBroadcastPluginCacheEntry> _liveBroadcastPluginRowsCache =
    {};
final Map<String, Future<List<Map<String, dynamic>>>> _liveBroadcastPluginInflight =
    {};

String _broadcastIndexKey(Map<String, dynamic> game) {
  return [
    (game['title'] ?? '').toString().toLowerCase(),
    '${game['dateMs'] ?? ''}',
    (game['category'] ?? '').toString().toLowerCase(),
  ].join('|');
}

Map<String, List<String>> _broadcastBySourceMap(Map<String, dynamic> game) {
  final raw = game['broadcastBySource'];
  if (raw is! Map) return {};
  final out = <String, List<String>>{};
  for (final entry in raw.entries) {
    final list = entry.value;
    if (list is! List) continue;
    out[entry.key.toString()] = [
      for (final c in list)
        if (c.toString().trim().isNotEmpty) c.toString().trim(),
    ];
  }
  return out;
}

Map<String, dynamic> _stampBroadcastSource(
  Map<String, dynamic> game, {
  required String sourceKey,
}) {
  final channels = _broadcastChannelsFromGame(game);
  if (channels.isEmpty || sourceKey.trim().isEmpty) return game;
  return {
    ...game,
    'broadcastChannels': channels,
    'broadcastBySource': {sourceKey: channels},
  };
}

Map<String, dynamic> _mergeBroadcastGames(
  Map<String, dynamic> existing,
  Map<String, dynamic> incoming, {
  String? sourceKey,
}) {
  final channels = <String>{
    ..._broadcastChannelsFromGame(existing),
    ..._broadcastChannelsFromGame(incoming),
  };
  final bySource = _broadcastBySourceMap(existing);
  if (sourceKey != null && sourceKey.trim().isNotEmpty) {
    final key = sourceKey.trim();
    final incomingChannels = _broadcastChannelsFromGame(incoming);
    if (incomingChannels.isNotEmpty) {
      final list = List<String>.from(bySource[key] ?? const []);
      for (final name in incomingChannels) {
        if (!list.contains(name)) list.add(name);
      }
      bySource[key] = list;
    }
  } else {
    for (final entry in _broadcastBySourceMap(incoming).entries) {
      final list = List<String>.from(bySource[entry.key] ?? const []);
      for (final name in entry.value) {
        if (!list.contains(name)) list.add(name);
      }
      bySource[entry.key] = list;
    }
  }
  return {
    ...existing,
    ...incoming,
    if (channels.isNotEmpty) 'broadcastChannels': channels.toList(),
    if (bySource.isNotEmpty) 'broadcastBySource': bySource,
  };
}

class _LiveBroadcastHints {
  const _LiveBroadcastHints({
    this.liveOnSat = const [],
    this.liveSoccerTv = const [],
  });

  final List<String> liveOnSat;
  final List<String> liveSoccerTv;

  bool get isEmpty => liveOnSat.isEmpty && liveSoccerTv.isEmpty;
}

void _logBroadcastHints(String message) {
  debugPrint('[LiveMatches] broadcast hints: $message');
}

List<String> _broadcastSearchTokens({
  required String title,
  String? homeTeam,
  String? awayTeam,
}) {
  final (home, away) = resolveLiveMatchTeams(
    homeTeam: homeTeam,
    awayTeam: awayTeam,
    title: title,
  );
  return {
    ..._broadcastTeamTokens(home),
    ..._broadcastTeamTokens(away),
    ..._matchTextKey(title).split(' ').where((t) => t.length >= 4),
  }.toList();
}

void _logBroadcastNearMisses({
  required String pluginId,
  required List<Map<String, dynamic>> rows,
  required List<String> searchTokens,
  required int kickoffMs,
}) {
  if (searchTokens.isEmpty || rows.isEmpty) return;
  final samples = <String>[];
  for (final row in rows) {
    if (row['sportMatchGame'] is! Map) continue;
    final game = Map<String, dynamic>.from(row['sportMatchGame'] as Map);
    final gameTitle = (game['title'] ?? row['title'] ?? '').toString();
    final hay = _matchTextKey(gameTitle);
    if (searchTokens.any(hay.contains)) {
      final channels = _broadcastChannelsFromCatalogRow(row);
      final gameMs = (game['dateMs'] as num?)?.toInt() ?? 0;
      samples.add(
        '"$gameTitle" channels=${channels.length} '
        'kickoff=$gameMs delta=${kickoffMs > 0 && gameMs > 0 ? ((gameMs - kickoffMs) / 60000).round() : "?"}m',
      );
    }
    if (samples.length >= 3) break;
  }
  if (samples.isEmpty) return;
  _logBroadcastHints(
    '$pluginId near-miss titles (token overlap, no fixture match): '
    '${samples.join(" | ")}',
  );
}

List<String> _broadcastChannelsFromCatalogRow(Map<String, dynamic> row) {
  if (row['sportMatchGame'] is Map) {
    final fromGame = _broadcastChannelsFromGame(
      Map<String, dynamic>.from(row['sportMatchGame'] as Map),
    );
    if (fromGame.isNotEmpty) return fromGame;
  }
  return _broadcastChannelsFromGame(row);
}

int? _broadcastEventIdFromGame(Map<String, dynamic>? game) {
  if (game == null) return null;
  final raw =
      '${game['id'] ?? ''}'.trim().replaceFirst(RegExp(r'^lstv_'), '');
  if (raw.isEmpty) return null;
  return int.tryParse(raw);
}

Future<List<String>> _liveSoccerTvBroadcastOnDemand({
  required EnginePlugin plugin,
  required String home,
  required String away,
  int? eventId,
  int? dateMs,
  String matchPath = '',
}) async {
  if (home.isEmpty || away.isEmpty) return const [];
  _liveBroadcastPluginRowsCache.remove(plugin.id);
  try {
    _logBroadcastHints(
      '${plugin.id} on-demand international lookup home="$home" away="$away"',
    );
    final rows = await EngineService.instance.runLiveCatalog(
      catalogPlugin: plugin,
      extraConfig: {
        'broadcastLookup': true,
        'homeTeam': home,
        'awayTeam': away,
        'eventId': ?(eventId?.toString()),
        'dateMs': ?dateMs,
        if (matchPath.trim().isNotEmpty) 'matchPath': matchPath.trim(),
      },
      timeout: const Duration(seconds: 45),
    );
    for (final row in rows) {
      final channels = _broadcastChannelsFromCatalogRow(row);
      if (channels.isNotEmpty) {
        _logBroadcastHints(
          '${plugin.id} on-demand returned ${channels.length} channels',
        );
        return channels;
      }
    }
  } catch (e) {
    _logBroadcastHints('${plugin.id} on-demand lookup failed: $e');
  }
  return const [];
}

Future<List<Map<String, dynamic>>> _liveBroadcastPluginRowsCached(
  EnginePlugin plugin,
) async {
  final id = plugin.id;
  final cached = _liveBroadcastPluginRowsCache[id];
  if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
    return cached.rows;
  }
  final inflight = _liveBroadcastPluginInflight[id];
  if (inflight != null) return inflight;

  final future = () async {
    try {
      final rows = await EngineService.instance.runLiveCatalog(
        catalogPlugin: plugin,
      );
      final copy = List<Map<String, dynamic>>.from(rows);
      final withChannels = copy.where((row) {
        return _broadcastChannelsFromCatalogRow(row).isNotEmpty;
      }).length;
      _logBroadcastHints(
        '${plugin.id} catalog rows=${copy.length} withChannels=$withChannels',
      );
      if (copy.isEmpty) {
        _logBroadcastHints(
          '${plugin.id} returned 0 rows — plugin disabled or fetch failed',
        );
      } else if (withChannels == 0) {
        _logBroadcastHints(
          '${plugin.id} has rows but none include broadcastChannels',
        );
      }
      _liveBroadcastPluginRowsCache[id] = _LiveBroadcastPluginCacheEntry(
        expiresAt: DateTime.now().add(_liveBroadcastCacheTtl),
        rows: copy,
      );
      final sourceKey = LiveSportCapabilities.normalizePluginId(plugin.id);
      putLiveBroadcastIndex(
        [
          for (final row in copy)
            if (row['sportMatchGame'] is Map)
              _stampBroadcastSource(
                Map<String, dynamic>.from(row['sportMatchGame'] as Map),
                sourceKey: sourceKey,
              ),
        ],
        sourceKey: sourceKey,
      );
      return copy;
    } catch (e) {
      debugPrint('[LiveMatches] broadcast plugin ${plugin.id} failed: $e');
      _logBroadcastHints('${plugin.id} fetch error: $e');
      return const <Map<String, dynamic>>[];
    } finally {
      _liveBroadcastPluginInflight.remove(id);
    }
  }();

  _liveBroadcastPluginInflight[id] = future;
  return future;
}

_LiveBroadcastHints _liveBroadcastHintsFromGame(Map<String, dynamic>? game) {
  if (game == null) return const _LiveBroadcastHints();
  final bySource = _broadcastBySourceMap(game);
  if (bySource.isEmpty) return const _LiveBroadcastHints();
  return _LiveBroadcastHints(
    liveOnSat: List<String>.from(bySource['liveonsat'] ?? const []),
    liveSoccerTv: List<String>.from(bySource['livesoccertv'] ?? const []),
  );
}

Future<_LiveBroadcastHints> _broadcastHintsForMatch(_StreamedMatch match) async {
  final aligned = _sportMatchGameAlignedWithCard(match);
  final fromGame = _liveBroadcastHintsFromGame(aligned);
  var liveOnSat = List<String>.from(fromGame.liveOnSat);
  var liveSoccerTv = List<String>.from(fromGame.liveSoccerTv);

  if (liveOnSat.isNotEmpty && liveSoccerTv.isNotEmpty) {
    _logBroadcastHints(
      'using enriched game payload liveOnSat=${liveOnSat.length} '
      'liveSoccerTv=${liveSoccerTv.length}',
    );
    return fromGame;
  }

  if (liveOnSat.isNotEmpty || liveSoccerTv.isNotEmpty) {
    _logBroadcastHints(
      'partial game payload liveOnSat=${liveOnSat.length} '
      'liveSoccerTv=${liveSoccerTv.length} — filling gaps from catalogs',
    );
  }

  final plugins =
      await EngineService.instance.listLiveSportBroadcastPlugins();
  if (plugins.isEmpty) {
    if (liveOnSat.isEmpty && liveSoccerTv.isEmpty) {
      _logBroadcastHints(
        'no broadcast plugins enabled — turn on LiveOnSat / Live Soccer TV '
        'in Settings → Forja Sports → Catalog',
      );
    }
    return _LiveBroadcastHints(
      liveOnSat: liveOnSat.toSet().toList(),
      liveSoccerTv: liveSoccerTv.toSet().toList(),
    );
  }

  final home = (aligned['homeTeam'] ?? '').toString().trim();
  final away = (aligned['awayTeam'] ?? '').toString().trim();
  final title = (aligned['title'] ?? match.title).toString().trim();
  final kickoff = (aligned['dateMs'] as num?)?.toInt() ?? match.dateMs;
  final eventId = _broadcastEventIdFromGame(aligned);
  final searchTokens = _broadcastSearchTokens(
    title: title,
    homeTeam: home.isEmpty ? null : home,
    awayTeam: away.isEmpty ? null : away,
  );

  _logBroadcastHints(
    'lookup title="$title" home="$home" away="$away" kickoff=$kickoff '
    'plugins=${plugins.map((p) => p.id).join(", ")}',
  );

  for (final plugin in plugins) {
    final sourceKey = LiveSportCapabilities.normalizePluginId(plugin.id);
    if (sourceKey == 'livesoccertv' && liveSoccerTv.isNotEmpty) {
      continue;
    }

    final rows = await _liveBroadcastPluginRowsCached(plugin);
    var matchedRows = 0;
    var matchedChannels = 0;
    String matchedMatchPath = '';
    int? matchedEventId;
    final catalogChannels = <String>[];

    for (final row in rows) {
      if (row['sportMatchGame'] is! Map) continue;
      final game = Map<String, dynamic>.from(row['sportMatchGame'] as Map);
      if (!_sameCatalogEventAsBroadcast(
        title: title,
        homeTeam: home.isEmpty ? null : home,
        awayTeam: away.isEmpty ? null : away,
        dateMs: kickoff,
        broadcastGame: game,
      )) {
        continue;
      }
      matchedRows++;
      matchedEventId ??=
          _broadcastEventIdFromGame(game) ?? _broadcastEventIdFromGame(row);
      final rowPath =
          (game['matchPath'] ?? row['matchPath'] ?? '').toString().trim();
      if (rowPath.isNotEmpty) matchedMatchPath = rowPath;
      final channels = _broadcastChannelsFromCatalogRow(row);
      matchedChannels += channels.length;
      if (channels.isEmpty) {
        _logBroadcastHints(
          '${plugin.id} matched "${game['title'] ?? row['title']}" but 0 channels',
        );
        continue;
      }
      catalogChannels.addAll(channels);
    }

    if (sourceKey == 'liveonsat') {
      liveOnSat = catalogChannels.toSet().toList();
      if (matchedRows == 0) {
        _logBroadcastHints(
          '${plugin.id} no fixture match — LiveOnSat section omitted',
        );
      }
    } else if (sourceKey == 'livesoccertv') {
      liveSoccerTv = catalogChannels.toSet().toList();
    }

    if (sourceKey == 'livesoccertv' && liveSoccerTv.isEmpty) {
      final onDemand = await _liveSoccerTvBroadcastOnDemand(
        plugin: plugin,
        home: home,
        away: away,
        eventId: matchedEventId ?? eventId,
        dateMs: kickoff,
        matchPath: matchedMatchPath,
      );
      if (onDemand.isNotEmpty) {
        liveSoccerTv.addAll(onDemand);
        matchedChannels += onDemand.length;
      }
    }

    if (matchedRows == 0) {
      _logBroadcastHints('${plugin.id} no fixture match in ${rows.length} rows');
      _logBroadcastNearMisses(
        pluginId: plugin.id,
        rows: rows,
        searchTokens: searchTokens,
        kickoffMs: kickoff,
      );
    } else {
      _logBroadcastHints(
        '${plugin.id} matchedRows=$matchedRows matchedChannels=$matchedChannels',
      );
    }
  }

  final hints = _LiveBroadcastHints(
    liveOnSat: liveOnSat.toSet().toList(),
    liveSoccerTv: liveSoccerTv.toSet().toList(),
  );
  if (hints.isEmpty) {
    _logBroadcastHints(
      'result empty — fixture not listed with TV data on LiveOnSat / Live Soccer TV',
    );
  } else {
    _logBroadcastHints(
      'result liveOnSat=${hints.liveOnSat.length} '
      'liveSoccerTv=${hints.liveSoccerTv.length} '
      'sample=${[
        ...hints.liveOnSat.take(2),
        ...hints.liveSoccerTv.take(2),
      ].join(", ")}',
    );
  }
  return hints;
}

void putLiveBroadcastIndex(
  List<Map<String, dynamic>> games, {
  String? sourceKey,
}) {
  if (games.isEmpty) return;
  if (sourceKey != null && sourceKey.trim().isNotEmpty) {
    _liveBroadcastIndexedSources.add(sourceKey.trim());
  }
  final byKey = <String, Map<String, dynamic>>{
    for (final g in _liveBroadcastIndex)
      _broadcastIndexKey(g): Map<String, dynamic>.from(g),
  };
  for (final g in games) {
    final incoming = Map<String, dynamic>.from(g);
    final key = _broadcastIndexKey(incoming);
    final existing = byKey[key];
    byKey[key] = existing == null
        ? incoming
        : _mergeBroadcastGames(
            existing,
            incoming,
            sourceKey: sourceKey,
          );
  }
  _liveBroadcastIndex = byKey.values.toList();
  _liveBroadcastCacheExpiry = DateTime.now().add(_liveBroadcastCacheTtl);
}

Future<List<Map<String, dynamic>>> _liveBroadcastIndexCached() async {
  final plugins =
      await EngineService.instance.listLiveSportBroadcastPlugins();
  if (plugins.isEmpty) return _liveBroadcastIndex;

  final requiredSources = {
    for (final plugin in plugins)
      LiveSportCapabilities.normalizePluginId(plugin.id),
  };
  final cacheFresh = _liveBroadcastCacheExpiry != null &&
      DateTime.now().isBefore(_liveBroadcastCacheExpiry!) &&
      requiredSources.every(_liveBroadcastIndexedSources.contains);
  if (cacheFresh && _liveBroadcastIndex.isNotEmpty) {
    return _liveBroadcastIndex;
  }

  final inflight = _liveBroadcastInFlight;
  if (inflight != null) return inflight;

  final future = _fetchLiveBroadcastIndex();
  _liveBroadcastInFlight = future;
  try {
    return await future;
  } finally {
    _liveBroadcastInFlight = null;
  }
}

Future<List<Map<String, dynamic>>> _fetchLiveBroadcastIndex() async {
  try {
    final plugins =
        await EngineService.instance.listLiveSportBroadcastPlugins();
    if (plugins.isEmpty) return [];
    await Future.wait(
      plugins.map(_liveBroadcastPluginRowsCached),
    );
    return _liveBroadcastIndex;
  } catch (e) {
    debugPrint('[LiveMatches] broadcast catalog index failed: $e');
    return _liveBroadcastIndex;
  }
}

Map<String, dynamic> _enrichGameWithBroadcastChannels(
  Map<String, dynamic> game,
  List<Map<String, dynamic>> broadcastGames, {
  required String title,
  String? homeTeam,
  String? awayTeam,
  int dateMs = 0,
}) {
  if (broadcastGames.isEmpty) return game;
  final home = (game['homeTeam'] ?? homeTeam ?? '').toString().trim();
  final away = (game['awayTeam'] ?? awayTeam ?? '').toString().trim();
  final kickoff = (game['dateMs'] as num?)?.toInt() ?? dateMs;
  final cardTitle = (game['title'] ?? title).toString().trim();
  var merged = <String>{
    ..._broadcastChannelsFromGame(game),
  };
  final mergedBySource = <String, List<String>>{
    ..._broadcastBySourceMap(game),
  };
  for (final broadcast in broadcastGames) {
    if (!_sameCatalogEventAsBroadcast(
      title: cardTitle,
      homeTeam: home.isEmpty ? null : home,
      awayTeam: away.isEmpty ? null : away,
      dateMs: kickoff,
      broadcastGame: broadcast,
    )) {
      continue;
    }
    merged.addAll(_broadcastChannelsFromGame(broadcast));
    for (final entry in _broadcastBySourceMap(broadcast).entries) {
      final list = List<String>.from(mergedBySource[entry.key] ?? const []);
      for (final name in entry.value) {
        if (!list.contains(name)) list.add(name);
      }
      mergedBySource[entry.key] = list;
    }
  }
  if (merged.isEmpty) return game;
  return {
    ...game,
    'broadcastChannels': merged.toList(),
    if (mergedBySource.isNotEmpty) 'broadcastBySource': mergedBySource,
  };
}

class _IptvSportsStreamsCacheEntry {
  final DateTime expiresAt;
  final List<IptvPlaySource> sources;
  const _IptvSportsStreamsCacheEntry({
    required this.expiresAt,
    required this.sources,
  });
}

final Map<String, _IptvSportsStreamsCacheEntry> _iptvSportsStreamsCache = {};

/// Dedupes concurrent resolves for the same match; late joiners replay partials.
final class _IptvSportsStreamsInflight {
  _IptvSportsStreamsInflight(this.future);

  final Future<List<IptvPlaySource>> future;
  final List<IptvPlaySource> _accumulated = [];
  final Set<String> _seenKeys = {};
  final List<void Function(List<IptvPlaySource> batch)> _listeners = [];

  void subscribe(void Function(List<IptvPlaySource> batch)? onPartial) {
    if (onPartial == null) return;
    if (_accumulated.isNotEmpty) {
      onPartial(List<IptvPlaySource>.from(_accumulated));
    }
    _listeners.add(onPartial);
  }

  void emit(List<IptvPlaySource> batch) {
    if (batch.isEmpty) return;
    final fresh = <IptvPlaySource>[];
    for (final s in batch) {
      final id = (s.streamId ?? '').trim();
      final url = s.url.trim();
      final key = id.isNotEmpty ? 'id:$id' : 'url:$url';
      if (id.isEmpty && url.isEmpty) continue;
      if (!_seenKeys.add(key)) continue;
      fresh.add(s);
      _accumulated.add(s);
    }
    if (fresh.isEmpty) return;
    for (final listener in List<void Function(List<IptvPlaySource> batch)>.from(
      _listeners,
    )) {
      listener(fresh);
    }
  }
}

final Map<String, _IptvSportsStreamsInflight> _iptvSportsStreamsInFlight = {};

String _iptvSportsStreamsCacheKey({
  required String portalKey,
  required List<String> categoryIds,
  required _StreamedMatch match,
}) {
  final cats = List<String>.from(categoryIds)..sort();
  // Same fixture identity as Providers — not catalog match.id / broadcast
  // channel lists (those change between opens and caused constant misses).
  return '$portalKey|${cats.join(',')}|${_liveEventViewerKey(match)}';
}

List<IptvPlaySource>? _iptvSportsStreamsCacheGet(String key) {
  final hit = _iptvSportsStreamsCache[key];
  if (hit == null) return null;
  if (DateTime.now().isAfter(hit.expiresAt)) {
    _iptvSportsStreamsCache.remove(key);
    return null;
  }
  if (hit.sources.isEmpty) {
    _iptvSportsStreamsCache.remove(key);
    return null;
  }
  return List<IptvPlaySource>.from(hit.sources);
}

bool _liveMatchesJsonCancelled(Map<String, dynamic> parsed) =>
    (parsed['error'] ?? '').toString() == 'cancelled';

void _iptvSportsStreamsCachePut(String key, List<IptvPlaySource> sources) {
  if (sources.isEmpty) return;
  _iptvSportsStreamsCache[key] = _IptvSportsStreamsCacheEntry(
    expiresAt: DateTime.now().add(_iptvSportsStreamsCacheTtl),
    sources: List<IptvPlaySource>.from(sources),
  );
}

Map<String, dynamic> _sportMatchGameAlignedWithCard(_StreamedMatch match) {
  final base = Map<String, dynamic>.from(
    match.sportMatchGame ?? _sportMatchGamePayloadFromMatch(match),
  );
  final (home, away) = resolveLiveMatchTeams(
    homeTeam: match.homeTeam,
    awayTeam: match.awayTeam,
    title: match.title,
  );
  final title = match.title.trim();
  if (title.isNotEmpty) base['title'] = title;
  if (home.isNotEmpty) {
    base['homeTeam'] = home;
    base['homeNick'] = sportNickFromTeam(home);
  }
  if (away.isNotEmpty) {
    base['awayTeam'] = away;
    base['awayNick'] = sportNickFromTeam(away);
  }
  if (match.dateMs > 0) {
    base['dateMs'] = match.dateMs;
    base['date'] = DateTime.fromMillisecondsSinceEpoch(
      match.dateMs,
      isUtc: true,
    ).toIso8601String();
  }
  final sport = match.category.trim();
  if (sport.isNotEmpty) {
    base['sport'] = sport;
    base['category'] = sport;
  }
  return base;
}

Future<List<IptvPlaySource>> _resolveIptvSportsStreams(
  _StreamedMatch match, {
  void Function(List<IptvPlaySource> batch)? onPartial,
  bool force = false,
}) async {
  final config = await LiveMatchesIptvSportsConfig.load();
  final armed = await config.resolveForFetch();
  if (armed == null) return [];
  final portalKey = armed.portalKey;
  final portals = await IptvStore.load();
  VerifiedPortal? portal;
  for (final p in portals) {
    if (p.key == portalKey) {
      portal = p;
      break;
    }
  }
  if (portal == null || !portal.portal.platform.supportsForjaSports) {
    return [];
  }
  final sport = match.category.trim().isNotEmpty
      ? match.category
      : (match.sportMatchGame?['sport'] ?? '').toString();
  final categoryIds = config.categoryIdsForGame(sport);
  final cacheKey = _iptvSportsStreamsCacheKey(
    portalKey: portalKey,
    categoryIds: categoryIds,
    match: match,
  );
  if (force) {
    _iptvSportsStreamsCache.remove(cacheKey);
    _iptvSportsStreamsInFlight.remove(cacheKey);
  } else {
    final cached = _iptvSportsStreamsCacheGet(cacheKey);
    if (cached != null) {
      debugPrint(
        '[LiveMatches] IPTV sports: cache hit (${cached.length} channels) '
        'ttl=${_iptvSportsStreamsCacheTtl.inMinutes}m key=$cacheKey',
      );
      final logos = await _ensureIptvSportsLogos(cached, portalKey);
      final result = _ensureIptvSportsUrls(logos, portal);
      onPartial?.call(result);
      return result;
    }
    final inflight = _iptvSportsStreamsInFlight[cacheKey];
    if (inflight != null) {
      inflight.subscribe(onPartial);
      return inflight.future;
    }
  }

  final broadcastFuture = _liveBroadcastIndexCached();
  var game = _sportMatchGameAlignedWithCard(match);
  final broadcastGames = await broadcastFuture;
  game = _enrichGameWithBroadcastChannels(
    game,
    broadcastGames,
    title: match.title,
    homeTeam: match.homeTeam,
    awayTeam: match.awayTeam,
    dateMs: match.dateMs,
  );
  final home = (game['homeTeam'] ?? '').toString().trim();
  final away = (game['awayTeam'] ?? '').toString().trim();
  final title = (game['title'] ?? match.title).toString().trim();
  if (home.isEmpty && away.isEmpty && title.isEmpty) {
    debugPrint(
      '[LiveMatches] IPTV sports: no title/teams/keywords for "${match.title}"',
    );
    return [];
  }

  final armedPortal = portal;
  late final _IptvSportsStreamsInflight coordinator;
  final future = () async {
    try {
      final p = armedPortal.portal;
      final Map<String, dynamic> portalCreds;
      if (p.platform == IptvPortalPlatform.stalker) {
        portalCreds = {
          'stalker': {
            'url': p.url,
            'username': p.username,
            'password': p.password,
          },
        };
      } else {
        portalCreds = {
          'xtream': {
            'url': p.url,
            'username': p.username,
            'password': p.password,
          },
        };
      }
      final requestBase = {
        'action': 'sport_match_streams',
        'game': game,
        ...portalCreds,
        'category_ids': categoryIds,
      };

      void emitPartial(List<IptvPlaySource> batch) => coordinator.emit(batch);

      final excludeStreamIds = <String>[];
      final accumulated = <IptvPlaySource>[];

      void trackExcludeIds(Iterable<IptvPlaySource> batch) {
        for (final s in batch) {
          final id = (s.streamId ?? '').trim();
          if (id.isNotEmpty) excludeStreamIds.add(id);
        }
      }

      final fastRaw = await runLiveMatchesFetchJson(
        jsonEncode({...requestBase, 'skip_epg': true}),
      );
      final fastParsed = jsonDecode(fastRaw) as Map<String, dynamic>;
      if (_liveMatchesJsonCancelled(fastParsed)) {
        return <IptvPlaySource>[];
      }
      if (!fastParsed.containsKey('error')) {
        final fast = _parseSportMatchStreamItems(
          fastParsed['items'] as List? ?? [],
          platform: p.platform,
        );
        final fastNorm = _ensureIptvSportsUrls(fast, armedPortal);
        emitPartial(fastNorm);
        accumulated.addAll(fastNorm);
        trackExcludeIds(fastNorm);
      }

      var epgOffset = 0;
      var epgMore = true;
      while (epgMore) {
        final raw = await runLiveMatchesFetchJson(
          jsonEncode({
            ...requestBase,
            'epg_offset': epgOffset,
            'epg_limit': _iptvSportsEpgBatchSize,
            'exclude_stream_ids': excludeStreamIds,
          }),
        );
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        if (_liveMatchesJsonCancelled(parsed)) {
          return accumulated;
        }
        if (parsed.containsKey('error')) {
          if (!_liveMatchesJsonCancelled(parsed)) {
            debugPrint(
              '[LiveMatches] IPTV sports streams error: ${parsed['error']}',
            );
          }
          break;
        }
        final batch = _parseSportMatchStreamItems(
          parsed['items'] as List? ?? [],
          platform: p.platform,
        );
        if (batch.isNotEmpty) {
          final normalized = _ensureIptvSportsUrls(batch, armedPortal);
          emitPartial(normalized);
          accumulated.addAll(normalized);
          trackExcludeIds(normalized);
        }
        epgMore = parsed['epg_more'] == true;
        if (epgMore) {
          epgOffset = (parsed['epg_next_offset'] as num?)?.toInt() ??
              epgOffset + _iptvSportsEpgBatchSize;
        }
      }

      if (accumulated.isEmpty) return <IptvPlaySource>[];
      final enriched = await _ensureIptvSportsLogos(accumulated, portalKey);
      _iptvSportsStreamsCachePut(cacheKey, enriched);
      return enriched;
    } finally {
      _iptvSportsStreamsInFlight.remove(cacheKey);
    }
  }();

  coordinator = _IptvSportsStreamsInflight(future);
  coordinator.subscribe(onPartial);
  _iptvSportsStreamsInFlight[cacheKey] = coordinator;
  return future;
}

List<IptvPlaySource> _parseSportMatchStreamItems(
  List<dynamic> list, {
  IptvPortalPlatform platform = IptvPortalPlatform.xtream,
}) {
  final kind = switch (platform) {
    IptvPortalPlatform.stalker => IptvLiveSourceKind.iptvStalker,
    _ => IptvLiveSourceKind.iptvXtream,
  };
  final out = <IptvPlaySource>[];
  for (final s in list) {
    if (s is! Map) continue;
    final url = s['url']?.toString().trim() ?? '';
    final streamId = (s['stream_id'] ?? s['streamId'] ?? '').toString().trim();
    final epgChannelId =
        (s['epg_channel_id'] ?? s['epgChannelId'] ?? '').toString().trim();
    // Xtream needs http(s) URL; Stalker may ship empty URL + cmd stream_id.
    if (platform == IptvPortalPlatform.stalker) {
      if (streamId.isEmpty) continue;
    } else {
      if (url.isEmpty) continue;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        continue;
      }
    }
    final channel = (s['name'] ?? 'Stream').toString().trim();
    final category = (s['title'] ?? '').toString().trim();
    final logo = (s['logo'] ?? s['stream_icon'] ?? s['cover'] ?? '')
        .toString()
        .trim();
    final name = channel.isEmpty ? 'Stream' : channel;
    final label = name;
    out.add(IptvPlaySource(
      url: url,
      label: label,
      detail: category.isEmpty ? null : category,
      logoUrl: logo.isEmpty ? null : logo,
      streamId: streamId.isEmpty ? null : streamId,
      epgChannelId: epgChannelId.isEmpty ? null : epgChannelId,
      liveSourceKind: kind,
    ));
  }
  return out;
}

/// Rebuild Xtream play URLs the same way as IPTV Live (`…/live/u/p/id.ts`).
/// Stalker keeps empty URL until create_link at play.
List<IptvPlaySource> _ensureIptvSportsUrls(
  List<IptvPlaySource> sources,
  VerifiedPortal portal,
) {
  if (sources.isEmpty || portal.portal.platform != IptvPortalPlatform.xtream) {
    return sources;
  }
  final p = portal.portal;
  return [
    for (final s in sources)
      () {
        final id = (s.streamId ?? '').trim();
        if (id.isEmpty) return s;
        final url = IptvClient.streamUrl(
          p,
          IptvStream(
            streamId: id,
            name: '',
            icon: '',
            categoryId: '',
            containerExt: 'ts',
            epgChannelId: '',
            kind: 'live',
          ),
        );
        if (url.isEmpty || url == s.url) return s;
        return IptvPlaySource(
          url: url,
          label: s.label,
          detail: s.detail,
          logoUrl: s.logoUrl,
          streamId: s.streamId,
          epgChannelId: s.epgChannelId,
          headers: s.headers,
          liveSourceKind: s.liveSourceKind,
        );
      }(),
  ];
}

/// Fill missing logos and EPG channel ids from the IPTV live catalog.
Future<List<IptvPlaySource>> _ensureIptvSportsLogos(
  List<IptvPlaySource> sources,
  String portalKey,
) async {
  if (sources.isEmpty) return sources;
  final needLogo = sources.any((s) => (s.logoUrl ?? '').trim().isEmpty);
  final needEpg = sources.any(
    (s) =>
        (s.streamId ?? '').trim().isNotEmpty &&
        (s.epgChannelId ?? '').trim().isEmpty,
  );
  if (!needLogo && !needEpg) return sources;

  final byId = <String, String>{};
  final byEpgId = <String, String>{};
  final byName = <String, String>{};
  try {
    final shelf = await IptvCatalogDiskStore.load(portalKey, IptvSection.live);
    if (shelf != null) {
      for (final s in shelf.streams) {
        final id = s.streamId.trim();
        if (id.isNotEmpty) {
          final epgId = s.epgChannelId.trim();
          if (epgId.isNotEmpty) byEpgId[id] = epgId;
        }
        final icon = s.icon.trim();
        if (icon.isEmpty) continue;
        if (id.isNotEmpty) byId[id] = icon;
        final n = s.name.trim().toLowerCase();
        if (n.isNotEmpty) byName.putIfAbsent(n, () => icon);
      }
    }
  } catch (e) {
    debugPrint('[LiveMatches] IPTV catalog logo lookup failed: $e');
  }
  if (byId.isEmpty && byName.isEmpty && byEpgId.isEmpty) {
    debugPrint(
      '[LiveMatches] IPTV sports catalog enrich: empty — open IPTV once '
      'to cache channel metadata',
    );
    return sources;
  }

  String? lookup(String channelName) {
    final key = channelName.trim().toLowerCase();
    if (key.isEmpty) return null;
    final exact = byName[key];
    if (exact != null && exact.isNotEmpty) return exact;
    final stem = key.replaceFirst(RegExp(r'\s+\d+$'), '').trim();
    if (stem.isNotEmpty && stem != key) {
      final byStem = byName[stem];
      if (byStem != null && byStem.isNotEmpty) return byStem;
    }
    for (final e in byName.entries) {
      if (e.key.isEmpty) continue;
      if (key.startsWith('${e.key} ') || e.key.startsWith('$key ')) {
        return e.value;
      }
    }
    return null;
  }

  // Prefer stream_id (exact catalog row), then name / stem ("WNBA 01" → "WNBA").
  var logosFilled = 0;
  var epgFilled = 0;
  final out = <IptvPlaySource>[
    for (final s in sources)
      () {
        final id = (s.streamId ?? '').trim();
        String? logo = (s.logoUrl ?? '').trim().isNotEmpty ? s.logoUrl : null;
        if (logo == null || logo.isEmpty) {
          if (id.isNotEmpty) logo = byId[id];
          logo ??= lookup(s.chromeTitle);
        }
        final epgId = (s.epgChannelId ?? '').trim().isNotEmpty
            ? s.epgChannelId
            : (id.isNotEmpty ? byEpgId[id] : null);
        if (logo == s.logoUrl && epgId == s.epgChannelId) return s;
        if ((s.logoUrl ?? '').trim().isEmpty &&
            logo != null &&
            logo.isNotEmpty) {
          logosFilled++;
        }
        if ((s.epgChannelId ?? '').trim().isEmpty &&
            (epgId ?? '').trim().isNotEmpty) {
          epgFilled++;
        }
        return IptvPlaySource(
          url: s.url,
          label: s.label,
          detail: s.detail,
          logoUrl: logo ?? s.logoUrl,
          streamId: s.streamId,
          epgChannelId: epgId,
          headers: s.headers,
          liveSourceKind: s.liveSourceKind,
        );
      }(),
  ];
  debugPrint(
    '[LiveMatches] IPTV sports catalog enrich: logos $logosFilled/${sources.length} '
    'epg $epgFilled/${sources.length} (ids=${byId.length} epg=${byEpgId.length})',
  );
  return out;
}

/// Build matcher payload from a Live Matches card (PPV / Streamed / CDN).
Map<String, dynamic> _sportMatchGamePayloadFromMatch(_StreamedMatch match) {
  final (home, away) = resolveLiveMatchTeams(
    homeTeam: match.homeTeam,
    awayTeam: match.awayTeam,
    title: match.title,
  );
  return {
    'id': match.id,
    'title': match.title,
    'sport': match.category,
    'category': match.category,
    'homeTeam': home,
    'awayTeam': away,
    'homeNick': sportNickFromTeam(home),
    'awayNick': sportNickFromTeam(away),
    'homeAbbr': '',
    'awayAbbr': '',
    'dateMs': match.dateMs,
    'date': match.dateMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(match.dateMs, isUtc: true)
            .toIso8601String()
        : '',
  };
}

