part of 'live_matches_screen.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

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

class _Sport {
  final String id;
  final String name;
  const _Sport({required this.id, required this.name});
}

class _CdnChannel {
  final String name;
  final String code;
  final String url;
  final String image;
  final String status;
  final int viewers;

  const _CdnChannel({
    required this.name,
    required this.code,
    required this.url,
    required this.image,
    required this.status,
    required this.viewers,
  });

  factory _CdnChannel.fromJson(Map<String, dynamic> j) => _CdnChannel(
    name: (j['name'] ?? '').toString(),
    code: (j['code'] ?? '').toString(),
    url: (j['url'] ?? '').toString(),
    image: (j['image'] ?? '').toString(),
    status: (j['status'] ?? 'offline').toString(),
    viewers: (j['viewers'] as num?)?.toInt() ?? 0,
  );
}

class _CdnSportEvent {
  final String gameID;
  final String homeTeam;
  final String awayTeam;
  final String homeTeamIMG;
  final String awayTeamIMG;
  final String time;
  final String tournament;

  /// Parent CDN bucket (Soccer / NFL / NBA / NHL), injected by Rust flatten.
  final String sport;
  final String country;
  final String countryIMG;
  final String status;
  final String start;
  final String end;
  final List<_CdnChannel> channels;

  const _CdnSportEvent({
    required this.gameID,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeTeamIMG,
    required this.awayTeamIMG,
    required this.time,
    required this.tournament,
    required this.sport,
    required this.country,
    required this.countryIMG,
    required this.status,
    required this.start,
    required this.end,
    required this.channels,
  });

  factory _CdnSportEvent.fromJson(Map<String, dynamic> j) => _CdnSportEvent(
    gameID: (j['gameID'] ?? '').toString(),
    homeTeam: (j['homeTeam'] ?? '').toString(),
    awayTeam: (j['awayTeam'] ?? '').toString(),
    homeTeamIMG: (j['homeTeamIMG'] ?? '').toString(),
    awayTeamIMG: (j['awayTeamIMG'] ?? '').toString(),
    time: (j['time'] ?? '').toString(),
    tournament: (j['tournament'] ?? '').toString(),
    sport: (j['sport'] ?? '').toString(),
    country: (j['country'] ?? '').toString(),
    countryIMG: (j['countryIMG'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    start: (j['start'] ?? '').toString(),
    end: (j['end'] ?? '').toString(),
    channels: (j['channels'] as List? ?? [])
        .map((c) => _CdnChannel.fromJson(c as Map<String, dynamic>))
        .toList(),
  );

  bool get isLive => status.toLowerCase() == 'live';
}

/// Canonical sport chip id across PPV / Streamed / CDN label variants.
///
/// PPV uses Title Case (`American Football`); Streamed uses kebab slugs
/// (`american-football`); CDN uses bucket names (`Soccer`, `NFL`).
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
  final String? homeBadge;
  final String? awayTeam;
  final String? awayBadge;
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
    this.homeTeam,
    this.homeBadge,
    this.awayTeam,
    this.awayBadge,
    required this.viewers,
    required this.iframe,
    this.alwaysLive = false,
  });

  factory _DamiTvStream.fromJson(Map<String, dynamic> j) {
    final teams = j['teams'] as Map<String, dynamic>?;
    final home = teams?['home'] as Map<String, dynamic>?;
    final away = teams?['away'] as Map<String, dynamic>?;

    String abs(String path) {
      if (path.startsWith('/')) return 'https://ppv.is$path';
      return path;
    }

    final league = (j['league'] ?? j['tag'] ?? j['source_tag'] ?? '')
        .toString();

    return _DamiTvStream(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      poster: abs((j['poster'] ?? '').toString()),
      startsAt: (j['starts_at'] as num?)?.toInt() ?? 0,
      endsAt: (j['ends_at'] as num?)?.toInt() ?? 0,
      categoryName: (j['category_name'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      league: league,
      homeTeam: home?['name'] as String?,
      homeBadge: abs((home?['badge'] ?? '').toString()),
      awayTeam: away?['name'] as String?,
      awayBadge: abs((away?['badge'] ?? '').toString()),
      viewers: parsePpvViewers(j['viewers']),
      iframe: (j['iframe'] ?? '').toString(),
      alwaysLive: parsePpvAlwaysLive(j['always_live']),
    );
  }

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
      final dt = DateTime.fromMillisecondsSinceEpoch(startsAt * 1000);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

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
  const _StreamedSourceRef({required this.source, required this.id});

  factory _StreamedSourceRef.fromJson(Map<String, dynamic> j) =>
      _StreamedSourceRef(
        source: (j['source'] ?? '').toString(),
        id: (j['id'] ?? '').toString(),
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

  const _StreamedMatch({
    required this.id,
    required this.title,
    required this.category,
    required this.dateMs,
    required this.poster,
    required this.popular,
    this.airing = false,
    this.homeTeam,
    this.homeBadge,
    this.awayTeam,
    this.awayBadge,
    required this.sources,
    this.inlineStreams = const [],
    this.catalog = '',
    this.stremioBaseUrl = '',
    this.stremioType = 'sport',
  });

  bool get isMut => catalog == 'mut' || inlineStreams.isNotEmpty;

  bool get isStremio => stremioBaseUrl.isNotEmpty;

  factory _StreamedMatch.fromJson(Map<String, dynamic> j) {
    final teams = j['teams'] as Map<String, dynamic>?;
    final home = teams?['home'] as Map<String, dynamic>?;
    final away = teams?['away'] as Map<String, dynamic>?;

    return _StreamedMatch(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      dateMs: (j['date'] as num?)?.toInt() ?? 0,
      poster: (j['poster'] ?? '').toString(),
      popular: j['popular'] == true,
      airing: j['airing'] == true,
      homeTeam: home?['name'] as String?,
      homeBadge: home?['badge'] as String?,
      awayTeam: away?['name'] as String?,
      awayBadge: away?['badge'] as String?,
      sources: (j['sources'] as List? ?? [])
          .map((s) => _StreamedSourceRef.fromJson(s as Map<String, dynamic>))
          .where((s) => s.source.isNotEmpty && s.id.isNotEmpty)
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
          .where((s) => s.embedUrl.isNotEmpty)
          .toList(),
      catalog: (j['catalog'] ?? '').toString(),
      stremioBaseUrl: (j['stremioBaseUrl'] ?? '').toString(),
      stremioType: (j['stremioType'] ?? 'sport').toString(),
    );
  }

  String get categoryLabel =>
      category.isEmpty ? 'Other' : category.replaceAll('-', ' ');

  bool get isAlwaysOn =>
      dateMs == 0 && (sources.isNotEmpty || inlineStreams.isNotEmpty);

  /// Hours after start that still count as live when Streamed did not tag
  /// `airing`. Popular rows (golf, cycling) often outlast the short window.
  static int _liveWindowHours({required bool popular}) => popular ? 18 : 6;

  String get timeLabel {
    if (isLive) return 'live';

    if (dateMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final now = DateTime.now();
    if (dt.isAfter(now)) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  bool get isLive {
    if (isAlwaysOn || airing) return true;

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
    embedUrl: (j['embedUrl'] ?? '').toString(),
    source: (j['source'] ?? '').toString(),
    viewers: (j['viewers'] as num?)?.toInt() ?? 0,
  );
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

List<_StreamedMatch> _sortStreamedLiveFirst(List<_StreamedMatch> items) {
  final sorted = List<_StreamedMatch>.from(items);
  sorted.sort((a, b) {
    final live = _liveFirstCompare(
      aLive: a.isLive,
      bLive: b.isLive,
      aStart: a.dateMs,
      bStart: b.dateMs,
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

int _cdnSportStartKey(_CdnSportEvent event) =>
    int.tryParse(event.start) ?? int.tryParse(event.time) ?? 0;

List<_CdnSportEvent> _sortCdnSportsLiveFirst(List<_CdnSportEvent> items) {
  final sorted = List<_CdnSportEvent>.from(items);
  sorted.sort(
    (a, b) => _liveFirstCompare(
      aLive: a.isLive,
      bLive: b.isLive,
      aStart: _cdnSportStartKey(a),
      bStart: _cdnSportStartKey(b),
    ),
  );
  return sorted;
}

bool _gridEntryIsLive(_LiveMatchGridEntry entry) => switch (entry) {
  _LiveMatchGridEntryPpv(:final stream) => stream.isLive,
  _LiveMatchGridEntryStreamed(:final match) => match.isLive,
  _LiveMatchGridEntryMerged(:final ppv, :final streamed) =>
    ppv.isLive || streamed.isLive,
  _LiveMatchGridEntryCdnSport(:final event) => event.isLive,
};

int _gridEntryStartKey(_LiveMatchGridEntry entry) => switch (entry) {
  _LiveMatchGridEntryPpv(:final stream) => stream.startsAt,
  _LiveMatchGridEntryStreamed(:final match) => match.dateMs,
  _LiveMatchGridEntryMerged(:final streamed) => streamed.dateMs,
  _LiveMatchGridEntryCdnSport(:final event) => _cdnSportStartKey(event),
};

int _gridEntryViewers(_LiveMatchGridEntry entry) => switch (entry) {
  _LiveMatchGridEntryPpv(:final stream) => stream.viewers,
  _LiveMatchGridEntryStreamed() => 0,
  _LiveMatchGridEntryMerged(:final ppv) => ppv.viewers,
  _LiveMatchGridEntryCdnSport(:final event) => event.channels.fold<int>(
    0,
    (sum, ch) => sum + ch.viewers,
  ),
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
                token != 'w',
          )
          .toList()
        ..sort();
  return tokens.join(' ');
}

String? _teamPairKey(String? home, String? away) {
  if (home == null || away == null || home.isEmpty || away.isEmpty) return null;
  final teams = [_matchTextKey(home), _matchTextKey(away)]..sort();
  if (teams.any((team) => team.isEmpty)) return null;
  return teams.join('|');
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

  final ppvTeams = _teamPairKey(ppv.homeTeam, ppv.awayTeam);
  final streamedTeams = _teamPairKey(streamed.homeTeam, streamed.awayTeam);
  if (ppvTeams != null && streamedTeams != null) {
    return ppvTeams == streamedTeams;
  }
  final ppvTitle = _matchTextKey(ppv.name);
  final streamedTitle = _matchTextKey(streamed.title);
  return ppvTitle.isNotEmpty &&
      streamedTitle.isNotEmpty &&
      ppvTitle == streamedTitle;
}

List<_LiveMatchGridEntry> _mergePpvAndStreamedEntries({
  required List<_DamiTvStream> ppv,
  required List<_StreamedMatch> streamed,
  required List<_CdnSportEvent> cdn,
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
  entries.addAll(cdn.map(_LiveMatchGridEntry.cdnSport));
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
  'Origin': 'https://ppv.is',
  'Referer': 'https://ppv.is/',
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
/// matches the website (streamed.pk / ppv.is). Direct top-level loads of
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
String _buildLiveEmbedWrapperHtml(String embedUrl) {
  final safe = embedUrl
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;');
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
<iframe id="p" src="$safe" allow="autoplay; fullscreen; encrypted-media" allowfullscreen referrerpolicy="unsafe-url"></iframe>
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

const _ppvReferer = 'https://ppv.is/';
const _streamedBase = 'https://streamed.pk';
const _streamedReferer = 'https://streamed.pk/';
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
  final origin = Uri.tryParse(embedUrl)?.origin ?? 'https://embedindia.st';
  return {
    'User-Agent': _ua['User-Agent']!,
    'Referer': embedUrl,
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

/// Sniff the direct HLS/MP4 URL from a PPV embed, proxied so Referer applies
/// to every segment request.
Future<String?> _resolvePpvPlayUrl(String embedUrl) async {
  debugPrint('[LiveMatches] Extracting PPV embed: $embedUrl');
  final extracted = await StreamExtractor().extract(
    embedUrl,
    referer: _ppvReferer,
    iframeWrapperBaseUrl: _ppvReferer,
    timeout: const Duration(seconds: 25),
  );
  if (extracted == null || extracted.url.isEmpty) {
    debugPrint('[LiveMatches] PPV extract failed - WebView fallback');
    return null;
  }

  debugPrint('[LiveMatches] PPV extracted: ${extracted.url}');
  final headers = _ppvEmbedStreamHeaders(embedUrl);

  final proxy = LocalServerService();
  await proxy.start();
  if (proxy.port > 0) {
    return proxy.getHlsProxyUrl(extracted.url, headers);
  }
  return extracted.url;
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
    final raw = await runLiveMatchesFetchJson(
      jsonEncode({'action': 'streamed_matches'}),
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
  final live = release.contains('LIVE') || desc.contains('LIVE NOW');
  final poster = meta['poster']?.toString() ?? '';
  final type = meta['type']?.toString().trim();
  // For leaf / 24/7 IPTV rows with LIVE but no kickoff, treat as always-on.
  final alwaysOn = live &&
      (id.startsWith('leaf:') || desc.contains('IPTV'));
  return _StreamedMatch(
    id: id,
    title: title,
    category: alwaysOn
        ? '24/7'
        : (category.isEmpty ? 'other' : category.toLowerCase()),
    dateMs: 0,
    poster: poster,
    popular: desc.contains('POPULAR'),
    airing: live,
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
  out.sort((a, b) {
    if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return out;
}

Future<List<_StreamedStream>> _fetchStreamedStreams(
  _StreamedSourceRef sourceRef,
) async {
  try {
    final raw = await runLiveMatchesFetchJson(
      jsonEncode({
        'action': 'streamed_streams',
        'source': sourceRef.source,
        'id': sourceRef.id,
      }),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) return [];
    final list = parsed['items'] as List? ?? [];
    return list
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
  } catch (_) {
    return [];
  }
}

Future<List<_DamiTvStream>> _fetchDamiTvStreams() async {
  try {
    final raw = await runLiveMatchesFetchJson(
      jsonEncode({'action': 'damitv_streams'}),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) return [];
    final list = parsed['items'] as List? ?? [];
    return list
        .map((s) {
          try {
            return _DamiTvStream.fromJson(s as Map<String, dynamic>);
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

Future<List<_CdnChannel>> _fetchCdnChannels() async {
  try {
    final raw = await runLiveMatchesFetchJson(
      jsonEncode({'action': 'cdn_channels'}),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) return [];
    final list = parsed['items'] as List? ?? [];
    return list
        .map((c) => _CdnChannel.fromJson(c as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<List<_CdnSportEvent>> _fetchCdnSports() async {
  try {
    final raw = await runLiveMatchesFetchJson(
      jsonEncode({'action': 'cdn_sports'}),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) return [];
    final list = parsed['items'] as List? ?? [];
    return list
        .map((e) {
          try {
            return _CdnSportEvent.fromJson(e as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<_CdnSportEvent>()
        .toList();
  } catch (_) {
    return [];
  }
}

enum _LiveMatchesServer { all, ppv, streamed, mutStreams, cdnLive, stremio }

String _liveMatchesServerLabel(_LiveMatchesServer server) => switch (server) {
  _LiveMatchesServer.all => 'All',
  _LiveMatchesServer.ppv => 'PPV',
  _LiveMatchesServer.streamed => 'Streamed',
  _LiveMatchesServer.mutStreams => 'MutStreams',
  _LiveMatchesServer.cdnLive => 'CDN Live',
  _LiveMatchesServer.stremio => 'Stremio',
};

String _liveMatchesServerSubtitle(_LiveMatchesServer server) =>
    switch (server) {
      _LiveMatchesServer.all => 'PPV · Streamed · CDN Live',
      _LiveMatchesServer.ppv => 'ppv.is',
      _LiveMatchesServer.streamed => 'streamed.pk',
      _LiveMatchesServer.mutStreams => 'mut.st',
      _LiveMatchesServer.cdnLive => 'cdn-live.tv',
      _LiveMatchesServer.stremio => 'Installed live addons',
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

  factory _LiveMatchGridEntry.cdnSport(_CdnSportEvent event) =
      _LiveMatchGridEntryCdnSport;
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

final class _LiveMatchGridEntryCdnSport extends _LiveMatchGridEntry {
  const _LiveMatchGridEntryCdnSport(this.event);
  final _CdnSportEvent event;
}
