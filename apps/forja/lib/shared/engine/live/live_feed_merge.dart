import 'package:forja/shared/engine/live/live_fixture_match.dart';
import 'package:forja/shared/foundation/lib/match_event.dart';

/// Collapse same-fixture schedule rows across catalogs (Catalog = All).
///
/// Keeps opaque `sources[]` union + summed viewers. Prefer poster / structured
/// teams / more specific category on the surviving card.
List<Map<String, dynamic>> mergeLiveFeedMatchingRows(
  List<Map<String, dynamic>> rows,
) {
  if (rows.length < 2) return rows;
  final out = <Map<String, dynamic>>[];
  final buckets = <String, List<int>>{};

  for (final row in rows) {
    final map = Map<String, dynamic>.from(row);
    final m = MatchEvent.fromLegacyRow(map);
    final bucketKey = liveEventMergeBucketKey(
      homeTeam: m.homeTeam,
      awayTeam: m.awayTeam,
      title: m.title,
      alwaysOn: m.isAlwaysOn,
    );
    var merged = false;
    if (bucketKey != null) {
      final candidates = buckets[bucketKey];
      if (candidates != null) {
        for (final idx in candidates) {
          if (liveCatalogEventsSoftMatchMaps(out[idx], map)) {
            out[idx] = _mergeFeedRowPair(out[idx], map);
            merged = true;
            break;
          }
        }
      }
    }
    if (merged) continue;
    final storeKey = bucketKey ?? 'id:${m.id}';
    (buckets[storeKey] ??= []).add(out.length);
    out.add(map);
  }
  return out;
}

Map<String, dynamic> _mergeFeedRowPair(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final primary = _pickBetterFeedRow(a, b);
  final other = identical(primary, a) ? b : a;
  final out = Map<String, dynamic>.from(primary);

  final sources = <Map<String, dynamic>>[];
  final seen = <String>{};
  void addSources(Map<String, dynamic> row) {
    final raw = row['sources'];
    if (raw is! List) return;
    for (final s in raw) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(s);
      final source = (m['source'] ?? '').toString().trim();
      final id = (m['id'] ?? '').toString().trim();
      if (source.isEmpty || id.isEmpty) continue;
      if (source.toLowerCase() == 'echo') continue;
      final key = '$source|$id';
      if (!seen.add(key)) continue;
      sources.add({'source': source, 'id': id});
    }
  }

  addSources(primary);
  addSources(other);
  if (sources.isNotEmpty) out['sources'] = sources;

  final va = _viewersOf(primary);
  final vb = _viewersOf(other);
  if (va + vb > 0) out['viewers'] = va + vb;

  if (_posterOf(primary).isEmpty && _posterOf(other).isNotEmpty) {
    out['poster'] = other['poster'] ?? other['thumbnail'];
    if (other['thumbnail'] != null) out['thumbnail'] = other['thumbnail'];
  }

  final home = (out['homeTeam'] ?? '').toString().trim();
  final away = (out['awayTeam'] ?? '').toString().trim();
  if (home.isEmpty) {
    final o = (other['homeTeam'] ?? '').toString().trim();
    if (o.isNotEmpty) out['homeTeam'] = o;
  }
  if (away.isEmpty) {
    final o = (other['awayTeam'] ?? '').toString().trim();
    if (o.isNotEmpty) out['awayTeam'] = o;
  }

  if (primary['airing'] == true || other['airing'] == true) {
    out['airing'] = true;
  }
  if (primary['live'] == true || other['live'] == true) {
    out['live'] = true;
  }

  return out;
}

Map<String, dynamic> _pickBetterFeedRow(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final ma = MatchEvent.fromLegacyRow(a);
  final mb = MatchEvent.fromLegacyRow(b);
  if (ma.isLive != mb.isLive) return ma.isLive ? a : b;

  final posterA = _posterOf(a).isNotEmpty;
  final posterB = _posterOf(b).isNotEmpty;
  if (posterA != posterB) return posterA ? a : b;

  final catA = _categorySpecificity(ma.category);
  final catB = _categorySpecificity(mb.category);
  if (catA != catB) return catA > catB ? a : b;

  final srcA = ma.sources.length;
  final srcB = mb.sources.length;
  if (srcA != srcB) return srcA >= srcB ? a : b;

  if (ma.dateMs > 0 && mb.dateMs > 0 && ma.dateMs != mb.dateMs) {
    return ma.dateMs <= mb.dateMs ? a : b;
  }
  return a;
}

String _posterOf(Map<String, dynamic> row) =>
    (row['poster'] ?? row['thumbnail'] ?? '').toString().trim();

int _viewersOf(Map<String, dynamic> row) {
  final v = row['viewers'];
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

/// Prefer league names over bare sport labels (`football`).
int _categorySpecificity(String raw) {
  final t = raw.trim().toLowerCase().replaceAll('-', ' ');
  if (t.isEmpty) return 0;
  if (t == 'football' ||
      t == 'soccer' ||
      t == 'basketball' ||
      t == 'hockey' ||
      t == 'tennis' ||
      t == 'baseball' ||
      t == 'american football') {
    return 1;
  }
  return 2 + t.split(RegExp(r'\s+')).length;
}
