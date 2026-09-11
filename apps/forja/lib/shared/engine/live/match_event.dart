import 'package:forja/shared/engine/live/match_team_parse.dart';
import 'package:forja/shared/engine/live/schedule_sport_filter.dart';

/// Optional host hook — Live Sports engine may mark catalogs as airing-only.
bool Function(String pluginId)? matchEventAiringOnlyLiveCheck;

/// Opaque source ref on a schedule / match row (plugin resolve input).
class MatchSourceRef {
  const MatchSourceRef({
    required this.source,
    required this.id,
    this.iframe = '',
  });

  final String source;
  final String id;
  final String iframe;

  factory MatchSourceRef.fromJson(Map<String, dynamic> j) => MatchSourceRef(
        source: (j['source'] ?? '').toString(),
        id: (j['id'] ?? '').toString(),
        iframe: (j['iframe'] ?? j['url'] ?? '').toString(),
      );
}

/// One stream mirror / embed row before native unlock.
class MatchStream {
  const MatchStream({
    required this.id,
    required this.streamNo,
    required this.language,
    required this.hd,
    required this.embedUrl,
    required this.source,
    required this.viewers,
    this.directPlayback = false,
    this.resolvedHeaders,
  });

  final String id;
  final int streamNo;
  final String language;
  final bool hd;
  final String embedUrl;
  final String source;
  final int viewers;
  final bool directPlayback;
  final Map<String, String>? resolvedHeaders;

  factory MatchStream.fromJson(Map<String, dynamic> j) => MatchStream(
        id: (j['id'] ?? '').toString(),
        streamNo: (j['streamNo'] as num?)?.toInt() ?? 0,
        language: (j['language'] ?? '').toString(),
        hd: j['hd'] == true,
        embedUrl: (j['embedUrl'] ?? j['embed_url'] ?? '').toString(),
        source: (j['source'] ?? '').toString(),
        viewers: parseLiveViewerCount(j['viewers']),
        directPlayback: j['directPlayback'] == true,
      );
}

/// Public match / fixture DTO for live resolve streams + IPTV portal matching.
class MatchEvent {
  const MatchEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.dateMs,
    required this.poster,
    required this.popular,
    this.airing = false,
    this.viewers = 0,
    this.homeTeam,
    this.homeBadge,
    this.awayTeam,
    this.awayBadge,
    required this.sources,
    this.inlineStreams = const [],
    this.catalog = '',
    this.stremioBaseUrl = '',
    this.stremioType = 'sport',
    this.stremioAddonName = '',
    this.sportMatchGame,
    this.livePluginId = '',
  });

  final String id;
  final String title;
  final String category;
  final int dateMs;
  final String poster;
  final bool popular;
  final bool airing;
  final int viewers;
  final String? homeTeam;
  final String? homeBadge;
  final String? awayTeam;
  final String? awayBadge;
  final List<MatchSourceRef> sources;
  final List<MatchStream> inlineStreams;
  final String catalog;
  final String stremioBaseUrl;
  final String stremioType;
  final String stremioAddonName;
  final Map<String, dynamic>? sportMatchGame;
  final String livePluginId;

  bool get isMut => catalog == 'mut';
  bool get isStremio => stremioBaseUrl.isNotEmpty;
  bool get isIptvSports => catalog == 'iptv_sports';
  bool get isForjaLive => catalog == 'forja_live';

  String get categoryLabel =>
      category.isEmpty ? 'Other' : category.replaceAll('-', ' ');

  bool get isAlwaysOn =>
      dateMs == 0 &&
      (sources.isNotEmpty ||
          inlineStreams.isNotEmpty ||
          (isStremio && (category == '24/7' || category == '24-7')));

  static int _liveWindowHours({required bool popular}) => popular ? 18 : 6;

  bool get isLive {
    if (isAlwaysOn || airing) return true;
    if (matchEventAiringOnlyLiveCheck?.call(livePluginId) == true) {
      return false;
    }
    if (dateMs <= 0) return false;
    final dt = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final now = DateTime.now();
    final delta = now.difference(dt);
    final maxHours = _liveWindowHours(popular: popular);
    return delta.inMinutes >= 0 && delta.inHours < maxHours;
  }

  MatchEvent copyWith({
    Map<String, dynamic>? sportMatchGame,
    String? homeTeam,
    String? awayTeam,
    String? homeBadge,
    String? awayBadge,
    bool? airing,
    List<MatchSourceRef>? sources,
    List<MatchStream>? inlineStreams,
    int? viewers,
    String? livePluginId,
  }) {
    return MatchEvent(
      id: id,
      title: title,
      category: category,
      dateMs: dateMs,
      poster: poster,
      popular: popular,
      airing: airing ?? this.airing,
      viewers: viewers ?? this.viewers,
      homeTeam: homeTeam ?? this.homeTeam,
      homeBadge: homeBadge ?? this.homeBadge,
      awayTeam: awayTeam ?? this.awayTeam,
      awayBadge: awayBadge ?? this.awayBadge,
      sources: sources ?? this.sources,
      inlineStreams: inlineStreams ?? this.inlineStreams,
      catalog: catalog,
      stremioBaseUrl: stremioBaseUrl,
      stremioType: stremioType,
      stremioAddonName: stremioAddonName,
      sportMatchGame: sportMatchGame ?? this.sportMatchGame,
      livePluginId: livePluginId ?? this.livePluginId,
    );
  }

  factory MatchEvent.fromJson(Map<String, dynamic> j) {
    final teams = j['teams'] as Map<String, dynamic>?;
    final home = teams?['home'] as Map<String, dynamic>?;
    final away = teams?['away'] as Map<String, dynamic>?;
    final title = (j['title'] ?? '').toString();
    final (parsedHome, parsedAway) = resolveLiveMatchTeams(
      homeTeam: home?['name'] as String?,
      awayTeam: away?['name'] as String?,
      title: title,
    );

    return MatchEvent(
      id: (j['id'] ?? '').toString(),
      title: title,
      category: (j['category'] ?? '').toString(),
      dateMs: (j['date'] as num?)?.toInt() ?? 0,
      poster: (j['poster'] ?? '').toString(),
      popular: j['popular'] == true,
      airing: j['airing'] == true,
      viewers: parseLiveViewerCount(j['viewers']),
      homeTeam: parsedHome.isEmpty ? null : parsedHome,
      homeBadge: home?['badge'] as String?,
      awayTeam: parsedAway.isEmpty ? null : parsedAway,
      awayBadge: away?['badge'] as String?,
      sources: (j['sources'] as List? ?? [])
          .map((s) => MatchSourceRef.fromJson(s as Map<String, dynamic>))
          .where(
            (s) =>
                s.source.isNotEmpty &&
                s.id.isNotEmpty &&
                s.source.trim().toLowerCase() != 'echo',
          )
          .toList(),
      inlineStreams: (j['streams'] as List? ?? [])
          .map((s) {
            try {
              return MatchStream.fromJson(s as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<MatchStream>()
          .where(
            (s) =>
                s.embedUrl.isNotEmpty &&
                s.source.trim().toLowerCase() != 'echo',
          )
          .toList(),
      catalog: (j['catalog'] ?? '').toString(),
      stremioBaseUrl: (j['stremioBaseUrl'] ?? '').toString(),
      stremioType: (j['stremioType'] ?? 'sport').toString(),
      stremioAddonName: (j['stremioAddonName'] ?? '').toString(),
      sportMatchGame: j['sportMatchGame'] is Map
          ? Map<String, dynamic>.from(j['sportMatchGame'] as Map)
          : null,
      livePluginId: (j['pluginId'] ?? j['livePluginId'] ?? '').toString(),
    );
  }

  /// Normalize kit [KitListEntry.legacyRow] then parse.
  ///
  /// Schedule catalogs may only carry opaque `sources[{source,id}]` resolve
  /// keys. Embed URLs / `streams[]` / `iframe` on catalog rows are dropped —
  /// live resolve packs own stream discovery (issue 254).
  factory MatchEvent.fromLegacyRow(Map<String, dynamic> row) {
    final normalized = normalizeMatchLegacyRow(row);
    final sourcesRaw = normalized['sources'];
    final refs = <Map<String, dynamic>>[];
    if (sourcesRaw is List) {
      for (final s in sourcesRaw) {
        if (s is! Map) continue;
        final m = Map<String, dynamic>.from(s);
        final source = (m['source'] ?? '').toString().trim();
        final id = (m['id'] ?? '').toString().trim();
        if (source.isEmpty || id.isEmpty) continue;
        if (source.toLowerCase() == 'echo') continue;
        refs.add({'source': source, 'id': id});
      }
    }
    final enriched = Map<String, dynamic>.from(normalized);
    enriched['sources'] = refs;
    // Catalog schedule rows never ship playable stream payloads.
    enriched.remove('streams');
    enriched.remove('iframe');
    if (normalized['homeTeam'] != null && enriched['teams'] == null) {
      enriched['teams'] = {
        'home': {
          'name': normalized['homeTeam'],
          'badge': normalized['homeBadge'] ?? '',
        },
        'away': {
          'name': normalized['awayTeam'],
          'badge': normalized['awayBadge'] ?? '',
        },
      };
    }
    return MatchEvent.fromJson(enriched);
  }
}

/// Kit schedule row → wire shape expected by [MatchEvent.fromJson].
Map<String, dynamic> normalizeMatchLegacyRow(Map<String, dynamic> row) {
  final out = Map<String, dynamic>.from(row);
  final title = (out['title'] ?? out['name'] ?? out['event'] ?? '')
      .toString()
      .trim();
  if (title.isNotEmpty) out['title'] = title;
  if ((out['category'] ?? '').toString().trim().isEmpty) {
    final genres = out['genres'];
    if (genres is List && genres.isNotEmpty) {
      out['category'] = genres.first.toString();
    } else if ((out['badge'] ?? '').toString().trim().isNotEmpty) {
      out['category'] = out['badge'].toString();
    }
  }
  out['airing'] = out['airing'] == true ||
      out['live'] == true ||
      (out['status'] ?? '').toString().toLowerCase() == 'live';
  if ((out['catalog'] ?? '').toString().isEmpty) {
    out['catalog'] = 'forja_live';
  }
  final plugin = (out['livePluginId'] ?? out['pluginId'] ?? '').toString();
  if (plugin.isNotEmpty) out['livePluginId'] = plugin;
  if (out['date'] == null) {
    final starts = (out['starts_at'] ?? out['startsAt'] ?? '').toString();
    final asInt = int.tryParse(starts);
    if (asInt != null) {
      out['date'] = asInt > 20000000000 ? asInt : asInt * 1000;
    } else {
      final dt = DateTime.tryParse(starts);
      if (dt != null) out['date'] = dt.millisecondsSinceEpoch;
    }
  }
  return out;
}

/// Prefer per-stream viewers; fall back to catalog-level.
int effectiveMatchStreamViewers(MatchStream stream, MatchEvent match) =>
    stream.viewers > 0 ? stream.viewers : match.viewers;

/// Providers / details header total.
///
/// Sums each row's own viewer count. When a row has no per-stream count, counts
/// that catalog's match-level audience at most once (avoids N× merged total).
int sumListedLiveStreamViewers({
  required Iterable<({int streamViewers, String catalogKey, int catalogViewers})>
      rows,
}) {
  var total = 0;
  final countedCatalogFallback = <String>{};
  for (final row in rows) {
    if (row.streamViewers > 0) {
      total += row.streamViewers;
      continue;
    }
    if (row.catalogViewers <= 0) continue;
    final key = row.catalogKey.trim();
    if (key.isEmpty || !countedCatalogFallback.add(key)) continue;
    total += row.catalogViewers;
  }
  return total;
}

String matchTextKey(String raw) {
  var value = foldLiveMatchLatin(raw.toLowerCase());
  const aliases = {
    '&': ' and ',
    'women': ' w ',
    'womens': ' w ',
    'woman': ' w ',
  };
  for (final alias in aliases.entries) {
    value = value.replaceAll(alias.key, alias.value);
  }
  final tokens = value
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where(
        (token) =>
            token.isNotEmpty &&
            token != 'fc' &&
            token != 'sc' &&
            token != 'w' &&
            token != 'at' &&
            token != 'vs' &&
            token != 'versus' &&
            token != 'v' &&
            !_genericIptvTeamTokens.contains(token),
      )
      .toList()
    ..sort();
  return tokens.join(' ');
}

const _genericIptvTeamTokens = {
  'city',
  'united',
  'town',
  'rovers',
  'county',
  'club',
  'deportivo',
  'atletico',
  'athletico',
  'athletic',
  'wanderers',
  'albion',
  'villa',
  'forest',
  'palace',
  'north',
  'south',
  'west',
  'east',
  'sport',
  'sports',
  'real',
  'inter',
  'sporting',
};

String? matchTeamPairKey(String? home, String? away) {
  if (home == null || away == null || home.isEmpty || away.isEmpty) return null;
  final teams = [matchTextKey(home), matchTextKey(away)]..sort();
  if (teams.any((team) => team.isEmpty)) return null;
  return teams.join('|');
}

String? matchTeamPairKeyFromCatalog({
  required String? homeTeam,
  required String? awayTeam,
  required String title,
}) {
  final (home, away) = resolveLiveMatchTeams(
    homeTeam: homeTeam,
    awayTeam: awayTeam,
    title: title,
  );
  return matchTeamPairKey(
    home.isEmpty ? null : home,
    away.isEmpty ? null : away,
  );
}

/// Stable fixture key for IPTV / Providers caches.
String matchEventViewerKey(MatchEvent match) {
  final teams = matchTeamPairKeyFromCatalog(
    homeTeam: match.homeTeam,
    awayTeam: match.awayTeam,
    title: match.title,
  );
  if (teams != null) return 't:$teams';
  final title = matchTextKey(match.title);
  if (title.isNotEmpty && match.dateMs > 0) {
    return 'n:$title@${match.dateMs ~/ 60000}';
  }
  if (title.isNotEmpty) return 'n:$title';
  return 'id:${match.id}';
}

/// Resolve row `name` / `title` → language + HD flags.
({String language, bool hd}) forjaLiveStreamFieldsFromRowName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return (language: '', hd: false);
  final match = RegExp(
    r'\b(FHD|UHD|HD|4K|SD)\b',
    caseSensitive: false,
  ).firstMatch(name);
  final token = match?.group(1)?.toUpperCase();
  final hd = token != null && token != 'SD';
  return (language: name, hd: hd);
}
