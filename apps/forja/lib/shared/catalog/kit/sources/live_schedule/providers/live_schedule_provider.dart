part of '../live_sports_hub_page.dart';

/// Primary match-list fetch keyed by server mode.
final liveMatchesPrimaryLoadProvider = FutureProvider.autoDispose
    .family<_LiveMatchesPrimaryLoad, _LiveMatchesServer>((ref, server) async {
      switch (server) {
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
    this.iframeCatalogStreams = const [],
    this.streamedMatches = const [],
    this.espnGames = const [],
  });

  final List<_Sport> sports;
  final List<_IframeCatalogStream> iframeCatalogStreams;
  final List<_StreamedMatch> streamedMatches;
  /// Raw ESPN scoreboard rows for My IPTV play-time enrichment.
  final List<Map<String, dynamic>> espnGames;
}

_StreamedMatch _forjaLiveRowToMatch(Map<String, dynamic> j) {
  final sourcesRaw = j['sources'];
  final inline = <Map<String, dynamic>>[];
  final refs = <Map<String, dynamic>>[];
  if (sourcesRaw is List) {
    for (final s in sourcesRaw) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(s);
      final url = (m['url'] ?? m['iframe'] ?? '').toString();
      if (url.isNotEmpty) {
        inline.add({
          'id': m['id'] ?? '',
          'streamNo': 1,
          'language': '',
          'hd': false,
          'embedUrl': url,
          'source': m['source'] ?? '',
          'viewers': parseLiveViewerCount(m['viewers']),
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

Future<_LiveMatchesPrimaryLoad> _fetchLiveMatchesForjaLive() async {
  return const _LiveMatchesPrimaryLoad(sports: [], espnGames: []);
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

/// Forja Sports schedule = same enabled Catalog JS as Forja Live;
/// play still matches Xtream.
Future<_LiveMatchesPrimaryLoad> _fetchLiveMatchesIptvSports() async {
  return const _LiveMatchesPrimaryLoad(sports: [], espnGames: []);
}
