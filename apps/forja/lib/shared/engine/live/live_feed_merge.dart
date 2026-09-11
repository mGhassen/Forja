import 'package:forja/shared/engine/live/live_fixture_match.dart';
import 'package:forja/shared/host/live_sports/match_event.dart';
import 'package:forja/shared/host/live_sports/schedule_sport_filter.dart';

/// Broadcast channel names from a schedule row (`sportMatchGame` and/or top-level).
List<String> liveBroadcastChannelsFromRow(Map<String, dynamic> row) {
  final out = <String>[];
  final seen = <String>{};
  void addAll(Object? raw) {
    if (raw is! List) return;
    for (final item in raw) {
      final name = item.toString().trim();
      if (name.isEmpty) continue;
      if (!seen.add(name.toLowerCase())) continue;
      out.add(name);
    }
  }

  addAll(row['broadcastChannels']);
  addAll(row['broadcast_channels']);
  final game = row['sportMatchGame'];
  if (game is Map) {
    addAll(game['broadcastChannels']);
    addAll(game['broadcast_channels']);
  }
  return out;
}

/// Union [extra] into [game]'s `broadcastChannels` (case-insensitive dedupe).
Map<String, dynamic> withLiveBroadcastChannels(
  Map<String, dynamic> game,
  Iterable<String> extra,
) {
  final out = Map<String, dynamic>.from(game);
  final merged = <String>[];
  final seen = <String>{};
  void add(String name) {
    final t = name.trim();
    if (t.isEmpty) return;
    if (!seen.add(t.toLowerCase())) return;
    merged.add(t);
  }

  final existing = out['broadcastChannels'] ?? out['broadcast_channels'];
  if (existing is List) {
    for (final item in existing) {
      add(item.toString());
    }
  }
  for (final name in extra) {
    add(name);
  }
  if (merged.isNotEmpty) {
    out['broadcastChannels'] = merged;
    out.remove('broadcast_channels');
  }
  return out;
}

/// Collapse same-fixture schedule rows across catalogs (Catalog = All).
///
/// Keeps opaque `sources[]` union + summed viewers + guide `broadcastChannels`
/// (Live TV IPTV matching). Prefer poster / structured teams / more specific
/// category on the surviving card.
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
  if ((out['homeBadge'] ?? '').toString().trim().isEmpty) {
    final o = (other['homeBadge'] ?? '').toString().trim();
    if (o.isNotEmpty) out['homeBadge'] = o;
  }
  if ((out['awayBadge'] ?? '').toString().trim().isEmpty) {
    final o = (other['awayBadge'] ?? '').toString().trim();
    if (o.isNotEmpty) out['awayBadge'] = o;
  }

  if (primary['airing'] == true || other['airing'] == true) {
    out['airing'] = true;
  }
  if (primary['live'] == true || other['live'] == true) {
    out['live'] = true;
  }

  _mergeSportMatchGame(out, primary, other);

  return out;
}

void _mergeSportMatchGame(
  Map<String, dynamic> out,
  Map<String, dynamic> primary,
  Map<String, dynamic> other,
) {
  final channels = [
    ...liveBroadcastChannelsFromRow(primary),
    ...liveBroadcastChannelsFromRow(other),
  ];
  final a = primary['sportMatchGame'];
  final b = other['sportMatchGame'];
  final Map<String, dynamic>? base;
  if (a is Map && b is Map) {
    // Prefer the game that already carries guide channel names.
    final aCh = liveBroadcastChannelsFromRow({'sportMatchGame': a});
    final bCh = liveBroadcastChannelsFromRow({'sportMatchGame': b});
    final preferA = aCh.length >= bCh.length;
    base = Map<String, dynamic>.from(preferA ? a : b);
    final filler = preferA ? b : a;
    for (final key in ['homeTeam', 'awayTeam', 'title', 'sport', 'category']) {
      final cur = (base[key] ?? '').toString().trim();
      if (cur.isNotEmpty) continue;
      final alt = (filler[key] ?? '').toString().trim();
      if (alt.isNotEmpty) base[key] = alt;
    }
  } else if (a is Map) {
    base = Map<String, dynamic>.from(a);
  } else if (b is Map) {
    base = Map<String, dynamic>.from(b);
  } else if (channels.isEmpty) {
    return;
  } else {
    base = {
      'id': (out['id'] ?? '').toString(),
      'title': (out['title'] ?? out['name'] ?? '').toString(),
      'homeTeam': (out['homeTeam'] ?? '').toString(),
      'awayTeam': (out['awayTeam'] ?? '').toString(),
      'sport': (out['category'] ?? out['sport'] ?? '').toString(),
      'category': (out['category'] ?? out['sport'] ?? '').toString(),
    };
  }

  final merged = withLiveBroadcastChannels(base, channels);
  out['sportMatchGame'] = merged;
  final list = merged['broadcastChannels'];
  if (list is List && list.isNotEmpty) {
    out['broadcastChannels'] = List<String>.from(list.map((e) => e.toString()));
  }
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

int _viewersOf(Map<String, dynamic> row) =>
    parseLiveViewerCount(row['viewers']);

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
