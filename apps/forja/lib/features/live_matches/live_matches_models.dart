part of 'live_matches_screen.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

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
    final viewersRaw = j['viewers'];
    final viewers = viewersRaw is num
        ? viewersRaw.toInt()
        : int.tryParse(viewersRaw?.toString() ?? '') ?? 0;

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
      viewers: viewers,
      iframe: (j['iframe'] ?? '').toString(),
    );
  }

  bool get isAlwaysOn => startsAt == 0 && endsAt == 0 && iframe.isNotEmpty;

  String get timeLabel {
    if (isAlwaysOn) return 'live';

    final statusLower = status.toLowerCase();
    if (statusLower == 'live') return 'live';

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (startsAt > 0 && endsAt > startsAt && now >= startsAt && now <= endsAt) {
      return 'live';
    }
    if (startsAt > now) {
      final dt = DateTime.fromMillisecondsSinceEpoch(startsAt * 1000);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  bool get isLive {
    if (isAlwaysOn) return true;

    final statusLower = status.toLowerCase();
    if (statusLower == 'live') return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return startsAt > 0 &&
        endsAt > startsAt &&
        now >= startsAt &&
        now <= endsAt;
  }
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

  String get timeLabel {
    if (isAlwaysOn) return 'live';

    if (dateMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final now = DateTime.now();
    final delta = now.difference(dt);
    if (delta.inMinutes >= 0 && delta.inHours < 6) return 'live';
    if (dt.isAfter(now)) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  bool get isLive {
    if (isAlwaysOn) return true;

    if (dateMs <= 0) return false;
    final dt = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final now = DateTime.now();
    final delta = now.difference(dt);
    return delta.inMinutes >= 0 && delta.inHours < 6;
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

  String get label {
    final parts = <String>['Stream ${streamNo > 0 ? streamNo : 1}'];
    if (language.isNotEmpty) parts.add(language);
    if (hd) parts.add('HD');
    if (source.isNotEmpty) parts.add(source);
    if (viewers > 0) parts.add('$viewers viewers');
    return parts.join(' · ');
  }
}

int _liveFirstCompare({
  required bool aLive,
  required bool bLive,
  required int aStart,
  required int bStart,
}) {
  if (aLive != bLive) return aLive ? -1 : 1;
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
    ),
  );
  return sorted;
}

List<_StreamedMatch> _sortStreamedLiveFirst(List<_StreamedMatch> items) {
  final sorted = List<_StreamedMatch>.from(items);
  sorted.sort(
    (a, b) => _liveFirstCompare(
      aLive: a.isLive,
      bLive: b.isLive,
      aStart: a.dateMs,
      bStart: b.dateMs,
    ),
  );
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
  _LiveMatchGridEntryCdnSport(:final event) => event.isLive,
};

int _gridEntryStartKey(_LiveMatchGridEntry entry) => switch (entry) {
  _LiveMatchGridEntryPpv(:final stream) => stream.startsAt,
  _LiveMatchGridEntryStreamed(:final match) => match.dateMs,
  _LiveMatchGridEntryCdnSport(:final event) => _cdnSportStartKey(event),
};

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
          if (el.tagName === 'VIDEO') {
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
