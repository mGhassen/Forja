part of '../live_matches_screen.dart';

/// Primary match-list fetch keyed by server mode.
final liveMatchesPrimaryLoadProvider = FutureProvider.autoDispose
    .family<LiveMatchesPrimaryLoad, _LiveMatchesServer>((ref, server) async {
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

class LiveMatchesPrimaryLoad {
  const LiveMatchesPrimaryLoad({
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

Future<LiveMatchesPrimaryLoad> _fetchLiveMatchesAll() async {
  final results = await Future.wait([
    _fetchDamiTvStreams().catchError((_) => <_DamiTvStream>[]),
    _fetchStreamedMatches().catchError((_) => <_StreamedMatch>[]),
  ]);
  final ppvStreams = results[0] as List<_DamiTvStream>;
  final rustStreamed = results[1] as List<_StreamedMatch>;

  final seenCats = <String>{};
  final cats = <_Sport>[];
  void addCat(String raw) {
    final id = _normalizeSportId(raw);
    if (id.isEmpty || !seenCats.add(id)) return;
    cats.add(_Sport(id: id, name: _sportDisplayName(raw, id)));
  }

  void addMatchCat(String category, {required bool isAlwaysOn}) {
    if (_is247Item(category: category, isAlwaysOn: isAlwaysOn)) {
      addCat('24/7');
    } else {
      addCat(category);
    }
  }

  for (final s in ppvStreams) {
    addMatchCat(s.categoryName, isAlwaysOn: s.isAlwaysOn);
  }
  for (final m in rustStreamed) {
    addMatchCat(m.category, isAlwaysOn: m.isAlwaysOn);
  }
  cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return LiveMatchesPrimaryLoad(
    sports: cats,
    damiTvStreams: ppvStreams,
    streamedMatches: rustStreamed,
  );
}

Future<LiveMatchesPrimaryLoad> _fetchLiveMatchesPpv() async {
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
  return LiveMatchesPrimaryLoad(sports: cats, damiTvStreams: streams);
}

Future<LiveMatchesPrimaryLoad> _fetchLiveMatchesStreamed() async {
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

  return LiveMatchesPrimaryLoad(sports: cats, streamedMatches: matches);
}

Future<LiveMatchesPrimaryLoad> _fetchLiveMatchesMut() async {
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
  return LiveMatchesPrimaryLoad(sports: cats, streamedMatches: matches);
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

Future<List<_StreamedMatch>> _fetchForjaLiveMatches() async {
  final rows = await LiveMatchesEngine.fetchCatalog();
  return rows
      .where(_forjaLiveCatalogRowVisible)
      .map(_forjaLiveRowToMatch)
      .where((m) => m.id.isNotEmpty && m.title.isNotEmpty)
      .take(_kForjaLiveCatalogMaxPerPlugin)
      .toList();
}

// Kept for bulk fetch tests / tooling; Live Matches UI uses lazy per-plugin load.

Future<LiveMatchesPrimaryLoad> _fetchLiveMatchesForjaLive() async {
  // Same PPV · Streamed base as All — engine catalogs + Rust ESPN merge on top.
  return _fetchLiveMatchesAll();
}

Future<LiveMatchesPrimaryLoad> _fetchLiveMatchesStremio() async {
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
  return LiveMatchesPrimaryLoad(sports: cats, streamedMatches: matches);
}

Future<LiveMatchesPrimaryLoad> _fetchLiveMatchesIptvSports() async {
  final results = await Future.wait([
    _fetchLiveMatchesAll(),
    _fetchEspnSportMatchGames(),
  ]);
  final all = results[0] as LiveMatchesPrimaryLoad;
  final espn = results[1] as List<Map<String, dynamic>>;
  final merged = _mergeStreamedWithEspn(all.streamedMatches, espn);

  final seenCats = <String>{};
  final cats = <_Sport>[];
  void addCat(String raw) {
    final id = _normalizeSportId(raw);
    if (id.isEmpty || !seenCats.add(id)) return;
    cats.add(_Sport(id: id, name: _sportDisplayName(raw, id)));
  }

  for (final s in all.damiTvStreams) {
    if (_is247Item(category: s.categoryName, isAlwaysOn: s.isAlwaysOn)) {
      addCat('24/7');
    } else {
      addCat(s.categoryName);
    }
  }
  for (final m in merged.streamed) {
    if (_is247Item(category: m.category, isAlwaysOn: m.isAlwaysOn)) {
      addCat('24/7');
    } else {
      addCat(m.category);
    }
  }
  cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return LiveMatchesPrimaryLoad(
    sports: cats,
    damiTvStreams: all.damiTvStreams,
    streamedMatches: merged.streamed,
    espnGames: espn,
  );
}
