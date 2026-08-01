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
        case _LiveMatchesServer.cdnLive:
          return _fetchLiveMatchesCdn();
        case _LiveMatchesServer.stremio:
          return _fetchLiveMatchesStremio();
      }
    });

class LiveMatchesPrimaryLoad {
  const LiveMatchesPrimaryLoad({
    required this.sports,
    this.damiTvStreams = const [],
    this.streamedMatches = const [],
    this.cdnChannels = const [],
    this.cdnSports = const [],
  });

  final List<_Sport> sports;
  final List<_DamiTvStream> damiTvStreams;
  final List<_StreamedMatch> streamedMatches;
  final List<_CdnChannel> cdnChannels;
  final List<_CdnSportEvent> cdnSports;
}

Future<LiveMatchesPrimaryLoad> _fetchLiveMatchesAll() async {
  final results = await Future.wait([
    _fetchDamiTvStreams().catchError((_) => <_DamiTvStream>[]),
    _fetchStreamedMatches().catchError((_) => <_StreamedMatch>[]),
    _fetchCdnChannels().catchError((_) => <_CdnChannel>[]),
    _fetchCdnSports().catchError((_) => <_CdnSportEvent>[]),
  ]);
  final ppvStreams = results[0] as List<_DamiTvStream>;
  final streamedMatches = results[1] as List<_StreamedMatch>;
  final cdnChannels = results[2] as List<_CdnChannel>;
  final cdnSports = results[3] as List<_CdnSportEvent>;

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
  for (final m in streamedMatches) {
    addMatchCat(m.category, isAlwaysOn: m.isAlwaysOn);
  }
  for (final e in cdnSports) {
    if (e.sport.isNotEmpty) addCat(e.sport);
  }
  cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return LiveMatchesPrimaryLoad(
    sports: cats,
    damiTvStreams: ppvStreams,
    streamedMatches: streamedMatches,
    cdnChannels: cdnChannels,
    cdnSports: cdnSports,
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

Future<LiveMatchesPrimaryLoad> _fetchLiveMatchesCdn() async {
  final results = await Future.wait([_fetchCdnChannels(), _fetchCdnSports()]);
  final channels = results[0] as List<_CdnChannel>;
  final sports = results[1] as List<_CdnSportEvent>;

  final seenCats = <String>{};
  final cats = <_Sport>[];
  for (final s in sports) {
    if (s.tournament.isNotEmpty && seenCats.add(s.tournament)) {
      cats.add(_Sport(id: s.tournament, name: s.tournament));
    }
  }

  return LiveMatchesPrimaryLoad(
    sports: cats,
    cdnChannels: channels,
    cdnSports: sports,
  );
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
