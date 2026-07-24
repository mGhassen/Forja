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
}) =>
    includeLiveMatchInSportFilter(
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
  /// PPV `always_live` — 24/7 channels keep stale start/end windows.
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

  /// Playable 24/7 channel — PPV often leaves expired `starts_at`/`ends_at`
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
  });

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
    );
  }

  String get categoryLabel =>
      category.isEmpty ? 'Other' : category.replaceAll('-', ' ');

  bool get isAlwaysOn => dateMs == 0 && sources.isNotEmpty;

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
  final tokens = value
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

/// Force play on embed players that gate behind a gesture / big-play overlay.
/// One retry only — repeated clicks restart playback and cause visible stutter.
const _autoplayJs = r'''
(function () {
  function clickPlay() {
    var sels = [
      'video',
      '.vjs-big-play-button',
      '.jw-icon-display',
      '.plyr__control--overlaid',
      'button[aria-label*="Play"]',
      'button[title*="Play"]',
      '.play-button',
      '#big_play_button'
    ];
    for (var i = 0; i < sels.length; i++) {
      try {
        var nodes = document.querySelectorAll(sels[i]);
        for (var j = 0; j < nodes.length; j++) {
          var el = nodes[j];
          if (el.tagName === 'VIDEO' || el.tagName === 'AUDIO') {
            el.setAttribute('autoplay', '');
            el.muted = false;
            var p = el.play();
            if (p && p.catch) {
              p.catch(function () {
                el.muted = true;
                el.play().catch(function () {});
              });
            }
          } else if (typeof el.click === 'function') {
            el.click();
          }
        }
      } catch (_) {}
    }
  }
  clickPlay();
  setTimeout(clickPlay, 1500);
})();
''';

/// Installs play / pause / mute handlers in every frame (wrapper + embed iframe)
/// and bridges Flutter chrome via `postMessage({__forjaMedia: 'play'|…})`.
const _embedMediaControlUserScript = r'''
(function () {
  if (window.__forjaMediaCtrl) return;
  window.__forjaMediaCtrl = true;

  function clickPlay() {
    var sels = [
      'video',
      'audio',
      '.vjs-big-play-button',
      '.jw-icon-display',
      '.plyr__control--overlaid',
      'button[aria-label*="Play"]',
      'button[title*="Play"]',
      '.play-button',
      '#big_play_button'
    ];
    for (var i = 0; i < sels.length; i++) {
      try {
        var nodes = document.querySelectorAll(sels[i]);
        for (var j = 0; j < nodes.length; j++) {
          var el = nodes[j];
          if (el.tagName === 'VIDEO' || el.tagName === 'AUDIO') {
            el.setAttribute('autoplay', '');
            el.muted = false;
            var p = el.play();
            if (p && p.catch) {
              p.catch(function () {
                el.muted = true;
                el.play().catch(function () {});
              });
            }
          } else if (typeof el.click === 'function') {
            el.click();
          }
        }
      } catch (_) {}
    }
  }

  function pauseAll() {
    try {
      document.querySelectorAll('video,audio').forEach(function (el) {
        try { el.pause(); } catch (e) {}
      });
    } catch (_) {}
  }

  function toggleMute() {
    try {
      document.querySelectorAll('video,audio').forEach(function (el) {
        try { el.muted = !el.muted; } catch (e) {}
      });
    } catch (_) {}
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
    if (cmd === 'play') clickPlay();
    else if (cmd === 'pause') pauseAll();
    else if (cmd === 'mute') toggleMute();
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
/// `video`/`audio` alone is not enough for the iframe wrapper — blank iframes too.
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
/// embed.st stall behind parser-blocking ad scripts and leave a white WebView.
///
/// Do **not** set HTML `sandbox` — embed hosts reject sandboxed parents with
/// "SANDBOX IFRAME NOT ALLOWED". Main-frame hijacks are cancelled in
/// `shouldOverrideUrlLoading`; ad `window.open` is accepted off-screen (hidden)
/// so Streamed embeds that require a successful open keep playing.
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
  // Click / interstitial networks are not URL-blocked here — window.open is
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

bool _liveEmbedAllowsNavigation({
  required String url,
  required String embedUrl,
  required String referer,
  required String origin,
}) {
  if (url.isEmpty ||
      url.startsWith('about:') ||
      url.startsWith('data:') ||
      url.startsWith('blob:')) {
    return true;
  }
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return true;
  final allowed = <String>{
    Uri.tryParse(embedUrl)?.host.toLowerCase() ?? '',
    Uri.tryParse(referer)?.host.toLowerCase() ?? '',
    Uri.tryParse(origin)?.host.toLowerCase() ?? '',
  }.where((h) => h.isNotEmpty);
  for (final h in allowed) {
    if (host == h || host.endsWith('.$h')) return true;
  }
  return false;
}

const _ppvReferer = 'https://ppv.is/';
const _streamedBase = 'https://streamed.pk';
const _streamedReferer = 'https://streamed.pk/';

String _streamedImageUrl(String path) {
  if (path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  if (path.startsWith('/')) return '$_streamedBase$path';
  return '$_streamedBase/api/images/badge/$path.webp';
}

/// embedindia JW Player resolves tokenised HLS inside the embed browsing
/// context. The sniffed m3u8 403s in mpv — same as copying the URL into VLC.
bool _ppvEmbedRequiresWebView(String embedUrl) {
  final host = Uri.tryParse(embedUrl)?.host.toLowerCase() ?? '';
  return host.contains('embedindia.st');
}

Map<String, String> _ppvEmbedStreamHeaders(String embedUrl) {
  final origin = Uri.tryParse(embedUrl)?.origin ?? 'https://embedindia.st';
  return {
    'User-Agent': _ua['User-Agent']!,
    'Referer': embedUrl,
    'Origin': origin,
  };
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
    debugPrint('[LiveMatches] PPV extract failed — WebView fallback');
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

enum _LiveMatchesServer { all, ppv, streamed, cdnLive }

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

String _liveMatchesServerLabel(_LiveMatchesServer server) => switch (server) {
  _LiveMatchesServer.all => 'All',
  _LiveMatchesServer.ppv => 'PPV',
  _LiveMatchesServer.streamed => 'Streamed',
  _LiveMatchesServer.cdnLive => 'CDN Live',
};

String _liveMatchesServerSubtitle(_LiveMatchesServer server) =>
    switch (server) {
      _LiveMatchesServer.all => 'PPV · Streamed · CDN Live',
      _LiveMatchesServer.ppv => 'ppv.is',
      _LiveMatchesServer.streamed => 'streamed.pk',
      _LiveMatchesServer.cdnLive => 'cdn-live.tv',
    };
