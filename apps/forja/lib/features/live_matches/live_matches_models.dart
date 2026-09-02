part of 'live_matches_screen.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

/// Leanback TV — not desktop D-pad (which also uses focusable mood chips).
bool _liveMatchesLeanbackOnly(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity;

/// Grid (card catalog) vs vertical timeline layout for the body.
enum _LiveMatchesView { grid, timeline }

/// Time window that one screen height of the timeline rail represents.
enum _TimelineGranularity { day, h12, h6, h3 }

int _timelineSpanHours(_TimelineGranularity g) => switch (g) {
  _TimelineGranularity.day => 24,
  _TimelineGranularity.h12 => 12,
  _TimelineGranularity.h6 => 6,
  _TimelineGranularity.h3 => 3,
};

String _timelineGranularityLabel(_TimelineGranularity g) => switch (g) {
  _TimelineGranularity.day => 'Day',
  _TimelineGranularity.h12 => '12h',
  _TimelineGranularity.h6 => '6h',
  _TimelineGranularity.h3 => '3h',
};

String _liveMatchClockHm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

/// Card caption above the title — `18:00 – 20:00` or kickoff-only when no end.
String _liveMatchScheduleLabel({
  int startsAtSec = 0,
  int endsAtSec = 0,
  int dateMs = 0,
  bool alwaysOn = false,
}) {
  if (alwaysOn) return '';
  if (startsAtSec > 0) {
    final start = DateTime.fromMillisecondsSinceEpoch(startsAtSec * 1000);
    final startLabel = _liveMatchClockHm(start);
    if (endsAtSec > startsAtSec) {
      final end = DateTime.fromMillisecondsSinceEpoch(endsAtSec * 1000);
      return '$startLabel – ${_liveMatchClockHm(end)}';
    }
    return startLabel;
  }
  if (dateMs > 0) {
    return _liveMatchClockHm(DateTime.fromMillisecondsSinceEpoch(dateMs));
  }
  return '';
}

class _Sport {
  final String id;
  final String name;
  const _Sport({required this.id, required this.name});
}

/// Canonical sport chip id across PPV / Streamed label variants.
///
/// PPV uses Title Case (`American Football`); Streamed uses kebab slugs
/// (`american-football`).
String _normalizeSportId(String raw) => normalizeLiveSportId(raw);

String _sportDisplayName(String raw, String normalizedId) =>
    liveSportDisplayName(raw, normalizedId);

bool _is247Item({required String category, required bool isAlwaysOn}) =>
    isLive247Item(category: category, isAlwaysOn: isAlwaysOn);

bool _includeInSportFilter({
  required String category,
  required bool isAlwaysOn,
  required String sportFilter,
}) => includeLiveMatchInSportFilter(
  category: category,
  isAlwaysOn: isAlwaysOn,
  sportFilter: sportFilter,
);

class _DamiTvStream {
  final String id;
  final String name;
  final String poster;
  final int startsAt;
  final int endsAt;
  final String categoryName;
  final String status;
  final String league;
  final String? homeTeam;
  final String? homeBadge = null;
  final String? awayTeam;
  final String? awayBadge = null;
  final int viewers;
  final String iframe;

  /// PPV `always_live` - 24/7 channels keep stale start/end windows.
  final bool alwaysLive;

  const _DamiTvStream({
    required this.id,
    required this.name,
    required this.poster,
    required this.startsAt,
    required this.endsAt,
    required this.categoryName,
    required this.status,
    required this.league,
    required this.viewers,
    required this.iframe,
    this.homeTeam,
    this.awayTeam,
    this.alwaysLive = false,
  });

  /// Playable 24/7 channel - PPV often leaves expired `starts_at`/`ends_at`
  /// while setting `always_live` (and/or category `24/7 Streams`).
  bool get isAlwaysOn => ppvStreamIsAlwaysOn(
    alwaysLive: alwaysLive,
    categoryName: categoryName,
    startsAt: startsAt,
    endsAt: endsAt,
    hasIframe: iframe.isNotEmpty,
  );

  String get timeLabel {
    if (isLive) return 'live';

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (startsAt > now) {
      return _liveMatchClockHm(
        DateTime.fromMillisecondsSinceEpoch(startsAt * 1000),
      );
    }
    return '';
  }

  String get scheduleLabel => _liveMatchScheduleLabel(
    startsAtSec: startsAt,
    endsAtSec: endsAt,
    alwaysOn: isAlwaysOn,
  );

  bool get isLive => ppvStreamIsLive(
    isAlwaysOn: isAlwaysOn,
    status: status,
    startsAt: startsAt,
    endsAt: endsAt,
    viewers: viewers,
  );
}

class _StreamedSourceRef {
  final String source;
  final String id;
  final String iframe;

  const _StreamedSourceRef({
    required this.source,
    required this.id,
    this.iframe = '',
  });

  factory _StreamedSourceRef.fromJson(Map<String, dynamic> j) =>
      _StreamedSourceRef(
        source: (j['source'] ?? '').toString(),
        id: (j['id'] ?? '').toString(),
        iframe: (j['iframe'] ?? '').toString(),
      );
}

class _StreamedMatch {
  final String id;
  final String title;
  final String category;
  final int dateMs;
  final String poster;
  final bool popular;

  /// From Streamed `/api/matches/live` (engine tags `airing: true`).
  final bool airing;

  /// Catalog-level concurrent viewers when the site exposes them (0 = unknown).
  final int viewers;
  final String? homeTeam;
  final String? homeBadge;
  final String? awayTeam;
  final String? awayBadge;
  final List<_StreamedSourceRef> sources;

  /// MutStreams embeds are already on the schedule row — skip `/api/stream`.
  final List<_StreamedStream> inlineStreams;

  /// `mut` when from MutStreams; empty/streamed otherwise.
  final String catalog;

  /// Non-empty → resolve via Stremio `/stream/{type}/{id}.json` (HLS).
  final String stremioBaseUrl;
  final String stremioType;

  /// ESPN game payload for My IPTV stream matching (RFC-062).
  final Map<String, dynamic>? sportMatchGame;

  /// Forja live engine plugin id when [catalog] is `forja_live`.
  final String livePluginId;

  const _StreamedMatch({
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
    this.sportMatchGame,
    this.livePluginId = '',
  });

  bool get isMut => catalog == 'mut' || inlineStreams.isNotEmpty;

  bool get isStremio => stremioBaseUrl.isNotEmpty;

  bool get isIptvSports => catalog == 'iptv_sports';

  bool get isForjaLive => catalog == 'forja_live';

  factory _StreamedMatch.fromJson(Map<String, dynamic> j) {
    final teams = j['teams'] as Map<String, dynamic>?;
    final home = teams?['home'] as Map<String, dynamic>?;
    final away = teams?['away'] as Map<String, dynamic>?;
    final title = (j['title'] ?? '').toString();
    final (parsedHome, parsedAway) = resolveLiveMatchTeams(
      homeTeam: home?['name'] as String?,
      awayTeam: away?['name'] as String?,
      title: title,
    );

    return _StreamedMatch(
      id: (j['id'] ?? '').toString(),
      title: title,
      category: (j['category'] ?? '').toString(),
      dateMs: (j['date'] as num?)?.toInt() ?? 0,
      poster: (j['poster'] ?? '').toString(),
      popular: j['popular'] == true,
      airing: j['airing'] == true,
      viewers: parsePpvViewers(j['viewers']),
      homeTeam: parsedHome.isEmpty ? null : parsedHome,
      homeBadge: home?['badge'] as String?,
      awayTeam: parsedAway.isEmpty ? null : parsedAway,
      awayBadge: away?['badge'] as String?,
      sources: (j['sources'] as List? ?? [])
          .map((s) => _StreamedSourceRef.fromJson(s as Map<String, dynamic>))
          .where(
            (s) =>
                s.source.isNotEmpty &&
                s.id.isNotEmpty &&
                // streamed.pk lists echo in match metadata but `/api/stream/echo/…`
                // is empty and the site UI never offers it — hide like the website.
                s.source.trim().toLowerCase() != 'echo',
          )
          .toList(),
      inlineStreams: (j['streams'] as List? ?? [])
          .map((s) {
            try {
              return _StreamedStream.fromJson(s as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<_StreamedStream>()
          .where(
            (s) =>
                s.embedUrl.isNotEmpty &&
                s.source.trim().toLowerCase() != 'echo',
          )
          .toList(),
      catalog: (j['catalog'] ?? '').toString(),
      stremioBaseUrl: (j['stremioBaseUrl'] ?? '').toString(),
      stremioType: (j['stremioType'] ?? 'sport').toString(),
      sportMatchGame: j['sportMatchGame'] is Map
          ? Map<String, dynamic>.from(j['sportMatchGame'] as Map)
          : null,
      livePluginId: (j['pluginId'] ?? j['livePluginId'] ?? '').toString(),
    );
  }

  String get categoryLabel =>
      category.isEmpty ? 'Other' : category.replaceAll('-', ' ');

  bool get isAlwaysOn =>
      dateMs == 0 &&
      (sources.isNotEmpty ||
          inlineStreams.isNotEmpty ||
          (isStremio &&
              (id.startsWith('leaf:') ||
                  category == '24/7' ||
                  category == '24-7')));

  /// Hours after start that still count as live when Streamed did not tag
  /// `airing`. Popular rows (golf, cycling) often outlast the short window.
  static int _liveWindowHours({required bool popular}) => popular ? 18 : 6;

  String get timeLabel {
    if (isLive) return 'live';

    if (dateMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final now = DateTime.now();
    if (dt.isAfter(now)) {
      return _liveMatchClockHm(dt);
    }
    return '';
  }

  String get scheduleLabel => _liveMatchScheduleLabel(
    dateMs: dateMs,
    alwaysOn: isAlwaysOn,
  );

  bool get isLive {
    if (isAlwaysOn || airing) return true;
    // Catalogs with airingOnlyLive (e.g. WatchFooty) set airing from API status
    // (incl. stream-less). Don't fake LIVE for every kickoff in the last 6h.
    if (LiveMatchesEngine.cachedAiringOnlyLive(livePluginId)) return false;

    if (dateMs <= 0) return false;
    final dt = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final now = DateTime.now();
    final delta = now.difference(dt);
    final maxHours = _liveWindowHours(popular: popular);
    return delta.inMinutes >= 0 && delta.inHours < maxHours;
  }
}

class _StreamedStream {
  final String id;
  final int streamNo;
  final String language;
  final bool hd;
  final String embedUrl;
  final String source;
  final int viewers;

  const _StreamedStream({
    required this.id,
    required this.streamNo,
    required this.language,
    required this.hd,
    required this.embedUrl,
    required this.source,
    required this.viewers,
  });

  factory _StreamedStream.fromJson(Map<String, dynamic> j) => _StreamedStream(
    id: (j['id'] ?? '').toString(),
    streamNo: (j['streamNo'] as num?)?.toInt() ?? 0,
    language: (j['language'] ?? '').toString(),
    hd: j['hd'] == true,
    embedUrl: (j['embedUrl'] ?? j['embed_url'] ?? '').toString(),
    source: (j['source'] ?? '').toString(),
    viewers: parsePpvViewers(j['viewers']),
  );
}

/// Resolve row `name` / `title` from Forja Live plugins into panel fields.
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

/// Prefer per-stream viewers; fall back to catalog-level when the site only
/// reports audience on the match (StreamFree / TimStreams / PPV).
int _effectiveStreamViewers(_StreamedStream stream, _StreamedMatch match) =>
    stream.viewers > 0 ? stream.viewers : match.viewers;

/// Sheet header total: sum every stream's own viewers, plus each catalog's
/// match-level audience once when that catalog's rows have no per-stream count.
int _sheetTotalViewers(Iterable<_StreamedStreamChoice> choices) {
  var total = 0;
  final countedCatalogFallback = <String>{};
  for (final c in choices) {
    if (c.stream.viewers > 0) {
      total += c.stream.viewers;
      continue;
    }
    if (c.catalogMatch.viewers <= 0) continue;
    final key = '${c.catalogMatch.livePluginId}:${c.catalogMatch.id}';
    if (!countedCatalogFallback.add(key)) continue;
    total += c.catalogMatch.viewers;
  }
  return total;
}

/// Catalog row in the stream picker — may be unresolved until the user selects it.
class _StreamedStreamChoice {
  const _StreamedStreamChoice({
    required this.catalogMatch,
    required this.stream,
  });

  final _StreamedMatch catalogMatch;
  final _StreamedStream stream;

  bool get needsResolve => stream.embedUrl.trim().isEmpty;
}

int _liveFirstCompare({
  required bool aLive,
  required bool bLive,
  required int aStart,
  required int bStart,
  int aViewers = 0,
  int bViewers = 0,
}) {
  if (aLive != bLive) return aLive ? -1 : 1;
  // PPV Live now orders by audience; keep the busiest airing cards first.
  if (aLive && bLive && aViewers != bViewers) {
    return bViewers.compareTo(aViewers);
  }
  return aStart.compareTo(bStart);
}

List<_DamiTvStream> _sortDamiTvLiveFirst(List<_DamiTvStream> items) {
  final sorted = List<_DamiTvStream>.from(items);
  sorted.sort(
    (a, b) => _liveFirstCompare(
      aLive: a.isLive,
      bLive: b.isLive,
      aStart: a.startsAt,
      bStart: b.startsAt,
      aViewers: a.viewers,
      bViewers: b.viewers,
    ),
  );
  return sorted;
}

/// Max Forja Live catalog rows ingested per plugin (safety cap).
const _kForjaLiveCatalogMaxPerPlugin = 100;

/// Status axis of the schedule sheet (airing vs upcoming).
enum _LiveMatchesScheduleStatus { airing, upcoming, both }

/// How far ahead to ingest / show upcoming kickoffs.
enum _LiveMatchesScheduleHorizon { h1, h3, h6, h24 }

int _liveMatchesScheduleHorizonRank(_LiveMatchesScheduleHorizon horizon) =>
    switch (horizon) {
      _LiveMatchesScheduleHorizon.h1 => 1,
      _LiveMatchesScheduleHorizon.h3 => 2,
      _LiveMatchesScheduleHorizon.h6 => 3,
      _LiveMatchesScheduleHorizon.h24 => 4,
    };

String _liveMatchesScheduleHorizonLabel(_LiveMatchesScheduleHorizon horizon) =>
    switch (horizon) {
      _LiveMatchesScheduleHorizon.h1 => '1h',
      _LiveMatchesScheduleHorizon.h3 => '3h',
      _LiveMatchesScheduleHorizon.h6 => '6h',
      _LiveMatchesScheduleHorizon.h24 => '24h',
    };

String _liveMatchesScheduleStatusLabel(_LiveMatchesScheduleStatus status) =>
    switch (status) {
      _LiveMatchesScheduleStatus.airing => 'Airing',
      _LiveMatchesScheduleStatus.upcoming => 'Upcoming',
      _LiveMatchesScheduleStatus.both => 'Airing + upcoming',
    };

/// Top-bar chip: Airing · Next · 3h · 1h (both+1h).
String _liveMatchesScheduleChipLabel({
  required _LiveMatchesScheduleStatus status,
  required _LiveMatchesScheduleHorizon horizon,
}) {
  final h = _liveMatchesScheduleHorizonLabel(horizon);
  return switch (status) {
    _LiveMatchesScheduleStatus.airing => 'Airing',
    _LiveMatchesScheduleStatus.upcoming => 'Next · $h',
    _LiveMatchesScheduleStatus.both => h,
  };
}

({Duration past, Duration future}) _liveMatchesScheduleHorizonRange(
  _LiveMatchesScheduleHorizon horizon,
) =>
    switch (horizon) {
      _LiveMatchesScheduleHorizon.h1 => (
        past: const Duration(hours: 1),
        future: const Duration(hours: 1),
      ),
      _LiveMatchesScheduleHorizon.h3 => (
        past: const Duration(hours: 3),
        future: const Duration(hours: 3),
      ),
      _LiveMatchesScheduleHorizon.h6 => (
        past: const Duration(hours: 3),
        future: const Duration(hours: 6),
      ),
      _LiveMatchesScheduleHorizon.h24 => (
        past: const Duration(hours: 3),
        future: const Duration(hours: 24),
      ),
    };

_LiveMatchesScheduleHorizon? _liveMatchesScheduleHorizonFromPref(String? raw) {
  return switch (raw) {
    '1h' => _LiveMatchesScheduleHorizon.h1,
    '3h' => _LiveMatchesScheduleHorizon.h3,
    '6h' => _LiveMatchesScheduleHorizon.h6,
    '24h' || 'all' => _LiveMatchesScheduleHorizon.h24,
    _ => null,
  };
}

_LiveMatchesScheduleStatus? _liveMatchesScheduleStatusFromPref(String? raw) {
  return switch (raw) {
    'airing' || 'live' => _LiveMatchesScheduleStatus.airing,
    'upcoming' => _LiveMatchesScheduleStatus.upcoming,
    'both' => _LiveMatchesScheduleStatus.both,
    _ => null,
  };
}

/// Pref format: `status|horizon` (e.g. `both|1h`). Migrates v1 `live|1h|…`.
({_LiveMatchesScheduleStatus status, _LiveMatchesScheduleHorizon horizon})?
    _liveMatchesScheduleFromPref(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('|');
  if (parts.length == 2) {
    final status = _liveMatchesScheduleStatusFromPref(parts[0]);
    final horizon = _liveMatchesScheduleHorizonFromPref(parts[1]);
    if (status != null && horizon != null) {
      return (status: status, horizon: horizon);
    }
  }
  // v1 single-token prefs
  return switch (raw) {
    'live' => (
        status: _LiveMatchesScheduleStatus.airing,
        horizon: _LiveMatchesScheduleHorizon.h1,
      ),
    '1h' => (
        status: _LiveMatchesScheduleStatus.both,
        horizon: _LiveMatchesScheduleHorizon.h1,
      ),
    '3h' => (
        status: _LiveMatchesScheduleStatus.both,
        horizon: _LiveMatchesScheduleHorizon.h3,
      ),
    '6h' => (
        status: _LiveMatchesScheduleStatus.both,
        horizon: _LiveMatchesScheduleHorizon.h6,
      ),
    'all' => (
        status: _LiveMatchesScheduleStatus.both,
        horizon: _LiveMatchesScheduleHorizon.h24,
      ),
    _ => null,
  };
}

String _liveMatchesSchedulePref({
  required _LiveMatchesScheduleStatus status,
  required _LiveMatchesScheduleHorizon horizon,
}) =>
    '${switch (status) {
      _LiveMatchesScheduleStatus.airing => 'airing',
      _LiveMatchesScheduleStatus.upcoming => 'upcoming',
      _LiveMatchesScheduleStatus.both => 'both',
    }}|${_liveMatchesScheduleHorizonLabel(horizon).toLowerCase()}';

bool _kickoffInScheduleFilter({
  required int epochMs,
  required _LiveMatchesScheduleStatus status,
  required _LiveMatchesScheduleHorizon horizon,
  required bool alwaysOn,
  required bool liveOrAiring,
}) {
  final isLiveNow = alwaysOn || liveOrAiring;
  switch (status) {
    case _LiveMatchesScheduleStatus.airing:
      return isLiveNow;
    case _LiveMatchesScheduleStatus.upcoming:
      if (isLiveNow) return false;
      break;
    case _LiveMatchesScheduleStatus.both:
      if (isLiveNow) return true;
      break;
  }
  if (epochMs <= 0) return false;
  final ms = epochMs >= 1000000000000 ? epochMs : epochMs * 1000;
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final range = _liveMatchesScheduleHorizonRange(horizon);
  return !dt.isBefore(now.subtract(range.past)) &&
      !dt.isAfter(now.add(range.future));
}

String _liveCatalogPluginIdFromRow(
  Map<String, dynamic> row, {
  String fallback = '',
}) =>
    EngineService.normalizeLiveSportPluginId(
      (row['pluginId'] ?? row['livePluginId'] ?? fallback).toString(),
    );

_LiveMatchesScheduleHorizon _widerScheduleHorizon(
  _LiveMatchesScheduleHorizon a,
  _LiveMatchesScheduleHorizon b,
) =>
    _liveMatchesScheduleHorizonRank(a) >= _liveMatchesScheduleHorizonRank(b)
        ? a
        : b;

bool _liveCatalogRowMatchesFilter(_StreamedMatch row, String filter) {
  if (filter == 'all' || filter.isEmpty) return true;
  return EngineService.normalizeLiveSportPluginId(row.livePluginId) ==
      EngineService.normalizeLiveSportPluginId(filter);
}

/// Grid rows for one catalog chip — only that plugin's schedule rows (not
/// cross-catalog siblings merged into another plugin's card).
List<_StreamedMatch> _streamedMatchesForCatalogGrid(
  List<_StreamedMatch> pool,
  String catalogFilter,
) {
  if (catalogFilter == 'all' || catalogFilter.isEmpty) {
    return _mergeStreamedCatalogRows(_sortStreamedLiveFirst(pool));
  }
  final norm = EngineService.normalizeLiveSportPluginId(catalogFilter);
  final scoped = pool
      .where(
        (m) => EngineService.normalizeLiveSportPluginId(m.livePluginId) == norm,
      )
      .toList();
  return _mergeStreamedCatalogRows(_sortStreamedLiveFirst(scoped));
}

/// When a pack declares `scheduleHorizon: fullDay`, widen display for its rows.
_LiveMatchesScheduleHorizon _scheduleHorizonForCatalogMatch(
  _StreamedMatch match, {
  required _LiveMatchesScheduleHorizon horizon,
  required String catalogFilter,
}) {
  if (catalogFilter == 'all' || catalogFilter.isEmpty) return horizon;
  if (!_liveCatalogRowMatchesFilter(match, catalogFilter)) return horizon;
  final filterId = EngineService.normalizeLiveSportPluginId(catalogFilter);
  if (LiveMatchesEngine.cachedScheduleFullDay(filterId)) {
    return _widerScheduleHorizon(horizon, _LiveMatchesScheduleHorizon.h24);
  }
  return horizon;
}

/// Catalog ingest uses horizon as both (cache upcoming for status switches).
bool _forjaLiveCatalogRowInHorizon(
  Map<String, dynamic> row,
  _LiveMatchesScheduleHorizon horizon, {
  String pluginId = '',
}) {
  final pid = _liveCatalogPluginIdFromRow(row, fallback: pluginId);
  if (LiveMatchesEngine.cachedScheduleFullDay(pid)) return true;
  final raw = (row['date'] as num?)?.toInt() ?? 0;
  if (raw <= 0) {
    return row['airing'] == true || row['popular'] == true;
  }
  return _kickoffInScheduleFilter(
    epochMs: raw,
    status: _LiveMatchesScheduleStatus.both,
    horizon: horizon,
    alwaysOn: false,
    liveOrAiring: row['airing'] == true || row['popular'] == true,
  );
}

bool _streamedMatchInScheduleFilter(
  _StreamedMatch match, {
  required _LiveMatchesScheduleStatus status,
  required _LiveMatchesScheduleHorizon horizon,
}) =>
    _kickoffInScheduleFilter(
      epochMs: match.dateMs,
      status: status,
      horizon: horizon,
      alwaysOn: match.isAlwaysOn,
      liveOrAiring: match.isLive || match.airing,
    );

bool _damiTvInScheduleFilter(
  _DamiTvStream stream, {
  required _LiveMatchesScheduleStatus status,
  required _LiveMatchesScheduleHorizon horizon,
}) =>
    _kickoffInScheduleFilter(
      epochMs: stream.startsAt > 0 ? stream.startsAt * 1000 : 0,
      status: status,
      horizon: horizon,
      alwaysOn: stream.isAlwaysOn,
      liveOrAiring: stream.isLive,
    );

List<_StreamedMatch> _sortStreamedLiveFirst(List<_StreamedMatch> items) {
  final sorted = List<_StreamedMatch>.from(items);
  sorted.sort((a, b) {
    final live = _liveFirstCompare(
      aLive: a.isLive,
      bLive: b.isLive,
      aStart: a.dateMs,
      bStart: b.dateMs,
      aViewers: a.viewers,
      bViewers: b.viewers,
    );
    if (live != 0) return live;
    // Within the same live bucket, prefer Streamed's popular / airing rows
    // (matches the website Popular Live ordering more closely).
    if (a.airing != b.airing) return a.airing ? -1 : 1;
    if (a.popular != b.popular) return a.popular ? -1 : 1;
    return 0;
  });
  return sorted;
}

bool _gridEntryIsLive(_LiveMatchGridEntry entry) => switch (entry) {
  _LiveMatchGridEntryPpv(:final stream) => stream.isLive,
  _LiveMatchGridEntryStreamed(:final match) => match.isLive,
  _LiveMatchGridEntryMerged(:final ppv, :final streamed) =>
    ppv.isLive || streamed.isLive,
};

int _gridEntryStartKey(_LiveMatchGridEntry entry) => switch (entry) {
  _LiveMatchGridEntryPpv(:final stream) => stream.startsAt,
  _LiveMatchGridEntryStreamed(:final match) => match.dateMs,
  _LiveMatchGridEntryMerged(:final streamed) => streamed.dateMs,
};

int _gridEntryViewers(_LiveMatchGridEntry entry) => switch (entry) {
  _LiveMatchGridEntryPpv(:final stream) => stream.viewers,
  _LiveMatchGridEntryStreamed(:final match) => match.viewers,
  _LiveMatchGridEntryMerged(:final ppv, :final streamed) =>
    ppv.viewers + streamed.viewers,
};

String _matchTextKey(String raw) {
  var value = raw.toLowerCase();
  const aliases = {
    '&': ' and ',
    'women': ' w ',
    'womens': ' w ',
    'woman': ' w ',
  };
  for (final alias in aliases.entries) {
    value = value.replaceAll(alias.key, alias.value);
  }
  final tokens =
      value
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim()
          .split(RegExp(r'\s+'))
          .where(
            (token) =>
                token.isNotEmpty &&
                token != 'fc' &&
                token != 'sc' &&
                token != 'w' &&
                // Drop fixture connectors so `X at Y` / `Y vs X` title keys match.
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

String? _teamPairKey(String? home, String? away) {
  if (home == null || away == null || home.isEmpty || away.isEmpty) return null;
  final teams = [_matchTextKey(home), _matchTextKey(away)]..sort();
  if (teams.any((team) => team.isEmpty)) return null;
  return teams.join('|');
}

String? _teamPairKeyFromCatalog({
  String? homeTeam,
  String? awayTeam,
  required String title,
}) {
  final (home, away) = resolveLiveMatchTeams(
    homeTeam: homeTeam,
    awayTeam: awayTeam,
    title: title,
  );
  return _teamPairKey(home, away);
}

bool _samePpvStreamedMatch(_DamiTvStream ppv, _StreamedMatch streamed) {
  if (ppv.isAlwaysOn || streamed.isAlwaysOn) return false;
  if (ppv.startsAt <= 0 || streamed.dateMs <= 0) return false;
  final ppvSport = _normalizeSportId(ppv.categoryName);
  final streamedSport = _normalizeSportId(streamed.category);
  if (ppvSport.isEmpty || streamedSport.isEmpty || ppvSport != streamedSport) {
    return false;
  }
  final deltaMs = (ppv.startsAt * 1000 - streamed.dateMs).abs();
  if (deltaMs > const Duration(minutes: 30).inMilliseconds) return false;

  final ppvTeams = _teamPairKeyFromCatalog(
    homeTeam: ppv.homeTeam,
    awayTeam: ppv.awayTeam,
    title: ppv.name,
  );
  final streamedTeams = _teamPairKeyFromCatalog(
    homeTeam: streamed.homeTeam,
    awayTeam: streamed.awayTeam,
    title: streamed.title,
  );
  if (ppvTeams != null && streamedTeams != null) {
    return ppvTeams == streamedTeams;
  }
  final ppvTitle = _matchTextKey(ppv.name);
  final streamedTitle = _matchTextKey(streamed.title);
  return ppvTitle.isNotEmpty &&
      streamedTitle.isNotEmpty &&
      ppvTitle == streamedTitle;
}

List<_StreamedMatch> _streamedMatchesForEvent(
  _StreamedMatch match,
  List<_StreamedMatch> pool,
) =>
    pool.where((m) => _sameStreamedEvent(match, m)).toList();

/// Stable key for caching resolved stream-viewer totals on the grid card.
String _liveEventViewerKey(_StreamedMatch match) {
  final teams = _teamPairKeyFromCatalog(
    homeTeam: match.homeTeam,
    awayTeam: match.awayTeam,
    title: match.title,
  );
  if (teams != null) return 't:$teams';
  final title = _matchTextKey(match.title);
  if (title.isNotEmpty && match.dateMs > 0) {
    return 'n:$title@${match.dateMs ~/ 60000}';
  }
  if (title.isNotEmpty) return 'n:$title';
  return 'id:${match.id}';
}

String _liveEventViewerKeyFromPpv(_DamiTvStream ppv) {
  final teams = _teamPairKeyFromCatalog(
    homeTeam: ppv.homeTeam,
    awayTeam: ppv.awayTeam,
    title: ppv.name,
  );
  if (teams != null) return 't:$teams';
  final title = _matchTextKey(ppv.name);
  if (title.isNotEmpty && ppv.startsAt > 0) {
    return 'n:$title@${ppv.startsAt ~/ 60}';
  }
  if (title.isNotEmpty) return 'n:$title';
  return 'id:ppv:${ppv.id}';
}

/// Catalog-level audience across every Forja Live row for this event.
int _catalogViewersForEvent(
  _StreamedMatch match,
  List<_StreamedMatch> pool,
) {
  final siblings = _streamedMatchesForEvent(match, pool);
  if (siblings.isEmpty) return match.viewers;
  return siblings.fold<int>(0, (n, m) => n + m.viewers);
}

_StreamedMatch _pickBetterStreamedMatch(_StreamedMatch a, _StreamedMatch b) {
  if (a.isLive != b.isLive) return a.isLive ? a : b;
  if (a.poster.isNotEmpty != b.poster.isNotEmpty) {
    return a.poster.isNotEmpty ? a : b;
  }
  final aSources = a.sources.length + a.inlineStreams.length;
  final bSources = b.sources.length + b.inlineStreams.length;
  if (aSources != bSources) return aSources >= bSources ? a : b;
  if (a.dateMs > 0 && b.dateMs > 0 && a.dateMs != b.dateMs) {
    return a.dateMs <= b.dateMs ? a : b;
  }
  return a;
}

String? _nonEmptyOrNull(String? value) {
  final t = value?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// Collapse duplicate event rows without dropping ESPN teams or extra source refs.
_StreamedMatch _mergeStreamedCatalogPair(_StreamedMatch a, _StreamedMatch b) {
  final primary = _pickBetterStreamedMatch(a, b);
  final other = identical(primary, a) ? b : a;

  final sources = <_StreamedSourceRef>[...primary.sources];
  for (final s in other.sources) {
    if (sources.any((x) => x.source == s.source && x.id == s.id)) continue;
    sources.add(s);
  }

  final inlineStreams = <_StreamedStream>[...primary.inlineStreams];
  for (final s in other.inlineStreams) {
    final url = s.embedUrl.trim();
    if (url.isEmpty) continue;
    if (inlineStreams.any((x) => x.embedUrl.trim() == url)) continue;
    inlineStreams.add(s);
  }

  final sportMatchGame = primary.sportMatchGame ?? other.sportMatchGame;
  final livePluginId = primary.livePluginId.isNotEmpty
      ? primary.livePluginId
      : other.livePluginId;

  return _StreamedMatch(
    id: primary.id,
    title: primary.title,
    category: primary.category,
    dateMs: primary.dateMs > 0 ? primary.dateMs : other.dateMs,
    poster: primary.poster.isNotEmpty ? primary.poster : other.poster,
    popular: primary.popular || other.popular,
    airing: primary.airing || other.airing,
    viewers: primary.viewers + other.viewers,
    homeTeam: _nonEmptyOrNull(primary.homeTeam) ?? other.homeTeam,
    homeBadge: _nonEmptyOrNull(primary.homeBadge) ?? other.homeBadge,
    awayTeam: _nonEmptyOrNull(primary.awayTeam) ?? other.awayTeam,
    awayBadge: _nonEmptyOrNull(primary.awayBadge) ?? other.awayBadge,
    sources: sources,
    inlineStreams: inlineStreams,
    catalog: primary.catalog.isNotEmpty ? primary.catalog : other.catalog,
    stremioBaseUrl: primary.stremioBaseUrl.isNotEmpty
        ? primary.stremioBaseUrl
        : other.stremioBaseUrl,
    stremioType: primary.stremioType,
    sportMatchGame: sportMatchGame,
    livePluginId: livePluginId,
  );
}

/// Rows dropped before re-applying ESPN merge (avoid duplicate ESPN-only cards).
List<_StreamedMatch> _stripEspnMergedScheduleRows(List<_StreamedMatch> matches) =>
    [
      for (final m in matches)
        if (!m.isIptvSports &&
            (!m.id.startsWith('espn:') || m.isForjaLive)) m,
    ];

/// One card per event — catalog rows from different Forja Live plugins collapse here.
List<_StreamedMatch> _mergeStreamedCatalogRows(List<_StreamedMatch> matches) {
  if (matches.length < 2) return matches;
  final out = <_StreamedMatch>[];
  final buckets = <String, List<int>>{};
  for (final m in matches) {
    final bucketKey = _streamedEventMergeBucketKey(m);
    var merged = false;
    if (bucketKey != null) {
      final candidates = buckets[bucketKey];
      if (candidates != null) {
        for (final idx in candidates) {
          if (_sameStreamedEvent(out[idx], m)) {
            out[idx] = _mergeStreamedCatalogPair(out[idx], m);
            merged = true;
            break;
          }
        }
      }
    }
    if (merged) continue;
    final storeKey = bucketKey ?? 'id:${m.id}';
    (buckets[storeKey] ??= []).add(out.length);
    out.add(m);
  }
  return out;
}

String? _streamedEventMergeBucketKey(_StreamedMatch m) {
  if (m.isAlwaysOn) return null;
  final teams = _teamPairKeyFromCatalog(
    homeTeam: m.homeTeam,
    awayTeam: m.awayTeam,
    title: m.title,
  );
  if (teams != null) return 't:$teams';
  final title = _matchTextKey(m.title);
  if (title.isEmpty) return null;
  return 'n:$title';
}

/// Cross-catalog match for TV native picker (All card → Stremio addon event).
bool _sameStreamedEvent(_StreamedMatch a, _StreamedMatch b) {
  if (a.isAlwaysOn || b.isAlwaysOn) return false;
  final teamsA = _teamPairKeyFromCatalog(
    homeTeam: a.homeTeam,
    awayTeam: a.awayTeam,
    title: a.title,
  );
  final teamsB = _teamPairKeyFromCatalog(
    homeTeam: b.homeTeam,
    awayTeam: b.awayTeam,
    title: b.title,
  );
  if (teamsA != null && teamsB != null) return teamsA == teamsB;
  final titleA = _matchTextKey(a.title);
  final titleB = _matchTextKey(b.title);
  if (titleA.isEmpty || titleB.isEmpty || titleA != titleB) return false;
  if (a.dateMs > 0 && b.dateMs > 0) {
    final deltaMs = (a.dateMs - b.dateMs).abs();
    if (deltaMs > const Duration(hours: 6).inMilliseconds) return false;
  }
  return true;
}

List<_LiveMatchGridEntry> _mergePpvAndStreamedEntries({
  required List<_DamiTvStream> ppv,
  required List<_StreamedMatch> streamed,
}) {
  final remainingStreamed = [...streamed];
  final entries = <_LiveMatchGridEntry>[];
  for (final stream in ppv) {
    final matchIndex = remainingStreamed.indexWhere(
      (match) => _samePpvStreamedMatch(stream, match),
    );
    if (matchIndex < 0) {
      entries.add(_LiveMatchGridEntry.ppv(stream));
      continue;
    }
    entries.add(
      _LiveMatchGridEntry.merged(
        stream,
        remainingStreamed.removeAt(matchIndex),
      ),
    );
  }
  entries.addAll(remainingStreamed.map(_LiveMatchGridEntry.streamed));
  return _sortGridEntriesLiveFirst(entries);
}

List<_LiveMatchGridEntry> _sortGridEntriesLiveFirst(
  List<_LiveMatchGridEntry> entries,
) {
  final sorted = List<_LiveMatchGridEntry>.from(entries);
  sorted.sort(
    (a, b) => _liveFirstCompare(
      aLive: _gridEntryIsLive(a),
      bLive: _gridEntryIsLive(b),
      aStart: _gridEntryStartKey(a),
      bStart: _gridEntryStartKey(b),
      aViewers: _gridEntryViewers(a),
      bViewers: _gridEntryViewers(b),
    ),
  );
  return sorted;
}

// ─── API helpers ──────────────────────────────────────────────────────────────

const _ua = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'application/json',
};

/// Shared play-nudge body for embedindia JW / Video.js overlays.
///
/// Android handoff keeps a black cover over the WebView — the user cannot
/// press the site’s big-play button. Mute-first + `jwplayer().play()` + a
/// synthetic center tap are what make the playlist XHR fire so sniff works.
///
/// Desktop / iOS open is a user gesture: after the muted autoplay fallback we
/// set `window.__forjaMediaMuted = false` and unmute. Play nudges (including
/// the delayed retry) must honor that flag — otherwise JW remutes and sites
/// like MutStreams keep the "CLICK UNMUTE STREAM" overlay up.
const _liveEmbedForcePlayBodyJs = r'''
  if (typeof window.__forjaMediaMuted !== 'boolean') {
    window.__forjaMediaMuted = true;
  }

  function forjaWantMute() {
    return window.__forjaMediaMuted !== false;
  }

  function forjaTapCenter() {
    try {
      var x = Math.floor((window.innerWidth || 0) / 2) || 1;
      var y = Math.floor((window.innerHeight || 0) / 2) || 1;
      var el = document.elementFromPoint(x, y) || document.body;
      if (!el) return;
      var mouseOpts = {
        bubbles: true, cancelable: true, view: window,
        clientX: x, clientY: y, button: 0, buttons: 1
      };
      try { el.dispatchEvent(new PointerEvent('pointerdown', Object.assign({
        pointerId: 1, pointerType: 'touch', isPrimary: true
      }, mouseOpts))); } catch (_) {}
      try { el.dispatchEvent(new MouseEvent('mousedown', mouseOpts)); } catch (_) {}
      try { el.dispatchEvent(new PointerEvent('pointerup', Object.assign({
        pointerId: 1, pointerType: 'touch', isPrimary: true
      }, mouseOpts))); } catch (_) {}
      try { el.dispatchEvent(new MouseEvent('mouseup', mouseOpts)); } catch (_) {}
      try { el.dispatchEvent(new MouseEvent('click', mouseOpts)); } catch (_) {}
      try { if (typeof el.click === 'function') el.click(); } catch (_) {}
    } catch (_) {}
  }

  function forjaClickUnmuteUi() {
    try {
      var nodes = document.querySelectorAll(
        'button, a, [role="button"], div, span, p'
      );
      for (var i = 0; i < nodes.length; i++) {
        var el = nodes[i];
        var label = '';
        try {
          label = (
            (el.innerText || el.textContent || '') +
            ' ' +
            (el.getAttribute('aria-label') || '') +
            ' ' +
            (el.getAttribute('title') || '')
          ).toLowerCase();
        } catch (_) { continue; }
        if (label.indexOf('unmute') < 0) continue;
        try {
          var rect = el.getBoundingClientRect();
          if (rect.width <= 0 || rect.height <= 0) continue;
        } catch (_) {}
        try { if (typeof el.click === 'function') el.click(); } catch (_) {}
      }
    } catch (_) {}
  }

  function forjaForceJwPlay() {
    try {
      var jw = window.jwplayer;
      if (typeof jw !== 'function') return;
      var muted = forjaWantMute();
      var tried = {};
      function playOne(p) {
        if (!p || typeof p.play !== 'function') return;
        try {
          if (typeof p.setMute === 'function') p.setMute(!!muted);
        } catch (_) {}
        try {
          if (typeof p.setVolume === 'function') {
            p.setVolume(muted ? 0 : 100);
          }
        } catch (_) {}
        try { p.play(true); } catch (_) {
          try { p.play(); } catch (__) {}
        }
      }
      try { playOne(jw()); } catch (_) {}
      try {
        document.querySelectorAll('[id]').forEach(function (node) {
          var id = node.id;
          if (!id || tried[id]) return;
          tried[id] = true;
          try { playOne(jw(id)); } catch (_) {}
        });
      } catch (_) {}
    } catch (_) {}
  }

  function forjaClickPlay() {
    forjaForceJwPlay();
    forjaTapCenter();
    if (!forjaWantMute()) forjaClickUnmuteUi();
    var sels = [
      'video',
      'audio',
      '.jw-display-icon-container',
      '.jw-icon-display',
      '.jw-icon-playback',
      '.jw-display',
      '.vjs-big-play-button',
      '.plyr__control--overlaid',
      'button[aria-label*="Play" i]',
      'button[title*="Play" i]',
      '.play-button',
      '.play-icon-main',
      '#big_play_button',
      '#play-button',
      '[class*="play" i]',
      '[id*="play" i]'
    ];
    var muted = forjaWantMute();
    for (var i = 0; i < sels.length; i++) {
      try {
        var nodes = document.querySelectorAll(sels[i]);
        for (var j = 0; j < nodes.length; j++) {
          var el = nodes[j];
          if (el.tagName === 'VIDEO' || el.tagName === 'AUDIO') {
            try {
              el.setAttribute('autoplay', '');
              el.muted = !!muted;
              if (muted) el.setAttribute('muted', '');
              else el.removeAttribute('muted');
              try { el.volume = muted ? 0 : 1; } catch (_) {}
              var p = el.play();
              if (p && p.catch) p.catch(function () {});
            } catch (_) {}
          } else if (typeof el.click === 'function') {
            try {
              var rect = el.getBoundingClientRect();
              if (rect.width <= 0 || rect.height <= 0) continue;
            } catch (_) {}
            try { el.click(); } catch (_) {}
          }
        }
      } catch (_) {}
    }
  }
''';

/// Force play on embed players that gate behind a gesture / big-play overlay.
/// Immediate + one delayed retry (repeated polls also re-run from Dart).
const _autoplayJs =
    '''
(function () {
$_liveEmbedForcePlayBodyJs
  forjaClickPlay();
  setTimeout(forjaClickPlay, 1500);
})();
''';

/// Installs play / pause / mute handlers in every frame (wrapper + embed iframe)
/// and bridges Flutter chrome via `postMessage({__forjaMedia: 'play'|…})`.
const _embedMediaControlUserScript =
    '''
(function () {
  if (window.__forjaMediaCtrl) return;
  window.__forjaMediaCtrl = true;

$_liveEmbedForcePlayBodyJs

  function pauseAll() {
    try {
      document.querySelectorAll('video,audio').forEach(function (el) {
        try { el.pause(); } catch (e) {}
      });
    } catch (_) {}
    try {
      var jw = window.jwplayer;
      if (typeof jw === 'function') {
        try { var p = jw(); if (p && p.pause) p.pause(); } catch (e) {}
      }
    } catch (_) {}
  }

  function setMute(on) {
    window.__forjaMediaMuted = !!on;
    try {
      document.querySelectorAll('video,audio').forEach(function (el) {
        try {
          el.muted = !!on;
          if (on) el.setAttribute('muted', '');
          else el.removeAttribute('muted');
          try { el.volume = on ? 0 : 1; } catch (e) {}
        } catch (e) {}
      });
    } catch (_) {}
    try {
      var jw = window.jwplayer;
      if (typeof jw === 'function') {
        try {
          var p = jw();
          if (p && typeof p.setMute === 'function') p.setMute(!!on);
          if (p && typeof p.setVolume === 'function') {
            p.setVolume(on ? 0 : 100);
          }
        } catch (e) {}
      }
    } catch (_) {}
    if (!on) {
      forjaClickUnmuteUi();
      // MutStreams (and similar) paint "CLICK UNMUTE STREAM" after JW starts.
      [500, 1500, 3000].forEach(function (ms) {
        setTimeout(function () {
          if (window.__forjaMediaMuted === false) forjaClickUnmuteUi();
        }, ms);
      });
    }
  }

  function toggleMute() {
    var next = true;
    try {
      var vids = document.querySelectorAll('video,audio');
      if (vids.length) next = !vids[0].muted;
    } catch (_) {}
    setMute(next);
  }

  function dispatchToIframes(cmd) {
    try {
      document.querySelectorAll('iframe').forEach(function (frame) {
        try {
          frame.contentWindow.postMessage({ __forjaMedia: cmd }, '*');
        } catch (e) {}
      });
    } catch (_) {}
  }

  function handle(cmd) {
    if (cmd === 'play') forjaClickPlay();
    else if (cmd === 'pause') pauseAll();
    else if (cmd === 'mute') setMute(true);
    else if (cmd === 'unmute') setMute(false);
    else if (cmd === 'toggleMute') toggleMute();
    dispatchToIframes(cmd);
  }

  window.__forjaMedia = handle;
  window.addEventListener('message', function (ev) {
    try {
      var d = ev && ev.data;
      if (!d || typeof d !== 'object' || !d.__forjaMedia) return;
      handle(d.__forjaMedia);
    } catch (_) {}
  });
})();
''';

/// Main-frame entry: run media cmd in this document and fan out to iframes.
String _embedMediaCommandJs(String cmd) {
  final safe = cmd.replaceAll("'", '');
  return '''
(function () {
  var cmd = '$safe';
  try {
    if (typeof window.__forjaMedia === 'function') {
      window.__forjaMedia(cmd);
      return;
    }
  } catch (_) {}
  try {
    document.querySelectorAll('iframe').forEach(function (frame) {
      try {
        frame.contentWindow.postMessage({ __forjaMedia: cmd }, '*');
      } catch (e) {}
    });
  } catch (_) {}
})();
''';
}

/// Pause + tear down HTML media before the Flutter route pops. Parent-frame
/// `video`/`audio` alone is not enough for the iframe wrapper - blank iframes too.
const _stopEmbedMediaJs = r'''
(function () {
  try {
    if (document.fullscreenElement && document.exitFullscreen) {
      document.exitFullscreen();
    }
  } catch (e) {}
  try {
    if (document.webkitFullscreenElement && document.webkitExitFullscreen) {
      document.webkitExitFullscreen();
    }
  } catch (e) {}
  document.querySelectorAll('video,audio').forEach(function (el) {
    try {
      el.pause();
      el.muted = true;
      el.removeAttribute('src');
      while (el.firstChild) el.removeChild(el.firstChild);
      el.load();
    } catch (e) {}
  });
  document.querySelectorAll('iframe').forEach(function (frame) {
    try {
      frame.src = 'about:blank';
      frame.removeAttribute('src');
    } catch (e) {}
  });
})();
''';

/// Double-click the embed surface → toggle host fullscreen (films / IPTV parity).
const _dblclickFullscreenJs = r'''
(function () {
  if (window.__forjaDblFs) return;
  window.__forjaDblFs = true;
  document.addEventListener('dblclick', function () {
    try {
      window.flutter_inappwebview.callHandler('toggleFullscreen');
    } catch (_) {}
  }, true);
})();
''';

/// Wrap the third-party embed in an iframe under [baseUrl] so `document.referrer`
/// matches the website (streamed.pk / PPV plugin webOrigin). Direct top-level loads of
/// embed.st / embedindia break the host lock (same red “Remove sandbox
/// attributes…” page + UA) and stall behind parser-blocking ads (issue 046).
///
/// Do **not** set HTML `sandbox`. Main-frame hijacks are cancelled in
/// `shouldOverrideUrlLoading` except the catalog **origin root** required by
/// `loadData(baseUrl)` (see [liveEmbedAllowsMainFrameNavigation] / 046 T05).
/// Ad `window.open` is accepted off-screen so Streamed embeds that require a
/// successful open keep playing. Same wrapper on **all** platforms including
/// Android / Android TV — top-level + Referer headers do not set
/// `document.referrer` the way the lock expects.
/// [allowHtmlFullscreen]: on macOS false — HTML5/WK fullscreen races
/// `windowManager.setFullScreen` and PAC-traps in `WKFullScreenWindowController`
/// dealloc (issue 145). Host fullscreen stays on chrome / dblclick.
String _buildLiveEmbedWrapperHtml(
  String embedUrl, {
  bool allowHtmlFullscreen = true,
}) {
  final safe = embedUrl
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;');
  final allow = allowHtmlFullscreen
      ? 'autoplay; fullscreen; encrypted-media'
      : 'autoplay; encrypted-media';
  final allowFsAttr = allowHtmlFullscreen ? ' allowfullscreen' : '';
  return '''<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="referrer" content="unsafe-url">
<title>player</title>
<style>
html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}
iframe{border:0;width:100%;height:100%;display:block}
</style>
</head><body>
<iframe id="p" src="$safe" allow="$allow"$allowFsAttr referrerpolicy="unsafe-url"></iframe>
<script>
(function () {
  function ready() {
    try { window.flutter_inappwebview.callHandler('embedReady'); } catch (_) {}
  }
  var f = document.getElementById('p');
  if (f) {
    f.addEventListener('load', ready);
    // If the embed already finished before this script ran.
    try {
      if (f.contentDocument && f.contentDocument.readyState === 'complete') ready();
    } catch (_) {}
  }
  // Don't leave the Flutter spinner over the play button if load is slow.
  setTimeout(ready, 1500);
})();
</script>
</body></html>''';
}

/// Ad / tracker hosts that inject parser-blocking scripts on embed.st and keep
/// `onLoadStop` from firing (unlimited spinner + blank player).
List<ContentBlocker> _liveEmbedContentBlockers() {
  // Only parser-blocking script hosts that hang the player document itself.
  // Click / interstitial networks are not URL-blocked here - window.open is
  // accepted off-screen (hidden), and main-frame redirects are cancelled.
  const hosts = <String>[
    r'.*therocketlanguages\.com.*',
    r'.*optimserve\.agency.*',
    r'.*doubleclick\.net.*',
    r'.*googlesyndication\.com.*',
    r'.*googleadservices\.com.*',
    r'.*adnxs\.com.*',
    r'.*adservice\.google\..*',
  ];
  return [
    for (final filter in hosts)
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: filter),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
  ];
}

/// Strip `sandbox` from iframes under the wrapper document before they load.
/// Embed hosts reject sandboxed parents; some injectors re-add the attribute.
const _stripIframeSandboxJs = r'''
(function () {
  if (window.__forjaStripSandbox) return;
  window.__forjaStripSandbox = true;
  function strip(root) {
    try {
      (root || document).querySelectorAll('iframe[sandbox]').forEach(function (f) {
        f.removeAttribute('sandbox');
      });
    } catch (_) {}
  }
  strip();
  try {
    new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var m = mutations[i];
        if (m.type === 'attributes' && m.attributeName === 'sandbox' && m.target && m.target.tagName === 'IFRAME') {
          m.target.removeAttribute('sandbox');
        }
        if (m.addedNodes) {
          for (var j = 0; j < m.addedNodes.length; j++) {
            var n = m.addedNodes[j];
            if (!n || n.nodeType !== 1) continue;
            if (n.tagName === 'IFRAME' && n.hasAttribute('sandbox')) {
              n.removeAttribute('sandbox');
            } else {
              strip(n);
            }
          }
        }
      }
    }).observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['sandbox'],
    });
  } catch (_) {}
})();
''';

/// Report HLS / media URLs to Flutter. Android System WebView cannot play
/// Streamed / PPV embeds in-page (CORS + host lock UI). We sniff the playlist
/// from the visible WebView and hand off to the native IPTV player.
///
/// Cross-origin embed iframes often cannot call `flutter_inappwebview` — fall
/// back to `postMessage` so the catalog wrapper (main frame) can bridge.
const _liveEmbedMediaSpyJs = r'''
(function () {
  if (window.__forjaLiveMediaSpy) return;
  window.__forjaLiveMediaSpy = true;

  function absUrl(u) {
    try { return new URL(String(u), window.location.href).href; } catch (_) {
      return String(u || '');
    }
  }

  function looksMedia(s) {
    var low = String(s || '').toLowerCase();
    if (!low || low.indexOf('blob:') === 0 || low.indexOf('data:') === 0) return false;
    if (low.indexOf('.m3u8') !== -1) return true;
    if (low.indexOf('.mpd') !== -1) return true;
    if (low.indexOf('.mp4') !== -1) return true;
    if (low.indexOf('strmd.st') !== -1) return true;
    // PPV embedindia JW CDN (XHR playlist).
    if (low.indexOf('indianservers.st') !== -1) return true;
    if (low.indexOf('/playlist') !== -1) return true;
    if (low.indexOf('/secure/') !== -1) return true;
    if (low.indexOf('/hls') !== -1) return true;
    if (low.indexOf('application/x-mpegurl') !== -1) return true;
    if (low.indexOf('mpegurl') !== -1) return true;
    return false;
  }

  function report(u) {
    try {
      if (!u) return;
      var s = absUrl(u);
      if (!looksMedia(s)) return;
      try {
        if (window.flutter_inappwebview &&
            typeof window.flutter_inappwebview.callHandler === 'function') {
          window.flutter_inappwebview.callHandler('liveMediaUrl', s);
          return;
        }
      } catch (_) {}
      try { window.parent.postMessage({ __forjaLiveMedia: s }, '*'); } catch (_) {}
      try { window.top.postMessage({ __forjaLiveMedia: s }, '*'); } catch (_) {}
    } catch (_) {}
  }

  // Forward the playlist BODY WebView already downloaded — native must not
  // re-GET strmd.st (Rust/OkHttp often 403s the same URL).
  function reportPlaylist(url, body) {
    try {
      if (!url || body == null) return;
      var s = absUrl(url);
      var text = String(body);
      if (text.trim().indexOf('#EXTM3U') !== 0) return;
      try {
        if (window.flutter_inappwebview &&
            typeof window.flutter_inappwebview.callHandler === 'function') {
          window.flutter_inappwebview.callHandler('liveMediaPlaylist', s, text);
          report(s);
          return;
        }
      } catch (_) {}
      try {
        window.parent.postMessage(
          { __forjaLivePlaylist: true, url: s, body: text }, '*');
      } catch (_) {}
      try {
        window.top.postMessage(
          { __forjaLivePlaylist: true, url: s, body: text }, '*');
      } catch (_) {}
      report(s);
    } catch (_) {}
  }

  function reportM3u8InText(text) {
    try {
      var t = String(text || '');
      if (!t) return;
      var re = /https?:\/\/[^"'\\s<>]+\\.m3u8[^"'\\s<>]*/gi;
      var m;
      while ((m = re.exec(t)) !== null) report(m[0]);
      re = /https?:\/\/[^"'\\s<>]+strmd\\.st[^"'\\s<>]*/gi;
      while ((m = re.exec(t)) !== null) report(m[0]);
    } catch (_) {}
  }

  // Main-frame bridge for iframe postMessage reports.
  try {
    window.addEventListener('message', function (e) {
      try {
        var d = e && e.data;
        if (!d) return;
        if (typeof d === 'string') {
          if (looksMedia(d)) report(d);
          return;
        }
        if (d.__forjaLivePlaylist && d.url && d.body) {
          try {
            if (window.flutter_inappwebview &&
                typeof window.flutter_inappwebview.callHandler === 'function') {
              window.flutter_inappwebview.callHandler(
                'liveMediaPlaylist', d.url, d.body);
            }
          } catch (_) {}
          report(d.url);
          return;
        }
        if (d.__forjaProxyFetchResult && d.id) {
          try {
            if (window.flutter_inappwebview &&
                typeof window.flutter_inappwebview.callHandler === 'function') {
              window.flutter_inappwebview.callHandler(
                'liveProxyFetchResult',
                d.id,
                d.status || 0,
                d.body || '',
                d.ct || '');
            }
          } catch (_) {}
          return;
        }
        if (d.__forjaProxyFetch && d.id && d.url) {
          // Embed iframe: fetch CDN bytes for the Exo loopback proxy.
          // Streamed CDN often returns ACAO:* which forbids credentials:include
          // — tokens live in the URL path, so omit first, then include.
          try {
            function reply(status, body, ct) {
              try {
                if (window.flutter_inappwebview &&
                    typeof window.flutter_inappwebview.callHandler ===
                        'function') {
                  window.flutter_inappwebview.callHandler(
                    'liveProxyFetchResult', d.id, status, body, ct);
                  return;
                }
              } catch (_) {}
              try {
                window.parent.postMessage({
                  __forjaProxyFetchResult: true,
                  id: d.id,
                  status: status,
                  body: body,
                  ct: ct
                }, '*');
              } catch (_) {}
            }
            function readBlob(r, blob) {
              return new Promise(function (resolve) {
                var reader = new FileReader();
                reader.onloadend = function () {
                  var dataUrl = String(reader.result || '');
                  var b64 = '';
                  var idx = dataUrl.indexOf(',');
                  if (idx >= 0) b64 = dataUrl.substring(idx + 1);
                  resolve({
                    status: r.status,
                    body: b64,
                    ct: (r.headers && r.headers.get('content-type')) ||
                        blob.type || ''
                  });
                };
                reader.onerror = function () {
                  resolve({ status: 0, body: '', ct: '' });
                };
                reader.readAsDataURL(blob);
              });
            }
            function tryFetch(creds) {
              return fetch(d.url, {
                credentials: creds,
                cache: 'no-store',
                mode: 'cors'
              }).then(function (r) {
                return r.blob().then(function (blob) {
                  return readBlob(r, blob);
                });
              });
            }
            tryFetch('omit').then(function (res) {
              if (res && res.status > 0 && res.body) {
                reply(res.status, res.body, res.ct);
                return;
              }
              return tryFetch('include').then(function (res2) {
                reply(
                  (res2 && res2.status) || 0,
                  (res2 && res2.body) || '',
                  (res2 && res2.ct) || '');
              });
            }).catch(function () {
              tryFetch('include').then(function (res2) {
                reply(
                  (res2 && res2.status) || 0,
                  (res2 && res2.body) || '',
                  (res2 && res2.ct) || '');
              }).catch(function () {
                reply(0, '', '');
              });
            });
          } catch (_) {}
          return;
        }
        if (d.__forjaLiveMedia) report(d.__forjaLiveMedia);
        if (d.file) report(d.file);
        if (d.source) report(d.source);
        if (d.sources && d.sources.length) {
          for (var i = 0; i < d.sources.length; i++) {
            var src = d.sources[i];
            if (typeof src === 'string') report(src);
            else if (src && src.file) report(src.file);
          }
        }
      } catch (_) {}
    });
  } catch (_) {}

  try {
    var ofetch = window.fetch;
    if (typeof ofetch === 'function' && !ofetch.__forjaFetchHooked) {
      var wrappedFetch = function (input, init) {
        var reqUrl = '';
        var nextInput = input;
        try {
          if (typeof input === 'string') reqUrl = input;
          else if (input && input.url) {
            reqUrl = input.url;
            // Never pass a consumed Request through — clone first.
            try {
              if (typeof Request !== 'undefined' && input instanceof Request) {
                nextInput = input.clone();
              }
            } catch (_) {}
          }
          report(reqUrl);
        } catch (_) {}
        return ofetch.call(this, nextInput, init).then(function (res) {
          try {
            var clone = res.clone();
            clone.text().then(function (text) {
              reportM3u8InText(text);
              if (text && text.trim().indexOf('#EXTM3U') === 0 && reqUrl) {
                reportPlaylist(reqUrl, text);
              }
            }).catch(function () {});
          } catch (_) {}
          return res;
        });
      };
      wrappedFetch.__forjaFetchHooked = true;
      window.fetch = wrappedFetch;
    }
  } catch (_) {}

  try {
    var open = XMLHttpRequest.prototype.open;
    var send = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function (method, url) {
      try {
        this.__forjaUrl = absUrl(url);
        report(this.__forjaUrl);
      } catch (_) {}
      return open.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function () {
      try {
        this.addEventListener('load', function () {
          try {
            var text = this.responseText || '';
            reportM3u8InText(text);
            if (text && text.trim().indexOf('#EXTM3U') === 0 && this.__forjaUrl) {
              reportPlaylist(this.__forjaUrl, text);
            }
          } catch (_) {}
        });
      } catch (_) {}
      return send.apply(this, arguments);
    };
  } catch (_) {}

  // HLS.js / similar: playlist often never appears as video.src (blob: MSE).
  function hookHlsProto(H) {
    try {
      if (!H || !H.prototype || H.prototype.__forjaHlsHooked) return;
      H.prototype.__forjaHlsHooked = true;
      var orig = H.prototype.loadSource;
      if (typeof orig !== 'function') return;
      H.prototype.loadSource = function (url) {
        try { report(url); } catch (_) {}
        return orig.apply(this, arguments);
      };
    } catch (_) {}
  }
  function hookHls() {
    hookHlsProto(window.Hls);
    hookHlsProto(window.hls);
    hookHlsProto(window.Hlsjs);
  }
  try {
    hookHls();
    setInterval(hookHls, 500);
    var _hls = window.Hls;
    Object.defineProperty(window, 'Hls', {
      configurable: true,
      get: function () { return _hls; },
      set: function (v) { _hls = v; hookHlsProto(v); }
    });
  } catch (_) {}

  // JW Player playlist / setup hooks (embedindia).
  // Playlist `file` is often known before play — report it so Android sniff
  // does not depend on the big-play gesture under the handoff cover.
  function reportJwItem(item) {
    try {
      if (!item) return;
      if (item.file) report(item.file);
      if (item.sources && item.sources.length) {
        for (var i = 0; i < item.sources.length; i++) {
          var s = item.sources[i];
          if (s && s.file) report(s.file);
        }
      }
    } catch (_) {}
  }
  function reportJwPlayer(player) {
    try {
      if (!player) return;
      try {
        var pl = player.getPlaylist && player.getPlaylist();
        if (pl && pl.length) {
          for (var i = 0; i < pl.length; i++) reportJwItem(pl[i]);
        }
      } catch (_) {}
      try {
        var item = player.getPlaylistItem && player.getPlaylistItem();
        reportJwItem(item);
      } catch (_) {}
      try {
        var cfg = player.getConfig && player.getConfig();
        if (cfg) {
          if (cfg.file) report(cfg.file);
          if (cfg.sources) reportJwItem({ sources: cfg.sources });
          if (cfg.playlist && cfg.playlist.length) {
            for (var j = 0; j < cfg.playlist.length; j++) {
              reportJwItem(cfg.playlist[j]);
            }
          }
        }
      } catch (_) {}
    } catch (_) {}
  }
  function hookJwPlayer(player) {
    try {
      if (!player || player.__forjaJwBound) return;
      player.__forjaJwBound = true;
      reportJwPlayer(player);
      if (typeof player.on !== 'function') return;
      player.on('ready', function () { reportJwPlayer(player); });
      player.on('playlist', function (e) {
        try {
          var pl = (e && e.playlist) || [];
          for (var i = 0; i < pl.length; i++) reportJwItem(pl[i]);
        } catch (_) {}
        reportJwPlayer(player);
      });
      player.on('playlistItem', function () { reportJwPlayer(player); });
      player.on('meta', function (e) {
        try {
          if (e && e.metadata && e.metadata.file) report(e.metadata.file);
        } catch (_) {}
      });
      try {
        var origSetup = player.setup;
        if (typeof origSetup === 'function' && !origSetup.__forjaSetup) {
          var wrappedSetup = function (config) {
            try {
              if (config) {
                if (config.file) report(config.file);
                reportJwItem(config);
                if (config.playlist && config.playlist.length) {
                  for (var i = 0; i < config.playlist.length; i++) {
                    reportJwItem(config.playlist[i]);
                  }
                }
              }
            } catch (_) {}
            return origSetup.apply(this, arguments);
          };
          wrappedSetup.__forjaSetup = true;
          player.setup = wrappedSetup;
        }
      } catch (_) {}
    } catch (_) {}
  }
  function scanJwInstances() {
    try {
      var jw = window.jwplayer;
      if (typeof jw !== 'function') return;
      try { hookJwPlayer(jw()); } catch (_) {}
      try {
        document.querySelectorAll('[id]').forEach(function (node) {
          if (!node.id) return;
          try { hookJwPlayer(jw(node.id)); } catch (_) {}
        });
      } catch (_) {}
    } catch (_) {}
  }
  function hookJw() {
    try {
      var jw = window.jwplayer;
      if (typeof jw !== 'function' || jw.__forjaHooked) {
        scanJwInstances();
        return;
      }
      jw.__forjaHooked = true;
      var wrapped = function () {
        var player = jw.apply(this, arguments);
        hookJwPlayer(player);
        return player;
      };
      wrapped.__forjaHooked = true;
      try {
        for (var k in jw) {
          if (Object.prototype.hasOwnProperty.call(jw, k)) wrapped[k] = jw[k];
        }
      } catch (_) {}
      window.jwplayer = wrapped;
      scanJwInstances();
    } catch (_) {}
  }
  try {
    hookJw();
    setInterval(hookJw, 500);
  } catch (_) {}

  function scanDom() {
    try {
      document.querySelectorAll('video, audio, source').forEach(function (el) {
        try {
          if (el.src) report(el.src);
          if (el.currentSrc) report(el.currentSrc);
          if (el.getAttribute) {
            var ds = el.getAttribute('data-src');
            if (ds) report(ds);
          }
        } catch (_) {}
      });
    } catch (_) {}
    try {
      performance.getEntriesByType('resource').forEach(function (e) {
        if (e && e.name) report(e.name);
      });
    } catch (_) {}
    try {
      scanJwInstances();
    } catch (_) {}
    // Page HTML often embeds the tokenised playlist before JW play.
    try {
      var html = document.documentElement && document.documentElement.innerHTML;
      if (html && html.length) {
        var re = /https?:\/\/[^"'\\\s<>]+(?:\.m3u8|indianservers\.st\/[^"'\\\s<>]*)/gi;
        var m;
        while ((m = re.exec(html)) !== null) report(m[0]);
      }
    } catch (_) {}
  }
  try {
    scanDom();
    setInterval(scanDom, 1200);
  } catch (_) {}

  try {
    var obs = new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var m = mutations[i];
        if (m.type === 'attributes' &&
            (m.attributeName === 'src' || m.attributeName === 'data-src')) {
          try {
            report(m.target.getAttribute(m.attributeName));
          } catch (_) {}
        }
        for (var j = 0; j < m.addedNodes.length; j++) {
          var n = m.addedNodes[j];
          if (!n || n.nodeType !== 1) continue;
          try {
            if (n.src) report(n.src);
            if (n.querySelectorAll) {
              n.querySelectorAll('video,audio,source').forEach(function (el) {
                if (el.src) report(el.src);
                if (el.currentSrc) report(el.currentSrc);
              });
            }
          } catch (_) {}
        }
      }
    });
    obs.observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src', 'data-src']
    });
  } catch (_) {}

  try {
    if (window.PerformanceObserver) {
      var po = new PerformanceObserver(function (list) {
        try {
          list.getEntries().forEach(function (e) {
            if (e && e.name) report(e.name);
          });
        } catch (_) {}
      });
      po.observe({ entryTypes: ['resource'] });
    }
  } catch (_) {}

  // Parent asks nested frames to re-scan (Dart poll).
  try {
    window.addEventListener('message', function (e) {
      try {
        if (e && e.data && e.data.__forjaSniffPoll) scanDom();
      } catch (_) {}
    });
  } catch (_) {}
})();
''';

/// Poll performance / media elements from the catalog wrapper (and fan out to
/// iframes via postMessage). Used while Android native handoff is waiting.
/// Also pulls JW playlist `file` URLs that exist before a real play gesture.
const _liveEmbedSniffPollJs = r'''
(function () {
  var out = [];
  function push(u) {
    try {
      if (!u) return;
      var s = String(u);
      if (s.indexOf('blob:') === 0 || s.indexOf('data:') === 0) return;
      out.push(s);
    } catch (_) {}
  }
  function pushJwItem(item) {
    try {
      if (!item) return;
      if (item.file) push(item.file);
      if (item.sources && item.sources.length) {
        for (var i = 0; i < item.sources.length; i++) {
          var s = item.sources[i];
          if (s && s.file) push(s.file);
        }
      }
    } catch (_) {}
  }
  function pushJwPlayer(p) {
    try {
      if (!p) return;
      try {
        var pl = p.getPlaylist && p.getPlaylist();
        if (pl && pl.length) {
          for (var i = 0; i < pl.length; i++) pushJwItem(pl[i]);
        }
      } catch (_) {}
      try { pushJwItem(p.getPlaylistItem && p.getPlaylistItem()); } catch (_) {}
      try {
        var cfg = p.getConfig && p.getConfig();
        if (cfg) {
          if (cfg.file) push(cfg.file);
          pushJwItem(cfg);
          if (cfg.playlist && cfg.playlist.length) {
            for (var j = 0; j < cfg.playlist.length; j++) {
              pushJwItem(cfg.playlist[j]);
            }
          }
        }
      } catch (_) {}
    } catch (_) {}
  }
  try {
    performance.getEntriesByType('resource').forEach(function (e) {
      if (e && e.name) push(e.name);
    });
  } catch (_) {}
  try {
    document.querySelectorAll('video,audio,source').forEach(function (el) {
      if (el.src) push(el.src);
      if (el.currentSrc) push(el.currentSrc);
    });
  } catch (_) {}
  try {
    var jw = window.jwplayer;
    if (typeof jw === 'function') {
      try { pushJwPlayer(jw()); } catch (_) {}
      document.querySelectorAll('[id]').forEach(function (node) {
        if (!node.id) return;
        try { pushJwPlayer(jw(node.id)); } catch (_) {}
      });
    }
  } catch (_) {}
  try {
    var html = document.documentElement && document.documentElement.innerHTML;
    if (html && html.length) {
      var re = /https?:\/\/[^"'\\\s<>]+(?:\.m3u8|indianservers\.st\/[^"'\\\s<>]*)/gi;
      var m;
      while ((m = re.exec(html)) !== null) push(m[0]);
    }
  } catch (_) {}
  try {
    document.querySelectorAll('iframe').forEach(function (frame) {
      try { frame.contentWindow.postMessage({ __forjaSniffPoll: true }, '*'); } catch (_) {}
    });
  } catch (_) {}
  return out;
})();
''';

const _streamedBase = 'https://streamed.pk';
const _streamedReferer = 'https://streamed.pk/';
const _streamedEmbedOrigin = 'https://embed.st';

List<_StreamedStream> _streamedEmbedFallbackStreams(_StreamedSourceRef sourceRef) {
  final source = sourceRef.source.trim();
  final id = sourceRef.id.trim();
  if (source.isEmpty || id.isEmpty) return const [];
  if (source.toLowerCase() == 'echo') return const [];
  return [
    _StreamedStream(
      id: id,
      streamNo: 1,
      language: '',
      hd: false,
      embedUrl: '$_streamedEmbedOrigin/embed/$source/$id/1',
      source: source,
      viewers: 0,
    ),
  ];
}
const _mutBase = 'https://mut.st';
const _mutReferer = 'https://mut.st/';

String _streamedImageUrl(String path) {
  if (path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  if (path.startsWith('/')) return '$_streamedBase$path';
  return '$_streamedBase/api/images/badge/$path.webp';
}

/// embedindia JW Player resolves tokenised HLS inside the embed browsing
/// context. The sniffed m3u8 403s in mpv - same as copying the URL into VLC.
bool _ppvEmbedRequiresWebView(String embedUrl) =>
    liveEmbedRequiresWebViewPlayback(embedUrl);

Map<String, String> _ppvEmbedStreamHeaders(String embedUrl) {
  final uri = Uri.tryParse(embedUrl.trim());
  final origin = uri?.origin ?? 'https://embedindia.st';
  // Path only — `?gid=` on Referer 403s `*.indianservers.st` (nginx).
  final referer = (uri != null && uri.hasScheme && uri.path.isNotEmpty)
      ? '$origin${uri.path}'
      : embedUrl.trim();
  return {
    'User-Agent': _ua['User-Agent']!,
    'Referer': referer,
    'Origin': origin,
  };
}

Map<String, String> _liveEmbedStreamHeaders(
  String embedUrl, {
  String? catalogReferer,
}) {
  final uri = Uri.tryParse(embedUrl);
  final origin = uri?.origin ?? '';
  final catalog = (catalogReferer ?? '').trim();
  final catalogRoot = catalog.isEmpty
      ? null
      : (catalog.endsWith('/') ? catalog : '$catalog/');
  final catalogOrigin = catalogRoot == null
      ? null
      : Uri.tryParse(catalogRoot)?.origin;
  // Streamed CDN (`strmd.st`) usually validates against the catalog site
  // (streamed.pk), not only the embed host. Pass [catalogReferer] on the
  // primary probe; omit it to try embed-origin as a fallback.
  final referer = catalogRoot ?? (origin.isNotEmpty ? '$origin/' : embedUrl);
  final headerOrigin = catalogOrigin ?? (origin.isNotEmpty ? origin : null);
  return {
    'User-Agent': _ua['User-Agent']!,
    'Referer': referer,
    if (headerOrigin != null && headerOrigin.isNotEmpty) 'Origin': headerOrigin,
  };
}

/// CDN token checks — JW/HLS on the third-party embed host, not the catalog.
String? _forjaLiveCdnReferer(String embedUrl) {
  final uri = Uri.tryParse(embedUrl.trim());
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase();
  // WatchFooty HLS (`lb*.wfty.st`) validates Referer against sportsembed.
  if (host.contains('wfty.st')) return 'https://sportsembed.su/';
  return '${uri.origin}/';
}

bool _liveEmbedIsSniffableMediaUrl(String url) {
  final lower = url.toLowerCase();
  if (lower.startsWith('blob:') || lower.startsWith('data:')) return false;
  if (lower.contains('doubleclick') ||
      lower.contains('googlesyndication') ||
      lower.contains('therocketlanguages') ||
      lower.contains('optimserve') ||
      lower.contains('googleadservices') ||
      lower.contains('adnxs.com') ||
      lower.contains('/ads/') ||
      lower.contains('vast.')) {
    return false;
  }
  if (lower.contains('.m3u8')) return true;
  if (lower.contains('.mpd')) return true;
  if (lower.contains('.mp4') &&
      (lower.contains('http://') || lower.contains('https://'))) {
    return true;
  }
  // PPV embedindia JW Player CDN (playlist often via XHR).
  if (lower.contains('indianservers.st')) return true;
  if (lower.contains('strmd.st/') &&
      (lower.contains('/secure/') ||
          lower.contains('playlist') ||
          lower.contains('/hls'))) {
    return true;
  }
  // embedindia / similar JW hosts often omit `.m3u8` in the path.
  if ((lower.contains('/secure/') ||
          lower.contains('/playlist') ||
          lower.contains('/hls/') ||
          lower.contains('/hls?') ||
          lower.contains('mpegurl')) &&
      (lower.contains('http://') || lower.contains('https://'))) {
    return true;
  }
  return false;
}

/// Pull WebView cookies so proxied HLS matches the embed session (PPV tokens).
Future<String?> _liveEmbedCollectCookieHeader({
  required String embedUrl,
  required String streamUrl,
  String? catalogReferer,
}) async {
  try {
    final manager = CookieManager.instance();
    final urls = <String>{embedUrl, streamUrl};
    if (catalogReferer != null && catalogReferer.isNotEmpty) {
      urls.add(catalogReferer);
    }
    for (final raw in [embedUrl, streamUrl, catalogReferer ?? '']) {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
        urls.add(uri.origin);
      }
    }
    final parts = <String>[];
    final seen = <String>{};
    for (final u in urls) {
      if (u.isEmpty) continue;
      final cookies = await manager.getCookies(url: WebUri(u));
      for (final c in cookies) {
        final key = '${c.name}=';
        if (seen.add(key)) {
          parts.add('${c.name}=${c.value}');
        }
      }
    }
    if (parts.isEmpty) return null;
    return parts.join('; ');
  } catch (e) {
    debugPrint('[LiveMatches] Cookie harvest failed: $e');
    return null;
  }
}

Future<List<_Sport>> _fetchStreamedSports() async {
  try {
    final raw = await runLiveMatchesFetchJson(
      jsonEncode({'action': 'streamed_sports'}),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) return [];
    final list = parsed['items'] as List? ?? [];
    return list
        .map((s) {
          final j = s as Map<String, dynamic>;
          final id = (j['id'] ?? '').toString();
          final name = (j['name'] ?? '').toString();
          if (id.isEmpty || name.isEmpty) return null;
          return _Sport(id: id, name: name);
        })
        .whereType<_Sport>()
        .toList();
  } catch (_) {
    return [];
  }
}

Future<List<_StreamedMatch>> _fetchStreamedMatches() async {
  try {
    final list = await LiveMatchesEngine.fetchServerCatalog('streamed');
    return list
        .map((m) {
          try {
            return _StreamedMatch.fromJson(m);
          } catch (_) {
            return null;
          }
        })
        .whereType<_StreamedMatch>()
        .toList();
  } catch (_) {
    return [];
  }
}

Future<List<_StreamedMatch>> _fetchMutMatches() async {
  try {
    final raw = await runLiveMatchesFetchJson(
      jsonEncode({'action': 'mut_matches'}),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) return [];
    final list = parsed['items'] as List? ?? [];
    return list
        .map((m) {
          try {
            return _StreamedMatch.fromJson(m as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<_StreamedMatch>()
        .toList();
  } catch (_) {
    return [];
  }
}

/// Kickoff epoch-ms from a Stremio sport meta (Highfly / similar).
///
/// Sources tried in order:
/// 1. `released` — ISO-8601 or unix seconds/ms
/// 2. `releaseInfo` — e.g. `06 Aug 2026 · 07:10 UTC` (Highfly)
/// 3. `description` lines — same human date format
int _stremioKickoffMsFromMeta(Map<String, dynamic> meta) {
  final released = meta['released'];
  final fromReleased = _stremioParseKickoffValue(released);
  if (fromReleased > 0) return fromReleased;

  final releaseInfo = meta['releaseInfo']?.toString() ?? '';
  final fromInfo = _stremioParseHumanKickoff(releaseInfo);
  if (fromInfo > 0) return fromInfo;

  final desc = meta['description']?.toString() ?? '';
  for (final line in desc.split('\n')) {
    final fromLine = _stremioParseHumanKickoff(line.trim());
    if (fromLine > 0) return fromLine;
  }
  return 0;
}

int _stremioParseKickoffValue(Object? raw) {
  if (raw == null) return 0;
  if (raw is num) {
    final n = raw.toInt();
    if (n <= 0) return 0;
    // Seconds ~1.7e9 today; milliseconds ~1.7e12.
    return n >= 1000000000000 ? n : n * 1000;
  }
  final s = raw.toString().trim();
  if (s.isEmpty) return 0;
  final asInt = int.tryParse(s);
  if (asInt != null) return _stremioParseKickoffValue(asInt);
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso.toUtc().millisecondsSinceEpoch;
  return _stremioParseHumanKickoff(s);
}

/// `06 Aug 2026 · 07:10 UTC` / `06 Aug 2026 07:10` / `15 AUG 05:05 UTC`.
int _stremioParseHumanKickoff(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return 0;
  // Skip bare LIVE badges with no clock.
  if (RegExp(r'^LIVE\b', caseSensitive: false).hasMatch(t) &&
      !RegExp(r'\d').hasMatch(t)) {
    return 0;
  }
  final re = RegExp(
    r'(\d{1,2})\s+'
    r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+'
    r'(\d{4})\s*[·•\-]?\s*'
    r'(\d{1,2}):(\d{2})'
    r'(?:\s*(?:UTC|GMT|Z))?',
    caseSensitive: false,
  );
  final m = re.firstMatch(t);
  if (m == null) return 0;
  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[m.group(2)!.toLowerCase().substring(0, 3)];
  if (month == null) return 0;
  final day = int.tryParse(m.group(1)!);
  final year = int.tryParse(m.group(3)!);
  final hour = int.tryParse(m.group(4)!);
  final minute = int.tryParse(m.group(5)!);
  if (day == null || year == null || hour == null || minute == null) return 0;
  try {
    return DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;
  } catch (_) {
    return 0;
  }
}

_StreamedMatch? _streamedMatchFromStremioMeta(
  Map<String, dynamic> meta, {
  required String addonBaseUrl,
}) {
  final id = meta['id']?.toString().trim() ?? '';
  if (id.isEmpty) return null;
  final title = meta['name']?.toString().trim() ?? '';
  if (title.isEmpty) return null;
  final genres = meta['genres'];
  var category = '';
  if (genres is List && genres.isNotEmpty) {
    category = genres.first.toString().trim();
  }
  final release = meta['releaseInfo']?.toString().toUpperCase() ?? '';
  final desc = meta['description']?.toString().toUpperCase() ?? '';
  final dateMs = _stremioKickoffMsFromMeta(meta);
  final live = release.contains('LIVE') || desc.contains('LIVE NOW');
  final poster = meta['poster']?.toString() ?? '';
  final type = meta['type']?.toString().trim();
  // For leaf / 24/7 IPTV rows with LIVE but no kickoff, treat as always-on.
  final alwaysOn = live &&
      dateMs <= 0 &&
      (id.startsWith('leaf:') || desc.contains('IPTV'));
  return _StreamedMatch(
    id: id,
    title: title,
    category: alwaysOn
        ? '24/7'
        : (category.isEmpty ? 'other' : category.toLowerCase()),
    dateMs: dateMs,
    poster: poster,
    popular: desc.contains('POPULAR'),
    airing: live && dateMs <= 0,
    sources: const [],
    catalog: 'stremio',
    stremioBaseUrl: addonBaseUrl,
    stremioType: (type == null || type.isEmpty) ? 'sport' : type,
  );
}

Future<List<_StreamedMatch>> _fetchStremioSportMatches() async {
  final stremio = StremioService();
  final addons = await stremio.getAddonsForFeature(StremioAddonFeatures.live);
  if (addons.isEmpty) return [];

  final seen = <String>{};
  final out = <_StreamedMatch>[];
  for (final addon in addons) {
    final baseUrl = addon['baseUrl']?.toString() ?? '';
    if (baseUrl.isEmpty) continue;
    final catalogs = StremioService.sportCatalogsForLive(addon);
    for (final cat in catalogs) {
      final type = cat['type']?.toString() ?? 'sport';
      final catalogId = cat['id']?.toString() ?? '';
      if (catalogId.isEmpty) continue;
      try {
        final metas = await stremio.getCatalog(
          baseUrl: baseUrl,
          type: type,
          id: catalogId,
        );
        for (final meta in metas) {
          final match = _streamedMatchFromStremioMeta(
            meta,
            addonBaseUrl: baseUrl,
          );
          if (match == null) continue;
          if (!seen.add(match.id)) continue;
          out.add(match);
        }
      } catch (e) {
        debugPrint('[LiveMatches] Stremio catalog error ($baseUrl/$catalogId): $e');
      }
    }
  }
  return _sortStreamedLiveFirst(out);
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
        if (eventId != null) 'eventId': '$eventId',
        if (dateMs != null) 'dateMs': dateMs,
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
  required Map<String, dynamic> game,
  required String matchId,
}) {
  final cats = List<String>.from(categoryIds)..sort();
  final home = (game['homeTeam'] ?? '').toString().trim().toLowerCase();
  final away = (game['awayTeam'] ?? '').toString().trim().toLowerCase();
  final dateMs = '${game['dateMs'] ?? ''}';
  final id = matchId.trim().isNotEmpty
      ? matchId.trim()
      : (game['id'] ?? '').toString().trim();
  final channels = List<String>.from(
    (game['broadcastChannels'] as List?)
            ?.map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty) ??
        const <String>[],
  )..sort();
  final channelKey = channels.join('|');
  return '$portalKey|${cats.join(',')}|$id|$home|$away|$dateMs|$channelKey';
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
}) async {
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
  final sport = (game['sport'] ?? match.category).toString();
  final categoryIds = config.categoryIdsForGame(sport);
  final cacheKey = _iptvSportsStreamsCacheKey(
    portalKey: portalKey,
    categoryIds: categoryIds,
    game: game,
    matchId: match.id,
  );
  final cached = _iptvSportsStreamsCacheGet(cacheKey);
  if (cached != null) {
    debugPrint(
      '[LiveMatches] IPTV sports: cache hit (${cached.length} channels) '
      'ttl=${_iptvSportsStreamsCacheTtl.inMinutes}m',
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

Future<List<_StreamedStream>> _fetchStreamedStreams(
  _StreamedSourceRef sourceRef, {
  bool allowFallback = true,
}) async {
  if (sourceRef.source.trim().toLowerCase() == 'echo') return const [];
  try {
    final raw = await runLiveMatchesFetchJson(
      jsonEncode({
        'action': 'streamed_streams',
        'source': sourceRef.source,
        'id': sourceRef.id,
      }),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) {
      return allowFallback
          ? _streamedEmbedFallbackStreams(sourceRef)
          : const [];
    }
    final list = parsed['items'] as List? ?? [];
    final rows = list
        .map((s) {
          try {
            return _StreamedStream.fromJson(s as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<_StreamedStream>()
        .where((s) => s.embedUrl.isNotEmpty)
        .toList();
    if (rows.isNotEmpty) return rows;
    return allowFallback
        ? _streamedEmbedFallbackStreams(sourceRef)
        : const [];
  } catch (_) {
    return allowFallback
        ? _streamedEmbedFallbackStreams(sourceRef)
        : const [];
  }
}

_DamiTvStream _damiTvFromPpvCatalogRow(Map<String, dynamic> row) {
  final sources = row['sources'] as List?;
  final src = sources != null && sources.isNotEmpty
      ? Map<String, dynamic>.from(sources.first as Map)
      : const <String, dynamic>{};
  final rawId = (src['id'] ?? row['id'] ?? '')
      .toString()
      .replaceFirst(RegExp(r'^ppv_'), '');
  final categoryName = (row['category_name'] ?? row['category'] ?? '')
      .toString();
  final name = (row['title'] ?? '').toString();
  final (home, away) = resolveLiveMatchTeams(title: name);
  return _DamiTvStream(
    id: rawId,
    name: name,
    poster: (row['poster'] ?? '').toString(),
    startsAt: (row['starts_at'] as num?)?.toInt() ?? 0,
    endsAt: (row['ends_at'] as num?)?.toInt() ?? 0,
    categoryName: categoryName,
    status: row['airing'] == true ? 'live' : '',
    league: '',
    homeTeam: home.isEmpty ? null : home,
    awayTeam: away.isEmpty ? null : away,
    viewers: parsePpvViewers(row['viewers']),
    iframe: (row['iframe'] ?? src['iframe'] ?? '').toString(),
    alwaysLive: row['always_live'] == true,
  );
}

Future<List<_DamiTvStream>> _fetchDamiTvStreams() async {
  try {
    // Warm host label cache from plugin config (no hardcoded domain).
    await LiveMatchesEngine.ppvWebOrigin();
    final list = await LiveMatchesEngine.fetchServerCatalog('ppv');
    return list
        .map((s) {
          try {
            return _damiTvFromPpvCatalogRow(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<_DamiTvStream>()
        .toList();
  } catch (_) {
    return [];
  }
}

enum _LiveMatchesServer {
  all,
  ppv,
  streamed,
  mutStreams,
  forjaLive,
  stremio,
  iptvSports,
}

String _liveForjaPluginDisplayName(String pluginId) {
  return LiveMatchesEngine.cachedPluginDisplayName(pluginId);
}

/// True when an installed Stremio addon is wired to Live Matches.
///
/// Local prefs only — never awaits manifest hydrate on Live tab open. Catalog
/// shape is resolved when the Stremio server loads (`getAddonsForFeature`).
Future<bool> _liveMatchesStremioLiveEnabled() async {
  return StremioService().hasInstalledLiveAddons();
}

/// Server picker order: Forja Live first, Stremio last when available.
/// **All** / PPV / Streamed / MutStreams are hidden from the sheet.
List<_LiveMatchesServer> _liveMatchesServersForSurface({
  bool iptvSportsEnabled = false,
  bool stremioLiveEnabled = false,
}) {
  return [
    _LiveMatchesServer.forjaLive,
    if (iptvSportsEnabled) _LiveMatchesServer.iptvSports,
    if (stremioLiveEnabled) _LiveMatchesServer.stremio,
  ];
}

_LiveMatchesServer _liveMatchesClampServerForSurface(
  _LiveMatchesServer server, {
  bool iptvSportsEnabled = false,
  bool stremioLiveEnabled = false,
}) {
  final allowed = _liveMatchesServersForSurface(
    iptvSportsEnabled: iptvSportsEnabled,
    stremioLiveEnabled: stremioLiveEnabled,
  );
  if (allowed.contains(server)) return server;
  return _LiveMatchesServer.forjaLive;
}

String _liveMatchesServerLabel(_LiveMatchesServer server) => switch (server) {
  _LiveMatchesServer.all => 'All',
  _LiveMatchesServer.ppv => 'PPV',
  _LiveMatchesServer.streamed => 'Streamed',
  _LiveMatchesServer.mutStreams => 'MutStreams',
  _LiveMatchesServer.forjaLive => 'Forja Live',
  _LiveMatchesServer.stremio => 'Stremio',
  _LiveMatchesServer.iptvSports => 'Forja Sports',
};

String _liveMatchesServerSubtitle(_LiveMatchesServer server) =>
    switch (server) {
      _LiveMatchesServer.all => 'PPV · Streamed · Forja Live',
      _LiveMatchesServer.ppv => LiveMatchesEngine.ppvHostLabelCached(),
      _LiveMatchesServer.streamed => 'streamed.pk',
      _LiveMatchesServer.mutStreams => 'mut.st',
      _LiveMatchesServer.forjaLive => 'Engine live plugins',
      _LiveMatchesServer.stremio => 'Installed live addons',
      _LiveMatchesServer.iptvSports => 'Catalog schedule · your Xtream',
    };

sealed class _LiveMatchGridEntry {
  const _LiveMatchGridEntry();

  factory _LiveMatchGridEntry.ppv(_DamiTvStream stream) =
      _LiveMatchGridEntryPpv;

  factory _LiveMatchGridEntry.streamed(_StreamedMatch match) =
      _LiveMatchGridEntryStreamed;

  factory _LiveMatchGridEntry.merged(
    _DamiTvStream ppv,
    _StreamedMatch streamed,
  ) = _LiveMatchGridEntryMerged;
}

final class _LiveMatchGridEntryPpv extends _LiveMatchGridEntry {
  const _LiveMatchGridEntryPpv(this.stream);
  final _DamiTvStream stream;
}

final class _LiveMatchGridEntryStreamed extends _LiveMatchGridEntry {
  const _LiveMatchGridEntryStreamed(this.match);
  final _StreamedMatch match;
}

final class _LiveMatchGridEntryMerged extends _LiveMatchGridEntry {
  const _LiveMatchGridEntryMerged(this.ppv, this.streamed);
  final _DamiTvStream ppv;
  final _StreamedMatch streamed;
}

