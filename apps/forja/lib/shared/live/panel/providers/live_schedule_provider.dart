part of '../live_sports_hub_page.dart';

/// Primary match-list fetch — catalog schedule only (RFC-073; no mode family).
final liveMatchesPrimaryLoadProvider =
    FutureProvider.autoDispose<_LiveMatchesPrimaryLoad>((ref) async {
  return _fetchLiveMatchesCatalog();
});

class _LiveMatchesPrimaryLoad {
  const _LiveMatchesPrimaryLoad({
    required this.sports,
    this.espnGames = const [],
  });

  final List<_Sport> sports;
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

/// Catalog schedule is filled by lazy Forja Live catalog kick — primary load is a no-op seed.
Future<_LiveMatchesPrimaryLoad> _fetchLiveMatchesCatalog() async {
  return const _LiveMatchesPrimaryLoad(sports: [], espnGames: []);
}
