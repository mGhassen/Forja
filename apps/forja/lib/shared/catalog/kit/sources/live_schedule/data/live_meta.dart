part of '../live_sports_hub_page.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

/// Leanback TV — not desktop D-pad (which also uses focusable mood chips).
bool _liveMatchesLeanbackOnly(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity;

/// Grid (card catalog) vs vertical timeline layout for the body.
enum _LiveMatchesView { grid, timeline }

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

class _IframeCatalogStream {
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

  const _IframeCatalogStream({
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
  bool get isAlwaysOn => iframeCatalogStreamIsAlwaysOn(
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

  bool get isLive => iframeCatalogStreamIsLive(
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

  /// Installed addon display name when [stremioBaseUrl] is set (e.g. Leaf).
  final String stremioAddonName;

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
    this.stremioAddonName = '',
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
      viewers: parseLiveViewerCount(j['viewers']),
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
      stremioAddonName: (j['stremioAddonName'] ?? '').toString(),
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
          (isStremio && (category == '24/7' || category == '24-7')));

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

  _StreamedMatch withViewerCount(int viewers) => _StreamedMatch(
    id: id,
    title: title,
    category: category,
    dateMs: dateMs,
    poster: poster,
    popular: popular,
    airing: airing,
    viewers: viewers,
    homeTeam: homeTeam,
    homeBadge: homeBadge,
    awayTeam: awayTeam,
    awayBadge: awayBadge,
    sources: sources,
    inlineStreams: inlineStreams,
    catalog: catalog,
    stremioBaseUrl: stremioBaseUrl,
    stremioType: stremioType,
    stremioAddonName: stremioAddonName,
    sportMatchGame: sportMatchGame,
    livePluginId: livePluginId,
  );
}

class _StreamedStream {
  final String id;
  final int streamNo;
  final String language;
  final bool hd;
  final String embedUrl;
  final String source;
  final int viewers;
  /// Plugin already returned a native play URL (`directPlayback` / unlocked).
  final bool directPlayback;
  /// Headers the plugin returned alongside the resolved URL.
  /// When non-null, these take priority over fabricated headers in playback.
  final Map<String, String>? resolvedHeaders;

  const _StreamedStream({
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

  factory _StreamedStream.fromJson(Map<String, dynamic> j) => _StreamedStream(
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

/// Mirror rows for one catalog source ref — inline catalog streams or streamed.pk API.
Future<List<_StreamedStream>> _catalogStreamsForSourceRef(
  _StreamedMatch match,
  _StreamedSourceRef sourceRef, {
  bool allowFallback = true,
}) async {
  final token = sourceRef.source.trim().toLowerCase();
  if (token.isNotEmpty) {
    final inline = match.inlineStreams
        .where((s) => s.source.trim().toLowerCase() == token)
        .toList();
    if (inline.isNotEmpty) return inline;
  }
  return _fetchStreamedStreams(sourceRef, allowFallback: allowFallback);
}

_StreamedStream _streamedStreamFromResolveRow({
  required Map<String, dynamic> row,
  required _StreamedSourceRef source,
  required _StreamedMatch match,
  required String pluginSource,
  _StreamedStream? catalogMeta,
  required int index,
}) {
  final rowViewers = parseLiveViewerCount(row['viewers']);
  final nameRaw = (row['name'] ?? row['title'] ?? catalogMeta?.language ?? '')
      .toString();
  final fields = forjaLiveStreamFieldsFromRowName(nameRaw);
  final langFromRow = (row['language'] ?? '').toString().trim();
  final language = langFromRow.isNotEmpty
      ? langFromRow
      : (fields.language.isNotEmpty
            ? fields.language
            : (catalogMeta?.language ?? ''));
  final hd = row['hd'] == true || catalogMeta?.hd == true || fields.hd;
  final metaViewers = catalogMeta?.viewers ?? 0;
  final viewers = rowViewers > 0
      ? rowViewers
      : (metaViewers > 0 ? metaViewers : match.viewers);
  final url = (row['url'] ?? '').toString().trim();
  final sourceToken = catalogMeta?.source.trim().isNotEmpty == true
      ? catalogMeta!.source
      : pluginSource;
  Map<String, String>? resolvedHeaders;
  final h = row['headers'];
  if (h is Map && h.isNotEmpty) {
    resolvedHeaders = {
      for (final e in h.entries) e.key.toString(): e.value.toString(),
    };
  }

  return _StreamedStream(
    id: source.id,
    streamNo: catalogMeta?.streamNo ?? index + 1,
    language: language,
    hd: hd,
    embedUrl: url,
    source: sourceToken,
    viewers: viewers,
    directPlayback: row['directPlayback'] == true ||
        iptvLiveEnginePlayUrlReady(url),
    resolvedHeaders: resolvedHeaders,
  );
}

/// Sum mirror viewers from streamed.pk `/api/stream/{source}/{id}` (not on match rows).
Future<int> _streamedMatchViewerTotalFromSources(_StreamedMatch match) async {
  if (match.sources.isEmpty) return 0;
  var total = 0;
  for (final ref in match.sources) {
    if (ref.source.trim().toLowerCase() == 'echo') continue;
    final streams = await _fetchStreamedStreams(ref, allowFallback: false);
    for (final stream in streams) {
      if (stream.viewers > 0) total += stream.viewers;
    }
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

List<_IframeCatalogStream> _sortIframeCatalogLiveFirst(List<_IframeCatalogStream> items) {
  final sorted = List<_IframeCatalogStream>.from(items);
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

/// When true, hides the Catalog / Schedule top-bar chips only — grid still loads.
const kLiveMatchesCatalogFiltersHidden = false;

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

/// Catalog chip id for an installed live Stremio addon (`stremio:<baseUrl>`).
const _kStremioCatalogFilterPrefix = 'stremio:';

bool _isStremioCatalogFilter(String filter) =>
    filter.startsWith(_kStremioCatalogFilterPrefix);

String _stremioCatalogFilterId(String baseUrl) {
  final normalized = SettingsService.normalizeStremioAddonBaseUrl(baseUrl.trim());
  return '$_kStremioCatalogFilterPrefix$normalized';
}

String? _stremioBaseUrlFromCatalogFilter(String filter) {
  if (!_isStremioCatalogFilter(filter)) return null;
  final raw = filter.substring(_kStremioCatalogFilterPrefix.length).trim();
  if (raw.isEmpty) return null;
  final normalized = SettingsService.normalizeStremioAddonBaseUrl(raw);
  return normalized.isEmpty ? null : normalized;
}

bool _liveCatalogRowMatchesFilter(_StreamedMatch row, String filter) {
  if (filter == 'all' || filter.isEmpty) return true;
  if (_isStremioCatalogFilter(filter)) {
    final base = _stremioBaseUrlFromCatalogFilter(filter);
    if (base == null || !row.isStremio) return false;
    return SettingsService.normalizeStremioAddonBaseUrl(row.stremioBaseUrl) ==
        base;
  }
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
  if (_isStremioCatalogFilter(catalogFilter)) {
    final scoped =
        pool.where((m) => _liveCatalogRowMatchesFilter(m, catalogFilter)).toList();
    return _mergeStreamedCatalogRows(_sortStreamedLiveFirst(scoped));
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

bool _iframeCatalogInScheduleFilter(
  _IframeCatalogStream stream, {
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
  _LiveMatchGridEntryIframeCatalog(:final stream) => stream.isLive,
  _LiveMatchGridEntryStreamed(:final match) => match.isLive,
  _LiveMatchGridEntryMerged(:final iframeCatalog, :final streamed) =>
    iframeCatalog.isLive || streamed.isLive,
};

int _gridEntryStartKey(_LiveMatchGridEntry entry) => switch (entry) {
  _LiveMatchGridEntryIframeCatalog(:final stream) => stream.startsAt,
  _LiveMatchGridEntryStreamed(:final match) => match.dateMs,
  _LiveMatchGridEntryMerged(:final streamed) => streamed.dateMs,
};

int _gridEntryViewers(_LiveMatchGridEntry entry) => switch (entry) {
  _LiveMatchGridEntryIframeCatalog(:final stream) => stream.viewers,
  _LiveMatchGridEntryStreamed(:final match) => match.viewers,
  _LiveMatchGridEntryMerged(:final iframeCatalog, :final streamed) =>
    iframeCatalog.viewers + streamed.viewers,
};

String _matchTextKey(String raw) {
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

bool _sameIframeAndScheduleEvent(_IframeCatalogStream iframeCatalog, _StreamedMatch streamed) {
  if (iframeCatalog.isAlwaysOn || streamed.isAlwaysOn) return false;
  if (iframeCatalog.startsAt <= 0 || streamed.dateMs <= 0) return false;
  final iframeSport = _normalizeSportId(iframeCatalog.categoryName);
  final streamedSport = _normalizeSportId(streamed.category);
  if (iframeSport.isEmpty || streamedSport.isEmpty || iframeSport != streamedSport) {
    return false;
  }
  final deltaMs = (iframeCatalog.startsAt * 1000 - streamed.dateMs).abs();
  if (deltaMs > const Duration(minutes: 30).inMilliseconds) return false;

  final iframeTeams = _teamPairKeyFromCatalog(
    homeTeam: iframeCatalog.homeTeam,
    awayTeam: iframeCatalog.awayTeam,
    title: iframeCatalog.name,
  );
  final streamedTeams = _teamPairKeyFromCatalog(
    homeTeam: streamed.homeTeam,
    awayTeam: streamed.awayTeam,
    title: streamed.title,
  );
  if (iframeTeams != null && streamedTeams != null) {
    if (iframeTeams == streamedTeams) return true;
  }
  final (iframeHome, iframeAway) = resolveLiveMatchTeams(
    homeTeam: iframeCatalog.homeTeam,
    awayTeam: iframeCatalog.awayTeam,
    title: iframeCatalog.name,
  );
  final (streamedHome, streamedAway) = resolveLiveMatchTeams(
    homeTeam: streamed.homeTeam,
    awayTeam: streamed.awayTeam,
    title: streamed.title,
  );
  if (liveTeamPairSoftEqual(
    iframeHome,
    iframeAway,
    streamedHome,
    streamedAway,
  )) {
    return true;
  }
  final iframeTitle = _matchTextKey(iframeCatalog.name);
  final streamedTitle = _matchTextKey(streamed.title);
  if (iframeTitle.isNotEmpty &&
      streamedTitle.isNotEmpty &&
      iframeTitle == streamedTitle) {
    return true;
  }
  return liveEventSessionSoftEqual(iframeCatalog.name, streamed.title);
}

List<_StreamedMatch> _streamedMatchesForEvent(
  _StreamedMatch match,
  List<_StreamedMatch> pool,
) =>
    pool.where((m) => _sameStreamedEvent(match, m)).toList();

bool _streamedMatchSameIdentity(_StreamedMatch a, _StreamedMatch b) {
  if (a.id.isNotEmpty && b.id.isNotEmpty && a.id == b.id) return true;
  return _sameStreamedEvent(a, b);
}

/// Pool siblings plus the opened row — details Providers must never drop the anchor.
List<_StreamedMatch> _eventMatchesForStreamResolve(
  _StreamedMatch match,
  List<_StreamedMatch> pool,
) {
  final siblings = _streamedMatchesForEvent(match, pool).toList();
  if (!siblings.any((m) => _streamedMatchSameIdentity(m, match))) {
    siblings.add(match);
  }
  return siblings;
}

/// Each matching catalog row stays its own Providers resolve target.
///
/// Catalogs may merge on the schedule grid; providers never merge — Streamed,
/// TimStreams, PPV, … each resolve through their own live plugin + refs.
List<_StreamedMatch> _providerResolveTargets(
  _StreamedMatch anchor,
  List<_StreamedMatch> pool,
) {
  final out = <_StreamedMatch>[];
  final seen = <String>{};
  for (final m in _eventMatchesForStreamResolve(anchor, pool)) {
    final row = _ensureProviderResolveMatch(m);
    final resolveId = LiveMatchesEngine.cachedProviderResolvePluginId(
      row.livePluginId.isNotEmpty ? row.livePluginId : anchor.livePluginId,
    );
    final key = [
      LiveMatchesEngine.resolvePluginKey(
        resolveId.isNotEmpty ? resolveId : row.livePluginId,
      ),
      row.id,
      for (final ref in row.sources) '${ref.source}:${ref.id}',
    ].join('|');
    if (key.isEmpty || !seen.add(key)) continue;
    if (row.sources.isEmpty && row.inlineStreams.isEmpty) continue;
    out.add(row);
  }
  if (out.isEmpty) {
    final fallback = _ensureProviderResolveMatch(anchor);
    if (fallback.sources.isNotEmpty || fallback.inlineStreams.isNotEmpty) {
      return [fallback];
    }
  }
  return out;
}

/// Catalog rows normally carry `sources[]`; synthesize when the grid row lost them.
_StreamedMatch _ensureProviderResolveMatch(_StreamedMatch match) {
  if (match.sources.isNotEmpty || match.inlineStreams.isNotEmpty) {
    return match;
  }
  if (!match.isForjaLive || match.id.isEmpty || match.livePluginId.isEmpty) {
    return match;
  }
  if (LiveMatchesEngine.cachedIsScheduleEnrichCatalog(match.livePluginId)) {
    return match;
  }
  final resolvePluginId =
      LiveMatchesEngine.cachedProviderResolvePluginId(match.livePluginId);
  if (resolvePluginId.isEmpty) return match;
  final source = LiveMatchesEngine.cachedResolveSourceToken(resolvePluginId);
  final refId = LiveMatchesEngine.cachedResolveRefId(
    match.id,
    match.livePluginId,
  );
  if (source.isEmpty || refId.isEmpty) return match;
  return _StreamedMatch(
    id: match.id,
    title: match.title,
    category: match.category,
    dateMs: match.dateMs,
    poster: match.poster,
    popular: match.popular,
    airing: match.airing,
    viewers: match.viewers,
    homeTeam: match.homeTeam,
    homeBadge: match.homeBadge,
    awayTeam: match.awayTeam,
    awayBadge: match.awayBadge,
    sources: [_StreamedSourceRef(source: source, id: refId)],
    inlineStreams: match.inlineStreams,
    catalog: match.catalog,
    stremioBaseUrl: match.stremioBaseUrl,
    stremioType: match.stremioType,
    stremioAddonName: match.stremioAddonName,
    sportMatchGame: match.sportMatchGame,
    livePluginId: resolvePluginId,
  );
}

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

String _liveEventViewerKeyFromIframeCatalog(_IframeCatalogStream iframeCatalog) {
  final teams = _teamPairKeyFromCatalog(
    homeTeam: iframeCatalog.homeTeam,
    awayTeam: iframeCatalog.awayTeam,
    title: iframeCatalog.name,
  );
  if (teams != null) return 't:$teams';
  final title = _matchTextKey(iframeCatalog.name);
  if (title.isNotEmpty && iframeCatalog.startsAt > 0) {
    return 'n:$title@${iframeCatalog.startsAt ~/ 60}';
  }
  if (title.isNotEmpty) return 'n:$title';
  return 'id:iframe:${iframeCatalog.id}';
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
    stremioAddonName: primary.stremioAddonName.isNotEmpty
        ? primary.stremioAddonName
        : other.stremioAddonName,
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

bool _liveEventDatesCloseEnough(_StreamedMatch a, _StreamedMatch b) {
  if (a.dateMs <= 0 || b.dateMs <= 0) return true;
  final deltaMs = (a.dateMs - b.dateMs).abs();
  return deltaMs <= const Duration(hours: 6).inMilliseconds;
}

/// Cross-catalog match for TV native picker (All card → Stremio addon event).
bool _sameStreamedEvent(_StreamedMatch a, _StreamedMatch b) {
  if (a.isAlwaysOn || b.isAlwaysOn) return false;
  if (a.id.isNotEmpty && b.id.isNotEmpty && a.id == b.id) return true;
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
  if (teamsA != null && teamsB != null && teamsA == teamsB) return true;

  // Soft: PPV "Colorado Buffaloes at Georgia Tech Yellow Jackets" ↔
  // Streamed "Georgia Tech vs Colorado" (mascot / short-name drift).
  final (homeA, awayA) = resolveLiveMatchTeams(
    homeTeam: a.homeTeam,
    awayTeam: a.awayTeam,
    title: a.title,
  );
  final (homeB, awayB) = resolveLiveMatchTeams(
    homeTeam: b.homeTeam,
    awayTeam: b.awayTeam,
    title: b.title,
  );
  if (liveTeamPairSoftEqual(homeA, awayA, homeB, awayB) &&
      _liveEventDatesCloseEnough(a, b)) {
    return true;
  }

  final titleA = _matchTextKey(a.title);
  final titleB = _matchTextKey(b.title);
  if (titleA.isNotEmpty &&
      titleB.isNotEmpty &&
      titleA == titleB &&
      _liveEventDatesCloseEnough(a, b)) {
    return true;
  }
  // Motorsport / named sessions: "Practice 2" ↔ "2nd Practice" when cores overlap.
  return liveEventSessionSoftEqual(a.title, b.title) &&
      _liveEventDatesCloseEnough(a, b);
}

bool _iframeCatalogTimesCloseEnough(
  _IframeCatalogStream a,
  _IframeCatalogStream b,
) {
  if (a.isAlwaysOn || b.isAlwaysOn) return true;
  if (a.startsAt <= 0 || b.startsAt <= 0) return true;
  final deltaSec = (a.startsAt - b.startsAt).abs();
  return deltaSec <= const Duration(minutes: 30).inSeconds;
}

bool _sameIframeCatalogStream(_IframeCatalogStream a, _IframeCatalogStream b) {
  if (a.id.isNotEmpty && b.id.isNotEmpty && a.id == b.id) return true;
  if (_normalizeSportId(a.categoryName) != _normalizeSportId(b.categoryName)) {
    return false;
  }
  final teamsA = _teamPairKeyFromCatalog(
    homeTeam: a.homeTeam,
    awayTeam: a.awayTeam,
    title: a.name,
  );
  final teamsB = _teamPairKeyFromCatalog(
    homeTeam: b.homeTeam,
    awayTeam: b.awayTeam,
    title: b.name,
  );
  if (teamsA != null && teamsB != null && teamsA == teamsB) {
    return _iframeCatalogTimesCloseEnough(a, b);
  }
  final (homeA, awayA) = resolveLiveMatchTeams(
    homeTeam: a.homeTeam,
    awayTeam: a.awayTeam,
    title: a.name,
  );
  final (homeB, awayB) = resolveLiveMatchTeams(
    homeTeam: b.homeTeam,
    awayTeam: b.awayTeam,
    title: b.name,
  );
  if (liveTeamPairSoftEqual(homeA, awayA, homeB, awayB)) {
    return _iframeCatalogTimesCloseEnough(a, b);
  }
  final titleA = _matchTextKey(a.name);
  final titleB = _matchTextKey(b.name);
  if (titleA.isEmpty || titleB.isEmpty || titleA != titleB) return false;
  return _iframeCatalogTimesCloseEnough(a, b);
}

String? _iframeCatalogMergeBucketKey(_IframeCatalogStream s) {
  if (s.isAlwaysOn) {
    final title = _matchTextKey(s.name);
    if (title.isEmpty) return null;
    return '247:$title';
  }
  final teams = _teamPairKeyFromCatalog(
    homeTeam: s.homeTeam,
    awayTeam: s.awayTeam,
    title: s.name,
  );
  if (teams != null) return 't:$teams';
  final title = _matchTextKey(s.name);
  if (title.isEmpty) return null;
  return 'n:$title';
}

_IframeCatalogStream _mergeIframeCatalogPair(
  _IframeCatalogStream a,
  _IframeCatalogStream b,
) {
  final primary = a.isLive != b.isLive ? (a.isLive ? a : b) : a;
  final other = identical(primary, a) ? b : a;
  return _IframeCatalogStream(
    id: primary.id.isNotEmpty ? primary.id : other.id,
    name: primary.name.isNotEmpty ? primary.name : other.name,
    poster: primary.poster.isNotEmpty ? primary.poster : other.poster,
    startsAt: primary.startsAt > 0 ? primary.startsAt : other.startsAt,
    endsAt: primary.endsAt > 0 ? primary.endsAt : other.endsAt,
    categoryName: primary.categoryName.isNotEmpty
        ? primary.categoryName
        : other.categoryName,
    status: primary.isLive ? primary.status : other.status,
    league: primary.league.isNotEmpty ? primary.league : other.league,
    homeTeam: _nonEmptyOrNull(primary.homeTeam) ?? other.homeTeam,
    awayTeam: _nonEmptyOrNull(primary.awayTeam) ?? other.awayTeam,
    viewers: primary.viewers + other.viewers,
    iframe: primary.iframe.isNotEmpty ? primary.iframe : other.iframe,
    alwaysLive: primary.alwaysLive || other.alwaysLive,
  );
}

List<_IframeCatalogStream> _mergeIframeCatalogRows(
  List<_IframeCatalogStream> streams,
) {
  if (streams.length < 2) return streams;
  final out = <_IframeCatalogStream>[];
  final buckets = <String, List<int>>{};
  for (final s in streams) {
    final bucketKey = _iframeCatalogMergeBucketKey(s);
    var merged = false;
    if (bucketKey != null) {
      final candidates = buckets[bucketKey];
      if (candidates != null) {
        for (final idx in candidates) {
          if (_sameIframeCatalogStream(out[idx], s)) {
            out[idx] = _mergeIframeCatalogPair(out[idx], s);
            merged = true;
            break;
          }
        }
      }
    }
    if (merged) continue;
    final storeKey = bucketKey ?? 'id:${s.id}';
    (buckets[storeKey] ??= []).add(out.length);
    out.add(s);
  }
  return out;
}

/// Id token after the last `:` (Highfly often reuses `streamed:<streamedId>`).
String _liveEventIdToken(String id) {
  final t = id.trim().toLowerCase();
  if (t.isEmpty) return '';
  final colon = t.lastIndexOf(':');
  if (colon >= 0 && colon < t.length - 1) return t.substring(colon + 1);
  return t;
}

/// Engine schedule row ↔ Stremio meta (teams/title, or shared streamed id).
bool _stremioCatalogEventMatch(_StreamedMatch engine, _StreamedMatch stremio) {
  if (_sameStreamedEvent(engine, stremio)) return true;
  if (engine.id.isNotEmpty &&
      stremio.id.isNotEmpty &&
      engine.id.toLowerCase() == stremio.id.toLowerCase()) {
    return true;
  }
  final tokenA = _liveEventIdToken(engine.id);
  final tokenB = _liveEventIdToken(stremio.id);
  return tokenA.isNotEmpty && tokenA == tokenB;
}

/// When exact fixture match misses: same session key, and either shared title
/// tokens or this session is unique in [catalog] (e.g. only one Practice 2).
List<_StreamedMatch> _stremioSessionSoftHits(
  _StreamedMatch engine,
  List<_StreamedMatch> catalog,
) {
  if (engine.isAlwaysOn) return const [];
  final session = liveEventSessionKey(engine.title);
  if (session == null) return const [];
  final candidates = [
    for (final m in catalog)
      if (!m.isAlwaysOn && liveEventSessionKey(m.title) == session) m,
  ];
  if (candidates.isEmpty) return const [];
  return [
    for (final m in candidates)
      if (liveEventSessionSoftEqual(
        engine.title,
        m.title,
        candidateCountForSession: candidates.length,
      ))
        m,
  ];
}

List<_LiveMatchGridEntry> _mergeIframeAndScheduleEntries({
  required List<_IframeCatalogStream> iframeCatalog,
  required List<_StreamedMatch> streamed,
}) {
  final mergedIframe = _mergeIframeCatalogRows(iframeCatalog);
  final remainingStreamed = [...streamed];
  final entries = <_LiveMatchGridEntry>[];
  for (final stream in mergedIframe) {
    final matchIndex = remainingStreamed.indexWhere(
      (match) => _sameIframeAndScheduleEvent(stream, match),
    );
    if (matchIndex < 0) {
      entries.add(_LiveMatchGridEntry.iframeCatalog(stream));
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
String _streamedImageUrl(String path) {
  if (path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  if (path.startsWith('/')) return '$_streamedBase$path';
  return '$_streamedBase/api/images/badge/$path.webp';
}

/// embedindia JW Player resolves tokenised HLS inside the embed browsing
/// context. Native playback needs Referer/Origin from the embed page.
Map<String, String> _tokenizedEmbedStreamHeaders(String embedUrl) {
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
  // WatchFooty HLS (`lb*.wfty.st`) validates Referer against the sportsembed
  // player page — origin-root Referer gets a 500 / PNG decoy playlist.
  if (host.contains('wfty.st')) {
    return LiveGoatUnlock.sportsEmbedRefererFromWftyPlaylist(embedUrl) ??
        'https://sportsembed.su/';
  }
  return '${uri.origin}/';
}

/// Kickoff epoch-ms from a Stremio sport meta.
///
/// Sources tried in order:
/// 1. `released` — ISO-8601 or unix seconds/ms
/// 2. `releaseInfo` — e.g. `06 Aug 2026 · 07:10 UTC`
/// 3. `description` lines — same human date format
/// 4. title calendar date + `Time: HH:MM` in description
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

  return stremioKickoffMsFromTitleAndTime(
    title: meta['name']?.toString() ?? '',
    description: desc,
  );
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

String _stremioAddonNameFromInstall(Map<String, dynamic> addon) {
  final name = (addon['name']?.toString() ?? '').trim();
  if (name.isNotEmpty) return name;
  final manifest = addon['manifest'];
  if (manifest is Map) {
    final mname = (manifest['name']?.toString() ?? '').trim();
    if (mname.isNotEmpty) return mname;
  }
  return '';
}

Future<String?> _stremioAddonNameForBaseUrl(String baseUrl) async {
  final normalized = SettingsService.normalizeStremioAddonBaseUrl(baseUrl.trim());
  if (normalized.isEmpty) return null;
  final addons = await StremioService().peekAddonsForFeature(
    StremioAddonFeatures.live,
  );
  for (final addon in addons) {
    final url = SettingsService.normalizeStremioAddonBaseUrl(
      addon['baseUrl']?.toString() ?? '',
    );
    if (url.isEmpty || url != normalized) continue;
    final name = _stremioAddonNameFromInstall(addon);
    if (name.isNotEmpty) return name;
  }
  return null;
}

Future<String> _resolveStremioAddonName({
  required String baseUrl,
  String matchAddonName = '',
}) async {
  final fromMatch = matchAddonName.trim();
  if (fromMatch.isNotEmpty) return fromMatch;
  return (await _stremioAddonNameForBaseUrl(baseUrl)) ?? '';
}

String _stremioLiveProviderBadge(String? addonName) {
  final addon = (addonName ?? '').trim();
  if (addon.isEmpty) return 'Stremio';
  return 'Stremio · $addon';
}

String _stremioStreamDisplayLabel(String rawName, String? addonName) {
  final name = rawName.trim();
  if (name.isEmpty) return 'Stream';
  final addon = (addonName ?? '').trim();
  if (addon.isNotEmpty) {
    final prefix = '$addon · ';
    if (name.startsWith(prefix)) {
      final stripped = name.substring(prefix.length).trim();
      if (stripped.isNotEmpty) return stripped;
    }
    final parts = name.split(RegExp(r'\s*[·•]\s*'));
    if (parts.length >= 2 &&
        parts.first.trim().toLowerCase() == addon.toLowerCase()) {
      final stripped = parts.sublist(1).join(' · ').trim();
      if (stripped.isNotEmpty) return stripped;
    }
  }
  // Upstream labels often prefix with an internal tag (e.g. Leaf · channel).
  final parts = name.split(RegExp(r'\s*[·•]\s*'));
  if (parts.length >= 2) {
    final stripped = parts.sublist(1).join(' · ').trim();
    if (stripped.isNotEmpty) return stripped;
  }
  return name;
}

_StreamedMatch? _streamedMatchFromStremioMeta(
  Map<String, dynamic> meta, {
  required String addonBaseUrl,
  String addonName = '',
}) {
  final id = meta['id']?.toString().trim() ?? '';
  if (id.isEmpty) return null;
  final title = meta['name']?.toString().trim() ?? '';
  if (title.isEmpty) return null;
  final genres = meta['genres'] is List ? meta['genres'] as List : const [];
  final release = meta['releaseInfo']?.toString().toUpperCase() ?? '';
  final descRaw = meta['description']?.toString() ?? '';
  final desc = descRaw.toUpperCase();
  final dateMs = _stremioKickoffMsFromMeta(meta);
  final poster = meta['poster']?.toString() ?? '';
  final type = meta['type']?.toString().trim();
  final live = stremioMetaLooksLive(
    releaseInfoUpper: release,
    descriptionUpper: desc,
    poster: poster,
    genres: genres,
  );
  // Live + no kickoff + no schedule clock/date → 24/7 channel feed.
  final alwaysOn = stremioMetaIsAlwaysOnChannel(
    looksLive: live,
    dateMs: dateMs,
    descriptionUpper: desc,
    title: title,
    genres: genres,
  );
  final categoryRaw = alwaysOn
      ? '24/7'
      : stremioCategoryFromGenres(genres);
  return _StreamedMatch(
    id: id,
    title: title,
    category: categoryRaw.isEmpty ? 'other' : categoryRaw.toLowerCase(),
    dateMs: dateMs,
    poster: poster,
    popular: desc.contains('POPULAR'),
    // No kickoff + live badge → airing now (events + channels).
    airing: live && dateMs <= 0,
    sources: const [],
    catalog: 'stremio',
    stremioBaseUrl: addonBaseUrl,
    stremioType: (type == null || type.isEmpty) ? 'sport' : type,
    stremioAddonName: addonName.trim(),
  );
}

Future<List<_StreamedMatch>> _fetchStremioSportMatchesForAddon(
  Map<String, dynamic> addon, {
  StremioService? service,
}) async {
  final stremio = service ?? StremioService();
  final baseUrl = addon['baseUrl']?.toString() ?? '';
  if (baseUrl.isEmpty) return const [];
  final addonName = _stremioAddonNameFromInstall(addon);
  final catalogs = StremioService.sportCatalogsForLive(addon);
  final seen = <String>{};
  final out = <_StreamedMatch>[];
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
          addonName: addonName,
        );
        if (match == null) continue;
        if (!seen.add(match.id)) continue;
        out.add(match);
      }
    } catch (e) {
      debugPrint('[LiveMatches] Stremio catalog error ($baseUrl/$catalogId): $e');
    }
  }
  return out;
}

Future<List<_StreamedMatch>> _fetchStremioSportMatches() async {
  final stremio = StremioService();
  final addons = await stremio.getAddonsForFeature(StremioAddonFeatures.live);
  if (addons.isEmpty) return [];

  final seen = <String>{};
  final out = <_StreamedMatch>[];
  for (final addon in addons) {
    for (final match in await _fetchStremioSportMatchesForAddon(
      addon,
      service: stremio,
    )) {
      if (!seen.add(match.id)) continue;
      out.add(match);
    }
  }
  return _sortStreamedLiveFirst(out);
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

_IframeCatalogStream _iframeCatalogFromRow(Map<String, dynamic> row) {
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
  return _IframeCatalogStream(
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
    viewers: parseLiveViewerCount(row['viewers']),
    iframe: (row['iframe'] ?? src['iframe'] ?? '').toString(),
    alwaysLive: row['always_live'] == true,
  );
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

sealed class _LiveMatchGridEntry {
  const _LiveMatchGridEntry();

  factory _LiveMatchGridEntry.iframeCatalog(_IframeCatalogStream stream) =
      _LiveMatchGridEntryIframeCatalog;

  factory _LiveMatchGridEntry.streamed(_StreamedMatch match) =
      _LiveMatchGridEntryStreamed;

  factory _LiveMatchGridEntry.merged(
    _IframeCatalogStream iframeCatalog,
    _StreamedMatch streamed,
  ) = _LiveMatchGridEntryMerged;
}

final class _LiveMatchGridEntryIframeCatalog extends _LiveMatchGridEntry {
  const _LiveMatchGridEntryIframeCatalog(this.stream);
  final _IframeCatalogStream stream;
}

final class _LiveMatchGridEntryStreamed extends _LiveMatchGridEntry {
  const _LiveMatchGridEntryStreamed(this.match);
  final _StreamedMatch match;
}

final class _LiveMatchGridEntryMerged extends _LiveMatchGridEntry {
  const _LiveMatchGridEntryMerged(this.iframeCatalog, this.streamed);
  final _IframeCatalogStream iframeCatalog;
  final _StreamedMatch streamed;
}

