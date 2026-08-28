part of '../live_matches_screen.dart';

/// Primary match-list fetch keyed by server mode.
final liveMatchesPrimaryLoadProvider = FutureProvider.autoDispose
    .family<_LiveMatchesPrimaryLoad, _LiveMatchesServer>((ref, server) async {
      switch (server) {
        case _LiveMatchesServer.all:
          return _fetchLiveMatchesAll();
        case _LiveMatchesServer.ppv:
          return _fetchLiveMatchesPpv();
        case _LiveMatchesServer.streamed:
          return _fetchLiveMatchesStreamed();
        case _LiveMatchesServer.mutStreams:
          return _fetchLiveMatchesMut();
        case _LiveMatchesServer.forjaLive:
          return _fetchLiveMatchesForjaLive();
        case _LiveMatchesServer.stremio:
          return _fetchLiveMatchesStremio();
        case _LiveMatchesServer.iptvSports:
          return _fetchLiveMatchesIptvSports();
      }
    });

class _LiveMatchesPrimaryLoad {
  const _LiveMatchesPrimaryLoad({
    required this.sports,
    this.damiTvStreams = const [],
    this.streamedMatches = const [],
    this.espnGames = const [],
  });

  final List<_Sport> sports;
  final List<_DamiTvStream> damiTvStreams;
  final List<_StreamedMatch> streamedMatches;
  /// Raw ESPN scoreboard rows for My IPTV play-time enrichment.
  final List<Map<String, dynamic>> espnGames;
}

/// PPV + Streamed schedule for dedicated server tabs only.
/// **Forja Live** / **Forja Sports** / **All** load catalogs via the Catalog button instead.
Future<_LiveMatchesPrimaryLoad> _fetchLiveMatchesAll() async {
  return const _LiveMatchesPrimaryLoad(sports: [], espnGames: []);
}

Future<_LiveMatchesPrimaryLoad> _fetchLiveMatchesPpv() async {
  final streams = await _fetchDamiTvStreams();
  final seenCats = <String>{};
  final cats = <_Sport>[];
  for (final s in streams) {
    final raw = _is247Item(category: s.categoryName, isAlwaysOn: s.isAlwaysOn)
        ? '24/7'
        : s.categoryName;
    final id = _normalizeSportId(raw);
    if (id.isEmpty || !seenCats.add(id)) continue;
    cats.add(_Sport(id: id, name: _sportDisplayName(raw, id)));
  }
  return _LiveMatchesPrimaryLoad(
    sports: cats,
    damiTvStreams: streams,
    espnGames: const [],
  );
}

Future<_LiveMatchesPrimaryLoad> _fetchLiveMatchesStreamed() async {
  final results = await Future.wait([
    _fetchStreamedSports(),
    _fetchStreamedMatches(),
  ]);
  final sports = results[0] as List<_Sport>;
  final matches = results[1] as List<_StreamedMatch>;

  final scheduledCats = matches
      .where((m) => !m.isAlwaysOn)
      .map((m) => m.category)
      .toSet();
  var cats = sports.where((s) => scheduledCats.contains(s.id)).toList();
  if (cats.isEmpty) {
    final seen = <String>{};
    cats = [];
    for (final m in matches) {
      if (m.isAlwaysOn) continue;
      if (m.category.isNotEmpty && seen.add(m.category)) {
        cats.add(_Sport(id: m.category, name: m.categoryLabel));
      }
    }
  }
  if (matches.any((m) => m.isAlwaysOn) &&
      !cats.any((c) => _normalizeSportId(c.id) == '24-7')) {
    cats = [...cats, const _Sport(id: '24-7', name: '24/7')];
  }
  cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return _LiveMatchesPrimaryLoad(
    sports: cats,
    streamedMatches: matches,
    espnGames: const [],
  );
}

Future<_LiveMatchesPrimaryLoad> _fetchLiveMatchesMut() async {
  final matches = await _fetchMutMatches();
  final seen = <String>{};
  final cats = <_Sport>[];
  for (final m in matches) {
    if (m.isAlwaysOn) continue;
    if (m.category.isNotEmpty && seen.add(m.category)) {
      cats.add(_Sport(id: m.category, name: m.categoryLabel));
    }
  }
  if (matches.any((m) => m.isAlwaysOn) &&
      !cats.any((c) => _normalizeSportId(c.id) == '24-7')) {
    cats.add(const _Sport(id: '24-7', name: '24/7'));
  }
  cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return _LiveMatchesPrimaryLoad(
    sports: cats,
    streamedMatches: matches,
    espnGames: const [],
  );
}

_StreamedMatch _forjaLiveRowToMatch(Map<String, dynamic> j) {
  final sourcesRaw = j['sources'];
  final inline = <Map<String, dynamic>>[];
  final refs = <Map<String, dynamic>>[];
  if (sourcesRaw is List) {
    for (final s in sourcesRaw) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(s);
      final url = (m['url'] ?? '').toString();
      if (url.isNotEmpty) {
        inline.add({
          'id': m['id'] ?? '',
          'streamNo': 1,
          'language': '',
          'hd': false,
          'embedUrl': url,
          'source': m['source'] ?? '',
          'viewers': 0,
        });
      } else {
        refs.add(m);
      }
    }
  }
  final enriched = Map<String, dynamic>.from(j);
  enriched['sources'] = refs;
  enriched['streams'] = inline;
  if (j['homeTeam'] != null && enriched['teams'] == null) {
    enriched['teams'] = {
      'home': {'name': j['homeTeam'], 'badge': j['homeBadge'] ?? ''},
      'away': {'name': j['awayTeam'], 'badge': j['awayBadge'] ?? ''},
    };
  }
  return _StreamedMatch.fromJson(enriched);
}

// Kept for bulk fetch tests / tooling; Live Matches UI uses lazy per-plugin load.

Future<_LiveMatchesPrimaryLoad> _fetchLiveMatchesForjaLive() async {
  return _fetchLiveMatchesAll();
}

Future<_LiveMatchesPrimaryLoad> _fetchLiveMatchesStremio() async {
  final matches = await _fetchStremioSportMatches();
  final seen = <String>{};
  final cats = <_Sport>[];
  for (final m in matches) {
    if (m.isAlwaysOn) continue;
    if (m.category.isNotEmpty && seen.add(m.category)) {
      cats.add(_Sport(id: m.category, name: m.categoryLabel));
    }
  }
  if (matches.any((m) => m.isAlwaysOn) &&
      !cats.any((c) => _normalizeSportId(c.id) == '24-7')) {
    cats.add(const _Sport(id: '24-7', name: '24/7'));
  }
  cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return _LiveMatchesPrimaryLoad(
    sports: cats,
    streamedMatches: matches,
    espnGames: const [],
  );
}

/// Forja Sports schedule = same enabled Catalog JS as Forja Live / All
/// (lazy chips in [_LiveMatchesForjaLive]); play still matches Xtream.
Future<_LiveMatchesPrimaryLoad> _fetchLiveMatchesIptvSports() async {
  return _fetchLiveMatchesAll();
}
